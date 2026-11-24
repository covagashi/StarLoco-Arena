#!/usr/bin/env bash
## S51: «Guardar mi progreso» live — test/save_account_smoke.gd's phases in
## order against a fresh server (demo_accounts on, auto_register off, no
## mail host: the reset code goes to the server log), each phase with its
## own user:// (XDG_DATA_HOME) so a "fresh browser" really is one. In its own
## network namespace (unshare -rn: a qemu may hold 5555).
##   godot/tools/save_account_smoke.sh [shot dir, default ~/codigo/capturas/s51]
## Screenshots need a renderer: it runs under xvfb-run at 1280x720.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHOTS="${1:-$HOME/codigo/capturas/s51}"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
mkdir -p "$SHOTS"
WORK="$(mktemp -d)"
(cd "$REPO/server" && go build -o "$WORK/arena" ./cmd/server) || exit 1
cp "$REPO/godot/tools/save_account_smoke.inner.sh" "$WORK/inner.sh"
REPO="$REPO" WORK="$WORK" SHOTS="$SHOTS" GODOT="$GODOT" \
	timeout 900 unshare -rn bash -c 'ip link set lo up; bash "$WORK/inner.sh"'
rc=$?
[ $rc -eq 0 ] && rm -rf "$WORK" || echo "[smoke] logs kept in $WORK"
exit $rc
