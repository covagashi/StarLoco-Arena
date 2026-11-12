extends Control
## The fight HUD, as in the S45 mockup ("5 · Combate"; S17 put the fighters'
## information off the map, this keeps that and changes where it lives):
##
##   - the turn order across the top in one dark pill: the acting fighter
##     first and larger, its clock as a badge and a ring that runs out, then
##     the others in the order they play, each in its team's ring that is
##     also its life; a KO greys out;
##   - under it, "¡Te toca!" in pop when the turn is yours, or whose turn it
##     is in navy;
##   - the acting fighter bottom-left: a large portrait with its life as a
##     ring, AP and MP medallions, its name, life and effects.
##
## fight_view owns the fight state and pushes a plain model with set_model();
## this node only draws it and reports clicks/hovers. The spell bar, the PASS
## button, the menu and the chat stay fight_view nodes; it lays them out
## around the rects this node publishes (medal_rect, banner_rect).

signal card_pressed(fid: int)
signal card_hovered(fid: int, on: bool)

const FighterCard := preload("res://src/fight/fighter_card.gd")
const Medallion := preload("res://src/fight/fight_medallion.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")

var hp_style: int = FighterCard.HpStyle.RING
var team_colors: Array = [Color("4c8dff"), Color("ff4d5e")]
var clock_max := 30.0   # a full turn, for the active fighter's ring

## Published by layout_hud() for fight_view's own nodes.
var medal_rect := Rect2()
var banner_rect := Rect2()
var left_w := 0.0       # no side columns any more: the map is the screen
var right_w := 0.0

var cards := {}         # fid -> FighterCard, in initiative order
var medallion: Control
var banner: Control
var _strip: Control     # the dark pill behind the turn order
var _badges: Control    # the clock badge over the acting portrait
var _order: Array = []  # fids, initiative order
var _active := -1
var _left_team := 0
var _title := ""
var _sub := ""
var _sub_col := Color.WHITE
var _mine := false
var _clock := -1.0
var _peek := -1         # the fighter under the pointer in the turn order
var _peek_card: Control
var _names := {}        # fid -> name, for the peek card

const TOP := 14.0
const ACTIVE_SIDE := 56.0
const SIDE := 40.0
const SUMMON_SIDE := 32.0
const GAP := 8.0
const PAD := 10.0


func _init() -> void:
	name = "Hud"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_strip = Control.new()
	_strip.name = "Timeline"
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.draw.connect(_draw_strip)
	add_child(_strip)
	_badges = Control.new()
	_badges.name = "Clock"
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badges.draw.connect(_draw_badges)
	add_child(_badges)
	medallion = Medallion.new()
	medallion.name = "Medallion"
	add_child(medallion)
	banner = Control.new()
	banner.name = "Banner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.draw.connect(_draw_banner)
	add_child(banner)
	_peek_card = Control.new()
	_peek_card.name = "Peek"
	_peek_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_peek_card.draw.connect(_draw_peek)
	add_child(_peek_card)


## model = {
##   left_team: int,                 # our team (blue)
##   order: [fid…],                  # initiative order
##   fighters: {fid: {team, name, hp, hp_max, lost, dead, invisible,
##                    summon, buffs: [str], portrait_key: {breed,sex,look}}},
##   active: fid or -1, ap, mp,
##   mine: bool,                     # the acting fighter is ours to play
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
	var moved := active != _active
	_active = active
	for fid in _order:
		var f: Dictionary = fighters.get(fid, {})
		var c: FighterCard = cards[fid]
		var team := clampi(int(f.get("team", 0)), 0, 1)
		# blue is always us, red the rival
		c.team_color = team_colors[0 if team == _left_team else 1]
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
		_names[fid] = str(f.get("name", ""))
		c.queue_redraw()
	var af: Dictionary = fighters.get(active, {})
	medallion.shown = not af.is_empty()
	if medallion.shown:
		var ac: FighterCard = cards.get(active)
		medallion.portrait = ac.portrait if ac != null else null
		medallion.initials = ac.initials if ac != null else ""
		var team := clampi(int(af.get("team", 0)), 0, 1)
		medallion.team_color = team_colors[0 if team == _left_team else 1]
		medallion.fighter_name = str(af.get("name", ""))
		medallion.buffs = af.get("buffs", [])
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
	_mine = bool(m.get("mine", false))
	banner.queue_redraw()
	_badges.queue_redraw()
	if rebuilt or moved:
		layout_hud()


func set_clock(seconds: float) -> void:
	if is_equal_approx(seconds, _clock):
		return
	_clock = seconds
	_badges.queue_redraw()


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
			c.round = true
			var f: Dictionary = fighters.get(fid, {})
			c.portrait = FighterCard.portrait_for(f)
			c.initials = str(f.get("name", "?")).left(2)
			c.pressed.connect(func(id): card_pressed.emit(id))
			c.hovered.connect(func(id, on):
				_peek = id if on else (-1 if _peek == id else _peek)
				_peek_card.queue_redraw()
				card_hovered.emit(id, on))
			add_child(c)
		c.hp_style = hp_style
		kept[fid] = c
	cards = kept
	_order = order.duplicate()
	move_child(_badges, get_child_count() - 1)
	move_child(_peek_card, get_child_count() - 1)


## The turn order (from the acting fighter on), the banner under it and the
## acting fighter's block bottom-left, for the current viewport.
func layout_hud() -> void:
	var vp := get_viewport_rect().size
	# who plays from now on: the acting fighter, then the rest in order
	var seq: Array = _order.duplicate()
	var at := seq.find(_active)
	if at > 0:
		seq = seq.slice(at) + seq.slice(0, at)
	var sides: Array = []
	for fid in seq:
		var c: FighterCard = cards[fid]
		sides.append(ACTIVE_SIDE if int(fid) == _active else (SUMMON_SIDE if c.summon else SIDE))
	# clear of the arena label (left) and the four round buttons (right)
	var fit := fit_timeline(sides, at >= 0, vp.x - 2.0 * 285.0)
	var k := fit.x
	var shown := int(fit.y)
	for i in seq.size():
		cards[seq[i]].visible = i < shown
	seq = seq.slice(0, shown)
	sides = sides.slice(0, shown)
	var total := _strip_width(sides, at >= 0)
	var x := (vp.x - total * k) * 0.5 + PAD * k
	var h := (ACTIVE_SIDE + 8.0) * k + 12.0
	for i in seq.size():
		var c: FighterCard = cards[seq[i]]
		var side: float = floorf(sides[i] * k)
		c.side = side
		c.size = FighterCard.card_size(side, FighterCard.HpStyle.RING)
		c.position = Vector2(x, TOP + (h - c.size.y) * 0.5)
		x += c.size.x + GAP * k
		if i == 0 and at >= 0:
			x += 9.0 * k
		c.queue_redraw()
	_strip.position = Vector2((vp.x - total * k) * 0.5, TOP)
	_strip.size = Vector2(total * k, h)
	_strip.set_meta("rule", (cards[seq[0]].position.x + cards[seq[0]].size.x + 4.0 * k - _strip.position.x) if at >= 0 and not seq.is_empty() else -1.0)
	_strip.queue_redraw()
	_badges.size = vp
	_peek_card.size = vp
	var bw := clampf(vp.x * 0.42, 300.0, 520.0)
	banner_rect = Rect2((vp.x - bw) * 0.5, TOP + h + 8.0, bw, 36.0)
	banner.position = banner_rect.position
	banner.size = banner_rect.size
	var ms := Vector2(340.0, 124.0)
	medallion.position = Vector2(20.0, vp.y - ms.y - 16.0)
	medallion.size = ms
	medal_rect = Rect2(medallion.position, Vector2(medallion.used_width(), ms.y))


## The turn order's scale and how many portraits fit in `room` px: everyone
## a step smaller first (down to MIN_K), then only the next ones. Pure, for
## the unit test.
const MIN_K := 0.7


static func fit_timeline(sides: Array, has_active: bool, room: float) -> Vector2:
	var total := _strip_width(sides, has_active)
	var k := minf(1.0, room / maxf(total, 1.0))
	if k >= MIN_K:
		return Vector2(k, sides.size())
	var n := sides.size()
	while n > 1 and _strip_width(sides.slice(0, n), has_active) * MIN_K > room:
		n -= 1
	return Vector2(MIN_K, n)


static func _strip_width(sides: Array, has_active: bool) -> float:
	var total := PAD * 2.0
	for s in sides:
		total += s + 8.0 + GAP
	total -= GAP
	if has_active:
		total += 9.0   # the rule after the acting fighter
	return total


func _draw_strip() -> void:
	if _order.is_empty():
		return
	var r := Rect2(Vector2.ZERO, _strip.size)
	# style B: a dark band with a white rule along its top
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.08, 0.16, 0.82)
	sb.border_color = Color(1, 1, 1, 0.85)
	sb.border_width_top = 2
	_strip.draw_style_box(sb, r)
	var rule: float = _strip.get_meta("rule", -1.0)
	if rule > 0.0:
		_strip.draw_line(Vector2(rule, r.size.y * 0.22), Vector2(rule, r.size.y * 0.78),
			Color(1, 1, 1, 0.15), 1.0)


## The clock: a pop badge on the acting portrait (or a disc of its own at the
## pill's left when nobody acts, e.g. while placing).
func _draw_badges() -> void:
	if _clock < 0.0:
		return
	var urgent := _clock <= 5.5
	var col := Color("e0283b") if urgent else UiStyle.B_CORAL
	var c: FighterCard = cards.get(_active)
	var at: Vector2
	var r := 12.0
	if c != null:
		at = c.position + c.size - Vector2(8, 8)
	else:
		at = _strip.position + Vector2(-22, _strip.size.y * 0.5) if not _order.is_empty() \
			else Vector2(get_viewport_rect().size.x * 0.5, TOP + 30)
		r = 18.0
	_badges.draw_circle(at, r + 2.0, UiStyle.NIGHT)
	_badges.draw_circle(at, r, col)
	var f := UiStyle.display_font()
	var s := str(ceili(_clock))
	var fs := int(r * 1.25)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	_badges.draw_string(f, at + Vector2(-w * 0.5, fs * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# the acting portrait's ring runs out with the clock
	if c != null and clock_max > 0.0:
		var cc := c.position + c.size * 0.5
		var rr := c.side * 0.5 + 4.0
		var frac := clampf(_clock / clock_max, 0.0, 1.0)
		_badges.draw_arc(cc, rr, -PI * 0.5 + TAU * frac, -PI * 0.5 + TAU, 48,
			Color(1, 1, 1, 0.18), 4.0, true)


## "¡Te toca!" (pop) or whose turn it is (navy), under the turn order.
func _draw_banner() -> void:
	if _title.is_empty() and _sub.is_empty():
		return
	var title := UiStyle.display_font()
	var body := UiStyle.bold(800)
	var head := I18n.t("fight.your_turn") if _mine else ""
	var rest := _title
	if not _mine and not _sub.is_empty():
		rest = "%s · %s" % [_title, _sub] if not _title.is_empty() else _sub
	var hw := title.get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x if head != "" else 0.0
	var rw := body.get_string_size(rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var w := hw + rw + (10.0 if head != "" and rest != "" else 0.0) + 36.0
	var r := Rect2((banner.size.x - w) * 0.5, 0, w, banner.size.y)
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiStyle.B_CORAL if _mine else Color(0.07, 0.08, 0.16, 0.86)
	sb.skew = Vector2(0.3, 0)
	if not _mine:
		sb.border_color = Color(_sub_col, 0.9)
		sb.border_width_bottom = 3
	banner.draw_style_box(sb, r)
	var ink := Color.WHITE
	var x := r.position.x + 18.0
	var base := r.size.y * 0.5 + 6.0
	if head != "":
		banner.draw_string(title, Vector2(x, base), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, ink)
		x += hw + 10.0
	banner.draw_string(body, Vector2(x, base - 1.0), rest, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)


## The cream card under a portrait the pointer is on (the mockup's hover
## card): its name and side, its life as a bar and in numbers.
func _draw_peek() -> void:
	var c: FighterCard = cards.get(_peek)
	if c == null:
		return
	var w := 214.0
	var h := 74.0
	var x := clampf(c.position.x + c.size.x * 0.5 - w * 0.5, 8.0, _peek_card.size.x - w - 8.0)
	# under the banner and the hint line, so neither is covered
	var r := Rect2(x, banner_rect.end.y + 44.0, w, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = UiStyle.B_INK
	sb.border_width_top = 3
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0, 6)
	_peek_card.draw_style_box(sb, r)
	var ink := Color("1e2142")
	var soft := Color("5a5f86")
	var b9 := UiStyle.bold(900)
	var b8 := UiStyle.bold(800)
	var ours := c.inward > 0
	var dot := c.team_color
	_peek_card.draw_circle(r.position + Vector2(19, 21), 5, dot)
	_peek_card.draw_string(b9, r.position + Vector2(31, 27), str(_names.get(_peek, "")),
		HORIZONTAL_ALIGNMENT_LEFT, w - 90, 15, ink)
	var side := I18n.t("fi.ours" if ours else "fi.theirs")
	var sw := b8.get_string_size(side, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_peek_card.draw_string(b8, r.position + Vector2(w - 14 - sw, 26), side, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, soft)
	var bar := Rect2(r.position + Vector2(14, 38), Vector2(w - 28, 8))
	_peek_card.draw_rect(bar, Color("e3ddcb"))
	if c.hp_max > 0:
		_peek_card.draw_rect(Rect2(bar.position, Vector2(bar.size.x * c.hp_ratio(), bar.size.y)), dot)
	var life := ("%d / %d %s" % [c.hp, c.hp_max, I18n.t("fight.hp_short")]) if c.hp_max > 0 \
		else ("-%d %s" % [c.lost, I18n.t("fight.hp_short")] if c.lost > 0 else "?")
	if c.dead:
		life = "KO"
	_peek_card.draw_string(b8, r.position + Vector2(14, 64), life, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("3b3f66"))
