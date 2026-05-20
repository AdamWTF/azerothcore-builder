#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

errors=0

require_var() {
  local name="$1"

  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: $name is not set"
    errors=$((errors + 1))
  else
    echo "OK: $name is set"
  fi
}

require_cmd() {
  local name="$1"

  if command -v "$name" >/dev/null 2>&1; then
    echo "OK: command found: $name"
  else
    echo "ERROR: command missing: $name"
    errors=$((errors + 1))
  fi
}

check_path() {
  local name="$1"
  local path="$2"

  if [[ -d "$path" ]]; then
    echo "OK: $name exists: $path"
  elif [[ -e "$path" ]]; then
    echo "WARN: $name exists but is not a directory: $path"
  else
    echo "WARN: $name does not exist yet: $path"
  fi
}

log "Required Variables"
for name in \
  ACM_ROOT \
  ACORE_REPO \
  ACORE_BRANCH \
  ACORE_USER \
  ACORE_GROUP \
  AUTH_SERVICE \
  WORLD_SERVICE \
  MYSQL_HOST \
  MYSQL_PORT \
  MYSQL_AUTH_DB \
  MYSQL_WORLD_DB \
  MYSQL_CHAR_DB \
  DATADIR \
  CONFIG_DIR \
  BUILD_TYPE \
  BUILD_THREADS; do
  require_var "$name"
done

log "Required Commands"
for name in git cmake make mysql systemctl; do
  require_cmd "$name"
done

log "Paths"
check_path "ACM_ROOT" "$ACM_ROOT"
check_path "DATADIR" "$DATADIR"
check_path "CONFIG_DIR" "$CONFIG_DIR"

log "Services"
require_var AUTH_SERVICE
require_var WORLD_SERVICE

if [[ "$errors" -gt 0 ]]; then
  die "config validation failed with $errors error(s)"
fi

echo
echo "Config validation completed with no blocking errors."
