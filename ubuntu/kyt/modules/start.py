from kyt import *


@bot.on(events.NewMessage(pattern=r"(?i)^(?:/start|\.start)$"))
@bot.on(events.CallbackQuery(data=b"start"))
async def start(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        try:
            await event.answer("Access Denied", alert=True)
        except Exception:
            await event.reply("Access Denied")
        return

    os_name = subprocess.check_output(
        "grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"'",
        shell=True).decode().strip()
    ip_vps  = subprocess.check_output("curl -s ipv4.icanhazip.com", shell=True).decode().strip()
    uptime  = subprocess.check_output("uptime -p", shell=True).decode().strip()
    ram     = subprocess.check_output(
        "free -m | awk '/Mem/{print $3\"/\"$2\" MB\"}'", shell=True).decode().strip()
    cpu     = subprocess.check_output(
        "nproc", shell=True).decode().strip()
    isp     = subprocess.check_output(
        "curl -s ipinfo.io/org | cut -d' ' -f2-", shell=True).decode().strip()
    city    = subprocess.check_output(
        "curl -s ipinfo.io/city", shell=True).decode().strip()

    msg = f"""**━━━━━━━━━━━━━━━━━━━━━━━**
**⚡ stanlley-locke VPN Script ⚡**
**━━━━━━━━━━━━━━━━━━━━━━━**
**» OS      :** `{os_name}`
**» CPU     :** `{cpu} core(s)`
**» RAM     :** `{ram}`
**» Uptime  :** `{uptime}`
**» Domain  :** `{DOMAIN}`
**» IP VPS  :** `{ip_vps}`
**» ISP     :** `{isp}`
**» City    :** `{city}`
**━━━━━━━━━━━━━━━━━━━━━━━**
🤖 **@stanlley-locke**"""

    inline = [
        [Button.inline("📋 ADMIN PANEL", b"menu")],
        [Button.url("GitHub Repo", "https://github.com/stanlley-locke/vpn_script"),
         Button.url("README",      "https://github.com/stanlley-locke/vpn_script#readme")],
    ]

    try:
        await event.edit(msg, buttons=inline)
    except Exception:
        await event.reply(msg, buttons=inline)
