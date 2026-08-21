#!/usr/bin/env bash
# Create NAS data directories and set ownership from config.env.
# Idempotent: safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config

dirs=(
  "${NAS_ROOT}/docker/portainer"
  "${NAS_ROOT}/docker/jellyfin/config"
  "${NAS_ROOT}/docker/vaultwarden"
  "${NAS_ROOT}/docker/code-server"
  "${NAS_ROOT}/projects"
  "${NAS_ROOT}/docker/rabbitmq"
  "${NAS_ROOT}/docker/registry"
  "${NAS_ROOT}/docker/registry-auth"
  "${NAS_ROOT}/docker/ai-trading/data/portfolio"
  "${NAS_ROOT}/docker/ai-trading/data/stocks_cache"
  "${NAS_ROOT}/docker/ai-trading/data/reports"
  "${NAS_ROOT}/docker/homesecurity/postgres"
  "${NAS_ROOT}/docker/homesecurity/face_db"
  "${NAS_ROOT}/docker/loki"
  "${NAS_ROOT}/docker/alloy"
  "${NAS_ROOT}/docker/grafana"
  "${MEDIA_PATH}/movies"
  "${MEDIA_PATH}/tv"
  "${MEDIA_PATH}/music"
)

info "Creating directories under ${NAS_ROOT}"
for d in "${dirs[@]}"; do
  mkdir -p "${d}"
  echo "  + ${d}"
done

info "Setting ownership to ${PUID}:${PGID}"
chown -R "${PUID}:${PGID}" \
  "${NAS_ROOT}/docker/jellyfin" \
  "${NAS_ROOT}/docker/vaultwarden" \
  "${NAS_ROOT}/docker/code-server" \
  "${NAS_ROOT}/projects" \
  "${NAS_ROOT}/docker/ai-trading" \
  "${NAS_ROOT}/docker/homesecurity/face_db" \
  "${MEDIA_PATH}"

# Portainer / registry auth run as root inside containers; RabbitMQ image uses rabbitmq user (999).
chown -R root:root "${NAS_ROOT}/docker/portainer"
mkdir -p "${NAS_ROOT}/docker/registry-auth"
chown -R root:root "${NAS_ROOT}/docker/registry-auth"
# RabbitMQ official image runs as uid 999; leave writable for the container user.
chown -R 999:999 "${NAS_ROOT}/docker/rabbitmq"
# Registry runs as root by default in registry:2
chown -R root:root "${NAS_ROOT}/docker/registry"
# Postgres alpine image runs as uid 70
mkdir -p "${NAS_ROOT}/docker/homesecurity/postgres" "${HOMESECURITY_RECORDINGS_PATH}"
chown -R 70:70 "${NAS_ROOT}/docker/homesecurity/postgres" || true
chown "${PUID}:${PGID}" "${HOMESECURITY_RECORDINGS_PATH}" || true

HS_CAMERAS="${NAS_ROOT}/docker/homesecurity/cameras.yaml"
HS_CAMERAS_EXAMPLE="${REPO_ROOT}/compose/projects/homesecurity.cameras.example.yaml"
if [[ ! -f "${HS_CAMERAS}" && -f "${HS_CAMERAS_EXAMPLE}" ]]; then
  cp "${HS_CAMERAS_EXAMPLE}" "${HS_CAMERAS}"
  echo "  + ${HS_CAMERAS} (from example — edit RTSP URLs)"
fi

# Loki / Grafana official image UIDs
mkdir -p "${NAS_ROOT}/docker/loki" "${NAS_ROOT}/docker/grafana" "${NAS_ROOT}/docker/alloy"
chown -R 10001:10001 "${NAS_ROOT}/docker/loki" || true
chown -R 472:472 "${NAS_ROOT}/docker/grafana" || true

info "Directory layout ready"
