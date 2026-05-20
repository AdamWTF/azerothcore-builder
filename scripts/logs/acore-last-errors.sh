#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v journalctl >/dev/null 2>&1 || die "journalctl is not available"

PATTERN='ERROR|WARN|CRASH|DBUpdater|failed|exception'
LINES="${1:-500}"

log "Recent auth service issues"
echo "Service: $AUTH_SERVICE"
journalctl -u "$AUTH_SERVICE" -n "$LINES" --no-pager 2>/dev/null | grep -Ei "$PATTERN" || echo "No matching recent auth log entries."

log "Recent world service issues"
echo "Service: $WORLD_SERVICE"
journalctl -u "$WORLD_SERVICE" -n "$LINES" --no-pager 2>/dev/null | grep -Ei "$PATTERN" || echo "No matching recent world log entries."
