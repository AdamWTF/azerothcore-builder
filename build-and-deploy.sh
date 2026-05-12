#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
  echo "Missing config.env"
  exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

COMMAND="${1:-all}"
MODULES=()

log() {
  echo
  echo "================================================================"
  echo "$1"
  echo "================================================================"
}

run() {
  echo "+ $*"
  "$@"
}

trim() {
  local value="$1"

  # Remove Windows carriage returns.
  value="${value//$'\r'/}"

  # Trim leading whitespace.
  value="${value#"${value%%[![:space:]]*}"}"

  # Trim trailing whitespace.
  value="${value%"${value##*[![:space:]]}"}"

  printf '%s' "$value"
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

remote() {
  ssh "$REMOTE_HOST" "$@"
}

remote_tty() {
  ssh -t "$REMOTE_HOST" "$@"
}

load_modules() {
  MODULES=()

  while IFS='|' read -r module_name module_url module_branch || [[ -n "${module_name:-}" ]]; do
    module_name="$(trim "${module_name:-}")"
    module_url="$(trim "${module_url:-}")"
    module_branch="$(trim "${module_branch:-}")"

    [[ -z "$module_name" ]] && continue
    [[ "$module_name" =~ ^# ]] && continue

    if [[ -z "$module_url" || -z "$module_branch" ]]; then
      echo "Invalid modules.txt line for module '$module_name'. Expected:"
      echo "module-name|git-url|branch"
      exit 1
    fi

    MODULES+=("$module_name|$module_url|$module_branch")
  done < "$SCRIPT_DIR/modules.txt"

  if [[ "${#MODULES[@]}" -eq 0 ]]; then
    echo "No modules found in modules.txt"
    exit 1
  fi
}

check_prereqs() {
  log "Checking prerequisites"

  for cmd in git cmake make rsync ssh; do
    require_cmd "$cmd"
  done

  if [[ ! -f "$SCRIPT_DIR/modules.txt" ]]; then
    echo "Missing modules.txt"
    exit 1
  fi

  load_modules
}

check_remote() {
  log "Checking SSH access to remote server"
  remote "echo Connected to \$(hostname) as \$(whoami)"
}

validate_local_modules() {
  log "Validating local modules"

  if [[ ! -d "$SOURCE_DIR/modules" ]]; then
    echo "Missing local modules directory: $SOURCE_DIR/modules"
    echo "Run: ./build-and-deploy.sh sync-source"
    exit 1
  fi

  for module in "${MODULES[@]}"; do
    IFS='|' read -r module_name module_url module_branch <<< "$module"

    module_dir="$SOURCE_DIR/modules/$module_name"

    if [[ ! -d "$module_dir" ]]; then
      echo "Expected module is missing locally: $module_name"
      echo "Missing path: $module_dir"
      echo "Run: ./build-and-deploy.sh sync-source"
      exit 1
    fi

    if [[ ! -d "$module_dir/.git" ]]; then
      echo "Warning: module directory exists but is not a git repo: $module_dir"
    fi

    echo "OK: $module_name"
  done
}

sync_source() {
  log "Preparing local directories"

  mkdir -p "$WORK_ROOT"
  mkdir -p "$STAGING_DIR"

  log "Cloning/updating AzerothCore source"

  if [[ ! -d "$SOURCE_DIR/.git" ]]; then
    run git clone "$AC_REPO" --branch "$AC_BRANCH" "$SOURCE_DIR"
  else
    cd "$SOURCE_DIR"
    run git fetch origin
    run git checkout "$AC_BRANCH"
    run git pull --ff-only origin "$AC_BRANCH"
  fi

  log "Cloning/updating modules"

  mkdir -p "$SOURCE_DIR/modules"

  for module in "${MODULES[@]}"; do
    IFS='|' read -r module_name module_url module_branch <<< "$module"

    module_dir="$SOURCE_DIR/modules/$module_name"

    echo
    echo "Module: $module_name"
    echo "Repo:   $module_url"
    echo "Branch: $module_branch"
    echo "Dir:    $module_dir"

    if [[ ! -d "$module_dir/.git" ]]; then
      run git clone "$module_url" --branch "$module_branch" "$module_dir"
    else
      cd "$module_dir"
      run git fetch origin
      run git checkout "$module_branch"
      run git pull --ff-only origin "$module_branch"
    fi
  done

  validate_local_modules
}

build_server() {
  validate_local_modules

  log "Cleaning build and staging directories"

  rm -rf "$BUILD_DIR"
  rm -rf "$STAGING_DIR"

  mkdir -p "$BUILD_DIR"
  mkdir -p "$STAGING_DIR"

  log "Configuring CMake"

  cd "$BUILD_DIR"

  cmake_args=(
    "../"
    "-DCMAKE_INSTALL_PREFIX=$REMOTE_INSTALL_DIR"
    "-DTOOLS=1"
    "-DSCRIPTS=$SCRIPTS_MODE"
    "-DMODULES=$MODULES_MODE"
    "-DCMAKE_BUILD_TYPE=$BUILD_TYPE"
    "-DCMAKE_C_STANDARD=17"
    "-DCMAKE_C_EXTENSIONS=ON"
    "-DCMAKE_C_FLAGS=-std=gnu17"
  )

  if [[ -n "${C_COMPILER:-}" ]]; then
    cmake_args+=("-DCMAKE_C_COMPILER=$C_COMPILER")
  fi

  if [[ -n "${CXX_COMPILER:-}" ]]; then
    cmake_args+=("-DCMAKE_CXX_COMPILER=$CXX_COMPILER")
  fi

  run cmake "${cmake_args[@]}"

  log "Building AzerothCore"

  run make -j"$BUILD_THREADS"

  log "Installing into local staging directory"

  run make install "DESTDIR=$STAGING_DIR"

  validate_staged_build
}

validate_staged_build() {
  STAGED_SERVER_DIR="$STAGING_DIR$REMOTE_INSTALL_DIR"

  if [[ ! -x "$STAGED_SERVER_DIR/bin/authserver" ]]; then
    echo "authserver was not found in staged install: $STAGED_SERVER_DIR/bin/authserver"
    exit 1
  fi

  if [[ ! -x "$STAGED_SERVER_DIR/bin/worldserver" ]]; then
    echo "worldserver was not found in staged install: $STAGED_SERVER_DIR/bin/worldserver"
    exit 1
  fi
}

prepare_remote_dirs() {
  log "Preparing remote directories"

  remote_tty "sudo mkdir -p '$REMOTE_SERVER_ROOT' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' '$REMOTE_SERVER_ROOT/backups'"

  if remote "getent group acore >/dev/null"; then
    remote_tty "sudo chown -R '$REMOTE_USER':acore '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' '$REMOTE_SERVER_ROOT/backups'"
    remote_tty "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type d -exec chmod 775 {} \;"
    remote_tty "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type f -exec chmod 664 {} \; 2>/dev/null || true"
  else
    remote_tty "sudo chown -R '$REMOTE_USER':'$REMOTE_USER' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' '$REMOTE_SERVER_ROOT/backups'"
  fi
}

backup_remote_etc() {
  if [[ "$BACKUP_REMOTE_ETC" == "true" ]]; then
    log "Backing up remote etc directory, including module configs"

    remote "
      mkdir -p '$REMOTE_SERVER_ROOT/backups'
      if [ -d '$REMOTE_INSTALL_DIR/etc' ]; then
        ts=\$(date +%Y%m%d-%H%M%S)
        tar -czf '$REMOTE_SERVER_ROOT/backups/etc-'\$ts'.tar.gz' -C '$REMOTE_INSTALL_DIR' etc
        echo 'Created backup: $REMOTE_SERVER_ROOT/backups/etc-'\$ts'.tar.gz'
      else
        echo 'No existing etc directory to back up.'
      fi
    "
  fi
}

stop_services() {
  if [[ "$STOP_SERVICES_BEFORE_DEPLOY" == "true" ]]; then
    log "Stopping remote services"
    remote_tty "sudo systemctl stop '$WORLD_SERVICE' 2>/dev/null || true"
    remote_tty "sudo systemctl stop '$AUTH_SERVICE' 2>/dev/null || true"
  fi
}

deploy_server() {
  validate_staged_build
  validate_local_modules
  prepare_remote_dirs
  backup_remote_etc
  stop_services

  STAGED_SERVER_DIR="$STAGING_DIR$REMOTE_INSTALL_DIR"

  log "Deploying staged server to remote, excluding runtime configs"

  run rsync -avh --progress --delete \
    --exclude='/etc/***' \
    "$STAGED_SERVER_DIR/" \
    "$REMOTE_HOST:$REMOTE_INSTALL_DIR/"

  log "Deploying config templates only"

  if [[ -d "$STAGED_SERVER_DIR/etc" ]]; then
    remote "mkdir -p '$REMOTE_INSTALL_DIR/etc'"

    run rsync -avh --progress \
      --include='*/' \
      --include='*.conf.dist' \
      --exclude='*' \
      "$STAGED_SERVER_DIR/etc/" \
      "$REMOTE_HOST:$REMOTE_INSTALL_DIR/etc/"
  fi

  deploy_source_sql
  fix_remote_permissions

  if [[ "$START_SERVICES_AFTER_DEPLOY" == "true" ]]; then
    restart_services
  else
    log "Skipping service start because START_SERVICES_AFTER_DEPLOY=false"
  fi

  log "Deploy complete"
}

deploy_source_sql() {
  validate_local_modules

  log "Deploying AzerothCore SQL source tree to remote"

  remote "mkdir -p '$REMOTE_SOURCE_DIR/data' '$REMOTE_SOURCE_DIR/modules'"

  run rsync -avh --delete \
    "$SOURCE_DIR/data/sql/" \
    "$REMOTE_HOST:$REMOTE_SOURCE_DIR/data/sql/"

  log "Deploying module source trees to remote"

  for module in "${MODULES[@]}"; do
    IFS='|' read -r module_name module_url module_branch <<< "$module"

    module_dir="$SOURCE_DIR/modules/$module_name"
    remote_module_dir="$REMOTE_SOURCE_DIR/modules/$module_name"

    if [[ ! -d "$module_dir" ]]; then
      echo "Missing module directory: $module_dir"
      echo "Run: ./build-and-deploy.sh sync-source"
      exit 1
    fi

    echo
    echo "Deploying module source: $module_name"
    echo "From: $module_dir"
    echo "To:   $REMOTE_HOST:$remote_module_dir"

    remote "mkdir -p '$remote_module_dir'"

    run rsync -avh --delete \
      --exclude='.git/' \
      --exclude='build/' \
      "$module_dir/" \
      "$REMOTE_HOST:$remote_module_dir/"
  done

  log "Checking deployed module SQL files"

  remote "
    echo
    echo 'Deployed module directories:'
    find '$REMOTE_SOURCE_DIR/modules' -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort

    echo
    echo 'Module SQL files deployed:'
    find '$REMOTE_SOURCE_DIR/modules' -type f -name '*.sql' | sort
  "
}

fix_remote_permissions() {
  log "Fixing remote ownership and permissions"

  if remote "getent group acore >/dev/null"; then
    remote_tty "sudo chown -R '$REMOTE_USER':acore '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR'"
    remote_tty "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type d -exec chmod 775 {} \;"
    remote_tty "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type f -exec chmod 664 {} \;"
    remote_tty "sudo chmod +x '$REMOTE_INSTALL_DIR/bin/authserver' '$REMOTE_INSTALL_DIR/bin/worldserver'"

    if remote "[ -d '$REMOTE_INSTALL_DIR/etc' ]"; then
      remote_tty "sudo chown -R '$REMOTE_USER':acore '$REMOTE_INSTALL_DIR/etc'"
      remote_tty "sudo find '$REMOTE_INSTALL_DIR/etc' -type d -exec chmod 775 {} \;"
      remote_tty "sudo find '$REMOTE_INSTALL_DIR/etc' -type f -exec chmod 664 {} \;"
    fi
  else
    remote_tty "sudo chown -R '$REMOTE_USER':'$REMOTE_USER' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR'"
    remote_tty "sudo chmod +x '$REMOTE_INSTALL_DIR/bin/authserver' '$REMOTE_INSTALL_DIR/bin/worldserver'"
  fi

  log "Checking available config templates and real configs"

  remote "
    echo
    echo 'Available config templates:'
    find '$REMOTE_INSTALL_DIR/etc' -type f -name '*.conf.dist' | sort

    echo
    echo 'Existing real configs:'
    find '$REMOTE_INSTALL_DIR/etc' -type f -name '*.conf' | sort
  "
}

restart_services() {
  log "Restarting remote services"

  remote_tty "sudo systemctl restart '$AUTH_SERVICE'"
  remote_tty "sudo systemctl restart '$WORLD_SERVICE'"

  remote "sudo systemctl --no-pager status '$AUTH_SERVICE' || true"
  remote "sudo systemctl --no-pager status '$WORLD_SERVICE' || true"
}

status_services() {
  log "Remote service status"

  remote "sudo systemctl --no-pager status '$AUTH_SERVICE' || true"
  remote "sudo systemctl --no-pager status '$WORLD_SERVICE' || true"
}

logs_world() {
  log "Worldserver logs"

  ssh -t "$REMOTE_HOST" "journalctl -u '$WORLD_SERVICE' -f"
}

logs_auth() {
  log "Authserver logs"

  ssh -t "$REMOTE_HOST" "journalctl -u '$AUTH_SERVICE' -f"
}

usage() {
  cat <<EOF
Usage:
  ./build-and-deploy.sh <command>

Commands:
  all             Sync source, build, deploy
  sync-source     Clone/update AzerothCore and modules only
  build           Build and stage locally only
  deploy          Deploy existing staged build only
  sql             Deploy SQL/source trees only
  restart         Restart auth and world services
  status          Show auth and world service status
  logs            Follow worldserver logs
  logs-auth       Follow authserver logs
  check           Check local prerequisites and remote SSH

Examples:
  ./build-and-deploy.sh all
  ./build-and-deploy.sh sync-source
  ./build-and-deploy.sh sql
  ./build-and-deploy.sh deploy
  ./build-and-deploy.sh restart
  ./build-and-deploy.sh logs
EOF
}

case "$COMMAND" in
  all)
    check_prereqs
    check_remote
    sync_source
    build_server
    deploy_server
    ;;

  sync-source)
    check_prereqs
    sync_source
    ;;

  build)
    check_prereqs
    build_server
    ;;

  deploy)
    check_prereqs
    check_remote
    deploy_server
    ;;

  sql)
    check_prereqs
    check_remote
    deploy_source_sql
    fix_remote_permissions
    ;;

  restart)
    check_remote
    restart_services
    ;;

  status)
    check_remote
    status_services
    ;;

  logs)
    check_remote
    logs_world
    ;;

  logs-auth)
    check_remote
    logs_auth
    ;;

  check)
    check_prereqs
    check_remote
    ;;

  help|-h|--help)
    usage
    ;;

  *)
    echo "Unknown command: $COMMAND"
    echo
    usage
    exit 1
    ;;
esac

log "Done"

echo "Command completed: $COMMAND"