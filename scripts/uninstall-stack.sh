#!/usr/bin/env bash
# Stop and remove stack containers. Data under NAS_ROOT is kept.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config

COMPOSE_FILE="${REPO_ROOT}/compose/docker-compose.yml"
ENV_FILE="${REPO_ROOT}/compose/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  write_compose_env
fi

cd "${REPO_ROOT}/compose"

info "Stopping stack (${COMPOSE_PROJECT_NAME}) — data volumes/bind mounts are preserved"
docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" down

info "Done. Data remains under ${NAS_ROOT}"
