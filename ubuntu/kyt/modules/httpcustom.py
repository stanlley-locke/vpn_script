from kyt import *
import os

HTTPC_LIB    = "/usr/local/lib/vpn_script/httpcustom"
HTTPC_EXPORT = "/usr/local/sbin/httpcustom-export"
_PAGE_SIZE   = 8


def _lib(fname):
    path = os.path.join(HTTPC_LIB, fname)
    if not os.path.isfile(path):
        return {}
    with open(path) as f:
        return json.load(f)


def _profiles():  return _lib("profiles.json").get("profiles", [])
def _payloads():  return _lib("payloads.json").get("payloads", [])
def _proxies():   return _lib("proxies.json").get("proxies", [])
def _sni():       return _lib("sni.json").get("sni_hosts", [])
def _zerorate():  return _lib("sni.json").get("zerorate_hosts", {})


def _guard(event, sender):
    return valid(str(sender.id)) == "true"


# ── main HTTP Custom menu ─────────────────────────────────────────────────────

@bot.on(events.NewMessage(pattern=r"(?i)^(?:/httpcustom|\.httpcustom)$"))
@bot.on(events.CallbackQuery(data=b"httpcustom"))
async def httpcustom_menu(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        try:
            await event.answer("Access Denied", alert=True)
        except Exception:
            await event.reply("Access Denied")
        return

    p_count  = len(_profiles())
    pl_count = len(_payloads())
    px_count = len(_proxies())
    sni_count= len(_sni())
    zr_count = len(_zerorate())

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**🌐 HTTP Custom Library**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Domain    :** `{DOMAIN}`
**» Profiles  :** `{p_count}`
**» Payloads  :** `{pl_count}`
**» Proxies   :** `{px_count}`
**» SNI hosts :** `{sni_count}`
**» Zero-rated groups:** `{zr_count}`
**━━━━━━━━━━━━━━━━━━━━━━━**"""

    inline = [
        [Button.inline("📤 Export Profile",    b"httpc-export-menu"),
         Button.inline("📋 List Profiles",     b"httpc-profiles-0")],
        [Button.inline("📦 List Payloads",     b"httpc-payloads-0"),
         Button.inline("🔌 List Proxies",      b"httpc-proxies-0")],
        [Button.inline("🔒 List SNI",          b"httpc-sni-0"),
         Button.inline("📶 Zero-rated Groups", b"httpc-zerorate")],
        [Button.inline("⚙️ Manual Config",     b"httpc-manual"),
         Button.inline("🔍 Search Library",    b"httpc-search")],
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
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    page = int(event.data.decode().split("-")[-1])
    profiles = _profiles()
    start = page * _PAGE_SIZE
    chunk = profiles[start:start + _PAGE_SIZE]
    rows = []
    for p in chunk:
        rows.append([Button.inline(p.get("name", p["id"])[:38], f"httpc-pinfo:{p['id']}".encode())])
    nav = []
    if page > 0:
        nav.append(Button.inline("◀ Prev", f"httpc-profiles-{page-1}".encode()))
    if start + _PAGE_SIZE < len(profiles):
        nav.append(Button.inline("Next ▶", f"httpc-profiles-{page+1}".encode()))
    if nav:
        rows.append(nav)
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit(f"**📋 Profiles (page {page+1}):**", buttons=rows)
    except Exception:
        await event.reply(f"**📋 Profiles:**", buttons=rows)


@bot.on(events.CallbackQuery(pattern=rb"httpc-pinfo:(.+)"))
async def httpc_profile_info(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    pid = event.data.decode().split(":", 1)[1]
    profiles = _profiles()
    p = next((x for x in profiles if x["id"] == pid), None)
    if not p:
        await event.answer("Profile not found", alert=True)
        return
    payloads = _payloads()
    pl = next((x for x in payloads if x["id"] == p.get("payload_id", "")), {})
    pv5 = p.get("template", {}).get("profilev5", {})
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📋 {p.get('name')}**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» ID         :** `{p['id']}`
**» Payload    :** `{p.get('payload_id','')}`
**» SNI        :** `{p.get('sni_id','')}`
**» Proxy      :** `{p.get('proxy_id','')}`
**» Port       :** `{pv5.get('server_port','')}`
**» Custom Host:** `{pv5.get('custom_host','')}`
**» Custom SNI :** `{pv5.get('custom_sni','')}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Payload:**
`{pl.get('payload','N/A')[:300]}`"""
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
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    page = int(event.data.decode().split("-")[-1])
    payloads = _payloads()
    start = page * _PAGE_SIZE
    chunk = payloads[start:start + _PAGE_SIZE]
    rows = []
    for pl in chunk:
        rows.append([Button.inline(f"[{pl['category']}] {pl['name'][:32]}", f"httpc-plinfo:{pl['id']}".encode())])
    nav = []
    if page > 0:
        nav.append(Button.inline("◀ Prev", f"httpc-payloads-{page-1}".encode()))
    if start + _PAGE_SIZE < len(payloads):
        nav.append(Button.inline("Next ▶", f"httpc-payloads-{page+1}".encode()))
    if nav:
        rows.append(nav)
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit(f"**📦 Payloads (page {page+1}/{(len(payloads)-1)//_PAGE_SIZE+1}):**", buttons=rows)
    except Exception:
        await event.reply("**📦 Payloads:**", buttons=rows)


@bot.on(events.CallbackQuery(pattern=rb"httpc-plinfo:(.+)"))
async def httpc_payload_info(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    pid = event.data.decode().split(":", 1)[1]
    pl = next((x for x in _payloads() if x["id"] == pid), None)
    if not pl:
        await event.answer("Not found", alert=True)
        return
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📦 {pl['name']}**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» ID       :** `{pl['id']}`
**» Category :** `{pl['category']}`
**» Tags     :** `{', '.join(pl.get('tags',[]))}`
**» Port     :** `{pl.get('server_port','')}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Payload:**
`{pl.get('payload','')[:500]}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Recommended proxies:** `{', '.join(pl.get('recommended_proxies',[]))}`
**Recommended SNI:** `{', '.join(pl.get('recommended_sni',[]))}`"""
    try:
        await event.edit(msg, buttons=[[Button.inline("⬅️ Back", b"httpc-payloads-0")]])
    except Exception:
        await event.respond(msg, buttons=[[Button.inline("⬅️ Back", b"httpc-payloads-0")]])


# ── proxy list ────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-proxies-(\d+)"))
async def httpc_proxies(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    page = int(event.data.decode().split("-")[-1])
    proxies = _proxies()
    start = page * _PAGE_SIZE
    chunk = proxies[start:start + _PAGE_SIZE]
    lines = [f"**🔌 Proxies (page {page+1}):**\n"]
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


# ── SNI list ──────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(pattern=rb"httpc-sni-(\d+)"))
async def httpc_sni(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    page = int(event.data.decode().split("-")[-1])
    sni_list = _sni()
    start = page * _PAGE_SIZE
    chunk = sni_list[start:start + _PAGE_SIZE]
    lines = [f"**🔒 SNI Hosts (page {page+1}):**\n"]
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
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    zr = _zerorate()
    rows = []
    for group in zr:
        rows.append([Button.inline(f"📶 {group} ({len(zr[group])} hosts)", f"httpc-zr:{group}".encode())])
    rows.append([Button.inline("⬅️ Back", b"httpcustom")])
    try:
        await event.edit("**📶 Zero-rated Host Groups:**", buttons=rows)
    except Exception:
        await event.reply("**📶 Zero-rated Host Groups:**", buttons=rows)


@bot.on(events.CallbackQuery(pattern=rb"httpc-zr:(.+)"))
async def httpc_zr_group(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    group = event.data.decode().split(":", 1)[1]
    zr = _zerorate()
    hosts = zr.get(group, [])
    lines = [f"**📶 {group} zero-rated hosts:**\n"]
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
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    profiles = _profiles()
    rows = []
    row = []
    for i, p in enumerate(profiles):
        row.append(Button.inline(p.get("name", p["id"])[:20], f"httpc-do-export:{p['id']}".encode()))
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


@bot.on(events.CallbackQuery(pattern=rb"httpc-do-export:(.+)"))
async def httpc_do_export(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    profile_id = event.data.decode().split(":", 1)[1]
    chat = event.chat_id
    async with bot.conversation(chat) as conv:
        await event.respond(f"Profile: `{profile_id}`\n\n**SSH username:**")
        ssh_user = (await conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))).raw_text.strip()
        await event.respond("**SSH password (or `-` to skip):**")
        ssh_pass = (await conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))).raw_text.strip()
        if ssh_pass == "-":
            ssh_pass = ""

    await event.respond("`Exporting HTTP Custom profile…`")
    try:
        cmd = f"{HTTPC_EXPORT} export-v5 {profile_id} {ssh_user} {ssh_pass} 2>&1"
        raw = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
        out_path = f"/tmp/httpc-{profile_id}-{ssh_user}.json"
        with open(out_path, "w") as f:
            f.write(raw)
        await bot.send_file(chat, out_path,
            caption=f"**HTTP Custom v5 — `{profile_id}`**\nUser: `{ssh_user}`\n🤖 @stanlley-locke")
    except subprocess.CalledProcessError as e:
        err = e.output.decode() if e.output else str(e)
        await event.respond(f"Export failed:\n```\n{err[:1000]}\n```")
    except Exception as e:
        await event.respond(f"Export failed: `{e}`")


# ── manual config display ─────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"httpc-manual"))
async def httpc_manual(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**⚙️ HTTP Custom Manual Config**
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 1 — SSH Config**
**» Host:port@user:pass :** `{DOMAIN}:443@<user>:<pass>`
**» Use Payload :** ✅ ON
**» SSL         :** ❌ OFF
**» Enhanced    :** ✅ ON
**» All others  :** ❌ OFF
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 2 — Payload**
`GET / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `91.195.240.94:443`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 3 — SNI**
`{DOMAIN}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Zero-rated (no balance) — CF-RAY payload:**
`GET /cdn-cgi/trace HTTP/1.1[crlf]Host: openwho.org[crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `104.17.3.81:80`
**» SNI          :** `openwho.org`
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""

    try:
        await event.edit(msg, buttons=[[Button.inline("⬅️ Back", b"httpcustom")]])
    except Exception:
        await event.respond(msg, buttons=[[Button.inline("⬅️ Back", b"httpcustom")]])


# ── search ────────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"httpc-search"))
async def httpc_search_prompt(event):
    sender = await event.get_sender()
    if not _guard(event, sender):
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    async with bot.conversation(chat) as conv:
        await event.respond("**Search term (carrier, country, tag):**")
        term = (await conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))).raw_text.strip().lower()

    results = []
    for pl in _payloads():
        if term in pl["id"].lower() or term in pl["name"].lower() or term in " ".join(pl.get("tags", [])):
            results.append(f"📦 `{pl['id']}` — {pl['name']}")
    for p in _profiles():
        if term in p["id"].lower() or term in p["name"].lower():
            results.append(f"📋 `{p['id']}` — {p['name']}")
    for s in _sni():
        if term in s["host"].lower() or term in s["name"].lower():
            results.append(f"🔒 `{s['host']}` — {s['name']}")

    if not results:
        results = ["No results found."]

    msg = f"**🔍 Search: `{term}`**\n\n" + "\n".join(results[:30])
    await event.respond(msg, buttons=[[Button.inline("⬅️ Back", b"httpcustom")]])
