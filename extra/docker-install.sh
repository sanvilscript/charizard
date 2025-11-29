#!/bin/bash
# ==============================================================================
#   DOCKER ENGINE INSTALLER
#   Quick install Docker Engine on Debian 12/13
#   Developed by Sanvil (c) 2025
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Config
DOCKER_USER="${SUDO_USER:-debian}"

# ==============================================================================
# HELPERS
# ==============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_ok() {
    echo -e "${GREEN}[ok]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[x]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        echo "Usage: sudo bash $0"
        exit 1
    fi
}

check_debian() {
    if [ ! -f /etc/debian_version ]; then
        print_error "This script is for Debian only"
        exit 1
    fi
    DEBIAN_VERSION=$(cat /etc/debian_version | cut -d. -f1)
    print_ok "Debian $DEBIAN_VERSION detected"
}

# ==============================================================================
# DOCKER INSTALLATION
# ==============================================================================

install_docker() {
    print_header "INSTALLING DOCKER ENGINE"

    # Check if already installed
    if command -v docker &>/dev/null; then
        DOCKER_VER=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        print_warn "Docker already installed: v$DOCKER_VER"
        read -p "  Reinstall? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    # Prerequisites
    print_step "Installing prerequisites..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg lsb-release >/dev/null
    print_ok "Prerequisites installed"

    # Docker GPG key
    print_step "Adding Docker GPG key..."
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
    chmod a+r /etc/apt/keyrings/docker.gpg
    print_ok "GPG key added"

    # Docker repository
    print_step "Adding Docker repository..."
    CODENAME=$(lsb_release -cs)
    # Fallback for Debian 13 (trixie) if not in Docker repo yet
    if ! curl -fsSL "https://download.docker.com/linux/debian/dists/$CODENAME/Release" &>/dev/null; then
        print_warn "Codename '$CODENAME' not found, using 'bookworm'"
        CODENAME="bookworm"
    fi
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $CODENAME stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    print_ok "Repository added"

    # Install Docker
    print_step "Installing Docker packages..."
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    print_ok "Docker packages installed"

    # Add user to docker group
    print_step "Adding user '$DOCKER_USER' to docker group..."
    usermod -aG docker "$DOCKER_USER"
    print_ok "User added to docker group"

    # Enable and start
    print_step "Enabling Docker service..."
    systemctl enable docker >/dev/null 2>&1
    systemctl start docker
    print_ok "Docker service started"

    # Verify
    DOCKER_VER=$(docker --version | awk '{print $3}' | tr -d ',')
    COMPOSE_VER=$(docker compose version | awk '{print $4}')
    print_ok "Docker v$DOCKER_VER installed"
    print_ok "Docker Compose v$COMPOSE_VER installed"
}

# ==============================================================================
# VERIFICATION
# ==============================================================================

verify_installation() {
    print_header "VERIFICATION"

    # Docker
    if command -v docker &>/dev/null; then
        print_ok "Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
    else
        print_error "Docker not found"
    fi

    # Docker Compose
    if docker compose version &>/dev/null; then
        print_ok "Compose: $(docker compose version | awk '{print $4}')"
    else
        print_error "Docker Compose not found"
    fi

    echo ""
    echo -e "${CYAN}==============================================================${NC}"
    echo -e "${GREEN}  INSTALLATION COMPLETE${NC}"
    echo -e "${CYAN}==============================================================${NC}"
    echo ""
    echo -e "  ${YELLOW}NOTE:${NC} Log out and back in for docker group to take effect"
    echo -e "        Or run: ${CYAN}newgrp docker${NC}"
    echo ""
    echo -e "  Next steps:"
    echo -e "    ${CYAN}charizard install portainer${NC} - Install Portainer UI"
    echo ""
}

# ==============================================================================
# UNINSTALL
# ==============================================================================

uninstall() {
    print_header "UNINSTALLING DOCKER"

    read -p "Are you sure? This will remove Docker and all containers! [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warn "Cancelled"
        exit 0
    fi

    # Remove Docker
    print_step "Removing Docker..."
    apt-get purge -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null 2>&1 || true
    apt-get autoremove -y -qq >/dev/null 2>&1
    rm -rf /var/lib/docker
    rm -rf /var/lib/containerd
    rm -f /etc/apt/sources.list.d/docker.list
    rm -f /etc/apt/keyrings/docker.gpg
    print_ok "Docker removed"

    print_ok "Uninstallation complete"
}

# ==============================================================================
# STATUS
# ==============================================================================

show_status() {
    print_header "DOCKER STATUS"

    # Docker
    if command -v docker &>/dev/null; then
        print_ok "Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
        print_ok "Compose: $(docker compose version 2>/dev/null | awk '{print $4}' || echo 'N/A')"

        # Containers
        RUNNING=$(docker ps -q 2>/dev/null | wc -l)
        TOTAL=$(docker ps -aq 2>/dev/null | wc -l)
        echo -e "  Containers: $RUNNING running / $TOTAL total"

        # Images
        IMAGES=$(docker images -q 2>/dev/null | wc -l)
        echo -e "  Images: $IMAGES"
    else
        print_error "Docker not installed"
    fi

    echo ""
}

# ==============================================================================
# HELP
# ==============================================================================

show_help() {
    echo ""
    echo "Docker Engine Installer"
    echo ""
    echo "Usage: sudo bash $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     Install Docker Engine (default)"
    echo "  uninstall   Remove Docker"
    echo "  status      Show status"
    echo "  help        Show this help"
    echo ""
    echo "After installation:"
    echo "  charizard install portainer   Install Portainer UI"
    echo ""
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    case "${1:-install}" in
        install)
            check_root
            check_debian
            install_docker
            verify_installation
            ;;
        uninstall|remove)
            check_root
            uninstall
            ;;
        status)
            show_status
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
