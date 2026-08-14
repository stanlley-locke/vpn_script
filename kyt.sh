#!/bin/bash
# Telegram bot panel installer — stanlley_locke/vpn_script
[ -f /usr/local/lib/vpn_script/common.sh ] && source /usr/local/lib/vpn_script/common.sh

REPO="${VPN_REPO:-https://raw.githubusercontent.com/stanlley_locke/vpn_script/main/}"
NS=$(cat /etc/xray/dns 2>/dev/null || echo "")
PUB=$(cat /etc/slowdns/server.pub 2>/dev/null || echo "")
domain=$(cat /etc/xray/domain 2>/dev/null || echo "localhost")

grenbo="\e[92;1m"
NC='\e[0m'

apt update && apt install -y python3 python3-pip git unzip

cd /usr/bin
wget -q "${REPO}ubuntu/bot.zip"
unzip -o bot.zip
mv bot/* /usr/bin/
chmod +x /usr/bin/*
rm -rf bot.zip bot

wget -q "${REPO}ubuntu/kyt.zip"
unzip -o kyt.zip
pip3 install -r kyt/requirements.txt --break-system-packages 2>/dev/null \
    || pip3 install -r kyt/requirements.txt

echo ""
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e " \e[1;97;101m       VPN Script — Telegram Bot Panel         \e[0m"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
echo -e "${grenbo}Create a bot: @BotFather${NC}"
echo -e "${grenbo}Get your Telegram ID: @userinfobot${NC}"
echo -e "\033[1;36m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

read -e -p "[*] Bot Token: " bottoken
read -e -p "[*] Admin Telegram ID: " admin

mkdir -p /usr/bin/kyt
cat > /usr/bin/kyt/var.txt << EOF
BOT_TOKEN="${bottoken}"
ADMIN="${admin}"
DOMAIN="${domain}"
PUB="${PUB}"
HOST="${NS}"
EOF

cat > /etc/systemd/system/kyt.service << END
[Unit]
Description=VPN Script Telegram Bot (kyt)
After=network.target

[Service]
WorkingDirectory=/usr/bin
ExecStart=/usr/bin/python3 -m kyt
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable kyt
systemctl restart kyt

echo ""
echo "Bot panel installed."
echo "  Token : ${bottoken:0:8}..."
echo "  Admin : ${admin}"
echo "  Domain: ${domain}"
echo ""
echo "Send /menu to your bot on Telegram."
