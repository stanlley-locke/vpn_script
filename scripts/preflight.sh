#!/bin/bash
# Pre-install checks — stanlley-locke/vpn_script
# Usage: preflight [domain]
set -euo pipefail

DOMAIN="${1:-${VPN_DOMAIN:-}}"
IP_EXPECT="${VPS_PUBLIC_IP:-}"

RED='\033[0;31m'; GRN='\033[0;32m'; YEL='\033[0;33m'; NC='\033[0m'
ok=0; warn=0; fail=0

_pass() { echo -e "${GRN}[OK]${NC} $1"; ((ok++)) || true; }
_warn() { echo -e "${YEL}[WARN]${NC} $1"; ((warn++)) || true; }
_fail() { echo -e "${RED}[FAIL]${NC} $1"; ((fail++)) || true; }

echo "VPN Script preflight"
echo "======================"

[[ "${EUID}" -eq 0 ]] && _pass "Running as root" || _fail "Must run as root (sudo -i)"

arch=$(uname -m)
[[ "$arch" == "x86_64" ]] && _pass "Architecture: $arch" || _fail "Need x86_64, got $arch"

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    case "${ID:-}" in ubuntu|debian) _pass "OS: ${PRETTY_NAME:-$ID}" ;; *) _warn "Untested OS: ${PRETTY_NAME:-unknown}" ;; esac
fi

virt=$(systemd-detect-virt 2>/dev/null || echo unknown)
[[ "$virt" != "openvz" ]] && _pass "Virtualization: $virt" || _fail "OpenVZ not supported"

MYIP=$(curl -4 -sS --max-time 8 ipv4.icanhazip.com 2>/dev/null || echo "")
[[ -n "$MYIP" ]] && _pass "Public IP detected: $MYIP" || _fail "Cannot detect public IP"

if [[ -n "$IP_EXPECT" && -n "$MYIP" && "$MYIP" != "$IP_EXPECT" ]]; then
    _warn "Env VPS_PUBLIC_IP=$IP_EXPECT but detected $MYIP (Elastic IP reassigned?)"
fi

if [[ -n "$DOMAIN" ]]; then
    resolved=$(dig +short "$DOMAIN" 2>/dev/null | tail -1)
    if [[ -z "$resolved" ]]; then
        _fail "DNS: $DOMAIN has no A record"
    elif [[ -n "$MYIP" && "$resolved" == "$MYIP" ]]; then
        _pass "DNS: $DOMAIN → $resolved (matches VPS)"
    else
        _warn "DNS: $DOMAIN → $resolved (VPS is $MYIP) — OK if DNS only and propagating"
    fi
else
    _warn "No domain passed — set VPN_DOMAIN in /root/vpn_script.env"
fi

for port in 22 80 443; do
    if ss -tln | grep -q ":${port} "; then
        _warn "Port $port already in use (may be fine if reinstalling)"
    else
        _pass "Port $port available locally"
    fi
done

echo ""
echo "Summary: ${ok} passed, ${warn} warnings, ${fail} failed"
echo ""

if [[ "$fail" -gt 0 ]]; then
    echo "Fix failures before installing."
    exit 1
fi

echo "Ready to install. Next:"
echo "  set -a && source /root/vpn_script.env && set +a"
echo "  curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/install.sh | bash"
exit 0
