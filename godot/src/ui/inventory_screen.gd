extends "res://src/ui/hero_panel.gd"
## Inventario (S47, owner point 12: "rework grande de Inventario /
## Colecciones"): a screen of its own instead of the modal.
##
## Cartas: on the left what the cards are FOR, each with how many you have
## (Todo, Equipo del coach, Consumibles, Cosméticos, Combate, Fusión,
## Reliquias, Arenas, Otras), the search and the order, and "Equipo del
## coach"; in the middle the cards; on the paper at the right the picked
## card large — what it does, what it is for, its collection (how many of
## it you hold), copies and value, and "Ponérsela" for coach gear.
## Colecciones: an album, every collection a strip of its cards (the ones
## you lack greyed) with its progress; the picked one's bonuses and what is
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

var _left: VBoxContainer
var _tabs_box: HBoxContainer
var _center: ScrollContainer
var _built := false


func _ready() -> void:
	panel_name = "cardBookDialog"
	super._ready()
	_tabs_box = HBoxContainer.new()
	_tabs_box.name = "InvTabs"
	_tabs_box.position = Vector2(560, 34)
	_tabs_box.add_theme_constant_override("separation", 8)
	stage.add_child(_tabs_box)
	_left = VBoxContainer.new()
	_left.name = "Kinds"
	_left.position = Vector2(28, 100)
	_left.custom_minimum_size = Vector2(272, 0)
	_left.add_theme_constant_override("separation", 6)
	stage.add_child(_left)
	_center = ScrollContainer.new()
	_center.name = "Center"
	_center.position = GRID.position
	_center.size = GRID.size
	_center.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stage.add_child(_center)
	_built = true
	refresh()


func hero_word() -> String:
	return "CARDS"


func hero_tag() -> String:
	return "INVENTORY"


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


# ------------------------------------------------------------------ cards

func _items() -> Array:
	var v: Variant = data("localCoach.cardInventory", [])
	return v if v is Array else []


func _kind_of(it: Dictionary) -> String:
	return Panels._inv_kind(int(it.get("cardType", 0)))


func _cards() -> void:
	var all := _items()
	var kind := str(draft.get("inv_kind", "all"))
	# the left column: what the cards are for, with how many
	_left.add_child(UiStyle.caption(I18n.t("inv.for_what")))
	for k in KINDS:
		var n := all.size() if k == "all" else all.filter(func(it): return _kind_of(it) == k).size()
		if n == 0 and k != "all":
			continue
		var b := _kind_button("%s  ·  %d" % [I18n.t("inv.kind_%s" % k), n], k == kind)
		b.name = "Kind_" + k
		var kk: String = k
		b.pressed.connect(func():
			draft["inv_kind"] = kk
			selected = {}
			schedule_refresh())
		_left.add_child(b)
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = I18n.t("inv.search_ph")
	search.text = str(draft.get("search", ""))
	search.custom_minimum_size = Vector2(272, 40)
	StyleB.field(search, 16)
	search.text_changed.connect(func(t):
		draft["search"] = t
		schedule_refresh())
	_left.add_child(search)
	var sort_pick := int(draft.get("sort", 0))
	var sort := OptionButton.new()
	sort.name = "SortPick"
	for k in SORTS:
		sort.add_item(I18n.t("inv.sort_%s" % k))
	sort.select(sort_pick)
	sort.custom_minimum_size = Vector2(272, 38)
	sort.item_selected.connect(func(i):
		draft["sort"] = i
		schedule_refresh())
	_left.add_child(sort)
	var eq := StyleB.button(false, 16)
	eq.name = "CoachEquip"
	eq.text = I18n.t("inv.coach_equip")
	eq.custom_minimum_size = Vector2(272, 44)
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


func _kind_button(text: String, on: bool) -> Button:
	var b := StyleB.button(on, 16)
	b.text = text
	b.custom_minimum_size = Vector2(272, 40)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return b


## The paper: the picked card large and what it is.
func _card_sheet(items: Array, pick: int) -> void:
	sheet_tag.text = I18n.t("inv.card_tag").to_upper()
	if selected.is_empty() or not items.any(func(i): return int(i.get("id", -2)) == pick):
		sheet_title.text = I18n.t("panel.inventory")
		_muted(body, I18n.t("inv.pick_hint"))
		return
	sheet_title.text = str(selected.get("name", ""))
	var head := row(body)
	head.add_child(_framed_art(pick, Vector2(140, 168)))
	var facts := column(head)
	var nm := label(facts, str(selected.get("name", "")), 20)
	nm.name = "CardName"
	var kind := _kind_of(selected)
	var what := label(facts, I18n.t("inv.kind_%s" % kind), 16)
	what.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
	label(facts, "×%d · %s" % [int(selected.get("quantity", 0)),
		I18n.t("inv.value_n", {"n": int(selected.get("value", 0))})], 15)
	var fx := CardText.card_lines(pick)
	if not fx.is_empty() or kind == "coach":
		var fx_l := label(body, "\n".join(fx) if not fx.is_empty() else I18n.t("inv.no_effects"), 15)
		fx_l.name = "CardEffects"
	var use := label(body, I18n.t("inv.use_%s" % kind), 15)
	use.name = "CardUse"
	use.add_theme_color_override("font_color", UiStyle.BROWN)
	# its collection, and how much of it you hold
	var sid := int(Cards.meta(pick).get("set", 0))
	var st := _set_by_id(sid)
	if not st.is_empty():
		var sl := label(body, I18n.t("inv.in_set", {"name": str(st.get("name", "")),
			"have": int(st.get("completion", 0)), "of": int(st.get("size", 0))}), 15)
		sl.name = "CardSet"
	if kind == "coach":
		var on := StyleB.button(true, 18)
		on.name = "WearIt"
		on.text = I18n.t("inv.wear_it")
		on.custom_minimum_size = Vector2(0, 46)
		on.pressed.connect(func(): send("nativeEquipOpen"))
		body.add_child(on)


func _set_by_id(sid: int) -> Dictionary:
	for st in data("localCoach.cardSets", []):
		if st is Dictionary and int(st.get("id", 0)) == sid:
			return st
	return {}


# ------------------------------------------------------------------ sets

func _sets() -> void:
	var sets: Array = data("localCoach.cardSets", [])
	var show := str(draft.get("set_show", "started"))
	_left.add_child(UiStyle.caption(I18n.t("inv.sets_show")))
	var counts := {"started": sets.filter(func(s): return int(s.completion) > 0).size(),
		"done": sets.filter(func(s): return int(s.completion) >= int(s.size)).size(),
		"all": sets.size()}
	for k in ["started", "done", "all"]:
		var b := _kind_button("%s  ·  %d" % [I18n.t("inv.sets_%s" % k), counts[k]], k == show)
		b.name = "SetShow_" + k
		var kk: String = k
		b.pressed.connect(func():
			draft["set_show"] = kk
			selected = {}
			schedule_refresh())
		_left.add_child(b)
	var search := LineEdit.new()
	search.name = "Search"
	search.placeholder_text = I18n.t("inv.search_sets_ph")
	search.text = str(draft.get("set_search", ""))
	search.custom_minimum_size = Vector2(272, 40)
	StyleB.field(search, 16)
	search.text_changed.connect(func(t):
		draft["set_search"] = t
		schedule_refresh())
	_left.add_child(search)
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
	list.add_theme_constant_override("separation", 8)
	_center.add_child(list)
	if sets.is_empty():
		_muted(list, I18n.t("inv.sets_none"))
	for st in sets:
		list.add_child(_set_strip(st))
	_set_sheet()


## One collection as a strip: its name and progress, then its cards small
## (the ones you lack faded).
func _set_strip(st: Dictionary) -> Control:
	var b := Button.new()
	b.name = "Set%d" % int(st.get("id", 0))
	b.toggle_mode = true
	b.button_pressed = int(selected.get("id", -1)) == int(st.get("id", 0))
	b.focus_mode = Control.FOCUS_ALL
	var picked := b.button_pressed
	for s in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color.WHITE
		sb.border_color = UiStyle.B_CORAL if picked or s.begins_with("hover") else UiStyle.B_INK
		sb.set_border_width_all(3 if picked else 2)
		b.add_theme_stylebox_override(s, sb)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.position = Vector2(12, 8)
	col.add_theme_constant_override("separation", 4)
	b.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var nm := Label.new()
	nm.text = str(st.get("name", ""))
	nm.custom_minimum_size = Vector2(300, 0)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiStyle.display(nm, 18)
	head.add_child(nm)
	var have := int(st.get("completion", 0))
	var total := int(st.get("size", 0))
	var prog := Label.new()
	prog.text = "%d / %d" % [have, total]
	prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prog.add_theme_color_override("font_color", UiStyle.B_CORAL if have >= total else UiStyle.B_MUTE)
	prog.add_theme_font_override("font", UiStyle.bold(900))
	head.add_child(prog)
	var bar := ProgressBar.new()
	bar.max_value = maxf(1.0, total)
	bar.value = have
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(440, 6)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiStyle.B_CORAL
	var back := StyleBoxFlat.new()
	back.bg_color = Color(UiStyle.B_INK, 0.12)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", back)
	col.add_child(bar)
	var row_c := HFlowContainer.new()
	row_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_c.custom_minimum_size = Vector2(440, 0)
	row_c.add_theme_constant_override("h_separation", 4)
	row_c.add_theme_constant_override("v_separation", 4)
	col.add_child(row_c)
	for c in st.get("collection", []):
		var cid := int(c.get("id", 0))
		var face := CardFace.make(cid, MINI)
		face.custom_minimum_size = MINI
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if int(c.get("quantity", c.get("owned", 0))) <= 0 and not _owned(cid):
			face.modulate = Color(1, 1, 1, 0.25)
		row_c.add_child(face)
	var rows := ceili(float(st.get("collection", []).size()) / 9.0)
	b.custom_minimum_size = Vector2(GRID.size.x - 14, 60 + rows * (MINI.y + 4))
	var item: Dictionary = st
	b.pressed.connect(func():
		selected = item
		schedule_refresh())
	return b


func _owned(cid: int) -> bool:
	for it in _items():
		if int(it.get("id", -1)) == cid and int(it.get("quantity", 0)) > 0:
			return true
	return false


func _set_sheet() -> void:
	sheet_tag.text = I18n.t("inv.set_tag").to_upper()
	if selected.is_empty():
		sheet_title.text = I18n.t("inv.sets")
		_muted(body, I18n.t("inv.set_pick_hint"))
		return
	sheet_title.text = str(selected.get("name", ""))
	label(body, I18n.t("inv.set_progress", {"have": int(selected.get("completion", 0)),
		"of": int(selected.get("size", 0))}), 16)
	var bonuses := CardText.set_lines(int(selected.get("id", 0)))
	if not bonuses.is_empty():
		body.add_child(UiStyle.caption(I18n.t("inv.set_bonuses")))
		var bt := label(body, "\n".join(bonuses), 15)
		bt.name = "SetBonuses"
	var missing: Array = []
	for c in selected.get("collection", []):
		if not _owned(int(c.get("id", 0))):
			missing.append(str(c.get("name", Cards.name_of(int(c.get("id", 0))))))
	if missing.is_empty():
		label(body, I18n.t("inv.set_complete"), 16).add_theme_color_override("font_color", UiStyle.B_CORAL)
	else:
		body.add_child(UiStyle.caption(I18n.t("inv.set_missing", {"n": missing.size()})))
		var ml := label(body, " · ".join(missing), 14)
		ml.name = "SetMissing"
		ml.add_theme_color_override("font_color", UiStyle.BROWN)
