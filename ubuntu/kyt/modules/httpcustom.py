from kyt import *
import glob
import os

HTTPC_LIB = "/usr/local/lib/vpn_script/httpcustom"
HTTPC_EXPORT = "/usr/local/sbin/httpcustom-export"


def _load_profiles():
    path = os.path.join(HTTPC_LIB, "profiles.json")
    if not os.path.isfile(path):
        return []
    with open(path) as f:
        return json.load(f).get("profiles", [])


def _run_export(profile_id, ssh_user, ssh_pass=None):
    cmd = [HTTPC_EXPORT, "export-v5", profile_id, ssh_user]
    if ssh_pass:
        cmd.append(ssh_pass)
    out = subprocess.check_output(cmd, stderr=subprocess.STDOUT).decode("utf-8", errors="replace")
    return out


@bot.on(events.NewMessage(pattern=r"(?i)^(?:/httpcustom|\.httpcustom)$"))
@bot.on(events.CallbackQuery(data=b"httpcustom"))
async def httpcustom_menu(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        try:
            await event.answer("Access Denied", alert=True)
        except Exception:
            await event.reply("Access Denied")
        return

    profiles = _load_profiles()
    buttons = []
    row = []
    for i, p in enumerate(profiles[:12]):
        pid = p.get("id", "")
        name = p.get("name", pid)[:28]
        row.append(Button.inline(name, f"httpc:{pid}".encode()))
        if len(row) == 2:
            buttons.append(row)
            row = []
    if row:
        buttons.append(row)
    buttons.append([Button.inline(" List all profiles ", b"httpc-list")])
    buttons.append([Button.inline(" Subscription URL ", b"httpc-sub"), Button.inline(" REALITY info ", b"httpc-reality")])
    buttons.append([Button.inline(" ‹ Main Menu › ", b"menu")])

    msg = """
━━━━━━━━━━━━━━━━━━━━━━━
**HTTP Custom Export**
━━━━━━━━━━━━━━━━━━━━━━━
Select a carrier/profile to export a v5 JSON config for the HTTP Custom app.

Supported carriers include Safaricom, Airtel, MTN, Vodacom profiles.
"""
    try:
        await event.edit(msg, buttons=buttons)
    except Exception:
        await event.reply(msg, buttons=buttons)


@bot.on(events.CallbackQuery(pattern=b"httpc-list"))
async def httpcustom_list(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    profiles = _load_profiles()
    lines = ["**Available profiles:**\n"]
    for p in profiles:
        lines.append(f"• `{p.get('id')}` — {p.get('name')}")
    await event.edit("\n".join(lines), buttons=[[Button.inline("‹ Back ", b"httpcustom")]])


@bot.on(events.CallbackQuery(pattern=b"httpc-sub"))
async def httpcustom_sub(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    try:
        out = subprocess.check_output(["/usr/local/sbin/sub-manage", "url"], text=True)
    except Exception as e:
        out = f"Subscription not configured: {e}"
    await event.edit(f"```\n{out}\n```", buttons=[[Button.inline("‹ Back ", b"httpcustom")]])


@bot.on(events.CallbackQuery(pattern=b"httpc-reality"))
async def httpcustom_reality(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    path = "/etc/xray/reality.json"
    if os.path.isfile(path):
        with open(path) as f:
            data = json.load(f)
        msg = f"**REALITY port:** `{data.get('port', 8443)}`\n**Public key:** `{data.get('publicKey','')}`\n**Short ID:** `{data.get('shortId','')}`"
    else:
        msg = "REALITY not installed. Use menu option **31 REALITY** on VPS."
    await event.edit(msg, buttons=[[Button.inline("‹ Back ", b"httpcustom")]])


@bot.on(events.CallbackQuery(pattern=b"httpc:"))
async def httpcustom_export_cb(event):
    sender = await event.get_sender()
    if valid(str(sender.id)) != "true":
        await event.answer("Access Denied", alert=True)
        return
    profile_id = event.data.decode().split(":", 1)[1]
    chat = event.chat_id
    async with bot.conversation(chat) as conv:
        await event.edit(f"Profile: `{profile_id}`\n\n**SSH username to embed:**")
        resp = conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))
        ssh_user = (await resp).raw_text.strip()
        await event.respond("**SSH password (optional, send `-` to skip):**")
        resp2 = conv.wait_event(events.NewMessage(incoming=True, from_users=sender.id))
        ssh_pass = (await resp2).raw_text.strip()
        if ssh_pass == "-":
            ssh_pass = None
    await event.respond("Exporting HTTP Custom profile…")
    try:
        raw = _run_export(profile_id, ssh_user, ssh_pass)
        out_dir = f"/tmp/httpc-{profile_id}-{ssh_user}.json"
        with open(out_dir, "w") as f:
            f.write(raw)
        await bot.send_file(chat, out_dir, caption=f"HTTP Custom v5 — `{profile_id}`")
        txt_path = out_dir.replace(".json", ".txt")
        if os.path.isfile(txt_path):
            await bot.send_file(chat, txt_path, caption="Plain-text payload summary")
    except subprocess.CalledProcessError as e:
        await event.respond(f"Export failed:\n```\n{e.output.decode() if e.output else e}\n```")
    except Exception as e:
        await event.respond(f"Export failed: `{e}`")
