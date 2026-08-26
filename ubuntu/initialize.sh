#!/usr/bin/env bash
# initialize.sh — runs on the HOST before the container is created.
# Ensures the prebuilt Docker image is available in the local registry.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Docker image ──────────────────────────────────────────────────────────────
# ensure-image.sh is shared by all variants (see scripts/); passing this directory
# selects the Dockerfile to build and names the image "ubuntu".
echo "==> Ensuring Docker image is available..."
bash "${SCRIPT_DIR}/../scripts/ensure-image.sh" "${SCRIPT_DIR}"
