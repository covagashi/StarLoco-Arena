extends Control
## One fighter's card in the fight HUD's side columns (sprints/S17): the
## retail breed portrait in a team-coloured frame, its life under it, its
## buffs as small chips towards the map. Everything a fighter's head used to
## carry over the map lives here instead.
##
## Pure view: fight_hud.gd fills the fields and calls queue_redraw(). Drawn by
## hand (no child nodes) so the frame stays crisp at any card size and the
## buff chips can hang outside the card rect without stealing map clicks.

signal pressed(fid: int)
signal hovered(fid: int, on: bool)

const AssetPaths := preload("res://src/util/asset_paths.gd")

## Life drawn as a bar under the portrait, or as a ring around it.
enum HpStyle { BAR, RING }

var fid := -1
var portrait: Texture2D = null
var initials := ""          # shown when there is no portrait art
var team_color := Color.WHITE
var hp := 0                 # current life (only meaningful with hp_max > 0)
var hp_max := 0             # 0 = unknown (monsters keep it off the wire)
var lost := 0               # cumulative damage, the only number for hp_max 0
var active := false
var dead := false
var invisible := false
var summon := false
var buffs: Array = []       # chip strings, newest last
var inward := 1             # +1: the map is to the right (left column), -1: left
var onebit := false
var hp_style := HpStyle.BAR
var side := 56.0            # portrait side in px; fight_hud picks it per column
var chip_gap := 0.0         # extra px the chips skip (inner columns of a wrap)
var slide := true           # the active card steps towards the map (not when
                            # another column of cards is in the way)

const BAR_H := 5.0
const FRAME := 2.0
const MAX_CHIPS := 3
const ACTIVE_SLIDE := 8.0

static var _portraits := {}   # asset path -> Texture2D (or null)
var _hover := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# keyboard parity with the old timeline chips: Tab reaches the cards,
	# Enter/Space centres the camera like a click
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_entered.connect(func():
		_hover = true
		hovered.emit(fid, true)
		queue_redraw())
	mouse_exited.connect(func():
		_hover = false
		hovered.emit(fid, false)
		queue_redraw())


## Card footprint for a portrait side — the bar style adds a strip under it.
static func card_size(p: float, style: int) -> Vector2:
	var box := p + FRAME * 2.0
	if style == HpStyle.RING:
		return Vector2(box + 8.0, box + 8.0)
	return Vector2(box, box + BAR_H + 3.0)


## Retail portrait for a fighter record: players use the breed art
## (breed*10 + sex), summons their look id; null when nothing matches.
static func portrait_for(f: Dictionary) -> Texture2D:
	var ids := []
	var breed := int(f.get("breed", 0))
	var look := int(f.get("look", 0))
	if look != 0:
		ids.append(absi(look))
	if breed >= 1 and breed <= 12:
		ids.append(breed * 10 + clampi(int(f.get("sex", 0)), 0, 1))
	for id in ids:
		for dir in ["gui/images/theme/images/breeds/",
				"gui/images/breeds/fightTimeline/"]:
			var rel: String = dir + "%d.png" % id
			if not _portraits.has(rel):
				var img := AssetPaths.load_image(rel)
				_portraits[rel] = ImageTexture.create_from_image(img) \
					if img != null else null
			if _portraits[rel] != null:
				return _portraits[rel]
	return null


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT) \
			or event.is_action_pressed("ui_accept"):
		pressed.emit(fid)
		accept_event()


func hp_ratio() -> float:
	if hp_max <= 0:
		return 1.0
	return clampf(float(hp) / float(hp_max), 0.0, 1.0)


static func hp_color(ratio: float) -> Color:
	return Color(0.85, 0.15, 0.1).lerp(Color(0.3, 0.9, 0.35), ratio)


func _draw() -> void:
	var font := get_theme_default_font()
	var box := side + FRAME * 2.0
	var origin := Vector2(4.0, 4.0) if hp_style == HpStyle.RING else Vector2.ZERO
	if active and slide:
		origin.x += ACTIVE_SLIDE * inward   # the acting card steps out
	var outer := Rect2(origin, Vector2(box, box))
	var inner := outer.grow(-FRAME)
	var frame_col := team_color
	if dead:
		frame_col = Color(0.4, 0.4, 0.42)
	# backing: a dark team wash behind the (transparent-background) art
	var back := Color.BLACK if onebit else team_color.darkened(0.78)
	draw_rect(outer, Color(0.08, 0.08, 0.07) if dead else back)
	if not onebit and not dead:
		draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.5)),
			Color(1, 1, 1, 0.06))
	# portrait
	var mod := Color.WHITE
	if dead:
		mod = Color(0.32, 0.32, 0.34)
	elif invisible:
		mod = Color(1, 1, 1, 0.4)
	if portrait != null:
		draw_texture_rect(portrait, inner, false, mod)
	else:
		var s := initials if not initials.is_empty() else "?"
		var fs := int(side * 0.4)
		var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, inner.get_center() + Vector2(-w * 0.5, fs * 0.35), s,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, mod)
	# frame (dashed while invisible: the fighter is there, just unseen)
	var fw := FRAME + (1.0 if active else 0.0)
	if invisible and not dead:
		_dashed_rect(outer.grow(-fw * 0.5), frame_col, fw)
	else:
		draw_rect(outer.grow(-fw * 0.5), frame_col, false, fw)
	if active:
		var glow := Color.WHITE if onebit else Color("f6dc8c")
		draw_rect(outer.grow(2.0), glow, false, 2.0)
		# a notch pointing at the map: "this one is playing"
		var tip_x := outer.end.x + 7.0 if inward > 0 else outer.position.x - 7.0
		var base_x := outer.end.x + 1.0 if inward > 0 else outer.position.x - 1.0
		var cy := outer.get_center().y
		draw_colored_polygon(PackedVector2Array([Vector2(base_x, cy - 6),
			Vector2(tip_x, cy), Vector2(base_x, cy + 6)]), glow)
	if _hover and not active:
		draw_rect(outer.grow(1.0), Color(1, 1, 1, 0.55), false, 1.0)
	if has_focus():
		draw_rect(outer.grow(4.0), Color.WHITE, false, 1.0)
	if dead:
		var ko := "KO"
		var fs := int(maxf(side * 0.3, 11.0))
		var w := font.get_string_size(ko, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		_shadow_string(font, inner.get_center() + Vector2(-w * 0.5, fs * 0.35),
			ko, fs, Color(0.85, 0.85, 0.85))
	# life
	if hp_style == HpStyle.RING:
		_draw_ring(outer)
	else:
		_draw_bar(outer)
	_draw_hp_number(font, inner)
	_draw_chips(font, outer)


func _draw_bar(outer: Rect2) -> void:
	var r := Rect2(outer.position.x, outer.end.y + 2.0, outer.size.x, BAR_H)
	draw_rect(r, Color.BLACK)
	if hp_max <= 0 or dead:
		return
	var fill := r.grow(-1.0)
	fill.size.x *= hp_ratio()
	draw_rect(fill, hp_color(hp_ratio()))


## Ring style: the life runs clockwise round the square frame, starting at
## the top centre — a square "ring" keeps the portrait uncropped.
func _draw_ring(outer: Rect2) -> void:
	var r := outer.grow(3.0)
	var pts := _rect_loop(r)
	draw_polyline(pts, Color.BLACK, 4.0)
	if hp_max <= 0 or dead:
		return
	var total := 0.0
	for i in pts.size() - 1:
		total += pts[i].distance_to(pts[i + 1])
	var want := total * hp_ratio()
	var part := PackedVector2Array([pts[0]])
	var acc := 0.0
	for i in pts.size() - 1:
		var seg := pts[i].distance_to(pts[i + 1])
		if acc + seg >= want:
			part.append(pts[i].lerp(pts[i + 1], (want - acc) / maxf(seg, 0.001)))
			break
		part.append(pts[i + 1])
		acc += seg
	if part.size() >= 2:
		draw_polyline(part, hp_color(hp_ratio()), 2.0)


func _rect_loop(r: Rect2) -> PackedVector2Array:
	var top := Vector2(r.get_center().x, r.position.y)
	return PackedVector2Array([top, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y), r.position, top])


## The number sits on the portrait's lower edge: current life, or the damage
## tally when the max is unknown.
func _draw_hp_number(font: Font, inner: Rect2) -> void:
	var s := ""
	if hp_max > 0 and not dead:
		s = str(hp)
	elif lost > 0 and not dead:
		s = "-%d" % lost
	if s.is_empty():
		return
	var fs := int(clampf(side * 0.26, 10.0, 15.0))
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var pill := Rect2(inner.end.x - w - 6.0, inner.end.y - fs - 3.0, w + 6.0, fs + 3.0)
	draw_rect(pill, Color(0, 0, 0, 0.82))
	var col := Color.WHITE if hp_max <= 0 else hp_color(hp_ratio()).lightened(0.35)
	if onebit:
		col = Color.WHITE
	draw_string(font, Vector2(pill.position.x + 3.0, pill.end.y - 3.0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Buff chips hang towards the map, stacked down from the card's top edge.
func _draw_chips(font: Font, outer: Rect2) -> void:
	if buffs.is_empty() or dead:
		return
	var fs := 10
	var shown: Array = buffs.slice(0, MAX_CHIPS)
	if buffs.size() > MAX_CHIPS:
		shown[MAX_CHIPS - 1] = "+%d" % (buffs.size() - MAX_CHIPS + 1)
	var y := outer.position.y
	var chip_h := 14.0
	for s in shown:
		var w := font.get_string_size(str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 8.0
		var x := outer.end.x + 10.0 + chip_gap if inward > 0 \
			else outer.position.x - 10.0 - chip_gap - w
		var r := Rect2(x, y, w, chip_h)
		draw_rect(r, Color(0, 0, 0, 0.85))
		draw_rect(r, team_color if onebit else Color(0.75, 0.85, 1.0, 0.7), false, 1.0)
		draw_string(font, Vector2(x + 4.0, y + chip_h - 3.0), str(s),
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.92, 0.95, 1.0))
		y += chip_h + 2.0


func _dashed_rect(r: Rect2, col: Color, w: float) -> void:
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(c[i], c[(i + 1) % 4], col, w, 4.0)


func _shadow_string(font: Font, at: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string(font, at + Vector2(1, 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
		Color(0, 0, 0, 0.9))
	draw_string(font, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
