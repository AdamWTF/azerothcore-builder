#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v git >/dev/null 2>&1 || die "git is not available"

log "Updating AzerothCore source"

mkdir -p "$SOURCE_ROOT"

if [[ ! -d "$ACORE_SOURCE_DIR/.git" ]]; then
  if [[ -e "$ACORE_SOURCE_DIR" ]]; then
    die "ACORE_SOURCE_DIR exists but is not a git repository: $ACORE_SOURCE_DIR"
  fi

  echo "Cloning $ACORE_REPO into $ACORE_SOURCE_DIR"
  git clone "$ACORE_REPO" --branch "$ACORE_BRANCH" "$ACORE_SOURCE_DIR"
else
  echo "Fetching updates in $ACORE_SOURCE_DIR"
  git -C "$ACORE_SOURCE_DIR" fetch origin
fi

echo "Checking out branch: $ACORE_BRANCH"
git -C "$ACORE_SOURCE_DIR" checkout "$ACORE_BRANCH"

echo "Pulling latest changes"
git -C "$ACORE_SOURCE_DIR" pull --ff-only origin "$ACORE_BRANCH"

echo
echo "Current source commit:"
git -C "$ACORE_SOURCE_DIR" rev-parse HEAD
