#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/common.sh"

DEB_URL="https://github.com/OliveTin/OliveTin/releases/latest/download/OliveTin_linux_amd64.deb"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  die "installing OliveTin requires root: sudo $0"
fi

arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"
case "$arch" in
  amd64|x86_64)
    ;;
  *)
    die "unsupported architecture for this installer: $arch (expected amd64/x86_64)"
    ;;
esac

command -v apt-get >/dev/null 2>&1 || die "apt-get is required"

log "Installing OliveTin prerequisites"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y curl ca-certificates

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

deb_file="$tmp_dir/OliveTin_linux_amd64.deb"

log "Downloading OliveTin"
curl -fsSL "$DEB_URL" -o "$deb_file"

log "Installing OliveTin package"
DEBIAN_FRONTEND=noninteractive apt-get install -y "$deb_file"

log "Rendering acore-manager OliveTin config"
"$ACM_REPO_ROOT/scripts/integrations/acore-render-olivetin-config.sh"

log "Enabling OliveTin"
systemctl enable --now OliveTin

echo
systemctl status OliveTin --no-pager || true

cat <<EOF

OliveTin installation complete.

Access hint:
  http://SERVER-IP:1337

Keep OliveTin LAN/VPN-only. This installer did not open firewall ports.
EOF
