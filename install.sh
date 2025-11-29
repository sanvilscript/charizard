#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD FIREWALL - INSTALLER v1.0.2
#   "Fireblast your packets"
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════
set -e

echo ""
echo "⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠀⢀⢤⠈⢀⠀⢀⠀⠠⠀⠀⠀⠀⢖⠀⡀⠀⠀⠀⠀⠀⠀⠀"
echo "⠀⠀⠀⢀⠄⠊⠐⠁⠀⠀⠀⡀⠀⠀⡅⠀⠀⠀⠀⡆⣤⣥⣂⠠⡀⠀⠀⠀"
echo "⠀⠀⡀⣡⣾⣿⡾⠀⠀⠀⢄⠈⠒⠀⠁⠀⠀⠀⢠⣸⣿⣿⣿⣿⣖⡀⠀⠀"
echo "⠀⠐⣼⣿⣿⣿⣿⣄⠀⠀⠈⠑⢆⡬⠜⠀⠀⠀⡄⣿⣿⣿⣿⣿⣿⣿⠄⠀"
echo "⢀⢳⣿⣿⣿⣿⣿⣿⡆⡀⢀⠀⠀⠃⠀⠀⡠⣠⢘⣿⣿⣿⣿⣿⣿⣿⣏⠆"
echo "⠘⣿⠟⢛⠝⠻⣿⡿⣿⣄⡎⠀⠀⠨⠠⣠⣇⠋⠈⢻⡿⠋⡻⠈⡙⢿⣿⠀"
echo "⢰⠁⠀⠓⠤⢄⠀⠀⡈⡜⠐⠂⢄⠀⠀⡙⢃⠀⠔⠿⢤⡀⡠⠀⠀⠀⠙⡆"
echo "⠀⠀⠀⠀⠀⠀⠈⠁⡘⠀⠀⠀⠀⠡⠀⠈⢂⠐⠀⠀⠀⠈⡐⡀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠀⠀⠔⡇⠀⠀⠀⠀⠀⠆⠀⠀⠡⡀⠀⠀⢀⠃⠁⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠀⢸⠀⠐⡀⠀⠀⠀⠀⡆⠀⠀⠀⢡⣀⠠⠂⠀⡀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠀⢀⠄⠀⠈⡢⢀⡀⠀⠃⠀⠀⠀⡘⠀⠀⡀⠔⠀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠚⠂⣀⠠⠐⠁⠀⠁⠂⠤⣌⠀⠀⠑⠤⠑⠀⠀⠀⠀⠀⠀⠀"
echo "⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠈⠀⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀"
echo ""
echo "  # CHARIZARD v1.0.1 - Fireblast your packets"
echo "  # By Sanvil"
echo ""

# Check root
if [ "$EUID" -ne 0 ]; then
    echo "  [!] Please run as root: sudo bash install.sh"
    exit 1
fi

# ══════════════════════════════════════════════════════════════════════════════
# CHECK EXISTING INSTALLATION
# ══════════════════════════════════════════════════════════════════════════════

if [ -d "/etc/firewall" ] && [ -f "/etc/firewall/firewall.sh" ]; then
    echo "  ┌─────────────────────────────────────────────────────────────────┐"
    echo "  │ EXISTING INSTALLATION DETECTED                                  │"
    echo "  └─────────────────────────────────────────────────────────────────┘"
    echo ""

    ISSUES=0

    # Check firewall.sh
    if [ -x "/etc/firewall/firewall.sh" ]; then
        echo "  [✓] firewall.sh"
    else
        echo "  [✗] firewall.sh (not executable)"
        ISSUES=$((ISSUES+1))
    fi

    # Check symlink charizard
    if [ -L "/usr/local/bin/charizard" ]; then
        echo "  [✓] /usr/local/bin/charizard symlink"
    else
        echo "  [✗] /usr/local/bin/charizard symlink missing"
        ISSUES=$((ISSUES+1))
    fi

    # Check symlink cmon
    if [ -L "/usr/local/bin/cmon" ]; then
        echo "  [✓] /usr/local/bin/cmon symlink"
    else
        echo "  [✗] /usr/local/bin/cmon symlink missing"
        ISSUES=$((ISSUES+1))
    fi

    # Check monitor scripts
    if [ -x "/etc/firewall/monitor/cmon.sh" ] && [ -x "/etc/firewall/monitor/stats.sh" ]; then
        echo "  [✓] monitor scripts"
    else
        echo "  [✗] monitor scripts missing or not executable"
        ISSUES=$((ISSUES+1))
    fi

    # Check systemd timer
    if systemctl is-active charizard-update.timer >/dev/null 2>&1; then
        echo "  [✓] systemd timer active"
    else
        echo "  [✗] systemd timer not active"
        ISSUES=$((ISSUES+1))
    fi

    # Check config files
    if [ -f "/etc/firewall/whitelist.json" ] && [ -f "/etc/firewall/openports.json" ]; then
        echo "  [✓] config files (whitelist.json, openports.json)"
    else
        echo "  [✗] config files missing"
        ISSUES=$((ISSUES+1))
    fi

    # Check sysctl
    if [ -f "/etc/sysctl.d/99-charizard.conf" ]; then
        echo "  [✓] sysctl hardening"
    else
        echo "  [✗] sysctl hardening missing"
        ISSUES=$((ISSUES+1))
    fi

    # Check ipset
    if ipset list whitelist >/dev/null 2>&1; then
        WL_COUNT=$(ipset list whitelist 2>/dev/null | grep -c "^[0-9]" || echo "0")
        BL_COUNT=$(ipset list blacklist 2>/dev/null | grep -c "^[0-9]" || echo "0")
        echo "  [✓] ipset (whitelist: $WL_COUNT IPs, blacklist: $BL_COUNT IPs)"
    else
        echo "  [✗] ipset not configured"
        ISSUES=$((ISSUES+1))
    fi

    echo ""

    if [ "$ISSUES" -eq 0 ]; then
        echo "  [✓] Installation OK - no issues found"
        echo ""
        echo -n "  Reinstall anyway? [y/N]: "
        read -r REINSTALL
        if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
            echo "  [*] Use 'charizard apply' to refresh rules"
            echo ""
            exit 0
        fi
        echo ""
    else
        echo "  [!] Found $ISSUES issue(s) - reinstalling to fix..."
        echo ""
    fi
fi

# ══════════════════════════════════════════════════════════════════════════════
# DETECTION
# ══════════════════════════════════════════════════════════════════════════════

# Detect SSH client IP
SSH_IP=""
if [ -n "$SSH_CLIENT" ]; then
    SSH_IP=$(echo "$SSH_CLIENT" | awk '{print $1}')
elif [ -n "$SSH_CONNECTION" ]; then
    SSH_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
fi

# Detect SSH port from running sshd
SSH_PORT=$(ss -tlnp 2>/dev/null | grep sshd | head -1 | awk '{print $4}' | rev | cut -d: -f1 | rev)
[ -z "$SSH_PORT" ] && SSH_PORT="22"

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ CONFIGURATION                                                   │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# Show detected values
if [ -n "$SSH_IP" ]; then
    echo "  [*] Detected SSH client IP: $SSH_IP"
else
    echo "  [!] Could not detect SSH client IP (local session?)"
fi
echo "  [*] Detected SSH port: $SSH_PORT"
echo ""

# Build default ports (80, 443, SSH_PORT)
if [ "$SSH_PORT" = "22" ]; then
    DEFAULT_PORTS="80,443,22"
else
    DEFAULT_PORTS="80,443,$SSH_PORT"
fi

# Interactive port selection
echo "  Enter ports to open (comma-separated)"
echo -n "  [$DEFAULT_PORTS]: "
read -r USER_PORTS
PORTS="${USER_PORTS:-$DEFAULT_PORTS}"
echo ""
echo "  [✓] Ports to open: $PORTS"
echo ""

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ INSTALLATION                                                    │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# Dependencies (firewall + monitor + tools)
echo "  [1/16] Installing dependencies..."
DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
DEBIAN_FRONTEND=noninteractive apt-get install -y sudo curl jq ipset iptables-persistent rsyslog tmux screen iftop nethogs vnstat btop nmap tree htop fail2ban sysstat iotop rclone unzip mmdb-bin >/dev/null 2>&1
systemctl enable vnstat >/dev/null 2>&1 || true
systemctl start vnstat >/dev/null 2>&1 || true
echo "        ✓ sudo, curl, jq, ipset, iptables-persistent, rsyslog, fail2ban"
echo "        ✓ tmux, screen, iftop, nethogs, vnstat, btop (monitor)"
echo "        ✓ nmap, tree, htop, sysstat, iotop, rclone, mmdb-bin (tools)"

# Configure sudo NOPASSWD for main user (uid 1000)
echo "  [2/16] Configuring sudo..."
MAIN_USER=$(getent passwd 1000 2>/dev/null | cut -d: -f1)
if [ -n "$MAIN_USER" ]; then
    # Check if already configured
    if [ -f "/etc/sudoers.d/99-charizard-user" ]; then
        echo "        ✓ sudoers already configured"
    elif grep -q "^$MAIN_USER.*NOPASSWD" /etc/sudoers.d/* 2>/dev/null; then
        echo "        ✓ $MAIN_USER already has NOPASSWD (cloud-init)"
    else
        echo "$MAIN_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-charizard-user
        chmod 440 /etc/sudoers.d/99-charizard-user
        echo "        ✓ $MAIN_USER added to sudoers (NOPASSWD)"
    fi
    # Ensure user is in sudo group
    usermod -aG sudo "$MAIN_USER" 2>/dev/null || true
else
    echo "        ! No user with uid 1000 found (skipped)"
fi

# Create directories
echo "  [3/16] Creating directories..."
mkdir -p /etc/firewall/monitor
mkdir -p /etc/firewall/geo
mkdir -p /etc/firewall/scripts
echo "        ✓ /etc/firewall"
echo "        ✓ /etc/firewall/monitor"
echo "        ✓ /etc/firewall/geo"
echo "        ✓ /etc/firewall/scripts"

# Copy files
echo "  [4/16] Copying files..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cp "$SCRIPT_DIR/firewall.sh" /etc/firewall/
cp "$SCRIPT_DIR/VERSION" /etc/firewall/ 2>/dev/null || echo "1.0.0" > /etc/firewall/VERSION
chmod +x /etc/firewall/firewall.sh
# Monitor scripts
cp "$SCRIPT_DIR/monitor/cmon.sh" /etc/firewall/monitor/
cp "$SCRIPT_DIR/monitor/stats.sh" /etc/firewall/monitor/
chmod +x /etc/firewall/monitor/cmon.sh
chmod +x /etc/firewall/monitor/stats.sh
# Telegram bot (optional)
if [ -f "$SCRIPT_DIR/modules/telegram.sh" ]; then
    cp "$SCRIPT_DIR/modules/telegram.sh" /etc/firewall/
    chmod +x /etc/firewall/telegram.sh
fi
# Notify module
if [ -f "$SCRIPT_DIR/modules/notify.sh" ]; then
    cp "$SCRIPT_DIR/modules/notify.sh" /etc/firewall/
    chmod +x /etc/firewall/notify.sh
fi
# GeoIP database
if [ -f "$SCRIPT_DIR/modules/GeoLite2-Country.mmdb" ]; then
    cp "$SCRIPT_DIR/modules/GeoLite2-Country.mmdb" /etc/firewall/geo/
    echo "        ✓ GeoLite2-Country.mmdb (GeoIP)"
fi
# SSH notify PAM hook
if [ -f "$SCRIPT_DIR/scripts/ssh-notify.sh" ]; then
    cp "$SCRIPT_DIR/scripts/ssh-notify.sh" /etc/firewall/scripts/
    chmod +x /etc/firewall/scripts/ssh-notify.sh
    echo "        ✓ ssh-notify.sh (PAM hook)"
fi
# Notify config (copy example if not exists)
if [ ! -f /etc/firewall/notify.json ]; then
    if [ -f "$SCRIPT_DIR/examples/notify.example.json" ]; then
        cp "$SCRIPT_DIR/examples/notify.example.json" /etc/firewall/notify.json
        echo "        ✓ notify.json created from example"
    fi
fi
# Modules directory (telegram.sh needs to be in modules/)
mkdir -p /etc/firewall/modules
if [ -f "$SCRIPT_DIR/modules/telegram.sh" ]; then
    cp "$SCRIPT_DIR/modules/telegram.sh" /etc/firewall/modules/
    chmod +x /etc/firewall/modules/telegram.sh
fi
echo "        ✓ firewall.sh"
echo "        ✓ monitor/cmon.sh, stats.sh"
echo "        ✓ telegram.sh, notify.sh (modules)"

# Whitelist: create or update with SSH IP
if [ -f /etc/firewall/whitelist.json ]; then
    echo "        ✓ whitelist.json exists (kept)"
    # Add SSH IP if not already present
    if [ -n "$SSH_IP" ]; then
        if ! jq -e ".hosts | index(\"$SSH_IP\")" /etc/firewall/whitelist.json >/dev/null 2>&1; then
            jq ".hosts += [\"$SSH_IP\"]" /etc/firewall/whitelist.json > /tmp/whitelist.tmp && mv /tmp/whitelist.tmp /etc/firewall/whitelist.json
            echo "        ✓ SSH IP $SSH_IP added to whitelist"
        fi
    fi
else
    # Create new whitelist (with SSH IP if detected, empty otherwise)
    if [ -n "$SSH_IP" ]; then
        echo "{\"hosts\":[\"$SSH_IP\"]}" | jq '.' > /etc/firewall/whitelist.json
        echo "        ✓ whitelist.json created with SSH IP: $SSH_IP"
    else
        echo '{"hosts":[]}' | jq '.' > /etc/firewall/whitelist.json
        echo "        ✓ whitelist.json created (empty - add hosts manually)"
    fi
fi

# Openports: create with user-selected ports
PORTS_JSON=$(echo "$PORTS" | tr ',' '\n' | jq -R 'tonumber' | jq -s '.')
echo "{\"ports\":$PORTS_JSON}" | jq '.' > /etc/firewall/openports.json
echo "        ✓ openports.json created with: $PORTS"

# Rsyslog configuration
echo "  [5/16] Configuring rsyslog..."
cat > /etc/rsyslog.d/10-charizard.conf << 'EOF'
# Charizard Firewall - Separate log files (IPv4+IPv6)
:msg, contains, "CHARIZARD_" /var/log/charizard.log
:msg, contains, "CHARIZARD_" stop
:msg, contains, "CHARIZARD6_" /var/log/charizard.log
:msg, contains, "CHARIZARD6_" stop
EOF
touch /var/log/charizard.log
chmod 640 /var/log/charizard.log
systemctl restart rsyslog
echo "        ✓ /var/log/charizard.log"

# Logrotate configuration
echo "  [6/16] Configuring logrotate..."
cat > /etc/logrotate.d/charizard << 'EOF'
# Charizard Firewall - Main log
/var/log/charizard.log {
    daily
    rotate 3
    maxsize 50M
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    postrotate
        /usr/lib/rsyslog/rsyslog-rotate
    endscript
}

# Charizard Bot log
/var/log/charizard-bot.log {
    daily
    rotate 3
    maxsize 10M
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}

# Charizard S3 Backup log
/var/log/charizard-s3.log {
    weekly
    rotate 4
    maxsize 5M
    compress
    delaycompress
    missingok
    notifempty
    create 640 root root
}
EOF
echo "        ✓ charizard.log: daily, 3 rotations, 50MB max"
echo "        ✓ charizard-bot.log: daily, 3 rotations, 10MB max"
echo "        ✓ charizard-s3.log: weekly, 4 rotations, 5MB max"

# Systemd timer (replaces cron for Debian 13+ compatibility)
echo "  [7/16] Configuring systemd timers..."
cat > /etc/systemd/system/charizard-update.service << 'EOF'
[Unit]
Description=Charizard Firewall - Update whitelist DNS
Documentation=https://github.com/sanvilscript/charizard
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/firewall/firewall.sh update
StandardOutput=null
StandardError=journal
NoNewPrivileges=no
ProtectSystem=full
PrivateTmp=true
EOF

cat > /etc/systemd/system/charizard-update.timer << 'EOF'
[Unit]
Description=Charizard Firewall - Whitelist update timer (every 5 min)
Documentation=https://github.com/sanvilscript/charizard

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min
RandomizedDelaySec=30
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "        ✓ Whitelist update every 5 min"

# Cache cleanup timer (daily at midnight)
cat > /etc/systemd/system/charizard-cache.service << 'EOF'
[Unit]
Description=Charizard Firewall - Clear system cache
Documentation=https://github.com/sanvilscript/charizard

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'sync && echo 3 > /proc/sys/vm/drop_caches'
EOF

cat > /etc/systemd/system/charizard-cache.timer << 'EOF'
[Unit]
Description=Charizard Firewall - Daily cache cleanup (midnight)
Documentation=https://github.com/sanvilscript/charizard

[Timer]
OnCalendar=*-*-* 00:00:00
RandomizedDelaySec=60
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "        ✓ Cache cleanup daily at midnight"

# Spamhaus DROP timer (every 6 hours)
cat > /etc/systemd/system/charizard-spamhaus.service << 'EOF'
[Unit]
Description=Charizard Firewall - Update Spamhaus DROP list
Documentation=https://github.com/sanvilscript/charizard
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/etc/firewall/firewall.sh spamhaus update
StandardOutput=null
StandardError=journal
EOF

cat > /etc/systemd/system/charizard-spamhaus.timer << 'EOF'
[Unit]
Description=Charizard Firewall - Spamhaus DROP update (every 6h)
Documentation=https://github.com/sanvilscript/charizard

[Timer]
OnBootSec=5min
OnUnitActiveSec=6h
RandomizedDelaySec=5min
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "        ✓ Spamhaus DROP update every 6 hours"

systemctl daemon-reload
systemctl enable --now charizard-update.timer >/dev/null 2>&1
systemctl enable --now charizard-cache.timer >/dev/null 2>&1
systemctl enable --now charizard-spamhaus.timer >/dev/null 2>&1
# Remove legacy cron if exists
rm -f /etc/cron.d/charizard 2>/dev/null || true

# Systemd service for boot persistence
echo "  [8/16] Configuring boot service..."
cat > /etc/systemd/system/charizard.service << 'EOF'
[Unit]
Description=Charizard Firewall - Apply iptables rules
Documentation=https://github.com/sanvilscript/charizard
After=network-online.target
Wants=network-online.target
Before=sshd.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/etc/firewall/firewall.sh apply
ExecReload=/etc/firewall/firewall.sh reload
ExecStop=/etc/firewall/firewall.sh flush

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable charizard.service >/dev/null 2>&1
echo "        ✓ charizard.service (boot persistence)"

# Copy optional service files (telegram, s3 backup, notify) - not enabled by default
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/systemd" ]; then
    cp "$SCRIPT_DIR/systemd/charizard-bot.service" /etc/systemd/system/ 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/charizard-report.service" /etc/systemd/system/ 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/charizard-report.timer" /etc/systemd/system/ 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/charizard-s3-backup.service" /etc/systemd/system/ 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/charizard-s3-backup.timer" /etc/systemd/system/ 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/charizard-notify.service" /etc/systemd/system/ 2>/dev/null || true
    cp "$SCRIPT_DIR/systemd/charizard-notify.timer" /etc/systemd/system/ 2>/dev/null || true
    systemctl daemon-reload
    # Enable notify timer by default (for spike/scan detection)
    systemctl enable --now charizard-notify.timer >/dev/null 2>&1 || true
    echo "        ✓ optional services (telegram, s3, notify) installed"
    echo "        ✓ notify timer enabled (spike/scan detection)"
fi

# Sysctl kernel hardening
echo "  [9/16] Applying kernel hardening..."
cat > /etc/sysctl.d/99-charizard.conf << 'EOF'
# ══════════════════════════════════════════════════════════════════════════════
# CHARIZARD FIREWALL - Kernel Hardening
# ══════════════════════════════════════════════════════════════════════════════

# =================================
# NETWORK SECURITY
# =================================

# SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Block source routing (MITM)
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Block ICMP redirects (routing attacks)
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# Don't send ICMP redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# IP spoofing protection (reverse path)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# Log martian packets
net.ipv4.conf.all.log_martians = 1

# Ignore ICMP broadcast (smurf attack)
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Ignore bogus ICMP errors
net.ipv4.icmp_ignore_bogus_error_responses = 1

# TCP time-wait assassination protection
net.ipv4.tcp_rfc1337 = 1

# =================================
# SYSTEM SECURITY
# =================================

# ASLR max level
kernel.randomize_va_space = 2

# Restrict dmesg
kernel.dmesg_restrict = 1

# Hide kernel pointers
kernel.kptr_restrict = 2

# Restrict perf_event
kernel.perf_event_paranoid = 3

# Hardlink/symlink protection
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Disable core dumps
kernel.core_uses_pid = 1
fs.suid_dumpable = 0

# Restrict ptrace
kernel.yama.ptrace_scope = 1

# =================================
# NETWORK PERFORMANCE
# =================================

# SYN queue for burst connections
net.ipv4.tcp_max_syn_backlog = 4096

# Packet input queue
net.core.netdev_max_backlog = 5000

# Faster connection close
net.ipv4.tcp_fin_timeout = 30

# Larger socket buffers
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216

# TCP buffer auto-tuning (min, default, max)
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216

# TCP window scaling
net.ipv4.tcp_window_scaling = 1
EOF
sysctl --system >/dev/null 2>&1
echo "        ✓ Security: SYN flood, ICMP, spoofing protection"
echo "        ✓ System: ASLR, dmesg/ptrace restrictions"
echo "        ✓ Performance: TCP buffers, connection handling"

# Bash aliases
echo "  [10/16] Installing bash aliases..."
BASH_ALIASES_FILE="/etc/profile.d/charizard-aliases.sh"
cat > "$BASH_ALIASES_FILE" << 'EOF'
# ══════════════════════════════════════════════════════════════════════════════
# CHARIZARD - Bash Aliases
# ══════════════════════════════════════════════════════════════════════════════

# File System
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias lt='ls -alFtr'
alias lh='ls -alFh'
alias lsa='ls -al'

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'

# Git (base)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline -20'

# System Info
alias c='clear'
alias h='history'
alias j='jobs -l'
alias ports='ss -tulpn'
alias listen='ss -tulpn | grep LISTEN'
alias meminfo='free -h'
alias diskinfo='df -h'
alias cpuinfo='lscpu | head -20'
alias topcpu='ps aux --sort=-%cpu | head -11'
alias topmem='ps aux --sort=-%mem | head -11'
alias myip='curl -s ifconfig.me && echo'
alias psm='ps aux | more'

# Colors
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

# Network/Security
alias nmaps='sudo nmap -PN -sS -f -vv -n -T4 --max-rtt-timeout 15'
alias whois='whois -H'
alias wget='wget -c'

# Search
alias cerca='find / -name'
alias big='find . -size +100M'
alias tlsa='tree -L 2'

# Shortcuts
alias v='vim'
alias vi='vim'
alias reload='source ~/.bashrc'
alias path='echo -e ${PATH//:/\\n}'
alias now='date +"%Y-%m-%d %H:%M:%S"'

# System
alias drop3='sudo sync && sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"'
EOF
chmod 644 "$BASH_ALIASES_FILE"
echo "        ✓ /etc/profile.d/charizard-aliases.sh"

# Bash prompt (powerline style)
echo "  [11/16] Installing bash prompt..."
cat > /etc/profile.d/charizard-prompt.sh << 'EOFPROMPT'
# ══════════════════════════════════════════════════════════════════════════════
# CHARIZARD - Bash Prompt (Powerline Style)
# ══════════════════════════════════════════════════════════════════════════════

__prompt_reset='\[\e[0m\]'
__prompt_green='\[\e[32m\]'
__prompt_blue='\[\e[34m\]'
__prompt_magenta='\[\e[35m\]'
__prompt_cyan='\[\e[36m\]'
__prompt_red='\[\e[31m\]'
__prompt_gray='\[\e[90m\]'
__prompt_white='\[\e[97m\]'

__git_branch() {
    local branch
    branch=$(git symbolic-ref --short HEAD 2>/dev/null || git describe --tags --exact-match 2>/dev/null)
    if [[ -n "$branch" ]]; then
        local status=""
        [[ -n $(git status --porcelain 2>/dev/null) ]] && status="*"
        echo "─[${branch}${status}]"
    fi
}

__build_prompt() {
    local exit_code=$?
    local prompt=""
    prompt+="\n${__prompt_gray}┌─${__prompt_reset}"
    prompt+="${__prompt_gray}[${__prompt_green}\u${__prompt_gray}@${__prompt_cyan}\h${__prompt_gray}]${__prompt_reset}"
    prompt+="${__prompt_gray}─[${__prompt_blue}\w${__prompt_gray}]${__prompt_reset}"
    prompt+="${__prompt_magenta}\$(__git_branch)${__prompt_reset}"
    prompt+="${__prompt_gray}─[${__prompt_white}\t${__prompt_gray}]${__prompt_reset}"
    prompt+="\n${__prompt_gray}└─${__prompt_reset}"
    if [[ $exit_code -ne 0 ]]; then
        prompt+="${__prompt_red}✗ ${exit_code} ❯${__prompt_reset} "
    else
        prompt+="${__prompt_green}❯${__prompt_reset} "
    fi
    PS1="$prompt"
}

# Only set prompt for interactive shells
[[ $- == *i* ]] && PROMPT_COMMAND=__build_prompt
EOFPROMPT
chmod 644 /etc/profile.d/charizard-prompt.sh
echo "        ✓ /etc/profile.d/charizard-prompt.sh"

# Bashrc enhancements
echo "  [12/16] Installing bashrc enhancements..."
cat > /etc/profile.d/charizard-bashrc.sh << 'EOFBASHRC'
# ══════════════════════════════════════════════════════════════════════════════
# CHARIZARD - Bashrc Enhancements
# ══════════════════════════════════════════════════════════════════════════════

# Only for interactive shells
[[ $- != *i* ]] && return

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
HISTTIMEFORMAT="%Y-%m-%d %H:%M:%S  "
shopt -s histappend

# Shell options
shopt -s autocd 2>/dev/null
shopt -s cdspell 2>/dev/null
shopt -s dirspell 2>/dev/null
shopt -s checkwinsize
shopt -s globstar 2>/dev/null
shopt -s nocaseglob

# Autocomplete enhancements
bind 'set show-all-if-ambiguous on' 2>/dev/null
bind 'set completion-ignore-case on' 2>/dev/null
bind 'set colored-stats on' 2>/dev/null
bind 'set visible-stats on' 2>/dev/null
bind 'set mark-symlinked-directories on' 2>/dev/null
bind '"\e[A": history-search-backward' 2>/dev/null
bind '"\e[B": history-search-forward' 2>/dev/null

# Editor
export EDITOR=vim
export VISUAL=vim

# Less colors
export LESS='-R'
export LESS_TERMCAP_mb=$'\e[1;31m'
export LESS_TERMCAP_md=$'\e[1;36m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[1;44;33m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;32m'
export LESS_TERMCAP_ue=$'\e[0m'

# Man colors
export MANPAGER="less -R --use-color -Dd+r -Du+b"
EOFBASHRC
chmod 644 /etc/profile.d/charizard-bashrc.sh
echo "        ✓ /etc/profile.d/charizard-bashrc.sh"

# Vimrc
echo "  [13/16] Installing vimrc..."
cat > /etc/vim/vimrc.local << 'EOFVIM'
" ══════════════════════════════════════════════════════════════════════════════
" CHARIZARD - Vim Configuration
" ══════════════════════════════════════════════════════════════════════════════

" Basic
set nocompatible
syntax on
set encoding=utf-8
set fileencoding=utf-8

" Display
set number
set relativenumber
set showmatch
set showcmd
set laststatus=2
set ruler
set title

" Search
set hlsearch
set incsearch
set ignorecase
set smartcase

" Indentation
set autoindent
set smartindent
set expandtab
set tabstop=4
set shiftwidth=4
set softtabstop=4

" Behavior
set mouse=a
set backspace=indent,eol,start
set scrolloff=5
set wildmenu
set wildmode=longest:full,full

" Files
set nobackup
set nowritebackup
set noswapfile
set autoread
set hidden

" Status line
set statusline=%f\ %m%r%h%w%=%y\ [%{&ff}]\ %l:%c\ %p%%

" Key mappings
nnoremap <Esc> :nohlsearch<CR>
nnoremap <C-s> :w<CR>
inoremap <C-s> <Esc>:w<CR>a
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l

" Filetype
filetype plugin indent on
autocmd FileType yaml setlocal ts=2 sw=2 sts=2
autocmd FileType make setlocal noexpandtab
autocmd FileType python setlocal ts=4 sw=4 sts=4
EOFVIM
chmod 644 /etc/vim/vimrc.local
echo "        ✓ /etc/vim/vimrc.local"

# Screenrc
echo "  [14/16] Installing screenrc..."
cat > /etc/screenrc << 'EOFSCREEN'
# ══════════════════════════════════════════════════════════════════════════════
# CHARIZARD - Screen Configuration
# ══════════════════════════════════════════════════════════════════════════════

# Terminal settings
term screen-256color
defutf8 on
altscreen on
termcapinfo xterm* ti@:te@

# Session behavior
autodetach on
startup_message off
defscrollback 10000

# Mouse disabled (cleaner copy/paste)
mousetrack off
defmousetrack off

# Window resize on reattach
fit

# Status bar (hostname | windows | date/time)
hardstatus alwayslastline
hardstatus string '%{= kw}[ %{c}%H %{w}][ %{y}%l %{w}][ %{g}%-Lw%{c}%n%f %t%{g}%+Lw %{w}]%=%{w}[ %{m}%d/%m %{w}%c ]'

# Visual bell instead of audible
vbell on
vbell_msg " Bell! "

# Faster command sequence detection
maptimeout 5

# Default shell
shell -$SHELL

# Caption for split windows
caption always "%{= kw}%?%-Lw%?%{kc}[%n %t]%{kw}%?%+Lw%?"

# Key bindings
bind ' ' windowlist -b
bind x remove
bind X kill
bind r source /etc/screenrc

# Split navigation (Ctrl-a + arrows)
bindkey "^A^[OA" focus up
bindkey "^A^[OB" focus down
bindkey "^A^[OC" focus right
bindkey "^A^[OD" focus left
EOFSCREEN
chmod 644 /etc/screenrc
echo "        ✓ /etc/screenrc (256 colors, mouse, 10k scrollback)"

# Fail2ban configuration
echo "  [15/16] Configuring fail2ban..."
cat > /etc/fail2ban/action.d/charizard.conf << 'EOFF2BACTION'
# Fail2Ban action for Charizard Firewall
# Uses separate ipset 'fail2ban' with iptables integration
# Author: Sanvil

[INCLUDES]
before = iptables.conf

[Definition]

actionstart = ipset -exist create fail2ban hash:ip timeout 3600
              iptables -I INPUT 1 -m set --match-set fail2ban src -j DROP

actionflush = ipset flush fail2ban

actionstop = iptables -D INPUT -m set --match-set fail2ban src -j DROP 2>/dev/null || true
             <actionflush>
             ipset destroy fail2ban 2>/dev/null || true

actionban = ipset -exist add fail2ban <ip> timeout 3600

actionunban = ipset -exist del fail2ban <ip>

[Init]
EOFF2BACTION

cat > /etc/fail2ban/jail.local << 'EOFF2BJAIL'
# ══════════════════════════════════════════════════════════════════════════════
# CHARIZARD FIREWALL - Fail2ban Configuration
# ══════════════════════════════════════════════════════════════════════════════

[DEFAULT]
# Ban policy: Soft
bantime = 1h
findtime = 10m
maxretry = 5

# Whitelist
ignoreip = 127.0.0.1/8 ::1

# Use systemd backend
backend = systemd

# Use Charizard action (separate ipset)
banaction = charizard
banaction_allports = charizard

# ══════════════════════════════════════════════════════════════════════════════
# JAILS
# ══════════════════════════════════════════════════════════════════════════════

[sshd]
enabled = true
port = ssh
filter = sshd
backend = systemd
maxretry = 5
bantime = 1h
findtime = 10m
EOFF2BJAIL

systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban >/dev/null 2>&1
echo "        ✓ /etc/fail2ban/action.d/charizard.conf"
echo "        ✓ /etc/fail2ban/jail.local (soft policy: 5 attempts, 1h ban)"

# SSH login notification PAM hook
if [ -f /etc/firewall/scripts/ssh-notify.sh ]; then
    if ! grep -q "charizard" /etc/pam.d/sshd 2>/dev/null; then
        echo "" >> /etc/pam.d/sshd
        echo "# Charizard SSH notification" >> /etc/pam.d/sshd
        echo "session optional pam_exec.so seteuid /etc/firewall/scripts/ssh-notify.sh" >> /etc/pam.d/sshd
        echo "        ✓ PAM hook for SSH notifications"
    else
        echo "        ✓ PAM hook already configured"
    fi
fi

# Symlinks
echo "  [16/16] Creating symlinks..."
ln -sf /etc/firewall/firewall.sh /usr/local/bin/charizard
ln -sf /etc/firewall/monitor/cmon.sh /usr/local/bin/cmon
echo "        ✓ /usr/local/bin/charizard"
echo "        ✓ /usr/local/bin/cmon"

# Bash completion
if [ -d /etc/bash_completion.d ]; then
    cp "$SCRIPT_DIR/scripts/charizard-completion.bash" /etc/bash_completion.d/charizard
    echo "        ✓ Bash completion installed"
fi

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ ACTIVATION                                                      │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

# Apply firewall
/etc/firewall/firewall.sh apply

# ══════════════════════════════════════════════════════════════════════════════
# EXTRA MODULES
# ══════════════════════════════════════════════════════════════════════════════

echo ""
echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ EXTRA MODULES                                                   │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""

INSTALL_DOCKER=false
INSTALL_PORTAINER=false
INSTALL_DNS=false

# Ask about Docker
echo -n "  Install Docker Engine? [y/N]: "
read -r REPLY
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    INSTALL_DOCKER=true
fi

# Check if Docker is available (installed now or previously)
if [ "$INSTALL_DOCKER" = true ] || command -v docker &>/dev/null; then
    DOCKER_AVAILABLE=true

    # Ask about Portainer
    echo -n "  Install Portainer CE? (Docker web UI) [y/N]: "
    read -r REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        INSTALL_PORTAINER=true
    fi

    # Ask about DNS
    echo -n "  Install DNS Module? (Unbound resolver) [y/N]: "
    read -r REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        INSTALL_DNS=true
    fi
else
    DOCKER_AVAILABLE=false
    echo -e "  ${DIM}Portainer and DNS require Docker - skipped${NC}"
fi

echo ""

# Install selected extras
if [ "$INSTALL_DOCKER" = true ]; then
    echo "  [*] Installing Docker Engine..."
    DOCKER_SCRIPT="$SCRIPT_DIR/extra/docker-install.sh"
    if [ -f "$DOCKER_SCRIPT" ]; then
        bash "$DOCKER_SCRIPT" install
    else
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/docker-install.sh" | bash -s install
    fi
    echo ""
fi

if [ "$INSTALL_PORTAINER" = true ]; then
    echo "  [*] Installing Portainer CE..."
    if [ -f "$SCRIPT_DIR/extra/portainer/install.sh" ]; then
        bash "$SCRIPT_DIR/extra/portainer/install.sh" install
    else
        PORTAINER_TMP="/tmp/charizard-portainer-install"
        mkdir -p "$PORTAINER_TMP"
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/portainer/install.sh" -o "$PORTAINER_TMP/install.sh"
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/portainer/docker-compose.yml" -o "$PORTAINER_TMP/docker-compose.yml"
        chmod +x "$PORTAINER_TMP/install.sh"
        bash "$PORTAINER_TMP/install.sh" install
        rm -rf "$PORTAINER_TMP"
    fi
    echo ""
fi

if [ "$INSTALL_DNS" = true ]; then
    echo "  [*] Installing DNS Module..."
    if [ -f "$SCRIPT_DIR/extra/dns/install.sh" ]; then
        bash "$SCRIPT_DIR/extra/dns/install.sh" install
    else
        DNS_TMP="/tmp/charizard-dns-install"
        mkdir -p "$DNS_TMP"
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/install.sh" -o "$DNS_TMP/install.sh"
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/Dockerfile" -o "$DNS_TMP/Dockerfile"
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/docker-compose.yml" -o "$DNS_TMP/docker-compose.yml"
        mkdir -p "$DNS_TMP/config"
        curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/config/unbound.conf" -o "$DNS_TMP/config/unbound.conf"
        chmod +x "$DNS_TMP/install.sh"
        bash "$DNS_TMP/install.sh" install
        rm -rf "$DNS_TMP"
    fi
    echo ""
fi

# Summary of extras
if [ "$INSTALL_DOCKER" = false ] && [ "$INSTALL_PORTAINER" = false ] && [ "$INSTALL_DNS" = false ]; then
    echo "  No extras installed. You can install later with:"
    echo "    charizard install docker"
    echo "    charizard install portainer"
    echo "    charizard install dns"
    echo ""
fi

echo "  ┌─────────────────────────────────────────────────────────────────┐"
echo "  │ INSTALLATION COMPLETE                                           │"
echo "  ├─────────────────────────────────────────────────────────────────┤"
echo "  │                                                                 │"
echo "  │  Firewall: charizard {apply|status|ban|watch|...}               │"
echo "  │  Monitor:  sudo cmon                                            │"
echo "  │                                                                 │"
echo "  │  Log:      /var/log/charizard.log                               │"
echo "  │  Config:   /etc/firewall/whitelist.json                         │"
echo "  │            /etc/firewall/openports.json                         │"
echo "  │                                                                 │"
echo "  └─────────────────────────────────────────────────────────────────┘"
echo ""
