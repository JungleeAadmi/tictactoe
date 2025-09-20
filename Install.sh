#!/usr/bin/env bash
set -euo pipefail

# Tic Tac Toe - One Line Installer
# Usage: bash -c "$(wget -qO- https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main/install.sh)"

# Configuration
IMAGE="${IMAGE:-ghcr.io/jungleeaadmi/tictactoe:latest}"
PORT="${PORT:-8080}"
NAME="${NAME:-tictactoe}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
log() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check if running as root (recommended for LXC)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        warn "Not running as root. Some operations may require sudo."
    fi
}

# Install Docker if not present
install_docker() {
    if command -v docker >/dev/null 2>&1; then
        log "Docker already installed: $(docker --version)"
        return 0
    fi
    
    log "Installing Docker..."
    
    # Detect OS
    if [[ -f /etc/debian_version ]]; then
        # Debian/Ubuntu
        apt-get update -qq
        apt-get install -y ca-certificates curl gnupg lsb-release
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null || {
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        }
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null 2>/dev/null || {
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        }
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    elif [[ -f /etc/redhat-release ]]; then
        # CentOS/RHEL/Rocky
        yum install -y yum-utils
        yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
        systemctl enable docker
    else
        error "Unsupported OS. Please install Docker manually."
        exit 1
    fi
    
    systemctl start docker
    systemctl enable docker
    success "Docker installed successfully"
}

# Pull the image
pull_image() {
    log "Pulling Docker image: $IMAGE"
    if ! docker pull "$IMAGE"; then
        error "Failed to pull image $IMAGE"
        error "Make sure the image exists and is public on GHCR"
        exit 1
    fi
    success "Image pulled successfully"
}

# Stop and remove existing container
cleanup_existing() {
    if docker ps -a --format '{{.Names}}' | grep -q "^${NAME}$"; then
        log "Removing existing container: $NAME"
        docker rm -f "$NAME" >/dev/null 2>&1 || true
    fi
}

# Run the container
run_container() {
    log "Starting Tic Tac Toe container..."
    
    if ! docker run -d \
        --name "$NAME" \
        --restart unless-stopped \
        -p "${PORT}:80" \
        "$IMAGE"; then
        error "Failed to start container"
        exit 1
    fi
    
    success "Container started successfully!"
}

# Check if container is healthy
check_health() {
    log "Checking container health..."
    
    # Wait a moment for container to start
    sleep 2
    
    if ! docker ps --filter name="^${NAME}$" --format '{{.Names}}' | grep -q "^${NAME}$"; then
        error "Container failed to start"
        log "Container logs:"
        docker logs "$NAME" 2>&1 || true
        exit 1
    fi
    
    success "Container is running healthy"
}

# Show access information
show_access_info() {
    # Get local IP addresses
    LOCAL_IPS=$(hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^[0-9]+\.' | head -3 | tr '\n' ' ' || echo "localhost")
    
    echo ""
    echo "🎮 Tic Tac Toe is now running!"
    echo ""
    echo "📱 Access your game at:"
    for ip in $LOCAL_IPS; do
        echo "   http://${ip}:${PORT}"
    done
    echo ""
    echo "🐳 Container: $NAME"
    echo "🏷️  Image: $IMAGE"
    echo "🚪 Port: $PORT"
    echo ""
    echo "📋 Useful commands:"
    echo "   Stop:    docker stop $NAME"
    echo "   Start:   docker start $NAME" 
    echo "   Remove:  docker rm -f $NAME"
    echo "   Logs:    docker logs $NAME"
    echo ""
}

# Main installation process
main() {
    echo ""
    echo "🎯 Tic Tac Toe - One Line Installer"
    echo "   Installing AI-generated liquid glass game..."
    echo ""
    
    check_root
    install_docker
    pull_image
    cleanup_existing
    run_container
    check_health
    show_access_info
    
    success "Installation complete! Enjoy your game! 🎮"
}

# Trap errors
trap 'error "Installation failed at line $LINENO"' ERR

# Environment variable help
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Tic Tac Toe One-Line Installer"
    echo ""
    echo "Usage:"
    echo "  bash -c \"\$(wget -qO- https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main/install.sh)\""
    echo ""
    echo "Environment variables:"
    echo "  PORT=8080     Port to run on (default: 8080)"
    echo "  NAME=tictactoe Container name (default: tictactoe)"
    echo "  IMAGE=...     Docker image (default: ghcr.io/jungleeaadmi/tictactoe:latest)"
    echo ""
    echo "Examples:"
    echo "  PORT=9000 bash -c \"\$(wget -qO- https://raw.githubusercontent.com/JungleeAadmi/tictactoe/main/install.sh)\""
    echo "  NAME=mygame PORT=3000 bash -c \"\$(wget -qO- <URL>)\""
    exit 0
fi

# Run main installation
main "$@"
