#!/usr/bin/env bash
# postStart.sh — starts runtime services on every container start.
# Idempotent — safe to call multiple times.
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail

	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

	echo ┌───────────────────────┐
	echo │ D-Bus + gnome-keyring │
	echo └───────────────────────┘

	bash "$SCRIPT_DIR/../scripts/setup-dbus-keyring.sh"

	echo ┌─────────────┐
	echo │ Claude Code │
	echo └─────────────┘

	# The image's copy goes stale between rebuilds, so update on every start.
	# Non-fatal: a failed update (e.g. offline) keeps the current version.
	# --foreground: without it, timeout moves claude off the terminal's
	# foreground group, so touching the tty freezes it (SIGTTOU) forever.
	# -k: SIGKILL if SIGTERM doesn't end it.
	echo "==> Updating Claude Code (stable)..."
	timeout --foreground -k 10 120 "$HOME/.local/bin/claude" install stable \
		|| echo "WARNING: Claude Code update failed, keeping current version" >&2

	echo ┌─\───────────────────────┐
	echo │ ✅  Completed PostStart │
	echo └─\───────────────────────┘
}
