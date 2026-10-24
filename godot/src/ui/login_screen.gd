class_name PippopLogin
extends Control
## Login screen (src/ui/ui_style.gd): the stone backdrop, the title, one
## window with the three fields and one primary button. Replaces the retail logonDialog; emits
## `submit(login, password, proxy)`.

signal submit(login: String, password: String, proxy: String)

const UiStyle := preload("res://src/ui/ui_style.gd")
const REF := Vector2(1280, 720)
const R_PANEL := Rect2(440, 262, 400, 330)
const R_BTN := Rect2(520, 620, 240, 64)
const R_LANG := Rect2(1080, 30, 170, 40)
const R_ERR := Rect2(340, 690, 600, 24)

var name_edit: LineEdit
var pass_edit: LineEdit
var reveal_btn: Button  # eye toggle: show / hide the password
var proxy_opt: OptionButton
var err_lbl: Label
var _box: Control  # REF-sized child, scaled+centered


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UiStyle.backdrop())
	_box = Control.new()
	_box.size = REF
	_box.theme = UiStyle.theme()
	add_child(_box)

	var brand := Label.new()
	brand.text = "PIPPOP"
	brand.position = Vector2(0, 58)
	brand.size = Vector2(REF.x, 44)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_override("font", UiStyle.title_font())
	brand.add_theme_color_override("font_color", UiStyle.GOLD)
	brand.add_theme_font_size_override("font_size", 36)
	brand.add_theme_constant_override("outline_size", 10)
	_box.add_child(brand)
	var title := Label.new()
	title.text = "ARENA"
	title.position = Vector2(0, 92)
	title.size = Vector2(REF.x, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiStyle.title_font())
	title.add_theme_color_override("font_color", UiStyle.GOLD)
	title.add_theme_font_size_override("font_size", 96)
	# a dark outline keeps the title clean over the stone
	title.add_theme_constant_override("outline_size", 14)
	_box.add_child(title)
	var tagline := Label.new()
	tagline.text = I18n.t("login.tagline")
	tagline.position = Vector2(0, 202)
	tagline.size = Vector2(REF.x, 28)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 20)
	tagline.add_theme_constant_override("outline_size", 10)
	_box.add_child(tagline)

	var panel := PanelContainer.new()
	panel.position = R_PANEL.position
	panel.size = R_PANEL.size
	panel.add_theme_stylebox_override("panel", UiStyle.window(38))
	_box.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(UiStyle.caption(I18n.t("login.user")))
	name_edit = _field(col)
	_gap(col)
	col.add_child(UiStyle.caption(I18n.t("login.pass")))
	var pass_row := HBoxContainer.new()
	pass_row.add_theme_constant_override("separation", 6)
	col.add_child(pass_row)
	pass_edit = _field(pass_row)
	pass_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_edit.secret = true
	reveal_btn = Button.new()
	reveal_btn.toggle_mode = true
	reveal_btn.focus_mode = Control.FOCUS_NONE
	reveal_btn.custom_minimum_size = Vector2(46, 46)
	reveal_btn.tooltip_text = I18n.t("login.show_pass")
	reveal_btn.toggled.connect(_on_reveal)
	reveal_btn.draw.connect(_draw_eye)
	pass_row.add_child(reveal_btn)
	_gap(col)
	col.add_child(UiStyle.caption(I18n.t("login.server")))
	proxy_opt = OptionButton.new()
	proxy_opt.custom_minimum_size.y = 46
	proxy_opt.add_theme_font_size_override("font_size", 19)
	col.add_child(proxy_opt)

	var btn := Button.new()
	btn.text = I18n.t("net.connect").to_upper()
	btn.position = R_BTN.position
	btn.size = R_BTN.size
	UiStyle.primary(btn)
	btn.pressed.connect(_do_submit)
	_box.add_child(btn)

	# locale picker — top-right, flags the i18n table the lobby will use
	var lang_opt := OptionButton.new()
	lang_opt.position = R_LANG.position
	lang_opt.size = R_LANG.size
	lang_opt.tooltip_text = I18n.t("login.language")
	for code in ["es", "en", "fr"]:
		lang_opt.add_item(I18n.NAMES[code])
	var cur := ["es", "en", "fr"].find(I18n.lang)
	lang_opt.select(cur if cur >= 0 else 0)
	lang_opt.item_selected.connect(func(i):
		I18n.set_locale(["es", "en", "fr"][i]))
	_box.add_child(lang_opt)

	name_edit.focus_next = name_edit.get_path_to(pass_edit)
	pass_edit.focus_next = pass_edit.get_path_to(proxy_opt)
	proxy_opt.focus_next = proxy_opt.get_path_to(btn)
	btn.focus_next = btn.get_path_to(lang_opt)
	lang_opt.focus_next = lang_opt.get_path_to(name_edit)

	err_lbl = Label.new()
	err_lbl.position = R_ERR.position
	err_lbl.size = R_ERR.size
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.add_theme_font_size_override("font_size", 16)
	err_lbl.add_theme_constant_override("outline_size", 8)
	_box.add_child(err_lbl)

	resized.connect(_relayout)


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


func _field(parent: Control) -> LineEdit:
	var e := LineEdit.new()
	e.custom_minimum_size.y = 46
	e.add_theme_font_size_override("font_size", 19)
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
	var col := UiStyle.GOLD if reveal_btn.button_pressed else UiStyle.MUTED
	var top := PackedVector2Array()
	var bot := PackedVector2Array()
	for i in 17:
		var t := -1.0 + i / 8.0
		var y := 7.0 * (1.0 - t * t)
		top.append(c + Vector2(t * 13.0, -y))
		bot.append(c + Vector2(t * 13.0, y))
	reveal_btn.draw_polyline(top, col, 2.0, true)
	reveal_btn.draw_polyline(bot, col, 2.0, true)
	reveal_btn.draw_circle(c, 3.5, col)
	if not reveal_btn.button_pressed:
		reveal_btn.draw_line(c + Vector2(-12, 10), c + Vector2(12, -10),
			col, 2.5, true)


func _gap(parent: Control) -> void:
	var g := Control.new()
	g.custom_minimum_size.y = 12
	parent.add_child(g)


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
		err_lbl.text = I18n.t("login.enter_account")
		return
	var proxy := ""
	if proxy_opt.selected >= 0:
		proxy = proxy_opt.get_item_text(proxy_opt.selected)
	submit.emit(login, pass_edit.text, proxy)
