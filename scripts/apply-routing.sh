#!/bin/bash
# Switch Xray routing profile — stanlley-locke/vpn_script
set -euo pipefail

[ -f /usr/local/lib/vpn_script/routing.sh ] && source /usr/local/lib/vpn_script/routing.sh

profile="${1:-}"
if [[ -z "$profile" ]]; then
    echo "Usage: apply-routing <profile>"
    echo "Available: $(vpn_list_routing_profiles | tr '\n' ' ')"
    exit 1
fi
vpn_apply_routing_profile "$profile"
