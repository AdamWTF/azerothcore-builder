#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

ACM_LOCAL_DB_CONFIG="$ACM_REPO_ROOT/config/local/db.conf"

if [[ -f "$ACM_LOCAL_DB_CONFIG" ]]; then
  # shellcheck disable=SC1090
  source "$ACM_LOCAL_DB_CONFIG"
fi

errors=0
mysql_args=(
  "--host=${MYSQL_HOST:-127.0.0.1}"
  "--port=${MYSQL_PORT:-3306}"
  "--batch"
  "--skip-column-names"
)

if [[ -n "${MYSQL_USER:-}" ]]; then
  mysql_args+=("--user=$MYSQL_USER")
else
  echo "WARN: MYSQL_USER is not set; trying MySQL client defaults"
fi

if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  echo "WARN: MYSQL_PASSWORD is not set; trying MySQL client defaults"
fi

run_mysql() {
  if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
    MYSQL_PWD="$MYSQL_PASSWORD" command mysql "${mysql_args[@]}" "$@"
  else
    command mysql "${mysql_args[@]}" "$@"
  fi
}

check_db_exists() {
  local db_name="$1"
  local count

  count="$(run_mysql -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${db_name}';" 2>/dev/null || true)"

  if [[ "$count" == "1" ]]; then
    echo "OK: database exists: $db_name"
  else
    echo "ERROR: database not found: $db_name"
    errors=$((errors + 1))
  fi
}

log "MySQL Client"
if command -v mysql >/dev/null 2>&1; then
  echo "OK: mysql client found: $(command -v mysql)"
else
  die "mysql client is not installed or not in PATH"
fi

log "MySQL Connection"
if run_mysql -e "SELECT 1;" >/dev/null 2>&1; then
  echo "OK: connected to MySQL at ${MYSQL_HOST:-127.0.0.1}:${MYSQL_PORT:-3306}"
else
  die "unable to connect to MySQL; configure credentials outside git, for example in config/local/manager.conf or config/local/db.conf"
fi

log "MySQL Version"
run_mysql -e "SELECT VERSION();" || errors=$((errors + 1))

log "Databases"
check_db_exists "$MYSQL_AUTH_DB"
check_db_exists "$MYSQL_WORLD_DB"
check_db_exists "$MYSQL_CHAR_DB"

if [[ "$errors" -gt 0 ]]; then
  die "database check failed with $errors error(s)"
fi

echo
echo "Database check completed with no blocking errors."
