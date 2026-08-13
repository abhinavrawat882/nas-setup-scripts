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
ensure_insecure_registry
write_projects_compose_env

COMPOSE_FILE="${REPO_ROOT}/compose/projects/docker-compose.yml"
ENV_FILE="${REPO_ROOT}/compose/projects/.env"
TELLEGRAM_IMAGE="${TAILSCALE_IP}:${REGISTRY_PORT}/tellegramservice:latest"
cd "${REPO_ROOT}/compose/projects"

info "Pulling RabbitMQ + Registry images"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull rabbitmq registry || true

info "Starting RabbitMQ + Registry first (${PROJECTS_COMPOSE_PROJECT_NAME})"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d rabbitmq registry

info "Logging into private registry ${TAILSCALE_IP}:${REGISTRY_PORT}"
echo "${REGISTRY_PASS}" | docker login "${TAILSCALE_IP}:${REGISTRY_PORT}" \
  -u "${REGISTRY_USER}" --password-stdin

info "Pulling ${TELLEGRAM_IMAGE}"
if docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull tellegram; then
  info "Starting TellegramService"
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d tellegram
else
  warn "Could not pull ${TELLEGRAM_IMAGE}"
  warn "Push from your Mac first (bash scripts/build-push-nas.sh), then re-run this script."
fi

AI_TRADING_IMAGE="${TAILSCALE_IP}:${REGISTRY_PORT}/ai-trading:latest"
AI_CFG="${NAS_ROOT}/docker/ai-trading/config.yaml"
if [[ ! -f "${AI_CFG}" ]]; then
  warn "Missing ${AI_CFG}"
  warn "First-time: sudo ./scripts/07-setup-ai-trading.sh   # creates folders + seeds config"
fi

info "Pulling ${AI_TRADING_IMAGE}"
if docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull ai-trading; then
  info "Starting AI Trading Advisor + Ofelia scheduler"
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d ai-trading ai-trading-ofelia
else
  warn "Could not pull ${AI_TRADING_IMAGE}"
  warn "On your Mac (AI Trading repo): ./scripts/build-push-nas.sh"
  warn "Then on NAS: sudo ./scripts/07-setup-ai-trading.sh --deploy"
fi

info "Current containers"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps

echo
info "Projects stack deployed (Tailscale-bound):"
echo "  RabbitMQ AMQP:       ${TAILSCALE_IP}:${RABBITMQ_PORT}"
echo "  RabbitMQ Management: http://${TAILSCALE_IP}:${RABBITMQ_MGMT_PORT}"
echo "  Registry:            http://${TAILSCALE_IP}:${REGISTRY_PORT}"
echo "  TellegramService:    container 'tellegram' on nas network (no host port)"
echo "  Tellegram image:     ${TELLEGRAM_IMAGE}"
echo "  AI Trading:          http://${TAILSCALE_IP}:${AI_TRADING_PORT:-5100}"
echo "  AI Trading image:    ${AI_TRADING_IMAGE}"
echo "  Schedule:            Mon–Fri 07:00 and 19:00 (${TZ})"
echo
echo "  On the nas Docker network: rabbitmq:5672 , registry:5000 , tellegram , ai-trading"
echo "  Reclaim registry disk later: sudo ./scripts/06-registry-gc.sh"
