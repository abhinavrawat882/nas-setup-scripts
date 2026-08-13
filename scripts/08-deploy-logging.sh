#!/usr/bin/env bash
# Deploy Loki + Grafana + Alloy (shared Docker log collection).
# Requires core stack network "nas". Idempotent.
#
#   sudo ./scripts/08-deploy-logging.sh
#
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

if [[ "${GRAFANA_ADMIN_PASSWORD}" == "changeme" ]]; then
  warn "GRAFANA_ADMIN_PASSWORD is still 'changeme'. Set a real password in config.env."
fi

info "Creating logging data dirs under ${NAS_ROOT}/docker"
mkdir -p \
  "${NAS_ROOT}/docker/loki/chunks" \
  "${NAS_ROOT}/docker/loki/rules" \
  "${NAS_ROOT}/docker/loki/compactor" \
  "${NAS_ROOT}/docker/alloy" \
  "${NAS_ROOT}/docker/grafana"

# Official image UIDs
chown -R 10001:10001 "${NAS_ROOT}/docker/loki"
chown -R 472:472 "${NAS_ROOT}/docker/grafana"
chown -R root:root "${NAS_ROOT}/docker/alloy"

write_logging_compose_env

COMPOSE_FILE="${REPO_ROOT}/compose/logging/docker-compose.yml"
ENV_FILE="${REPO_ROOT}/compose/logging/.env"
cd "${REPO_ROOT}/compose/logging"

info "Pulling Loki / Grafana / Alloy images"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" pull

info "Starting logging stack (${LOGGING_COMPOSE_PROJECT_NAME})"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d

info "Current logging containers"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps

echo
info "Logging stack deployed (Tailscale-bound Grafana):"
echo "  Grafana:  http://${TAILSCALE_IP}:${GRAFANA_PORT}"
echo "  Login:    ${GRAFANA_ADMIN_USER} / (password from config.env)"
echo "  Loki:     internal only (http://loki:3100 on nas network)"
echo "  Alloy:    scrapes all Docker container logs → Loki"
echo
echo "  First login:"
echo "    1. Open Grafana URL above (Tailscale on)"
echo "    2. Explore → Loki → query: {container=\"ai-trading\"}"
echo "    3. Or: {job=\"docker\"} |= \"error\""
echo
echo "  Full guide: docs/LOGGING.md"
