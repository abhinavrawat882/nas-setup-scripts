#!/usr/bin/env bash
# Stop and remove core + projects stack containers. Data under NAS_ROOT is kept.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config

PROJECTS_COMPOSE="${REPO_ROOT}/compose/projects/docker-compose.yml"
PROJECTS_ENV="${REPO_ROOT}/compose/projects/.env"
CORE_COMPOSE="${REPO_ROOT}/compose/docker-compose.yml"
CORE_ENV="${REPO_ROOT}/compose/.env"

if [[ -f "${PROJECTS_ENV}" ]] || docker inspect rabbitmq >/dev/null 2>&1 || docker inspect registry >/dev/null 2>&1; then
  if [[ ! -f "${PROJECTS_ENV}" ]]; then
    write_projects_compose_env
  fi
  info "Stopping projects stack (${PROJECTS_COMPOSE_PROJECT_NAME}) — data preserved"
  cd "${REPO_ROOT}/compose/projects"
  docker compose -f "${PROJECTS_COMPOSE}" --env-file "${PROJECTS_ENV}" down || warn "Projects stack down returned non-zero (may already be stopped)"
else
  info "Projects stack not present; skipping"
fi

if [[ ! -f "${CORE_ENV}" ]]; then
  write_compose_env
fi

cd "${REPO_ROOT}/compose"
info "Stopping core stack (${COMPOSE_PROJECT_NAME}) — data volumes/bind mounts are preserved"
docker compose -f "${CORE_COMPOSE}" --env-file "${CORE_ENV}" down

info "Done. Data remains under ${NAS_ROOT}"
