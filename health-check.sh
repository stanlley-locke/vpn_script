#!/bin/bash
# Service health check — stanlley_locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

check_service() {
    local name="$1"
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        echo -e "${GREEN}●${NC} $name"
        return 0
    fi
    echo -e "${RED}●${NC} $name (not running)"
    return 1
}

check_port() {
    local port="$1"
    local label="$2"
    if ss -tln | awk '{print $4}' | grep -q ":${port}$"; then
        echo -e "${GREEN}●${NC} port ${port} (${label})"
        return 0
    fi
    echo -e "${YELLOW}○${NC} port ${port} (${label}) — not listening"
    return 1
}

echo ""
echo -e "${YELLOW}VPN Script Health Check — ${VPN_AUTHOR:-stanlley_locke}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Services:"
failed=0
for svc in xray nginx haproxy cron fail2ban; do
    check_service "$svc" || ((failed++)) || true
done
if systemctl list-unit-files kyt.service &>/dev/null; then
    check_service kyt || true
fi
echo ""
echo "Ports:"
check_port 443 "HAProxy/TLS" || true
check_port 80 "HTTP" || true
check_port 8880 "SSH non-TLS" || true
echo ""
if [[ -f /etc/xray/domain ]]; then
    domain=$(cat /etc/xray/domain)
    echo "Domain: ${domain}"
    ip=$(vpn_get_public_ip 2>/dev/null || curl -4 -sS ipv4.icanhazip.com)
    echo "Public IP: ${ip}"
fi
echo ""
if [[ $failed -gt 0 ]]; then
    echo -e "${RED}Some core services are down. Run: restart${NC}"
    exit 1
fi
echo -e "${GREEN}Core services OK${NC}"
