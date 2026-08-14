#!/bin/bash
# Cloudflare API helpers — stanlley-locke/vpn_script
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
vpn_load_config

CF_API="${CF_API:-https://api.cloudflare.com/client/v4}"

cf_api() {
    local method="$1" endpoint="$2" data="${3:-}"
    local args=(-sS --max-time 30 -X "$method"
        -H "X-Auth-Email: ${CF_EMAIL}"
        -H "X-Auth-Key: ${CF_API_KEY}"
        -H "Content-Type: application/json")
    if [[ -n "$data" ]]; then
        args+=(--data "$data")
    fi
    curl "${args[@]}" "${CF_API}${endpoint}"
}

cf_get_zone_id() {
    local domain="$1"
    cf_api GET "/zones?name=${domain}&status=active" | jq -r '.result[0].id // empty'
}

cf_ensure_dns() {
    local zone_id="$1" name="$2" ip="$3" proxied="${4:-true}"
    local record_id
    record_id=$(cf_api GET "/zones/${zone_id}/dns_records?name=${name}" | jq -r '.result[0].id // empty')
    local payload
    payload=$(jq -nc --arg name "$name" --arg ip "$ip" --argjson proxied "$proxied" \
        '{type:"A",name:$name,content:$ip,ttl:120,proxied:$proxied}')
    if [[ -z "$record_id" || "$record_id" == "null" ]]; then
        cf_api POST "/zones/${zone_id}/dns_records" "$payload" | jq -e '.success' >/dev/null
    else
        cf_api PUT "/zones/${zone_id}/dns_records/${record_id}" "$payload" | jq -e '.success' >/dev/null
    fi
}

cf_set_ssl_mode() {
    local zone_id="$1" mode="${2:-full}"
    cf_api PATCH "/zones/${zone_id}/settings/ssl" "{\"value\":\"${mode}\"}" | jq -e '.success' >/dev/null
}

cf_set_grpc() {
    local zone_id="$1" enabled="${2:-on}"
    cf_api PATCH "/zones/${zone_id}/settings/grpc" "{\"value\":\"${enabled}\"}" | jq -e '.success' >/dev/null
}

cf_set_websockets() {
    local zone_id="$1" enabled="${2:-on}"
    cf_api PATCH "/zones/${zone_id}/settings/websockets" "{\"value\":\"${enabled}\"}" | jq -e '.success' >/dev/null
}

cf_set_always_https() {
    local zone_id="$1" enabled="${2:-off}"
    cf_api PATCH "/zones/${zone_id}/settings/always_use_https" "{\"value\":\"${enabled}\"}" | jq -e '.success' >/dev/null
}

cf_create_origin_cert() {
    local zone_id="$1" hostnames="$2" days="${3:-5475}"
    local resp
    resp=$(cf_api POST "/certificates" \
        "{\"hostnames\":[\"${hostnames}\"],\"requested_validity\":${days},\"request_type\":\"origin-rsa\"}")
    local cert key
    cert=$(echo "$resp" | jq -r '.result.certificate // empty')
    key=$(echo "$resp" | jq -r '.result.private_key // empty')
    if [[ -z "$cert" || -z "$key" ]]; then
        return 1
    fi
    mkdir -p /etc/xray /etc/haproxy
    echo "$cert" > /etc/xray/xray.crt
    echo "$key" > /etc/xray/xray.key
    chmod 600 /etc/xray/xray.key
    cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/hap.pem
    cf_set_ssl_mode "$zone_id" "strict"
    return 0
}

cf_apply_recommended_settings() {
    local zone_id="$1"
    cf_set_ssl_mode "$zone_id" "${CF_SSL_MODE:-full}"
    cf_set_grpc "$zone_id" "on"
    cf_set_websockets "$zone_id" "on"
    cf_set_always_https "$zone_id" "off"
    cf_api PATCH "/zones/${zone_id}/settings/http3" '{"value":"on"}' >/dev/null 2>&1 || true
    cf_api PATCH "/zones/${zone_id}/settings/0rtt" '{"value":"off"}' >/dev/null 2>&1 || true
}

cf_sync_ips_to_nginx() {
    local dest="${1:-/etc/nginx/conf.d/cloudflare-ips.conf}"
    mkdir -p "$(dirname "$dest")"
    {
        echo "# Cloudflare IP ranges — auto-managed by vpn_script"
        curl -sS --max-time 15 https://api.cloudflare.com/client/v4/ips | jq -r '.result.ipv4_cidrs[], .result.ipv6_cidrs[]' \
            | while read -r cidr; do
                echo "set_real_ip_from ${cidr};"
            done
        echo "real_ip_header CF-Connecting-IP;"
        echo "real_ip_recursive on;"
    } > "$dest"
}

cf_validate_credentials() {
    [[ -n "${CF_EMAIL:-}" && -n "${CF_API_KEY:-}" ]] || return 1
    cf_api GET "/user/tokens/verify" 2>/dev/null | jq -e '.success' >/dev/null 2>&1 \
        || cf_api GET "/zones?per_page=1" | jq -e '.success' >/dev/null
}
