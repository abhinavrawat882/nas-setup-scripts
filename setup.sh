#!/usr/bin/env bash
# First-time setup only: install Docker → prepare dirs → deploy stack.
# Later: use ./update.sh to pull newer images without wiping app data.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root

if [[ ! -f "${REPO_ROOT}/config.env" ]]; then
  die "Missing config.env. Run: cp config.env.example config.env && edit config.env"
fi

# If the stack is already running, prefer update.sh so it is obvious we are
# not doing a destructive reinstall.
if docker_ready && docker ps --format '{{.Names}}' 2>/dev/null | grep -Eq '^(portainer|jellyfin|vaultwarden)$'; then
  warn "Stack containers already look deployed."
  warn "For image updates (keeps Portainer login, Jellyfin, Vaultwarden data), run:"
  warn "  sudo ./update.sh"
  warn "Continuing with setup anyway (idempotent; data bind-mounts are kept)..."
fi

"${SCRIPT_DIR}/01-install-docker.sh"
"${SCRIPT_DIR}/02-prepare-dirs.sh"
"${SCRIPT_DIR}/03-deploy-stack.sh"

info "All done. Next time, update images with: sudo ./update.sh"
