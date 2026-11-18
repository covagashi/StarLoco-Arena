extends RefCounted
## Style B (S45, the owner's pick on 2026-11-12: "minimalista pero buenas
## animaciones"): the pieces every screen shares. A light backdrop of its
## own per screen (never an arena render: a huge outlined word, soft ghosts,
## a coral band, thin technical lines with crosses and a code tag), slanted
## buttons (coral for the action, ink otherwise), fields with an ink rule
## under them, tags, and the entrance tweens. Colours and fonts live in
## ui_style.gd (B_*, display_font).

const UiStyle := preload("res://src/ui/ui_style.gd")
const INK := UiStyle.B_INK
const CORAL := UiStyle.B_CORAL

const _LIGHT := """shader_type canvas_item;
uniform vec2 centre = vec2(0.3, 0.4);
void fragment() {
	float d = length((UV - centre) * vec2(1.0 / 0.7, 1.0 / 0.9));
	vec3 c = mix(vec3(1.0), vec3(0.914, 0.925, 0.945), smoothstep(0.0, 0.6, d));
	c = mix(c, vec3(0.875, 0.89, 0.918), smoothstep(0.6, 1.2, d));
	COLOR = vec4(c, 1.0);
}"""

static var _light_sh: Shader


## The light backdrop of a screen: `word` huge and outlined (it drifts),
## `ghost` (a scene texture name, or "") soft behind, a coral band, and the
## frame lines with `code` ("PPA // LOGIN · 00") at the top right. Returns
## the drift list for drift(): [node, base, amplitude, period].
static func backdrop(parent: Control, size: Vector2, word: String, code: String,
		ghost := "", centre := Vector2(0.3, 0.4), band_y := 360.0) -> Array:
	var drifts: Array = []
	var light := ColorRect.new()
	light.size = size
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	if _light_sh == null:
		_light_sh = Shader.new()
		_light_sh.code = _LIGHT
	mat.shader = _light_sh
	mat.set_shader_parameter("centre", centre)
	light.material = mat
	parent.add_child(light)
	if word != "":
		var w := Label.new()
		w.text = word
		UiStyle.display(w, 300, Color(0, 0, 0, 0))
		w.add_theme_color_override("font_outline_color", Color(INK, 0.07))
		w.add_theme_constant_override("outline_size", 4)
		w.position = Vector2(-30, 40)
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(w)
		drifts.append([w, w.position, Vector2(40, 0), 38.0])
	if ghost != "":
		var tex := UiStyle.scene_texture(ghost)
		if tex != null:
			var g := TextureRect.new()
			g.texture = tex
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.stretch_mode = TextureRect.STRETCH_SCALE
			var h := 1200.0
			g.size = Vector2(h * tex.get_width() / tex.get_height(), h)
			g.position = Vector2(size.x * 0.2, -220)
			g.modulate.a = 0.55
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			parent.add_child(g)
			drifts.append([g, g.position, Vector2(0, 16), 23.0])
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(0, band_y), Vector2(size.x * 0.56, band_y - 100),
		Vector2(size.x * 0.56, band_y + 70), Vector2(0, band_y + 170)])
	band.vertex_colors = PackedColorArray([Color(CORAL, 0.1), Color(CORAL, 0.0), Color(CORAL, 0.0), Color(CORAL, 0.1)])
	parent.add_child(band)
	drifts.append([band, band.position, Vector2(0, 10), 17.0])
	splash_dress(parent, size, centre.x * size.x)
	parent.add_child(frame_lines(size, code))
	return drifts


## The loading splash's dressing (S44, tools/splash/splash.vx.js), so every
## screen around it looks like the same game: a pale coral beam falling
## behind the figures (`beam_x`: its centre at the bottom), a thin wedge in
## the top right corner, coral speed lines and a few four-point sparkles.
static func splash_dress(parent: Control, size: Vector2, beam_x: float) -> void:
	var beam := Polygon2D.new()
	beam.polygon = PackedVector2Array([Vector2(beam_x - 60, 0), Vector2(beam_x + 360, 0),
		Vector2(beam_x + 160, size.y - 140), Vector2(beam_x - 140, size.y - 140)])
	beam.vertex_colors = PackedColorArray([Color(CORAL, 0.2), Color(CORAL, 0.12),
		Color(CORAL, 0.02), Color(CORAL, 0.06)])
	parent.add_child(beam)
	var wedge := Polygon2D.new()
	wedge.polygon = PackedVector2Array([Vector2(size.x - 160, 0), Vector2(size.x, 0), Vector2(size.x - 90, 300)])
	wedge.color = Color(CORAL, 0.1)
	parent.add_child(wedge)
	var bits := Control.new()
	bits.size = size
	bits.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bits.draw.connect(func():
		for i in 4:   # speed lines, leaning like the splash's
			var y := 250.0 + i * 22.0
			var x := beam_x + 380.0 - i * 18.0
			bits.draw_line(Vector2(x, y), Vector2(x + 120 - i * 14, y - 6), Color(CORAL, 0.45), 3.0, true)
		for s: Array in [[Vector2(beam_x - 210, 140), 9.0, CORAL], [Vector2(beam_x + 330, 470), 7.0, CORAL],
				[Vector2(beam_x - 260, 520), 6.0, INK], [Vector2(beam_x + 420, 120), 5.0, INK]]:
			sparkle(bits, s[0], s[1], s[2]))
	parent.add_child(bits)


## A four-point star, the splash's sparkle.
static func sparkle(on: CanvasItem, at: Vector2, r: float, colour: Color) -> void:
	var t := r * 0.28
	on.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(t, -t), at + Vector2(r, 0),
		at + Vector2(t, t), at + Vector2(0, r), at + Vector2(-t, t), at + Vector2(-r, 0), at + Vector2(-t, -t)]), colour)


## The menus' figures sway on their feet, a little out of step, like paper
## cut-outs (owner: "como PaRappa the Rapper"). Rotation only, about the
## pivot the caller set at the feet, on top of each figure's own angle, so
## the entrance tween (position) and the tiles' hover (scale) keep working.
static func sway(figs: Array, t: float, degrees := 1.8) -> void:
	for i in figs.size():
		var f: Control = figs[i]
		if not is_instance_valid(f):
			continue
		if not f.has_meta("sway_base"):
			f.set_meta("sway_base", f.rotation_degrees)
		var period := 1.6 + 0.37 * i
		f.rotation_degrees = float(f.get_meta("sway_base")) + degrees * sin(TAU * t / period + i * 1.3)


## The frame's thin lines (top and bottom rules, a centre column), crosses
## where they meet, and the code tag.
static func frame_lines(size: Vector2, code: String, mid := 640.0) -> Control:
	var lines := Control.new()
	lines.size = size
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func():
		var c := Color(INK, 0.25)
		lines.draw_line(Vector2(24, 92), Vector2(size.x - 24, 92), c, 1.0)
		lines.draw_line(Vector2(24, size.y - 56), Vector2(size.x - 24, size.y - 56), c, 1.0)
		if mid > 0.0:
			lines.draw_line(Vector2(mid, 92), Vector2(mid, size.y - 56), Color(INK, 0.1), 1.0)
		for p in [Vector2(mid if mid > 0.0 else size.x * 0.5, 92), Vector2(24, size.y - 56), Vector2(size.x - 24, size.y - 56)]:
			lines.draw_line(p - Vector2(7, 0), p + Vector2(7, 0), INK, 2.0)
			lines.draw_line(p - Vector2(0, 7), p + Vector2(0, 7), INK, 2.0)
		var f := UiStyle.bold(700)
		var w := f.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		lines.draw_string(f, Vector2(size.x - 24 - w, 104), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.B_FAINT))
	return lines


## Move the drift list's nodes (call from _process with the running time).
static func drift(drifts: Array, t: float) -> void:
	for d in drifts:
		d[0].position = d[1] + d[2] * sin(TAU * t / float(d[3]))


## A slanted button: coral for the action (with an ink shadow), ink
## otherwise; its text white and leaning, drawn here because the box is.
static func button(primary: bool, font_size := 18) -> Button:
	var b := Button.new()
	var font := UiStyle.display_font()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("outline_size", 0)
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(col, Color(0, 0, 0, 0))
	b.draw.connect(func():
		var s := b.size
		var k := minf(18.0, s.y * 0.3)
		var dy := 2.0 if b.is_pressed() else 0.0
		var face := PackedVector2Array([Vector2(k, dy), Vector2(s.x, dy), Vector2(s.x - k, s.y + dy), Vector2(0, s.y + dy)])
		var col: Color = (CORAL if primary else INK)
		if b.disabled:
			col = Color("b8bcc8")
		elif b.is_hovered():
			col = col.lightened(0.12)
		if primary and not b.disabled and not b.is_pressed():
			var sh := PackedVector2Array()
			for p in face:
				sh.append(p + Vector2(5, 5))
			b.draw_colored_polygon(sh, Color(INK, 0.9))
		b.draw_colored_polygon(face, col)
		if b.has_focus():
			var loop := face.duplicate()
			loop.append(face[0])
			b.draw_polyline(loop, UiStyle.B_GOLD if primary else CORAL, 2.0, true)
		var t := b.text.to_upper()
		var fs := b.get_theme_font_size("font_size")
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := Vector2((s.x - ts.x) * 0.5, (s.y + fs * 0.72) * 0.5 + dy)
		b.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, 0.7) if b.disabled else Color.WHITE))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited, b.button_down, b.button_up]:
		sig.connect(b.queue_redraw)
	return b


## A text field: white, an ink rule under it (coral with the focus), ink
## bold text.
static func field(e: LineEdit, font_size := 18) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(1, 1, 1, 0.9)
	n.border_color = INK
	n.border_width_bottom = 2
	n.content_margin_left = 12
	n.content_margin_right = 12
	var f: StyleBoxFlat = n.duplicate()
	f.border_color = CORAL
	f.border_width_bottom = 3
	e.add_theme_stylebox_override("normal", n)
	e.add_theme_stylebox_override("focus", f)
	e.add_theme_font_override("font", UiStyle.bold(800))
	e.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_selected_color", "font_uneditable_color"]:
		e.add_theme_color_override(c, INK)
	e.add_theme_color_override("font_placeholder_color", UiStyle.B_FAINT)
	e.add_theme_color_override("caret_color", CORAL)
	e.add_theme_color_override("selection_color", Color(CORAL, 0.25))
	e.add_theme_color_override("clear_button_color", UiStyle.B_MUTE)
	e.add_theme_color_override("clear_button_color_pressed", CORAL)


## A white plate with an ink rule along its top (sheets, forms, panels).
static func plate(alpha := 0.92) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1, 1, 1, alpha)
	s.border_color = INK
	s.border_width_top = 3
	s.shadow_color = Color(INK, 0.12)
	s.shadow_size = 18
	s.shadow_offset = Vector2(0, 10)
	return s


## The entrance: each node comes from `offset` and fades in, one after the
## other (`gap` seconds apart), easing out.
static func enter(owner: Node, nodes: Array, offset: Vector2, delay := 0.0, gap := 0.06, time := 0.5) -> Tween:
	var tw := owner.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var k := 0
	for n in nodes:
		if n == null:
			continue
		var to: Vector2 = n.position
		n.position = to + offset
		n.modulate.a = 0.0
		tw.tween_property(n, "position", to, time).set_delay(delay + gap * k)
		tw.tween_property(n, "modulate:a", 1.0, time * 0.8).set_delay(delay + gap * k)
		k += 1
	return tw

## A ribbon with swallowtail ends and a hard shadow, its text white and
## leaning (the recruit's plate cap, the inventory's lists). `lit`: a coral
## rule under the text (the pointer is on what it names).
static func ribbon(c: Control, text: String, fill: Color, font_size: int, lit := false) -> void:
	var s := c.size
	var k := s.y * 0.4
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x - k, s.y * 0.5),
		Vector2(s.x, s.y), Vector2(0, s.y), Vector2(k, s.y * 0.5)])
	var sh := PackedVector2Array()
	for p in shape:
		sh.append(p + Vector2(3, 3))
	c.draw_colored_polygon(sh, Color(INK, 0.9 if fill != INK else 0.35))
	c.draw_colored_polygon(shape, fill)
	var font := UiStyle.display_font()
	var t := text.to_upper()
	var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := Vector2((s.x - ts.x) * 0.5, (s.y + font_size * 0.72) * 0.5)
	c.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if lit:
		c.draw_line(Vector2(at.x, at.y + 4), Vector2(at.x + ts.x, at.y + 4), CORAL, 2.0)


## A choice among a few (sex, mode, an order): a slanted face with a hard
## shadow, coral and white text when picked, white with an ink rim and ink
## text when not.
static func choice(font_size := 16) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(col, Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	var font := UiStyle.display_font()
	b.draw.connect(func():
		var s := b.size - Vector2(4, 4)
		var k := 10.0
		var face := PackedVector2Array([Vector2(k, 0), Vector2(s.x, 0), Vector2(s.x - k, s.y), Vector2(0, s.y)])
		var on := b.button_pressed
		var lit := b.is_hovered() or b.has_focus()
		var sh := PackedVector2Array()
		for p in face:
			sh.append(p + Vector2(4, 4))
		b.draw_colored_polygon(sh, Color(INK, 0.9 if on else 0.25))
		b.draw_colored_polygon(face, CORAL if on else Color.WHITE)
		var loop := face.duplicate()
		loop.append(face[0])
		b.draw_polyline(loop, CORAL if lit and not on else INK, 2.0, true)
		var t := b.text.to_upper()
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		b.draw_string(font, Vector2((s.x - ts.x) * 0.5, (s.y + font_size * 0.72) * 0.5), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE if on else INK))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited, b.toggled]:
		sig.connect(func(_a = null): b.queue_redraw())
	return b


## A white slab with a hard ink shadow and a cut bottom-right corner (the
## recruit's class plate, the inventory's lists and album); `rules` faint
## technical lines across it, so the slab is paper. Returns the face, for a
## rim a caller draws over it.
static func draw_slab(c: CanvasItem, s: Vector2, cut := 22.0, rules := 0) -> PackedVector2Array:
	var face := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y - cut),
		Vector2(s.x - cut, s.y), Vector2(0, s.y)])
	var sh := PackedVector2Array()
	for p in face:
		sh.append(p + Vector2(6, 6))
	c.draw_colored_polygon(sh, Color(INK, 0.9))
	c.draw_colored_polygon(face, Color(1, 1, 1, 0.96))
	var loop := face.duplicate()
	loop.append(face[0])
	c.draw_polyline(loop, INK, 2.5, true)
	for i in rules:
		var y := 60.0 + i * 72.0
		c.draw_line(Vector2(10, y), Vector2(s.x - 10, y), Color(INK, 0.06), 1.0)
	return face
