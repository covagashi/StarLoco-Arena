extends "res://test/world_smoke.gd"

## S13: async PvP ghosts through the real main scene, in Spanish.
##
##   godot --path godot -s test/ghost_smoke.gd -- --as=test  [--shot-dir=D]
##   godot --path godot -s test/ghost_smoke.gd -- --as=test2 [--shot-dir=D]
##
## Run as `test` first: Menú → Fantasmas → Crear; two rules for the first
## titular fighter that knows a spell, built with the editor's own controls (cast a spell at the
## weakest enemy when an enemy is under 50 %, else move closer); Guardar
## fantasma → 60010 → "Fantasma guardado" and the ghost under "Mis
## fantasmas". Old smoke ghosts are deleted first (60015), so the cap of three
## never bites. The ghost id goes to user://ghost_smoke_id.txt.
## Seed (server stopped): `test`'s titulars are smoke "Humo" Iops with no
## spells, so fighter 2 gets fighter 1's three Iop spells (fighter_spells
## 2/0..2 = 4, 5, 6) — without a spell the editor offers no "cast".
## Then as `test2`: Retar lists that ghost; Combatir → 60014 → the fight view
## on the ghost; test2 passes its turns, the AI plays the ghost (its casts are
## counted); the fight ends (8300) and the result screen comes up.
## S14: back in the lobby, Clasificación ranks test2 (60016 → 60017), and
## Retar shows the twelve arena (filler) ghosts and "Rival automático".

const ID_FILE := "user://ghost_smoke_id.txt"
const GHOST_NAME := "Fantasma smoke"

var _ghost_casts := 0
var _t = null


func _audit() -> void:
	var i18n = root.get_node("I18n")
	var lang: String = i18n.lang
	i18n.set_locale("es")
	_t = i18n
	current_scene = _main
	if _as == "test2":
		await _challenge()
	else:
		await _create()
	i18n.set_locale(lang)


func _panel(tab_key: String) -> Node:
	_main._gui.close("ghostDialog")
	var menu = _main._gui.open("menuDialog")
	await create_timer(0.3).timeout
	var entry := _find_button(menu, _t.t("menu.ghosts"))
	if entry == null:
		return null
	entry.pressed.emit()
	await _wait(func(): return _main._gui.is_open("ghostDialog"), 3.0)
	await create_timer(0.6).timeout   # the 60013 list lands
	var p = _main._gui.dialogs.get("ghostDialog")
	var tb := _find_button(p, _t.t(tab_key))
	if tb != null:
		tb.pressed.emit()
	await create_timer(0.3).timeout
	return _main._gui.dialogs.get("ghostDialog")


func _create() -> void:
	# clean up earlier runs
	_main._on_native_lobby_action("nativeGhostList", [], null, -1)
	await create_timer(0.6).timeout
	for g in _main._gui.gui.model.get_value("ghosts.list") if _main._gui.gui.model.get_value("ghosts.list") != null else []:
		if g.mine and str(g.name) == GHOST_NAME:
			_main._on_native_lobby_action("nativeGhostDelete", [int(g.id)], null, -1)
			await create_timer(0.4).timeout
	var p = await _panel("ghost.tab_new")
	_record(0, "panel", p != null and _main._gui.is_open("ghostDialog"), "Menú → Fantasmas → Crear")
	if p == null:
		return
	var name_edit: LineEdit = p.find_child("GhostName", true, false)
	name_edit.text = GHOST_NAME
	name_edit.text_changed.emit(GHOST_NAME)
	# the first titular fighter that knows a spell (cast needs one)
	var eds: Array = p.find_children("Rules*", "VBoxContainer", true, false)
	var ed: Node = null
	for c in eds:
		if not c.spells.is_empty():
			ed = c
			break
	_record(0, "editor", ed != null and eds.size() == p._ghost_lineup().size(),
		"%d rule editors, one per titular fighter; one with %d spells" % [eds.size(),
			ed.spells.size() if ed else 0])
	if ed == null:
		return
	# rule 1: if an enemy is under 50 % → cast (first spell) at the weakest enemy
	ed.find_child("AddRule", true, false).pressed.emit()
	await process_frame
	var r0: Node = ed.find_child("Rule0", true, false)
	_choose(r0.find_child("Cond", true, false), 2)          # enemy_hp_pct_below
	await process_frame
	r0 = ed.find_child("Rule0", true, false)
	var v: SpinBox = r0.find_child("Value", true, false)
	v.value = 50
	_choose(r0.find_child("Act", true, false), 0)            # cast
	await process_frame
	r0 = ed.find_child("Rule0", true, false)
	_choose(r0.find_child("Target", true, false), 1)         # weakest_enemy
	# rule 2: always → move closer
	ed.find_child("AddRule", true, false).pressed.emit()
	await process_frame
	var r1: Node = ed.find_child("Rule1", true, false)
	_choose(r1.find_child("Act", true, false), 2)            # move_toward
	await process_frame
	var rules: Array = ed.rules
	var want := [{"if": {"kind": "enemy_hp_pct_below", "value": 50},
		"do": {"kind": "cast", "spell": int(ed.spells[0]), "target": "weakest_enemy"}},
		{"if": {"kind": "always"}, "do": {"kind": "move_toward"}}]
	_record(0, "rules", JSON.stringify(rules) == JSON.stringify(want), JSON.stringify(rules))
	var caps: Array = p.find_children("*", "Label", true, false).filter(func(l): return "2 REGLAS" in l.text)
	_record(0, "caption", caps.size() == 1, "the fighter's caption counts its 2 rules")
	await _shot("ghost-editor")
	p.find_child("GhostSave", true, false).pressed.emit()
	var saved: bool = await _wait(func():
		return str(_main._gui.gui.model.get_value("ghosts.status")) == _t.t("ghost.ok.1"), 4.0)
	await create_timer(0.6).timeout
	var gid := -1
	for g in _main._gui.gui.model.get_value("ghosts.list"):
		if g.mine and str(g.name) == GHOST_NAME:
			gid = int(g.id)
	_record(0, "save", saved and gid > 0, "60010 → '%s', id %d" % [
		_main._gui.gui.model.get_value("ghosts.status"), gid])
	p = await _panel("ghost.tab_mine")
	await _shot("ghost-mine")
	var f := FileAccess.open(ID_FILE, FileAccess.WRITE)
	f.store_string(str(gid))
	f.close()


func _challenge() -> void:
	var gid := int(FileAccess.get_file_as_string(ID_FILE))
	_record(0, "id", gid > 0, "ghost %d from the test run" % gid)
	var p = await _panel("ghost.tab_fight")
	if p == null:
		return
	var tree: Tree = p.find_children("*", "Tree", true, false)[0]
	var row: TreeItem = null
	for it in tree.get_root().get_children():
		var m: Variant = it.get_metadata(0)
		if m is Dictionary and int(m.get("id", -1)) == gid:
			row = it
	_record(0, "listed", row != null and row.get_text(1) == "test", "Retar lists ghost %d by test" % gid)
	if row == null:
		return
	row.select(0)
	await create_timer(0.3).timeout
	await _shot("ghost-challenge")
	p = _main._gui.dialogs.get("ghostDialog")
	_sess.client.message_received.connect(_count_casts)
	p.find_child("GhostFight", true, false).pressed.emit()
	var in_fight: bool = await _wait(func(): return current_scene != null \
		and current_scene.scene_file_path.ends_with("fight_view.tscn"), 10.0)
	_record(0, "fight", in_fight, "Combatir → 60014 → the fight view")
	if not in_fight:
		return
	var fv = current_scene
	fv.placement_began.connect(func():
		create_timer(0.8).timeout.connect(func():
			if is_instance_valid(fv):
				fv.confirm_placement()))
	fv.turn_began.connect(func(_fid, ours):
		if ours:
			create_timer(0.4).timeout.connect(func():
				if is_instance_valid(fv):
					fv.request_end_turn()))
	await create_timer(6.0).timeout
	await _shot("ghost-fight")
	var over: bool = await _wait(func(): return is_instance_valid(fv) and fv._result_modal != null, 240.0)
	await create_timer(1.0).timeout
	await _shot("ghost-result")
	_record(0, "ends", over, "the fight against the ghost ends with a result screen")
	_record(0, "ghost plays", _ghost_casts > 0, "%d spells cast by the ghost's fighters" % _ghost_casts)
	if not over:
		return
	# S14: back in the lobby, the ladder ranks test2 and lists the fillers
	fv._close_fight_result()
	await _wait(func(): return current_scene != null \
		and current_scene.scene_file_path.ends_with("main.tscn"), 10.0)
	_main = current_scene
	await create_timer(1.0).timeout
	var lp = await _panel("ghost.tab_ladder")
	await _wait(func(): return lp != null and _main._gui.gui.model.get_value("ghosts.ladder") != null, 3.0)
	await create_timer(0.4).timeout
	var l: Dictionary = _main._gui.gui.model.get_value("ghosts.ladder")
	var me_listed: bool = l.get("rows", []).any(func(r): return r.mine and str(r.name) == "test2")
	_record(0, "ladder", int(l.get("fights", 0)) >= 1 and int(l.get("rank", 0)) >= 1 and me_listed,
		"60017: Elo %s, rank %s, %s fights; test2 listed: %s" % [l.get("elo"), l.get("rank"),
			l.get("fights"), me_listed])
	await _shot("ghost-ladder")
	var fp = await _panel("ghost.tab_fight")
	var fillers: Array = _main._gui.gui.model.get_value("ghosts.list").filter(func(g): return str(g.owner) == "")
	_record(0, "fillers", fillers.size() == 12 and fp.find_child("GhostAuto", true, false) != null,
		"%d arena ghosts to fight, and 'Rival automático'" % fillers.size())
	await _shot("ghost-fillers")


func _count_casts(op: int, raw: PackedByteArray) -> void:
	# 8110: [i32 uid][i32 -1][i64 caster]…; ghost fighters sit at 2^40 + 2^36 + …
	if op == 8110 and raw.size() >= 16:
		var caster := 0
		for i in 8:
			caster = (caster << 8) | raw[8 + i]
		if caster >= (1 << 40) + (1 << 36):
			_ghost_casts += 1


func _choose(o: OptionButton, idx: int) -> void:
	o.select(idx)
	o.item_selected.emit(idx)


func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and node.text == text:
		return node
	for c in node.get_children():
		var f := _find_button(c, text)
		if f != null:
			return f
	return null
