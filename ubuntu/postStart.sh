#!/usr/bin/env bash
# postStart.sh — starts runtime services on every container start.
# Idempotent — safe to call multiple times.
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail

	SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

	echo ┌───────────────────────┐
	echo │ D-Bus + gnome-keyring │
	echo └───────────────────────┘

	bash "$SCRIPT_DIR/../lib/setup-dbus-keyring.sh"

	echo ┌─\───────────────────────┐
	echo │ ✅  Completed PostStart │
	echo └─\───────────────────────┘
}
