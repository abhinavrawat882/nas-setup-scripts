#!/usr/bin/env bash
# Bring all stacks back up after a reboot (or after uninstall-stack.sh).
# Does NOT reinstall Docker or wipe bind-mounted app data under NAS_ROOT.
#
#   sudo ./start-all.sh
#
# Order: core → projects → logging (same as first-time deploy after setup).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root

if [[ ! -f "${REPO_ROOT}/config.env" ]]; then
  die "Missing config.env. Run: cp config.env.example config.env && edit config.env"
fi

load_config
require_tailscale_ip

if ! docker_ready; then
  die "Docker is not ready. Run scripts/01-install-docker.sh first, then retry: sudo ./start-all.sh"
fi

info "Bringing up core stack (Portainer, Jellyfin, Vaultwarden, code-server)"
"${SCRIPT_DIR}/03-deploy-stack.sh"

info "Bringing up projects stack (RabbitMQ, Registry, Tellegram, AI Trading, HomeSecurity)"
"${SCRIPT_DIR}/05-deploy-projects.sh"

info "Bringing up logging stack (Loki, Grafana, Alloy)"
"${SCRIPT_DIR}/08-deploy-logging.sh"

echo
info "All stacks are up (data under ${NAS_ROOT} preserved)."
echo "  Portainer:     http://${TAILSCALE_IP}:${PORTAINER_PORT}"
echo "  Vaultwarden:   http://${TAILSCALE_IP}:${VAULTWARDEN_PORT}"
echo "  Jellyfin (LAN): http://<lan-ip>:${JELLYFIN_PORT}"
echo "  RabbitMQ mgmt: http://${TAILSCALE_IP}:${RABBITMQ_MGMT_PORT}"
echo "  Registry:      http://${TAILSCALE_IP}:${REGISTRY_PORT}"
echo "  AI Trading:    http://${TAILSCALE_IP}:${AI_TRADING_PORT}"
echo "  HomeSecurity:  http://${TAILSCALE_IP}:${HOMESECURITY_DASHBOARD_PORT} (API :${HOMESECURITY_API_PORT})"
echo "  Grafana:       http://${TAILSCALE_IP}:${GRAFANA_PORT}"
echo
info "Day-to-day image updates: sudo ./update.sh  /  sudo ./scripts/05-deploy-projects.sh"
