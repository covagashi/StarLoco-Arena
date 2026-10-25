extends Node2D

## S33 prototype: a patch of arena in our own stone (no retail art) at the
## real cell size (86×43), so fighters are judged at the scale they play at.

const Pal := preload("res://proto/s33/palette.gd")
const HW := 43.0
const HH := 21.5
const DEPTH := 14.0

var cols := 5
var rows := 5
var rings := {}   # Vector2i cell -> team index


func cell(c: Vector2i) -> Vector2:
	return Vector2((c.x - c.y) * HW, (c.x + c.y) * HH)


func _draw() -> void:
	# side walls of the slab, front edges only
	for y in rows:
		for x in cols:
			var p := cell(Vector2i(x, y))
			if y == rows - 1:
				_side(p, Vector2(-HW, 0), Vector2(0, HH), Pal.STONE_LO)
			if x == cols - 1:
				_side(p, Vector2(0, HH), Vector2(HW, 0), Pal.STONE_LO.darkened(0.2))
	for y in rows:
		for x in cols:
			_tile(Vector2i(x, y))
	for c in rings:
		_ring(cell(c), Pal.TEAM[rings[c]])


func _tile(c: Vector2i) -> void:
	var p := cell(c)
	var h := hash(c * 7919) % 100
	var base := Pal.STONE if (c.x + c.y) % 2 == 0 else Pal.STONE_ALT
	base = base.lerp(Pal.MOSS, 0.35) if h < 12 else base.lightened((h % 7) * 0.012)
	var g := 2.0   # mortar gap
	var d := PackedVector2Array([p + Vector2(0, -HH + g), p + Vector2(HW - g * 2, 0),
		p + Vector2(0, HH - g), p + Vector2(-HW + g * 2, 0)])
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -HH), p + Vector2(HW, 0),
		p + Vector2(0, HH), p + Vector2(-HW, 0)]), Pal.MORTAR)
	draw_colored_polygon(d, base)
	# bevel: light top-left edges, dark bottom-right edges
	draw_line(d[3], d[0], Pal.STONE_HI, 2.0, true)
	draw_line(d[0], d[1], Pal.STONE_HI.lerp(base, 0.4), 1.5, true)
	draw_line(d[1], d[2], Pal.STONE_LO, 2.0, true)
	draw_line(d[2], d[3], Pal.STONE_LO.lerp(base, 0.3), 1.5, true)
	if h % 5 == 0:   # a crack here and there
		var a := p + Vector2(-10 + h % 9, -4)
		draw_polyline(PackedVector2Array([a, a + Vector2(7, 3), a + Vector2(11, 1),
			a + Vector2(16, 5)]), Pal.STONE_LO, 1.0, true)


func _side(p: Vector2, a: Vector2, b: Vector2, col: Color) -> void:
	var e0 := p + a
	var e1 := p + b
	draw_colored_polygon(PackedVector2Array([e0, e1, e1 + Vector2(0, DEPTH),
		e0 + Vector2(0, DEPTH)]), col)


func _ring(p: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 33:
		var a := TAU * i / 32.0
		pts.append(p + Vector2(cos(a) * 24.0, sin(a) * 12.0))
	draw_polyline(pts, col.darkened(0.5), 5.0, true)
	draw_polyline(pts, col, 2.5, true)
