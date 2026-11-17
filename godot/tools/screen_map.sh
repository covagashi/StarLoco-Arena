#!/usr/bin/env bash
## S47: the screen map. Builds the server, plays test/screen_map.gd against a
## copy of the database with a new account and with `test` (and a practice
## fight), then writes the page (tools/screen_map_page.py).
##
##   godot/tools/screen_map.sh OUT_DIR [arena.db]
##
## Runs in its own network namespace (unshare -rn): port 5555 on the host may
## belong to something else. Needs xvfb-run and Go. OUT_DIR/notas.html, if
## present, goes at the top of the page (the flow and the findings, by hand).
set -euo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$(realpath -m "$1")"
DB="${2:-$REPO/server/arena.db}"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
(cd "$REPO/server" && go build -o "$WORK/arena" ./cmd/server)
cat > "$WORK/config.yaml" <<'YAML'
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
YAML
cat > "$WORK/one.sh" <<SH
#!/usr/bin/env bash
ip link set lo up 2>/dev/null || true
cd "$WORK" && ./arena -config config.yaml > "\$1.server.log" 2>&1 &
SP=\$!
for _ in \$(seq 60); do grep -q "Game data" "\$1.server.log" 2>/dev/null && break; sleep 0.25; done
cd "$REPO/godot"
env -u DISPLAY xvfb-run -a -s "-screen 0 1280x720x24" timeout 900 "$GODOT" --path . \
	--resolution 1280x720 -s test/screen_map.gd -- --out="\$1" "\${@:2}" > "\$1.godot.log" 2>&1
rc=\$?
kill \$SP 2>/dev/null
exit \$rc
SH
chmod +x "$WORK/one.sh"
mkdir -p "$OUT"
rm -rf "$OUT/thumbs"
for run in "nuevo --as=mapa$(date +%s)" "veterano --as=test --fight"; do
	set -- $run
	cp "$DB" "$WORK/arena.db"
	rm -rf "${OUT:?}/$1"
	echo "[map] $1"
	unshare -rn "$WORK/one.sh" "$OUT/$1" "${@:2}"
done
python3 "$REPO/godot/tools/screen_map_page.py" "$OUT"
