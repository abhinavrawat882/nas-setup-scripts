#!/usr/bin/env bash
# Generate compose/.env and bring the NAS core stack up.
# Idempotent: re-run to apply config changes / pull updates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config
require_tailscale_ip

if ! docker_ready; then
  die "Docker is not ready. Run scripts/01-install-docker.sh first."
fi

write_compose_env

COMPOSE_FILE="${REPO_ROOT}/compose/docker-compose.yml"
cd "${REPO_ROOT}/compose"

# Drop a previous Plex container if this host was set up with the older stack.
if docker ps -a --format '{{.Names}}' | grep -qx 'plex'; then
  info "Removing legacy plex container"
  docker rm -f plex >/dev/null
fi

info "Pulling images"
docker compose -f "${COMPOSE_FILE}" --env-file .env pull

info "Starting stack (${COMPOSE_PROJECT_NAME})"
info "Bind-mounted data under ${NAS_ROOT} is preserved (Portainer is not reset)"
docker compose -f "${COMPOSE_FILE}" --env-file .env up -d --remove-orphans

info "Current containers"
docker compose -f "${COMPOSE_FILE}" --env-file .env ps

echo
info "Core stack deployed (Tailscale-bound except Jellyfin):"
echo "  Portainer:     http://${TAILSCALE_IP}:${PORTAINER_PORT}"
echo "  Vaultwarden:   http://${TAILSCALE_IP}:${VAULTWARDEN_PORT}"
echo "  code-server:   http://${TAILSCALE_IP}:${CODE_SERVER_PORT}  (workspace: ${NAS_ROOT}/projects → /projects)"
echo "  Jellyfin (LAN): http://<lan-ip>:${JELLYFIN_PORT}"
echo
info "Day-to-day image updates: sudo ./update.sh  (does not re-run Docker install)"
if [[ "${VAULTWARDEN_SIGNUPS_ALLOWED}" == "true" ]]; then
  warn "Vaultwarden signups are ENABLED. Create your account, then set VAULTWARDEN_SIGNUPS_ALLOWED=false in config.env and re-run deploy or update."
fi
if [[ "${CODE_SERVER_PASSWORD}" == "changeme" ]]; then
  warn "code-server password is still 'changeme'. Set CODE_SERVER_PASSWORD in config.env and re-run deploy or update."
fi
