#!/bin/bash
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh
# VPN Script shared library — stanlley_locke/vpn_script
# Installed to /usr/local/lib/vpn_script/common.sh during setup.

readonly VPN_GITHUB_USER="${VPN_GITHUB_USER:-stanlley_locke}"
readonly VPN_REPO_NAME="${VPN_REPO_NAME:-vpn_script}"
readonly VPN_REPO_BRANCH="${VPN_REPO_BRANCH:-main}"
readonly VPN_REPO="https://raw.githubusercontent.com/${VPN_GITHUB_USER}/${VPN_REPO_NAME}/${VPN_REPO_BRANCH}"
readonly VPN_KEYGEN_URL="${VPN_KEYGEN_URL:-${VPN_REPO}/keygen}"
readonly VPN_SCRIPT_NAME="${VPN_SCRIPT_NAME:-VPN Script}"
readonly VPN_AUTHOR="${VPN_AUTHOR:-stanlley_locke}"
readonly VPN_GITHUB_URL="https://github.com/${VPN_GITHUB_USER}/${VPN_REPO_NAME}"

VPN_CONFIG_FILE="${VPN_CONFIG_FILE:-/etc/vpn_script/config}"

vpn_load_config() {
    if [[ -f "$VPN_CONFIG_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$VPN_CONFIG_FILE"
    fi
    LICENSE_CHECK="${LICENSE_CHECK:-0}"
    INSTALL_NOTIFY="${INSTALL_NOTIFY:-0}"
    TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
    TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"
    SUPPORT_TELEGRAM="${SUPPORT_TELEGRAM:-@stanlley_locke}"
}

vpn_get_public_ip() {
    curl -4 -sS --max-time 10 ipv4.icanhazip.com 2>/dev/null \
        || wget -qO- ipv4.icanhazip.com 2>/dev/null \
        || echo ""
}

vpn_date_from_web() {
    curl -v --insecure --silent https://google.com/ 2>&1 \
        | grep -i Date | sed -e 's/< Date: //' | head -n1
}

checking_sc() {
    vpn_load_config
    if [[ "${LICENSE_CHECK}" == "0" ]]; then
        return 0
    fi

    local ipsaya useexp date_list date_server
    ipsaya="$(vpn_get_public_ip)"
    date_server="$(vpn_date_from_web)"
    date_list="$(date +"%Y-%m-%d" -d "${date_server:-now}" 2>/dev/null || date +"%Y-%m-%d")"
    useexp="$(curl -sS --max-time 15 "${VPN_KEYGEN_URL}" | grep -F "${ipsaya}" | awk '{print $3}' | head -n1)"

    if [[ -n "${useexp}" && "${date_list}" < "${useexp}" ]]; then
        return 0
    fi

    echo -e "\033[1;93m────────────────────────────────────────────\033[0m"
    echo -e "\033[42m          LICENSE CHECK FAILED               \033[0m"
    echo -e "\033[1;93m────────────────────────────────────────────\033[0m"
    echo -e ""
    echo -e "            \033[0;31mPERMISSION DENIED\033[0m"
    echo -e "   \033[0;33mVPS IP:\033[0m ${ipsaya}"
    echo -e "   \033[0;33mAdd this IP to keygen or set LICENSE_CHECK=0\033[0m"
    echo -e "   \033[0;33mRepo:\033[0m ${VPN_GITHUB_URL}"
    echo -e "\033[1;93m────────────────────────────────────────────\033[0m"
    sleep 5
    reboot
}

vpn_send_install_notify() {
    vpn_load_config
    [[ "${INSTALL_NOTIFY}" == "1" ]] || return 0
    [[ -n "${TELEGRAM_BOT_TOKEN}" && -n "${TELEGRAM_CHAT_ID}" ]] || return 0

    local text url
    text="<b>${VPN_SCRIPT_NAME} — Install Complete</b>%0AIP: $(vpn_get_public_ip)%0ADomain: ${domain:-unknown}%0ABy: ${VPN_AUTHOR}"
    url="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    curl -sS --max-time 10 -d "chat_id=${TELEGRAM_CHAT_ID}&text=${text}&parse_mode=html" "$url" >/dev/null 2>&1 || true
}

vpn_print_ok()    { echo -e "\033[92;1m  »\033[0m \033[36m $1 \033[0m"; }
vpn_print_error() { echo -e "\033[31m[ERROR]\033[0m \033[41;37m $1 \033[0m"; }
vpn_print_install() {
    echo -e "\033[32m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ \033[0m"
    echo -e "\033[33m » $1 \033[0m"
    echo -e "\033[32m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ \033[0m"
    sleep 1
}
vpn_print_success() {
    echo -e "\033[32m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ \033[0m"
    echo -e "\033[92;1m » $1 installed successfully\033[0m"
    echo -e "\033[32m ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ \033[0m"
    sleep 1
}

vpn_load_config
