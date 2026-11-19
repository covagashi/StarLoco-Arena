extends "res://test/world_smoke.gd"

## S47 W6: the touch bubble as a phone shows it — a finger held on the
## Historia tile's JUGAR in the live lobby. --shot-dir=D needs a renderer.

func _audit() -> void:
	await create_timer(1.5).timeout
	var play: Control = _main._lobby_screen._cards.story.play
	var p := play.get_global_transform_with_canvas() * (play.size * 0.5)
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = true
	Input.parse_input_event(e)
	await create_timer(0.8).timeout
	var tips = root.get_node("TouchTips")
	await _shot("touch-tip-lobby")
	_record(0, "touch tip", tips.tip_text() != "", tips.tip_text().replace("\n", " | "))
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await create_timer(0.5).timeout
	_record(0, "no launch", not _main._lobby_screen._searching, "lifting the finger launched nothing")
