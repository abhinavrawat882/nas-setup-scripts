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

# Portainer runs as root inside the container; keep data dir root-owned.
chown -R root:root "${NAS_ROOT}/docker/portainer"

info "Directory layout ready"
