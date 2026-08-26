#!/usr/bin/env bash
# ensure-image.sh — make sure one variant's prebuilt image exists in the local
# registry, building and pushing it on first use.  Shared by every variant;
# call it from the variant's initialize.sh (which runs on the HOST).
#
# Usage: bash scripts/ensure-image.sh <variant-dir>
#
# Environment overrides: REGISTRY, IMAGE_NAME, TAG
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTEXT_DIR="$(cd "${1:-$PWD}" && pwd)"

REGISTRY="${REGISTRY:-localhost:5001}"
IMAGE_NAME="${IMAGE_NAME:-$(basename "${CONTEXT_DIR}")}"
TAG="${TAG:-latest}"
# Export so rebuild-and-push.sh resolves the same image even when these were
# defaulted here rather than inherited from the caller's environment.
export REGISTRY IMAGE_NAME TAG
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${TAG}"
REGISTRY_NAME="local-registry"

# 1. Verify Docker is available
if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Docker is not running or not installed." >&2
    exit 1
fi

# 2. Ensure the local registry container is running.
#    One registry serves every variant, so this is shared and idempotent.
echo "==> Ensuring local registry at ${REGISTRY}..."
bash "${LIB_DIR}/setup-local-registry.sh" add "${REGISTRY_NAME}"

# 3. Wait for registry readiness
echo "==> Waiting for registry..."
for i in $(seq 1 10); do
    if curl -fsSL "http://${REGISTRY}/v2/" >/dev/null 2>&1; then
        break
    fi
    if [ "$i" -eq 10 ]; then
        echo "ERROR: Registry at ${REGISTRY} is not responding after 10 seconds." >&2
        echo "Check: docker logs ${REGISTRY_NAME}" >&2
        exit 1
    fi
    sleep 1
done

# 4. Check if the image already exists in the registry
echo "==> Checking for ${FULL_TAG}..."
HTTP_CODE=$(curl -so /dev/null -w '%{http_code}' \
    "http://${REGISTRY}/v2/${IMAGE_NAME}/manifests/${TAG}" \
    -H "Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.index.v1+json, application/vnd.oci.image.manifest.v1+json")
if [ "$HTTP_CODE" = "200" ]; then
    echo "==> Image found. Ready."
    exit 0
fi
echo "==> Image not found (HTTP ${HTTP_CODE})."

# 5. Image not found — build and push
echo ""
echo "============================================================"
echo "  First-time setup: building the ${IMAGE_NAME} devcontainer"
echo "  image.  This downloads every SDK and toolchain baked into"
echo "  ${CONTEXT_DIR}/Dockerfile, so it can take a while."
echo "  Subsequent opens reuse the pushed image and are fast."
echo "============================================================"
echo ""
bash "${LIB_DIR}/rebuild-and-push.sh" "${CONTEXT_DIR}"
