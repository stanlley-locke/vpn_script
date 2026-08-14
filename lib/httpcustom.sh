#!/bin/bash
# HTTP Custom library API — stanlley-locke/vpn_script
# Payloads, SNI, proxies and v5 profile export for HTTP Custom app.

HTTPC_LIB="${HTTPC_LIB:-/usr/local/lib/vpn_script/httpcustom}"
[[ -d "$HTTPC_LIB" ]] || HTTPC_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/httpcustom" 2>/dev/null && pwd)"

[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
command -v jq >/dev/null 2>&1 || { echo "jq required"; exit 1; }

httpc_domain() {
    cat /etc/xray/domain 2>/dev/null || echo "vpn.example.com"
}

httpc_lib() {
    local file="$1"
    if [[ -f "${HTTPC_LIB}/${file}" ]]; then
        cat "${HTTPC_LIB}/${file}"
    else
        curl -sS --max-time 15 "${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main}/lib/httpcustom/${file}"
    fi
}

httpc_list_payloads() {
    local cat="${1:-}"
    if [[ -n "$cat" ]]; then
        httpc_lib payloads.json | jq -r --arg c "$cat" '.payloads[] | select(.category==$c) | "\(.id)\t\(.name)"'
    else
        httpc_lib payloads.json | jq -r '.payloads[] | "\(.id)\t[\(.category)] \(.name)"'
    fi
}

httpc_list_sni() {
    local tag="${1:-}"
    if [[ -n "$tag" ]]; then
        httpc_lib sni.json | jq -r --arg t "$tag" '.sni_hosts[] | select(.category==$t or (.use_case|contains($t))) | "\(.id)\t\(.host)\t\(.name)"'
    else
        httpc_lib sni.json | jq -r '.sni_hosts[] | "\(.id)\t\(.host)\t\(.name)"'
    fi
}

httpc_list_proxies() {
    local cat="${1:-}"
    if [[ -n "$cat" ]]; then
        httpc_lib proxies.json | jq -r --arg c "$cat" '.proxies[] | select(.category==$c) | "\(.id)\t\(.host):\(.port)\t\(.name)"'
    else
        httpc_lib proxies.json | jq -r '.proxies[] | "\(.id)\t\(.host):\(.port)\t[\(.category)] \(.name)"'
    fi
}

httpc_list_profiles() {
    httpc_lib profiles.json | jq -r '.profiles[] | "\(.id)\t\(.name)"'
}

httpc_list_zerorate() {
    local carrier="${1:-safaricom_ke}"
    httpc_lib sni.json | jq -r --arg c "$carrier" '.zerorate_hosts[$c][]? // empty'
}

httpc_get_payload() {
    local id="$1"
    httpc_lib payloads.json | jq -r --arg id "$id" '.payloads[] | select(.id==$id) | .payload'
}

httpc_get_entry() {
    local type="$1" id="$2"
    case "$type" in
        payload) httpc_lib payloads.json | jq -c --arg id "$id" '.payloads[] | select(.id==$id)' ;;
        sni)     httpc_lib sni.json | jq -c --arg id "$id" '.sni_hosts[] | select(.id==$id)' ;;
        proxy)   httpc_lib proxies.json | jq -c --arg id "$id" '.proxies[] | select(.id==$id)' ;;
        profile) httpc_lib profiles.json | jq -c --arg id "$id" '.profiles[] | select(.id==$id)' ;;
    esac
}

httpc_substitute() {
    local text="$1"
    local domain host port sni payload ssh_user ssh_pass expiry
    domain="$(httpc_domain)"
    host="${HTTPC_SSH_HOST:-$domain}"
    port="${HTTPC_SSH_PORT:-443}"
    sni="${HTTPC_SNI:-$domain}"
    ssh_user="${HTTPC_SSH_USER:-user}"
    ssh_pass="${HTTPC_SSH_PASS:-pass}"
    expiry="${HTTPC_EXPIRY:-lifeTime}"

    text="${text//\[domain\]/$domain}"
    text="${text//\[host\]/$host}"
    text="${text//\[Host\]/$host}"
    text="${text//\[host_port\]/${host}:${port}}"
    text="${text//\[your_host\]/$domain}"
    text="${text//@domain/$domain}"
    text="${text//@sni/$sni}"
    text="${text//@payload/$payload}"
    text="${text//@proxy_host/${HTTPC_PROXY_HOST:-104.17.3.81}}"
    text="${text//@proxy_port/${HTTPC_PROXY_PORT:-80}}"
    echo "$text"
}

httpc_export_v5() {
    local profile_id="$1"
    local out="${2:-/root/httpcustom-export.json}"
    local ssh_user="${3:-}"
    local ssh_pass="${4:-}"

    local profile
    profile=$(httpc_get_entry profile "$profile_id")
    [[ -n "$profile" && "$profile" != "null" ]] || { echo "Profile not found: $profile_id"; return 1; }

    local payload_id sni_id proxy_id
    payload_id=$(echo "$profile" | jq -r '.payload_id')
    sni_id=$(echo "$profile" | jq -r '.sni_id')
    proxy_id=$(echo "$profile" | jq -r '.proxy_id')

    local domain; domain=$(httpc_domain)
    local payload_raw sni_host proxy_host proxy_port
    payload_raw=$(httpc_get_payload "$payload_id")
    sni_host=$(httpc_get_entry sni "$sni_id" | jq -r '.host')
    proxy_host=$(httpc_get_entry proxy "$proxy_id" | jq -r '.host')
    proxy_port=$(httpc_get_entry proxy "$proxy_id" | jq -r '.port')

    HTTPC_SNI="${sni_host//\[domain\]/ $domain}"; HTTPC_SNI="${HTTPC_SNI//\[domain\]/$domain}"
    HTTPC_PROXY_HOST="${proxy_host//\[domain\]/$domain}"
    HTTPC_PROXY_PORT="$proxy_port"
    HTTPC_SSH_HOST="$domain"
    HTTPC_SSH_PORT="$(echo "$profile" | jq -r '.template.profilev5.server_port // 443')"

    payload_raw=$(httpc_substitute "$payload_raw")

    echo "$profile" | jq \
        --arg payload "$payload_raw" \
        --arg sni "$HTTPC_SNI" \
        --arg domain "$domain" \
        --arg ph "$HTTPC_PROXY_HOST" \
        --arg pp "$HTTPC_PROXY_PORT" \
        --arg user "$ssh_user" \
        --arg pass "$ssh_pass" \
        --arg pid "$profile_id" \
        '.template
         | .profilev5.custom_payload = $payload
         | .profilev5.custom_sni = $sni
         | .profilev5.custom_host = ($ph + ":" + $pp)
         | . + {
             ssh: {
               server: ($domain + ":" + (.profilev5.server_port|tostring)),
               username: $user,
               password: $pass,
               protocol: "SSH WebSocket"
             },
             meta: {
               author: "stanlley-locke",
               repo: "https://github.com/stanlley-locke/vpn_script",
               profile_id: $pid
             }
           }' > "$out"

    echo "Exported: $out"
}

httpc_export_text() {
    local profile_id="$1"
    local ssh_user="$2"
    local ssh_pass="$3"
    local domain; domain=$(httpc_domain)

    local profile payload_id
    profile=$(httpc_get_entry profile "$profile_id")
    payload_id=$(echo "$profile" | jq -r '.payload_id')
    local payload; payload=$(httpc_get_payload "$payload_id")
    payload=$(httpc_substitute "$payload")

    local proxy_id sni_id
    proxy_id=$(echo "$profile" | jq -r '.proxy_id')
    sni_id=$(echo "$profile" | jq -r '.sni_id')
    local proxy_line sni_line
    proxy_line=$(httpc_get_entry proxy "$proxy_id" | jq -r '"\(.host):\(.port)"')
    sni_line=$(httpc_get_entry sni "$sni_id" | jq -r '.host')
    local proxy sni
    proxy=$(httpc_substitute "$proxy_line")
    sni=$(httpc_substitute "$sni_line")

    cat <<EOF
═══════════════════════════════════════
 HTTP Custom Export — stanlley-locke
 Profile: $(echo "$profile" | jq -r '.name')
 Domain : ${domain}
═══════════════════════════════════════
❂ Payload ❂
${payload}
═══════════════════════════════════════
❂ Proxy ❂
${proxy}
═══════════════════════════════════════
❂ SNI ❂
${sni}
═══════════════════════════════════════
❂ SSH ❂
${domain}:443@${ssh_user}:${ssh_pass}
═══════════════════════════════════════
❂ Ports (plain) ❂
80, 8080, 8880, 2052, 2082, 2086, 2095
❂ Ports (TLS) ❂
443, 2053, 2083, 2087, 2096, 8443
═══════════════════════════════════════
Import JSON: httpc-export-v5 ${profile_id} ${ssh_user}
═══════════════════════════════════════
EOF
}

httpc_search() {
    local q="$1"
    echo "== Payloads =="
    httpc_lib payloads.json | jq -r --arg q "$q" '.payloads[] | select(.name|test($q;"i") or .description|test($q;"i") or (.tags[]?|test($q;"i"))) | "\(.id): \(.name)"'
    echo "== SNI =="
    httpc_lib sni.json | jq -r --arg q "$q" '.sni_hosts[] | select(.name|test($q;"i") or .host|test($q;"i")) | "\(.id): \(.host)"'
    echo "== Proxies =="
    httpc_lib proxies.json | jq -r --arg q "$q" '.proxies[] | select(.name|test($q;"i") or .host|test($q;"i")) | "\(.id): \(.host):\(.port)"'
}

# CLI when sourced with args
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-help}" in
        list-payloads)  shift; httpc_list_payloads "${1:-}" ;;
        list-sni)       shift; httpc_list_sni "${1:-}" ;;
        list-proxies)   shift; httpc_list_proxies "${1:-}" ;;
        list-profiles)  httpc_list_profiles ;;
        list-zerorate)  shift; httpc_list_zerorate "${1:-safaricom_ke}" ;;
        get-payload)    httpc_get_payload "$2" ;;
        export-v5)      httpc_export_v5 "$2" "${3:-/root/httpcustom-export.json}" "$4" "$5" ;;
        export-text)    httpc_export_text "$2" "$3" "$4" ;;
        search)         httpc_search "$2" ;;
        *)
            echo "Usage: httpc-lib {list-payloads|list-sni|list-proxies|list-profiles|list-zerorate|export-v5|export-text|search} [args]"
            ;;
    esac
fi
