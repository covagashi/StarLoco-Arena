extends CanvasLayer
## S47 W6: on a touch screen nothing hovers, so a tooltip never shows (a
## spell's cost and range, what a lobby tile pays, why a chapter is locked…).
## Hold a finger still on anything with a tooltip and its text shows in a
## bubble above the finger; lifting that finger then presses nothing. A
## mouse never gets here: only touch events start a hold.

const UiStyle := preload("res://src/ui/ui_style.gd")

const HOLD := 0.45      # seconds still before the bubble shows
const SLOP := 14.0      # px the finger may wander and still be holding
const SHOWN := 4.0      # seconds the bubble stays
const REF := Vector2(1280, 720)   # the screens' reference size (lobby_screen.REF)

var _start := Vector2.ZERO
var _hold := -1.0
var _left := 0.0
var _eat_release := false
var _text := ""   # the tooltip shown, as the control gives it
var _bubble: PanelContainer
var _label: Label


func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


## The bubble, built the first time it shows: an autoload is ready before
## the web build has unpacked assets/, and UiStyle caches the fonts it reads
## (one read now would leave every screen without its font).
func _build() -> void:
	_bubble = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = UiStyle.B_INK
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(UiStyle.B_INK, 0.35)
	sb.shadow_offset = Vector2(4, 4)
	_bubble.add_theme_stylebox_override("panel", sb)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.add_theme_font_override("font", UiStyle.bold(800))
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", UiStyle.B_INK)
	_bubble.add_child(_label)
	_bubble.visible = false
	add_child(_bubble)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			hide_tip()
			_eat_release = false
			_start = event.position
			_hold = HOLD
			set_process(true)
		else:
			_hold = -1.0
			if _eat_release:
				# the finger that opened the bubble lifts: the controls take
				# the touch itself as a press too (Viewport touch focus)
				_eat_release = false
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0:
		if event.position.distance_to(_start) > SLOP:
			_hold = -1.0
	elif event is InputEventMouseButton and _eat_release and not event.pressed \
			and event.device == InputEvent.DEVICE_ID_EMULATION:
		# ...and first as the mouse release emulated from it: neither is a click
		get_viewport().set_input_as_handled()


func _process(dt: float) -> void:
	if _hold > 0.0:
		_hold -= dt
		if _hold <= 0.0:
			_hold = -1.0
			if show_tip_at(_start):
				_eat_release = true
	if _bubble != null and _bubble.visible:
		_left -= dt
		if _left <= 0.0:
			hide_tip()
	if _hold < 0.0 and (_bubble == null or not _bubble.visible):
		set_process(false)


## Shows the tooltip of what is under `p` (viewport pixels); false when it
## has none.
func show_tip_at(p: Vector2) -> bool:
	var text := tip_at(get_tree().root, p, self)
	if text == "":
		return false
	if _bubble == null:
		_build()
	var vp := get_viewport().get_visible_rect().size
	var k := maxf(1.0, minf(vp.x / REF.x, vp.y / REF.y))
	_text = text
	_label.text = wrap_text(text, _label.get_theme_font("font"), 16, 320.0)
	_bubble.size = Vector2.ZERO
	_bubble.reset_size()
	_bubble.scale = Vector2(k, k)
	var sz := _bubble.get_combined_minimum_size() * k
	var at := p + Vector2(-sz.x * 0.5, -sz.y - 36.0 * k)
	if at.y < 8.0:   # no room above the finger: below it
		at.y = p.y + 36.0 * k
	at.x = clampf(at.x, 8.0, maxf(8.0, vp.x - sz.x - 8.0))
	at.y = clampf(at.y, 8.0, maxf(8.0, vp.y - sz.y - 8.0))
	_bubble.position = at
	_bubble.visible = true
	_left = SHOWN
	set_process(true)
	return true


## `text` broken at spaces so no line is wider than `width` (a wrapping
## Label sizes itself from a width it does not have yet; this one never wraps).
static func wrap_text(text: String, font: Font, size: int, width: float) -> String:
	var out := PackedStringArray()
	for para in text.split("\n"):
		var line := ""
		for word in para.split(" ", false):
			var next := word if line == "" else line + " " + word
			if line != "" and font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				out.append(line)
				line = word
			else:
				line = next
		out.append(line)
	return "\n".join(out)


func hide_tip() -> void:
	if _bubble != null:
		_bubble.visible = false


func tip_text() -> String:
	return _text if _bubble != null and _bubble.visible else ""


## The tooltip of the topmost control under `p`, or of its nearest parent
## with one ("" when none). `skip` is left out of the search (the bubble).
static func tip_at(root: Node, p: Vector2, skip: Node = null) -> String:
	var hit := [null, -INF]   # [control, its canvas layer]
	_scan(root, 0, p, skip, hit)
	var c: Control = hit[0]
	while c != null:
		var local := c.get_global_transform_with_canvas().affine_inverse() * p
		var t := c.get_tooltip(local)
		if t != "":
			return t
		c = c.get_parent() as Control
	return ""


## Tree order is draw order: the last control that takes the mouse and holds
## `p` is the one on top (a higher canvas layer wins over tree order).
static func _scan(n: Node, layer: int, p: Vector2, skip: Node, hit: Array) -> void:
	if n == skip:
		return
	if n is Viewport and n != n.get_tree().root:
		return   # a SubViewport's figure, not the UI
	if n is CanvasLayer:
		if not n.visible:
			return
		layer = n.layer
	if n is CanvasItem and not n.visible:
		return
	if n is Control:
		var c := n as Control
		var local := c.get_global_transform_with_canvas().affine_inverse() * p
		var inside := Rect2(Vector2.ZERO, c.size).has_point(local)
		if c.clip_contents and not inside:
			return   # scrolled out of a list: not under the finger
		if inside and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and layer >= hit[1]:
			hit[0] = c
			hit[1] = layer
	for ch in n.get_children():
		_scan(ch, layer, p, skip, hit)
