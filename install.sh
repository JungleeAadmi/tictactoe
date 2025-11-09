#!/usr/bin/env bash
set -euo pipefail

# TicTacToe robust installer
# - prefers distro docker.io, falls back to Docker official installer
# - detects LXC/Proxmox restrictions and prints host instructions
# - supports PORT and NAME environment variables
# - fixes test container name to a valid docker name

IMAGE="ghcr.io/jungleeaadmi/tictactoe:latest"
PORT="${PORT:-8080}"
NAME="${NAME:-tictactoe}"
FORCE_OFFICIAL="${FORCE_OFFICIAL:-0}"  # set to 1 to force use of get.docker.com

is_root() { [ "$(id -u)" -eq 0 ]; }

need_sudo_run() {
  if ! is_root; then
    # If script is a regular file, try re-exec with sudo. If piped, ask user to run with sudo.
    if [ -f "$0" ] && command -v sudo >/dev/null 2>&1; then
      echo "[INFO] Not running as root — re-running installer with sudo..."
      exec sudo bash "$0" "$@"
    else
      echo "[ERROR] This installer needs root. Please run with sudo, for example:" >&2
      echo "  sudo bash -c \"\$(wget -qO- https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main/install.sh)\"" >&2
      exit 1
    fi
  fi
}

cleanup_bad_docker_list() {
  rm -f /etc/apt/sources.list.d/docker.list* /etc/apt/sources.list.d/docker*.save || true
}

docker_installed() {
  command -v docker >/dev/null 2>&1 && docker version >/dev/null 2>&1 || return 1
}

install_docker_via_apt() {
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
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  bash /tmp/get-docker.sh
  systemctl enable --now docker || true
}

detect_lxc() {
  # Return 0 if running in LXC/container-like environment
  if [ -f /proc/1/environ ] && grep -q container= /proc/1/environ 2>/dev/null; then
    return 0
  fi
  if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt -v | grep -qi lxc; then
    return 0
  fi
  if grep -qaE 'lxc|container' /proc/1/cgroup 2>/dev/null; then
    return 0
  fi
  return 1
}

explain_lxc_fix() {
  cat <<'EOF'

[WARNING] You're running inside an LXC/container environment. Docker's runtime (runc)
sometimes needs to re-open kernel sysctls at container start. If you see an error like:

  open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied

Please change settings on the LXC host (Proxmox) as root. Example (replace <CTID> with your container id):

  pct stop <CTID>
  pct set <CTID> -unprivileged 0
  pct set <CTID> -features nesting=1,keyctl=1
  pct start <CTID>

If you cannot make the container privileged, try allowing AppArmor unconfined:

  grep -q "lxc.apparmor.profile" /etc/pve/lxc/<CTID>.conf || \
    echo "lxc.apparmor.profile: unconfined" >> /etc/pve/lxc/<CTID>.conf
  pct stop <CTID> && pct start <CTID>

Notes:
 - Making a container privileged or unconfined reduces isolation — only do this on trusted hosts.
 - If you do not have host access, you can test by running the image locally with --privileged,
   but that is insecure and not recommended for production.

EOF
}

start_game_container() {
  # Remove same-name container if present
  docker ps -a --filter "name=^/${NAME}$" -q | xargs -r docker rm -f || true

  echo "[INFO] Pulling Docker image: ${IMAGE}"
  docker pull "${IMAGE}"

  echo "[INFO] Starting Tic Tac Toe container..."
  if docker run -d --name "${NAME}" --restart unless-stopped -p "${PORT}:80" "${IMAGE}"; then
    echo "[SUCCESS] Container started and listening on host port ${PORT}."
    return 0
  fi
  return 1
}

check_for_sysctl_error_in_last_docker() {
  # Attempt a throwaway non-detached run to capture the error message.
  # Use a valid container name that starts with a letter (docker requires that).
  TEMP_NAME="tictactoe_test_temp"
  set +e
  ERR="$(docker run --name "${TEMP_NAME}" --rm -p "${PORT}:80" "${IMAGE}" 2>&1 || true)"
  set -e
  # Ensure no stray container
  docker ps -a --filter "name=${TEMP_NAME}" -q | xargs -r docker rm -f || true

  # print a short preview for debugging
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

  cleanup_bad_docker_list

  if docker_installed && [ "${FORCE_OFFICIAL}" = "0" ]; then
    echo "[INFO] Docker already installed. Skipping installation."
  else
    if install_docker_via_apt; then
      echo "[INFO] Installed docker from distro packages."
    else
      echo "[WARN] Distro package install failed or not preferred; using Docker official installer."
      install_docker_official_script
    fi
  fi

  if ! docker_installed; then
    echo "[ERROR] Docker not available after attempted installs. Exiting." >&2
    exit 1
  fi

  if start_game_container; then
    exit 0
  fi

  if detect_lxc; then
    echo "[ERROR] Container start failed and we detected running inside an LXC/container environment."
    echo "[ERROR] Checking whether the failure is the known sysctl permission issue..."
    if check_for_sysctl_error_in_last_docker; then
      echo "[ERROR] Detected sysctl permission denied situation (common on Proxmox LXC)."
      explain_lxc_fix
      exit 2
    fi
  fi

  echo "[ERROR] Container start failed for an unknown reason. Showing 'docker ps -a' to help debug:"
  docker ps -a || true
  echo "[ERROR] Inspect the output above. You can try FORCE_OFFICIAL=1 to force Docker's official installer."
  exit 3
}

main "$@"
