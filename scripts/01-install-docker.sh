#!/usr/bin/env bash
# Install / enable Docker on OpenMediaVault (or plain Debian/Ubuntu).
# Idempotent: safe to re-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root

if docker_ready; then
  info "Docker and Compose already available — skipping install"
  docker --version
  docker compose version
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive

install_via_omv_extras() {
  info "Detected OpenMediaVault — preferring OMV-Extras / compose plugin"

  if ! dpkg -l openmediavault-omvextrasorg >/dev/null 2>&1; then
    info "Installing OMV-Extras"
    local installer
    installer="$(mktemp)"
    if ! wget -qO "${installer}" \
      https://github.com/OpenMediaVault-Plugin-Developers/packages/raw/master/install; then
      rm -f "${installer}"
      die "Failed to download OMV-Extras installer"
    fi
    bash "${installer}"
    rm -f "${installer}"
  else
    info "OMV-Extras already installed"
  fi

  apt-get update -y

  # openmediavault-compose pulls Docker Engine + compose plugin on modern OMV.
  if ! dpkg -l openmediavault-compose >/dev/null 2>&1; then
    info "Installing openmediavault-compose (brings in Docker)"
    apt-get install -y openmediavault-compose || \
      apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
  else
    info "openmediavault-compose already installed"
  fi
}

install_via_docker_ce() {
  info "Installing Docker CE via official convenience script"
  if ! command -v curl >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y curl ca-certificates
  fi
  curl -fsSL https://get.docker.com | sh
  apt-get install -y docker-compose-plugin || true
}

if is_omv; then
  install_via_omv_extras
else
  warn "OpenMediaVault not detected — installing Docker CE directly"
  install_via_docker_ce
fi

systemctl enable --now docker >/dev/null 2>&1 || true

# Give a moment for the daemon to come up after first install
for _ in 1 2 3 4 5; do
  if docker_ready; then
    break
  fi
  sleep 2
done

if ! docker_ready; then
  die "Docker install finished but 'docker compose' is not usable yet. Reboot or check: systemctl status docker"
fi

info "Docker ready"
docker --version
docker compose version
