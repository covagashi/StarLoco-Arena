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
	var ok: bool = over and panel != null and not _main.get_node("UI/ElementDlg").visible \
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
	await _normal_path()
	i18n.set_locale(_lang_before)


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


func _normal_path() -> void:
	_seen.clear()
	_main._launch_challenge(CHALLENGE, 99)
	if not await _wait(func(): return _seen.has(8000), 6.0):
		_record(8300, "fight 2", false, "no 8000")
		return
	# from here the old lobby is gone, as in the game (change_scene frees it)
	_sess.message.disconnect(_main._on_message)
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
