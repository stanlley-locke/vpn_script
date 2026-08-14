from kyt import *
import asyncio
import os

HTTPC_LIB    = "/usr/local/lib/vpn_script/httpcustom"
HTTPC_EXPORT = "/usr/local/sbin/httpcustom-export"
_PAGE_SIZE   = 8

# pending export state: chat_id -> {"step": str, "profile_id": str, "user": str}
_export_pending = {}


def _lib(fname):
    path = os.path.join(HTTPC_LIB, fname)
    if not os.path.isfile(path):
        # fallback to repo path
        repo = os.path.join(os.path.dirname(__file__), "../../../../lib/httpcustom", fname)
        if os.path.isfile(repo):
            path = repo
        else:
            return {}
    with open(path) as f:
        return json.load(f)


def _profiles():  return _lib("profiles.json").get("profiles", [])
def _payloads():  return _lib("payloads.json").get("payloads", [])
def _proxies():   return _lib("proxies.json").get("proxies", [])
def _sni():       return _lib("sni.json").get("sni_hosts", [])
def _zerorate():  return _lib("sni.json").get("zerorate_hosts", {})


def _guard(sender):
    return valid(str(sender.id)) == "true"


# ── main HTTP Custom menu ─────────────────────────────────────────────────────

@bot.on(events.NewMessage(pattern=r"(?i)^(?:/httpcustom|\.httpcustom)$"))
@bot.on(events.CallbackQuery(data=b"httpcustom"))
async def httpcustom_menu(event):
    sender = await event.get_sender()
    if not _guard(sender):
        try:
            await event.answer("Access Denied", alert=True)
        except Exception:
            await event.reply("Access Denied")
        return

    p_count   = len(_profiles())
    pl_count  = len(_payloads())
    px_count  = len(_proxies())
    sni_count = len(_sni())
    zr_count  = len(_zerorate())

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**🌐 HTTP Custom Library**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Domain        :** `{DOMAIN}`
**» Profiles      :** `{p_count}`
**» Payloads      :** `{pl_count}`
**» Proxies       :** `{px_count}`
**» SNI hosts     :** `{sni_count}`
**» Zero-rated    :** `{zr_count} groups`
**━━━━━━━━━━━━━━━━━━━━━━━**"""

    inline = [
        [Button.inline("📤 Export Profile",    b"httpc-export-menu"),
         Button.inline("📋 List Profiles",     b"httpc-profiles-0")],
        [Button.inline("📦 Payloads",          b"httpc-payloads-0"),
         Button.inline("🔌 Proxies",           b"httpc-proxies-0")],
        [Button.inline("🔒 SNI Hosts",         b"httpc-sni-0"),
         Button.inline("📶 Zero-rated",        b"httpc-zerorate")],
        [Button.inline("⚙️ Manual Config",     b"httpc-manual"),
         Button.inline("🔍 Search",            b"httpc-search-prompt")],
        [Button.inline("📡 Subscription URL",  b"sub-url"),
         Button.inline("🔮 REALITY Info",      b"reality-info")],
        [Button.inline("⬅️ Main Menu",         b"menu")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.reply(msg, buttons=inline)


# ── profile list (paginated) ──────────────────────────────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-profiles-(\d+)"))
async def httpc_profiles(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    page     = int(event.data.decode().split("-")[-1])
    profiles = _profiles()
    start    = page * _PAGE_SIZE
    chunk    = profiles[start:start + _PAGE_SIZE]
    rows     = []
    for p in chunk:
        rows.append([Button.inline(p.get("name", p["id"])[:40], f"httpc-pinfo:{p['id']}".encode())])
    nav = []
    if page > 0:
        nav.append(Button.inline("◀ Prev", f"httpc-profiles-{page-1}".encode()))
    if start + _PAGE_SIZE < len(profiles):
        nav.append(Button.inline("Next ▶", f"httpc-profiles-{page+1}".encode()))
    if nav:
        rows.append(nav)
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    total = (len(profiles) - 1) // _PAGE_SIZE + 1
    try:
        await event.edit(f"**📋 Profiles — page {page+1}/{total}:**", buttons=rows)
    except Exception:
        await event.reply(f"**📋 Profiles:**", buttons=rows)


@bot.on(events.CallbackQuery(pattern=rb"httpc-pinfo:(.+)"))
async def httpc_profile_info(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    pid      = event.data.decode().split(":", 1)[1]
    profiles = _profiles()
    p        = next((x for x in profiles if x["id"] == pid), None)
    if not p:
        await event.answer("Profile not found", alert=True)
        return
    payloads = _payloads()
    pl       = next((x for x in payloads if x["id"] == p.get("payload_id", "")), {})
    pv5      = p.get("template", {}).get("profilev5", {})
    payload_preview = pl.get("payload", "N/A")[:300]
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📋 {p.get('name')}**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Payload    :** `{p.get('payload_id','')}`
**» SNI        :** `{p.get('sni_id','')}`
**» Proxy      :** `{p.get('proxy_id','')}`
**» Port       :** `{pv5.get('server_port','')}`
**» Custom Host:** `{pv5.get('custom_host','')}`
**» Custom SNI :** `{pv5.get('custom_sni','')}`
**» Resolver   :** `{pv5.get('custom_resolver','1.1.1.1')}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Payload:**
`{payload_preview}`"""
    inline = [
        [Button.inline("📤 Export this profile", f"httpc-do-export:{pid}".encode())],
        [Button.inline("⬅️ Back", b"httpc-profiles-0")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.respond(msg, buttons=inline)


# ── payload list (paginated) ──────────────────────────────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-payloads-(\d+)"))
async def httpc_payloads(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    page     = int(event.data.decode().split("-")[-1])
    payloads = _payloads()
    start    = page * _PAGE_SIZE
    chunk    = payloads[start:start + _PAGE_SIZE]
    rows     = []
    for pl in chunk:
        label = f"[{pl['category']}] {pl['name']}"[:40]
        rows.append([Button.inline(label, f"httpc-plinfo:{pl['id']}".encode())])
    nav = []
    if page > 0:
        nav.append(Button.inline("◀ Prev", f"httpc-payloads-{page-1}".encode()))
    if start + _PAGE_SIZE < len(payloads):
        nav.append(Button.inline("Next ▶", f"httpc-payloads-{page+1}".encode()))
    if nav:
        rows.append(nav)
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    total = (len(payloads) - 1) // _PAGE_SIZE + 1
    try:
        await event.edit(f"**📦 Payloads — page {page+1}/{total}:**", buttons=rows)
    except Exception:
        await event.reply(f"**📦 Payloads:**", buttons=rows)


@bot.on(events.CallbackQuery(pattern=rb"httpc-plinfo:(.+)"))
async def httpc_payload_info(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    pid = event.data.decode().split(":", 1)[1]
    pl  = next((x for x in _payloads() if x["id"] == pid), None)
    if not pl:
        await event.answer("Not found", alert=True)
        return
    tags    = ", ".join(pl.get("tags", []))
    proxies = ", ".join(pl.get("recommended_proxies", []))
    snis    = ", ".join(pl.get("recommended_sni", []))
    payload = pl.get("payload", "")[:500]
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📦 {pl['name']}**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Category :** `{pl['category']}`
**» Tags     :** `{tags}`
**» Port     :** `{pl.get('server_port','')}`
**» Mode     :** `{pl.get('connection_mode','3')}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Payload:**
`{payload}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Recommended proxies:** `{proxies}`
**Recommended SNI    :** `{snis}`"""
    if pl.get("notes"):
        msg += f"\n**Notes:** {pl['notes']}"
    try:
        await event.edit(msg, buttons=[[Button.inline("⬅️ Back", b"httpc-payloads-0")]])
    except Exception:
        await event.respond(msg, buttons=[[Button.inline("⬅️ Back", b"httpc-payloads-0")]])


# ── proxy list (paginated) ────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-proxies-(\d+)"))
async def httpc_proxies(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    page    = int(event.data.decode().split("-")[-1])
    proxies = _proxies()
    start   = page * _PAGE_SIZE
    chunk   = proxies[start:start + _PAGE_SIZE]
    lines   = [f"**🔌 Proxies — page {page+1}:**\n"]
    for px in chunk:
        lines.append(f"• `{px['host']}:{px['port']}` — {px['name']} [{px['category']}]")
    nav = []
    if page > 0:
        nav.append(Button.inline("◀ Prev", f"httpc-proxies-{page-1}".encode()))
    if start + _PAGE_SIZE < len(proxies):
        nav.append(Button.inline("Next ▶", f"httpc-proxies-{page+1}".encode()))
    rows = [nav] if nav else []
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit("\n".join(lines), buttons=rows)
    except Exception:
        await event.reply("\n".join(lines), buttons=rows)


# ── SNI list (paginated) ──────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-sni-(\d+)"))
async def httpc_sni(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    page     = int(event.data.decode().split("-")[-1])
    sni_list = _sni()
    start    = page * _PAGE_SIZE
    chunk    = sni_list[start:start + _PAGE_SIZE]
    lines    = [f"**🔒 SNI Hosts — page {page+1}:**\n"]
    for s in chunk:
        lines.append(f"• `{s['host']}` — {s['name']} [{s['category']}]")
    nav = []
    if page > 0:
        nav.append(Button.inline("◀ Prev", f"httpc-sni-{page-1}".encode()))
    if start + _PAGE_SIZE < len(sni_list):
        nav.append(Button.inline("Next ▶", f"httpc-sni-{page+1}".encode()))
    rows = [nav] if nav else []
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit("\n".join(lines), buttons=rows)
    except Exception:
        await event.reply("\n".join(lines), buttons=rows)


# ── zero-rated groups ─────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"httpc-zerorate"))
async def httpc_zerorate(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    zr   = _zerorate()
    rows = []
    for group, hosts in zr.items():
        rows.append([Button.inline(f"📶 {group} ({len(hosts)} hosts)", f"httpc-zr:{group}".encode())])
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit("**📶 Zero-rated Host Groups:**", buttons=rows)
    except Exception:
        await event.reply("**📶 Zero-rated Host Groups:**", buttons=rows)


@bot.on(events.CallbackQuery(pattern=rb"httpc-zr:(.+)"))
async def httpc_zr_group(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    group = event.data.decode().split(":", 1)[1]
    zr    = _zerorate()
    hosts = zr.get(group, [])
    lines = [f"**📶 {group} — zero-rated hosts:**\n"]
    for h in hosts:
        lines.append(f"• `{h}`")
    try:
        await event.edit("\n".join(lines), buttons=[[Button.inline("⬅️ Back", b"httpc-zerorate")]])
    except Exception:
        await event.respond("\n".join(lines), buttons=[[Button.inline("⬅️ Back", b"httpc-zerorate")]])


# ── export menu ───────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"httpc-export-menu"))
async def httpc_export_menu(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    profiles = _profiles()
    rows     = []
    row      = []
    for i, p in enumerate(profiles):
        row.append(Button.inline(p.get("name", p["id"])[:22], f"httpc-do-export:{p['id']}".encode()))
        if len(row) == 2:
            rows.append(row)
            row = []
    if row:
        rows.append(row)
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit("**📤 Select profile to export:**", buttons=rows)
    except Exception:
        await event.reply("**📤 Select profile to export:**", buttons=rows)


# ── export flow (state machine — no bot.conversation) ────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-do-export:(.+)"))
async def httpc_do_export_start(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    profile_id = event.data.decode().split(":", 1)[1]
    chat       = event.chat_id
    _export_pending[chat] = {"step": "user", "profile_id": profile_id}
    await event.respond(f"**📤 Export:** `{profile_id}`\n\n**Enter SSH username:**")


@bot.on(events.NewMessage(incoming=True))
async def httpc_export_handler(event):
    if event.is_channel or not event.is_private:
        return
    chat = event.chat_id
    if chat not in _export_pending:
        return
    state = _export_pending[chat]
    text  = event.raw_text.strip()

    if state["step"] == "user":
        state["ssh_user"] = text
        state["step"]     = "pass"
        await event.respond("**Enter SSH password (or `-` to skip):**")

    elif state["step"] == "pass":
        ssh_pass   = "" if text == "-" else text
        profile_id = state["profile_id"]
        ssh_user   = state["ssh_user"]
        del _export_pending[chat]

        msg = await event.respond("`Exporting HTTP Custom profile…`")
        try:
            cmd = f"{HTTPC_EXPORT} export-v5 {profile_id} {ssh_user} {ssh_pass} 2>&1"
            raw = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
        except subprocess.CalledProcessError as e:
            raw = e.output.decode("utf-8", errors="replace") if e.output else str(e)
            await msg.edit(f"**Export failed:**\n```\n{raw[:1500]}\n```")
            return
        except Exception as e:
            await msg.edit(f"**Export failed:** `{e}`")
            return

        out_path = f"/tmp/httpc-{profile_id}-{ssh_user}.json"
        try:
            with open(out_path, "w") as f:
                f.write(raw)
            await bot.send_file(
                chat, out_path,
                caption=f"**HTTP Custom v5 — `{profile_id}`**\nUser: `{ssh_user}`\n🤖 @stanlley-locke",
                buttons=[[Button.inline("⬅️ HTTP Custom", b"httpcustom")]]
            )
            await msg.delete()
        except Exception:
            # fallback: send as text
            await msg.edit(
                f"**HTTP Custom v5 — `{profile_id}`**\nUser: `{ssh_user}`\n```\n{raw[:3000]}\n```\n🤖 @stanlley-locke",
                buttons=[[Button.inline("⬅️ HTTP Custom", b"httpcustom")]]
            )


# ── manual config ─────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"httpc-manual"))
async def httpc_manual(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**⚙️ HTTP Custom Manual Config**
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 1 — SSH**
**» Host:port@user:pass :** `{DOMAIN}:443@<user>:<pass>`
**» Use Payload :** ✅ ON
**» SSL         :** ❌ OFF  ← must be OFF
**» Enhanced    :** ✅ ON
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 2 — Standard Payload**
`GET / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `91.195.240.94:443`
**» SNI          :** `{DOMAIN}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 2 — CF-RAY (zero-rated / no balance)**
`GET /cdn-cgi/trace HTTP/1.1[crlf]Host: openwho.org[crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `104.17.3.81:80`
**» SNI          :** `openwho.org`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 2 — African Storybook (Airtel KE)**
`CONNECT {DOMAIN}:443 HTTP/1.1[crlf]Host: {DOMAIN}[crlf]X-Online-Host: r.airtelkenya.com[crlf]Connection: Keep-Alive[crlf][instant_split]GET /cdn-cgi/trace HTTP/1.1[crlf]Host: africanstorybook.org[crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `104.17.3.81:80`
**» SNI          :** `africanstorybook.org`
**━━━━━━━━━━━━━━━━━━━━━━━**
**⚠️ Key Rules:**
• SSL checkbox = OFF always
• Use HTTP/1.1 (not HTTP/2)
• Cloudflare proxy = ON (orange cloud)
• Remote Proxy = Cloudflare IP, not your VPS IP
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""
    inline = [
        [Button.inline("📋 Full Payload List", b"httpc-payloads-0"),
         Button.inline("📤 Export Profile",    b"httpc-export-menu")],
        [Button.inline("📶 Zero-rated Groups", b"httpc-zerorate"),
         Button.inline("⬅️ Back",             b"httpcustom")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.respond(msg, buttons=inline)


# ── search (state machine) ────────────────────────────────────────────────────

_search_pending = set()  # chat_ids waiting for search term


@bot.on(events.CallbackQuery(data=b"httpc-search-prompt"))
async def httpc_search_prompt(event):
    sender = await event.get_sender()
    if not _guard(sender):
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    _search_pending.add(chat)
    await event.respond("**🔍 Enter search term (carrier, country, tag, e.g. `safaricom`, `nigeria`, `cf-ray`):**")


@bot.on(events.NewMessage(incoming=True))
async def httpc_search_handler(event):
    if event.is_channel or not event.is_private:
        return
    chat = event.chat_id
    if chat not in _search_pending:
        return
    _search_pending.discard(chat)
    term    = event.raw_text.strip().lower()
    results = []

    for pl in _payloads():
        if (term in pl["id"].lower() or term in pl["name"].lower()
                or term in " ".join(pl.get("tags", []))):
            results.append(f"📦 `{pl['id']}` — {pl['name']}")

    for p in _profiles():
        if term in p["id"].lower() or term in p["name"].lower():
            results.append(f"📋 `{p['id']}` — {p['name']}")

    for s in _sni():
        if term in s["host"].lower() or term in s["name"].lower():
            results.append(f"🔒 `{s['host']}` — {s['name']}")

    for px in _proxies():
        if term in px["name"].lower() or term in " ".join(px.get("tags", [])):
            results.append(f"🔌 `{px['host']}:{px['port']}` — {px['name']}")

    if not results:
        results = ["No results found."]

    msg = f"**🔍 Results for `{term}`:**\n\n" + "\n".join(results[:30])
    await event.respond(msg, buttons=[[Button.inline("⬅️ HTTP Custom", b"httpcustom")]])
