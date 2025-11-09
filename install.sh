#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 🎮 Tic Tac Toe - Static Site Installer (No Docker Required)
# Works on Debian, Ubuntu, Armbian, and Proxmox LXC containers
# ============================================================

REPO_RAW_BASE="https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main"
PORT="${PORT:-80}"
SITE_DIR="/var/www/tictactoe"
ASSETS_DIR="${SITE_DIR}/assets"
ICONS_DIR="${ASSETS_DIR}/icons"
NGINX_CONF="/etc/nginx/sites-available/tictactoe"
NGINX_LINK="/etc/nginx/sites-enabled/tictactoe"

# --- Root check ---
is_root() { [ "$(id -u)" -eq 0 ]; }
if ! is_root; then
  if command -v sudo >/dev/null 2>&1; then
    echo "[INFO] Re-running installer with sudo..."
    exec sudo bash "$0" "$@"
  else
    echo "[ERROR] Please run as root or with sudo." >&2
    exit 1
  fi
fi

echo "🎯 Tic Tac Toe Installer (Static HTML Version)"
echo "-----------------------------------------------"
echo "Installing to: ${SITE_DIR}"
echo "Serving on port: ${PORT}"
echo

# --- Install nginx if missing ---
if ! command -v nginx >/dev/null 2>&1; then
  echo "[INFO] Installing nginx web server..."
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y nginx
else
  echo "[INFO] nginx already installed."
fi

# --- Create site directories ---
echo "[INFO] Setting up site directory structure..."
mkdir -p "${ASSETS_DIR}"
mkdir -p "${ICONS_DIR}"
chown -R www-data:www-data "${SITE_DIR}" || true
chmod -R 755 "${SITE_DIR}" || true

# --- Download latest files from GitHub (overwrite) ---
echo "[INFO] Downloading website files from repository..."
# main html
wget -qO "${SITE_DIR}/index.html" "${REPO_RAW_BASE}/index.html"
# assets
wget -qO "${ASSETS_DIR}/app.js" "${REPO_RAW_BASE}/assets/app.js"
wget -qO "${ASSETS_DIR}/style.css" "${REPO_RAW_BASE}/assets/style.css"
# icons (optional - ignore failures)
wget -qO "${ICONS_DIR}/favicon.ico" "${REPO_RAW_BASE}/assets/icons/favicon.ico" || true
wget -qO "${ICONS_DIR}/apple-touch-icon.png" "${REPO_RAW_BASE}/assets/icons/apple-touch-icon.png" || true
# keep original reference icon if present in IMAGES/Icon
# (not required for site to function)

# --- Create nginx site configuration ---
echo "[INFO] Creating nginx configuration..."
cat > "${NGINX_CONF}" <<EOF
server {
    listen ${PORT} default_server;
    listen [::]:${PORT} default_server;

    server_name _;

    root ${SITE_DIR};
    index index.html;

    access_log /var/log/nginx/tictactoe.access.log;
    error_log  /var/log/nginx/tictactoe.error.log;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location /assets/ {
        try_files \$uri \$uri/ =404;
    }

    # Optional: cache static assets
    location ~* \.(?:css|js|png|jpg|jpeg|gif|ico|svg)$ {
        expires 7d;
        add_header Cache-Control "public";
    }
}
EOF

# --- Enable new site ---
ln -sf "${NGINX_CONF}" "${NGINX_LINK}"

# --- Disable default nginx site if present ---
if [ -f /etc/nginx/sites-enabled/default ]; then
  echo "[INFO] Disabling default nginx site..."
  rm -f /etc/nginx/sites-enabled/default
fi

# --- Validate nginx configuration ---
echo "[INFO] Testing nginx configuration..."
if nginx -t; then
  echo "[INFO] Reloading nginx..."
  systemctl enable --now nginx
  systemctl reload nginx || systemctl restart nginx
else
  echo "[ERROR] nginx configuration test failed." >&2
  exit 1
fi

# --- Final permissions ---
chown -R www-data:www-data "${SITE_DIR}" || true
chmod -R 755 "${SITE_DIR}" || true

# --- Done ---
IP_ADDR="$(hostname -I | awk '{print $1}')"
echo
echo "✅ Installation complete!"
echo "-----------------------------------------------"
echo "🌐 Visit: http://${IP_ADDR}:${PORT}"
echo "📁 Files installed at: ${SITE_DIR}"
echo "🧱 Served by: nginx (service enabled)"
echo
echo "To uninstall later:"
echo "  sudo bash -c \"\$(wget -qO- https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main/uninstall.sh)\""
echo
echo "Enjoy your game! 🎮"
