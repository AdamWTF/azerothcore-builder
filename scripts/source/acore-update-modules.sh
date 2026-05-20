#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

command -v git >/dev/null 2>&1 || die "git is not available"

[[ -d "$ACORE_SOURCE_DIR/.git" ]] || die "ACORE_SOURCE_DIR is not an AzerothCore git checkout: $ACORE_SOURCE_DIR"

MODULES_FILE="$ACM_REPO_ROOT/config/local/modules.txt"
if [[ ! -f "$MODULES_FILE" ]]; then
  MODULES_FILE="$ACM_REPO_ROOT/config/defaults/modules.txt.example"
fi

trim() {
  local value="$1"
  value="${value//$'\r'/}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

declare -a modules=()
declare -A listed_modules=()

log "Loading module list"
echo "Modules file: $MODULES_FILE"

while IFS='|' read -r module_name module_url module_branch || [[ -n "${module_name:-}" ]]; do
  module_name="$(trim "${module_name:-}")"
  module_url="$(trim "${module_url:-}")"
  module_branch="$(trim "${module_branch:-}")"

  [[ -z "$module_name" ]] && continue
  [[ "$module_name" =~ ^# ]] && continue

  if [[ -z "$module_url" || -z "$module_branch" ]]; then
    die "invalid module line for '$module_name'; expected module-name|git-url|branch"
  fi

  modules+=("$module_name|$module_url|$module_branch")
  listed_modules["$module_name"]=1
done < "$MODULES_FILE"

mkdir -p "$MODULES_DIR"

if [[ "${#modules[@]}" -eq 0 ]]; then
  echo "No modules configured."
fi

for module in "${modules[@]}"; do
  IFS='|' read -r module_name module_url module_branch <<< "$module"
  module_dir="$MODULES_DIR/$module_name"

  log "Updating module: $module_name"
  echo "Repo:   $module_url"
  echo "Branch: $module_branch"
  echo "Dir:    $module_dir"

  if [[ ! -d "$module_dir/.git" ]]; then
    if [[ -e "$module_dir" ]]; then
      die "module path exists but is not a git repository: $module_dir"
    fi

    git clone "$module_url" --branch "$module_branch" "$module_dir"
  else
    git -C "$module_dir" fetch origin
    git -C "$module_dir" checkout "$module_branch"
    git -C "$module_dir" pull --ff-only origin "$module_branch"
  fi

  echo "Commit: $(git -C "$module_dir" rev-parse HEAD)"
done

log "Checking for unlisted modules"
if [[ -d "$MODULES_DIR" ]]; then
  found_unlisted=false

  for module_dir in "$MODULES_DIR"/*; do
    [[ -d "$module_dir" ]] || continue
    module_name="$(basename "$module_dir")"

    if [[ -z "${listed_modules[$module_name]:-}" ]]; then
      echo "WARN: module directory is not listed and was left unchanged: $module_dir"
      found_unlisted=true
    fi
  done

  if [[ "$found_unlisted" == "false" ]]; then
    echo "No unlisted module directories found."
  fi
else
  echo "WARN: MODULES_DIR does not exist yet: $MODULES_DIR"
fi
