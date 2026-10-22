extends "res://test/totems_smoke.gd"

## S09 block E: the tournaments in the Godot client, end to end against a live
## server. In Spanish.
##
##   godot --path godot -s test/tournaments_smoke.gd [-- --shot-dir=D]
##
## 1. Carry-over: arriving in the lobby, the coach is asked about a tournament
##    it could not finish (28618 → askDialog); yes → 28617 → it is entered in
##    the next edition.
## 2. Calendar: the scheduled tournament sits on the day of its search period,
##    with its periods, its kind and its registration deadline; registering
##    marks it entered; the bracket is drawn by rounds.
## 3. Team → Torneos: the tournament is listed with its search open; "Buscar
##    rival del torneo" (28611) brings up the lobby's searching bar, and the
##    bar's cancel (28609 → 28610) takes it down.
## 4. A search period opens during the session: 28646 → toast, search open.
## 5. Player tournament: with a "Création de Tournoi" card (807), the
##    Calendar's form sends 17010 and the new tournament is listed.
##
## Seeding (server stopped, on a COPY of arena.db; coach "test" = id 1) is
## done by tools in the session that ran it; see the S09 sprint for the SQL.

const CARRY_NEXT := "Copa Smoke II"
const OPEN_CUP := "Copa Smoke Abierta"
const LATE_CUP := "Copa Smoke Tarde"
const PLAYER_CUP := "Copa de Prueba Godot"


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await create_timer(0.2).timeout
	await _carry()
	await _calendar_s09()
	await _team_tab()
	await _period_opens()
	await _create()
	i18n.set_locale(_lang_before)


func _tid_named(name: String) -> int:
	for tid in _main._tourn_rows:
		if str(_main._tourn_rows[tid].get("name", "")) == name:
			return int(tid)
	return -1


func _carry() -> void:
	# 28601 goes out on arrival; the question follows the list
	await _wait(func(): return _seen.has(28618), 6.0)
	await _wait(func(): return _main._gui.is_open("askDialog"), 3.0)
	await create_timer(0.5).timeout
	var ask: Dictionary = _main._gui.gui.model.get_value("ask")
	_record(13, "carry ask", _seen.has(28618) and str(ask.get("text", "")).contains(CARRY_NEXT),
		"28618 → '%s'" % ask.get("text", "—"))
	await _shot("carry-ask")
	if _main._asks.is_empty():
		return
	_seen.clear()
	_main._asks[0].answer.call(true)
	_main._asks.pop_front()
	_main._ask_show()
	await _wait(func(): return _seen.has(28602), 3.0)
	await create_timer(0.3).timeout
	var tid := _tid_named(CARRY_NEXT)
	_record(13, "carry yes", tid >= 0 and _main._registered_tids.has(tid),
		"28617 → 28602: entered in '%s' (%d)" % [CARRY_NEXT, tid])


func _calendar_s09() -> void:
	var panel = await _menu("nav.calendar", "calendarDialog")
	await _wait(func(): return _seen.has(17003) and _seen.has(28602), 3.0)
	await create_timer(0.3).timeout
	var tid := _tid_named(OPEN_CUP)
	var cell := {}
	var ev := {}
	for c in _main._gui.gui.model.get_value("calendar").get("calendar", []):
		for e in c.get("events", []):
			if int(e.id) == tid and cell.is_empty():
				cell = c   # its first period's day; the second is tomorrow
				ev = e
	var today := str(Time.get_datetime_dict_from_system().day)
	_record(13, "on its day", panel != null and not cell.is_empty() and str(cell.day) == today,
		"'%s' on day %s (today %s)" % [OPEN_CUP, cell.get("day", "—"), today])
	if cell.is_empty():
		return
	panel.selected = cell
	panel.schedule_refresh()
	await create_timer(0.4).timeout
	var periods = panel.find_child("Periods%d" % tid, true, false)
	_record(13, "details", periods != null and not ev.get("periods", []).is_empty(),
		"%s · %s" % [periods.text if periods != null else "—", ev.get("regUntil", "")])
	await _shot("cal-details")
	var bracket_btn: Button = panel.find_child("Bracket%d" % tid, true, false)
	if bracket_btn == null:
		_record(13, "bracket", false, "not entered in '%s' (seed it)" % OPEN_CUP)
		return
	_seen.clear()
	bracket_btn.pressed.emit()
	await _wait(func(): return _seen.has(28650), 3.0)
	await create_timer(0.4).timeout
	var drawn = panel.find_child("Draw%d" % tid, true, false)
	var slots: Dictionary = _main._gui.gui.model.get_value("calendar").get("bracket", {}).get("slots", {})
	var rounds: Array = []
	if drawn is HBoxContainer:
		for col in drawn.get_children():
			rounds.append(col.get_child(0).text)
	_record(13, "bracket rounds", _seen.has(28650) and rounds.size() >= 1,
		"%d seat(s), columns %s" % [slots.size(), rounds])
	await _shot("cal-bracket")


func _team_tab() -> void:
	_close_all()
	_main._gui.open("teamManagementDialog")
	await _wait(func(): return _main._gui.is_open("teamManagementDialog"), 3.0)
	await _wait(func(): return _seen.has(28602), 3.0)
	var panel = _main._gui.dialogs.get("teamManagementDialog")
	panel.tab = 3
	panel.schedule_refresh()
	await create_timer(0.6).timeout
	var pick: OptionButton = panel.find_child("TournamentPick", true, false)
	var find: Button = panel.find_child("FindTournament", true, false)
	_record(13, "team tab", pick != null and find != null and not find.disabled,
		"Torneos: '%s', button %s" % [pick.get_item_text(pick.selected) if pick != null else "—",
			"enabled" if find != null and not find.disabled else "disabled"])
	await _shot("team-tournaments")
	if find == null or find.disabled:
		return
	_seen.clear()
	find.pressed.emit()
	await _wait(func(): return _seen.has(28612) or _seen.has(28616), 3.0)
	await create_timer(0.4).timeout
	_record(13, "search", _seen.has(28612) and _main._searching and _main._search_kind == 4,
		"28611 → %s, lobby searching=%s" % ["28612" if _seen.has(28612) else "28616", _main._searching])
	await _shot("searching")
	_seen.clear()
	_main._on_cancel_search()
	await _wait(func(): return _seen.has(28610), 3.0)
	await create_timer(0.3).timeout
	_record(13, "cancel", _seen.has(28610) and not _main._searching,
		"28609 → 28610, lobby searching=%s" % _main._searching)


func _period_opens() -> void:
	# LATE_CUP's first period is seeded to open about a minute after login
	var tid := _tid_named(LATE_CUP)
	await _wait(func(): return _seen.has(28646), 90.0)
	await create_timer(0.4).timeout
	_record(13, "period opens", _seen.has(28646) and bool(_main._search_open.get(tid, false)),
		"28646 for '%s': search open" % LATE_CUP)
	await _shot("period-open")


func _create() -> void:
	var panel = await _menu("nav.calendar", "calendarDialog")
	await create_timer(0.4).timeout
	var create: Button = panel.find_child("CreateTournament", true, false) if panel != null else null
	if create == null or create.disabled:
		_record(13, "create", false, "no Crear torneo (seed card 807)")
		return
	create.pressed.emit()
	await create_timer(0.4).timeout
	panel.draft["t_name"] = PLAYER_CUP
	panel.draft["t_desc"] = "Hecha desde el smoke"
	# tomorrow if the month allows, else the last day of the month on show
	var days := 0
	for c in _main._gui.gui.model.get_value("calendar").get("calendar", []):
		if str(c.get("day", "")) != "":
			days += 1
	var day := mini(int(Time.get_datetime_dict_from_system().day) + 1, days)
	panel.draft["t_day"] = str(day)
	panel.schedule_refresh()
	await create_timer(0.4).timeout
	await _shot("create-form")
	var send: Button = panel.find_child("CreateSend", true, false)
	_seen.clear()
	send.pressed.emit()
	await create_timer(0.2).timeout
	_confirm(panel)
	await _wait(func(): return _seen.has(28602), 4.0)
	await create_timer(0.4).timeout
	var tid := _tid_named(PLAYER_CUP)
	_record(13, "create", tid >= 0 and str(_main._tourn_rows[tid].get("organizer", "")) == "test",
		"17010 → listed '%s' (%d), organizer %s" % [PLAYER_CUP, tid,
			_main._tourn_rows.get(tid, {}).get("organizer", "—")])
