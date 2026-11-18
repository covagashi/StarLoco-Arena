extends "res://test/world_smoke.gd"

## S47: the coach as a player sees it, live: the lobby (its menu stance,
## dressed in what it wears) and Inventario → Equipo del coach, a few
## seconds apart so the idle moves. --shot-dir=D needs a real renderer.

func _audit() -> void:
	await create_timer(2.0).timeout
	await _shot("coach-lobby-a")
	await create_timer(1.3).timeout
	await _shot("coach-lobby-b")
	_main._gui.open("cardBookDialog")
	await create_timer(0.6).timeout
	var p = _main._gui.dialogs.get("cardBookDialog")
	var eq = p.find_child("CoachEquip", true, false) if p != null else null
	if eq != null:
		eq.pressed.emit()
	await _wait(func(): return _main._gui.is_open("coachEquipDialog"), 3.0)
	await create_timer(2.0).timeout
	await _shot("coach-equip")
	_record(0, "coach shown", _main._gui.is_open("coachEquipDialog"), "lobby and Equipo del coach shot")
