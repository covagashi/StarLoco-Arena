extends RefCounted
## The native UI look (login, creation, lobby, every panel, the versus): the
## stonework and gold of the retail-coloured fight HUD (S17) — the owner's
## choice on 2026-10-24, replacing the S18 1-bit system. Olive stone plates,
## a worn gold rim, cream text, gold titles, one gold primary button per
## screen, soft shadows and rounded corners. Colour art stays in colour.

const INK := Color("f0e4c4")        # text, and the light side of a selection
const PAPER := Color("24261b")      # plates and window fill
const MUTED := Color("a89f86")      # secondary text
const ACCENT := Color(0.235, 0.47, 1.0)   # the player's own team blue
const GOLD := Color("e2bd6e")       # titles
const RIM := Color("8f7f52")        # plate borders
const RIM_HI := Color("d9bd7e")     # hover / focus border
const PLATE := Color("33342a")      # buttons and fields
const PRESSED := Color("8a5a12")    # pressed / toggled
const RADIUS := 8

static var _card_art_cache := {}   # card id -> Texture2D (null when missing)


## A plate: fill, rim, rounded corners. `border` INK means "the rim".
static func box(fill := PAPER, border := INK, width := 2, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = RIM if border == INK else border
	s.set_border_width_all(width)
	s.set_corner_radius_all(RADIUS)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


## A window: a plate with a soft shadow under it.
static func window(margin := 22) -> StyleBoxFlat:
	var s := box(PAPER, RIM, 2, margin)
	s.set_corner_radius_all(14)
	s.shadow_color = Color(0, 0, 0, 0.55)
	s.shadow_size = 12
	s.shadow_offset = Vector2(0, 6)
	return s


## Focus ring: a gold outline just outside the control.
static func focus_ring() -> StyleBoxFlat:
	var s := box(Color(0, 0, 0, 0), RIM_HI, 2, 0)
	s.draw_center = false
	s.set_expand_margin_all(3)
	return s


## A full-rect shade behind modal panels.
static func shade() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.02, 0.025, 0.018, 0.62)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Check boxes and toggles drawn in the palette. `on` fills.
static func _icon(w: int, h: int, on: bool, knob: bool, rim := RIM) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, w, h), rim)
	img.fill_rect(Rect2i(2, 2, w - 4, h - 4), PLATE)
	if knob:   # toggle: a knob, left when off, right on a gold track
		if on:
			img.fill_rect(Rect2i(2, 2, w - 4, h - 4), PRESSED)
		var k := h - 8
		var x := w - 4 - k if on else 4
		img.fill_rect(Rect2i(x, 4, k, k), INK if on else MUTED)
	elif on:
		img.fill_rect(Rect2i(5, 5, w - 10, h - 10), GOLD)
	return ImageTexture.create_from_image(img)


static func _grabber(col := GOLD) -> ImageTexture:
	var img := Image.create(12, 22, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)


## Backdrop for full screens (login, creation, lobby): the stonework plate,
## assets/ui/ui_bg.png (tools/make_ui_bg.py; committed, our own art). Without
## the file, a plain olive gradient.
const BACKDROP := "ui/ui_bg.png"

const _GRADIENT := """shader_type canvas_item;
void fragment() {
	COLOR = vec4(mix(vec3(0.22, 0.215, 0.14), vec3(0.09, 0.1, 0.07), UV.y), 1.0);
}"""


## `fixed` sizes it by hand (for a parent without a layout rect, like the
## lobby's scaled REF box); otherwise it anchors to the full parent rect.
static func backdrop(fixed := Vector2.ZERO) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := AssetPaths.load_image(BACKDROP)
	var art: Control
	if img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		art = tr
	else:
		var cr := ColorRect.new()
		var mat := ShaderMaterial.new()
		mat.shader = Shader.new()
		mat.shader.code = _GRADIENT
		cr.material = mat
		art = cr
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	if fixed != Vector2.ZERO:
		for c in [root, art]:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2.ZERO
			c.size = fixed
	return root


## A card's illustration (coach or fighter equipment), cached; null if the
## art is not installed.
static func card_art(cid: int) -> Texture2D:
	if _card_art_cache.has(cid):
		return _card_art_cache[cid]
	var tex: Texture2D = null
	for dir in ["gui/images/equipments/coachs/illustrations/",
			"gui/images/equipments/fighters/illustrations/"]:
		var img := AssetPaths.load_image(dir + "%d.png" % cid)
		if img != null:
			tex = ImageTexture.create_from_image(img)
			break
	_card_art_cache[cid] = tex
	return tex


## The one primary action of a screen: the gold button of the fight's PASS.
static func primary(b: Button, font_size := 24) -> void:
	var n := box(Color("a8701a"), Color("f6dc8c"), 2, 12)
	n.set_corner_radius_all(12)
	n.shadow_color = Color(0, 0, 0, 0.5)
	n.shadow_size = 6
	n.shadow_offset = Vector2(0, 3)
	var h := n.duplicate()
	h.bg_color = Color("c08428")
	var p := n.duplicate()
	p.bg_color = Color("6c4510")
	p.shadow_size = 0
	var off := n.duplicate()
	off.bg_color = Color("3a3426")
	off.border_color = Color("6e6448")
	off.shadow_size = 0
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", focus_ring())
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", off)
	for c in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("fff0c5"))
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("font_outline_color", Color("3c2408"))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", font_size)


## Small uppercase caption above a field.
static func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", MUTED)
	return l


static func body_font() -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(AssetPaths.resolve("gui/fonts/TAHOMA.TTF"))
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


static func title_font() -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(AssetPaths.resolve("gui/fonts/COPRGTB.TTF"))
	return f


## Theme for every native control: stone plates, gold rims on hover and
## focus, the pressed/toggled state in gold-brown, the selected row lit.
## `pad` is the inner margin of buttons and fields (compact chat: 3).
static func theme(pad := 10) -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17
	var text_types := ["Label", "Button", "OptionButton", "LineEdit", "Tree",
		"CheckButton", "CheckBox", "PopupMenu", "ItemList", "RichTextLabel"]
	for type in text_types:
		for c in ["font_color", "font_hover_color", "font_focus_color"]:
			t.set_color(c, type, INK)
		t.set_color("font_disabled_color", type, MUTED)
		t.set_color("font_outline_color", type, Color(0, 0, 0))
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_color("font_pressed_color", type, Color("fff0c5"))
		t.set_color("font_hover_pressed_color", type, Color("fff0c5"))
		t.set_stylebox("normal", type, box(PLATE, RIM, 2, pad))
		t.set_stylebox("hover", type, box(PLATE.lightened(0.08), RIM_HI, 2, pad))
		t.set_stylebox("pressed", type, box(PRESSED, RIM_HI, 2, pad))
		t.set_stylebox("hover_pressed", type, box(PRESSED.lightened(0.1), RIM_HI, 2, pad))
		t.set_stylebox("disabled", type, box(PAPER, Color("4d4936"), 1, pad))
		t.set_stylebox("focus", type, focus_ring())
		t.set_color("icon_disabled_color", type, MUTED)
	# CheckButton/CheckBox rows sit on the panel, not on a plate
	for type in ["CheckButton", "CheckBox"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var flat := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad)
			t.set_stylebox(st, type, flat)
	t.set_stylebox("pressed", "OptionButton", box(PLATE, RIM_HI, 2, pad))
	t.set_color("font_pressed_color", "OptionButton", INK)
	t.set_stylebox("normal", "LineEdit", box(Color("1a1c14"), RIM, 2, pad))
	t.set_stylebox("focus", "LineEdit", box(Color("1a1c14"), RIM_HI, 2, pad))
	t.set_stylebox("read_only", "LineEdit", box(PAPER, Color("4d4936"), 1, pad))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(0.54, 0.35, 0.07, 0.8))
	t.set_color("font_selected_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_stylebox("normal", "TextEdit", box(Color("1a1c14"), RIM, 2, pad))
	t.set_stylebox("focus", "TextEdit", box(Color("1a1c14"), RIM_HI, 2, pad))
	t.set_stylebox("read_only", "TextEdit", box(PAPER, Color("4d4936"), 1, pad))
	for c in ["font_color", "font_readonly_color"]:
		t.set_color(c, "TextEdit", INK)
	t.set_color("caret_color", "TextEdit", GOLD)
	t.set_color("selection_color", "TextEdit", Color(0.54, 0.35, 0.07, 0.8))
	t.set_color("font_selected_color", "TextEdit", INK)
	t.set_color("font_placeholder_color", "TextEdit", MUTED)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	# Tree (the tables): a gold header rule, the selected row in gold-brown.
	t.set_stylebox("panel", "Tree", box(Color("1d1f16"), RIM, 2, 4))
	t.set_stylebox("focus", "Tree", focus_ring())
	var sel := box(PRESSED, RIM_HI, 0, 0)
	sel.set_corner_radius_all(4)
	t.set_stylebox("selected", "Tree", sel)
	t.set_stylebox("selected_focus", "Tree", sel)
	t.set_stylebox("cursor", "Tree", box(Color(0, 0, 0, 0), RIM_HI, 1, 0))
	t.set_stylebox("cursor_unfocused", "Tree", box(Color(0, 0, 0, 0), RIM, 1, 0))
	var head := box(Color("2b2c21"), Color(0, 0, 0, 0), 0, 6)
	head.border_color = RIM
	head.border_width_bottom = 2
	head.set_corner_radius_all(0)
	for s in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		t.set_stylebox(s, "Tree", head)
	t.set_color("title_button_color", "Tree", GOLD)
	t.set_font("title_button_font", "Tree", title_font())
	t.set_font_size("title_button_font_size", "Tree", 14)
	t.set_color("font_selected_color", "Tree", Color("fff0c5"))
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.05))
	t.set_color("relationship_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "Tree", 8)
	# Dropdown menus.
	t.set_stylebox("panel", "PopupMenu", box(PAPER, RIM, 2, 6))
	t.set_stylebox("hover", "PopupMenu", box(PRESSED, PRESSED, 0, 4))
	t.set_color("font_hover_color", "PopupMenu", Color("fff0c5"))
	t.set_stylebox("panel", "PopupPanel", box(PAPER, RIM, 2, 6))
	# Scrollbars: a gold bar in a dark gutter.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color("1a1c14"), Color("3e3b2b"), 1, 2))
		t.set_stylebox("scroll_focus", bar, box(Color("1a1c14"), Color("3e3b2b"), 1, 2))
		t.set_stylebox("grabber", bar, box(RIM, RIM, 0, 4))
		t.set_stylebox("grabber_highlight", bar, box(RIM_HI, RIM_HI, 0, 4))
		t.set_stylebox("grabber_pressed", bar, box(GOLD, GOLD, 0, 4))
	t.set_stylebox("separator", "HSeparator", box(RIM, RIM, 0, 0))
	t.set_constant("separation", "HSeparator", 2)
	t.set_stylebox("panel", "PanelContainer", window())
	# Sliders (options): a rim-coloured rule and a gold grabber.
	var rail := box(RIM, RIM, 0, 0)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", rail)
	var lit := box(GOLD, GOLD, 0, 0)
	lit.content_margin_top = 2
	lit.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", lit)
	t.set_stylebox("grabber_area_highlight", "HSlider", lit)
	t.set_icon("unchecked", "CheckBox", _icon(20, 20, false, false))
	t.set_icon("checked", "CheckBox", _icon(20, 20, true, false))
	t.set_icon("unchecked_disabled", "CheckBox", _icon(20, 20, false, false, Color("4d4936")))
	t.set_icon("checked_disabled", "CheckBox", _icon(20, 20, true, false, Color("4d4936")))
	t.set_icon("unchecked", "CheckButton", _icon(40, 20, false, true))
	t.set_icon("checked", "CheckButton", _icon(40, 20, true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _icon(40, 20, false, true, Color("4d4936")))
	t.set_icon("checked_disabled", "CheckButton", _icon(40, 20, true, true, Color("4d4936")))
	t.set_icon("grabber", "HSlider", _grabber())
	t.set_icon("grabber_highlight", "HSlider", _grabber(RIM_HI))
	t.set_icon("grabber_disabled", "HSlider", _grabber(MUTED))
	return t
