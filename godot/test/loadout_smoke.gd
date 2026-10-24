extends "res://test/world_smoke.gd"

## S20: "Guardar cambios" in Equipo del luchador says what happened, live.
##
##   godot --path godot -s test/loadout_smoke.gd [-- --shot-dir=D]
##
## Opens Equipo → the first fighter → "Hechizos y equipo". With no change,
## "Guardar cambios" is disabled. Removes the first equipped spell (by picking
## its row and pressing the button, like a player), saves, and checks that the
## button reads "✓ Guardado", a toast appeared, and the roster still holds the
## fighter's cards (6010's card section is read). Then puts the spell back and
## saves again, so the fighter is left as found.


func _audit() -> void:
	var i18n = root.get_node("I18n")
	i18n.set_locale("es")
	var team = await _menu("nav.team", "teamManagementDialog")
	if team == null or State.roster.is_empty():
		_record(6011, "team", false, "Team did not open or the roster is empty")
		return
	var f: Dictionary = {}
	# prefer a fighter that also wears cards, so the roster check means something
	for it in State.roster:
		if not it.get("spells", []).is_empty() and (f.is_empty() or not it.get("cards", []).is_empty()):
			f = it
			if not it.get("cards", []).is_empty():
				break
	if f.is_empty():
		_record(6011, "fighter", false, "no fighter with spells")
		return
	var cards_before: int = f.get("cards", []).size()
	team.send("editFighter", [f], f)
	await _wait(func(): return _main._gui.is_open("fighterEquipmentDialog"), 3.0)
	await create_timer(0.4).timeout
	var p = _main._gui.dialogs.get("fighterEquipmentDialog")
	var save: Button = p.find_child("Save", true, false) if p != null else null
	_record(6011, "clean", save != null and save.disabled,
		"no change → Guardar disabled (%s)" % (str(save.disabled) if save != null else "no button"))
	var sid := int(f.spells[0])
	if not await _toggle_spell(p, sid, "fe.remove_spell"):
		return
	save = p.find_child("Save", true, false)
	_record(6011, "dirty", save != null and not save.disabled and save.text == i18n.t("fe.save"),
		"after removing spell %d → '%s', enabled=%s" % [sid, save.text, str(not save.disabled)])
	var toasts_before: int = _main.get_node("Toasts/ToastBox").get_child_count()
	_seen.erase(6010)
	save.pressed.emit()
	await _wait(func(): return _seen.has(6010), 3.0)
	await create_timer(0.4).timeout
	await _shot("loadout-saved")
	save = p.find_child("Save", true, false)
	_record(6010, "saved", save != null and save.disabled and save.text == i18n.t("fe.saved"),
		"button reads '%s'" % (save.text if save != null else "—"))
	_record(6010, "toast", _main.get_node("Toasts/ToastBox").get_child_count() > toasts_before,
		"a toast says it")
	var mine: Dictionary = {}
	for it in State.roster:
		if int(it.id) == int(f.id):
			mine = it
	_record(6010, "roster", not mine.get("spells", []).has(sid) and mine.get("cards", []).size() == cards_before,
		"roster: spell %d gone, %d cards kept (had %d)" % [sid, mine.get("cards", []).size(), cards_before])
	# put it back
	if await _toggle_spell(p, sid, "fe.equip_spell"):
		_seen.erase(6010)
		p.find_child("Save", true, false).pressed.emit()
		await _wait(func(): return _seen.has(6010), 3.0)
		await create_timer(0.3).timeout
	var back := false
	for it in State.roster:
		if int(it.id) == int(f.id):
			back = it.get("spells", []).has(sid)
	_record(6010, "restore", back, "spell %d is back" % sid)
	# the equipment tab: the five slots and the cards for the picked one
	for b in p.find_children("*", "Button", true, false):
		if b.toggle_mode and b.text == i18n.t("fe.equip"):
			b.pressed.emit()
	await create_timer(0.5).timeout
	var slots = p.find_child("Slots", true, false)
	var pool = p.find_child("Pool", true, false)
	_record(6011, "equipment", slots != null and slots.get_child_count() == 5 and pool != null and pool.get_child_count() > 0,
		"5 slots, %d cards offered" % (pool.get_child_count() if pool != null else 0))
	await _shot("loadout-equipment")
	_close_all()


func _toggle_spell(p, sid: int, _button_key: String) -> bool:
	# S22: spells are tiles; a click equips or takes one off
	var b: Button = p.find_child("Spell%d" % sid, true, false)
	if b == null or b.disabled:
		_record(6011, "spell tile", false, "spell %d has no usable tile" % sid)
		return false
	b.pressed.emit()
	await create_timer(0.3).timeout
	return true


func _menu(key: String, dialog: String):
	_close_all()
	for b in _main._lobby_screen._menu_buttons:
		if b.text == root.get_node("I18n").t(key):
			b.pressed.emit()
	await _wait(func(): return _main._gui.is_open(dialog), 3.0)
	await create_timer(0.4).timeout
	return _main._gui.dialogs.get(dialog)
