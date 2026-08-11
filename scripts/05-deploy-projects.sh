#!/usr/bin/env bash
# Generate compose/projects/.env and bring the projects stack up
# (RabbitMQ + Registry + TellegramService).
# Requires the core stack network "nas". Idempotent.
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

require_nas_network

if [[ "${RABBITMQ_PASS}" == "changeme" ]] || [[ "${REGISTRY_PASS}" == "changeme" ]]; then
  warn "Using default changeme passwords. Set RABBITMQ_PASS and REGISTRY_PASS in config.env."
fi

if [[ -z "${TELEGRAM_BOT_TOKEN}" ]] || [[ -z "${TELEGRAM_CHAT_ID}" ]]; then
  warn "TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID empty in config.env — tellegram will fail until set."
fi

"${SCRIPT_DIR}/02-prepare-dirs.sh"
ensure_registry_htpasswd
write_projects_compose_env

COMPOSE_FILE="${REPO_ROOT}/compose/projects/docker-compose.yml"
ENV_FILE="${REPO_ROOT}/compose/projects/.env"
cd "${REPO_ROOT}/compose/projects"

info "Pulling images (tellegram needs a prior push to ${TAILSCALE_IP}:${REGISTRY_PORT}/tellegramservice)"
# RabbitMQ + registry always pull; tellegram may be missing until first push — allow soft fail
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull rabbitmq registry || true
if ! docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull tellegram; then
  warn "Could not pull registry:5000/tellegramservice:latest"
  warn "Build/push from your Mac first, then re-run this script."
fi

info "Starting projects stack (${PROJECTS_COMPOSE_PROJECT_NAME})"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d

info "Current containers"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps

echo
info "Projects stack deployed (Tailscale-bound):"
echo "  RabbitMQ AMQP:       ${TAILSCALE_IP}:${RABBITMQ_PORT}"
echo "  RabbitMQ Management: http://${TAILSCALE_IP}:${RABBITMQ_MGMT_PORT}"
echo "  Registry:            http://${TAILSCALE_IP}:${REGISTRY_PORT}"
echo "  TellegramService:    container 'tellegram' on nas network (no host port)"
echo
echo "  On the nas Docker network: rabbitmq:5672 , registry:5000 , tellegram"
echo "  Reclaim registry disk later: sudo ./scripts/06-registry-gc.sh"
