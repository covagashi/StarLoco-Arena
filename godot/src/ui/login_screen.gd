class_name PippopLogin
extends Control
## Login screen in style B (S45, src/ui/style_b.gd): a light backdrop of its
## own (a giant outlined ARENA, the coach's ghost, a coral band, thin lines),
## the coach and two fighters large and sharp on the left, the name top left,
## and on the right a white form with an ink rule: account, password (with
## its eye), the server, CONECTAR. Everything enters in a cascade.
## Replaces the retail logonDialog; emits `submit(login, password, proxy)`.
## In the web demo (S44) the form is one JUGAR button instead: the browser's
## own demo account (DemoAccount), on the page's server.

signal submit(login: String, password: String, proxy: String)
## S51 «Ya tengo cuenta» (demo screens only): log in with an email and its
## password; ask for a reset code; set a new password with it.
signal account_login(email: String, password: String, proxy: String)
signal reset_request(email: String, proxy: String)
signal reset_confirm(email: String, code: String, password: String, proxy: String)

const UiStyle := preload("res://src/ui/ui_style.gd")
const DemoAccount := preload("res://src/web/demo_account.gd")
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
var _back: Control  # the backdrop, scaled to cover the window (W4)
var _drifts: Array = []
var _t := 0.0
var _figs: Array = []
var _brand: Control
var _form: Control
var _play_col: VBoxContainer   # the usual form (JUGAR in the demo)
var _acct: VBoxContainer       # «Ya tengo cuenta» and the reset, in its place
var _acct_mode := ""
var _acct_err: Label
var _acct_go: Button
var _acct_fields := {}         # name -> LineEdit of the shown mode
var _reset_email := ""


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UiStyle.B_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_back = StyleB.back_layer(self, REF)
	_box = Control.new()
	_box.size = REF
	_box.clip_contents = true
	_box.theme = UiStyle.theme()
	add_child(_box)
	_drifts = StyleB.backdrop(_back, REF, "", "", "coach_ghost", Vector2(0.28, 0.45), 380.0, _box)
	# the vex figures (S44, tools/scene_vex) are wider than the old renders:
	# a little smaller and further apart, the coach in front
	_figs = [UiStyle.figure(_box, "fighter_a", Vector2(36, 270), 390),
		UiStyle.figure(_box, "fighter_b", Vector2(450, 262), 398),
		UiStyle.figure(_box, "coach", Vector2(214, 150), 500)]
	for f: Control in _figs:   # they sway on their feet (StyleB.sway)
		f.pivot_offset = f.size * Vector2(0.5, 0.92)
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
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		lang_btn.draw_string(f, Vector2(lang_btn.size.x - 40 - tw, 14), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.B_MUTE)
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
	_play_col = col
	var head := Label.new()
	head.text = I18n.t("login.ribbon")
	UiStyle.display(head, 44)
	col.add_child(head)
	_gap(col, 6)
	var rows: Array[Control] = []   # what the web demo hides
	rows.append(UiStyle.tag(I18n.t("login.user")))
	col.add_child(rows[-1])
	name_edit = _field(col)
	rows.append(name_edit)
	_gap(col, 6)
	rows.append(UiStyle.tag(I18n.t("login.pass")))
	col.add_child(rows[-1])
	pass_edit = _field(col)
	rows.append(pass_edit)
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
	rows.append(UiStyle.tag(I18n.t("login.server")))
	col.add_child(rows[-1])
	proxy_opt = OptionButton.new()
	rows.append(proxy_opt)
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
	proxy_opt.add_theme_font_size_override("font_size", 14)
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
	if DemoAccount.demo_ui():
		for r in rows:
			r.visible = false
		var note := Label.new()
		note.text = I18n.t("login.demo_note")
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size.x = R_FORM.size.x - 68   # wraps at its width from the start
		note.add_theme_font_size_override("font_size", 16)
		note.add_theme_color_override("font_color", INK)
		col.add_child(note)
		col.move_child(note, rows[0].get_index())
		btn.text = I18n.t("login.play")
		btn.pressed.disconnect(_do_submit)
		btn.pressed.connect(_do_play)
		btn.name = "Play"
		# S51: a saved account comes back here — an ink button under JUGAR
		var have := StyleB.button(false, 20)
		have.name = "HaveAccount"
		have.text = I18n.t("login.have_account")
		have.custom_minimum_size.y = 44
		have.pressed.connect(func(): show_account("login"))
		_gap(col, 4)
		col.add_child(have)
		_acct = VBoxContainer.new()
		_acct.name = "Account"
		_acct.add_theme_constant_override("separation", 8)
		_acct.visible = false
		form.add_child(_acct)
		form.reset_size.call_deferred()   # without the hidden rows

	name_edit.focus_next = name_edit.get_path_to(pass_edit)
	pass_edit.focus_next = pass_edit.get_path_to(proxy_opt)
	proxy_opt.focus_next = proxy_opt.get_path_to(btn)
	btn.focus_next = btn.get_path_to(lang_btn)
	lang_btn.focus_next = lang_btn.get_path_to(name_edit)


func _ready() -> void:
	_relayout()
	if name_edit.visible:
		name_edit.grab_focus()
	_enter.call_deferred()
	_mark("login")


## S47: in the browser, the moment a screen is up, for the load test
## (tools/web/load_test.mjs reads window.__pippop); nothing on desktop.
static func _mark(screen: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("(window.__pippop = window.__pippop || {})['%s'] = performance.now()" % screen)


## The entrance: the figures sweep in from the left one after another, the
## name drops, the form rises.
func _enter() -> void:
	StyleB.enter(self, _figs, Vector2(-160, 0), 0.0, 0.09, 0.7)
	StyleB.enter(self, [_brand, lang_btn], Vector2(0, -24), 0.15)
	StyleB.enter(self, [_form], Vector2(60, 0), 0.25, 0.0, 0.6)


func _process(dt: float) -> void:
	_t += dt
	StyleB.drift(_drifts, _t)
	StyleB.sway(_figs, _t)


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
	StyleB.cover(_back, REF, vp)


func _do_submit() -> void:
	var login := name_edit.text.strip_edges()
	if login == "":
		set_error(I18n.t("login.enter_account"))
		return
	var proxy := ""
	if proxy_opt.selected >= 0:
		proxy = proxy_opt.get_item_text(proxy_opt.selected)
	submit.emit(login, pass_edit.text, proxy)


## The web demo's JUGAR: this browser's account — the demo one, made on
## first use, or the saved one (email + device key, S51).
func _do_play() -> void:
	var acc := DemoAccount.load_or_create()
	submit.emit(acc.login, acc.password, _proxy())


## The server picked (the web build ignores it: one server).
func _proxy() -> String:
	if proxy_opt.selected >= 0:
		return proxy_opt.get_item_text(proxy_opt.selected)
	return ""


## --- «Ya tengo cuenta» (S51) ---------------------------------------------------
## The plate swaps JUGAR for one of three small forms: "login" (correo,
## contraseña, ENTRAR, ¿Olvidaste la contraseña?), "forgot" (correo, ENVIAR
## CÓDIGO), "reset" (código, contraseña nueva ×2, CAMBIAR Y ENTRAR); "" goes
## back to JUGAR. main.gd answers through set_account_error / reset_sent.
func show_account(mode: String) -> void:
	if _acct == null:
		return
	var keep_email := ""
	if _acct_fields.has("email"):
		keep_email = (_acct_fields.email as LineEdit).text
	_acct_mode = mode
	_play_col.visible = mode == ""
	_acct.visible = mode != ""
	# the code form is the tallest: the plate starts a little higher
	_form.position.y = R_FORM.position.y - (28.0 if mode == "reset" else 0.0)
	_acct.add_theme_constant_override("separation", 6 if mode == "reset" else 8)
	for c in _acct.get_children():
		_acct.remove_child(c)
		c.queue_free()
	_acct_fields = {}
	set_error("")
	if mode != "":
		var head := Label.new()
		head.name = "AccountTitle"
		head.text = I18n.t("login.acct.%s_title" % mode)
		head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		head.custom_minimum_size.x = R_FORM.size.x - 68
		UiStyle.display(head, 30)
		head.add_theme_constant_override("line_spacing", -10)
		_acct.add_child(head)
		var text := I18n.t("login.acct.%s_text" % mode, {"email": _reset_email})
		if text != "":
			var note := Label.new()
			note.text = text
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size.x = R_FORM.size.x - 68
			note.add_theme_font_size_override("font_size", 14)
			note.add_theme_constant_override("line_spacing", -4)
			note.add_theme_color_override("font_color", INK)
			_acct.add_child(note)
		_gap(_acct, 2)
		match mode:
			"login":
				_acct_field("email", "save.email", false, keep_email)
				_acct_field("password", "save.password", true)
			"forgot":
				_acct_field("email", "save.email", false, keep_email)
			"reset":
				_acct_field("code", "login.acct.code", false)
				(_acct_fields.code as LineEdit).max_length = 6
				_acct_field("password", "save.new_password", true)
				_acct_field("again", "save.again", true)
		_acct_err = Label.new()
		_acct_err.name = "AccountError"
		_acct_err.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_acct_err.custom_minimum_size.x = R_FORM.size.x - 68
		_acct_err.add_theme_font_override("font", UiStyle.bold(800))
		_acct_err.add_theme_font_size_override("font_size", 14)
		_acct_err.add_theme_color_override("font_color", CORAL)
		_acct_err.visible = false
		_acct.add_child(_acct_err)
		_gap(_acct, 4)
		_acct_go = StyleB.button(true, 24)
		_acct_go.name = "AccountGo"
		_acct_go.text = I18n.t("login.acct.%s_go" % mode)
		_acct_go.custom_minimum_size.y = 50
		_acct_go.pressed.connect(_acct_submit)
		_acct.add_child(_acct_go)
		var links := HBoxContainer.new()
		links.add_theme_constant_override("separation", 18)
		_acct.add_child(links)
		if mode == "login":
			links.add_child(_link("Forgot", "login.acct.forgot", func(): show_account("forgot")))
		if mode == "reset":
			links.add_child(_link("Resend", "login.acct.resend", func(): show_account("forgot")))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		links.add_child(sp)
		links.add_child(_link("Back", "login.acct.back", func(): show_account("")))
		var first: LineEdit = _acct_fields.values()[0]
		if first.text != "" and _acct_fields.size() > 1:
			first = _acct_fields.values()[1]
		first.grab_focus.call_deferred()
	_form.reset_size.call_deferred()


func account_mode() -> String:
	return _acct_mode


## A server or local error under the shown form ("" hides it); the
## button comes back.
func set_account_error(msg: String) -> void:
	if _acct_err == null or not is_instance_valid(_acct_err):
		set_error(msg)
		return
	_acct_err.text = msg
	_acct_err.visible = msg != ""
	set_account_busy(false)


func set_account_busy(on: bool) -> void:
	if _acct_go != null and is_instance_valid(_acct_go):
		_acct_go.disabled = on


## 60075 "sent": on to the code form.
func reset_sent() -> void:
	show_account("reset")


func _acct_field(key: String, tag_key: String, secret: bool, initial := "") -> void:
	var t := UiStyle.tag(I18n.t(tag_key))
	_acct.add_child(t)
	var e := LineEdit.new()
	e.name = "Acct" + key.capitalize()
	e.custom_minimum_size.y = 42
	StyleB.field(e, 18)
	e.secret = secret
	e.text = initial
	e.max_length = 72 if secret else 64
	e.text_submitted.connect(func(_t): _acct_submit())
	_acct.add_child(e)
	_acct_fields[key] = e


func _link(node_name: String, key: String, cb: Callable) -> LinkButton:
	var l := LinkButton.new()
	l.name = node_name
	l.text = I18n.t(key)
	l.add_theme_font_override("font", UiStyle.bold(800))
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", INK)
	l.add_theme_color_override("font_hover_color", CORAL)
	l.add_theme_color_override("font_focus_color", CORAL)
	l.add_theme_color_override("font_pressed_color", CORAL)
	l.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	l.pressed.connect(cb)
	return l


func _acct_text(key: String) -> String:
	return (_acct_fields[key] as LineEdit).text if _acct_fields.has(key) else ""


func _acct_submit() -> void:
	if _acct_go != null and _acct_go.disabled:
		return
	var err := ""
	match _acct_mode:
		"login":
			var email := _acct_text("email").strip_edges().to_lower()
			err = DemoAccount.check_email(email)
			if err == "" and _acct_text("password") == "":
				err = "login.acct.no_password"
			if err == "":
				set_account_error("")
				set_account_busy(true)
				account_login.emit(email, _acct_text("password"), _proxy())
		"forgot":
			var email := _acct_text("email").strip_edges().to_lower()
			err = DemoAccount.check_email(email)
			if err == "":
				_reset_email = email
				set_account_error("")
				set_account_busy(true)
				reset_request.emit(email, _proxy())
		"reset":
			var code := _acct_text("code").strip_edges()
			if code.length() != 6 or not code.is_valid_int():
				err = "login.acct.code_format"
			else:
				err = DemoAccount.check_password(_acct_text("password"), _acct_text("again"))
			if err == "":
				set_account_error("")
				set_account_busy(true)
				reset_confirm.emit(_reset_email, code, _acct_text("password"), _proxy())
	if err != "":
		set_account_error(I18n.t(err))
