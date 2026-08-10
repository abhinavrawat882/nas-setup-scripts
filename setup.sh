#!/usr/bin/env bash
# One-shot setup: install Docker → prepare dirs → deploy stack.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/scripts" && pwd)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root

if [[ ! -f "${REPO_ROOT}/config.env" ]]; then
  die "Missing config.env. Run: cp config.env.example config.env && edit config.env"
fi

"${SCRIPT_DIR}/01-install-docker.sh"
"${SCRIPT_DIR}/02-prepare-dirs.sh"
"${SCRIPT_DIR}/03-deploy-stack.sh"

info "All done."
