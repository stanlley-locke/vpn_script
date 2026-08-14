#!/bin/bash
# Service health check — stanlley-locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
failed=0

check_service() {
    local name="$1"
    if systemctl is-active --quiet "$name" 2>/dev/null; then
        echo -e "${GREEN}●${NC} $name"
    else
        echo -e "${RED}●${NC} $name (down)"; ((failed++)) || true
    fi
}

check_port() {
    local port="$1" label="$2"
    if ss -tln 2>/dev/null | awk '{print $4}' | grep -qE ":${port}$"; then
        echo -e "${GREEN}●${NC} :${port} ${label}"
    else
        echo -e "${YELLOW}○${NC} :${port} ${label}"
    fi
}

check_cert() {
    local cert="/etc/xray/xray.crt"
    [[ -f "$cert" ]] || { echo -e "${RED}●${NC} TLS cert missing"; ((failed++)); return; }
    local exp
    exp=$(openssl x509 -enddate -noout -in "$cert" 2>/dev/null | cut -d= -f2)
    echo -e "${GREEN}●${NC} TLS cert expires: ${exp}"
}

echo ""
echo -e "${YELLOW}VPN Script Health — ${VPN_AUTHOR:-stanlley-locke}${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Services:"
for s in xray nginx haproxy ws cron fail2ban; do check_service "$s"; done
systemctl is-enabled kyt &>/dev/null && check_service kyt
echo ""
echo "Ports:"
check_port 443 "HAProxy/TLS"
check_port 80 "HTTP"
check_port 8880 "SSH plain"
check_port 81 "Decoy TLS"
echo ""
check_cert
[[ -f /etc/xray/domain ]] && echo "Domain: $(cat /etc/xray/domain)"
[[ -f /etc/xray/routing.active ]] && echo "Routing: $(cat /etc/xray/routing.active)"
echo "IP: $(vpn_get_public_ip 2>/dev/null || echo unknown)"
echo ""
[[ $failed -eq 0 ]] && echo -e "${GREEN}Core checks passed${NC}" || echo -e "${RED}${failed} service(s) need attention — run: reload-stack${NC}"
