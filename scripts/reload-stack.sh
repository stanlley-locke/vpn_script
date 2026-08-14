#!/bin/bash
# Reload entire proxy stack — stanlley-locke/vpn_script
set -euo pipefail

systemctl daemon-reload
for svc in xray nginx haproxy ws dropbear fail2ban cron; do
    systemctl restart "$svc" 2>/dev/null || true
done
systemctl restart kyt 2>/dev/null || true
echo "Stack reloaded: xray nginx haproxy ws dropbear fail2ban cron"
