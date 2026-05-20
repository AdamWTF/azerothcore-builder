#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v cmake >/dev/null 2>&1 || die "cmake is not available"
command -v make >/dev/null 2>&1 || die "make is not available"

[[ -d "$ACORE_SOURCE_DIR" ]] || die "ACORE_SOURCE_DIR does not exist: $ACORE_SOURCE_DIR"
[[ -f "$ACORE_SOURCE_DIR/CMakeLists.txt" ]] || die "ACORE_SOURCE_DIR does not look like an AzerothCore source tree: $ACORE_SOURCE_DIR"

STAGING_DIR="$BUILD_DIR/staging"

build_threads="$BUILD_THREADS"
if [[ "$build_threads" == "auto" ]]; then
  if command -v nproc >/dev/null 2>&1; then
    build_threads="$(nproc)"
  else
    build_threads="1"
  fi
fi

log "Preparing build directories"
mkdir -p "$BUILD_DIR"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

log "Configuring AzerothCore"
cmake -S "$ACORE_SOURCE_DIR" -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
  -DCMAKE_INSTALL_PREFIX="$STAGING_DIR"

log "Building AzerothCore"
cmake --build "$BUILD_DIR" --parallel "$build_threads"

log "Installing into staging"
cmake --install "$BUILD_DIR"

echo
echo "Build completed successfully."
echo "Staging directory: $STAGING_DIR"
