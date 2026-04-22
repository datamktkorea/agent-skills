#!/usr/bin/env bash
# update-page.sh <page_id_or_url> --properties <json>
# update-page.sh <page_id_or_url> --trash
# update-page.sh <page_id_or_url> --restore
#
# PATCH /v1/pages/{id}

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  cat >&2 <<'EOF'
Usage: update-page.sh <page_id_or_url> --properties <json>
       update-page.sh <page_id_or_url> --trash
       update-page.sh <page_id_or_url> --restore

Exactly one of --properties / --trash / --restore must be provided.
EOF
  exit 2
}

[[ $# -ge 2 ]] || usage

input="$1"; shift
properties=""
trash=0
restore=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --properties) properties="$2"; shift 2 ;;
    --trash)      trash=1; shift ;;
    --restore)    restore=1; shift ;;
    -h|--help)    usage ;;
    *)            die_precondition "unknown argument: $1" ;;
  esac
done

mode_count=0
[[ -n "$properties" ]] && mode_count=$((mode_count + 1))
[[ $trash -eq 1 ]]     && mode_count=$((mode_count + 1))
[[ $restore -eq 1 ]]   && mode_count=$((mode_count + 1))
[[ $mode_count -eq 1 ]] || usage

notion_api_init
page_id="$(resolve_page_id "$input")"

if [[ -n "$properties" ]]; then
  body="$(jq -n --argjson p "$properties" '{properties: $p}')"
elif [[ $trash -eq 1 ]]; then
  body='{"in_trash": true}'
else
  body='{"in_trash": false}'
fi

notion_curl PATCH "/v1/pages/${page_id}" "$body"
