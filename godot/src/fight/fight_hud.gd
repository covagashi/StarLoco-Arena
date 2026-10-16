extends Control
## Krosmaster-style fight HUD (sprints/S17). The fighters' information moves
## off the map into fixed places:
##
##   - a column of cards per team down the screen sides (ours on the left),
##     in initiative order — portrait, team frame, life, buffs;
##   - the acting fighter's medallion bottom-left, with its live AP/MP/life;
##   - a turn banner top-centre ("TURNO 7" + whose turn + the clock).
##
## fight_view owns the fight state and pushes a plain model with set_model();
## this node only draws it and reports clicks/hovers. The spell bar, the PASS
## button, the menu and the chat stay fight_view nodes; it lays them out
## around the rects this node publishes (medal_rect, column widths).

signal card_pressed(fid: int)
signal card_hovered(fid: int, on: bool)

const FighterCard := preload("res://src/fight/fighter_card.gd")
const Medallion := preload("res://src/fight/fight_medallion.gd")
const AssetPaths := preload("res://src/util/asset_paths.gd")

var onebit := false
var hp_style: int = FighterCard.HpStyle.BAR
var team_colors: Array = [Color(0.3, 0.5, 1.0), Color(1.0, 0.4, 0.3)]

## Published by layout_hud() for fight_view's own nodes.
var medal_rect := Rect2()
var banner_rect := Rect2()
var left_w := 0.0       # px the left column takes from the screen edge
var right_w := 0.0

var cards := {}         # fid -> FighterCard
var medallion: Control
var banner: Control
var _order: Array = []  # fids, initiative order
var _left_team := 0
var _title := ""
var _sub := ""
var _sub_col := Color.WHITE
var _clock := -1.0
var _title_font: Font = null

const TOP := 62.0       # columns start under the menu row
const MARGIN := 10.0
const GAP := 5.0


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	var path := AssetPaths.resolve("gui/fonts/COPRGTB.TTF")
	if not path.is_empty() and FileAccess.file_exists(path):
		var f := FontFile.new()
		if f.load_dynamic_font(path) == OK:
			_title_font = f
	medallion = Medallion.new()
	medallion.name = "Medallion"
	medallion.onebit = onebit
	add_child(medallion)
	banner = Control.new()
	banner.name = "Banner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	add_child(banner)


## model = {
##   left_team: int,                 # the team drawn on the left (ours)
##   order: [fid…],                  # initiative order
##   fighters: {fid: {team, name, hp, hp_max, lost, dead, invisible,
##                    summon, buffs: [str], portrait_key: {breed,sex,look}}},
##   active: fid or -1, ap, mp,
##   title, sub,                     # banner lines
## }
func set_model(m: Dictionary) -> void:
	var order: Array = m.get("order", [])
	var fighters: Dictionary = m.get("fighters", {})
	_left_team = int(m.get("left_team", 0))
	var rebuilt := order != _order or cards.size() != order.size()
	if rebuilt:
		_rebuild(order, fighters)
	var active := int(m.get("active", -1))
	for fid in _order:
		var f: Dictionary = fighters.get(fid, {})
		var c: FighterCard = cards[fid]
		var team := clampi(int(f.get("team", 0)), 0, 1)
		c.team_color = team_colors[team]
		c.inward = 1 if team == _left_team else -1
		c.hp_max = int(f.get("hp_max", 0))
		c.lost = int(f.get("lost", 0))
		c.hp = clampi(c.hp_max - c.lost, 0, c.hp_max) if c.hp_max > 0 else 0
		c.dead = bool(f.get("dead", false))
		c.invisible = bool(f.get("invisible", false))
		c.summon = bool(f.get("summon", false))
		c.buffs = f.get("buffs", [])
		c.active = int(fid) == active
		c.tooltip_text = str(f.get("name", ""))
		c.queue_redraw()
	var af: Dictionary = fighters.get(active, {})
	medallion.shown = not af.is_empty()
	if medallion.shown:
		var ac: FighterCard = cards.get(active)
		medallion.portrait = ac.portrait if ac != null else null
		medallion.initials = ac.initials if ac != null else ""
		medallion.team_color = team_colors[clampi(int(af.get("team", 0)), 0, 1)]
		medallion.hp_max = int(af.get("hp_max", 0))
		medallion.lost = int(af.get("lost", 0))
		medallion.hp = clampi(medallion.hp_max - medallion.lost, 0,
			medallion.hp_max) if medallion.hp_max > 0 else 0
		medallion.ap = int(m.get("ap", 0))
		medallion.mp = int(m.get("mp", 0))
		_sub_col = medallion.team_color
	medallion.queue_redraw()
	_title = str(m.get("title", ""))
	_sub = str(m.get("sub", ""))
	banner.queue_redraw()
	if rebuilt:
		layout_hud()


func set_clock(seconds: float) -> void:
	if is_equal_approx(seconds, _clock):
		return
	var redraw := ceili(seconds) != ceili(_clock) or (seconds < 0) != (_clock < 0)
	_clock = seconds
	if redraw:
		banner.queue_redraw()


func _rebuild(order: Array, fighters: Dictionary) -> void:
	for fid in cards:
		if not order.has(fid):
			cards[fid].queue_free()
	var kept := {}
	for fid in order:
		var c: FighterCard = cards.get(fid)
		if c == null:
			c = FighterCard.new()
			c.name = "Card%d" % int(fid)
			c.fid = int(fid)
			var f: Dictionary = fighters.get(fid, {})
			c.portrait = FighterCard.portrait_for(f)
			c.initials = str(f.get("name", "?")).left(2)
			c.pressed.connect(func(id): card_pressed.emit(id))
			c.hovered.connect(func(id, on): card_hovered.emit(id, on))
			add_child(c)
		c.onebit = onebit
		c.hp_style = hp_style
		kept[fid] = c
	cards = kept
	_order = order.duplicate()


## Columns + medallion + banner for the current viewport. Card size shrinks
## to fit the column (summons a step smaller); past ~9 a column wraps into
## two so 8+ cards per side still fit at 800x600.
func layout_hud() -> void:
	var vp := get_viewport_rect().size
	var mr := clampf(vp.y * 0.065, 34.0, 50.0)
	var ms: Vector2 = Medallion.size_for(mr)
	medallion.radius = mr
	medallion.position = Vector2(MARGIN - 4.0, vp.y - ms.y - 2.0)
	medallion.size = ms
	medal_rect = Rect2(medallion.position, ms)
	var bw := clampf(vp.x * 0.3, 240.0, 360.0)
	banner_rect = Rect2((vp.x - bw) * 0.5, 4.0, bw, 52.0)
	banner.position = banner_rect.position
	banner.size = banner_rect.size
	var left: Array = []
	var right: Array = []
	for fid in _order:
		var c: FighterCard = cards[fid]
		(left if c.inward > 0 else right).append(c)
	var lb := medal_rect.position.y - 8.0
	var rb := vp.y - 10.0
	# one card size for both sides, the smaller of the two fits, so the
	# teams read as equals; each side wraps on its own
	var lf := _column_fit(left, TOP, lb, vp)
	var rf := _column_fit(right, TOP, rb, vp)
	var p := minf(lf.x if not left.is_empty() else 999.0,
		rf.x if not right.is_empty() else 999.0)
	left_w = _layout_column(left, true, TOP, p, int(lf.y), vp)
	right_w = _layout_column(right, false, TOP, p, int(rf.y), vp)


## (portrait side, columns) that fits a column of cards between top and
## bottom — summons count as 0.8 of a card.
func _column_fit(col: Array, top: float, bottom: float, vp: Vector2) -> Vector2:
	if col.is_empty():
		return Vector2(0, 1)
	var max_p := clampf(vp.y * 0.08, 40.0, 60.0)
	var avail := bottom - top
	var units := 0.0
	for c in col:
		units += 0.8 if c.summon else 1.0
	var extra := FighterCard.card_size(0.0, hp_style).y + GAP
	var p := floorf((avail - extra * col.size()) / units)
	var cols := 1
	if p < 30.0 and col.size() > 1:
		cols = 2
		# same split as _layout_column: the first `per` cards, then the rest;
		# the heavier half (fewer summons) sets the size
		var per := ceili(col.size() / 2.0)
		var heavy := 0.0
		for half in [col.slice(0, per), col.slice(per)]:
			var u := 0.0
			for c in half:
				u += 0.8 if c.summon else 1.0
			heavy = maxf(heavy, u)
		p = floorf((avail - extra * per) / heavy)
	return Vector2(clampf(p, 24.0, max_p), cols)


func _layout_column(col: Array, is_left: bool, top: float, p: float,
		cols: int, vp: Vector2) -> float:
	if col.is_empty():
		return 0.0
	var col_w: float = FighterCard.card_size(p, hp_style).x
	var y := top
	var k := 0
	var rows := ceili(col.size() / float(cols))
	for c in col:
		var side: float = floorf(p * (0.8 if c.summon else 1.0))
		var sz: Vector2 = FighterCard.card_size(side, hp_style)
		var ci := k / rows
		if k % rows == 0:
			y = top
		var pad := (col_w - sz.x) * 0.5
		var x_in := MARGIN + ci * (col_w + GAP) + pad
		c.side = side
		c.size = sz
		c.position = Vector2(x_in if is_left else vp.x - x_in - sz.x, y)
		# buff chips clear the whole block, not just this card
		c.chip_gap = (cols - 1 - ci) * (col_w + GAP) + pad
		c.slide = ci == cols - 1
		y += sz.y + GAP
		k += 1
		c.queue_redraw()
	return MARGIN + cols * col_w + (cols - 1) * GAP


func _draw_banner() -> void:
	var r := Rect2(Vector2.ZERO, banner.size)
	var ink := Color.WHITE if onebit else Color("ad965a")
	var plate := Color.BLACK if onebit else Color("292c20")
	_draw_clock(r, ink, plate)
	if _title.is_empty() and _sub.is_empty():
		return
	# a ribbon: a box with notched ends
	var n := 12.0
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(r.end.x, 0),
		Vector2(r.end.x - n, r.size.y * 0.5), Vector2(r.end.x, r.size.y),
		Vector2(0, r.size.y), Vector2(n, r.size.y * 0.5)])
	banner.draw_colored_polygon(pts, Color(plate, 0.94))
	var loop := pts.duplicate()
	loop.append(pts[0])
	banner.draw_polyline(loop, ink, 2.0, true)
	var font: Font = _title_font if _title_font != null else get_theme_default_font()
	var body := get_theme_default_font()
	var tc := Color.WHITE if onebit else Color("f6dc8c")
	_centered(font, _title, Vector2(r.size.x * 0.5, 23.0), 20, tc)
	_centered(body, _sub, Vector2(r.size.x * 0.5, 43.0), 14,
		_sub_col.lightened(0.25))


## The turn clock, a disc left of the ribbon (the top-right corner belongs to
## the menu); it shows on its own too, e.g. before the first round.
func _draw_clock(r: Rect2, ink: Color, plate: Color) -> void:
	if _clock < 0.0:
		return
	var body := get_theme_default_font()
	var c := Vector2(-24.0, r.size.y * 0.5)
	var urgent := _clock <= 5.5
	banner.draw_circle(c, 18.0, plate)
	banner.draw_arc(c, 18.0, 0.0, TAU, 40,
		Color(1.0, 0.45, 0.3) if urgent else ink, 2.0, true)
	_centered(body, str(ceili(_clock)), c + Vector2(0, 6), 16,
		Color(1.0, 0.55, 0.4) if urgent else Color.WHITE)


func _centered(font: Font, s: String, at: Vector2, fs: int, col: Color) -> void:
	if s.is_empty():
		return
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	banner.draw_string(font, at + Vector2(-w * 0.5 + 1, 1), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.9))
	banner.draw_string(font, at + Vector2(-w * 0.5, 0), s,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
