#!/bin/bash
# Repair half-failed install on Ubuntu 26.04 — stanlley-locke/vpn_script
# Run as root before re-running ec2-install.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "Removing broken HAProxy PPA..."
rm -f /etc/apt/sources.list.d/*vbernat* /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
add-apt-repository --remove -y ppa:vbernat/haproxy-2.0 2>/dev/null || true

apt-get update -y
apt-get install -y haproxy netcat-openbsd chrony jq dnsutils wget curl

mkdir -p /etc/haproxy /etc/xray /etc/vpn_script /usr/local/lib/vpn_script

if [[ -f /root/vpn_script.env ]]; then
    set -a && source /root/vpn_script.env && set +a
    [[ -n "${VPN_DOMAIN:-}" ]] && echo "$VPN_DOMAIN" > /etc/xray/domain
fi

echo "Repair complete. Re-run install:"
echo "  curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/scripts/ec2-install.sh | bash"
