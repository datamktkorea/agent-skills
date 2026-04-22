#!/usr/bin/env bash
# create-page.sh --parent <db_key_or_data_source_id>
#                --properties <json>
#                [--markdown <file_or_-> | --markdown-text <string>]
#
# POST /v1/pages

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: create-page.sh --parent <db_key_or_data_source_id>
                      --properties <json>
                      [--markdown <file_or_->]
                      [--markdown-text <string>]

  --parent         Config key (e.g. triggers_db) or raw data_source_id.
  --properties     Notion properties JSON (passthrough — match the target schema).
  --markdown       Path to a markdown file, or '-' to read from stdin.
  --markdown-text  Inline markdown string. Mutually exclusive with --markdown.
EOF
  exit 2
}

parent=""
properties=""
markdown_path=""
markdown_text=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent)        parent="$2"; shift 2 ;;
    --properties)    properties="$2"; shift 2 ;;
    --markdown)      markdown_path="$2"; shift 2 ;;
    --markdown-text) markdown_text="$2"; shift 2 ;;
    -h|--help)       usage ;;
    *)               die_precondition "unknown argument: $1" ;;
  esac
done

[[ -n "$parent" && -n "$properties" ]] || usage

if [[ -n "$markdown_path" && -n "$markdown_text" ]]; then
  die_precondition "--markdown and --markdown-text are mutually exclusive."
fi

markdown=""
if [[ -n "$markdown_path" ]]; then
  if [[ "$markdown_path" == "-" ]]; then
    markdown="$(cat)"
  else
    [[ -f "$markdown_path" ]] || die_precondition "markdown file not found: $markdown_path"
    markdown="$(cat "$markdown_path")"
  fi
elif [[ -n "$markdown_text" ]]; then
  markdown="$markdown_text"
fi

notion_api_init
ds_id="$(resolve_parent_ds_id "$parent")"

body="$(jq -n \
  --arg ds "$ds_id" \
  --argjson props "$properties" \
  '{parent: {type: "data_source_id", data_source_id: $ds}, properties: $props}')"

if [[ -n "$markdown" ]]; then
  body="$(echo "$body" | jq --arg md "$markdown" '. + {markdown: $md}')"
fi

notion_curl POST "/v1/pages" "$body"
