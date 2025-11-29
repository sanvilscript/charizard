#!/bin/bash
# ==============================================================================
#   CHARIZARD DNS INSTALLER
#   Unbound Recursive Resolver in Docker
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
DNS_DIR="/etc/firewall/dns"
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
# SYSTEMD-RESOLVED HANDLING
# ==============================================================================

disable_resolved() {
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        print_step "Disabling systemd-resolved..."
        systemctl disable --now systemd-resolved
        print_ok "systemd-resolved disabled"
    fi

    # Backup and replace resolv.conf
    if [ -L /etc/resolv.conf ]; then
        print_step "Configuring /etc/resolv.conf..."
        rm -f /etc/resolv.conf
        echo "nameserver 127.0.0.1" > /etc/resolv.conf
        # Make immutable to prevent overwrite
        chattr +i /etc/resolv.conf 2>/dev/null || true
        print_ok "resolv.conf configured"
    fi
}

# ==============================================================================
# INSTALLATION
# ==============================================================================

install_dns() {
    print_header "INSTALLING CHARIZARD DNS"

    # Check if already running
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^charizard_dns$"; then
        print_warn "Charizard DNS already running"
        read -p "  Reinstall? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        print_step "Stopping existing container..."
        docker stop charizard_dns >/dev/null 2>&1 || true
        docker rm charizard_dns >/dev/null 2>&1 || true
    fi

    # Create directory
    print_step "Creating directory: $DNS_DIR"
    mkdir -p "$DNS_DIR/config"
    mkdir -p "$DNS_DIR/data"

    # Copy files
    print_step "Copying configuration files..."
    if [ -f "$SCRIPT_DIR/Dockerfile" ]; then
        cp "$SCRIPT_DIR/Dockerfile" "$DNS_DIR/"
    else
        print_error "Dockerfile not found in $SCRIPT_DIR"
        exit 1
    fi
    if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
        cp "$SCRIPT_DIR/docker-compose.yml" "$DNS_DIR/"
    else
        print_error "docker-compose.yml not found in $SCRIPT_DIR"
        exit 1
    fi
    if [ -f "$SCRIPT_DIR/config/unbound.conf" ]; then
        cp "$SCRIPT_DIR/config/unbound.conf" "$DNS_DIR/config/"
    else
        print_error "config/unbound.conf not found in $SCRIPT_DIR"
        exit 1
    fi
    print_ok "Configuration files copied"

    # Download root hints
    print_step "Downloading root hints..."
    if curl -sS --fail https://www.internic.net/domain/named.root -o "$DNS_DIR/data/root.hints" 2>/dev/null; then
        print_ok "Root hints downloaded"
    else
        # Fallback: use bundled or create minimal
        print_warn "Could not download root hints, using fallback"
        cat > "$DNS_DIR/data/root.hints" << 'EOFROOTS'
; Root hints for Unbound
.                        3600000      NS    a.root-servers.net.
a.root-servers.net.      3600000      A     198.41.0.4
a.root-servers.net.      3600000      AAAA  2001:503:ba3e::2:30
.                        3600000      NS    b.root-servers.net.
b.root-servers.net.      3600000      A     170.247.170.2
b.root-servers.net.      3600000      AAAA  2801:1b8:10::b
.                        3600000      NS    c.root-servers.net.
c.root-servers.net.      3600000      A     192.33.4.12
c.root-servers.net.      3600000      AAAA  2001:500:2::c
.                        3600000      NS    d.root-servers.net.
d.root-servers.net.      3600000      A     199.7.91.13
d.root-servers.net.      3600000      AAAA  2001:500:2d::d
EOFROOTS
        print_ok "Fallback root hints created"
    fi

    # Create empty hosts.local
    touch "$DNS_DIR/data/hosts.local"

    # Create hosts.json template
    if [ ! -f "$DNS_DIR/hosts.json" ]; then
        cat > "$DNS_DIR/hosts.json" <<'EOF'
{
  "hosts": []
}
EOF
        print_ok "hosts.json template created"
    fi

    # Disable systemd-resolved if present
    disable_resolved

    # Build and start
    print_step "Building Docker image..."
    cd "$DNS_DIR"
    docker compose build --quiet
    print_ok "Image built"

    print_step "Starting Charizard DNS..."
    docker compose up -d
    sleep 3

    # Verify
    if docker ps --format '{{.Names}}' | grep -q "^charizard_dns$"; then
        print_ok "Charizard DNS started"
    else
        print_error "Failed to start Charizard DNS"
        docker compose logs
        exit 1
    fi

    # Test resolution
    print_step "Testing DNS resolution..."
    sleep 2
    if dig @127.0.0.1 cloudflare.com +short +time=5 >/dev/null 2>&1; then
        print_ok "DNS resolution working"
    else
        print_warn "DNS test failed - container may still be starting"
    fi

    print_header "INSTALLATION COMPLETE"
    echo "  Charizard DNS is running on port 53"
    echo ""
    echo "  Commands:"
    echo "    charizard dns status   - Show status"
    echo "    charizard dns add      - Add local host"
    echo "    charizard dns hosts    - List local hosts"
    echo "    charizard dns test     - Test resolution"
    echo ""
    echo "  Test: dig @127.0.0.1 google.com"
    echo ""
}

# ==============================================================================
# UNINSTALL
# ==============================================================================

uninstall_dns() {
    print_header "UNINSTALLING CHARIZARD DNS"

    read -p "Are you sure? This will remove Charizard DNS! [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_warn "Cancelled"
        exit 0
    fi

    # Stop container
    print_step "Stopping Charizard DNS..."
    if [ -f "$DNS_DIR/docker-compose.yml" ]; then
        cd "$DNS_DIR"
        docker compose down -v >/dev/null 2>&1 || true
    fi
    docker stop charizard_dns >/dev/null 2>&1 || true
    docker rm charizard_dns >/dev/null 2>&1 || true
    docker rmi charizard_dns:latest >/dev/null 2>&1 || true
    print_ok "Container removed"

    # Remove directory (keep hosts.json)
    if [ -f "$DNS_DIR/hosts.json" ]; then
        cp "$DNS_DIR/hosts.json" /tmp/charizard-dns-hosts.json.bak
        print_warn "hosts.json backed up to /tmp/"
    fi
    rm -rf "$DNS_DIR"
    print_ok "Configuration removed"

    # Restore resolv.conf
    print_step "Restoring DNS configuration..."
    chattr -i /etc/resolv.conf 2>/dev/null || true
    if [ -f /run/systemd/resolve/stub-resolv.conf ]; then
        ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        systemctl enable --now systemd-resolved 2>/dev/null || true
        print_ok "systemd-resolved restored"
    else
        echo "nameserver 8.8.8.8" > /etc/resolv.conf
        print_ok "Using Google DNS as fallback"
    fi

    print_ok "Uninstallation complete"
}

# ==============================================================================
# STATUS
# ==============================================================================

show_status() {
    print_header "CHARIZARD DNS STATUS"

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^charizard_dns$"; then
        print_ok "Container: running"
        echo ""
        echo "  Image: $(docker inspect charizard_dns --format '{{.Config.Image}}' 2>/dev/null)"
        echo "  Uptime: $(docker inspect charizard_dns --format '{{.State.StartedAt}}' 2>/dev/null | cut -d'T' -f1)"
        echo ""

        # Test resolution
        if dig @127.0.0.1 cloudflare.com +short +time=3 >/dev/null 2>&1; then
            print_ok "DNS resolution: working"
        else
            print_error "DNS resolution: failed"
        fi
    else
        print_error "Container: not running"
    fi

    echo ""

    # Local hosts count
    if [ -f "$DNS_DIR/hosts.json" ]; then
        HOSTS_COUNT=$(grep -c '"name"' "$DNS_DIR/hosts.json" 2>/dev/null || echo "0")
        echo "  Local hosts: $HOSTS_COUNT"
    fi

    echo ""
}

# ==============================================================================
# HELP
# ==============================================================================

show_help() {
    echo ""
    echo "Charizard DNS Installer"
    echo ""
    echo "Usage: sudo bash $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     Install Charizard DNS (default)"
    echo "  uninstall   Remove Charizard DNS"
    echo "  status      Show status"
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
            install_dns
            ;;
        uninstall|remove)
            check_root
            uninstall_dns
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
