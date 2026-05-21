#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

CONFIG_FILE="${1:-$ACM_REPO_ROOT/olivetin/config.yaml.example}"

[[ -f "$CONFIG_FILE" ]] || die "OliveTin config not found: $CONFIG_FILE"
[[ -x "$ACM_REPO_ROOT/bin/acore-manager" ]] || die "CLI wrapper is not executable: $ACM_REPO_ROOT/bin/acore-manager"

supported_commands="$("$ACM_REPO_ROOT/bin/acore-manager" --help | awk '/^  [a-z0-9-]+[[:space:]]/ { print $1 }' | sort -u)"

errors=0
found=0

while IFS= read -r command_name; do
  found=$((found + 1))

  if printf '%s\n' "$supported_commands" | grep -qx "$command_name"; then
    echo "OK: OliveTin command exists: $command_name"
  else
    echo "ERROR: OliveTin command is not supported by bin/acore-manager: $command_name"
    errors=$((errors + 1))
  fi
done < <(
  sed -n 's/.*\/opt\/acore-manager\/bin\/acore-manager \([a-z0-9-][a-z0-9-]*\).*/\1/p' "$CONFIG_FILE" | sort -u
)

if [[ "$found" -eq 0 ]]; then
  die "no acore-manager commands found in $CONFIG_FILE"
fi

if [[ "$errors" -gt 0 ]]; then
  die "OliveTin config validation failed with $errors error(s)"
fi

echo
echo "OliveTin config references $found supported acore-manager command(s)."
