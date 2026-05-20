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

command -v mysqldump >/dev/null 2>&1 || die "mysqldump is not available"
command -v mysql >/dev/null 2>&1 || die "mysql client is not available"

[[ -n "${MYSQL_HOST:-}" ]] || die "MYSQL_HOST is not set"
[[ -n "${MYSQL_PORT:-}" ]] || die "MYSQL_PORT is not set"
[[ -n "${MYSQL_USER:-}" ]] || die "MYSQL_USER is not set; configure it in config/local/db.conf"
[[ -n "${MYSQL_PASSWORD:-}" ]] || die "MYSQL_PASSWORD is not set; configure it in config/local/db.conf"

mysql_args=(
  "--host=$MYSQL_HOST"
  "--port=$MYSQL_PORT"
  "--user=$MYSQL_USER"
)

run_mysql() {
  MYSQL_PWD="$MYSQL_PASSWORD" command mysql "${mysql_args[@]}" --batch --skip-column-names "$@"
}

run_mysqldump() {
  MYSQL_PWD="$MYSQL_PASSWORD" command mysqldump "${mysql_args[@]}" \
    --single-transaction \
    --routines \
    --events \
    --triggers \
    "$@"
}

check_db_exists() {
  local db_name="$1"
  local count

  count="$(run_mysql -e "SELECT COUNT(*) FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '${db_name}';" 2>/dev/null || true)"
  [[ "$count" == "1" ]] || die "database not found or not accessible: $db_name"
}

timestamp="$(date +%Y-%m-%d-%H%M)"
backup_dir="$BACKUP_DIR/db/$timestamp"
manifest="$backup_dir/backup-manifest.txt"
databases=("$MYSQL_AUTH_DB" "$MYSQL_WORLD_DB" "$MYSQL_CHAR_DB")

log "Checking MySQL connection"
run_mysql -e "SELECT 1;" >/dev/null || die "unable to connect to MySQL at $MYSQL_HOST:$MYSQL_PORT"

log "Creating database backup"
mkdir -p "$backup_dir"

{
  echo "Database backup manifest"
  echo "Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Host: $MYSQL_HOST"
  echo "Port: $MYSQL_PORT"
  echo "User: $MYSQL_USER"
  echo "Backup directory: $backup_dir"
  echo
  echo "Databases:"
} > "$manifest"

for db_name in "${databases[@]}"; do
  [[ -n "$db_name" ]] || die "configured database name is empty"

  check_db_exists "$db_name"

  output_file="$backup_dir/$db_name.sql"
  echo "Backing up $db_name -> $output_file"
  run_mysqldump "$db_name" > "$output_file"
  echo "  $db_name: $output_file" >> "$manifest"
done

echo
echo "Database backup completed."
echo "Backup directory: $backup_dir"
echo "Manifest: $manifest"
