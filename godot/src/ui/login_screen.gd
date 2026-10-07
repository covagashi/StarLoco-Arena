class_name PippopLogin
extends Control
## Custom login screen — Pillow-baked art (assets/ui/login_bg.png) with
## real controls overlaid at the baked slot coordinates. Replaces the
## retail logonDialog; emits `submit(login, password, proxy)`.

signal submit(login: String, password: String, proxy: String)

const REF := Vector2(1280, 720)
# baked slot rects (final px of login_bg.png)
const R_NAME := Rect2(475, 365, 330, 44)
const R_PASS := Rect2(475, 445, 330, 44)
const R_PROXY := Rect2(475, 525, 330, 44)
const R_BTN := Rect2(530, 608, 220, 52)
const R_ERR := Rect2(440, 662, 400, 20)

var name_edit: LineEdit
var pass_edit: LineEdit
var proxy_opt: OptionButton
var err_lbl: Label
var _box: Control  # REF-sized child, scaled+centered


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_box = Control.new()
	_box.size = REF
	add_child(_box)

	var bg := TextureRect.new()
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path("res://assets/ui/login_bg.png")) == OK:
		bg.texture = ImageTexture.create_from_image(img)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_box.add_child(bg)

	var font := FontFile.new()
	font.load_dynamic_font("res://assets/gui/fonts/COPRGTB.TTF")
	var plain := StyleBoxEmpty.new()

	name_edit = _field(R_NAME, false, font, plain)
	name_edit.placeholder_text = I18n.t("login.user")
	pass_edit = _field(R_PASS, true, font, plain)
	pass_edit.secret = true
	pass_edit.placeholder_text = I18n.t("login.pass")

	# locale picker — top-right, flags the i18n table the lobby will use
	var lang_opt := OptionButton.new()
	lang_opt.position = Vector2(1040, 24)
	lang_opt.size = Vector2(190, 36)
	lang_opt.flat = true
	lang_opt.add_theme_font_override("font", font)
	lang_opt.add_theme_font_size_override("font_size", 18)
	lang_opt.add_theme_color_override("font_color", Color(0.85, 0.80, 0.60))
	lang_opt.add_theme_stylebox_override("normal", plain)
	lang_opt.add_theme_stylebox_override("hover", plain)
	lang_opt.add_theme_stylebox_override("pressed", plain)
	lang_opt.get_popup().add_theme_stylebox_override("panel",
		_solid(Color(0.10, 0.09, 0.05, 0.95)))
	lang_opt.get_popup().add_theme_color_override("font_color",
		Color(0.85, 0.80, 0.60))
	for code in ["es", "en", "fr"]:
		lang_opt.add_item(I18n.NAMES[code])
	var cur := ["es", "en", "fr"].find(I18n.lang)
	lang_opt.select(cur if cur >= 0 else 0)
	lang_opt.item_selected.connect(func(i):
		I18n.set_locale(["es", "en", "fr"][i]))
	_box.add_child(lang_opt)

	proxy_opt = OptionButton.new()
	proxy_opt.position = R_PROXY.position
	proxy_opt.size = R_PROXY.size
	proxy_opt.flat = true
	proxy_opt.add_theme_font_override("font", font)
	proxy_opt.add_theme_font_size_override("font_size", 20)
	proxy_opt.add_theme_color_override("font_color", Color(0.85, 0.80, 0.60))
	proxy_opt.add_theme_stylebox_override("normal", plain)
	proxy_opt.add_theme_stylebox_override("hover", plain)
	proxy_opt.add_theme_stylebox_override("pressed", plain)
	proxy_opt.get_popup().add_theme_stylebox_override("panel",
		_solid(Color(0.10, 0.09, 0.05, 0.95)))
	proxy_opt.get_popup().add_theme_color_override("font_color",
		Color(0.85, 0.80, 0.60))
	_box.add_child(proxy_opt)

	var btn := Button.new()
	btn.position = R_BTN.position
	btn.size = R_BTN.size
	btn.flat = true           # the art draws the button; we catch the click
	btn.tooltip_text = I18n.t("net.connect")
	btn.add_theme_stylebox_override("focus", _focus_style())
	btn.pressed.connect(_do_submit)
	_box.add_child(btn)
	name_edit.focus_next = name_edit.get_path_to(pass_edit)
	pass_edit.focus_next = pass_edit.get_path_to(proxy_opt)
	proxy_opt.focus_next = proxy_opt.get_path_to(btn)
	btn.focus_next = btn.get_path_to(lang_opt)
	lang_opt.focus_next = lang_opt.get_path_to(name_edit)

	err_lbl = Label.new()
	err_lbl.position = R_ERR.position
	err_lbl.size = R_ERR.size
	err_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_lbl.add_theme_font_override("font", font)
	err_lbl.add_theme_font_size_override("font_size", 15)
	err_lbl.add_theme_color_override("font_color", Color(0.85, 0.35, 0.25))
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


func _field(r: Rect2, _secret: bool, font: Font, plain: StyleBox) -> LineEdit:
	var e := LineEdit.new()
	e.position = r.position + Vector2(8, 0)
	e.size = r.size - Vector2(16, 0)
	e.flat = true
	e.add_theme_font_override("font", font)
	e.add_theme_font_size_override("font_size", 22)
	e.add_theme_color_override("font_color", Color(0.90, 0.85, 0.62))
	e.add_theme_color_override("caret_color", Color(0.90, 0.85, 0.62))
	for s in ["normal", "focus", "read_only"]:
		e.add_theme_stylebox_override(s, plain)
	e.text_submitted.connect(func(_t): _do_submit())
	_box.add_child(e)
	return e


func _solid(c: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	return s


func _focus_style() -> StyleBoxFlat:
	var style := _solid(Color.TRANSPARENT)
	style.border_color = Color("ffe6a0")
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	return style


func _relayout() -> void:
	if _box == null:
		return
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
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
