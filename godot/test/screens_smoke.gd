extends "res://test/world_smoke.gd"

## S18: the two screens only the hidden debug row used to reach, live.
##
##   godot --path godot -s test/screens_smoke.gd [-- --shot-dir=D]
##
## 1. Coach equipment (Inventario → "Equipo del coach"): the client knows at
##    login what the coach wears (B-179: 5200's first section), shows it in
##    its slot, swaps the hat for another and wears it (5201 → 5200 says the
##    new hat is on), then puts the first hat back.
## 2. Kanodo (Equipo → Evolución → a fighter → "Esferas"): the board opens on
##    the fighter's spheres; picking a lit sphere enables "Comprar", which
##    sends 23009 and moves the fighter's cursor onto it.
## 3. Matchmaking: "Aleatorio" shows the search card (mode, a running clock,
##    a full-size Cancelar), which cancels the search (2303 → 2306); Esc too.
## Leaves the hat as it found it; the sphere purchase is undone in the db by
## the caller (see sprints/S18 for the snippet).

const HAT_A := 55     # Sgrim Hat, worn by `test` (slot 0)
const HAT_B := 131    # Weerdtrot Hat, in the inventory
const EVO_FIGHTER := 1

var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	await _wait(func(): return _seen.has(5200), 4.0)
	await create_timer(0.5).timeout
	await _equipment()
	await _kanodo()
	await _search_cancel()
	await _ranking()
	i18n.set_locale(_lang_before)


## The ranking as sketched: button tabs, your row marked, "Mi puesto".
func _ranking() -> void:
	var lp = await _menu("nav.ladder", "ladderInformationDialog")
	await create_timer(1.0).timeout   # the 7 boards arrive
	var board: Tree = lp.find_child("Board", true, false) if lp != null else null
	var marked := ""
	var rows := 0
	if board != null:
		for it in board.get_root().get_children():
			rows += 1
			if it.get_text(0).begins_with("▶"):
				marked = it.get_text(1)
	var tab_buttons: int = lp.find_children("*", "Button", true, false).filter(func(b): return b.toggle_mode).size() if lp != null else 0
	_record(27500, "ranking", board != null and tab_buttons == 7 and marked == State.my_coach_name,
		"%d tab buttons, %d rows, your row marked: '%s'" % [tab_buttons, rows, marked])
	await _shot("ranking")


## Matchmaking state on the lobby (S18): before, only the hidden debug row
## could cancel a search.
func _search_cancel() -> void:
	_close_all()
	var lobby = _main._lobby_screen
	_seen.clear()
	lobby.action_requested.emit("quick")
	await _wait(func(): return _seen.has(2304), 3.0)
	await create_timer(1.6).timeout
	var btn: Button = lobby.find_child("CancelSearch", true, false)
	var clock: Label = lobby.find_child("SearchClock", true, false)
	var shown: bool = btn != null and btn.is_visible_in_tree() and btn.size.x >= 200 \
		and lobby._subtitle.text == "Buscando rival…"
	var ticking: bool = clock != null and clock.is_visible_in_tree() and clock.text != "0:00"
	var hidden: bool = lobby._actions.all(func(b): return not b.is_visible_in_tree())
	await _shot("lobby-searching")
	_record(2304, "search card", shown and ticking and hidden,
		"card with a %s Cancelar, clock '%s', actions hidden=%s" % [
			("%dpx" % int(btn.size.x)) if btn != null else "no", clock.text if clock != null else "—", str(hidden)])
	_seen.clear()
	if btn != null:
		btn.pressed.emit()
	await _wait(func(): return _seen.has(2306), 3.0)
	await create_timer(0.4).timeout
	_record(2303, "search", shown and _seen.has(2306) and not btn.is_visible_in_tree(),
		"Aleatorio → 2304 → 'Buscando rival…' + Cancelar → 2303 → 2306, back to normal")
	# Esc cancels too (S20), when no window is open
	_seen.clear()
	lobby.action_requested.emit("quick")
	await _wait(func(): return _seen.has(2304), 3.0)
	await create_timer(0.4).timeout
	_seen.clear()
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = KEY_ESCAPE
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await process_frame
	await _wait(func(): return _seen.has(2306), 3.0)
	await create_timer(0.4).timeout
	_record(2303, "esc", _seen.has(2306) and not lobby._searching,
		"Esc during a search → 2303 → 2306")


func _menu(key: String, dialog: String):
	_close_all()
	for b in _main._lobby_screen._menu_buttons:
		if b.text == root.get_node("I18n").t(key):
			b.pressed.emit()
	await _wait(func(): return _main._gui.is_open(dialog), 3.0)
	await create_timer(0.4).timeout
	return _main._gui.dialogs.get(dialog)


func _equipment() -> void:
	_record(5200, "worn at login", int(_main._equip_slots[0]) == HAT_A,
		"5200 section 1 → slot 0 holds card %d (want %d)" % [int(_main._equip_slots[0]), HAT_A])
	var inv = await _menu("nav.inventory", "cardBookDialog")
	# the inventory shows the cards as art tiles (S18 "contenido de paneles")
	var grid = inv.find_child("CardGrid", true, false) if inv != null else null
	var tiles: Array = grid.get_children().filter(func(c): return c is Button) if grid != null else []
	var picked_name := ""
	if not tiles.is_empty():
		tiles[0].pressed.emit()
		await create_timer(0.4).timeout
		var nm = inv.find_child("CardName", true, false)
		picked_name = nm.text if nm != null else ""
	_record(5200, "inventory", tiles.size() == State.inventory.size() and picked_name != "",
		"%d card tiles (inventory has %d), picked '%s'" % [tiles.size(), State.inventory.size(), picked_name])
	await _shot("inventory-cards")
	var open_btn: Button = inv.find_child("CoachEquip", true, false) if inv != null else null
	if open_btn == null:
		_record(5200, "panel", false, "no Equipo del coach button in Inventario")
		return
	open_btn.pressed.emit()
	await _wait(func(): return _main._gui.is_open("coachEquipDialog"), 3.0)
	await create_timer(0.5).timeout
	var p = _main._gui.dialogs.get("coachEquipDialog")
	var slot0: Button = p.find_child("Slot0", true, false) if p != null else null
	var hat_name: String = load("res://src/gamedata/cards.gd").name_of(HAT_A)
	_record(5200, "panel", slot0 != null and slot0.text == hat_name,
		"native panel, the hat slot shows '%s'" % (slot0.text if slot0 != null else "—"))
	await _shot("coach-equip")
	if slot0 == null:
		return
	if not await _wear(p, HAT_B):
		return
	_record(5200, "swap", int(_main._equip_slots[0]) == HAT_B,
		"Poner Weerdtrot Hat + Llevar puesto → 5201 → 5200: slot 0 = %d" % int(_main._equip_slots[0]))
	await _wear(p, HAT_A)
	_record(5200, "restore", int(_main._equip_slots[0]) == HAT_A, "the Sgrim Hat is back on")
	_close_all()


func _wear(p, cid: int) -> bool:
	# Pick the card in the "Owned" table the way a click does (item_selected),
	# not by writing the draft: S20 found "Poner" never woke up on a real click
	# because only this smoke refreshed the panel.
	var owned: Tree = p.find_child("Owned", true, false)
	var row: TreeItem = null
	if owned != null:
		for it in owned.get_root().get_children():
			var m: Variant = it.get_metadata(0)
			if m is Dictionary and int(m.get("id", -1)) == cid:
				row = it
	if row == null:
		_record(5200, "put", false, "card %d not in the Owned table" % cid)
		return false
	row.select(0)   # emits item_selected, like a click
	await create_timer(0.3).timeout
	var put: Button = p.find_child("Put", true, false)
	if put == null or put.disabled:
		_record(5200, "put", false, "card %d not offered" % cid)
		return false
	put.pressed.emit()
	await create_timer(0.3).timeout
	_seen.erase(5200)
	p.find_child("Wear", true, false).pressed.emit()
	await _wait(func(): return _seen.has(5200), 3.0)
	await create_timer(0.4).timeout
	return true


func _kanodo() -> void:
	var team = await _menu("nav.team", "teamManagementDialog")
	if team == null:
		_record(23009, "team", false, "Team did not open")
		return
	var item := {}
	for t in team.find_children("*", "Tree", true, false):
		for it in t.get_root().get_children():
			var m: Variant = it.get_metadata(0)
			if m is Dictionary and int(m.get("id", -1)) == EVO_FIGHTER:
				item = m
	team.selected = item
	team.schedule_refresh()
	await create_timer(0.4).timeout
	var sph: Button = team.find_child("Spheres", true, false)
	if sph == null:
		_record(23009, "kanodo", false, "no Esferas button for fighter %d" % EVO_FIGHTER)
		return
	sph.pressed.emit()
	await _wait(func(): return _main._gui.is_open("kanodoDialog"), 3.0)
	await create_timer(0.8).timeout
	var k = _main._gui.dialogs.get("kanodoDialog")
	var board = k.find_child("Board", true, false) if k != null else null
	var model: Dictionary = _main._gui.gui.model.get_value("kanodo")
	_record(23009, "kanodo", board != null and int(model.get("board", 0)) > 0 and board._lit.size() > 0,
		"native panel, board %d, %d sphere(s) owned, %d within reach" % [int(model.get("board", 0)),
			model.get("owned", []).size(), board._lit.size() if board != null else 0])
	await _shot("kanodo")
	if board == null:
		return
	var Kanodo = load("res://src/gamedata/kanodo.gd")
	var pick := {}
	for id in board._lit:
		var n: Dictionary = Kanodo.nodes.get(int(id), {})
		if Kanodo.has_payload(n) and String(n.get("kind", "")) != "barrier" \
				and int(n.get("xp", 0)) <= int(model.xp):
			pick = n
			break
	if pick.is_empty():
		_record(23009, "buy", false, "no affordable lit sphere")
		return
	board.sphere_clicked.emit(pick)
	await create_timer(0.4).timeout
	var buy: Button = k.find_child("Buy", true, false)
	var info: Label = k.find_child("Info", true, false)
	var enabled := buy != null and not buy.disabled
	buy.pressed.emit()
	await create_timer(0.6).timeout
	var after: Dictionary = _main._gui.gui.model.get_value("kanodo")
	var cur: Array = after.get("cursor", [0, 0])
	_record(23009, "buy", enabled and int(cur[0]) == int(pick.x) and int(cur[1]) == int(pick.y)
		and int(pick.id) in after.get("owned", []),
		"sphere %d '%s' → Comprar → 23009; cursor now (%d, %d), %s" % [int(pick.id),
			info.text.split("\n")[0] if info != null else "", int(cur[0]), int(cur[1]), after.get("status", "")])
	await _shot("kanodo-bought")
	print("[audit] KANODO_BOUGHT %d" % int(pick.id))
