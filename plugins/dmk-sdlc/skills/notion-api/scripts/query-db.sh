#!/usr/bin/env bash
# query-db.sh <db_key_or_id> [--filter <json>] [--sorts <json>]
#                           [--page-size N] [--start-cursor <uuid>]
#                           [--all]
#
# POST /v1/data_sources/{data_source_id}/query

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: query-db.sh <db_key_or_id>
                   [--filter <json>] [--sorts <json>]
                   [--page-size N] [--start-cursor <uuid>]
                   [--all]

  db_key_or_id: a key from ~/.datamktkorea/config.json (e.g. requests_db)
                or a raw database_id / data_source_id.
  --all         Follow next_cursor until has_more=false; merge all results.
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage

db_input=""
filter=""
sorts=""
page_size=""
start_cursor=""
fetch_all=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --filter)       filter="$2"; shift 2 ;;
    --sorts)        sorts="$2"; shift 2 ;;
    --page-size)    page_size="$2"; shift 2 ;;
    --start-cursor) start_cursor="$2"; shift 2 ;;
    --all)          fetch_all=1; shift ;;
    -h|--help)      usage ;;
    -*)             die_precondition "unknown option: $1" ;;
    *)
      [[ -z "$db_input" ]] || die_precondition "unexpected extra argument: $1"
      db_input="$1"; shift ;;
  esac
done

[[ -n "$db_input" ]] || usage

notion_api_init
ds_id="$(resolve_parent_ds_id "$db_input")"

build_body() {
  local cursor="$1"
  local body='{}'
  [[ -n "$filter" ]]       && body="$(echo "$body" | jq --argjson v "$filter" '. + {filter:$v}')"
  [[ -n "$sorts" ]]        && body="$(echo "$body" | jq --argjson v "$sorts"  '. + {sorts:$v}')"
  [[ -n "$page_size" ]]    && body="$(echo "$body" | jq --argjson v "$page_size" '. + {page_size:$v}')"
  [[ -n "$cursor" ]]       && body="$(echo "$body" | jq --arg v "$cursor" '. + {start_cursor:$v}')"
  echo "$body"
}

path="/v1/data_sources/${ds_id}/query"

if [[ $fetch_all -ne 1 ]]; then
  body="$(build_body "$start_cursor")"
  notion_curl POST "$path" "$body"
else
  # Paginate and merge.
  merged='{"object":"list","results":[],"next_cursor":null,"has_more":false}'
  cursor="$start_cursor"
  while :; do
    body="$(build_body "$cursor")"
    page="$(notion_curl POST "$path" "$body")"
    merged="$(jq -n --argjson a "$merged" --argjson b "$page" '{
      object: "list",
      results: ($a.results + $b.results),
      next_cursor: $b.next_cursor,
      has_more: $b.has_more
    }')"
    if [[ "$(echo "$page" | jq -r '.has_more')" != "true" ]]; then
      break
    fi
    cursor="$(echo "$page" | jq -r '.next_cursor')"
  done
  echo "$merged"
fi
