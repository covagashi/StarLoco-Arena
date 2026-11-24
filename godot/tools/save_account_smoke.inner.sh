#!/usr/bin/env bash
## Inside save_account_smoke.sh's namespace: the server, then the phases.
set -u
cd "$WORK"
cat > config.yaml <<'CFG'
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
limits:
  auto_register: false
  demo_accounts: true
  # every phase logs in from 127.0.0.1 within a few minutes: the default 10
  # a minute (which a claim and a reset share, bcrypt) would refuse some
  login_attempts_per_minute: 60
CFG
./arena -config config.yaml >server.log 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' EXIT
for _ in $(seq 50); do grep -q "Game data" server.log 2>/dev/null && break; sleep 0.2; done
EMAIL="Smoke.$RANDOM@example.com"
ARGS=(--demo-ui --email="$EMAIL" --password=primera123 --new-password=segunda456
	--server-log="$WORK/server.log" --shot-dir="$SHOTS")
fail=0
run() {   # run <phase> <browser> [more args]
	echo "[smoke] phase $1 (browser $2) ${3:-}"
	log="$WORK/$1${3:+-${3#--lang=}}.log"
	XDG_DATA_HOME="$WORK/browser-$2" xvfb-run -a -s "-screen 0 1280x720x24" \
		"$GODOT" --path "$REPO/godot" --resolution 1280x720 -s test/save_account_smoke.gd -- \
		--phase="$1" "${ARGS[@]}" ${3:-} >"$log" 2>&1 || fail=1
	grep -E "\[audit\]|SCRIPT ERROR" "$log"
}
run claim 1
run have 2
run jugar 2
run reset 3
run refused 2
# the same forms in French and English, for their captures (longer words)
EMAIL="Smoke.$RANDOM@example.com"
ARGS=(--demo-ui --email="$EMAIL" --password=primera123 --new-password=segunda456
	--server-log="$WORK/server.log" --shot-dir="$SHOTS")
run claim 4 --lang=fr
run reset 5 --lang=en
[ $fail -eq 0 ] && echo "[smoke] OK: save_account_smoke, every phase" || echo "[smoke] FAIL"
exit $fail
