# EC2 install — vps.stanlleylocke.dev

Step-by-step for **AWS EC2** with **Cloudflare DNS only** (grey cloud).

## Your environment

| Item | Value |
|------|-------|
| Domain | `vps.stanlleylocke.dev` |
| Public IP | `3.87.53.252` |
| Instance | `i-03c76f90fe4f9adc0` (t2.small, us-east-1) |
| SSH key | `proxylockes` |
| Cloudflare | DNS only (not proxied) |

Pre-filled env file: [`examples/vps.stanlleylocke.dev.env`](../examples/vps.stanlleylocke.dev.env)

---

## 1. AWS Security Group (required)

Inbound rules for the instance security group:

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | Your IP | Admin |
| HTTP | 80 | 0.0.0.0/0 | ACME + WS fallback |
| HTTPS | 443 | 0.0.0.0/0 | Main proxy |
| Custom TCP | 8443 | 0.0.0.0/0 | REALITY |
| Custom TCP | 8880 | 0.0.0.0/0 | SSH alt |
| Custom TCP | 1194 | 0.0.0.0/0 | OpenVPN |
| Custom UDP | 5300 | 0.0.0.0/0 | SlowDNS |

---

## 2. Cloudflare DNS (already done)

```
vps.stanlleylocke.dev   A   3.87.53.252   DNS only
vps                     A   3.87.53.252   DNS only
```

**DNS only** means:

- Traffic goes **directly** to EC2 (no orange cloud)
- Let's Encrypt cert is issued on the VPS (install handles this)
- You can enable **proxied** later via Cloudflare dashboard + `menu → 26 CF SETUP`

Verify before install:

```bash
dig +short vps.stanlleylocke.dev
# must return 3.87.53.252
```

---

## 3. Connect to EC2

```bash
ssh -i ~/.ssh/proxylockes.pem ubuntu@3.87.53.252
sudo -i
```

---

## 4. Copy environment file

```bash
apt update -y && apt install -y wget curl git

# Option A — from GitHub (after you push this repo)
wget -qO /root/vpn_script.env \
  https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/examples/vps.stanlleylocke.dev.env

# Option B — clone repo and copy
git clone https://github.com/stanlley-locke/vpn_script.git /root/vpn_script
cp /root/vpn_script/examples/vps.stanlleylocke.dev.env /root/vpn_script.env

nano /root/vpn_script.env
# Add optional: CF_EMAIL, CF_API_KEY, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
```

---

## 5. Install

```bash
set -a && source /root/vpn_script.env && set +a

curl -fsSL https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/install.sh | bash
```

Domain prompt is **skipped** — install uses `VPN_DOMAIN=vps.stanlleylocke.dev` from env.

Or from cloned repo:

```bash
cd /root/vpn_script
set -a && source /root/vpn_script.env && set +a
./genz.sh
```

Press **Enter** when prompted to start. Wait ~15–20 min, then reboot.

---

## 6. After reboot

```bash
ssh -i ~/.ssh/proxylockes.pem ubuntu@3.87.53.252
sudo menu
```

| Step | Command / menu |
|------|----------------|
| Health check | menu **29** or `health-check` |
| Subscription URL | menu **32** or `sub-manage url` |
| Create SSH user | menu **01** |
| HTTP Custom export | menu **27** |
| REALITY | menu **31** (port 8443) |

Expected subscription URL:

```
https://vps.stanlleylocke.dev/sub/<your-token>
```

Apply env to runtime config (if you edited `/root/vpn_script.env` post-install):

```bash
apply-env /root/vpn_script.env
reload-stack
```

---

## 7. Test clients

| Client | Config |
|--------|--------|
| Hiddify / Sing-box | Paste subscription URL |
| v2rayNG | Subscription → add URL |
| HTTP Custom | Import `profile-v5-production-ssh` JSON |
| REALITY | Link from menu 31 (host `vps.stanlleylocke.dev:8443`) |

---

## 8. Optional: enable Cloudflare proxy later

1. Cloudflare → DNS → **Proxied** (orange cloud) on `vps`
2. SSL/TLS → **Full**
3. Enable WebSockets + gRPC
4. On VPS: `menu → 26 CF SETUP` then `menu → 30 RELOAD STACK`

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `dig` wrong IP | Wait DNS propagation; check Cloudflare record |
| Port 443 timeout | Open security group |
| ACME / SSL fail | Port 80 must be open; `dig` must point to VPS |
| License check | `LICENSE_CHECK=0` in env (default) |

See also: [SETUP.md](../SETUP.md) · [TECHNICAL.md](../TECHNICAL.md)
