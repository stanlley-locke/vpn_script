#!/bin/bash
# REALITY inbound setup — stanlley-locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

REALITY_CFG="/etc/xray/reality.json"
USERS_CFG="/etc/xray/reality-users.json"
XRAY_CFG="/etc/xray/config.json"
REALITY_PORT="${REALITY_PORT:-8443}"
DEST="${REALITY_DEST:-www.microsoft.com:443}"
SERVER_NAMES="${REALITY_SNI:-www.microsoft.com}"

install_reality_keys() {
    if [[ ! -x /usr/local/bin/xray ]]; then
        echo "Xray not installed"; return 1
    fi
    local keys
    keys=$(/usr/local/bin/xray x25519)
    local priv pub
    priv=$(echo "$keys" | grep -i "Private" | awk '{print $NF}')
    pub=$(echo "$keys" | grep -i "Public" | awk '{print $NF}')
    local sid
    sid=$(openssl rand -hex 4)
    mkdir -p /etc/xray
    cat > "$REALITY_CFG" <<EOF
{
  "privateKey": "${priv}",
  "publicKey": "${pub}",
  "shortId": "${sid}",
  "dest": "${DEST}",
  "serverNames": ["${SERVER_NAMES}"],
  "port": ${REALITY_PORT}
}
EOF
    chmod 600 "$REALITY_CFG"
    echo "REALITY keys saved to ${REALITY_CFG}"
    echo "  Public key : ${pub}"
    echo "  Short ID   : ${sid}"
    echo "  Port       : ${REALITY_PORT}"
}

apply_reality_inbound() {
    [[ -f "$REALITY_CFG" ]] || install_reality_keys
    local priv sid
    priv=$(jq -r '.privateKey' "$REALITY_CFG")
    sid=$(jq -r '.shortId' "$REALITY_CFG")
    [[ -f "$USERS_CFG" ]] || echo '{"users":[]}' > "$USERS_CFG"
    local clients
    clients=$(jq -c '[.users[] | {id: .uuid, email: .email, flow: "xtls-rprx-vision"}]' "$USERS_CFG")
    jq --argjson clients "$clients" \
       --arg priv "$priv" \
       --arg sid "$sid" \
       --arg dest "$DEST" \
       --arg sn "$SERVER_NAMES" \
       --argjson port "$REALITY_PORT" \
       '
       .inbounds = ([.inbounds[] | select(.tag != "reality-in")] + [{
         "listen": "0.0.0.0",
         "port": $port,
         "protocol": "vless",
         "tag": "reality-in",
         "settings": {
           "decryption": "none",
           "clients": $clients
         },
         "streamSettings": {
           "network": "tcp",
           "security": "reality",
           "realitySettings": {
             "show": false,
             "dest": $dest,
             "xver": 0,
             "serverNames": [$sn],
             "privateKey": $priv,
             "shortIds": [$sid]
           }
         },
         "sniffing": {"enabled": true, "destOverride": ["http", "tls", "quic"]}
       }])' "$XRAY_CFG" > "${XRAY_CFG}.tmp" && mv "${XRAY_CFG}.tmp" "$XRAY_CFG"
    jq --arg pub "$(jq -r '.publicKey' "$REALITY_CFG)" \
       --arg sid "$sid" --argjson port "$REALITY_PORT" --arg dest "$DEST" --arg sn "$SERVER_NAMES" \
       '.params = {publicKey: $pub, shortId: $sid, port: $port, dest: $dest, serverName: $sn}' \
       "$USERS_CFG" > "${USERS_CFG}.tmp" && mv "${USERS_CFG}.tmp" "$USERS_CFG"
    systemctl restart xray
    echo "REALITY inbound applied on port ${REALITY_PORT}"
}

add_reality_user() {
    local user="${1:-}"
    local days="${2:-30}"
    [[ -n "$user" ]] || read -rp "Username: " user
    local uuid
    uuid=$(cat /proc/sys/kernel/random/uuid)
    local exp
    exp=$(date -d "+${days} days" +%Y-%m-%d)
    [[ -f "$USERS_CFG" ]] || echo '{"users":[],"params":{}}' > "$USERS_CFG"
    jq --arg u "$user" --arg id "$uuid" --arg e "$exp" \
       '.users += [{email: $u, uuid: $id, expiry: $e}]' "$USERS_CFG" > "${USERS_CFG}.tmp" \
       && mv "${USERS_CFG}.tmp" "$USERS_CFG"
    apply_reality_inbound
    local domain pub sid port sn
    domain=$(cat /etc/xray/domain)
    pub=$(jq -r '.params.publicKey // .publicKey' "$REALITY_CFG" 2>/dev/null || jq -r '.publicKey' "$REALITY_CFG")
    sid=$(jq -r '.params.shortId // .shortId' "$REALITY_CFG")
    port=$(jq -r '.params.port // .port' "$REALITY_CFG")
    sn=$(jq -r '.serverNames[0] // .params.serverName' "$REALITY_CFG" 2>/dev/null || echo "www.microsoft.com")
    local link
    link="vless://${uuid}@${domain}:${port}?encryption=none&security=reality&type=tcp&flow=xtls-rprx-vision&sni=${sn}&fp=chrome&pbk=${pub}&sid=${sid}#${user}"
    echo ""
    echo "REALITY user created: ${user}"
    echo "Link: ${link}"
    mkdir -p /var/www/html
    echo "$link" > "/var/www/html/reality-${user}.txt"
}

case "${1:-install}" in
    install) install_reality_keys; apply_reality_inbound ;;
    add)     add_reality_user "${2:-}" "${3:-30}" ;;
    apply)   apply_reality_inbound ;;
    keys)    install_reality_keys ;;
    *)       echo "Usage: reality-setup {install|add [user] [days]|apply|keys}" ;;
esac
