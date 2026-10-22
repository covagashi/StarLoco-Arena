extends "res://test/pvp_smoke.gd"

## S09 closing check: a tournament fixture played live between the Godot
## client and a second client. In Spanish.
##
##   godot --path godot -s test/tournament_fight_smoke.gd
##
## Seed (server stopped, a COPY of arena.db): one scheduled edition "Copa
## Final" whose only search period is open now, with "test" (1) and "test2"
## (2) entered — so their fixture is the final. The main client presses
## Equipo → Torneos → "Buscar rival del torneo" (28611 → 28612, the lobby's
## searching bar); the bot sends its own 28611; the server pairs them (28614
## both, then the fight). The main client readies, passes its turns and
## surrenders after a while, so test2 wins the final: the bracket's root, the
## prize path, the finish (winner test2) and the points are then read back
## from the server's database by the session that ran this.

const CUP := "Copa Final"

var _tid := -1
var _fixture_starting := false
var _searching_seen := false
var _search_bar_down := false
var _results_s09: Array = []


func _on_main_msg(op: int, raw: PackedByteArray) -> void:
	if op == 8100:
		_rounds += 1
	match op:
		2048:
			_coach_create(_sess.client, "test")
		4516:
			if _bot_in_world:
				return   # the post-fight re-entry
			_login(_bot, "test2", "test123")
		28612:
			_searching_seen = _main._searching and _main._search_kind == 4
		28614:
			_fixture_starting = true
			await create_timer(0.2).timeout
			_search_bar_down = not _main._searching
			print("[s09] main 28614 — fixture starting; lobby searching=%s" % _main._searching)
		8000:
			_fight_seen = true
			print("[s09] main 8000 — the tournament fight")
			_drive_fight()
		8300:
			print("[s09] main 8300 — fight over")


func _on_bot_msg(op: int, raw: PackedByteArray) -> void:
	var p := WireReader.new(raw)
	match op:
		2048:
			_coach_create(_bot, "test2")
		2052:
			_bot_coach = int(p.get_i64())
		4516:
			if _bot_in_world:
				return
			_bot_in_world = true
			await _main_searches()
		8010:
			_bot.send_message(8011, PackedByteArray(), 3)
		8020:
			_bot.send_message(8023, PackedByteArray(), 3)
		8030:
			_bot.send_message(8031, PackedByteArray(), 3)
		8104:
			p.get_i32()
			p.get_i32()
			var w := WireWriter.new()
			w.put_i64(p.get_i64())
			_bot.send_message(8105, w.raw(), 3)
		8300:
			_bot.send_message(26321, PackedByteArray(), 3)
			print("[s09] bot fight done")


## The main client searches through the real Team panel, then the bot joins.
func _main_searches() -> void:
	await create_timer(1.0).timeout
	_main._gui.open("teamManagementDialog")
	await create_timer(1.5).timeout   # 28601 → 28602 for the tab
	for tid in _main._tourn_rows:
		if str(_main._tourn_rows[tid].get("name", "")) == CUP:
			_tid = int(tid)
	var panel = _main._gui.dialogs.get("teamManagementDialog")
	if panel == null or _tid < 0:
		_finish(1, "FAIL no team panel or no '%s' in the list" % CUP)
		return
	panel.tab = 3
	panel.draft["tournament"] = _tid
	panel.schedule_refresh()
	await create_timer(0.6).timeout
	var find: Button = panel.find_child("FindTournament", true, false)
	if find == null or find.disabled:
		_finish(1, "FAIL 'Buscar rival del torneo' missing or disabled")
		return
	find.pressed.emit()
	await create_timer(1.0).timeout
	print("[s09] main searching (bar up=%s)" % _searching_seen)
	_main._gui.close("teamManagementDialog")
	var w := WireWriter.new()
	w.put_i64(_tid)
	w.put_i64(_bot_coach)
	w.put_i16(-1)
	_bot.send_message(28611, w.raw(), 2)
	print("[s09] bot 28611 for %d" % _tid)


func _finish(code: int, msg: String) -> void:
	if _done:
		return
	_done = true
	var ok := code == 0 and _searching_seen and _fixture_starting and _search_bar_down and _fight_seen
	print("[s09] %s — search bar=%s, 28614=%s, bar down=%s, fight=%s, rounds=%d" % [
		"OK" if ok else "FAIL", _searching_seen, _fixture_starting, _search_bar_down,
		_fight_seen, _rounds])
	print("[s09] %s" % msg)
	quit(0 if ok else 1)


## Ready, pass the turns, surrender after a while: the bot wins the final.
func _drive_fight() -> void:
	var fv = null
	for i in 100:
		await process_frame
		if current_scene != null and current_scene.has_signal("placement_began"):
			fv = current_scene
			break
	if fv == null:
		_finish(1, "FAIL the fight view never came up")
		return
	var ref: WeakRef = weakref(fv)
	var press_ready := func():
		create_timer(0.5).timeout.connect(func():
			var s = ref.get_ref()
			if s != null:
				s.confirm_placement())
	fv.placement_began.connect(press_ready)
	if fv._placement:
		press_ready.call()
	fv.turn_began.connect(func(_fid, ours):
		if ours:
			create_timer(0.5).timeout.connect(func():
				var s = ref.get_ref()
				if s != null:
					s.request_end_turn()))
	await create_timer(15.0).timeout
	print("[s09] main surrenders the final")
	_sess.client.send_message(8151, PackedByteArray(), 3)
	# the scheduler ticks every 5 s; give it two
	await create_timer(12.0).timeout
	_finish(0, "tournament final played; read the result back from the server")
