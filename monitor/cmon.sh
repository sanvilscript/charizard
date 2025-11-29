#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD MONITOR (cmon) v1.1.0
#   Real-time network monitoring dashboard
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Read version from VERSION file
if [ -f "$SCRIPT_DIR/../VERSION" ]; then
    VERSION=$(cat "$SCRIPT_DIR/../VERSION" | tr -d '[:space:]')
elif [ -f "/etc/firewall/VERSION" ]; then
    VERSION=$(cat "/etc/firewall/VERSION" | tr -d '[:space:]')
else
    VERSION="1.1.0"
fi
INSTALL_DIR="/etc/firewall/monitor"
SESSION_NAME="cmon"
REFRESH_RATE=2

# ══════════════════════════════════════════════════════════════════════════════
# GRUVBOX COLORS
# ══════════════════════════════════════════════════════════════════════════════

RED='\033[38;5;160m'
GREEN='\033[38;5;142m'
YELLOW='\033[38;5;214m'
ORANGE='\033[38;5;166m'
CYAN='\033[38;5;109m'
PURPLE='\033[38;5;132m'
GRAY='\033[38;5;246m'
WHITE='\033[38;5;223m'
NC='\033[0m'

BRED='\033[38;5;167m'
BGREEN='\033[38;5;106m'
BYELLOW='\033[38;5;220m'
BCYAN='\033[38;5;72m'
BPURPLE='\033[38;5;175m'
BORANGE='\033[38;5;208m'

# ══════════════════════════════════════════════════════════════════════════════
# LOG COLORIZER
# ══════════════════════════════════════════════════════════════════════════════

colorize_line() {
    local line="$1"
    local ip=$(echo "$line" | grep -oE 'SRC=[0-9a-fA-F.:]+' | cut -d= -f2)

    if [[ "$line" =~ CHARIZARD6?_SPAM ]]; then
        echo -e "${PURPLE}[SPAM]${NC} ${BRED}$ip${NC} ${GRAY}$(echo "$line" | sed 's/.*CHARIZARD6\?_SPAM://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_SCAN ]]; then
        echo -e "${YELLOW}[SCAN]${NC} ${RED}$ip${NC} ${GRAY}$(echo "$line" | sed 's/.*CHARIZARD6\?_SCAN://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_BLOCK ]]; then
        echo -e "${CYAN}[BLCK]${NC} ${RED}$ip${NC} ${GRAY}$(echo "$line" | sed 's/.*CHARIZARD6\?_BLOCK://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_FLAGS ]]; then
        echo -e "${BORANGE}[FLAG]${NC} ${RED}$ip${NC} ${GRAY}$(echo "$line" | sed 's/.*CHARIZARD6\?_FLAGS://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_INVALID ]]; then
        echo -e "${GRAY}[INVD]${NC} ${GRAY}$ip$(echo "$line" | sed 's/.*CHARIZARD6\?_INVALID://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_ICMP ]]; then
        echo -e "${BCYAN}[ICMP]${NC} ${YELLOW}$ip${NC} ${GRAY}$(echo "$line" | sed 's/.*CHARIZARD6\?_ICMP://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_BAN ]]; then
        echo -e "${BRED}[BAN!]${NC} ${BRED}$ip${NC} ${WHITE}$(echo "$line" | sed 's/.*CHARIZARD6\?_BAN://')${NC}"
    elif [[ "$line" =~ CHARIZARD6?_DROP ]]; then
        echo -e "${RED}[DROP]${NC} ${RED}$ip${NC} ${GRAY}$(echo "$line" | sed 's/.*CHARIZARD6\?_DROP://')${NC}"
    elif [[ "$line" =~ CHARIZARD ]]; then
        echo -e "${ORANGE}[FW]${NC} ${GRAY}$line${NC}"
    else
        echo -e "${GRAY}$line${NC}"
    fi
}

run_logcolor() {
    local log_file="${1:-/var/log/charizard.log}"

    echo -e "${ORANGE}══════════════════════════════════════${NC}"
    echo -e "${WHITE}  LIVE FIREWALL LOG${NC}"
    echo -e "${ORANGE}══════════════════════════════════════${NC}"
    echo -e "${GRAY}  Watching: $log_file${NC}"
    echo ""

    if [ ! -f "$log_file" ]; then
        echo -e "${YELLOW}  [!] Log file not found${NC}"
        echo -e "${GRAY}  Waiting for first entry...${NC}"
        echo ""
    fi

    tail -f "$log_file" 2>/dev/null | while IFS= read -r line; do
        colorize_line "$line"
    done
}

# ══════════════════════════════════════════════════════════════════════════════
# DEPENDENCY CHECK
# ══════════════════════════════════════════════════════════════════════════════

check_deps() {
    local missing=()

    command -v tmux >/dev/null 2>&1 || missing+=("tmux")
    command -v iftop >/dev/null 2>&1 || missing+=("iftop")
    command -v nethogs >/dev/null 2>&1 || missing+=("nethogs")
    command -v vnstat >/dev/null 2>&1 || missing+=("vnstat")

    if [ ${#missing[@]} -gt 0 ]; then
        echo ""
        echo -e "  ${YELLOW}[!] Missing dependencies: ${missing[*]}${NC}"
        echo ""
        echo -n "  Install them now? [Y/n]: "
        read -r CONFIRM
        if [[ "$CONFIRM" =~ ^[Nn]$ ]]; then
            echo "  [!] Cannot run without dependencies. Exiting."
            exit 1
        fi

        echo "  [*] Installing dependencies..."
        DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
        DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing[@]}" >/dev/null 2>&1
        echo -e "  ${GREEN}[ok] Dependencies installed${NC}"

        if [[ " ${missing[*]} " =~ " vnstat " ]]; then
            systemctl enable vnstat >/dev/null 2>&1 || true
            systemctl start vnstat >/dev/null 2>&1 || true
        fi
    fi
}

# ══════════════════════════════════════════════════════════════════════════════
# HELP
# ══════════════════════════════════════════════════════════════════════════════

show_help() {
    echo ""
    echo "  # CHARIZARD MONITOR (cmon) v${VERSION}"
    echo ""
    echo "  Usage: cmon [command]"
    echo ""
    echo "  Commands:"
    echo "    (none)    Default layout (5 panes, focus on log)"
    echo "    full      Full layout (7 panes, includes btop + SSH log)"
    echo "    stop      Kill running monitor session"
    echo "    log       Live colorized firewall log only"
    echo "    help      Show this help"
    echo ""
    echo "  Keyboard shortcuts:"
    echo "    Q         Quit monitor (uppercase)"
    echo "    q         Quit current app (btop, iftop, etc.)"
    echo "    Shift+N   Toggle navigation mode (arrows move between panes)"
    echo ""
    exit 0
}

# ══════════════════════════════════════════════════════════════════════════════
# STOP SESSION
# ══════════════════════════════════════════════════════════════════════════════

stop_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        tmux kill-session -t "$SESSION_NAME"
        echo "  [ok] Monitor session stopped"
    else
        echo "  [!] No monitor session running"
    fi
    exit 0
}

# ══════════════════════════════════════════════════════════════════════════════
# GET SYSTEM INFO FOR STATUS BAR
# ══════════════════════════════════════════════════════════════════════════════

get_ip() {
    ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}' || echo "N/A"
}

# ══════════════════════════════════════════════════════════════════════════════
# TMUX THEME SETUP
# ══════════════════════════════════════════════════════════════════════════════

setup_tmux_theme() {
    tmux set-option -t "$SESSION_NAME" status on
    tmux set-option -t "$SESSION_NAME" status-position top
    tmux set-option -t "$SESSION_NAME" status-interval "$REFRESH_RATE"
    tmux set-option -t "$SESSION_NAME" status-style "bg=colour235,fg=colour223"

    tmux set-option -t "$SESSION_NAME" status-left-length 100
    tmux set-option -t "$SESSION_NAME" status-left "#[bg=colour166,fg=colour235,bold]  CHARIZARD #[bg=colour235,fg=colour166]█#[fg=colour246] #H #[fg=colour239]│#[fg=colour208] $(get_ip) #[fg=colour239]│#[fg=colour142] #(ss -tn state established 2>/dev/null | tail -n +2 | wc -l)con #[fg=colour239]│#[fg=colour160] #(ipset list blacklist 2>/dev/null | grep -c '^[0-9]' || echo 0)ban "

    tmux set-option -t "$SESSION_NAME" status-right-length 60
    tmux set-option -t "$SESSION_NAME" status-right "#[fg=colour246]DSK #(df / | awk 'NR==2{print $5}') #[fg=colour239]│#[fg=colour214] #(cut -d' ' -f1 /proc/loadavg) #[fg=colour239]│#[fg=colour223] %H:%M "

    tmux set-option -t "$SESSION_NAME" status-justify centre
    tmux set-option -t "$SESSION_NAME" window-status-current-format ""
    tmux set-option -t "$SESSION_NAME" window-status-format ""

    tmux set-option -t "$SESSION_NAME" pane-border-style "fg=colour239"
    tmux set-option -t "$SESSION_NAME" pane-active-border-style "fg=colour208"
    tmux set-option -t "$SESSION_NAME" pane-border-format "#[fg=colour166]─"

    tmux set-option -t "$SESSION_NAME" message-style "bg=colour166,fg=colour235,bold"
    tmux set-option -t "$SESSION_NAME" message-command-style "bg=colour235,fg=colour208"

    tmux set-option -t "$SESSION_NAME" clock-mode-colour colour214
}

# ══════════════════════════════════════════════════════════════════════════════
# TMUX KEY BINDINGS
# ══════════════════════════════════════════════════════════════════════════════

setup_keybindings() {
    tmux set-option -t "$SESSION_NAME" prefix None

    tmux bind-key -n Q kill-session -t "$SESSION_NAME"

    tmux bind-key -n N set-option -t "$SESSION_NAME" key-table navigate \; display-message " NAVIGATE: Arrows=move | Shift+N=exit "

    tmux bind-key -T navigate Up select-pane -U
    tmux bind-key -T navigate Down select-pane -D
    tmux bind-key -T navigate Left select-pane -L
    tmux bind-key -T navigate Right select-pane -R

    tmux bind-key -T navigate N set-option -t "$SESSION_NAME" key-table root \; display-message " Normal mode "
}

# ══════════════════════════════════════════════════════════════════════════════
# DEFAULT LAYOUT (5 panes - focus on log)
# ══════════════════════════════════════════════════════════════════════════════
#
# ┌───────────────┬───────────────────────────────┐
# │ Stats         │                               │
# ├───────────────┤         LIVE LOG              │
# │ iftop         │       (colorized)             │
# ├───────────────┼───────────────────────────────┤
# │ nethogs       │ Shell                         │
# └───────────────┴───────────────────────────────┘
#
# Left: 40%, Right: 60%
# Log: 70% right height, Shell: 30% right height

launch_monitor_default() {
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

    IFACE=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

    tmux new-session -d -s "$SESSION_NAME" -x "$(tput cols)" -y "$(tput lines)"

    setup_tmux_theme
    setup_keybindings

    # Create layout: vertical split 40/60, then subdivide each
    tmux split-window -t "$SESSION_NAME" -h -p 60

    # Left side: Stats (top), iftop (middle), nethogs (bottom)
    tmux split-window -t "$SESSION_NAME:0.0" -v -p 66
    tmux split-window -t "$SESSION_NAME:0.1" -v -p 50

    # Right side: Log (top 70%), Shell (bottom 30%)
    tmux split-window -t "$SESSION_NAME:0.3" -v -p 30

    # Result: 0=Stats, 1=iftop, 2=nethogs, 3=Log, 4=Shell

    # Pane 0: Firewall stats
    tmux send-keys -t "$SESSION_NAME:0.0" "TERM=xterm-256color watch -c -t -n $REFRESH_RATE '$INSTALL_DIR/stats.sh'" Enter

    # Pane 1: iftop
    tmux send-keys -t "$SESSION_NAME:0.1" "TERM=xterm iftop -i $IFACE -n -N -P 2>/dev/null || (echo 'iftop requires root'; sleep 999)" Enter

    # Pane 2: nethogs
    tmux send-keys -t "$SESSION_NAME:0.2" "nethogs $IFACE 2>/dev/null || (echo 'nethogs requires root'; sleep 999)" Enter

    # Pane 3: Live log
    tmux send-keys -t "$SESSION_NAME:0.3" "$INSTALL_DIR/cmon.sh --logcolor /var/log/charizard.log" Enter

    # Pane 4: Shell
    tmux send-keys -t "$SESSION_NAME:0.4" "cd /etc/firewall && clear && charizard help" Enter

    tmux select-pane -t "$SESSION_NAME:0.3"

    tmux attach-session -t "$SESSION_NAME"
}

# ══════════════════════════════════════════════════════════════════════════════
# FULL LAYOUT (7 panes - complete monitoring)
# ══════════════════════════════════════════════════════════════════════════════
#
# ┌───────────────┬───────────────────────────────┐
# │ iftop         │ btop                          │
# ├───────────────┤                               │
# │ SSH Log       │                               │
# ├───────────────┼───────────────────────────────┤
# │ Stats         │ Live Log                      │
# ├───────────────┼───────────────────────────────┤
# │ nethogs       │ Shell                         │
# └───────────────┴───────────────────────────────┘

launch_monitor_full() {
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

    IFACE=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{print $5; exit}' || echo "eth0")

    tmux new-session -d -s "$SESSION_NAME" -x "$(tput cols)" -y "$(tput lines)"

    setup_tmux_theme
    setup_keybindings

    # Create 7-pane layout
    tmux split-window -t "$SESSION_NAME" -h -p 50
    tmux split-window -t "$SESSION_NAME:0.0" -v -p 70
    tmux split-window -t "$SESSION_NAME:0.0" -v -p 35
    tmux split-window -t "$SESSION_NAME:0.2" -v -p 40
    tmux split-window -t "$SESSION_NAME:0.4" -v -p 50
    tmux split-window -t "$SESSION_NAME:0.5" -v -p 40

    # Result: 0=iftop, 1=ssh, 2=stats, 3=nethogs, 4=btop, 5=logs, 6=shell

    # Pane 0: iftop
    tmux send-keys -t "$SESSION_NAME:0.0" "TERM=xterm iftop -i $IFACE -n -N -P 2>/dev/null || (echo 'iftop requires root'; sleep 999)" Enter

    # Pane 1: SSH log
    tmux send-keys -t "$SESSION_NAME:0.1" "clear && journalctl -f -u ssh --no-hostname -o short-iso | grep --line-buffered -E 'Accepted|Failed|Invalid|Disconnected|Connection'" Enter

    # Pane 2: Firewall stats
    tmux send-keys -t "$SESSION_NAME:0.2" "TERM=xterm-256color watch -c -t -n $REFRESH_RATE '$INSTALL_DIR/stats.sh'" Enter

    # Pane 3: nethogs
    tmux send-keys -t "$SESSION_NAME:0.3" "nethogs $IFACE 2>/dev/null || (echo 'nethogs requires root'; sleep 999)" Enter

    # Pane 4: btop
    tmux send-keys -t "$SESSION_NAME:0.4" "btop --preset 0 -t gruvbox_dark_v2 2>/dev/null || btop 2>/dev/null || (echo 'btop not found'; sleep 999)" Enter

    # Pane 5: Live log
    tmux send-keys -t "$SESSION_NAME:0.5" "$INSTALL_DIR/cmon.sh --logcolor /var/log/charizard.log" Enter

    # Pane 6: Shell
    tmux send-keys -t "$SESSION_NAME:0.6" "cd /etc/firewall && clear && charizard help" Enter

    tmux select-pane -t "$SESSION_NAME:0.0"

    tmux attach-session -t "$SESSION_NAME"
}

# ══════════════════════════════════════════════════════════════════════════════
# MAIN
# ══════════════════════════════════════════════════════════════════════════════

case "${1:-}" in
    help|--help|-h)
        show_help
        ;;
    stop|kill)
        stop_session
        ;;
    log|--logcolor)
        run_logcolor "${2:-/var/log/charizard.log}"
        ;;
    full|complete|7)
        if [ "$EUID" -ne 0 ]; then
            echo ""
            echo "  [!] Monitor requires root for network tools"
            echo "  [*] Run: sudo cmon full"
            echo ""
            exit 1
        fi

        check_deps
        launch_monitor_full
        ;;
    *)
        if [ "$EUID" -ne 0 ]; then
            echo ""
            echo "  [!] Monitor requires root for network tools"
            echo "  [*] Run: sudo cmon"
            echo ""
            exit 1
        fi

        check_deps
        launch_monitor_default
        ;;
esac
