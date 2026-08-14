#!/bin/bash
# Cloudflare Tunnel (cloudflared) — stanlley-locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
[ -f /usr/local/lib/vpn_script/cloudflare.sh ] && source /usr/local/lib/vpn_script/cloudflare.sh
vpn_load_config

DOMAIN="${CF_DOMAIN:-$(cat /etc/xray/domain 2>/dev/null)}"
TUNNEL_NAME="${CF_TUNNEL_NAME:-vpn-script-$(hostname -s)}"
CONFIG_DIR="/etc/cloudflared"
CONFIG_FILE="${CONFIG_DIR}/config.yml"

install_cloudflared() {
    if command -v cloudflared >/dev/null 2>&1; then
        echo "cloudflared already installed: $(cloudflared --version)"
        return 0
    fi
    echo "Installing cloudflared..."
    curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared $(lsb_release -cs) main" \
        > /etc/apt/sources.list.d/cloudflared.list 2>/dev/null || true
    apt-get update -qq
    apt-get install -y cloudflared 2>/dev/null || {
        ARCH=$(uname -m); [[ "$ARCH" == "x86_64" ]] && ARCH=amd64
        curl -fsSL "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${ARCH}" \
            -o /usr/local/bin/cloudflared
        chmod +x /usr/local/bin/cloudflared
    }
    echo "cloudflared installed"
}

login_tunnel() {
    echo "Opening Cloudflare login (copy URL if headless)..."
    cloudflared tunnel login
}

create_tunnel() {
    install_cloudflared
    mkdir -p "$CONFIG_DIR"
    if ! cloudflared tunnel list 2>/dev/null | grep -q "$TUNNEL_NAME"; then
        cloudflared tunnel create "$TUNNEL_NAME"
    fi
    local tunnel_id
    tunnel_id=$(cloudflared tunnel list 2>/dev/null | awk -v n="$TUNNEL_NAME" '$0 ~ n {print $1}' | head -1)
    [[ -n "$tunnel_id" ]] || { echo "Could not find tunnel ID"; exit 1; }

    cat > "$CONFIG_FILE" <<EOF
tunnel: ${tunnel_id}
credentials-file: ${CONFIG_DIR}/${tunnel_id}.json

ingress:
  - hostname: ${DOMAIN}
    service: https://127.0.0.1:443
    originRequest:
      noTLSVerify: true
      http2Origin: true
  - service: http_status:404
EOF

    echo "Config written to ${CONFIG_FILE}"
    echo ""
    echo "Add DNS route:"
    echo "  cloudflared tunnel route dns ${TUNNEL_NAME} ${DOMAIN}"
    read -rp "Run DNS route now? [Y/n] " ans
    [[ "${ans,,}" == "n" ]] || cloudflared tunnel route dns "$TUNNEL_NAME" "$DOMAIN"

    cat > /etc/systemd/system/cloudflared.service <<EOF
[Unit]
Description=Cloudflare Tunnel
After=network.target nginx.service haproxy.service

[Service]
Type=simple
ExecStart=/usr/bin/cloudflared --config ${CONFIG_FILE} tunnel run
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable cloudflared
    systemctl restart cloudflared
    echo ""
    echo "Cloudflare Tunnel running. Origin IP hidden behind Cloudflare."
    echo "Set Cloudflare DNS for ${DOMAIN} to CNAME: ${tunnel_id}.cfargotunnel.com"
    echo "Disable proxied A record if switching to tunnel."
}

status_tunnel() {
    systemctl status cloudflared --no-pager 2>/dev/null || echo "cloudflared not running"
    cloudflared tunnel list 2>/dev/null || true
}

case "${1:-setup}" in
    install) install_cloudflared ;;
    login)   login_tunnel ;;
    setup)   create_tunnel ;;
    status)  status_tunnel ;;
    *)       echo "Usage: cf-tunnel {install|login|setup|status}" ;;
esac
