#!/bin/bash
# postCreate.sh — runs once at container creation via devcontainer.json
# postCreateCommand. At this point bind mounts and the workspace are available.
# Everything installable is baked into the image instead — see Dockerfile.
{ # prevents execution from breaking from concurrent modification

	set -euo pipefail

	echo ┌─────────────┐
	echo │ Claude Code │
	echo └─────────────┘

	# ~/.claude is bind-mounted from the host, so it comes in root-owned.
	echo "==> Setting ownership of ~/.claude..."
	sudo chown $USER ~/.claude
	sudo chgrp $USER ~/.claude

	# Written here rather than at build time: $PWD is the workspace folder now,
	# but would be / in the Dockerfile.
	cat > ~/.claude.json <<EOF
{
	"hasCompletedOnboarding": true,
	"projects": {
		"$PWD": {
			"hasTrustDialogAccepted": true
		}
	}
}
EOF

	echo ┌─\────────────┐
	echo │ ✅  Complete │
	echo └─\────────────┘

	exit 0
}
