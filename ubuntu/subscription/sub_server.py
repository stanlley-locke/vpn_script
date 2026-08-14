#!/usr/bin/env python3
"""Subscription server for Hiddify / Sing-box / v2rayNG — stanlley-locke/vpn_script"""
import base64
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import unquote

CONFIG = "/etc/vpn_script/config"
DOMAIN_FILE = "/etc/xray/domain"
TOKEN_FILE = "/etc/vpn_script/subscription.token"
PORT = int(os.environ.get("SUB_PORT", "8099"))


def load_config():
    cfg = {}
    if os.path.isfile(CONFIG):
        with open(CONFIG) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    k, v = line.split("=", 1)
                    cfg[k.strip()] = v.strip().strip('"')
    return cfg


def get_token():
    cfg = load_config()
    if cfg.get("SUBSCRIPTION_TOKEN"):
        return cfg["SUBSCRIPTION_TOKEN"]
    if os.path.isfile(TOKEN_FILE):
        return open(TOKEN_FILE).read().strip()
    return ""


def get_domain():
    if os.path.isfile(DOMAIN_FILE):
        d = open(DOMAIN_FILE).read().strip()
        if d:
            return d
    cfg = load_config()
    if cfg.get("CF_DOMAIN"):
        return cfg["CF_DOMAIN"]
    return "localhost"


def path_prefix(cfg):
    prefix = cfg.get("HTTP_APP_PREFIX", "")
    base = cfg.get("PATH_VMESS", "/vmess")
    if prefix:
        return prefix.rstrip("/") + base
    return base


def collect_links():
    domain = get_domain()
    cfg = load_config()
    links = []
    prefix_vless = cfg.get("PATH_VLESS", "/vless")
    prefix_vmess = path_prefix(cfg)
    prefix_trojan = cfg.get("PATH_TROJAN", "/trojan-ws")
    if cfg.get("HTTP_APP_PREFIX"):
        p = cfg["HTTP_APP_PREFIX"].rstrip("/")
        prefix_vless = p + prefix_vless
        prefix_trojan = p + prefix_trojan

    sni = cfg.get("SNI_FRONTING") or domain

    try:
        with open("/etc/xray/config.json") as f:
            xray = json.load(f)
    except OSError:
        return []

    for ib in xray.get("inbounds", []):
        proto = ib.get("protocol")
        net = ib.get("streamSettings", {}).get("network", "")
        clients = ib.get("settings", {}).get("clients", [])
        for c in clients:
            email = c.get("email", "")
            if not email or email.startswith("default@"):
                continue
            uid = c.get("id") or c.get("password", "")
            if proto == "vless" and net == "ws":
                links.append(
                    f"vless://{uid}@{domain}:443?encryption=none&security=tls&type=ws"
                    f"&host={domain}&path={prefix_vless}&sni={sni}#{email}"
                )
            elif proto == "vless" and net == "grpc":
                svc = ib.get("streamSettings", {}).get("grpcSettings", {}).get("serviceName", "vless-grpc")
                links.append(
                    f"vless://{uid}@{domain}:443?encryption=none&security=tls&type=grpc"
                    f"&serviceName={svc}&sni={sni}#{email}"
                )
            elif proto == "vmess" and net == "ws":
                links.append(
                    f"vmess://{base64.b64encode(json.dumps({'v':'2','ps':email,'add':domain,'port':'443','id':uid,'aid':'0','net':'ws','type':'none','host':domain,'path':prefix_vmess,'tls':'tls','sni':sni,'scy':'auto'}).encode()).decode()}"
                )
            elif proto == "trojan" and net == "ws":
                links.append(
                    f"trojan://{uid}@{domain}:443?security=tls&type=ws&host={domain}"
                    f"&path={prefix_trojan}&sni={sni}#{email}"
                )

    # REALITY users from separate file
    reality_file = "/etc/xray/reality-users.json"
    if os.path.isfile(reality_file):
        try:
            ru = json.load(open(reality_file))
            rp = ru.get("params", {})
            pbk = rp.get("publicKey", "")
            sid = rp.get("shortId", "")
            port = rp.get("port", 8443)
            for u in ru.get("users", []):
                links.append(
                    f"vless://{u['uuid']}@{domain}:{port}?encryption=none&security=reality"
                    f"&type=tcp&flow=xtls-rprx-vision&sni={rp.get('dest','www.microsoft.com')}"
                    f"&fp=chrome&pbk={pbk}&sid={sid}#{u['email']}"
                )
        except (json.JSONDecodeError, KeyError):
            pass

    return links


class SubHandler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def do_GET(self):
        path = unquote(self.path.split("?")[0])
        m = re.match(r"^/sub/([A-Za-z0-9_-]+)/?$", path)
        if not m:
            self.send_error(404)
            return
        token = m.group(1)
        if token != get_token():
            self.send_error(403, "Invalid subscription token")
            return
        links = collect_links()
        body = base64.b64encode("\n".join(links).encode()).decode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Profile-Update-Interval", "24")
        self.send_header("Subscription-Userinfo", f"upload=0; download=0; total=0; expire=0")
        self.end_headers()
        self.wfile.write(body.encode())

    def do_HEAD(self):
        self.do_GET()


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "generate-token":
        import secrets
        t = secrets.token_urlsafe(24)
        os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
        open(TOKEN_FILE, "w").write(t)
        d = get_domain()
        print(f"Token saved to {TOKEN_FILE}")
        print(f"Subscription URL: https://{d}/sub/{t}")
        return
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        links = collect_links()
        print("\n".join(links) if links else "(no user links)")
        return
    HTTPServer(("127.0.0.1", PORT), SubHandler).serve_forever()


if __name__ == "__main__":
    main()
