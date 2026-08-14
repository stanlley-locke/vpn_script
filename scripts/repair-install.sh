#!/bin/bash
# Repair half-failed install on Ubuntu 26.04 — stanlley-locke/vpn_script
# wget -qO /tmp/repair.sh .../repair-install.sh && bash /tmp/repair.sh
set -e

export DEBIAN_FRONTEND=noninteractive

echo "Removing broken HAProxy PPA (file cleanup only)..."
rm -f /etc/apt/sources.list.d/*vbernat* /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
sed -i '/vbernat\/haproxy/d' /etc/apt/sources.list 2>/dev/null || true

apt-get update -y
apt-get install -y haproxy netcat-openbsd chrony dnsutils wget ca-certificates || true

mkdir -p /etc/haproxy /etc/xray /etc/vpn_script /usr/local/lib/vpn_script

if [[ -f /root/vpn_script.env ]]; then
    set -a && source /root/vpn_script.env && set +a
    [[ -n "${VPN_DOMAIN:-}" ]] && echo "$VPN_DOMAIN" > /etc/xray/domain
fi

echo ""
echo "Repair complete. Re-run install:"
echo "  wget -qO /tmp/ec2-install.sh https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/scripts/ec2-install.sh"
echo "  bash /tmp/ec2-install.sh"
