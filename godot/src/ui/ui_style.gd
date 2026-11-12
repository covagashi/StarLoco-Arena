extends RefCounted
## The native UI look (login, creation, lobby, every panel, the versus).
## S45 (2026-11-12), after the owner-reviewed mockup: game material, not a
## web page — a 3 px ink border and a hard (never soft) shadow under what can
## be pressed, raised buttons with a lip, the main action in pop orange and
## leaning, titles in Lilita One with an ink outline, text in bold Nunito, on
## night navy. The pieces are 9-slice textures drawn by tools/make_ui_kit.py
## (assets/ui/kit); without them, flat boxes in the same palette.
## The old names (INK, PAPER, GOLD, RIM…) keep their role so every caller
## takes the new look unchanged: INK is still the text, PAPER the fill.

const INK := Color("fff6e6")        # text (cream), and the light side of a selection
const PAPER := Color("1b2048")      # plates and window fill (navy)
const MUTED := Color("b9bee0")      # secondary text
const ACCENT := Color("4c8dff")     # the player's own team blue (ally)
const GOLD := Color("ffc247")       # titles and rewards (sun)
const RIM := Color("0b0d1c")        # borders: the ink
const RIM_HI := Color("ffc247")     # hover / focus border
const PLATE := Color("2b3268")      # buttons and fields
const PRESSED := Color("e8501f")    # pressed / toggled (pop, dark)
const RADIUS := 10
# S45 palette
const NIGHT := Color("12152a")
const POP := Color("ff6b3d")        # only for the action
const SUN := Color("ffc247")
const RIVAL := Color("ff4d5e")
const OK := Color("36c98a")
const OUTLINE := Color("0b0d1c")    # the ink
const PAPER_SHEET := Color("fff1d6")   # the cream paper (forms and sheets)
const PAPER_INK := Color("2b1d10")     # text on paper
const FIELD := Color("0c0e1e")

const KIT := "ui/kit/"
const FONT_TITLE := "ui/fonts/LilitaOne-Regular.ttf"
const FONT_BODY := "ui/fonts/Nunito-Variable.ttf"

static var _card_art_cache := {}   # card id -> Texture2D (null when missing)
static var _kit_cache := {}        # asset path -> Texture2D (null when missing)
static var _fonts := {}


## A plate: fill, ink border, rounded corners. `border` INK means "the rim".
static func box(fill := PAPER, border := INK, width := 3, margin := 10) -> StyleBoxFlat:
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


## One piece of the kit, or null when assets/ui/kit is not there.
static func kit_texture(piece: String) -> Texture2D:
	return _texture(KIT + piece + ".png")


static func _texture(rel: String) -> Texture2D:
	if not _kit_cache.has(rel):
		var img := AssetPaths.load_image(rel)
		_kit_cache[rel] = ImageTexture.create_from_image(img) if img != null else null
	return _kit_cache[rel]


## A kit piece as a 9-slice: `slice` is its texture margins (left, top,
## right, bottom), which must match tools/make_ui_kit.py; `content` the
## inner margins. `tile` repeats the edges and centre instead of stretching
## them (the paper's stitch and lines). Null without the kit.
static func kit(piece: String, slice: Vector4, content: Vector4, tile := false) -> StyleBoxTexture:
	var tex := kit_texture(piece)
	if tex == null:
		return null
	var s := StyleBoxTexture.new()
	s.texture = tex
	s.texture_margin_left = slice.x
	s.texture_margin_top = slice.y
	s.texture_margin_right = slice.z
	s.texture_margin_bottom = slice.w
	s.content_margin_left = content.x
	s.content_margin_top = content.y
	s.content_margin_right = content.z
	s.content_margin_bottom = content.w
	if tile:
		s.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
		s.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	return s


## A raised button of the kit: `colour` pop, navy, green or sun; `state`
## "", "hover", "pressed" or "off". The face sinks 4 px when pressed, so its
## content moves down with it (same total margin: no jump in size).
static func button_box(colour: String, state := "", pad := 10) -> StyleBox:
	var piece := "btn_off" if state == "off" else "btn_" + colour + ("" if state == "" else "_" + state)
	var top := maxf(2, pad * 0.6)
	var c := Vector4(pad + 6, top + (4 if state == "pressed" else 0), pad + 6,
		top + (1 if state == "pressed" else 5))
	var s := kit(piece, Vector4(16, 12, 16, 18), c)
	if s != null:
		return s
	var fill := {"pop": POP, "navy": PLATE, "green": OK, "sun": SUN}.get(colour, PLATE) as Color
	if state == "hover":
		fill = fill.lightened(0.12)
	elif state == "pressed":
		fill = fill.darkened(0.15)
	elif state == "off":
		fill = Color("3a3f63")
	var f := box(fill, RIM, 3, pad)
	f.shadow_color = OUTLINE
	f.shadow_size = 0
	f.shadow_offset = Vector2(0, 0 if state == "pressed" else 5)
	return f


## A window: the navy plate with its hard ink shadow.
static func window(margin := 22) -> StyleBox:
	var s := kit("window", Vector4(24, 24, 24, 30), Vector4(margin, margin, margin, margin + 6))
	if s != null:
		return s
	var f := box(PAPER, RIM, 3, margin)
	f.set_corner_radius_all(18)
	f.shadow_color = OUTLINE
	f.shadow_offset = Vector2(0, 6)
	return f


## A sheet of cream paper with its stitch (forms, sheets): dark text on it
## (PAPER_INK). Phase 3 turns the panels into these.
static func paper(margin := 22) -> StyleBox:
	var s := kit("paper", Vector4(24, 24, 24, 30), Vector4(margin, margin, margin, margin + 6), true)
	if s != null:
		return s
	var f := box(PAPER_SHEET, RIM, 3, margin)
	f.shadow_color = OUTLINE
	f.shadow_offset = Vector2(0, 6)
	return f


## A text slot on the dark plates; `focus` lights its rim in sun.
static func field(pad := 10, focus := false) -> StyleBox:
	var s := kit("field_focus" if focus else "field", Vector4(12, 12, 12, 12),
		Vector4(pad + 4, pad, pad + 4, pad))
	if s != null:
		return s
	return box(FIELD, RIM_HI if focus else RIM, 3, pad)


## A title ribbon with notched ends (the mockup's .ribbon): `sun` for
## rewards, otherwise pop. Its label goes on top, centred.
static func ribbon(sun := false) -> StyleBox:
	var s := kit("ribbon_sun" if sun else "ribbon", Vector4(16, 10, 16, 10), Vector4(30, 0, 30, 2))
	if s != null:
		return s
	return box(SUN if sun else PRESSED, RIM, 3, 8)


## A text slot on paper: cream, a brown rim, dark bold text.
static func paper_field(e: LineEdit, font_size := 18) -> void:
	var n: StyleBox = kit("slot_paper", Vector4(12, 12, 12, 12), Vector4(14, 8, 14, 8))
	if n == null:
		n = box(Color("f3ddb2"), Color("3b2a1a"), 3, 10)
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", focus_ring())
	e.add_theme_font_override("font", bold(900))
	e.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_selected_color", "font_uneditable_color"]:
		e.add_theme_color_override(c, PAPER_INK)
	e.add_theme_color_override("font_placeholder_color", Color(PAPER_INK, 0.45))
	e.add_theme_color_override("caret_color", PRESSED)
	e.add_theme_color_override("selection_color", Color(1.0, 0.42, 0.24, 0.35))
	e.add_theme_color_override("clear_button_color", Color("7a4a1e"))
	e.add_theme_color_override("clear_button_color_pressed", PRESSED)


## A caption on paper (CUENTA, CONTRASEÑA): brown, bold, spaced.
static func paper_caption(text: String) -> Label:
	var l := caption(text)
	l.add_theme_color_override("font_color", Color("7a4a1e"))
	return l


## A round medallion button (back, language, mail): the kit's medal as its
## face, an icon drawn by `draw_icon(button)` on top.
static func medal_button(d: float, draw_icon: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(d, d)
	b.size = Vector2(d, d)
	b.focus_mode = Control.FOCUS_ALL
	var tex := kit_texture("medal")
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var e := StyleBoxEmpty.new()
		b.add_theme_stylebox_override(st, e)
	b.add_theme_stylebox_override("focus", focus_ring())
	b.draw.connect(func():
		var r := Rect2(Vector2.ZERO, Vector2(d, d * (68.0 / 64.0)))
		if b.is_pressed() or b.button_pressed:
			r.position.y += 2
		if tex != null:
			b.draw_texture_rect(tex, r, false,
				Color(1.15, 1.15, 1.15) if b.is_hovered() else Color.WHITE)
		else:
			b.draw_circle(Vector2(d, d) / 2, d / 2, PLATE)
		draw_icon.call(b))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	return b


## The four-pointed sparkle of rewards and logos (the mockup's .spark).
static func draw_spark(ci: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	var k := r * 0.2
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(k, -k),
		c + Vector2(r, 0), c + Vector2(k, k), c + Vector2(0, r), c + Vector2(-k, k),
		c + Vector2(-r, 0), c + Vector2(-k, -k)]), col)


## The art behind the screens (tools/make_ui_scene.py), or null.
static func scene_texture(n: String) -> Texture2D:
	return _texture("ui/scene/" + n + ".png")


## A piece of scene art placed as in the mockup: `pos` and `h` are the
## mockup's (CSS) position and height; the baked shadow's pad is undone.
const SCENE_PAD := 32


static func figure(parent: Control, n: String, pos: Vector2, h: float) -> TextureRect:
	var tex := scene_texture(n)
	var t := TextureRect.new()
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tex == null:
		return t
	var src_h := tex.get_height() - 2 * SCENE_PAD
	var k := h / src_h
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.size = Vector2(tex.get_width(), tex.get_height()) * k
	t.position = pos - Vector2(SCENE_PAD, SCENE_PAD) * k
	parent.add_child(t)
	return t


## Focus ring: a sun outline just outside the control.
static func focus_ring() -> StyleBoxFlat:
	var s := box(Color(0, 0, 0, 0), RIM_HI, 3, 0)
	s.draw_center = false
	s.set_expand_margin_all(3)
	return s


## A full-rect shade behind modal panels.
static func shade() -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0.03, 0.035, 0.08, 0.7)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Check boxes and toggles: ink rim, a night slot, pop when ticked and a
## green track with a cream knob when on.
static func _icon(w: int, h: int, on: bool, knob: bool, rim := RIM) -> ImageTexture:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, w, h), rim)
	img.fill_rect(Rect2i(3, 3, w - 6, h - 6), FIELD)
	if knob:   # toggle: a knob, left when off, right on a green track
		if on:
			img.fill_rect(Rect2i(3, 3, w - 6, h - 6), OK)
		var k := h - 10
		var x := w - 5 - k if on else 5
		img.fill_rect(Rect2i(x, 5, k, k), INK if on else MUTED)
	elif on:
		img.fill_rect(Rect2i(3, 3, w - 6, h - 6), POP)
		img.fill_rect(Rect2i(7, 7, w - 14, h - 14), INK)
	return ImageTexture.create_from_image(img)


static func _grabber(col := GOLD) -> ImageTexture:
	var img := Image.create(14, 24, false, Image.FORMAT_RGBA8)
	img.fill(OUTLINE)
	img.fill_rect(Rect2i(3, 3, 8, 18), col)
	return ImageTexture.create_from_image(img)


## Backdrop for full screens (login, creation, lobby): the night plate,
## assets/ui/ui_bg.png (tools/make_ui_kit.py; committed, our own art). Without
## the file, a plain night gradient.
const BACKDROP := "ui/ui_bg.png"

const _GRADIENT := """shader_type canvas_item;
void fragment() {
	COLOR = vec4(mix(vec3(0.085, 0.1, 0.2), vec3(0.03, 0.035, 0.08), UV.y), 1.0);
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


## A FIGHTER equipment card's art (equipments/fighters/icons). Its id is
## shared with a coach card whose illustration card_art() would find first,
## a different item (S22).
static var _fighter_art_cache := {}


static func fighter_card_art(cid: int) -> Texture2D:
	if not _fighter_art_cache.has(cid):
		var img := AssetPaths.load_image("gui/images/equipments/fighters/icons/%d.png" % cid)
		_fighter_art_cache[cid] = ImageTexture.create_from_image(img) if img != null else null
	return _fighter_art_cache[cid]


## The one primary action of a screen: the leaning pop button of the mockup
## ("¡A LUCHAR!", "CONECTAR"), its label in the title font with an ink outline.
static func primary(b: Button, font_size := 24) -> void:
	var slice := Vector4(24, 14, 24, 20)
	var pad := Vector4(28, 8, 28, 13)
	var sunk := Vector4(28, 12, 28, 9)   # the face 4 px down, same total
	var n: StyleBox = kit("btn_main", slice, pad)
	var h: StyleBox = kit("btn_main_hover", slice, pad)
	var p: StyleBox = kit("btn_main_pressed", slice, sunk)
	var off: StyleBox = kit("btn_main_off", slice, pad)
	if n == null:
		n = button_box("pop", "", 12)
		h = button_box("pop", "hover", 12)
		p = button_box("pop", "pressed", 12)
		off = button_box("pop", "off", 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", focus_ring())
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", off)
	for c in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", maxi(6, font_size / 3))
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", font_size)


## A raised button of the kit in `colour` (pop, navy, green, sun), its
## label in the title font with an ink outline: "CONECTAR", "Al azar".
static func raised(b: Button, colour := "pop", font_size := 24, pad := 12) -> void:
	b.add_theme_stylebox_override("normal", button_box(colour, "", pad))
	b.add_theme_stylebox_override("hover", button_box(colour, "hover", pad))
	b.add_theme_stylebox_override("pressed", button_box(colour, "pressed", pad))
	b.add_theme_stylebox_override("hover_pressed", button_box(colour, "pressed", pad))
	b.add_theme_stylebox_override("disabled", button_box(colour, "off", pad))
	b.add_theme_stylebox_override("focus", focus_ring())
	for c in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.add_theme_color_override("font_outline_color", OUTLINE)
	b.add_theme_constant_override("outline_size", maxi(6, font_size / 3))
	b.add_theme_font_override("font", title_font())
	b.add_theme_font_size_override("font_size", font_size)


## A title in the game's voice: Lilita One, cream (or `colour`), an ink
## outline and a hard ink shadow straight down.
static func title(l: Label, font_size := 28, colour := INK) -> void:
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_outline_color", OUTLINE)
	l.add_theme_constant_override("outline_size", maxi(6, font_size / 4))
	l.add_theme_color_override("font_shadow_color", OUTLINE)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", maxi(2, font_size / 14))
	l.add_theme_constant_override("shadow_outline_size", maxi(6, font_size / 4))


## Small uppercase caption above a field: bold, spaced, muted.
static func caption(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", _body(900, 1))
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", MUTED)
	return l


## Nunito at a weight (700–900); see _body.
static func bold(weight := 900) -> Font:
	return _body(weight)


## Nunito at a weight (the variable font's wght axis), `spacing` extra px
## between letters. Cached.
static func _body(weight: int, spacing := 0) -> Font:
	var key := "body%d_%d" % [weight, spacing]
	if not _fonts.has(key):
		var f := FontVariation.new()
		f.base_font = _file(FONT_BODY, "gui/fonts/TAHOMA.TTF")
		var ts := TextServerManager.get_primary_interface()
		f.variation_opentype = {ts.name_to_tag("wght"): weight}
		f.spacing_glyph = spacing
		_fonts[key] = f
	return _fonts[key]


## A font file of ours, or `fallback` (the old one) when it is not installed.
static func _file(rel: String, fallback: String) -> FontFile:
	var key := "file:" + rel
	if not _fonts.has(key):
		var f := FontFile.new()
		var path := AssetPaths.resolve(rel)
		if not FileAccess.file_exists(path):
			path = AssetPaths.resolve(fallback)
		f.load_dynamic_font(path)
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		_fonts[key] = f
	return _fonts[key]


## Text: Nunito, always bold (800).
static func body_font() -> Font:
	return _body(800)


## Titles and buttons: Lilita One.
static func title_font() -> FontFile:
	return _file(FONT_TITLE, "gui/fonts/COPRGTB.TTF")


## Theme for every native control: raised navy buttons with a lip, the
## pressed/toggled one in pop, ink borders everywhere, sun on hover and
## focus, sunk night fields, the selected row in pop.
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
		t.set_color("font_outline_color", type, OUTLINE)
	for type in ["Button", "OptionButton"]:
		t.set_font("font", type, title_font())
		t.set_constant("outline_size", type, 6)
		t.set_color("font_pressed_color", type, INK)
		t.set_color("font_hover_pressed_color", type, INK)
		t.set_stylebox("normal", type, button_box("navy", "", pad))
		t.set_stylebox("hover", type, button_box("navy", "hover", pad))
		t.set_stylebox("pressed", type, button_box("pop", "pressed", pad))
		t.set_stylebox("hover_pressed", type, button_box("pop", "pressed", pad))
		t.set_stylebox("disabled", type, button_box("navy", "off", pad))
		t.set_stylebox("focus", type, focus_ring())
		t.set_color("icon_disabled_color", type, MUTED)
	# CheckButton/CheckBox rows sit on the panel, not on a plate
	for type in ["CheckButton", "CheckBox"]:
		t.set_color("font_pressed_color", type, INK)
		t.set_color("font_hover_pressed_color", type, INK)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var flat := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, pad)
			t.set_stylebox(st, type, flat)
		t.set_stylebox("focus", type, focus_ring())
	t.set_stylebox("pressed", "OptionButton", button_box("navy", "pressed", pad))
	t.set_stylebox("hover_pressed", "OptionButton", button_box("navy", "pressed", pad))
	t.set_color("font_pressed_color", "OptionButton", INK)
	for type in ["LineEdit", "TextEdit"]:
		t.set_stylebox("normal", type, field(pad))
		t.set_stylebox("focus", type, field(pad, true))
		t.set_stylebox("read_only", type, box(PAPER, Color("3a3f63"), 2, pad))
		t.set_color("caret_color", type, SUN)
		t.set_color("selection_color", type, Color(0.91, 0.31, 0.12, 0.7))
		t.set_color("font_selected_color", type, INK)
		t.set_color("font_placeholder_color", type, Color(MUTED, 0.7))
	for c in ["font_color", "font_readonly_color"]:
		t.set_color(c, "TextEdit", INK)
	t.set_color("background_color", "TextEdit", Color(0, 0, 0, 0))
	# Tree (the tables): an ink header rule, the selected row in pop.
	t.set_stylebox("panel", "Tree", box(FIELD, RIM, 3, 4))
	t.set_stylebox("focus", "Tree", focus_ring())
	var sel := box(PRESSED, RIM, 0, 0)
	sel.set_corner_radius_all(6)
	t.set_stylebox("selected", "Tree", sel)
	t.set_stylebox("selected_focus", "Tree", sel)
	t.set_stylebox("cursor", "Tree", box(Color(0, 0, 0, 0), RIM_HI, 2, 0))
	t.set_stylebox("cursor_unfocused", "Tree", box(Color(0, 0, 0, 0), PLATE, 2, 0))
	var head := box(PLATE, Color(0, 0, 0, 0), 0, 6)
	head.border_color = RIM
	head.border_width_bottom = 3
	head.set_corner_radius_all(0)
	for st in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		t.set_stylebox(st, "Tree", head)
	t.set_color("title_button_color", "Tree", SUN)
	t.set_font("title_button_font", "Tree", title_font())
	t.set_font_size("title_button_font_size", "Tree", 15)
	t.set_color("font_selected_color", "Tree", INK)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.05))
	t.set_color("relationship_line_color", "Tree", Color(0, 0, 0, 0))
	t.set_constant("v_separation", "Tree", 8)
	# Dropdown menus.
	t.set_stylebox("panel", "PopupMenu", box(PAPER, RIM, 3, 6))
	t.set_stylebox("hover", "PopupMenu", box(PRESSED, PRESSED, 0, 4))
	t.set_color("font_hover_color", "PopupMenu", INK)
	t.set_stylebox("panel", "PopupPanel", box(PAPER, RIM, 3, 6))
	# Scrollbars: a navy bar in an ink gutter, sun when held.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(FIELD, RIM, 2, 2))
		t.set_stylebox("scroll_focus", bar, box(FIELD, RIM, 2, 2))
		t.set_stylebox("grabber", bar, box(Color("4a5499"), RIM, 2, 4))
		t.set_stylebox("grabber_highlight", bar, box(Color("5d68b5"), RIM, 2, 4))
		t.set_stylebox("grabber_pressed", bar, box(SUN, RIM, 2, 4))
	t.set_stylebox("separator", "HSeparator", box(PLATE, PLATE, 0, 0))
	t.set_constant("separation", "HSeparator", 3)
	t.set_stylebox("panel", "PanelContainer", window())
	# Sliders (options): an ink rule and a sun grabber.
	var rail := box(FIELD, RIM, 2, 0)
	rail.content_margin_top = 3
	rail.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", rail)
	var lit := box(SUN, RIM, 2, 0)
	lit.content_margin_top = 3
	lit.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", lit)
	t.set_stylebox("grabber_area_highlight", "HSlider", lit)
	var dim := Color("3a3f63")
	t.set_icon("unchecked", "CheckBox", _icon(22, 22, false, false))
	t.set_icon("checked", "CheckBox", _icon(22, 22, true, false))
	t.set_icon("unchecked_disabled", "CheckBox", _icon(22, 22, false, false, dim))
	t.set_icon("checked_disabled", "CheckBox", _icon(22, 22, true, false, dim))
	t.set_icon("unchecked", "CheckButton", _icon(44, 22, false, true))
	t.set_icon("checked", "CheckButton", _icon(44, 22, true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _icon(44, 22, false, true, dim))
	t.set_icon("checked_disabled", "CheckButton", _icon(44, 22, true, true, dim))
	t.set_icon("grabber", "HSlider", _grabber())
	t.set_icon("grabber_highlight", "HSlider", _grabber(Color("ffe08a")))
	t.set_icon("grabber_disabled", "HSlider", _grabber(MUTED))
	return t
