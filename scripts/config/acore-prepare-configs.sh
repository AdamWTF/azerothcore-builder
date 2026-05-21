#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

usage() {
  cat <<EOF
Usage:
  $0 [release-name]

Seeds shared runtime configs from release config templates without overwriting
existing shared configs.
EOF
}

release_name="${1:-}"
case "$release_name" in
  -h|--help)
    usage
    exit 0
    ;;
esac

find_template_root() {
  local candidate=""

  if [[ -n "$release_name" ]]; then
    candidate="$RELEASES_DIR/$release_name"
    [[ -d "$candidate" ]] || die "release does not exist: $candidate"
  elif [[ -L "$CURRENT_LINK" ]]; then
    candidate="$(readlink -f "$CURRENT_LINK")"
  else
    candidate="$(find "$RELEASES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort | tail -n 1 || true)"
    [[ -n "$candidate" ]] && candidate="$RELEASES_DIR/$candidate"
  fi

  if [[ -n "$candidate" && -d "$candidate/etc.dist" ]]; then
    printf '%s\n' "$candidate/etc.dist"
  elif [[ -n "$candidate" && -d "$candidate/etc" ]]; then
    printf '%s\n' "$candidate/etc"
  elif [[ -d "$BUILD_DIR/staging/etc" ]]; then
    printf '%s\n' "$BUILD_DIR/staging/etc"
  else
    return 1
  fi
}

copy_if_missing() {
  local source_file="$1"
  local dest_file="$2"

  if [[ ! -f "$source_file" ]]; then
    echo "WARN: template missing: $source_file"
    return
  fi

  if [[ -e "$dest_file" ]]; then
    echo "Skipping existing shared config: $dest_file"
    return
  fi

  install -m 0640 "$source_file" "$dest_file"
  echo "Created shared config: $dest_file"
}

log "Preparing shared configs"

template_root="$(find_template_root)" || die "no config templates found; create a release first or keep staging output at $BUILD_DIR/staging"
echo "Template source: $template_root"

mkdir -p "$CONFIG_DIR" "$MODULE_CONFIG_DIR"

copy_if_missing "$template_root/authserver.conf.dist" "$CONFIG_DIR/authserver.conf"
if [[ ! -e "$CONFIG_DIR/authserver.conf" && -f "$template_root/authserver.conf" ]]; then
  copy_if_missing "$template_root/authserver.conf" "$CONFIG_DIR/authserver.conf"
fi

copy_if_missing "$template_root/worldserver.conf.dist" "$CONFIG_DIR/worldserver.conf"
if [[ ! -e "$CONFIG_DIR/worldserver.conf" && -f "$template_root/worldserver.conf" ]]; then
  copy_if_missing "$template_root/worldserver.conf" "$CONFIG_DIR/worldserver.conf"
fi

if [[ -d "$template_root/modules" ]]; then
  while IFS= read -r module_conf; do
    module_name="$(basename "$module_conf")"
    module_name="${module_name%.dist}"
    copy_if_missing "$module_conf" "$MODULE_CONFIG_DIR/$module_name"
  done < <(find "$template_root/modules" -type f \( -name '*.conf' -o -name '*.conf.dist' \) | sort)
else
  echo "WARN: no module config template directory found: $template_root/modules"
fi

if command -v chown >/dev/null 2>&1; then
  chown -R "$ACORE_USER:$ACORE_GROUP" "$CONFIG_DIR" || echo "WARN: failed to set ownership on $CONFIG_DIR"
fi

echo
echo "Shared config preparation complete."
echo "Shared config directory: $CONFIG_DIR"
echo "Module config directory: $MODULE_CONFIG_DIR"
echo "Existing configs were left unchanged."
