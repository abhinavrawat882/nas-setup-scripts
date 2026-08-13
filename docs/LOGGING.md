# Loki + Grafana + Alloy — shared logging on the NAS

Collects **stdout/stderr from every Docker container** on the host into Loki.
Browse / search in Grafana over **Tailscale only**.

| Service | Role | Access |
|---------|------|--------|
| **Grafana** | Search UI | `http://arnosatlas:3000` (or `http://<TAILSCALE_IP>:3000`) |
| **Loki** | Log store | Internal only (`http://loki:3100` on `nas` network) |
| **Alloy** | Scrapes Docker logs → Loki | No host port |

Retention default: **14 days** (`compose/logging/loki-config.yml`).

Full operator map: [HOWTO_USE_SCRIPTS.md](HOWTO_USE_SCRIPTS.md).

---

## Architecture

```text
  ai-trading / tellegram / rabbitmq / jellyfin / …
                    │ stdout / stderr
                    ▼
              Docker engine
                    │
                    ▼
         Alloy  (reads docker.sock)
                    │
                    ▼
                  Loki
                    │
                    ▼
         Grafana  ← Tailscale :3000
```

Alloy discovers containers automatically. Any new compose service that logs to stdout shows up in Grafana without extra wiring.

---

## Files in this repo

| Path | Purpose |
|------|---------|
| `compose/logging/docker-compose.yml` | Loki + Alloy + Grafana |
| `compose/logging/loki-config.yml` | Retention, filesystem storage |
| `compose/logging/alloy-config.alloy` | Docker log scrape → Loki |
| `compose/logging/grafana/provisioning/datasources/datasource.yml` | Auto-adds Loki in Grafana |
| `scripts/08-deploy-logging.sh` | Create dirs, write `.env`, pull, start |
| `docs/LOGGING.md` | This guide |

Data on disk (`NAS_ROOT=/srv/nas`):

```text
/srv/nas/docker/loki/
/srv/nas/docker/grafana/
/srv/nas/docker/alloy/
```

---

## First-time setup

### Prerequisites

- Core stack already running (`nas` Docker network exists) — Portainer/Jellyfin is enough
- Tailscale up on the NAS and on your phone/laptop

### 1) Edit `config.env` on the NAS

```bash
cd ~/nas-setup-scripts
git pull
sudo nano config.env
```

Add or set:

```bash
LOGGING_COMPOSE_PROJECT_NAME=nas-logging
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD='pick-a-strong-password'
TZ=Asia/Kolkata
```

| Variable | Meaning |
|----------|---------|
| `GRAFANA_PORT` | Host port on Tailscale IP (default `3000`) |
| `GRAFANA_ADMIN_USER` | First Grafana login user |
| `GRAFANA_ADMIN_PASSWORD` | First Grafana login password — **change from `changeme`** |
| `TZ` | Container timezone (affects log timestamps display context) |

### 2) Deploy

```bash
chmod +x scripts/*.sh
sudo ./scripts/08-deploy-logging.sh
```

What the script does:

1. Creates `/srv/nas/docker/{loki,grafana,alloy}` with correct ownership
2. Writes `compose/logging/.env` from `config.env`
3. Pulls images and starts `loki`, `alloy`, `grafana`

### 3) Open Grafana

1. Tailscale on → **http://arnosatlas:3000**
2. Login with `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`
3. Left menu → **Explore**
4. Datasource dropdown → **Loki** (already provisioned)
5. Run a query (examples below)

---

## Useful LogQL queries

In Explore, set time range to **Last 15 minutes** or **Last 1 hour** while debugging.

```logql
# Everything from AI Trading
{container="ai-trading"}

# AI Trading errors / failures / tracebacks
{container="ai-trading"} |~ "(?i)error|traceback|failed|exception"

# Analysis / advisor lines
{container="ai-trading"} |~ "(?i)analysis|run_advisor"

# TellegramService
{container="tellegram"}

# RabbitMQ
{container="rabbitmq"}

# Any container containing text
{job="docker"} |= "analysis"

# Live-ish: all docker logs (noisy)
{job="docker"}
```

Label tips:

- `container` = Docker container name (`ai-trading`, `tellegram`, …)
- `stream` = `stdout` or `stderr`
- `compose_service` / `compose_project` = Compose metadata when present

---

## Day-to-day: update logging stack

```bash
cd ~/nas-setup-scripts
git pull
sudo ./scripts/08-deploy-logging.sh
```

Or manually:

```bash
cd ~/nas-setup-scripts/compose/logging
sudo docker compose --env-file .env pull
sudo docker compose --env-file .env up -d
```

Changing `GRAFANA_*` / `TZ` in `config.env` → re-run `08-deploy-logging.sh` so `.env` is regenerated.

---

## How new projects opt in

**Default:** log to **stdout/stderr**. Alloy picks them up automatically.

Best practice:

1. Prefer stdout over only writing files inside the container
2. When you control the code, use one JSON object per line:
   ```json
   {"level":"INFO","service":"myapp","message":"started","run_id":"..."}
   ```
3. Set a stable `container_name:` in compose so queries stay `{container="myapp"}`

File logs (e.g. AI Trading `data/reports/last_run.log`) can still exist for a single-run dump. **Grafana is the shared search UI** across all apps.

---

## Change retention (disk)

Edit `compose/logging/loki-config.yml`:

```yaml
limits_config:
  retention_period: 336h   # 14 days — e.g. 720h = 30 days
```

Then:

```bash
sudo ./scripts/08-deploy-logging.sh
```

Check disk:

```bash
du -sh /srv/nas/docker/loki /srv/nas/docker/grafana
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Grafana connection refused | Tailscale up? `docker ps \| grep grafana`? Bound to `TAILSCALE_IP`? |
| Explore empty / no Loki | Wait ~30–60s after deploy; `docker logs alloy --tail 80` |
| Alloy can’t read Docker | Needs `/var/run/docker.sock` (compose mounts it `:ro`) |
| Loki permission denied | `sudo chown -R 10001:10001 /srv/nas/docker/loki` → redeploy |
| Grafana permission denied | `sudo chown -R 472:472 /srv/nas/docker/grafana` → redeploy |
| Forgot Grafana password | Set `GRAFANA_ADMIN_PASSWORD` in `config.env`, redeploy; or reset via Grafana docs / wipe `/srv/nas/docker/grafana` (loses Grafana UI state only, not Loki history) |

```bash
docker ps | grep -E 'loki|grafana|alloy'
docker logs alloy --tail 80
docker logs loki --tail 80
docker logs grafana --tail 80
```

---

## Uninstall (keep data)

```bash
cd ~/nas-setup-scripts/compose/logging
sudo docker compose --env-file .env down
```

Or full stack uninstall (also stops core/projects): `sudo ./scripts/uninstall-stack.sh`  
Bind-mounted data under `/srv/nas/docker/{loki,grafana,alloy}` is kept.
