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
	i18n.set_locale(_lang_before)


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
	var open_btn: Button = inv.find_child("CoachEquip", true, false) if inv != null else null
	if open_btn == null:
		_record(5200, "panel", false, "no Equipo del coach button in Inventario")
		return
	open_btn.pressed.emit()
	await _wait(func(): return _main._gui.is_open("coachEquipDialog"), 3.0)
	await create_timer(0.5).timeout
	var p = _main._gui.dialogs.get("coachEquipDialog")
	var slot0: Button = p.find_child("Slot0", true, false) if p != null else null
	_record(5200, "panel", slot0 != null and slot0.text == "Sgrim Hat",
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
	p.draft["put"] = cid
	p.schedule_refresh()
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
