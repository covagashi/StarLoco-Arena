extends SceneTree

## S37: every shape × element of the effect library (src/fx/vfx.gd) on a
## grid of small stone floors, each with a caster and a target dummy, the
## effect replayed every LOOP seconds. Run it under the movie maker;
## tools/fx/vfx_sheet.sh turns the frames into an MP4 and sheet pages.
##
##   godot --path godot --write-movie <dir>/f.png --fixed-fps 30 \
##       -s tools/fx/vfx_sheet.gd -- [--secs=4.4] [--shapes=bolt,hit] [--elems=fire]
## (the window size comes from override.cfg — see vfx_sheet.sh)

const Vfx := preload("res://src/fx/vfx.gd")
const TILE := Vector2(200, 170)
const HEAD := Vector2(70, 26)
const LOOP := 2.0
const BG := Color("20252b")
const FLOOR := Color("454a50")
const EDGE := Color("5b6168")
const GOLD := Color("e2bd6e")

var opts := {"secs": "4.4", "shapes": ",".join(Vfx.SHAPES), "elems": ",".join(Vfx.ELEMS)}
var _tiles: Array = []   # [node, shape, elem, from, to]
var _t := 0.0
var _next := 0.3
var _secs := 4.4


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	_secs = float(opts.secs)
	_build.call_deferred()


func _build() -> void:
	RenderingServer.set_default_clear_color(BG)
	var shapes: PackedStringArray = String(opts.shapes).split(",")
	var elems: PackedStringArray = String(opts.elems).split(",")
	var font := ThemeDB.fallback_font
	for i in shapes.size():
		_label(shapes[i], Vector2(HEAD.x + i * TILE.x, 0), Vector2(TILE.x, HEAD.y), font)
	for j in elems.size():
		_label(elems[j], Vector2(0, HEAD.y + j * TILE.y), Vector2(HEAD.x, TILE.y), font)
		for i in shapes.size():
			# each tile clips its floor and effects to its own box
			var box := Control.new()
			box.position = HEAD + Vector2(i * TILE.x, j * TILE.y)
			box.size = TILE
			box.clip_contents = true
			root.add_child(box)
			var tile := Floor.new()
			box.add_child(tile)
			var to := Vector2(128, 124)
			var from := to + Vector2(-2 * Vfx.HW, 0)
			if shapes[i] in ["hit", "curse"]:
				from = to + Vector2(-Vfx.HW, -Vfx.HH)
			if shapes[i] in ["aura", "heal"]:
				from = to
			tile.to = to
			tile.from = from
			tile.zone = 1 if shapes[i] in ["area", "trap"] else 0
			tile.queue_redraw()
			_tiles.append([tile, shapes[i], elems[j], from, to])


func _label(text: String, at: Vector2, size: Vector2, font: Font) -> void:
	var l := Label.new()
	l.text = text
	l.position = at
	l.size = size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", GOLD)
	root.add_child(l)


func _process(delta: float) -> bool:
	_t += delta
	if _t >= _next:
		_next += LOOP
		for t in _tiles:
			var z := 1 if t[1] in ["area", "trap"] else 0
			Vfx.play(t[0], {"s": t[1], "e": t[2], "k": 2, "z": z}, t[3], t[4])
	return _t >= _secs


## A few stone cells round the target, the target and caster as grey dummies.
class Floor extends Node2D:
	var to := Vector2.ZERO
	var from := Vector2.ZERO
	var zone := 0

	func _draw() -> void:
		draw_rect(Rect2(2, 2, 196, 166), Color("272c33"))
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if absi(dx) + absi(dy) > 2:
					continue
				var c := to + Vector2((dx - dy) * 43.0, (dx + dy) * 21.5)
				var d := PackedVector2Array([c + Vector2(0, -21.5), c + Vector2(43, 0),
					c + Vector2(0, 21.5), c + Vector2(-43, 0)])
				draw_colored_polygon(d, Color("454a50"))
				d.append(d[0])
				draw_polyline(d, Color("5b6168"), 1.0, true)
		if from != to:
			_dummy(from, Color("6f7f96"))
		_dummy(to, Color("96806f"))

	func _dummy(at: Vector2, c: Color) -> void:
		draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(at + Vector2(-11, -52), Vector2(22, 46)), c)
		draw_circle(at + Vector2(0, -62), 11.0, c.lightened(0.15))
