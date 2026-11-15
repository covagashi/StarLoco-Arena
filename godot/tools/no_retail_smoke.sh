#!/usr/bin/env bash
## S43: play the smokes and fail on any read of a file that is not there.
##
##   godot/tools/no_retail_smoke.sh [arena.db]
##   SMOKES="fight_smoke hub_smoke" godot/tools/no_retail_smoke.sh
##
## Since S43 the repo holds nothing from the old client; this builds and starts
## the server on a copy of the database (default server/arena.db: fight_smoke
## logs in as test/test123 and needs its coach), plays test/fight_smoke.gd (or
## SMOKES) under xvfb with ARENA_ASSET_TRACE=1, and fails if the fight does not
## end, the server loads no spells, a smoke exits non-zero, or the client asks
## for any file that is not there.
##
## Port 5555 must be free. GODOT overrides the binary.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="${1:-$REPO/server/arena.db}"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"

WORK="$(mktemp -d)"
SERVER_PID=""

cleanup() {
	[[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
	if [[ "${fail:-1}" -ne 0 ]]; then
		echo "[smoke] logs kept in $WORK"
	else
		rm -rf "$WORK"
	fi
}
trap cleanup EXIT

echo "[smoke] building the server"
(cd "$REPO/server" && go build -o "$WORK/arena" ./cmd/server)
cp "$DB" "$WORK/arena.db"
cat > "$WORK/config.yaml" <<'EOF'
addr: "127.0.0.1:5555"
web:
  enabled: false
update_check:
  enabled: false
db:
  driver: "sqlite"
  dsn: "arena.db"
  max_open_conns: 1
  max_idle_conns: 1
EOF
(cd "$WORK" && exec ./arena -config config.yaml >server.log 2>&1) &
SERVER_PID=$!
for _ in $(seq 50); do
	grep -q "Game data" "$WORK/server.log" 2>/dev/null && break
	sleep 0.2
done
grep "Game data" "$WORK/server.log" || { cat "$WORK/server.log"; exit 1; }
if grep -q " 0 spells" "$WORK/server.log"; then
	echo "[smoke] FAIL the server loaded no spells"
	exit 1
fi

WRAP=()
command -v xvfb-run >/dev/null && WRAP=(xvfb-run -a -s "-screen 0 1280x720x24")
fail=0
for smoke in ${SMOKES:-fight_smoke}; do
	echo "[smoke] playing $smoke"
	log="$WORK/$smoke.log"
	rc=0
	ARENA_ASSET_TRACE=1 ${WRAP[@]+"${WRAP[@]}"} "$GODOT" --path "$REPO/godot" -s "test/$smoke.gd" >"$log" 2>&1 || rc=$?
	bad=0
	if [[ $rc -ne 0 ]]; then
		echo "[smoke] FAIL $smoke exited $rc"
		bad=1
	fi
	if [[ $smoke == fight_smoke ]] && ! grep -q "END FIGHT" "$log"; then
		echo "[smoke] FAIL the fight did not end"
		bad=1
	fi
	if grep -E "Can't open file|asset json unusable|\[assets\] missing" "$log" | sort | uniq -c; then
		echo "[smoke] FAIL $smoke looked for files that are not there"
		bad=1
	fi
	if [[ $bad -ne 0 ]]; then
		grep -E "FAIL|SCRIPT ERROR|^ERROR: [a-z]" "$log" | head -20 || true
		fail=1
	fi
done
[[ $fail -eq 0 ]] || exit 1
echo "[smoke] OK: ${SMOKES:-fight_smoke} with no missing file"
