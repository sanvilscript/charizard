# CMON - Charizard Monitor

Real-time firewall monitoring dashboard / Dashboard monitoraggio in tempo reale.

---

## Quick Start / Avvio Rapido

```bash
sudo cmon          # Default layout (5 panes)
sudo cmon full     # Full layout (7 panes)
sudo cmon log      # Log only (colorized)
sudo cmon stop     # Stop session
sudo cmon help     # Show help
```

---

## Layouts

### Default Layout (5 panes)

Focus on firewall log with essential monitoring tools.

```
+---------------+-------------------------------+
| Stats         |                               |
+---------------+        LIVE LOG               |
| iftop         |       (colorized)             |
+---------------+-------------------------------+
| nethogs       | Shell                         |
+---------------+-------------------------------+
```

**Panes:**
| Pane | Content | Description |
|------|---------|-------------|
| Stats | `stats.sh` | IP sets, traffic, bandwidth, connections |
| iftop | Network | Bandwidth per connection |
| nethogs | Network | Bandwidth per process |
| Live Log | Firewall | Colorized `/var/log/charizard.log` |
| Shell | Terminal | Charizard commands |

### Full Layout (7 panes)

Complete monitoring with system resources and SSH log.

```
+---------------+-------------------------------+
| iftop         | btop                          |
+---------------+                               |
| SSH Log       |                               |
+---------------+-------------------------------+
| Stats         | Live Log                      |
+---------------+-------------------------------+
| nethogs       | Shell                         |
+---------------+-------------------------------+
```

**Additional Panes:**
| Pane | Content | Description |
|------|---------|-------------|
| btop | System | CPU, RAM, processes (Gruvbox theme) |
| SSH Log | journalctl | SSH login/logout events |

---

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `Q` | Quit monitor (exit session) |
| `q` | Quit current tool (iftop, btop, etc.) |
| `N` | Enter navigation mode |
| Arrows | Move between panes (in nav mode) |
| `N` (in nav) | Exit navigation mode |

---

## Log Colors (Gruvbox Theme)

| Tag | Color | Meaning |
|-----|-------|---------|
| `[SPAM]` | Purple | Spamhaus DROP match |
| `[SCAN]` | Yellow | Port scan (NULL/XMAS/FIN) |
| `[BLCK]` | Cyan | Blacklist match |
| `[FLAG]` | Orange | Illegal TCP flags |
| `[INVD]` | Gray | Invalid packet |
| `[ICMP]` | Cyan | ICMP packet |
| `[BAN!]` | Red | IP banned |
| `[DROP]` | Red | Dropped packet |

---

## Stats Panel

The stats panel (`stats.sh`) displays:

### IP Sets
- Whitelist count (IPv4/IPv6)
- Blacklist count (IPv4/IPv6)
- Spamhaus ranges loaded

### Spamhaus DROP
- Packets blocked
- Last update time

### Fail2ban
- Currently banned IPs
- Total banned (all-time)
- ipset entries

### Bandwidth (Live)
- **Rate:** Current download/upload speed
- **Session:** Total since boot
- **Today:** Daily totals (vnstat)

### Connections
- Total established
- By port: SSH:22, HTTP:80, HTTPS:443, Other

### Traffic
- Accepted packets
- Dropped packets
- Blacklist hits
- Scan attempts

### Timers
- Update timer status (5min)
- Spamhaus timer status (6h)

### Top Attackers
- Top 5 IPs by packet count
- Country codes (GeoIP)

### Top Countries
- Aggregated by country code

---

## Requirements

**Dependencies (auto-installed):**
- `tmux` - Terminal multiplexer
- `iftop` - Network bandwidth monitor
- `nethogs` - Per-process bandwidth
- `vnstat` - Network statistics
- `btop` - System monitor (optional, for full layout)

**Install missing:**
```bash
sudo apt install tmux iftop nethogs vnstat btop
```

---

## Customization

### Refresh Rate

Default: 2 seconds. Modify in `cmon.sh`:
```bash
REFRESH_RATE=2
```

### Status Bar

The tmux status bar shows:
- **Left:** CHARIZARD | hostname | IP | connections | bans
- **Right:** Disk% | Load | Time

### Theme

Uses Gruvbox Dark color palette:
- Background: `#282828`
- Foreground: `#EBDBB2`
- Orange accent: `#D65D0E`

---

## Troubleshooting

### "Monitor requires root"
```bash
sudo cmon   # Must run as root for network tools
```

### "iftop/nethogs requires root"
Network monitoring tools need root privileges. Run with `sudo`.

### Session already exists
```bash
sudo cmon stop   # Kill existing session first
sudo cmon        # Start fresh
```

### Missing dependencies
```bash
sudo apt update
sudo apt install tmux iftop nethogs vnstat btop
```

### Log file not found
```bash
# Check if firewall is logging
sudo charizard apply
# Verify log exists
ls -la /var/log/charizard.log
```

---

## Files

| File | Location | Purpose |
|------|----------|---------|
| `cmon.sh` | `/etc/firewall/monitor/` | Main monitor script |
| `stats.sh` | `/etc/firewall/monitor/` | Stats panel script |
| `charizard.log` | `/var/log/` | Firewall log |

---

## Integration

### With Telegram Bot

View stats remotely:
```
/status   - Firewall status
/top 10   - Top blocked IPs
/log 20   - Recent log entries
```

### With SSH

Quick check via SSH:
```bash
ssh user@server 'sudo cmon log' | head -50
```

---

*Charizard Firewall v1.0.1*
