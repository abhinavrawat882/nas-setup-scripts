# Loki + Grafana + Alloy — shared logging on the NAS

Collects **stdout/stderr from every Docker container** on the host into Loki.
Browse / search in Grafana over Tailscale.

| Service | Role | URL |
|---------|------|-----|
| **Grafana** | UI | `http://<TAILSCALE_IP>:3000` (default) |
| **Loki** | Log store | Internal only (`loki:3100` on `nas` network) |
| **Alloy** | Scrapes Docker logs → Loki | No host port |

Retention default: **14 days** (`compose/logging/loki-config.yml`).

---

## First-time setup

### 1) Config

On the NAS, edit `config.env`:

```bash
GRAFANA_PORT=3000
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD='pick-a-strong-password'
TZ=Asia/Kolkata   # optional but recommended
```

### 2) Deploy

```bash
cd ~/nas-setup-scripts
git pull
chmod +x scripts/08-deploy-logging.sh
sudo ./scripts/08-deploy-logging.sh
```

Requires the core `nas` Docker network (already present if Portainer/Jellyfin are up).

### 3) Open Grafana

1. Tailscale on → `http://arnosatlas:3000` (or your Tailscale IP)
2. Login with `GRAFANA_ADMIN_USER` / `GRAFANA_ADMIN_PASSWORD`
3. Left menu → **Explore**
4. Datasource: **Loki** (provisioned automatically)

---

## Useful queries

```logql
# Everything from AI Trading
{container="ai-trading"}

# AI Trading errors / failures
{container="ai-trading"} |= "ERROR" or {container="ai-trading"} |= "Error"

# TellegramService
{container="tellegram"}

# Any container, filter text
{job="docker"} |= "analysis"

# Last analysis / Flask messages
{container="ai-trading"} |~ "(?i)analysis|run_advisor|Traceback"
```

Time range: set to **Last 15 minutes** / **Last 1 hour** while debugging.

---

## How new projects opt in

**Nothing special** if the app logs to **stdout/stderr** (normal Docker practice).

Alloy discovers containers via the Docker socket and ships their logs automatically.

Best practice for future apps:

1. Log to stdout (not only a file inside the container)
2. Prefer one JSON object per line when you control the code:
   `{"level":"INFO","service":"myapp","message":"..."}`
3. Keep the container name stable (`container_name:` in compose) so queries stay stable

---

## Update / restart

```bash
sudo ./scripts/08-deploy-logging.sh
```

Or:

```bash
cd compose/logging
sudo docker compose --env-file .env pull
sudo docker compose --env-file .env up -d
```

---

## Disk / retention

Data lives under:

```text
/srv/nas/docker/loki/
/srv/nas/docker/grafana/
/srv/nas/docker/alloy/
```

Change retention in `compose/logging/loki-config.yml`:

```yaml
limits_config:
  retention_period: 336h   # 14 days — raise/lower as needed
```

Then redeploy logging.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Grafana connection refused | Tailscale up? `docker ps \| grep grafana`? Port bind to `TAILSCALE_IP`? |
| Explore shows no Loki data | Wait ~30s after deploy; check `docker logs alloy --tail 50` |
| Alloy permission errors | Needs `/var/run/docker.sock` (mounted read-only in compose) |
| Loki crash / permission denied | `chown -R 10001:10001 /srv/nas/docker/loki` then redeploy |
| Grafana permission denied | `chown -R 472:472 /srv/nas/docker/grafana` then redeploy |

```bash
docker logs alloy --tail 80
docker logs loki --tail 80
docker logs grafana --tail 80
```

---

## Relation to AI Trading `last_run.log`

File logs under `/srv/nas/docker/ai-trading/data/reports/` are still useful for a single run dump.
**Grafana + Loki** is the shared place to search live container output across all apps — use both.
