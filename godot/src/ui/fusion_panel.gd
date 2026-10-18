extends "res://src/ui/card_panel.gd"
## The native fusion altar (S18, tanda 2): replaces the retail XML
## fusionLabDialog. Your cards on the left, as a grid; on the right the
## strip of boost cards the altar can make, the chosen one with its recipe
## (power, quality, chance), what you have given so far and "Fusionar".
## Reads `fusionTrade` (main.gd _push_fusion_model: lab, targets, fuel,
## inputs, power, quality, chance, reason, status) and asks main.gd for
## every change through `nativeFus*` events — the wire (5490/5491) stays in
## main.gd. Same 1-bit rules as the Card Master: white interface, card art
## in dither.

const COLUMNS := 4

var _grid_scroll: ScrollContainer
var _lab_label: Label


func _ready() -> void:
	panel_name = "fusionLabDialog"
	super._ready()
	# The altar's numbers beside the close button, like the Card Master's
	# wallet: they are the altar's identity, not something to scroll past.
	_lab_label = Label.new()
	_lab_label.add_theme_font_size_override("font_size", 16)
	_lab_label.add_theme_color_override("font_color", OneBit.MUTED)
	var header := close_button.get_parent()
	header.add_child(_lab_label)
	header.move_child(_lab_label, close_button.get_index())
	_fill_lab()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "fusionTrade":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	var keep_scroll := 0
	if is_instance_valid(_grid_scroll):
		keep_scroll = _grid_scroll.scroll_vertical
	var keep_focus := remember_focus()
	_grid_scroll = null
	clear_body()
	title.text = I18n.t("fus.title")
	_fill_lab()
	var split := row(body)
	split.add_theme_constant_override("separation", 28)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	split.add_child(left)
	var right := column(split)
	_fuel_grid(left)
	_recipe_side(right)
	var foot := Control.new()   # room for the primary button's hard shadow
	foot.custom_minimum_size.y = 6
	body.add_child(foot)
	_restore(keep_scroll, keep_focus)


func _restore(scroll: int, focus_name: String) -> void:
	await get_tree().process_frame
	if is_instance_valid(_grid_scroll):
		_grid_scroll.scroll_vertical = scroll
	restore_focus(focus_name)


func _fill_lab() -> void:
	if _lab_label == null:
		return
	var lab: Dictionary = data("fusionTrade.lab", {})
	_lab_label.text = I18n.t("fus.altar", {"power": int(lab.get("power", 0)),
		"quality": int(lab.get("quality", 0)), "n": int(lab.get("slots", 0))})


# --- left: your cards --------------------------------------------------------

func _fuel_grid(parent: Node) -> void:
	parent.add_child(OneBit.caption(I18n.t("fus.fuel_title")))
	var items: Array = data("fusionTrade.fuel", [])
	var width := COLUMNS * TILE.x + (COLUMNS - 1) * 12 + 18
	if items.is_empty():
		var l := label(parent, I18n.t("fus.no_fuel"))
		l.custom_minimum_size.x = width
		return
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(width, 2 * TILE.y + 12 + 8)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	_grid_scroll = scroll
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var pad := MarginContainer.new()   # room for the chosen tile's hard shadow
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(grid)
	scroll.add_child(pad)
	var full := int(data("fusionTrade.inputCount", 0)) >= int(data("fusionTrade.slotCount", 0))
	for item in items:
		var cid := int(item.get("id", 0))
		var left_n := int(item.get("owned", 0)) - int(item.get("staged", 0))
		var t := _tile(grid, item, int(item.get("staged", 0)) > 0,
			I18n.t("cm.qty", {"n": left_n}), _fuel_sub(item))
		t.name = "Fuel%d" % cid
		t.disabled = left_n <= 0 or full
		t.pressed.connect(func(): send("nativeFusStage", [cid]))


## What a card brings to the altar: its level (power) and value, or the
## boost it carries when it is a boost card itself.
func _fuel_sub(item: Dictionary) -> String:
	var fp := int(item.get("fusPower", 0))
	var fq := int(item.get("fusQuality", 0))
	if fp > 0:
		return I18n.t("fus.boost_power", {"n": fp})
	if fq > 0:
		return I18n.t("fus.boost_quality", {"n": fq})
	return I18n.t("fus.fuel_sub", {"lvl": int(item.get("reqLevel", 0)),
		"v": int(item.get("value", 0))})


# --- right: what to make, the recipe, what you give ---------------------------

func _recipe_side(side: VBoxContainer) -> void:
	side.add_theme_constant_override("separation", 8)
	side.add_child(OneBit.caption(I18n.t("fus.targets")))
	_target_rows(side)
	var sel := int(data("fusionTrade.targetId", -1))
	var target := _target_item(sel)
	if target.is_empty():
		var pick := label(side, I18n.t("fus.pick_target"), 16)
		pick.add_theme_color_override("font_color", OneBit.MUTED)
	else:
		var head := row(side)
		head.add_child(_framed_art(sel, Vector2(100, 75)))
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(info)
		var name_l := label(info, str(target.get("name", "")), 18)
		name_l.add_theme_font_override("font", OneBit.title_font())
		_muted(info, "%s · %s" % [I18n.t("cm.value", {"v": int(target.get("value", 0))}),
			I18n.t("cm.owned", {"n": int(target.get("owned", 0))})])
		_recipe(side)
	var inputs: Array = data("fusionTrade.inputs", [])
	side.add_child(OneBit.caption("%s · %d/%d" % [I18n.t("fus.given"),
		int(data("fusionTrade.inputCount", 0)), int(data("fusionTrade.slotCount", 0))]))
	if inputs.is_empty() and str(data("fusionTrade.status", "")) == "":
		# the how-to, until there is a result to read instead
		var hint := label(side, I18n.t("fus.given_hint",
			{"n": int(data("fusionTrade.slotCount", 0))}), 15)
		hint.add_theme_color_override("font_color", OneBit.MUTED)
	else:
		# chips, several per line: the grid already shows them highlighted
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 8)
		flow.add_theme_constant_override("v_separation", 6)
		side.add_child(flow)
		for s in inputs:
			var cid := int(s.get("id", 0))
			var b := Button.new()
			b.name = "Staged%d" % cid
			b.text = "%s ×%d  ✕" % [str(s.get("name", "")), int(s.get("count", 0))]
			b.custom_minimum_size.y = 30
			b.add_theme_font_size_override("font_size", 14)
			b.tooltip_text = I18n.t("fus.unstage")
			b.pressed.connect(func(): send("nativeFusUnstage", [cid]))
			flow.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_status(side)
	var actions := row(side)
	actions.add_theme_constant_override("separation", 16)
	var fuse := Button.new()
	fuse.name = "Fuse"
	fuse.text = I18n.t("fus.fuse")
	fuse.custom_minimum_size = Vector2(200, 54)
	fuse.disabled = not bool(data("fusionTrade.canFusion", false))
	OneBit.primary(fuse, 20)
	fuse.pressed.connect(func(): send("nativeFusRequest"))
	actions.add_child(fuse)
	var clear := Button.new()
	clear.name = "Clear"
	clear.text = I18n.t("fus.clear")
	clear.custom_minimum_size = Vector2(120, 46)
	clear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	clear.disabled = inputs.is_empty()
	clear.pressed.connect(func(): send("nativeFusClear"))
	actions.add_child(clear)


## The boost cards the altar can make, one row per side they push: power
## (the rubies), quality (the sapphires), both (Potaras). A chip reads its
## boost ("+5"); the card's name and art come up in the detail. The 1-bit
## dither leaves 7 thumbnails all alike, the numbers are what you choose by.
func _target_rows(side: VBoxContainer) -> void:
	var groups := {"power": [], "quality": [], "both": []}
	for t in data("fusionTrade.targets", []):
		var fp := int(t.get("fusPower", 0))
		var fq := int(t.get("fusQuality", 0))
		groups["both" if fp > 0 and fq > 0 else "power" if fp > 0 else "quality"].append(t)
	var sel := int(data("fusionTrade.targetId", -1))
	for key in ["power", "quality", "both"]:
		if groups[key].is_empty():
			continue
		var r := row(side)
		r.add_theme_constant_override("separation", 8)
		var l := _small(r, I18n.t("fus." + key), 15)
		l.custom_minimum_size.x = 76
		l.add_theme_color_override("font_color", OneBit.MUTED)
		for t in groups[key]:
			var cid := int(t.get("id", 0))
			var fp := int(t.get("fusPower", 0))
			var fq := int(t.get("fusQuality", 0))
			var b := _chip(r, "+%d / +%d" % [fp, fq] if key == "both" \
				else "+%d" % (fp if key == "power" else fq), cid == sel)
			b.name = "Target%d" % cid
			b.tooltip_text = str(t.get("name", ""))
			b.pressed.connect(func(): send("nativeFusTarget", [cid]))


## Power and quality on one line each: name, bar, "have of need"; then the
## chance the altar gives you and the one rule still unmet (if any).
func _recipe(side: VBoxContainer) -> void:
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 4)
	side.add_child(facts)
	for key in ["power", "quality"]:
		var v: Dictionary = data("fusionTrade." + key, {})
		var r := row(facts)
		r.add_theme_constant_override("separation", 8)
		var l := _small(r, I18n.t("fus." + key), 15)
		l.name = key.capitalize()
		l.custom_minimum_size.x = 76
		var m := _meter(int(v.get("have", 0)), int(v.get("need", 0)))
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(m)
		var n := _small(r, I18n.t("fus.have_need", {"a": int(v.get("have", 0)),
			"b": int(v.get("need", 0))}), 15)
		n.custom_minimum_size.x = 70
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var chance := label(facts, I18n.t("fus.chance", {"p": int(data("fusionTrade.chance", 0))}), 16)
	chance.name = "Chance"
	var reason := str(data("fusionTrade.reason", ""))
	if reason != "" and reason != "fus.pick_target" and reason != "fus.need_two":
		var why := label(facts, I18n.t(reason), 15)
		why.name = "Reason"
		why.add_theme_color_override("font_color", OneBit.MUTED)


func _status(parent: Node) -> void:
	var text := str(data("fusionTrade.status", ""))
	if text == "":
		return
	var l := label(parent, text, 15)
	l.name = "Status"
	if not bool(data("fusionTrade.statusOk", false)):
		l.add_theme_color_override("font_color", OneBit.MUTED)


## A small text button; the chosen one gets the thick border and the hard
## shadow, like a chosen card tile.
func _chip(parent: Node, text: String, chosen: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(60, 28)
	b.add_theme_font_size_override("font_size", 15)
	var normal := OneBit.box(OneBit.PAPER, OneBit.INK, 4 if chosen else 2, 4)
	if chosen:
		normal.shadow_color = OneBit.INK
		normal.shadow_size = 1
		normal.shadow_offset = Vector2(4, 4)
	var hover := normal.duplicate()
	hover.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("focus", OneBit.focus_ring())
	parent.add_child(b)
	return b


func _target_item(cid: int) -> Dictionary:
	for item in data("fusionTrade.targets", []):
		if int(item.get("id", 0)) == cid:
			return item
	return {}
