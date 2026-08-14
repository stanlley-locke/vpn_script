#!/bin/bash
# Quick install entry point — stanlley-locke/vpn_script
# Usage:
#   curl -fsSL .../install.sh | bash
#   — with env file on VPS first —
#   cp examples/vps.stanlleylocke.dev.env /root/vpn_script.env && nano /root/vpn_script.env
#   curl -fsSL .../install.sh | bash

set -euo pipefail

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main}"

if [[ "${EUID}" -ne 0 ]]; then
    echo "Run as root: sudo bash install.sh"
    exit 1
fi

# Load environment before install (non-interactive domain, CF settings, etc.)
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
wget -qO /tmp/genz.sh "${REPO}/genz.sh"
chmod +x /tmp/genz.sh
exec /tmp/genz.sh "$@"
