#!/usr/bin/env bash
# Generate compose/.env and bring the NAS *core* stack up (Portainer, Jellyfin,
# Vaultwarden only). Does not stop or recreate projects/logging containers.
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

CORE_SERVICES=(portainer jellyfin vaultwarden)

info "Pulling core images"
docker compose -f "${COMPOSE_FILE}" --env-file .env pull "${CORE_SERVICES[@]}"

# Only start the three core services. Do NOT pass --remove-orphans: that flag
# removes any container labeled with this Compose project that is not in
# docker-compose.yml. If projects/logging were ever started under the same
# project name (or left as orphans), --remove-orphans would stop them.
info "Starting core stack only (${COMPOSE_PROJECT_NAME}: ${CORE_SERVICES[*]})"
info "Bind-mounted data under ${NAS_ROOT} is preserved; projects/logging stacks are left running"
docker compose -f "${COMPOSE_FILE}" --env-file .env up -d --no-deps "${CORE_SERVICES[@]}"

info "Core containers"
docker compose -f "${COMPOSE_FILE}" --env-file .env ps

echo
info "Core stack deployed (Tailscale-bound except Jellyfin):"
echo "  Portainer:    http://${TAILSCALE_IP}:${PORTAINER_PORT}"
echo "  Vaultwarden:  http://${TAILSCALE_IP}:${VAULTWARDEN_PORT}"
echo "  Jellyfin (LAN): http://<lan-ip>:${JELLYFIN_PORT}"
echo
info "Projects / logging were not touched. Bring them up with:"
echo "  sudo ./scripts/05-deploy-projects.sh"
echo "  sudo ./scripts/08-deploy-logging.sh"
echo "  # or everything: sudo ./start-all.sh"
echo
info "Day-to-day image updates: sudo ./update.sh  (does not re-run Docker install)"
if [[ "${VAULTWARDEN_SIGNUPS_ALLOWED}" == "true" ]]; then
  warn "Vaultwarden signups are ENABLED. Create your account, then set VAULTWARDEN_SIGNUPS_ALLOWED=false in config.env and re-run deploy or update."
fi
