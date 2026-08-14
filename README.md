# VPN Script

Multi-protocol proxy and VPN auto-installer for Debian/Ubuntu VPS servers.

**Author:** [stanlley-locke](https://github.com/stanlley-locke)  
**Repository:** [stanlley-locke/vpn_script](https://github.com/stanlley-locke/vpn_script)

---

## Overview

VPN Script turns a fresh VPS into a full proxy stack behind Cloudflare. It installs and configures:

- **Xray Core** — VLESS, VMess, Trojan, Shadowsocks (WebSocket + gRPC)
- **HAProxy** — TLS termination on port 443
- **Nginx** — WebSocket/gRPC reverse proxy
- **SSH over WebSocket** — tunnel SSH through port 443
- **OpenVPN** — classic VPN (TCP 1194)
- **SlowDNS** — DNS tunnel (UDP 5300)
- **Dropbear + OpenSSH** — dual SSH daemons
- **Fail2ban**, BBR tuning, swap, log rotation, account expiry
- **CLI admin menu** — create/delete users, quotas, backups
- **Telegram bot panel** — optional remote management via `kyt`
- **Subscription URL** — `/sub/<token>` for Hiddify, Sing-box, v2rayNG auto-import
- **REALITY inbound** — VLESS over REALITY on port 8443 (harder to detect than WS)
- **Cloudflare Tunnel** — `cloudflared` to hide origin IP completely
- **HTTP Custom library** — 26 payloads, 15 carrier profiles (Safaricom, Airtel, MTN, Vodacom)

Designed for use with **Cloudflare** (proxied domain, Full SSL, WebSocket + gRPC enabled).

📖 **Full guides:** [SETUP.md](SETUP.md) · [TECHNICAL.md](TECHNICAL.md) · [EC2 example](docs/EC2-vps.stanlleylocke.dev.md)

### Environment file (recommended for EC2 / non-interactive install)

```bash
cp examples/vps.stanlleylocke.dev.env /root/vpn_script.env
nano /root/vpn_script.env          # add CF API / Telegram tokens if needed
set -a && source /root/vpn_script.env && set +a
curl -fsSL .../install.sh | bash   # skips domain prompt when VPN_DOMAIN is set
```

See [`.env.example`](.env.example) for all variables.

---

## Requirements

| Item | Details |
|------|---------|
| OS | Debian 10+ or Ubuntu 18.04 – 24.04 |
| Arch | x86_64 |
| Access | Root SSH |
| Domain | Subdomain on Cloudflare (e.g. `vps.stanlleylocke.dev`) |
| Ports | 22, 80, 443, 8880, 1194, 5300 open on VPS firewall |

**Not supported:** OpenVZ, GitHub Codespaces, non-root containers.

---

## Quick Install

On a **fresh VPS as root**:

```bash
apt update -y && apt install -y wget curl
wget -q https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/genz.sh
chmod +x genz.sh
./genz.sh
```

Or one-liner with env file:

```bash
curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/scripts/ec2-install.sh | sudo bash
```

During install you will be asked for:

1. **Domain** — use your own subdomain (recommended) or auto Cloudflare subdomain
2. Press Enter to start — install takes ~10–20 minutes, then reboots

After reboot, SSH login opens the **`menu`** automatically.

---

## Cloudflare Setup

### DNS

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `vpn` | Your VPS IP | Proxied (orange cloud) |

### SSL/TLS Settings

| Setting | Value |
|---------|-------|
| SSL/TLS mode | **Full** |
| gRPC | **ON** |
| WebSockets | **ON** |
| Always Use HTTPS | **OFF** (during install) |
| Under Attack Mode | **OFF** |

### HTTP Custom Application / Zero Trust

If you use a Cloudflare custom HTTP application or tunnel, point it at the **same hostname** as your proxy. Ensure WebSocket upgrades and gRPC are forwarded to the origin — the script routes paths like `/vless`, `/vmess`, `/trojan-ws` through Nginx to Xray.

---

## Telegram Bot Panel

### Install after base setup

```bash
kyt.sh
# or from menu: add-bot-panel → option 1
```

You need:

- **Bot token** from [@BotFather](https://t.me/BotFather)
- **Your Telegram user ID** from [@userinfobot](https://t.me/userinfobot)

Then message your bot: `/menu`

The bot can create/delete users, check accounts, reboot the VPS, run speed tests, manage backups, and **export HTTP Custom v5 profiles** (`/httpcustom` or **HTTP CUSTOM** button in menu).

---

## Configuration

Runtime config lives at `/etc/vpn_script/config` (created on install):

```bash
# License: 0 = disabled (default for self-hosted), 1 = check keygen on GitHub
LICENSE_CHECK="0"

# Optional install notification (your bot only)
INSTALL_NOTIFY="0"
TELEGRAM_BOT_TOKEN=""
TELEGRAM_CHAT_ID=""

# Branding
VPN_SCRIPT_NAME="VPN Script"
VPN_AUTHOR="stanlley-locke"
```

Edit and apply:

```bash
nano /etc/vpn_script/config
systemctl restart kyt   # if bot is running
```

### License whitelist (optional)

If `LICENSE_CHECK=1`, add VPS IPs to [`keygen`](keygen):

```text
### username 2099-12-31 203.0.113.10
```

Format: `### name YYYY-M-D IP_ADDRESS`

---

## Ports & Protocols

| Service | Port | Transport |
|---------|------|-----------|
| VLESS / VMess / Trojan / SS | 443 | WebSocket + gRPC |
| VLESS REALITY | 8443 | TCP + REALITY |
| VLESS / VMess | 80 | Non-TLS |
| SSH | 443 (WS), 8880 | WebSocket / plain |
| Subscription | 443 `/sub/<token>` | HTTPS → local :8099 |
| OpenVPN | 1194 | TCP/SSL |
| SlowDNS | 5300 | UDP |

---

## Admin Commands

After install, these are available in `/usr/local/sbin/`:

| Command | Description |
|---------|-------------|
| `menu` | Main admin panel |
| `addvless` / `addws` / `addssh` / `addtr` / `addss` | Create users |
| `delvless` / `delws` / … | Delete users |
| `add-bot-panel` | Install/manage Telegram bot |
| `health-check` | Verify services and ports |
| `sub-manage` | Subscription URL generate/show/test |
| `reality-setup` | REALITY keys and users |
| `cf-tunnel` | Cloudflare Tunnel (cloudflared) |
| `httpcustom-export` | Export HTTP Custom v5 JSON |
| `update.sh` | Update menu scripts from GitHub |
| `restart` | Restart all services |

### New menu options (26–33)

| # | Feature |
|---|---------|
| 31 | REALITY inbound |
| 32 | Subscription URL |
| 33 | Cloudflare Tunnel |

---

## Repository Structure

```
vpn_script/
├── genz.sh              # Main installer
├── SETUP.md             # Step-by-step setup (VPS → HTTP Custom app)
├── TECHNICAL.md         # Architecture & functionality
├── install.sh           # One-liner entry point
├── update.sh            # Update admin menu
├── kyt.sh               # Telegram bot installer
├── health-check.sh      # Service health check
├── keygen               # Optional IP license whitelist
├── lib/
│   ├── common.sh        # Shared functions (license, notify, repo URL)
│   ├── cloudflare.sh, httpcustom.sh, routing.sh, linkgen.sh
│   ├── config.defaults  # Default runtime config template
│   └── httpcustom/      # Payload library (JSON)
├── scripts/
│   ├── cf-setup.sh, cf-tunnel.sh, reality-setup.sh, sub-manage.sh
│   └── httpcustom-export*.sh, health-check.sh, reload-stack.sh
└── ubuntu/
    ├── config.json      # Xray configuration template
    ├── subscription/    # Subscription server (Python)
    ├── subscription.conf
    ├── xray.conf        # Nginx reverse proxy paths
    ├── haproxy.cfg      # HAProxy TLS front-end
    ├── ws.py            # SSH WebSocket proxy (Python 3)
    ├── routing/         # Xray routing profiles
    ├── menu/            # Admin CLI scripts
    ├── kyt/             # Telegram bot source (+ httpcustom.py)
    ├── menu.zip         # Packaged menu
    └── kyt.zip          # Packaged bot
```

Previously these lived only inside zip archives. They are now **extracted, inspectable, and editable** in the repo. Zips are rebuilt from source on release.

---

## Architecture

```
Client
  └── Cloudflare (DNS proxy or Tunnel)
        └── HAProxy :443 (TLS)
              ├── Nginx → Xray (127.0.0.1:10001–10008)
              │         VLESS / VMess / Trojan / SS (WS + gRPC)
              ├── Nginx → sub_server.py (/sub/<token>)
              ├── ws.py → SSH :22 (WebSocket tunnel)
              ├── Xray :8443 REALITY (direct, no WS)
              └── OpenVPN :1194
```

Cron jobs handle:

- Account expiry (`xp`) — daily 00:02
- Log cleanup — every 1–20 minutes
- IP limits — every 2 minutes
- Daily reboot — 05:00 (configurable in profile)

---

## Production Features

| Feature | Command / Config | Description |
|---------|------------------|-------------|
| Subscription URL | `sub-manage`, menu **32** | Base64 feed for Hiddify/Sing-box at `/sub/<token>` |
| REALITY inbound | `reality-setup`, menu **31** | VLESS REALITY on :8443 |
| Cloudflare Tunnel | `cf-tunnel`, menu **33** | Hide origin IP via cloudflared |
| Cloudflare wizard | `cf-setup` | DNS, SSL, gRPC, WS, origin cert, real IP sync |
| HTTP Custom App paths | `HTTP_APP_PREFIX` + `apply-paths` | Custom WS path prefix for CF HTTP apps |
| SNI control | `SNI_FRONTING` in config | Client TLS SNI / servername |
| Routing profiles | `routing-profile` or `apply-routing` | global / split / adblock / direct |
| Decoy site | port 81, `/var/www/html` | Camouflage for HTTP probes |
| HAProxy SNI filter | `haproxy.cfg` | Rejects TLS with wrong SNI |
| CF real IP | `cloudflare-ips.conf` | nginx logs true client via `CF-Connecting-IP` |
| Cert auto-renew | weekly cron | `cert-renew` (Let's Encrypt / acme.sh) |
| Stack reload | `reload-stack` | Restart all proxy services |
| Telegram HTTP Custom | `/httpcustom` in bot | Export carrier profiles as JSON |

Full guide: [docs/CLOUDFLARE.md](docs/CLOUDFLARE.md)

### HTTP Custom payload library

```bash
httpcustom-lib                                    # interactive browser
httpc-export-v5 profile-v5-cf-ray-ssh user pass  # export JSON + text
httpc-lib search safaricom                        # search library
```

26 payloads, 25+ SNI hosts, 16 proxies, **15 v5 profiles** (Safaricom, Airtel KE/NG/UG/TZ, MTN NG/GH/ZA, Vodacom ZA/TZ, CF-RAY, YouTube).  
Guide: [docs/HTTPCUSTOM.md](docs/HTTPCUSTOM.md) · Setup: [SETUP.md](SETUP.md#12-configure-http-custom-app-on-android)

### HTTP Custom Application example

```bash
# /etc/vpn_script/config
HTTP_APP_PREFIX="/app/cdn"
apply-paths
```

Client WebSocket path becomes `/app/cdn/vmess` instead of `/vmess`.

### SNI example

```bash
SNI_FRONTING="vpn.example.com"   # empty = use proxy domain
```

---

## Updates

```bash
wget -q https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/update.sh
chmod +x update.sh
./update.sh
```

Or from menu → update option.

---

## Health Check

```bash
health-check
```

Reports status of `xray`, `nginx`, `haproxy`, `cron`, `fail2ban`, and key ports.

---

## Bugs Fixed in This Fork

| Issue | Fix |
|-------|-----|
| Missing `password_default` function | Added — generates root password to `/root/.default-pass` |
| `add-bot-panel` wrong case labels (`02 \| 3`) | Fixed menu option routing |
| Hardcoded third-party Telegram bot token | Removed — uses `/etc/vpn_script/config` or bot DB |
| IP license always enforced | Disabled by default (`LICENSE_CHECK=0`) |
| `ws.py` Python 2 syntax | Rewritten for Python 3 |
| `kyt` broken `var.txt` path | Uses `/usr/bin/kyt/var.txt` with fallback |
| `setting.py` restore used undefined `$z` | Fixed to use `$a` |
| Ubuntu 24.04 blocked | Supported |
| External `fv-tunnel` dependency | Bundled in repo |
| Menu sources only in zip | Extracted to `ubuntu/menu/` |

---

## Security Notes

- Change the root password after install: `passwd root`
- Remove `/root/.default-pass` after noting the password
- Set your own `TELEGRAM_BOT_TOKEN` — never commit tokens
- Review `keygen` before enabling `LICENSE_CHECK=1`
- The installer removes UFW/firewalld — configure your cloud provider firewall instead

---

## Troubleshooting

**Install fails on license check**

```bash
# On VPS before install, or edit after:
echo 'LICENSE_CHECK="0"' >> /etc/vpn_script/config
```

**Services not running after reboot**

```bash
health-check
restart
systemctl status xray nginx haproxy
```

**Client cannot connect through Cloudflare**

- Confirm SSL/TLS is **Full** (not Strict until cert is valid)
- Enable WebSockets and gRPC in Cloudflare dashboard
- Verify A record is proxied (orange cloud)
- Check path matches menu output (`/vless`, `/vmess`, etc.)

**Bot not responding**

```bash
systemctl status kyt
journalctl -u kyt -f
cat /usr/bin/kyt/var.txt   # verify token and admin ID
```

---

## Development

Clone and edit menu/bot sources directly:

```bash
git clone https://github.com/stanlley-locke/vpn_script.git
cd vpn_script/ubuntu
# edit menu/, kyt/, bot/
zip -rq menu.zip menu && zip -rq kyt.zip kyt && zip -rq bot.zip bot
```

Point a test VPS at your fork by setting in `genz.sh` or env:

```bash
export VPN_GITHUB_USER=stanlley-locke
export VPN_REPO_NAME=vpn_script
```

---

## License

This project is maintained by **stanlley-locke**. Use responsibly and in compliance with your VPS provider's terms of service and local laws.

---

## Support

- **GitHub Issues:** [stanlley-locke/vpn_script/issues](https://github.com/stanlley-locke/vpn_script/issues)
- **Author:** [@stanlley-locke](https://github.com/stanlley-locke)
