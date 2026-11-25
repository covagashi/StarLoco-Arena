extends Control
## S52: Nilo's guided practice on screen, only in challenge 46 ("Tutorial de
## Baan"). practice_guide.gd decides the step; this node reads the fight
## (fight_view's own state), tells the guide what happened, and draws:
##
##   - Nilo's bubble: his portrait at a screen edge, a white plate with an ink
##     rule and a hard shadow (style B), the step tag, his page, "Siguiente"
##     (or "Continuar") when there is more, and "Saltar práctica". It sits on
##     the side away from what blinks, the foe and our fighter, and stays put
##     until it would cover one of them.
##   - the blink: a pulsing coral ring like the lobby guide's (S47) around a
##     HUD control (Ready / End turn, a spell slot, the turn bar, the AP
##     globe), or a pulsing coral diamond and a bouncing arrow on a cell.
##
## Since the owner's «1 contra 1 con un muñeco» (S52) the fight is our first
## titular against a training dummy (server practice_dummy.go); the foe is
## the living enemy nearest our acting fighter — the dummy — and the spell
## ("{spell}") that fighter's cheapest attack that reaches an adjacent cell
## (the retail lesson's "Presión", which no class has any more).

const PracticeGuide := preload("res://src/fight/practice_guide.gd")
const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const Spells := preload("res://src/gamedata/spells.gd")
const State := preload("res://src/state.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const StyleB := preload("res://src/ui/style_b.gd")

const CHALLENGE := 46
const CORAL := UiStyle.B_CORAL
const INK := UiStyle.B_INK
const NILO := "ui/portraits/npc/nilo.png"
const PLATE_W := 400.0
const FACE := Vector2(124, 146)
const MARGIN := 14.0
const TOP := 214.0      # the highest the bubble goes: under the banner, hints and event strip
const OVERLAP := 16.0   # how far Nilo stands over the plate's edge
const ATTACK_KINDS := ["hit", "bolt", "area"]   # spells.json fx.s that strike

var guide := PracticeGuide.new()
var fv: Node   # the fight view
var _t := 0.0
var _foe := -1
var _goal := Vector2i(-9999, -9999)     # step 4's cell
var _goal_key := []
var _place_cell := Vector2i(-9999, -9999)
var _side := -1                          # bubble: 0 left, 1 right, -1 unplaced
var _slot := 0

var bubble: Control
var _plate: PanelContainer
var _face: TextureRect
var _ribbon: Control
var _tag: Label
var _count: Label
var _text: Label
var _next: Button
var _skip: Button


## Only Nilo's practice, played (not watched, not a replay).
static func wanted(fight_data: Dictionary, spectating: bool, replay: bool) -> bool:
	return int(fight_data.get("fight_type", 0)) == 5 \
		and int(fight_data.get("fight_id", 0)) == CHALLENGE \
		and not spectating and not replay


func _init(view: Node = null) -> void:
	fv = view
	name = "Practice"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	guide.changed.connect(_refresh)
	_refresh()


## --- events from fight_view ------------------------------------------------

func placement() -> void:
	guide.on_placement()


## 8022: a fighter moved while placing.
func placed(fid: int) -> void:
	if _ours(fid):
		guide.on_placed()


func ready_pressed() -> void:
	guide.on_ready()


func turn_began(fid: int, ours: bool) -> void:
	if ours:
		_pick_foe(fid)
	guide.on_turn(ours, ours and _in_reach(_cell_of(fid)))


## 4524: `fid` walks to `to` (its last step).
func moved(fid: int, to: Vector2i) -> void:
	if fid != fv._current_fid or not fv._is_my_turn():
		return
	var on_goal := to == _move_goal()   # the goal from where it set off
	guide.on_moved(_in_reach(to), on_goal)


## 8110 / 8112 / 8108 by `caster`; `aimed` is (-9999, -9999) on a miss.
func cast(caster: int, miss: bool, aimed: Vector2i) -> void:
	if not _ours(caster):
		return
	if not miss and aimed == _cell_of(caster):
		return   # a spell on itself (a boost) is not the lesson's cast
	var hit := false
	if not miss:
		var who: int = fv._occupied_fighter(aimed)
		hit = who >= 0 and _enemy(who)
		if hit:
			_foe = who   # the one it hit is the one to finish
	guide.on_cast(hit)


func died(fid: int) -> void:
	if _enemy(fid):
		guide.on_foe_died()
		if fid == _foe:
			_foe = -1
			if fv._is_my_turn():
				_pick_foe(fv._current_fid)


func turn_ended(fid: int) -> void:
	guide.on_turn_end(_ours(fid))


func fight_over() -> void:
	guide.on_fight_end()


## --- the bubble ------------------------------------------------------------

func _build() -> void:
	bubble = Control.new()
	bubble.name = "Bubble"
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	_plate = PanelContainer.new()
	_plate.name = "Plate"
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = INK
	sb.set_border_width_all(2)
	sb.border_width_top = 4
	sb.shadow_color = Color(INK, 0.9)
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(5, 5)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 10
	_plate.add_theme_stylebox_override("panel", sb)
	_plate.custom_minimum_size = Vector2(PLATE_W, 0)
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	bubble.add_child(_plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_plate.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_tag = Label.new()
	_tag.name = "Tag"
	_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag.add_theme_font_override("font", UiStyle.bold(900))
	_tag.add_theme_font_size_override("font_size", 12)
	_tag.add_theme_color_override("font_color", CORAL)
	head.add_child(_tag)
	_count = Label.new()
	_count.name = "Count"
	_count.add_theme_font_override("font", UiStyle.bold(800))
	_count.add_theme_font_size_override("font_size", 12)
	_count.add_theme_color_override("font_color", UiStyle.B_MUTE)
	head.add_child(_count)
	_text = Label.new()
	_text.name = "Text"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(PLATE_W - 44.0, 0)
	_text.add_theme_font_override("font", UiStyle.bold(700))
	_text.add_theme_font_size_override("font_size", 17)
	_text.add_theme_color_override("font_color", INK)
	col.add_child(_text)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	col.add_child(foot)
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.flat = true
	_skip.focus_mode = Control.FOCUS_ALL
	_skip.add_theme_font_override("font", UiStyle.bold(800))
	_skip.add_theme_font_size_override("font_size", 13)
	for c in ["font_color", "font_focus_color", "font_pressed_color"]:
		_skip.add_theme_color_override(c, UiStyle.B_MUTE)
	_skip.add_theme_color_override("font_hover_color", CORAL)
	_skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip.pressed.connect(func(): guide.skip())
	_skip.draw.connect(func():   # a link: a rule under the words
		var w := _skip.get_theme_font("font").get_string_size(_skip.text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var x := (_skip.size.x - w) * 0.5
		var col_u := CORAL if _skip.is_hovered() else Color(UiStyle.B_MUTE, 0.7)
		_skip.draw_line(Vector2(x, _skip.size.y - 6), Vector2(x + w, _skip.size.y - 6), col_u, 1.0))
	foot.add_child(_skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	_next = StyleB.button(true, 16)
	_next.name = "Next"
	_next.custom_minimum_size = Vector2(150, 38)
	_next.focus_mode = Control.FOCUS_ALL
	_next.pressed.connect(_on_next)
	foot.add_child(_next)
	# Nilo, peeking in from the screen edge, his name on an ink ribbon
	_face = TextureRect.new()
	_face.name = "Face"
	var img := AssetPaths.load_image(NILO)
	if img != null:
		_face.texture = ImageTexture.create_from_image(img)
	_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_face.size = FACE
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(_face)
	_ribbon = Control.new()
	_ribbon.name = "Ribbon"
	_ribbon.size = Vector2(112, 30)
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.draw.connect(func(): StyleB.ribbon(_ribbon, I18n.t("talk.baan"), INK, 18))
	bubble.add_child(_ribbon)


func _on_next() -> void:
	var fid: int = fv._current_fid if fv != null else -1
	var ours: bool = fv != null and fv._is_my_turn()
	if ours:
		_pick_foe(fid)
	guide.next(ours, ours and _in_reach(_cell_of(fid)))


func _refresh() -> void:
	bubble.visible = guide.active()
	if not guide.active():
		queue_redraw()
		return
	_tag.text = I18n.t("practice.tag", {"n": guide.step, "of": PracticeGuide.TOTAL}).to_upper()
	_count.text = "%d / %d" % [guide.page + 1, guide.pages.size()] if guide.pages.size() > 1 else ""
	_text.text = page_text(guide.current_page())
	_skip.text = I18n.t("practice.skip")
	_next.visible = guide.has_next()
	_next.text = I18n.t("btn.next") if guide.page < guide.pages.size() - 1 else I18n.t("practice.go_on")
	_place_cell = Vector2i(-9999, -9999)
	_goal_key = []
	_plate.reset_size()
	queue_redraw()


## Nilo's page `id` with this fight's names in it.
func page_text(id: int) -> String:
	var raw := NpcDialogs.npc_name(id)
	return raw.format(text_vars())


func text_vars() -> Dictionary:
	var f: Dictionary = State.fighters.get(_acting(), {})
	var sid := lesson_spell(f)
	var stats: Array = fv._base_stats(f) if fv != null and not f.is_empty() else [0, 6, 3]
	var foe: Dictionary = State.fighters.get(_foe, {})
	var mp := int(stats[2])   # a turn's MP, as the medallion starts it
	return {
		"foe": str(foe.get("name", "")) if not foe.is_empty() else I18n.t("practice.foe"),
		"spell": Spells.name_of(sid) if sid >= 0 else I18n.t("practice.weapon"),
		"ap": spell_ap(sid), "ap_max": int(stats[1]), "mp": mp,
	}


## The fighter's attack for the lesson: the cheapest one that reaches an
## adjacent cell and that it can afford, a direct strike before a bolt before
## an area; the weapon (-2) when it has none.
static func lesson_spell(f: Dictionary) -> int:
	var best := -2
	var best_key := []
	for sid in f.get("spells", []):
		var m := Spells.meta(int(sid))
		var kind := str(m.get("fx", {}).get("s", "")) if m.get("fx") is Dictionary else ""
		var rank := ATTACK_KINDS.find(kind)
		if rank < 0 or int(m.get("min", 0)) > 1 or int(m.get("max", 0)) < 1:
			continue
		var key := [rank, int(m.get("ap", 99)), int(sid)]
		if best_key.is_empty() or _before(key, best_key):
			best_key = key
			best = int(sid)
	return best


static func _before(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] != b[i]:
			return a[i] < b[i]
	return false


const WEAPON_AP := 5   # server closeCombatAP

static func spell_ap(sid: int) -> int:
	return int(Spells.meta(sid).get("ap", 3)) if sid >= 0 else WEAPON_AP


## --- the fight, read -------------------------------------------------------

func _acting() -> int:
	if fv == null:
		return -1
	if fv._is_my_turn():
		return int(fv._current_fid)
	for fid in State.fight_data.get("timeline", []):   # our first fighter
		if _ours(int(fid)) and not fv._dead.get(int(fid), false):
			return int(fid)
	return -1


func _ours(fid: int) -> bool:
	var f: Dictionary = State.fighters.get(fid, {})
	return not f.is_empty() and int(f.get("coach", -1)) == State.my_coach_id \
		and not f.get("summon", false)


func _enemy(fid: int) -> bool:
	var f: Dictionary = State.fighters.get(fid, {})
	return not f.is_empty() and fv != null and int(f.get("team", -1)) != fv._my_team()


func _cell_of(fid: int) -> Vector2i:
	if fv == null or not fv._actor_cells.has(fid):
		return Vector2i(-9999, -9999)
	var p: Vector3i = fv._actor_cells[fid]
	return Vector2i(p.x, p.y)


## The living enemy nearest `fid` (each of our fighters goes for its own),
## kept on step 6 for the one it hit.
func _pick_foe(fid: int) -> void:
	if guide.step == PracticeGuide.Step.FINISH and _foe >= 0 \
			and not fv._dead.get(_foe, false) and fv._actor_cells.has(_foe):
		return   # the one it hit: finish it
	var from := _cell_of(fid)
	var best := -1
	var best_d := 1 << 30
	for id in fv._actor_cells:
		if not _enemy(int(id)) or fv._dead.get(int(id), false):
			continue
		var c := _cell_of(int(id))
		var d := absi(c.x - from.x) + absi(c.y - from.y)
		if d < best_d or (d == best_d and int(id) < best):
			best_d = d
			best = int(id)
	_foe = best


## From `from`, the lesson spell reaches the foe (range, line, sight).
func _in_reach(from: Vector2i) -> bool:
	if _foe < 0 or from.x <= -9999:
		return false
	var sid := lesson_spell(State.fighters.get(_acting(), {}))
	var m: Dictionary = Spells.meta(sid) if sid >= 0 else {"min": 1, "max": 1}
	var to := _cell_of(_foe)
	var d := absi(to.x - from.x) + absi(to.y - from.y)
	if d < int(m.get("min", 1)) or d > int(m.get("max", 1)):
		return false
	if m.get("line", false) and to.x != from.x and to.y != from.y:
		return false
	if m.get("los", false) and not fv._los_clear(from, to):
		return false
	return true


## Step 4's cell: beside the foe if our MP reach it, else as far along the
## way as they go; none with no MP left (then End turn blinks).
func _move_goal() -> Vector2i:
	var none := Vector2i(-9999, -9999)
	var fid: int = fv._current_fid
	if not fv._is_my_turn() or _foe < 0:
		return none
	var from := _cell_of(fid)
	var to := _cell_of(_foe)
	var key := [from, to, int(fv._mp_left)]
	if key == _goal_key:
		return _goal
	_goal_key = key
	_goal = none
	var mp: int = fv._mp_left
	if mp <= 0 or absi(to.x - from.x) + absi(to.y - from.y) <= 1:
		return _goal   # no MP, or already beside it
	# every cell we can walk to (4-connected, around fighters, like
	# fight_view._find_path); the one nearest the foe, then the shortest way
	var blocked := {}
	for id in fv._actor_cells:
		if int(id) != fid and not fv._dead.get(int(id), false):
			blocked[_cell_of(int(id))] = true
	var prev := {from: from}
	var dist := {from: 0}
	var queue: Array = [from]
	var qi := 0
	var best := from
	var best_key := [absi(to.x - from.x) + absi(to.y - from.y), 0]
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if prev.has(n) or blocked.has(n) or not fv._cells.has(n) \
					or not fv._cells[n].get("ground", false):
				continue
			prev[n] = c
			dist[n] = int(dist[c]) + 1
			queue.append(n)
			var k := [maxi(absi(to.x - n.x) + absi(to.y - n.y), 1), int(dist[n])]
			if _before(k, best_key):
				best_key = k
				best = n
	if best == from:
		return _goal
	# walk back from the best cell to the last one this turn's MP reach
	var way: Array = []
	var cur := best
	while cur != from:
		way.push_front(cur)
		cur = prev[cur]
	_goal = way[mini(mp, way.size()) - 1]
	return _goal


## Step 1's cell: a free start cell of ours, the one nearest the foes (the
## dummy, S52; the enemy start cells before they stand anywhere).
func _placement_goal() -> Vector2i:
	if _place_cell.x > -9999 and fv._occupied_fighter(_place_cell) < 0:
		return _place_cell
	var t: int = fv._my_team()
	var foes: Array = []
	for id in fv._actor_cells:
		if _enemy(int(id)) and not fv._dead.get(int(id), false):
			var p: Vector3i = fv._actor_cells[id]
			foes.append({"x": p.x, "y": p.y})
	if foes.is_empty():
		foes = fv._fmd.get("team%d" % (1 - t), [])
	var best := Vector2i(-9999, -9999)
	var best_d := 1 << 30
	for c in fv._fmd.get("team%d" % t, []):
		var cell := Vector2i(int(c.x), int(c.y))
		if fv._occupied_fighter(cell) >= 0:
			continue
		var d := 1 << 30
		for e in foes:
			d = mini(d, absi(int(e.x) - cell.x) + absi(int(e.y) - cell.y))
		if d < best_d:
			best_d = d
			best = cell
	_place_cell = best
	return best


## What blinks now: {"cell": Vector2i} or {"rect": Rect2} / {"circle": [c, r]}
## in screen space; {} for nothing.
func blink() -> Dictionary:
	if not guide.active() or fv == null:
		return {}
	var mine: bool = fv._is_my_turn()
	match guide.target():
		"cell_place":
			var c := _placement_goal() if fv._placement else Vector2i(-9999, -9999)
			return {"cell": c} if c.x > -9999 else {}
		"ready":
			return _button(fv._end_turn) if fv._placement else {}
		"timeline":
			var strip: Control = fv._fight_hud.get_node_or_null("Timeline")
			return {"rect": strip.get_global_rect()} if strip != null and strip.size.x > 0 else {}
		"cell_move":
			if not mine:
				return {}
			var g := _move_goal()
			if g.x > -9999:
				return {"cell": g}
			return _button(fv._end_turn)
		"spell":
			if not mine:
				return {}
			if fv._spell_mode != -1 or fv._card_mode != -1:
				return {"cell": _cell_of(_foe)} if _foe >= 0 else {}
			return _spell_or_end()
		"ap":
			return _ap_globe() if mine else {}
		"spell_or_end":
			return _spell_or_end() if mine else {}
	return {}


func _spell_or_end() -> Dictionary:
	var b := lesson_button()
	var sid := lesson_spell(State.fighters.get(fv._current_fid, {}))
	if b != null and not b.disabled and fv._ap_left >= spell_ap(sid) and _foe >= 0:
		return _button(b)
	return _button(fv._end_turn)


## The lesson's slot in the spell bar (the weapon's when it has no attack).
func lesson_button() -> Button:
	var sid := lesson_spell(State.fighters.get(fv._current_fid, {}))
	for c in fv.get_node("UI/SpellScroll/SpellBar").get_children():
		if c is Button and not c.is_queued_for_deletion() and c.has_meta("sid") \
				and int(c.get_meta("sid")) == sid:
			return c
	return null


func _button(b: Control) -> Dictionary:
	if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
		return {}
	return {"rect": b.get_global_rect()}


## The blue AP medal on the medallion's left edge (fight_medallion.gd).
func _ap_globe() -> Dictionary:
	var m: Control = fv._fight_hud.medallion
	if m == null or not m.shown:
		return {}
	var r: float = m.radius
	var c: Vector2 = m.get_global_rect().position + Vector2(r + 14.0, m.size.y - r - 8.0)
	return {"circle": [c + Vector2(-r - 4.0, -r * 0.42), 24.0]}


## A cell's diamond on screen.
func cell_poly(cell: Vector2i) -> PackedVector2Array:
	var alt := int(fv._cells.get(cell, {}).get("alt", 0))
	var xf: Transform2D = fv.get_global_transform_with_canvas()
	return xf * fv._cell_poly(cell.x, cell.y, alt)


## --- per frame: pulse, and keep the bubble clear of the action --------------

func _process(dt: float) -> void:
	_t += dt
	if not guide.active() or fv == null:
		if bubble.visible:
			bubble.visible = false
		return
	# the names in the page can change (a new foe, another of ours acting)
	var want := page_text(guide.current_page())
	if want != _text.text:
		_text.text = want
		_plate.reset_size()
	_place_bubble()
	queue_redraw()


## What the bubble must not cover, [rect, weight]: what blinks (100), the foe
## (100 once it is the next thing to click, else 10), our acting fighter (1).
func _avoid() -> Array:
	var out: Array = []
	var b := blink()
	if b.has("rect"):
		out.append([(b.rect as Rect2).grow(16), 100])
	elif b.has("circle"):
		out.append([Rect2(b.circle[0] - Vector2.ONE * 40.0, Vector2.ONE * 80.0), 100])
	elif b.has("cell"):
		out.append([_cell_rect(b.cell), 100])
	var foe_w := 100 if guide.step >= PracticeGuide.Step.CAST else 10
	if _foe >= 0 and fv._actor_cells.has(_foe):
		out.append([_cell_rect(_cell_of(_foe)), foe_w])
	var me := _acting()
	if me >= 0 and fv._actor_cells.has(me):
		out.append([_cell_rect(_cell_of(me)), 1])
	return out


## A cell and the fighter that may stand on it, on screen.
func _cell_rect(cell: Vector2i) -> Rect2:
	var poly := cell_poly(cell)
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	r = r.expand(r.get_center() + Vector2(0, -r.size.y * 3.2))   # the figure above it
	return r.grow(14)


## The places the bubble may take: a screen side, under the banner's line
## down to just over the spell bar, every 30 px.
func _slots() -> int:
	var vp := get_viewport_rect().size
	var h := bubble_rect(0, 0).size.y
	return maxi(1, int((vp.y - 170.0 - h - TOP) / 30.0) + 1)


func bubble_rect(side: int, slot: int) -> Rect2:
	var vp := get_viewport_rect().size
	var plate := _plate.get_combined_minimum_size()
	var w := plate.x + FACE.x - OVERLAP
	var h := maxf(plate.y + 16.0, FACE.y)
	var top := minf(TOP + 30.0 * slot, maxf(TOP, vp.y - 170.0 - h))
	var x := MARGIN if side == 0 else vp.x - MARGIN - w
	return Rect2(x, top, w, h)


## How much a bubble at `r` would hide (the weights of _avoid it meets).
static func cover_cost(r: Rect2, avoid: Array) -> int:
	var cost := 0
	for a in avoid:
		if r.intersects(a[0]):
			cost += int(a[1])
	return cost


func _place_bubble() -> void:
	var avoid := _avoid()
	var now := cover_cost(bubble_rect(_side, _slot), avoid) if _side >= 0 else 1 << 20
	if now > 0:
		# away from what blinks first, high to low, then the other side; the
		# place that hides least (staying put on a tie)
		var vp := get_viewport_rect().size
		var away := 1
		if not avoid.is_empty() and (avoid[0][0] as Rect2).get_center().x > vp.x * 0.5:
			away = 0
		var best := [_side, _slot]
		var best_cost := now
		for side in [away, 1 - away]:
			for slot in _slots():
				var c := cover_cost(bubble_rect(side, slot), avoid)
				if c < best_cost:
					best_cost = c
					best = [side, slot]
		_side = best[0]
		_slot = best[1]
	var r := bubble_rect(_side, _slot)
	var plate := _plate.get_combined_minimum_size()
	bubble.position = r.position
	bubble.size = r.size
	if _side == 0:
		_face.position = Vector2(0, r.size.y - FACE.y)
		_face.flip_h = false
		_plate.position = Vector2(FACE.x - OVERLAP, r.size.y - plate.y - 8.0)
		_ribbon.position = _plate.position + Vector2(44, -_ribbon.size.y + 6)
	else:
		_face.position = Vector2(r.size.x - FACE.x, r.size.y - FACE.y)
		_face.flip_h = true
		_plate.position = Vector2(0, r.size.y - plate.y - 8.0)
		_ribbon.position = _plate.position + Vector2(plate.x - _ribbon.size.x - 44, -_ribbon.size.y + 6)
	_plate.size = plate
	bubble.move_child(_face, -1)   # Nilo over the plate's edge


## --- the blink -------------------------------------------------------------

func _draw() -> void:
	var b := blink()
	if b.is_empty():
		return
	var pulse := 0.5 + 0.5 * sin(_t * 4.0)
	if b.has("rect"):
		var r: Rect2 = (b.rect as Rect2).grow(6)
		draw_rect(r, Color(CORAL, 0.35 + 0.5 * pulse), false, 3.0 + 2.0 * pulse)
		draw_rect(r.grow(6 + 4 * pulse), Color(CORAL, 0.25 * (1.0 - pulse)), false, 2.0)
		if r.get_center().y > get_viewport_rect().size.y * 0.5:   # not over the turn bar
			_arrow(Vector2(r.get_center().x, r.position.y - 8.0), pulse)
	elif b.has("circle"):
		var c: Vector2 = b.circle[0]
		var rad: float = b.circle[1]
		draw_arc(c, rad + 2.0 * pulse, 0, TAU, 40, Color(CORAL, 0.4 + 0.5 * pulse), 3.0 + 2.0 * pulse, true)
		draw_arc(c, rad + 8.0 + 6.0 * pulse, 0, TAU, 40, Color(CORAL, 0.3 * (1.0 - pulse)), 2.0, true)
		_arrow(c + Vector2(0, -rad - 8.0), pulse)
	elif b.has("cell"):
		var poly := cell_poly(b.cell)
		var ctr := (poly[0] + poly[2]) * 0.5
		draw_colored_polygon(poly, Color(CORAL, 0.18 + 0.2 * pulse))
		var loop := poly.duplicate()
		loop.append(poly[0])
		draw_polyline(loop, Color(INK, 0.6), 5.0 + 2.0 * pulse, true)
		draw_polyline(loop, Color(CORAL, 0.7 + 0.3 * pulse), 3.0 + 1.5 * pulse, true)
		var k := 1.15 + 0.35 * (1.0 - pulse)
		var outer := PackedVector2Array()
		for p in loop:
			outer.append(ctr + (p - ctr) * k)
		draw_polyline(outer, Color(CORAL, 0.45 * pulse), 2.0, true)
		_arrow(ctr + Vector2(0, -(poly[2].y - poly[0].y) * 0.5 - 70.0), pulse)


## A coral arrow with an ink rim pointing down at `tip`, bobbing.
func _arrow(tip: Vector2, pulse: float) -> void:
	var t := tip + Vector2(0, -6.0 * pulse)
	var pts := PackedVector2Array([t, t + Vector2(-15, -17), t + Vector2(-6, -17),
		t + Vector2(-6, -32), t + Vector2(6, -32), t + Vector2(6, -17), t + Vector2(15, -17)])
	var rim := pts.duplicate()
	rim.append(pts[0])
	draw_colored_polygon(pts, CORAL)
	draw_polyline(rim, INK, 2.5, true)
