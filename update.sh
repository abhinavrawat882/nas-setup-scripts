#!/usr/bin/env bash
# Convenience wrapper: update containers after the initial setup.
# Does NOT reinstall Docker or wipe Portainer / Jellyfin / Vaultwarden data.
#
#   sudo ./update.sh
#   sudo ./update.sh jellyfin
#   sudo ./update.sh --prune
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"
exec "${SCRIPT_DIR}/04-update-stack.sh" "$@"
