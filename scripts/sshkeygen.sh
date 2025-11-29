#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD - SSH Key Setup Utility v1.0.0
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════
# Cross-platform SSH key generator and deployer (Mac/Linux)
# Usage: ./sshkeygen.sh --ip <server> --user <username>
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ============================================
# COLORS & FORMATTING
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ============================================
# OUTPUT FUNCTIONS
# ============================================
print_header() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }

# ============================================
# INTERACTIVE QUESTION FUNCTIONS
# ============================================

# Ask multiple choice question
# Usage: ask_choice "Question" "opt1" "opt2" "opt3"
# Returns: selected index (0-based) in CHOICE variable
ask_choice() {
    local question="$1"
    shift
    local options=("$@")
    local count=${#options[@]}

    echo ""
    echo -e "${BOLD}${question}${NC}"
    echo ""

    for i in "${!options[@]}"; do
        echo -e "  ${CYAN}$((i+1))${NC}) ${options[$i]}"
    done

    echo ""
    while true; do
        read -r -p "Select [1-${count}]: " CHOICE
        if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "$count" ]; then
            CHOICE=$((CHOICE-1))
            return 0
        fi
        echo -e "${RED}Invalid. Enter 1-${count}${NC}"
    done
}

# Ask for text input with default
# Usage: ask_input "Question" "default"
# Returns: value in INPUT variable
ask_input() {
    local question="$1"
    local default="${2:-}"

    echo ""
    echo -e "${BOLD}${question}${NC}"
    if [[ -n "$default" ]]; then
        echo -e "${CYAN}Default: ${default}${NC}"
    fi
    read -r -p "> " INPUT
    INPUT="${INPUT:-$default}"
}

# ============================================
# VARIABLES
# ============================================
TARGET_IP=""
TARGET_USER=""
KEY_TYPE="ed25519"
KEY_PATH=""
KEY_COMMENT=""

# ============================================
# USAGE
# ============================================
usage() {
    echo ""
    echo "  CHARIZARD - SSH Key Setup Utility"
    echo "  By Sanvil"
    echo ""
    echo "  Usage: $0 [OPTIONS]"
    echo ""
    echo "  Options:"
    echo "    --ip IP       Target server IP or domain"
    echo "    --user USER   Target username (default: debian)"
    echo "    --help        Show this help"
    echo ""
    echo "  Examples:"
    echo "    $0 --ip server.example.com --user debian"
    echo "    $0 --ip 192.168.1.100"
    echo ""
}

# ============================================
# PARSE ARGUMENTS
# ============================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ip)
                TARGET_IP="$2"
                shift 2
                ;;
            --user)
                TARGET_USER="$2"
                shift 2
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# ============================================
# CHECK EXISTING KEYS
# ============================================
find_existing_keys() {
    local found=()

    [[ -f "$HOME/.ssh/id_ed25519.pub" ]] && found+=("ed25519")
    [[ -f "$HOME/.ssh/id_rsa.pub" ]] && found+=("rsa")
    [[ -f "$HOME/.ssh/id_ecdsa.pub" ]] && found+=("ecdsa")

    echo "${found[@]:-}"
}

# ============================================
# GENERATE NEW KEY
# ============================================
generate_key() {
    print_header "Generate New SSH Key"

    # Key type selection
    ask_choice "Select key type:" \
        "ed25519 (recommended - modern, fast, secure)" \
        "rsa-4096 (legacy - wide compatibility)"

    case $CHOICE in
        0) KEY_TYPE="ed25519" ;;
        1) KEY_TYPE="rsa" ;;
    esac

    KEY_PATH="$HOME/.ssh/id_${KEY_TYPE}"

    # Check if exists
    if [[ -f "$KEY_PATH" ]]; then
        ask_choice "Key $KEY_PATH already exists:" \
            "Use existing key (don't generate new)" \
            "Overwrite with new key"

        if [[ $CHOICE -eq 0 ]]; then
            print_info "Using existing key: $KEY_PATH"
            return 0
        fi
    fi

    # Email/comment
    local default_comment="$(whoami)@$(hostname -s 2>/dev/null || hostname)"
    ask_input "Enter email or comment for the key:" "$default_comment"
    KEY_COMMENT="$INPUT"

    # Passphrase
    ask_choice "Protect key with passphrase?" \
        "No passphrase (convenient for automation)" \
        "Set passphrase (more secure)"

    local use_passphrase=$CHOICE

    # Create .ssh directory
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Generate key
    print_info "Generating $KEY_TYPE key..."
    echo ""

    if [[ $use_passphrase -eq 0 ]]; then
        if [[ "$KEY_TYPE" == "rsa" ]]; then
            ssh-keygen -t rsa -b 4096 -C "$KEY_COMMENT" -f "$KEY_PATH" -N ""
        else
            ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$KEY_PATH" -N ""
        fi
    else
        if [[ "$KEY_TYPE" == "rsa" ]]; then
            ssh-keygen -t rsa -b 4096 -C "$KEY_COMMENT" -f "$KEY_PATH"
        else
            ssh-keygen -t "$KEY_TYPE" -C "$KEY_COMMENT" -f "$KEY_PATH"
        fi
    fi

    if [[ $? -eq 0 ]]; then
        echo ""
        print_success "Key generated successfully!"
        print_info "Private key: $KEY_PATH"
        print_info "Public key:  ${KEY_PATH}.pub"
    else
        print_error "Failed to generate key"
        exit 1
    fi
}

# ============================================
# COPY KEY TO SERVER
# ============================================
copy_key_to_server() {
    print_header "Copy Key to Server"

    print_info "Target: ${TARGET_USER}@${TARGET_IP}"
    print_info "Key:    ${KEY_PATH}.pub"
    echo ""
    print_warning "Enter the server password when prompted (one time only)"
    echo ""

    if ssh-copy-id -i "${KEY_PATH}.pub" "${TARGET_USER}@${TARGET_IP}"; then
        echo ""
        print_success "Key copied successfully!"
    else
        echo ""
        print_error "Failed to copy key to server"
        print_info "Make sure the server is reachable and password is correct"
        exit 1
    fi
}

# ============================================
# TEST CONNECTION
# ============================================
test_connection() {
    print_header "Test Connection"

    print_info "Testing passwordless SSH connection..."
    echo ""

    # Test with BatchMode (fails if password required)
    if ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
        "${TARGET_USER}@${TARGET_IP}" "echo 'OK'" 2>/dev/null; then

        print_success "SSH key authentication is working!"
        echo ""
        echo -e "${GREEN}You can now connect without password:${NC}"
        echo -e "  ${BOLD}ssh ${TARGET_USER}@${TARGET_IP}${NC}"
        echo ""
    else
        print_error "Passwordless connection failed"
        print_info "Try connecting manually to debug:"
        echo "  ssh -v ${TARGET_USER}@${TARGET_IP}"
        exit 1
    fi
}

# ============================================
# MAIN
# ============================================
main() {
    print_header "CHARIZARD - SSH Key Setup"

    # Parse command line arguments
    parse_args "$@"

    # ─────────────────────────────────────────
    # STEP 1: Check for existing keys
    # ─────────────────────────────────────────
    print_info "Checking for existing SSH keys..."

    existing_keys=$(find_existing_keys)

    if [[ -n "$existing_keys" ]]; then
        print_success "Found existing keys:"
        for key in $existing_keys; do
            echo "  - ~/.ssh/id_${key} ($key)"
        done

        # Build options array
        local options=()
        for key in $existing_keys; do
            options+=("Use existing $key key")
        done
        options+=("Generate new key")

        ask_choice "What do you want to do?" "${options[@]}"

        local num_existing=$(echo "$existing_keys" | wc -w | tr -d ' ')

        if [[ $CHOICE -lt $num_existing ]]; then
            # Selected existing key
            local selected_key=$(echo "$existing_keys" | tr ' ' '\n' | sed -n "$((CHOICE+1))p")
            KEY_TYPE="$selected_key"
            KEY_PATH="$HOME/.ssh/id_${KEY_TYPE}"
            print_info "Using key: $KEY_PATH"
        else
            # Generate new
            generate_key
        fi
    else
        print_warning "No SSH keys found"
        generate_key
    fi

    # ─────────────────────────────────────────
    # STEP 2: Get server details (if not provided)
    # ─────────────────────────────────────────
    if [[ -z "$TARGET_IP" ]]; then
        ask_input "Enter server IP or domain:" ""
        TARGET_IP="$INPUT"

        if [[ -z "$TARGET_IP" ]]; then
            print_error "Server IP/domain is required"
            exit 1
        fi
    fi

    if [[ -z "$TARGET_USER" ]]; then
        ask_input "Enter SSH username:" "debian"
        TARGET_USER="$INPUT"
    fi

    print_info "Server: ${TARGET_USER}@${TARGET_IP}"

    # ─────────────────────────────────────────
    # STEP 3: Copy key to server
    # ─────────────────────────────────────────
    copy_key_to_server

    # ─────────────────────────────────────────
    # STEP 4: Test connection
    # ─────────────────────────────────────────
    test_connection

    print_header "Setup Complete"
    print_success "SSH key authentication configured!"
    echo ""
    echo -e "  ${CYAN}Ready to use Charizard firewall on this server!${NC}"
    echo ""
}

# Run main
main "$@"
