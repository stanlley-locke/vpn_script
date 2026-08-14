#!/bin/bash
# Renew Let's Encrypt / acme.sh certificate — stanlley-locke/vpn_script
set -euo pipefail

domain=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null)
[[ -n "$domain" ]] || { echo "No domain configured"; exit 1; }

if [[ -x /root/.acme.sh/acme.sh ]]; then
    /root/.acme.sh/acme.sh --renew -d "$domain" --ecc --force
    /root/.acme.sh/acme.sh --installcert -d "$domain" \
        --fullchainpath /etc/xray/xray.crt \
        --keypath /etc/xray/xray.key --ecc
    chmod 600 /etc/xray/xray.key
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/hap.pem
    systemctl reload haproxy nginx
    echo "Certificate renewed for ${domain}"
else
    echo "acme.sh not found — use cf-setup for Cloudflare Origin Cert"
    exit 1
fi
