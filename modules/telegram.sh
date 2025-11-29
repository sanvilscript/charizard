#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD TELEGRAM BOT v1.0.0
#   Long polling bot for firewall control and alerts
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════

set -e

CONFIG_FILE="/etc/firewall/telegram.json"
OFFSET_FILE="/var/run/charizard-bot.offset"
POLL_TIMEOUT=30
LOG_FILE="/var/log/charizard-bot.log"

# ══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ══════════════════════════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

log_stdout() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    log "$1"
}

# ══════════════════════════════════════════════════════════════════════════════
# CONFIG
# ══════════════════════════════════════════════════════════════════════════════

load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "ERROR: Config file not found: $CONFIG_FILE"
        echo "Copy telegram.example.json to $CONFIG_FILE and configure it."
        exit 1
    fi

    BOT_TOKEN=$(jq -r '.bot_token' "$CONFIG_FILE")
    if [ "$BOT_TOKEN" = "YOUR_BOT_TOKEN_HERE" ] || [ -z "$BOT_TOKEN" ]; then
        echo "ERROR: Bot token not configured in $CONFIG_FILE"
        exit 1
    fi

    # Load authorized chat IDs into array
    mapfile -t CHAT_IDS < <(jq -r '.chat_ids[]' "$CONFIG_FILE" 2>/dev/null)
    if [ ${#CHAT_IDS[@]} -eq 0 ]; then
        echo "ERROR: No chat_ids configured in $CONFIG_FILE"
        exit 1
    fi

    COMMANDS_ENABLED=$(jq -r '.commands.enabled // true' "$CONFIG_FILE")
    ALERTS_ENABLED=$(jq -r '.alerts.enabled // true' "$CONFIG_FILE")

    API_URL="https://api.telegram.org/bot${BOT_TOKEN}"
}

# ══════════════════════════════════════════════════════════════════════════════
# TELEGRAM API
# ══════════════════════════════════════════════════════════════════════════════

send_message() {
    local chat_id="$1"
    local text="$2"
    local parse_mode="${3:-HTML}"

    curl -s -X POST "$API_URL/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$text" \
        -d "parse_mode=$parse_mode" \
        -d "disable_web_page_preview=true" > /dev/null 2>&1
}

send_to_all() {
    local text="$1"
    local parse_mode="${2:-HTML}"

    for chat_id in "${CHAT_IDS[@]}"; do
        send_message "$chat_id" "$text" "$parse_mode"
    done
}

get_updates() {
    local offset="${1:-0}"
    curl -s -X GET "$API_URL/getUpdates?offset=$offset&timeout=$POLL_TIMEOUT" 2>/dev/null
}

is_authorized() {
    local chat_id="$1"
    for authorized_id in "${CHAT_IDS[@]}"; do
        if [ "$chat_id" = "$authorized_id" ]; then
            return 0
        fi
    done
    return 1
}

# ══════════════════════════════════════════════════════════════════════════════
# COMMAND HANDLERS
# ══════════════════════════════════════════════════════════════════════════════

handle_command() {
    local chat_id="$1"
    local command="$2"
    local args="$3"

    log "Command from $chat_id: $command $args"

    case "$command" in
        /start|/help)
            send_message "$chat_id" "$(cat <<'EOF'
<b>🔥 CHARIZARD FIREWALL BOT</b>

<b>Commands:</b>
/status - Firewall status
/top [n] - Top blocked IPs
/log [n] - Recent log entries
/report - Full report
/doctor - Health check
/ban &lt;ip&gt; - Ban an IP
/unban &lt;ip&gt; - Unban an IP
/reload - Reload firewall
/help - This message
EOF
)"
            ;;

        /status)
            local status=$(charizard status 2>&1 | head -30)
            send_message "$chat_id" "<pre>$(echo "$status" | sed 's/</\&lt;/g; s/>/\&gt;/g')</pre>"
            ;;

        /top)
            local limit="${args:-10}"
            local top=$(charizard top "$limit" 2>&1)
            send_message "$chat_id" "<pre>$(echo "$top" | sed 's/</\&lt;/g; s/>/\&gt;/g')</pre>"
            ;;

        /log)
            local limit="${args:-10}"
            local logs=$(charizard log "$limit" 2>&1)
            send_message "$chat_id" "<pre>$(echo "$logs" | sed 's/</\&lt;/g; s/>/\&gt;/g')</pre>"
            ;;

        /report)
            local report=$(charizard report 2>&1)
            send_message "$chat_id" "<pre>$(echo "$report" | sed 's/</\&lt;/g; s/>/\&gt;/g')</pre>"
            ;;

        /doctor)
            local doctor=$(charizard doctor 2>&1)
            send_message "$chat_id" "<pre>$(echo "$doctor" | sed 's/</\&lt;/g; s/>/\&gt;/g')</pre>"
            ;;

        /ban)
            if [ -z "$args" ]; then
                send_message "$chat_id" "Usage: /ban &lt;ip&gt;"
            else
                local result=$(charizard ban "$args" 2>&1)
                send_message "$chat_id" "<pre>$result</pre>"
                log "Ban executed: $args"
            fi
            ;;

        /unban)
            if [ -z "$args" ]; then
                send_message "$chat_id" "Usage: /unban &lt;ip&gt;"
            else
                local result=$(charizard unban "$args" 2>&1)
                send_message "$chat_id" "<pre>$result</pre>"
                log "Unban executed: $args"
            fi
            ;;

        /reload)
            local result=$(charizard reload 2>&1 | tail -5)
            send_message "$chat_id" "<pre>$result</pre>"
            log "Reload executed"
            ;;

        *)
            send_message "$chat_id" "Unknown command. Use /help for available commands."
            ;;
    esac
}

# ══════════════════════════════════════════════════════════════════════════════
# ALERT FUNCTIONS (called externally)
# ══════════════════════════════════════════════════════════════════════════════

send_alert() {
    local alert_type="$1"
    local message="$2"

    load_config

    if [ "$ALERTS_ENABLED" != "true" ]; then
        return
    fi

    local alert_enabled=$(jq -r ".alerts.${alert_type} // true" "$CONFIG_FILE")
    if [ "$alert_enabled" != "true" ]; then
        return
    fi

    send_to_all "$message"
    log "Alert sent: $alert_type"
}

send_ban_alert() {
    local ip="$1"
    local reason="${2:-Manual ban}"
    local hits="${3:-N/A}"

    send_alert "ban" "$(cat <<EOF
<b>🚫 CHARIZARD BAN ALERT</b>

<b>IP:</b> <code>$ip</code>
<b>Reason:</b> $reason
<b>Hits:</b> $hits
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')
EOF
)"
}

send_spike_alert() {
    local count="$1"
    local period="$2"

    send_alert "spike" "$(cat <<EOF
<b>⚠️ CHARIZARD SPIKE ALERT</b>

<b>Blocked packets:</b> $count
<b>Period:</b> $period
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')

High attack rate detected!
EOF
)"
}

send_ssh_login_alert() {
    local user="$1"
    local ip="$2"
    local geo="??"

    # GeoIP lookup
    local GEO_DB="/etc/firewall/geo/GeoLite2-Country.mmdb"
    if [ -f "$GEO_DB" ] && command -v mmdblookup &>/dev/null; then
        geo=$(mmdblookup --file "$GEO_DB" --ip "$ip" country iso_code 2>/dev/null | grep -oP '"\K[^"]+' | head -1)
        geo="${geo:-??}"
    fi

    send_alert "ssh" "$(cat <<EOF
<b>🔐 SSH LOGIN</b>

<b>User:</b> <code>$user</code>
<b>IP:</b> <code>$ip</code> ($geo)
<b>Host:</b> $(hostname)
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')
EOF
)"
}

send_scan_alert() {
    local ip="$1"
    local scan_type="$2"

    send_alert "scan" "$(cat <<EOF
<b>🔍 CHARIZARD SCAN DETECTED</b>

<b>IP:</b> <code>$ip</code>
<b>Type:</b> $scan_type
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')
EOF
)"
}

send_system_alert() {
    local alert_type="$1"
    local value="$2"
    local threshold="$3"
    local extra="$4"

    case "$alert_type" in
        disk)
            send_alert "system" "$(cat <<EOF
<b>💾 DISK SPACE WARNING</b>

<b>Usage:</b> ${value}% (threshold: ${threshold}%)
<b>$extra</b>
<b>Host:</b> $(hostname)
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')
EOF
)"
            ;;
        memory)
            send_alert "system" "$(cat <<EOF
<b>🧠 MEMORY WARNING</b>

<b>Usage:</b> ${value}% (threshold: ${threshold}%)
<b>$extra</b>
<b>Host:</b> $(hostname)
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')
EOF
)"
            ;;
        cpu)
            send_alert "system" "$(cat <<EOF
<b>⚡ CPU LOAD WARNING</b>

<b>Load:</b> $value (threshold: $threshold)
<b>$extra</b>
<b>Host:</b> $(hostname)
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')
EOF
)"
            ;;
        service)
            send_alert "system" "$(cat <<EOF
<b>🔴 SERVICE DOWN</b>

<b>Service:</b> $value
<b>Status:</b> $threshold
<b>Host:</b> $(hostname)
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')

Restart: <code>sudo systemctl restart $value</code>
EOF
)"
            ;;
    esac
}

send_daily_report() {
    load_config

    local report_enabled=$(jq -r '.report.enabled // false' "$CONFIG_FILE")
    if [ "$report_enabled" != "true" ]; then
        return
    fi

    # Get JSON data for compact report
    local data=$(charizard report json 2>&1)

    local hostname=$(echo "$data" | jq -r '.hostname')
    local ip=$(echo "$data" | jq -r '.ip')
    local uptime=$(echo "$data" | jq -r '.uptime')
    local accepted=$(echo "$data" | jq -r '.traffic.accepted')
    local dropped=$(echo "$data" | jq -r '.traffic.dropped')
    local spamhaus=$(echo "$data" | jq -r '.traffic.spamhaus')
    local scans=$(echo "$data" | jq -r '.traffic.scans')
    local wl=$(echo "$data" | jq -r '.ipsets.whitelist')
    local bl=$(echo "$data" | jq -r '.ipsets.blacklist')
    local sh=$(echo "$data" | jq -r '.ipsets.spamhaus')
    local f2b_banned=$(echo "$data" | jq -r '.fail2ban.banned')
    local conn=$(echo "$data" | jq -r '.connections')

    # Top attackers (from log, compact)
    local top_attackers=$(grep -oE 'SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/charizard.log 2>/dev/null | \
        cut -d= -f2 | sort | uniq -c | sort -rn | head -3 | \
        awk '{printf "• %s (%s)\n", $2, $1}')

    send_to_all "$(cat <<EOF
<b>📊 CHARIZARD DAILY REPORT</b>

<b>🖥 Host:</b> $hostname ($ip)
<b>⏱ Uptime:</b> $uptime

<b>📈 Traffic:</b>
• Accepted: $accepted pkts
• Dropped: $dropped pkts
• Spamhaus: $spamhaus pkts
• Scans: $scans

<b>🛡 IP Sets:</b>
• WL: $wl | BL: $bl | Spam: $sh

<b>🔒 Fail2ban:</b> $f2b_banned banned
<b>🔗 Connections:</b> $conn active

<b>🎯 Top Attackers:</b>
$top_attackers

<i>Generated: $(date '+%Y-%m-%d %H:%M')</i>
EOF
)"
    log "Daily report sent"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN POLLING LOOP
# ══════════════════════════════════════════════════════════════════════════════

run_bot() {
    load_config

    log_stdout "Charizard Telegram Bot starting..."
    log_stdout "Authorized chat IDs: ${CHAT_IDS[*]}"

    # Read last offset
    local offset=0
    if [ -f "$OFFSET_FILE" ]; then
        offset=$(cat "$OFFSET_FILE")
    fi

    # Notify startup
    send_to_all "🔥 <b>Charizard Bot Online</b>

Firewall monitoring active.
Use /help for commands."

    log_stdout "Bot is running. Polling for updates..."

    while true; do
        # Get updates from Telegram
        local response=$(get_updates "$offset")

        if [ -z "$response" ]; then
            log "Empty response from Telegram API"
            sleep 5
            continue
        fi

        # Check if response is OK
        local ok=$(echo "$response" | jq -r '.ok')
        if [ "$ok" != "true" ]; then
            log "API error: $response"
            sleep 10
            continue
        fi

        # Process each update
        local updates=$(echo "$response" | jq -c '.result[]' 2>/dev/null)

        while IFS= read -r update; do
            [ -z "$update" ] && continue

            local update_id=$(echo "$update" | jq -r '.update_id')
            local chat_id=$(echo "$update" | jq -r '.message.chat.id // empty')
            local text=$(echo "$update" | jq -r '.message.text // empty')

            # Update offset
            offset=$((update_id + 1))
            echo "$offset" > "$OFFSET_FILE"

            # Skip if no message
            [ -z "$chat_id" ] || [ -z "$text" ] && continue

            # Check authorization
            if ! is_authorized "$chat_id"; then
                log "Unauthorized access attempt from chat_id: $chat_id"
                send_message "$chat_id" "⛔ Unauthorized. Your chat ID ($chat_id) is not in the allowed list."
                continue
            fi

            # Parse command
            if [[ "$text" =~ ^/ ]]; then
                local command=$(echo "$text" | awk '{print $1}')
                local args=$(echo "$text" | cut -d' ' -f2- -s)
                handle_command "$chat_id" "$command" "$args"
            fi

        done <<< "$updates"

        # Small delay to avoid hammering the API
        sleep 1
    done
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
    start|run)
        run_bot
        ;;
    alert)
        # Usage: telegram.sh alert <type> <message>
        send_alert "$2" "$3"
        ;;
    ban-alert)
        # Usage: telegram.sh ban-alert <ip> [reason] [hits]
        send_ban_alert "$2" "$3" "$4"
        ;;
    spike-alert)
        # Usage: telegram.sh spike-alert <count> <period>
        send_spike_alert "$2" "$3"
        ;;
    scan-alert)
        # Usage: telegram.sh scan-alert <ip> <type>
        send_scan_alert "$2" "$3"
        ;;
    ssh-login)
        # Usage: telegram.sh ssh-login <user> <ip>
        load_config
        send_ssh_login_alert "$2" "$3"
        ;;
    report)
        send_daily_report
        ;;
    test)
        load_config
        send_to_all "🔥 <b>Charizard Test Message</b>

Bot is configured correctly!
Chat IDs: ${CHAT_IDS[*]}"
        echo "Test message sent to configured chat IDs"
        ;;
    *)
        echo "Charizard Telegram Bot v1.0.0"
        echo ""
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start       Run the bot (long polling)"
        echo "  test        Send test message"
        echo "  report      Send daily report now"
        echo "  ban-alert   Send ban alert"
        echo "  spike-alert Send spike alert"
        echo "  scan-alert  Send scan alert"
        echo "  ssh-login   Send SSH login alert"
        echo ""
        ;;
esac
