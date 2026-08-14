# Push images to the NAS private registry (from Mac)

Canonical guide for **all** projects that use the NAS `registry` service
(HTTP on Tailscale `:5000`).

## The rule

**Do not rely on `docker push` from Docker Desktop** to this registry.

Use:

```text
docker build → docker save → crane push --insecure
```

Reason: Docker Desktop’s containerd image store ignores `insecure-registries` and errors with
`http: server gave HTTP response to HTTPS client`.

Install once: `brew install crane`.

## Per-project scripts

| Project | Script |
|---------|--------|
| AI Trading | `AI Trading/scripts/build-push-nas.sh` (see also `AI Trading/docs/NAS_REGISTRY_PUSH.md`) |
| TellegramService | `TellegramService/scripts/build-push-nas.sh` (if present) |
| HomeSecurity | `HomeSecuritySystem/scripts/build-push-nas.sh` (`linux/amd64`; three images: api, pipeline, dashboard) |

Generic one-liner pattern:

```bash
IMAGE=myapp
REGISTRY=arnosatlas:5000
docker build --provenance=false --sbom=false -t ${IMAGE}:latest .
echo "$REGISTRY_PASS" | crane auth login --insecure "$REGISTRY" -u "$REGISTRY_USER" --password-stdin
TMP=$(mktemp).tar
docker save ${IMAGE}:latest -o "$TMP"
crane push --insecure "$TMP" ${REGISTRY}/${IMAGE}:latest
rm -f "$TMP"
crane digest --insecure ${REGISTRY}/${IMAGE}:latest
```

On the NAS, compose `image:` must use `${TAILSCALE_IP}:5000/...` (host pull), then:

```bash
sudo ./scripts/05-deploy-projects.sh
# HomeSecurity first-time: sudo ./scripts/09-setup-homesecurity.sh --deploy
```

Full AI Trading first-time + holiday deploy notes live in the AI Trading repo:
[`docs/NAS_REGISTRY_PUSH.md`](../AI%20Trading/docs/NAS_REGISTRY_PUSH.md) (sibling project).
