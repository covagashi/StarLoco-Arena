extends "res://test/world_smoke.gd"

## S47: the reorganised screens, live. Logs in as `test` (or --as=NAME):
##
##   godot --path godot -s test/s47_smoke.gd [-- --shot-dir=D]
##
## 1. Reclutar: opened as Historia, a name the server refuses ("1234", no
##    letter) leaves the screen open with its error; a good name closes it
##    and the fighter is in the roster as an evolution one. The same as
##    Élite gives a classic fighter. An empty name never reaches the server.
## 2. Torneos: three tabs (Mis torneos, Calendario, Clasificación); the
##    ranking tab asks the server for the tournament board. Equipo has no
##    Torneos tab and Clasificación no tournament tab.
## 3. Logros has the Estadísticas tab with the coach's numbers.
## 4. The top icons: the friends icon opens Social, the bubble the mailbox,
##    the bars of the menu open the Menu; Servicios has no Buzón.
## Leaves the two recruits in the database (a throwaway copy, see
## tools/screen_map.sh for the isolated run).

const State2 := preload("res://src/state.gd")


func _audit() -> void:
	var i18n = root.get_node("I18n")
	i18n.set_locale("es")
	await _recruit(true)
	await _recruit(false)
	await _tournaments()
	await _stats_tab()
	await _icons()


func _recruit(evo: bool) -> void:
	_close_all()
	var kind := 2 if evo else 1
	_main._on_new_fighter_dialog([], null, evo, 9)
	await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 3.0)
	await create_timer(1.0).timeout
	var p = _main._gui.dialogs.get("fighterCreationDialog")
	var ok_screen: bool = p != null and p.find_child("Attacks", true, false) != null
	_record(6001, "recruit screen (%s)" % ("Historia" if evo else "Élite"), ok_screen,
		"class %s, %d attacks" % [p.sheet_title.text if p != null else "—",
			p.find_child("Attacks", true, false).get_child_count() if ok_screen else 0])
	if not ok_screen:
		return
	await _shot("recruit-" + ("story" if evo else "elite"))
	var edit: LineEdit = p.find_child("FighterName", true, false)
	var go: Button = p.find_child("Recruit", true, false)
	# empty: said on the screen, nothing sent
	edit.text = ""
	_seen.clear()
	go.pressed.emit()
	await create_timer(0.4).timeout
	var status: Label = p.find_child("Status", true, false)
	_record(6001, "empty name", not _seen.has(6000) and status.text != "", "'%s'" % status.text)
	# refused by the server: the screen stays with the reason
	edit.text = "1234"
	_seen.clear()
	go.pressed.emit()
	await _wait(func(): return _seen.has(6000), 4.0)
	await create_timer(0.4).timeout
	_record(6001, "refused name", _main._gui.is_open("fighterCreationDialog") and status.text != "",
		"open, '%s'" % status.text)
	# a good one: the screen closes, the fighter is ours
	var fname := ("Hist" if evo else "Elit") + str(Time.get_ticks_msec() % 100000)
	edit.text = fname
	_seen.clear()
	go.pressed.emit()
	await _wait(func(): return not _main._gui.is_open("fighterCreationDialog"), 5.0)
	await _wait(func(): return State2.roster.any(func(f): return str(f.get("name", "")) == fname), 4.0)
	var made: Array = State2.roster.filter(func(f): return str(f.get("name", "")) == fname)
	_record(6001, "recruited", not _main._gui.is_open("fighterCreationDialog") and made.size() == 1
		and int(made[0].get("type", 0)) == kind and int(made[0].get("breed", 0)) == 9,
		"%s type %s" % [fname, made[0].get("type") if not made.is_empty() else "—"])


func _tournaments() -> void:
	_close_all()
	var b: Button = _main._lobby_screen.find_child("Menu_calendarDialog", true, false)
	b.pressed.emit()
	await _wait(func(): return _main._gui.is_open("calendarDialog"), 3.0)
	await create_timer(1.0).timeout
	var p = _main._gui.dialogs.get("calendarDialog")
	var tabs: Array = p.body.get_child(0).get_children().filter(func(c): return c is Button)
	_record(28600, "Torneos tabs", p.title.text == root.get_node("I18n").t("panel.tournaments") and tabs.size() == 3,
		"'%s': %s" % [p.title.text, tabs.map(func(t): return t.text)])
	await _shot("torneos")
	_seen.clear()
	tabs[2].pressed.emit()
	await create_timer(1.2).timeout
	_record(28600, "Torneos ranking", p.find_child("Board", true, false) != null and _seen.size() > 0,
		"board shown, replies %s" % [_seen.keys()])
	await _shot("torneos-ranking")
	tabs = p.body.get_child(0).get_children().filter(func(c): return c is Button)
	tabs[0].pressed.emit()
	await create_timer(0.6).timeout
	_record(28600, "Mis torneos", p.find_child("NoTournaments", true, false) != null
		or p.find_child("TeamPick", true, false) != null or p.find_child("NoTeam", true, false) != null,
		"list or the empty line")
	await _shot("torneos-mine")
	_close_all()
	_main._gui.open("teamManagementDialog")
	await create_timer(0.6).timeout
	var team = _main._gui.dialogs.get("teamManagementDialog")
	var ttabs: Array = team.body.get_child(0).get_children().filter(func(c): return c is Button)
	_record(0, "Equipo tabs", not ttabs.any(func(t): return t.text == root.get_node("I18n").t("team.tab_tournaments")),
		"%s" % [ttabs.map(func(t): return t.text)])
	_close_all()
	_main._gui.open("ladderInformationDialog")
	await create_timer(0.6).timeout
	var lad = _main._gui.dialogs.get("ladderInformationDialog")
	var ltabs: Array = []
	for c in lad.body.get_children():
		if c is HBoxContainer and c.get_child_count() > 3:
			ltabs = c.get_children().filter(func(x): return x is Button)
			break
	_record(0, "Clasificación tabs", ltabs.size() == 6
		and not ltabs.any(func(t): return t.text == root.get_node("I18n").t("ladder.tab_tourn")),
		"%s" % [ltabs.map(func(t): return t.text)])
	_close_all()


func _stats_tab() -> void:
	_close_all()
	var b: Button = _main._lobby_screen.find_child("Menu_achievementDialog", true, false)
	b.pressed.emit()
	await _wait(func(): return _main._gui.is_open("achievementDialog"), 3.0)
	await create_timer(0.8).timeout
	var p = _main._gui.dialogs.get("achievementDialog")
	var tabs: Array = p.body.get_child(0).get_children().filter(func(c): return c is Button)
	tabs[1].pressed.emit()
	await create_timer(0.6).timeout
	var tree: Tree = p.find_child("*", true, false) as Tree
	for c in p.find_children("*", "Tree", true, false):
		tree = c
	var rows := tree.get_root().get_child_count() if tree != null else 0
	_record(0, "Logros → Estadísticas", tabs.size() == 2 and rows >= 8, "%d rows" % rows)
	await _shot("logros-stats")
	_close_all()


func _icons() -> void:
	_close_all()
	var cases := [["Menu_socialDialog", "socialDialog"], ["Menu_mailboxDialog", "mailboxDialog"],
		["Menu_menuDialog", "menuDialog"]]
	for c in cases:
		var b: Button = _main._lobby_screen.find_child(c[0], true, false)
		if b == null:
			_record(0, c[0], false, "no button")
			continue
		_seen.clear()
		b.pressed.emit()
		var ok: bool = await _wait(func(): return _main._gui.is_open(c[1]), 3.0)
		if c[1] == "mailboxDialog":
			ok = ok and await _wait(func(): return _seen.has(15001), 3.0)
		_record(0, "icon " + c[0], ok, "opens %s" % c[1])
		_close_all()
		await create_timer(0.3).timeout
	var stats: Button = _main._lobby_screen.find_child("Menu_coachStatisticsDialog", true, false)
	_record(0, "no stats icon", stats == null, "the bars icon is gone")
	var city = await _open_city()
	var groups: Array = _main._gui.model.get_value("city").get("groups", [])
	_record(0, "no Buzón in Servicios", not groups.any(func(g): return int(g.kind) == 2),
		"%s" % [groups.map(func(g): return g.name)])
	_close_all()
