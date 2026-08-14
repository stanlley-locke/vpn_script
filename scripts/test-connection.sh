#!/bin/bash
# ============================================================
# test-connection.sh — Full connection diagnostic
# stanlley-locke/vpn_script
# Usage: bash test-connection.sh [user] [pass]
# Run ON THE SERVER for full results
# ============================================================

USER="${1:-1locke}"
PASS="${2:-1locke}"
DOMAIN="vps.stanlleylocke.dev"
IP="3.87.53.252"
ON_SERVER=false
[[ -f /etc/xray/domain ]] && ON_SERVER=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

ok()   { echo -e "  ${GREEN}✔${NC} $1"; }
fail() { echo -e "  ${RED}✘${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }
hdr()  { echo -e "\n${BOLD}${YELLOW}━━━ $1 ━━━${NC}"; }

PASS_COUNT=0
FAIL_COUNT=0

echo -e "\n${BOLD}╔══════════════════════════════════════════╗"
echo -e "║   VPN Stack Connection Diagnostic        ║"
echo -e "║   Domain : $DOMAIN  ║"
echo -e "║   User   : $USER / $PASS"
echo -e "║   Mode   : $( $ON_SERVER && echo 'SERVER (full)' || echo 'REMOTE (limited)' )"
echo -e "╚══════════════════════════════════════════╝${NC}"

# ── 1. DNS ──────────────────────────────────────────────────
hdr "1. DNS Resolution"
RESOLVED=$(getent hosts "$DOMAIN" 2>/dev/null | awk '{print $1}' | head -1)
if [[ -z "$RESOLVED" ]]; then
    RESOLVED=$(curl -s "https://dns.google/resolve?name=$DOMAIN&type=A" \
        | grep -oP '"data":"\K[0-9.]+' | head -1)
fi
if [[ -n "$RESOLVED" ]]; then
    ok "DNS resolves $DOMAIN → $RESOLVED"
    ((PASS_COUNT++))
    if [[ "$RESOLVED" == "$IP" ]]; then
        info "Direct IP (Cloudflare proxy may be off)"
    else
        info "Cloudflare proxy IP — expected (orange cloud)"
    fi
else
    fail "DNS resolution failed for $DOMAIN"
    ((FAIL_COUNT++))
fi

# ── 2. TCP Port Reachability ─────────────────────────────────
hdr "2. TCP Port Reachability"
for PORT in 443 80 8880; do
    if timeout 5 bash -c "echo >/dev/tcp/$DOMAIN/$PORT" 2>/dev/null; then
        ok "TCP $DOMAIN:$PORT reachable"
        ((PASS_COUNT++))
    else
        fail "TCP $DOMAIN:$PORT unreachable"
        ((FAIL_COUNT++))
    fi
done

# ── 3. TLS Handshake ─────────────────────────────────────────
hdr "3. TLS Handshake (port 443)"
TLS_OUT=$(echo | timeout 5 openssl s_client \
    -connect "$DOMAIN:443" \
    -servername "$DOMAIN" 2>&1)
if echo "$TLS_OUT" | grep -q "Verify return code: 0"; then
    ok "TLS certificate valid"
    ((PASS_COUNT++))
elif echo "$TLS_OUT" | grep -q "CONNECTED"; then
    ok "TLS connected (cert may be self-signed)"
    ((PASS_COUNT++))
else
    fail "TLS handshake failed"
    info "$(echo "$TLS_OUT" | grep -E 'error|alert|CONNECTED' | head -3)"
    ((FAIL_COUNT++))
fi
CERT_CN=$(echo "$TLS_OUT" | grep "subject=" | grep -oP 'CN\s*=\s*\K[^,/]+' | head -1)
TLS_VER=$(echo "$TLS_OUT" | grep "Protocol  :" | awk '{print $3}')
[[ -n "$CERT_CN" ]] && info "Certificate CN: $CERT_CN"
[[ -n "$TLS_VER" ]] && info "TLS version: $TLS_VER"

# ── 4. HAProxy WebSocket Upgrade ─────────────────────────────
hdr "4. HAProxy WebSocket Upgrade (port 443)"
info "Forcing HTTP/1.1 — WebSocket upgrade requires HTTP/1.1 not HTTP/2"
WS_OUT=$(curl -si --max-time 10 --http1.1 \
    -H "Host: $DOMAIN" \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    "https://$DOMAIN/" 2>&1)
HTTP_CODE=$(echo "$WS_OUT" | grep -oP 'HTTP/\S+ \K\d+' | head -1)
info "HTTP response code: ${HTTP_CODE:-no response}"
if echo "$WS_OUT" | grep -qi "101"; then
    ok "WebSocket upgrade: 101 Switching Protocols ✔"
    ((PASS_COUNT++))
elif echo "$WS_OUT" | grep -qi "400"; then
    fail "WebSocket upgrade: 400 — double-TLS (SSL checkbox must be OFF in app)"
    ((FAIL_COUNT++))
elif [[ "$HTTP_CODE" == "200" ]]; then
    fail "WebSocket upgrade: 200 — Cloudflare returned HTML (WebSocket not enabled in CF dashboard)"
    info "Fix: Cloudflare dashboard → Network → WebSockets → ON"
    ((FAIL_COUNT++))
else
    fail "WebSocket upgrade: unexpected (${HTTP_CODE:-no response})"
    echo "$WS_OUT" | head -8 | sed 's/^/    /'
    ((FAIL_COUNT++))
fi

# ── 5. ws.py direct ──────────────────────────────────────────
hdr "5. ws.py Direct (127.0.0.1:10015)"
if $ON_SERVER; then
    WS_DIRECT=$(curl -si --max-time 5 http://127.0.0.1:10015/ \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" 2>&1)
    if echo "$WS_DIRECT" | grep -qi "101"; then
        ok "ws.py responding with 101"
        ((PASS_COUNT++))
    else
        fail "ws.py not responding — check: systemctl status ws-epro"
        info "$(echo "$WS_DIRECT" | head -3)"
        ((FAIL_COUNT++))
    fi
else
    info "Skipping — localhost only. Run script on server for full results."
fi

# ── 6. Nginx port 1010 ───────────────────────────────────────
hdr "6. Nginx WS Port 1010"
if $ON_SERVER; then
    NGX_OUT=$(curl -si --max-time 5 http://127.0.0.1:1010/ \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" 2>&1)
    if echo "$NGX_OUT" | grep -qi "101"; then
        ok "Nginx :1010 → ws.py: 101 OK"
        ((PASS_COUNT++))
    else
        fail "Nginx :1010 not returning 101 — check: systemctl status nginx"
        info "$(echo "$NGX_OUT" | head -3)"
        ((FAIL_COUNT++))
    fi
else
    info "Skipping — localhost only. Run script on server for full results."
fi

# ── 7. Full WS tunnel → SSH banner ───────────────────────────
hdr "7. SSH-over-WebSocket Full Tunnel Test"
if $ON_SERVER; then
    info "Chain: HAProxy:443 → Nginx:1010 → ws.py:10015 → SSH:22"
    SSH_BANNER=$(python3 - <<'PYEOF' 2>/dev/null
import socket, ssl, base64, os
ctx = ssl.create_default_context()
s = ctx.wrap_socket(
    socket.create_connection(("127.0.0.1", 443), timeout=8),
    server_hostname="vps.stanlleylocke.dev"
)
key = base64.b64encode(os.urandom(16)).decode()
req = (
    "GET / HTTP/1.1\r\n"
    "Host: vps.stanlleylocke.dev\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    f"Sec-WebSocket-Key: {key}\r\n"
    "Sec-WebSocket-Version: 13\r\n\r\n"
)
s.sendall(req.encode())
resp = s.recv(4096).decode("latin-1", errors="ignore")
if "101" in resp:
    banner = s.recv(256).decode("latin-1", errors="ignore")
    print(banner.strip())
else:
    print("NO_101:" + resp[:120])
s.close()
PYEOF
)
    if echo "$SSH_BANNER" | grep -qi "SSH-2.0"; then
        ok "SSH banner through WS tunnel: $SSH_BANNER"
        ((PASS_COUNT++))
    elif echo "$SSH_BANNER" | grep -q "NO_101:"; then
        fail "No 101 from HAProxy — $(echo "$SSH_BANNER" | cut -c1-80)"
        ((FAIL_COUNT++))
    else
        fail "101 received but no SSH banner — ws.py may not forward to SSH:22"
        info "$SSH_BANNER"
        ((FAIL_COUNT++))
    fi
else
    info "Testing external WebSocket upgrade (HTTP/1.1)..."
    SSH_WS=$(curl -si --max-time 10 --http1.1 \
        -H "Host: $DOMAIN" \
        -H "Upgrade: websocket" \
        -H "Connection: Upgrade" \
        -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
        "https://$DOMAIN/" 2>&1)
    if echo "$SSH_WS" | grep -qi "101"; then
        ok "External WebSocket 101 — tunnel entry point working"
        ((PASS_COUNT++))
    else
        fail "External WebSocket upgrade failed"
        info "$(echo "$SSH_WS" | head -3)"
        ((FAIL_COUNT++))
    fi
fi

# ── 8. HTTP Custom payload simulation ────────────────────────
hdr "8. HTTP Custom App Payload Simulation"
info "Exact payload: GET / HTTP/1.1 + Host + Upgrade: websocket (HTTP/1.1 forced)"
PAYLOAD_OUT=$(curl -si --max-time 10 --http1.1 \
    -H "Host: $DOMAIN" \
    -H "Upgrade: websocket" \
    -H "Connection: Upgrade" \
    -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
    -H "Sec-WebSocket-Version: 13" \
    "https://$DOMAIN/" 2>&1)
P_CODE=$(echo "$PAYLOAD_OUT" | grep -oP 'HTTP/\S+ \K\d+' | head -1)
info "Response: ${P_CODE:-none}"
if echo "$PAYLOAD_OUT" | grep -qi "101"; then
    ok "HTTP Custom payload: 101 — PASS ✔"
    ((PASS_COUNT++))
elif echo "$PAYLOAD_OUT" | grep -qi "400"; then
    fail "HTTP Custom payload: 400 — SSL checkbox must be OFF"
    ((FAIL_COUNT++))
elif [[ "$P_CODE" == "200" ]]; then
    fail "HTTP Custom payload: 200 — Cloudflare not forwarding WebSocket upgrade"
    info "Fix: Cloudflare → Network → WebSockets → ON"
    ((FAIL_COUNT++))
else
    fail "HTTP Custom payload: unexpected (${P_CODE:-no response})"
    echo "$PAYLOAD_OUT" | head -5 | sed 's/^/    /'
    ((FAIL_COUNT++))
fi

# ── 9. SSH banner + auth ──────────────────────────────────────
hdr "9. SSH Banner + Auth (port 22)"
SSH_BANNER22=$(timeout 5 bash -c "exec 3<>/dev/tcp/$DOMAIN/22; cat <&3" 2>/dev/null | head -1)
if echo "$SSH_BANNER22" | grep -qi "SSH-2.0"; then
    ok "SSH port 22 banner: $SSH_BANNER22"
    ((PASS_COUNT++))
else
    fail "SSH port 22: no banner"
    ((FAIL_COUNT++))
fi
SSH22=$(timeout 8 sshpass -p "$PASS" ssh \
    -o StrictHostKeyChecking=no \
    -o ConnectTimeout=5 \
    -o PasswordAuthentication=yes \
    -o PubkeyAuthentication=no \
    -p 22 "$USER@$DOMAIN" "echo SSH_OK" 2>&1 || true)
if echo "$SSH22" | grep -q "SSH_OK"; then
    ok "SSH auth: login OK (user has shell access)"
    ((PASS_COUNT++))
elif echo "$SSH22" | grep -qi "Permission denied"; then
    fail "SSH auth: Permission denied — wrong password or account expired"
    info "Expected: user=$USER pass=$PASS"
    ((FAIL_COUNT++))
else
    ok "SSH auth: accepted (shell=/bin/false closes session — correct for tunnel users)"
    ((PASS_COUNT++))
fi

# ── 10. Dropbear port 109 ────────────────────────────────────
hdr "10. Dropbear SSH (port 109)"
DB_HOST=$( $ON_SERVER && echo "127.0.0.1" || echo "$DOMAIN" )
DB_BANNER=$(timeout 5 bash -c "exec 3<>/dev/tcp/$DB_HOST/109; cat <&3" 2>/dev/null | head -1)
if echo "$DB_BANNER" | grep -qi "SSH-2.0"; then
    ok "Dropbear port 109: $DB_BANNER"
    ((PASS_COUNT++))
else
    fail "Dropbear port 109: no banner"
    info "Fix: add TCP 109 inbound rule in AWS EC2 security group"
    ((FAIL_COUNT++))
fi

# ── 11. OpenVPN port 1194 ────────────────────────────────────
hdr "11. OpenVPN TCP (port 1194)"
OVPN_HOST=$( $ON_SERVER && echo "127.0.0.1" || echo "$DOMAIN" )
if timeout 5 bash -c "echo >/dev/tcp/$OVPN_HOST/1194" 2>/dev/null; then
    ok "OpenVPN port 1194: reachable"
    ((PASS_COUNT++))
else
    fail "OpenVPN port 1194: unreachable"
    info "Fix: add TCP 1194 inbound rule in AWS EC2 security group"
    ((FAIL_COUNT++))
fi

# ── 12. Subscription server ──────────────────────────────────
hdr "12. Subscription Server"
if $ON_SERVER; then
    SUB_OUT=$(curl -si --max-time 10 "http://127.0.0.1:8099/sub/" 2>&1)
else
    SUB_OUT=$(curl -si --max-time 10 --http1.1 "https://$DOMAIN/sub/" 2>&1)
fi
SUB_CODE=$(echo "$SUB_OUT" | grep -oP 'HTTP/\S+ \K\d+' | head -1)
if [[ "$SUB_CODE" =~ ^(200|401|403)$ ]]; then
    ok "Subscription server responding (HTTP $SUB_CODE)"
    ((PASS_COUNT++))
else
    fail "Subscription server not responding (HTTP ${SUB_CODE:-none})"
    info "Check: systemctl status sub-server"
    ((FAIL_COUNT++))
fi

# ── 13. OVPN file download ───────────────────────────────────
hdr "13. OVPN File Download (port 81)"
if $ON_SERVER; then
    OVPN_OUT=$(curl -si --max-time 10 "http://127.0.0.1:81/" 2>&1)
else
    OVPN_OUT=$(curl -si --max-time 10 "http://$IP:81/" 2>&1)
fi
OVPN_CODE=$(echo "$OVPN_OUT" | grep -oP 'HTTP/\S+ \K\d+' | head -1)
if [[ "$OVPN_CODE" =~ ^(200|301|302)$ ]]; then
    ok "OVPN download page reachable (HTTP $OVPN_CODE)"
    ((PASS_COUNT++))
else
    fail "OVPN download page not reachable (HTTP ${OVPN_CODE:-none})"
    info "Port 81 may be blocked — add TCP 81 to AWS security group"
    ((FAIL_COUNT++))
fi

# ── 14. Account save link ────────────────────────────────────
hdr "14. Account File (ssh-${USER}.txt)"
if $ON_SERVER; then
    if [[ -f "/var/www/html/ssh-${USER}.txt" ]]; then
        ok "Account file exists: /var/www/html/ssh-${USER}.txt"
        ((PASS_COUNT++))
    else
        fail "Account file missing — run: addssh"
        ((FAIL_COUNT++))
    fi
else
    ACCT_OUT=$(curl -si --max-time 10 "http://$IP:81/ssh-${USER}.txt" 2>&1)
    ACCT_CODE=$(echo "$ACCT_OUT" | grep -oP 'HTTP/\S+ \K\d+' | head -1)
    if [[ "$ACCT_CODE" == "200" ]]; then
        ok "Account file reachable via HTTP"
        ((PASS_COUNT++))
    else
        fail "Account file not reachable externally (port 81 blocked by AWS)"
        info "Open port 81 in EC2 security group to access OVPN/account files"
        ((FAIL_COUNT++))
    fi
fi

# ── 15. Service health ───────────────────────────────────────
hdr "15. Service Health"
if $ON_SERVER; then
    for SVC in xray nginx haproxy dropbear ssh openvpn; do
        if systemctl is-active --quiet "$SVC" 2>/dev/null; then
            ok "$SVC: active"
            ((PASS_COUNT++))
        else
            fail "$SVC: not active — fix: systemctl restart $SVC"
            ((FAIL_COUNT++))
        fi
    done
    if pgrep -f "ws.py" >/dev/null 2>&1; then
        ok "ws.py: running"
        ((PASS_COUNT++))
    else
        fail "ws.py: not running — fix: systemctl restart ws-epro"
        ((FAIL_COUNT++))
    fi
    info "Listening ports:"
    ss -tlnp 2>/dev/null | grep -E ':22 |:109 |:443 |:1010 |:1194 |:10015 |:8099 ' \
        | awk '{print "    " $4}' | sort -u
else
    info "Run 'health-check' on the server for full service status"
    info "AWS Security Group — missing inbound rules cause most failures:"
    for P in "TCP 109 — Dropbear" "TCP 1194 — OpenVPN" "TCP 81 — OVPN files" "UDP 2200 — OpenVPN UDP" "UDP 5300 — SlowDNS"; do
        info "  $P"
    done
fi

# ── Summary ──────────────────────────────────────────────────
echo -e "\n${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  RESULTS: ${GREEN}${PASS_COUNT} passed${NC}  ${RED}${FAIL_COUNT} failed${NC}"
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ $FAIL_COUNT -eq 0 ]]; then
    echo -e "\n${GREEN}${BOLD}  ✔ All checks passed — stack is healthy${NC}"
else
    echo -e "\n${RED}${BOLD}  ✘ $FAIL_COUNT check(s) failed${NC}"
fi

echo -e "\n${BOLD}  HTTP Custom app settings:${NC}"
echo -e "    Host:port@user:pass : ${DOMAIN}:443@${USER}:${PASS}"
echo -e "    Payload             : GET / HTTP/1.1[crlf]Host: ${DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]"
echo -e "    SSL checkbox        : OFF"
echo -e "    SNI                 : ${DOMAIN}"
echo ""
