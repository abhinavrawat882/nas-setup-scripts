#!/usr/bin/env bash
# Update container images and recreate containers WITHOUT reinstalling Docker
# or wiping app data (Portainer admin, Jellyfin libraries, Vaultwarden vault).
#
# Usage:
#   sudo ./scripts/04-update-stack.sh           # update all services
#   sudo ./scripts/04-update-stack.sh jellyfin  # update one service
#   sudo ./scripts/04-update-stack.sh --prune   # update all, then prune unused images
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config
require_tailscale_ip

if ! docker_ready; then
  die "Docker is not ready. Run setup once with ./setup.sh first."
fi

PRUNE=false
SERVICES=()

for arg in "$@"; do
  case "${arg}" in
    --prune)
      PRUNE=true
      ;;
    -h|--help)
      cat <<'EOF'
Update NAS stack containers (images only). App data under NAS_ROOT is kept.

  sudo ./scripts/04-update-stack.sh              Update Portainer, Jellyfin, Vaultwarden
  sudo ./scripts/04-update-stack.sh jellyfin     Update only Jellyfin
  sudo ./scripts/04-update-stack.sh --prune      Update all, then remove unused images
EOF
      exit 0
      ;;
    -*)
      die "Unknown option: ${arg} (try --help)"
      ;;
    *)
      SERVICES+=("${arg}")
      ;;
  esac
done

write_compose_env

COMPOSE_FILE="${REPO_ROOT}/compose/docker-compose.yml"
cd "${REPO_ROOT}/compose"

# Drop a previous Plex container if this host was set up with the older stack.
if docker ps -a --format '{{.Names}}' | grep -qx 'plex'; then
  info "Removing legacy plex container"
  docker rm -f plex >/dev/null
fi

# Never use --remove-orphans here — it can stop projects/logging containers that
# share (or previously shared) this Compose project name.
info "Updating core images (data under ${NAS_ROOT} is NOT deleted; other stacks left alone)"
if [[ ${#SERVICES[@]} -eq 0 ]]; then
  SERVICES=(portainer jellyfin vaultwarden)
fi

for svc in "${SERVICES[@]}"; do
  case "${svc}" in
    portainer|jellyfin|vaultwarden) ;;
    *)
      die "Unknown service '${svc}'. Use: portainer, jellyfin, or vaultwarden"
      ;;
  esac
done

docker compose -f "${COMPOSE_FILE}" --env-file .env pull "${SERVICES[@]}"
info "Recreating: ${SERVICES[*]}"
docker compose -f "${COMPOSE_FILE}" --env-file .env up -d --no-deps "${SERVICES[@]}"

info "Core containers"
docker compose -f "${COMPOSE_FILE}" --env-file .env ps

if [[ "${PRUNE}" == "true" ]]; then
  info "Pruning unused Docker images"
  docker image prune -f
fi

echo
info "Update finished. Portainer / Jellyfin / Vaultwarden settings and data were kept."
echo "  Portainer:      http://${TAILSCALE_IP}:${PORTAINER_PORT}"
echo "  Vaultwarden:    http://${TAILSCALE_IP}:${VAULTWARDEN_PORT}"
echo "  Jellyfin (LAN): http://<lan-ip>:${JELLYFIN_PORT}"
echo
info "Projects / logging were not touched (use 05-deploy-projects.sh / 08-deploy-logging.sh / start-all.sh)."
