extends SceneTree
## S47 (owner, point 3): the screen map. Plays the client as a player would,
## against a live server, and saves one capture per screen it reaches, with
## how it got there, so the flow can be laid out before reorganising it.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##       -s test/screen_map.gd -- --as=LOGIN --out=DIR [--fight]
##
## A login nobody has used goes through the coach creation and the intro
## (auto-register); an existing one lands in the lobby. Then: every lobby
## menu (and each tab of the panel it opens), each mode tile's two buttons,
## Equipo's "Crear luchador" per tab, every City group and the screens its
## services open, the coach equipment, and the panels the lobby has no
## button for (opened directly, marked so). --fight ends with a practice
## fight (needs fighters).
##
## Writes DIR/NN-name.png and DIR/index.tsv (file, screen, how it was
## reached). Needs a real renderer (xvfb), not --headless.

var _main
var _i18n
var _out := ""
var _login := ""
var _n := 0
var _rows: Array = []
var _shot_dialogs := {}   # dialog name -> true once captured


func _initialize() -> void:
	_run.call_deferred()


func _wait(cond: Callable, secs: float) -> bool:
	var t := 0.0
	while not cond.call() and t < secs:
		await create_timer(0.1).timeout
		t += 0.1
	return cond.call()


func _pause(secs: float) -> void:
	await create_timer(secs).timeout


func _shot(name: String, screen: String, how: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		return
	_n += 1
	var file := "%02d-%s.png" % [_n, name]
	img.save_png(_out.path_join(file))
	_rows.append([file, screen, how])
	print("[map] ", file, " — ", screen)


func _close_all() -> void:
	for n in _main._gui.dialogs.keys():
		_main._gui.close(n)
	await _pause(0.4)


func _panel_title(p) -> String:
	if p != null and "title" in p and p.title != null:
		return str(p.title.text)
	return ""


## The toggle buttons of a LobbyPanel's tab row (tabs() puts it first).
func _tab_buttons(p) -> Array:
	if p == null or not ("body" in p) or p.body == null or p.body.get_child_count() == 0:
		return []
	var first = p.body.get_child(0)
	if not first is HBoxContainer:
		return []
	return first.get_children().filter(func(c): return c is Button and c.toggle_mode)


## Capture a panel, then each of its other tabs.
func _shoot_panel(dname: String, how: String) -> void:
	var p = _main._gui.dialogs.get(dname)
	if p == null:
		return
	await _pause(0.9)
	_shot_dialogs[dname] = true
	var tabs := _tab_buttons(p)
	var label := _panel_title(p)
	if tabs.size() > 1:
		label += " · " + str(tabs[0].text)
	await _shot(dname, label if label != "" else dname, how)
	for i in range(1, tabs.size()):
		tabs = _tab_buttons(p)
		if i >= tabs.size():
			break
		var tab_text: String = tabs[i].text   # the press rebuilds the row
		tabs[i].pressed.emit()
		await _pause(0.8)
		await _shot("%s-tab%d" % [dname, i], "%s · %s" % [_panel_title(p), tab_text],
			how + " → pestaña " + tab_text)


func _button_with_text(node: Node, text: String) -> Button:
	for c in node.find_children("*", "Button", true, false):
		if c.text == text and c.is_visible_in_tree():
			return c
	return null


func _run() -> void:
	var fight := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--as="):
			_login = a.trim_prefix("--as=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a == "--fight":
			fight = true
	if _login == "" or _out == "":
		push_error("[map] --as=LOGIN --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_i18n = root.get_node("I18n")
	_i18n.set_locale("es")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	current_scene = _main
	await _wait(func(): return _main._login_screen != null, 10.0)
	await _pause(1.5)
	await _shot("login", "Login", "arranque del juego")
	_main._login_screen.submit.emit(_login, "test123", "127.0.0.1:5555")
	await _wait(func(): return _main._lobby_ready or _main._create_screen != null, 20.0)
	await _creation()
	if not await _wait(func(): return _main._lobby_ready, 20.0):
		push_error("[map] never reached the lobby")
		_write_index()
		quit(1)
		return
	await _pause(2.0)
	await _intro()
	await _close_all()
	await _pause(1.0)
	await _shot("lobby", "Lobby", "tras entrar")
	await _menus()
	await _tiles()
	await _team_create()
	await _city()
	await _unreachable()
	if fight:
		await _fight()
	_write_index()
	quit(0)


func _creation() -> void:
	var cs = _main._create_screen
	if cs == null or _main._lobby_ready:
		return
	await _pause(1.5)
	await _shot("creation-body", "Crear jefe · Cuerpo", "login con una cuenta nueva")
	for sec in ["hair", "skin"]:
		if cs._tabs.has(sec):
			cs._tabs[sec].pressed.emit()
			await _pause(0.6)
			await _shot("creation-" + sec, "Crear jefe · " + str(cs._tabs[sec].text),
				"crear jefe → pestaña")
	var name := "Mapa" + str(Time.get_ticks_msec() % 100000)
	cs.name_edit.text = name
	cs.name_edit.text_changed.emit(name)
	cs.submit.emit()


## The intro a new coach meets: its first and last page, and how many.
func _intro() -> void:
	if not await _wait(func(): return _main._gui.is_open("npcTalkDialog"), 3.0):
		return
	await _pause(1.0)
	await _shot("intro-first", "Intro (primera página)", "primera entrada al lobby")
	var pages := 1
	while _main._gui.is_open("npcTalkDialog") and pages < 40:
		var before = _main._gui.model.get_value("talk")
		_main._talk_choice(0)
		await _pause(0.25)
		if not _main._gui.is_open("npcTalkDialog"):
			break
		pages += 1
		if before == _main._gui.model.get_value("talk"):
			await _pause(0.3)
	print("[map] intro pages: ", pages)
	_rows.append(["", "Intro: %d páginas antes del lobby" % pages, "dato"])


## Every lobby menu button, as the player presses it.
func _menus() -> void:
	var lobby = _main._lobby_screen
	for b in lobby._menu_buttons:
		await _close_all()
		var label: String = b.tooltip_text if b.text == "" else b.text
		var before: Array = _main._gui.dialogs.keys()
		b.pressed.emit()
		await _pause(0.5)
		for d in _main._gui.dialogs.keys():
			if not d in before:
				await _shoot_panel(d, "lobby → botón «%s»" % label)
		if d_inventory(label):
			await _coach_equip()


func d_inventory(label: String) -> bool:
	return label == _i18n.t("nav.inventory")


func _coach_equip() -> void:
	var p = _main._gui.dialogs.get("cardBookDialog")
	if p == null:
		return
	var eq = p.find_child("CoachEquip", true, false)
	if eq == null:
		return
	eq.pressed.emit()
	await _pause(0.6)
	if _main._gui.is_open("coachEquipDialog"):
		await _pause(1.5)
		_shot_dialogs["coachEquipDialog"] = true
		await _shot("coachEquipDialog", "Equipo del coach", "Inventario → «Equipo del coach»")


## The three mode tiles: the big button and the small one, each.
func _tiles() -> void:
	var lobby = _main._lobby_screen
	for id in ["story", "ranked", "tourn"]:
		for extra in [false, true]:
			await _close_all()
			var c: Dictionary = lobby._cards.get(id, {})
			var btn: Button = c.get("extra" if extra else "play")
			if btn == null or not btn.is_visible_in_tree():
				continue
			var how := "lobby → loseta %s → «%s»" % [id, btn.text]
			if id == "story" and extra and not _main.State.roster.is_empty():
				# practice with fighters starts a fight (the scene changes):
				# that is the last step (--fight), not here
				_rows.append(["", "Loseta story → «%s»: lanza el combate de entrenamiento" % btn.text, how])
				continue
			var before: Array = _main._gui.dialogs.keys()
			lobby._card_pressed(id, extra)
			await _pause(1.2)
			var opened := false
			for d in _main._gui.dialogs.keys():
				if not d in before:
					opened = true
					await _shoot_panel(d, how)
			if not opened:
				await _shot("tile-%s%s" % [id, "-extra" if extra else ""],
					"Loseta %s → «%s» (sin ventana)" % [id, btn.text], how)
			if lobby._searching:
				lobby.action_requested.emit("cancel_search")
				await _pause(0.8)
			if _main.get_tree().current_scene != _main:
				return


## Equipo → "Crear luchador" on each tab.
func _team_create() -> void:
	await _close_all()
	_main._gui.open("teamManagementDialog")
	await _pause(0.8)
	var p = _main._gui.dialogs.get("teamManagementDialog")
	if p == null:
		return
	var n := _tab_buttons(p).size()
	for i in n:
		var tabs := _tab_buttons(p)
		if i >= tabs.size():
			break
		var tab_name: String = tabs[i].text
		tabs[i].pressed.emit()
		await _pause(0.6)
		var create := _button_with_text(p, _i18n.t("team.create_fighter"))
		if create == null:
			continue
		create.pressed.emit()
		await _pause(1.5)
		for d in _main._gui.dialogs.keys():
			if d != "teamManagementDialog":
				await _pause(1.0)
				await _shot("create-fighter-tab%d" % i, "Crear luchador (desde %s)" % tab_name,
					"Equipo → pestaña %s → «Crear luchador»" % tab_name)
				_shot_dialogs[d] = true
				_main._gui.close(d)
				await _pause(0.4)
		p = _main._gui.dialogs.get("teamManagementDialog")
		if p == null:
			_main._gui.open("teamManagementDialog")
			await _pause(0.8)
			p = _main._gui.dialogs.get("teamManagementDialog")


## Servicios: each group, and the first screen of each kind its services open.
func _city() -> void:
	await _close_all()
	_main._gui.open("cityDialog")
	await _pause(1.0)
	var groups: Array = _main._gui.model.get_value("city").get("groups", []) \
		if _main._gui.model.get_value("city") is Dictionary else []
	for gi in groups.size():
		var p = _main._gui.dialogs.get("cityDialog")
		if p == null:
			_main._gui.open("cityDialog")
			await _pause(0.8)
			p = _main._gui.dialogs.get("cityDialog")
		p.draft["group"] = gi
		p.schedule_refresh()
		await _pause(0.6)
		await _shot("city-group%d" % gi, "Servicios · %s" % str(groups[gi].get("name", "")),
			"lobby → Servicios → grupo")
		for s in groups[gi].get("services", []):
			await _close_all()
			_main._gui.open("cityDialog")
			await _pause(0.5)
			p = _main._gui.dialogs.get("cityDialog")
			p.draft["group"] = gi
			p.schedule_refresh()
			await _pause(0.4)
			var b = p.find_child("Service%d" % int(s.id), true, false)
			if b == null:
				continue
			b.pressed.emit()
			await _pause(1.5)
			for d in _main._gui.dialogs.keys():
				if d == "cityDialog" or _shot_dialogs.has(d):
					continue
				await _pause(0.8)
				_shot_dialogs[d] = true
				await _shot(d, "%s (%s)" % [_panel_title(_main._gui.dialogs[d]), d],
					"Servicios → %s → «%s»" % [str(groups[gi].get("name", "")), str(s.get("label", ""))])
	await _close_all()


## Panels the lobby shows no button for: opened directly, said so.
func _unreachable() -> void:
	for d in ["menuDialog", "optionsDialog", "replayDialog", "ghostDialog", "storyDialog",
			"ladderInformationDialog", "calendarDialog", "tooltipDialog"]:
		if _shot_dialogs.has(d):
			continue
		await _close_all()
		_main._gui.open(d)
		var how := "SIN BOTÓN en el lobby (abierto a mano)"
		if d in ["optionsDialog", "replayDialog"] and _shot_dialogs.has("menuDialog"):
			how = "lobby → icono Menú → «%s»" % _i18n.t("menu.options" if d == "optionsDialog" else "menu.replays")
		await _shoot_panel(d, how)
	await _close_all()


func _fight() -> void:
	_main._on_practice_pressed()
	if not await _wait(func(): return current_scene != _main, 20.0):
		_rows.append(["", "Entrenamiento: no arrancó (¿sin luchadores?)", "dato"])
		return
	await _pause(6.0)
	await _shot("fight", "Combate de entrenamiento", "lobby → loseta Historia → «Entrenamiento»")
	await _pause(8.0)
	await _shot("fight-later", "Combate (más tarde)", "")


func _write_index() -> void:
	var f := FileAccess.open(_out.path_join("index.tsv"), FileAccess.WRITE)
	for r in _rows:
		f.store_line("\t".join(r))
	f.close()
