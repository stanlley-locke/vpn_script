#!/bin/bash
# Update admin menu scripts — stanlley-locke/vpn_script
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/}"

clear
fun_bar() {
    CMD[0]="$1"
    (
        [[ -e $HOME/fim ]] && rm $HOME/fim
        ${CMD[0]} >/dev/null 2>&1
        touch $HOME/fim
    ) >/dev/null 2>&1 &
    tput civis 2>/dev/null || true
    echo -ne "  \033[0;33mUpdating \033[1;37m- \033[0;33m["
    while true; do
        for ((i = 0; i < 18; i++)); do
            echo -ne "\033[0;32m#"
            sleep 0.05s
        done
        [[ -e $HOME/fim ]] && rm $HOME/fim && break
        echo -e "\033[0;33m]"
        sleep 0.5s
        tput cuu1 2>/dev/null; tput dl1 2>/dev/null
        echo -ne "  \033[0;33mUpdating \033[1;37m- \033[0;33m["
    done
    echo -e "\033[0;33m]\033[1;37m -\033[1;32m OK\033[1;37m"
    tput cnorm 2>/dev/null || true
}

res1() {
    wget -q "${REPO}ubuntu/menu.zip"
    unzip -o menu.zip
    chmod +x menu/*
    mv menu/* /usr/local/sbin/
    rm -rf menu menu.zip
    mkdir -p /usr/local/lib/vpn_script/httpcustom
    for f in common.sh cloudflare.sh linkgen.sh routing.sh httpcustom.sh config.defaults; do
        wget -qO "/usr/local/lib/vpn_script/${f}" "${REPO}lib/${f}" 2>/dev/null || true
    done
    for f in index.json payloads.json sni.json proxies.json profiles.json; do
        wget -qO "/usr/local/lib/vpn_script/httpcustom/${f}" "${REPO}lib/httpcustom/${f}" 2>/dev/null || true
    done
    for script in health-check cf-setup apply-routing apply-paths cert-renew reload-stack httpcustom-export reality-setup cf-tunnel sub-manage apply-env; do
        wget -qO "/usr/local/sbin/${script}" "${REPO}scripts/${script}.sh" 2>/dev/null || true
    done
    wget -qO /usr/local/sbin/httpcustom-export-v5 "${REPO}scripts/httpcustom-export-v5.sh" 2>/dev/null || true
    wget -qO /usr/local/sbin/httpc-lib "${REPO}lib/httpcustom.sh" 2>/dev/null || true
    wget -qO /usr/local/lib/vpn_script/sub_server.py "${REPO}ubuntu/subscription/sub_server.py" 2>/dev/null || true
    wget -qO /etc/systemd/system/subscription.service "${REPO}ubuntu/subscription/subscription.service" 2>/dev/null || true
    wget -qO /etc/nginx/conf.d/subscription.conf "${REPO}ubuntu/subscription.conf" 2>/dev/null || true
    chmod +x /usr/local/sbin/{health-check,cf-setup,apply-routing,apply-paths,cert-renew,reload-stack,httpcustom-export,httpcustom-export-v5,httpc-lib,reality-setup,cf-tunnel,sub-manage,apply-env} 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
}

netfilter-persistent 2>/dev/null || true
clear
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \e[1;97;101m     VPN Script Update — stanlley-locke          \e[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo ""
fun_bar res1
echo ""
read -n 1 -s -r -p "Press [ Enter ] to return to menu"
menu
