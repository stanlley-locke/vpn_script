#!/bin/bash
# Apply HTTP Custom App path prefix to nginx + xray — stanlley-locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
vpn_load_config

PREFIX="${HTTP_APP_PREFIX:-}"
NGINX_XRAY="/etc/nginx/conf.d/xray.conf"
XRAY_CFG="/etc/xray/config.json"
REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/}"

# Restore templates from repo then apply domain + prefix
domain=$(cat /etc/xray/domain 2>/dev/null || echo "localhost")
wget -qO "$NGINX_XRAY" "${REPO}/ubuntu/xray.conf"
wget -qO "$XRAY_CFG" "${REPO}/ubuntu/config.json"

sed -i "s/xxx/${domain}/g" "$NGINX_XRAY"

p() { echo "${PREFIX%/}$1"; }

PVLESS=$(p "${PATH_VLESS:-/vless}")
PVMESS=$(p "${PATH_VMESS:-/vmess}")
PTROJAN=$(p "${PATH_TROJAN:-/trojan-ws}")
PSS=$(p "${PATH_SS:-/ss-ws}")
PSSH=$(p "${PATH_SSH:-/}")

for pair in \
    "/vless|${PVLESS}" \
    "/vmess|${PVMESS}" \
    "/trojan-ws|${PTROJAN}" \
    "/ss-ws|${PSS}"; do
    old="${pair%%|*}"; new="${pair##*|}"
    sed -i "s|${old}|${new}|g" "$NGINX_XRAY"
done

sed -i "s|/vless|${PVLESS}|g; s|/vmess|${PVMESS}|g; s|/trojan-ws|${PTROJAN}|g; s|/ss-ws|${PSS}|g" "$XRAY_CFG"

nginx -t && systemctl reload nginx
systemctl restart xray
echo "Paths applied (prefix=${PREFIX:-none})"
echo "  VLESS : ${PVLESS}"
echo "  VMESS : ${PVMESS}"
echo "  TROJAN: ${PTROJAN}"
echo "  SS    : ${PSS}"
