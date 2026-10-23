extends RefCounted
## Tactical marks for the 1-bit fight style (sprints/S04): the reach, the AoE,
## the hovered cell, the walk dots and placed traps, drawn so they survive the
## dithered world.
##
## A translucent fill (the retail look) over 1-bit art turns into a washed-out
## pastel that is nearly invisible on white dither. These are Bayer dot fills
## in the mark's colour instead — the dots stay fully saturated, the density
## carries the strength — plus a black outline under every line, so a mark
## reads on white and on black alike. Same Bayer matrix as TeamAura.

const _BAYER8 := [0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
	12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
	15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21]

## Big enough to cover one cell's diamond (fight_view HW*2 × HH*2 = 86 × 43).
const TEX := Vector2i(96, 48)

static var _cache := {}


## Dot-fill `poly` (a cell diamond) in `col` at `density` (0..1).
static func fill(ci: CanvasItem, poly: PackedVector2Array, col: Color, density: float) -> void:
	var tex := texture(col, density)
	var origin := poly[0]
	for p in poly:
		origin = Vector2(minf(origin.x, p.x), minf(origin.y, p.y))
	origin = origin.floor()
	var uvs := PackedVector2Array()
	for p in poly:
		uvs.append((p - origin) / Vector2(TEX))
	ci.draw_colored_polygon(poly, Color.WHITE, uvs, tex)


## A closed outline that reads on any background: black under, colour over.
static func outline(ci: CanvasItem, poly: PackedVector2Array, col: Color, width := 2.0) -> void:
	var closed := poly + PackedVector2Array([poly[0]])
	ci.draw_polyline(closed, Color.BLACK, width + 2.0)
	ci.draw_polyline(closed, col, width)


## A walk-step dot with a black rim.
static func dot(ci: CanvasItem, at: Vector2, col: Color, r := 3.5) -> void:
	ci.draw_circle(at, r + 1.5, Color.BLACK)
	ci.draw_circle(at, r, col)


static func texture(col: Color, density: float) -> Texture2D:
	var key := "%s|%.2f" % [col.to_html(false), density]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(col, density))
	return _cache[key]


## The dot pattern: a pixel is `col` where the Bayer threshold is under the
## density, clear elsewhere — screen-stable as the pattern repeats every 8 px.
static func image(col: Color, density: float) -> Image:
	var img := Image.create(TEX.x, TEX.y, false, Image.FORMAT_RGBA8)
	var opaque := Color(col.r, col.g, col.b, 1.0)
	var cut := clampf(density, 0.0, 1.0) * 64.0
	for y in TEX.y:
		for x in TEX.x:
			if float(_BAYER8[(y % 8) * 8 + (x % 8)]) < cut:
				img.set_pixel(x, y, opaque)
	return img
