#!/bin/bash
# ==============================================================================
#   PORTAINER CE INSTALLER
#   Docker management UI
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
PORTAINER_DIR="/home/$DOCKER_USER/docker/portainer"
PORTAINER_PORT="9443"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

check_docker() {
    if ! command -v docker &>/dev/null; then
        print_error "Docker not installed. Run: charizard install docker"
        exit 1
    fi
}

# ==============================================================================
# INSTALLATION
# ==============================================================================

install_portainer() {
    print_header "INSTALLING PORTAINER CE"

    # Check if already running
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
        print_warn "Portainer already running"
        read -p "  Reinstall? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        print_step "Stopping existing Portainer..."
        docker stop portainer >/dev/null 2>&1 || true
        docker rm portainer >/dev/null 2>&1 || true
    fi

    # Create directory
    print_step "Creating directory: $PORTAINER_DIR"
    mkdir -p "$PORTAINER_DIR"

    # Copy docker-compose.yml
    print_step "Copying docker-compose.yml..."
    cp "$SCRIPT_DIR/docker-compose.yml" "$PORTAINER_DIR/"
    print_ok "docker-compose.yml copied"

    # Set ownership
    chown -R "$DOCKER_USER:$DOCKER_USER" "$PORTAINER_DIR"

    # Start Portainer
    print_step "Starting Portainer..."
    cd "$PORTAINER_DIR"
    docker compose up -d >/dev/null 2>&1

    # Wait for container
    sleep 3
    if docker ps --format '{{.Names}}' | grep -q "^portainer$"; then
        print_ok "Portainer started"
    else
        print_error "Failed to start Portainer"
        docker compose logs
        exit 1
    fi

    # Get server IP
    SERVER_IP=$(hostname -I | awk '{print $1}')

    print_header "INSTALLATION COMPLETE"
    echo "  Portainer UI: https://$SERVER_IP:$PORTAINER_PORT"
    echo ""
    echo "  Commands:"
    echo "    charizard portainer status    - Show status"
    echo "    charizard portainer restart   - Restart Portainer"
    echo "    charizard portainer logs      - Show logs"
    echo ""
}

# ==============================================================================
# UNINSTALL
# ==============================================================================

uninstall_portainer() {
    print_header "UNINSTALLING PORTAINER"

    read -p "Are you sure? This will remove Portainer! [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warn "Cancelled"
        exit 0
    fi

    # Stop Portainer
    print_step "Stopping Portainer..."
    if [ -f "$PORTAINER_DIR/docker-compose.yml" ]; then
        cd "$PORTAINER_DIR"
        docker compose down -v >/dev/null 2>&1 || true
    fi
    docker stop portainer >/dev/null 2>&1 || true
    docker rm portainer >/dev/null 2>&1 || true
    rm -rf "$PORTAINER_DIR"
    print_ok "Portainer removed"

    print_ok "Uninstallation complete"
}

# ==============================================================================
# STATUS
# ==============================================================================

show_status() {
    print_header "PORTAINER STATUS"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
        print_ok "Container: running"
        SERVER_IP=$(hostname -I | awk '{print $1}')
        echo ""
        echo "  URL: https://$SERVER_IP:$PORTAINER_PORT"
        echo "  Image: $(docker inspect portainer --format '{{.Config.Image}}' 2>/dev/null)"
        echo "  Uptime: $(docker inspect portainer --format '{{.State.StartedAt}}' 2>/dev/null | cut -d'T' -f1)"
    else
        print_error "Container: not running"
    fi

    echo ""
}

# ==============================================================================
# OTHER COMMANDS
# ==============================================================================

restart_portainer() {
    print_step "Restarting Portainer..."
    if [ -f "$PORTAINER_DIR/docker-compose.yml" ]; then
        cd "$PORTAINER_DIR"
        docker compose restart
        print_ok "Portainer restarted"
    else
        docker restart portainer 2>/dev/null || print_error "Portainer not found"
    fi
}

show_logs() {
    if [ -f "$PORTAINER_DIR/docker-compose.yml" ]; then
        cd "$PORTAINER_DIR"
        docker compose logs -f --tail=50
    else
        docker logs -f --tail=50 portainer 2>/dev/null || print_error "Portainer not found"
    fi
}

# ==============================================================================
# HELP
# ==============================================================================

show_help() {
    echo ""
    echo "Portainer CE Installer"
    echo ""
    echo "Usage: sudo bash $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     Install Portainer CE (default)"
    echo "  uninstall   Remove Portainer"
    echo "  status      Show status"
    echo "  restart     Restart Portainer"
    echo "  logs        Show logs"
    echo "  help        Show this help"
    echo ""
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    case "${1:-install}" in
        install)
            check_root
            check_docker
            install_portainer
            ;;
        uninstall|remove)
            check_root
            uninstall_portainer
            ;;
        status)
            show_status
            ;;
        restart)
            restart_portainer
            ;;
        logs)
            show_logs
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
