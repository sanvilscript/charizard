#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD MONITOR - Stats Panel v1.1.0
#   Displays firewall statistics
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════

# Gruvbox Colors
ORANGE='\033[38;5;166m'
BRIGHT_ORANGE='\033[38;5;208m'
GREEN='\033[38;5;142m'
BRIGHT_GREEN='\033[38;5;106m'
RED='\033[38;5;160m'
YELLOW='\033[38;5;214m'
CYAN='\033[38;5;109m'
WHITE='\033[38;5;223m'
DIM='\033[38;5;246m'
PURPLE='\033[38;5;132m'
NC='\033[0m'

# GeoIP lookup
GEO_DB="/etc/firewall/geo/GeoLite2-Country.mmdb"
geo_lookup() {
    local ip="$1"
    if [ -f "$GEO_DB" ] && command -v mmdblookup &>/dev/null; then
        local country=$(mmdblookup --file "$GEO_DB" --ip "$ip" country iso_code 2>/dev/null | grep -oP '"\K[^"]+' | head -1)
        echo "${country:-??}"
    else
        echo "??"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# DATA COLLECTION
# ══════════════════════════════════════════════════════════════════════════════

# Blacklist count
BL4=$(ipset list blacklist 2>/dev/null | grep -c "^[0-9]") || BL4=0
BL6=$(ipset list blacklist6 2>/dev/null | grep -c "^[0-9a-f]") || BL6=0

# Whitelist count
WL4=$(ipset list whitelist 2>/dev/null | grep -c "^[0-9]") || WL4=0
WL6=$(ipset list whitelist6 2>/dev/null | grep -c "^[0-9a-f]") || WL6=0

# Spamhaus count
SH4=$(ipset list spamhaus 2>/dev/null | grep -c "^[0-9]") || SH4=0
SH6=$(ipset list spamhaus6 2>/dev/null | grep -c "^[0-9a-f]") || SH6=0

# Spamhaus hits (packets blocked)
SH4_HITS=$(iptables -nvL INPUT 2>/dev/null | awk '/match-set spamhaus src/ {print $1}' | head -1)
SH6_HITS=$(ip6tables -nvL INPUT 2>/dev/null | awk '/match-set spamhaus6 src/ {print $1}' | head -1)
SH4_HITS=${SH4_HITS:-0}
SH6_HITS=${SH6_HITS:-0}

# Traffic stats from iptables (INPUT chain)
IPTABLES_OUTPUT=$(iptables -nvL INPUT 2>/dev/null)
PKTS_ACCEPT=$(echo "$IPTABLES_OUTPUT" | awk '/RELATED,ESTABLISHED/ {print $1}' | head -1 | tr -d 'KMG')
BYTES_ACCEPT=$(echo "$IPTABLES_OUTPUT" | awk '/RELATED,ESTABLISHED/ {print $2}' | head -1)
PKTS_DROP=$(echo "$IPTABLES_OUTPUT" | awk '/^Chain INPUT \(policy DROP/ {gsub(/[^0-9]/,"",$4); print $4}')
PKTS_BLACKLIST=$(echo "$IPTABLES_OUTPUT" | awk '/match-set blacklist src/ {print $1}' | head -1 | tr -d 'KMG')

# Scan attempts
SCAN_COUNT=$(iptables -nvL INPUT 2>/dev/null | awk '/CHARIZARD_SCAN/ {sum+=$1} END {print sum+0}')

# Format bytes
format_bytes() {
    local input=$1
    if [ -z "$input" ] || [ "$input" = "0" ]; then
        echo "0 B"
        return
    fi
    if [[ "$input" =~ [KMG]$ ]]; then
        echo "$input"
        return
    fi
    local bytes
    bytes=$(echo "$input" | tr -dc '0-9')
    if [ -z "$bytes" ] || [ "$bytes" = "0" ]; then
        echo "0 B"
    elif [ "$bytes" -ge 1073741824 ]; then
        awk "BEGIN {printf \"%.1f GB\", $bytes/1073741824}"
    elif [ "$bytes" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.1f MB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ]; then
        awk "BEGIN {printf \"%.1f KB\", $bytes/1024}"
    else
        echo "$bytes B"
    fi
}

# Format rate (KB/s or MB/s)
format_rate() {
    local bytes=$1
    if [ -z "$bytes" ] || [ "$bytes" -le 0 ]; then
        echo "0 B/s"
    elif [ "$bytes" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.1f MB/s\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ]; then
        awk "BEGIN {printf \"%.1f KB/s\", $bytes/1024}"
    else
        echo "$bytes B/s"
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# BANDWIDTH (live rate from /proc/net/dev)
# ══════════════════════════════════════════════════════════════════════════════

IFACE=$(ip route 2>/dev/null | grep default | awk '{print $5}' | head -1)
IFACE=${IFACE:-eth0}

# Get current bytes
RX_NOW=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
TX_NOW=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)

# State file for rate calculation
STATE_FILE="/tmp/charizard-bw-state"

RX_RATE=0
TX_RATE=0

if [ -f "$STATE_FILE" ]; then
    read RX_PREV TX_PREV TS_PREV < "$STATE_FILE" 2>/dev/null
    TS_NOW=$(date +%s)
    ELAPSED=$((TS_NOW - TS_PREV))
    if [ "$ELAPSED" -gt 0 ] && [ "$ELAPSED" -lt 60 ]; then
        RX_RATE=$(( (RX_NOW - RX_PREV) / ELAPSED ))
        TX_RATE=$(( (TX_NOW - TX_PREV) / ELAPSED ))
        # Sanity check (no negative rates)
        [ "$RX_RATE" -lt 0 ] && RX_RATE=0
        [ "$TX_RATE" -lt 0 ] && TX_RATE=0
    fi
fi
echo "$RX_NOW $TX_NOW $(date +%s)" > "$STATE_FILE"

# Session totals (from boot)
RX_SESSION=$(format_bytes "$RX_NOW")
TX_SESSION=$(format_bytes "$TX_NOW")

# Today from vnstat
VNSTAT_RX="N/A"
VNSTAT_TX="N/A"
if command -v vnstat >/dev/null 2>&1; then
    VNSTAT_TODAY=$(vnstat -d 1 --oneline 2>/dev/null | cut -d';' -f4,5 2>/dev/null)
    VNSTAT_RX=$(echo "$VNSTAT_TODAY" | cut -d';' -f1)
    VNSTAT_TX=$(echo "$VNSTAT_TODAY" | cut -d';' -f2)
fi

# ══════════════════════════════════════════════════════════════════════════════
# CONNECTIONS
# ══════════════════════════════════════════════════════════════════════════════

CONN_TOTAL=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)
CONN_SSH=$(ss -tn state established '( dport = :22 )' 2>/dev/null | tail -n +2 | wc -l)
CONN_HTTP=$(ss -tn state established '( dport = :80 )' 2>/dev/null | tail -n +2 | wc -l)
CONN_HTTPS=$(ss -tn state established '( dport = :443 )' 2>/dev/null | tail -n +2 | wc -l)
CONN_OTHER=$((CONN_TOTAL - CONN_SSH - CONN_HTTP - CONN_HTTPS))
[ "$CONN_OTHER" -lt 0 ] && CONN_OTHER=0

# ══════════════════════════════════════════════════════════════════════════════
# FAIL2BAN
# ══════════════════════════════════════════════════════════════════════════════

F2B_CURRENT=0
F2B_TOTAL=0
F2B_IPSET=0
if command -v fail2ban-client >/dev/null 2>&1; then
    F2B_STATUS=$(fail2ban-client status sshd 2>/dev/null)
    F2B_CURRENT=$(echo "$F2B_STATUS" | grep "Currently banned" | awk '{print $NF}')
    F2B_TOTAL=$(echo "$F2B_STATUS" | grep "Total banned" | awk '{print $NF}')
    F2B_IPSET=$(ipset list fail2ban 2>/dev/null | grep -c "^[0-9]" || echo 0)
fi

# ══════════════════════════════════════════════════════════════════════════════
# TOP ATTACKERS + COUNTRIES
# ══════════════════════════════════════════════════════════════════════════════

TOP_ATTACKERS=$(grep -oE 'SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/charizard.log 2>/dev/null | cut -d= -f2 | sort | uniq -c | sort -rn | head -5)

# Count by country
declare -A COUNTRY_COUNTS
if [ -n "$TOP_ATTACKERS" ]; then
    while read -r count ip; do
        cc=$(geo_lookup "$ip")
        COUNTRY_COUNTS[$cc]=$((${COUNTRY_COUNTS[$cc]:-0} + count))
    done <<< "$TOP_ATTACKERS"
fi

# Sort countries by count
TOP_COUNTRIES=$(for cc in "${!COUNTRY_COUNTS[@]}"; do echo "${COUNTRY_COUNTS[$cc]} $cc"; done | sort -rn | head -5)

# ══════════════════════════════════════════════════════════════════════════════
# DISPLAY
# ══════════════════════════════════════════════════════════════════════════════

clear

echo -e "${ORANGE}══════════════════════════════════════${NC}"
echo -e "${WHITE}  FIREWALL STATS${NC}"
echo -e "${ORANGE}══════════════════════════════════════${NC}"
echo ""

# IP Sets
echo -e "${CYAN}  IP SETS${NC}"
echo -e "  ${DIM}├${NC} Whitelist:  ${GREEN}$WL4${NC} IPv4  ${GREEN}$WL6${NC} IPv6"
echo -e "  ${DIM}├${NC} Blacklist:  ${RED}$BL4${NC} IPv4  ${RED}$BL6${NC} IPv6"
echo -e "  ${DIM}└${NC} Spamhaus:   ${ORANGE}$SH4${NC} IPv4  ${ORANGE}$SH6${NC} IPv6"
echo ""

# Spamhaus
echo -e "${CYAN}  SPAMHAUS DROP${NC}"
echo -e "  ${DIM}├${NC} Blocked:    ${PURPLE}$SH4_HITS${NC} IPv4  ${PURPLE}$SH6_HITS${NC} IPv6"
SH_LAST=$(stat -c %Y /etc/firewall/spamhaus_drop.txt 2>/dev/null || echo 0)
SH_AGO=$(( ($(date +%s) - SH_LAST) / 3600 ))
echo -e "  ${DIM}└${NC} Updated:    ${DIM}${SH_AGO}h ago${NC}"
echo ""

# Fail2ban
echo -e "${CYAN}  FAIL2BAN${NC}"
if [ "${F2B_CURRENT:-0}" -gt 0 ]; then
    echo -e "  ${DIM}├${NC} Banned:     ${RED}${F2B_CURRENT:-0}${NC} active"
else
    echo -e "  ${DIM}├${NC} Banned:     ${GREEN}0${NC} active"
fi
echo -e "  ${DIM}├${NC} Total:      ${YELLOW}${F2B_TOTAL:-0}${NC} all time"
echo -e "  ${DIM}└${NC} Ipset:      ${ORANGE}${F2B_IPSET:-0}${NC} entries"
echo ""

# Bandwidth
echo -e "${CYAN}  BANDWIDTH${NC}"
echo -e "  ${DIM}├${NC} Rate:       ${GREEN}$(format_rate $RX_RATE)${NC} ${DIM}↓${NC}  ${ORANGE}$(format_rate $TX_RATE)${NC} ${DIM}↑${NC}"
echo -e "  ${DIM}├${NC} Session:    ${GREEN}$RX_SESSION${NC} ${DIM}↓${NC}  ${ORANGE}$TX_SESSION${NC} ${DIM}↑${NC}"
echo -e "  ${DIM}└${NC} Today:      ${GREEN}${VNSTAT_RX:-N/A}${NC} ${DIM}↓${NC}  ${ORANGE}${VNSTAT_TX:-N/A}${NC} ${DIM}↑${NC}"
echo ""

# Connections
echo -e "${CYAN}  CONNECTIONS ${DIM}($CONN_TOTAL total)${NC}"
echo -e "  ${DIM}├${NC} SSH:22      ${WHITE}$CONN_SSH${NC}"
echo -e "  ${DIM}├${NC} HTTP:80     ${WHITE}$CONN_HTTP${NC}"
echo -e "  ${DIM}├${NC} HTTPS:443   ${WHITE}$CONN_HTTPS${NC}"
echo -e "  ${DIM}└${NC} Other       ${WHITE}$CONN_OTHER${NC}"
echo ""

# Traffic
echo -e "${CYAN}  TRAFFIC${NC}"
echo -e "  ${DIM}├${NC} Accepted:   ${GREEN}${PKTS_ACCEPT:-0}${NC} pkts ($(format_bytes ${BYTES_ACCEPT:-0}))"
echo -e "  ${DIM}├${NC} Dropped:    ${RED}${PKTS_DROP:-0}${NC} pkts"
echo -e "  ${DIM}├${NC} Blacklist:  ${RED}${PKTS_BLACKLIST:-0}${NC} pkts"
echo -e "  ${DIM}└${NC} Scans:      ${ORANGE}${SCAN_COUNT:-0}${NC}"
echo ""

# Timer status
TIMER_UPDATE=$(systemctl is-active charizard-update.timer 2>/dev/null || echo "inactive")
TIMER_SPAM=$(systemctl is-active charizard-spamhaus.timer 2>/dev/null || echo "inactive")
if [ "$TIMER_UPDATE" = "active" ]; then
    TIMER_UPDATE_C="${GREEN}active${NC}"
else
    TIMER_UPDATE_C="${RED}$TIMER_UPDATE${NC}"
fi
if [ "$TIMER_SPAM" = "active" ]; then
    TIMER_SPAM_C="${GREEN}active${NC}"
else
    TIMER_SPAM_C="${RED}$TIMER_SPAM${NC}"
fi
echo -e "${CYAN}  TIMERS${NC}"
echo -e "  ${DIM}├${NC} Update:     $TIMER_UPDATE_C ${DIM}(5min)${NC}"
echo -e "  ${DIM}└${NC} Spamhaus:   $TIMER_SPAM_C ${DIM}(6h)${NC}"
echo ""

# Top attackers
if [ -n "$TOP_ATTACKERS" ]; then
    echo -e "${CYAN}  TOP ATTACKERS${NC}"
    echo "$TOP_ATTACKERS" | while read -r count ip; do
        cc=$(geo_lookup "$ip")
        echo -e "  ${DIM}•${NC} ${RED}$ip${NC} ${DIM}($count)${NC} ${CYAN}$cc${NC}"
    done
    echo ""
fi

# Top countries
if [ -n "$TOP_COUNTRIES" ]; then
    echo -e "${CYAN}  TOP COUNTRIES${NC}"
    echo "$TOP_COUNTRIES" | while read -r count cc; do
        echo -e "  ${DIM}•${NC} ${CYAN}$cc${NC} ${DIM}($count hits)${NC}"
    done
    echo ""
fi

echo -e "${DIM}  Updated: $(date '+%H:%M:%S')${NC}"
