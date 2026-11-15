#!/usr/bin/env bash
## S43 step 3: play a whole fight with nothing from the old client.
##
##   godot/tools/no_retail_smoke.sh [arena.db]
##   SMOKES="fight_smoke hub_smoke" godot/tools/no_retail_smoke.sh
##
## Moves the retail folders of godot/assets/ (anims, mapgfx, fx, gui, sounds,
## musics, gamedata) and server/data-dist/ aside, builds and starts the server
## on a copy of the database (default server/arena.db: fight_smoke logs in as
## test/test123 and needs its coach), plays test/fight_smoke.gd under xvfb and
## puts everything back, whatever happens. It fails if the fight does not end,
## the server loads no spells, or the client tries to open any file that is
## not there (ARENA_ASSET_TRACE). SMOKES runs other test/<name>.gd scripts too,
## each of which must exit 0.
##
## Port 5555 must be free. GODOT overrides the binary.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DB="${1:-$REPO/server/arena.db}"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
RETAIL=(anims mapgfx fx gui sounds musics gamedata)

WORK="$(mktemp -d)"
## Same filesystem as the repo where possible, so moving 350 MB is a rename.
ASIDE="$REPO/../.no-retail-smoke.$$"
mkdir -p "$ASIDE/assets"
SERVER_PID=""

restore() {
	[[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" 2>/dev/null || true
	for d in "${RETAIL[@]}"; do
		if [[ -d "$ASIDE/assets/$d" ]]; then
			find "$ASIDE/assets/$d" -mindepth 1 -maxdepth 1 -exec mv -t "$REPO/godot/assets/$d" {} +
		fi
	done
	[[ -d "$ASIDE/data-dist" ]] && mv "$ASIDE/data-dist" "$REPO/server/data-dist"
	rm -rf "$ASIDE"
	if [[ "${fail:-1}" -ne 0 ]]; then
		echo "[no-retail] logs kept in $WORK"
	else
		rm -rf "$WORK"
	fi
}
trap restore EXIT

echo "[no-retail] moving the old client's files aside"
for d in "${RETAIL[@]}"; do
	mkdir -p "$ASIDE/assets/$d"
	if [[ -d "$REPO/godot/assets/$d" ]]; then
		## .gdignore stays: it is tracked and ours.
		find "$REPO/godot/assets/$d" -mindepth 1 -maxdepth 1 ! -name .gdignore \
			-exec mv -t "$ASIDE/assets/$d" {} +
	fi
done
[[ -d "$REPO/server/data-dist" ]] && mv "$REPO/server/data-dist" "$ASIDE/data-dist"

echo "[no-retail] building the server"
(cd "$REPO/server" && go build -o "$WORK/arena" ./cmd/server)
cp "$DB" "$WORK/arena.db"
cat > "$WORK/config.yaml" <<'EOF'
addr: "127.0.0.1:5555"
web:
  enabled: false
data_dir: "no-such-dir"
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
	echo "[no-retail] FAIL the server loaded no spells"
	exit 1
fi

WRAP=()
command -v xvfb-run >/dev/null && WRAP=(xvfb-run -a -s "-screen 0 1280x720x24")
fail=0
for smoke in ${SMOKES:-fight_smoke}; do
	echo "[no-retail] playing $smoke"
	log="$WORK/$smoke.log"
	rc=0
	ARENA_ASSET_TRACE=1 ${WRAP[@]+"${WRAP[@]}"} "$GODOT" --path "$REPO/godot" -s "test/$smoke.gd" >"$log" 2>&1 || rc=$?
	bad=0
	if [[ $rc -ne 0 ]]; then
		echo "[no-retail] FAIL $smoke exited $rc"
		bad=1
	fi
	if [[ $smoke == fight_smoke ]] && ! grep -q "END FIGHT" "$log"; then
		echo "[no-retail] FAIL the fight did not end"
		bad=1
	fi
	if grep -E "Can't open file|asset json unusable|\[assets\] missing" "$log" | sort | uniq -c; then
		echo "[no-retail] FAIL $smoke looked for files that are not there"
		bad=1
	fi
	if [[ $bad -ne 0 ]]; then
		grep -E "FAIL|SCRIPT ERROR|^ERROR: [a-z]" "$log" | head -20 || true
		fail=1
	fi
done
[[ $fail -eq 0 ]] || exit 1
echo "[no-retail] OK: ${SMOKES:-fight_smoke} with no file from the old client"
