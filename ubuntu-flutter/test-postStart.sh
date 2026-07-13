#!/usr/bin/env bash
# test-postStart.sh — verifies postStart.sh and postCreate.sh behaved correctly.
# Run this inside the container after a rebuild.

PASS=0
FAIL=0

pass()   { echo "  ✅ $1"; ((PASS++)); }
fail() { echo "  ❌ $1"; ((FAIL++)); }

check_process() {
	local name="$1"
	# Linux truncates comm names at 15 chars; pgrep -f matches the full
	# command line but can false-positive on the calling shell itself.
	# Use pgrep -x with the first 15 chars of the process name instead.
	local comm="${name:0:15}"
	if pgrep -x "$comm" >/dev/null 2>&1; then
		pass "$name is running ($(pgrep -x "$comm" | head -1))"
	else
		fail "$name is NOT running"
	fi
}

# ── DNS ───────────────────────────────────────────────────────────────────────

echo
echo "── DNS ────────────────────────────────────────────────────────────────────"

if grep -q 'single-request-reopen' /etc/resolv.conf 2>/dev/null; then
	pass "resolv.conf has single-request-reopen"
else
	fail "resolv.conf missing single-request-reopen"
fi

ns_count=$(grep -c '^nameserver' /etc/resolv.conf 2>/dev/null || echo 0)
if [ "$ns_count" -ge 2 ]; then
	pass "$ns_count nameservers configured (fallback available)"
else
	fail "only $ns_count nameserver configured (no fallback)"
fi

if getent hosts google.com >/dev/null 2>&1; then
	pass "DNS resolution works (google.com)"
else
	fail "DNS resolution failed (google.com)"
fi

# ── udevd ─────────────────────────────────────────────────────────────────────

echo
echo "── udevd ──────────────────────────────────────────────────────────────────"

check_process "systemd-udevd"

if [ -d /dev/bus/usb ]; then
	pass "/dev/bus/usb exists"
else
	fail "/dev/bus/usb does not exist"
fi

if [ -f /etc/udev/rules.d/99-usb-open-access.rules ]; then
	pass "udev rule file exists"
else
	fail "udev rule file /etc/udev/rules.d/99-usb-open-access.rules missing"
fi

# ── ADB ──────────────────────────────────────────────────────────────────────

echo
echo "── ADB ────────────────────────────────────────────────────────────────────"

export ANDROID_HOME="$HOME/.android/SDK"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

if command -v adb >/dev/null 2>&1; then
	pass "adb binary found"
else
	fail "adb binary not found"
fi

if adb devices >/dev/null 2>&1; then
	pass "adb server reachable"
else
	fail "adb server not reachable"
fi

# ── Headless desktop ───────────────────────────────────────────────────────────

echo
echo "── Headless desktop ───────────────────────────────────────────────────────"

check_process "Xvfb"

if [ "${DISPLAY:-}" = ":99" ]; then
	pass "DISPLAY=:99"
else
	fail "DISPLAY is '${DISPLAY:-<unset>}' (expected :99)"
fi

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
	pass "DBUS_SESSION_BUS_ADDRESS is set"
else
	fail "DBUS_SESSION_BUS_ADDRESS is unset"
fi

check_process "at-spi2-registryd"
check_process "openbox"

# ── Secret Service ────────────────────────────────────────────────────────────
# gnome-keyring must be unlocked on the pinned session bus, or libsecret
# clients (supabase login, etc.) hang forever on a headless unlock prompt.

echo
echo "── Secret Service ─────────────────────────────────────────────────────────"

if [ "${DBUS_SESSION_BUS_ADDRESS:-}" = "unix:path=/tmp/dbus-session" ]; then
	pass "DBUS_SESSION_BUS_ADDRESS is the pinned bus"
else
	fail "DBUS_SESSION_BUS_ADDRESS is '${DBUS_SESSION_BUS_ADDRESS:-<unset>}' (expected unix:path=/tmp/dbus-session)"
fi

if dbus-send --session --dest=org.freedesktop.DBus --print-reply \
		/org/freedesktop/DBus org.freedesktop.DBus.Peer.Ping &>/dev/null; then
	pass "session bus reachable"
else
	fail "session bus not reachable"
fi

check_process "gnome-keyring-daemon"

# NameHasOwner is a bus-driver call and never D-Bus-activates the service;
# querying org.freedesktop.secrets directly while unowned would spawn a
# fresh LOCKED daemon.
if dbus-send --session --print-reply --dest=org.freedesktop.DBus \
		/org/freedesktop/DBus org.freedesktop.DBus.NameHasOwner \
		string:org.freedesktop.secrets 2>/dev/null | grep -q 'boolean true'; then
	pass "org.freedesktop.secrets is owned"
	if dbus-send --session --print-reply --dest=org.freedesktop.secrets \
			/org/freedesktop/secrets/aliases/default \
			org.freedesktop.DBus.Properties.Get \
			string:org.freedesktop.Secret.Collection string:Locked 2>/dev/null \
			| grep -q 'boolean false'; then
		pass "default collection is unlocked"
	else
		fail "default collection is LOCKED"
	fi
else
	fail "org.freedesktop.secrets has no owner"
fi

if printf 'poststart-roundtrip' | timeout 10 secret-tool store \
		--label='postStart test' poststart-test v1 2>/dev/null \
		&& [ "$(timeout 10 secret-tool lookup poststart-test v1 2>/dev/null)" = "poststart-roundtrip" ]; then
	pass "secret-tool store/lookup roundtrip"
	timeout 10 secret-tool clear poststart-test v1 2>/dev/null || true
else
	fail "secret-tool store/lookup roundtrip failed (would hang supabase login)"
fi

# ── Summary ────────────────────────────────────────────────────────────────────

echo
echo "── Summary ────────────────────────────────────────────────────────────────"
echo "  Passed: $PASS  Failed: $FAIL"
echo

if [ "$FAIL" -gt 0 ]; then
	exit 1
fi
