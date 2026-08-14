#!/bin/bash
# Export HTTP Custom v5 profile for SSH user — stanlley-locke/vpn_script
set -euo pipefail

source /usr/local/lib/vpn_script/httpcustom.sh 2>/dev/null \
    || source "$(dirname "$0")/../lib/httpcustom.sh"

PROFILE="${1:-profile-v5-production-ssh}"
SSH_USER="${2:-}"
SSH_PASS="${3:-}"
OUT="${4:-/var/www/html/httpcustom-${SSH_USER:-export}.json}"

if [[ -z "$SSH_USER" ]]; then
    read -rp "SSH username: " SSH_USER
    read -rsp "SSH password: " SSH_PASS
    echo ""
fi

mkdir -p "$(dirname "$OUT")"
httpc_export_v5 "$PROFILE" "$OUT" "$SSH_USER" "$SSH_PASS"
httpc_export_text "$PROFILE" "$SSH_USER" "$SSH_PASS"

domain=$(httpc_domain)
echo ""
echo "Text config saved. JSON: ${OUT}"
echo "URL: http://${domain}/$(basename "$OUT")  (if port 81/decoy reachable)"
