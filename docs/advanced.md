# Advanced / Avanzato

Technical architecture and internals / Architettura tecnica e internals.

---

## Architecture / Architettura

```
+-------------------------------------------------------------------+
|                       CHARIZARD FIREWALL                          |
+-------------------------------------------------------------------+
|  whitelist (ipset)  |  blacklist (ipset)  |  iptables + ip6tables |
+-------------------------------------------------------------------+
                              |
                      [ PACKET FLOW ]
                              |
+-------------------------------------------------------------------+
| Config: /etc/firewall/     | Logs: /var/log/charizard.log        |
+-------------------------------------------------------------------+
```

### Components / Componenti

| Component | Purpose / Scopo |
|-----------|-----------------|
| `firewall.sh` | Main script (iptables/ipset logic) |
| `whitelist.json` | Dynamic hosts with full access |
| `openports.json` | Public ports open to everyone |
| `cmon` | Real-time monitoring dashboard |
| `modules/telegram.sh` | Telegram bot daemon |
| `modules/notify.sh` | Notification system |

---

## Packet Flow / Flusso Pacchetti

```
INCOMING PACKET
      |
      v
[ LOOPBACK? ] --> ACCEPT
      |
      v
[ BROADCAST/MULTICAST? ] --> DROP
      |
      v
[ STATE: INVALID? ] --> DROP
      |
      v
[ STATE: ESTABLISHED/RELATED? ] --> ACCEPT
      |
      v
[ BLACKLIST? ] --> LOG + DROP
      |
      v
[ WHITELIST? ] --> ACCEPT
      |
      v
[ SCAN DETECTED? ] --> LOG + DROP
      |
      v
[ ICMP (rate limited)? ] --> ACCEPT
      |
      v
[ PUBLIC PORT? ] --> ACCEPT
      |
      v
[ DEFAULT ] --> DROP
```

---

## ipset

O(1) lookup vs O(n) iptables scan / Lookup O(1) vs scansione O(n) iptables.

| Set | Type | Purpose / Scopo | Timeout |
|-----|------|-----------------|---------|
| `whitelist` | hash:ip | Allowed IPv4 | None |
| `whitelist6` | hash:ip inet6 | Allowed IPv6 | None |
| `blacklist` | hash:ip | Banned IPv4 | 3600s |
| `blacklist6` | hash:ip inet6 | Banned IPv6 | 3600s |
| `spamhaus` | hash:net | Spamhaus DROP IPv4 | None |
| `spamhaus6` | hash:net inet6 | Spamhaus DROP IPv6 | None |
| `fail2ban` | hash:ip | Fail2ban bans | 3600s |

**Atomic update / Aggiornamento atomico:**
```
1. Create temp set (whitelist_tmp)
2. Populate with resolved IPs
3. Atomic swap: whitelist_tmp <-> whitelist
4. Destroy temp set
```

---

## Kernel Hardening (sysctl)

File: `/etc/sysctl.d/99-charizard.conf`

### Network Security / Sicurezza Rete

| Parameter | Value | EN | IT |
|-----------|-------|----|----|
| `tcp_syncookies` | 1 | SYN flood protection | Protezione SYN flood |
| `accept_source_route` | 0 | Reject source routing | Rifiuta source routing |
| `accept_redirects` | 0 | Ignore ICMP redirects | Ignora redirect ICMP |
| `rp_filter` | 1 | Drop spoofed packets | Droppa pacchetti spoofed |
| `log_martians` | 1 | Log impossible sources | Log sorgenti impossibili |
| `tcp_rfc1337` | 1 | Prevent TIME-WAIT hijack | Previeni hijack TIME-WAIT |

### System Security / Sicurezza Sistema

| Parameter | Value | EN | IT |
|-----------|-------|----|----|
| `randomize_va_space` | 2 | Full ASLR | ASLR completo |
| `dmesg_restrict` | 1 | Restrict dmesg to root | dmesg solo per root |
| `kptr_restrict` | 2 | Hide kernel pointers | Nascondi puntatori kernel |
| `perf_event_paranoid` | 3 | Disable perf for users | Disabilita perf per utenti |
| `protected_hardlinks` | 1 | Restrict hardlinks | Restrizioni hardlink |
| `protected_symlinks` | 1 | Restrict symlinks | Restrizioni symlink |
| `yama.ptrace_scope` | 1 | Restrict ptrace | Restrizioni ptrace |

### Performance

| Parameter | Value | EN | IT |
|-----------|-------|----|----|
| `tcp_max_syn_backlog` | 4096 | SYN queue size | Dimensione coda SYN |
| `netdev_max_backlog` | 5000 | Packet queue size | Dimensione coda pacchetti |
| `tcp_fin_timeout` | 30 | Faster socket release | Rilascio socket veloce |
| `rmem_max/wmem_max` | 16MB | Large TCP buffers | Buffer TCP grandi |

---

## Logging

| File | Purpose / Scopo |
|------|-----------------|
| `/var/log/charizard.log` | Firewall events (3 day retention) |
| `/var/log/charizard-bot.log` | Telegram bot log |
| `/var/log/charizard-s3.log` | S3 backup log |

**Log Prefixes:**

| Prefix | EN | IT |
|--------|----|----|
| `CHARIZARD_BLOCK` | Default policy block | Blocco policy default |
| `CHARIZARD_DROP` | Blacklisted IP | IP in blacklist |
| `CHARIZARD_SPAM` | Spamhaus DROP | Spamhaus DROP |
| `CHARIZARD_SCAN` | Port scan detected | Port scan rilevato |

---

## Fail2ban Integration / Integrazione Fail2ban

| Setting | Value | EN | IT |
|---------|-------|----|----|
| Max Retry | 5 | Failed attempts | Tentativi falliti |
| Ban Time | 1h | Ban duration | Durata ban |
| Find Time | 10m | Counting window | Finestra conteggio |

Files:
- `/etc/fail2ban/action.d/charizard.conf` - Custom ipset action
- `/etc/fail2ban/jail.local` - SSH jail config

---

## Systemd Timers

| Timer | Interval | EN | IT |
|-------|----------|----|----|
| `charizard-update.timer` | 5min | Whitelist DNS update | Aggiorna DNS whitelist |
| `charizard-spamhaus.timer` | 6h | Spamhaus list update | Aggiorna liste Spamhaus |
| `charizard-notify.timer` | 5min | Alert checks | Controlli alert |
| `charizard-report.timer` | 07:30 | Daily Telegram report | Report giornaliero |
| `charizard-s3-backup.timer` | 03:00 | S3 backup | Backup S3 |

```bash
charizard timers       # Status
systemctl list-timers charizard*
```

---

## Monitor Dashboard (cmon)

7 panels tmux dashboard / Dashboard tmux 7 pannelli:

| Panel | Tool | EN | IT |
|-------|------|----|----|
| iftop | `iftop` | Live bandwidth | Banda live |
| btop | `btop` | System monitor | Monitor sistema |
| SSH Log | `journalctl` | SSH access log | Log accessi SSH |
| Stats | `stats.sh` | Firewall statistics | Statistiche firewall |
| Live Log | colored | Firewall events | Eventi firewall |
| Shell | `bash` | Ready shell | Shell pronta |
| nethogs | `nethogs` | Per-process bandwidth | Banda per processo |

**Log Colors / Colori Log:**

| Tag | Color | EN | IT |
|-----|-------|----|----|
| `[SPAM]` | Purple | Spamhaus block | Blocco Spamhaus |
| `[BLCK]` | Cyan | Policy block | Blocco policy |
| `[SCAN]` | Yellow | Port scan | Port scan |
| `[DROP]` | Red | Explicit drop | Drop esplicito |
| `[BAN!]` | Bright Red | Manual ban | Ban manuale |

---

## Bash Customizations / Personalizzazioni Bash

Charizard installs system-wide shell enhancements in `/etc/profile.d/`.

### Aliases

| Alias | Command | EN | IT |
|-------|---------|----|----|
| `ll` | `ls -alF` | Long list | Lista lunga |
| `la` | `ls -A` | List all | Lista tutto |
| `lt` | `ls -alFtr` | List by time | Lista per tempo |
| `..` / `...` | `cd ..` / `cd ../..` | Navigate up | Naviga su |
| `gs` | `git status` | Git status | Stato git |
| `ga` | `git add` | Git add | Git add |
| `gc` | `git commit` | Git commit | Git commit |
| `gp` | `git push` | Git push | Git push |
| `gl` | `git log --oneline -20` | Compact log | Log compatto |
| `ports` | `ss -tulpn` | Show ports | Mostra porte |
| `listen` | `ss -tulpn \| grep LISTEN` | Listening ports | Porte in ascolto |
| `meminfo` | `free -h` | Memory usage | Uso memoria |
| `diskinfo` | `df -h` | Disk usage | Uso disco |
| `topcpu` | `ps aux --sort=-%cpu \| head` | Top CPU | Top CPU |
| `topmem` | `ps aux --sort=-%mem \| head` | Top memory | Top memoria |
| `myip` | `curl -s ifconfig.me` | Public IP | IP pubblico |

### Prompt

Powerline-style prompt / Prompt stile Powerline:

```
+--[user@hostname]--[/current/path]--[git-branch*]--[HH:MM:SS]
+---> command
```

Features / Caratteristiche:
- Git branch + dirty indicator (`*`)
- Exit code on error (`X 1 >`)
- Color-coded components / Componenti colorati

### Shell Options

| Option | EN | IT |
|--------|----|----|
| `HISTSIZE=10000` | Commands in memory | Comandi in memoria |
| `autocd` | Type dir to cd | Scrivi dir per cd |
| `cdspell` | Autocorrect cd typos | Correggi typo cd |
| `globstar` | `**` recursive match | `**` match ricorsivo |

### Vim Config

File: `/etc/vim/vimrc.local`

- Line numbers (relative) / Numeri riga (relativi)
- Syntax highlighting / Evidenziazione sintassi
- 4 spaces indent / Indentazione 4 spazi
- Smart search / Ricerca smart

---

## Installed Files / File Installati

```
/etc/firewall/
+-- firewall.sh          # Main script
+-- whitelist.json       # Allowed hosts
+-- openports.json       # Public ports
+-- telegram.json        # Telegram config
+-- s3-backup.json       # S3 config
+-- notify.json          # Notify config
+-- spamhaus_drop.txt    # Cached Spamhaus IPv4
+-- spamhaus_dropv6.txt  # Cached Spamhaus IPv6
+-- monitor/
    +-- cmon.sh          # Dashboard
    +-- stats.sh         # Stats panel

/etc/systemd/system/
+-- charizard.service         # Boot apply
+-- charizard-update.*        # Whitelist timer
+-- charizard-spamhaus.*      # Spamhaus timer
+-- charizard-bot.service     # Telegram bot
+-- charizard-report.*        # Daily report
+-- charizard-s3-backup.*     # S3 backup
+-- charizard-notify.*        # Notifications

/etc/sysctl.d/99-charizard.conf    # Kernel hardening
/etc/rsyslog.d/10-charizard.conf   # Log routing
/etc/logrotate.d/charizard         # Log rotation
/etc/bash_completion.d/charizard   # Tab completion

/etc/profile.d/
+-- charizard-aliases.sh     # 50+ aliases
+-- charizard-prompt.sh      # Powerline prompt
+-- charizard-bashrc.sh      # Shell options

/etc/vim/vimrc.local         # Vim configuration
/var/log/charizard.log       # Firewall log
/usr/local/bin/charizard     # Symlink
/usr/local/bin/cmon          # Monitor symlink
```
