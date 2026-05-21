#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

[[ -L "$CURRENT_LINK" ]] || die "CURRENT_LINK is not a symlink: $CURRENT_LINK"

current_target="$(readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
[[ -n "$current_target" ]] || die "unable to resolve CURRENT_LINK: $CURRENT_LINK"

current_release="$(basename "$current_target")"
[[ -d "$RELEASES_DIR/$current_release" ]] || die "current release is not under RELEASES_DIR: $current_target"

mapfile -t releases < <(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

previous_release=""
for index in "${!releases[@]}"; do
  if [[ "${releases[$index]}" == "$current_release" ]]; then
    if [[ "$index" -gt 0 ]]; then
      previous_release="${releases[$((index - 1))]}"
    fi
    break
  fi
done

[[ -n "$previous_release" ]] || die "no previous release exists before current release: $current_release"

echo "Rolling back from $current_release to $previous_release"
echo "WARN: rollback switches binaries and relinks shared configs, but does not roll back database schema changes or shared config edits."
"$SCRIPT_DIR/acore-switch-release.sh" "$previous_release"
