from kyt import *


# ── helpers ──────────────────────────────────────────────────────────────────

async def _run_cmd_respond(event, cmd, caption=""):
    try:
        await event.edit("`Running…`")
    except Exception:
        pass
    try:
        out = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
    except subprocess.CalledProcessError as e:
        out = e.output.decode("utf-8", errors="replace") if e.output else str(e)
    out = out.strip() or "(no output)"
    header = f"**{caption}**\n" if caption else ""
    await event.respond(
        f"{header}```\n{out[:3800]}\n```\n🤖 **@stanlley-locke**",
        buttons=[[Button.inline("‹ Main Menu ›", b"menu")]]
    )


# ── services sub-menu ─────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"services"))
async def services_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return

    inline = [
        [Button.inline("🔁 Restart All",   b"resx"),       Button.inline("🔌 Reboot VPS",   b"reboot")],
        [Button.inline("🚀 Speedtest",      b"speedtest"),  Button.inline("🧹 Clear Log",    b"clearlog")],
        [Button.inline("🧹 Clear Cache",    b"clearcache"), Button.inline("🔌 Port Info",    b"port-info")],
        [Button.inline("📋 Running Svcs",   b"running"),    Button.inline("📶 Bandwidth",    b"bandwidth")],
        [Button.inline("🏥 Health Check",   b"health-menu"),Button.inline("🔃 Reload Stack", b"reload-stack")],
        [Button.inline("🔃 Update Script",  b"update-script"),Button.inline("🔔 Bot Notif", b"bot-notif")],
        [Button.inline("📜 Cert SSL",       b"cert-menu"),  Button.inline("📋 Banner",       b"banner-menu")],
        [Button.inline("💾 Backup/Restore", b"backer"),     Button.inline("🗑 Del Expired",  b"del-expired")],
        [Button.inline("⬅️ Main Menu",      b"menu")],
    ]
    try:
        await event.edit("**⚙️ Services & System Management**", buttons=inline)
    except Exception:
        await event.reply("**⚙️ Services & System Management**", buttons=inline)


# ── reboot ────────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"reboot"))
async def reboot_vps(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("✅ YES — Reboot now", b"reboot-confirm"),
         Button.inline("❌ Cancel",           b"menu")],
    ]
    try:
        await event.edit("⚠️ **Confirm VPS reboot?** Bot will be offline ~60s.", buttons=inline)
    except Exception:
        await event.reply("⚠️ **Confirm VPS reboot?**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"reboot-confirm"))
async def reboot_confirm(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await event.edit("🔌 **Rebooting VPS… back in ~60s.**")
    subprocess.Popen("sleep 2 && reboot", shell=True)


# ── restart all services ──────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"resx"))
async def restart_services(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "systemctl restart xray nginx haproxy dropbear ssh openvpn 2>&1; "
        "pkill -f ws.py; sleep 1; python3 /usr/bin/ws.py 10015 &>/dev/null & "
        "echo 'All services restarted.'",
        "🔁 Restart All Services")


# ── reload stack ──────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"reload-stack"))
async def reload_stack(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "reload-stack 2>&1 || restart 2>&1", "🔃 Reload Stack")


# ── speedtest ─────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"speedtest"))
async def speedtest(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "speedtest-cli --simple 2>&1", "🚀 Speedtest")


# ── clear log ─────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"clearlog"))
async def clearlog(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "clearlog 2>&1 || (journalctl --vacuum-time=1d && echo 'Logs cleared.')",
        "🧹 Clear Log")


# ── clear cache ───────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"clearcache"))
async def clearcache(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "sync && echo 3 > /proc/sys/vm/drop_caches && echo 'Cache cleared.'",
        "🧹 Clear Cache")


# ── running services ──────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"running"))
async def running_svcs(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "systemctl list-units --type=service --state=running --no-pager --no-legend | awk '{print $1}' | head -30",
        "📋 Running Services")


# ── bandwidth ─────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"bandwidth"))
async def bandwidth(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "bw 2>&1 || vnstat --oneline 2>&1 || cat /proc/net/dev | awk 'NR>2{print $1,$2,$10}'",
        "📶 Bandwidth Usage")


# ── health check ──────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"health-menu"))
async def health_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "health-check 2>&1", "🏥 Health Check")


# ── delete expired ────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"del-expired"))
async def del_expired(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "delexp 2>&1", "🗑 Delete Expired Accounts")


# ── update script ─────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"update-script"))
async def update_script(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "update.sh 2>&1 || bash /usr/local/sbin/update.sh 2>&1", "🔃 Update Script")


# ── cert SSL ──────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"cert-menu"))
async def cert_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("📜 Show Cert Info",  b"cert-info"),
         Button.inline("🔄 Renew Cert",      b"cert-renew")],
        [Button.inline("🔧 Fix Cert",        b"cert-fix"),
         Button.inline("⬅️ Back",            b"services")],
    ]
    try:
        await event.edit("**📜 SSL Certificate Management**", buttons=inline)
    except Exception:
        await event.reply("**📜 SSL Certificate Management**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"cert-info"))
async def cert_info(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "openssl x509 -in /etc/xray/xray.crt -noout -subject -issuer -dates 2>&1",
        "📜 Certificate Info")


@bot.on(events.CallbackQuery(data=b"cert-renew"))
async def cert_renew(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "cert-renew 2>&1", "🔄 Renew Certificate")


@bot.on(events.CallbackQuery(data=b"cert-fix"))
async def cert_fix(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "fixcert 2>&1", "🔧 Fix Certificate")


# ── bot notif ─────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"bot-notif"))
async def bot_notif(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("✅ Enable Notif",  b"notif-on"),
         Button.inline("❌ Disable Notif", b"notif-off")],
        [Button.inline("⬅️ Back",          b"services")],
    ]
    try:
        await event.edit("**🔔 Bot Notification Settings**", buttons=inline)
    except Exception:
        await event.reply("**🔔 Bot Notification Settings**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"notif-on"))
async def notif_on(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "add-bot-notif 2>&1", "✅ Bot Notifications Enabled")


@bot.on(events.CallbackQuery(data=b"notif-off"))
async def notif_off(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "del-bot-notif 2>&1", "❌ Bot Notifications Disabled")


# ── banner ────────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"banner-menu"))
async def banner_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "cat /etc/motd 2>/dev/null || echo 'No banner set.'", "📋 Current Banner")


# ── routing ───────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"routing-menu"))
async def routing_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("🌍 Global",   b"route-global"),  Button.inline("✂️ Split",    b"route-split")],
        [Button.inline("🚫 Adblock",  b"route-adblock"), Button.inline("🏠 Direct",   b"route-direct")],
        [Button.inline("📋 Current",  b"route-show"),    Button.inline("⬅️ Back",     b"menu")],
    ]
    try:
        await event.edit("**🛣️ Routing Profile**\nSelect a routing mode:", buttons=inline)
    except Exception:
        await event.reply("**🛣️ Routing Profile**", buttons=inline)


for _route in ["global", "split", "adblock", "direct"]:
    def _make_route_handler(r):
        @bot.on(events.CallbackQuery(data=f"route-{r}".encode()))
        async def _handler(event, _r=r):
            sender = await event.get_sender()
            if valid(str(sender.id)) != "true":
                await event.answer("Access Denied", alert=True)
                return
            await _run_cmd_respond(event, f"routing-profile {_r} 2>&1", f"🛣️ Routing: {_r}")
    _make_route_handler(_route)


@bot.on(events.CallbackQuery(data=b"route-show"))
async def route_show(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "cat /etc/xray/routing/current 2>/dev/null || echo 'No routing profile set.'",
        "📋 Current Routing Profile")


# ── CF setup ──────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"cf-menu"))
async def cf_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("🔧 CF Setup Wizard", b"cf-setup"),
         Button.inline("📋 CF Status",       b"cf-status")],
        [Button.inline("🔄 Sync CF IPs",     b"cf-sync-ips"),
         Button.inline("⬅️ Back",            b"menu")],
    ]
    try:
        await event.edit("**☁️ Cloudflare Management**", buttons=inline)
    except Exception:
        await event.reply("**☁️ Cloudflare Management**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"cf-setup"))
async def cf_setup(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "cf-setup status 2>&1", "☁️ Cloudflare Setup Status")


@bot.on(events.CallbackQuery(data=b"cf-status"))
async def cf_status(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    domain = open("/etc/xray/domain").read().strip() if os.path.isfile("/etc/xray/domain") else DOMAIN
    await _run_cmd_respond(event,
        f"curl -s https://cloudflare.com/cdn-cgi/trace | head -10; "
        f"echo '---'; dig +short {domain} | head -5",
        "☁️ Cloudflare Status")


@bot.on(events.CallbackQuery(data=b"cf-sync-ips"))
async def cf_sync_ips(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event,
        "curl -s https://www.cloudflare.com/ips-v4 > /etc/nginx/cloudflare-ips.conf && "
        "systemctl reload nginx && echo 'CF IPs synced and Nginx reloaded.'",
        "🔄 Sync Cloudflare IPs")


# ── CF tunnel ─────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"cftunnel-menu"))
async def cftunnel_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("📋 Tunnel Status",  b"cftunnel-status"),
         Button.inline("▶️ Start Tunnel",   b"cftunnel-start")],
        [Button.inline("⏹ Stop Tunnel",    b"cftunnel-stop"),
         Button.inline("⬅️ Back",          b"menu")],
    ]
    try:
        await event.edit("**🚇 Cloudflare Tunnel (cloudflared)**", buttons=inline)
    except Exception:
        await event.reply("**🚇 Cloudflare Tunnel**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"cftunnel-status"))
async def cftunnel_status(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "systemctl status cloudflared --no-pager 2>&1 | head -20", "🚇 CF Tunnel Status")


@bot.on(events.CallbackQuery(data=b"cftunnel-start"))
async def cftunnel_start(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "systemctl start cloudflared && echo 'CF Tunnel started.'", "▶️ CF Tunnel Start")


@bot.on(events.CallbackQuery(data=b"cftunnel-stop"))
async def cftunnel_stop(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "systemctl stop cloudflared && echo 'CF Tunnel stopped.'", "⏹ CF Tunnel Stop")


# ── subscription ──────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"sub-menu"))
async def sub_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("🔗 Show Sub URL",   b"sub-url"),
         Button.inline("🔄 Regen Token",    b"sub-regen")],
        [Button.inline("🧪 Test Sub",       b"sub-test"),
         Button.inline("⬅️ Back",          b"menu")],
    ]
    try:
        await event.edit("**📡 Subscription URL Manager**", buttons=inline)
    except Exception:
        await event.reply("**📡 Subscription URL Manager**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"sub-url"))
async def sub_url(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "sub-manage url 2>&1", "🔗 Subscription URL")


@bot.on(events.CallbackQuery(data=b"sub-regen"))
async def sub_regen(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "sub-manage regen 2>&1", "🔄 Regenerate Sub Token")


@bot.on(events.CallbackQuery(data=b"sub-test"))
async def sub_test(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "sub-manage test 2>&1", "🧪 Test Subscription")


# ── REALITY ───────────────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"reality-menu"))
async def reality_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("📋 REALITY Info",   b"reality-info"),
         Button.inline("🔑 Regen Keys",     b"reality-regen")],
        [Button.inline("➕ Add User",       b"reality-add"),
         Button.inline("⬅️ Back",          b"menu")],
    ]
    try:
        await event.edit("**🔮 REALITY Inbound (VLESS :8443)**", buttons=inline)
    except Exception:
        await event.reply("**🔮 REALITY Inbound**", buttons=inline)


@bot.on(events.CallbackQuery(data=b"reality-info"))
async def reality_info(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "reality-setup show 2>&1", "🔮 REALITY Info")


@bot.on(events.CallbackQuery(data=b"reality-regen"))
async def reality_regen(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    await _run_cmd_respond(event, "reality-setup regen 2>&1", "🔑 REALITY Keys Regenerated")


@bot.on(events.CallbackQuery(data=b"reality-add"))
async def reality_add(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    async with bot.conversation(chat) as conv:
        await event.respond("**REALITY username:**")
        user = (await conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))).raw_text.strip()
    await _run_cmd_respond(event, f"reality-setup add {user} 2>&1", f"🔮 REALITY User: {user}")


# ── backup / restore ──────────────────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"backup"))
async def backup(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    async with bot.conversation(chat) as conv:
        await event.respond("**Input email for backup:**")
        email = (await conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))).raw_text.strip()
    await _run_cmd_respond(event, f'printf "%s\\n" "{email}" | bot-backup 2>&1', "💾 Backup")


@bot.on(events.CallbackQuery(data=b"restore"))
async def restore(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    chat = event.chat_id
    async with bot.conversation(chat) as conv:
        await event.respond("**Input backup link:**")
        link = (await conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))).raw_text.strip()
    await _run_cmd_respond(event, f'printf "%s\\n" "{link}" | bot-restore 2>&1', "🔄 Restore")


@bot.on(events.CallbackQuery(data=b"backer"))
async def backer(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    inline = [
        [Button.inline("💾 Backup",  b"backup"),
         Button.inline("🔄 Restore", b"restore")],
        [Button.inline("⬅️ Back",   b"services")],
    ]
    try:
        await event.edit("**💾 Backup & Restore**", buttons=inline)
    except Exception:
        await event.reply("**💾 Backup & Restore**", buttons=inline)


# ── settings root (legacy compat) ─────────────────────────────────────────────

@bot.on(events.CallbackQuery(data=b"setting"))
async def settings_legacy(event):
    await services_menu(event)
