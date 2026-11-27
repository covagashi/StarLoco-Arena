extends "res://test/world_smoke.gd"

## S20: the lobby's « » turned the coach. S54: the lobby shows a picture
## of it, front on, so it has no « » any more; what turns is the recruit
## screen's preview.
##
##   godot --path godot -s test/coach_turn_smoke.gd [-- --shot-dir=D]


func _audit() -> void:
	var lobby = _main._lobby_screen
	var arrows := 0
	for b in lobby.find_children("*", "Button", true, false):
		if b.text == "»" or b.text == "«":
			arrows += 1
	_record(0, "no turning", arrows == 0, "« » in the lobby: %d" % arrows)
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
	# S47: the recruit screen's chevron
	var right: Button = p.find_child("TurnRight", true, false)
	var before := int(p._dir)
	var look_before := str(p._look)
	if right != null:
		right.pressed.emit()
	await create_timer(0.3).timeout
	_record(0, "creation turn", right != null and int(p._dir) == ((before + 1) & 7)
		and str(p._look) != look_before and str(p._look) != "",
		"▶ : %d → %d, look '%s' → '%s'" % [before, int(p._dir), look_before, str(p._look)])
	await _shot("creation-turned")
	_close_all()
