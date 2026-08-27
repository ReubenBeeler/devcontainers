#!/usr/bin/env bash
# initialize.sh — runs on the HOST before the container is created.
# 1. Ensures the Docker image is available (local registry).
# 2. Starts the ADB server on the host so USB devices are tracked
#    before the container (which uses --network=host) comes up.
#
# Runs once per VS Code window, so every step touches shared host state
# concurrently and must be safe to run N times in parallel.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Shared lock directory ─────────────────────────────────────────────────────
# Bind-mounted into the container as /var/lock/devcontainer, so host and
# containers take the same locks.  Created here so it belongs to the host user;
# Docker would create the mount source as root and lock it out of the container.
LOCK_DIR="${HOME}/.cache/devcontainer-locks"
mkdir -p "${LOCK_DIR}"

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
	# `adb start-server` is check-then-act: N windows all probe 5037, all fork
	# a server, one binds and the rest exit 255 with "could not install
	# *smartsocket* listener", failing initializeCommand and aborting those
	# windows.  The lock makes probe-and-fork atomic.  -o is required: the
	# forked server inherits the lock fd and would hold the lock for life.
	flock -w 30 -o "${LOCK_DIR}/adb-start.lock" adb start-server
else
	echo "WARN: adb not found on host — USB device passthrough may not work." >&2
fi
