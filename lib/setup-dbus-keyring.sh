#!/usr/bin/env bash
# setup-dbus-keyring.sh — shared by the ubuntu and ubuntu-flutter variants.
#
# Pins ONE D-Bus session bus at a fixed socket path for the whole container
# and ensures gnome-keyring's Secret Service is UNLOCKED on it, so libsecret
# clients (supabase CLI, flutter_secure_storage, git-credential-libsecret)
# never hit a locked collection whose GUI unlock prompt can't appear headlessly.
#
# Why a fixed address: dbus-launch creates a new private bus per shell lineage;
# libsecret then D-Bus-activates a fresh LOCKED gnome-keyring on each bus, and
# an unlock performed on one bus doesn't help clients on another. containerEnv
# in devcontainer.json sets DBUS_SESSION_BUS_ADDRESS to this same address for
# every container process. The socket must be path-based, not abstract: the
# container runs --network=host and abstract sockets live in the (shared)
# network namespace.
#
# Idempotent — safe to run on every container start and multiple times.

set -euo pipefail

DBUS_SOCKET="/tmp/dbus-session"
export DBUS_SESSION_BUS_ADDRESS="unix:path=${DBUS_SOCKET}"

bus_ok() {
	dbus-send --session --dest=org.freedesktop.DBus --print-reply \
		/org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping &>/dev/null
}

# Bus-driver call: NEVER causes service activation.
secrets_owned() {
	dbus-send --session --print-reply --dest=org.freedesktop.DBus \
		/org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
		string:org.freedesktop.secrets 2>/dev/null | grep -q 'boolean true'
}

# Only call when secrets_owned is true — calling it on an unowned name would
# D-Bus-activate a NEW locked daemon and race the one this script starts.
secrets_unlocked() {
	dbus-send --session --print-reply --dest=org.freedesktop.secrets \
		/org/freedesktop/secrets/aliases/default \
		org.freedesktop.DBus.Properties.Get \
		string:org.freedesktop.Secret.Collection string:Locked 2>/dev/null \
		| grep -q 'boolean false'
}

echo "==> Ensuring D-Bus session bus at ${DBUS_SESSION_BUS_ADDRESS}..."
if ! bus_ok; then
	# flock: postStart and the bashrc self-heal block may race at container
	# start; an unguarded rm -f could unlink a live socket another starter
	# just bound.
	exec 9>"${DBUS_SOCKET}.lock"
	flock 9
	if ! bus_ok; then
		# /tmp persists across container stop/start, so remove the stale
		# socket from the previous run (dbus-daemon won't unlink it itself).
		rm -f "${DBUS_SOCKET}"
		dbus-daemon --session --address="unix:path=${DBUS_SOCKET}" --fork
	fi
	flock -u 9
	exec 9>&-
fi
for _ in $(seq 20); do bus_ok && break; sleep 0.1; done
bus_ok || { echo "ERROR: D-Bus session bus failed to start" >&2; exit 1; }

if ! command -v gnome-keyring-daemon >/dev/null 2>&1; then
	echo "WARNING: gnome-keyring-daemon not installed; Secret Service unavailable" >&2
	exit 0
fi

start_unlocked_keyring() {
	# XDG_RUNTIME_DIR and GNOME_KEYRING_CONTROL are unset in these containers,
	# so gnome-keyring daemon discovery (and therefore --replace or re-unlock
	# of a running daemon) cannot work; killing and starting fresh is the only
	# reliable path.
	pkill -9 -f gnome-keyring-daemon 2>/dev/null || true
	rm -rf "$HOME"/.cache/keyring-*   # stale control directories
	# The password is the literal newline emitted by `echo ""` — gnome-keyring
	# does NOT strip trailing newlines from stdin, and the login keyring was
	# created with exactly this command at image build. Keep it byte-identical.
	# (Newline password = effectively unencrypted storage; acceptable for a
	# dev container.)
	echo "" | gnome-keyring-daemon --unlock --components=secrets --daemonize >/dev/null
	# Wait for the daemon to claim org.freedesktop.secrets before anyone
	# touches the name (touching it earlier would activate a locked copy).
	for _ in $(seq 50); do secrets_owned && break; sleep 0.1; done
}

echo "==> Ensuring gnome-keyring Secret Service is unlocked..."
if ! secrets_owned || ! secrets_unlocked; then
	start_unlocked_keyring
	if ! secrets_owned || ! secrets_unlocked; then
		echo "==> Unlock failed; recreating login keyring with blank password..."
		pkill -9 -f gnome-keyring-daemon 2>/dev/null || true
		rm -f "$HOME/.local/share/keyrings/login.keyring"
		start_unlocked_keyring
	fi
fi

if secrets_owned && secrets_unlocked; then
	echo "==> Secret Service ready (default collection unlocked)"
else
	echo "ERROR: Secret Service default collection is still locked" >&2
	exit 1
fi
