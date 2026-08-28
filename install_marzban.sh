#!/bin/bash
# ===========================================================
# Marzban Panel Auto-Install Script
# One-shot, no-interaction, production-ready
# Supports: Ubuntu 20.04 / 22.04 / 24.04
# ===========================================================

set -e  # Exit on error

# ============ CONFIGURATION ============
DOMAIN="marz.tkii.eu.cc"          # <-- Replace with your domain
ADMIN_EMAIL="kxantbhko@gmail.com" # <-- Your email for SSL
TIMEZONE="UTC"

# ============ COLORS ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============ FUNCTIONS ============
log() {
    echo -e "${BLUE}[+]${NC} $1"
}

success() {
    echo -e "${GREEN}[✔]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

error() {
    echo -e "${RED}[✘]${NC} $1"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo bash $0"
    fi
}

# ============ MAIN INSTALLATION ============
clear
echo "============================================================"
echo "       Marzban Panel Auto-Install Script"
echo "       Domain: $DOMAIN"
echo "============================================================"
echo ""

# 1. Root Check
check_root

# 2. Update System
log "Updating system packages..."
apt update -y && apt upgrade -y

# 3. Install Dependencies
log "Installing dependencies..."
apt install -y python3 python3-pip python3-venv nginx certbot python3-certbot-nginx sqlite3 curl wget git ufw

# 4. Set Timezone
log "Setting timezone to $TIMEZONE..."
timedatectl set-timezone $TIMEZONE

# 5. Remove old Marzban installation (if any)
log "Removing old Marzban installation (if exists)..."
systemctl stop marzban 2>/dev/null || true
systemctl disable marzban 2>/dev/null || true
rm -rf /opt/marzban /var/lib/marzban /usr/local/bin/marzban
rm -f /etc/systemd/system/marzban.service
rm -f /etc/nginx/sites-available/marzban /etc/nginx/sites-enabled/marzban
systemctl daemon-reload

# 6. Install Marzban
log "Installing Marzban..."
bash <(curl -s https://raw.githubusercontent.com/Gozargah/Marzban/master/install.sh) <<< "y"

# 7. Configure .env
log "Configuring .env..."
cat > /opt/marzban/.env <<EOF
UVICORN_HOST=0.0.0.0
UVICORN_PORT=8000
ALLOWED_HOSTS=$DOMAIN,localhost,127.0.0.1
DEBUG=False
# DATABASE
DB_URL=sqlite:////var/lib/marzban/db.sqlite3
# SSL
SSL_CERT_FILE=/var/lib/marzban/certs/$DOMAIN/fullchain.pem
SSL_KEY_FILE=/var/lib/marzban/certs/$DOMAIN/privkey.pem
EOF

# 8. Create SSL Certificate Directory
mkdir -p /var/lib/marzban/certs/$DOMAIN

# 9. Start Marzban (first run to create DB)
log "Starting Marzban for the first time..."
systemctl daemon-reload
systemctl start marzban
systemctl enable marzban
sleep 5
systemctl status marzban --no-pager || true

# 10. Configure Nginx
log "Configuring Nginx..."
cat > /etc/nginx/sites-available/marzban <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /var/lib/marzban/certs/$DOMAIN/fullchain.pem;
    ssl_certificate_key /var/lib/marzban/certs/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

ln -sf /etc/nginx/sites-available/marzban /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# 11. Obtain SSL Certificate (Certbot)
log "Obtaining SSL certificate for $DOMAIN..."
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email $ADMIN_EMAIL --redirect --force-renewal

# 12. Set Permissions
log "Setting permissions..."
chown -R www-data:www-data /var/lib/marzban/
chmod 644 /var/lib/marzban/db.sqlite3 2>/dev/null || true
chown -R www-data:www-data /var/lib/marzban/certs/

# 13. Restart Services
log "Restarting services..."
systemctl restart marzban
systemctl restart nginx

# 14. Firewall
log "Configuring firewall..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
echo "y" | ufw enable || true

# 15. Final Check
sleep 3
echo ""

# ============ VERIFICATION ============
success "Installation completed!"
echo ""
echo "============================================================"
echo "📌  Marzban Panel is ready!"
echo ""
echo "🔗  Access: https://$DOMAIN/dashboard"
echo ""
echo "📁  Admin credentials (default):"
echo "    Username: admin"
echo "    Password: admin"
echo ""
echo "⚠️  Change the default password immediately!"
echo "============================================================"
echo ""

# Check if service is running
if systemctl is-active --quiet marzban; then
    success "Marzban service is running."
else
    warn "Marzban service is not running. Check logs: journalctl -u marzban -f"
fi

if systemctl is-active --quiet nginx; then
    success "Nginx service is running."
else
    warn "Nginx service is not running. Check logs: journalctl -u nginx -f"
fi

# Print service status
echo ""
log "Service status:"
systemctl status marzban --no-pager | grep Active
systemctl status nginx --no-pager | grep Active
echo ""
log "Listen ports:"
ss -tlnp | grep -E ":80|:443|:8000" || true
echo ""
log "All done! Happy hacking 😎"
