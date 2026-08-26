#!/usr/bin/env bash
# initialize.sh — runs on the HOST before the container is created.
# 1. Ensures the Docker image is available (local registry).
# 2. Starts the ADB server on the host so USB devices are tracked
#    before the container (which uses --network=host) comes up.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Docker image ──────────────────────────────────────────────────────────────
# ensure-image.sh is shared by all variants (see scripts/); passing this directory
# selects the Dockerfile to build and names the image "ubuntu-flutter".
echo "==> Ensuring Docker image is available..."
bash "${SCRIPT_DIR}/../scripts/ensure-image.sh" "${SCRIPT_DIR}"

# ── ADB server ────────────────────────────────────────────────────────────────
# The container shares the host network (--network=host), so the host's ADB
# server on localhost:5037 is reachable from inside the container.  Starting it
# here guarantees a fresh USB scan before the container's postStart.sh runs.
if command -v adb >/dev/null 2>&1; then
	echo "==> Starting ADB server on host..."
	adb start-server
else
	echo "WARN: adb not found on host — USB device passthrough may not work." >&2
fi
