#!/bin/bash
# VPN Script — Multi-protocol proxy installer
# Author  : stanlley-locke
# Repo    : https://github.com/stanlley-locke/vpn_script
# OS      : Debian 10+ / Ubuntu 18.04–26.04 (x86_64)

export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a

# Optional env file (set by install.sh or manually)
for _envf in "${VPN_ENV_FILE:-}" /root/vpn_script.env ./vpn_script.env; do
    [[ -n "$_envf" && -f "$_envf" ]] || continue
    set -a
    # shellcheck source=/dev/null
    source "$_envf"
    set +a
    break
done
unset _envf

Green="\e[92;1m"
RED="\033[31m"
YELLOW="\033[33m"
BLUE="\033[36m"
FONT="\033[0m"
GREENBG="\033[42;37m"
REDBG="\033[41;37m"
OK="${Green}  »${FONT}"
ERROR="${RED}[ERROR]${FONT}"
GRAY="\e[1;30m"
NC='\e[0m'
red='\e[1;31m'
green='\e[0;32m'

function genz_show_banner() {
    export IP=$(wget -qO- --timeout=10 ipv4.icanhazip.com 2>/dev/null || echo "${VPS_PUBLIC_IP:-}")
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Script : ${BLUE}VPN Script${NC} — Multi-protocol Proxy"
    echo -e "  Author : ${GREEN}stanlley-locke${NC}"
    echo -e "  Repo   : ${BLUE}github.com/stanlley-locke/vpn_script${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${OK} Your Architecture Is Supported ( ${green}$(uname -m)${NC} )"
    echo -e "${OK} Your OS Is Supported ( ${green}$(. /etc/os-release; echo "$PRETTY_NAME")${NC} )"
    [[ -n "$IP" ]] && echo -e "${OK} IP Address ( ${green}$IP${NC} )"
    echo ""
    if [[ "${VPN_AUTO_INSTALL:-0}" != "1" ]]; then
        read -rp "Press Enter to start installation..."
    else
        echo "Auto-install enabled."
    fi
    echo ""
}

function genz_prepare() {
    [[ "${EUID:-0}" -ne 0 ]] && { echo "Run as root"; exit 1; }
    REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley-locke/vpn_script/main/}"
    mkdir -p /usr/local/lib/vpn_script /etc/vpn_script /etc/xray
    wget -qO /usr/local/lib/vpn_script/common.sh "${REPO}lib/common.sh" 2>/dev/null || true
    [[ -f /usr/local/lib/vpn_script/common.sh ]] && source /usr/local/lib/vpn_script/common.sh
    rm -f /etc/apt/sources.list.d/*vbernat* /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
    sed -i '/vbernat\/haproxy/d' /etc/apt/sources.list 2>/dev/null || true
    echo -e "\e[32mloading...\e[0m"
}

####
start=$(date +%s)
secs_to_human() {
    echo "Installation time : $((${1} / 3600)) hours $(((${1} / 60) % 60)) minute's $((${1} % 60)) seconds"
}
### Status
function print_ok() {
    echo -e "${OK} ${BLUE} $1 ${FONT}"
}
function print_install() {
	echo -e "${green} â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â” ${FONT}"
    echo -e "${YELLOW} Â» $1 ${FONT}"
	echo -e "${green} â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â” ${FONT}"
    sleep 1
}

function print_error() {
    echo -e "${ERROR} ${REDBG} $1 ${FONT}"
}

function print_success() {
    if [[ 0 -eq $? ]]; then
		echo -e "${green} â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â” ${FONT}"
        echo -e "${Green} Â» $1 installed successfully"
		echo -e "${green} â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â” ${FONT}"
        sleep 2
    fi
}

### Cek root
function is_root() {
    if [[ 0 == "$UID" ]]; then
        print_ok "Root user Start installation process"
    else
        print_error "The current user is not the root user, please switch to the root user and run the script again"
    fi

}

# (early xray bootstrap moved into make_folder_xray)

# Change Environment System

function install_haproxy() {
    print_install "Installing HAProxy"
    rm -f /etc/apt/sources.list.d/*vbernat* /etc/apt/sources.list.d/haproxy.list 2>/dev/null || true
    sed -i '/vbernat\/haproxy/d' /etc/apt/sources.list 2>/dev/null || true
    apt-get update -y || true
    mkdir -p /etc/haproxy
    apt-get install -y haproxy
    print_success "HAProxy"
}

function first_setup(){
    timedatectl set-timezone Asia/Jakarta
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    print_success "Directory Xray"
    echo "Setup Dependencies $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
    install_haproxy
}

# GEO PROJECT
function nginx_install() {
    # // Checking System
    if [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "ubuntu" ]]; then
        print_install "Setup nginx For OS Is $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
        # // sudo add-apt-repository ppa:nginx/stable -y 
        sudo apt-get install nginx -y 
    elif [[ $(cat /etc/os-release | grep -w ID | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/ID//g') == "debian" ]]; then
        print_success "Setup nginx For OS Is $(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')"
        apt -y install nginx 
    else
        echo -e " Your OS Is Not Supported ( ${YELLOW}$(cat /etc/os-release | grep -w PRETTY_NAME | head -n1 | sed 's/=//g' | sed 's/"//g' | sed 's/PRETTY_NAME//g')${FONT} )"
        # // exit 1
    fi
}

# Update and remove packages
function base_package() {
    clear
    print_install "Installing the Required Packages"
    apt-get update -y || true
    apt-get install -y zip pwgen openssl netcat-openbsd socat cron bash-completion figlet jq dnsutils || true
    apt-get install -y chrony || apt-get install -y chronyd || true
    systemctl enable chrony 2>/dev/null || systemctl enable chronyd 2>/dev/null || true
    systemctl restart chrony 2>/dev/null || systemctl restart chronyd 2>/dev/null || true
    chronyc -a makestep 2>/dev/null || true
    apt-get install -y sudo debconf-utils || true
    apt-get remove --purge -y exim4 ufw firewalld 2>/dev/null || true
    apt-get autoremove -y || true
    apt-get install -y --no-install-recommends software-properties-common || true
    echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
    echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
    apt-get install -y speedtest-cli vnstat libnss3-dev libnspr4-dev pkg-config libpam0g-dev \
        libcap-ng-dev libcap-ng-utils libselinux1-dev libcurl4-nss-dev flex bison make libnss3-tools \
        libevent-dev bc rsyslog dos2unix zlib1g-dev libssl-dev libsqlite3-dev sed dirmngr \
        libxml-parser-perl build-essential gcc g++ python3 python3-pip htop lsof tar wget curl ruby \
        zip unzip p7zip-full libc6 util-linux msmtp-mta ca-certificates bsd-mailx iptables \
        iptables-persistent netfilter-persistent net-tools gnupg gnupg2 lsb-release shc cmake git \
        screen xz-utils apt-transport-https dnsutils cron bash-completion openvpn easy-rsa || true
    print_success "Required Packages"
}
# Fungsi input domain
function pasang_domain() {
echo -e ""
if [[ -n "${VPN_DOMAIN:-}" ]]; then
    echo -e " \e[1;32mUsing domain from environment: ${VPN_DOMAIN}\e[0m"
    echo "$VPN_DOMAIN" > /etc/xray/domain
    echo "$VPN_DOMAIN" > /root/domain
    mkdir -p /var/lib/kyt
    echo "IP=${VPS_PUBLIC_IP:-$(wget -qO- --timeout=10 ipv4.icanhazip.com 2>/dev/null || echo "")}" >> /var/lib/kyt/ipvps.conf
    print_success "Domain ${VPN_DOMAIN}"
    return 0
fi
echo -e " â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo -e " \e[1;32mPlease Select a Domain Type Below \e[0m"
echo -e " â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
echo -e " \e[1;32m1)\e[0m Use Your Own Domain (Recommended)"
echo -e " \e[1;32m2)\e[0m Use Random Domain"
echo -e " â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”"
read -p " Please select numbers 1-2 or Any Button(Random) : " host
echo ""
if [[ $host == "1" ]]; then
echo -e " \e[1;32mPlease Enter Your Subdomain $NC"
echo -e " â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\033[0m"
echo -e ""
read -p " Input Domain : " host1
echo -e ""
echo -e " â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”â”\033[0m"
echo "IP=" >> /var/lib/kyt/ipvps.conf
echo $host1 > /etc/xray/domain
echo $host1 > /root/domain
echo ""
elif [[ $host == "2" ]]; then
#install cf
wget ${REPO}ubuntu/cf.sh && chmod +x cf.sh && ./cf.sh
rm -f /root/cf.sh
else
print_install "Random Subdomain/Domain is Used"
    fi
}

# Post-install: optional license metadata + notification
restart_system(){
MYIP=$(wget -qO- --timeout=10 ipv4.icanhazip.com 2>/dev/null || echo "${VPS_PUBLIC_IP:-}")
domain=$(cat /etc/xray/domain 2>/dev/null || cat /root/domain 2>/dev/null || echo "unknown")
izinsc="${VPN_KEYGEN_URL:-${REPO}keygen}"

if [[ "${LICENSE_CHECK:-0}" == "1" ]]; then
    username=$(wget -qO- --timeout=15 "$izinsc" 2>/dev/null | grep "$MYIP" | awk '{print $2}')
    expx=$(wget -qO- --timeout=15 "$izinsc" 2>/dev/null | grep "$MYIP" | awk '{print $3}')
else
    username="${VPN_AUTHOR:-stanlley-locke}"
    expx="self-hosted"
fi
echo "$username" >/usr/bin/user
echo "$expx" >/usr/bin/e

vpn_load_config 2>/dev/null || true
vpn_send_install_notify
}
# Pasang SSL
function pasang_ssl() {
clear
clear
print_install "Installing SSL On Domain"
    rm -rf /etc/xray/xray.key
    rm -rf /etc/xray/xray.crt
    domain=$(cat /root/domain)
    STOPWEBSERVER=$(lsof -i:80 | cut -d' ' -f1 | awk 'NR==2 {print $1}')
    rm -rf /root/.acme.sh
    mkdir /root/.acme.sh
    systemctl stop $STOPWEBSERVER
    systemctl stop nginx
    wget -qO /root/.acme.sh/acme.sh https://acme-install.netlify.app/acme.sh || wget -qO /root/.acme.sh/acme.sh https://raw.githubusercontent.com/acmesh-official/acme.sh/master/acme.sh -o /root/.acme.sh/acme.sh
    chmod +x /root/.acme.sh/acme.sh
    /root/.acme.sh/acme.sh --upgrade --auto-upgrade
    /root/.acme.sh/acme.sh --set-default-ca --server letsencrypt
    /root/.acme.sh/acme.sh --issue -d $domain --standalone -k ec-256
    ~/.acme.sh/acme.sh --installcert -d $domain --fullchainpath /etc/xray/xray.crt --keypath /etc/xray/xray.key --ecc
    chmod 777 /etc/xray/xray.key
    print_success "SSL Certificate"
}

function make_folder_xray() {
rm -rf /etc/vmess/.vmess.db
    rm -rf /etc/vless/.vless.db
    rm -rf /etc/trojan/.trojan.db
    rm -rf /etc/shadowsocks/.shadowsocks.db
    rm -rf /etc/ssh/.ssh.db
    rm -rf /etc/bot/.bot.db
    rm -rf /etc/user-create/user.log
    mkdir -p /etc/bot
    mkdir -p /etc/xray
    wget -qO- --timeout=5 ifconfig.me 2>/dev/null > /etc/xray/ipvps || echo "${IP:-${VPS_PUBLIC_IP:-127.0.0.1}}" > /etc/xray/ipvps
    mkdir -p /etc/vmess
    mkdir -p /etc/vless
    mkdir -p /etc/trojan
    mkdir -p /etc/shadowsocks
    mkdir -p /etc/ssh
    mkdir -p /usr/bin/xray/
    mkdir -p /var/log/xray/
    mkdir -p /var/www/html
    mkdir -p /etc/kyt/limit/vmess/ip
    mkdir -p /etc/kyt/limit/vless/ip
    mkdir -p /etc/kyt/limit/trojan/ip
    mkdir -p /etc/kyt/limit/ssh/ip
    mkdir -p /etc/limit/vmess
    mkdir -p /etc/limit/vless
    mkdir -p /etc/limit/trojan
    mkdir -p /etc/limit/ssh
    mkdir -p /etc/user-create
    chmod +x /var/log/xray
    touch /etc/xray/domain
    touch /var/log/xray/access.log
    touch /var/log/xray/error.log
    touch /etc/vmess/.vmess.db
    touch /etc/vless/.vless.db
    touch /etc/trojan/.trojan.db
    touch /etc/shadowsocks/.shadowsocks.db
    touch /etc/ssh/.ssh.db
    touch /etc/bot/.bot.db
    echo "& plughin Account" >>/etc/vmess/.vmess.db
    echo "& plughin Account" >>/etc/vless/.vless.db
    echo "& plughin Account" >>/etc/trojan/.trojan.db
    echo "& plughin Account" >>/etc/shadowsocks/.shadowsocks.db
    echo "& plughin Account" >>/etc/ssh/.ssh.db
    echo "echo -e 'Vps Config User Account'" >> /etc/user-create/user.log
    }
#Instal Xray
function install_xray() {
clear
clear
    print_install "Core Xray 1.8.1 Latest Version"
    domainSock_dir="/run/xray";! [ -d $domainSock_dir ] && mkdir  $domainSock_dir
    chown www-data.www-data $domainSock_dir
    
    # / / Ambil Xray Core Version Terbaru
latest_version="$(wget -qO- --timeout=15 https://api.github.com/repos/XTLS/Xray-core/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"
bash -c "$(wget -qO- https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u www-data --version $latest_version
 
    # // Ambil Config Server
    wget -O /etc/xray/config.json "${REPO}ubuntu/config.json" >/dev/null 2>&1
    wget -O /etc/systemd/system/runn.service "${REPO}ubuntu/runn.service" >/dev/null 2>&1
    #chmod +x /usr/local/bin/xray
    domain=$(cat /etc/xray/domain)
    IPVS=$(cat /etc/xray/ipvps)
    print_success "Core Xray 1.8.1 Latest Version"
    
    # Settings UP Nginix Server
    clear
    wget -qO- --timeout=10 ipinfo.io/city 2>/dev/null >>/etc/xray/city
    wget -qO- --timeout=10 ipinfo.io/org 2>/dev/null | cut -d " " -f 2-10 >>/etc/xray/isp
    print_install "Installing Packet Configuration"
    mkdir -p /etc/haproxy /etc/nginx/conf.d
    wget -O /etc/haproxy/haproxy.cfg "${REPO}ubuntu/haproxy.cfg" >/dev/null 2>&1
    wget -O /etc/nginx/conf.d/xray.conf "${REPO}ubuntu/xray.conf" >/dev/null 2>&1
    wget -O /etc/nginx/conf.d/decoy.conf "${REPO}ubuntu/decoy.conf" >/dev/null 2>&1
    wget -O /etc/nginx/conf.d/subscription.conf "${REPO}ubuntu/subscription.conf" >/dev/null 2>&1
    wget -qO- "${REPO}ubuntu/nginx.conf" > /etc/nginx/nginx.conf
    sed -i "s/xxx/${domain}/g" /etc/haproxy/haproxy.cfg 2>/dev/null || true
    sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/xray.conf 2>/dev/null || true
    sed -i "s/xxx/${domain}/g" /etc/nginx/conf.d/decoy.conf 2>/dev/null || true
    # Decoy site + Cloudflare real IP placeholder
    mkdir -p /var/www/html
    wget -qO /var/www/html/index.html "${REPO}ubuntu/decoy/index.html"
    sed -i "s/__DECOY_TITLE__/VPN Script/g" /var/www/html/index.html
    touch /etc/nginx/conf.d/cloudflare-ips.conf
    echo 'set_real_ip_from 127.0.0.1; real_ip_header CF-Connecting-IP;' > /etc/nginx/conf.d/cloudflare-ips.conf
    # Apply custom paths after nginx+xray configs exist
    if [[ -x /usr/local/sbin/apply-paths ]] && command -v nginx >/dev/null; then
        /usr/local/sbin/apply-paths >/dev/null 2>&1 || true
    fi

if [[ -f /etc/xray/xray.crt && -f /etc/xray/xray.key ]]; then
    cat /etc/xray/xray.crt /etc/xray/xray.key | tee /etc/haproxy/hap.pem >/dev/null
fi

    # > Set Permission
    chmod +x /etc/systemd/system/runn.service

    # > Create Service
    rm -rf /etc/systemd/system/xray.service.d
    cat >/etc/systemd/system/xray.service <<EOF
Description=Xray Service
Documentation=https://github.com
After=network.target nss-lookup.target

[Service]
User=www-data
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=/usr/local/bin/xray run -config /etc/xray/config.json
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target

EOF
print_success "Configuration Packet"
}

function ssh(){
clear
clear
print_install "Installing Password SSH"
wget -O /etc/pam.d/common-password "${REPO}ubuntu/password"
chmod +x /etc/pam.d/common-password

    DEBIAN_FRONTEND=noninteractive dpkg-reconfigure keyboard-configuration
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/altgr select The default for the keyboard layout"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/compose select No compose key"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/ctrl_alt_bksp boolean false"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/layoutcode string de"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/layout select English"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/modelcode string pc105"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/model select Generic 105-key (Intl) PC"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/optionscode string "
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/store_defaults_in_debconf_db boolean true"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/switch select No temporary switch"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/toggle select No toggling"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_config_layout boolean true"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_config_options boolean true"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_layout boolean true"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/unsupported_options boolean true"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/variantcode string "
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/variant select English"
    debconf-set-selections <<<"keyboard-configuration keyboard-configuration/xkb-keymap select "

# go to root
cd

# Edit file /etc/systemd/system/rc-local.service
cat > /etc/systemd/system/rc-local.service <<-END
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
END

# nano /etc/rc.local
cat > /etc/rc.local <<-END
#!/bin/sh -e
# rc.local
# By default this script does nothing.
exit 0
END

# Ubah izin akses
chmod +x /etc/rc.local

# enable rc local
systemctl enable rc-local
systemctl start rc-local.service

# disable ipv6
echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6
sed -i '$ i\echo 1 > /proc/sys/net/ipv6/conf/all/disable_ipv6' /etc/rc.local

#update
# set time GMT +7
ln -fs /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# set locale
sed -i 's/AcceptEnv/#AcceptEnv/g' /etc/ssh/sshd_config
print_success "Password SSH"
}

function udp_mini(){
clear
clear
print_install "Installing Service Limit IP & Quota"
wget -q "${REPO}ubuntu/fv-tunnel" -O fv-tunnel && chmod +x fv-tunnel && ./fv-tunnel

# // Installing UDP Mini
mkdir -p /usr/local/kyt/
wget -q -O /usr/local/kyt/udp-mini "${REPO}ubuntu/udp-mini"
chmod +x /usr/local/kyt/udp-mini
wget -q -O /etc/systemd/system/udp-mini-1.service "${REPO}ubuntu/udp-mini-1.service"
wget -q -O /etc/systemd/system/udp-mini-2.service "${REPO}ubuntu/udp-mini-2.service"
wget -q -O /etc/systemd/system/udp-mini-3.service "${REPO}ubuntu/udp-mini-3.service"
systemctl disable udp-mini-1
systemctl stop udp-mini-1
systemctl enable udp-mini-1
systemctl start udp-mini-1
systemctl disable udp-mini-2
systemctl stop udp-mini-2
systemctl enable udp-mini-2
systemctl start udp-mini-2
systemctl disable udp-mini-3
systemctl stop udp-mini-3
systemctl enable udp-mini-3
systemctl start udp-mini-3
print_success "Limit IP Service"
}

function ssh_slow(){
clear
clear
# // Installing UDP Mini
print_install "Installing the SlowDNS Server module"
    wget -q -O /tmp/nameserver "${REPO}ubuntu/nameserver" >/dev/null 2>&1
    chmod +x /tmp/nameserver
    bash /tmp/nameserver | tee /root/install.log
 print_success "SlowDNS"
}

function ins_SSHD(){
clear
clear
print_install "Installing SSHD"
wget -q -O /etc/ssh/sshd_config "${REPO}ubuntu/sshd" >/dev/null 2>&1
chmod 700 /etc/ssh/sshd_config
/etc/init.d/ssh restart
systemctl restart ssh
/etc/init.d/ssh status
print_success "SSHD"
}

function ins_dropbear(){
clear
clear
print_install "Installing Dropbear"
# // Installing Dropbear
apt-get install dropbear -y > /dev/null 2>&1
wget -q -O /etc/default/dropbear "${REPO}ubuntu/dropbear.conf"
chmod +x /etc/default/dropbear
/etc/init.d/dropbear restart
/etc/init.d/dropbear status
print_success "Dropbear"
}

function ins_vnstat(){
clear
clear
print_install "Installing Vnstat"
apt-get install -y vnstat >/dev/null 2>&1 || true
NET=$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')
[[ -z "$NET" ]] && NET=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | head -1)
[[ -z "$NET" ]] && NET=eth0
vnstat -u -i "$NET" 2>/dev/null || true
if [[ -f /etc/vnstat.conf ]]; then
    sed -i "s/^Interface .*/Interface \"$NET\"/" /etc/vnstat.conf 2>/dev/null || true
fi
chown -R vnstat:vnstat /var/lib/vnstat 2>/dev/null || true
systemctl enable vnstat 2>/dev/null || true
systemctl restart vnstat 2>/dev/null || true
print_success "Vnstat"
}

function ins_openvpn(){
clear
clear
print_install "Installing OpenVPN"
#OpenVPN
wget ${REPO}ubuntu/openvpn &&  chmod +x openvpn && ./openvpn
/etc/init.d/openvpn restart
print_success "OpenVPN"
}

function ins_backup(){
clear
clear
print_install "Installing Backup Server"
#BackupOption
apt install rclone -y
printf "q\n" | rclone config
wget -O /root/.config/rclone/rclone.conf "${REPO}ubuntu/rclone.conf"
#Install Wondershaper
cd /bin
git clone  https://github.com/magnific0/wondershaper.git
cd wondershaper
sudo make install
cd
rm -rf wondershaper
echo > /home/limit
apt install msmtp-mta ca-certificates bsd-mailx -y
cat<<EOF>>/etc/msmtprc
defaults
tls on
tls_starttls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt

account default
host smtp.gmail.com
port 587
auth on
user oceantestdigital@gmail.com
from oceantestdigital@gmail.com
password jokerman77 
logfile ~/.msmtp.log
EOF
chown -R www-data:www-data /etc/msmtprc
wget -q -O /etc/ipserver "${REPO}ubuntu/ipserver" && bash /etc/ipserver
print_success "Backup Server"
}

function ins_swab(){
clear
clear
print_install "Installing Swap 1 G"
gotop_latest="$(curl -s https://api.github.com/repos/xxxserxxx/gotop/releases | grep tag_name | sed -E 's/.*"v(.*)".*/\1/' | head -n 1)"
    gotop_link="https://github.com/xxxserxxx/gotop/releases/download/v$gotop_latest/gotop_v"$gotop_latest"_linux_amd64.deb"
    curl -sL "$gotop_link" -o /tmp/gotop.deb
    dpkg -i /tmp/gotop.deb >/dev/null 2>&1
    
    # > Buat swap sebesar 1G
    dd if=/dev/zero of=/swapfile bs=1024 count=1048576
    mkswap /swapfile
    chown root:root /swapfile
    chmod 0600 /swapfile >/dev/null 2>&1
    swapon /swapfile >/dev/null 2>&1
    sed -i '$ i\/swapfile      swap swap   defaults    0 0' /etc/fstab

    # > Singkronisasi jam
    chronyd -q 'server 0.id.pool.ntp.org iburst'
    chronyc sourcestats -v
    chronyc tracking -v
    
    wget ${REPO}ubuntu/bbr.sh &&  chmod +x bbr.sh && ./bbr.sh
    print_success "Swap 1 G"
}

function ins_Fail2ban(){
clear
clear
print_install "Installing Fail2ban"
#apt -y install fail2ban > /dev/null 2>&1
#sudo systemctl enable --now fail2ban
#/etc/init.d/fail2ban restart
#/etc/init.d/fail2ban status

# Instal DDOS Flate
if [ -d '/usr/local/ddos' ]; then
	echo; echo; echo "Please un-install the previous version first"
	exit 0
else
	mkdir /usr/local/ddos
fi

# banner
echo "Banner /etc/kyt.txt" >>/etc/ssh/sshd_config
sed -i 's@DROPBEAR_BANNER=""@DROPBEAR_BANNER="/etc/kyt.txt"@g' /etc/default/dropbear

# Ganti Banner
wget -O /etc/kyt.txt "${REPO}ubuntu/issue.net"
print_success "Fail2ban"
}

function ins_epro(){
clear
clear
print_install "Installing  ePro WebSocket Proxy"
    wget -O /usr/bin/ws "${REPO}ubuntu/ws" >/dev/null 2>&1
    wget -O /usr/bin/tun.conf "${REPO}ubuntu/tun.conf" >/dev/null 2>&1
    wget -O /etc/systemd/system/ws.service "${REPO}ubuntu/ws.service" >/dev/null 2>&1
    chmod +x /etc/systemd/system/ws.service
    chmod +x /usr/bin/ws
    chmod 644 /usr/bin/tun.conf
systemctl disable ws
systemctl stop ws
systemctl enable ws
systemctl start ws
systemctl restart ws
wget -q -O /usr/local/share/xray/geosite.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat" >/dev/null 2>&1
wget -q -O /usr/local/share/xray/geoip.dat "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat" >/dev/null 2>&1
wget -O /usr/sbin/ftvpn "${REPO}ubuntu/ftvpn" >/dev/null 2>&1
chmod +x /usr/sbin/ftvpn
iptables -A FORWARD -m string --string "get_peers" --algo bm -j DROP
iptables -A FORWARD -m string --string "announce_peer" --algo bm -j DROP
iptables -A FORWARD -m string --string "find_node" --algo bm -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "BitTorrent protocol" -j DROP
iptables -A FORWARD -m string --algo bm --string "peer_id=" -j DROP
iptables -A FORWARD -m string --algo bm --string ".torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce.php?passkey=" -j DROP
iptables -A FORWARD -m string --algo bm --string "torrent" -j DROP
iptables -A FORWARD -m string --algo bm --string "announce" -j DROP
iptables -A FORWARD -m string --algo bm --string "info_hash" -j DROP
iptables-save > /etc/iptables.up.rules
iptables-restore -t < /etc/iptables.up.rules
netfilter-persistent save
netfilter-persistent reload

# remove unnecessary files
cd
apt autoclean -y >/dev/null 2>&1
apt autoremove -y >/dev/null 2>&1
print_success "ePro WebSocket Proxy"
}

function ins_restart(){
clear
clear
print_install "Restarting  All Packet"
/etc/init.d/nginx restart
/etc/init.d/openvpn restart
/etc/init.d/ssh restart
/etc/init.d/dropbear restart
/etc/init.d/fail2ban restart
/etc/init.d/vnstat restart
systemctl restart haproxy
/etc/init.d/cron restart
    systemctl daemon-reload
    systemctl start netfilter-persistent
    systemctl enable --now nginx
    systemctl enable --now xray
    systemctl enable --now rc-local
    systemctl enable --now dropbear
    systemctl enable --now openvpn
    systemctl enable --now cron
    systemctl enable --now haproxy
    systemctl enable --now netfilter-persistent
    systemctl enable --now ws
    systemctl enable --now fail2ban
history -c
echo "unset HISTFILE" >> /etc/profile

cd
rm -f /root/openvpn
rm -f /root/key.pem
rm -f /root/cert.pem
print_success "All Packet"
}

#Instal Menu
function menu(){
    clear
    print_install "Installing  Menu Packet"
    wget ${REPO}ubuntu/menu.zip
    unzip menu.zip
    chmod +x menu/*
    mv menu/* /usr/local/sbin
    rm -rf menu
    rm -rf menu.zip
}

# Membaut Default Menu 
function profile(){
clear
clear
    cat >/root/.profile <<EOF
# ~/.profile: executed by Bourne-compatible login shells.
if [ "$BASH" ]; then
    if [ -f ~/.bashrc ]; then
        . ~/.bashrc
    fi
fi
mesg n || true
menu
EOF

cat >/etc/cron.d/xp_all <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		2 0 * * * root /usr/local/sbin/xp
	END
	cat >/etc/cron.d/logclean <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		*/20 * * * * root /usr/local/sbin/clearlog
		END
    chmod 644 /root/.profile
	
    cat >/etc/cron.d/daily_reboot <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		0 5 * * * root /sbin/reboot
	END
    cat >/etc/cron.d/limit_ip <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		*/2 * * * * root /usr/local/sbin/limit-ip
	END
    cat >/etc/cron.d/limit_ip2 <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		*/2 * * * * root /usr/bin/limit-ip
	END
    echo "*/1 * * * * root echo -n > /var/log/nginx/access.log" >/etc/cron.d/log.nginx
    echo "*/1 * * * * root echo -n > /var/log/xray/access.log" >>/etc/cron.d/log.xray
    cat >/etc/cron.d/cert-renew <<-END
		SHELL=/bin/sh
		PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
		0 3 * * 1 root /usr/local/sbin/cert-renew >> /var/log/cert-renew.log 2>&1
	END
    service cron restart
    cat >/home/daily_reboot <<-END
		5
	END

cat >/etc/systemd/system/rc-local.service <<EOF
[Unit]
Description=/etc/rc.local
ConditionPathExists=/etc/rc.local
[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
StandardOutput=tty
RemainAfterExit=yes
SysVStartPriority=99
[Install]
WantedBy=multi-user.target
EOF

echo "/bin/false" >>/etc/shells
echo "/usr/sbin/nologin" >>/etc/shells
cat >/etc/rc.local <<EOF
#!/bin/sh -e
# rc.local
# By default this script does nothing.
iptables -I INPUT -p udp --dport 5300 -j ACCEPT
iptables -t nat -I PREROUTING -p udp --dport 53 -j REDIRECT --to-ports 5300
systemctl restart netfilter-persistent
exit 0
EOF

    chmod +x /etc/rc.local
    
    AUTOREB=$(cat /home/daily_reboot)
    SETT=11
    if [ $AUTOREB -gt $SETT ]; then
        TIME_DATE="PM"
    else
        TIME_DATE="AM"
    fi
print_success "Menu Packet"
}

# Restart layanan after install
function enable_services(){
clear
clear
print_install "Enable Service"
    systemctl daemon-reload
    systemctl start netfilter-persistent
    systemctl enable --now rc-local
    systemctl enable --now cron
    systemctl enable --now netfilter-persistent
    systemctl restart nginx
    systemctl restart xray
    systemctl restart cron
    systemctl restart haproxy
    print_success "Enable Service"
    clear
}

function password_default() {
    print_install "Setting root password"
    if [[ -z "${ROOT_PASSWORD:-}" ]]; then
        ROOT_PASSWORD=$(openssl rand -base64 12 | tr -dc 'A-Za-z0-9' | head -c 16)
        echo "root:${ROOT_PASSWORD}" | chpasswd
        echo "${ROOT_PASSWORD}" > /root/.default-pass
        chmod 600 /root/.default-pass
        print_success "Root password saved to /root/.default-pass"
    else
        echo "root:${ROOT_PASSWORD}" | chpasswd
        print_success "Root password set from ROOT_PASSWORD env"
    fi
}

function install_vpn_lib() {
    print_install "Installing VPN Script library"
    mkdir -p /usr/local/lib/vpn_script /etc/xray/routing /usr/local/sbin
    for f in common.sh cloudflare.sh linkgen.sh routing.sh httpcustom.sh config.defaults; do
        wget -qO "/usr/local/lib/vpn_script/${f}" "${REPO}lib/${f}" 2>/dev/null || true
    done
    mkdir -p /usr/local/lib/vpn_script/httpcustom
    for f in index.json payloads.json sni.json proxies.json profiles.json; do
        wget -qO "/usr/local/lib/vpn_script/httpcustom/${f}" "${REPO}lib/httpcustom/${f}" 2>/dev/null || true
    done
    if [[ ! -f /etc/vpn_script/config ]]; then
        mkdir -p /etc/vpn_script
        cp /usr/local/lib/vpn_script/config.defaults /etc/vpn_script/config
    fi
    for script in health-check cf-setup apply-routing apply-paths cert-renew reload-stack httpcustom-export httpcustom-export-v5 httpc-lib reality-setup cf-tunnel sub-manage apply-env preflight ec2-install repair-install; do
        src="${script}.sh"
        [[ "$script" == "httpc-lib" ]] && src="httpcustom.sh" && script_dest="httpc-lib" || script_dest="$script"
        [[ "$script" == "httpcustom-export-v5" ]] && src="httpcustom-export-v5.sh"
        [[ "$script" == "httpcustom-export" ]] && src="httpcustom-export.sh"
        [[ "$script" == "health-check" ]] && src="health-check.sh" && script_dest="health-check"
        wget -qO "/usr/local/sbin/${script_dest}" "${REPO}scripts/${src}" 2>/dev/null || \
        wget -qO "/usr/local/sbin/${script_dest}" "${REPO}lib/${src}" 2>/dev/null || true
    done
    wget -qO /usr/local/lib/vpn_script/sub_server.py "${REPO}ubuntu/subscription/sub_server.py" 2>/dev/null || true
    wget -qO /etc/systemd/system/subscription.service "${REPO}ubuntu/subscription/subscription.service" 2>/dev/null || true
    wget -qO /etc/nginx/conf.d/subscription.conf "${REPO}ubuntu/subscription.conf" 2>/dev/null || true
    wget -qO /usr/local/sbin/httpc-lib "${REPO}lib/httpcustom.sh" 2>/dev/null || true
    for profile in global split adblock direct; do
        wget -qO "/etc/xray/routing/${profile}.json" "${REPO}ubuntu/routing/${profile}.json"
    done
    chmod +x /usr/local/sbin/{health-check,cf-setup,apply-routing,apply-paths,cert-renew,reload-stack,httpcustom-export,httpcustom-export-v5,httpc-lib,reality-setup,cf-tunnel,sub-manage,apply-env,preflight,ec2-install,repair-install} 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl enable subscription 2>/dev/null || true
    systemctl restart subscription 2>/dev/null || true
    print_success "VPN Script library"
}

function finalize_subscription() {
    [[ -f /usr/local/lib/vpn_script/sub_server.py ]] || return 0
    if [[ -f /etc/xray/domain ]] && [[ -s /etc/xray/domain ]]; then
        python3 /usr/local/lib/vpn_script/sub_server.py generate-token 2>/dev/null || true
    fi
}

# Fingsi Install Script
function instal(){
clear
clear
    install_vpn_lib
    [[ -f /usr/local/lib/vpn_script/common.sh ]] && source /usr/local/lib/vpn_script/common.sh
    [[ -f /root/vpn_script.env ]] && /usr/local/sbin/apply-env /root/vpn_script.env 2>/dev/null || true
    checking_sc 2>/dev/null || true
    first_setup
    nginx_install
    base_package
    make_folder_xray
    pasang_domain
    finalize_subscription
    password_default
    pasang_ssl
    install_xray
    ssh
    udp_mini
    ssh_slow
    ins_SSHD
    ins_dropbear
    ins_vnstat
    ins_openvpn
    ins_backup
    ins_swab
    ins_Fail2ban
    ins_epro
    ins_restart
    menu
    profile
    enable_services
    restart_system
}
genz_show_banner
genz_prepare
instal
echo ""
history -c
rm -rf /root/menu
rm -rf /root/*.zip
rm -rf /root/*.sh
rm -rf /root/LICENSE
rm -rf /root/README.md
rm -rf /root/domain
#sudo hostnamectl set-hostname $user
secs_to_human "$(($(date +%s) - ${start}))"
sudo hostnamectl set-hostname $username
echo -e "${green} VPN Script installed successfully — stanlley-locke${NC}"
echo -e "${YELLOW} Root password (if generated): /root/.default-pass${NC}"
echo -e "${YELLOW} Run 'menu' after reboot, or 'health-check' to verify services${NC}"
echo ""
read -p "$( echo -e "Press ${YELLOW}[ ${NC}${YELLOW}Enter${NC} ${YELLOW}]${NC} For reboot") "
reboot
