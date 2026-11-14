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
const PAPER := Color("1d2140")      # plates and window fill (navy)
const MUTED := Color("b9bee0")      # secondary text
const ACCENT := Color("4c8dff")     # the player's own team blue (ally)
const GOLD := Color("e9b44c")       # titles and rewards (old gold)
const RIM := Color("0b0d1c")        # borders: the ink
const RIM_HI := Color("e9b44c")     # hover / focus border
const PLATE := Color("2c3156")      # buttons and fields
const PRESSED := Color("b8471f")    # pressed / toggled (pop, dark)
const RADIUS := 2      # style B: square-ish corners
# S45 palette
const NIGHT := Color("12152a")
const POP := Color("de643a")        # only for the action (a terracotta pop)
const SUN := Color("e9b44c")
const RIVAL := Color("ff4d5e")
const OK := Color("36c98a")
const OUTLINE := Color("0b0d1c")    # the ink
const PAPER_SHEET := Color("f3e3c0")   # the cream paper (forms and sheets)
const PAPER_INK := Color("1c2030")     # text on a sheet (style B ink)
const FIELD := Color("0c0e1e")
const SLOT := Color("f3f4f8")          # a band inside a sheet (slots, rows, footers)
const BROWN := Color("6b7183")         # secondary text on a sheet (style B mute)
const ACCENT_INK := Color("ff4d6d")    # what stands out on a sheet (style B coral)

# style B (S45, owner 2026-11-12): light, minimal, technical lines, one accent
const B_BG := Color("e9ecf1")
const B_INK := Color("1c2030")
const B_MUTE := Color("6b7183")
const B_FAINT := Color("9aa0b0")
const B_CORAL := Color("ff4d6d")
const B_BLUE := Color("2f74f0")
const B_GOLD := Color("d99a2b")

const KIT := "ui/kit/"
const FONT_TITLE := "ui/fonts/LilitaOne-Regular.ttf"
const FONT_BODY := "ui/fonts/Nunito-Variable.ttf"
const FONT_DISPLAY := "ui/fonts/SairaCondensed-ExtraBold.ttf"

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
	# aged parchment (S45 finish): its corners hold the filigree, the rest
	# stretches (the mottling would show seams if tiled)
	var s := kit("paper", Vector4(40, 40, 40, 46), Vector4(margin, margin, margin, margin + 6))
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


## A title ribbon with notched ends (the mockup's .ribbon): "pop", "sun"
## (rewards) or "navy". Its label goes on top, centred.
static func ribbon(kind := "pop") -> StyleBox:
	# a cloth band with folded tails behind its ends (S45 finish)
	var s := kit("ribbon" if kind == "pop" else "ribbon_" + kind, Vector4(28, 16, 28, 18), Vector4(40, 0, 40, 8))
	if s != null:
		return s
	return box({"sun": SUN, "navy": PLATE}.get(kind, PRESSED), RIM, 3, 8)


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
	l.add_theme_color_override("font_color", BROWN)
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


## A screen's header (the mockup's back medallion and pop strip): the
## medallion at (18, top) calls `on_back`; the strip carries `text`.
## Returns the back button.
static func header(parent: Control, text: String, on_back: Callable, top := 18.0) -> Button:
	var strip := Control.new()
	strip.name = "Header"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.position = Vector2(62, top + 1)
	strip.size = Vector2(200, 52)
	var l := Label.new()
	l.name = "HeaderTitle"
	l.text = text
	title(l, 30)
	l.position = Vector2(30, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.uppercase = true
	# the strip follows its title (a panel sets it on every refresh)
	strip.draw.connect(func():
		var w := title_font().get_string_size(l.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 100
		if absf(strip.size.x - w) > 0.5:
			strip.size.x = w
		l.size = Vector2(w - 70, 52)
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.92, 52), Vector2(0, 52)])
		strip.draw_colored_polygon(pts, PRESSED)
		strip.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0),
			Vector2(w * 0.96, 26), Vector2(0, 26)]), Color(POP, 0.6))
		strip.draw_rect(Rect2(0, 0, w, 3), OUTLINE)
		strip.draw_rect(Rect2(0, 49, w * 0.92 + 1, 3), OUTLINE))
	l.draw.connect(strip.queue_redraw)
	parent.add_child(strip)
	strip.add_child(l)
	var back := medal_button(54, func(b: Button):
		var c := Vector2(27, 27)
		b.draw_polyline(PackedVector2Array([c + Vector2(4, -9), c + Vector2(-5, 0), c + Vector2(4, 9)]),
			SUN, 3.6, true))
	back.name = "Back"
	back.position = Vector2(18, top)
	back.tooltip_text = I18n.t("panel.close")
	back.pressed.connect(on_back)
	back.set_meta("title", l)
	parent.add_child(back)
	return back


## A rounded square turned 45° (the mockup's .dia): centre `c`, `half` the
## half-diagonal, corners rounded by `r`.
static func diamond_points(c: Vector2, half: float, r := 8.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var side := half * sqrt(2.0)
	var h := side / 2.0 - r
	for corner in [Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1)]:
		var a0: float = corner.angle() - PI / 4.0
		for i in 7:
			var a := a0 + (PI / 2.0) * i / 6.0
			var p: Vector2 = corner * h + Vector2(cos(a), sin(a)) * r
			pts.append(c + p.rotated(-PI / 4.0))
	return pts


## A diamond button (slots, sections): `fill` its face, `draw_icon(b, c)`
## its icon at the centre. Toggle buttons light a sun ring when on;
## `empty` draws the dashed empty slot.
static func diamond_button(d: float, fill: Color, draw_icon: Callable, empty := false) -> Button:
	var b := Button.new()
	var box_d := d * 1.42 + 12
	b.custom_minimum_size = Vector2(box_d, box_d)
	b.size = b.custom_minimum_size
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func():
		# style B (S45): a thin ink outline on white; coral when picked, a
		# coral outline under the pointer or the focus
		var c := b.size / 2.0
		var half := d * 0.707
		var on := b.toggle_mode and b.button_pressed
		var lit := b.is_hovered() or b.has_focus()
		var face: Color = B_CORAL if on else (Color(1, 1, 1, 0.6) if empty else fill)
		b.draw_colored_polygon(diamond_points(c, half, 4), face)
		var loop := diamond_points(c, half, 4)
		loop.append(loop[0])
		var rim: Color = B_CORAL if lit and not on else (B_CORAL if on else Color(B_INK, 0.35 if empty else 0.8))
		b.draw_polyline(loop, rim, 2.0 if not on else 3.0, true)
		draw_icon.call(b, c))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.toggled.connect(func(_on): b.queue_redraw())
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	return b


## A colour gem (the mockup's .gem): ink rim, a light top, a dark bottom
## and a hard shadow; when picked, a pop ring around it.
static func gem_button(d: float, col: Color) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(d + 16, d + 16)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func():
		var c := b.size / 2.0 - Vector2(0, 1)
		var r := d / 2.0
		if b.button_pressed:
			b.draw_arc(c, r + 6, 0, TAU, 40, PRESSED, 4.0, true)
		elif b.has_focus():
			b.draw_arc(c, r + 5, 0, TAU, 40, SUN, 2.5, true)
		b.draw_circle(c + Vector2(0, 3), r, OUTLINE)
		b.draw_circle(c, r, OUTLINE)
		var face := col.lightened(0.08) if b.is_hovered() else col
		b.draw_circle(c, r - 3, face)
		b.draw_arc(c, r - 6, PI * 0.15, PI * 0.85, 16, Color(0, 0, 0, 0.25), 5.0, true)
		b.draw_arc(c, r - 5.5, PI * 1.2, PI * 1.8, 16, Color(1, 1, 1, 0.45), 3.5, true))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.toggled.connect(func(_on): b.queue_redraw())
	b.focus_entered.connect(b.queue_redraw)
	b.focus_exited.connect(b.queue_redraw)
	return b


## The sun chevron that turns a figure (the mockup's .chev), pointing right
## or, `left`, left.
static func chevron_button(left: bool, col := SUN) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(54, 76)
	b.size = b.custom_minimum_size
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func():
		var w := 54.0
		var h := 70.0
		var dy := 2.0 if b.is_pressed() else 0.0
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(w * 0.55, 0), Vector2(w, h / 2),
			Vector2(w * 0.55, h), Vector2(0, h), Vector2(w * 0.45, h / 2)])
		if left:
			for i in pts.size():
				pts[i].x = w - pts[i].x
		var sh := PackedVector2Array()
		var face := PackedVector2Array()
		for p in pts:
			sh.append(p + Vector2(0, 4))
			face.append(p + Vector2(0, dy))
		if not b.is_pressed():
			b.draw_colored_polygon(sh, OUTLINE)
		var fill := col.lightened(0.15) if b.is_hovered() else col
		b.draw_colored_polygon(face, fill)
		if b.has_focus():
			b.draw_polyline(face + PackedVector2Array([face[0]]), INK, 2.0, true))
	b.mouse_entered.connect(b.queue_redraw)
	b.mouse_exited.connect(b.queue_redraw)
	b.button_down.connect(b.queue_redraw)
	b.button_up.connect(b.queue_redraw)
	return b


## The round pedestal a figure stands on (the mockup's .ped): purple stone
## lit in the middle, an ink rim, a gold ring and a dark lower lip.
static func draw_pedestal(ci: CanvasItem, r: Rect2) -> void:
	var c := r.get_center()
	var rad := r.size / 2.0
	ci.draw_set_transform(c, 0.0, Vector2(1.0, rad.y / rad.x))
	ci.draw_circle(Vector2.ZERO, rad.x, OUTLINE)
	ci.draw_circle(Vector2.ZERO, rad.x - 4, Color("241e40"))
	ci.draw_circle(Vector2.ZERO, rad.x - 10, Color("3a3260"))
	ci.draw_circle(Vector2(0, -rad.x * 0.06), rad.x * 0.6, Color("4e4475"))
	ci.draw_circle(Vector2(0, -rad.x * 0.08), rad.x * 0.3, Color("6a5a86"))
	ci.draw_arc(Vector2.ZERO, rad.x - 8, 0, TAU, 64, Color(0.91, 0.66, 0.23, 0.85), 6.0, true)
	ci.draw_arc(Vector2.ZERO, rad.x - 12, PI * 0.1, PI * 0.9, 32, Color(0, 0, 0, 0.3), 8.0, true)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A full-screen backdrop of scene art (cover), or the night when missing.
static func scene_backdrop(parent: Control, n: String, size: Vector2) -> void:
	var night := ColorRect.new()
	night.color = NIGHT
	night.size = size
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(night)
	var tex := scene_texture(n)
	if tex == null:
		return
	var bg := TextureRect.new()
	bg.texture = tex
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


## A radial shade over the art (CSS radial-gradient(rx ry at cx cy,
## rgba(inner) 0, rgba(outer) 100%)), in REF pixels.
static func vignette(parent: Control, size: Vector2, centre: Vector2, radius: Vector2,
		inner: Color, outer: Color) -> ColorRect:
	var cr := ColorRect.new()
	cr.size = size
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _vignette_shader()
	mat.set_shader_parameter("ref", size)
	mat.set_shader_parameter("centre", centre)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("inner", inner)
	mat.set_shader_parameter("outer", outer)
	cr.material = mat
	parent.add_child(cr)
	return cr


static var _vig: Shader


static func _vignette_shader() -> Shader:
	if _vig == null:
		_vig = Shader.new()
		_vig.code = """shader_type canvas_item;
uniform vec2 ref; uniform vec2 centre; uniform vec2 radius;
uniform vec4 inner : source_color; uniform vec4 outer : source_color;
void fragment() {
	float d = clamp(length((UV * ref - centre) / radius), 0.0, 1.0);
	COLOR = mix(inner, outer, d);
}"""
	return _vig


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
	# S38: our own coach icon (the 3D piece, tools/icons); S38b: no retail
	# illustration behind it — the other cards show the card template
	for dir in ["ui/equip_coach/"]:
		var img := AssetPaths.load_image(dir + "%d.png" % cid)
		if img != null:
			tex = ImageTexture.create_from_image(img)
			break
	_card_art_cache[cid] = tex
	return tex


## A coin's icon (wallet type: 1 the Card Master tokens, 2/3/5 the others,
## 10 the pesetas), cached; ours (S38b, tools/icons/badge_icons.py) first,
## null for a type we have no coin for.
static var _token_cache := {}


static func token_icon(type: int) -> Texture2D:
	if not _token_cache.has(type):
		var img := AssetPaths.load_image("ui/tokens/%d.png" % type)
		_token_cache[type] = ImageTexture.create_from_image(img) if img != null else null
	return _token_cache[type]


## A FIGHTER equipment card's art (equipments/fighters/icons). Its id is
## shared with a coach card whose illustration card_art() would find first,
## a different item (S22).
static var _fighter_art_cache := {}


static func fighter_card_art(cid: int) -> Texture2D:
	if not _fighter_art_cache.has(cid):
		# S38: our own icon (the 3D piece, tools/icons/equip_icons) first
		var img := AssetPaths.load_image("ui/equip/%d.png" % cid)
		_fighter_art_cache[cid] = ImageTexture.create_from_image(img) if img != null else null
	return _fighter_art_cache[cid]


## The one primary action of a screen (style B, S45): a slanted coral box
## with its leaning white title ("Comprar", "Enviar", "Llevar puesto").
static func primary(b: Button, font_size := 24) -> void:
	_b_boxes(b, B_CORAL, maxi(8, font_size / 2))
	b.add_theme_font_override("font", display_font())
	b.add_theme_font_size_override("font_size", font_size)


## The slanted box a style B button wears in each state, and white text.
static func _b_boxes(b: Button, col: Color, pad := 10) -> void:
	var make := func(c: Color) -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = c
		s.skew = Vector2(0.22, 0)
		s.content_margin_left = pad + 12
		s.content_margin_right = pad + 12
		s.content_margin_top = maxf(2, pad * 0.5)
		s.content_margin_bottom = maxf(2, pad * 0.5)
		return s
	b.add_theme_stylebox_override("normal", make.call(col))
	b.add_theme_stylebox_override("hover", make.call(col.lightened(0.12)))
	b.add_theme_stylebox_override("pressed", make.call(col.darkened(0.15)))
	b.add_theme_stylebox_override("hover_pressed", make.call(col.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", make.call(Color("c3c7d1")))
	var f: StyleBoxFlat = make.call(Color(0, 0, 0, 0))
	f.draw_center = false
	f.border_color = B_GOLD if col == B_CORAL else B_CORAL
	f.set_border_width_all(2)
	f.set_expand_margin_all(3)
	b.add_theme_stylebox_override("focus", f)
	for c in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
	b.add_theme_constant_override("outline_size", 0)


## A style B button in `colour`'s role: "pop" (the action) coral, the
## rest ink ("Al azar", "Deshacer").
static func raised(b: Button, colour := "pop", font_size := 24, pad := 12) -> void:
	_b_boxes(b, B_CORAL if colour == "pop" else B_INK, pad)
	b.add_theme_font_override("font", display_font())
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
	# its colour comes from the theme: lavender on navy, brown on paper
	l.theme_type_variation = "Caption"
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


## Style B's titles: Saira Condensed ExtraBold, leaning (the family has
## no italic, so the glyphs are sheared).
static func display_font() -> Font:
	if not _fonts.has("display"):
		var f := FontVariation.new()
		f.base_font = _file(FONT_DISPLAY, FONT_TITLE)
		f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-0.2, 1), Vector2.ZERO)
		f.spacing_glyph = 1
		_fonts["display"] = f
	return _fonts["display"]


## A style B title: big, leaning, uppercase, in ink (or `colour`).
static func display(l: Label, font_size := 32, colour := B_INK) -> void:
	l.add_theme_font_override("font", display_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("outline_size", 0)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	l.uppercase = true


## A style B tag: tiny, bold, widely spaced, grey ("STORY · 01").
static func tag(text: String, colour := B_MUTE) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", _body(800, 3))
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Titles and buttons: Lilita One.
static func title_font() -> FontFile:
	return _file(FONT_TITLE, "gui/fonts/COPRGTB.TTF")


## Theme for every native control: raised navy buttons with a lip, the
## pressed/toggled one in pop, ink borders everywhere, sun on hover and
## focus, sunk night fields, the selected row in pop.
## `pad` is the inner margin of buttons and fields (compact chat: 3).
## The theme inside a sheet (every panel; S45 style B since 2026-11-13):
## ink text on white, buttons as slanted ink boxes (coral when pressed or
## picked) with leaning white titles, fields with an ink rule under them,
## tables with a thin header rule and the picked row in coral.
static func paper_theme(pad := 10) -> Theme:
	var t := theme(pad)
	var ink := B_INK
	for type in ["Label", "CheckButton", "CheckBox", "RichTextLabel", "ItemList", "Tree", "LinkButton"]:
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color",
				"font_hover_pressed_color", "default_color"]:
			t.set_color(c, type, ink)
		t.set_color("font_disabled_color", type, B_FAINT)
		t.set_color("font_outline_color", type, Color(1, 1, 1, 0))
	t.set_color("font_selected_color", "Tree", Color.WHITE)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	t.set_color("font_color", "Caption", B_MUTE)
	# buttons: a slanted ink box, coral when held or picked
	var make := func(col: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = col
		b.skew = Vector2(0.22, 0)
		b.content_margin_left = pad + 10
		b.content_margin_right = pad + 10
		b.content_margin_top = maxf(2, pad * 0.5)
		b.content_margin_bottom = maxf(2, pad * 0.5)
		return b
	for type in ["Button", "OptionButton"]:
		t.set_stylebox("normal", type, make.call(ink))
		t.set_stylebox("hover", type, make.call(ink.lightened(0.15)))
		t.set_stylebox("pressed", type, make.call(B_CORAL))
		t.set_stylebox("hover_pressed", type, make.call(B_CORAL.lightened(0.1)))
		t.set_stylebox("disabled", type, make.call(Color("c3c7d1")))
		var f: StyleBoxFlat = make.call(Color(0, 0, 0, 0))
		f.draw_center = false
		f.border_color = B_CORAL
		f.set_border_width_all(2)
		f.set_expand_margin_all(3)
		t.set_stylebox("focus", type, f)
		t.set_font("font", type, display_font())
		t.set_constant("outline_size", type, 0)
		for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			t.set_color(c, type, Color.WHITE)
		t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.8))
	t.set_stylebox("pressed", "OptionButton", make.call(ink.lightened(0.15)))
	# check rows stay flat on the sheet
	for type in ["CheckButton", "CheckBox"]:
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			t.set_stylebox(st, type, StyleBoxEmpty.new())
	var dim := Color("c3c7d1")
	t.set_icon("unchecked", "CheckBox", _b_check(false, ink))
	t.set_icon("checked", "CheckBox", _b_check(true, ink))
	t.set_icon("unchecked_disabled", "CheckBox", _b_check(false, dim))
	t.set_icon("checked_disabled", "CheckBox", _b_check(true, dim))
	t.set_icon("unchecked", "CheckButton", _b_toggle(false, ink))
	t.set_icon("checked", "CheckButton", _b_toggle(true, ink))
	t.set_icon("unchecked_disabled", "CheckButton", _b_toggle(false, dim))
	t.set_icon("checked_disabled", "CheckButton", _b_toggle(true, dim))
	# fields: white with an ink rule (coral with the focus)
	for type in ["LineEdit", "TextEdit"]:
		var n := StyleBoxFlat.new()
		n.bg_color = SLOT
		n.border_color = ink
		n.border_width_bottom = 2
		n.content_margin_left = pad + 4
		n.content_margin_right = pad + 4
		n.content_margin_top = pad * 0.6
		n.content_margin_bottom = pad * 0.6
		var fo: StyleBoxFlat = n.duplicate()
		fo.border_color = B_CORAL
		fo.border_width_bottom = 3
		t.set_stylebox("normal", type, n)
		t.set_stylebox("focus", type, fo)
		var ro: StyleBoxFlat = n.duplicate()
		ro.border_color = Color(ink, 0.2)
		t.set_stylebox("read_only", type, ro)
		for c in ["font_color", "font_readonly_color", "font_selected_color", "font_uneditable_color"]:
			t.set_color(c, type, ink)
		t.set_color("font_placeholder_color", type, B_FAINT)
		t.set_color("caret_color", type, B_CORAL)
		t.set_color("selection_color", type, Color(B_CORAL, 0.25))
		t.set_color("clear_button_color", type, B_MUTE)
	t.set_font("font", "LineEdit", bold(800))
	# tables: white, a thin header rule, the picked row coral
	for type in ["Tree", "ItemList"]:
		var p := StyleBoxFlat.new()
		p.bg_color = Color.WHITE
		p.border_color = Color(ink, 0.15)
		p.set_border_width_all(1)
		p.content_margin_left = 4
		p.content_margin_right = 4
		p.content_margin_top = 4
		p.content_margin_bottom = 4
		t.set_stylebox("panel", type, p)
	var sel := StyleBoxFlat.new()
	sel.bg_color = B_CORAL
	t.set_stylebox("selected", "Tree", sel)
	t.set_stylebox("selected_focus", "Tree", sel)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel)
	# the row under the pointer: a faint coral tint (the default was a dark block)
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(B_CORAL, 0.12)
	for st in ["hovered", "hovered_dimmed", "hovered_selected", "hovered_selected_focus"]:
		t.set_stylebox(st, "Tree", hov)
	t.set_stylebox("hovered", "ItemList", hov)
	# the cell under the pointer and the hovered row's text: Godot's defaults
	# (a dark block, white text on the faint tint) showed through (S38b)
	for st in ["button_hover", "button_pressed", "custom_button", "custom_button_hover", "custom_button_pressed"]:
		t.set_stylebox(st, "Tree", StyleBoxEmpty.new())
	t.set_color("font_hovered_color", "Tree", ink)
	t.set_color("font_hovered_dimmed_color", "Tree", ink)
	t.set_color("font_hovered_selected_color", "Tree", Color.WHITE)
	t.set_stylebox("cursor", "Tree", box(Color(0, 0, 0, 0), B_CORAL, 1, 0))
	t.set_stylebox("cursor_unfocused", "Tree", box(Color(0, 0, 0, 0), Color(ink, 0.2), 1, 0))
	var head := StyleBoxFlat.new()
	head.bg_color = Color.WHITE
	head.border_color = ink
	head.border_width_bottom = 2
	head.content_margin_top = 6
	head.content_margin_bottom = 6
	for st in ["title_button_normal", "title_button_hover", "title_button_pressed"]:
		t.set_stylebox(st, "Tree", head)
	t.set_color("title_button_color", "Tree", B_MUTE)
	t.set_font("title_button_font", "Tree", _body(800, 2))
	t.set_font_size("title_button_font_size", "Tree", 11)
	t.set_color("guide_color", "Tree", Color(ink, 0.06))
	for bar in ["VScrollBar", "HScrollBar"]:
		var gut := StyleBoxFlat.new()
		gut.bg_color = Color(ink, 0.06)
		gut.content_margin_left = 3
		gut.content_margin_right = 3
		var grab := StyleBoxFlat.new()
		grab.bg_color = Color(ink, 0.5)
		grab.content_margin_left = 3
		grab.content_margin_right = 3
		var grab_h: StyleBoxFlat = grab.duplicate()
		grab_h.bg_color = B_CORAL
		t.set_stylebox("scroll", bar, gut)
		t.set_stylebox("scroll_focus", bar, gut)
		t.set_stylebox("grabber", bar, grab)
		t.set_stylebox("grabber_highlight", bar, grab_h)
		t.set_stylebox("grabber_pressed", bar, grab_h)
	var rule := StyleBoxLine.new()
	rule.color = Color(ink, 0.15)
	rule.thickness = 1
	t.set_stylebox("separator", "HSeparator", rule)
	t.set_stylebox("separator", "VSeparator", rule)
	var band := StyleBoxFlat.new()
	band.bg_color = SLOT
	band.content_margin_left = 12
	band.content_margin_right = 12
	band.content_margin_top = 10
	band.content_margin_bottom = 10
	t.set_stylebox("panel", "PanelContainer", band)
	t.set_stylebox("panel", "Panel", band)
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(ink, 0.15)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	t.set_stylebox("slider", "HSlider", rail)
	var lit := StyleBoxFlat.new()
	lit.bg_color = B_CORAL
	lit.content_margin_top = 2
	lit.content_margin_bottom = 2
	t.set_stylebox("grabber_area", "HSlider", lit)
	t.set_stylebox("grabber_area_highlight", "HSlider", lit)
	t.set_icon("grabber", "HSlider", _b_grabber(ink))
	t.set_icon("grabber_highlight", "HSlider", _b_grabber(B_CORAL))
	t.set_icon("grabber_disabled", "HSlider", _b_grabber(B_FAINT))
	t.set_stylebox("panel", "PopupMenu", box(Color.WHITE, Color(ink, 0.2), 1, 6))
	t.set_stylebox("hover", "PopupMenu", box(B_CORAL, B_CORAL, 0, 4))
	for c in ["font_color", "font_disabled_color"]:
		t.set_color(c, "PopupMenu", ink)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	return t


static func _b_grabber(col: Color) -> ImageTexture:
	var img := Image.create(10, 22, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return ImageTexture.create_from_image(img)


static func _b_check(on: bool, col: Color) -> ImageTexture:
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, 20, 20), col)
	img.fill_rect(Rect2i(2, 2, 16, 16), Color.WHITE)
	if on:
		img.fill_rect(Rect2i(5, 5, 10, 10), B_CORAL)
	return ImageTexture.create_from_image(img)


static func _b_toggle(on: bool, col: Color) -> ImageTexture:
	var img := Image.create(40, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(0, 0, 40, 20), B_CORAL if on else col)
	img.fill_rect(Rect2i(2, 2, 36, 16), B_CORAL if on else Color.WHITE)
	img.fill_rect(Rect2i(22 if on else 4, 4, 14, 12), Color.WHITE if on else col)
	return ImageTexture.create_from_image(img)


static func theme(pad := 10) -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 17
	t.set_type_variation("Caption", "Label")
	t.set_color("font_color", "Caption", MUTED)
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
