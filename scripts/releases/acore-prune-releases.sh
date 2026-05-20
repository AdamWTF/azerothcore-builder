#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

keep_count="${ACORE_RELEASE_KEEP_COUNT:-${1:-5}}"
[[ "$keep_count" =~ ^[0-9]+$ ]] || die "keep count must be a non-negative integer: $keep_count"

active_release=""
if [[ -L "$CURRENT_LINK" ]]; then
  active_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
  if [[ -n "$active_target" ]]; then
    active_release="$(basename "$active_target")"
  fi
fi

[[ -d "$RELEASES_DIR" ]] || die "RELEASES_DIR does not exist: $RELEASES_DIR"

mapfile -t releases < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)

declare -A keep=()
kept_recent=0
for release in "${releases[@]}"; do
  if [[ "$kept_recent" -lt "$keep_count" ]]; then
    keep["$release"]=1
    kept_recent=$((kept_recent + 1))
  fi
done

if [[ -n "$active_release" ]]; then
  keep["$active_release"]=1
fi

log "Pruning releases"
echo "Releases directory: $RELEASES_DIR"
echo "Keep recent count: $keep_count"
echo "Active release: ${active_release:-none}"
echo

for release in "${releases[@]}"; do
  release_dir="$RELEASES_DIR/$release"

  if [[ -n "${keep[$release]:-}" ]]; then
    echo "Keeping: $release"
  else
    echo "Pruning: $release"
    rm -rf -- "$release_dir"
  fi
done
