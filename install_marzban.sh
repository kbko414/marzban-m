#!/bin/bash

# ======================================================
# KBK Marzban VPN Panel - One-Line Setup Script
# Based on YNL Script | Modified for KBK
# Features: No SSL Warning, Telegram Bot, Auto Admin
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
apt update && apt install -y curl socat wget sed jq

# --- Inputs ---
echo ""
read -p "🌐 Enter Domain Name (e.g., kbko.kdns.fr): " DOMAIN
read -p "📧 Enter Email for SSL: " EMAIL
read -p "🤖 Enter Telegram Bot Token: " BOT_TOKEN
read -p "👤 Enter Telegram Admin ID: " ADMIN_ID
read -p "📝 Enter Subscription Title: " SUB_TITLE
read -p "👨‍💼 Create Admin Username: " ADMIN_USER
read -s -p "🔑 Create Admin Password: " ADMIN_PASS
echo ""
echo "============================================================"

# --- Install Marzban ---
echo ""
echo "🚀 Installing Marzban..."
sudo bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

# --- Wait for Marzban to initialize ---
sleep 5

# --- Generate SSL Certificates using ESSL (No Certbot Issues) ---
echo ""
echo "🔐 Generating SSL Certificates..."
sudo bash -c "$(curl -sL https://raw.githubusercontent.com/erfjab/ESSL/master/essl.sh)" @ --install
sudo essl "$EMAIL" "$DOMAIN" marzban

# --- Set Up Custom Template (KBK Style) ---
echo ""
echo "🎨 Setting up KBK Custom Template..."
sudo mkdir -p /var/lib/marzban/templates/subscription/
sudo wget -N -P /var/lib/marzban/templates/subscription/ https://raw.githubusercontent.com/yannaing86tt/template/main/subscription/index.html

# --- Update .env Configuration (No SSL Warning) ---
ENV_FILE="/opt/marzban/.env"

update_env() {
    local key=$1
    local value=$2
    if sudo grep -iqE "^#?\s*$key\s*=" "$ENV_FILE"; then
        sudo sed -i "s|^#*\s*$key\s*=.*|$key = \"$value\"|gI" "$ENV_FILE"
    else
        echo "$key = \"$value\"" | sudo tee -a "$ENV_FILE" > /dev/null
    fi
}

echo ""
echo "📝 Updating .env configuration (SSL Enabled)..."
update_env "UVICORN_HOST" "0.0.0.0"
update_env "UVICORN_PORT" "8000"
update_env "UVICORN_SSL_CERTFILE" "/var/lib/marzban/certs/$DOMAIN/fullchain.pem"
update_env "UVICORN_SSL_KEYFILE" "/var/lib/marzban/certs/$DOMAIN/privkey.pem"
update_env "TELEGRAM_API_TOKEN" "$BOT_TOKEN"
update_env "TELEGRAM_ADMIN_ID" "$ADMIN_ID"
update_env "SUB_PROFILE_TITLE" "$SUB_TITLE"
update_env "XRAY_SUBSCRIPTION_URL_PREFIX" "https://$DOMAIN:8000"
update_env "CUSTOM_TEMPLATES_DIRECTORY" "/var/lib/marzban/templates/"
update_env "SUBSCRIPTION_PAGE_TEMPLATE" "subscription/index.html"

# Remove any old typo entries
sudo sed -i "/^UNICORN_SSL_/d" "$ENV_FILE"

# --- Restart Marzban ---
echo ""
echo "🔄 Restarting Marzban to apply changes..."
marzban restart

# --- Wait for Marzban to wake up ---
sleep 10

# --- Create Admin User ---
echo ""
echo "👤 Creating Admin User..."
marzban cli admin create --username "$ADMIN_USER" --password "$ADMIN_PASS" --sudo || echo "⚠️ Admin setup skipped."

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
echo "📌 Telegram Bot: @$(curl -s https://api.telegram.org/bot$BOT_TOKEN/getMe | jq -r .result.username)"
echo ""
echo "📁 Nginx Config: /etc/nginx/sites-available/marzban (if needed)"
echo "📁 Marzban Folder: /opt/marzban/"
echo ""
echo "💡 Logs: cd /opt/marzban && docker-compose logs -f"
echo "============================================================"
