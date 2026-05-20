#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

active_release=""
if [[ -L "$CURRENT_LINK" ]]; then
  active_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  if [[ -n "$active_target" ]]; then
    active_release="$(basename "$active_target")"
  fi
fi

log "AzerothCore releases"
echo "Releases directory: $RELEASES_DIR"
echo "Current link: $CURRENT_LINK"
if [[ -n "$active_release" ]]; then
  echo "Active release: $active_release"
else
  echo "Active release: none"
fi
echo

if [[ ! -d "$RELEASES_DIR" ]]; then
  echo "WARN: RELEASES_DIR does not exist: $RELEASES_DIR"
  exit 0
fi

found=false
while IFS= read -r release_dir; do
  found=true
  release_name="$(basename "$release_dir")"

  if [[ "$release_name" == "$active_release" ]]; then
    echo "* $release_name (active)"
  else
    echo "  $release_name"
  fi
done < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d | sort)

if [[ "$found" == "false" ]]; then
  echo "No releases found."
fi
