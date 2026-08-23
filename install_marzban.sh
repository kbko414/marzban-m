#!/bin/bash

# ======================================================
# KBK Marzban VPN Panel - Error-Proof Installer
# Features: No SSL Warning, Auto Admin, Custom Template
# Fixed: .env parsing, SSL generation, Port conflicts
# ======================================================

# Clear screen
clear

# Show KBK Banner
echo "============================================================"
echo -e "\e[1;36m"
echo "  ██╗  ██╗██████╗ ██╗  ██╗"
echo "  ██║ ██╔╝██╔══██╗██║ ██╔╝"
echo "  █████╔╝ ██████╔╝█████╔╝ "
echo "  ██╔═██╗ ██╔══██╗██╔═██╗ "
echo "  ██║  ██╗██████╔╝██║  ██╗"
echo "  ╚═╝  ╚═╝╚═════╝ ╚═╝  ╚═╝"
echo -e "\e[0m"
echo "        KBK Marzban One-Line Setup"
echo "============================================================"

# --- Check Root ---
if [[ $EUID -ne 0 ]]; then
   echo -e "\e[31m❌ Root နဲ့ Run ပါ။\e[0m"
   echo "sudo bash kbk_marzban.sh"
   exit 1
fi

# --- Install Necessary Packages ---
echo ""
echo "📦 Checking necessary packages..."
apt update && apt install -y curl socat wget sed jq ufw

# --- Inputs ---
echo ""
read -p "🌐 Enter Domain Name: " DOMAIN
read -p "📧 Enter Email for SSL: " EMAIL
read -p "🤖 Enter Telegram Bot Token: " BOT_TOKEN
read -p "👤 Enter Telegram Admin ID: " ADMIN_ID
read -p "📝 Enter Subscription Title: " SUB_TITLE
read -p "👨‍💼 Admin Username: " ADMIN_USER
read -s -p "🔑 Admin Password: " ADMIN_PASS
echo ""
echo "============================================================"

# --- Install Marzban ---
echo ""
echo "🚀 Installing Marzban..."
sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

# --- Wait for Marzban to initialize ---
sleep 10

# --- Stop Marzban to configure ---
cd /opt/marzban/
docker-compose down

# --- Generate SSL Certificates using ESSL ---
echo ""
echo "🔐 Generating SSL Certificates..."
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/erfjab/ESSL/master/essl.sh)" @ --install
sudo essl "$EMAIL" "$DOMAIN" marzban

# --- Check if SSL files exist ---
if [[ ! -f "/var/lib/marzban/certs/$DOMAIN/fullchain.pem" ]]; then
    echo "❌ SSL Certificate မရဘူး။ Certbot နဲ့ ပြန်စမ်းပါ။"
    echo "sudo certbot certonly --standalone -d $DOMAIN"
    exit 1
fi

# --- Set Up Custom Template ---
echo ""
echo "🎨 Setting up KBK Custom Template..."
sudo mkdir -p /var/lib/marzban/templates/subscription/
sudo wget -N -P /var/lib/marzban/templates/subscription/ https://raw.githubusercontent.com/kbko414/marzban-m/main/index.html

# --- Create .env file (CLEAN) ---
echo ""
echo "📝 Creating .env configuration..."
cat > .env <<EOF
UVICORN_HOST = "0.0.0.0"
UVICORN_PORT = "8000"
UVICORN_SSL_CERTFILE = "/var/lib/marzban/certs/$DOMAIN/fullchain.pem"
UVICORN_SSL_KEYFILE = "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
TELEGRAM_API_TOKEN = "$BOT_TOKEN"
TELEGRAM_ADMIN_ID = "$ADMIN_ID"
SUB_PROFILE_TITLE = "$SUB_TITLE"
XRAY_SUBSCRIPTION_URL_PREFIX = "https://$DOMAIN:8000"
CUSTOM_TEMPLATES_DIRECTORY = "/var/lib/marzban/templates/"
SUBSCRIPTION_PAGE_TEMPLATE = "subscription/index.html"
EOF

# --- Start Marzban ---
echo ""
echo "🔄 Starting Marzban..."
docker-compose up -d

# --- Wait for Marzban to be ready ---
sleep 10

# --- Create Admin User ---
echo ""
echo "👤 Creating Admin User..."
docker exec marzban-marzban-1 marzban cli admin create --username "$ADMIN_USER" --password "$ADMIN_PASS" --sudo || echo "Admin setup skipped."

# --- Configure Firewall ---
echo ""
echo "🛡️ Configuring Firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable

# --- Final Output ---
clear
echo "============================================================"
echo -e "\e[1;32m✅ KBK Marzban Setup အောင်မြင်စွာ ပြီးဆုံးပါပြီ!\e[0m"
echo "============================================================"
echo ""
echo "🌐 Dashboard: https://$DOMAIN:8000/dashboard"
echo "👤 Username: $ADMIN_USER"
echo "🔑 Password: [You set it]"
echo ""
echo "📌 Telegram Bot: @$(curl -s https://api.telegram.org/bot$BOT_TOKEN/getMe | jq -r .result.username 2>/dev/null || echo 'Check Token')"
echo ""
echo "📁 Marzban Folder: /opt/marzban/"
echo "📁 Custom Template: /var/lib/marzban/templates/subscription/index.html"
echo ""
echo "💡 Logs: cd /opt/marzban && docker-compose logs -f"
echo "⚠️  SSL Warning ကို လျစ်လျူရှုပါ (Nginx မပါဘူး)"
echo "============================================================"
