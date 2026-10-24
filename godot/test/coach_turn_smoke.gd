extends "res://test/world_smoke.gd"

## S20: the lobby's « » turn the coach, and the turn survives a model rebuild.
##
##   godot --path godot -s test/coach_turn_smoke.gd [-- --shot-dir=D]
##
## Before S20, _rotate() re-read the old direction before writing the new one,
## so « » did nothing; and _local_coach_model() always reset it to 3.


func _audit() -> void:
	var lobby = _main._lobby_screen
	var turn_right: Button = null
	var turn_left: Button = null
	for b in lobby.find_children("*", "Button", true, false):
		if b.text == "»":
			turn_right = b
		elif b.text == "«":
			turn_left = b
	if turn_right == null or turn_left == null:
		_record(0, "buttons", false, "no « » buttons in the lobby")
		return
	var before := int(lobby._dir)
	turn_right.pressed.emit()
	await create_timer(0.3).timeout
	var after := int(lobby._dir)
	var model_dir := int(_main._gui.gui.model.get_value("localCoach").get("actorDirection", -1))
	_record(0, "turn", after == ((before + 1) & 7) and model_dir == after,
		"» : %d → %d (model says %d)" % [before, after, model_dir])
	await _shot("coach-turned")
	_main._push_local_coach()
	await create_timer(0.3).timeout
	_record(0, "kept", int(lobby._dir) == after,
		"after a lobby model rebuild the coach still faces %d (got %d)" % [after, int(lobby._dir)])
	turn_left.pressed.emit()
	await create_timer(0.3).timeout
	_record(0, "back", int(lobby._dir) == before, "« puts it back to %d (got %d)" % [before, int(lobby._dir)])
	await _new_fighter_turn()


## "Nuevo luchador": ◀ ▶ turn the preview (it loads that direction's idle).
func _new_fighter_turn() -> void:
	_main._on_new_fighter_dialog([], null, false)
	await _wait(func(): return _main._gui.is_open("fighterCreationDialog"), 3.0)
	await create_timer(0.5).timeout
	var p = _main._gui.dialogs.get("fighterCreationDialog")
	if p == null:
		_record(0, "creation", false, "fighterCreationDialog did not open")
		return
	var right: Button = null
	for b in p.find_children("*", "Button", true, false):
		if b.text == "▶":
			right = b
	var before := int(p._preview_dir)
	var look_before := str(p._preview_look)
	if right != null:
		right.pressed.emit()
	await create_timer(0.3).timeout
	_record(0, "creation turn", right != null and int(p._preview_dir) == ((before + 1) & 7)
		and str(p._preview_look) != look_before and str(p._preview_look) != "",
		"▶ : %d → %d, look '%s' → '%s'" % [before, int(p._preview_dir), look_before, str(p._preview_look)])
	await _shot("creation-turned")
	_close_all()
