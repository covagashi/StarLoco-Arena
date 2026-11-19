extends SceneTree
## S47 W6: TouchTips with real touch events (the mouse emulated from touch,
## as a phone's browser sends them): a held finger shows the button's
## tooltip and does not press it; a quick tap presses it and shows nothing.
##
##   godot --headless --path godot -s test/touch_tips_smoke.gd

var _presses := 0
var _fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("[touch] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _touch(p: Vector2, down: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = p
	e.pressed = down
	Input.parse_input_event(e)


func _run() -> void:
	var tips = root.get_node("TouchTips")
	var b := Button.new()
	b.text = "Jugar"
	b.position = Vector2(100, 100)
	b.size = Vector2(200, 80)
	b.tooltip_text = "3 victorias pagan una carta"
	b.pressed.connect(func(): _presses += 1)
	root.add_child(b)
	await process_frame
	var p := Vector2(200, 140)

	_touch(p, true)
	await create_timer(0.7).timeout
	print("[touch] presses while held: ", _presses)
	_check(tips.tip_text() == b.tooltip_text, "a held finger shows the tooltip (%s)" % tips.tip_text())
	_touch(p, false)
	for i in 3: await process_frame
	_check(_presses == 0, "lifting it presses nothing (%d)" % _presses)

	_touch(p, true)
	await process_frame
	_check(tips.tip_text() == "", "the next touch hides the bubble")
	_touch(p, false)
	for i in 3: await process_frame
	_check(_presses == 1, "a quick tap presses (%d)" % _presses)

	_touch(p, true)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = p + Vector2(60, 0)
	Input.parse_input_event(d)
	await create_timer(0.7).timeout
	_check(tips.tip_text() == "", "a finger that drags is not holding")
	_touch(p + Vector2(60, 0), false)
	for i in 3: await process_frame

	_touch(Vector2(900, 600), true)
	await create_timer(0.7).timeout
	_check(tips.tip_text() == "", "nothing under the finger, no bubble")
	_touch(Vector2(900, 600), false)
	for i in 3: await process_frame
	print("[touch] %d failed" % _fails)
	quit(1 if _fails > 0 else 0)
