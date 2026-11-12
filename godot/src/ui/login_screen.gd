class_name PippopLogin
extends Control
## Login screen, as in the S45 mockup (sprints/S45, "1 · Inicio de sesión"):
## an arena in 3D behind, the coach and two fighters large on the left, the
## logo on a ribbon, and on the right a tilted sheet of paper with its ribbon
## ("¡A LA ARENA!"), the fields and CONECTAR. Replaces the retail logonDialog;
## emits `submit(login, password, proxy)`.

signal submit(login: String, password: String, proxy: String)

const UiStyle := preload("res://src/ui/ui_style.gd")
const REF := Vector2(1280, 720)
const LANGS := ["es", "en", "fr"]
const R_SHEET := Rect2(810, 100, 400, 0)   # the mockup's right: 70px; height from its content
const BROWN := Color("7a4a1e")

## The mockup's vignette over the arena (radial-gradient(80% 100% at 30% 70%,
## transparent, rgba(18,21,42,.5) 55%, rgba(12,14,30,.95))) and the warm glow
## under the figures, in one pass.
const _SHADE := """shader_type canvas_item;
uniform vec2 ref = vec2(1280.0, 720.0);
void fragment() {
	vec2 p = UV * ref;
	float d = length((p - vec2(384.0, 504.0)) / vec2(1024.0, 720.0));
	float a = d < 0.55 ? mix(0.0, 0.5, d / 0.55) : mix(0.5, 0.95, clamp((d - 0.55) / 0.45, 0.0, 1.0));
	vec3 col = mix(vec3(0.071, 0.082, 0.165), vec3(0.047, 0.055, 0.118), smoothstep(0.55, 1.0, d));
	float g = length((p - vec2(350.0, 650.0)) / vec2(280.0, 60.0));
	vec4 glow = vec4(1.0, 0.6, 0.3, g < 0.6 ? mix(0.5, 0.12, g / 0.6) : mix(0.12, 0.0, clamp((g - 0.6) / 0.4, 0.0, 1.0)));
	COLOR = vec4(col, a);
	COLOR = vec4(mix(COLOR.rgb, glow.rgb, glow.a), max(COLOR.a, glow.a));
}"""

var name_edit: LineEdit
var pass_edit: LineEdit
var reveal_btn: Button  # eye toggle: show / hide the password
var proxy_opt: OptionButton
var err_lbl: Label
var lang_btn: Button
var _lang_lbl: Label
var _lang_menu: PopupMenu
var _box: Control  # REF-sized child, scaled+centered


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var night := ColorRect.new()
	night.color = UiStyle.NIGHT
	night.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)
	_box = Control.new()
	_box.size = REF
	_box.clip_contents = true
	_box.theme = UiStyle.theme()
	add_child(_box)
	_scene()
	_logo()
	_language()
	_sheet()
	resized.connect(_relayout)


## The arena (background-position 10% 50%, 1500px wide), the shade and the
## three figures where the mockup has them.
func _scene() -> void:
	var tex := UiStyle.scene_texture("arena_bg")
	if tex != null:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		var sz := Vector2(1500, 1500.0 * tex.get_height() / tex.get_width())
		bg.size = sz
		bg.position = Vector2(0.1 * (REF.x - sz.x), 0.5 * (REF.y - sz.y))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(bg)
	var shade := ColorRect.new()
	shade.size = REF
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = _SHADE
	shade.material = mat
	_box.add_child(shade)
	UiStyle.figure(_box, "fighter_a", Vector2(70, 250), 420)
	UiStyle.figure(_box, "fighter_b", Vector2(420, 240), 430)
	UiStyle.figure(_box, "coach", Vector2(236, 150), 540)


## PIPPOP on a pop ribbon, ARENA large in sun, two sparkles.
func _logo() -> void:
	var rib := PanelContainer.new()
	rib.position = Vector2(78, 24)
	rib.custom_minimum_size.y = 40
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon())
	var brand := Label.new()
	brand.text = "PIPPOP"
	UiStyle.title(brand, 28)
	var spaced := FontVariation.new()
	spaced.base_font = UiStyle.title_font()
	spaced.spacing_glyph = 3
	brand.add_theme_font_override("font", spaced)
	brand.add_theme_constant_override("shadow_offset_y", 3)
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(brand)
	_box.add_child(rib)
	var title := Label.new()
	title.text = "ARENA"
	title.position = Vector2(60, 46)
	UiStyle.title(title, 120, UiStyle.GOLD)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_constant_override("shadow_outline_size", 18)
	title.add_theme_constant_override("shadow_offset_y", 7)
	_box.add_child(title)
	var sparks := Control.new()
	sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparks.size = REF
	sparks.draw.connect(func():
		var w := UiStyle.title_font().get_string_size("ARENA", HORIZONTAL_ALIGNMENT_LEFT, -1, 120).x
		var x := 60.0 + w
		UiStyle.draw_spark(sparks, Vector2(x + 3, 76), 23, UiStyle.INK)
		UiStyle.draw_spark(sparks, Vector2(x + 5, 116), 11, UiStyle.GOLD))
	_box.add_child(sparks)


## A globe medallion top right, the language code beside it; a click opens
## the three languages.
func _language() -> void:
	lang_btn = UiStyle.medal_button(50, func(b: Button):
		var c := Vector2(25, 25)
		var col := UiStyle.INK
		b.draw_arc(c, 9, 0, TAU, 32, col, 2.4, true)
		b.draw_line(c + Vector2(-9, 0), c + Vector2(9, 0), col, 2.4, true)
		b.draw_arc(c + Vector2(-6, 0), 10.8, -0.98, 0.98, 12, col, 2.0, true)
		b.draw_arc(c + Vector2(6, 0), 10.8, PI - 0.98, PI + 0.98, 12, col, 2.0, true))
	lang_btn.name = "Language"
	lang_btn.position = Vector2(REF.x - 22 - 50, 20)
	lang_btn.tooltip_text = I18n.t("login.language")
	_box.add_child(lang_btn)
	_lang_lbl = Label.new()
	UiStyle.title(_lang_lbl, 16)
	_lang_lbl.add_theme_constant_override("outline_size", 6)
	_lang_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lang_lbl.size = Vector2(60, 24)
	_lang_lbl.position = Vector2(REF.x - 80 - 60, 32)
	_box.add_child(_lang_lbl)
	_lang_menu = PopupMenu.new()
	for code in LANGS:
		_lang_menu.add_item(I18n.NAMES[code])
	_lang_menu.id_pressed.connect(func(i):
		I18n.set_locale(LANGS[i])
		_show_lang())
	_box.add_child(_lang_menu)
	lang_btn.pressed.connect(func():
		var at := lang_btn.get_screen_position() + Vector2(-110, 56) * _box.scale
		_lang_menu.popup(Rect2i(Vector2i(at), Vector2i(160, 0))))
	_show_lang()


func _show_lang() -> void:
	_lang_lbl.text = I18n.lang.to_upper()


## The sheet: paper with its stitch, a perforated left edge and the ribbon
## across the top, tilted 1.5°.
func _sheet() -> void:
	var sheet := Control.new()
	sheet.name = "Sheet"
	sheet.position = R_SHEET.position
	sheet.size = Vector2(R_SHEET.size.x, 440)
	sheet.pivot_offset = sheet.size / 2.0
	sheet.rotation_degrees = 1.5
	_box.add_child(sheet)
	var paper := PanelContainer.new()
	var ps: StyleBox = UiStyle.paper(0)
	ps.content_margin_left = 42
	ps.content_margin_right = 34
	ps.content_margin_top = 54
	ps.content_margin_bottom = 34
	paper.add_theme_stylebox_override("panel", ps)
	paper.size.x = R_SHEET.size.x
	sheet.add_child(paper)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	paper.add_child(col)

	var acc := VBoxContainer.new()
	acc.add_theme_constant_override("separation", 4)
	acc.add_child(UiStyle.paper_caption(I18n.t("login.user")))
	name_edit = _field(acc)
	col.add_child(acc)

	var pw := VBoxContainer.new()
	pw.add_theme_constant_override("separation", 4)
	pw.add_child(UiStyle.paper_caption(I18n.t("login.pass")))
	pass_edit = _field(pw)
	pass_edit.secret = true
	pass_edit.clear_button_enabled = false
	pass_edit.add_theme_constant_override("minimum_character_width", 0)
	var ps2: StyleBox = pass_edit.get_theme_stylebox("normal").duplicate()
	ps2.content_margin_right = 50
	pass_edit.add_theme_stylebox_override("normal", ps2)
	reveal_btn = Button.new()
	reveal_btn.toggle_mode = true
	reveal_btn.focus_mode = Control.FOCUS_NONE
	reveal_btn.flat = true
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		reveal_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	reveal_btn.tooltip_text = I18n.t("login.show_pass")
	reveal_btn.toggled.connect(_on_reveal)
	reveal_btn.draw.connect(_draw_eye)
	reveal_btn.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	reveal_btn.offset_left = -46
	reveal_btn.offset_right = -6
	reveal_btn.offset_top = -20
	reveal_btn.offset_bottom = 20
	pass_edit.add_child(reveal_btn)
	col.add_child(pw)

	# the server, as the mockup's green chip
	var srv := HBoxContainer.new()
	srv.add_theme_constant_override("separation", 10)
	proxy_opt = OptionButton.new()
	proxy_opt.name = "Server"
	proxy_opt.tooltip_text = I18n.t("login.server")
	var chip := UiStyle.box(UiStyle.OK, UiStyle.RIM, 2, 6)
	chip.set_corner_radius_all(8)
	chip.content_margin_left = 26
	chip.content_margin_right = 12
	var chip_h: StyleBoxFlat = chip.duplicate()
	chip_h.bg_color = UiStyle.OK.lightened(0.15)
	for st in ["normal", "pressed", "hover_pressed", "disabled"]:
		proxy_opt.add_theme_stylebox_override(st, chip)
	proxy_opt.add_theme_stylebox_override("hover", chip_h)
	proxy_opt.add_theme_font_override("font", UiStyle.bold(900))
	proxy_opt.add_theme_font_size_override("font_size", 14)
	proxy_opt.add_theme_constant_override("outline_size", 0)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		proxy_opt.add_theme_color_override(c, Color("08261a"))
	proxy_opt.custom_minimum_size.y = 32
	proxy_opt.draw.connect(func():
		proxy_opt.draw_circle(Vector2(14, proxy_opt.size.y / 2.0), 4, Color("0b3a24")))
	srv.add_child(proxy_opt)
	col.add_child(srv)

	var btn := Button.new()
	btn.name = "Connect"
	btn.text = I18n.t("net.connect").to_upper()
	btn.custom_minimum_size.y = 66
	UiStyle.raised(btn, "pop", 34)
	btn.pressed.connect(_do_submit)
	col.add_child(btn)

	err_lbl = Label.new()
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.add_theme_font_override("font", UiStyle.bold(900))
	err_lbl.add_theme_font_size_override("font_size", 15)
	err_lbl.add_theme_color_override("font_color", Color("b23a12"))
	err_lbl.visible = false
	col.add_child(err_lbl)

	# the perforated left edge: holes punched through to the night
	var perf := Control.new()
	perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	perf.position = Vector2(-3, 0)
	perf.draw.connect(func():
		var y := 13.0
		while y < paper.size.y - 8:
			perf.draw_circle(Vector2(0, y), 9.5, UiStyle.NIGHT)
			y += 26.0)
	sheet.add_child(perf)
	paper.resized.connect(func():
		perf.size = Vector2(20, paper.size.y)
		perf.queue_redraw())

	var rib := PanelContainer.new()
	rib.position = Vector2(-24, -22)
	rib.size = Vector2(R_SHEET.size.x + 48, 54)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon())
	var rl := Label.new()
	rl.text = I18n.t("login.ribbon")
	UiStyle.title(rl, 30)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(rl)
	sheet.add_child(rib)

	name_edit.focus_next = name_edit.get_path_to(pass_edit)
	pass_edit.focus_next = pass_edit.get_path_to(proxy_opt)
	proxy_opt.focus_next = proxy_opt.get_path_to(btn)
	btn.focus_next = btn.get_path_to(lang_btn)
	lang_btn.focus_next = lang_btn.get_path_to(name_edit)


func _ready() -> void:
	_relayout()
	name_edit.grab_focus()


func set_proxies(list: Array, selected: String) -> void:
	proxy_opt.clear()
	for h in list:
		proxy_opt.add_item(str(h))
	var i := list.find(selected)
	proxy_opt.selected = i if i >= 0 else 0


func set_error(msg: String) -> void:
	err_lbl.text = msg
	err_lbl.visible = msg != ""


func _field(parent: Control) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size.y = 48
	UiStyle.paper_field(e)
	e.clear_button_enabled = true   # the "x" that empties the field
	e.text_submitted.connect(func(_t): _do_submit())
	parent.add_child(e)
	return e


func _on_reveal(on: bool) -> void:
	pass_edit.secret = not on
	reveal_btn.tooltip_text = I18n.t(
		"login.hide_pass" if on else "login.show_pass")
	reveal_btn.queue_redraw()


## An eye drawn over the button; crossed out while the password is hidden.
func _draw_eye() -> void:
	var c := reveal_btn.size / 2.0
	var col := UiStyle.PRESSED if reveal_btn.button_pressed else BROWN
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var t := -1.0 + i / 8.0
		var y := 7.0 * (1.0 - t * t)
		top.append(c + Vector2(t * 11.0, -y))
		bot.append(c + Vector2(t * 11.0, y))
	reveal_btn.draw_polyline(top, col, 2.4, true)
	reveal_btn.draw_polyline(bot, col, 2.4, true)
	reveal_btn.draw_arc(c, 3.2, 0, TAU, 16, col, 2.4, true)
	if not reveal_btn.button_pressed:
		reveal_btn.draw_line(c + Vector2(-11, 9), c + Vector2(11, -9),
			col, 2.4, true)


func _relayout() -> void:
	if _box == null:
		return
	# full-rect anchors already size the screen to the viewport; setting
	# size here too only made Godot warn (the old S07 anchor warnings)
	var vp := get_viewport_rect().size
	var s := minf(vp.x / REF.x, vp.y / REF.y)
	_box.scale = Vector2(s, s)
	_box.position = (vp - REF * s) / 2.0


func _do_submit() -> void:
	var login := name_edit.text.strip_edges()
	if login == "":
		set_error(I18n.t("login.enter_account"))
		return
	var proxy := ""
	if proxy_opt.selected >= 0:
		proxy = proxy_opt.get_item_text(proxy_opt.selected)
	submit.emit(login, pass_edit.text, proxy)
