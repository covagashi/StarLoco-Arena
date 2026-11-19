extends "res://test/world_smoke.gd"

## S47 (point 10): "Añadir" in Social answers in the panel itself, live.
##
##   godot --path godot -s test/social_smoke.gd [-- --full]
##
## As the player: open Social, type a name in its field, press "Añadir".
## A name nobody has → "No hay ningún jefe que se llame X" in the panel
## (3204); `test2` → "test2 añadido a amigos"; with the server's
## `rules.max_social_list_entries: 1` (--full) a second friend → "la lista
## está llena" (3216). Removes the friends it added, as the player does
## (select the row, "Eliminar seleccionado"). Needs a server on 5555 and a
## throwaway copy of the database.

var _full := false


func _audit() -> void:
	_full = "--full" in OS.get_cmdline_user_args()
	root.get_node("I18n").set_locale("es")
	_close_all()
	_main._gui.open("socialDialog")
	await _wait(func(): return _main._gui.is_open("socialDialog"), 3.0)
	await create_timer(0.6).timeout
	await _add("nadie%d" % (Time.get_ticks_msec() % 100000), 3204, "No hay ningún jefe")
	await _add("test2", 3156, "test2 añadido")
	if _full:
		await _add("spec", 3216, "llena")
	await _remove("test2")


func _panel():
	return _main._gui.dialogs.get("socialDialog")


func _press(p, text: String) -> bool:
	var b := _button_with_text(p, text)
	if b == null or b.disabled:
		return false
	b.pressed.emit()
	return true


func _button_with_text(node: Node, text: String) -> Button:
	for c in node.find_children("*", "Button", true, false):
		if c.text == text and c.is_visible_in_tree():
			return c
	return null


func _status() -> String:
	var st = _panel().find_child("SocialStatus", true, false)
	return st.text if st != null else ""


func _add(name: String, op: int, expect: String) -> void:
	var p = _panel()
	var edit: LineEdit = null
	for c in p.find_children("*", "LineEdit", true, false):
		if c.is_visible_in_tree():
			edit = c
			break
	edit.text = name
	_seen.clear()
	var pressed := _press(p, root.get_node("I18n").t("social.add"))
	var got: bool = await _wait(func(): return _seen.has(op), 5.0)
	await create_timer(0.4).timeout
	var st := _status()
	_record(op, "Añadir «%s»" % name, pressed and got and expect in st,
		"reply %s, panel says '%s'" % [str(got), st])
	await _shot("social-" + name)


func _remove(name: String) -> void:
	var p = _panel()
	var tree: Tree = p.find_children("*", "Tree", true, false)[0]
	var found := false
	var it := tree.get_root().get_first_child() if tree.get_root() != null else null
	while it != null:
		var item = it.get_metadata(0)
		if item is Dictionary and str(item.get("name", "")) == name:
			it.select(0)   # item_selected → the panel's `selected`, as a click
			found = true
			break
		it = it.get_next()
	await create_timer(0.4).timeout
	_seen.clear()
	var pressed := found and _press(_panel(), root.get_node("I18n").t("social.remove_sel"))
	var got: bool = await _wait(func(): return _seen.has(3160), 5.0)
	await create_timer(0.4).timeout
	var st := _status()
	_record(3160, "Quitar «%s»" % name, pressed and got and "eliminado" in st,
		"row %s, reply %s, panel says '%s'" % [str(found), str(got), st])
