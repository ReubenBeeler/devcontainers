FROM mcr.microsoft.com/devcontainers/base:noble

# Run post-build setup as vscode — installs tools into the image.
# postCreate.sh and postStart.sh still run at container lifecycle time from the
# workspace; only what can be baked ahead of time lives here.
USER vscode
RUN bash <<'EOPOSTCREATE'
#!/usr/bin/env bash
{ # prevents execution from breaking from concurrent modification
	set -euo pipefail

	echo ┌──────────────────┐
	echo │ System utilities │
	echo └──────────────────┘

	echo 'apt updating and upgrading...'
	sudo apt-get update -y > /dev/null
	# Hold tzdata so apt-get upgrade doesn't try to hard-link over the bind-mounted
	# timezone files from devcontainer feature match-host-time-zone
	sudo apt-mark hold tzdata
	sudo apt-get upgrade -y > /dev/null

	echo 'apt installing basic utilities...'
	sudo apt-get install -y > /dev/null \
		curl git zip unzip xz-utils moreutils

	echo ┌───────────────────────┐
	echo │ D-Bus + gnome-keyring │
	echo └───────────────────────┘

	# Secret Service for CLI credential storage (supabase login, etc.) —
	# postStart.sh runs scripts/setup-dbus-keyring.sh on every container start.
	# dbus-session-bus-common provides session.conf, which dbus-daemon
	# --session needs (the dbus metapackage only pulls the system-bus config).
	# No dbus-x11/X needed: the bus uses a fixed socket path, and the keyring
	# is unlocked via stdin, never a GUI prompt.
	sudo apt-get install -y > /dev/null \
		dbus dbus-session-bus-common gnome-keyring libsecret-tools

	echo ┌─────┐
	echo │ Act │ # (run GitHub Actions locally)
	echo └─────┘

	curl -fsSL https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash -s -- -b /usr/local/bin

	echo ┌──────────┐
	echo │ Lefthook │
	echo └──────────┘

	LEFTHOOK_VERSION=$(curl -fsSL https://api.github.com/repos/evilmartians/lefthook/releases/latest | grep -o '"tag_name": "v[^"]*"' | grep -o '[0-9][^"]*')
	echo "installing lefthook version $LEFTHOOK_VERSION..."
	LEFTHOOK_DEB=$(mktemp --suffix='.deb')
	curl -fsSL -o "$LEFTHOOK_DEB" "https://github.com/evilmartians/lefthook/releases/download/v${LEFTHOOK_VERSION}/lefthook_${LEFTHOOK_VERSION}_amd64.deb"
	sudo apt-get install -y "$LEFTHOOK_DEB" > /dev/null
	rm "$LEFTHOOK_DEB"

	echo ┌─────────────┐
	echo │ Claude Code │
	echo └─────────────┘

	echo 'claude --permission-mode bypassPermissions' >> ~/.bash_history

	curl -fsSL https://claude.ai/install.sh | bash -s stable
	# see {"autoUpdatesChannel": "stable"} in settings json for auto-update channel

	echo ┌─\────────────┐
	echo │ ✅  Complete │
	echo └─\────────────┘

	exit 0
}
EOPOSTCREATE
USER root
