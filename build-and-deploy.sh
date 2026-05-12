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

remote_sudo() {
  ssh "$REMOTE_HOST" "sudo bash -lc '$*'"
}

log "Checking prerequisites"

for cmd in git cmake make rsync ssh; do
  require_cmd "$cmd"
done

if [[ ! -f "$SCRIPT_DIR/modules.txt" ]]; then
  echo "Missing modules.txt"
  exit 1
fi

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

remote "sudo mkdir -p '$REMOTE_SERVER_ROOT' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' '$REMOTE_SERVER_ROOT/backups'"

# Make sure the SSH user can rsync into the target paths.
if remote "getent group acore >/dev/null"; then
  remote "sudo chown -R '$REMOTE_USER':acore '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' '$REMOTE_SERVER_ROOT/backups'"
  remote "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type d -exec chmod 775 {} \;"
  remote "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type f -exec chmod 664 {} \; 2>/dev/null || true"
else
  remote "sudo chown -R '$REMOTE_USER':'$REMOTE_USER' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' '$REMOTE_SERVER_ROOT/backups'"
fi

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

if [[ "$STOP_SERVICES_BEFORE_DEPLOY" == "true" ]]; then
  log "Stopping remote services"
  remote "sudo systemctl stop '$WORLD_SERVICE' 2>/dev/null || true"
  remote "sudo systemctl stop '$AUTH_SERVICE' 2>/dev/null || true"
fi

log "Deploying staged server to remote, excluding runtime configs"

# Important:
# We exclude /etc entirely here so rsync --delete can never remove real .conf files.
# Config templates are deployed in a separate step below.
run rsync -avh --progress --delete \
  --exclude='/etc/***' \
  "$STAGED_SERVER_DIR/" \
  "$REMOTE_HOST:$REMOTE_INSTALL_DIR/"

log "Deploying config templates only"

# This copies new/updated .conf.dist files, including module templates,
# but never touches real .conf files such as:
#   authserver.conf
#   worldserver.conf
#   modules/playerbots.conf
#   modules/individual_progression.conf
if [[ -d "$STAGED_SERVER_DIR/etc" ]]; then
  remote "mkdir -p '$REMOTE_INSTALL_DIR/etc'"

  run rsync -avh --progress \
    --include='*/' \
    --include='*.conf.dist' \
    --exclude='*' \
    "$STAGED_SERVER_DIR/etc/" \
    "$REMOTE_HOST:$REMOTE_INSTALL_DIR/etc/"
fi

log "Deploying AzerothCore SQL source tree to remote"

remote "mkdir -p '$REMOTE_SOURCE_DIR/data' '$REMOTE_SOURCE_DIR/modules'"

run rsync -avh --delete \
  "$SOURCE_DIR/data/sql/" \
  "$REMOTE_HOST:$REMOTE_SOURCE_DIR/data/sql/"

log "Deploying module source trees to remote"

while IFS='|' read -r module_name module_url module_branch; do
  [[ -z "${module_name// }" ]] && continue
  [[ "$module_name" =~ ^# ]] && continue

  module_dir="$SOURCE_DIR/modules/$module_name"
  remote_module_dir="$REMOTE_SOURCE_DIR/modules/$module_name"

  if [[ ! -d "$module_dir" ]]; then
    echo "Skipping missing module directory: $module_dir"
    continue
  fi

  echo
  echo "Deploying module source: $module_name"

  remote "mkdir -p '$remote_module_dir'"

  run rsync -avh --delete \
    --exclude='.git/' \
    --exclude='build/' \
    "$module_dir/" \
    "$REMOTE_HOST:$remote_module_dir/"
done < "$SCRIPT_DIR/modules.txt"

log "Checking deployed module SQL files"

remote "
  echo
  echo 'Module SQL files deployed:'
  find '$REMOTE_SOURCE_DIR/modules' -type f -name '*.sql' | sort
"

log "Fixing remote ownership and permissions"

if remote "getent group acore >/dev/null"; then
  # Keep adam able to edit configs, while acore can read them.
  remote "sudo chown -R '$REMOTE_USER':acore '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR'"
  remote "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type d -exec chmod 775 {} \;"
  remote "sudo find '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR' -type f -exec chmod 664 {} \;"
  remote "sudo chmod +x '$REMOTE_INSTALL_DIR/bin/authserver' '$REMOTE_INSTALL_DIR/bin/worldserver'"

  # Configs remain editable by adam.
  remote "sudo chown -R '$REMOTE_USER':acore '$REMOTE_INSTALL_DIR/etc'"
  remote "sudo find '$REMOTE_INSTALL_DIR/etc' -type d -exec chmod 775 {} \;"
  remote "sudo find '$REMOTE_INSTALL_DIR/etc' -type f -exec chmod 664 {} \;"
else
  remote "sudo chown -R '$REMOTE_USER':'$REMOTE_USER' '$REMOTE_INSTALL_DIR' '$REMOTE_SOURCE_DIR'"
  remote "sudo chmod +x '$REMOTE_INSTALL_DIR/bin/authserver' '$REMOTE_INSTALL_DIR/bin/worldserver'"
fi

log "Checking for new module config templates"

remote "
  echo
  echo 'Available config templates:'
  find '$REMOTE_INSTALL_DIR/etc' -type f -name '*.conf.dist' | sort
  echo
  echo 'Existing real configs:'
  find '$REMOTE_INSTALL_DIR/etc' -type f -name '*.conf' | sort
"

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
echo "Important:"
echo "  Runtime configs are preserved and are never deleted by rsync."
echo "  New module .conf.dist templates are copied across."
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