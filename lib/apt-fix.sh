#!/bin/bash
# Safe PPA cleanup — never call add-apt-repository (can segfault on Ubuntu 26.04)
cleanup_broken_haproxy_ppa() {
    rm -f /etc/apt/sources.list.d/*vbernat* 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
    sed -i '/vbernat\/haproxy/d' /etc/apt/sources.list 2>/dev/null || true
    sed -i '/haproxy.debian.net/d' /etc/apt/sources.list 2>/dev/null || true
}

# Portable download (prefer wget — curl can segfault on some Ubuntu 26.04 images)
vpn_download() {
    local url="$1" dest="$2"
    if command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url" && return 0
    fi
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest" && return 0
    fi
    return 1
}

vpn_public_ip() {
    wget -qO- --timeout=10 ipv4.icanhazip.com 2>/dev/null \
        || curl -4 -sS --max-time 10 ipv4.icanhazip.com 2>/dev/null \
        || echo ""
}
