#!/usr/bin/env bash
set -eo pipefail
# Robust TicTacToe installer (works on Debian/Ubuntu/Armbian/Proxmox LXC/Raspberry Pi)
# Usage:
#   PORT=3000 NAME=mytictactoe bash install.sh
# or:
#   PORT=3000 bash -c "$(wget -qO- https://raw.githubusercontent.com/YOURUSER/tictactoe/main/install.sh)"

IMAGE="ghcr.io/jungleeaadmi/tictactoe:latest"
PORT="${PORT:-8080}"
NAME="${NAME:-tictactoe}"
FORCE_OFFICIAL="${FORCE_OFFICIAL:-0}"  # set to 1 to force use of get.docker.com
RETRY_LIMIT=1

is_root() { [ "$(id -u)" -eq 0 ]; }

need_sudo_run() {
  if ! is_root; then
    if command -v sudo >/dev/null 2>&1; then
      echo "Re-running installer with sudo..."
      exec sudo bash -c "PORT=${PORT} NAME=${NAME} FORCE_OFFICIAL=${FORCE_OFFICIAL} bash -s" -- "$0" "$@"
    else
      echo "This installer needs root. Please run as root or install sudo." >&2
      exit 1
    fi
  fi
}

cleanup_bad_docker_list() {
  # remove any previously created docker.list variants that can cause apt errors
  rm -f /etc/apt/sources.list.d/docker.list* /etc/apt/sources.list.d/docker*.save || true
}

detect_arch() {
  dpkg --print-architecture 2>/dev/null || uname -m
}

install_docker_via_apt() {
  # Try installing docker from distro repos first (safe)
  echo "[INFO] Attempting to install docker from distro packages (docker.io)..."
  apt-get update -y
  if apt-get install -y docker.io; then
    systemctl enable --now docker || true
    return 0
  fi
  return 1
}

install_docker_official_script() {
  echo "[INFO] Falling back to Docker official installer (get.docker.com)."
  # Use the official convenience script (it supports Debian/Ubuntu/various arches)
  # This will install docker-ce, containerd, etc.
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  bash /tmp/get-docker.sh
  systemctl enable --now docker || true
}

docker_installed() {
  command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1
}

cleanup_and_prepare() {
  cleanup_bad_docker_list
  apt-get update -y || true
}

detect_lxc() {
  # Returns 0 when in an LXC/containers environment likely to be problematic
  if [ -f /proc/1/environ ] && grep -q container= /proc/1/environ 2>/dev/null; then
    return 0
  fi
  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -v | grep -qi lxc; then
    return 0
  fi
  # /proc/1/cgroup may include 'lxc' or 'liblxc'
  if grep -qaE 'lxc|container' /proc/1/cgroup 2>/dev/null; then
    return 0
  fi
  return 1
}

explain_lxc_fix() {
  cat <<EOF

[WARNING] It looks like you're running inside an LXC container (Proxmox LXC or similar).
Docker's runtime (runc) sometimes needs to re-open kernel sysctls at container start.
If you see an error like:

  open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied

You must change settings on the LXC host. On Proxmox host, run (as root):

  pct stop ${CTID:-<CTID>}
  pct set ${CTID:-<CTID>} -features nesting=1,keyctl=1
  pct start ${CTID:-<CTID>}

If that still fails, add the AppArmor override (on the Proxmox host):

  grep -q "lxc.apparmor.profile" /etc/pve/lxc/<CTID>.conf || \
      echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/<CTID>.conf
  pct stop <CTID> && pct start <CTID>

Notes:
 - Enabling nesting reduces container isolation; AppArmor unconfined reduces it more.
 - If you do not have access to the host, you can test the image by running Docker with --privileged,
   but that is insecure and not recommended for production.

EOF
}

start_game_container() {
  # Remove any existing container with same name (force)
  docker ps -a --filter "name=^/${NAME}$" -q | xargs -r docker rm -f || true

  # Pull image first
  echo "[INFO] Pulling Docker image: ${IMAGE}"
  docker pull "${IMAGE}"

  # Try to run normally
  echo "[INFO] Starting Tic Tac Toe container..."
  if docker run -d --name "${NAME}" --restart unless-stopped -p "${PORT}:80" "${IMAGE}"; then
    echo "[SUCCESS] Container started and listening on host port ${PORT}."
    return 0
  else
    echo "[ERROR] Failed to start container normally. Inspecting error..."
    return 1
  fi
}

check_for_sysctl_error_in_last_docker() {
  # Try to start a throwaway container capturing stderr (non-detached)
  set +e
  ERR="$(docker run --name __tictactoe_test_temp --rm -p "${PORT}:80" "${IMAGE}" 2>&1 || true)"
  set -e
  # Clean up any stray container
  docker ps -a --filter "name=__tictactoe_test_temp" -q | xargs -r docker rm -f || true

  echo "${ERR}" | sed -n '1,200p' >&2

  if echo "${ERR}" | grep -qi 'ip_unprivileged_port_start\|unprivileged_port_start\|permission denied'; then
    return 0
  fi
  return 1
}

main() {
  need_sudo_run "$@"

  echo "🎯 Tic Tac Toe - One Line Installer"
  echo "   Installing AI-generated liquid glass game..."

  cleanup_and_prepare

  if docker_installed && [ "${FORCE_OFFICIAL}" = "0" ]; then
    echo "[INFO] Docker already installed. Skipping installation."
  else
    # Try apt-based install first (distro package)
    if install_docker_via_apt; then
      echo "[INFO] Installed docker from distro packages."
    else
      # apt approach failed and/or user forced official install
      echo "[WARN] Installing via distro packages failed or not preferred."
      install_docker_official_script
    fi
  fi

  # Quick test
  if ! docker_installed; then
    echo "[ERROR] Docker still not available after install. Exiting." >&2
    exit 1
  fi

  # Start container, with LXC-aware behavior
  if start_game_container; then
    exit 0
  fi

  # If we are here, normal start failed. If in LXC, give instructions.
  if detect_lxc; then
    echo "[ERROR] Container start failed and we detected running inside LXC/container environment."
    echo "[ERROR] Checking whether the failure is the known sysctl permission issue..."
    if check_for_sysctl_error_in_last_docker; then
      echo "[ERROR] Detected sysctl permission denied situation (common on Proxmox LXC)."
      explain_lxc_fix
      exit 2
    fi
  fi

  echo "[ERROR] Container start failed for an unknown reason. Showing 'docker ps -a' to help debug:"
  docker ps -a || true
  echo "[ERROR] Inspect the error above and retry. If you want, run this script with FORCE_OFFICIAL=1 to use Docker's official installer."
  exit 3
}

main "$@"
