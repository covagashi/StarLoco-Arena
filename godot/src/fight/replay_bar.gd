extends PanelContainer

## Replay transport (S11): pause, speed ×1/×2/×4, the clock, and leave. It
## sits where the PASS button goes — a replay has nothing to pass.

signal leave_requested

var client: Node            # the ReplayClient (State.replay)
var _play: Button
var _speed: Button
var _clock: Label


func _init(rc: Node) -> void:
	client = rc
	name = "ReplayBar"


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.82)
	style.set_corner_radius_all(9)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var tag := Label.new()
	tag.text = I18n.t("replay.tag")
	tag.add_theme_color_override("font_color", Color("e0c070"))
	row.add_child(tag)
	_play = _button(row, "PlayBtn", I18n.t("replay.pause"), _toggle_pause)
	_speed = _button(row, "SpeedBtn", "×1", _cycle_speed)
	_clock = Label.new()
	_clock.name = "Clock"
	_clock.custom_minimum_size.x = 92
	_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_clock)
	_button(row, "LeaveBtn", I18n.t("replay.leave"), func(): leave_requested.emit())
	_refresh()


func _button(parent: Node, id: String, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _toggle_pause() -> void:
	client.paused = not client.paused
	_refresh()


func _cycle_speed() -> void:
	client.cycle_speed()
	_refresh()


func _process(_delta: float) -> void:
	_clock.text = "%s / %s" % [_mmss(client.elapsed_ms()), _mmss(client.total_ms())]
	_refresh()   # the reel renderer sets the speed without the button


func _refresh() -> void:
	_play.text = I18n.t("replay.play") if client.paused else I18n.t("replay.pause")
	_speed.text = "×%d" % int(client.speed)


static func _mmss(ms: int) -> String:
	var s := maxi(ms, 0) / 1000
	return "%d:%02d" % [s / 60, s % 60]
