#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

DEST_DIR="/etc/OliveTin"
DEST_FILE="$DEST_DIR/config.yaml"
SOURCE_FILE="$ACM_REPO_ROOT/olivetin/config.yaml.example"

[[ -f "$SOURCE_FILE" ]] || die "OliveTin example config not found: $SOURCE_FILE"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "rendering OliveTin config requires root: sudo $0"
fi

log "Rendering OliveTin config"

mkdir -p "$DEST_DIR"

if [[ -f "$DEST_FILE" ]]; then
  if cmp -s "$SOURCE_FILE" "$DEST_FILE"; then
    echo "OliveTin config is already up to date: $DEST_FILE"
    exit 0
  fi

  backup_file="$DEST_FILE.$(date +%Y%m%d-%H%M%S).bak"
  cp -a "$DEST_FILE" "$backup_file"
  echo "Backed up existing config: $backup_file"
fi

install -m 0644 "$SOURCE_FILE" "$DEST_FILE"
echo "Installed OliveTin config: $DEST_FILE"
echo "OliveTin remains optional; this script did not install or start OliveTin."
