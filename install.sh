#!/bin/bash
# Quick install entry point — stanlley_locke/vpn_script
# Usage: curl -fsSL https://raw.githubusercontent.com/stanlley_locke/vpn_script/main/install.sh | bash

set -euo pipefail

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley_locke/vpn_script/main}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

echo "Fetching installer from ${REPO}..."
wget -qO /tmp/genz.sh "${REPO}/genz.sh"
chmod +x /tmp/genz.sh
exec /tmp/genz.sh "$@"
