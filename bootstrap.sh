#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD FIREWALL - BOOTSTRAP INSTALLER
#   One-liner installation script
#   Developed by Sanvil (c) 2025
#
#   Usage:
#     curl -fsSL https://raw.githubusercontent.com/sanvilscript/charizard/main/bootstrap.sh | bash
#     wget -qO- https://raw.githubusercontent.com/sanvilscript/charizard/main/bootstrap.sh | bash
#
# ══════════════════════════════════════════════════════════════════════════════
set -e

REPO_URL="https://github.com/sanvilscript/charizard.git"
INSTALL_DIR="/tmp/charizard-install"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "  ═══════════════════════════════════════════════════════════════"
echo "   CHARIZARD FIREWALL - Bootstrap Installer"
echo "  ═══════════════════════════════════════════════════════════════"
echo ""

# ══════════════════════════════════════════════════════════════════════════════
# AUTO-ELEVATE TO ROOT
# ══════════════════════════════════════════════════════════════════════════════

BOOTSTRAP_URL="https://raw.githubusercontent.com/sanvilscript/charizard/main/bootstrap.sh"

if [ "$EUID" -ne 0 ]; then
    echo "  [*] Elevating to root..."

    # Determine download command
    if command -v curl &>/dev/null; then
        DL_CMD="curl -fsSL $BOOTSTRAP_URL"
    elif command -v wget &>/dev/null; then
        DL_CMD="wget -qO- $BOOTSTRAP_URL"
    else
        echo -e "  ${RED}[!] curl or wget required${NC}"
        exit 1
    fi

    # Try sudo first, then su -c
    if command -v sudo &>/dev/null; then
        exec sudo bash -c "$($DL_CMD)"
    else
        echo "  [*] sudo not found, using su (enter root password):"
        exec su -c "bash -c \"\$($DL_CMD)\""
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# INSTALL PREREQUISITES
# ══════════════════════════════════════════════════════════════════════════════

echo "  [1/4] Checking prerequisites..."

# Update package list
apt-get update >/dev/null 2>&1

# Install sudo if missing
if ! command -v sudo &>/dev/null; then
    echo "        Installing sudo..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y sudo >/dev/null 2>&1
    echo -e "        ${GREEN}✓${NC} sudo installed"
else
    echo -e "        ${GREEN}✓${NC} sudo"
fi

# Install git if missing
if ! command -v git &>/dev/null; then
    echo "        Installing git..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1
    echo -e "        ${GREEN}✓${NC} git installed"
else
    echo -e "        ${GREEN}✓${NC} git"
fi

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURE SUDO FOR MAIN USER
# ══════════════════════════════════════════════════════════════════════════════

echo "  [2/4] Configuring sudo..."

MAIN_USER=$(getent passwd 1000 2>/dev/null | cut -d: -f1)

if [ -n "$MAIN_USER" ]; then
    # Check if already configured
    if [ -f "/etc/sudoers.d/99-charizard-user" ]; then
        echo -e "        ${GREEN}✓${NC} sudoers already configured"
    elif grep -rq "^$MAIN_USER.*NOPASSWD" /etc/sudoers.d/ 2>/dev/null; then
        echo -e "        ${GREEN}✓${NC} $MAIN_USER already has NOPASSWD"
    else
        echo "$MAIN_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-charizard-user
        chmod 440 /etc/sudoers.d/99-charizard-user
        echo -e "        ${GREEN}✓${NC} $MAIN_USER added to sudoers (NOPASSWD)"
    fi
    # Ensure user is in sudo group
    usermod -aG sudo "$MAIN_USER" 2>/dev/null || true
else
    echo -e "        ${YELLOW}!${NC} No user with uid 1000 found (skipped)"
fi

# ══════════════════════════════════════════════════════════════════════════════
# CLONE REPOSITORY
# ══════════════════════════════════════════════════════════════════════════════

echo "  [3/4] Downloading Charizard..."

# Cleanup previous attempts
rm -rf "$INSTALL_DIR" 2>/dev/null || true

# Clone repository
if git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" >/dev/null 2>&1; then
    echo -e "        ${GREEN}✓${NC} Repository cloned"
else
    echo -e "        ${RED}✗${NC} Failed to clone repository"
    echo ""
    echo "  Check your internet connection and try again."
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# RUN INSTALLER
# ══════════════════════════════════════════════════════════════════════════════

echo "  [4/4] Running installer..."
echo ""

# Run the main installer
cd "$INSTALL_DIR"
bash install.sh

# ══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ══════════════════════════════════════════════════════════════════════════════

cd /
rm -rf "$INSTALL_DIR" 2>/dev/null || true

echo ""
echo "  ═══════════════════════════════════════════════════════════════"
echo -e "  ${GREEN}Bootstrap complete!${NC}"
echo "  ═══════════════════════════════════════════════════════════════"
echo ""
