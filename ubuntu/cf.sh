#!/bin/bash
# Cloudflare DNS helper — stanlley_locke/vpn_script
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
[ -f /etc/vpn_script/config ] && source /etc/vpn_script/config

set -euo pipefail

MYIP=$(curl -4 -sS --max-time 10 icanhazip.com || wget -qO- icanhazip.com)
apt-get install -y jq curl >/dev/null 2>&1 || apt install -y jq curl

echo ""
echo "Cloudflare random subdomain setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
read -rp "Cloudflare account email: " CF_ID
read -rsp "Cloudflare Global API Key: " CF_KEY
echo ""
read -rp "Root domain (e.g. example.com): " DOMAIN
read -rp "Subdomain prefix [auto random]: " sub_input

if [[ -n "${sub_input}" ]]; then
    dns="${sub_input}.${DOMAIN}"
else
    sub=$(tr -dc 'a-z0-9' </dev/urandom | head -c5)
    dns="${sub}.${DOMAIN}"
fi

echo "Creating DNS A record: ${dns} -> ${MYIP}"

ZONE=$(curl -sS --max-time 15 \
    "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}&status=active" \
    -H "X-Auth-Email: ${CF_ID}" \
    -H "X-Auth-Key: ${CF_KEY}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -z "${ZONE}" || "${ZONE}" == "null" ]]; then
    echo "ERROR: Could not find Cloudflare zone for ${DOMAIN}"
    exit 1
fi

RECORD=$(curl -sS --max-time 15 \
    "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records?name=${dns}" \
    -H "X-Auth-Email: ${CF_ID}" \
    -H "X-Auth-Key: ${CF_KEY}" \
    -H "Content-Type: application/json" | jq -r '.result[0].id')

if [[ -z "${RECORD}" || "${RECORD}" == "null" ]]; then
    RECORD=$(curl -sS --max-time 15 -X POST \
        "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records" \
        -H "X-Auth-Email: ${CF_ID}" \
        -H "X-Auth-Key: ${CF_KEY}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${dns}\",\"content\":\"${MYIP}\",\"ttl\":120,\"proxied\":true}" \
        | jq -r '.result.id')
else
    curl -sS --max-time 15 -X PUT \
        "https://api.cloudflare.com/client/v4/zones/${ZONE}/dns_records/${RECORD}" \
        -H "X-Auth-Email: ${CF_ID}" \
        -H "X-Auth-Key: ${CF_KEY}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"A\",\"name\":\"${dns}\",\"content\":\"${MYIP}\",\"ttl\":120,\"proxied\":true}" >/dev/null
fi

for f in /root/domain /root/scdomain /etc/xray/domain /etc/v2ray/domain /etc/xray/scdomain; do
    echo "$dns" > "$f" 2>/dev/null || mkdir -p "$(dirname "$f")" && echo "$dns" > "$f"
done
echo "IP=${dns}" > /var/lib/kyt/ipvps.conf 2>/dev/null || true

echo ""
echo "Done. Domain set to: ${dns}"
echo "Enable Cloudflare proxy (orange cloud) and set SSL/TLS to Full."
