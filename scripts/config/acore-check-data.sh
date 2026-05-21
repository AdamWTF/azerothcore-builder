#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

errors=0

log "Checking AzerothCore data files"
echo "Data directory: $DATADIR"
echo "acore-manager does not download client data. Provide extracted 3.3.5a data yourself."

if [[ ! -d "$DATADIR" ]]; then
  echo "WARN: DATADIR does not exist: $DATADIR"
fi

for name in dbc maps vmaps mmaps; do
  if [[ -d "$DATADIR/$name" ]]; then
    echo "OK: found $DATADIR/$name"
  else
    echo "WARN: missing required data directory: $DATADIR/$name"
    errors=$((errors + 1))
  fi
done

world_conf="$CONFIG_DIR/worldserver.conf"
if [[ -f "$world_conf" ]]; then
  configured_datadir="$(awk -F= '
    /^[[:space:]]*DataDir[[:space:]]*=/ {
      value = $2
      sub(/^[[:space:]]*/, "", value)
      sub(/[[:space:]]*(#.*)?$/, "", value)
      gsub(/^"|"$/, "", value)
      print value
      exit
    }
  ' "$world_conf")"

  if [[ -z "$configured_datadir" ]]; then
    echo "WARN: DataDir is not set in $world_conf"
  elif [[ "$configured_datadir" == "$DATADIR" ]]; then
    echo "OK: worldserver.conf DataDir points to $DATADIR"
  else
    echo "WARN: worldserver.conf DataDir is '$configured_datadir', expected '$DATADIR'"
  fi
else
  echo "WARN: worldserver.conf is missing: $world_conf"
fi

if [[ "$errors" -gt 0 ]]; then
  echo
  echo "Data check completed with warning(s). Copy dbc, maps, vmaps, and mmaps into $DATADIR before starting worldserver."
else
  echo
  echo "Data check completed."
fi
