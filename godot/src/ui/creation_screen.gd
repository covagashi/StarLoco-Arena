class_name PippopCoachCreation
extends Control
## Native coach creation screen — Pillow-baked art (assets/ui/creation_bg.png)
## with real controls overlaid. Drives the shared `localCoach` model so the
## existing handlers (_on_localcoach_changed/_on_coach_dir/_on_coach_random/
## _on_coach_create) keep working unchanged.

signal dir_pressed(d: int)
signal random_pressed
signal submit
signal closed

const REF := Vector2(1280, 720)
const R_NAME := Rect2(260, 204, 340, 44)
const R_SEX_M := Rect2(260, 286, 165, 40)
const R_SEX_F := Rect2(435, 286, 165, 40)
const GRID_X := 262
const GRID_STEP := 42
const CELL := Vector2(34, 34)
const HAIR_ROWS := [362, 404]
const SKIN_ROWS := [474, 516]
const R_PREV := Rect2(665, 330, 48, 38)
const R_NEXT := Rect2(1055, 330, 48, 38)
const R_RANDOM := Rect2(430, 620, 200, 52)
const R_VALIDATE := Rect2(650, 620, 200, 52)
const R_QUIT := Rect2(1205, 28, 44, 44)
const DOLL_POS := Vector2(875, 545)
const DOLL_SCALE := 1.6

var _box: Control
var _model                   # GuiLib model — localCoach lives here
var _spr                     # AnmSprite paper-doll
var name_edit: LineEdit
var _sex_btns := {}
var _hair_cells := {}
var _skin_cells := {}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.size = REF
	add_child(_box)

	var bg := TextureRect.new()
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(
			"res://assets/ui/creation_bg.png")) == OK:
		bg.texture = ImageTexture.create_from_image(img)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_box.add_child(bg)

	var font := FontFile.new()
	font.load_dynamic_font("res://assets/gui/fonts/COPRGTB.TTF")
	var plain := StyleBoxEmpty.new()

	name_edit = LineEdit.new()
	name_edit.position = R_NAME.position + Vector2(10, 0)
	name_edit.size = R_NAME.size - Vector2(20, 0)
	name_edit.flat = true
	name_edit.max_length = 20
	name_edit.add_theme_font_override("font", font)
	name_edit.add_theme_font_size_override("font_size", 22)
	name_edit.add_theme_color_override("font_color", Color(0.90, 0.85, 0.62))
	name_edit.add_theme_color_override("caret_color", Color(0.90, 0.85, 0.62))
	for s in ["normal", "focus", "read_only"]:
		name_edit.add_theme_stylebox_override(s, plain)
	name_edit.text_changed.connect(func(t): _set_lc("name", t))
	_box.add_child(name_edit)

	_sex_btns[0] = _toggle(R_SEX_M, "♂  HOMBRE", font,
		func(): _set_lc("sex", 0))
	_sex_btns[1] = _toggle(R_SEX_F, "♀  MUJER", font,
		func(): _set_lc("sex", 1))

	for i in range(14):
		var cell := Rect2(GRID_X + (i % 8) * GRID_STEP,
			HAIR_ROWS[i / 8], CELL.x, CELL.y)
		_hair_cells[i] = _swatch(cell, Palettes.HAIR[i],
			func(): _set_lc("hair", i))
	for i in range(11):
		var cell := Rect2(GRID_X + (i % 8) * GRID_STEP,
			SKIN_ROWS[i / 8], CELL.x, CELL.y)
		_skin_cells[i] = _swatch(cell, Palettes.SKIN[i],
			func(): _set_lc("skin", i))

	_ghost(R_PREV, func(): dir_pressed.emit(-1))
	_ghost(R_NEXT, func(): dir_pressed.emit(1))
	_ghost(R_RANDOM, func(): random_pressed.emit())
	_ghost(R_VALIDATE, func(): submit.emit())
	_ghost(R_QUIT, func(): closed.emit())

	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = DOLL_POS
	_spr.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	_box.add_child(_spr)

	resized.connect(_relayout)


func _ready() -> void:
	_relayout()
	name_edit.grab_focus()


## Wire the shared model — every change to localCoach resyncs the doll
## and the selected states. main.gd seeds the model before showing us.
func bind_model(m) -> void:
	_model = m
	if not _model.changed.is_connected(_on_lc_changed):
		_model.changed.connect(_on_lc_changed)
	_sync()


func _set_lc(field: String, v) -> void:
	if _model == null:
		return
	var lc = _model.get_value("localCoach")
	if not (lc is Dictionary):
		return
	lc[field] = v
	_model.set_value("localCoach", lc)


func _on_lc_changed(n: String, _f: String, _v) -> void:
	if n == "localCoach":
		_sync()


func _sync() -> void:
	if _model == null:
		return
	var lc = _model.get_value("localCoach")
	if not (lc is Dictionary):
		return
	if name_edit.text != str(lc.get("name", "")):
		name_edit.text = str(lc.get("name", ""))
	var sex: int = int(lc.get("sex", 0))
	for k in _sex_btns:
		_sex_btns[k].self_modulate = \
			Color(1.0, 0.9, 0.45) if k == sex else Color(0.55, 0.53, 0.42)
	var hair: int = int(lc.get("hair", 0)) % Palettes.HAIR.size()
	var skin: int = int(lc.get("skin", 0)) % Palettes.SKIN.size()
	for k in _hair_cells:
		_hair_cells[k].get_meta("_ring").visible = (k == hair)
	for k in _skin_cells:
		_skin_cells[k].get_meta("_ring").visible = (k == skin)
	_sync_doll(lc)


func _sync_doll(lc: Dictionary) -> void:
	var lib := str(lc.get("actorDescriptorLibrary", "coach_7000"))
	if not lib.begins_with("res://"):
		lib = "res://assets/anims/" + lib
	var dir: int = int(lc.get("actorDirection", 3))
	if lc.get("actorMaterial") is Dictionary:
		_spr.tints = lc["actorMaterial"]
	if not _spr.load_action(lib, "%d_AnimStatique" % dir):
		for d in [5, 2, 0, 6, 1, 3, 7, 4]:
			if _spr.load_action(lib, "%d_AnimStatique" % d):
				break
	_spr.scale.x = absf(DOLL_SCALE) * (-1.0 if dir in [1, 2, 3] else 1.0)


func _toggle(r: Rect2, text: String, font: Font, cb: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.text = text
	b.flat = true
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", Color(0.85, 0.80, 0.60))
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _swatch(r: Rect2, v: Vector3, cb: Callable) -> Control:
	var holder := Control.new()
	holder.position = r.position
	holder.size = r.size
	var fill := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0),
		clampf(v.z, 0.0, 1.0))
	sb.border_color = Color(0.08, 0.07, 0.03)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	fill.add_theme_stylebox_override("panel", sb)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	var ring := Panel.new()
	var rs := StyleBoxFlat.new()
	rs.bg_color = Color(0, 0, 0, 0)
	rs.border_color = Color(0.95, 0.80, 0.30)
	rs.set_border_width_all(2)
	rs.set_corner_radius_all(4)
	ring.add_theme_stylebox_override("panel", rs)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	holder.add_child(ring)
	var b := Button.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	holder.add_child(b)
	holder.set_meta("_ring", ring)
	_box.add_child(holder)
	return holder


func _ghost(r: Rect2, cb: Callable) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _relayout() -> void:
	if _box == null:
		return
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	var s := minf(vp.x / REF.x, vp.y / REF.y)
	_box.scale = Vector2(s, s)
	_box.position = (vp - REF * s) / 2.0
