extends Control
## The acting fighter's medallion, bottom-left of the fight HUD (sprints/S17,
## after Krosmaster Arena): a round portrait with its life as a ring, and
## three badges over it — MP (green), life (red), AP (blue). It follows the
## turn, so on an enemy turn it shows the enemy's live AP/MP.

const FighterCard := preload("res://src/fight/fighter_card.gd")

var portrait: Texture2D = null
var initials := ""
var team_color := Color.WHITE
var hp := 0
var hp_max := 0
var lost := 0
var ap := 0
var mp := 0
var shown := false      # false between turns: an empty socket
var onebit := false
var radius := 46.0

const RING_W := 7.0


## Footprint for a radius: the ring plus room for the badges on top.
static func size_for(r: float) -> Vector2:
	return Vector2(r * 2.0 + RING_W * 2.0 + 30.0, r * 2.0 + RING_W * 2.0 + 30.0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var font := get_theme_default_font()
	var c := Vector2(size.x * 0.5, size.y - radius - RING_W - 4.0)
	var ink := Color.WHITE if onebit else Color("ad965a")
	var plate := Color.BLACK if onebit else Color("292c20")
	draw_circle(c, radius + RING_W + 3.0, plate)
	draw_arc(c, radius + RING_W + 3.0, 0.0, TAU, 64, ink, 2.0, true)
	if not shown:
		draw_circle(c, radius, Color(0, 0, 0, 0.6))
		return
	draw_circle(c, radius, Color.BLACK if onebit else team_color.darkened(0.78))
	if portrait != null:
		_draw_round_texture(portrait, c, radius)
	elif not initials.is_empty():
		var fs := int(radius * 0.7)
		var w := font.get_string_size(initials, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), initials,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_arc(c, radius, 0.0, TAU, 64, team_color, 2.0, true)
	# life ring, clockwise from the top
	var rr := radius + RING_W * 0.5 + 1.0
	draw_arc(c, rr, 0.0, TAU, 64, Color.BLACK, RING_W, true)
	if hp_max > 0:
		var ratio := clampf(float(hp) / float(hp_max), 0.0, 1.0)
		if ratio > 0.0:
			draw_arc(c, rr, -PI * 0.5, -PI * 0.5 + TAU * ratio, 64,
				FighterCard.hp_color(ratio), RING_W - 2.0, true)
	# badges: MP left, life top, AP right (Krosmaster's order)
	var life := str(hp) if hp_max > 0 else ("-%d" % lost if lost > 0 else "?")
	var br := clampf(radius * 0.3, 11.0, 15.0)
	var ring_out := radius + RING_W + 3.0
	_badge(font, c + Vector2.from_angle(deg_to_rad(-140)) * ring_out, br,
		str(mp), Color(0.2, 0.62, 0.25))
	_badge(font, c + Vector2.from_angle(deg_to_rad(-90)) * ring_out, br * 1.15,
		life, Color(0.78, 0.16, 0.14))
	_badge(font, c + Vector2.from_angle(deg_to_rad(-40)) * ring_out, br,
		str(ap), Color(0.18, 0.42, 0.85))


func _badge(font: Font, at: Vector2, r: float, text: String, col: Color) -> void:
	var edge := Color.WHITE if onebit else Color("f1e5c1")
	draw_circle(at, r + 1.5, Color.BLACK)
	draw_circle(at, r, Color.BLACK if onebit else col)
	draw_arc(at, r, 0.0, TAU, 32, col if onebit else edge, 1.5, true)
	var fs := int(r * 1.05)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-w * 0.5, fs * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


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
