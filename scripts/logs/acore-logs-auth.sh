#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v journalctl >/dev/null 2>&1 || die "journalctl is not available"

log "Following auth service logs"
echo "Service: $AUTH_SERVICE"

journalctl -u "$AUTH_SERVICE" -f
