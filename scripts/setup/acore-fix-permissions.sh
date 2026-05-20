#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

changed=0

make_executable() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    return
  fi

  if [[ -x "$path" ]]; then
    echo "OK: executable: $path"
  else
    chmod +x "$path"
    echo "Fixed: added executable permission: $path"
    changed=$((changed + 1))
  fi
}

while IFS= read -r script_path; do
  make_executable "$script_path"
done < <(find "$REPO_ROOT/scripts" -type f -name '*.sh' | sort)

make_executable "$REPO_ROOT/bin/acore-manager"

echo
if [[ "$changed" -eq 0 ]]; then
  echo "No permission changes needed."
else
  echo "Updated executable permissions on $changed file(s)."
fi
