#!/bin/bash
# One-shot EC2 bootstrap for vps.stanlleylocke.dev
# SAFE install — download first, use wget (curl may segfault on Ubuntu 26.04)
#
#   wget -qO /tmp/ec2-install.sh https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/scripts/ec2-install.sh
#   bash /tmp/ec2-install.sh
set -e

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main}"
ENV_DEST="/root/vpn_script.env"
ENV_EXAMPLE="${REPO}/examples/vps.stanlleylocke.dev.env"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo bash ec2-install.sh"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " VPN Script EC2 Install — vps.stanlleylocke.dev"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# PPA cleanup — file removal only (add-apt-repository can segfault)
rm -f /etc/apt/sources.list.d/*vbernat* /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
sed -i '/vbernat\/haproxy/d' /etc/apt/sources.list 2>/dev/null || true

apt-get update -qq || apt-get update -y
apt-get install -y wget ca-certificates dnsutils || true

if [[ ! -f "$ENV_DEST" ]]; then
    echo "Downloading environment file..."
    wget -qO "$ENV_DEST" "$ENV_EXAMPLE" || { echo "Download failed"; exit 1; }
    echo "Saved: $ENV_DEST"
    echo ""
    echo "Optional: nano $ENV_DEST   # CF_EMAIL, TELEGRAM_*"
    echo ""
    read -rp "Press Enter to continue (Ctrl+C to edit env first)..."
fi

set -a
# shellcheck source=/dev/null
source "$ENV_DEST"
set +a
export VPN_ENV_FILE="$ENV_DEST"

echo ""
echo "Starting install (domain: ${VPN_DOMAIN:-vps.stanlleylocke.dev})..."
echo ""

wget -qO /tmp/genz.sh "${REPO}/genz.sh" || { echo "Failed to download genz.sh"; exit 1; }
chmod +x /tmp/genz.sh
exec bash /tmp/genz.sh
