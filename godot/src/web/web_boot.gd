extends Control

## The web demo's first scene (S44; project.godot run/main_scene.web):
## downloads the boot bundle (WebAssets) behind a progress bar, then hands
## over to main.tscn, which then finds every table, image, sound and figure
## where a desktop build has them. Nothing here may read an asset: none is
## here yet, so the texts are plain and in English.

const MAIN := "res://src/main.tscn"

var _bar := ProgressBar.new()
var _label := Label.new()
var _retry := Button.new()


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.07, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 0)
	box.position = Vector2(-210, -60)
	box.add_theme_constant_override("separation", 14)
	add_child(box)
	var title := Label.new()
	title.text = "Pippop Arena"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	box.add_child(title)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(420, 14)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.85, 0.45)
	fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(4)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_label)
	_retry.text = "Retry"
	_retry.visible = false
	_retry.pressed.connect(_load)
	box.add_child(_retry)
	_load.call_deferred()


func _process(_dt: float) -> void:
	if WebAssets.downloading() != "":
		_bar.value = WebAssets.progress()
		_label.text = "Loading… %d %%" % int(WebAssets.progress() * 100.0)


func _load() -> void:
	_retry.visible = false
	_label.text = "Loading…"
	if not await WebAssets.ensure(["boot"]):
		_label.text = "Couldn't download the game. Check your connection."
		_retry.visible = true
		return
	_bar.value = 1.0
	I18n.reload()   # its autoload ran before the tables were here
	WebAssets.fetch_later()   # the fighters and summons, while the player logs in
	get_tree().change_scene_to_file.call_deferred(MAIN)
