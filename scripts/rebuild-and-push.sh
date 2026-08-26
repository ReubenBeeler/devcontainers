#!/usr/bin/env bash
# rebuild-and-push.sh — build one devcontainer variant's image and push it to
# the local registry.  Shared by every variant that uses a prebuilt image.
#
# A variant is identified by the directory holding its Dockerfile; that
# directory is both the build context and — via its basename — the image name.
# So .devcontainer/ubuntu-flutter/ builds localhost:5001/ubuntu-flutter:latest.
#
# Usage:
#   bash scripts/rebuild-and-push.sh <variant-dir>
#   bash ../scripts/rebuild-and-push.sh          # from inside the variant dir
#
# Environment overrides: REGISTRY, IMAGE_NAME, TAG
set -euo pipefail

CONTEXT_DIR="$(cd "${1:-$PWD}" && pwd)"
if [ ! -f "${CONTEXT_DIR}/Dockerfile" ]; then
	echo "ERROR: no Dockerfile in ${CONTEXT_DIR}" >&2
	echo "Pass the variant directory, e.g. bash scripts/rebuild-and-push.sh ubuntu-flutter" >&2
	exit 1
fi

REGISTRY="${REGISTRY:-localhost:5001}"
IMAGE_NAME="${IMAGE_NAME:-$(basename "${CONTEXT_DIR}")}"
TAG="${TAG:-latest}"
FULL_TAG="${REGISTRY}/${IMAGE_NAME}:${TAG}"

echo "Building ${FULL_TAG} from ${CONTEXT_DIR}..."
docker build --tag "${FULL_TAG}" "${CONTEXT_DIR}"

echo "Pushing to ${REGISTRY}..."
docker push "${FULL_TAG}"

echo "Done: ${FULL_TAG}"
