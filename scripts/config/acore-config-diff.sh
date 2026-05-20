#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v diff >/dev/null 2>&1 || die "diff is not available"

extract_keys() {
  local file="$1"

  awk '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*$/ { next }
    /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/ {
      line = $0
      sub(/^[[:space:]]*/, "", line)
      sub(/[[:space:]]*=.*/, "", line)
      print line
    }
  ' "$file" | sort -u
}

compare_pair() {
  local live_file="$1"
  local dist_file="$2"

  echo
  echo "Live: $live_file"
  echo "Dist: $dist_file"

  if [[ ! -f "$live_file" ]]; then
    echo "WARN: live config file is missing"
    return
  fi

  if [[ ! -f "$dist_file" ]]; then
    echo "WARN: matching .dist file is missing"
    return
  fi

  live_keys="$(mktemp)"
  dist_keys="$(mktemp)"

  extract_keys "$live_file" > "$live_keys"
  extract_keys "$dist_file" > "$dist_keys"

  echo "Options present in .dist but missing from live config:"
  comm -23 "$dist_keys" "$live_keys" || true

  echo
  echo "Options present in live config but not in .dist:"
  comm -13 "$dist_keys" "$live_keys" || true

  rm -f "$live_keys" "$dist_keys"
}

log "Config diff"

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "WARN: CONFIG_DIR does not exist: $CONFIG_DIR"
fi

if [[ ! -d "$CURRENT_LINK/etc" ]]; then
  echo "WARN: current release etc directory does not exist: $CURRENT_LINK/etc"
  exit 0
fi

found=false
while IFS= read -r dist_file; do
  found=true
  relative_path="${dist_file#$CURRENT_LINK/etc/}"
  live_relative="${relative_path%.dist}"
  live_file="$CONFIG_DIR/$live_relative"
  compare_pair "$live_file" "$dist_file"
done < <(find "$CURRENT_LINK/etc" -type f -name '*.dist' | sort)

if [[ "$found" == "false" ]]; then
  echo "WARN: no .dist files found under $CURRENT_LINK/etc"
fi
