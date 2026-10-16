extends RefCounted
## Team aura for the 1-bit fight style (sprints/S04): a round glow of
## team-coloured Bayer dots under a fighter, fading outwards — the Glagstone
## light pools, in colour. The colour is the one thing the 1-bit world keeps
## for gameplay: it says whose fighter this is. The acting fighter's aura is
## larger and denser.
##
## Picked from three auditioned designs (cell, aura, ring) on 2026-10-17.

const HW := 43.0   # half cell width (fight_view.HW)
const HH := 21.5   # half cell height
## Aura size in cells; the first audition used 1.5 and neighbours overlapped.
const SCALE := 1.15
const ACTIVE_SCALE := 1.45

const _BAYER8 := [0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
	12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
	15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21]

static var _cache := {}


## Draw the aura centred on a cell centre, on any canvas item. Textures are
## built once per (colour, active).
static func draw(ci: CanvasItem, ctr: Vector2, col: Color, active := false) -> void:
	var key := "%s|%s" % [col.to_html(), active]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(col, active))
	var tex: Texture2D = _cache[key]
	ci.draw_texture(tex, (ctr - tex.get_size() / 2.0).floor())


static func image(col: Color, active := false) -> Image:
	var s := ACTIVE_SCALE if active else SCALE
	var w := int(HW * 2.0 * s)
	var h := int(HH * 2.0 * s)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var opaque := Color(col.r, col.g, col.b, 1.0)
	for y in h:
		for x in w:
			var dx := (float(x) + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (float(y) + 0.5 - h / 2.0) / (h / 2.0)
			var v := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			v = pow(v, 0.8) * (1.0 if active else 0.85)
			if v > (float(_BAYER8[(y & 7) * 8 + (x & 7)]) + 0.5) / 64.0:
				img.set_pixel(x, y, opaque)
	return img
