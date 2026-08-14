# HomeSecurity on NAS — first-time setup

Your NAS already runs RabbitMQ, Registry, and TellegramService. HomeSecurity is
an extra service on the same `nas` Docker network.

**Dashboard (LAN, no Tailscale):** `http://<nas-lan-ip>:8081`  
**Dashboard (Tailscale):** `http://arnosatlas:8081`  
**API (Tailscale only):** `http://arnosatlas:5101`

---

## What you end up with

| Piece | Where |
|-------|--------|
| `config.env` keys | Postgres password, recordings path, ports |
| Cameras | `/srv/nas/docker/homesecurity/cameras.yaml` |
| Postgres data | `/srv/nas/docker/homesecurity/postgres` |
| MP4 clips | `HOMESECURITY_RECORDINGS_PATH` (default `/srv/nas/docker/homesecurity/recordings`) |
| Containers | `homesecurity-postgres`, `homesecurity-redis`, `homesecurity-api`, `homesecurity-pipeline`, `homesecurity-dashboard` |
| Lockdown Telegram | Same bot as TellegramService (`TELEGRAM_BOT_TOKEN` / `TELEGRAM_CHAT_ID`) |

YOLO / face ML stays **off** (CPU NAS).

---

## 1) On the NAS — `config.env`

```bash
cd /path/to/nas-setup-scripts
git pull
sudo nano config.env
```

Scroll to the bottom and **paste** this block (change the password and recordings path):

```bash
# --- HomeSecurity ---
HOMESECURITY_API_PORT=5101
HOMESECURITY_DASHBOARD_PORT=8081
HOMESECURITY_POSTGRES_PASSWORD=REPLACE_WITH_A_STRONG_PASSWORD
HOMESECURITY_RECORDINGS_PATH=/srv/nas/docker/homesecurity/recordings
HOMESECURITY_TELEGRAM_ENABLED=true
# Optional: if you bookmark the UI by LAN IP (CORS)
# HOMESECURITY_DASHBOARD_LAN_URL=http://192.168.1.9:8081

# USB webcam plugged into the NAS (ls -l /dev/video*):
HOMESECURITY_USB_CAMERA=/dev/video0
# HOMESECURITY_USB_CAMERA_GID=44
```

Telegram lockdown reuses keys you should already have:

```bash
TELEGRAM_BOT_TOKEN=…
TELEGRAM_CHAT_ID=…
```

Save and exit (`Ctrl+O`, Enter, `Ctrl+X`).

---

## 2) On your Mac — push images (once per code change)

Needs Docker Desktop + `crane` (`brew install crane`) and `REGISTRY_PASS` from `config.env`.

```bash
cd /Users/arno/Documents/Projects/HomeSecuritySystem
export REGISTRY=arnosatlas:5000
export REGISTRY_USER=nas
export REGISTRY_PASS='YOUR_REGISTRY_PASS'
./scripts/build-push-nas.sh
```

Use **crane**, not `docker push`. See [PUSH_IMAGES_FROM_MAC.md](PUSH_IMAGES_FROM_MAC.md).

---

## 3) On the NAS — folders, cameras, start

```bash
cd /path/to/nas-setup-scripts
chmod +x scripts/*.sh
sudo ./scripts/09-setup-homesecurity.sh
sudo nano /srv/nas/docker/homesecurity/cameras.yaml
```

Paste / edit RTSP URLs the **NAS** can reach:

```yaml
cameras:
  - name: Hall_DoorFacing
    rtsp_url: rtsp://arnohomecam-hall:8554/cam

  - name: Hall_KitchenFacing
    rtsp_url: rtsp://arnohomecam-room:8554/cam

  - name: Arnos_Room
    source: /dev/video0
```

Then start containers:

```bash
sudo ./scripts/09-setup-homesecurity.sh --deploy
```

---

## 4) Use it

1. Open `http://<nas-lan-ip>:8081` on the home LAN (phone/TV/laptop, no Tailscale).
2. **Settings → Lockdown** — turn on.
3. On motion, Telegram gets an event link + video link (those links need Tailscale on the phone).

| What | URL |
|------|-----|
| Dashboard LAN | `http://<nas-lan-ip>:8081` |
| Dashboard Tailscale | `http://arnosatlas:8081` |
| API Tailscale | `http://arnosatlas:5101` |

---

## Day-to-day

```bash
# After a new image push from the Mac
sudo ./scripts/05-deploy-projects.sh

# Logs
cd /path/to/nas-setup-scripts/compose/projects
sudo docker compose --env-file .env logs -f homesecurity-api
sudo docker compose --env-file .env logs -f homesecurity-pipeline

# Grafana
# http://arnosatlas:3000  →  {container="homesecurity-api"}
```

Overwrite cameras from the example template:

```bash
sudo ./scripts/09-setup-homesecurity.sh --force
sudo nano /srv/nas/docker/homesecurity/cameras.yaml
sudo ./scripts/09-setup-homesecurity.sh --deploy
```

---

## If deploy skips HomeSecurity

Images are not in the registry yet — run step 2 on the Mac, then `--deploy` again.

If you see `HOMESECURITY_POSTGRES_PASSWORD is still changeme`, fix `config.env` and re-run `--deploy`.
