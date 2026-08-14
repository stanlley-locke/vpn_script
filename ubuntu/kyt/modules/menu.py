from kyt import *


def _svc(name):
    r = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
    return "✅" if r.stdout.strip() == "active" else "❌"


def _count(path, marker="#"):
    try:
        out = subprocess.check_output(
            f"grep -c '{marker}' {path} 2>/dev/null || echo 0", shell=True
        ).decode().strip()
        return out
    except Exception:
        return "0"


@bot.on(events.NewMessage(pattern=r"(?i)^(?:/menu|\.menu)$"))
@bot.on(events.CallbackQuery(data=b"menu"))
async def menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        try:
            await event.answer("Access Denied", alert=True)
        except Exception:
            await event.reply("Access Denied")
        return

    ssh  = _count("/etc/ssh/.ssh.db", "#ssh#")
    vms  = _count("/etc/vmess/.vmess.db", "#vmess#")
    vls  = _count("/etc/vless/.vless.db", "#vless#")
    trj  = _count("/etc/trojan/.trojan.db", "#trojan#")
    ss   = _count("/etc/shadowsocks/.ss.db", "#ss#")

    os_name = subprocess.check_output(
        "grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'",
        shell=True).decode().strip()
    ip_vps = subprocess.check_output("curl -s ipv4.icanhazip.com", shell=True).decode().strip()
    uptime = subprocess.check_output("uptime -p", shell=True).decode().strip()
    ram    = subprocess.check_output(
        "free -m | awk '/Mem/{print $3\"/\"$2\" MB\"}'", shell=True).decode().strip()

    svc_ssh  = _svc("ssh")
    svc_ngx  = _svc("nginx")
    svc_xray = _svc("xray")
    svc_ws   = "✅" if subprocess.run("pgrep -f ws.py", shell=True, capture_output=True).returncode == 0 else "❌"
    svc_db   = _svc("dropbear")
    svc_hap  = _svc("haproxy")

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**⚡ VPN SCRIPT ADMIN PANEL ⚡**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» OS      :** `{os_name}`
**» Domain  :** `{DOMAIN}`
**» IP VPS  :** `{ip_vps}`
**» RAM     :** `{ram}`
**» Uptime  :** `{uptime}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**» SSH/OVPN    :** `{ssh}` accounts
**» VMess       :** `{vms}` accounts
**» VLess       :** `{vls}` accounts
**» Trojan      :** `{trj}` accounts
**» Shadowsocks :** `{ss}` accounts
**━━━━━━━━━━━━━━━━━━━━━━━**
SSH:{svc_ssh} NGX:{svc_ngx} XRAY:{svc_xray} WS:{svc_ws} DB:{svc_db} HAP:{svc_hap}
**━━━━━━━━━━━━━━━━━━━━━━━**"""

    inline = [
        [Button.inline("🔐 SSH / OVPN", b"ssh"),       Button.inline("🎭 VMess",      b"vmess")],
        [Button.inline("🗼 VLess",       b"vless"),     Button.inline("🎯 Trojan",     b"trojan")],
        [Button.inline("🌑 Shadowsocks", b"shadowsocks"),Button.inline("📊 VPS Info",  b"info")],
        [Button.inline("⚙️ Services",    b"services"),  Button.inline("🌐 HTTP Custom",b"httpcustom")],
        [Button.inline("📡 Subscription",b"sub-menu"),  Button.inline("🔮 REALITY",    b"reality-menu")],
        [Button.inline("☁️ CF Setup",    b"cf-menu"),   Button.inline("🚇 CF Tunnel",  b"cftunnel-menu")],
        [Button.inline("🛣️ Routing",     b"routing-menu"),Button.inline("🏥 Health",   b"health-menu")],
        [Button.inline("💾 Backup",      b"backer"),    Button.inline("🔄 Reload Stack",b"reload-stack")],
        [Button.inline("🚀 Speedtest",   b"speedtest"), Button.inline("🧹 Clear Log",  b"clearlog")],
        [Button.inline("🔁 Restart All", b"resx"),      Button.inline("🔌 Reboot VPS", b"reboot")],
        [Button.inline("📜 Cert SSL",    b"cert-menu"), Button.inline("🔔 Bot Notif",  b"bot-notif")],
        [Button.inline("🔃 Update Script",b"update-script"),Button.inline("📋 Banner", b"banner-menu")],
        [Button.inline("⬅️ Back",        b"start")],
    ]

    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.reply(msg, buttons=inline)
