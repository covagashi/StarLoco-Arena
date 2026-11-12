class_name PippopCoachCreation
extends Control
## Coach creation in style B (S45, src/ui/style_b.gd): a light studio of its
## own (a giant outlined COACH, a height chart behind the figure, thin
## lines), the back button and the title top left, the three sections as a
## numbered list on the left, the 3D coach large in the middle with the
## chevrons that turn it, and on the right a white form with the name and the
## section's choices (sex, the 14 hair colours, the 11 skin colours); "Al
## azar" and "¡CREAR!" at the bottom right. Drives the shared `localCoach`
## model so the existing handlers (_on_localcoach_changed/_on_coach_dir/
## _on_coach_random/_on_coach_create) keep working unchanged.

signal dir_pressed(d: int)
signal random_pressed
signal submit
signal closed

const UiStyle := preload("res://src/ui/ui_style.gd")
const StyleB := preload("res://src/ui/style_b.gd")
const Direction8 := preload("res://src/util/direction8.gd")
const REF := Vector2(1280, 720)
const FOOT := Vector2(560, 636)
const DOLL_SCALE := 6.0
const R_FORM := Rect2(860, 118, 380, 0)
const SECTIONS := ["body", "hair", "skin"]
const INK := UiStyle.B_INK
const CORAL := UiStyle.B_CORAL

var _box: Control
var _model                   # GuiLib model — localCoach lives here
var _spr                     # AnmSprite paper-doll (the 3D coach)
var name_edit: LineEdit
var _sex_btns := {}
var _hair_cells := {}
var _skin_cells := {}
var _tabs := {}              # section -> list Button
var _pages := {}             # section -> its Control on the form
var _sheet_title: Label
var _sheet_tag: Label
var _section := "hair"
var _drifts: Array = []
var _t := 0.0
var _head: Control
var _form: Control
var _list: Array = []
var _acts: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.size = REF
	_box.clip_contents = true
	_box.theme = UiStyle.theme()
	add_child(_box)
	_drifts = StyleB.backdrop(_box, REF, "COACH", "PPA // CREATE · 02", "", Vector2(0.45, 0.45), 400.0)
	_box.add_child(_height_chart())
	_header()
	_section_list()
	var shadow := Control.new()
	shadow.size = REF
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.draw.connect(func():
		shadow.draw_set_transform(FOOT + Vector2(0, -4), 0.0, Vector2(1.0, 0.22))
		shadow.draw_circle(Vector2.ZERO, 150, Color(INK, 0.12))
		shadow.draw_arc(Vector2.ZERO, 175, 0, TAU, 64, Color(INK, 0.35), 3.0, true)
		shadow.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE))
	_box.add_child(shadow)
	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = FOOT
	_spr.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	_box.add_child(_spr)
	for left in [true, false]:
		var b := UiStyle.chevron_button(left, INK)
		b.name = "TurnLeft" if left else "TurnRight"
		b.scale = Vector2(0.6, 0.6)
		b.position = FOOT + Vector2(-230 if left else 198, -300)
		b.tooltip_text = I18n.t("creation.rotate_left" if left else "creation.rotate_right")
		b.pressed.connect(func(): dir_pressed.emit(-1 if left else 1))
		_box.add_child(b)
	_form_block()
	_actions()
	_show_section(_section)
	resized.connect(_relayout)


## A tailor's height chart behind the figure: a rule with ticks every
## 20 px, a longer one and a number every 100.
func _height_chart() -> Control:
	var c := Control.new()
	c.size = REF
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var x := FOOT.x + 250.0
		c.draw_line(Vector2(x, 130), Vector2(x, FOOT.y), Color(INK, 0.3), 1.0)
		var f := UiStyle.bold(700)
		var n := 0
		var y := FOOT.y
		while y >= 130.0:
			var long := n % 5 == 0
			c.draw_line(Vector2(x - (12 if long else 6), y), Vector2(x, y), Color(INK, 0.35 if long else 0.2), 1.0)
			if long:
				c.draw_string(f, Vector2(x + 6, y + 4), "%.1f" % (n * 0.2), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.B_FAINT)
			y -= 20.0
			n += 1)
	return c


## Top left: back (an ink box), the tag and the title.
func _header() -> void:
	var back := StyleB.button(false, 26)
	back.name = "Back"
	back.text = "‹"
	back.size = Vector2(58, 52)
	back.position = Vector2(24, 20)
	back.tooltip_text = I18n.t("panel.close")
	back.pressed.connect(func(): closed.emit())
	_box.add_child(back)
	var col := VBoxContainer.new()
	col.position = Vector2(96, 16)
	col.add_theme_constant_override("separation", -4)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UiStyle.tag("NEW COACH · 02"))
	var t := Label.new()
	t.text = I18n.t("creation.title")
	UiStyle.display(t, 44)
	col.add_child(t)
	_box.add_child(col)
	_head = col


## The three sections as a numbered list on the left (the picked one in
## coral, underlined).
func _section_list() -> void:
	var keys := {"body": "creation.body", "hair": "creation.hair_short", "skin": "creation.skin_short"}
	var tips := {"body": "creation.sex", "hair": "creation.hair", "skin": "creation.skin"}
	var y := 150.0
	var n := 1
	for sec in SECTIONS:
		var b := Button.new()
		b.name = "Section_" + sec
		b.toggle_mode = true
		b.text = I18n.t(keys[sec]).to_upper()
		b.tooltip_text = I18n.t(tips[sec])
		b.position = Vector2(28, y)
		b.size = Vector2(220, 56)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var e := StyleBoxEmpty.new()
			e.content_margin_left = 40
			b.add_theme_stylebox_override(st, e)
		b.add_theme_font_override("font", UiStyle.display_font())
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_constant_override("outline_size", 0)
		for col in ["font_color", "font_disabled_color"]:
			b.add_theme_color_override(col, INK)
		for col in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(col, CORAL)
		var num := "%02d" % n
		b.draw.connect(func():
			b.draw_string(UiStyle.bold(700), Vector2(0, 34), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiStyle.B_FAINT)
			if b.button_pressed:
				b.draw_line(Vector2(40, 48), Vector2(200, 48), CORAL, 3.0))
		for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
			sig.connect(b.queue_redraw)
		b.toggled.connect(func(_on): b.queue_redraw())
		b.pressed.connect(_show_section.bind(sec))
		_box.add_child(b)
		_tabs[sec] = b
		_list.append(b)
		y += 64.0
		n += 1


## The form on the right: the name, then the section's tag, title and choices.
func _form_block() -> void:
	var form := PanelContainer.new()
	form.name = "Sheet"
	form.position = R_FORM.position
	form.custom_minimum_size.x = R_FORM.size.x
	var ps := StyleB.plate()
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 24
	ps.content_margin_bottom = 28
	form.add_theme_stylebox_override("panel", ps)
	_box.add_child(form)
	_form = form
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	form.add_child(col)
	col.add_child(UiStyle.tag(I18n.t("creation.name")))
	name_edit = LineEdit.new()
	name_edit.name = "CoachName"
	name_edit.max_length = 20
	name_edit.custom_minimum_size.y = 52
	name_edit.placeholder_text = I18n.t("creation.name")
	StyleB.field(name_edit, 30)
	name_edit.add_theme_font_override("font", UiStyle.display_font())
	name_edit.text_changed.connect(func(t): _set_lc("name", t))
	col.add_child(name_edit)
	var gap := Control.new()
	gap.custom_minimum_size.y = 8
	col.add_child(gap)
	_sheet_tag = UiStyle.tag("")
	col.add_child(_sheet_tag)
	_sheet_title = Label.new()
	UiStyle.display(_sheet_title, 34)
	col.add_child(_sheet_title)
	# body: male / female as two slanted boxes (ink when picked)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	_sex_btns[0] = _sex_toggle(body, I18n.t("creation.male"), 0)
	_sex_btns[1] = _sex_toggle(body, I18n.t("creation.female"), 1)
	col.add_child(body)
	_pages["body"] = body
	_pages["hair"] = _swatches(col, Palettes.HAIR, 14, _hair_cells, "hair", "creation.hair_note")
	_pages["skin"] = _swatches(col, Palettes.SKIN, 11, _skin_cells, "skin", "")


func _swatches(parent: Control, palette: Array, n: int, cells: Dictionary, field: String,
		note_key: String) -> Control:
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	page.add_child(g)
	for i in range(n):
		var v: Vector3 = palette[i]
		var colour := Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))
		var b := Button.new()
		b.name = "%s_%d" % [field, i]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(46, 46)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.draw.connect(func():
			var r := Rect2(Vector2(3, 3), b.size - Vector2(6, 12))
			b.draw_rect(r, colour)
			if b.button_pressed:
				b.draw_rect(r.grow(2), INK, false, 3.0)
				b.draw_line(Vector2(3, b.size.y - 3), Vector2(b.size.x - 3, b.size.y - 3), CORAL, 3.0)
			elif b.is_hovered() or b.has_focus():
				b.draw_rect(r.grow(1), CORAL, false, 2.0)
			else:
				b.draw_rect(r, Color(INK, 0.15), false, 1.0))
		for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
			sig.connect(b.queue_redraw)
		b.toggled.connect(func(_on): b.queue_redraw())
		b.pressed.connect(func(): _set_lc(field, i))
		g.add_child(b)
		cells[i] = b
	if note_key != "":
		var note := Label.new()
		note.text = I18n.t(note_key)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_override("font", UiStyle.bold(800))
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", UiStyle.B_MUTE)
		page.add_child(note)
	parent.add_child(page)
	return page


## Male / Female: ink slanted boxes when picked, plain text otherwise.
func _sex_toggle(parent: Control, text: String, sex: int) -> Button:
	var b := Button.new()
	b.name = "Sex_%d" % sex
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(col, Color(0, 0, 0, 0))
	b.draw.connect(func():
		var s := b.size
		var on := b.button_pressed
		var face := PackedVector2Array([Vector2(12, 0), Vector2(s.x, 0), Vector2(s.x - 12, s.y), Vector2(0, s.y)])
		if on:
			b.draw_colored_polygon(face, INK)
		else:
			var loop := face.duplicate()
			loop.append(face[0])
			b.draw_polyline(loop, CORAL if b.is_hovered() or b.has_focus() else Color(INK, 0.3), 2.0, true)
		var f := UiStyle.display_font()
		var t := b.text.to_upper()
		var ts := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		b.draw_string(f, Vector2((s.x - ts.x) * 0.5, s.y * 0.5 + 7), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20,
			Color.WHITE if on else INK))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
		sig.connect(b.queue_redraw)
	b.toggled.connect(func(_on): b.queue_redraw())
	b.pressed.connect(func(): _set_lc("sex", sex))
	parent.add_child(b)
	return b


## "Al azar" and "¡CREAR!" close the form (inside it, under the choices).
func _actions() -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = 14
	_form.get_child(0).add_child(gap)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_form.get_child(0).add_child(row)
	_acts = row
	var rnd := StyleB.button(false, 22)
	rnd.name = "Random"
	rnd.text = I18n.t("creation.random_btn")
	rnd.tooltip_text = I18n.t("creation.random")
	rnd.custom_minimum_size = Vector2(130, 52)
	rnd.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rnd.pressed.connect(func(): random_pressed.emit())
	row.add_child(rnd)
	var ok := StyleB.button(true, 34)
	ok.name = "Create"
	ok.text = I18n.t("creation.create_btn")
	ok.tooltip_text = I18n.t("creation.validate")
	ok.custom_minimum_size = Vector2(0, 64)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(func(): submit.emit())
	row.add_child(ok)


func _show_section(sec: String) -> void:
	_section = sec
	for k in _tabs:
		_tabs[k].set_pressed_no_signal(k == sec)
		_tabs[k].queue_redraw()
	for k in _pages:
		_pages[k].visible = k == sec
	var i := SECTIONS.find(sec) + 1
	_sheet_tag.text = ("%02d · " % i) + I18n.t({"body": "creation.sex", "hair": "creation.hair",
		"skin": "creation.skin"}[sec]).to_upper()
	_sheet_title.text = I18n.t({"body": "creation.body", "hair": "creation.hair_short",
		"skin": "creation.skin_short"}[sec])
	_form.size = Vector2.ZERO   # back to its content's height


func _ready() -> void:
	_relayout()
	name_edit.grab_focus()
	_enter.call_deferred()


## The entrance: the coach sweeps in, the title drops, the list types in,
## the form and the actions rise.
func _enter() -> void:
	var to: Vector2 = _spr.position
	_spr.position = to - Vector2(180, 0)
	_spr.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spr, "position", to, 0.7)
	tw.tween_property(_spr, "modulate:a", 1.0, 0.35)
	StyleB.enter(self, [_head], Vector2(0, -24), 0.1)
	StyleB.enter(self, _list, Vector2(-30, 0), 0.2, 0.07, 0.4)
	StyleB.enter(self, [_form], Vector2(60, 0), 0.25, 0.0, 0.6)


func _process(dt: float) -> void:
	_t += dt
	StyleB.drift(_drifts, _t)


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
		_sex_btns[k].queue_redraw()
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
	var dir: int = int(lc.get("actorDirection", 3)) & 7
	if lc.get("actorMaterial") is Dictionary:
		_spr.tints = lc["actorMaterial"]
	# the same wire table as the lobby (Direction8): 1–3 face the camera
	if not Direction8.load_idle(_spr, lib, dir, "AnimMenu") \
			and not Direction8.load_idle(_spr, lib, dir):
		Direction8.load_idle_any(_spr, lib)


func _relayout() -> void:
	if _box == null:
		return
	# full-rect anchors already size the screen to the viewport; setting
	# size here too only made Godot warn (the old S07 anchor warnings)
	var vp := get_viewport_rect().size
	var s := minf(vp.x / REF.x, vp.y / REF.y)
	_box.scale = Vector2(s, s)
	_box.position = (vp - REF * s) / 2.0
