#!/usr/bin/env bash
# fetch-page.sh <page_id_or_url> [--markdown-only] [--include-transcript]
#
# GET /v1/pages/{id}/markdown — returns the page body as Notion-flavored markdown.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  echo "Usage: $(basename "$0") <page_id_or_url> [--markdown-only] [--include-transcript]" >&2
  exit 2
}

[[ $# -ge 1 ]] || usage

input=""
markdown_only=0
include_transcript=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --markdown-only) markdown_only=1; shift ;;
    --include-transcript) include_transcript=1; shift ;;
    -h|--help) usage ;;
    --) shift; break ;;
    -*) die_precondition "unknown option: $1" ;;
    *)
      [[ -z "$input" ]] || die_precondition "unexpected extra argument: $1"
      input="$1"; shift ;;
  esac
done

[[ -n "$input" ]] || usage

notion_api_init
page_id="$(resolve_page_id "$input")"
path="/v1/pages/${page_id}/markdown"
[[ $include_transcript -eq 1 ]] && path="${path}?include_transcript=true"

resp="$(notion_curl GET "$path")"

if [[ $markdown_only -eq 1 ]]; then
  truncated="$(echo "$resp" | jq -r '.truncated')"
  unknown_count="$(echo "$resp" | jq -r '.unknown_block_ids | length')"
  [[ "$truncated" == "true" ]] && echo "[notion-api] warning: page content is truncated (>20k blocks)" >&2
  [[ "$unknown_count" -gt 0 ]] && echo "[notion-api] warning: $unknown_count unknown block(s) in response" >&2
  echo "$resp" | jq -r '.markdown'
else
  echo "$resp"
fi
