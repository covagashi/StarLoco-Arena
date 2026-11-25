extends Control
## The tutorial's focus (S53, owner: "en un tutorial hay que obligar a los
## jugadores a hacer lo que se tenga que hacer, ofuscar todo y enseñar
## explícitamente dónde se buscan las cosas"): the screen goes dark but for
## a hole around the one control the step uses; a click outside the hole
## does nothing, one inside reaches that control. A bubble beside the hole
## says what to do (or, with no target, sits in the middle with one button),
## and a small «Saltar tutorial» in the corner asks once before skipping.
##
##   show_step(target, text, button := "")   target null → a centred bubble
##   clear()
## Signals: skipped (confirmed), pressed (the bubble's own button).

signal skipped
signal pressed

const UiStyle := preload("res://src/ui/ui_style.gd")
const StyleB := preload("res://src/ui/style_b.gd")
const DIM := Color(0.06, 0.07, 0.13, 0.72)
const PAD := 8.0
const BUBBLE_W := 380.0

var _target: Control = null
var _hole := Rect2()
var _t := 0.0
var _bubble: PanelContainer
var _text: Label
var _button: Button
var _skip: Button
var _ask: HBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # the dark part eats every click
	visible = false
	_bubble = PanelContainer.new()
	_bubble.name = "Bubble"
	var ps := StyleB.plate(0.98)
	ps.content_margin_left = 22
	ps.content_margin_right = 22
	ps.content_margin_top = 16
	ps.content_margin_bottom = 16
	ps.border_color = UiStyle.B_CORAL
	ps.border_width_left = 5
	_bubble.add_theme_stylebox_override("panel", ps)
	add_child(_bubble)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_bubble.add_child(col)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size.x = BUBBLE_W - 44
	_text.add_theme_font_override("font", UiStyle.body_font())
	_text.add_theme_font_size_override("font_size", 19)
	_text.add_theme_color_override("font_color", UiStyle.B_INK)
	col.add_child(_text)
	_button = StyleB.button(true, 18)
	_button.name = "BubbleButton"
	_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_button.custom_minimum_size = Vector2(190, 50)
	_button.pressed.connect(func(): pressed.emit())
	col.add_child(_button)
	# «Saltar tutorial», then «¿Seguro?» Sí / No in its place
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.flat = true
	_skip.text = I18n.t("tutorial.skip")
	_skip.add_theme_font_override("font", UiStyle.bold(800))
	_skip.add_theme_font_size_override("font_size", 15)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		_skip.add_theme_color_override(c, Color(1, 1, 1, 0.85) if c == "font_color" else UiStyle.B_CORAL)
	_skip.pressed.connect(func():
		_skip.hide()
		_ask.show())
	add_child(_skip)
	_ask = HBoxContainer.new()
	_ask.name = "SkipAsk"
	_ask.add_theme_constant_override("separation", 8)
	_ask.hide()
	add_child(_ask)
	var q := Label.new()
	q.text = I18n.t("tutorial.skip_ask")
	q.add_theme_font_override("font", UiStyle.bold(800))
	q.add_theme_font_size_override("font_size", 15)
	q.add_theme_color_override("font_color", Color.WHITE)
	_ask.add_child(q)
	var yes := StyleB.button(true, 14)
	yes.name = "SkipYes"
	yes.text = I18n.t("tutorial.skip_yes")
	yes.pressed.connect(func():
		clear()
		skipped.emit())
	_ask.add_child(yes)
	var no := StyleB.button(false, 14)
	no.name = "SkipNo"
	no.text = I18n.t("tutorial.skip_no")
	no.pressed.connect(func():
		_ask.hide()
		_skip.show())
	_ask.add_child(no)


## Light up `target` (null: no hole) with `text` beside it; `button` puts a
## button in the bubble (the step goes on when it is pressed).
func show_step(target: Control, text: String, button := "") -> void:
	_target = target
	_text.text = text
	_button.visible = button != ""
	_button.text = button
	if not visible:
		_skip.show()
		_ask.hide()
	_skip.text = I18n.t("tutorial.skip")
	(_ask.get_child(0) as Label).text = I18n.t("tutorial.skip_ask")
	(_ask.get_node("SkipYes") as Button).text = I18n.t("tutorial.skip_yes")
	(_ask.get_node("SkipNo") as Button).text = I18n.t("tutorial.skip_no")
	visible = true
	_place()


func clear() -> void:
	_target = null
	visible = false


func text() -> String:
	return _text.text


func active() -> bool:
	return visible


## The hole, in this control's coordinates (empty with no target).
func hole() -> Rect2:
	return _hole


func _has_point(point: Vector2) -> bool:
	# a click inside the hole falls through to the control under it
	return not (_hole.has_area() and _hole.has_point(point))


func _process(dt: float) -> void:
	if not visible:
		return
	_t += dt
	_place()
	queue_redraw()


func _place() -> void:
	# the whole window, whatever the parent's size (the lobby's is its stage)
	global_position = Vector2.ZERO
	size = get_viewport_rect().size
	var t := _target if is_instance_valid(_target) and _target.is_visible_in_tree() else null
	if t != null:
		_hole = t.get_global_rect().grow(PAD)
		_hole.position -= get_global_rect().position
	else:
		_hole = Rect2()
	var s := size
	# the lobby scales its stage with the window (1280×720 at 1): so does the bubble
	var k := clampf(minf(s.x / 1280.0, s.y / 720.0), 1.0, 2.5)
	_bubble.scale = Vector2(k, k)
	_skip.scale = Vector2(k, k)
	_ask.scale = Vector2(k, k)
	_bubble.reset_size()
	var b := _bubble.get_combined_minimum_size() * k
	var at: Vector2
	if _hole.has_area():
		# beside the hole, on the side with more room, kept on screen
		var right := s.x - _hole.end.x
		var left := _hole.position.x
		if right >= b.x + 24 or right >= left:
			at = Vector2(_hole.end.x + 20, _hole.position.y)
		else:
			at = Vector2(_hole.position.x - 20 - b.x, _hole.position.y)
		if at.x < 16 or at.x + b.x > s.x - 16:   # neither side: under or over it
			at.x = clampf(_hole.get_center().x - b.x / 2, 16, s.x - 16 - b.x)
			at.y = _hole.end.y + 20 if _hole.end.y + 20 + b.y < s.y - 16 else _hole.position.y - 20 - b.y
	else:
		at = (s - b) / 2
	at.y = clampf(at.y, 16, s.y - 16 - b.y)
	_bubble.position = at
	_skip.reset_size()
	_skip.position = Vector2(s.x - _skip.size.x * k - 24 * k, 74 * k)   # under the top bar
	_ask.reset_size()
	_ask.position = Vector2(s.x - _ask.get_combined_minimum_size().x * k - 24 * k, 70 * k)


func _draw() -> void:
	var s := size
	if not _hole.has_area():
		draw_rect(Rect2(Vector2.ZERO, s), DIM)
		return
	var h := _hole
	# four bands round the hole
	draw_rect(Rect2(0, 0, s.x, h.position.y), DIM)
	draw_rect(Rect2(0, h.end.y, s.x, s.y - h.end.y), DIM)
	draw_rect(Rect2(0, h.position.y, h.position.x, h.size.y), DIM)
	draw_rect(Rect2(h.end.x, h.position.y, s.x - h.end.x, h.size.y), DIM)
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	draw_rect(h, Color(UiStyle.B_CORAL, 0.6 + 0.4 * pulse), false, 3.0 + 2.0 * pulse)
	draw_rect(h.grow(6 + 5 * pulse), Color(UiStyle.B_CORAL, 0.35 * (1.0 - pulse)), false, 2.0)
