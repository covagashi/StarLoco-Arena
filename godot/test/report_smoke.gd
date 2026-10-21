extends "res://test/world_smoke.gd"

## S18: the native fight report against a live server, in Spanish.
##
##   godot --path godot -s test/report_smoke.gd [-- --shot-dir=D]
##
## Two fights, each launched with a challenge (26330 → 8000) and surrendered
## a few seconds in (8151):
##  1. the lobby gets the 8300 itself (the player backed out of the fight
##     view): the native fightReportDialog opens with the outcome, the
##     coaches and the fighters' report; "Continuar" closes it.
##  2. the normal path: the old lobby is unhooked (as if freed), the fight
##     view gets the 8300 and acks it, the server re-enters the coach (4516)
##     and a FRESH main scene must show the lobby and the report (B-178: it
##     drained that 4516 before its GUI existed, so neither appeared).
## No debug pane on the way. Each run loses two fights for the `test` coach:
## its fighters bank tiredness and morale like any defeat.

const CHALLENGE := 3   # the Hell's Tofus (SuperBidi)
const VICTORY_CHALLENGE := 14   # "last 20 rounds" (np_1 type 14, B-074)

var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	_seen.clear()
	_main._launch_challenge(CHALLENGE, 99)
	var started: bool = await _wait(func(): return _seen.has(8000), 6.0)
	_record(8300, "fight", started, "26330 → 8000")
	if not started:
		i18n.set_locale(_lang_before)
		return
	await create_timer(5.0).timeout
	_sess.send(8151, PackedByteArray(), 3)
	var over: bool = await _wait(func(): return _seen.has(8300), 8.0)
	await _wait(func(): return _main._gui.is_open("fightReportDialog"), 3.0)
	await create_timer(0.6).timeout
	var panel = _main._gui.dialogs.get("fightReportDialog")
	var r: Variant = _main._gui.gui.model.get_value("fightReport")
	var rep: Dictionary = r if r is Dictionary else {}
	var ok: bool = over and panel != null and not _debug_pane_shown() \
		and str(panel.title.text) != "" and panel.find_child("Continue", true, false) != null
	_record(8300, "report", ok, "8151 → 8300: '%s', %d coach(es), %d fighter row(s), summary %s" % [
		panel.title.text if panel != null else "—", rep.get("coaches", []).size(),
		rep.get("fighters", []).size(), rep.get("summary", [])])
	await _shot("fight-report")
	if panel != null:
		panel.find_child("Continue", true, false).pressed.emit()
		await create_timer(0.4).timeout
		_record(8300, "close", not _main._gui.is_open("fightReportDialog"), "Continuar closes it")
	await create_timer(1.0).timeout
	await _evolution_rows()
	await create_timer(0.5).timeout
	await _level_up()
	await create_timer(0.5).timeout
	await _normal_path()
	await create_timer(1.0).timeout
	await _victory_condition()
	i18n.set_locale(_lang_before)


## S08 (B-074): a fight won by a VICTORY CONDITION ends with the loser still
## standing — a state nothing else produces (a surrender kills the side that
## gives up). Challenge 14 is won by lasting 20 rounds; /TABLETURN 20 (admin)
## jumps the round counter, our turns end at once, and the next round meets
## the condition. The report must say victory while the enemy is alive.
func _victory_condition() -> void:
	var lobby = current_scene
	if lobby == null or not "_gui" in lobby:
		_record(8300, "victory condition", false, "no lobby to launch from")
		return
	_seen.clear()
	lobby._launch_challenge(VICTORY_CHALLENGE, 99)
	if not await _wait(func(): return _seen.has(8000), 6.0):
		_record(8300, "victory condition", false, "no 8000")
		return
	# the scene change frees this lobby; one still alive must not listen
	if is_instance_valid(lobby) and _sess.message.is_connected(lobby._on_message):
		_sess.message.disconnect(lobby._on_message)
	await _wait(func():
		return current_scene != null and current_scene.has_signal("turn_began"), 6.0)
	var fight = current_scene
	if fight == null or not fight.has_signal("turn_began"):
		_record(8300, "victory condition", false, "no fight view")
		return
	var ref: WeakRef = weakref(fight)
	fight.turn_began.connect(func(_fid, ours):
		if ours:
			create_timer(0.3).timeout.connect(func():
				var f = ref.get_ref()
				if f != null:
					f.request_end_turn()))
	fight.placement_began.connect(func():
		create_timer(0.3).timeout.connect(func():
			var f = ref.get_ref()
			if f != null:
				f.confirm_placement()))
	if fight._placement:
		fight.confirm_placement()
	await _wait(func(): return _seen.has(8040), 20.0)   # combat started
	var line := "/TABLETURN 20".to_ascii_buffer()
	var w := WireWriter.new()
	w.put_u16(line.size())
	w.put_bytes(line)
	_sess.send(3153, w.raw(), 3)
	var over: bool = await _wait(func(): return _seen.has(8300), 60.0)
	await create_timer(1.0).timeout
	var enemy_alive := 0
	if is_instance_valid(fight):
		for fid in State.fighters:
			if int(State.fighters[fid].get("coach", -1)) != State.my_coach_id \
					and not fight._dead.get(fid, false):
				enemy_alive += 1
		fight._end_fight_ack()
	var back: bool = await _wait(func():
		var sc = current_scene
		return sc != null and "_gui" in sc and sc._gui != null \
			and sc._gui.is_open("fightReportDialog"), 10.0)
	var rep: Dictionary = {}
	if back:
		var r: Variant = current_scene._gui.gui.model.get_value("fightReport")
		rep = r if r is Dictionary else {}
	_record(8300, "victory condition", over and back and rep.get("outcome", "") == "victory"
		and enemy_alive > 0, "challenge %d: outcome '%s' with %d enemy fighter(s) alive" % [
		VICTORY_CHALLENGE, rep.get("outcome", "—"), enemy_alive])
	await _shot("fight-report-victory-condition")


## Challenge fights carry no fighter reports (only evolution ones do): feed
## the decoded shape of one — two fighters, one killed, a card won — so the
## Fighters and Cards tables are exercised too.
func _evolution_rows() -> void:
	var me := int(State.my_coach_id)
	var f1 := int(State.roster[0].id) if State.roster.size() > 0 else 1
	var f2 := int(State.roster[1].id) if State.roster.size() > 1 else 2
	State.fight_result = {"winners": [{"id": me}], "losers": [{"id": 999}],
		"win_str": {me: 1012}, "lose_str": {999: 988}, "standing": 3,
		"killed": 1, "injured": 0, "won_cards": [128, 128],
		"reports": [
			{"fighter": f1, "xp_final": 40, "morale": 55, "morale_delta": 5,
				"tiredness": 20, "tiredness_delta": 10},
			{"fighter": f2, "xp_final": 15, "morale": 40, "morale_delta": -5,
				"tiredness": 35, "tiredness_delta": 15, "dead": true}]}
	var morale_before := int(State.roster[0].get("morale", 0)) if State.roster.size() > 0 else 0
	_main._show_fight_result()
	await create_timer(0.6).timeout
	var panel = _main._gui.dialogs.get("fightReportDialog")
	var fighters = panel.find_child("Fighters", true, false) if panel != null else null
	var cards = panel.find_child("Cards", true, false) if panel != null else null
	var rows: int = fighters.get_root().get_child_count() if fighters != null else 0
	var r: Dictionary = _main._gui.gui.model.get_value("fightReport")
	_record(8300, "fighter rows", panel != null and str(panel.title.text) == "Victoria"
		and rows == 2 and cards != null and str(r.fighters[1].state) == "Muerto" and _fits(panel)
		and int(State.roster[0].get("morale", -1)) == 55,
		"Victoria, %d fighter rows (2nd '%s'), cards %s, roster morale %d → %d" % [rows,
			r.fighters[1].state if r.get("fighters", []).size() > 1 else "—",
			r.get("cards", []), morale_before, int(State.roster[0].get("morale", -1))])
	await _shot("fight-report-evo")
	if panel != null:
		panel.find_child("Continue", true, false).pressed.emit()
		await create_timer(0.3).timeout


## S07: a fight whose standing crosses a level. The lobby shows the level
## from the standing (it was a hard-coded 0) and, once the report is closed,
## the native level-up notice pops with the new level. Client-side only:
## the standing is put back afterwards.
func _level_up() -> void:
	var standing_before := int(State.coach_standing)
	var lvl := int(State.coach_level(standing_before))
	var shown_before: String = _main._lobby_screen._level.text
	# just short of the next level, then a fight that wins 25
	State.coach_standing = State.standing_for_level(lvl + 1) - 10
	State.fight_result = {"winners": [{"id": int(State.my_coach_id)}], "losers": [{"id": 999}],
		"win_str": {}, "lose_str": {}, "standing": 25, "won_cards": [], "reports": []}
	_main._show_fight_result()
	await create_timer(0.6).timeout
	var lobby_level: String = _main._lobby_screen._level.text
	var report = _main._gui.dialogs.get("fightReportDialog")
	var early: bool = _main._gui.is_open("coachLevelUpDialog")
	if report != null:
		report.find_child("Continue", true, false).pressed.emit()
	await _wait(func(): return _main._gui.is_open("coachLevelUpDialog"), 2.0)
	await create_timer(0.6).timeout
	var p = _main._gui.dialogs.get("coachLevelUpDialog")
	var shown: String = p.find_child("Level", true, false).text if p != null else "—"
	_record(8300, "level up", not early and p != null and shown == str(lvl + 1)
		and lobby_level == I18n_t("lobby.level", {"n": lvl + 1}),
		"lobby '%s' → '%s'; after the report, the notice says %s (want %d)" % [
			shown_before, lobby_level, shown, lvl + 1])
	await _shot("level-up")
	if p != null:
		p.find_child("Continue", true, false).pressed.emit()
		await create_timer(0.3).timeout
	# a fight that crosses nothing: no notice
	State.fight_result = {"winners": [], "losers": [], "win_str": {}, "lose_str": {},
		"standing": 1, "won_cards": [], "reports": []}
	_main._show_fight_result()
	await create_timer(0.4).timeout
	report = _main._gui.dialogs.get("fightReportDialog")
	if report != null:
		report.find_child("Continue", true, false).pressed.emit()
	await create_timer(0.6).timeout
	_record(8300, "no level up", not _main._gui.is_open("coachLevelUpDialog"),
		"+1 standing inside a level: no notice")
	State.coach_standing = standing_before
	_main._push_local_coach()


func I18n_t(key: String, args := {}) -> String:
	return root.get_node("I18n").t(key, args)


func _normal_path() -> void:
	# The first fight's re-entry already loaded a fresh main as the current
	# scene. Drive this one from it and unhook the harness's own main, so a
	# single lobby handles the 8000 — as in the game, where change_scene frees
	# the previous one.
	var lobby = current_scene if current_scene != null and "_gui" in current_scene else _main
	if lobby != _main and _sess.message.is_connected(_main._on_message):
		_sess.message.disconnect(_main._on_message)
	_seen.clear()
	lobby._launch_challenge(CHALLENGE, 99)
	if not await _wait(func(): return _seen.has(8000), 6.0):
		_record(8300, "fight 2", false, "no 8000")
		return
	# from here no lobby is listening: the fight view owns the socket
	for m in [_main, lobby]:
		if is_instance_valid(m) and _sess.message.is_connected(m._on_message):
			_sess.message.disconnect(m._on_message)
	await create_timer(5.0).timeout
	_sess.send(8151, PackedByteArray(), 3)
	await _wait(func(): return _seen.has(8300), 8.0)
	await create_timer(1.0).timeout
	var fight = current_scene
	if fight == null or not fight.has_method("_end_fight_ack"):
		_record(8300, "normal path", false, "no fight view as the current scene")
		return
	fight._end_fight_ack()    # the result modal's "Continuar"
	var lobby_back: bool = await _wait(func():
		var sc = current_scene
		return sc != null and sc != fight and "_gui" in sc and sc._gui != null \
			and sc._gui.is_open("fightReportDialog"), 10.0)
	var sc = current_scene
	var shown: bool = lobby_back and is_instance_valid(sc._lobby_screen) and sc._lobby_screen.visible
	_record(8300, "normal path", shown, "8300 → fight view ack → 4516 → fresh lobby with the report")
	await _shot("fight-report-normal")


func _fits(panel) -> bool:
	var found: Array = panel.find_children("*", "ScrollContainer", true, false)
	if found.is_empty():
		return false
	var bar: VScrollBar = found[0].get_v_scroll_bar()
	return bar.max_value - bar.page <= 1.0
