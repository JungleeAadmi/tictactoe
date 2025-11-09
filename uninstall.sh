#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# 🧹 Tic Tac Toe Uninstaller
# Safely removes the game, nginx config, and site files.
# Works on Debian, Ubuntu, Armbian, and Proxmox LXC.
# ============================================================

SITE_DIR="/var/www/tictactoe"
NGINX_CONF="/etc/nginx/sites-available/tictactoe"
NGINX_LINK="/etc/nginx/sites-enabled/tictactoe"

echo "🧹 Tic Tac Toe Uninstaller"
echo "-----------------------------------------"

# Ensure root
if [ "$(id -u)" -ne 0 ]; then
  echo "[INFO] Re-running with sudo..."
  exec sudo bash "$0" "$@"
fi

# Stop nginx (optional, safe even if not running)
if systemctl list-units --type=service | grep -q nginx; then
  echo "[INFO] Stopping nginx service..."
  systemctl stop nginx || true
fi

# Remove site directory
if [ -d "$SITE_DIR" ]; then
  echo "[INFO] Removing site directory: $SITE_DIR"
  rm -rf "$SITE_DIR"
else
  echo "[WARN] Site directory not found: $SITE_DIR"
fi

# Remove nginx site configs
if [ -f "$NGINX_CONF" ]; then
  echo "[INFO] Removing nginx site configuration..."
  rm -f "$NGINX_CONF"
fi

if [ -f "$NGINX_LINK" ]; then
  echo "[INFO] Removing enabled nginx site link..."
  rm -f "$NGINX_LINK"
fi

# Reload nginx if available
if command -v nginx >/dev/null 2>&1; then
  echo "[INFO] Reloading nginx..."
  systemctl reload nginx || systemctl restart nginx || true
fi

# Clean log files (optional)
if [ -f /var/log/nginx/tictactoe.access.log ]; then
  rm -f /var/log/nginx/tictactoe.*.log
  echo "[INFO] Old logs cleaned up."
fi

echo
echo "✅ Tic Tac Toe has been completely removed."
echo "You can reinstall it anytime with:"
echo
echo "  sudo bash -c \"\$(wget -qO- https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main/install.sh)\""
echo
echo "-----------------------------------------"
echo "Uninstallation complete. 🎯"
