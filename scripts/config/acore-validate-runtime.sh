#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

errors=0

warn_or_error_link() {
  local link_path="$1"
  local expected_path="$2"

  if [[ ! -L "$link_path" ]]; then
    echo "ERROR: expected symlink is missing: $link_path"
    errors=$((errors + 1))
    return
  fi

  local actual expected
  actual="$(readlink -f "$link_path" 2>/dev/null || true)"
  expected="$(readlink -f "$expected_path" 2>/dev/null || true)"
  if [[ "$actual" == "$expected" && -n "$actual" ]]; then
    echo "OK: $link_path -> $expected_path"
  else
    echo "ERROR: $link_path points to $actual, expected $expected_path"
    errors=$((errors + 1))
  fi
}

log "Runtime release"
if [[ -L "$CURRENT_LINK" ]]; then
  current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  if [[ -n "$current_target" && -d "$current_target" ]]; then
    echo "OK: active release: $current_target"
  else
    echo "ERROR: CURRENT_LINK cannot be resolved: $CURRENT_LINK"
    errors=$((errors + 1))
  fi
else
  echo "ERROR: CURRENT_LINK is not a symlink: $CURRENT_LINK"
  errors=$((errors + 1))
fi

log "Shared configs"
for path in "$CONFIG_DIR/authserver.conf" "$CONFIG_DIR/worldserver.conf" "$MODULE_CONFIG_DIR"; do
  if [[ -e "$path" ]]; then
    echo "OK: exists: $path"
  else
    echo "ERROR: missing: $path"
    errors=$((errors + 1))
  fi
done

if [[ -L "$CURRENT_LINK" ]]; then
  log "Active release config links"
  warn_or_error_link "$CURRENT_LINK/etc/authserver.conf" "$CONFIG_DIR/authserver.conf"
  warn_or_error_link "$CURRENT_LINK/etc/worldserver.conf" "$CONFIG_DIR/worldserver.conf"
  warn_or_error_link "$CURRENT_LINK/etc/modules" "$MODULE_CONFIG_DIR"
fi

"$SCRIPT_DIR/acore-check-data.sh" || true

if [[ "$errors" -gt 0 ]]; then
  die "runtime validation failed with $errors error(s)"
fi

echo
echo "Runtime validation completed with no blocking errors."
