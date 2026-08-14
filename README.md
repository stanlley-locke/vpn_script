# VPN Script

Multi-protocol proxy and VPN auto-installer for Debian/Ubuntu VPS servers.

**Author:** [stanlley_locke](https://github.com/stanlley_locke)  
**Repository:** [stanlley_locke/vpn_script](https://github.com/stanlley_locke/vpn_script)

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

Designed for use with **Cloudflare** (proxied domain, Full SSL, WebSocket + gRPC enabled).

---

## Requirements

| Item | Details |
|------|---------|
| OS | Debian 10+ or Ubuntu 18.04 – 24.04 |
| Arch | x86_64 |
| Access | Root SSH |
| Domain | Subdomain on Cloudflare (e.g. `vpn.example.com`) |
| Ports | 22, 80, 443, 8880, 1194, 5300 open on VPS firewall |

**Not supported:** OpenVZ, GitHub Codespaces, non-root containers.

---

## Quick Install

On a **fresh VPS as root**:

```bash
apt update -y && apt install -y wget curl
wget -q https://raw.githubusercontent.com/stanlley_locke/vpn_script/main/genz.sh
chmod +x genz.sh
./genz.sh
```

Or one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/stanlley_locke/vpn_script/main/install.sh | bash
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

The bot can create/delete users, check accounts, reboot the VPS, run speed tests, and manage backups.

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
VPN_AUTHOR="stanlley_locke"
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
| VLESS / VMess | 80 | Non-TLS |
| SSH | 443 (WS), 8880 | WebSocket / plain |
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
| `update.sh` | Update menu scripts from GitHub |
| `restart` | Restart all services |

---

## Repository Structure

```
vpn_script/
├── genz.sh              # Main installer
├── install.sh           # One-liner entry point
├── update.sh            # Update admin menu
├── kyt.sh               # Telegram bot installer
├── health-check.sh      # Service health check
├── keygen               # Optional IP license whitelist
├── lib/
│   ├── common.sh        # Shared functions (license, notify, repo URL)
│   └── config.defaults  # Default runtime config template
└── ubuntu/
    ├── config.json      # Xray configuration template
    ├── xray.conf        # Nginx reverse proxy paths
    ├── haproxy.cfg      # HAProxy TLS front-end
    ├── ws.py            # SSH WebSocket proxy (Python 3)
    ├── cf.sh            # Cloudflare DNS helper
    ├── menu/            # Admin CLI scripts (66 tools)
    ├── kyt/             # Telegram bot source
    ├── bot/             # Bot shell helpers
    ├── menu.zip         # Packaged menu (installed to /usr/local/sbin)
    ├── kyt.zip          # Packaged bot
    └── bot.zip          # Bot helper scripts
```

Previously these lived only inside zip archives. They are now **extracted, inspectable, and editable** in the repo. Zips are rebuilt from source on release.

---

## Architecture

```
Client
  └── Cloudflare (your domain)
        └── HAProxy :443 (TLS)
              ├── Nginx → Xray (127.0.0.1:10001–10008)
              │         VLESS / VMess / Trojan / SS (WS + gRPC)
              ├── ws.py → SSH :22 (WebSocket tunnel)
              └── OpenVPN :1194
```

Cron jobs handle:

- Account expiry (`xp`) — daily 00:02
- Log cleanup — every 1–20 minutes
- IP limits — every 2 minutes
- Daily reboot — 05:00 (configurable in profile)

---

## Updates

```bash
wget -q https://raw.githubusercontent.com/stanlley_locke/vpn_script/main/update.sh
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
git clone https://github.com/stanlley_locke/vpn_script.git
cd vpn_script/ubuntu
# edit menu/, kyt/, bot/
zip -rq menu.zip menu && zip -rq kyt.zip kyt && zip -rq bot.zip bot
```

Point a test VPS at your fork by setting in `genz.sh` or env:

```bash
export VPN_GITHUB_USER=stanlley_locke
export VPN_REPO_NAME=vpn_script
```

---

## License

This project is maintained by **stanlley_locke**. Use responsibly and in compliance with your VPS provider's terms of service and local laws.

---

## Support

- **GitHub Issues:** [stanlley_locke/vpn_script/issues](https://github.com/stanlley_locke/vpn_script/issues)
- **Author:** [@stanlley_locke](https://github.com/stanlley_locke)
