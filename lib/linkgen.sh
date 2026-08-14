#!/bin/bash
# Client link helpers — stanlley-locke/vpn_script
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
vpn_load_config

vpn_read_paths() {
    local cfg="${VPN_CONFIG_FILE:-/etc/vpn_script/config}"
    # shellcheck source=/dev/null
    [[ -f "$cfg" ]] && source "$cfg"
    PATH_VLESS="${PATH_VLESS:-/vless}"
    PATH_VMESS="${PATH_VMESS:-/vmess}"
    PATH_TROJAN="${PATH_TROJAN:-/trojan-ws}"
    PATH_SS="${PATH_SS:-/ss-ws}"
    PATH_SSH="${PATH_SSH:-/}"
    GRPC_VLESS="${GRPC_VLESS:-vless-grpc}"
    GRPC_VMESS="${GRPC_VMESS:-vmess-grpc}"
    GRPC_TROJAN="${GRPC_TROJAN:-trojan-grpc}"
    GRPC_SS="${GRPC_SS:-ss-grpc}"
    SNI_FRONTING="${SNI_FRONTING:-}"
    domain="${domain:-$(cat /etc/xray/domain 2>/dev/null)}"
    SNI_HOST="${SNI_FRONTING:-$domain}"
}

# HTTP Custom App: optional path prefix (e.g. /app/cdn)
vpn_path() {
    local base="$1"
    local prefix="${HTTP_APP_PREFIX:-}"
    if [[ -n "$prefix" ]]; then
        echo "${prefix%/}${base}"
    else
        echo "$base"
    fi
}

vpn_vmess_link() {
    local uuid="$1" user="$2"
    vpn_read_paths
    local path; path=$(vpn_path "$PATH_VMESS")
    local json
    json=$(jq -nc \
        --arg v "2" --arg ps "$user" --arg add "$domain" --arg port "443" \
        --arg id "$uuid" --arg aid "0" --arg net "ws" --arg type "none" \
        --arg host "$domain" --arg path "$path" --arg tls "tls" --arg sni "$SNI_HOST" \
        '{v:$v,ps:$ps,add:$add,port:$port,id:$id,aid:$aid,net:$net,type:$type,host:$host,path:$path,tls:$tls,sni:$sni,scy:"auto"}')
    echo "vmess://$(echo -n "$json" | base64 -w0 2>/dev/null || echo -n "$json" | base64)"
}

vpn_vless_link() {
    local uuid="$1" user="$2"
    vpn_read_paths
    local path; path=$(vpn_path "$PATH_VLESS")
    echo "vless://${uuid}@${domain}:443?encryption=none&security=tls&type=ws&host=${domain}&path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${path}'))")&sni=${SNI_HOST}#${user}"
}

vpn_trojan_link() {
    local uuid="$1" user="$2"
    vpn_read_paths
    local path; path=$(vpn_path "$PATH_TROJAN")
    echo "trojan://${uuid}@${domain}:443?security=tls&type=ws&host=${domain}&path=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${path}'))")&sni=${SNI_HOST}#${user}"
}

vpn_ssh_ws_hint() {
    vpn_read_paths
    cat <<EOF
SSH WebSocket tunnel
  Host    : ${domain}
  Port    : 443
  Path    : $(vpn_path "$PATH_SSH")
  SNI     : ${SNI_HOST}
  User    : <ssh-username>
  Transport: WebSocket TLS (Cloudflare proxied)
EOF
}
