class_name PippopLogin
extends Control
## Login screen in style B (S45, src/ui/style_b.gd): a light backdrop of its
## own (a giant outlined ARENA, the coach's ghost, a coral band, thin lines),
## the coach and two fighters large and sharp on the left, the name top left,
## and on the right a white form with an ink rule: account, password (with
## its eye), the server, CONECTAR. Everything enters in a cascade.
## Replaces the retail logonDialog; emits `submit(login, password, proxy)`.

signal submit(login: String, password: String, proxy: String)

const UiStyle := preload("res://src/ui/ui_style.gd")
const StyleB := preload("res://src/ui/style_b.gd")
const REF := Vector2(1280, 720)
const LANGS := ["es", "en", "fr"]
const R_FORM := Rect2(836, 132, 400, 0)   # height from its content
const INK := UiStyle.B_INK
const CORAL := UiStyle.B_CORAL

var name_edit: LineEdit
var pass_edit: LineEdit
var reveal_btn: Button  # eye toggle: show / hide the password
var proxy_opt: OptionButton
var err_lbl: Label
var lang_btn: Button
var _lang_menu: PopupMenu
var _box: Control  # REF-sized child, scaled+centered
var _drifts: Array = []
var _t := 0.0
var _figs: Array = []
var _brand: Control
var _form: Control


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiStyle.B_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_box = Control.new()
	_box.size = REF
	_box.clip_contents = true
	_box.theme = UiStyle.theme()
	add_child(_box)
	_drifts = StyleB.backdrop(_box, REF, "ARENA", "PPA // LOGIN · 00", "coach_ghost", Vector2(0.28, 0.45), 380.0)
	_figs = [UiStyle.figure(_box, "fighter_a", Vector2(60, 240), 420),
		UiStyle.figure(_box, "fighter_b", Vector2(430, 230), 430),
		UiStyle.figure(_box, "coach", Vector2(236, 130), 560)]
	_brand_block()
	_language()
	_form_block()
	resized.connect(_relayout)


## Top left: what it is (a tag) and the name, ARENA in coral.
func _brand_block() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(36, 16)
	col.add_theme_constant_override("separation", -6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UiStyle.tag(I18n.t("login.tagline")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var a := Label.new()
	a.text = "PIPPOP"
	UiStyle.display(a, 52)
	row.add_child(a)
	var b := Label.new()
	b.text = "ARENA"
	UiStyle.display(b, 52, CORAL)
	row.add_child(b)
	col.add_child(row)
	_box.add_child(col)
	_brand = col


## Top right: the language, as its code with a globe; a click opens the
## three languages.
func _language() -> void:
	lang_btn = Button.new()
	lang_btn.name = "Language"
	lang_btn.size = Vector2(110, 44)
	lang_btn.position = Vector2(REF.x - 24 - 110, 22)
	lang_btn.tooltip_text = I18n.t("login.language")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		lang_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	lang_btn.draw.connect(func():
		var lit := lang_btn.is_hovered() or lang_btn.has_focus()
		var col := CORAL if lit else INK
		var c := Vector2(lang_btn.size.x - 18, 24)
		lang_btn.draw_arc(c, 10, 0, TAU, 32, col, 2.0, true)
		lang_btn.draw_line(c + Vector2(-10, 0), c + Vector2(10, 0), col, 2.0, true)
		lang_btn.draw_arc(c + Vector2(-6, 0), 12, -0.98, 0.98, 12, col, 1.8, true)
		lang_btn.draw_arc(c + Vector2(6, 0), 12, PI - 0.98, PI + 0.98, 12, col, 1.8, true)
		var f := UiStyle.bold(700)
		var tag := I18n.t("login.language").to_upper()
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		lang_btn.draw_string(f, Vector2(lang_btn.size.x - 40 - tw, 14), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.B_MUTE)
		var code := I18n.lang.to_upper()
		var df := UiStyle.display_font()
		var cw := df.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
		lang_btn.draw_string(df, Vector2(lang_btn.size.x - 40 - cw, 38), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, col))
	for sig in [lang_btn.mouse_entered, lang_btn.mouse_exited, lang_btn.focus_entered, lang_btn.focus_exited]:
		sig.connect(lang_btn.queue_redraw)
	_box.add_child(lang_btn)
	_lang_menu = PopupMenu.new()
	for code in LANGS:
		_lang_menu.add_item(I18n.NAMES[code])
	_lang_menu.id_pressed.connect(func(i):
		I18n.set_locale(LANGS[i])
		lang_btn.queue_redraw())
	_box.add_child(_lang_menu)
	lang_btn.pressed.connect(func():
		var at := lang_btn.get_screen_position() + Vector2(-50, 48) * _box.scale
		_lang_menu.popup(Rect2i(Vector2i(at), Vector2i(160, 0))))


## The form: a white plate with an ink rule, its tag and title, the fields,
## the server, CONECTAR.
func _form_block() -> void:
	var form := PanelContainer.new()
	form.name = "Sheet"
	form.position = R_FORM.position
	form.custom_minimum_size.x = R_FORM.size.x
	var ps := StyleB.plate()
	ps.content_margin_left = 34
	ps.content_margin_right = 34
	ps.content_margin_top = 26
	ps.content_margin_bottom = 30
	form.add_theme_stylebox_override("panel", ps)
	_box.add_child(form)
	_form = form
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	form.add_child(col)
	col.add_child(UiStyle.tag("LOGIN · 00"))
	var head := Label.new()
	head.text = I18n.t("login.ribbon")
	UiStyle.display(head, 44)
	col.add_child(head)
	_gap(col, 6)
	col.add_child(UiStyle.tag(I18n.t("login.user")))
	name_edit = _field(col)
	_gap(col, 6)
	col.add_child(UiStyle.tag(I18n.t("login.pass")))
	pass_edit = _field(col)
	pass_edit.secret = true
	pass_edit.clear_button_enabled = false
	var ps2: StyleBox = pass_edit.get_theme_stylebox("normal").duplicate()
	ps2.content_margin_right = 50
	pass_edit.add_theme_stylebox_override("normal", ps2)
	reveal_btn = Button.new()
	reveal_btn.toggle_mode = true
	reveal_btn.focus_mode = Control.FOCUS_NONE
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
	_gap(col, 6)
	# the server: a small ink box with its live dot
	col.add_child(UiStyle.tag(I18n.t("login.server")))
	proxy_opt = OptionButton.new()
	proxy_opt.name = "Server"
	proxy_opt.tooltip_text = I18n.t("login.server")
	var chip := StyleBoxFlat.new()
	chip.bg_color = INK
	chip.content_margin_left = 26
	chip.content_margin_right = 12
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	var chip_h: StyleBoxFlat = chip.duplicate()
	chip_h.bg_color = INK.lightened(0.15)
	for st in ["normal", "pressed", "hover_pressed", "disabled"]:
		proxy_opt.add_theme_stylebox_override(st, chip)
	proxy_opt.add_theme_stylebox_override("hover", chip_h)
	proxy_opt.add_theme_stylebox_override("focus", UiStyle.box(Color(0, 0, 0, 0), CORAL, 2, 0))
	proxy_opt.add_theme_font_override("font", UiStyle.bold(800))
	proxy_opt.add_theme_font_size_override("font_size", 13)
	proxy_opt.add_theme_constant_override("outline_size", 0)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		proxy_opt.add_theme_color_override(c, Color.WHITE)
	proxy_opt.custom_minimum_size.y = 30
	proxy_opt.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	proxy_opt.draw.connect(func():
		proxy_opt.draw_circle(Vector2(13, proxy_opt.size.y / 2.0), 4, UiStyle.OK))
	col.add_child(proxy_opt)
	err_lbl = Label.new()
	err_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	err_lbl.add_theme_font_override("font", UiStyle.bold(800))
	err_lbl.add_theme_font_size_override("font_size", 14)
	err_lbl.add_theme_color_override("font_color", CORAL)
	err_lbl.visible = false
	col.add_child(err_lbl)
	_gap(col, 10)
	var btn := StyleB.button(true, 34)
	btn.name = "Connect"
	btn.text = I18n.t("net.connect")
	btn.custom_minimum_size.y = 64
	btn.pressed.connect(_do_submit)
	col.add_child(btn)

	name_edit.focus_next = name_edit.get_path_to(pass_edit)
	pass_edit.focus_next = pass_edit.get_path_to(proxy_opt)
	proxy_opt.focus_next = proxy_opt.get_path_to(btn)
	btn.focus_next = btn.get_path_to(lang_btn)
	lang_btn.focus_next = lang_btn.get_path_to(name_edit)


func _ready() -> void:
	_relayout()
	name_edit.grab_focus()
	_enter.call_deferred()


## The entrance: the figures sweep in from the left one after another, the
## name drops, the form rises.
func _enter() -> void:
	StyleB.enter(self, _figs, Vector2(-160, 0), 0.0, 0.09, 0.7)
	StyleB.enter(self, [_brand, lang_btn], Vector2(0, -24), 0.15)
	StyleB.enter(self, [_form], Vector2(60, 0), 0.25, 0.0, 0.6)


func _process(dt: float) -> void:
	_t += dt
	StyleB.drift(_drifts, _t)


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
	e.custom_minimum_size.y = 46
	StyleB.field(e)
	e.clear_button_enabled = true   # the "x" that empties the field
	e.text_submitted.connect(func(_t): _do_submit())
	parent.add_child(e)
	return e


func _gap(parent: Control, h: float) -> void:
	var g := Control.new()
	g.custom_minimum_size.y = h
	parent.add_child(g)


func _on_reveal(on: bool) -> void:
	pass_edit.secret = not on
	reveal_btn.tooltip_text = I18n.t(
		"login.hide_pass" if on else "login.show_pass")
	reveal_btn.queue_redraw()


## An eye drawn over the button; crossed out while the password is hidden.
func _draw_eye() -> void:
	var c := reveal_btn.size / 2.0
	var col := CORAL if reveal_btn.button_pressed else UiStyle.B_MUTE
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var t := -1.0 + i / 8.0
		var y := 7.0 * (1.0 - t * t)
		top.append(c + Vector2(t * 11.0, -y))
		bot.append(c + Vector2(t * 11.0, y))
	reveal_btn.draw_polyline(top, col, 2.0, true)
	reveal_btn.draw_polyline(bot, col, 2.0, true)
	reveal_btn.draw_arc(c, 3.2, 0, TAU, 16, col, 2.0, true)
	if not reveal_btn.button_pressed:
		reveal_btn.draw_line(c + Vector2(-11, 9), c + Vector2(11, -9), col, 2.0, true)


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
