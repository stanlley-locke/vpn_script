#!/bin/bash
# Xray routing profile switcher — stanlley-locke/vpn_script
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

ROUTING_DIR="/etc/xray/routing"
XRAY_CONFIG="/etc/xray/config.json"

vpn_apply_routing_profile() {
    local profile="${1:-global}"
    local src="${ROUTING_DIR}/${profile}.json"
    if [[ ! -f "$src" ]]; then
        echo "Unknown profile: $profile (available: global, split, adblock, direct)"
        return 1
    fi
    if [[ ! -f "$XRAY_CONFIG" ]]; then
        echo "Xray config not found"
        return 1
    fi
    rules=$(cat "$src")
    jq --slurpfile rules "$src" '.routing.rules = $rules[0]' "$XRAY_CONFIG" > "${XRAY_CONFIG}.tmp" \
        && mv "${XRAY_CONFIG}.tmp" "$XRAY_CONFIG"
    systemctl restart xray
    echo "$profile" > /etc/xray/routing.active
    echo "Routing profile applied: $profile"
}

vpn_list_routing_profiles() {
    ls -1 "${ROUTING_DIR}"/*.json 2>/dev/null | xargs -n1 basename | sed 's/.json$//' || true
}
