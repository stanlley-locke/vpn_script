#!/bin/bash
# Apply vpn_script.env → /etc/vpn_script/config + domain files
# stanlley-locke/vpn_script
set -euo pipefail

ENV_FILE="${1:-/root/vpn_script.env}"
CONFIG="/etc/vpn_script/config"
DEFAULTS="/usr/local/lib/vpn_script/config.defaults"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "Env file not found: $ENV_FILE"
    echo "Copy examples/vps.stanlleylocke.dev.env to /root/vpn_script.env"
    exit 1
fi

set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

mkdir -p /etc/vpn_script /etc/xray

# Seed config from defaults if missing
if [[ ! -f "$CONFIG" ]]; then
    if [[ -f "$DEFAULTS" ]]; then
        cp "$DEFAULTS" "$CONFIG"
    else
        touch "$CONFIG"
    fi
fi

_apply_kv() {
    local key="$1" val="$2"
    [[ -z "$val" ]] && return 0
    if grep -q "^${key}=" "$CONFIG" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${val}\"|" "$CONFIG"
    else
        echo "${key}=\"${val}\"" >> "$CONFIG"
    fi
}

# Map env vars → runtime config keys
for key in \
    VPN_GITHUB_USER VPN_REPO_NAME VPN_REPO_BRANCH LICENSE_CHECK INSTALL_NOTIFY \
    TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID VPN_SCRIPT_NAME VPN_AUTHOR SUPPORT_TELEGRAM \
    CF_EMAIL CF_API_KEY CF_DOMAIN CF_SSL_MODE SNI_FRONTING HTTP_APP_PREFIX \
    PATH_VLESS PATH_VMESS PATH_TROJAN PATH_SS PATH_SSH \
    GRPC_VLESS GRPC_VMESS GRPC_TROJAN GRPC_SS ROUTING_PROFILE \
    SSH_WS_PORT SSH_DROPBEAR_PORT SSH_OPENSSH_PORT \
    SUBSCRIPTION_TOKEN SUBSCRIPTION_PORT \
    REALITY_PORT REALITY_DEST REALITY_SNI CF_TUNNEL_NAME \
    DECOY_SITE_TITLE DECOY_SITE_ENABLED HTTPC_DEFAULT_PROFILE
do
    val="${!key:-}"
    _apply_kv "$key" "$val"
done

if [[ -n "${VPN_DOMAIN:-}" ]]; then
    echo "$VPN_DOMAIN" > /etc/xray/domain
    echo "$VPN_DOMAIN" > /root/domain 2>/dev/null || true
    _apply_kv "CF_DOMAIN" "${CF_DOMAIN:-$VPN_DOMAIN}"
    echo "Domain set: $VPN_DOMAIN"
fi

if [[ -n "${VPS_PUBLIC_IP:-}" ]]; then
    mkdir -p /var/lib/kyt
    echo "IP=${VPS_PUBLIC_IP}" > /var/lib/kyt/ipvps.conf
fi

echo "Applied $ENV_FILE → $CONFIG"
echo "Run: apply-paths && reload-stack  (if already installed)"
