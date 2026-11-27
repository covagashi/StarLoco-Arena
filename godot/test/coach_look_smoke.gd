extends "res://test/world_smoke.gd"

## S47: the coach as a player sees it, live: the lobby (its menu stance,
## dressed in what it wears) and Inventario → Equipo del coach, a few
## seconds apart so the idle moves. --shot-dir=D needs a real renderer.
## S54: the lobby's coach is its picture (CoachPortrait), wearing the
## pieces its worn cards name.

const Fighter3D := preload("res://src/anims/fighter3d.gd")


func _audit() -> void:
	await create_timer(2.0).timeout
	var spr = _main._lobby_screen._spr
	var coach: Dictionary = _main._gui.model.get_value("localCoach")
	var want := Fighter3D.coach_pieces(coach.get("worn", []))
	var got := {}
	for slot in spr.worn():
		if spr.worn()[slot] != "":
			got[slot] = spr.worn()[slot]
	_record(0, "lobby picture", not spr.index.is_empty() and got == want,
		"picture %s, wears %s (cards say %s)" % [not spr.index.is_empty(), got, want])
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
