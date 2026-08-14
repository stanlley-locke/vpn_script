#!/bin/bash
# One-shot EC2 bootstrap for vps.stanlleylocke.dev
# Run on fresh Ubuntu EC2 as root:
#   curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/scripts/ec2-install.sh | bash
#
# Or from cloned repo:
#   bash scripts/ec2-install.sh
set -euo pipefail

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main}"
ENV_DEST="/root/vpn_script.env"
ENV_EXAMPLE="${REPO}/examples/vps.stanlleylocke.dev.env"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo bash ec2-install.sh"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " VPN Script EC2 Install — vps.stanlleylocke.dev"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Clean broken HAProxy PPA from prior attempts
rm -f /etc/apt/sources.list.d/*vbernat* /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
add-apt-repository --remove -y ppa:vbernat/haproxy-2.0 2>/dev/null || true

apt-get update -qq
apt-get install -y wget curl dnsutils jq software-properties-common

if [[ ! -f "$ENV_DEST" ]]; then
    echo "Downloading environment file..."
    wget -qO "$ENV_DEST" "$ENV_EXAMPLE"
    echo "Saved: $ENV_DEST"
    echo ""
    echo "Edit optional secrets before continuing:"
    echo "  nano $ENV_DEST   # CF_EMAIL, CF_API_KEY, TELEGRAM_*"
    echo ""
    read -rp "Press Enter to continue (or Ctrl+C to edit env first)..."
fi

set -a
# shellcheck source=/dev/null
source "$ENV_DEST"
set +a
export VPN_ENV_FILE="$ENV_DEST"

# Preflight
if wget -qO /tmp/preflight.sh "${REPO}/scripts/preflight.sh" 2>/dev/null; then
    chmod +x /tmp/preflight.sh
    /tmp/preflight.sh "${VPN_DOMAIN:-vps.stanlleylocke.dev}" || true
fi

echo ""
echo "Starting VPN Script install (domain: ${VPN_DOMAIN:-vps.stanlleylocke.dev})..."
echo ""

wget -qO /tmp/genz.sh "${REPO}/genz.sh"
chmod +x /tmp/genz.sh
exec /tmp/genz.sh
