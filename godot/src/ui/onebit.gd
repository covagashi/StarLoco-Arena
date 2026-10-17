extends RefCounted
## The 1-bit UI system (S18, direction B, chosen by the owner 2026-10-17):
## pure black and white, square corners, white borders, a hard white drop
## shadow, inverted selection, and dither instead of grey or alpha. The only
## colour allowed on screen is the player's own team blue (ACCENT), as in the
## S04 1-bit fights. Sketch: godot/tools/mock_screens.py, direction B.

const INK := Color(1, 1, 1)
const PAPER := Color(0, 0, 0)
const MUTED := Color(0.6, 0.6, 0.6)   # secondary text only; never a fill
const ACCENT := Color(0.235, 0.47, 1.0)
const SHADOW := Vector2(8, 8)

static var _dither_cache := {}
static var _card_art_cache := {}   # card id -> Texture2D (null when missing)


## Flat box: black fill, white border, square corners.
static func box(fill := PAPER, border := INK, width := 2, margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


## A window: box plus the hard white shadow down-right.
static func window(margin := 22) -> StyleBoxFlat:
	var s := box(PAPER, INK, 3, margin)
	s.shadow_color = INK
	s.shadow_size = 1
	s.shadow_offset = SHADOW
	return s


## Focus ring: a white outline 4 px outside the control, nothing inside.
static func focus_ring() -> StyleBoxFlat:
	var s := box(Color(0, 0, 0, 0), INK, 2, 0)
	s.draw_center = false
	s.set_expand_margin_all(4)
	return s


## Tiled checker of black and transparent pixels: a 50 % dither for modal
## shades, so nothing behind a dialog turns grey.
static func dither_texture(step := 2) -> ImageTexture:
	if _dither_cache.has(step):
		return _dither_cache[step]
	# 64 px, not one 2x2 cell: a tiny texture tiled across the screen came
	# out averaged to grey on the Compatibility renderer.
	var side := 64
	var img := Image.create(side, side, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in side:
		for x in side:
			if ((x / step) + (y / step)) % 2 == 0:
				img.set_pixel(x, y, Color(0, 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	_dither_cache[step] = tex
	return tex


## A full-rect dither shade (TextureRect, tiled).
static func shade() -> TextureRect:
	var t := TextureRect.new()
	t.texture = dither_texture()
	t.stretch_mode = TextureRect.STRETCH_TILE
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	t.mouse_filter = Control.MOUSE_FILTER_STOP
	return t


## Pixel icons for check boxes, toggles and slider grabbers. `on` fills.
static func _icon(w: int, h: int, on: bool, knob: bool, ink := INK) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, w, h), ink)
	img.fill_rect(Rect2i(2, 2, w - 4, h - 4), INK if on and not knob else PAPER)
	if knob:   # toggle: a square knob, left when off, right on a white track
		if on:
			img.fill_rect(Rect2i(2, 2, w - 4, h - 4), ink)
		var k := h - 8
		var x := w - 4 - k if on else 4
		img.fill_rect(Rect2i(x, 4, k, k), PAPER if on else ink)
	elif on:
		img.fill_rect(Rect2i(5, 5, w - 10, h - 10), PAPER)
		img.fill_rect(Rect2i(7, 7, w - 14, h - 14), ink)
	return ImageTexture.create_from_image(img)


static func _grabber(ink := INK) -> ImageTexture:
	var img := Image.create(12, 22, false, Image.FORMAT_RGBA8)
	img.fill(ink)
	return ImageTexture.create_from_image(img)


## Backdrop for full screens (login, creation, lobby): our own 1-bit art,
## assets/ui/onebit_bg.png (tools/make_onebit_bg.py; committed, not retail).
## ARENA_BACKDROP=<name> picks assets/ui/onebit_bg_<name>.png instead, for
## comparing candidates. Without the file, a dithered vignette shader.
const BACKDROP := "ui/onebit_bg.png"

const _THRESHOLD := """shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(step(0.5, l)), 1.0);
}"""

const _VIGNETTE := """shader_type canvas_item;
const float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
void fragment() {
	ivec2 p = ivec2(FRAGCOORD.xy) / 2 % 4;
	float t = (B[p.y * 4 + p.x] + 0.5) / 16.0;
	float v = 0.42 * (1.0 - length((UV - 0.5) * vec2(1.6, 1.3)));
	COLOR = vec4(vec3(step(t, v)), 1.0);
}"""


## Content art (card illustrations, token icons) is 1-bit too: ordered
## dither, chosen by the owner 2026-10-17 (S18, option B). The team blue and
## the hair/skin swatches keep their colour: they carry meaning, not art.
## ARENA_CARD_ART=color shows the art in colour, for comparing on a sheet.
## Returns null when the art keeps its colour.
const _ART_DITHER := """shader_type canvas_item;
const float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	ivec2 p = ivec2(FRAGCOORD.xy) % 4;
	float t = (B[p.y * 4 + p.x] + 0.5) / 16.0;
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(vec3(step(t, l)), step(0.5, c.a));
}"""

static var _art_mat: ShaderMaterial


static func art_in_colour() -> bool:
	return OS.get_environment("ARENA_CARD_ART") == "color"


static func art_material() -> ShaderMaterial:
	return null if art_in_colour() else dither_material()


## The ordered dither alone, whatever ARENA_CARD_ART says.
static func dither_material() -> ShaderMaterial:
	if _art_mat == null:
		_art_mat = ShaderMaterial.new()
		_art_mat.shader = Shader.new()
		_art_mat.shader.code = _ART_DITHER
	return _art_mat


## A card's illustration (coach or fighter equipment), cached; null if the
## art is not installed. Draw it with art_material().
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


## The coach doll on menu screens is 1-bit too (owner, 2026-10-17): line
## art, the AnmSprite style of the 1-bit fights, so the coach looks the same
## in the lobby and in a fight. ARENA_DOLL_STYLE=dither lays the card-art
## dither over the colour doll instead; a number picks that AnmSprite style
## (0 colour, 2 dither with skin and hair in colour).
static func doll(spr) -> void:
	var pick := OS.get_environment("ARENA_DOLL_STYLE")
	spr.team_color = INK
	if pick == "dither":
		spr.style = 0
		spr.material = dither_material()
	else:
		spr.style = int(pick) if pick.is_valid_int() else 3


## `fixed` sizes it by hand (for a parent without a layout rect, like the
## lobby's scaled REF box); otherwise it anchors to the full parent rect.
static func backdrop(fixed := Vector2.ZERO) -> Control:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pick := OS.get_environment("ARENA_BACKDROP")
	var img := AssetPaths.load_image(
		"ui/onebit_bg_%s.png" % pick if pick != "" else BACKDROP)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	var art: Control
	if img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		mat.shader.code = _THRESHOLD
		art = tr
	else:
		var cr := ColorRect.new()
		mat.shader.code = _VIGNETTE
		art = cr
	art.material = mat
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(art)
	if fixed != Vector2.ZERO:
		for c in [root, art]:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT)
			c.position = Vector2.ZERO
			c.size = fixed
	return root


## The one primary action of a screen: a white block, black inner rule, hard
## white shadow. Pressing it inverts to black.
static func primary(b: Button, font_size := 24) -> void:
	var n := box(INK, PAPER, 3, 12)
	n.shadow_color = INK
	n.shadow_size = 1
	n.shadow_offset = Vector2(5, 5)
	var h := n.duplicate()
	h.border_width_left = 5
	h.border_width_right = 5
	h.border_width_top = 5
	h.border_width_bottom = 5
	var p := box(PAPER, INK, 3, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", focus_ring())
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, PAPER)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_hover_pressed_color", INK)
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


## Theme for every native control: buttons invert when pressed/toggled,
## hover thickens the border, lists invert the selected row.
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
		t.set_color("font_outline_color", type, PAPER)
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_color("font_pressed_color", type, PAPER)
		t.set_color("font_hover_pressed_color", type, PAPER)
		t.set_stylebox("normal", type, box(PAPER, INK, 2, pad))
		t.set_stylebox("hover", type, box(PAPER, INK, 3, pad))
		t.set_stylebox("pressed", type, box(INK, INK, 2, pad))
		t.set_stylebox("hover_pressed", type, box(INK, INK, 3, pad))
		t.set_stylebox("disabled", type, box(PAPER, MUTED, 1, pad))
		t.set_stylebox("focus", type, focus_ring())
	# Icons are drawn white; on an inverted (pressed) button they go black.
	for type in ["Button", "OptionButton", "CheckButton", "CheckBox"]:
		t.set_color("icon_pressed_color", type, PAPER)
		t.set_color("icon_hover_pressed_color", type, PAPER)
		t.set_color("icon_disabled_color", type, MUTED)
	# OptionButton shows its value on black even while its popup is open.
	t.set_color("font_pressed_color", "OptionButton", INK)
	t.set_stylebox("pressed", "OptionButton", box(PAPER, INK, 3))
	t.set_stylebox("normal", "LineEdit", box(PAPER, INK, 2, pad))
	t.set_stylebox("focus", "LineEdit", box(PAPER, INK, 3, pad))
	t.set_stylebox("read_only", "LineEdit", box(PAPER, MUTED, 1, pad))
	t.set_color("caret_color", "LineEdit", INK)
	t.set_color("selection_color", "LineEdit", INK)
	t.set_color("font_selected_color", "LineEdit", PAPER)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	t.set_stylebox("normal", "TextEdit", box(PAPER, INK, 2, pad))
	t.set_stylebox("focus", "TextEdit", box(PAPER, INK, 3, pad))
	t.set_stylebox("read_only", "TextEdit", box(PAPER, MUTED, 1, pad))
	for c in ["font_color", "font_readonly_color", "caret_color"]:
		t.set_color(c, "TextEdit", INK)
	t.set_color("selection_color", "TextEdit", INK)
	t.set_color("font_selected_color", "TextEdit", PAPER)
	t.set_color("font_placeholder_color", "TextEdit", MUTED)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	# Tree (the tables): white header rule, inverted selected row.
	t.set_stylebox("panel", "Tree", box(PAPER, INK, 2, 4))
	t.set_stylebox("focus", "Tree", focus_ring())
	t.set_stylebox("selected", "Tree", box(INK, INK, 0, 0))
	t.set_stylebox("selected_focus", "Tree", box(INK, INK, 0, 0))
	t.set_stylebox("cursor", "Tree", box(Color(0, 0, 0, 0), INK, 1, 0))
	t.set_stylebox("cursor_unfocused", "Tree", box(Color(0, 0, 0, 0), INK, 1, 0))
	var head := box(PAPER, PAPER, 0, 6)
	head.border_color = INK
	head.border_width_bottom = 2
	for s in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		t.set_stylebox(s, "Tree", head)
	t.set_color("title_button_color", "Tree", INK)
	t.set_font("title_button_font", "Tree", title_font())
	t.set_font_size("title_button_font_size", "Tree", 14)
	t.set_color("font_selected_color", "Tree", PAPER)
	t.set_color("guide_color", "Tree", Color(0, 0, 0, 0))
	t.set_color("relationship_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "Tree", 8)
	# Dropdown menus.
	t.set_stylebox("panel", "PopupMenu", box(PAPER, INK, 2, 6))
	t.set_stylebox("hover", "PopupMenu", box(INK, INK, 0, 4))
	t.set_color("font_hover_color", "PopupMenu", PAPER)
	t.set_stylebox("panel", "PopupPanel", box(PAPER, INK, 2, 6))
	# Scrollbars: a white bar in a white-ruled black gutter.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(PAPER, INK, 1, 2))
		t.set_stylebox("scroll_focus", bar, box(PAPER, INK, 1, 2))
		t.set_stylebox("grabber", bar, box(INK, INK, 0, 4))
		t.set_stylebox("grabber_highlight", bar, box(INK, INK, 0, 4))
		t.set_stylebox("grabber_pressed", bar, box(INK, INK, 0, 4))
	t.set_stylebox("separator", "HSeparator", box(INK, INK, 0, 0))
	t.set_constant("separation", "HSeparator", 2)
	t.set_stylebox("panel", "PanelContainer", window())
	# Sliders (options): a white rule and a square white grabber.
	var rail := box(INK, INK, 0, 0)
	rail.content_margin_top = 1
	rail.content_margin_bottom = 1
	t.set_stylebox("slider", "HSlider", rail)
	t.set_stylebox("grabber_area", "HSlider", rail)
	t.set_stylebox("grabber_area_highlight", "HSlider", rail)
	for type in ["CheckBox"]:
		t.set_icon("unchecked", type, _icon(20, 20, false, false))
		t.set_icon("checked", type, _icon(20, 20, true, false))
		t.set_icon("unchecked_disabled", type, _icon(20, 20, false, false, MUTED))
		t.set_icon("checked_disabled", type, _icon(20, 20, true, false, MUTED))
	t.set_icon("unchecked", "CheckButton", _icon(40, 20, false, true))
	t.set_icon("checked", "CheckButton", _icon(40, 20, true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _icon(40, 20, false, true, MUTED))
	t.set_icon("checked_disabled", "CheckButton", _icon(40, 20, true, true, MUTED))
	t.set_icon("grabber", "HSlider", _grabber())
	t.set_icon("grabber_highlight", "HSlider", _grabber())
	t.set_icon("grabber_disabled", "HSlider", _grabber(MUTED))
	return t
