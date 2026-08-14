# HTTP Custom Library — stanlley-locke/vpn_script

Complete payload, SNI, proxy and v5 profile library for **HTTP Custom**, **HTTP Injector**, and similar Android clients.

Based on community-tested patterns (CF-RAY, split payloads, carrier zero-rated hosts, Safaricom/Airtel/MTN).

---

## Quick start (on VPS)

```bash
# Browse library
httpcustom-lib

# Export v5 JSON + text for SSH user
httpc-export-v5 profile-v5-production-ssh myuser mypassword

# List everything
httpc-lib list-payloads
httpc-lib list-sni
httpc-lib list-proxies
httpc-lib list-profiles
httpc-lib search safaricom
```

---

## Library contents

| File | Contents |
|------|----------|
| `lib/httpcustom/payloads.json` | 12+ payload templates |
| `lib/httpcustom/sni.json` | 17 SNI hosts + Safaricom zero-rated list |
| `lib/httpcustom/proxies.json` | 10 proxy endpoints + port reference |
| `lib/httpcustom/profiles.json` | 6 ready-made HTTP Custom v5 profiles |

---

## Payload categories

| Category | Examples |
|----------|----------|
| **cloudflare** | CF-RAY, cdn-cgi/trace, openwho.org chains |
| **split** | HEAD bootstrapcdn + GET WebSocket |
| **connect** | YouTube CONNECT + instant_split |
| **websocket** | Basic double Upgrade, DLight coregateway |
| **carrier** | Safaricom API, Airtel Kenya headers |
| **cdn** | Imperva, CloudFront fronts |
| **tunnel** | wstunnel.site patterns |

---

## Pre-built v5 profiles

| Profile ID | Use case |
|------------|----------|
| `profile-v5-production-ssh` | **Your domain** — recommended production |
| `profile-v5-cf-ray-ssh` | CF-RAY + openwho trace chain |
| `profile-v5-split-bootstrap-ssh` | MTN/bootstrap CDN split |
| `profile-v5-youtube-connect-ssh` | YouTube zero-rated CONNECT |
| `profile-v5-safaricom-ssh` | Safaricom API host header |
| `profile-v5-africanstorybook-ssh` | Airtel + African Storybook chain |

---

## Export format

`httpc-export-v5` generates:

1. **JSON** — import into HTTP Custom v5 (`profilev5` block)
2. **Text block** — Payload / Proxy / SNI / SSH format (Telegram-style)

Example text output:

```
❂ Payload ❂
GET /cdn-cgi/trace HTTP/1.1[crlf]Host: openwho.org[crlf]...
❂ Proxy ❂
104.17.3.81:80
❂ SNI ❂
vpn.example.com
❂ SSH ❂
vpn.example.com:443@user:pass
```

---

## Safaricom zero-rated hosts

Included in `sni.json` → `zerorate_hosts.safaricom_ke`:

- `selfcare.safaricom.co.ke`
- `api.consumer.fsprod.safaricom.co.ke`
- `authdxl.safaricom.co.ke`
- `mpesaminiapps.safaricom.co.ke`
- …and 15+ more

Use with `profile-v5-safaricom-ssh` or build custom payload with `ws-safaricom-api-v1`.

List on VPS:

```bash
httpc-lib list-zerorate safaricom_ke
```

---

## Customizing

Edit `/etc/vpn_script/config`:

```bash
HTTP_APP_PREFIX="/app/cdn"    # path prefix on your server
SNI_FRONTING="104.18.8.127"    # TLS SNI for clients
```

Then:

```bash
apply-paths
httpc-export-v5 profile-v5-production-ssh username password
```

---

## Adding your own payloads

Edit on GitHub or locally:

```bash
nano lib/httpcustom/payloads.json
```

Add entry with `id`, `name`, `category`, `payload`, `recommended_sni`, `recommended_proxies`.

Push to your fork — VPS picks up on next `update.sh` or reinstall lib:

```bash
wget -qO /usr/local/lib/vpn_script/httpcustom/payloads.json \
  https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/lib/httpcustom/payloads.json
```

---

## HTTP Custom v5 field reference

| Field | Description |
|-------|-------------|
| `custom_payload` | Full HTTP request chain with `[crlf]`, `[split]`, `[instant_split]` |
| `custom_host` | Proxy/gateway host:port (e.g. `104.17.3.81:80`) |
| `custom_sni` | TLS SNI hostname or IP |
| `custom_resolver` | DNS resolver (1.1.1.1, 8.8.8.8) |
| `use_realm_host` | Enable realm host routing |
| `realm_host` | Secondary host for v5 realm mode |
| `preserve_sni` | Keep SNI across hops |
| `connection_mode` | `3` = WebSocket (typical) |

---

## Placeholders (auto-replaced on export)

| Placeholder | Replaced with |
|-------------|---------------|
| `[host]` | Your domain |
| `[host_port]` | domain:443 |
| `[domain]` | /etc/xray/domain |
| `[ua]` | Client User-Agent |
| `[crlf]` | Line endings (kept literal for HTTP Custom) |

---

## Security notes

- **Do not commit** real SSH passwords or carrier proxy auth in the library
- Community proxy IPs may go offline — use `proxy-domain-443` for production
- Zero-rated payloads may violate carrier ToS — use responsibly
- OpenVPN keys from third-party configs were **not** included in this library

---

## After creating SSH user

From menu `addssh`, export HTTP Custom config:

```bash
httpc-export-v5 profile-v5-cf-ray-ssh newuser newpass
cat /var/www/html/httpcustom-newuser.json
```

Or interactive: **menu → httpcustom-lib → option 8**

---

**Author:** [stanlley-locke](https://github.com/stanlley-locke)
