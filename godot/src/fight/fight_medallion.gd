extends Control
## The acting fighter, bottom-left of the fight HUD (S17; S45 mockup): a
## large round portrait with its life as a ring, AP (blue) and MP (green)
## medallions on its left edge, and beside it the name, the life and up to
## three effect chips. It follows the turn, so on an enemy turn it shows the
## enemy's live AP/MP.

const FighterCard := preload("res://src/fight/fighter_card.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")

var portrait: Texture2D = null
var initials := ""
var team_color := Color.WHITE
var fighter_name := ""
var buffs: Array = []
var hp := 0
var hp_max := 0
var lost := 0
var ap := 0
var mp := 0
var shown := false      # false between turns: an empty socket
var radius := 50.0

const RING_W := 6.0
const MAX_CHIPS := 3


## Footprint for a radius (kept for callers sizing the old medallion).
static func size_for(r: float) -> Vector2:
	return Vector2(r * 2.0 + RING_W * 2.0 + 30.0, r * 2.0 + RING_W * 2.0 + 30.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## How far right it draws (the portrait and its text), for the spell bar.
func used_width() -> float:
	if not shown:
		return radius * 2.0 + 24.0
	var f := UiStyle.display_font()
	var w := f.get_string_size(fighter_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	return minf(size.x, radius * 2.0 + 30.0 + maxf(w, 150.0))


func _draw() -> void:
	var c := Vector2(radius + 14.0, size.y - radius - 8.0)
	draw_circle(c, radius + RING_W + 2.0, Color(0.05, 0.06, 0.12))
	if not shown:
		draw_circle(c, radius, Color(0.07, 0.08, 0.16, 0.8))
		return
	draw_circle(c, radius, team_color.darkened(0.7))
	if portrait != null:
		_draw_round_texture(portrait, c, radius)
	elif not initials.is_empty():
		var font := UiStyle.display_font()
		var fs := int(radius * 0.7)
		var w := font.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), initials,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	# life ring, clockwise from the top, red over a faint track
	var rr := radius + RING_W * 0.5
	draw_arc(c, rr, 0.0, TAU, 64, Color(1, 1, 1, 0.18), RING_W, true)
	var ratio := clampf(float(hp) / float(hp_max), 0.0, 1.0) if hp_max > 0 else 1.0
	if ratio > 0.0:
		draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64, Color("ff4d5e"), RING_W, true)
	# AP and MP on the left edge
	_medal(c + Vector2(-radius - 4.0, -radius * 0.42), 19.0, str(ap), Color("2f74f0"))
	_medal(c + Vector2(-radius - 4.0, radius * 0.42), 19.0, str(mp), Color("1e9e66"))
	# name, life, effects
	var x := c.x + radius + RING_W + 14.0
	var title := UiStyle.display_font()
	var body := UiStyle.bold(800)
	var y := size.y - 70.0
	draw_string_outline(title, Vector2(x, y), fighter_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color(0, 0, 0, 0.7))
	draw_string(title, Vector2(x, y), fighter_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, UiStyle.INK)
	var life := ("%d / %d" % [hp, hp_max]) if hp_max > 0 else ("-%d" % lost if lost > 0 else "?")
	var label := "%s %s" % [life, I18n.t("fight.hp_short")]
	draw_string_outline(body, Vector2(x, y + 24.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.7))
	draw_string(body, Vector2(x, y + 24.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, UiStyle.INK)
	if hp_max > 0:
		var hs := "%d" % hp
		draw_string(body, Vector2(x, y + 24.0), hs, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("ff8a96"))
	var cx := x
	for i in mini(buffs.size(), MAX_CHIPS):
		var t := str(buffs[buffs.size() - 1 - i])
		var w := body.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 18.0
		if cx + w > size.x:
			break
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.07, 0.08, 0.16, 0.85)
		sb.skew = Vector2(0.25, 0)
		draw_style_box(sb, Rect2(cx, y + 34.0, w, 22.0))
		draw_string(body, Vector2(cx + 9.0, y + 50.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiStyle.INK)
		cx += w + 6.0


func _medal(at: Vector2, r: float, text: String, col: Color) -> void:
	draw_circle(at, r + 3.0, Color(0.07, 0.08, 0.16))
	draw_circle(at, r, col)
	draw_arc(at, r - 3.0, PI * 1.15, PI * 1.85, 12, Color(1, 1, 1, 0.3), 2.5, true)
	var f := UiStyle.display_font()
	var fs := int(r * 1.05)
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, at + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.6))
	draw_string(f, at + Vector2(-w * 0.5, fs * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## A texture cropped to a circle: a textured polygon, no shader needed. The
## portraits are square with the figure centred, so the crop keeps the face.
func _draw_round_texture(tex: Texture2D, c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	for i in 48:
		var d := Vector2.from_angle(TAU * i / 48.0)
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5)
	draw_colored_polygon(pts, Color.WHITE, uvs, tex)
