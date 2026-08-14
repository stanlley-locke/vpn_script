# Cloudflare & HTTP Custom Application Guide

**stanlley-locke/vpn_script**

This guide covers production deployment behind Cloudflare, including HTTP Custom Application routing for internet traffic.

---

## Architecture

```
Client / HTTP Custom App
    │
    ▼
Cloudflare Edge (proxied A record, orange cloud)
    │  SNI: vpn.example.com
    │  Headers: CF-Connecting-IP, Upgrade: websocket
    ▼
VPS :443 ─ HAProxy (TLS, SNI validation)
    │
    ├── WebSocket ──► Nginx :1010 ──► Xray (VLESS/VMess/Trojan/SS)
    ├── HTTP/2 gRPC ► Nginx :1013 ──► Xray (gRPC inbounds)
    ├── SSH WS ─────► ws.py :10015 ─► OpenSSH :22
    └── Decoy ──────► Nginx :81 (static site for probes)
```

---

## Initial Cloudflare Setup

Run on the VPS after install:

```bash
cf-setup
```

This wizard will:

1. Validate Cloudflare API credentials
2. Create/update proxied A record
3. Set SSL **Full**, enable **gRPC** and **WebSockets**
4. Sync Cloudflare IP ranges to nginx (`real_ip` / `CF-Connecting-IP`)
5. Optionally create a **Cloudflare Origin Certificate** (enables SSL **Strict**)

### Manual dashboard checklist

| Setting | Value |
|---------|-------|
| DNS A record | Proxied (orange cloud) |
| SSL/TLS | Full or Full (Strict) with origin cert |
| Network → gRPC | ON |
| Network → WebSockets | ON |
| Always Use HTTPS | OFF during install |
| HTTP/3 | ON (optional) |

---

## SNI Configuration

SNI (Server Name Indication) tells the client which hostname to present during TLS.

### Default

Clients use your proxy domain as SNI:

```
sni=vpn.example.com
servername=vpn.example.com
```

Set in `/etc/vpn_script/config`:

```bash
SNI_FRONTING=""   # empty = use proxy domain
```

### Custom SNI fronting

For advanced setups:

```bash
SNI_FRONTING="cdn.example.com"
```

Regenerate user links after changing SNI. Menu scripts use `${domain}` by default (legacy `bug.com` references removed).

---

## HTTP Custom Application

Cloudflare HTTP Custom Applications (Zero Trust / WARP routing) and similar clients route traffic through a **hostname + path + SNI** combination.

### Path prefix (obfuscation)

Add a custom path prefix so WebSocket paths are not obvious:

```bash
# /etc/vpn_script/config
HTTP_APP_PREFIX="/app/cdn"
PATH_VMESS="/vmess"
```

Effective client path: `/app/cdn/vmess`

Apply to nginx + xray:

```bash
apply-paths
# or menu → apply-paths
```

### Client configuration example (Clash Meta)

```yaml
- name: vmess-cf-app
  type: vmess
  server: vpn.example.com
  port: 443
  uuid: <uuid>
  alterId: 0
  cipher: auto
  tls: true
  skip-cert-verify: false
  servername: vpn.example.com
  network: ws
  ws-opts:
    path: /app/cdn/vmess
    headers:
      Host: vpn.example.com
```

### gRPC (HTTP/2)

```yaml
  network: grpc
  tls: true
  servername: vpn.example.com
  grpc-opts:
    grpc-service-name: vmess-grpc
```

Ensure Cloudflare **gRPC** is enabled for the zone.

---

## SSH WebSocket Tunneling

SSH is tunneled over WebSocket on port 443:

| Parameter | Value |
|-----------|-------|
| Host | Your domain |
| Port | 443 |
| Path | `/` (or custom via `PATH_SSH`) |
| Target | OpenSSH :22 via `ws.py` / `ws` binary |

Create SSH user via menu (`addssh`), then use an SSH-over-WS client (HTTP Injector, Napsternet, etc.) with:

- **Host header**: your domain
- **SNI**: your domain
- **TLS**: enabled

Check tunnel service:

```bash
systemctl status ws
ss -tlnp | grep 10015
```

---

## Traffic Routing Profiles

Control how Xray routes outbound traffic:

```bash
apply-routing global    # all via proxy (default)
apply-routing split     # CN/local direct, international proxy
apply-routing adblock   # block ads + direct
apply-routing direct    # passthrough
```

Or: `routing-profile` from menu.

Active profile stored in `/etc/xray/routing.active`.

---

## Decoy Site (Camouflage)

Non-WebSocket HTTP probes see a static page:

- Port **81** (direct TLS to VPS)
- `/var/www/html/index.html`

Customize title in config:

```bash
DECOY_SITE_TITLE="My Company Portal"
DECOY_SITE_ENABLED="1"
```

---

## Certificate Management

### Let's Encrypt (default install)

Auto-renew via cron (installed with stack):

```bash
cert-renew
```

### Cloudflare Origin Certificate (recommended for Strict)

```bash
cf-setup   # choose origin cert option
```

Then set Cloudflare SSL to **Full (Strict)**.

---

## Operations

| Command | Purpose |
|---------|---------|
| `health-check` | Services, ports, cert expiry |
| `reload-stack` | Restart xray, nginx, haproxy, ws |
| `cf-setup` | Cloudflare wizard |
| `apply-paths` | Apply HTTP Custom App path prefix |
| `apply-routing <profile>` | Switch routing rules |
| `cert-renew` | Renew TLS certificate |

---

## Troubleshooting

**502 / Cloudflare error**

- Confirm origin listens on 443: `ss -tlnp | grep 443`
- Check HAProxy: `systemctl status haproxy`
- Verify SNI matches domain in `/etc/haproxy/haproxy.cfg`

**WebSocket disconnects**

- Cloudflare WebSockets must be ON
- Increase timeouts (nginx `proxy_read_timeout 3600s` — already set)
- Client Host header must match domain

**gRPC fails**

- Enable gRPC in Cloudflare Network settings
- Use port 443, service name from menu output
- Client must support gRPC over TLS

**Wrong client IP in logs**

- Run `cf-setup` → sync Cloudflare IPs
- nginx uses `CF-Connecting-IP` header

---

## Security Recommendations

1. Use **Full (Strict)** with origin certificate
2. Enable SNI validation in HAProxy (only your domain accepted)
3. Set `LICENSE_CHECK=1` and maintain `keygen` for multi-tenant reselling
4. Rotate bot tokens; never commit secrets
5. Use `HTTP_APP_PREFIX` to avoid predictable paths
6. Run `health-check` after every config change
