#!/bin/bash
# Generate or show subscription URL — stanlley-locke/vpn_script
set -euo pipefail
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

case "${1:-url}" in
    generate-token)
        python3 /usr/local/lib/vpn_script/sub_server.py generate-token
        ;;
    test)
        python3 /usr/local/lib/vpn_script/sub_server.py test
        ;;
    url)
        domain=$(cat /etc/xray/domain 2>/dev/null || echo "your-domain.com")
        token=$(cat /etc/vpn_script/subscription.token 2>/dev/null || echo "RUN: sub-manage generate-token")
        echo "Subscription URL (Hiddify / Sing-box / v2rayNG):"
        echo "  https://${domain}/sub/${token}"
        echo ""
        echo "Clash Meta (same URL, client converts):"
        echo "  https://${domain}/sub/${token}"
        ;;
    install)
        mkdir -p /etc/vpn_script /usr/local/lib/vpn_script /etc/nginx/conf.d
        REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main}"
        if [[ ! -f /usr/local/lib/vpn_script/sub_server.py ]]; then
            wget -qO /usr/local/lib/vpn_script/sub_server.py "${REPO}/ubuntu/subscription/sub_server.py"
        fi
        if [[ ! -f /etc/nginx/conf.d/subscription.conf ]]; then
            wget -qO /etc/nginx/conf.d/subscription.conf "${REPO}/ubuntu/subscription.conf"
        fi
        if [[ ! -f /etc/systemd/system/subscription.service ]]; then
            wget -qO /etc/systemd/system/subscription.service "${REPO}/ubuntu/subscription/subscription.service"
        fi
        systemctl daemon-reload
        systemctl enable subscription
        systemctl restart subscription
        nginx -t && systemctl reload nginx
        python3 /usr/local/lib/vpn_script/sub_server.py generate-token
        ;;
    *)
        echo "Usage: sub-manage {generate-token|test|url|install}"
        ;;
esac
