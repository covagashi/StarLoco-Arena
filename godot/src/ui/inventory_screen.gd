extends "res://src/ui/hero_panel.gd"
## Inventario (S47, owner point 12: "rework grande de Inventario /
## Colecciones"): a screen of its own instead of the modal, dressed like the
## recruit screen (slabs with a hard ink shadow, ribbons, slanted choices).
##
## Cartas: on the left, on a slab under a coral ribbon, what the cards are
## FOR with how many of each on an ink tab (Todo, Equipo del coach,
## Consumibles, Cosméticos, Combate, Fusión, Reliquias, Arenas, Otras), then
## the search, the order as three choices and "Equipo del coach"; in the
## middle the cards; on the paper at the right the picked card large — its
## kind as a medallion, its rarity as diamonds, copies and value, what it
## does, what it is for, its collection with a bar — and "Ponérsela al jefe"
## pinned under the paper for coach gear.
## Colecciones: an album, every collection a slab with its bar and its cards
## small (the ones you lack greyed); the picked one's bonuses and what is
## missing on the paper.
##
## Reads localCoach.cardInventory and localCoach.cardSets as the old panel
## did; answers nativeEquipOpen. Keeps the old panel's node names (CardGrid,
## Card<id>, SortPick, CardName, CardEffects, CardUse, SetBonuses,
## CoachEquip) for the smokes.

const Panels := preload("res://src/ui/lobby_panels.gd")
const CardText := preload("res://src/gamedata/card_text.gd")
const Cards := preload("res://src/gamedata/cards.gd")
const GRID := Rect2(324, 100, 484, 596)
const KINDS := ["all", "coach", "consumable", "cosmetic", "combat", "fusion", "dofus", "arena", "other"]
const SORTS := ["name", "value", "qty"]
const MINI := Vector2(46, 56)
const LEFT_W := 290.0        # the left column, under the title
const ROW_H := 34.0          # a row of the slab (a kind, a show)
const ROW_GAP := 6.0
const SLAB_CUT := 18.0

var _left: VBoxContainer
var _tabs_box: HBoxContainer
var _center: ScrollContainer
var _built := false
var _last_pick := -1         # the sheet scrolls back up when another card is picked


func _ready() -> void:
	panel_name = "cardBookDialog"
	super._ready()
	harden_sheet(R_SHEET.size)
	_tabs_box = HBoxContainer.new()
	_tabs_box.name = "InvTabs"
	_tabs_box.position = Vector2(560, 34)
	_tabs_box.add_theme_constant_override("separation", 8)
	stage.add_child(_tabs_box)
	_left = VBoxContainer.new()
	_left.name = "Kinds"
	_left.position = Vector2(28, 116)
	_left.custom_minimum_size = Vector2(LEFT_W, 0)
	_left.add_theme_constant_override("separation", 12)
	stage.add_child(_left)
	_center = ScrollContainer.new()
	_center.name = "Center"
	_center.position = GRID.position
	_center.size = GRID.size
	_center.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_center.get_v_scroll_bar().theme = UiStyle.paper_theme()   # the paper's thin bar, not a navy rule
	stage.add_child(_center)
	_built = true
	refresh()
	StyleB.enter(self, [_left], Vector2(-40, 0), 0.15, 0.0, 0.5)


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	var root := model_name.split(".")[0]
	if root == "localCoach" or root == "tomeManager":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null or not _built:
		return
	var focus := remember_focus()
	clear_body()
	pinned_actions.hide()
	title.text = I18n.t("panel.inventory")
	_build_tabs()
	for c in _left.get_children():
		_left.remove_child(c)
		c.queue_free()
	for c in _center.get_children():
		_center.remove_child(c)
		c.queue_free()
	if tab == 1:
		_sets()
	else:
		_cards()
	restore_focus(focus)


func _build_tabs() -> void:
	for c in _tabs_box.get_children():
		_tabs_box.remove_child(c)
		c.queue_free()
	for i in 2:
		var b := StyleB.button(i == tab, 18)
		b.name = "InvTab%d" % i
		b.text = I18n.t("inv.cards" if i == 0 else "inv.sets")
		b.custom_minimum_size = Vector2(150, 44)
		var id := i
		b.pressed.connect(func():
			if tab != id:
				tab = id
				selected = {}
				schedule_refresh())
		_tabs_box.add_child(b)


# ------------------------------------------------------------------ left

## A white slab under a coral ribbon that names it, sized for `n` rows; the
## rows go in the box it returns.
func _slab(cap: String, n: int) -> VBoxContainer:
	var holder := Control.new()
	var h := 24.0 + n * ROW_H + maxf(0, n - 1) * ROW_GAP + 16.0
	holder.custom_minimum_size = Vector2(LEFT_W, h)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.draw.connect(func(): StyleB.draw_slab(holder, Vector2(LEFT_W - 6, h - 6), SLAB_CUT))
	_left.add_child(holder)
	var rib := Control.new()
	rib.position = Vector2(-6, -12)
	rib.size = Vector2(LEFT_W + 6, 26)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.draw.connect(func(): StyleB.ribbon(rib, cap, UiStyle.B_CORAL, 15))
	holder.add_child(rib)
	var rows := VBoxContainer.new()
	rows.position = Vector2(10, 24)
	rows.size = Vector2(LEFT_W - 6 - 24, h - 24 - 16)
	rows.add_theme_constant_override("separation", int(ROW_GAP))
	holder.add_child(rows)
	return rows


## A row of the slab: a slanted face, coral with white text when picked,
## white with an ink rim when not (coral under the pointer); how many on an
## ink tab at its right end, in gold.
func _kind_row(text: String, n: int, on: bool) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, ROW_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(col, Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	b.text = text
	b.set_pressed_no_signal(on)
	var font := UiStyle.display_font()
	var cf := UiStyle.bold(900)
	b.draw.connect(func():
		var s := b.size - Vector2(3, 3)
		var k := 8.0
		var face := PackedVector2Array([Vector2(k, 0), Vector2(s.x, 0), Vector2(s.x - k, s.y), Vector2(0, s.y)])
		var lit := b.is_hovered() or b.has_focus()
		var sh := PackedVector2Array()
		for p in face:
			sh.append(p + Vector2(3, 3))
		b.draw_colored_polygon(sh, Color(UiStyle.B_INK, 0.9 if on else 0.2))
		b.draw_colored_polygon(face, UiStyle.B_CORAL if on else Color.WHITE)
		var loop := face.duplicate()
		loop.append(face[0])
		b.draw_polyline(loop, UiStyle.B_CORAL if lit and not on else UiStyle.B_INK, 2.0, true)
		# the count on an ink tab at the right end
		var cnt := str(n)
		var cw := cf.get_string_size(cnt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tw := cw + 20.0
		b.draw_colored_polygon(PackedVector2Array([Vector2(s.x - tw, 0), Vector2(s.x, 0),
			Vector2(s.x - k, s.y), Vector2(s.x - tw - k, s.y)]), UiStyle.B_INK)
		b.draw_string(cf, Vector2(s.x - tw - k * 0.5 + (tw - cw) * 0.5, (s.y + 13 * 0.72) * 0.5), cnt,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.B_GOLD)
		b.draw_string(font, Vector2(k + 8, (s.y + 15 * 0.72) * 0.5), text.to_upper(),
			HORIZONTAL_ALIGNMENT_LEFT, s.x - tw - k - 20, 15, Color.WHITE if on else UiStyle.B_INK))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
		sig.connect(b.queue_redraw)
	return b


## The search: a white field with a full ink rim, a nameplate set in the
## stone (the recruit's name field), kept in draft[`key`].
func _search(key: String, placeholder: String) -> LineEdit:
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = placeholder
	search.text = str(draft.get(key, ""))
	search.custom_minimum_size = Vector2(LEFT_W - 6, 40)
	search.clear_button_enabled = true
	StyleB.field(search, 16)
	for st in ["normal", "focus"]:
		var sb: StyleBoxFlat = search.get_theme_stylebox(st)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 3 if st == "normal" else 4
		sb.bg_color = Color.WHITE
	search.text_changed.connect(func(t):
		draft[key] = t
		schedule_refresh())
	_left.add_child(search)
	return search


## A muted line that wraps to its box: an unwrapped one widened the paper
## past the screen's edge.
func _hint(parent: Node, text: String) -> Label:
	var l := _muted(parent, text)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## A caption on the stage (the backdrop is light: ink, muted).
func _stage_caption(text: String) -> Label:
	var l := UiStyle.caption(text)
	l.add_theme_color_override("font_color", UiStyle.B_MUTE)
	return l


# ------------------------------------------------------------------ cards

func _items() -> Array:
	var v: Variant = data("localCoach.cardInventory", [])
	return v if v is Array else []


func _kind_of(it: Dictionary) -> String:
	return Panels._inv_kind(int(it.get("cardType", 0)))


func _cards() -> void:
	var all := _items()
	var kind := str(draft.get("inv_kind", "all"))
	# the left column: what the cards are for, with how many, on a slab
	var counts := {}
	for k in KINDS:
		counts[k] = all.size() if k == "all" else all.filter(func(it): return _kind_of(it) == k).size()
	var shown := KINDS.filter(func(k): return k == "all" or int(counts[k]) > 0)
	var rows := _slab(I18n.t("inv.for_what"), shown.size())
	for k in shown:
		var b := _kind_row(I18n.t("inv.kind_%s" % k), int(counts[k]), k == kind)
		b.name = "Kind_" + k
		var kk: String = k
		b.pressed.connect(func():
			draft["inv_kind"] = kk
			selected = {}
			schedule_refresh())
		rows.add_child(b)
	_search("search", I18n.t("inv.search_ph"))
	# the order: three choices
	var sort_pick := int(draft.get("sort", 0))
	var order := VBoxContainer.new()
	order.add_theme_constant_override("separation", 4)
	order.add_child(_stage_caption(I18n.t("inv.sort")))
	var sort_row := HBoxContainer.new()
	sort_row.name = "SortPick"
	sort_row.add_theme_constant_override("separation", 8)
	sort_row.custom_minimum_size = Vector2(LEFT_W - 6, 0)
	for i in SORTS.size():
		var b := StyleB.choice(15)
		b.name = "Sort_" + SORTS[i]
		b.text = I18n.t("inv.sort_%s" % SORTS[i])
		b.custom_minimum_size = Vector2(0, 36)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.set_pressed_no_signal(i == sort_pick)
		var si := i
		b.pressed.connect(func():
			draft["sort"] = si
			schedule_refresh())
		sort_row.add_child(b)
	order.add_child(sort_row)
	_left.add_child(order)
	var eq := StyleB.button(false, 16)
	eq.name = "CoachEquip"
	eq.text = I18n.t("inv.coach_equip")
	eq.custom_minimum_size = Vector2(LEFT_W - 6, 44)
	eq.pressed.connect(func(): send("nativeEquipOpen"))
	_left.add_child(eq)
	# the cards
	var items: Array = all if kind == "all" else all.filter(func(it): return _kind_of(it) == kind)
	var needle := str(draft.get("search", "")).strip_edges().to_lower()
	if needle != "":
		items = items.filter(func(it): return str(it.get("name", "")).to_lower().contains(needle))
	match SORTS[clampi(sort_pick, 0, SORTS.size() - 1)]:
		"name": items.sort_custom(func(a, b): return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
		"value": items.sort_custom(func(a, b): return int(a.get("value", 0)) > int(b.get("value", 0)))
		"qty": items.sort_custom(func(a, b): return int(a.get("quantity", 0)) > int(b.get("quantity", 0)))
	var grid := HFlowContainer.new()
	grid.name = "CardGrid"
	grid.custom_minimum_size = Vector2(GRID.size.x - 14, 0)
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	_center.add_child(grid)
	var count := Label.new()
	count.name = "InvCount"
	count.text = I18n.t("inv.count", {"n": items.size()})
	count.visible = false
	grid.add_child(count)
	if items.is_empty():
		_muted(grid, I18n.t("common.empty"))
	var pick := int(selected.get("id", -1))
	for it in items:
		var t := _tile(grid, it, int(it.get("id", -2)) == pick, "×%d" % int(it.get("quantity", 0)),
			I18n.t("inv.value_n", {"n": int(it.get("value", 0))}))
		t.name = "Card%d" % int(it.get("id", 0))
		var item: Dictionary = it
		t.pressed.connect(func():
			selected = item
			schedule_refresh())
	_card_sheet(items, pick)


## The paper: the picked card large and what it is.
func _card_sheet(items: Array, pick: int) -> void:
	sheet_tag.text = I18n.t("inv.card_tag").to_upper()
	if pick != _last_pick:
		_last_pick = pick
		sheet_scroll.scroll_vertical = 0
	if selected.is_empty() or not items.any(func(i): return int(i.get("id", -2)) == pick):
		sheet_title.text = I18n.t("panel.inventory")
		_fit_title()
		_hint(body, I18n.t("inv.pick_hint"))
		return
	sheet_title.text = str(selected.get("name", ""))
	_fit_title()
	var head := row(body)
	head.add_child(_framed_art(pick, Vector2(150, 180)))
	var facts := column(head)
	facts.add_theme_constant_override("separation", 10)
	var nm := Label.new()   # the smokes read the name here; the ribbon above shows it
	nm.name = "CardName"
	nm.text = str(selected.get("name", ""))
	nm.visible = false
	facts.add_child(nm)
	var kind := _kind_of(selected)
	facts.add_child(_kind_medal(kind))
	facts.add_child(_diamonds(Cards.tier_of(pick)))
	var copies := Label.new()
	copies.name = "CardCopies"
	UiStyle.display(copies, 30)
	copies.text = "×%d" % int(selected.get("quantity", 0))
	facts.add_child(copies)
	var val := label(facts, I18n.t("inv.value_n", {"n": int(selected.get("value", 0))}), 15)
	val.add_theme_font_override("font", UiStyle.bold(800))
	val.add_theme_color_override("font_color", UiStyle.BROWN)
	var fx := CardText.card_lines(pick)
	if not fx.is_empty() or kind == "coach":
		body.add_child(UiStyle.caption(I18n.t("inv.does")))
		var fx_l := _ruled(body, "\n".join(fx) if not fx.is_empty() else I18n.t("inv.no_effects"), 15)
		fx_l.name = "CardEffects"
	var use := label(body, I18n.t("inv.use_%s" % kind), 15)
	use.name = "CardUse"
	use.add_theme_font_override("font", UiStyle.bold(800))
	use.add_theme_color_override("font_color", UiStyle.BROWN)
	# its collection, and how much of it you hold
	var sid := int(Cards.meta(pick).get("set", 0))
	var st := _set_by_id(sid)
	if not st.is_empty():
		var have := int(st.get("completion", 0))
		var of := int(st.get("size", 0))
		var sl := label(body, I18n.t("inv.in_set", {"name": str(st.get("name", "")), "have": have, "of": of}), 15)
		sl.name = "CardSet"
		sl.add_theme_font_override("font", UiStyle.bold(800))
		body.add_child(_bar(have, of))
	if kind == "coach":
		var on := hero_button(I18n.t("inv.wear_it"), func(): send("nativeEquipOpen"), true, true)
		on.name = "WearIt"
		pinned_actions.show()


## A long name shrinks the paper's title (down to 20) instead of losing its
## end to an ellipsis.
func _fit_title() -> void:
	var font := UiStyle.display_font()
	var w := R_SHEET.size.x - 26 - 22   # the paper's margins
	var fs := 30
	while fs > 20 and font.get_string_size(sheet_title.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		fs -= 2
	sheet_title.add_theme_font_size_override("font_size", fs)


## The kind as a medallion (a ringed disc in the family's colour with its
## pictogram, a hard shadow) and its name in coral beside it.
func _kind_medal(kind: String) -> Control:
	var c := Control.new()
	c.name = "CardKind"
	c.custom_minimum_size = Vector2(0, 40)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var colour: Color = CardFace.FAMILY_COLOUR.get(kind, CardFace.FAMILY_COLOUR.other)
	var pic := CardFace._tex("ui/cards/family/%s.webp" % kind)
	var font := UiStyle.display_font()
	var text := I18n.t("inv.kind_%s" % kind).to_upper()
	c.draw.connect(func():
		var at := Vector2(20, 20)
		c.draw_circle(at + Vector2(3, 3), 19, Color(UiStyle.B_INK, 0.9))
		c.draw_circle(at, 19, UiStyle.B_INK)
		c.draw_circle(at, 16.5, colour)
		c.draw_arc(at, 14.5, 0, TAU, 40, Color(1, 1, 1, 0.4), 1.0, true)
		if pic != null:
			c.draw_texture_rect(pic, Rect2(at - Vector2(14, 14), Vector2(28, 28)), false)
		c.draw_string(font, Vector2(50, (40 + 18 * 0.72) * 0.5), text, HORIZONTAL_ALIGNMENT_LEFT,
			c.size.x - 50, 18, UiStyle.B_CORAL))
	return c


## The rarity as four diamonds, the card's tier of them lit in gold, all
## outlined in ink with a hard shadow (the recruit's stars).
func _diamonds(tier: int) -> Control:
	var c := Control.new()
	c.name = "Rarity"
	c.custom_minimum_size = Vector2(0, 22)
	c.set_meta("tier", tier)
	c.draw.connect(func():
		for i in 4:
			var at := Vector2(12 + i * 24, 11)
			var on := i <= tier
			for layer in [[Vector2(2, 2), 9.0, Color(UiStyle.B_INK, 0.9)], [Vector2.ZERO, 9.0, UiStyle.B_INK],
					[Vector2.ZERO, 6.0, UiStyle.B_GOLD if on else Color.WHITE]]:
				var m: Vector2 = at + layer[0]
				var r: float = layer[1]
				c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -r), m + Vector2(r * 0.8, 0),
					m + Vector2(0, r), m + Vector2(-r * 0.8, 0)]), layer[2]))
	return c


## A paragraph behind a coral rule (what a card does, a collection's bonuses).
func _ruled(parent: Node, text: String, font_size: int) -> Label:
	var line := row(parent)
	line.add_theme_constant_override("separation", 10)
	var rule := ColorRect.new()
	rule.color = UiStyle.B_CORAL
	rule.custom_minimum_size = Vector2(3, 0)
	rule.size_flags_vertical = Control.SIZE_FILL
	line.add_child(rule)
	var l := label(line, text, font_size)
	l.add_theme_font_override("font", UiStyle.bold(800))
	return l


## A progress bar as a game meter: an ink-rimmed track, the fill coral,
## gold once full. `w` 0 stretches it to its row.
func _bar(have: int, total: int, w := 0.0) -> Control:
	var c := Control.new()
	c.name = "Meter"
	c.custom_minimum_size = Vector2(w, 10)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if w == 0.0:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var done := have >= total
	var f := clampf(float(have) / maxf(1.0, float(total)), 0.0, 1.0)
	c.draw.connect(func():
		var s := c.size
		c.draw_rect(Rect2(Vector2(2, 2), s - Vector2(2, 2)), Color(UiStyle.B_INK, 0.9))
		c.draw_rect(Rect2(Vector2.ZERO, s - Vector2(2, 2)), Color(UiStyle.B_INK, 0.08))
		if f > 0.0:
			c.draw_rect(Rect2(Vector2.ZERO, Vector2((s.x - 2) * f, s.y - 2)), UiStyle.B_GOLD if done else UiStyle.B_CORAL)
		c.draw_rect(Rect2(Vector2.ZERO, s - Vector2(2, 2)), UiStyle.B_INK, false, 1.5))
	return c


func _set_by_id(sid: int) -> Dictionary:
	for st in data("localCoach.cardSets", []):
		if st is Dictionary and int(st.get("id", 0)) == sid:
			return st
	return {}


# ------------------------------------------------------------------ sets

func _sets() -> void:
	var sets: Array = data("localCoach.cardSets", [])
	var show := str(draft.get("set_show", "started"))
	var counts := {"started": sets.filter(func(s): return int(s.completion) > 0).size(),
		"done": sets.filter(func(s): return int(s.completion) >= int(s.size)).size(),
		"all": sets.size()}
	var rows := _slab(I18n.t("inv.sets_show"), 3)
	for k in ["started", "done", "all"]:
		var b := _kind_row(I18n.t("inv.sets_%s" % k), int(counts[k]), k == show)
		b.name = "SetShow_" + k
		var kk: String = k
		b.pressed.connect(func():
			draft["set_show"] = kk
			selected = {}
			schedule_refresh())
		rows.add_child(b)
	_search("set_search", I18n.t("inv.search_sets_ph"))
	match show:
		"started": sets = sets.filter(func(s): return int(s.completion) > 0)
		"done": sets = sets.filter(func(s): return int(s.completion) >= int(s.size))
	var needle := str(draft.get("set_search", "")).strip_edges().to_lower()
	if needle != "":
		sets = sets.filter(func(s): return str(s.get("name", "")).to_lower().contains(needle))
	# the closest to finished first
	sets.sort_custom(func(a, b):
		var fa := float(a.completion) / maxf(1.0, float(a.size))
		var fb := float(b.completion) / maxf(1.0, float(b.size))
		return fa > fb if fa != fb else str(a.name) < str(b.name))
	var list := VBoxContainer.new()
	list.name = "Album"
	list.custom_minimum_size = Vector2(GRID.size.x - 14, 0)
	list.add_theme_constant_override("separation", 12)
	_center.add_child(list)
	if sets.is_empty():
		_hint(list, I18n.t("inv.sets_none"))
	for st in sets:
		list.add_child(_set_strip(st))
	_set_sheet()


## One collection as a slab: its name and progress (a gold sparkle once
## complete), its meter, then its cards small (the ones you lack faded).
## Coral-rimmed when picked, a thin coral rim under the pointer.
func _set_strip(st: Dictionary) -> Control:
	var b := Button.new()
	b.name = "Set%d" % int(st.get("id", 0))
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	var picked := int(selected.get("id", -1)) == int(st.get("id", 0))
	b.set_pressed_no_signal(picked)
	for s in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var have := int(st.get("completion", 0))
	var total := int(st.get("size", 0))
	var done := have >= total
	b.draw.connect(func():
		var s := b.size - Vector2(6, 6)
		var lit := b.is_hovered() or b.has_focus()
		if picked:
			for i in 3:
				b.draw_rect(Rect2(Vector2(-10 + i * 3, -10 + i * 3), s + Vector2(20 - i * 6, 20 - i * 6)), Color(UiStyle.B_GOLD, 0.14))
		var face := StyleB.draw_slab(b, s, SLAB_CUT)
		if picked or lit:
			var loop := face.duplicate()
			loop.append(face[0])
			b.draw_polyline(loop, UiStyle.B_CORAL, 3.5 if picked else 2.5, true)
		if done:
			StyleB.sparkle(b, Vector2(s.x - 22, 20), 7.0, UiStyle.B_GOLD))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(14, 10)
	col.add_theme_constant_override("separation", 6)
	b.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.custom_minimum_size = Vector2(GRID.size.x - 14 - 6 - 28, 0)
	col.add_child(head)
	var nm := Label.new()
	nm.text = str(st.get("name", ""))
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.display(nm, 20)
	head.add_child(nm)
	var prog := Label.new()
	prog.text = "%d / %d" % [have, total]
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.display(prog, 20, UiStyle.B_GOLD if done else UiStyle.B_CORAL if have > 0 else UiStyle.B_MUTE)
	head.add_child(prog)
	if done:   # room for the sparkle
		var pad := Control.new()
		pad.custom_minimum_size = Vector2(26, 0)
		pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(pad)
	col.add_child(_bar(have, total, GRID.size.x - 14 - 6 - 28))
	var row_c := HFlowContainer.new()
	row_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_c.custom_minimum_size = Vector2(GRID.size.x - 14 - 6 - 28, 0)
	row_c.add_theme_constant_override("h_separation", 4)
	row_c.add_theme_constant_override("v_separation", 4)
	col.add_child(row_c)
	for c in st.get("collection", []):
		var cid := int(c.get("id", 0))
		var face := CardFace.make(cid, MINI)
		face.custom_minimum_size = MINI
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(c.get("quantity", c.get("owned", 0))) <= 0 and not _owned(cid):
			face.modulate = Color(1, 1, 1, 0.28)
		row_c.add_child(face)
	var rows := ceili(float(st.get("collection", []).size()) / 9.0)
	b.custom_minimum_size = Vector2(GRID.size.x - 14, 74 + rows * (MINI.y + 4))
	var item: Dictionary = st
	b.pressed.connect(func():
		selected = item
		schedule_refresh())
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
		sig.connect(b.queue_redraw)
	return b


func _owned(cid: int) -> bool:
	for it in _items():
		if int(it.get("id", -1)) == cid and int(it.get("quantity", 0)) > 0:
			return true
	return false


func _set_sheet() -> void:
	sheet_tag.text = I18n.t("inv.set_tag").to_upper()
	var pick := int(selected.get("id", -1))
	if pick != _last_pick:
		_last_pick = pick
		sheet_scroll.scroll_vertical = 0
	if selected.is_empty():
		sheet_title.text = I18n.t("inv.sets")
		_fit_title()
		_hint(body, I18n.t("inv.set_pick_hint"))
		return
	sheet_title.text = str(selected.get("name", ""))
	_fit_title()
	var have := int(selected.get("completion", 0))
	var of := int(selected.get("size", 0))
	var pl := label(body, I18n.t("inv.set_progress", {"have": have, "of": of}), 16)
	pl.add_theme_font_override("font", UiStyle.bold(800))
	body.add_child(_bar(have, of))
	var bonuses := CardText.set_lines(pick)
	if not bonuses.is_empty():
		body.add_child(UiStyle.caption(I18n.t("inv.set_bonuses")))
		var bt := _ruled(body, "\n".join(bonuses), 15)
		bt.name = "SetBonuses"
	var missing: Array = []
	for c in selected.get("collection", []):
		if not _owned(int(c.get("id", 0))):
			missing.append(str(c.get("name", Cards.name_of(int(c.get("id", 0))))))
	if missing.is_empty():
		var ok := Label.new()
		UiStyle.display(ok, 22, UiStyle.B_GOLD)
		ok.text = I18n.t("inv.set_complete")
		body.add_child(ok)
	else:
		body.add_child(UiStyle.caption(I18n.t("inv.set_missing", {"n": missing.size()})))
		var ml := label(body, " · ".join(missing), 14)
		ml.name = "SetMissing"
		ml.add_theme_font_override("font", UiStyle.bold(800))
		ml.add_theme_color_override("font_color", UiStyle.BROWN)
