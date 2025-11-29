#!/bin/bash
# ══════════════════════════════════════════════════════════════════════════════
#   CHARIZARD SSH LOGIN NOTIFIER
#   PAM hook for SSH login notifications via Telegram
#   Developed by Sanvil (c) 2025
# ══════════════════════════════════════════════════════════════════════════════

# Only run on session open
[ -z "$PAM_USER" ] && exit 0
[ "$PAM_TYPE" != "open_session" ] && exit 0

# Config
NOTIFY_CONFIG="/etc/firewall/notify.json"
TELEGRAM_SCRIPT="/etc/firewall/modules/telegram.sh"

# Check if SSH notifications are enabled
if [ -f "$NOTIFY_CONFIG" ]; then
    ENABLED=$(jq -r '.alerts.ssh.enabled // false' "$NOTIFY_CONFIG" 2>/dev/null)
    [ "$ENABLED" != "true" ] && exit 0
else
    # No config = disabled by default
    exit 0
fi

# Check if telegram script exists
[ ! -x "$TELEGRAM_SCRIPT" ] && exit 0

# Send notification (background, non-blocking to not delay SSH)
"$TELEGRAM_SCRIPT" ssh-login "$PAM_USER" "$PAM_RHOST" &>/dev/null &

exit 0
