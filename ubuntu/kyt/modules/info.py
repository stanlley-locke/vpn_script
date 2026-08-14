from kyt import *


def _svc_status(name):
    r = subprocess.run(["systemctl", "is-active", name], capture_output=True, text=True)
    return "ON ✅" if r.stdout.strip() == "active" else "OFF ❌"


@bot.on(events.CallbackQuery(data=b"info"))
async def info_vps(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return

    try:
        await event.edit("`Gathering VPS info…`")
    except Exception:
        pass

    os_name  = subprocess.check_output("grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'", shell=True).decode().strip()
    cpu      = subprocess.check_output("nproc", shell=True).decode().strip()
    ram      = subprocess.check_output("free -m | awk '/Mem/{print $3\"/\"$2\" MB\"}'", shell=True).decode().strip()
    disk     = subprocess.check_output("df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\" used)\"}'", shell=True).decode().strip()
    uptime   = subprocess.check_output("uptime -p", shell=True).decode().strip()
    load     = subprocess.check_output("uptime | awk -F'load average:' '{print $2}'", shell=True).decode().strip()
    ip_vps   = subprocess.check_output("curl -s ipv4.icanhazip.com", shell=True).decode().strip()
    isp      = subprocess.check_output("curl -s ipinfo.io/org | cut -d' ' -f2-", shell=True).decode().strip()
    city     = subprocess.check_output("curl -s ipinfo.io/city", shell=True).decode().strip()
    country  = subprocess.check_output("curl -s ipinfo.io/country", shell=True).decode().strip()

    ssh_svc  = _svc_status("ssh")
    ngx_svc  = _svc_status("nginx")
    xray_svc = _svc_status("xray")
    hap_svc  = _svc_status("haproxy")
    db_svc   = _svc_status("dropbear")
    ovpn_svc = _svc_status("openvpn")
    ws_svc   = "ON ✅" if subprocess.run("pgrep -f ws.py", shell=True, capture_output=True).returncode == 0 else "OFF ❌"
    f2b_svc  = _svc_status("fail2ban")

    ssh_count  = subprocess.check_output("grep -c '#ssh#' /etc/ssh/.ssh.db 2>/dev/null || echo 0", shell=True).decode().strip()
    vms_count  = subprocess.check_output("grep -c '#vmess#' /etc/vmess/.vmess.db 2>/dev/null || echo 0", shell=True).decode().strip()
    vls_count  = subprocess.check_output("grep -c '#vless#' /etc/vless/.vless.db 2>/dev/null || echo 0", shell=True).decode().strip()
    trj_count  = subprocess.check_output("grep -c '#trojan#' /etc/trojan/.trojan.db 2>/dev/null || echo 0", shell=True).decode().strip()
    ss_count   = subprocess.check_output("grep -c '#ss#' /etc/shadowsocks/.ss.db 2>/dev/null || echo 0", shell=True).decode().strip()

    ports = subprocess.check_output(
        "ss -tlnp | awk 'NR>1{print $4}' | grep -oP ':\\K[0-9]+' | sort -un | tr '\\n' ' '",
        shell=True).decode().strip()

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**📊 VPS INFORMATION**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» OS      :** `{os_name}`
**» CPU     :** `{cpu} core(s)`
**» RAM     :** `{ram}`
**» Disk    :** `{disk}`
**» Uptime  :** `{uptime}`
**» Load    :** `{load}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**» IP VPS  :** `{ip_vps}`
**» Domain  :** `{DOMAIN}`
**» ISP     :** `{isp}`
**» City    :** `{city}, {country}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**📦 ACCOUNTS**
**» SSH/OVPN    :** `{ssh_count}`
**» VMess       :** `{vms_count}`
**» VLess       :** `{vls_count}`
**» Trojan      :** `{trj_count}`
**» Shadowsocks :** `{ss_count}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**🔧 SERVICES**
**» SSH      :** {ssh_svc}   **» Nginx   :** {ngx_svc}
**» Xray     :** {xray_svc}  **» HAProxy :** {hap_svc}
**» Dropbear :** {db_svc}    **» OpenVPN :** {ovpn_svc}
**» WS-ePRO  :** {ws_svc}    **» Fail2ban:** {f2b_svc}
**━━━━━━━━━━━━━━━━━━━━━━━**
**🔌 LISTENING PORTS**
`{ports}`
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""

    await event.respond(msg, buttons=[[Button.inline("‹ Main Menu ›", b"menu")]])


@bot.on(events.CallbackQuery(data=b"port-info"))
async def port_info(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**🔌 PORT INFORMATION**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» Domain         :** `{DOMAIN}`
**━━━━━━━━━━━━━━━━━━━━━━━**
**SSH / OVPN**
**» OpenSSH        :** `22, 80, 443`
**» Dropbear       :** `109, 443`
**» SSH WS         :** `80, 8080, 8081-9999`
**» SSH SSL WS     :** `443`
**» SSL/TLS        :** `222-1000`
**━━━━━━━━━━━━━━━━━━━━━━━**
**XRAY**
**» VLESS/VMess WS :** `443, 80`
**» VLESS/VMess gRPC:** `443`
**» REALITY        :** `8443`
**━━━━━━━━━━━━━━━━━━━━━━━**
**OpenVPN**
**» OVPN WS SSL    :** `443`
**» OVPN TCP       :** `443, 1194`
**» OVPN UDP       :** `2200`
**━━━━━━━━━━━━━━━━━━━━━━━**
**Other**
**» Proxy Squid    :** `3128`
**» BadVPN UDP     :** `7100, 7300`
**» SlowDNS        :** `5300 UDP`
**» Subscription   :** `443 /sub/<token>`
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""

    await event.respond(msg, buttons=[[Button.inline("‹ Main Menu ›", b"menu")]])
