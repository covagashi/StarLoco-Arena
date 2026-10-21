class_name PippopCoachCreation
extends Control
## Native coach creation screen in the 1-bit UI system (S18,
## src/ui/onebit.gd), real controls only (no baked art). Drives the shared `localCoach` model so the
## existing handlers (_on_localcoach_changed/_on_coach_dir/_on_coach_random/
## _on_coach_create) keep working unchanged.

signal dir_pressed(d: int)
signal random_pressed
signal submit
signal closed

const OneBit := preload("res://src/ui/onebit.gd")
const REF := Vector2(1280, 720)
const R_FORM := Rect2(200, 150, 440, 450)
const R_STAGE := Rect2(680, 150, 400, 450)
const SWATCH := Vector2(34, 34)
const SWATCH_COLS := 8
const R_RANDOM := Rect2(420, 630, 200, 56)
const R_VALIDATE := Rect2(660, 624, 220, 64)
const DOLL_POS := Vector2(880, 540)
const DOLL_SCALE := 3.65

var _box: Control
var _model                   # GuiLib model — localCoach lives here
var _spr                     # AnmSprite paper-doll
var name_edit: LineEdit
var _sex_btns := {}
var _hair_cells := {}
var _skin_cells := {}


## 1-bit UI (S18): the chrome is black and white; the swatches and the doll
## keep their colours, because colour is what is being chosen — like the
## 1-bit fights, where each actor keeps its own colours.
func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.size = REF
	_box.theme = OneBit.theme()
	add_child(_box)
	_box.add_child(OneBit.backdrop(REF))

	var title := Label.new()
	title.text = I18n.t("creation.title").to_upper()
	title.position = Vector2(0, 56)
	title.size = Vector2(REF.x, 80)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", OneBit.title_font())
	title.add_theme_font_size_override("font_size", 60)
	title.add_theme_constant_override("outline_size", 12)
	_box.add_child(title)

	var form := _window(R_FORM)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	form.add_child(col)
	col.add_child(OneBit.caption(I18n.t("creation.name")))
	name_edit = LineEdit.new()
	name_edit.max_length = 20
	name_edit.custom_minimum_size.y = 44
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.text_changed.connect(func(t): _set_lc("name", t))
	col.add_child(name_edit)
	col.add_child(OneBit.caption(I18n.t("creation.sex")))
	var sexes := HBoxContainer.new()
	sexes.add_theme_constant_override("separation", 10)
	col.add_child(sexes)
	_sex_btns[0] = _toggle(sexes, "♂  " + I18n.t("creation.male"),
		func(): _set_lc("sex", 0))
	_sex_btns[1] = _toggle(sexes, "♀  " + I18n.t("creation.female"),
		func(): _set_lc("sex", 1))
	col.add_child(OneBit.caption(I18n.t("creation.hair")))
	var hair := _grid(col)
	for i in range(14):
		_hair_cells[i] = _swatch(hair, Palettes.HAIR[i], func(): _set_lc("hair", i))
	col.add_child(OneBit.caption(I18n.t("creation.skin")))
	var skin := _grid(col)
	for i in range(11):
		_skin_cells[i] = _swatch(skin, Palettes.SKIN[i], func(): _set_lc("skin", i))

	_window(R_STAGE)
	_round(Rect2(R_STAGE.position + Vector2(24, R_STAGE.size.y - 64), Vector2(56, 40)),
		"«", func(): dir_pressed.emit(-1), "creation.rotate_left")
	_round(Rect2(R_STAGE.end - Vector2(80, 64), Vector2(56, 40)),
		"»", func(): dir_pressed.emit(1), "creation.rotate_right")

	var rnd := Button.new()
	rnd.text = I18n.t("creation.random_btn")
	rnd.position = R_RANDOM.position
	rnd.size = R_RANDOM.size
	rnd.tooltip_text = I18n.t("creation.random")
	rnd.add_theme_font_size_override("font_size", 19)
	rnd.pressed.connect(func(): random_pressed.emit())
	_box.add_child(rnd)
	var ok := Button.new()
	ok.text = I18n.t("creation.validate_btn").to_upper()
	ok.position = R_VALIDATE.position
	ok.size = R_VALIDATE.size
	ok.tooltip_text = I18n.t("creation.validate")
	OneBit.primary(ok)
	ok.pressed.connect(func(): submit.emit())
	_box.add_child(ok)

	_spr = preload("res://src/anims/anm_sprite.gd").new()
	OneBit.doll(_spr)
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
	_model.set_value("localCoach", v, field)


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
		_sex_btns[k].set_pressed_no_signal(k == sex)
	var hair: int = int(lc.get("hair", 0)) % Palettes.HAIR.size()
	var skin: int = int(lc.get("skin", 0)) % Palettes.SKIN.size()
	for k in _hair_cells:
		_hair_cells[k].get_meta("_ring").visible = (k == hair)
	for k in _skin_cells:
		_skin_cells[k].get_meta("_ring").visible = (k == skin)
	_sync_doll(lc)


func _sync_doll(lc: Dictionary) -> void:
	var lib := AssetPaths.normalize(str(lc.get("actorDescriptorLibrary",
		"coach_7000")))
	if not lib.begins_with("anims/"):
		lib = "anims/" + lib
	var dir: int = int(lc.get("actorDirection", 3))
	if lc.get("actorMaterial") is Dictionary:
		_spr.tints = lc["actorMaterial"]
	if not _spr.load_action(lib, "%d_AnimStatique" % dir):
		for d in [5, 2, 0, 6, 1, 3, 7, 4]:
			if _spr.load_action(lib, "%d_AnimStatique" % d):
				break
	_spr.scale.x = absf(DOLL_SCALE) * (-1.0 if dir in [1, 2, 3] else 1.0)


func _window(r: Rect2) -> PanelContainer:
	var p := PanelContainer.new()
	p.position = r.position
	p.size = r.size
	p.add_theme_stylebox_override("panel", OneBit.window(26))
	_box.add_child(p)
	return p


func _grid(parent: Control) -> GridContainer:
	var g := GridContainer.new()
	g.columns = SWATCH_COLS
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	parent.add_child(g)
	return g


## Sex choice: toggles that invert when picked (the theme's pressed style).
func _toggle(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 42)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## A colour swatch in a white frame; the picked one gets a thick frame and the
## hard shadow.
func _swatch(parent: Control, v: Vector3, cb: Callable) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = SWATCH
	var fill := Panel.new()
	var sb := OneBit.box(Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0),
		clampf(v.z, 0.0, 1.0)), OneBit.INK, 1, 0)
	fill.add_theme_stylebox_override("panel", sb)
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fill)
	var ring := Panel.new()
	var rs := OneBit.box(Color(0, 0, 0, 0), OneBit.INK, 3, 0)
	rs.draw_center = false
	rs.set_expand_margin_all(4)
	rs.shadow_color = OneBit.INK
	rs.shadow_size = 1
	rs.shadow_offset = Vector2(3, 3)
	ring.add_theme_stylebox_override("panel", rs)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.visible = false
	holder.add_child(ring)
	var b := Button.new()
	b.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.flat = true
	b.add_theme_stylebox_override("focus", OneBit.focus_ring())
	b.pressed.connect(cb)
	holder.add_child(b)
	holder.set_meta("_ring", ring)
	parent.add_child(holder)
	return holder


func _round(r: Rect2, text: String, cb: Callable, hint_key: String) -> Button:
	var b := Button.new()
	b.text = text
	b.position = r.position
	b.size = r.size
	b.tooltip_text = I18n.t(hint_key)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _relayout() -> void:
	if _box == null:
		return
	# full-rect anchors already size the screen to the viewport; setting
	# size here too only made Godot warn (the old S07 anchor warnings)
	var vp := get_viewport_rect().size
	var s := minf(vp.x / REF.x, vp.y / REF.y)
	_box.scale = Vector2(s, s)
	_box.position = (vp - REF * s) / 2.0
