# Charizard Commands / Comandi

Complete command reference / Riferimento completo dei comandi.

---

## Core / Base

| Command | EN | IT |
|---------|----|----|
| `charizard apply` | Apply firewall rules | Applica regole firewall |
| `charizard update` | Update whitelist DNS | Aggiorna DNS whitelist |
| `charizard reload` | Update + Apply | Aggiorna + Applica |
| `charizard flush` | Emergency disable | Disabilita (emergenza) |
| `charizard rollback` | Restore from backup | Ripristina da backup |
| `charizard show` | Show iptables rules | Mostra regole iptables |
| `charizard status` | Stats + counters | Statistiche + contatori |
| `charizard watch` | Live monitor | Monitor live |
| `charizard version` | Show version | Mostra versione |

---

## IP Management / Gestione IP

| Command | EN | IT |
|---------|----|----|
| `charizard ban <ip>` | Ban IP (auto-expire: 1h) | Banna IP (scadenza: 1h) |
| `charizard unban <ip>` | Remove ban | Rimuovi ban |
| `charizard add <ip>` | Temp whitelist (until reboot) | Whitelist temp (fino a reboot) |
| `charizard allow <host>` | Add host/IP to config | Aggiungi host/IP al config |
| `charizard deny <host>` | Remove host/IP from config | Rimuovi host/IP dal config |
| `charizard hosts` | List whitelisted hosts | Lista host in whitelist |

---

## Port Management / Gestione Porte

| Command | EN | IT |
|---------|----|----|
| `charizard open <port>` | Add port to config | Aggiungi porta al config |
| `charizard close <port>` | Remove port from config | Rimuovi porta dal config |
| `charizard ports` | List open ports | Lista porte aperte |

---

## Security / Sicurezza

| Command | EN | IT |
|---------|----|----|
| `charizard spamhaus` | Spamhaus DROP status | Stato Spamhaus DROP |
| `charizard spamhaus update` | Force Spamhaus update | Forza aggiornamento |
| `charizard f2b` | Fail2ban status | Stato Fail2ban |
| `charizard f2b ban <ip>` | Manual fail2ban ban | Ban manuale fail2ban |
| `charizard f2b unban <ip>` | Remove fail2ban ban | Rimuovi ban fail2ban |

---

## GeoIP

| Command | EN | IT |
|---------|----|----|
| `charizard geo lookup <ip>` | Show country for IP | Mostra paese per IP |
| `charizard geo top [n]` | Top n countries blocked | Top n paesi bloccati |
| `charizard geo stats` | GeoIP status | Stato GeoIP |

Note: `charizard log` and `charizard top` now show country codes.
Nota: `charizard log` e `charizard top` mostrano ora i codici paese.

---

## Monitoring / Monitoraggio

| Command | EN | IT |
|---------|----|----|
| `charizard log [n]` | Last n log entries (def: 20) | Ultimi n log (def: 20) |
| `charizard top [n]` | Top n blocked IPs (def: 10) | Top n IP bloccati (def: 10) |
| `charizard report` | Generate full report | Genera report completo |
| `charizard doctor` | Health check | Controllo salute |

---

## System / Sistema

| Command | EN | IT |
|---------|----|----|
| `charizard backup` | Backup config | Backup configurazione |
| `charizard restore [file]` | Restore from backup | Ripristina da backup |
| `charizard upgrade` | Self-update | Auto-aggiornamento |
| `charizard upgrade force` | Force update | Forza aggiornamento |

---

## Disk & I/O

| Command | EN | IT |
|---------|----|----|
| `charizard disk` | Disk usage overview | Overview uso disco |
| `charizard disk find SIZE` | Find files > SIZE | Trova file > SIZE |
| `charizard disk clean` | Cleanup suggestions | Suggerimenti pulizia |
| `charizard io` | I/O statistics | Statistiche I/O |
| `charizard io top` | Top I/O processes | Top processi I/O |
| `charizard io watch` | Live I/O monitoring | Monitor I/O live |

---

## Timers

| Command | EN | IT |
|---------|----|----|
| `charizard timers` | Charizard timers status | Stato timer Charizard |
| `charizard timers all` | All system timers | Tutti i timer sistema |
| `charizard timers next` | Next scheduled | Prossime esecuzioni |

---

## Telegram Bot

Setup: copy `examples/telegram.example.json` to `/etc/firewall/telegram.json`

| Command | EN | IT |
|---------|----|----|
| `charizard tg status` | Bot status | Stato bot |
| `charizard tg test` | Send test message | Invia messaggio test |
| `charizard tg report` | Send report now | Invia report ora |
| `charizard tg enable` | Enable bot | Abilita bot |
| `charizard tg disable` | Disable bot | Disabilita bot |

**Telegram Commands / Comandi Telegram:**

| Command | EN | IT |
|---------|----|----|
| `/status` | Firewall status | Stato firewall |
| `/top [n]` | Top blocked IPs | Top IP bloccati |
| `/log [n]` | Recent logs | Log recenti |
| `/ban <ip>` | Ban IP | Banna IP |
| `/unban <ip>` | Unban IP | Sbanna IP |
| `/reload` | Reload firewall | Ricarica firewall |
| `/help` | Command list | Lista comandi |

---

## S3 Backup

Setup: copy `examples/s3-backup.example.json` to `/etc/firewall/s3-backup.json`

| Command | EN | IT |
|---------|----|----|
| `charizard s3 status` | Backup status | Stato backup |
| `charizard s3 test` | Test S3 connection | Test connessione S3 |
| `charizard s3 backup` | Backup now | Backup ora |
| `charizard s3 list` | List backups | Lista backup |
| `charizard s3 restore <f>` | Restore backup | Ripristina backup |
| `charizard s3 enable` | Enable daily timer | Abilita timer |
| `charizard s3 disable` | Disable timer | Disabilita timer |
| `charizard s3 folders` | List backup folders | Lista cartelle backup |
| `charizard s3 addf <path>` | Add folder | Aggiungi cartella |
| `charizard s3 rmf <path>` | Remove folder | Rimuovi cartella |

**Providers:**

| Provider | endpoint | region |
|----------|----------|--------|
| AWS S3 | *(empty)* | `eu-west-1` |
| MinIO | `https://your-minio:9000` | custom |
| Backblaze B2 | `https://s3.us-west-001.backblazeb2.com` | `us-west-001` |

---

## Monitor (cmon)

| Command | EN | IT |
|---------|----|----|
| `cmon` | Default layout (5 panes, log focus) | Layout default (5 pannelli) |
| `cmon full` | Full layout (7 panes, + btop/SSH) | Layout completo (7 pannelli) |
| `cmon log` | Live colorized log only | Solo log colorizzato |
| `cmon stop` | Stop monitor session | Ferma sessione |
| `cmon help` | Show help | Mostra aiuto |

**Keyboard shortcuts / Scorciatoie:**

| Key | Action / Azione |
|-----|-----------------|
| `Q` | Quit monitor / Esci dal monitor |
| `q` | Quit current tool / Esci dallo strumento |
| `N` | Toggle navigation mode / Attiva navigazione |
| Arrows | Move between panes (in nav mode) |

---

## Notify Module / Modulo Notifiche

Setup: copy `examples/notify.example.json` to `/etc/firewall/notify.json`

| Command | EN | IT |
|---------|----|----|
| `charizard notify status` | Notification status | Stato notifiche |
| `charizard notify check` | Manual check | Controllo manuale |
| `charizard notify enable` | Enable timer | Abilita timer |
| `charizard notify disable` | Disable timer | Disabilita timer |
| `charizard notify reset` | Reset cooldowns | Reset cooldown |

**Alert Types / Tipi Alert:**

| Alert | EN | IT |
|-------|----|----|
| Ban | IP banned notification | Notifica IP bannato |
| Spike | Traffic spike detection | Rilevamento picchi |
| Scan | Port scan detection | Rilevamento port scan |
| SSH | SSH login notification (PAM) | Notifica login SSH (PAM) |
| Backup | S3 backup results | Risultati backup S3 |

**SSH Login Alert / Alert Login SSH:**

Sends Telegram notification on successful SSH login with user, IP, country (GeoIP).
Invia notifica Telegram ad ogni login SSH con utente, IP, paese (GeoIP).

Enable in `/etc/firewall/notify.json`:
```json
{
  "alerts": {
    "ssh": {
      "enabled": true
    }
  }
}
```

---

## Docker (Extra)

Requires: `charizard install docker`

| Command | EN | IT |
|---------|----|----|
| `charizard dps` | List containers | Lista container |
| `charizard dlogs <c>` | Follow container logs | Segui log container |
| `charizard dexec <c>` | Shell into container | Shell nel container |
| `charizard dstop <c\|all>` | Stop + save state | Ferma + salva stato |
| `charizard dstart <c\|all>` | Start from state | Avvia da stato |
| `charizard ddown` | Stop + remove all | Ferma + rimuovi tutto |
| `charizard drestart <c\|all>` | Restart container(s) | Riavvia container |

---

## DNS Module / Modulo DNS (Extra)

Requires: `charizard install dns`

| Command | EN | IT |
|---------|----|----|
| `charizard dns status` | DNS status | Stato DNS |
| `charizard dns start` | Start DNS | Avvia DNS |
| `charizard dns stop` | Stop DNS | Ferma DNS |
| `charizard dns restart` | Restart DNS | Riavvia DNS |
| `charizard dns logs` | Show logs | Mostra log |
| `charizard dns add` | Add local host | Aggiungi host locale |
| `charizard dns remove <n>` | Remove host | Rimuovi host |
| `charizard dns hosts` | List local hosts | Lista host locali |
| `charizard dns flush` | Flush DNS cache | Svuota cache DNS |
| `charizard dns test` | Test resolution | Test risoluzione |

---

## SSH Key Setup

```bash
./scripts/sshkeygen.sh                    # Interactive / Interattivo
./scripts/sshkeygen.sh --ip host --user u # With params / Con parametri
```

---

## Bash Customizations / Personalizzazioni Bash

Charizard installs shell enhancements / Charizard installa miglioramenti shell:

- **50+ aliases** (navigation, git, system, network)
- **Powerline prompt** with git branch
- **History 10k** entries with timestamps
- **Vim config** (syntax, numbers, indent)

**Key aliases / Alias principali:**

| Alias | Command |
|-------|---------|
| `ll` | `ls -alF` |
| `..` / `...` | `cd ..` / `cd ../..` |
| `gs` | `git status` |
| `ports` | `ss -tulpn` |
| `myip` | `curl -s ifconfig.me` |
| `topcpu` | Top CPU processes |
| `topmem` | Top memory processes |
