class_name PippopCoachCreation
extends Control
## Coach creation, as in the S45 mockup ("2 · Crea tu coach"): a lit stage
## behind, the back medallion and the pop header, three diamond sections on
## the left (body, hair, skin), the coach large on a pedestal with the sun
## chevrons that turn it, the name on a ribbon above it, the section's
## choices on a paper sheet at the right, and "Al azar" + "¡CREAR!".
## Drives the shared `localCoach` model so the existing handlers
## (_on_localcoach_changed/_on_coach_dir/_on_coach_random/_on_coach_create)
## keep working unchanged.

signal dir_pressed(d: int)
signal random_pressed
signal submit
signal closed

const UiStyle := preload("res://src/ui/ui_style.gd")
const REF := Vector2(1280, 720)
const R_PED := Rect2(352, 590, 470, 96)
const DOLL_POS := Vector2(587, 636)
const DOLL_SCALE := 6.2
const R_SHEET := Rect2(910, 108, 330, 0)
const BROWN := Color("7a4a1e")
const SECTIONS := ["body", "hair", "skin"]

var _box: Control
var _model                   # GuiLib model — localCoach lives here
var _spr                     # AnmSprite paper-doll (the 3D coach)
var name_edit: LineEdit
var _sex_btns := {}
var _hair_cells := {}
var _skin_cells := {}
var _tabs := {}              # section -> diamond Button
var _pages := {}             # section -> its Control on the sheet
var _sheet_title: Label
var _section := "hair"


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.size = REF
	_box.clip_contents = true
	_box.theme = UiStyle.theme()
	add_child(_box)
	UiStyle.scene_backdrop(_box, "stage_bg", REF)
	# the spotlight from above and the dark edges
	UiStyle.vignette(_box, REF, Vector2(589, 144), Vector2(384, 432),
		Color(1.0, 0.86, 0.63, 0.35), Color(1.0, 0.86, 0.63, 0.0))
	UiStyle.vignette(_box, REF, Vector2(589, 396), Vector2(768, 576),
		Color(0.07, 0.08, 0.16, 0.2), Color(0.047, 0.055, 0.118, 0.92))

	UiStyle.header(_box, I18n.t("creation.title").to_upper(), func(): closed.emit())
	_section_tabs()

	var ped := Control.new()
	ped.size = REF
	ped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ped.draw.connect(func(): UiStyle.draw_pedestal(ped, R_PED))
	_box.add_child(ped)
	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = DOLL_POS
	_spr.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	_box.add_child(_spr)
	var left := UiStyle.chevron_button(true)
	left.name = "TurnLeft"
	left.position = Vector2(300, 330)
	left.tooltip_text = I18n.t("creation.rotate_left")
	left.pressed.connect(func(): dir_pressed.emit(-1))
	_box.add_child(left)
	var right := UiStyle.chevron_button(false)
	right.name = "TurnRight"
	right.position = Vector2(820, 330)
	right.tooltip_text = I18n.t("creation.rotate_right")
	right.pressed.connect(func(): dir_pressed.emit(1))
	_box.add_child(right)

	_name_ribbon()
	_sheet()
	_actions()
	_show_section(_section)
	resized.connect(_relayout)


## The three sections as diamonds down the left (the selected one in pop
## with a sun ring).
func _section_tabs() -> void:
	var icons := {
		"body": func(b: Button, c: Vector2):
			b.draw_arc(c + Vector2(0, -7), 4.5, 0, TAU, 20, UiStyle.INK, 2.6, true)
			b.draw_arc(c + Vector2(0, 11), 9, PI, TAU, 20, UiStyle.INK, 2.6, true),
		"hair": func(b: Button, c: Vector2):
			b.draw_arc(c + Vector2(0, 6), 11, PI, TAU, 24, UiStyle.INK, 2.6, true)
			for x in [-5.0, 0.0, 5.0]:
				b.draw_line(c + Vector2(x, -4), c + Vector2(x * 0.8, 3), UiStyle.INK, 2.4, true),
		"skin": func(b: Button, c: Vector2):
			b.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -13), c + Vector2(7, 1),
				c + Vector2(5, 7), c + Vector2(0, 10), c + Vector2(-5, 7), c + Vector2(-7, 1)]), UiStyle.INK)
			b.draw_circle(c + Vector2(0, 3), 7, UiStyle.INK),
	}
	var tips := {"body": "creation.sex", "hair": "creation.hair", "skin": "creation.skin"}
	var y := 150.0
	for sec in SECTIONS:
		var b := UiStyle.diamond_button(64, UiStyle.PLATE, icons[sec])
		b.name = "Section_" + sec
		b.toggle_mode = true
		b.tooltip_text = I18n.t(tips[sec])
		b.position = Vector2(89, y) - b.size / 2.0 + Vector2(0, 46)
		b.pressed.connect(_show_section.bind(sec))
		_box.add_child(b)
		_tabs[sec] = b
		y += 134.0


## The name on a pop ribbon above the coach, typed in place.
func _name_ribbon() -> void:
	var rib := PanelContainer.new()
	rib.position = Vector2(420, 82)
	rib.size = Vector2(340, 56)
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon())
	name_edit = LineEdit.new()
	name_edit.name = "CoachName"
	name_edit.max_length = 20
	name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_edit.placeholder_text = I18n.t("creation.name")
	name_edit.tooltip_text = I18n.t("creation.name")
	name_edit.add_theme_font_override("font", UiStyle.title_font())
	name_edit.add_theme_font_size_override("font_size", 34)
	name_edit.add_theme_constant_override("outline_size", 9)
	name_edit.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
	name_edit.add_theme_color_override("font_color", UiStyle.INK)
	name_edit.add_theme_color_override("font_placeholder_color", Color(UiStyle.INK, 0.6))
	name_edit.add_theme_color_override("caret_color", UiStyle.INK)
	for st in ["normal", "read_only"]:
		name_edit.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	name_edit.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	name_edit.text_changed.connect(func(t): _set_lc("name", t))
	rib.add_child(name_edit)
	_box.add_child(rib)


## The paper sheet at the right: a navy ribbon with the section's name, then
## the section's page (sex, the 14 hair gems or the 11 skin gems).
func _sheet() -> void:
	var sheet := Control.new()
	sheet.name = "Sheet"
	sheet.position = R_SHEET.position
	sheet.size = Vector2(R_SHEET.size.x, 0)
	_box.add_child(sheet)
	var paper := PanelContainer.new()
	var ps: StyleBox = UiStyle.paper(0)
	ps.content_margin_left = 26
	ps.content_margin_right = 26
	ps.content_margin_top = 46
	ps.content_margin_bottom = 30
	paper.add_theme_stylebox_override("panel", ps)
	paper.custom_minimum_size.x = R_SHEET.size.x
	sheet.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	paper.add_child(col)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	var seg := PanelContainer.new()
	var segs := UiStyle.box(Color("f3ddb2"), Color("3b2a1a"), 3, 6)
	segs.set_corner_radius_all(12)
	seg.add_theme_stylebox_override("panel", segs)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	seg.add_child(row)
	_sex_btns[0] = _sex_toggle(row, I18n.t("creation.male"), 0)
	_sex_btns[1] = _sex_toggle(row, I18n.t("creation.female"), 1)
	body.add_child(seg)
	col.add_child(body)
	_pages["body"] = body

	_pages["hair"] = _gems(col, Palettes.HAIR, 14, _hair_cells, "hair", "creation.hair_note")
	_pages["skin"] = _gems(col, Palettes.SKIN, 11, _skin_cells, "skin", "")

	var rib := PanelContainer.new()
	rib.position = Vector2(40, -20)
	rib.size = Vector2(R_SHEET.size.x - 80, 46)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon("navy"))
	_sheet_title = Label.new()
	UiStyle.title(_sheet_title, 24)
	_sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sheet_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(_sheet_title)
	sheet.add_child(rib)


func _gems(parent: Control, palette: Array, n: int, cells: Dictionary, field: String,
		note_key: String) -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 2)
	g.add_theme_constant_override("v_separation", 0)
	page.add_child(g)
	for i in range(n):
		var v: Vector3 = palette[i]
		var b := UiStyle.gem_button(48, Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0),
			clampf(v.z, 0.0, 1.0)))
		b.name = "%s_%d" % [field, i]
		b.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _set_lc(field, i))
		g.add_child(b)
		cells[i] = b
	if note_key != "":
		var note := Label.new()
		note.text = I18n.t(note_key)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		note.add_theme_font_override("font", UiStyle.bold(900))
		note.add_theme_font_size_override("font_size", 13)
		note.add_theme_color_override("font_color", BROWN)
		page.add_child(note)
	parent.add_child(page)
	return page


## Male / Female as the sheet's segmented choice: the picked one raised in
## navy, the other plain on the paper.
func _sex_toggle(parent: Control, text: String, sex: int) -> Button:
	var b := Button.new()
	b.name = "Sex_%d" % sex
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var off := StyleBoxEmpty.new()
	for st in ["normal", "hover", "disabled"]:
		b.add_theme_stylebox_override(st, off)
	var on: StyleBox = UiStyle.button_box("navy", "", 8)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("focus", UiStyle.focus_ring())
	b.add_theme_font_override("font", UiStyle.title_font())
	b.add_theme_font_size_override("font_size", 19)
	b.add_theme_color_override("font_color", BROWN)
	b.add_theme_color_override("font_hover_color", UiStyle.PAPER_INK)
	b.add_theme_color_override("font_pressed_color", UiStyle.INK)
	b.add_theme_color_override("font_hover_pressed_color", UiStyle.INK)
	b.add_theme_constant_override("outline_size", 0)
	b.toggled.connect(func(p): b.add_theme_constant_override("outline_size", 6 if p else 0))
	b.pressed.connect(func(): _set_lc("sex", sex))
	parent.add_child(b)
	return b


func _actions() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.size = Vector2(600, 72)
	row.position = Vector2(REF.x - 40 - 600, REF.y - 30 - 72)
	_box.add_child(row)
	var rnd := Button.new()
	rnd.name = "Random"
	rnd.text = I18n.t("creation.random_btn")
	rnd.tooltip_text = I18n.t("creation.random")
	rnd.custom_minimum_size = Vector2(0, 60)
	rnd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.raised(rnd, "navy", 22, 14)
	rnd.pressed.connect(func(): random_pressed.emit())
	row.add_child(rnd)
	var ok := Button.new()
	ok.name = "Create"
	ok.text = I18n.t("creation.create_btn")
	ok.tooltip_text = I18n.t("creation.validate")
	ok.custom_minimum_size = Vector2(230, 72)
	UiStyle.primary(ok, 34)
	ok.pressed.connect(func(): submit.emit())
	row.add_child(ok)


func _show_section(sec: String) -> void:
	_section = sec
	for k in _tabs:
		_tabs[k].set_pressed_no_signal(k == sec)
		_tabs[k].queue_redraw()
	for k in _pages:
		_pages[k].visible = k == sec
	_sheet_title.text = I18n.t({"body": "creation.body", "hair": "creation.hair_short",
		"skin": "creation.skin_short"}[sec]).to_upper()


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
		_sex_btns[k].add_theme_constant_override("outline_size", 6 if k == sex else 0)
	var hair: int = int(lc.get("hair", 0)) % Palettes.HAIR.size()
	var skin: int = int(lc.get("skin", 0)) % Palettes.SKIN.size()
	for k in _hair_cells:
		_hair_cells[k].set_pressed_no_signal(k == hair)
		_hair_cells[k].queue_redraw()
	for k in _skin_cells:
		_skin_cells[k].set_pressed_no_signal(k == skin)
		_skin_cells[k].queue_redraw()
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


func _relayout() -> void:
	if _box == null:
		return
	# full-rect anchors already size the screen to the viewport; setting
	# size here too only made Godot warn (the old S07 anchor warnings)
	var vp := get_viewport_rect().size
	var s := minf(vp.x / REF.x, vp.y / REF.y)
	_box.scale = Vector2(s, s)
	_box.position = (vp - REF * s) / 2.0
