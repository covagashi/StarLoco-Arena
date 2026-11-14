extends Control
## S38b: a card drawn in the template the owner chose (option B of
## tools/icons/card_template_options.py): a frame in the metal of its rarity
## (black lacquer, copper, silver, gold), the colour of its family inside, its
## 3D piece (coach and fighter equipment) or the family's pictogram on a soft
## light, the name on an ink ribbon, the family's medallion at the top left
## and one to four diamonds for the rarity. Laid out on a 150 x 180 card and
## scaled to the control's size; `sub` (a value, a price) goes at the foot.
## The art comes from tools/icons/card_art.py (assets/ui/cards/).
## The text is drawn unscaled (its size follows the card's scale) so the
## detail size stays crisp.

const Cards := preload("res://src/gamedata/cards.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const FighterCards := preload("res://src/gamedata/fightercards.gd")
const BASE := Vector2(150, 180)
const INK := Color("1c2030")
# family → its colour (the sheet's)
const FAMILY_COLOUR := {
	"coach": Color8(47, 116, 240), "consumable": Color8(48, 168, 118), "combat": Color8(255, 77, 109),
	"cosmetic": Color8(176, 127, 208), "fusion": Color8(34, 181, 201), "dofus": Color8(217, 154, 43),
	"arena": Color8(106, 168, 79), "fighter": Color8(122, 88, 204), "other": Color8(107, 113, 131),
}
# tier → [base, light, dark]
const METAL := [
	[Color8(48, 52, 66), Color8(118, 124, 146), Color8(16, 18, 26)],
	[Color8(184, 115, 58), Color8(236, 176, 118), Color8(104, 56, 22)],
	[Color8(160, 170, 188), Color8(236, 241, 250), Color8(92, 102, 122)],
	[Color8(226, 172, 46), Color8(255, 234, 150), Color8(146, 96, 10)],
]
# tier → the strength of the sheen streak across the frame, and how far
# the shading runs from the light into the dark (black stays a deep lacquer)
const SHEEN := [0.2, 0.36, 0.46, 0.42]
const SHADE := [[0.42, 0.96], [0.1, 0.88], [0.04, 0.86], [0.06, 0.88]]
# card types drawn with the hair pictogram when they have no piece: the
# coach haircuts (3) and the cosmetic hair colours (29)
const HAIR_TYPES := [3, 29]
const NAME_W := BASE.x - 26.0   # the ribbon's text width

static var _art_cache := {}   # asset path → Texture2D (null when missing)

var card_id := 0
var fighter := false          # a fighter equipment card (fightercards.json)
var card_name := ""
var sub := ""


## A card face for `cid` at `size` (keeps the card's 5:6 shape inside it).
static func make(cid: int, size: Vector2, is_fighter := false, name := "", foot := "") -> Control:
	var f = load("res://src/ui/card_face.gd").new()
	f.card_id = cid
	f.fighter = is_fighter
	f.card_name = name if name != "" else (FighterCards.label(cid) if is_fighter else Cards.name_of(cid))
	f.sub = foot
	f.custom_minimum_size = size
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return f


static func family(cid: int, is_fighter: bool) -> String:
	return "fighter" if is_fighter else Cards.family_of(cid)


static func tier(cid: int, is_fighter: bool) -> int:
	return FighterCards.tier_of(cid) if is_fighter else Cards.tier_of(cid)


static func _tex(rel: String) -> Texture2D:
	if not _art_cache.has(rel):
		var img := AssetPaths.load_image(rel)
		_art_cache[rel] = ImageTexture.create_from_image(img) if img != null else null
	return _art_cache[rel]


## The piece for coach and fighter gear, the hair pictogram for haircuts and
## hair colours without one, else the family's pictogram.
static func art_of(cid: int, is_fighter: bool) -> Texture2D:
	var fam := family(cid, is_fighter)
	var piece: Texture2D = null
	if is_fighter:
		piece = _tex("ui/cards/fighter/%d.webp" % cid)
	elif fam == "coach":
		piece = _tex("ui/cards/coach/%d.webp" % cid)
	if piece != null:
		return piece
	if not is_fighter and int(Cards.meta(cid).get("type", -1)) in HAIR_TYPES:
		var hair := _tex("ui/cards/family/hair.webp")
		if hair != null:
			return hair
	return _tex("ui/cards/family/%s.webp" % fam)


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	# the card, scaled to fit, centred
	var k := minf(size.x / BASE.x, size.y / BASE.y)
	var off := (size - BASE * k) / 2.0
	draw_set_transform(off, 0.0, Vector2(k, k))
	var fam := family(card_id, fighter)
	var colour: Color = FAMILY_COLOUR.get(fam, FAMILY_COLOUR.other)
	var t := tier(card_id, fighter)
	var m: Array = METAL[t]
	var pale := colour.lerp(Color.WHITE, 0.55)
	_frame(m, SHEEN[t], SHADE[t])
	# inside: the pale family colour, the art window in the family colour
	_rounded(Rect2(7, 7, BASE.x - 14, BASE.y - 14), 3.0, pale)
	_rounded(Rect2(7, 7, BASE.x - 14, 104), 3.0, colour)
	# a soft light behind the art: a crisp core and a halo that fades out
	var light := colour.lerp(Color.WHITE, 0.36)
	var centre := Vector2(BASE.x / 2.0, 60)
	_disc(centre, 36.0, 0.94, light)
	_halo(centre, 36.0, 54.0, 0.94, Color(light, 0.55), Color(light, 0.0))
	# the art
	var tex := art_of(card_id, fighter)
	if tex != null:
		var side := 92.0
		draw_texture_rect(tex, Rect2((BASE.x - side) / 2.0, 12, side, side), false)
	# a fine ink line printed just inside the art window
	_outline(Rect2(9, 9, BASE.x - 18, 100), 2.0, Color(INK, 0.32))
	# the name on an ink ribbon wrapped over the frame
	draw_colored_polygon(PackedVector2Array([Vector2(4, 116), Vector2(BASE.x - 4, 116),
		Vector2(BASE.x - 10, 146), Vector2(10, 146)]), INK)
	draw_line(Vector2(4.5, 116.5), Vector2(BASE.x - 4.5, 116.5), INK.lerp(Color.WHITE, 0.22), 1.0, true)
	# the family's medallion
	draw_circle(Vector2(17, 17), 15, INK)
	draw_circle(Vector2(17, 17), 13, colour)
	draw_arc(Vector2(17, 17), 11.8, 0, TAU, 40, Color(1, 1, 1, 0.4), 1.0, true)
	var pic := _tex("ui/cards/family/%s.webp" % fam)
	if pic != null:
		draw_texture_rect(pic, Rect2(6, 6, 22, 22), false)
	# the rarity's diamonds, faceted: a lit top, the metal below
	var dy := 156.0 if sub != "" else 159.0
	for i in t + 1:
		var cx := BASE.x / 2.0 + (i - t / 2.0) * 13.0
		var l := Vector2(cx - 5, dy)
		var r := Vector2(cx + 5, dy)
		draw_colored_polygon(PackedVector2Array([Vector2(cx, dy - 5.5), r, l]), m[1])
		draw_colored_polygon(PackedVector2Array([l, r, Vector2(cx, dy + 5.5)]), m[0])
		draw_polyline(PackedVector2Array([Vector2(cx, dy - 5.5), r, Vector2(cx, dy + 5.5), l, Vector2(cx, dy - 5.5)]),
			m[2], 1.0, true)
	draw_set_transform(Vector2.ZERO)
	# the text, unscaled so it stays crisp at the detail size
	_name(off, k)
	if sub != "":
		var bf := UiStyle.body_font()
		var fs := maxi(6, roundi(10 * k))
		var sw := bf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(bf, off + Vector2(BASE.x * k / 2.0 - sw / 2.0, 172 * k), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			INK.lerp(colour, 0.3))


## The metal frame: a dark rim, the metal shaded from its light (top left)
## to its dark (bottom right), a sheen streak, a lit edge and the shadow of
## its inner lip.
func _frame(m: Array, sheen: float, shade: Array) -> void:
	_rounded(Rect2(Vector2.ZERO, BASE), 5.0, m[2])
	var pts := _round_pts(Rect2(1.2, 1.2, BASE.x - 2.4, BASE.y - 2.4), 4.0)
	var cols := PackedColorArray()
	for p in pts:
		var d := (p.x / BASE.x + p.y / BASE.y) / 2.0
		cols.append((m[1] as Color).lerp(m[2], lerpf(shade[0], shade[1], d)))
	draw_polygon(pts, cols)
	# the streak, from the top right down to the bottom left
	var hw := 30.0
	var tc := BASE.x * 0.7
	var bc := BASE.x * 0.3
	var c0 := Color(1, 1, 1, 0)
	var c1 := Color(1, 1, 1, sheen)
	draw_polygon(PackedVector2Array([Vector2(tc - hw, 1.2), Vector2(tc, 1.2), Vector2(bc, BASE.y - 1.2),
		Vector2(bc - hw, BASE.y - 1.2)]), PackedColorArray([c0, c1, c1, c0]))
	draw_polygon(PackedVector2Array([Vector2(tc, 1.2), Vector2(tc + hw, 1.2), Vector2(bc + hw, BASE.y - 1.2),
		Vector2(bc, BASE.y - 1.2)]), PackedColorArray([c1, c0, c0, c1]))
	draw_polyline(PackedVector2Array([Vector2(3, BASE.y - 6), Vector2(3, 3), Vector2(BASE.x - 6, 3)]),
		Color(m[1], 0.9), 1.4, true)
	# the inner lip: its shadow all round, the light it catches below and right
	_outline(Rect2(6, 6, BASE.x - 12, BASE.y - 12), 3.5, Color(m[2], 0.6))
	draw_polyline(PackedVector2Array([Vector2(5.5, 9), Vector2(5.5, BASE.y - 5.5), Vector2(BASE.x - 9, BASE.y - 5.5)]),
		Color(m[1], 0.55), 1.0, true)
	draw_polyline(PackedVector2Array([Vector2(BASE.x - 5.5, 9), Vector2(BASE.x - 5.5, BASE.y - 9)]),
		Color(m[1], 0.55), 1.0, true)


## The name on the ribbon: one line, two lines when that keeps it bigger,
## else trimmed. Drawn in screen space (`off`, `k` are the card's placement).
func _name(off: Vector2, k: float) -> void:
	var font := UiStyle.display_font()
	var text := card_name.to_upper()
	var maxw := NAME_W * k
	var fs := _fit(font, text, maxw, 15, 9, k)
	if fs < 11 * k and text.contains(" "):
		var lines := _split(font, text, maxw, k)
		if not lines.is_empty():
			var fs2 := mini(_fit(font, lines[0], maxw, 11, 9, k), _fit(font, lines[1], maxw, 11, 9, k))
			if fs2 >= 9 * k - 0.5:
				_centred(font, lines[0], off + Vector2(BASE.x * k / 2.0, (124.5 + 11 * 0.36) * k), fs2)
				_centred(font, lines[1], off + Vector2(BASE.x * k / 2.0, (137.5 + 11 * 0.36) * k), fs2)
				return
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:   # still too long: trim it
		while text.length() > 4 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
			text = text.left(text.length() - 1)
		text += "…"
	_centred(font, text, off + Vector2(BASE.x * k / 2.0, (131 + fs / k * 0.36) * k), fs)


## The largest size between hi and lo (base units, scaled by k) that fits
## `text` in `maxw` pixels; the size in pixels.
static func _fit(font: Font, text: String, maxw: float, hi: int, lo: int, k: float) -> int:
	var fs := maxi(1, roundi(hi * k))
	var floor_px := maxi(1, roundi(lo * k))
	while fs > floor_px and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > maxw:
		fs -= 1
	return fs


## The split of `text` at a space whose longer line is the shortest; empty
## when neither half fits at the smallest two-line size.
static func _split(font: Font, text: String, maxw: float, k: float) -> PackedStringArray:
	var words := text.split(" ", false)
	var best := PackedStringArray()
	var best_w := INF
	var fs := maxi(1, roundi(9 * k))
	for i in range(1, words.size()):
		var a := " ".join(words.slice(0, i))
		var b := " ".join(words.slice(i))
		var w := maxf(font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x,
			font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
		if w < best_w:
			best_w = w
			best = PackedStringArray([a, b])
	return best if best_w <= maxw else PackedStringArray()


func _centred(font: Font, text: String, at: Vector2, fs: int) -> void:
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2(at.x - tw / 2.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


func _rounded(r: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


func _outline(r: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = c
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)


## The outline of a rounded rectangle, clockwise from its top right corner.
static func _round_pts(r: Rect2, rad: float, n := 6) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [
		[Vector2(r.end.x - rad, r.position.y + rad), -PI / 2], [Vector2(r.end.x - rad, r.end.y - rad), 0.0],
		[Vector2(r.position.x + rad, r.end.y - rad), PI / 2], [Vector2(r.position.x + rad, r.position.y + rad), PI],
	]
	for c in corners:
		for i in n + 1:
			var a: float = c[1] + (PI / 2) * i / n
			pts.append((c[0] as Vector2) + Vector2(cos(a), sin(a)) * rad)
	return pts


## A flat ellipse (radius r, squashed by sy).
func _disc(c: Vector2, r: float, sy: float, col: Color, n := 48) -> void:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * r, sin(a) * r * sy))
	draw_colored_polygon(pts, col)


## A ring from r0 (colour c0) to r1 (colour c1), the colour blending between.
func _halo(c: Vector2, r0: float, r1: float, sy: float, c0: Color, c1: Color, n := 48) -> void:
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var u0 := Vector2(cos(a0), sin(a0) * sy)
		var u1 := Vector2(cos(a1), sin(a1) * sy)
		draw_polygon(PackedVector2Array([c + u0 * r0, c + u1 * r0, c + u1 * r1, c + u0 * r1]),
			PackedColorArray([c0, c0, c1, c1]))
