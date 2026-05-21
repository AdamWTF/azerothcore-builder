#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

timestamp="$(date +%Y%m%d-%H%M%S)"

[[ -L "$CURRENT_LINK" ]] || die "CURRENT_LINK is not a symlink: $CURRENT_LINK"
current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
[[ -n "$current_target" && -d "$current_target" ]] || die "CURRENT_LINK does not point to a release: $CURRENT_LINK"

[[ -f "$CONFIG_DIR/authserver.conf" ]] || die "missing shared auth config: $CONFIG_DIR/authserver.conf; run scripts/config/acore-prepare-configs.sh first"
[[ -f "$CONFIG_DIR/worldserver.conf" ]] || die "missing shared world config: $CONFIG_DIR/worldserver.conf; run scripts/config/acore-prepare-configs.sh first"
[[ -d "$MODULE_CONFIG_DIR" ]] || die "missing shared module config directory: $MODULE_CONFIG_DIR; run scripts/config/acore-prepare-configs.sh first"

backup_existing_path() {
  local path="$1"

  if [[ -L "$path" ]]; then
    rm -f "$path"
  elif [[ -e "$path" ]]; then
    local backup_path="$path.pre-shared-configs.$timestamp.bak"
    mv "$path" "$backup_path"
    echo "Moved existing path aside: $path -> $backup_path"
  fi
}

link_path() {
  local target="$1"
  local link="$2"

  if [[ -L "$link" ]]; then
    local current_link_target intended_target
    current_link_target="$(readlink -f "$link" 2>/dev/null || true)"
    intended_target="$(readlink -f "$target" 2>/dev/null || true)"
    if [[ "$current_link_target" == "$intended_target" ]]; then
      echo "OK: $link -> $target"
      return
    fi
  fi

  backup_existing_path "$link"
  ln -s "$target" "$link"
  echo "Linked: $link -> $target"
}

log "Linking shared configs into active release"
echo "Active release: $current_target"

mkdir -p "$current_target/etc"

link_path "$CONFIG_DIR/authserver.conf" "$current_target/etc/authserver.conf"
link_path "$CONFIG_DIR/worldserver.conf" "$current_target/etc/worldserver.conf"
link_path "$MODULE_CONFIG_DIR" "$current_target/etc/modules"

[[ "$(readlink -f "$current_target/etc/authserver.conf")" == "$(readlink -f "$CONFIG_DIR/authserver.conf")" ]] || die "authserver.conf symlink validation failed"
[[ "$(readlink -f "$current_target/etc/worldserver.conf")" == "$(readlink -f "$CONFIG_DIR/worldserver.conf")" ]] || die "worldserver.conf symlink validation failed"
[[ "$(readlink -f "$current_target/etc/modules")" == "$(readlink -f "$MODULE_CONFIG_DIR")" ]] || die "modules symlink validation failed"

echo
echo "Shared config links are ready:"
echo "  $CURRENT_LINK/etc/authserver.conf -> $CONFIG_DIR/authserver.conf"
echo "  $CURRENT_LINK/etc/worldserver.conf -> $CONFIG_DIR/worldserver.conf"
echo "  $CURRENT_LINK/etc/modules -> $MODULE_CONFIG_DIR"
