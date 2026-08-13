# NAS Setup Scripts

Idempotent scripts to put Docker on **OpenMediaVault**, then deploy:

| App | What it is | Access |
|-----|------------|--------|
| **Portainer** | Manage Docker from phone/browser | Tailscale `http://<TAILSCALE_IP>:9000` |
| **Vaultwarden** | Self-hosted Bitwarden-compatible password manager | Tailscale `http://<TAILSCALE_IP>:8080` |
| **Jellyfin** | Media server | LAN `http://<lan-ip>:8096` (discovery on LAN) |
| **RabbitMQ** | Message broker (projects stack) | Tailscale AMQP / management UI |
| **Registry** | Private Docker registry (projects stack) | Tailscale `http://<TAILSCALE_IP>:5000` |
| **TellegramService** | RabbitMQ → Telegram alerts (projects stack) | No host port; runs on `nas` network |
| **AI Trading** | Portfolio editor + scheduled advisor (projects stack) | Tailscale `http://<TAILSCALE_IP>:5100` |
| **Grafana + Loki** | Shared container logs (logging stack) | Tailscale `http://<TAILSCALE_IP>:3000` |

**Operator guide (start here):** **[docs/HOWTO_USE_SCRIPTS.md](docs/HOWTO_USE_SCRIPTS.md)** — first-time setup, updates, update one service, AI Trading, recipes.

Also: [AI Trading first-time](docs/AI_TRADING_FIRST_TIME.md) · [Push images from Mac](docs/PUSH_IMAGES_FROM_MAC.md) · [Logging (Loki/Grafana)](docs/LOGGING.md)

Published ports (except Jellyfin) bind to **Tailscale only** so Docker does not publish on `0.0.0.0` and bypass UFW onto the LAN. Tailscale encrypts traffic on your private tailnet; it is not anonymity.

Do not expose Vaultwarden to the public internet without HTTPS.

## Quick start

SSH into your OMV box as root (or use `sudo`).

```bash
git clone https://github.com/abhinavrawat882/nas-setup-scripts.git
cd nas-setup-scripts

cp config.env.example config.env
nano config.env   # set NAS_ROOT, PUID, PGID, TZ, TAILSCALE_IP, passwords

chmod +x setup.sh scripts/*.sh update.sh
sudo ./setup.sh
```

That runs, in order (first time only):

1. `scripts/01-install-docker.sh` — Docker via OMV-Extras / `openmediavault-compose` when OMV is detected
2. `scripts/02-prepare-dirs.sh` — data + media folders under `NAS_ROOT`
3. `scripts/03-deploy-stack.sh` — core stack `docker compose up -d`

**You do not need to run `./setup.sh` again** to update apps. Setup is idempotent and keeps bind-mounted data, but day-to-day updates should use `./update.sh` so Docker install / Portainer wizard are not part of the flow.

Optional projects stack (RabbitMQ + Registry + TellegramService), after core is up:

```bash
# set RABBITMQ_*, REGISTRY_*, and TELEGRAM_* in config.env first
# push tellegramservice:latest to the registry (see below), then:
sudo ./scripts/05-deploy-projects.sh
```

## Updating containers later

Full recipes (first-time vs update-all vs one service): **[docs/HOWTO_USE_SCRIPTS.md](docs/HOWTO_USE_SCRIPTS.md)**.

Pull newer images and recreate containers. **Portainer login, Jellyfin config/libraries, and Vaultwarden vault stay on disk** under `NAS_ROOT` — only the container image/layers are refreshed.

```bash
# Update all (Portainer + Jellyfin + Vaultwarden)
sudo ./update.sh

# Update one app
sudo ./update.sh jellyfin
sudo ./update.sh portainer
sudo ./update.sh vaultwarden

# Optional: also delete unused old images afterward
sudo ./update.sh --prune
```

After changing `config.env` (ports, signup flag, paths, Tailscale IP), either `sudo ./update.sh` or `sudo ./scripts/03-deploy-stack.sh` applies it. For the projects stack, use `sudo ./scripts/05-deploy-projects.sh`.

## Configure `config.env`

| Variable | Purpose |
|----------|---------|
| `NAS_ROOT` | Base path on your data disk (e.g. `/srv/dev-disk-by-uuid-…/nas`) |
| `PUID` / `PGID` | File ownership inside containers (OMV: often your uid + group `users` = `100`) |
| `TZ` | Timezone |
| `MEDIA_PATH` | Optional override; default `${NAS_ROOT}/media` |
| `TAILSCALE_IP` | NAS Tailscale IP (default `100.92.27.123`); Portainer/Vaultwarden/RabbitMQ/Registry bind here |
| `PORTAINER_PORT` / `JELLYFIN_PORT` / `VAULTWARDEN_PORT` | Host ports |
| `VAULTWARDEN_SIGNUPS_ALLOWED` | `true` until you create an account, then `false` |
| `RABBITMQ_USER` / `RABBITMQ_PASS` | Broker credentials (change from `changeme`) |
| `REGISTRY_USER` / `REGISTRY_PASS` | Registry basic auth (change from `changeme`) |
| `REGISTRY_KEEP_TAGS` | Tags to keep per repo when running GC with `--prune` (default `5`) |
| `TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID` | Bot credentials for TellegramService |
| `AI_TRADING_PORT` | Tailscale port for AI Trading dashboard (default `5100`) |
| `GEMINI_API_KEY` | Optional; passed into the ai-trading container |
| `GRAFANA_PORT` | Tailscale port for Grafana (default `3000`) |
| `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD` | Grafana login (change password from `changeme`) |

`config.env` and generated `compose/.env` / `compose/projects/.env` are gitignored.

## After deploy (core)

1. **Portainer** — over Tailscale, open `http://<TAILSCALE_IP>:9000`, create the admin user, choose **Docker** / local environment.
2. **Jellyfin** — on the LAN, open `http://<lan-ip>:8096`, finish the setup wizard, and add libraries:
   - Movies → `/data/movies`
   - TV → `/data/tv`
   - Music → `/data/music`  
   Put files in `movies/`, `tv/`, `music/` under your media path on the NAS.
3. **Vaultwarden** — over Tailscale, open `http://<TAILSCALE_IP>:8080`, create your account. Then set `VAULTWARDEN_SIGNUPS_ALLOWED=false` and re-run deploy or `update.sh`. Point the Bitwarden app at `http://<TAILSCALE_IP>:8080`.

## Projects stack (RabbitMQ + Registry + TellegramService + AI Trading)

```bash
sudo ./scripts/05-deploy-projects.sh
```

| Service | Tailscale URL / endpoint | From other containers on `nas` |
|---------|--------------------------|--------------------------------|
| RabbitMQ AMQP | `<TAILSCALE_IP>:5672` | `rabbitmq:5672` |
| RabbitMQ Management | http://`<TAILSCALE_IP>`:15672 | — |
| Registry | http://`<TAILSCALE_IP>`:5000 | `registry:5000` (in-network only) |
| TellegramService | (no host port) | container `tellegram` |
| AI Trading Advisor | http://`<TAILSCALE_IP>`:5100 | container `ai-trading` |

Set `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID` in `config.env` before deploy (or the worker will crash-loop).

Optional AI Trading: see **[docs/AI_TRADING_FIRST_TIME.md](docs/AI_TRADING_FIRST_TIME.md)**.

Short path (NAS already has RabbitMQ/Registry/Tellegram):

```bash
# Mac — push image
cd "/Users/arno/Documents/Projects/AI Trading" && ./scripts/build-push-nas.sh

# NAS — create /srv/nas/docker/ai-trading + seed config, then edit
sudo ./scripts/07-setup-ai-trading.sh
sudo nano /srv/nas/docker/ai-trading/config.yaml   # capital, holds
sudo ./scripts/07-setup-ai-trading.sh --deploy
```

Dashboard: `http://<TAILSCALE_IP>:5100`. Ofelia: Mon–Fri 07:00 / 19:00 (`TZ`; prefer `Asia/Kolkata`).

## Logging stack (Loki + Grafana + Alloy)

Shared logs for **all** Docker containers on the NAS. Full guide: **[docs/LOGGING.md](docs/LOGGING.md)**.

```bash
# in config.env:
#   GRAFANA_PORT=3000
#   GRAFANA_ADMIN_USER=admin
#   GRAFANA_ADMIN_PASSWORD='strong-password'

sudo ./scripts/08-deploy-logging.sh
```

| Service | Tailscale URL |
|---------|----------------|
| Grafana | `http://<TAILSCALE_IP>:3000` |
| Loki / Alloy | no host port (internal) |

In Grafana → **Explore** → Loki → `{container="ai-trading"}`.

Image pulls use **`${TAILSCALE_IP}:5000/...`** on the Docker host (not the compose DNS name `registry`). `05-deploy-projects.sh` adds that endpoint to `/etc/docker/daemon.json` `insecure-registries` automatically.

### Push TellegramService image (from your Mac)

See **[docs/PUSH_IMAGES_FROM_MAC.md](docs/PUSH_IMAGES_FROM_MAC.md)** for the shared Mac → NAS registry
workflow (`crane --insecure`). Docker Desktop `docker push` usually fails against this HTTP registry.

```bash
cd /path/to/TellegramService
brew install crane   # once
bash scripts/build-push-nas.sh
```

On the NAS, pull/recreate:

```bash
sudo ./scripts/05-deploy-projects.sh
# or: cd compose/projects && sudo docker compose --env-file .env up -d tellegram
```

Mac apps (e.g. AI Trading) publish alerts to `<TAILSCALE_IP>:5672` with the same `RABBITMQ_USER` / `RABBITMQ_PASS`.

### Push AI Trading image (from your Mac)

```bash
cd "/Users/arno/Documents/Projects/AI Trading"
./scripts/build-push-nas.sh
```

First-time on NAS (creates `/srv/nas/docker/ai-trading`, seeds config, tells you what to nano):

```bash
sudo ./scripts/07-setup-ai-trading.sh
sudo nano /srv/nas/docker/ai-trading/config.yaml
sudo ./scripts/07-setup-ai-trading.sh --deploy
```

Full walkthrough: **[docs/AI_TRADING_FIRST_TIME.md](docs/AI_TRADING_FIRST_TIME.md)**

Dashboard: `http://<TAILSCALE_IP>:5100` — Portfolio page edits holdings; Telegram alerts include a Tailscale link to the HTML report. Schedule: Mon–Fri 07:00 and 19:00 (`TZ` in config.env; prefer `Asia/Kolkata`).

### RabbitMQ reliability

Data lives under `$NAS_ROOT/docker/rabbitmq`. The container uses a fixed node name (`rabbit@nas` / `hostname: nas`) so recreating the container does not orphan the durable database. There is **no tight RAM cap** so home workloads can use available memory; `disk_free_limit` stops publishes if the NAS disk is nearly full.

For messages that must not be lost, apps should:

- Prefer **quorum queues** (or durable classic queues + persistent messages)
- Use **publisher confirms**
- Use **manual consumer acks** (no auto-ack for critical work)

### Private registry (push / pull)

On any Docker host that pushes or pulls (including this NAS if you pull by Tailscale IP **or MagicDNS hostname**), add to Docker Desktop → Settings → Docker Engine (Mac) or `/etc/docker/daemon.json` (Linux), then restart Docker:

```json
{
  "insecure-registries": ["arnosatlas:5000", "100.92.27.123:5000"]
}
```

Use your real Tailscale IP / MagicDNS name if different. Without this, `docker login` / `push` fails with: `http: server gave HTTP response to HTTPS client`.

On the NAS, `scripts/05-deploy-projects.sh` writes `${TAILSCALE_IP}:${REGISTRY_PORT}` into `/etc/docker/daemon.json` for you.

```bash
docker login <TAILSCALE_IP>:5000
docker tag myapp:latest <TAILSCALE_IP>:5000/myapp:latest
docker push <TAILSCALE_IP>:5000/myapp:latest
```

Compose services that pull local images must use `image: ${TAILSCALE_IP}:5000/myapp:latest` — the hostname `registry` only resolves **inside** containers on the `nas` network, not for host-side `docker pull`.

### Registry garbage collection

Deleting tags does not free disk until GC runs. Periodically:

```bash
# Optional: delete older tags (keep REGISTRY_KEEP_TAGS newest per repo), then GC
sudo ./scripts/06-registry-gc.sh --prune

# GC only (stops registry briefly, throwaway container, starts again)
sudo ./scripts/06-registry-gc.sh

# Preview
sudo ./scripts/06-registry-gc.sh --dry-run
```

Check usage: `du -sh "$NAS_ROOT/docker/registry"`.

## Layout on disk

```
$NAS_ROOT/
  docker/
    portainer/
    jellyfin/config/
    vaultwarden/
    rabbitmq/
    registry/
    registry-auth/
    ai-trading/
      config.yaml
      data/{portfolio,stocks_cache,reports}/
    loki/
    grafana/
    alloy/
  media/{movies,tv,music}/
```

## Useful commands

```bash
# Update images (preferred after first setup)
sudo ./update.sh

# Apply config.env / recreate core or projects
sudo ./scripts/03-deploy-stack.sh
sudo ./scripts/05-deploy-projects.sh

# Registry cleanup
sudo ./scripts/06-registry-gc.sh --prune

# Stop containers (keeps all data)
sudo ./scripts/uninstall-stack.sh

# Logs
cd compose && sudo docker compose --env-file .env logs -f
cd compose/projects && sudo docker compose --env-file .env logs -f
```

## Notes

- App state lives in bind mounts under `NAS_ROOT/docker/...`. Updating or recreating containers does **not** wipe Portainer’s admin user, Jellyfin’s library setup, or Vaultwarden passwords.
- **Jellyfin** libraries are mounted read-only at `/data/{movies,tv,music}` inside the container. Jellyfin ports stay on the LAN for local discovery (`8096`, `7359/udp`).
- If you previously deployed Plex from an older revision, deploy/update removes the `plex` container automatically; your media files are untouched.
- Other services bind to `TAILSCALE_IP` so they are not reachable on the LAN via Docker’s default `0.0.0.0` publish (which bypasses UFW).
- Scripts prefer **OMV-Extras** + `openmediavault-compose` on OpenMediaVault. On plain Debian/Ubuntu they fall back to Docker CE.
- Ensure Tailscale is up on the NAS (`tailscale up`) before deploy so binds to `TAILSCALE_IP` succeed.

## Uninstall

```bash
sudo ./scripts/uninstall-stack.sh
```

Stops projects (if present) then core. Everything under `NAS_ROOT` stays so you can redeploy later.
