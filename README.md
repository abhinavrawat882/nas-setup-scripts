# NAS Setup Scripts

Idempotent scripts to put Docker on **OpenMediaVault**, then deploy:

| App | What it is | Default URL |
|-----|------------|-------------|
| **Portainer** | Manage Docker from phone/browser | `http://<nas-ip>:9000` |
| **Plex** | Media server | `http://<nas-ip>:32400/web` |
| **Vaultwarden** | Self-hosted Bitwarden-compatible password manager | `http://<nas-ip>:8080` |

LAN-first. Do not expose Vaultwarden to the public internet without HTTPS.

## Quick start

SSH into your OMV box as root (or use `sudo`).

```bash
git clone <this-repo-url> nas-setup-scripts
cd nas-setup-scripts

cp config.env.example config.env
nano config.env   # set NAS_ROOT, PUID, PGID, TZ (and optional PLEX_CLAIM)

chmod +x setup.sh scripts/*.sh
sudo ./setup.sh
```

That runs, in order:

1. `scripts/01-install-docker.sh` — Docker via OMV-Extras / `openmediavault-compose` when OMV is detected
2. `scripts/02-prepare-dirs.sh` — data + media folders under `NAS_ROOT`
3. `scripts/03-deploy-stack.sh` — `docker compose up -d`

Re-run `sudo ./scripts/03-deploy-stack.sh` anytime to apply `config.env` changes or pull updates.

## Configure `config.env`

| Variable | Purpose |
|----------|---------|
| `NAS_ROOT` | Base path on your data disk (e.g. `/srv/dev-disk-by-uuid-…/nas`) |
| `PUID` / `PGID` | File ownership inside containers (OMV: often your uid + group `users` = `100`) |
| `TZ` | Timezone |
| `PLEX_MEDIA_PATH` | Optional override; default `${NAS_ROOT}/media` |
| `PLEX_CLAIM` | Optional token from [plex.tv/claim](https://www.plex.tv/claim/) |
| `PORTAINER_PORT` / `PLEX_PORT` / `VAULTWARDEN_PORT` | Host ports |
| `VAULTWARDEN_SIGNUPS_ALLOWED` | `true` until you create an account, then `false` |

`config.env` and generated `compose/.env` are gitignored.

## After deploy

1. **Portainer** — open `:9000`, create the admin user, choose **Docker** / local environment. Use this from your phone or laptop to start/stop containers, view logs, etc.
2. **Plex** — open `:32400/web`. Add libraries pointing at folders under your media path (e.g. `/srv/nas/media/movies`). Put files in `movies/`, `tv/`, `music/` on the NAS.
3. **Vaultwarden** — open `:8080`, create your account. Then set in `config.env`:

   ```bash
   VAULTWARDEN_SIGNUPS_ALLOWED=false
   ```

   and run `sudo ./scripts/03-deploy-stack.sh` again. Point the Bitwarden mobile/browser app at `http://<nas-ip>:8080` (self-hosted / custom server).

## Layout on disk

```
$NAS_ROOT/
  docker/
    portainer/
    plex/{config,transcode}/
    vaultwarden/
  media/{movies,tv,music}/
```

## Useful commands

```bash
# Redeploy / update
sudo ./scripts/03-deploy-stack.sh

# Stop containers (keeps all data)
sudo ./scripts/uninstall-stack.sh

# Logs
cd compose && sudo docker compose --env-file .env logs -f
```

## Notes

- **Plex** uses `network_mode: host` so TV/app discovery works on the LAN. It listens on host port `32400`.
- Scripts prefer **OMV-Extras** + `openmediavault-compose` on OpenMediaVault so you do not fight OMV’s package management. On plain Debian/Ubuntu they fall back to Docker CE.
- This stack is for home LAN use. Add a reverse proxy + HTTPS (or Tailscale) before remote access, especially for Vaultwarden.

## Uninstall

```bash
sudo ./scripts/uninstall-stack.sh
```

Removes containers/networks only. Everything under `NAS_ROOT` stays so you can redeploy later.
