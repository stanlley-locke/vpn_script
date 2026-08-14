#!/bin/bash
# Cloudflare full setup wizard — stanlley-locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
[ -f /usr/local/lib/vpn_script/cloudflare.sh ] && source /usr/local/lib/vpn_script/cloudflare.sh
vpn_load_config

apt-get install -y jq curl >/dev/null 2>&1 || apt install -y jq curl

MYIP=$(vpn_get_public_ip)
DOMAIN="${CF_DOMAIN:-$(cat /etc/xray/domain 2>/dev/null)}"

clear
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Cloudflare Setup — stanlley-locke/vpn_script"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Public IP: ${MYIP}"
echo "Domain   : ${DOMAIN}"
echo ""

if [[ -z "${CF_EMAIL}" || -z "${CF_API_KEY}" ]]; then
    read -rp "Cloudflare email: " CF_EMAIL
    read -rsp "Cloudflare Global API Key: " CF_API_KEY
    echo ""
fi

if ! cf_validate_credentials; then
    echo "ERROR: Invalid Cloudflare credentials"
    exit 1
fi
echo "✓ Credentials valid"

ROOT_DOMAIN="${DOMAIN#*.}"
[[ "$ROOT_DOMAIN" == "$DOMAIN" ]] && ROOT_DOMAIN="$DOMAIN"
ZONE_ID=$(cf_get_zone_id "$ROOT_DOMAIN")
if [[ -z "$ZONE_ID" ]]; then
    echo "ERROR: Zone not found for ${ROOT_DOMAIN}"
    exit 1
fi
echo "✓ Zone ID: ${ZONE_ID}"

echo ""
read -rp "Create/update A record ${DOMAIN} -> ${MYIP} (proxied)? [Y/n] " ans
if [[ "${ans,,}" != "n" ]]; then
    cf_ensure_dns "$ZONE_ID" "$DOMAIN" "$MYIP" true
    echo "✓ DNS A record updated (proxied)"
fi

echo ""
read -rp "Apply recommended settings (SSL Full, gRPC, WebSockets)? [Y/n] " ans
if [[ "${ans,,}" != "n" ]]; then
    cf_apply_recommended_settings "$ZONE_ID"
    echo "✓ Zone settings applied"
fi

echo ""
read -rp "Sync Cloudflare IP ranges to nginx real_ip? [Y/n] " ans
if [[ "${ans,,}" != "n" ]]; then
    cf_sync_ips_to_nginx
    nginx -t && systemctl reload nginx
    echo "✓ Cloudflare IPs synced"
fi

echo ""
read -rp "Create Cloudflare Origin Certificate (enables SSL Strict)? [y/N] " ans
if [[ "${ans,,}" == "y" ]]; then
    if cf_create_origin_cert "$ZONE_ID" "$DOMAIN"; then
        cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/hap.pem
        systemctl restart haproxy nginx xray
        echo "✓ Origin certificate installed — set SSL mode to Strict"
    else
        echo "WARN: Origin cert creation failed (may need Advanced Certificate Manager)"
    fi
fi

# Persist to config
mkdir -p /etc/vpn_script
grep -q CF_EMAIL /etc/vpn_script/config 2>/dev/null || cat >> /etc/vpn_script/config << EOF

CF_EMAIL="${CF_EMAIL}"
CF_API_KEY="${CF_API_KEY}"
CF_DOMAIN="${DOMAIN}"
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo " Cloudflare checklist (dashboard):"
echo "  • SSL/TLS: ${CF_SSL_MODE:-full}"
echo "  • Network → gRPC: ON"
echo "  • Network → WebSockets: ON"
echo "  • HTTP Custom App: point hostname to ${DOMAIN}"
echo "  • Same WS/gRPC paths as menu output"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
