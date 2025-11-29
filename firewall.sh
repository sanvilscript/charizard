#!/bin/bash
# ==============================================================================
#   CHARIZARD FIREWALL
#   "Fireblast your packets"
#   Developed by Sanvil (c) 2025
# ==============================================================================

# Read version from VERSION file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/VERSION" ]; then
    VERSION=$(cat "$SCRIPT_DIR/VERSION" | tr -d '[:space:]')
elif [ -f "/etc/firewall/VERSION" ]; then
    VERSION=$(cat "/etc/firewall/VERSION" | tr -d '[:space:]')
else
    VERSION="1.0.5"
fi
CONFIG_DIR="/etc/firewall"
WHITELIST_FILE="$CONFIG_DIR/whitelist.json"
PORTS_FILE="$CONFIG_DIR/openports.json"
SPAMHAUS_URL="https://www.spamhaus.org/drop/drop.txt"
SPAMHAUS6_URL="https://www.spamhaus.org/drop/dropv6.txt"
SPAMHAUS_CACHE="$CONFIG_DIR/spamhaus_drop.txt"
SPAMHAUS6_CACHE="$CONFIG_DIR/spamhaus_dropv6.txt"

# Auto-elevate to root if needed
if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

# ==============================================================================
# SAFETY CHECKS
# ==============================================================================

# Check dependencies
for cmd in jq host ipset iptables; do
    if ! command -v $cmd &> /dev/null; then
        echo "  [✗] Error: $cmd is not installed."
        exit 1
    fi
done

# Load config safely
if [ -s "$WHITELIST_FILE" ]; then
    if ! WHITELIST=$(jq -r '.hosts[]' "$WHITELIST_FILE" 2>/dev/null); then
        echo "  [✗] Error: whitelist.json format is invalid."
        exit 1
    fi
else
    echo "  [!] Warning: whitelist.json not found or empty."
    WHITELIST=""
fi

# Load ports with fallback to defaults
if [ -s "$PORTS_FILE" ]; then
    PUBLIC_PORTS=$(jq -r '.ports | join(",")' "$PORTS_FILE" 2>/dev/null)
fi
[ -z "$PUBLIC_PORTS" ] && PUBLIC_PORTS="80,443,22"

# ==============================================================================
# BANNER
# ==============================================================================

banner() {
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
    echo "  # CHARIZARD v${VERSION} - Fireblast your packets"
    echo "  # By Sanvil"
    echo ""
}

# ==============================================================================
# FUNCTIONS
# ==============================================================================

# Resolve hostname to IPv4 addresses (supports Round Robin DNS for CDN/cloud)
resolve() {
    local entry="$1"
    if [[ "$entry" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "$entry"
    else
        /usr/bin/host -t A "$entry" 2>/dev/null | grep "has address" | awk '{print $4}'
    fi
}

# Resolve hostname to IPv6 addresses (supports Round Robin DNS for CDN/cloud)
resolve6() {
    local entry="$1"
    if [[ "$entry" =~ ^[0-9a-fA-F:]+$ ]]; then
        echo "$entry"
    else
        /usr/bin/host -t AAAA "$entry" 2>/dev/null | grep "has IPv6 address" | awk '{print $5}'
    fi
}

# Check if address is IPv6
is_ipv6() {
    [[ "$1" =~ : ]]
}

# GeoIP lookup - returns country code (2 letters) or "??"
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

# GeoIP lookup - returns full country name
geo_lookup_name() {
    local ip="$1"
    if [ -f "$GEO_DB" ] && command -v mmdblookup &>/dev/null; then
        local name=$(mmdblookup --file "$GEO_DB" --ip "$ip" country names en 2>/dev/null | grep -oP '"\K[^"]+' | head -1)
        echo "${name:-Unknown}"
    else
        echo "Unknown"
    fi
}

# Update whitelist/blacklist ipsets from config
# Creates temporary sets, populates them, then swaps atomically
update_ipset() {
    # IPv4 whitelist
    ipset create whitelist hash:ip -exist
    ipset create whitelist_tmp hash:ip -exist
    ipset flush whitelist_tmp

    for entry in $WHITELIST; do
        resolved_ips=$(resolve "$entry")
        for ip in $resolved_ips; do
            [ -n "$ip" ] && ipset add whitelist_tmp "$ip" -exist
        done
    done
    ipset swap whitelist_tmp whitelist
    ipset destroy whitelist_tmp
    ipset create blacklist hash:ip timeout 3600 -exist

    # IPv6 whitelist
    ipset create whitelist6 hash:ip family inet6 -exist
    ipset create whitelist6_tmp hash:ip family inet6 -exist
    ipset flush whitelist6_tmp
    for entry in $WHITELIST; do
        resolved_ips6=$(resolve6 "$entry")
        for ip6 in $resolved_ips6; do
            [ -n "$ip6" ] && ipset add whitelist6_tmp "$ip6" -exist
        done
    done
    ipset swap whitelist6_tmp whitelist6
    ipset destroy whitelist6_tmp
    ipset create blacklist6 hash:ip family inet6 timeout 3600 -exist
}

# ==============================================================================
# SPAMHAUS DROP - Botnet/spammer blocklist (https://www.spamhaus.org/drop/)
# ==============================================================================

# Download and update Spamhaus DROP lists (IPv4 + IPv6)
spamhaus_update() {
    local tmp_file="/tmp/spamhaus_drop.txt"
    local tmp_file6="/tmp/spamhaus_dropv6.txt"

    # === IPv4 ===
    if ! curl -sfL --connect-timeout 10 --max-time 30 "$SPAMHAUS_URL" -o "$tmp_file" 2>/dev/null; then
        echo "  [✗] Failed to download Spamhaus DROP list (IPv4)"
        return 1
    fi

    ipset create spamhaus hash:net -exist
    ipset create spamhaus_tmp hash:net -exist
    ipset flush spamhaus_tmp

    local count=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*\; ]] && continue
        local cidr=$(echo "$line" | cut -d';' -f1 | tr -d ' ')
        if [[ -n "$cidr" ]] && [[ "$cidr" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
            ipset add spamhaus_tmp "$cidr" -exist 2>/dev/null && ((count++))
        fi
    done < "$tmp_file"

    ipset swap spamhaus_tmp spamhaus
    ipset destroy spamhaus_tmp
    mv "$tmp_file" "$SPAMHAUS_CACHE"
    echo "  [✓] Spamhaus DROP IPv4: $count ranges loaded"

    # === IPv6 ===
    if ! curl -sfL --connect-timeout 10 --max-time 30 "$SPAMHAUS6_URL" -o "$tmp_file6" 2>/dev/null; then
        echo "  [✗] Failed to download Spamhaus DROP list (IPv6)"
        return 1
    fi

    ipset create spamhaus6 hash:net family inet6 -exist
    ipset create spamhaus6_tmp hash:net family inet6 -exist
    ipset flush spamhaus6_tmp

    local count6=0
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^[[:space:]]*\; ]] && continue
        local cidr6=$(echo "$line" | cut -d';' -f1 | tr -d ' ')
        if [[ -n "$cidr6" ]] && [[ "$cidr6" =~ ^[0-9a-fA-F:]+/[0-9]+$ ]]; then
            ipset add spamhaus6_tmp "$cidr6" -exist 2>/dev/null && ((count6++))
        fi
    done < "$tmp_file6"

    ipset swap spamhaus6_tmp spamhaus6
    ipset destroy spamhaus6_tmp
    mv "$tmp_file6" "$SPAMHAUS6_CACHE"
    echo "  [✓] Spamhaus DROP IPv6: $count6 ranges loaded"

    return 0
}

# Apply Spamhaus rules to iptables (insert after blacklist, before whitelist)
spamhaus_apply() {
    if ! ipset list spamhaus >/dev/null 2>&1; then
        echo "  [!] Spamhaus ipset not found, updating..."
        spamhaus_update || return 1
    fi

    # IPv4: create LOGSPAM chain for logging
    iptables -N LOGSPAM 2>/dev/null || iptables -F LOGSPAM
    iptables -A LOGSPAM -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "CHARIZARD_SPAM: " --log-level 4
    iptables -A LOGSPAM -j DROP

    # Insert rule after blacklist
    if ! iptables -C INPUT -m set --match-set spamhaus src -j LOGSPAM 2>/dev/null; then
        local bl_line=$(iptables -L INPUT --line-numbers -n 2>/dev/null | grep "blacklist" | head -1 | awk '{print $1}')
        if [[ -n "$bl_line" ]]; then
            iptables -I INPUT $((bl_line + 1)) -m set --match-set spamhaus src -j LOGSPAM
        else
            iptables -I INPUT 5 -m set --match-set spamhaus src -j LOGSPAM
        fi
    fi

    # IPv6: create LOGSPAM6 chain for logging
    ip6tables -N LOGSPAM6 2>/dev/null || ip6tables -F LOGSPAM6
    ip6tables -A LOGSPAM6 -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "CHARIZARD6_SPAM: " --log-level 4
    ip6tables -A LOGSPAM6 -j DROP

    # Insert rule after blacklist6
    if ! ip6tables -C INPUT -m set --match-set spamhaus6 src -j LOGSPAM6 2>/dev/null; then
        local bl6_line=$(ip6tables -L INPUT --line-numbers -n 2>/dev/null | grep "blacklist6" | head -1 | awk '{print $1}')
        if [[ -n "$bl6_line" ]]; then
            ip6tables -I INPUT $((bl6_line + 1)) -m set --match-set spamhaus6 src -j LOGSPAM6
        else
            ip6tables -I INPUT 5 -m set --match-set spamhaus6 src -j LOGSPAM6
        fi
    fi
}

# Apply IPv4 iptables rules
# Order: loopback > noise > invalid > established > blacklist > whitelist > scans > ports > docker
apply_iptables() {
    [ -f /etc/iptables/rules.v4 ] && cp /etc/iptables/rules.v4 /etc/iptables/rules.v4.bak
    [ -f /etc/ipset.rules ] && cp /etc/ipset.rules /etc/ipset.rules.bak

    # LOGDROP chain for logging dropped packets
    iptables -N LOGDROP 2>/dev/null || iptables -F LOGDROP
    iptables -A LOGDROP -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "CHARIZARD_DROP: " --log-level 4
    iptables -A LOGDROP -j DROP

    iptables -F INPUT
    iptables -P INPUT DROP
    iptables -A INPUT -i lo -j ACCEPT

    # Drop broadcast/multicast/IGMP noise
    iptables -A INPUT -m pkttype --pkt-type broadcast -j DROP
    iptables -A INPUT -m pkttype --pkt-type multicast -j DROP
    iptables -A INPUT -p igmp -j DROP

    # State tracking
    iptables -A INPUT -m state --state INVALID -j DROP
    iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # IP sets
    iptables -A INPUT -m set --match-set blacklist src -j LOGDROP
    iptables -A INPUT -m set --match-set whitelist src -j ACCEPT

    # Scan detection (NULL, XMAS, FIN-only)
    iptables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/min -j LOG --log-prefix "CHARIZARD_SCAN: " --log-level 4
    iptables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/min -j LOG --log-prefix "CHARIZARD_SCAN: " --log-level 4
    iptables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    iptables -A INPUT -p tcp --tcp-flags ALL FIN -j DROP

    # Illegal flag combinations
    iptables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    iptables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    iptables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP

    # ICMP rate limiting
    iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 10/s --limit-burst 20 -j ACCEPT
    iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

    # Public ports + Docker interfaces
    iptables -A INPUT -p tcp -m multiport --dports $PUBLIC_PORTS -j ACCEPT
    iptables -A INPUT -i br-+ -j ACCEPT
    iptables -A INPUT -i docker0 -j ACCEPT
    iptables -A INPUT -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "CHARIZARD_BLOCK: " --log-level 4

    # Docker chain
    iptables -F DOCKER-USER 2>/dev/null
    iptables -A DOCKER-USER -m state --state ESTABLISHED,RELATED -j RETURN
    iptables -A DOCKER-USER -m set --match-set blacklist src -j DROP
    iptables -A DOCKER-USER -m set --match-set whitelist src -j RETURN
    iptables -A DOCKER-USER -p tcp -m multiport --dports $PUBLIC_PORTS -j RETURN
    iptables -A DOCKER-USER -j DROP
}

# Apply IPv6 ip6tables rules (mirrors IPv4 with IPv6-specific adjustments)
apply_ip6tables() {
    [ -f /etc/iptables/rules.v6 ] && cp /etc/iptables/rules.v6 /etc/iptables/rules.v6.bak

    # LOGDROP6 chain for logging
    ip6tables -N LOGDROP6 2>/dev/null || ip6tables -F LOGDROP6
    ip6tables -A LOGDROP6 -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "CHARIZARD6_DROP: " --log-level 4
    ip6tables -A LOGDROP6 -j DROP

    ip6tables -F INPUT
    ip6tables -P INPUT DROP
    ip6tables -A INPUT -i lo -j ACCEPT

    # Drop broadcast/multicast noise
    ip6tables -A INPUT -m pkttype --pkt-type broadcast -j DROP
    ip6tables -A INPUT -m pkttype --pkt-type multicast -j DROP

    # State tracking
    ip6tables -A INPUT -m state --state INVALID -j DROP
    ip6tables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

    # IP sets
    ip6tables -A INPUT -m set --match-set blacklist6 src -j LOGDROP6
    ip6tables -A INPUT -m set --match-set whitelist6 src -j ACCEPT

    # Scan detection
    ip6tables -A INPUT -p tcp ! --syn -m state --state NEW -j DROP
    ip6tables -A INPUT -p tcp --tcp-flags ALL NONE -m limit --limit 1/min -j LOG --log-prefix "CHARIZARD6_SCAN: " --log-level 4
    ip6tables -A INPUT -p tcp --tcp-flags ALL NONE -j DROP
    ip6tables -A INPUT -p tcp --tcp-flags ALL ALL -m limit --limit 1/min -j LOG --log-prefix "CHARIZARD6_SCAN: " --log-level 4
    ip6tables -A INPUT -p tcp --tcp-flags ALL ALL -j DROP
    ip6tables -A INPUT -p tcp --tcp-flags ALL FIN -j DROP

    # Illegal flag combinations
    ip6tables -A INPUT -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP
    ip6tables -A INPUT -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
    ip6tables -A INPUT -p tcp --tcp-flags FIN,RST FIN,RST -j DROP

    # ICMPv6 rate limiting + essential types for IPv6 connectivity
    ip6tables -A INPUT -p icmpv6 --icmpv6-type echo-request -m limit --limit 10/s --limit-burst 20 -j ACCEPT
    ip6tables -A INPUT -p icmpv6 --icmpv6-type echo-request -j DROP
    ip6tables -A INPUT -p icmpv6 --icmpv6-type neighbour-solicitation -j ACCEPT
    ip6tables -A INPUT -p icmpv6 --icmpv6-type neighbour-advertisement -j ACCEPT
    ip6tables -A INPUT -p icmpv6 --icmpv6-type router-solicitation -j ACCEPT
    ip6tables -A INPUT -p icmpv6 --icmpv6-type router-advertisement -j ACCEPT

    # Public ports + Docker interfaces
    ip6tables -A INPUT -p tcp -m multiport --dports $PUBLIC_PORTS -j ACCEPT
    ip6tables -A INPUT -i br-+ -j ACCEPT
    ip6tables -A INPUT -i docker0 -j ACCEPT
    ip6tables -A INPUT -m limit --limit 5/min --limit-burst 10 -j LOG --log-prefix "CHARIZARD6_BLOCK: " --log-level 4

    # Docker chain
    ip6tables -F DOCKER-USER 2>/dev/null
    ip6tables -A DOCKER-USER -m state --state ESTABLISHED,RELATED -j RETURN
    ip6tables -A DOCKER-USER -m set --match-set blacklist6 src -j DROP
    ip6tables -A DOCKER-USER -m set --match-set whitelist6 src -j RETURN
    ip6tables -A DOCKER-USER -p tcp -m multiport --dports $PUBLIC_PORTS -j RETURN
    ip6tables -A DOCKER-USER -j DROP
}

# ==============================================================================
# COMMANDS
# ==============================================================================

case "$1" in
apply)
    banner
    echo "  [*] Updating ipset (v4+v6)..."
    update_ipset
    echo "  [*] Updating Spamhaus DROP..."
    spamhaus_update
    echo "  [*] Applying iptables rules..."
    apply_iptables
    echo "  [*] Applying ip6tables rules..."
    apply_ip6tables
    echo "  [*] Applying Spamhaus rules..."
    spamhaus_apply
    ipset save > /etc/ipset.rules
    iptables-save > /etc/iptables/rules.v4
    ip6tables-save > /etc/iptables/rules.v6
    echo "  [✓] Firewall active (IPv4+IPv6) - $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    ;;
update)
    update_ipset
    echo "  [✓] Whitelist updated - $(date '+%Y-%m-%d %H:%M:%S')"
    ;;
flush)
    iptables -F INPUT && iptables -P INPUT ACCEPT
    iptables -F DOCKER-USER 2>/dev/null
    iptables -A DOCKER-USER -j RETURN
    iptables -F LOGDROP 2>/dev/null
    iptables -F LOGSPAM 2>/dev/null
    ip6tables -F INPUT && ip6tables -P INPUT ACCEPT
    ip6tables -F DOCKER-USER 2>/dev/null
    ip6tables -A DOCKER-USER -j RETURN
    ip6tables -F LOGDROP6 2>/dev/null
    ip6tables -F LOGSPAM6 2>/dev/null
    echo "  [!] Firewall DISABLED (IPv4+IPv6) - $(date '+%Y-%m-%d %H:%M:%S')"
    ;;
rollback)
    [ -f /etc/iptables/rules.v4.bak ] || { echo "  [✗] No backup found"; exit 1; }
    iptables-restore < /etc/iptables/rules.v4.bak
    [ -f /etc/iptables/rules.v6.bak ] && ip6tables-restore < /etc/iptables/rules.v6.bak 2>/dev/null
    [ -f /etc/ipset.rules.bak ] && ipset restore < /etc/ipset.rules.bak 2>/dev/null
    echo "  [✓] Rollback complete (IPv4+IPv6) - $(date '+%Y-%m-%d %H:%M:%S')"
    ;;
show)
    echo ""
    echo "  +-----------------------------------------------------------------+"
    echo "  | CHARIZARD STATUS                                                |"
    echo "  +-----------------------------------------------------------------+"
    echo ""
    echo "  === WHITELIST (IPv4) ==="
    ipset list whitelist 2>/dev/null | grep -E "^[0-9]" | sed 's/^/  /'
    echo ""
    echo "  === WHITELIST6 (IPv6) ==="
    ipset list whitelist6 2>/dev/null | grep -E "^[0-9a-fA-F]" | sed 's/^/  /' || echo "  (empty)"
    echo ""
    echo "  === BLACKLIST (IPv4) ==="
    ipset list blacklist 2>/dev/null | grep -E "^[0-9]" | sed 's/^/  /' || echo "  (empty)"
    echo ""
    echo "  === BLACKLIST6 (IPv6) ==="
    ipset list blacklist6 2>/dev/null | grep -E "^[0-9a-fA-F]" | sed 's/^/  /' || echo "  (empty)"
    echo ""
    echo "  === INPUT CHAIN (IPv4) ==="
    iptables -L INPUT -n --line-numbers 2>/dev/null | sed 's/^/  /'
    echo ""
    echo "  === INPUT CHAIN (IPv6) ==="
    ip6tables -L INPUT -n --line-numbers 2>/dev/null | sed 's/^/  /'
    echo ""
    ;;
status)
    banner
    WL4=$(ipset list whitelist 2>/dev/null | grep -c '^[0-9]')
    BL4=$(ipset list blacklist 2>/dev/null | grep -c '^[0-9]')
    WL6=$(ipset list whitelist6 2>/dev/null | grep -c '^[0-9a-fA-F]')
    BL6=$(ipset list blacklist6 2>/dev/null | grep -c '^[0-9a-fA-F]')
    echo "  +-----------------------------------------------------------------+"
    echo "  | IPv4  WHITELIST: $WL4    BLACKLIST: $BL4                             |"
    echo "  | IPv6  WHITELIST: $WL6    BLACKLIST: $BL6                             |"
    echo "  +-----------------------------------------------------------------+"
    echo ""
    echo "  === TRAFFIC STATS (IPv4) ==="
    iptables -L INPUT -nvx 2>/dev/null | head -15 | sed 's/^/  /'
    echo ""
    echo "  === TRAFFIC STATS (IPv6) ==="
    ip6tables -L INPUT -nvx 2>/dev/null | head -15 | sed 's/^/  /'
    echo ""
    ;;
add)
    [ -z "$2" ] && echo "  [✗] Usage: $0 add <ip>" && exit 1
    if is_ipv6 "$2"; then
        ipset add whitelist6 "$2" -exist
        echo "  [✓] $2 added to whitelist6 (temporary)"
    else
        ipset add whitelist "$2" -exist
        echo "  [✓] $2 added to whitelist (temporary)"
    fi
    ;;
ban)
    [ -z "$2" ] && echo "  [✗] Usage: $0 ban <ip>" && exit 1
    if is_ipv6 "$2"; then
        ipset add blacklist6 "$2" -exist
        echo "  [✓] $2 BANNED IPv6 (auto-expire: 1h)"
    else
        ipset add blacklist "$2" -exist
        echo "  [✓] $2 BANNED (auto-expire: 1h)"
    fi
    # Send alert via notify module
    if [ -x /etc/firewall/notify.sh ]; then
        HITS=$(grep -c "SRC=$2" /var/log/charizard.log 2>/dev/null || echo "0")
        /etc/firewall/notify.sh ban "$2" "Manual ban" "$HITS" &
    fi
    ;;
unban)
    [ -z "$2" ] && echo "  [✗] Usage: $0 unban <ip>" && exit 1
    if is_ipv6 "$2"; then
        ipset del blacklist6 "$2" 2>/dev/null
        echo "  [✓] $2 removed from blacklist6"
    else
        ipset del blacklist "$2" 2>/dev/null
        echo "  [✓] $2 removed from blacklist"
    fi
    ;;
reload)
    $0 update && $0 apply
    ;;
open)
    [ -z "$2" ] && echo "  [✗] Usage: $0 open <port>" && exit 1
    PORT="$2"
    if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
        echo "  [✗] Invalid port: $PORT"
        exit 1
    fi
    if jq -e ".ports | index($PORT)" "$PORTS_FILE" >/dev/null 2>&1; then
        echo "  [*] Port $PORT already open"
    else
        jq ".ports += [$PORT]" "$PORTS_FILE" > /tmp/ports.tmp && mv /tmp/ports.tmp "$PORTS_FILE"
        echo "  [✓] Port $PORT added to openports.json"
        echo "  [*] Run 'charizard apply' to activate"
    fi
    ;;
close)
    [ -z "$2" ] && echo "  [✗] Usage: $0 close <port>" && exit 1
    PORT="$2"
    if ! jq -e ".ports | index($PORT)" "$PORTS_FILE" >/dev/null 2>&1; then
        echo "  [*] Port $PORT not in openports.json"
    else
        jq ".ports |= map(select(. != $PORT))" "$PORTS_FILE" > /tmp/ports.tmp && mv /tmp/ports.tmp "$PORTS_FILE"
        echo "  [✓] Port $PORT removed from openports.json"
        echo "  [*] Run 'charizard apply' to activate"
    fi
    ;;
ports)
    echo ""
    echo "  === OPEN PORTS ==="
    jq -r '.ports | sort | .[]' "$PORTS_FILE" 2>/dev/null | sed 's/^/  /'
    echo ""
    ;;
allow)
    [ -z "$2" ] && echo "  [✗] Usage: $0 allow <host/ip>" && exit 1
    HOST="$2"
    if jq -e ".hosts | index(\"$HOST\")" "$WHITELIST_FILE" >/dev/null 2>&1; then
        echo "  [*] $HOST already in whitelist"
    else
        jq ".hosts += [\"$HOST\"]" "$WHITELIST_FILE" > /tmp/wl.tmp && mv /tmp/wl.tmp "$WHITELIST_FILE"
        echo "  [✓] $HOST added to whitelist.json"
        echo "  [*] Run 'charizard apply' to activate"
    fi
    ;;
deny)
    [ -z "$2" ] && echo "  [✗] Usage: $0 deny <host/ip>" && exit 1
    HOST="$2"
    if ! jq -e ".hosts | index(\"$HOST\")" "$WHITELIST_FILE" >/dev/null 2>&1; then
        echo "  [*] $HOST not in whitelist"
    else
        jq ".hosts |= map(select(. != \"$HOST\"))" "$WHITELIST_FILE" > /tmp/wl.tmp && mv /tmp/wl.tmp "$WHITELIST_FILE"
        echo "  [✓] $HOST removed from whitelist.json"
        echo "  [*] Run 'charizard apply' to activate"
    fi
    ;;
hosts)
    echo ""
    echo "  === WHITELISTED HOSTS ==="
    jq -r '.hosts[]' "$WHITELIST_FILE" 2>/dev/null | sed 's/^/  /'
    echo ""
    ;;
watch)
    watch -n1 "echo ''; echo '  ╔===============================================================╗'; echo '  ║           CHARIZARD LIVE MONITOR                              ║'; echo '  ╚===============================================================╝'; echo ''; echo '  Active connections:'; ss -tun state established | grep -cE ':80|:443|:1935|:9022' | sed 's/^/    /'; echo ''; echo '  Recent blocks (v4+v6):'; dmesg | grep -E 'CHARIZARD6?_' | tail -5 | sed 's/^/    /'"
    ;;
spamhaus)
    case "$2" in
    update)
        echo "  [*] Forcing Spamhaus DROP update..."
        spamhaus_update
        spamhaus_apply
        ipset save > /etc/ipset.rules
        ;;
    status|"")
        echo ""
        echo "  === SPAMHAUS DROP ==="
        echo ""
        echo "  --- IPv4 ---"
        if ipset list spamhaus >/dev/null 2>&1; then
            SH_COUNT=$(ipset list spamhaus 2>/dev/null | grep -cE "^[0-9]")
            SH_HITS=$(iptables -L INPUT -nvx 2>/dev/null | grep "spamhaus" | awk '{print $1}')
            echo "  Status:  ACTIVE"
            echo "  Ranges:  $SH_COUNT"
            echo "  Hits:    ${SH_HITS:-0} packets blocked"
        else
            echo "  Status:  NOT LOADED"
        fi
        echo ""
        echo "  --- IPv6 ---"
        if ipset list spamhaus6 >/dev/null 2>&1; then
            SH6_COUNT=$(ipset list spamhaus6 2>/dev/null | grep -cE "^[0-9a-fA-F]")
            SH6_HITS=$(ip6tables -L INPUT -nvx 2>/dev/null | grep "spamhaus6" | awk '{print $1}')
            echo "  Status:  ACTIVE"
            echo "  Ranges:  $SH6_COUNT"
            echo "  Hits:    ${SH6_HITS:-0} packets blocked"
        else
            echo "  Status:  NOT LOADED"
        fi
        echo ""
        if [ -f "$SPAMHAUS_CACHE" ]; then
            SH_AGE=$(( ($(date +%s) - $(stat -c %Y "$SPAMHAUS_CACHE" 2>/dev/null || echo 0)) / 3600 ))
            echo "  Last update: ${SH_AGE}h ago"
        fi
        echo ""
        ;;
    *)
        echo "  Usage: charizard spamhaus [status|update]"
        ;;
    esac
    ;;
f2b|fail2ban)
    case "$2" in
    status|"")
        echo ""
        echo "  === FAIL2BAN STATUS ==="
        echo ""
        if ! command -v fail2ban-client >/dev/null 2>&1; then
            echo "  [!] fail2ban not installed"
            exit 1
        fi
        F2B_STATUS=$(fail2ban-client status sshd 2>/dev/null)
        if [ -z "$F2B_STATUS" ]; then
            echo "  [!] fail2ban not running or sshd jail not found"
            exit 1
        fi
        F2B_CURRENT=$(echo "$F2B_STATUS" | grep "Currently banned" | awk '{print $NF}')
        F2B_TOTAL=$(echo "$F2B_STATUS" | grep "Total banned" | awk '{print $NF}')
        F2B_FAILED=$(echo "$F2B_STATUS" | grep "Currently failed" | awk '{print $NF}')
        echo "  Currently banned:  $F2B_CURRENT"
        echo "  Total banned:      $F2B_TOTAL"
        echo "  Currently failed:  $F2B_FAILED"
        echo ""
        # Show banned IPs
        BANNED_IPS=$(echo "$F2B_STATUS" | grep "Banned IP list" | cut -d: -f2)
        if [ -n "$BANNED_IPS" ] && [ "$BANNED_IPS" != "	" ]; then
            echo "  Banned IPs:"
            echo "$BANNED_IPS" | tr '\t' '\n' | grep -v "^$" | sed 's/^/    /'
        fi
        echo ""
        # ipset entries
        echo "  Ipset fail2ban:"
        ipset list fail2ban 2>/dev/null | grep "^[0-9]" | sed 's/^/    /' | head -10
        echo ""
        ;;
    unban)
        [ -z "$3" ] && echo "  [✗] Usage: charizard f2b unban <ip>" && exit 1
        fail2ban-client set sshd unbanip "$3" 2>/dev/null
        echo "  [✓] $3 unbanned from fail2ban"
        ;;
    ban)
        [ -z "$3" ] && echo "  [✗] Usage: charizard f2b ban <ip>" && exit 1
        fail2ban-client set sshd banip "$3" 2>/dev/null
        echo "  [✓] $3 banned via fail2ban"
        ;;
    *)
        echo "  Usage: charizard f2b [status|ban <ip>|unban <ip>]"
        ;;
    esac
    ;;
log)
    LINES="${2:-20}"
    echo ""
    echo "  === FIREWALL LOG (last $LINES) ==="
    echo ""
    if [ ! -f /var/log/charizard.log ]; then
        echo "  [!] Log file not found"
        exit 1
    fi
    tail -n "$LINES" /var/log/charizard.log 2>/dev/null | while IFS= read -r line; do
        ip=$(echo "$line" | grep -oE 'SRC=[0-9a-fA-F.:]+' | cut -d= -f2)
        cc=$(geo_lookup "$ip" 2>/dev/null)
        if [[ "$line" =~ CHARIZARD6?_SPAM ]]; then
            echo -e "  \033[38;5;132m[SPAM]\033[0m \033[38;5;167m$ip\033[0m \033[38;5;246m($cc)\033[0m"
        elif [[ "$line" =~ CHARIZARD6?_SCAN ]]; then
            echo -e "  \033[38;5;214m[SCAN]\033[0m \033[38;5;160m$ip\033[0m \033[38;5;246m($cc)\033[0m"
        elif [[ "$line" =~ CHARIZARD6?_BLOCK ]]; then
            echo -e "  \033[38;5;109m[BLCK]\033[0m \033[38;5;160m$ip\033[0m \033[38;5;246m($cc)\033[0m"
        elif [[ "$line" =~ CHARIZARD6?_DROP ]]; then
            echo -e "  \033[38;5;160m[DROP]\033[0m \033[38;5;160m$ip\033[0m \033[38;5;246m($cc)\033[0m"
        else
            echo -e "  \033[38;5;246m[----]\033[0m \033[38;5;246m$ip\033[0m \033[38;5;246m($cc)\033[0m"
        fi
    done
    echo ""
    ;;
top)
    LIMIT="${2:-10}"
    echo ""
    echo "  === TOP $LIMIT BLOCKED IPs ==="
    echo ""
    if [ ! -f /var/log/charizard.log ]; then
        echo "  [!] Log file not found"
        exit 1
    fi
    grep -oE 'SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/charizard.log 2>/dev/null | \
        cut -d= -f2 | sort | uniq -c | sort -rn | head -n "$LIMIT" | \
        while read -r count ip; do
            cc=$(geo_lookup "$ip" 2>/dev/null)
            printf "  \033[38;5;160m%-15s\033[0m \033[38;5;246m%6s hits\033[0m \033[38;5;109m(%s)\033[0m\n" "$ip" "$count" "$cc"
        done
    echo ""
    ;;
backup)
    BACKUP_DIR="/etc/firewall/backups"
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    BACKUP_FILE="$BACKUP_DIR/charizard_$TIMESTAMP.tar.gz"
    TEMP_DIR=$(mktemp -d)
    mkdir -p "$BACKUP_DIR"
    echo ""
    echo "  === FULL SYSTEM BACKUP ==="
    echo ""

    # Create directory structure in temp
    mkdir -p "$TEMP_DIR"/{firewall,sysctl,systemd,rsyslog,logrotate,fail2ban,profile,vim,iptables}

    # 1. Firewall config
    echo "  [*] Firewall config..."
    cp /etc/firewall/whitelist.json "$TEMP_DIR/firewall/" 2>/dev/null
    cp /etc/firewall/openports.json "$TEMP_DIR/firewall/" 2>/dev/null
    cp /etc/firewall/firewall.sh "$TEMP_DIR/firewall/" 2>/dev/null
    cp -r /etc/firewall/monitor "$TEMP_DIR/firewall/" 2>/dev/null

    # 2. Sysctl hardening
    echo "  [*] Sysctl hardening..."
    cp /etc/sysctl.d/99-charizard.conf "$TEMP_DIR/sysctl/" 2>/dev/null

    # 3. Systemd services & timers
    echo "  [*] Systemd services..."
    cp /etc/systemd/system/charizard.service "$TEMP_DIR/systemd/" 2>/dev/null
    cp /etc/systemd/system/charizard-update.service "$TEMP_DIR/systemd/" 2>/dev/null
    cp /etc/systemd/system/charizard-update.timer "$TEMP_DIR/systemd/" 2>/dev/null
    cp /etc/systemd/system/charizard-spamhaus.service "$TEMP_DIR/systemd/" 2>/dev/null
    cp /etc/systemd/system/charizard-spamhaus.timer "$TEMP_DIR/systemd/" 2>/dev/null
    cp /etc/systemd/system/charizard-cache.service "$TEMP_DIR/systemd/" 2>/dev/null
    cp /etc/systemd/system/charizard-cache.timer "$TEMP_DIR/systemd/" 2>/dev/null

    # 4. Rsyslog & logrotate
    echo "  [*] Logging config..."
    cp /etc/rsyslog.d/10-charizard.conf "$TEMP_DIR/rsyslog/" 2>/dev/null
    cp /etc/logrotate.d/charizard "$TEMP_DIR/logrotate/" 2>/dev/null

    # 5. Fail2ban
    echo "  [*] Fail2ban config..."
    cp /etc/fail2ban/action.d/charizard.conf "$TEMP_DIR/fail2ban/" 2>/dev/null
    cp /etc/fail2ban/jail.local "$TEMP_DIR/fail2ban/" 2>/dev/null

    # 6. Bash customizations
    echo "  [*] Bash customizations..."
    cp /etc/profile.d/charizard-aliases.sh "$TEMP_DIR/profile/" 2>/dev/null
    cp /etc/profile.d/charizard-prompt.sh "$TEMP_DIR/profile/" 2>/dev/null
    cp /etc/profile.d/charizard-bashrc.sh "$TEMP_DIR/profile/" 2>/dev/null

    # 7. Vim & Screen
    echo "  [*] Vim & Screen config..."
    cp /etc/vim/vimrc.local "$TEMP_DIR/vim/" 2>/dev/null
    cp /etc/screenrc "$TEMP_DIR/" 2>/dev/null

    # 8. iptables rules (live)
    echo "  [*] iptables rules..."
    iptables-save > "$TEMP_DIR/iptables/rules.v4" 2>/dev/null
    ip6tables-save > "$TEMP_DIR/iptables/rules.v6" 2>/dev/null
    ipset save > "$TEMP_DIR/iptables/ipset.rules" 2>/dev/null

    # Create tarball
    tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" . 2>/dev/null
    rm -rf "$TEMP_DIR"

    # Show what was backed up
    echo ""
    echo "  [✓] Backup created: $BACKUP_FILE"
    echo ""
    echo "  Contents:"
    echo "      • firewall/      (config, scripts, monitor)"
    echo "      • sysctl/        (kernel hardening)"
    echo "      • systemd/       (services, timers)"
    echo "      • rsyslog/       (log routing)"
    echo "      • logrotate/     (log rotation)"
    echo "      • fail2ban/      (action, jail)"
    echo "      • profile/       (bash aliases, prompt)"
    echo "      • vim/           (vimrc)"
    echo "      • screenrc"
    echo "      • iptables/      (rules v4, v6, ipset)"
    echo ""

    # Keep only last 5 backups
    ls -t "$BACKUP_DIR"/charizard_*.tar.gz 2>/dev/null | tail -n +6 | xargs -r rm -f

    # Show size and list
    SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    echo "  Size: $SIZE"
    echo ""
    echo "  Recent backups:"
    ls -lht "$BACKUP_DIR"/charizard_*.tar.gz 2>/dev/null | head -3 | \
        awk '{print "      " $9 " (" $5 ")"}'
    echo ""
    ;;
restore)
    BACKUP_DIR="/etc/firewall/backups"
    if [ -z "$2" ]; then
        echo ""
        echo "  === AVAILABLE BACKUPS ==="
        echo ""
        ls -lht "$BACKUP_DIR"/charizard_*.tar.gz 2>/dev/null | head -5 | \
            awk '{print "  " NR ". " $9 " (" $5 ")"}'
        echo ""
        echo "  Usage: charizard restore <file> [--full]"
        echo ""
        echo "  Options:"
        echo "      (default)   Restore config only (whitelist, openports)"
        echo "      --full      Restore everything (systemd, sysctl, bash, etc.)"
        echo ""
        exit 0
    fi
    RESTORE_FILE="$2"
    FULL_RESTORE=false
    [ "$3" = "--full" ] && FULL_RESTORE=true
    [ ! -f "$RESTORE_FILE" ] && RESTORE_FILE="$BACKUP_DIR/$2"
    if [ ! -f "$RESTORE_FILE" ]; then
        echo "  [✗] Backup file not found: $2"
        exit 1
    fi

    TEMP_DIR=$(mktemp -d)
    tar -xzf "$RESTORE_FILE" -C "$TEMP_DIR" 2>/dev/null

    echo ""
    echo "  === RESTORE ==="
    echo ""
    echo "  [*] Source: $RESTORE_FILE"
    echo ""

    # Always restore firewall config
    echo "  [*] Restoring firewall config..."
    [ -f "$TEMP_DIR/firewall/whitelist.json" ] && cp "$TEMP_DIR/firewall/whitelist.json" /etc/firewall/
    [ -f "$TEMP_DIR/firewall/openports.json" ] && cp "$TEMP_DIR/firewall/openports.json" /etc/firewall/

    if [ "$FULL_RESTORE" = true ]; then
        echo "  [*] Full restore mode..."
        echo ""

        # Firewall scripts
        echo "  [*] Restoring firewall scripts..."
        [ -f "$TEMP_DIR/firewall/firewall.sh" ] && cp "$TEMP_DIR/firewall/firewall.sh" /etc/firewall/ && chmod +x /etc/firewall/firewall.sh
        [ -d "$TEMP_DIR/firewall/monitor" ] && cp -r "$TEMP_DIR/firewall/monitor" /etc/firewall/

        # Sysctl
        echo "  [*] Restoring sysctl..."
        [ -f "$TEMP_DIR/sysctl/99-charizard.conf" ] && cp "$TEMP_DIR/sysctl/99-charizard.conf" /etc/sysctl.d/

        # Systemd
        echo "  [*] Restoring systemd services..."
        for f in "$TEMP_DIR/systemd/"*.service "$TEMP_DIR/systemd/"*.timer; do
            [ -f "$f" ] && cp "$f" /etc/systemd/system/
        done

        # Rsyslog & logrotate
        echo "  [*] Restoring logging config..."
        [ -f "$TEMP_DIR/rsyslog/10-charizard.conf" ] && cp "$TEMP_DIR/rsyslog/10-charizard.conf" /etc/rsyslog.d/
        [ -f "$TEMP_DIR/logrotate/charizard" ] && cp "$TEMP_DIR/logrotate/charizard" /etc/logrotate.d/

        # Fail2ban
        echo "  [*] Restoring fail2ban..."
        [ -f "$TEMP_DIR/fail2ban/charizard.conf" ] && cp "$TEMP_DIR/fail2ban/charizard.conf" /etc/fail2ban/action.d/
        [ -f "$TEMP_DIR/fail2ban/jail.local" ] && cp "$TEMP_DIR/fail2ban/jail.local" /etc/fail2ban/

        # Bash
        echo "  [*] Restoring bash customizations..."
        for f in "$TEMP_DIR/profile/"*.sh; do
            [ -f "$f" ] && cp "$f" /etc/profile.d/
        done

        # Vim & Screen
        echo "  [*] Restoring vim & screen..."
        [ -f "$TEMP_DIR/vim/vimrc.local" ] && cp "$TEMP_DIR/vim/vimrc.local" /etc/vim/
        [ -f "$TEMP_DIR/screenrc" ] && cp "$TEMP_DIR/screenrc" /etc/

        # iptables (optional - don't auto-apply)
        echo ""
        echo "  [!] iptables rules backed up but NOT auto-restored"
        echo "      To restore manually:"
        echo "      tar -xzf $RESTORE_FILE -C /tmp iptables/"
        echo "      iptables-restore < /tmp/iptables/rules.v4"

        # Reload services
        echo ""
        echo "  [*] Reloading services..."
        systemctl daemon-reload 2>/dev/null
        sysctl --system >/dev/null 2>&1
    fi

    rm -rf "$TEMP_DIR"

    echo ""
    echo "  [✓] Restore complete"
    echo ""
    if [ "$FULL_RESTORE" = false ]; then
        echo "  [*] Config restored. Run 'charizard apply' to activate."
    else
        echo "  [*] Full restore done. Run 'charizard apply' to activate firewall."
    fi
    echo ""
    ;;
report)
    # Generate a comprehensive firewall report
    REPORT_DATE=$(date '+%Y-%m-%d %H:%M:%S')
    HOSTNAME=$(hostname)
    IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
    UPTIME=$(uptime -p | sed 's/up //')
    LOAD=$(cut -d' ' -f1-3 /proc/loadavg)

    # Traffic stats from iptables
    IPTABLES_OUT=$(iptables -nvL INPUT 2>/dev/null)
    PKTS_ACCEPT=$(echo "$IPTABLES_OUT" | awk '/RELATED,ESTABLISHED/ {print $1}' | head -1)
    PKTS_DROP=$(echo "$IPTABLES_OUT" | awk '/^Chain INPUT \(policy DROP/ {gsub(/[^0-9]/,"",$4); print $4}')
    PKTS_BLACKLIST=$(echo "$IPTABLES_OUT" | awk '/match-set blacklist src/ {print $1}' | head -1)
    PKTS_SPAMHAUS=$(echo "$IPTABLES_OUT" | awk '/match-set spamhaus src/ {print $1}' | head -1)
    PKTS_SCAN=$(iptables -nvL INPUT 2>/dev/null | awk '/CHARIZARD_SCAN/ {sum+=$1} END {print sum+0}')

    # ipset counts
    WL_COUNT=$(ipset list whitelist 2>/dev/null | grep -c "^[0-9]")
    BL_COUNT=$(ipset list blacklist 2>/dev/null | grep -c "^[0-9]")
    SH_COUNT=$(ipset list spamhaus 2>/dev/null | grep -c "^[0-9]")
    F2B_COUNT=$(ipset list fail2ban 2>/dev/null | grep -c "^[0-9]")

    # Connections
    CONN_COUNT=$(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)

    # Top attackers from log
    TOP_ATTACKERS=$(grep -oE 'SRC=[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/charizard.log 2>/dev/null | \
        cut -d= -f2 | sort | uniq -c | sort -rn | head -5)

    # Top targeted ports
    TOP_PORTS=$(grep -oE 'DPT=[0-9]+' /var/log/charizard.log 2>/dev/null | \
        cut -d= -f2 | sort | uniq -c | sort -rn | head -5)

    # Fail2ban stats
    F2B_BANNED=0
    F2B_TOTAL=0
    if command -v fail2ban-client &>/dev/null; then
        F2B_STATUS=$(fail2ban-client status sshd 2>/dev/null)
        F2B_BANNED=$(echo "$F2B_STATUS" | grep "Currently banned" | awk '{print $NF}')
        F2B_TOTAL=$(echo "$F2B_STATUS" | grep "Total banned" | awk '{print $NF}')
    fi

    # Output format
    OUTPUT_FORMAT="${2:-text}"

    if [ "$OUTPUT_FORMAT" = "json" ]; then
        # JSON output for Telegram/API
        cat <<JSONEOF
{
  "generated": "$REPORT_DATE",
  "hostname": "$HOSTNAME",
  "ip": "$IP",
  "uptime": "$UPTIME",
  "load": "$LOAD",
  "traffic": {
    "accepted": "${PKTS_ACCEPT:-0}",
    "dropped": "${PKTS_DROP:-0}",
    "blacklist": "${PKTS_BLACKLIST:-0}",
    "spamhaus": "${PKTS_SPAMHAUS:-0}",
    "scans": "${PKTS_SCAN:-0}"
  },
  "ipsets": {
    "whitelist": $WL_COUNT,
    "blacklist": $BL_COUNT,
    "spamhaus": $SH_COUNT,
    "fail2ban": $F2B_COUNT
  },
  "connections": $CONN_COUNT,
  "fail2ban": {
    "banned": ${F2B_BANNED:-0},
    "total": ${F2B_TOTAL:-0}
  }
}
JSONEOF
    else
        # Text output
        echo ""
        echo "  ╔===============================================================╗"
        echo "  ║             🔥 CHARIZARD FIREWALL REPORT                      ║"
        echo "  ╠===============================================================╣"
        echo "  ║  Generated: $REPORT_DATE"
        echo "  ║  Host: $HOSTNAME ($IP)"
        echo "  ║  Uptime: $UPTIME"
        echo "  ║  Load: $LOAD"
        echo "  ╠===============================================================╣"
        echo "  ║  TRAFFIC STATS                                                ║"
        echo "  ╟---------------------------------------------------------------╢"
        printf "  ║  %-20s %15s pkts                      ║\n" "Accepted:" "${PKTS_ACCEPT:-0}"
        printf "  ║  %-20s %15s pkts                      ║\n" "Dropped (policy):" "${PKTS_DROP:-0}"
        printf "  ║  %-20s %15s pkts                      ║\n" "Blacklist hits:" "${PKTS_BLACKLIST:-0}"
        printf "  ║  %-20s %15s pkts                      ║\n" "Spamhaus hits:" "${PKTS_SPAMHAUS:-0}"
        printf "  ║  %-20s %15s pkts                      ║\n" "Scan attempts:" "${PKTS_SCAN:-0}"
        echo "  ╠===============================================================╣"
        echo "  ║  IP SETS                                                      ║"
        echo "  ╟---------------------------------------------------------------╢"
        printf "  ║  Whitelist: %-6s  Blacklist: %-6s  Spamhaus: %-6s      ║\n" "$WL_COUNT" "$BL_COUNT" "$SH_COUNT"
        printf "  ║  Fail2ban:  %-6s  Connections: %-6s                       ║\n" "$F2B_COUNT" "$CONN_COUNT"
        echo "  ╠===============================================================╣"
        echo "  ║  FAIL2BAN                                                     ║"
        echo "  ╟---------------------------------------------------------------╢"
        printf "  ║  Currently banned: %-5s    Total banned: %-8s           ║\n" "${F2B_BANNED:-0}" "${F2B_TOTAL:-0}"
        echo "  ╠===============================================================╣"
        echo "  ║  TOP 5 ATTACKERS                                              ║"
        echo "  ╟---------------------------------------------------------------╢"
        if [ -n "$TOP_ATTACKERS" ]; then
            echo "$TOP_ATTACKERS" | while read -r count ip; do
                printf "  ║    %-18s %8s hits                            ║\n" "$ip" "$count"
            done
        else
            echo "  ║    No attacks logged                                          ║"
        fi
        echo "  ╠===============================================================╣"
        echo "  ║  TOP 5 TARGETED PORTS                                         ║"
        echo "  ╟---------------------------------------------------------------╢"
        if [ -n "$TOP_PORTS" ]; then
            echo "$TOP_PORTS" | while read -r count port; do
                printf "  ║    Port %-6s %12s attempts                         ║\n" "$port" "$count"
            done
        else
            echo "  ║    No port scans logged                                       ║"
        fi
        echo "  ╚===============================================================╝"
        echo ""
    fi
    ;;
doctor)
    echo ""
    echo "  === CHARIZARD HEALTH CHECK ==="
    echo ""
    ISSUES=0
    WARNINGS=0

    # Dependencies
    echo "  DEPENDENCIES"
    for cmd in iptables ip6tables ipset jq host curl; do
        if command -v $cmd &>/dev/null; then
            ver=$($cmd --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.?[0-9]*' | head -1)
            echo -e "  \033[38;5;142m[✓]\033[0m $cmd ${ver:+v$ver}"
        else
            echo -e "  \033[38;5;160m[✗]\033[0m $cmd NOT FOUND"
            ((ISSUES++))
        fi
    done
    echo ""

    # Core Services
    echo "  CORE SERVICES"
    for svc in charizard.service fail2ban; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            if systemctl is-active "$svc" &>/dev/null; then
                echo -e "  \033[38;5;142m[✓]\033[0m $svc (enabled, running)"
            else
                echo -e "  \033[38;5;214m[!]\033[0m $svc (enabled, stopped)"
                ((WARNINGS++))
            fi
        else
            echo -e "  \033[38;5;160m[✗]\033[0m $svc (not enabled)"
            ((ISSUES++))
        fi
    done
    echo ""

    # Core Timers
    echo "  CORE TIMERS"
    for tmr in charizard-update.timer charizard-cache.timer charizard-spamhaus.timer; do
        if systemctl is-enabled "$tmr" &>/dev/null; then
            if systemctl is-active "$tmr" &>/dev/null; then
                NEXT=$(systemctl list-timers "$tmr" --no-pager 2>/dev/null | grep "$tmr" | awk '{print $1, $2}')
                echo -e "  \033[38;5;142m[✓]\033[0m $tmr (next: $NEXT)"
            else
                echo -e "  \033[38;5;214m[!]\033[0m $tmr (enabled, not active)"
                ((WARNINGS++))
            fi
        else
            echo -e "  \033[38;5;160m[✗]\033[0m $tmr (not enabled)"
            ((ISSUES++))
        fi
    done
    echo ""

    # Optional Services
    echo "  OPTIONAL SERVICES"
    for svc in charizard-bot.service charizard-report.timer charizard-s3-backup.timer; do
        if systemctl is-enabled "$svc" &>/dev/null; then
            if systemctl is-active "$svc" &>/dev/null; then
                echo -e "  \033[38;5;142m[✓]\033[0m $svc (enabled)"
            else
                echo -e "  \033[38;5;246m[○]\033[0m $svc (enabled, waiting)"
            fi
        else
            echo -e "  \033[38;5;246m[-]\033[0m $svc (not enabled)"
        fi
    done
    echo ""

    # Core Config Files
    echo "  CORE CONFIG"
    for f in /etc/firewall/whitelist.json /etc/firewall/openports.json; do
        if [ -f "$f" ]; then
            if jq empty "$f" 2>/dev/null; then
                COUNT=$(jq -r '.hosts // .ports | length' "$f" 2>/dev/null)
                echo -e "  \033[38;5;142m[✓]\033[0m $(basename $f) ($COUNT entries)"
            else
                echo -e "  \033[38;5;160m[✗]\033[0m $(basename $f) INVALID JSON"
                ((ISSUES++))
            fi
        else
            echo -e "  \033[38;5;160m[✗]\033[0m $(basename $f) NOT FOUND"
            ((ISSUES++))
        fi
    done
    # VERSION
    if [ -f /etc/firewall/VERSION ]; then
        VER=$(cat /etc/firewall/VERSION | tr -d '[:space:]')
        echo -e "  \033[38;5;142m[✓]\033[0m VERSION: $VER"
    else
        echo -e "  \033[38;5;214m[!]\033[0m VERSION file missing"
        ((WARNINGS++))
    fi
    echo ""

    # Optional Config Files
    echo "  OPTIONAL CONFIG"
    for f in /etc/firewall/telegram.json /etc/firewall/s3-backup.json; do
        if [ -f "$f" ]; then
            if jq empty "$f" 2>/dev/null; then
                ENABLED=$(jq -r '.enabled // .bot_token' "$f" 2>/dev/null | head -c 10)
                echo -e "  \033[38;5;142m[✓]\033[0m $(basename $f) (configured)"
            else
                echo -e "  \033[38;5;214m[!]\033[0m $(basename $f) INVALID JSON"
                ((WARNINGS++))
            fi
        else
            echo -e "  \033[38;5;246m[-]\033[0m $(basename $f) (not configured)"
        fi
    done
    echo ""

    # Symlinks
    echo "  SYMLINKS"
    for link in /usr/local/bin/charizard /usr/local/bin/cmon; do
        if [ -L "$link" ]; then
            TARGET=$(readlink -f "$link")
            if [ -x "$TARGET" ]; then
                echo -e "  \033[38;5;142m[✓]\033[0m $link → $TARGET"
            else
                echo -e "  \033[38;5;160m[✗]\033[0m $link → target not executable"
                ((ISSUES++))
            fi
        else
            echo -e "  \033[38;5;160m[✗]\033[0m $link NOT FOUND"
            ((ISSUES++))
        fi
    done
    echo ""

    # Firewall status
    echo "  FIREWALL STATUS"
    POLICY=$(iptables -L INPUT 2>/dev/null | head -1 | grep -oE '\(policy [A-Z]+\)' | tr -d '()')
    if [ "$POLICY" = "policy DROP" ]; then
        echo -e "  \033[38;5;142m[✓]\033[0m INPUT policy: DROP (secure)"
    else
        echo -e "  \033[38;5;214m[!]\033[0m INPUT policy: ${POLICY:-UNKNOWN}"
        ((WARNINGS++))
    fi
    RULES4=$(iptables -L INPUT 2>/dev/null | wc -l)
    RULES6=$(ip6tables -L INPUT 2>/dev/null | wc -l)
    echo -e "  \033[38;5;142m[✓]\033[0m IPv4 rules: $((RULES4-2))"
    echo -e "  \033[38;5;142m[✓]\033[0m IPv6 rules: $((RULES6-2))"
    echo ""

    # ipsets
    echo "  IPSETS"
    for set in whitelist blacklist spamhaus spamhaus6 fail2ban; do
        if ipset list $set &>/dev/null; then
            count=$(ipset list $set 2>/dev/null | grep -cE "^[0-9a-fA-F]")
            echo -e "  \033[38;5;142m[✓]\033[0m $set: $count entries"
        else
            if [ "$set" = "fail2ban" ]; then
                echo -e "  \033[38;5;246m[-]\033[0m $set: not created (no bans yet)"
            else
                echo -e "  \033[38;5;214m[!]\033[0m $set: not found"
                ((WARNINGS++))
            fi
        fi
    done
    echo ""

    # Kernel hardening
    echo "  KERNEL HARDENING"
    SYSCTL_OK=0
    SYSCTL_WARN=0
    for param in "net.ipv4.tcp_syncookies=1" "net.ipv4.conf.all.rp_filter=1" "kernel.randomize_va_space=2"; do
        KEY=$(echo "$param" | cut -d= -f1)
        EXPECTED=$(echo "$param" | cut -d= -f2)
        ACTUAL=$(sysctl -n "$KEY" 2>/dev/null)
        if [ "$ACTUAL" = "$EXPECTED" ]; then
            ((SYSCTL_OK++))
        else
            ((SYSCTL_WARN++))
        fi
    done
    if [ $SYSCTL_WARN -eq 0 ]; then
        echo -e "  \033[38;5;142m[✓]\033[0m sysctl hardening: $SYSCTL_OK checks passed"
    else
        echo -e "  \033[38;5;214m[!]\033[0m sysctl hardening: $SYSCTL_WARN issues (run: sysctl --system)"
        ((WARNINGS++))
    fi
    echo ""

    # Log file
    echo "  LOGS"
    if [ -f /var/log/charizard.log ]; then
        SIZE=$(du -h /var/log/charizard.log 2>/dev/null | awk '{print $1}')
        LINES=$(wc -l < /var/log/charizard.log 2>/dev/null)
        echo -e "  \033[38;5;142m[✓]\033[0m /var/log/charizard.log ($SIZE, $LINES lines)"
    else
        echo -e "  \033[38;5;246m[-]\033[0m /var/log/charizard.log (empty/not created)"
    fi

    # Spamhaus age
    if [ -f /etc/firewall/spamhaus_drop.txt ]; then
        SH_AGE=$(( ($(date +%s) - $(stat -c %Y /etc/firewall/spamhaus_drop.txt)) / 3600 ))
        if [ "$SH_AGE" -gt 12 ]; then
            echo -e "  \033[38;5;214m[!]\033[0m Spamhaus last update: ${SH_AGE}h ago (stale)"
            ((WARNINGS++))
        else
            echo -e "  \033[38;5;142m[✓]\033[0m Spamhaus last update: ${SH_AGE}h ago"
        fi
    fi
    echo ""

    # Summary
    echo "  ==================================="
    if [ $ISSUES -eq 0 ] && [ $WARNINGS -eq 0 ]; then
        echo -e "  \033[38;5;142m STATUS: HEALTHY \033[0m"
    elif [ $ISSUES -eq 0 ]; then
        echo -e "  \033[38;5;214m STATUS: OK ($WARNINGS warnings) \033[0m"
    else
        echo -e "  \033[38;5;160m STATUS: UNHEALTHY ($ISSUES issues, $WARNINGS warnings) \033[0m"
    fi
    echo ""
    ;;
telegram|tg)
    TELEGRAM_SCRIPT="/etc/firewall/telegram.sh"
    case "$2" in
        test)
            if [ ! -f "$TELEGRAM_SCRIPT" ]; then
                echo "  [✗] Telegram bot not installed"
                echo "  [*] Run install.sh to set up the bot"
                exit 1
            fi
            "$TELEGRAM_SCRIPT" test
            ;;
        start)
            echo "  [*] Starting Telegram bot in foreground..."
            echo "  [*] Press Ctrl+C to stop"
            "$TELEGRAM_SCRIPT" start
            ;;
        status)
            echo ""
            echo "  === TELEGRAM BOT STATUS ==="
            echo ""
            if systemctl is-active charizard-bot &>/dev/null; then
                echo -e "  \033[38;5;142m[✓]\033[0m Bot service: running"
            else
                echo -e "  \033[38;5;160m[✗]\033[0m Bot service: stopped"
            fi
            if [ -f /etc/firewall/telegram.json ]; then
                CHAT_COUNT=$(jq '.chat_ids | length' /etc/firewall/telegram.json 2>/dev/null || echo 0)
                echo -e "  \033[38;5;142m[✓]\033[0m Config: found ($CHAT_COUNT chat IDs)"
            else
                echo -e "  \033[38;5;160m[✗]\033[0m Config: not found"
            fi
            if systemctl is-active charizard-report.timer &>/dev/null; then
                echo -e "  \033[38;5;142m[✓]\033[0m Daily report: enabled"
            else
                echo -e "  \033[38;5;214m[!]\033[0m Daily report: disabled"
            fi
            echo ""
            ;;
        report)
            "$TELEGRAM_SCRIPT" report
            echo "  [✓] Report sent to Telegram"
            ;;
        enable)
            systemctl enable charizard-bot charizard-report.timer 2>/dev/null
            systemctl start charizard-bot charizard-report.timer 2>/dev/null
            echo "  [✓] Telegram bot enabled and started"
            ;;
        disable)
            systemctl stop charizard-bot charizard-report.timer 2>/dev/null
            systemctl disable charizard-bot charizard-report.timer 2>/dev/null
            echo "  [✓] Telegram bot disabled"
            ;;
        *)
            echo ""
            echo "  === TELEGRAM BOT ==="
            echo ""
            echo "  Usage: charizard telegram <command>"
            echo ""
            echo "  Commands:"
            echo "    test     Send test message"
            echo "    status   Show bot status"
            echo "    start    Run bot in foreground (debug)"
            echo "    report   Send report now"
            echo "    enable   Enable bot service"
            echo "    disable  Disable bot service"
            echo ""
            ;;
    esac
    ;;
notify)
    NOTIFY_SCRIPT="/etc/firewall/notify.sh"
    case "$2" in
        status)
            if [ -x "$NOTIFY_SCRIPT" ]; then
                "$NOTIFY_SCRIPT" status
            else
                echo "  [!] Notify module not installed"
            fi
            ;;
        check)
            if [ -x "$NOTIFY_SCRIPT" ]; then
                "$NOTIFY_SCRIPT" check
                echo "  [✓] Check completed"
            else
                echo "  [!] Notify module not installed"
            fi
            ;;
        reset)
            if [ -x "$NOTIFY_SCRIPT" ]; then
                "$NOTIFY_SCRIPT" reset
            fi
            ;;
        enable)
            systemctl enable --now charizard-notify.timer 2>/dev/null
            echo "  [✓] Notify timer enabled (spike/scan detection every 5min)"
            ;;
        disable)
            systemctl stop charizard-notify.timer 2>/dev/null
            systemctl disable charizard-notify.timer 2>/dev/null
            echo "  [✓] Notify timer disabled"
            ;;
        *)
            echo ""
            echo "  === NOTIFY MODULE ==="
            echo ""
            echo "  Usage: charizard notify <command>"
            echo ""
            echo "  Commands:"
            echo "    status   Show notify module status"
            echo "    check    Run spike/scan check manually"
            echo "    reset    Reset state (clears alert cooldowns)"
            echo "    enable   Enable notify timer (auto-check every 5min)"
            echo "    disable  Disable notify timer"
            echo ""
            ;;
    esac
    ;;
disk)
    case "$2" in
        usage|"")
            echo ""
            echo "  === DISK USAGE ==="
            echo ""
            echo "  PARTITIONS"
            df -h | grep -E '^/dev|Filesystem' | awk '{printf "  %-20s %8s %8s %8s %6s %s\n", $1, $2, $3, $4, $5, $6}'
            echo ""
            echo "  TOP DIRECTORIES"
            du -sh /var/* /home/* /tmp/* /root/* 2>/dev/null | sort -hr | head -10 | sed 's/^/  /'
            echo ""
            # Docker if exists
            if command -v docker &>/dev/null; then
                DOCKER_SIZE=$(docker system df 2>/dev/null | awk '/Images|Containers|Volumes/ {printf "%s: %s  ", $1, $4}')
                [ -n "$DOCKER_SIZE" ] && echo "  DOCKER: $DOCKER_SIZE" && echo ""
            fi
            ;;
        find)
            SIZE="${3:-100M}"
            echo ""
            echo "  === FILES > $SIZE ==="
            echo ""
            find / -type f -size +$SIZE 2>/dev/null | head -20 | while read f; do
                ls -lh "$f" 2>/dev/null | awk '{printf "  %8s  %s\n", $5, $9}'
            done
            echo ""
            ;;
        clean)
            echo ""
            echo "  === CLEANUP SUGGESTIONS ==="
            echo ""
            # Journal
            JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oE '[0-9.]+[GMK]')
            echo "  JOURNAL: $JOURNAL_SIZE"
            echo "    sudo journalctl --vacuum-size=100M"
            echo ""
            # Apt cache
            APT_SIZE=$(du -sh /var/cache/apt/archives 2>/dev/null | awk '{print $1}')
            echo "  APT CACHE: $APT_SIZE"
            echo "    sudo apt-get clean"
            echo ""
            # Old kernels
            KERNELS=$(dpkg -l 'linux-image-*' 2>/dev/null | grep ^ii | wc -l)
            echo "  KERNELS: $KERNELS installed"
            echo "    sudo apt-get autoremove --purge"
            echo ""
            # Logs
            LOG_SIZE=$(du -sh /var/log 2>/dev/null | awk '{print $1}')
            echo "  LOGS: $LOG_SIZE"
            echo "    find /var/log -name '*.gz' -delete"
            echo ""
            # Docker
            if command -v docker &>/dev/null; then
                echo "  DOCKER:"
                echo "    docker system prune -a"
                echo ""
            fi
            ;;
        *)
            echo ""
            echo "  Usage: charizard disk [command]"
            echo ""
            echo "  Commands:"
            echo "    usage       Disk overview (default)"
            echo "    find SIZE   Find files > SIZE (default 100M)"
            echo "    clean       Cleanup suggestions"
            echo ""
            ;;
    esac
    ;;
io)
    case "$2" in
        top)
            echo ""
            echo "  === TOP I/O PROCESSES ==="
            echo ""
            if command -v iotop &>/dev/null; then
                iotop -b -n 1 -o 2>/dev/null | head -15 | sed 's/^/  /'
            else
                echo "  [!] iotop not installed"
                echo "  [*] Install with: apt-get install iotop-c"
            fi
            echo ""
            ;;
        watch)
            if command -v iotop &>/dev/null; then
                iotop -o
            else
                echo "  [!] iotop not installed"
            fi
            ;;
        stats|"")
            echo ""
            echo "  === I/O STATISTICS ==="
            echo ""
            # iowait from top
            IOWAIT=$(top -bn1 | grep "Cpu" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /wa/) print $i}' | grep -oE '[0-9.]+')
            echo "  I/O WAIT: ${IOWAIT:-0}%"
            echo ""
            # iostat
            if command -v iostat &>/dev/null; then
                echo "  DISK I/O (iostat)"
                iostat -x 1 1 2>/dev/null | tail -n +6 | head -10 | sed 's/^/  /'
            fi
            echo ""
            # vmstat
            echo "  SYSTEM (vmstat)"
            vmstat 1 3 2>/dev/null | sed 's/^/  /'
            echo ""
            ;;
        *)
            echo ""
            echo "  Usage: charizard io [command]"
            echo ""
            echo "  Commands:"
            echo "    stats       I/O statistics (default)"
            echo "    top         Top I/O processes (iotop)"
            echo "    watch       Live I/O monitoring"
            echo ""
            ;;
    esac
    ;;
timers)
    case "$2" in
        all)
            echo ""
            echo "  === ALL SYSTEM TIMERS ==="
            echo ""
            systemctl list-timers --all --no-pager | head -25 | sed 's/^/  /'
            echo ""
            ;;
        next)
            echo ""
            echo "  === NEXT EXECUTIONS ==="
            echo ""
            systemctl list-timers --no-pager | head -15 | sed 's/^/  /'
            echo ""
            ;;
        "")
            echo ""
            echo "  === CHARIZARD TIMERS ==="
            echo ""
            systemctl list-timers charizard-* --no-pager 2>/dev/null | sed 's/^/  /'
            echo ""
            echo "  STATUS"
            for timer in charizard-update charizard-spamhaus charizard-report; do
                if systemctl is-active ${timer}.timer &>/dev/null; then
                    NEXT=$(systemctl list-timers ${timer}.timer --no-pager 2>/dev/null | grep ${timer} | awk '{print $1, $2}')
                    echo -e "  \033[38;5;142m[✓]\033[0m ${timer}.timer active - next: $NEXT"
                else
                    echo -e "  \033[38;5;214m[!]\033[0m ${timer}.timer inactive"
                fi
            done
            echo ""
            ;;
        *)
            echo ""
            echo "  Usage: charizard timers [command]"
            echo ""
            echo "  Commands:"
            echo "    (none)      Show charizard timers (default)"
            echo "    all         All system timers"
            echo "    next        Next scheduled executions"
            echo ""
            ;;
    esac
    ;;
s3)
    S3_CONFIG="/etc/firewall/s3-backup.json"
    S3_LOG="/var/log/charizard-s3.log"

    # Check rclone
    if ! command -v rclone &>/dev/null; then
        echo "  [✗] rclone not installed"
        echo "  [*] Install with: curl https://rclone.org/install.sh | sudo bash"
        exit 1
    fi

    case "$2" in
        status)
            echo ""
            echo "  === S3 BACKUP STATUS ==="
            echo ""
            if [ ! -f "$S3_CONFIG" ]; then
                echo -e "  \033[38;5;160m[✗]\033[0m Config not found: $S3_CONFIG"
                echo "  [*] Copy s3-backup.example.json to $S3_CONFIG"
                exit 1
            fi
            ENABLED=$(jq -r '.enabled' "$S3_CONFIG")
            PROVIDER=$(jq -r '.provider' "$S3_CONFIG")
            BUCKET=$(jq -r '.bucket' "$S3_CONFIG")
            REGION=$(jq -r '.region' "$S3_CONFIG")
            RETENTION=$(jq -r '.retention_days' "$S3_CONFIG")

            if [ "$ENABLED" = "true" ]; then
                echo -e "  \033[38;5;142m[✓]\033[0m S3 backup: enabled"
            else
                echo -e "  \033[38;5;214m[!]\033[0m S3 backup: disabled"
            fi
            echo "  Provider: $PROVIDER"
            echo "  Bucket: $BUCKET"
            echo "  Region: $REGION"
            echo "  Retention: ${RETENTION} days"
            echo ""
            # Timer status
            if systemctl is-active charizard-s3-backup.timer &>/dev/null; then
                NEXT=$(systemctl list-timers charizard-s3-backup.timer --no-pager 2>/dev/null | grep charizard-s3 | awk '{print $1, $2}')
                echo -e "  \033[38;5;142m[✓]\033[0m Timer active - next: $NEXT"
            else
                echo -e "  \033[38;5;214m[!]\033[0m Timer inactive"
            fi
            # Last backup
            if [ -f "$S3_LOG" ]; then
                LAST=$(grep "Backup completed" "$S3_LOG" 2>/dev/null | tail -1)
                [ -n "$LAST" ] && echo "  Last: $LAST"
            fi
            echo ""
            ;;
        test)
            echo "  [*] Testing S3 connection..."
            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [✗] Config not found: $S3_CONFIG"
                exit 1
            fi

            PROVIDER=$(jq -r '.provider' "$S3_CONFIG")
            ENDPOINT=$(jq -r '.endpoint // empty' "$S3_CONFIG")
            REGION=$(jq -r '.region' "$S3_CONFIG")
            BUCKET=$(jq -r '.bucket' "$S3_CONFIG")
            ACCESS_KEY=$(jq -r '.access_key' "$S3_CONFIG")
            SECRET_KEY=$(jq -r '.secret_key' "$S3_CONFIG")

            # Create rclone config on the fly
            export RCLONE_CONFIG_CHARIZARD_TYPE="s3"
            export RCLONE_CONFIG_CHARIZARD_PROVIDER="$PROVIDER"
            export RCLONE_CONFIG_CHARIZARD_ACCESS_KEY_ID="$ACCESS_KEY"
            export RCLONE_CONFIG_CHARIZARD_SECRET_ACCESS_KEY="$SECRET_KEY"
            export RCLONE_CONFIG_CHARIZARD_REGION="$REGION"
            [ -n "$ENDPOINT" ] && export RCLONE_CONFIG_CHARIZARD_ENDPOINT="$ENDPOINT"

            if rclone lsd charizard:"$BUCKET" &>/dev/null; then
                echo -e "  \033[38;5;142m[✓]\033[0m Connection successful"
                echo "  Bucket: $BUCKET"
                SIZE=$(rclone size charizard:"$BUCKET" 2>/dev/null | grep "Total size" | awk '{print $3, $4}')
                [ -n "$SIZE" ] && echo "  Size: $SIZE"
            else
                echo -e "  \033[38;5;160m[✗]\033[0m Connection failed"
                echo "  [*] Check credentials and bucket name"
            fi
            ;;
        backup)
            echo "  [*] Starting S3 backup..."
            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [✗] Config not found: $S3_CONFIG"
                exit 1
            fi

            PROVIDER=$(jq -r '.provider' "$S3_CONFIG")
            ENDPOINT=$(jq -r '.endpoint // empty' "$S3_CONFIG")
            REGION=$(jq -r '.region' "$S3_CONFIG")
            BUCKET=$(jq -r '.bucket' "$S3_CONFIG")
            ACCESS_KEY=$(jq -r '.access_key' "$S3_CONFIG")
            SECRET_KEY=$(jq -r '.secret_key' "$S3_CONFIG")
            S3_PATH=$(jq -r '.path // empty' "$S3_CONFIG")
            COMPRESSION=$(jq -r '.compression // "gz"' "$S3_CONFIG")
            NOTIFY_SUCCESS=$(jq -r '.notifications.success // false' "$S3_CONFIG")
            NOTIFY_FAILURE=$(jq -r '.notifications.failure // true' "$S3_CONFIG")

            # Setup rclone env
            export RCLONE_CONFIG_CHARIZARD_TYPE="s3"
            export RCLONE_CONFIG_CHARIZARD_PROVIDER="$PROVIDER"
            export RCLONE_CONFIG_CHARIZARD_ACCESS_KEY_ID="$ACCESS_KEY"
            export RCLONE_CONFIG_CHARIZARD_SECRET_ACCESS_KEY="$SECRET_KEY"
            export RCLONE_CONFIG_CHARIZARD_REGION="$REGION"
            [ -n "$ENDPOINT" ] && export RCLONE_CONFIG_CHARIZARD_ENDPOINT="$ENDPOINT"

            HOSTNAME=$(hostname)
            DATE=$(date '+%Y%m%d_%H%M%S')
            BACKUP_NAME="charizard_${HOSTNAME}_${DATE}.tar.${COMPRESSION}"
            TEMP_DIR=$(mktemp -d)
            BACKUP_FILE="$TEMP_DIR/$BACKUP_NAME"

            # Get folders to backup
            FOLDERS=$(jq -r '.folders[]' "$S3_CONFIG" 2>/dev/null)
            EXCLUDES=$(jq -r '.exclude[]' "$S3_CONFIG" 2>/dev/null | sed 's/^/--exclude=/' | tr '\n' ' ')

            echo "  [*] Creating archive..."
            # Create tar with folders that exist
            TAR_FILES=""
            for folder in $FOLDERS; do
                [ -e "$folder" ] && TAR_FILES="$TAR_FILES $folder"
            done

            if [ -z "$TAR_FILES" ]; then
                echo "  [✗] No files to backup"
                rm -rf "$TEMP_DIR"
                exit 1
            fi

            case "$COMPRESSION" in
                gz) tar -czf "$BACKUP_FILE" $EXCLUDES $TAR_FILES 2>/dev/null ;;
                xz) tar -cJf "$BACKUP_FILE" $EXCLUDES $TAR_FILES 2>/dev/null ;;
                zst) tar -I zstd -cf "$BACKUP_FILE" $EXCLUDES $TAR_FILES 2>/dev/null ;;
                *) tar -czf "$BACKUP_FILE" $EXCLUDES $TAR_FILES 2>/dev/null ;;
            esac

            SIZE=$(du -h "$BACKUP_FILE" | awk '{print $1}')
            echo "  [*] Archive: $BACKUP_NAME ($SIZE)"

            # Upload to S3
            REMOTE_PATH="charizard:$BUCKET"
            [ -n "$S3_PATH" ] && REMOTE_PATH="$REMOTE_PATH/$S3_PATH"

            echo "  [*] Uploading to S3..."
            if rclone copy "$BACKUP_FILE" "$REMOTE_PATH/" --progress 2>&1 | grep -E '%|Transferred'; then
                echo -e "  \033[38;5;142m[✓]\033[0m Backup uploaded successfully"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup completed: $BACKUP_NAME ($SIZE)" >> "$S3_LOG"

                # Telegram notification
                if [ "$NOTIFY_SUCCESS" = "true" ] && [ -f /etc/firewall/telegram.sh ]; then
                    /etc/firewall/telegram.sh alert backup "☁️ <b>S3 Backup Success</b>

<b>File:</b> $BACKUP_NAME
<b>Size:</b> $SIZE
<b>Bucket:</b> $BUCKET"
                fi
            else
                echo -e "  \033[38;5;160m[✗]\033[0m Upload failed"
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup FAILED: $BACKUP_NAME" >> "$S3_LOG"

                if [ "$NOTIFY_FAILURE" = "true" ] && [ -f /etc/firewall/telegram.sh ]; then
                    /etc/firewall/telegram.sh alert backup "❌ <b>S3 Backup Failed</b>

<b>Host:</b> $HOSTNAME
<b>Time:</b> $(date '+%Y-%m-%d %H:%M:%S')"
                fi
                rm -rf "$TEMP_DIR"
                exit 1
            fi

            rm -rf "$TEMP_DIR"

            # Cleanup old backups
            RETENTION=$(jq -r '.retention_days // 3' "$S3_CONFIG")
            echo "  [*] Cleaning backups older than ${RETENTION} days..."
            rclone delete "$REMOTE_PATH/" --min-age "${RETENTION}d" 2>/dev/null
            echo -e "  \033[38;5;142m[✓]\033[0m Done"
            ;;
        list)
            echo ""
            echo "  === S3 BACKUPS ==="
            echo ""
            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [✗] Config not found"
                exit 1
            fi

            PROVIDER=$(jq -r '.provider' "$S3_CONFIG")
            ENDPOINT=$(jq -r '.endpoint // empty' "$S3_CONFIG")
            REGION=$(jq -r '.region' "$S3_CONFIG")
            BUCKET=$(jq -r '.bucket' "$S3_CONFIG")
            ACCESS_KEY=$(jq -r '.access_key' "$S3_CONFIG")
            SECRET_KEY=$(jq -r '.secret_key' "$S3_CONFIG")
            S3_PATH=$(jq -r '.path // empty' "$S3_CONFIG")

            export RCLONE_CONFIG_CHARIZARD_TYPE="s3"
            export RCLONE_CONFIG_CHARIZARD_PROVIDER="$PROVIDER"
            export RCLONE_CONFIG_CHARIZARD_ACCESS_KEY_ID="$ACCESS_KEY"
            export RCLONE_CONFIG_CHARIZARD_SECRET_ACCESS_KEY="$SECRET_KEY"
            export RCLONE_CONFIG_CHARIZARD_REGION="$REGION"
            [ -n "$ENDPOINT" ] && export RCLONE_CONFIG_CHARIZARD_ENDPOINT="$ENDPOINT"

            REMOTE_PATH="charizard:$BUCKET"
            [ -n "$S3_PATH" ] && REMOTE_PATH="$REMOTE_PATH/$S3_PATH"

            rclone ls "$REMOTE_PATH/" 2>/dev/null | grep "charizard_" | sort -r | head -20 | \
                awk '{printf "  %8.2f MB  %s\n", $1/1024/1024, $2}'
            echo ""
            ;;
        restore)
            if [ -z "$3" ]; then
                echo "  [*] Available backups:"
                $0 s3 list
                echo "  Usage: charizard s3 restore <filename>"
                exit 0
            fi

            FILENAME="$3"
            echo "  [*] Restoring $FILENAME..."

            PROVIDER=$(jq -r '.provider' "$S3_CONFIG")
            ENDPOINT=$(jq -r '.endpoint // empty' "$S3_CONFIG")
            REGION=$(jq -r '.region' "$S3_CONFIG")
            BUCKET=$(jq -r '.bucket' "$S3_CONFIG")
            ACCESS_KEY=$(jq -r '.access_key' "$S3_CONFIG")
            SECRET_KEY=$(jq -r '.secret_key' "$S3_CONFIG")
            S3_PATH=$(jq -r '.path // empty' "$S3_CONFIG")

            export RCLONE_CONFIG_CHARIZARD_TYPE="s3"
            export RCLONE_CONFIG_CHARIZARD_PROVIDER="$PROVIDER"
            export RCLONE_CONFIG_CHARIZARD_ACCESS_KEY_ID="$ACCESS_KEY"
            export RCLONE_CONFIG_CHARIZARD_SECRET_ACCESS_KEY="$SECRET_KEY"
            export RCLONE_CONFIG_CHARIZARD_REGION="$REGION"
            [ -n "$ENDPOINT" ] && export RCLONE_CONFIG_CHARIZARD_ENDPOINT="$ENDPOINT"

            REMOTE_PATH="charizard:$BUCKET"
            [ -n "$S3_PATH" ] && REMOTE_PATH="$REMOTE_PATH/$S3_PATH"

            TEMP_DIR=$(mktemp -d)

            echo "  [*] Downloading..."
            if rclone copy "$REMOTE_PATH/$FILENAME" "$TEMP_DIR/" --progress; then
                echo "  [*] Extracting to /..."
                tar -xzf "$TEMP_DIR/$FILENAME" -C / 2>/dev/null
                echo -e "  \033[38;5;142m[✓]\033[0m Restore complete"
                echo "  [*] Run 'charizard apply' to activate"
            else
                echo -e "  \033[38;5;160m[✗]\033[0m Download failed"
            fi
            rm -rf "$TEMP_DIR"
            ;;
        enable)
            systemctl enable charizard-s3-backup.timer 2>/dev/null
            systemctl start charizard-s3-backup.timer 2>/dev/null
            echo "  [✓] S3 backup timer enabled"
            ;;
        disable)
            systemctl stop charizard-s3-backup.timer 2>/dev/null
            systemctl disable charizard-s3-backup.timer 2>/dev/null
            echo "  [✓] S3 backup timer disabled"
            ;;
        folders)
            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [✗] Config not found: $S3_CONFIG"
                exit 1
            fi
            echo ""
            echo "  === BACKUP FOLDERS ==="
            echo ""
            jq -r '.folders[]' "$S3_CONFIG" 2>/dev/null | while read -r folder; do
                if [ -e "$folder" ]; then
                    echo -e "  \033[38;5;142m[✓]\033[0m $folder"
                else
                    echo -e "  \033[38;5;214m[!]\033[0m $folder (not found)"
                fi
            done
            echo ""
            ;;
        addf)
            if [ -z "$3" ]; then
                echo "  Usage: charizard s3 addf <path>"
                exit 1
            fi
            FOLDER="$3"
            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [✗] Config not found: $S3_CONFIG"
                exit 1
            fi
            # Check if already exists
            if jq -e ".folders | index(\"$FOLDER\")" "$S3_CONFIG" &>/dev/null; then
                echo "  [!] Folder already in backup list: $FOLDER"
                exit 0
            fi
            # Add folder
            jq ".folders += [\"$FOLDER\"]" "$S3_CONFIG" > "$S3_CONFIG.tmp" && mv "$S3_CONFIG.tmp" "$S3_CONFIG"
            if [ -e "$FOLDER" ]; then
                echo -e "  \033[38;5;142m[✓]\033[0m Added: $FOLDER"
            else
                echo -e "  \033[38;5;214m[✓]\033[0m Added: $FOLDER (path not found, will skip during backup)"
            fi
            ;;
        rmf)
            if [ -z "$3" ]; then
                echo "  Usage: charizard s3 rmf <path>"
                exit 1
            fi
            FOLDER="$3"
            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [✗] Config not found: $S3_CONFIG"
                exit 1
            fi
            # Check if exists
            if ! jq -e ".folders | index(\"$FOLDER\")" "$S3_CONFIG" &>/dev/null; then
                echo "  [!] Folder not in backup list: $FOLDER"
                exit 0
            fi
            # Remove folder
            jq "del(.folders[] | select(. == \"$FOLDER\"))" "$S3_CONFIG" > "$S3_CONFIG.tmp" && mv "$S3_CONFIG.tmp" "$S3_CONFIG"
            echo -e "  \033[38;5;142m[✓]\033[0m Removed: $FOLDER"
            ;;
        *)
            echo ""
            echo "  === S3 BACKUP ==="
            echo ""
            echo "  Usage: charizard s3 <command>"
            echo ""
            echo "  Commands:"
            echo "    status     Show backup status"
            echo "    test       Test S3 connection"
            echo "    backup     Backup now"
            echo "    list       List backups in S3"
            echo "    restore    Restore from backup"
            echo "    enable     Enable daily backup timer"
            echo "    disable    Disable backup timer"
            echo "    folders    List folders in backup"
            echo "    addf       Add folder to backup"
            echo "    rmf        Remove folder from backup"
            echo ""
            ;;
    esac
    ;;
upgrade)
    REPO_URL="https://github.com/sanvilscript/charizard.git"
    REMOTE_VERSION_URL="https://raw.githubusercontent.com/sanvilscript/charizard/main/VERSION"
    UPGRADE_DIR="/tmp/charizard-upgrade"
    BACKUP_DIR="/etc/firewall/backups"
    FORCE_UPGRADE=false

    [ "$2" = "force" ] || [ "$2" = "-f" ] && FORCE_UPGRADE=true

    echo ""
    echo "  === CHARIZARD UPGRADE ==="
    echo ""

    # Get current version
    if [ -f /etc/firewall/VERSION ]; then
        LOCAL_VER=$(cat /etc/firewall/VERSION | tr -d '[:space:]')
    else
        LOCAL_VER="unknown"
    fi

    # Get remote version
    echo "  [*] Checking for updates..."
    if command -v curl &>/dev/null; then
        REMOTE_VER=$(curl -fsSL "$REMOTE_VERSION_URL" 2>/dev/null | tr -d '[:space:]')
    elif command -v wget &>/dev/null; then
        REMOTE_VER=$(wget -qO- "$REMOTE_VERSION_URL" 2>/dev/null | tr -d '[:space:]')
    else
        echo "  [✗] curl or wget required"
        exit 1
    fi

    if [ -z "$REMOTE_VER" ]; then
        echo "  [✗] Could not fetch remote version"
        exit 1
    fi

    echo "  Local version:  $LOCAL_VER"
    echo "  Remote version: $REMOTE_VER"
    echo ""

    # Compare versions
    if [ "$LOCAL_VER" = "$REMOTE_VER" ] && [ "$FORCE_UPGRADE" = false ]; then
        echo -e "  \033[38;5;142m[✓]\033[0m Already up to date"
        echo ""
        echo "  Use 'charizard upgrade force' to reinstall anyway"
        echo ""
        exit 0
    fi

    # Create backup
    echo "  [*] Creating backup..."
    mkdir -p "$BACKUP_DIR"
    BACKUP_FILE="$BACKUP_DIR/backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    tar -czf "$BACKUP_FILE" -C /etc/firewall \
        firewall.sh VERSION \
        monitor/cmon.sh monitor/stats.sh \
        telegram.sh 2>/dev/null || true
    echo "  [✓] Backup: $BACKUP_FILE"

    # Clone repository
    echo "  [*] Downloading v$REMOTE_VER..."
    rm -rf "$UPGRADE_DIR" 2>/dev/null
    if ! git clone --depth 1 "$REPO_URL" "$UPGRADE_DIR" &>/dev/null; then
        echo "  [✗] Failed to download update"
        exit 1
    fi

    # Update scripts
    echo "  [*] Updating scripts..."
    cp "$UPGRADE_DIR/firewall.sh" /etc/firewall/
    cp "$UPGRADE_DIR/VERSION" /etc/firewall/
    cp "$UPGRADE_DIR/monitor/cmon.sh" /etc/firewall/monitor/
    cp "$UPGRADE_DIR/monitor/stats.sh" /etc/firewall/monitor/
    [ -f "$UPGRADE_DIR/modules/telegram.sh" ] && cp "$UPGRADE_DIR/modules/telegram.sh" /etc/firewall/
    [ -f "$UPGRADE_DIR/modules/notify.sh" ] && cp "$UPGRADE_DIR/modules/notify.sh" /etc/firewall/
    chmod +x /etc/firewall/firewall.sh
    chmod +x /etc/firewall/monitor/*.sh
    chmod +x /etc/firewall/telegram.sh 2>/dev/null || true
    chmod +x /etc/firewall/notify.sh 2>/dev/null || true
    # Install bash completion
    if [ -d /etc/bash_completion.d ] && [ -f "$UPGRADE_DIR/scripts/charizard-completion.bash" ]; then
        cp "$UPGRADE_DIR/scripts/charizard-completion.bash" /etc/bash_completion.d/charizard
    fi
    echo "  [✓] Scripts updated"

    # Update systemd services
    echo "  [*] Updating systemd services..."
    for svc in "$UPGRADE_DIR"/systemd/*.service "$UPGRADE_DIR"/systemd/*.timer; do
        [ -f "$svc" ] && cp "$svc" /etc/systemd/system/
    done
    systemctl daemon-reload
    echo "  [✓] Systemd reloaded"

    # Cleanup
    rm -rf "$UPGRADE_DIR"

    # Show result
    NEW_VER=$(cat /etc/firewall/VERSION | tr -d '[:space:]')
    echo ""
    echo "  ==================================="
    echo -e "  \033[38;5;142m UPGRADED: $LOCAL_VER → $NEW_VER \033[0m"
    echo "  ==================================="
    echo ""
    echo "  Run 'charizard doctor' to verify"
    echo ""
    exit 0
    ;;
install)
    case "$2" in
        docker)
            echo ""
            echo "  === INSTALL DOCKER ENGINE ==="
            echo ""

            # Check if script exists locally or download
            DOCKER_SCRIPT="$CONFIG_DIR/extra/docker-install.sh"
            if [ ! -f "$DOCKER_SCRIPT" ]; then
                echo "  [*] Downloading docker installer..."
                mkdir -p "$CONFIG_DIR/extra"
                curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/docker-install.sh" -o "$DOCKER_SCRIPT"
                chmod +x "$DOCKER_SCRIPT"
            fi

            # Run installer
            bash "$DOCKER_SCRIPT" install

            # Add docker folder to S3 backup
            echo ""
            echo "  === CONFIGURING S3 BACKUP ==="
            echo ""

            S3_CONFIG="$CONFIG_DIR/s3-backup.json"
            DOCKER_USER="${SUDO_USER:-debian}"
            DOCKER_PATH="/home/$DOCKER_USER/docker"

            if [ ! -f "$S3_CONFIG" ]; then
                echo "  [*] Creating S3 backup config template..."
                cat > "$S3_CONFIG" << 'EOFS3'
{
  "enabled": false,
  "provider": "s3",
  "endpoint": "",
  "region": "eu-west-1",
  "bucket": "YOUR_BUCKET_NAME",
  "access_key": "YOUR_ACCESS_KEY",
  "secret_key": "YOUR_SECRET_KEY",
  "path": "",
  "schedule": "03:00",
  "retention_days": 3,
  "compression": "gz",
  "folders": [
    "/etc/firewall",
    "/etc/sysctl.d/99-charizard.conf",
    "/etc/fail2ban/jail.local"
  ],
  "exclude": [
    "*.log",
    "*.tmp",
    "spamhaus_*.txt",
    "backups/*"
  ]
}
EOFS3
                echo -e "  [\033[32m✓\033[0m] Created: $S3_CONFIG"
                echo ""
                echo -e "  \033[33m[!] Configure S3 credentials in:\033[0m"
                echo "      $S3_CONFIG"
                echo ""
            fi

            # Add docker path to folders if not present
            if ! jq -e ".folders | index(\"$DOCKER_PATH\")" "$S3_CONFIG" >/dev/null 2>&1; then
                echo "  [*] Adding $DOCKER_PATH to S3 backup folders..."
                jq ".folders += [\"$DOCKER_PATH\"]" "$S3_CONFIG" > "${S3_CONFIG}.tmp" && mv "${S3_CONFIG}.tmp" "$S3_CONFIG"
                echo -e "  [\033[32m✓\033[0m] Docker folder added to S3 backup"
            else
                echo -e "  [\033[32m✓\033[0m] Docker folder already in S3 backup"
            fi

            echo ""
            echo "  ==================================="
            echo -e "  \033[32m DOCKER INSTALLATION COMPLETE \033[0m"
            echo "  ==================================="
            echo ""
            echo "  Commands available:"
            echo "    charizard dps            - docker ps"
            echo "    charizard dlogs          - docker logs -f"
            echo "    charizard dexec          - docker exec -it"
            echo "    charizard dstop <c|all>  - stop container(s)"
            echo "    charizard dstart <c|all> - start container(s)"
            echo "    charizard ddown          - stop + remove all"
            echo "    charizard drestart       - restart container(s)"
            echo ""
            ;;
        dns)
            echo ""
            echo "  === INSTALL CHARIZARD DNS ==="
            echo ""

            # Check Docker first
            if ! command -v docker &>/dev/null; then
                echo -e "  \033[31m[x]\033[0m Docker required. Run: charizard install docker"
                exit 1
            fi

            # Check if script exists locally or download
            DNS_INSTALL_DIR="/tmp/charizard-dns-install"
            rm -rf "$DNS_INSTALL_DIR"
            mkdir -p "$DNS_INSTALL_DIR"

            echo "  [*] Downloading DNS installer..."
            curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/install.sh" -o "$DNS_INSTALL_DIR/install.sh"
            curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/Dockerfile" -o "$DNS_INSTALL_DIR/Dockerfile"
            curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/docker-compose.yml" -o "$DNS_INSTALL_DIR/docker-compose.yml"
            mkdir -p "$DNS_INSTALL_DIR/config"
            curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/dns/config/unbound.conf" -o "$DNS_INSTALL_DIR/config/unbound.conf"
            chmod +x "$DNS_INSTALL_DIR/install.sh"

            # Run installer
            bash "$DNS_INSTALL_DIR/install.sh" install

            # Cleanup
            rm -rf "$DNS_INSTALL_DIR"
            ;;
        portainer)
            echo ""
            echo "  === INSTALL PORTAINER CE ==="
            echo ""

            # Check Docker first
            if ! command -v docker &>/dev/null; then
                echo -e "  \033[31m[x]\033[0m Docker required. Run: charizard install docker"
                exit 1
            fi

            # Check if script exists locally or download
            PORTAINER_INSTALL_DIR="/tmp/charizard-portainer-install"
            rm -rf "$PORTAINER_INSTALL_DIR"
            mkdir -p "$PORTAINER_INSTALL_DIR"

            echo "  [*] Downloading Portainer installer..."
            curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/portainer/install.sh" -o "$PORTAINER_INSTALL_DIR/install.sh"
            curl -sSL "https://raw.githubusercontent.com/sanvilscript/charizard/main/extra/portainer/docker-compose.yml" -o "$PORTAINER_INSTALL_DIR/docker-compose.yml"
            chmod +x "$PORTAINER_INSTALL_DIR/install.sh"

            # Run installer
            bash "$PORTAINER_INSTALL_DIR/install.sh" install

            # Cleanup
            rm -rf "$PORTAINER_INSTALL_DIR"
            ;;
        *)
            echo ""
            echo "  Usage: charizard install <component>"
            echo ""
            echo "  Components:"
            echo "    docker      Install Docker Engine"
            echo "    portainer   Install Portainer CE (requires docker)"
            echo "    dns         Install Charizard DNS (Unbound)"
            echo ""
            ;;
    esac
    ;;
dps)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[✗]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    shift
    docker ps "$@"
    ;;
dlogs)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[✗]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "  Usage: charizard dlogs <container>"
        echo ""
        echo "  Running containers:"
        docker ps --format "    {{.Names}}"
    else
        docker logs -f "$2"
    fi
    ;;
dexec)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[✗]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "  Usage: charizard dexec <container> [command]"
        echo ""
        echo "  Running containers:"
        docker ps --format "    {{.Names}}"
    else
        CONTAINER="$2"
        shift 2
        CMD="${@:-sh}"
        docker exec -it "$CONTAINER" $CMD
    fi
    ;;
dstop)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[x]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    DOCKER_STATE="/etc/firewall/docker-state.json"
    if [ -z "$2" ]; then
        echo "  Usage: charizard dstop <container|all>"
        echo ""
        echo "  Running containers:"
        docker ps --format "    {{.Names}}"
    elif [ "$2" = "all" ]; then
        CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null)
        if [ -z "$CONTAINERS" ]; then
            echo -e "  \033[33m[!]\033[0m No running containers"
            exit 0
        fi
        echo '{"stopped":['$(echo "$CONTAINERS" | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')'],"timestamp":"'$(date -Iseconds)'"}' > "$DOCKER_STATE"
        echo "  [*] Stopping all containers..."
        docker stop $CONTAINERS
        echo -e "  \033[32m[ok]\033[0m Stopped $(echo "$CONTAINERS" | wc -l) containers"
        echo "  State saved to: $DOCKER_STATE"
    else
        if docker ps --format "{{.Names}}" | grep -q "^$2$"; then
            echo '{"stopped":["'$2'"],"timestamp":"'$(date -Iseconds)'"}' > "$DOCKER_STATE"
            docker stop "$2"
            echo -e "  \033[32m[ok]\033[0m Stopped: $2"
        else
            echo -e "  \033[31m[x]\033[0m Container not running: $2"
            exit 1
        fi
    fi
    ;;
dstart)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[x]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    DOCKER_STATE="/etc/firewall/docker-state.json"
    if [ -z "$2" ]; then
        echo "  Usage: charizard dstart <container|all>"
        echo ""
        if [ -f "$DOCKER_STATE" ]; then
            echo "  Saved state:"
            cat "$DOCKER_STATE" | grep -o '"[^"]*"' | grep -v timestamp | tr -d '"' | sed 's/^/    /'
        fi
        echo ""
        echo "  Stopped containers:"
        docker ps -a --filter "status=exited" --format "    {{.Names}}"
    elif [ "$2" = "all" ]; then
        if [ -f "$DOCKER_STATE" ]; then
            CONTAINERS=$(cat "$DOCKER_STATE" | grep -o '"stopped":\[[^]]*\]' | grep -o '"[^"]*"' | tr -d '"' | grep -v stopped)
            if [ -n "$CONTAINERS" ]; then
                echo "  [*] Starting containers from saved state..."
                for c in $CONTAINERS; do
                    docker start "$c" 2>/dev/null && echo -e "  \033[32m[ok]\033[0m Started: $c"
                done
                rm -f "$DOCKER_STATE"
            else
                echo -e "  \033[33m[!]\033[0m No saved state found"
            fi
        else
            echo -e "  \033[33m[!]\033[0m No saved state. Use: charizard dstart <container>"
        fi
    else
        docker start "$2" && echo -e "  \033[32m[ok]\033[0m Started: $2"
    fi
    ;;
ddown)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[x]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    DOCKER_STATE="/etc/firewall/docker-state.json"
    CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null)
    if [ -z "$CONTAINERS" ]; then
        echo -e "  \033[33m[!]\033[0m No running containers"
        exit 0
    fi
    echo '{"stopped":['$(echo "$CONTAINERS" | sed 's/^/"/;s/$/"/' | tr '\n' ',' | sed 's/,$//')'],"timestamp":"'$(date -Iseconds)'"}' > "$DOCKER_STATE"
    echo "  [*] Stopping and removing all containers..."
    docker stop $CONTAINERS >/dev/null 2>&1
    docker rm $CONTAINERS >/dev/null 2>&1
    echo -e "  \033[32m[ok]\033[0m Removed $(echo "$CONTAINERS" | wc -l) containers"
    echo "  State saved to: $DOCKER_STATE (for reference)"
    ;;
drestart)
    if ! command -v docker &>/dev/null; then
        echo -e "  \033[31m[x]\033[0m Docker not installed. Run: charizard install docker"
        exit 1
    fi
    if [ -z "$2" ]; then
        echo "  Usage: charizard drestart <container|all>"
        echo ""
        echo "  Running containers:"
        docker ps --format "    {{.Names}}"
    elif [ "$2" = "all" ]; then
        CONTAINERS=$(docker ps --format "{{.Names}}" 2>/dev/null)
        if [ -z "$CONTAINERS" ]; then
            echo -e "  \033[33m[!]\033[0m No running containers"
            exit 0
        fi
        echo "  [*] Restarting all containers..."
        docker restart $CONTAINERS
        echo -e "  \033[32m[ok]\033[0m Restarted $(echo "$CONTAINERS" | wc -l) containers"
    else
        docker restart "$2" && echo -e "  \033[32m[ok]\033[0m Restarted: $2"
    fi
    ;;
dns)
    DNS_DIR="/etc/firewall/dns"
    DNS_HOSTS="$DNS_DIR/hosts.json"
    case "$2" in
        status)
            echo ""
            echo "  === CHARIZARD DNS STATUS ==="
            echo ""
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^charizard_dns$"; then
                echo -e "  \033[32m[ok]\033[0m Container: running"
                if dig @127.0.0.1 cloudflare.com +short +time=3 >/dev/null 2>&1; then
                    echo -e "  \033[32m[ok]\033[0m DNS resolution: working"
                else
                    echo -e "  \033[31m[x]\033[0m DNS resolution: failed"
                fi
            else
                echo -e "  \033[31m[x]\033[0m Container: not running"
            fi
            if [ -f "$DNS_HOSTS" ]; then
                HOSTS_COUNT=$(grep -c '"name"' "$DNS_HOSTS" 2>/dev/null || echo "0")
                echo "  Local hosts: $HOSTS_COUNT"
            fi
            echo ""
            ;;
        start)
            if [ -f "$DNS_DIR/docker-compose.yml" ]; then
                cd "$DNS_DIR" && docker compose up -d
                echo -e "  \033[32m[ok]\033[0m Charizard DNS started"
            else
                echo -e "  \033[31m[x]\033[0m DNS not installed. Run: charizard install dns"
            fi
            ;;
        stop)
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^charizard_dns$"; then
                docker stop charizard_dns >/dev/null
                echo -e "  \033[32m[ok]\033[0m Charizard DNS stopped"
            else
                echo -e "  \033[33m[!]\033[0m DNS not running"
            fi
            ;;
        restart)
            if [ -f "$DNS_DIR/docker-compose.yml" ]; then
                cd "$DNS_DIR" && docker compose restart
                echo -e "  \033[32m[ok]\033[0m Charizard DNS restarted"
            else
                echo -e "  \033[31m[x]\033[0m DNS not installed"
            fi
            ;;
        logs)
            docker logs -f charizard_dns 2>/dev/null || echo -e "  \033[31m[x]\033[0m DNS not running"
            ;;
        add)
            if [ -z "$3" ] || [ -z "$4" ]; then
                echo "  Usage: charizard dns add <hostname> <ip>"
                echo "  Example: charizard dns add server1.local 192.168.1.10"
            else
                HOSTNAME="$3"
                IP="$4"
                # Add to hosts.json
                if [ -f "$DNS_HOSTS" ]; then
                    TMP=$(mktemp)
                    jq --arg name "$HOSTNAME" --arg ip "$IP" \
                        '.hosts += [{"name": $name, "ip": $ip}]' "$DNS_HOSTS" > "$TMP" && mv "$TMP" "$DNS_HOSTS"
                else
                    echo '{"hosts":[{"name":"'"$HOSTNAME"'","ip":"'"$IP"'"}]}' > "$DNS_HOSTS"
                fi
                # Update hosts.local
                echo "local-data: \"$HOSTNAME. A $IP\"" >> "$DNS_DIR/data/hosts.local"
                # Reload unbound
                docker exec charizard_dns unbound-control reload 2>/dev/null || true
                echo -e "  \033[32m[ok]\033[0m Added: $HOSTNAME -> $IP"
            fi
            ;;
        remove|rm)
            if [ -z "$3" ]; then
                echo "  Usage: charizard dns remove <hostname>"
            else
                HOSTNAME="$3"
                if [ -f "$DNS_HOSTS" ]; then
                    TMP=$(mktemp)
                    jq --arg name "$HOSTNAME" '.hosts |= map(select(.name != $name))' "$DNS_HOSTS" > "$TMP" && mv "$TMP" "$DNS_HOSTS"
                fi
                if [ -f "$DNS_DIR/data/hosts.local" ]; then
                    sed -i "/\"$HOSTNAME\./d" "$DNS_DIR/data/hosts.local"
                fi
                docker exec charizard_dns unbound-control reload 2>/dev/null || true
                echo -e "  \033[32m[ok]\033[0m Removed: $HOSTNAME"
            fi
            ;;
        hosts)
            echo ""
            echo "  === LOCAL HOSTS ==="
            echo ""
            if [ -f "$DNS_HOSTS" ]; then
                jq -r '.hosts[] | "  \(.name) -> \(.ip)"' "$DNS_HOSTS" 2>/dev/null || echo "  No hosts configured"
            else
                echo "  No hosts configured"
            fi
            echo ""
            ;;
        flush)
            docker exec charizard_dns unbound-control reload 2>/dev/null && \
                echo -e "  \033[32m[ok]\033[0m DNS cache flushed" || \
                echo -e "  \033[31m[x]\033[0m Failed to flush cache"
            ;;
        test)
            echo ""
            echo "  === DNS TEST ==="
            echo ""
            echo "  Testing external resolution..."
            RESULT=$(dig @127.0.0.1 google.com +short +time=5 2>/dev/null | head -1)
            if [ -n "$RESULT" ]; then
                echo -e "  \033[32m[ok]\033[0m google.com -> $RESULT"
            else
                echo -e "  \033[31m[x]\033[0m Failed to resolve google.com"
            fi
            echo ""
            ;;
        *)
            echo ""
            echo "  Usage: charizard dns <command>"
            echo ""
            echo "  Commands:"
            echo "    status    Show DNS status"
            echo "    start     Start DNS container"
            echo "    stop      Stop DNS container"
            echo "    restart   Restart DNS container"
            echo "    logs      Show DNS logs"
            echo "    add       Add local host"
            echo "    remove    Remove local host"
            echo "    hosts     List local hosts"
            echo "    flush     Flush DNS cache"
            echo "    test      Test DNS resolution"
            echo ""
            ;;
    esac
    ;;
portainer)
    PORTAINER_DIR="/home/${SUDO_USER:-debian}/docker/portainer"
    case "$2" in
        status)
            echo ""
            echo "  === PORTAINER STATUS ==="
            echo ""
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
                SERVER_IP=$(hostname -I | awk '{print $1}')
                echo -e "  \033[32m[ok]\033[0m Container: running"
                echo "  URL: https://$SERVER_IP:9443"
            else
                echo -e "  \033[31m[x]\033[0m Container: not running"
            fi
            echo ""
            ;;
        start)
            if [ -f "$PORTAINER_DIR/docker-compose.yml" ]; then
                cd "$PORTAINER_DIR" && docker compose up -d
                echo -e "  \033[32m[ok]\033[0m Portainer started"
            else
                echo -e "  \033[31m[x]\033[0m Portainer not installed. Run: charizard install portainer"
            fi
            ;;
        stop)
            if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^portainer$"; then
                docker stop portainer >/dev/null
                echo -e "  \033[32m[ok]\033[0m Portainer stopped"
            else
                echo -e "  \033[33m[!]\033[0m Portainer not running"
            fi
            ;;
        restart)
            if [ -f "$PORTAINER_DIR/docker-compose.yml" ]; then
                cd "$PORTAINER_DIR" && docker compose restart
                echo -e "  \033[32m[ok]\033[0m Portainer restarted"
            else
                echo -e "  \033[31m[x]\033[0m Portainer not installed"
            fi
            ;;
        logs)
            docker logs -f --tail=50 portainer 2>/dev/null || echo -e "  \033[31m[x]\033[0m Portainer not running"
            ;;
        *)
            echo ""
            echo "  Usage: charizard portainer <command>"
            echo ""
            echo "  Commands:"
            echo "    status    Show Portainer status"
            echo "    start     Start Portainer"
            echo "    stop      Stop Portainer"
            echo "    restart   Restart Portainer"
            echo "    logs      Show Portainer logs"
            echo ""
            ;;
    esac
    ;;
geo)
    case "$2" in
        lookup)
            if [ -z "$3" ]; then
                echo "  Usage: charizard geo lookup <ip>"
            else
                IP="$3"
                if [ ! -f "$GEO_DB" ]; then
                    echo -e "  \033[31m[x]\033[0m GeoIP database not found: $GEO_DB"
                    exit 1
                fi
                if ! command -v mmdblookup &>/dev/null; then
                    echo -e "  \033[31m[x]\033[0m mmdblookup not installed. Run: apt install mmdb-bin"
                    exit 1
                fi
                COUNTRY=$(geo_lookup "$IP")
                COUNTRY_NAME=$(geo_lookup_name "$IP")
                echo ""
                echo "  IP:      $IP"
                echo "  Country: $COUNTRY ($COUNTRY_NAME)"
                echo ""
            fi
            ;;
        top)
            N="${3:-10}"
            echo ""
            echo "  === TOP $N COUNTRIES (blocked traffic) ==="
            echo ""
            if [ ! -f "$GEO_DB" ] || ! command -v mmdblookup &>/dev/null; then
                echo "  GeoIP not available"
            else
                # Get top IPs from log and lookup countries
                grep -oP 'SRC=\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/charizard.log 2>/dev/null | \
                    sort | uniq -c | sort -rn | head -50 | while read count ip; do
                    CC=$(geo_lookup "$ip")
                    echo "$CC"
                done | sort | uniq -c | sort -rn | head -"$N" | while read count cc; do
                    printf "  %-4s %s\n" "$cc" "$count hits"
                done
            fi
            echo ""
            ;;
        stats)
            echo ""
            echo "  === GEO STATISTICS ==="
            echo ""
            if [ ! -f "$GEO_DB" ]; then
                echo -e "  \033[31m[x]\033[0m GeoIP database not found"
                echo "      Path: $GEO_DB"
            elif ! command -v mmdblookup &>/dev/null; then
                echo -e "  \033[31m[x]\033[0m mmdblookup not installed"
                echo "      Run: apt install mmdb-bin"
            else
                echo -e "  \033[32m[ok]\033[0m GeoIP ready"
                echo "      Database: $GEO_DB"
                DB_SIZE=$(du -h "$GEO_DB" 2>/dev/null | cut -f1)
                DB_DATE=$(stat -c %y "$GEO_DB" 2>/dev/null | cut -d' ' -f1)
                echo "      Size: $DB_SIZE"
                echo "      Date: $DB_DATE"
                echo ""
                # Count unique countries in last log
                if [ -f /var/log/charizard.log ]; then
                    UNIQUE_IPS=$(grep -oP 'SRC=\K[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' /var/log/charizard.log 2>/dev/null | sort -u | wc -l)
                    echo "  Unique blocked IPs: $UNIQUE_IPS"
                fi
            fi
            echo ""
            ;;
        *)
            echo ""
            echo "  Usage: charizard geo <command>"
            echo ""
            echo "  Commands:"
            echo "    lookup <ip>  Show country for IP"
            echo "    top [n]      Top n countries by blocked traffic (default 10)"
            echo "    stats        GeoIP status and statistics"
            echo ""
            ;;
    esac
    ;;
version)
    banner
    ;;
*)
    banner
    echo "  +-----------------------------------------------------------------+"
    echo "  | AVAILABLE COMMANDS                                              |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  apply ............. Apply firewall rules                       |"
    echo "  |  update ............ Update whitelist DNS                       |"
    echo "  |  reload ............ Update + Apply                             |"
    echo "  |  flush ............. Disable (emergency)                        |"
    echo "  |  rollback .......... Restore backup                             |"
    echo "  |  show .............. Show rules                                 |"
    echo "  |  status ............ Statistics                                 |"
    echo "  |  watch ............. Live monitor                               |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  ban <ip> .......... Ban IP (1h auto-expire)                    |"
    echo "  |  unban <ip> ........ Remove ban                                 |"
    echo "  |  add <ip> .......... Temporary whitelist                        |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  open <port> ....... Add port to config                         |"
    echo "  |  close <port> ...... Remove port from config                    |"
    echo "  |  ports ............. List open ports                            |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  allow <host> ...... Add host/IP to whitelist                   |"
    echo "  |  deny <host> ....... Remove host/IP from whitelist              |"
    echo "  |  hosts ............. List whitelisted hosts                     |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  spamhaus .......... Spamhaus DROP status                       |"
    echo "  |  spamhaus update ... Force Spamhaus update                      |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  f2b ............... Fail2ban status                            |"
    echo "  |  f2b ban <ip> ...... Ban IP via fail2ban                        |"
    echo "  |  f2b unban <ip> .... Unban IP from fail2ban                     |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  log [n] ........... Show last n log entries (default 20)       |"
    echo "  |  top [n] ........... Top n blocked IPs (default 10)             |"
    echo "  |  report ............ Generate full report                       |"
    echo "  |  backup ............ Backup config to /etc/firewall/backups     |"
    echo "  |  restore [file] .... Restore from backup                        |"
    echo "  |  doctor ............ Health check                               |"
    echo "  |  upgrade ........... Update Charizard to latest version        |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  telegram .......... Telegram bot commands                      |"
    echo "  |  tg test ........... Send test message                          |"
    echo "  |  tg status ......... Bot status                                 |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  notify ............ Alert/notification module                  |"
    echo "  |  notify status ..... Module status                              |"
    echo "  |  notify check ...... Run spike/scan check manually              |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  disk .............. Disk usage overview                        |"
    echo "  |  disk find SIZE .... Find files > SIZE (100M, 1G)               |"
    echo "  |  disk clean ........ Cleanup suggestions                        |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  io ................ I/O statistics                             |"
    echo "  |  io top ............ Top I/O processes                          |"
    echo "  |  io watch .......... Live I/O monitoring                        |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  timers ............ Charizard timers status                    |"
    echo "  |  timers all ........ All system timers                          |"
    echo "  |  timers next ....... Next scheduled executions                  |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  s3 ................ S3 backup commands                         |"
    echo "  |  s3 status ......... Backup status                              |"
    echo "  |  s3 backup ......... Backup now                                 |"
    echo "  |  s3 list ........... List backups in S3                         |"
    echo "  |  s3 restore ........ Restore from S3                            |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  install docker .... Install Docker + Portainer                 |"
    echo "  |  dps ............... docker ps (list containers)               |"
    echo "  |  dlogs <container> . docker logs -f (follow logs)              |"
    echo "  |  dexec <container> . docker exec -it (shell into)              |"
    echo "  |  dstop <c|all> .... Stop container(s), save state              |"
    echo "  |  dstart <c|all> ... Start container(s) from state              |"
    echo "  |  ddown ............ Stop + remove all containers               |"
    echo "  |  drestart <c|all> . Restart container(s)                       |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  install dns ....... Install Charizard DNS (Unbound)           |"
    echo "  |  dns status ........ DNS status                                 |"
    echo "  |  dns start/stop .... Start/stop DNS                             |"
    echo "  |  dns add <h> <ip> .. Add local host                             |"
    echo "  |  dns hosts ......... List local hosts                           |"
    echo "  |  dns test .......... Test DNS resolution                        |"
    echo "  +-----------------------------------------------------------------+"
    echo "  |  version ........... Show version                               |"
    echo "  +-----------------------------------------------------------------+"
    echo ""
    ;;
esac
