#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -f "$SCRIPT_DIR/config.env" ]]; then
  echo "Missing config.env"
  exit 1
fi

# shellcheck disable=SC1091
source "$SCRIPT_DIR/config.env"

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

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1"
    exit 1
  fi
}

remote() {
  ssh "$REMOTE_HOST" "$@"
}

log "Checking prerequisites"

for cmd in git cmake make rsync ssh; do
  require_cmd "$cmd"
done

log "Checking SSH access to remote server"

remote "echo Connected to \$(hostname) as \$(whoami)"

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

while IFS='|' read -r module_name module_url module_branch; do
  # skip blank lines and comments
  [[ -z "${module_name// }" ]] && continue
  [[ "$module_name" =~ ^# ]] && continue

  module_dir="$SOURCE_DIR/modules/$module_name"

  echo
  echo "Module: $module_name"
  echo "Repo:   $module_url"
  echo "Branch: $module_branch"

  if [[ ! -d "$module_dir/.git" ]]; then
    run git clone "$module_url" --branch "$module_branch" "$module_dir"
  else
    cd "$module_dir"
    run git fetch origin
    run git checkout "$module_branch"
    run git pull --ff-only origin "$module_branch"
  fi
done < "$SCRIPT_DIR/modules.txt"

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

STAGED_SERVER_DIR="$STAGING_DIR$REMOTE_INSTALL_DIR"

if [[ ! -x "$STAGED_SERVER_DIR/bin/authserver" ]]; then
  echo "authserver was not found in staged install: $STAGED_SERVER_DIR/bin/authserver"
  exit 1
fi

if [[ ! -x "$STAGED_SERVER_DIR/bin/worldserver" ]]; then
  echo "worldserver was not found in staged install: $STAGED_SERVER_DIR/bin/worldserver"
  exit 1
fi

log "Preparing remote directories"

remote "mkdir -p '$REMOTE_SERVER_ROOT' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR'"

if [[ "$BACKUP_REMOTE_ETC" == "true" ]]; then
  log "Backing up remote etc directory"
  remote "mkdir -p '$REMOTE_SERVER_ROOT/backups' && if [ -d '$REMOTE_INSTALL_DIR/etc' ]; then tar -czf '$REMOTE_SERVER_ROOT/backups/etc-\$(date +%Y%m%d-%H%M%S).tar.gz' -C '$REMOTE_INSTALL_DIR' etc; fi"
fi

if [[ "$STOP_SERVICES_BEFORE_DEPLOY" == "true" ]]; then
  log "Stopping remote services"
  remote "sudo systemctl stop '$WORLD_SERVICE' 2>/dev/null || true"
  remote "sudo systemctl stop '$AUTH_SERVICE' 2>/dev/null || true"
fi

if [[ "$PRESERVE_REMOTE_CONFIGS" == "true" ]]; then
  log "Temporarily preserving remote configs"
  remote "rm -rf /tmp/azerothcore-etc-preserve && if [ -d '$REMOTE_INSTALL_DIR/etc' ]; then cp -a '$REMOTE_INSTALL_DIR/etc' /tmp/azerothcore-etc-preserve; fi"
fi

log "Deploying staged server to remote"

run rsync -avh --progress --delete \
  "$STAGED_SERVER_DIR/" \
  "$REMOTE_HOST:$REMOTE_INSTALL_DIR/"

if [[ "$PRESERVE_REMOTE_CONFIGS" == "true" ]]; then
  log "Restoring preserved remote configs"
  remote "if [ -d /tmp/azerothcore-etc-preserve ]; then cp -a /tmp/azerothcore-etc-preserve/. '$REMOTE_INSTALL_DIR/etc/'; rm -rf /tmp/azerothcore-etc-preserve; fi"
fi

log "Deploying SQL source tree to remote"

remote "mkdir -p '$REMOTE_SOURCE_DIR/data' '$REMOTE_SOURCE_DIR/modules'"

run rsync -avh --delete \
  "$SOURCE_DIR/data/sql/" \
  "$REMOTE_HOST:$REMOTE_SOURCE_DIR/data/sql/"

while IFS='|' read -r module_name module_url module_branch; do
  [[ -z "${module_name// }" ]] && continue
  [[ "$module_name" =~ ^# ]] && continue

  if [[ -d "$SOURCE_DIR/modules/$module_name/sql" ]]; then
    remote "mkdir -p '$REMOTE_SOURCE_DIR/modules/$module_name/sql'"
    run rsync -avh --delete \
      "$SOURCE_DIR/modules/$module_name/sql/" \
      "$REMOTE_HOST:$REMOTE_SOURCE_DIR/modules/$module_name/sql/"
  fi
done < "$SCRIPT_DIR/modules.txt"

log "Fixing remote ownership and permissions"

remote "sudo chown -R acore:acore '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' || sudo chown -R adam:adam '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR'"
remote "sudo chmod +x '$REMOTE_INSTALL_DIR/bin/authserver' '$REMOTE_INSTALL_DIR/bin/worldserver'"

# Make configs easy for adam to edit if acore group exists.
remote "if getent group acore >/dev/null; then sudo chown -R adam:acore '$REMOTE_INSTALL_DIR/etc'; sudo find '$REMOTE_INSTALL_DIR/etc' -type d -exec chmod 775 {} \; ; sudo find '$REMOTE_INSTALL_DIR/etc' -type f -exec chmod 664 {} \; ; fi"

if [[ "$START_SERVICES_AFTER_DEPLOY" == "true" ]]; then
  log "Starting remote services"
  remote "sudo systemctl start '$AUTH_SERVICE'"
  remote "sudo systemctl start '$WORLD_SERVICE'"
  remote "sudo systemctl --no-pager status '$AUTH_SERVICE' || true"
  remote "sudo systemctl --no-pager status '$WORLD_SERVICE' || true"
else
  log "Skipping service start because START_SERVICES_AFTER_DEPLOY=false"
fi

log "Done"

echo "Deployed build to: $REMOTE_HOST:$REMOTE_INSTALL_DIR"
echo
echo "Next manual checks:"
echo "  ssh $REMOTE_HOST"
echo "  cd $REMOTE_INSTALL_DIR/bin"
echo "  ./authserver"
echo "  ./worldserver"
echo
echo "Or start services manually:"
echo "  sudo systemctl start $AUTH_SERVICE"
echo "  sudo systemctl start $WORLD_SERVICE"