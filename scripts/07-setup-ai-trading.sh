#!/usr/bin/env bash
# First-time (or repair) setup for AI Trading on the NAS.
#
# Creates:
#   ${NAS_ROOT}/docker/ai-trading/config.yaml
#   ${NAS_ROOT}/docker/ai-trading/data/{portfolio,stocks_cache,reports}
#
# Seeds config from compose/projects/ai-trading.config.example.yaml and fills
# RabbitMQ user/pass + dashboard URL from config.env.
#
# Usage (on the NAS, as root):
#   sudo ./scripts/07-setup-ai-trading.sh           # dirs + config only
#   sudo ./scripts/07-setup-ai-trading.sh --deploy  # also pull/start containers
#   sudo ./scripts/07-setup-ai-trading.sh --force   # overwrite existing config.yaml
#
# Prerequisites:
#   - Core + projects stack already set up (RabbitMQ / Registry / network "nas")
#   - Image pushed from Mac: AI Trading → ./scripts/build-push-nas.sh
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
      sed -n '2,20p' "$0"
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

AI_DIR="${NAS_ROOT}/docker/ai-trading"
AI_CFG="${AI_DIR}/config.yaml"
EXAMPLE="${REPO_ROOT}/compose/projects/ai-trading.config.example.yaml"
DASHBOARD_URL="http://${TAILSCALE_IP}:${AI_TRADING_PORT}"

[[ -f "${EXAMPLE}" ]] || die "Missing template ${EXAMPLE}"

info "Creating AI Trading directories under ${AI_DIR}"
mkdir -p \
  "${AI_DIR}/data/portfolio" \
  "${AI_DIR}/data/stocks_cache" \
  "${AI_DIR}/data/reports"

if [[ -f "${AI_CFG}" && "${FORCE}" -ne 1 ]]; then
  info "Config already exists: ${AI_CFG} (pass --force to overwrite)"
else
  info "Writing ${AI_CFG} from template (RabbitMQ creds from config.env)"
  # Use Python for safe substitution (passwords may contain sed-special chars)
  python3 - "${EXAMPLE}" "${AI_CFG}" \
    "${RABBITMQ_USER}" "${RABBITMQ_PASS}" "${DASHBOARD_URL}" <<'PY'
import sys
src, dst, user, password, url = sys.argv[1:6]
text = open(src, encoding="utf-8").read()
text = text.replace("__RABBITMQ_USER__", user)
text = text.replace("__RABBITMQ_PASS__", password)
text = text.replace("__DASHBOARD_BASE_URL__", url)
open(dst, "w", encoding="utf-8").write(text)
PY
  chmod 600 "${AI_CFG}"
fi

# Ownership: match other app data where possible
if [[ -n "${PUID:-}" && -n "${PGID:-}" ]]; then
  chown -R "${PUID}:${PGID}" "${AI_DIR}" || true
fi

# Soft reminder for timezone (schedules are wall-clock in container TZ)
if [[ "${TZ}" != "Asia/Kolkata" ]]; then
  warn "config.env has TZ=${TZ} — Ofelia schedules use this timezone."
  warn "For IST 07:00 / 19:00 runs, set TZ=Asia/Kolkata in ${CONFIG_FILE}"
fi

if [[ "${DO_DEPLOY}" -eq 1 ]]; then
  info "Deploying projects stack (includes ai-trading if image is in registry)"
  "${SCRIPT_DIR}/05-deploy-projects.sh"
fi

echo
info "AI Trading filesystem ready"
echo "  Config:  ${AI_CFG}"
echo "  Data:    ${AI_DIR}/data/"
echo "  URL:     ${DASHBOARD_URL}"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  NEXT: edit capital / holds (and confirm RabbitMQ password)"
echo
echo "    sudo nano ${AI_CFG}"
echo
echo "  Change at least:"
echo "    • capital.monthly_allocation     (your Groww cash)"
echo "    • portfolio.long_term_holds      (optional)"
echo "    • alerts.rabbitmq.password       (should already match config.env)"
echo
if [[ "${DO_DEPLOY}" -ne 1 ]]; then
  echo "  Then start / refresh containers:"
  echo
  echo "    sudo ./scripts/07-setup-ai-trading.sh --deploy"
  echo "    # or:  sudo ./scripts/05-deploy-projects.sh"
  echo
fi
echo "  On your Mac (if image not pushed yet):"
echo "    cd \"AI Trading\" && ./scripts/build-push-nas.sh"
echo
echo "  After containers are up, open:"
echo "    ${DASHBOARD_URL}"
echo "    → Portfolio → Import Groww (or Add row) → Save → Run Analysis"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
