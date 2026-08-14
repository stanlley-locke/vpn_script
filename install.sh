#!/bin/bash
# Quick install entry point — stanlley-locke/vpn_script
# SAFE: download with wget first (curl may segfault on Ubuntu 26.04)
#
#   wget -qO /tmp/install.sh https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/install.sh
#   bash /tmp/install.sh

set -e

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main}"

if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

for envfile in /root/vpn_script.env ./vpn_script.env; do
    if [[ -f "$envfile" ]]; then
        echo "Loading config from ${envfile}"
        set -a
        # shellcheck source=/dev/null
        source "$envfile"
        set +a
        export VPN_ENV_FILE="$envfile"
        break
    fi
done

echo "Fetching installer from ${REPO}..."
wget -qO /tmp/genz.sh "${REPO}/genz.sh" || { echo "Download failed — use: apt install wget"; exit 1; }
chmod +x /tmp/genz.sh
exec bash /tmp/genz.sh "$@"
