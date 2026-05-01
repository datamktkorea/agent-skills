#!/usr/bin/env bash
# Shared helpers for notion-api skill scripts.
#
# Source this file at the top of each script:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "${SCRIPT_DIR}/lib.sh"
#
# Contract: see skills/notion-api/SKILL.md.

set -euo pipefail

# ---------- Constants ----------

readonly NOTION_API_BASE="https://api.notion.com"
readonly NOTION_DEFAULT_VERSION="2026-03-11"
readonly CONFIG_PATH="${HOME}/.datamktkorea/config.json"
readonly MAX_RETRIES=3

# ---------- Exit helpers ----------

die_precondition() {
  # $1: message
  echo "notion-api precondition failed: $1" >&2
  exit 2
}

die_api() {
  # $1: message, $2 (optional): raw response for context
  echo "notion-api error: $1" >&2
  if [[ $# -ge 2 && -n "${2:-}" ]]; then
    echo "response: $2" >&2
  fi
  exit 1
}

debug() {
  [[ "${NOTION_DEBUG:-0}" == "1" ]] && echo "[notion-api] $*" >&2 || true
}

# ---------- Preconditions ----------

check_deps() {
  command -v jq >/dev/null 2>&1 || die_precondition "'jq' is not installed. Install it with 'brew install jq' (macOS)."
  command -v curl >/dev/null 2>&1 || die_precondition "'curl' is not installed."
}

load_config() {
  # Exports NOTION_TOKEN if not already set.
  if [[ -n "${NOTION_TOKEN:-}" ]]; then
    return 0
  fi
  [[ -f "$CONFIG_PATH" ]] || die_precondition "config file not found at $CONFIG_PATH — copy config.template.json and fill in your notion_token."
  local token
  token="$(jq -r '.notion_token // empty' "$CONFIG_PATH" 2>/dev/null || true)"
  [[ -n "$token" ]] || die_precondition "'notion_token' is empty in $CONFIG_PATH."
  export NOTION_TOKEN="$token"
}

# ---------- ID helpers ----------

# Normalize a 32-char hex (with or without dashes) to dashed UUID form.
# Accepts either a bare ID or a full Notion URL.
resolve_page_id() {
  # $1: input (id or url)
  local input="$1" hex
  # Extract 32 hex chars (dashes allowed as noise)
  hex="$(echo "$input" | grep -oE '[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}' | head -n1 | tr -d '-')"
  [[ -n "$hex" && ${#hex} -eq 32 ]] || die_precondition "could not extract a 32-char page ID from: $input"
  # Reassemble with dashes: 8-4-4-4-12
  echo "${hex:0:8}-${hex:8:4}-${hex:12:4}-${hex:16:4}-${hex:20:12}"
}

# Resolve a config key (like "requests_db") to its database_id. If the input
# is already a UUID-shaped string, pass it through (normalized to dashed form).
resolve_db_id() {
  # $1: key or id
  local input="$1"
  # Does it look like an ID already?
  if echo "$input" | grep -qE '^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$'; then
    resolve_page_id "$input"
    return 0
  fi
  [[ -f "$CONFIG_PATH" ]] || die_precondition "config file not found at $CONFIG_PATH."
  local raw
  raw="$(jq -r --arg k "$input" '.notion_dbs[$k] // empty' "$CONFIG_PATH" 2>/dev/null || true)"
  [[ -n "$raw" ]] || die_precondition "unknown db key '$input' — not found in notion_dbs of $CONFIG_PATH."
  resolve_page_id "$raw"
}

# Resolve a database_id to its data_source_id via GET /v1/databases/{id}.
resolve_ds_id() {
  # $1: database_id (dashed UUID)
  local db_id="$1"
  local resp ds
  resp="$(notion_curl GET "/v1/databases/${db_id}")"
  ds="$(echo "$resp" | jq -r '.data_sources[0].id // empty')"
  [[ -n "$ds" ]] || die_api "could not extract data_source_id for database ${db_id}" "$resp"
  echo "$ds"
}

# Accept either a db key, a database_id, or a data_source_id. Return a
# data_source_id. We distinguish by best-effort: resolve_db_id handles keys
# and database_ids; if the caller passed a data_source_id directly, the
# database retrieve call will return an error, so we first try that and fall
# back only if needed.
resolve_parent_ds_id() {
  # $1: db key | database_id | data_source_id
  local input="$1"
  # If it's a config key (non-UUID), resolve through the normal path.
  if ! echo "$input" | grep -qE '^[0-9a-fA-F]{8}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{4}-?[0-9a-fA-F]{12}$'; then
    local db_id; db_id="$(resolve_db_id "$input")"
    resolve_ds_id "$db_id"
    return 0
  fi
  # It's a UUID. Try as database_id first.
  local id; id="$(resolve_page_id "$input")"
  local resp
  if resp="$(notion_curl GET "/v1/databases/${id}" 2>/dev/null)" && echo "$resp" | jq -e '.data_sources[0].id' >/dev/null 2>&1; then
    echo "$resp" | jq -r '.data_sources[0].id'
  else
    # Assume the caller already passed a data_source_id.
    echo "$id"
  fi
}

# ---------- HTTP ----------

# notion_curl METHOD PATH [BODY]
# Emits the JSON response body on stdout. Retries 429/5xx up to MAX_RETRIES.
notion_curl() {
  local method="$1" path="$2" body="${3:-}"
  local version="${NOTION_VERSION:-$NOTION_DEFAULT_VERSION}"
  local url="${NOTION_API_BASE}${path}"
  local attempt=0 status body_resp retry_after sleep_for
  local tmp_body tmp_hdr
  tmp_body="$(mktemp)"
  tmp_hdr="$(mktemp)"
  trap 'rm -f "$tmp_body" "$tmp_hdr"' RETURN

  while :; do
    attempt=$((attempt + 1))
    debug "attempt $attempt: $method $url"
    local curl_args=(-sS -o "$tmp_body" -D "$tmp_hdr" -w "%{http_code}" -X "$method" "$url"
      -H "Authorization: Bearer ${NOTION_TOKEN}"
      -H "Notion-Version: ${version}")
    if [[ -n "$body" ]]; then
      curl_args+=(-H "Content-Type: application/json" --data-binary "$body")
    fi
    status="$(curl "${curl_args[@]}" || echo "000")"
    body_resp="$(cat "$tmp_body")"
    debug "status: $status"

    case "$status" in
      2??)
        echo "$body_resp"
        return 0
        ;;
      429|5??)
        if [[ $attempt -ge $MAX_RETRIES ]]; then
          die_api "exhausted $MAX_RETRIES retries for $method $path (last status: $status)" "$body_resp"
        fi
        retry_after="$(grep -i '^retry-after:' "$tmp_hdr" | awk '{print $2}' | tr -d '\r' | head -n1 || true)"
        if [[ -n "${retry_after:-}" ]] && echo "$retry_after" | grep -qE '^[0-9]+$'; then
          sleep_for="$retry_after"
        else
          # Exponential backoff: 1, 2, 4
          sleep_for=$((1 << (attempt - 1)))
        fi
        debug "retrying in ${sleep_for}s (status $status)"
        sleep "$sleep_for"
        ;;
      000)
        if [[ $attempt -ge $MAX_RETRIES ]]; then
          die_api "network failure after $MAX_RETRIES attempts for $method $path"
        fi
        sleep $((1 << (attempt - 1)))
        ;;
      *)
        # 4xx other than 429 — do not retry.
        die_api "$method $path returned HTTP $status" "$body_resp"
        ;;
    esac
  done
}

# ---------- Init ----------

notion_api_init() {
  check_deps
  load_config
}
