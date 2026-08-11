#!/usr/bin/env bash
# Prune old registry tags (optional) and garbage-collect orphaned blobs.
# Stops the registry briefly, runs GC in a throwaway container, then starts it again.
#
# Usage:
#   sudo ./scripts/06-registry-gc.sh           # GC only (--delete-untagged)
#   sudo ./scripts/06-registry-gc.sh --dry-run # show what GC would delete
#   sudo ./scripts/06-registry-gc.sh --prune   # delete old tags (keep REGISTRY_KEEP_TAGS) then GC
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/_common.sh
source "${SCRIPT_DIR}/_common.sh"

require_root
load_config
require_tailscale_ip

if ! docker_ready; then
  die "Docker is not ready."
fi

DRY_RUN=false
DO_PRUNE=false
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=true ;;
    --prune) DO_PRUNE=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--prune]"
      exit 0
      ;;
    *)
      die "Unknown argument: ${arg} (use --dry-run and/or --prune)"
      ;;
  esac
done

REGISTRY_CONFIG="${REPO_ROOT}/compose/projects/registry-config.yml"
REGISTRY_DATA="${NAS_ROOT}/docker/registry"
AUTH_FILE="${NAS_ROOT}/docker/registry-auth/htpasswd"

[[ -f "${REGISTRY_CONFIG}" ]] || die "Missing ${REGISTRY_CONFIG}"
[[ -d "${REGISTRY_DATA}" ]] || die "Missing registry data dir ${REGISTRY_DATA}"

registry_base="http://${TAILSCALE_IP}:${REGISTRY_PORT}"

prune_old_tags() {
  local keep="${REGISTRY_KEEP_TAGS}"
  info "Pruning tags (keep newest ${keep} per repository) via ${registry_base}"

  if [[ ! -f "${AUTH_FILE}" ]]; then
    die "Missing ${AUTH_FILE}; cannot authenticate to registry API"
  fi

  local repos
  repos="$(curl -fsS -u "${REGISTRY_USER}:${REGISTRY_PASS}" "${registry_base}/v2/_catalog" \
    | sed -n 's/.*"repositories":\[\([^]]*\)\].*/\1/p' \
    | tr -d '"' | tr ',' '\n' | sed '/^$/d')" || true

  if [[ -z "${repos}" ]]; then
    info "No repositories in catalog; nothing to prune"
    return 0
  fi

  local repo tags tag_count i digest
  while IFS= read -r repo; do
    [[ -z "${repo}" ]] && continue
    tags="$(curl -fsS -u "${REGISTRY_USER}:${REGISTRY_PASS}" "${registry_base}/v2/${repo}/tags/list" \
      | sed -n 's/.*"tags":\[\([^]]*\)\].*/\1/p' \
      | tr -d '"' | tr ',' '\n' | sed '/^$/d')" || true
    if [[ -z "${tags}" ]]; then
      continue
    fi
    # Registry tag list order is not guaranteed newest-first; keep lexicographic last N as a simple policy.
    mapfile -t tag_arr < <(printf '%s\n' "${tags}" | sort)
    tag_count="${#tag_arr[@]}"
    if (( tag_count <= keep )); then
      echo "  ${repo}: ${tag_count} tag(s), keeping all"
      continue
    fi
    local delete_count=$((tag_count - keep))
    echo "  ${repo}: deleting ${delete_count} older tag(s), keeping ${keep}"
    for ((i = 0; i < delete_count; i++)); do
      local tag="${tag_arr[$i]}"
      digest="$(curl -fsSI -u "${REGISTRY_USER}:${REGISTRY_PASS}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "${registry_base}/v2/${repo}/manifests/${tag}" \
        | tr -d '\r' | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2; exit}')"
      if [[ -z "${digest}" ]]; then
        warn "Could not resolve digest for ${repo}:${tag}; skipping"
        continue
      fi
      if [[ "${DRY_RUN}" == "true" ]]; then
        echo "    [dry-run] would delete ${repo}@${digest} (tag ${tag})"
      else
        curl -fsS -X DELETE -u "${REGISTRY_USER}:${REGISTRY_PASS}" \
          "${registry_base}/v2/${repo}/manifests/${digest}" >/dev/null
        echo "    deleted ${repo}:${tag}"
      fi
    done
  done <<<"${repos}"
}

if [[ "${DO_PRUNE}" == "true" ]]; then
  if ! docker inspect registry >/dev/null 2>&1; then
    die "Container 'registry' not found; deploy projects first."
  fi
  if [[ "$(docker inspect -f '{{.State.Running}}' registry 2>/dev/null || echo false)" != "true" ]]; then
    die "Container 'registry' is not running; start projects stack before --prune."
  fi
  prune_old_tags
fi

if [[ "${DRY_RUN}" == "true" && "${DO_PRUNE}" == "true" ]]; then
  info "Dry-run prune done. Running GC dry-run next (registry will be stopped briefly)."
fi

was_running=false
if docker inspect registry >/dev/null 2>&1 \
  && [[ "$(docker inspect -f '{{.State.Running}}' registry 2>/dev/null || echo false)" == "true" ]]; then
  was_running=true
  info "Stopping registry for garbage collection"
  docker stop registry >/dev/null
fi

GC_ARGS=(garbage-collect /etc/docker/registry/config.yml --delete-untagged)
if [[ "${DRY_RUN}" == "true" ]]; then
  GC_ARGS+=(--dry-run)
  info "Running registry garbage-collect (dry-run)"
else
  info "Running registry garbage-collect (--delete-untagged)"
fi

docker run --rm \
  -v "${REGISTRY_DATA}:/var/lib/registry" \
  -v "${REGISTRY_CONFIG}:/etc/docker/registry/config.yml:ro" \
  registry:2 "${GC_ARGS[@]}"

if [[ "${was_running}" == "true" ]]; then
  info "Starting registry"
  docker start registry >/dev/null
fi

info "Done. Registry disk usage:"
du -sh "${REGISTRY_DATA}" || true
