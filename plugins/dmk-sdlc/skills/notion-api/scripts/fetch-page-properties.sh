#!/usr/bin/env bash
# fetch-page-properties.sh <page_id_or_url>
#
# GET /v1/pages/{id} — returns the page object (properties, parent, timestamps).

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

usage() {
  echo "Usage: $(basename "$0") <page_id_or_url>" >&2
  exit 2
}

[[ $# -eq 1 ]] || usage
[[ "$1" != "-h" && "$1" != "--help" ]] || usage

notion_api_init
page_id="$(resolve_page_id "$1")"
notion_curl GET "/v1/pages/${page_id}"
