# VPN Script — Complete Setup Guide

Step-by-step installation from a fresh VPS through HTTP Custom app configuration.

**Author:** [stanlley-locke](https://github.com/stanlley-locke)  
**Repository:** [stanlley-locke/vpn_script](https://github.com/stanlley-locke/vpn_script)

---

## Table of contents

1. [Prerequisites](#1-prerequisites)
2. [Environment file (recommended)](#2-environment-file-recommended)
3. [Get a VPS](#3-get-a-vps)
4. [Register a domain on Cloudflare](#4-register-a-domain-on-cloudflare)
5. [Install VPN Script](#5-install-vpn-script)
6. [Post-install: Cloudflare DNS & SSL](#6-post-install-cloudflare-dns--ssl)
6. [Optional: Cloudflare Tunnel (hide origin IP)](#6-optional-cloudflare-tunnel-hide-origin-ip)
7. [Create your first users](#7-create-your-first-users)
8. [Subscription URL (Hiddify / Sing-box)](#8-subscription-url-hiddify--sing-box)
9. [REALITY inbound](#9-reality-inbound)
10. [Telegram bot panel](#10-telegram-bot-panel)
11. [HTTP Custom library (menu)](#11-http-custom-library-menu)
12. [Configure HTTP Custom app on Android](#12-configure-http-custom-app-on-android)
13. [Cloudflare custom HTTP application](#13-cloudflare-custom-http-application)
14. [Troubleshooting](#14-troubleshooting)

---

## 1. Prerequisites

| Requirement | Details |
|-------------|---------|
| VPS | Debian 10+ or Ubuntu 18.04–24.04, **x86_64**, root SSH |
| Domain | Any domain added to **Cloudflare** (free plan works) |
| Client apps | HTTP Custom (Android), Hiddify/Sing-box/v2rayNG (optional) |
| Firewall | Open ports: **22, 80, 443, 8443** (8443 = REALITY), 1194, 8880 |

**Does not work on:** GitHub Codespaces, OpenVZ, non-root containers.

> **AWS EC2 example:** See [docs/EC2-vps.stanlleylocke.dev.md](docs/EC2-vps.stanlleylocke.dev.md) for a complete walkthrough with `vps.stanlleylocke.dev` on `3.87.53.252`.

---

## 2. Environment file (recommended)

Use an env file to skip the interactive domain prompt and pre-configure Cloudflare, REALITY, subscription, and Telegram settings.

```bash
# On VPS as root
wget -qO /root/vpn_script.env \
  https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/examples/vps.stanlleylocke.dev.env
nano /root/vpn_script.env    # optional: CF_API_KEY, TELEGRAM_BOT_TOKEN
```

All variables are documented in [`.env.example`](.env.example).

**One-shot EC2 install** (downloads env + runs installer):

```bash
curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/scripts/ec2-install.sh | bash
```

**Preflight check** (DNS, ports, architecture):

```bash
source /root/vpn_script.env
bash /usr/local/sbin/preflight vps.stanlleylocke.dev
```

After install, re-apply env changes:

```bash
apply-env /root/vpn_script.env
reload-stack
```

---

## 3. Get a VPS

1. Choose a provider (Hetzner, DigitalOcean, Vultr, Contabo, etc.).
2. Create an **Ubuntu 22.04** or **Debian 12** instance.
3. Note the **public IPv4 address**.
4. Log in as root:

```bash
ssh root@YOUR_VPS_IP
```

---

## 4. Register a domain on Cloudflare

1. Buy or transfer a domain (Namecheap, Porkbun, etc.).
2. Add the domain to [Cloudflare](https://dash.cloudflare.com).
3. Update nameservers at your registrar to Cloudflare’s.
4. Create a DNS record **before install** (you can change it later):

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | `vpn` | `YOUR_VPS_IP` | **Proxied** (orange cloud) |

Your hostname will be something like `vps.stanlleylocke.dev`.

### Cloudflare SSL/TLS (set before or right after install)

| Setting | Value |
|---------|-------|
| SSL/TLS encryption mode | **Full** |
| Always Use HTTPS | **OFF** during install |
| WebSockets | **ON** |
| gRPC | **ON** |
| Under Attack Mode | **OFF** |

---

## 5. Install VPN Script

On the VPS as **root**:

```bash
apt update -y && apt install -y wget curl
wget -q https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/genz.sh
chmod +x genz.sh
./genz.sh
```

Or one-liner:

```bash
curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/install.sh | bash
```

### During install

1. Press **Enter** when prompted to start.
2. Enter your **domain** when asked (e.g. `vps.stanlleylocke.dev`) — or set `VPN_DOMAIN` in `/root/vpn_script.env` to skip this step.
3. Wait 10–20 minutes. The server **reboots** when finished.

### After reboot

SSH back in. The **`menu`** command opens automatically (or run `menu` manually).

---

## 6. Post-install: Cloudflare DNS & SSL

From the admin menu:

```
menu → 26 CF SETUP
```

This script:

- Syncs Cloudflare IP ranges into Nginx (`real_ip` headers)
- Can set SSL mode to Full/Strict
- Validates WebSocket/gRPC settings

Verify services:

```
menu → 29 HEALTH CHECK
```

All of **SSH, HAProxy, Nginx, Xray, ws.py** should show **ON**.

---

## 7. Optional: Cloudflare Tunnel (hide origin IP)

Use this when you want **no public A record** pointing at your VPS — traffic enters only through Cloudflare Tunnel.

```
menu → 33 CF TUNNEL
```

Steps in order:

1. **Install cloudflared** (option 1)
2. **Login to Cloudflare** (option 2) — open the URL shown, authorize
3. **Full tunnel setup** (option 3) — creates tunnel, config, systemd service

After setup:

- Remove or grey-cloud the old **A record** for your domain
- Cloudflare DNS should show a **CNAME** to `TUNNEL_ID.cfargotunnel.com`
- Origin IP is never exposed in DNS

Check status:

```bash
cf-tunnel status
# or menu → 33 → option 4
```

---

## 8. Create your first users

### SSH over WebSocket (HTTP Custom / SSH clients)

```
menu → 01 SSH MENU → Create user
```

Note the **username**, **password**, and **expiry**.

### Xray protocols (VLESS, VMess, Trojan, Shadowsocks)

```
menu → 02 VMESS / 03 VLESS / 04 TROJAN / 05 SHADOW
```

Each created user gets a share link. Links are also saved under `/var/www/html/`.

---

## 9. Subscription URL (Hiddify / Sing-box)

A single URL that auto-imports all active Xray + REALITY users.

```
menu → 32 SUBSCRIPTION
```

1. **Install subscription service** (option 1) — first time only
2. **Generate token** (option 2) if you need a new URL
3. **Show URL** (option 3)

Example output:

```
https://vpn.example.com/sub/AbCdEf123_xYz...
```

### Import in clients

| App | Steps |
|-----|-------|
| **Hiddify** | + → Subscription link → paste URL → Update |
| **Sing-box** | Profiles → Import from URL → paste |
| **v2rayNG** | Subscription → + → paste URL |

The server returns **Base64-encoded** lines (`vless://`, `vmess://`, `trojan://`).

Token file: `/etc/vpn_script/subscription.token`

---

## 10. REALITY inbound

REALITY is harder to fingerprint than WebSocket — useful where WS is throttled.

```
menu → 31 REALITY
```

1. **Install / regenerate keys** (option 1)
2. **Add user** (option 2) — enter username and days
3. Copy the **vless://** link with `security=reality`

Default port: **8443** (open in VPS firewall).

Config files:

- `/etc/xray/reality.json` — keys and parameters
- `/etc/xray/reality-users.json` — user list

REALITY links are included automatically in the **subscription URL**.

---

## 11. Telegram bot panel

Install after base setup:

```bash
kyt.sh
# or: menu → 24 BOT PANEL → option 1
```

You will need:

1. A Telegram bot token from [@BotFather](https://t.me/BotFather)
2. Your Telegram user ID (from [@userinfobot](https://t.me/userinfobot))

### Bot commands (admin)

| Command / button | Action |
|------------------|--------|
| `/menu` | Admin panel |
| **HTTP CUSTOM** button | Export carrier profiles as JSON |
| `/httpcustom` | Same as HTTP CUSTOM button |

The bot can:

- Create/delete SSH, VMess, VLESS, Trojan accounts
- Export **HTTP Custom v5** JSON for any carrier profile
- Show subscription URL and REALITY keys

Start/restart bot:

```
menu → 24 BOT PANEL
```

---

## 12. HTTP Custom library (menu)

```
menu → 27 HTTP CUSTOM
```

Lists **payloads**, **SNI hosts**, **proxies**, and **v5 profiles** including:

| Carrier | Countries | Example profiles |
|---------|-----------|------------------|
| Safaricom | Kenya | M-Pesa, API, Selfcare |
| Airtel | KE, NG, UG, TZ | CF-RAY, CONNECT, WS |
| MTN | NG, GH, ZA | SmartApp, MoMo, split |
| Vodacom | ZA, TZ | CF-RAY, WS |

Export from CLI:

```bash
httpcustom-export export-v5 profile-v5-safaricom-ssh myuser mypass /root/profile.json
httpc-lib list-profiles
httpc-lib list-payloads
```

Exports are also written to `/var/www/html/httpcustom-*.json` when creating SSH users.

---

## 13. Configure HTTP Custom app on Android

[HTTP Custom](https://play.google.com/store/apps/details?id=xyz.easypro.httpcustom) tunnels SSH/WebSocket through carrier-specific HTTP payloads.

### Method A — Import JSON from server

1. On VPS, export a profile (menu 27 or Telegram bot).
2. Transfer the `.json` file to your phone (Telegram, browser download from `/var/www/html/`).
3. In HTTP Custom: **Menu → Import → HTTP Custom v5 JSON**.
4. Open the imported profile and tap **Connect**.

### Method B — Manual v5 setup

Use values from your exported JSON:

| Field | Typical value |
|-------|---------------|
| Connection mode | `3` (SSH WebSocket) |
| Server / SSH host | Your VPS domain |
| SSH port | `443` or `80` |
| SSH user / pass | From menu SSH create |
| Custom payload | From library (e.g. CF-RAY chain) |
| Custom host | Proxy gateway (e.g. `104.17.3.81:80` or carrier host) |
| Custom SNI | e.g. `104.18.8.127` or carrier domain |
| Resolver | `1.1.1.1` or `8.8.8.8` |

### Recommended profiles by carrier

| Your SIM | Start with profile |
|----------|-------------------|
| Safaricom KE | `profile-v5-safaricom-ssh` or `profile-v5-mpesa-ssh` |
| Airtel KE | `profile-v5-africanstorybook-ssh` |
| Airtel NG | `profile-v5-airtel-ng-ssh` |
| MTN NG | `profile-v5-split-bootstrap-ssh` |
| MTN GH | `profile-v5-mtn-gh-ssh` |
| MTN ZA | `profile-v5-mtn-za-ssh` |
| Vodacom ZA | `profile-v5-vodacom-za-ssh` |
| Vodacom TZ | `profile-v5-vodacom-tz-ssh` |
| Wi-Fi / general | `profile-v5-production-ssh` |

### Payload placeholders

When editing payloads manually:

| Placeholder | Replaced with |
|-------------|---------------|
| `[host]` | Your domain |
| `[crlf]` | Line break |
| `[ua]` | User-Agent |
| `[instant_split]` | Split tunnel marker |

---

## 14. Cloudflare custom HTTP application

If you use **Cloudflare Zero Trust → Access → Applications** (custom HTTP app) or a **Workers** front:

1. **Application URL** must match your proxy domain: `https://vpn.example.com`
2. Enable **WebSocket** and **gRPC** passthrough to origin
3. Path routing should forward these to Nginx:

| Path | Backend |
|------|---------|
| `/vless`, `/vmess`, `/trojan-ws`, `/ss-ws` | Xray via Nginx |
| `/sub/*` | Subscription server |
| `/` | SSH WebSocket (ws.py) or decoy site |

Optional path prefix — set in `/etc/vpn_script/config`:

```bash
HTTP_APP_PREFIX="/cdn/app"
# Paths become /cdn/app/vless, etc.
apply-paths
reload-stack
```

SNI fronting hostname (if different from domain):

```bash
SNI_FRONTING="cdn.example.com"
```

Apply Cloudflare settings:

```
menu → 26 CF SETUP
menu → 30 RELOAD STACK
```

---

## 15. Troubleshooting

| Problem | Fix |
|---------|-----|
| Install fails on OpenVZ | Use KVM/Xen VPS |
| Certificate errors | `menu → 19 CERT SSL` or `fixcert` |
| WebSocket 502 | Check `systemctl status xray nginx haproxy ws` |
| Subscription 403 | Regenerate token: `sub-manage generate-token` |
| REALITY won't connect | Open port 8443; verify `reality-setup` keys |
| HTTP Custom timeout | Try another carrier profile; check mobile data bundle |
| Bot not responding | `menu → 24` restart; check token in `/etc/bot/.bot.db` |
| Update scripts | `menu → 23 UPDATE SCRIPT` |

Health check:

```bash
health-check
```

Logs:

```bash
journalctl -u xray -f
journalctl -u nginx -f
journalctl -u subscription -f
tail -f /var/log/nginx/access.log
```

---

## Quick reference — menu options

| # | Feature |
|---|---------|
| 26 | Cloudflare setup |
| 27 | HTTP Custom library |
| 28 | Xray routing profiles |
| 29 | Health check |
| 30 | Reload stack |
| 31 | REALITY inbound |
| 32 | Subscription URL |
| 33 | Cloudflare Tunnel |

---

**Support:** [@stanlley-locke](https://github.com/stanlley-locke)  
**Docs:** [TECHNICAL.md](TECHNICAL.md) · [docs/HTTPCUSTOM.md](docs/HTTPCUSTOM.md) · [docs/CLOUDFLARE.md](docs/CLOUDFLARE.md)
