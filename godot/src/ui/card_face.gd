extends Control
## S38b: a card drawn in the template the owner chose (option B of
## tools/icons/card_template_options.py): a frame in the metal of its rarity
## (black, copper, silver, gold), the colour of its family inside, its 3D
## piece (coach and fighter equipment) or the family's pictogram on a soft
## light, the name on an ink ribbon, the family's medallion at the top left
## and one to four diamonds for the rarity. Laid out on a 150 x 180 card and
## scaled to the control's size; `sub` (a value, a price) goes at the foot.
## The art comes from tools/icons/card_art.py (assets/ui/cards/).

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
	[Color8(52, 56, 70), Color8(120, 126, 146), Color8(22, 24, 32)],
	[Color8(184, 115, 58), Color8(232, 170, 110), Color8(110, 62, 26)],
	[Color8(160, 170, 188), Color8(232, 238, 248), Color8(98, 108, 126)],
	[Color8(226, 172, 46), Color8(255, 230, 140), Color8(150, 102, 12)],
]

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


## The piece for coach and fighter gear, else the family's pictogram.
static func art_of(cid: int, is_fighter: bool) -> Texture2D:
	var fam := family(cid, is_fighter)
	var piece: Texture2D = null
	if is_fighter:
		piece = _tex("ui/cards/fighter/%d.webp" % cid)
	elif fam == "coach":
		piece = _tex("ui/cards/coach/%d.webp" % cid)
	return piece if piece != null else _tex("ui/cards/family/%s.webp" % fam)


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
	# the frame: a dark rim, the metal, a lit edge along the top and the left
	_rounded(Rect2(Vector2.ZERO, BASE), 5.0, m[2])
	_rounded(Rect2(Vector2(1.2, 1.2), BASE - Vector2(2.4, 2.4)), 4.0, m[0])
	draw_polyline(PackedVector2Array([Vector2(3, BASE.y - 6), Vector2(3, 3), Vector2(BASE.x - 6, 3)]), m[1], 1.6, true)
	# inside: the pale family colour, the art window in the family colour
	_rounded(Rect2(7, 7, BASE.x - 14, BASE.y - 14), 3.0, pale)
	_rounded(Rect2(7, 7, BASE.x - 14, 104), 3.0, colour)
	# a soft light behind the art, then the art
	draw_set_transform(off + Vector2(BASE.x / 2.0, 60) * k, 0.0, Vector2(k, k * 0.92))
	draw_circle(Vector2.ZERO, 48, colour.lerp(Color.WHITE, 0.35))
	draw_set_transform(off, 0.0, Vector2(k, k))
	var tex := art_of(card_id, fighter)
	if tex != null:
		var side := 92.0
		draw_texture_rect(tex, Rect2((BASE.x - side) / 2.0, 12, side, side), false)
	# the name on an ink ribbon
	draw_colored_polygon(PackedVector2Array([Vector2(4, 116), Vector2(BASE.x - 4, 116),
		Vector2(BASE.x - 10, 146), Vector2(10, 146)]), INK)
	var font := UiStyle.display_font()
	var text := card_name.to_upper()
	var fs := 15
	while fs > 9 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > BASE.x - 26:
		fs -= 1
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if tw > BASE.x - 26:   # still too long: trim it
		while text.length() > 4 and font.get_string_size(text + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > BASE.x - 26:
			text = text.left(text.length() - 1)
		text += "…"
		tw = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((BASE.x - tw) / 2.0, 131 + fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# the family's medallion
	draw_circle(Vector2(17, 17), 15, INK)
	draw_circle(Vector2(17, 17), 13, colour)
	var pic := _tex("ui/cards/family/%s.webp" % fam)
	if pic != null:
		draw_texture_rect(pic, Rect2(8, 8, 18, 18), false)
	# the rarity's diamonds and the foot text
	var dy := 156.0 if sub != "" else 159.0
	for i in t + 1:
		var cx := BASE.x / 2.0 + (i - t / 2.0) * 13.0
		var d := PackedVector2Array([Vector2(cx, dy - 5), Vector2(cx + 5, dy), Vector2(cx, dy + 5), Vector2(cx - 5, dy)])
		draw_colored_polygon(d, m[1])
		d.append(d[0])
		draw_polyline(d, m[2], 1.0, true)
	if sub != "":
		var bf := UiStyle.body_font()
		var sw := bf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(bf, Vector2((BASE.x - sw) / 2.0, 172), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, INK.lerp(colour, 0.25))
	draw_set_transform(Vector2.ZERO)


func _rounded(r: Rect2, radius: float, c: Color) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	draw_style_box(sb, r)
