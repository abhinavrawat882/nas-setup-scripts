# NAS Setup Scripts — how to use (first time, updates, one service)

This is the **operator cheat sheet**. Your box already uses:

| Setting | Your value |
|---------|------------|
| `NAS_ROOT` | `/srv/nas` |
| Tailscale / MagicDNS | `arnosatlas` / `100.92.27.123` |
| Repo on NAS | wherever you cloned `nas-setup-scripts` |

Always run scripts from that repo on the NAS:

```bash
cd /path/to/nas-setup-scripts
sudo ./…
```

Data under `/srv/nas/docker/…` and `/srv/nas/media/…` is **bind-mounted**. Updating containers does **not** wipe Portainer, Vaultwarden, Jellyfin libraries, RabbitMQ, or AI Trading config/data.

---

## Script map (what each one is for)

| Script | When to use |
|--------|-------------|
| `./setup.sh` | **First time only** — install Docker + dirs + core stack |
| `scripts/01-install-docker.sh` | Docker missing / broken (rarely alone) |
| `scripts/02-prepare-dirs.sh` | Re-create folder layout under `NAS_ROOT` |
| `scripts/03-deploy-stack.sh` | Apply `config.env` + (re)start **core**: Portainer, Jellyfin, Vaultwarden |
| `./update.sh` [name] | Day-to-day **core** image updates (`jellyfin`, `portainer`, `vaultwarden`) |
| `scripts/05-deploy-projects.sh` | (Re)start **projects**: RabbitMQ, Registry, Tellegram, AI Trading |
| `scripts/07-setup-ai-trading.sh` | First-time AI Trading dirs + seed config (+ optional `--deploy`) |
| `scripts/06-registry-gc.sh` | Free registry disk (optional `--prune`) |
| `scripts/uninstall-stack.sh` | Stop/remove containers; **keeps** data on disk |

Related docs:

- [AI_TRADING_FIRST_TIME.md](AI_TRADING_FIRST_TIME.md)
- [PUSH_IMAGES_FROM_MAC.md](PUSH_IMAGES_FROM_MAC.md)

---

## 1) First-time setup (brand new NAS)

### Step A — clone + `config.env`

```bash
git clone https://github.com/abhinavrawat882/nas-setup-scripts.git
cd nas-setup-scripts
cp config.env.example config.env
sudo nano config.env
```

**Minimum to set:**

```bash
NAS_ROOT=/srv/nas
PUID=…          # your Linux uid
PGID=…          # often 100 (users) on OMV
TZ=Asia/Kolkata
TAILSCALE_IP=100.92.27.123

# Change these from changeme:
RABBITMQ_USER=…
RABBITMQ_PASS=…
REGISTRY_USER=…
REGISTRY_PASS=…

# For Telegram alerts:
TELEGRAM_BOT_TOKEN=…
TELEGRAM_CHAT_ID=…

# Optional:
AI_TRADING_PORT=5100
GEMINI_API_KEY=
```

### Step B — core stack (Portainer / Jellyfin / Vaultwarden)

```bash
chmod +x setup.sh scripts/*.sh update.sh
sudo ./setup.sh
```

Then finish wizards:

| App | URL |
|-----|-----|
| Portainer | `http://arnosatlas:9000` |
| Vaultwarden | `http://arnosatlas:8080` → create account → set `VAULTWARDEN_SIGNUPS_ALLOWED=false` → `sudo ./update.sh vaultwarden` |
| Jellyfin | `http://<lan-ip>:8096` |

### Step C — projects stack (RabbitMQ / Registry / Telegram)

1. On Mac, push **TellegramService** image (crane script in that repo).
2. On NAS:

```bash
sudo ./scripts/05-deploy-projects.sh
```

### Step D — AI Trading (optional)

1. On Mac: `cd "AI Trading" && ./scripts/build-push-nas.sh`
2. On NAS:

```bash
sudo ./scripts/07-setup-ai-trading.sh
sudo nano /srv/nas/docker/ai-trading/config.yaml   # capital, holds
sudo ./scripts/07-setup-ai-trading.sh --deploy
```

Open: `http://arnosatlas:5100`

**You do not run `./setup.sh` again** for normal updates.

---

## 2) Pull latest scripts from git (before updating)

When you change the repo on your Mac and push to GitHub:

```bash
cd /path/to/nas-setup-scripts
git pull
chmod +x setup.sh scripts/*.sh update.sh
```

Then run the update/deploy command you need below.

---

## 3) Update everything (day-to-day)

### Core apps (Portainer, Jellyfin, Vaultwarden)

```bash
sudo ./update.sh          # all three
sudo ./update.sh --prune  # also delete unused old images
```

### Projects stack (RabbitMQ, Registry, Tellegram, AI Trading)

```bash
sudo ./scripts/05-deploy-projects.sh
```

This rewrites `compose/projects/.env` from `config.env`, pulls images it can, and recreates containers. Bind mounts stay.

---

## 4) Update one specific thing

### Core — one app

```bash
sudo ./update.sh jellyfin
sudo ./update.sh portainer
sudo ./update.sh vaultwarden
```

### Projects — one service

From the projects compose directory:

```bash
cd /path/to/nas-setup-scripts
sudo ./scripts/05-deploy-projects.sh   # refreshes .env first (recommended)

# Or target one service after .env exists:
cd compose/projects
sudo docker compose --env-file .env pull tellegram
sudo docker compose --env-file .env up -d tellegram

sudo docker compose --env-file .env pull ai-trading
sudo docker compose --env-file .env up -d ai-trading ai-trading-ofelia

sudo docker compose --env-file .env up -d rabbitmq
sudo docker compose --env-file .env up -d registry
```

### After you change only `config.env`

| Changed | Apply with |
|---------|------------|
| Core ports / Tailscale / Vaultwarden signups / PUID | `sudo ./update.sh` or `sudo ./scripts/03-deploy-stack.sh` |
| RabbitMQ / Registry / Telegram / AI Trading env | `sudo ./scripts/05-deploy-projects.sh` |
| `TZ` (schedules) | projects deploy + recreate `ai-trading-ofelia` |

### After you change only AI Trading **config.yaml**

No rebuild needed — just restart the container:

```bash
sudo docker restart ai-trading
# or:
cd /path/to/nas-setup-scripts/compose/projects
sudo docker compose --env-file .env up -d ai-trading
```

### After you change AI Trading **code** (Mac)

```bash
# Mac
./scripts/build-push-nas.sh

# NAS
sudo ./scripts/05-deploy-projects.sh
# or only:
cd compose/projects && sudo docker compose --env-file .env pull ai-trading \
  && sudo docker compose --env-file .env up -d ai-trading ai-trading-ofelia
```

### After you change TellegramService **code** (Mac)

```bash
# Mac — that repo’s build-push script
bash scripts/build-push-nas.sh

# NAS
cd compose/projects
sudo docker compose --env-file .env pull tellegram
sudo docker compose --env-file .env up -d tellegram
```

---

## 5) Common “I want to…” recipes

| Goal | Commands |
|------|----------|
| Re-seed AI Trading folders/config | `sudo ./scripts/07-setup-ai-trading.sh` |
| Overwrite AI Trading config from template | `sudo ./scripts/07-setup-ai-trading.sh --force` then `sudo nano …` |
| Turn off Vaultwarden signups | Set `VAULTWARDEN_SIGNUPS_ALLOWED=false` in `config.env` → `sudo ./update.sh vaultwarden` |
| Free registry disk | `sudo ./scripts/06-registry-gc.sh --prune` |
| See what’s running | `docker ps` or Portainer |
| Logs | `docker logs -f ai-trading` / `tellegram` / `rabbitmq` |
| Stop everything, keep data | `sudo ./scripts/uninstall-stack.sh` |
| Start again after uninstall | `sudo ./scripts/03-deploy-stack.sh` then `sudo ./scripts/05-deploy-projects.sh` |

---

## 6) URLs (your NAS)

| Service | URL |
|---------|-----|
| Portainer | http://arnosatlas:9000 |
| Vaultwarden | http://arnosatlas:8080 |
| RabbitMQ management | http://arnosatlas:15672 |
| Registry | http://arnosatlas:5000 |
| AI Trading | http://arnosatlas:5100 |
| Jellyfin | http://\<lan-ip\>:8096 |

---

## 7) Mental model

```text
config.env  ──►  compose/.env           ──►  core containers
            └──►  compose/projects/.env  ──►  projects containers

Mac build  ──►  crane push  ──►  registry:5000/…  ──►  NAS docker pull
```

- **`setup.sh` / `update.sh` / `03`** → core (Hub images).
- **`05` / `07`** → projects (local registry images + RabbitMQ).
- **Never delete `/srv/nas/docker/…`** unless you intend to wipe that app’s state.
