extends SceneTree

## S29: an offline tournament, live, from the player's side. In Spanish.
##   godot --headless --path godot -s test/tourn_offline_smoke.gd -- --tid=N
## Needs the local server and a classic tournament N whose draw is a couple
## of minutes away, with another entrant that has a ghost (the S29 sprint
## says how it was seeded). `test` has a ghost of its own.
##
## 1. The server says classic tournaments play offline (60001), and the
##    Calendar's event for N carries the "se juega solo" note.
## 2. Registering (4607) is accepted.
## 3. A 28608 with code 3 reads "crea un fantasma".
## 4. After the draw the server has played the fixture: "Combates" (60032)
##    lists it with both names.
## 5. "Ver" (60034) downloads the recording in chunks, opens the fight view
##    on it, plays it to the result and goes back to the lobby; the file is
##    in user://replays.

const State := preload("res://src/state.gd")
const ReplayFile := preload("res://src/net/replay_file.gd")

var main
var failures := 0
var tid := -1


func _initialize() -> void:
	run.call_deferred()


func check(ok: bool, message: String) -> void:
	print("[offline] %s: %s" % ["PASS" if ok else "FAIL", message])
	if not ok:
		failures += 1


func wait_for(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while not cond.call() and t < secs:
		await create_timer(0.25).timeout
		t += 0.25
	return cond.call()


func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text and node.is_visible_in_tree():
		return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null:
			return found
	return null


func run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tid="):
			tid = int(a.get_slice("=", 1))
	var i18n: Node = root.get_node("I18n")
	i18n.set_locale("es")
	main = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	main._login_screen.submit.emit("test", "test123", "127.0.0.1:5555")
	check(await wait_for(func(): return main._lobby_ready, 30.0), "live login")
	if not main._lobby_ready:
		return _end()
	await create_timer(1.5).timeout
	# 1. offline, and the event says so
	check(State.offline_tournaments, "60001 says classic tournaments play offline")
	var ev: Dictionary = main._tourn_event_model({"tid": tid, "name": "?"},
		{"def_id": 1, "reg_open": 1})
	check(bool(ev.get("offline", false)), "the Calendar event carries the offline flag")
	# 2. register
	main._on_calendar_register([{"id": tid}], null)
	check(await wait_for(func(): return main._registered_tids.has(tid), 5.0), "4607 accepted (test has a ghost)")
	# 3. the needs-a-ghost answer, as the client reads it
	main._tourn_status = {}
	main._on_message(28608, _be_i64(424242) + PackedByteArray([3]))
	check(str(main._tourn_status.get("text", "")) == i18n.t("tourn.needs_ghost"),
		"28608 code 3 → '%s'" % str(main._tourn_status.get("text", "")))
	# 4. wait for the draw, then the fixtures
	print("[offline] waiting for the draw…")
	var listed := false
	for i in 60:
		main._on_native_lobby_action("nativeTournMatches", [tid], null, 0)
		if await wait_for(func(): return int(main._tourn_matches.get("tid", -1)) == tid \
				and not main._tourn_matches.get("rows", []).is_empty(), 5.0):
			listed = true
			break
	var rows: Array = main._tourn_matches.get("rows", []) if listed else []
	check(listed and rows.size() == 1 and str(rows[0].winner) != "" and str(rows[0].loser) != "",
		"60033: %s" % str(rows))
	if rows.is_empty():
		return _end()
	# 5. watch it
	var before := ReplayFile.list().size()
	main._on_native_lobby_action("nativeTournReplay", [tid, int(rows[0].slot)], null, 0)
	check(await wait_for(func(): return current_scene != null \
		and current_scene.scene_file_path.ends_with("fight_view.tscn"), 20.0), "Ver opens the fight view")
	var fv = current_scene
	if fv == null or not fv.scene_file_path.ends_with("fight_view.tscn"):
		return _end()
	check(State.replay != null, "the fight reads the recording")
	check(ReplayFile.list().size() == before + 1, "the recording is kept in user://replays")
	var speed: Button = fv.get_node("UI/ReplayBar").find_child("SpeedBtn", true, false)
	speed.pressed.emit()
	speed.pressed.emit()
	check(await wait_for(func(): return fv._result_modal != null, 240.0), "the recording reaches the result")
	var cont := find_button(fv, i18n.t("fight.result.continue"))
	if cont != null:
		cont.pressed.emit()
	check(await wait_for(func(): return current_scene != null \
		and current_scene.scene_file_path.ends_with("main.tscn"), 10.0), "back to the lobby")
	_end()


func _be_i64(v: int) -> PackedByteArray:
	var out := PackedByteArray()
	for i in 8:
		out.append((v >> (8 * (7 - i))) & 0xFF)
	return out


func _end() -> void:
	print("[offline] %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
