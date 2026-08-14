from kyt import *
import asyncio

# ── pending state for multi-step conversations ────────────────────────────────
_pending = {}  # chat_id -> {"step": str, "data": dict}


def _ssh_msg(user, pw, later_str):
    slowdns  = f"\n**» Host Slowdns     :** `{HOST}`" if HOST else ""
    pubkey   = f"\n**» Pub Key          :** `{PUB}`"  if PUB  else ""
    dns_port = "\n**» Port DNS         :** `443, 53, 22`" if HOST else ""
    return f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**⚡ SSH OVPN ACCOUNT ⚡**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Username         :** `{user}`
**» Password         :** `{pw}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Host             :** `{DOMAIN}`{slowdns}{pubkey}
**» Port OpenSSH     :** `443, 80, 22`{dns_port}
**» Port Dropbear    :** `443, 109`
**» Port Dropbear WS :** `443, 109`
**» Port SSH WS      :** `80, 8080, 8880`
**» Port SSH SSL WS  :** `443`
**» Port SSL/TLS     :** `222-1000`
**» Port OVPN WS SSL :** `443`
**» Port OVPN SSL    :** `443`
**» Port OVPN TCP    :** `443, 1194`
**» Port OVPN UDP    :** `2200`
**» Proxy Squid      :** `3128`
**» BadVPN UDP       :** `7100, 7300`
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Payload WSS      :** `GET wss://{DOMAIN}/ HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf][crlf]`
**» HTTP Custom      :** see /httpcustom or button below
**━━━━━━━━━━━━━━━━━━━━━━━**
**» OpenVPN WS SSL   :** `https://{DOMAIN}:81/ws-ssl.ovpn`
**» OpenVPN SSL      :** `https://{DOMAIN}:81/ssl.ovpn`
**» OpenVPN TCP      :** `https://{DOMAIN}:81/tcp.ovpn`
**» OpenVPN UDP      :** `https://{DOMAIN}:81/udp.ovpn`
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Save Link        :** `https://{DOMAIN}:81/ssh-{user}.txt`
**» Expired Until    :** `{later_str}`
**» 🤖 @stanlley-locke**"""


def _progress_steps():
    return [
        "`Processing... 0%\n▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ `",
        "`Processing... 20%\n█████▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒ `",
        "`Processing... 52%\n█████████████▒▒▒▒▒▒▒▒▒▒▒▒ `",
        "`Processing... 84%\n█████████████████████▒▒▒▒ `",
        "`Processing... 100%\n█████████████████████████ `",
    ]


async def _show_progress(event):
    for step in _progress_steps():
        try:
            await event.edit(step)
        except Exception:
            pass
        await asyncio.sleep(0.8)


# ── SSH manager menu ──────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"ssh"))
async def ssh(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    try:
        z = requests.get("http://ip-api.com/json/?fields=country,isp", timeout=5).json()
        isp     = z.get("isp", "N/A")
        country = z.get("country", "N/A")
    except Exception:
        isp = country = "N/A"
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**⚡ SSH OVPN MANAGER ⚡**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Host    :** `{DOMAIN}`
**» ISP     :** `{isp}`
**» Country :** `{country}`
**━━━━━━━━━━━━━━━━━━━━━━━**"""
    inline = [
        [Button.inline("🆕 Create SSH",    b"create-ssh"),
         Button.inline("🎲 Trial SSH",     b"trial-ssh")],
        [Button.inline("🗑 Delete SSH",    b"delete-ssh"),
         Button.inline("👥 Show Users",    b"show-ssh")],
        [Button.inline("🔍 Check Login",   b"login-ssh"),
         Button.inline("🌐 HTTP Custom",   b"ssh-httpcustom")],
        [Button.inline("📋 Payload Menu",  b"ssh-payload-menu"),
         Button.inline("📁 Config Files",  b"ssh-config-files")],
        [Button.inline("⬅️ Main Menu",     b"menu")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.reply(msg, buttons=inline)


# ── create SSH ────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"create-ssh"))
async def create_ssh(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    _pending[chat] = {"step": "ssh_user", "data": {}}
    await event.respond("**👤 Enter SSH username:**")


@bot.on(events.CallbackQuery(data=b"trial-ssh"))
async def trial_ssh(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await event.respond(
        "**⏱ Choose trial duration:**",
        buttons=[
            [Button.inline("10 min", b"trial-ssh-10"), Button.inline("15 min", b"trial-ssh-15")],
            [Button.inline("30 min", b"trial-ssh-30"), Button.inline("60 min", b"trial-ssh-60")],
        ]
    )


@bot.on(events.CallbackQuery(pattern=rb"trial-ssh-(\d+)"))
async def trial_ssh_duration(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    mins = event.data.decode().split("-")[-1]
    msg = await event.respond("`Creating trial account…`")
    await _show_progress(msg)
    user = "trial" + str(random.randint(1000, 9999))
    pw   = "trial123"
    cmd  = f'useradd -e `date -d "1 days" +"%Y-%m-%d"` -s /bin/false -M {user} && echo "{pw}\\n{pw}" | passwd {user} 2>&1'
    try:
        subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
        subprocess.Popen(f'sleep {int(mins)*60} && userdel -f {user}', shell=True)
    except Exception as e:
        await msg.edit(f"**Error:** `{e}`")
        return
    await msg.edit(
        _ssh_msg(user, pw, f"{mins} Minutes"),
        buttons=[
            [Button.inline("🌐 HTTP Custom", b"ssh-httpcustom"),
             Button.inline("📋 Payloads",    b"ssh-payload-menu")],
            [Button.inline("⬅️ SSH Menu",    b"ssh")],
        ]
    )


# ── delete SSH ────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"delete-ssh"))
async def delete_ssh(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    _pending[chat] = {"step": "ssh_delete", "data": {}}
    await event.respond("**🗑 Enter username to delete:**")


# ── show users ────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"show-ssh"))
async def show_ssh(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    try:
        z = subprocess.check_output("bot-member-ssh", shell=True, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
    except Exception as e:
        z = str(e)
    await event.respond(
        f"**👥 SSH Users:**\n```\n{z[:3500]}\n```\n🤖 **@stanlley-locke**",
        buttons=[[Button.inline("⬅️ SSH Menu", b"ssh")]]
    )


# ── check login ───────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"login-ssh"))
async def login_ssh(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    try:
        z = subprocess.check_output("bot-cek-login-ssh", shell=True, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
    except Exception as e:
        z = str(e)
    await event.respond(
        f"**🔍 Active SSH Logins:**\n```\n{z[:3500]}\n```\n🤖 **@stanlley-locke**",
        buttons=[[Button.inline("⬅️ SSH Menu", b"ssh")]]
    )


# ── HTTP Custom quick info for SSH ────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"ssh-httpcustom"))
async def ssh_httpcustom(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**🌐 HTTP Custom — Quick Setup**
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 1 — SSH Config**
**» Host:port@user:pass :** `{DOMAIN}:443@<user>:<pass>`
**» Use Payload :** ✅ ON
**» SSL         :** ❌ OFF  ← important!
**» Enhanced    :** ✅ ON
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 2 — Payload (Standard)**
`GET / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `91.195.240.94:443`
**» SNI          :** `{DOMAIN}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Screen 2 — Payload (Zero-rated / CF-RAY)**
`GET /cdn-cgi/trace HTTP/1.1[crlf]Host: openwho.org[crlf][crlf]CF-RAY / HTTP/1.1[crlf]Host: {DOMAIN}[crlf]Upgrade: websocket[crlf]Connection: Upgrade[crlf][crlf]`
**» Remote Proxy :** `104.17.3.81:80`
**» SNI          :** `openwho.org`
**━━━━━━━━━━━━━━━━━━━━━━━**
**⚠️ Tips:**
• SSL checkbox must be OFF in HTTP Custom
• Use HTTP/1.1 not HTTP/2
• Cloudflare proxy must be ON (orange cloud)
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""
    inline = [
        [Button.inline("📋 Full Payload Menu", b"ssh-payload-menu"),
         Button.inline("📤 Export Profile",    b"httpc-export-menu")],
        [Button.inline("⬅️ SSH Menu",          b"ssh")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.respond(msg, buttons=inline)


# ── payload menu for SSH ──────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"ssh-payload-menu"))
async def ssh_payload_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📋 SSH Payload Library**
**━━━━━━━━━━━━━━━━━━━━━━━**
**Domain:** `{DOMAIN}`
Select a payload category:"""
    inline = [
        [Button.inline("☁️ Cloudflare / CF-RAY",  b"pl-cat-cloudflare"),
         Button.inline("📡 Carrier Specific",      b"pl-cat-carrier")],
        [Button.inline("✂️ Split / HEAD+GET",       b"pl-cat-split"),
         Button.inline("🔌 CONNECT Tunnel",         b"pl-cat-connect")],
        [Button.inline("🌐 WebSocket Basic",        b"pl-cat-websocket"),
         Button.inline("🚇 WSTunnel / Workers",     b"pl-cat-tunnel")],
        [Button.inline("📦 All Payloads",           b"httpc-payloads-0"),
         Button.inline("📤 Export Profile",         b"httpc-export-menu")],
        [Button.inline("⬅️ SSH Menu",               b"ssh")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.respond(msg, buttons=inline)


@bot.on(events.CallbackQuery(pattern=rb"pl-cat-(.+)"))
async def pl_category(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    cat = event.data.decode().split("-", 2)[2]

    # load payloads from library
    lib_path = "/usr/local/lib/vpn_script/httpcustom/payloads.json"
    try:
        with open(lib_path) as f:
            all_pl = json.load(f).get("payloads", [])
    except Exception:
        all_pl = []

    filtered = [p for p in all_pl if p.get("category", "") == cat]
    if not filtered:
        await event.answer(f"No payloads for category: {cat}", alert=True)
        return

    rows = []
    for p in filtered:
        rows.append([Button.inline(p["name"][:40], f"httpc-plinfo:{p['id']}".encode())])
    rows.append([Button.inline("⬅️ Back", b"ssh-payload-menu")])
    try:
        await event.edit(f"**📋 {cat.title()} Payloads:**", buttons=rows)
    except Exception:
        await event.respond(f"**📋 {cat.title()} Payloads:**", buttons=rows)


# ── config files menu ─────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"ssh-config-files"))
async def ssh_config_files(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📁 SSH Config Files**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» OpenVPN WS SSL :** `https://{DOMAIN}:81/ws-ssl.ovpn`
**» OpenVPN SSL    :** `https://{DOMAIN}:81/ssl.ovpn`
**» OpenVPN TCP    :** `https://{DOMAIN}:81/tcp.ovpn`
**» OpenVPN UDP    :** `https://{DOMAIN}:81/udp.ovpn`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Download by username:**
**» SSH config     :** `https://{DOMAIN}:81/ssh-<user>.txt`
**» VMess config   :** `https://{DOMAIN}:81/vmess-<user>.txt`
**» VLess config   :** `https://{DOMAIN}:81/vless-<user>.txt`
**» Trojan config  :** `https://{DOMAIN}:81/trojan-<user>.txt`
**» SS config      :** `https://{DOMAIN}:81/ss-<user>.txt`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Subscription URL:**
`https://{DOMAIN}/sub/<token>`
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""
    inline = [
        [Button.inline("📡 Get Sub URL", b"sub-url"),
         Button.inline("⬅️ SSH Menu",   b"ssh")],
    ]
    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.respond(msg, buttons=inline)


# ── regis (IP registration placeholder) ──────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"regis"))
async def regis(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    try:
        ip = subprocess.check_output("curl -s ipv4.icanhazip.com", shell=True).decode().strip()
    except Exception:
        ip = "unknown"
    await event.respond(
        f"**🔌 IP Registration**\n\n**» Your VPS IP:** `{ip}`\n\nTo whitelist an IP in the license file, add it to `keygen` on GitHub.\n\n🤖 **@stanlley-locke**",
        buttons=[[Button.inline("⬅️ SSH Menu", b"ssh")]]
    )


# ── incoming message handler for multi-step flows ────────────────────────────

@bot.on(events.NewMessage(incoming=True))
async def ssh_conversation_handler(event):
    if event.is_channel or not event.is_private:
        return
    chat = event.chat_id
    if chat not in _pending:
        return
    state = _pending[chat]
    step  = state["step"]
    text  = event.raw_text.strip()

    # ── create SSH flow ───────────────────────────────────────────────────────
    if step == "ssh_user":
        state["data"]["user"] = text
        state["step"] = "ssh_pass"
        await event.respond("**🔑 Enter password:**")

    elif step == "ssh_pass":
        state["data"]["pw"] = text
        state["step"] = "ssh_exp"
        await event.respond(
            "**📅 Choose expiry:**",
            buttons=[
                [Button.inline("3 Days",  b"ssh-exp-3"),  Button.inline("7 Days",  b"ssh-exp-7")],
                [Button.inline("30 Days", b"ssh-exp-30"), Button.inline("60 Days", b"ssh-exp-60")],
            ]
        )

    # ── delete SSH flow ───────────────────────────────────────────────────────
    elif step == "ssh_delete":
        del _pending[chat]
        user = text
        cmd  = f'printf "%s\\n" "{user}" | delssh 2>&1'
        try:
            subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
            await event.respond(
                f"✅ **User `{user}` deleted.**",
                buttons=[[Button.inline("⬅️ SSH Menu", b"ssh")]]
            )
        except Exception:
            await event.respond(
                f"❌ **User `{user}` not found.**",
                buttons=[[Button.inline("⬅️ SSH Menu", b"ssh")]]
            )


@bot.on(events.CallbackQuery(pattern=rb"ssh-exp-(\d+)"))
async def ssh_exp_chosen(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    if chat not in _pending or _pending[chat].get("step") != "ssh_exp":
        await event.answer("Session expired. Start again.", alert=True)
        return
    exp  = event.data.decode().split("-")[-1]
    data = _pending.pop(chat)["data"]
    user = data["user"]
    pw   = data["pw"]

    msg = await event.respond("`Creating account…`")
    await _show_progress(msg)

    cmd = f'useradd -e `date -d "{exp} days" +"%Y-%m-%d"` -s /bin/false -M {user} && echo "{pw}\\n{pw}" | passwd {user} 2>&1'
    try:
        subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError:
        await msg.edit(f"❌ **User `{user}` already exists or creation failed.**",
                       buttons=[[Button.inline("⬅️ SSH Menu", b"ssh")]])
        return

    today = DT.date.today()
    later = today + DT.timedelta(days=int(exp))
    await msg.edit(
        _ssh_msg(user, pw, str(later)),
        buttons=[
            [Button.inline("🌐 HTTP Custom", b"ssh-httpcustom"),
             Button.inline("📋 Payloads",    b"ssh-payload-menu")],
            [Button.inline("📁 Config Files",b"ssh-config-files"),
             Button.inline("⬅️ SSH Menu",    b"ssh")],
        ]
    )
