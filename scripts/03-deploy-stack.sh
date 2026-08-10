#!/usr/bin/env bash
# Generate compose/.env and bring the NAS stack up.
# Idempotent: re-run to apply config changes / pull updates.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config

if ! docker_ready; then
  die "Docker is not ready. Run scripts/01-install-docker.sh first."
fi

write_compose_env

COMPOSE_FILE="${REPO_ROOT}/compose/docker-compose.yml"
cd "${REPO_ROOT}/compose"

info "Pulling images"
docker compose -f "${COMPOSE_FILE}" --env-file .env pull

info "Starting stack (${COMPOSE_PROJECT_NAME})"
docker compose -f "${COMPOSE_FILE}" --env-file .env up -d

info "Current containers"
docker compose -f "${COMPOSE_FILE}" --env-file .env ps

echo
info "Stack deployed. On your LAN:"
echo "  Portainer:    http://<nas-ip>:${PORTAINER_PORT}"
echo "  Plex:         http://<nas-ip>:${PLEX_PORT}/web"
echo "  Vaultwarden:  http://<nas-ip>:${VAULTWARDEN_PORT}"
echo
if [[ "${VAULTWARDEN_SIGNUPS_ALLOWED}" == "true" ]]; then
  warn "Vaultwarden signups are ENABLED. Create your account, then set VAULTWARDEN_SIGNUPS_ALLOWED=false in config.env and re-run this script."
fi
