# Extra Modules / Moduli Extra

Additional features installed separately / Funzionalita aggiuntive installate separatamente.

---

## Docker Engine

### Install / Installa

```bash
charizard install docker
```

**Installs / Installa:**
- Docker Engine + Compose plugin
- User added to docker group / Utente aggiunto al gruppo docker

**Note:** Log out and back in for docker group to take effect, or run `newgrp docker`

### Container Commands / Comandi Container

| Command | EN | IT |
|---------|----|----|
| `charizard dps` | List containers | Lista container |
| `charizard dlogs <c>` | Follow logs | Segui log |
| `charizard dexec <c>` | Shell access | Accesso shell |
| `charizard dstop <c\|all>` | Stop + save state | Ferma + salva stato |
| `charizard dstart <c\|all>` | Start from state | Avvia da stato |
| `charizard ddown` | Stop + remove all | Ferma + rimuovi tutto |
| `charizard drestart <c\|all>` | Restart | Riavvia |

### State Management / Gestione Stato

State saved to / Stato salvato in: `/etc/firewall/docker-state.json`

```bash
charizard dstop all    # Stop all, save state / Ferma tutto, salva stato
# ... maintenance / manutenzione ...
charizard dstart all   # Restart saved / Riavvia salvati
```

---

## Portainer CE

Docker management UI / Interfaccia gestione Docker.

### Install / Installa

```bash
charizard install portainer
```

**Requires:** Docker (run `charizard install docker` first)

**Access / Accesso:** `https://SERVER_IP:9443`

### Commands / Comandi

| Command | EN | IT |
|---------|----|----|
| `charizard portainer status` | Show status | Mostra stato |
| `charizard portainer start` | Start Portainer | Avvia Portainer |
| `charizard portainer stop` | Stop Portainer | Ferma Portainer |
| `charizard portainer restart` | Restart Portainer | Riavvia Portainer |
| `charizard portainer logs` | Show logs | Mostra log |

### Location / Posizione

```
~/docker/portainer/
├── docker-compose.yml
└── data/
```

---

## DNS Module (Unbound) / Modulo DNS

Private recursive DNS resolver / Resolver DNS ricorsivo privato.

### Install / Installa

```bash
charizard install dns
```

**Requires:** Docker (run `charizard install docker` first)

**Features / Caratteristiche:**
- Custom Debian slim Docker image / Immagine Docker Debian slim
- DNSSEC validation / Validazione DNSSEC
- Local domain resolution (.local, .lan, .home)
- Root hints auto-update
- Replaces systemd-resolved / Sostituisce systemd-resolved

### Commands / Comandi

| Command | EN | IT |
|---------|----|----|
| `charizard dns status` | Show status | Mostra stato |
| `charizard dns start` | Start DNS | Avvia DNS |
| `charizard dns stop` | Stop DNS | Ferma DNS |
| `charizard dns restart` | Restart DNS | Riavvia DNS |
| `charizard dns logs` | View logs | Mostra log |
| `charizard dns test` | Test resolution | Test risoluzione |

### Local Hosts / Host Locali

```bash
charizard dns add <host> <ip>  # Add host / Aggiungi host
charizard dns hosts            # List hosts / Lista host
charizard dns remove <name>    # Remove host / Rimuovi host
charizard dns flush            # Reload config / Ricarica config
```

**Config file:** `/etc/firewall/dns/hosts.json`

```json
{
  "hosts": [
    {"name": "myserver.local", "ip": "192.168.1.100"},
    {"name": "db.lan", "ip": "10.0.0.50"}
  ]
}
```

### Test

```bash
dig @127.0.0.1 google.com           # External / Esterno
dig @127.0.0.1 myserver.local       # Local / Locale
```

### Files

| File | Purpose / Scopo |
|------|-----------------|
| `/etc/firewall/dns/` | Main directory |
| `docker-compose.yml` | Container config |
| `config/unbound.conf` | Unbound config |
| `data/hosts.local` | Generated hosts |
| `hosts.json` | Local hosts (Charizard format) |

---

## Installation Location / Posizione Installazione

Extra modules are installed in / I moduli extra sono installati in:

```
/etc/firewall/
├── docker-state.json    # Docker state
└── dns/                 # DNS module
    ├── docker-compose.yml
    ├── Dockerfile
    ├── config/unbound.conf
    ├── data/
    └── hosts.json

~/docker/
└── portainer/           # Portainer
    ├── docker-compose.yml
    └── data/
```

---

## Uninstall / Disinstallazione

**Docker:**
```bash
sudo apt purge docker-ce docker-ce-cli containerd.io
```

**Portainer:**
```bash
cd ~/docker/portainer
docker compose down -v
rm -rf ~/docker/portainer
```

**DNS:**
```bash
cd /etc/firewall/dns
docker compose down -v
# Restore systemd-resolved / Ripristina systemd-resolved
sudo chattr -i /etc/resolv.conf
sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
sudo systemctl enable --now systemd-resolved
```
