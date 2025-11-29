<div align="center">

```
⠀⠀⠀⠀⠀⠀⠀⠀⢀⡀⠀⠀⠀⠄⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢀⢤⠈⢀⠀⢀⠀⠠⠀⠀⠀⠀⢖⠀⡀⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⢀⠄⠊⠐⠁⠀⠀⠀⡀⠀⠀⡅⠀⠀⠀⠀⡆⣤⣥⣂⠠⡀⠀⠀⠀
⠀⠀⡀⣡⣾⣿⡾⠀⠀⠀⢄⠈⠒⠀⠁⠀⠀⠀⢠⣸⣿⣿⣿⣿⣖⡀⠀⠀
⠀⠐⣼⣿⣿⣿⣿⣄⠀⠀⠈⠑⢆⡬⠜⠀⠀⠀⡄⣿⣿⣿⣿⣿⣿⣿⠄⠀
⢀⢳⣿⣿⣿⣿⣿⣿⡆⡀⢀⠀⠀⠃⠀⠀⡠⣠⢘⣿⣿⣿⣿⣿⣿⣿⣏⠆
⠘⣿⠟⢛⠝⠻⣿⡿⣿⣄⡎⠀⠀⠨⠠⣠⣇⠋⠈⢻⡿⠋⡻⠈⡙⢿⣿⠀
⢰⠁⠀⠓⠤⢄⠀⠀⡈⡜⠐⠂⢄⠀⠀⡙⢃⠀⠔⠿⢤⡀⡠⠀⠀⠀⠙⡆
⠀⠀⠀⠀⠀⠀⠈⠁⡘⠀⠀⠀⠀⠡⠀⠈⢂⠐⠀⠀⠀⠈⡐⡀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠔⡇⠀⠀⠀⠀⠀⠆⠀⠀⠡⡀⠀⠀⢀⠃⠁⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢸⠀⠐⡀⠀⠀⠀⠀⡆⠀⠀⠀⢡⣀⠠⠂⠀⡀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⢀⠄⠀⠈⡢⢀⡀⠀⠃⠀⠀⠀⡘⠀⠀⡀⠔⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠚⠂⣀⠠⠐⠁⠀⠁⠂⠤⣌⠀⠀⠑⠤⠑⠀⠀⠀⠀⠀⠀⠀
⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠁⠈⠀⠋⠀⠀⠀⠀⠀⠀⠀⠀⠀
```

# CHARIZARD

### Fireblast your packets

[![Version](https://img.shields.io/badge/version-1.0.1-orange.svg)](https://github.com/sanvilscript/charizard)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Linux-blue.svg)](https://www.linux.org/)
[![Debian](https://img.shields.io/badge/Debian-12%20|%2013-A81D33.svg?logo=debian)](https://www.debian.org/)

**Lightweight iptables + ipset firewall for Linux servers (IPv4 + IPv6)**

</div>

---

## Quick Install / Installazione Rapida

```bash
wget -qO- https://raw.githubusercontent.com/sanvilscript/charizard/main/bootstrap.sh | bash
```

<details>
<summary><b>Manual Install / Installazione Manuale</b></summary>

```bash
git clone https://github.com/sanvilscript/charizard.git
cd charizard
sudo bash install.sh
```

</details>

---

## Quick Start / Avvio Rapido

```bash
charizard status      # Show stats / Mostra statistiche
charizard watch       # Live monitor / Monitor live
charizard ban <ip>    # Ban IP (1h) / Banna IP (1h)
charizard allow <h>   # Add to whitelist / Aggiungi a whitelist
charizard open <p>    # Open port / Apri porta
charizard reload      # Update + Apply / Aggiorna + Applica
```

**Tab Completion:**
```bash
charizard <TAB>       # Show all commands / Mostra tutti i comandi
```

---

## Configuration / Configurazione

### Whitelist (`/etc/firewall/whitelist.json`)

```json
{
  "hosts": ["example.com", "192.168.1.100", "2001:db8::1"]
}
```

### Open Ports / Porte Aperte (`/etc/firewall/openports.json`)

```json
{
  "ports": [80, 443, 22]
}
```

---

## Protections / Protezioni

| Protection | Description / Descrizione |
|------------|---------------------------|
| Dual Stack | IPv4 + IPv6 mirroring |
| Spamhaus DROP | Botnet/spammer blocklist (6h update) |
| Fail2ban SSH | Brute-force protection (5 attempts, 1h ban) |
| Scan Detection | NULL/XMAS/FIN, illegal TCP flags |
| ICMP Limit | 10/sec (monitoring friendly) |
| Blacklist | ipset with 1h auto-expiry |

---

## Monitor (cmon)

Real-time dashboard / Dashboard in tempo reale:

```bash
sudo cmon        # Default layout (5 panes, focus log) / Layout default
sudo cmon full   # Full layout (7 panes, includes btop) / Layout completo
sudo cmon log    # Log only (colorized) / Solo log colorizzato
sudo cmon stop   # Stop / Ferma
```

**Default Layout / Layout Default (5 panes):**
```
+---------------+-------------------------------+
| Stats         |                               |
+---------------+        LIVE LOG               |
| iftop         |       (colorized)             |
+---------------+-------------------------------+
| nethogs       | Shell                         |
+---------------+-------------------------------+
```

**Full Layout / Layout Completo (`cmon full`, 7 panes):**
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

---

## Documentation / Documentazione

| Doc | Content / Contenuto |
|-----|---------------------|
| **[docs/commands.md](docs/commands.md)** | All commands reference / Riferimento comandi |
| **[docs/cmon.md](docs/cmon.md)** | Monitor dashboard guide / Guida dashboard |
| **[docs/extras.md](docs/extras.md)** | Docker, DNS module / Moduli extra |
| **[docs/advanced.md](docs/advanced.md)** | Architecture, sysctl, internals / Architettura |

---

## Uninstall / Disinstallazione

From cloned repo / Dalla repo clonata:
```bash
cd charizard
sudo bash uninstall.sh
```

Or download and run / Oppure scarica ed esegui:
```bash
wget -qO- https://raw.githubusercontent.com/sanvilscript/charizard/main/uninstall.sh | sudo bash
```

Removes firewall rules, configs, timers and restores system defaults.
Rimuove regole firewall, config, timer e ripristina i default di sistema.

---

## License / Licenza

MIT License - Copyright (c) 2025 Sanvil
