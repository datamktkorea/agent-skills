#!/usr/bin/env bash
# update-content.sh <page_id_or_url> replace --markdown <file_or_->
# update-content.sh <page_id_or_url> update --replacements <json>
#
# PATCH /v1/pages/{id}/markdown

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: update-content.sh <page_id_or_url> replace --markdown <file_or_->
       update-content.sh <page_id_or_url> update --replacements <json>

  replace  Rewrite the entire page body from the given markdown.
  update   Apply search-and-replace operations. --replacements is a JSON array
           like: [{"old_str":"...","new_str":"...","replace_all_matches":true}]
EOF
  exit 2
}

[[ $# -ge 3 ]] || usage

input="$1"; shift
mode="$1"; shift

case "$mode" in
  replace|update) ;;
  *) usage ;;
esac

markdown_path=""
replacements=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown)     markdown_path="$2"; shift 2 ;;
    --replacements) replacements="$2"; shift 2 ;;
    -h|--help)      usage ;;
    *)              die_precondition "unknown argument: $1" ;;
  esac
done

notion_api_init
page_id="$(resolve_page_id "$input")"

if [[ "$mode" == "replace" ]]; then
  [[ -n "$markdown_path" ]] || die_precondition "replace mode requires --markdown <file_or_->."
  if [[ "$markdown_path" == "-" ]]; then
    new_md="$(cat)"
  else
    [[ -f "$markdown_path" ]] || die_precondition "markdown file not found: $markdown_path"
    new_md="$(cat "$markdown_path")"
  fi
  body="$(jq -n --arg s "$new_md" '{type: "replace_content", replace_content: {new_str: $s}}')"
else
  # update
  [[ -n "$replacements" ]] || die_precondition "update mode requires --replacements <json-array>."
  body="$(jq -n --argjson r "$replacements" '{type: "update_content", update_content: {content_updates: $r}}')"
fi

notion_curl PATCH "/v1/pages/${page_id}/markdown" "$body"
