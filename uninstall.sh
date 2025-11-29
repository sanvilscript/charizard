#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD FIREWALL - UNINSTALLER v1.0.0
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════
set -e

echo ""
echo "  # CHARIZARD v1.0.0 - Uninstaller"
echo "  # By Sanvil"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "  [!] Please run as root: sudo bash uninstall.sh"
    exit 1
fi

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ WARNING                                                         │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
echo "  This will completely remove Charizard firewall + monitor and:"
echo "  - Flush all iptables/ip6tables rules"
echo "  - Remove ipset whitelist/blacklist"
echo "  - Delete configuration files and monitor"
echo "  - Remove sysctl hardening"
echo "  - Remove logs and systemd timer"
echo ""
echo -n "  Are you sure? [y/N]: "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "  [!] Aborted."
    exit 0
fi

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ REMOVING                                                        │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# [1/11] Flush iptables
echo "  [1/11] Flushing iptables..."
iptables -F 2>/dev/null || true
iptables -X LOGDROP 2>/dev/null || true
iptables -P INPUT ACCEPT 2>/dev/null || true
iptables -P FORWARD ACCEPT 2>/dev/null || true
iptables -P OUTPUT ACCEPT 2>/dev/null || true
ip6tables -F 2>/dev/null || true
ip6tables -X LOGDROP6 2>/dev/null || true
ip6tables -P INPUT ACCEPT 2>/dev/null || true
ip6tables -P FORWARD ACCEPT 2>/dev/null || true
ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
# Clear DOCKER-USER if exists
iptables -F DOCKER-USER 2>/dev/null || true
ip6tables -F DOCKER-USER 2>/dev/null || true
echo "        ✓ iptables/ip6tables flushed (policy: ACCEPT)"

# [2/11] Remove ipsets
echo "  [2/11] Removing ipsets..."
ipset destroy whitelist 2>/dev/null || true
ipset destroy whitelist6 2>/dev/null || true
ipset destroy blacklist 2>/dev/null || true
ipset destroy blacklist6 2>/dev/null || true
ipset destroy whitelist_tmp 2>/dev/null || true
ipset destroy whitelist6_tmp 2>/dev/null || true
ipset destroy spamhaus 2>/dev/null || true
ipset destroy spamhaus_tmp 2>/dev/null || true
ipset destroy spamhaus6 2>/dev/null || true
ipset destroy spamhaus6_tmp 2>/dev/null || true
ipset destroy fail2ban 2>/dev/null || true
echo "        ✓ All ipsets removed (incl. spamhaus, fail2ban)"

# [3/12] Remove fail2ban configuration
echo "  [3/12] Removing fail2ban configuration..."
# Remove iptables rule first
iptables -D INPUT -m set --match-set fail2ban src -j DROP 2>/dev/null || true
# Remove action and jail config
rm -f /etc/fail2ban/action.d/charizard.conf
rm -f /etc/fail2ban/jail.local
# Restart fail2ban if running (to clear state)
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    systemctl restart fail2ban 2>/dev/null || true
fi
echo "        ✓ /etc/fail2ban/action.d/charizard.conf"
echo "        ✓ /etc/fail2ban/jail.local"
echo "        ✓ fail2ban ipset and iptables rule"

# [4/12] Remove systemd service and timers
echo "  [4/12] Removing systemd service and timers..."
systemctl disable --now charizard.service 2>/dev/null || true
systemctl disable --now charizard-update.timer 2>/dev/null || true
systemctl disable --now charizard-cache.timer 2>/dev/null || true
systemctl disable --now charizard-spamhaus.timer 2>/dev/null || true
systemctl disable --now charizard-bot.service 2>/dev/null || true
systemctl disable --now charizard-report.timer 2>/dev/null || true
systemctl disable --now charizard-s3-backup.timer 2>/dev/null || true
rm -f /etc/systemd/system/charizard.service
rm -f /etc/systemd/system/charizard-update.timer
rm -f /etc/systemd/system/charizard-update.service
rm -f /etc/systemd/system/charizard-cache.timer
rm -f /etc/systemd/system/charizard-cache.service
rm -f /etc/systemd/system/charizard-spamhaus.timer
rm -f /etc/systemd/system/charizard-spamhaus.service
rm -f /etc/systemd/system/charizard-bot.service
rm -f /etc/systemd/system/charizard-report.timer
rm -f /etc/systemd/system/charizard-report.service
rm -f /etc/systemd/system/charizard-s3-backup.timer
rm -f /etc/systemd/system/charizard-s3-backup.service
systemctl daemon-reload 2>/dev/null || true
# Remove legacy cron if exists
rm -f /etc/cron.d/charizard 2>/dev/null || true
echo "        ✓ charizard.service (boot)"
echo "        ✓ charizard-update.timer"
echo "        ✓ charizard-cache.timer"
echo "        ✓ charizard-spamhaus.timer"
echo "        ✓ charizard-bot.service (telegram)"
echo "        ✓ charizard-report.timer (telegram)"
echo "        ✓ charizard-s3-backup.timer (s3)"

# [5/12] Remove rsyslog config
echo "  [5/12] Removing rsyslog config..."
rm -f /etc/rsyslog.d/10-charizard.conf
systemctl restart rsyslog 2>/dev/null || true
echo "        ✓ /etc/rsyslog.d/10-charizard.conf"

# [6/12] Remove logrotate config
echo "  [6/12] Removing logrotate config..."
rm -f /etc/logrotate.d/charizard
echo "        ✓ /etc/logrotate.d/charizard"

# [7/12] Remove sysctl hardening
echo "  [7/12] Removing sysctl hardening..."
rm -f /etc/sysctl.d/99-charizard.conf
sysctl --system >/dev/null 2>&1 || true
echo "        ✓ /etc/sysctl.d/99-charizard.conf"

# [8/12] Remove bash customizations
echo "  [8/12] Removing bash customizations..."
rm -f /etc/profile.d/charizard-aliases.sh
rm -f /etc/profile.d/charizard-prompt.sh
rm -f /etc/profile.d/charizard-bashrc.sh
echo "        ✓ /etc/profile.d/charizard-*.sh"

# [9/12] Remove vimrc
echo "  [9/12] Removing vimrc..."
rm -f /etc/vim/vimrc.local
echo "        ✓ /etc/vim/vimrc.local"

# [10/12] Remove screenrc
echo "  [10/12] Removing screenrc..."
rm -f /etc/screenrc
echo "        ✓ /etc/screenrc"

# [11/12] Remove files
echo "  [11/12] Removing files..."
rm -f /usr/local/bin/charizard
rm -f /usr/local/bin/cmon
rm -rf /etc/firewall
rm -f /var/log/charizard.log*
rm -f /var/log/charizard-bot.log*
echo "        ✓ /usr/local/bin/charizard"
echo "        ✓ /usr/local/bin/cmon"
echo "        ✓ /etc/firewall/"
echo "        ✓ /var/log/charizard.log"
echo "        ✓ /var/log/charizard-bot.log"

# [12/12] Save iptables-persistent empty state
echo "  [12/12] Saving empty firewall state..."
netfilter-persistent save 2>/dev/null || true
echo "        ✓ iptables-persistent saved"

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ UNINSTALL COMPLETE                                              │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │                                                                 │"
echo "  │  Charizard firewall + monitor completely removed.               │"
echo "  │  Firewall is now OPEN (all traffic allowed).                    │"
echo "  │                                                                 │"
echo "  │  Note: sysctl defaults will apply after reboot.                 │"
echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
