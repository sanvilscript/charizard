#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD NOTIFY MODULE v1.0.1
#   Centralized notification system for alerts and monitoring
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════

CONFIG_DIR="/etc/firewall"
NOTIFY_CONFIG="$CONFIG_DIR/notify.json"
TELEGRAM_CONFIG="$CONFIG_DIR/telegram.json"
TELEGRAM_SCRIPT="$CONFIG_DIR/telegram.sh"
STATE_DIR="/var/lib/charizard"
STATE_FILE="$STATE_DIR/notify.state"
LOG_FILE="/var/log/charizard.log"

# Ensure state directory exists
mkdir -p "$STATE_DIR" 2>/dev/null

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

load_config() {
    # Check if notify.json exists, otherwise use defaults
    if [ -f "$NOTIFY_CONFIG" ]; then
        NOTIFY_ENABLED=$(jq -r '.enabled // true' "$NOTIFY_CONFIG")

        # Ban config
        ALERT_BAN=$(jq -r '.alerts.ban.enabled // true' "$NOTIFY_CONFIG")
        BAN_COOLDOWN=$(jq -r '.alerts.ban.cooldown_minutes // 0' "$NOTIFY_CONFIG")

        # Spike config
        ALERT_SPIKE=$(jq -r '.alerts.spike.enabled // true' "$NOTIFY_CONFIG")
        SPIKE_THRESHOLD=$(jq -r '.alerts.spike.threshold // 100' "$NOTIFY_CONFIG")
        SPIKE_PERIOD=$(jq -r '.alerts.spike.period_minutes // 5' "$NOTIFY_CONFIG")
        SPIKE_COOLDOWN=$(jq -r '.alerts.spike.cooldown_minutes // 30' "$NOTIFY_CONFIG")

        # Scan config
        ALERT_SCAN=$(jq -r '.alerts.scan.enabled // true' "$NOTIFY_CONFIG")
        SCAN_MODE=$(jq -r '.alerts.scan.mode // "separate"' "$NOTIFY_CONFIG")
        SCAN_COOLDOWN=$(jq -r '.alerts.scan.cooldown_minutes // 30' "$NOTIFY_CONFIG")

        # F2B config
        ALERT_F2B=$(jq -r '.alerts.f2b.enabled // false' "$NOTIFY_CONFIG")
        F2B_MODE=$(jq -r '.alerts.f2b.mode // "summary"' "$NOTIFY_CONFIG")

        # Backup config
        BACKUP_SUCCESS=$(jq -r '.alerts.backup.success // true' "$NOTIFY_CONFIG")
        BACKUP_FAILURE=$(jq -r '.alerts.backup.failure // true' "$NOTIFY_CONFIG")

        # System config
        ALERT_SYSTEM=$(jq -r '.alerts.system.enabled // true' "$NOTIFY_CONFIG")
        DISK_THRESHOLD=$(jq -r '.alerts.system.disk_threshold // 80' "$NOTIFY_CONFIG")
        MEMORY_THRESHOLD=$(jq -r '.alerts.system.memory_threshold // 85' "$NOTIFY_CONFIG")
        CPU_THRESHOLD=$(jq -r '.alerts.system.cpu_threshold // 4.0' "$NOTIFY_CONFIG")
        SYSTEM_SERVICES=$(jq -r '.alerts.system.services // ["docker","ssh","fail2ban"] | join(" ")' "$NOTIFY_CONFIG")
        SYSTEM_COOLDOWN=$(jq -r '.alerts.system.cooldown_minutes // 30' "$NOTIFY_CONFIG")
    else
        # Defaults
        NOTIFY_ENABLED="true"
        ALERT_BAN="true"
        BAN_COOLDOWN=0
        ALERT_SPIKE="true"
        SPIKE_THRESHOLD=100
        SPIKE_PERIOD=5
        SPIKE_COOLDOWN=30
        ALERT_SCAN="true"
        SCAN_MODE="separate"
        SCAN_COOLDOWN=30
        ALERT_F2B="false"
        F2B_MODE="summary"
        BACKUP_SUCCESS="true"
        BACKUP_FAILURE="true"
        ALERT_SYSTEM="true"
        DISK_THRESHOLD=80
        MEMORY_THRESHOLD=85
        CPU_THRESHOLD=4.0
        SYSTEM_SERVICES="docker ssh fail2ban"
        SYSTEM_COOLDOWN=30
    fi

    # Check if Telegram is available
    if [ -f "$TELEGRAM_CONFIG" ] && [ -x "$TELEGRAM_SCRIPT" ]; then
        TELEGRAM_AVAILABLE="true"
    else
        TELEGRAM_AVAILABLE="false"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# STATE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

get_state() {
    local key="$1"
    local default="${2:-0}"
    if [ -f "$STATE_FILE" ]; then
        local val=$(grep "^${key}=" "$STATE_FILE" 2>/dev/null | tail -1 | cut -d= -f2)
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

set_state() {
    local key="$1"
    local value="$2"

    touch "$STATE_FILE"
    if grep -q "^${key}=" "$STATE_FILE" 2>/dev/null; then
        sed -i "s/^${key}=.*/${key}=${value}/" "$STATE_FILE"
    else
        echo "${key}=${value}" >> "$STATE_FILE"
    fi
}

check_cooldown() {
    local key="$1"
    local cooldown_min="$2"
    local now=$(date +%s)
    local last=$(get_state "$key" "0")
    local cooldown_sec=$((cooldown_min * 60))

    if [ $((now - last)) -ge $cooldown_sec ]; then
        return 0  # Can send
    else
        return 1  # In cooldown
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# TELEGRAM WRAPPER
# ══════════════════════════════════════════════════════════════════════════════

send_telegram() {
    local type="$1"
    shift

    if [ "$TELEGRAM_AVAILABLE" != "true" ]; then
        return 1
    fi

    case "$type" in
        ban)
            "$TELEGRAM_SCRIPT" ban-alert "$@" &>/dev/null &
            ;;
        spike)
            "$TELEGRAM_SCRIPT" spike-alert "$@" &>/dev/null &
            ;;
        scan)
            "$TELEGRAM_SCRIPT" scan-alert "$@" &>/dev/null &
            ;;
        *)
            "$TELEGRAM_SCRIPT" alert "$type" "$@" &>/dev/null &
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# BAN ALERT
# ══════════════════════════════════════════════════════════════════════════════

alert_ban() {
    local ip="$1"
    local reason="${2:-Manual ban}"
    local hits="${3:-0}"

    load_config
    [ "$NOTIFY_ENABLED" != "true" ] && return
    [ "$ALERT_BAN" != "true" ] && return

    # Check cooldown (per-IP)
    local cooldown_key="ban_${ip//[.:]/_}"
    if [ "$BAN_COOLDOWN" -gt 0 ]; then
        if ! check_cooldown "$cooldown_key" "$BAN_COOLDOWN"; then
            return
        fi
    fi

    send_telegram ban "$ip" "$reason" "$hits"
    set_state "$cooldown_key" "$(date +%s)"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] BAN ALERT: $ip ($reason, $hits hits)"
}

# ══════════════════════════════════════════════════════════════════════════════
# SPIKE DETECTION
# ══════════════════════════════════════════════════════════════════════════════

check_spike() {
    load_config
    [ "$NOTIFY_ENABLED" != "true" ] && return
    [ "$ALERT_SPIKE" != "true" ] && return

    local now=$(date +%s)

    # Get current iptables drop counter
    local current_drops=$(iptables -L INPUT -nvx 2>/dev/null | awk '/DROP/ {sum+=$1} END {print sum+0}')
    local last_drops=$(get_state "last_drops" "0")
    local last_check=$(get_state "last_spike_check" "0")

    # Calculate delta
    local delta=$((current_drops - last_drops))

    # Only check if enough time passed
    local period_sec=$((SPIKE_PERIOD * 60))
    if [ $((now - last_check)) -ge $period_sec ] && [ "$delta" -gt "$SPIKE_THRESHOLD" ]; then
        # Check cooldown
        if check_cooldown "last_spike_alert" "$SPIKE_COOLDOWN"; then
            send_telegram spike "$delta" "${SPIKE_PERIOD}min"
            set_state "last_spike_alert" "$now"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SPIKE ALERT: $delta drops in ${SPIKE_PERIOD}min (threshold: $SPIKE_THRESHOLD)"
        fi
    fi

    # Update state
    set_state "last_drops" "$current_drops"
    set_state "last_spike_check" "$now"
}

# ══════════════════════════════════════════════════════════════════════════════
# SCAN DETECTION
# ══════════════════════════════════════════════════════════════════════════════

check_scans() {
    load_config
    [ "$NOTIFY_ENABLED" != "true" ] && return
    [ "$ALERT_SCAN" != "true" ] && return
    [ ! -f "$LOG_FILE" ] && return

    local now=$(date +%s)

    # Get recent scan entries (last 5 minutes)
    local recent_logs=$(tail -1000 "$LOG_FILE" 2>/dev/null | grep -E 'CHARIZARD6?_SCAN')

    if [ "$SCAN_MODE" = "separate" ]; then
        # Separate alerts per scan type
        for scan_type in NULL XMAS FIN FLAG; do
            local scan_ips=$(echo "$recent_logs" | grep "$scan_type" | grep -oE 'SRC=[0-9a-fA-F:.]+' | cut -d= -f2 | sort -u)

            for ip in $scan_ips; do
                local cooldown_key="scan_${scan_type}_${ip//[.:]/_}"
                if check_cooldown "$cooldown_key" "$SCAN_COOLDOWN"; then
                    send_telegram scan "$ip" "${scan_type} scan"
                    set_state "$cooldown_key" "$now"
                    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SCAN ALERT: $scan_type from $ip"
                fi
            done
        done
    else
        # Grouped alert
        local scan_ips=$(echo "$recent_logs" | grep -oE 'SRC=[0-9a-fA-F:.]+' | cut -d= -f2 | sort -u | head -5)

        for ip in $scan_ips; do
            local cooldown_key="scan_${ip//[.:]/_}"
            if check_cooldown "$cooldown_key" "$SCAN_COOLDOWN"; then
                send_telegram scan "$ip" "Port scan"
                set_state "$cooldown_key" "$now"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] SCAN ALERT: Port scan from $ip"
            fi
        done
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# SYSTEM ALERTS (Disk, Memory, CPU, Services)
# ══════════════════════════════════════════════════════════════════════════════

check_system() {
    load_config
    [ "$NOTIFY_ENABLED" != "true" ] && return
    [ "$ALERT_SYSTEM" != "true" ] && return

    local now=$(date +%s)

    # Check Disk Usage
    local disk_usage=$(df / | awk 'NR==2 {gsub(/%/,""); print $5}')
    if [ "$disk_usage" -ge "$DISK_THRESHOLD" ]; then
        if check_cooldown "system_disk" "$SYSTEM_COOLDOWN"; then
            local disk_info=$(df -h / | awk 'NR==2 {print "Used: "$3" / "$2" ("$5")"}')
            send_telegram system "disk" "$disk_usage" "$DISK_THRESHOLD" "$disk_info"
            set_state "system_disk" "$now"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SYSTEM ALERT: Disk usage ${disk_usage}% (threshold: ${DISK_THRESHOLD}%)"
        fi
    fi

    # Check Memory Usage
    local mem_usage=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
    if [ "$mem_usage" -ge "$MEMORY_THRESHOLD" ]; then
        if check_cooldown "system_memory" "$SYSTEM_COOLDOWN"; then
            local mem_info=$(free -h | awk '/Mem:/ {print "Used: "$3" / "$2}')
            send_telegram system "memory" "$mem_usage" "$MEMORY_THRESHOLD" "$mem_info"
            set_state "system_memory" "$now"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SYSTEM ALERT: Memory usage ${mem_usage}% (threshold: ${MEMORY_THRESHOLD}%)"
        fi
    fi

    # Check CPU Load
    local cpu_load=$(cut -d' ' -f1 /proc/loadavg)
    if awk "BEGIN {exit !($cpu_load > $CPU_THRESHOLD)}"; then
        if check_cooldown "system_cpu" "$SYSTEM_COOLDOWN"; then
            local load_info=$(cat /proc/loadavg | cut -d' ' -f1-3)
            send_telegram system "cpu" "$cpu_load" "$CPU_THRESHOLD" "Load: $load_info"
            set_state "system_cpu" "$now"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] SYSTEM ALERT: CPU load $cpu_load (threshold: $CPU_THRESHOLD)"
        fi
    fi

    # Check Services
    for svc in $SYSTEM_SERVICES; do
        if ! systemctl is-active --quiet "$svc" 2>/dev/null; then
            local cooldown_key="system_service_${svc}"
            if check_cooldown "$cooldown_key" "$SYSTEM_COOLDOWN"; then
                local svc_status=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
                send_telegram system "service" "$svc" "$svc_status"
                set_state "$cooldown_key" "$now"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] SYSTEM ALERT: Service $svc is $svc_status"
            fi
        fi
    done
}

# ══════════════════════════════════════════════════════════════════════════════
# F2B SUMMARY (for daily report)
# ══════════════════════════════════════════════════════════════════════════════

get_f2b_summary() {
    if ! command -v fail2ban-client &>/dev/null; then
        echo "N/A"
        return
    fi

    local banned=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
    local total=$(fail2ban-client status sshd 2>/dev/null | grep "Total banned" | awk '{print $NF}')
    local ipset_count=$(ipset list fail2ban 2>/dev/null | grep -c '^[0-9]' || echo "0")

    echo "Current: ${banned:-0} | Total: ${total:-0} | ipset: $ipset_count"
}

# ══════════════════════════════════════════════════════════════════════════════
# BACKUP ALERT
# ══════════════════════════════════════════════════════════════════════════════

alert_backup() {
    local status="$1"  # success or failure
    local message="$2"

    load_config
    [ "$NOTIFY_ENABLED" != "true" ] && return

    if [ "$status" = "success" ] && [ "$BACKUP_SUCCESS" = "true" ]; then
        send_telegram backup "$message"
    elif [ "$status" = "failure" ] && [ "$BACKUP_FAILURE" = "true" ]; then
        send_telegram backup "$message"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN CHECK (called by timer every 5 minutes)
# ══════════════════════════════════════════════════════════════════════════════

run_check() {
    check_spike
    check_scans
    check_system
}

# ══════════════════════════════════════════════════════════════════════════════
# STATUS
# ══════════════════════════════════════════════════════════════════════════════

show_status() {
    load_config

    echo ""
    echo "  ═══ NOTIFY MODULE STATUS ═══"
    echo ""

    if [ -f "$NOTIFY_CONFIG" ]; then
        echo -e "  Config: \033[32m$NOTIFY_CONFIG\033[0m"
    else
        echo -e "  Config: \033[33mUsing defaults (no notify.json)\033[0m"
    fi

    echo ""
    echo "  ═══ ALERTS ═══"
    printf "  %-12s %-8s %s\n" "Type" "Status" "Settings"
    echo "  ────────────────────────────────────────"
    printf "  %-12s %-8s %s\n" "Ban" "$([ "$ALERT_BAN" = "true" ] && echo "ON" || echo "OFF")" "cooldown: ${BAN_COOLDOWN}min"
    printf "  %-12s %-8s %s\n" "Spike" "$([ "$ALERT_SPIKE" = "true" ] && echo "ON" || echo "OFF")" "threshold: $SPIKE_THRESHOLD, cooldown: ${SPIKE_COOLDOWN}min"
    printf "  %-12s %-8s %s\n" "Scan" "$([ "$ALERT_SCAN" = "true" ] && echo "ON" || echo "OFF")" "mode: $SCAN_MODE, cooldown: ${SCAN_COOLDOWN}min"
    printf "  %-12s %-8s %s\n" "System" "$([ "$ALERT_SYSTEM" = "true" ] && echo "ON" || echo "OFF")" "disk:${DISK_THRESHOLD}% mem:${MEMORY_THRESHOLD}% cpu:$CPU_THRESHOLD"
    printf "  %-12s %-8s %s\n" "F2B" "$([ "$ALERT_F2B" = "true" ] && echo "ON" || echo "OFF")" "mode: $F2B_MODE"
    printf "  %-12s %-8s %s\n" "Backup" "ON" "success: $BACKUP_SUCCESS, failure: $BACKUP_FAILURE"

    echo ""
    echo "  ═══ TELEGRAM ═══"
    if [ "$TELEGRAM_AVAILABLE" = "true" ]; then
        echo -e "  Status: \033[32mAvailable\033[0m"
    else
        echo -e "  Status: \033[31mNot configured\033[0m"
    fi

    echo ""
    echo "  ═══ STATE ═══"
    if [ -f "$STATE_FILE" ]; then
        echo "  Last drops: $(get_state last_drops 0)"
        echo "  Last spike check: $(date -d @$(get_state last_spike_check 0) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'never')"
        echo "  Last spike alert: $(date -d @$(get_state last_spike_alert 0) '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'never')"
    else
        echo "  No state file (first run)"
    fi

    echo ""
    echo "  ═══ FAIL2BAN ═══"
    echo "  $(get_f2b_summary)"
    echo ""
}

# ══════════════════════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════════════════════

setup_config() {
    if [ -f "$NOTIFY_CONFIG" ]; then
        echo "  [!] Config already exists: $NOTIFY_CONFIG"
        return
    fi

    local example="/etc/firewall/notify.example.json"
    if [ ! -f "$example" ]; then
        # Create default config
        cat > "$NOTIFY_CONFIG" << 'EOF'
{
  "enabled": true,
  "alerts": {
    "ban": { "enabled": true, "cooldown_minutes": 0 },
    "spike": { "enabled": true, "threshold": 100, "period_minutes": 5, "cooldown_minutes": 30 },
    "scan": { "enabled": true, "mode": "separate", "cooldown_minutes": 30 },
    "f2b": { "enabled": false, "mode": "summary" },
    "backup": { "success": true, "failure": true }
  }
}
EOF
    else
        cp "$example" "$NOTIFY_CONFIG"
    fi
    echo "  [✓] Config created: $NOTIFY_CONFIG"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
    check)
        run_check
        ;;
    spike)
        check_spike
        ;;
    scans)
        check_scans
        ;;
    system)
        check_system
        ;;
    ban)
        alert_ban "$2" "$3" "$4"
        ;;
    backup)
        alert_backup "$2" "$3"
        ;;
    status)
        show_status
        ;;
    setup)
        setup_config
        ;;
    f2b-summary)
        get_f2b_summary
        ;;
    reset)
        rm -f "$STATE_FILE"
        echo "  [✓] State reset"
        ;;
    *)
        echo "Charizard Notify Module v1.0.1"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  check       Run all checks (spike, scans, system)"
        echo "  spike       Check for traffic spike"
        echo "  scans       Check for port scans"
        echo "  system      Check disk/memory/cpu/services"
        echo "  ban <ip>    Send ban alert"
        echo "  backup <s|f> Send backup alert"
        echo "  status      Show module status"
        echo "  setup       Create default config"
        echo "  f2b-summary Get fail2ban summary"
        echo "  reset       Reset state file"
        echo ""
        ;;
esac
