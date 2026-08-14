#!/usr/bin/env bash
# First-time (or repair) setup for HomeSecurity on the NAS.
#
# Creates:
#   ${NAS_ROOT}/docker/homesecurity/{postgres,face_db}
#   ${HOMESECURITY_RECORDINGS_PATH}   (shared folder or default under docker/)
#   ${NAS_ROOT}/docker/homesecurity/cameras.yaml  (from example, unless present)
#
# Usage (on the NAS, as root):
#   sudo ./scripts/09-setup-homesecurity.sh           # dirs + cameras.yaml only
#   sudo ./scripts/09-setup-homesecurity.sh --deploy  # also pull/start containers
#   sudo ./scripts/09-setup-homesecurity.sh --force   # overwrite cameras.yaml
#
# Prerequisites:
#   - Core + projects stack already set up (network "nas" + Registry)
#   - Images pushed from Mac: HomeSecuritySystem → ./scripts/build-push-nas.sh
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

DO_DEPLOY=0
FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --deploy) DO_DEPLOY=1 ;;
    --force) FORCE=1 ;;
    -h|--help)
      sed -n '2,18p' "$0"
      exit 0
      ;;
    *)
      die "Unknown arg: ${arg} (use --deploy and/or --force)"
      ;;
  esac
done

require_root
load_config
require_tailscale_ip

HS_DIR="${NAS_ROOT}/docker/homesecurity"
CAMERAS="${HS_DIR}/cameras.yaml"
EXAMPLE="${REPO_ROOT}/compose/projects/homesecurity.cameras.example.yaml"
DASH_LAN="http://<nas-lan-ip>:${HOMESECURITY_DASHBOARD_PORT}"
DASH_TS="http://${TAILSCALE_IP}:${HOMESECURITY_DASHBOARD_PORT}"
API_TS="http://${TAILSCALE_IP}:${HOMESECURITY_API_PORT}"

[[ -f "${EXAMPLE}" ]] || die "Missing template ${EXAMPLE}"

info "Creating HomeSecurity directories"
mkdir -p \
  "${HS_DIR}/postgres" \
  "${HS_DIR}/face_db" \
  "${HOMESECURITY_RECORDINGS_PATH}"

if [[ -f "${CAMERAS}" && "${FORCE}" -ne 1 ]]; then
  info "cameras.yaml already exists: ${CAMERAS} (pass --force to overwrite)"
else
  info "Writing ${CAMERAS} from template"
  cp "${EXAMPLE}" "${CAMERAS}"
fi

# Postgres alpine image runs as uid 70
chown -R 70:70 "${HS_DIR}/postgres" || true

if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
  chown -R "${PUID}:${PGID}" "${HS_DIR}/face_db" || true
  # Own the recordings directory itself — do not recurse a large shared folder.
  chown "${PUID}:${PGID}" "${HOMESECURITY_RECORDINGS_PATH}" || true
fi

if [[ "${HOMESECURITY_POSTGRES_PASSWORD}" == "changeme" ]]; then
  warn "HOMESECURITY_POSTGRES_PASSWORD is still changeme — set it in config.env before --deploy"
fi

if [[ "${DO_DEPLOY}" -eq 1 ]]; then
  info "Deploying projects stack (includes HomeSecurity if images are in the registry)"
  "${SCRIPT_DIR}/05-deploy-projects.sh"
fi

echo
info "HomeSecurity filesystem ready"
echo "  Config:      ${CAMERAS}"
echo "  Recordings:  ${HOMESECURITY_RECORDINGS_PATH}"
echo "  Postgres:    ${HS_DIR}/postgres"
echo "  Dashboard:   ${DASH_LAN}  (LAN)"
echo "  Dashboard:   ${DASH_TS}  (Tailscale)"
echo "  API:         ${API_TS}  (Tailscale only)"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NEXT: edit RTSP URLs (reachable from the NAS)"
echo
echo "    sudo nano ${CAMERAS}"
echo
if [[ "${DO_DEPLOY}" -ne 1 ]]; then
  echo "  Then start / refresh containers:"
  echo
  echo "    sudo ./scripts/09-setup-homesecurity.sh --deploy"
  echo "    # or:  sudo ./scripts/05-deploy-projects.sh"
  echo
fi
echo "  On your Mac (if images not pushed yet):"
echo "    cd HomeSecuritySystem && ./scripts/build-push-nas.sh"
echo
echo "  After containers are up:"
echo "    ${DASH_LAN}"
echo
