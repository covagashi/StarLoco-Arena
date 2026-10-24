extends Control
## The versus screen (S07): the retail fightPresentation window, shown on
## 8010 (do_2) before placement. Both sides face each other — the coach
## and its fighters — with the time left and "¡A luchar!". (The 8000 team
## name is the server's generic "Team", so it is left out.)
## The retail waits for the button (setReadyForPlacement → 8011) or the
## server's 20 s; here the button or AUTO_S seconds, whichever first, so
## nobody idles through presentation. fight_view sends the 8011 on `ready`
## and drops the panel when placement opens (8020).
##
## set_sides(left, right): {coach, fighters: [{name, breed}]}.

const UiStyle := preload("res://src/ui/ui_style.gd")

signal ready_pressed

const AUTO_S := 4.0
const SIZE := Vector2(900, 420)

var _left: Dictionary = {}
var _right: Dictionary = {}
var _left_time := AUTO_S
var _count: Label
var _go: Button
var _sent := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame := PanelContainer.new()
	frame.name = "Frame"
	frame.theme = UiStyle.theme()
	frame.add_theme_stylebox_override("panel", UiStyle.window())
	frame.custom_minimum_size = SIZE
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(frame)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	frame.add_child(col)
	var sides := HBoxContainer.new()
	sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sides.add_theme_constant_override("separation", 24)
	col.add_child(sides)
	_side(sides, _left, "Left")
	var vs := _label(sides, I18n.t("vs.vs"), 64)
	vs.add_theme_font_override("font", UiStyle.title_font())
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_side(sides, _right, "Right")
	var bar := HBoxContainer.new()
	col.add_child(bar)
	_count = _label(bar, "", 18)
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_go = Button.new()
	_go.name = "Go"
	_go.text = I18n.t("vs.go")
	_go.custom_minimum_size.x = 200
	UiStyle.primary(_go, 22)
	_go.pressed.connect(_fire)
	bar.add_child(_go)
	_go.grab_focus.call_deferred()


func set_sides(left: Dictionary, right: Dictionary) -> void:
	_left = left
	_right = right


func _process(delta: float) -> void:
	if _sent:
		return
	_left_time -= delta
	_count.text = I18n.t("vs.starts", {"n": ceili(maxf(_left_time, 0.0))})
	if _left_time <= 0.0:
		_fire()


func _fire() -> void:
	if _sent:
		return
	_sent = true
	_go.disabled = true
	_count.text = I18n.t("fight.waiting")
	ready_pressed.emit()


func _side(parent: Node, d: Dictionary, node_name: String) -> void:
	var box := VBoxContainer.new()
	box.name = node_name
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var coach := _label(box, str(d.get("coach", "")), 30)
	coach.name = "Coach"
	coach.add_theme_font_override("font", UiStyle.title_font())
	box.add_child(HSeparator.new())
	for f in d.get("fighters", []):
		var line := str(f.get("name", ""))
		var breed := str(f.get("breed", ""))
		if breed != "" and breed != line:
			line += " · " + breed
		_label(box, line, 18)


func _label(parent: Node, text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l
