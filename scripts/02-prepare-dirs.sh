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
  "${NAS_ROOT}/docker/rabbitmq"
  "${NAS_ROOT}/docker/registry"
  "${NAS_ROOT}/docker/registry-auth"
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
  "${MEDIA_PATH}"

# Portainer / registry auth run as root inside containers; RabbitMQ image uses rabbitmq user (999).
chown -R root:root "${NAS_ROOT}/docker/portainer"
mkdir -p "${NAS_ROOT}/docker/registry-auth"
chown -R root:root "${NAS_ROOT}/docker/registry-auth"
# RabbitMQ official image runs as uid 999; leave writable for the container user.
chown -R 999:999 "${NAS_ROOT}/docker/rabbitmq"
# Registry runs as root by default in registry:2
chown -R root:root "${NAS_ROOT}/docker/registry"

info "Directory layout ready"
