extends "res://src/ui/lobby_panel.gd"
## The native Card Master (S18, tanda 2): replaces the retail XML
## cardMasterDialog. A grid of the master's set on the left, the chosen card
## on the right; buying with tokens when the card has a price, and the
## retail barter (give cards whose summed value covers the wanted one) in
## the same window. Reads `cardMasterTrade` (main.gd _push_cardmaster_model)
## and asks main.gd for every change through `nativeCm*` events — the wire
## stays in main.gd. Sketch: codigo/capturas/s18/opciones-cardmaster.png, B.

const ART_DIRS := ["gui/images/equipments/coachs/illustrations/",
	"gui/images/equipments/fighters/illustrations/"]
const TILE := Vector2(150, 180)
const COLUMNS := 4

static var _art_cache := {}   # card id -> Texture2D (null when missing)
static var _token_cache := {}

var bartering := false
var _wallet_box: HBoxContainer
var _grid_scroll: ScrollContainer
var _grid_mode := false   # the mode _grid_scroll was built for


func _ready() -> void:
	panel_name = "cardMasterDialog"
	super._ready()
	# Wallet beside the close button, like the sketch.
	_wallet_box = HBoxContainer.new()
	_wallet_box.add_theme_constant_override("separation", 14)
	var header := close_button.get_parent()
	header.add_child(_wallet_box)
	header.move_child(_wallet_box, close_button.get_index())
	_fill_wallet()


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "cardMasterTrade":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null:
		return
	# Every click rebuilds the window: keep the grid's scroll and the focused
	# control, or a click low in a long list jumps back to the top.
	var keep_scroll := 0
	if is_instance_valid(_grid_scroll) and _grid_mode == bartering:
		keep_scroll = _grid_scroll.scroll_vertical
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var keep_focus := String(focused.name) \
		if focused != null and frame.is_ancestor_of(focused) else ""
	_grid_scroll = null
	_grid_mode = bartering
	clear_body()
	var set_name := str(data("cardMasterTrade.setName", ""))
	title.text = I18n.t("cm.title_set", {"set": set_name}) if set_name != "" \
		else I18n.t("shop.title")
	_fill_wallet()
	var split := row(body)
	split.add_theme_constant_override("separation", 28)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	split.add_child(left)
	var right := column(split)
	if bartering:
		_offer_grid(left)
		_barter_side(right)
	else:
		_catalog_grid(left)
		_detail_side(right)
	# room for the primary button's hard shadow: the body scroll clips it
	var foot := Control.new()
	foot.custom_minimum_size.y = 6
	body.add_child(foot)
	_restore(keep_scroll, keep_focus)


func _restore(scroll: int, focus_name: String) -> void:
	await get_tree().process_frame   # the scroll range exists after sorting
	if is_instance_valid(_grid_scroll):
		_grid_scroll.scroll_vertical = scroll
	if focus_name != "":
		var target := frame.find_child(focus_name, true, false) as Control
		if target != null and target.is_visible_in_tree() \
				and target.focus_mode != Control.FOCUS_NONE \
				and not (target is BaseButton and target.disabled):
			target.grab_focus()


# --- left: the grids ---------------------------------------------------------

func _grid(parent: Node) -> GridContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(
		COLUMNS * TILE.x + (COLUMNS - 1) * 12 + 18, 2 * TILE.y + 12 + 8)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	_grid_scroll = scroll
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	# room for the selected tile's hard shadow
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_right", 8)
	pad.add_theme_constant_override("margin_bottom", 8)
	pad.add_child(grid)
	scroll.add_child(pad)
	return grid


func _catalog_grid(parent: Node) -> void:
	var items: Array = data("cardMasterTrade.catalog", [])
	if items.is_empty():
		label(parent, I18n.t("common.empty"))
		return
	var grid := _grid(parent)
	var sel := int(data("cardMasterTrade.selectedId", -1))
	for item in items:
		var cid := int(item.get("id", 0))
		var owned := int(item.get("owned", 0))
		var t := _tile(grid, item, cid == sel,
			I18n.t("cm.qty", {"n": owned}) if owned > 0 else "",
			I18n.t("cm.value", {"v": int(item.get("value", 0))}))
		t.name = "Card%d" % cid
		t.pressed.connect(func(): send("nativeCmSelect", [cid]))


func _offer_grid(parent: Node) -> void:
	parent.add_child(OneBit.caption(I18n.t("cm.offer_title")))
	var items: Array = data("cardMasterTrade.offer", [])
	if items.is_empty():
		var l := label(parent, I18n.t("cm.no_offer"))
		l.custom_minimum_size.x = COLUMNS * TILE.x + (COLUMNS - 1) * 12 + 18
		return
	var grid := _grid(parent)
	for item in items:
		var cid := int(item.get("id", 0))
		var left_n := int(item.get("owned", 0)) - int(item.get("staged", 0))
		var badge := I18n.t("cm.qty", {"n": left_n})
		var t := _tile(grid, item, int(item.get("staged", 0)) > 0, badge,
			I18n.t("cm.value", {"v": int(item.get("value", 0))}))
		t.name = "Offer%d" % cid
		t.disabled = left_n <= 0
		t.pressed.connect(func(): send("nativeCmStage", [cid]))


## One card: art, name and an optional value line; a badge (copies) top
## right. Selected = thick border plus the hard white shadow.
func _tile(parent: Node, item: Dictionary, chosen: bool, badge := "",
		sub := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_ALL
	var normal := OneBit.box(OneBit.PAPER, OneBit.INK, 4 if chosen else 2, 6)
	if chosen:
		normal.shadow_color = OneBit.INK
		normal.shadow_size = 1
		normal.shadow_offset = Vector2(6, 6)
	var hover := normal.duplicate()
	hover.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("disabled", OneBit.box(OneBit.PAPER, OneBit.MUTED, 1, 6))
	b.add_theme_stylebox_override("focus", OneBit.focus_ring())
	parent.add_child(b)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 8
	col.offset_right = -8
	col.offset_top = 10
	col.offset_bottom = -8
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)
	var art := _art(int(item.get("id", 0)), Vector2(TILE.x - 16, 100))
	col.add_child(art)
	var name_l := _small(col, str(item.get("name", "")), 13)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if sub != "":
		var s := _small(col, sub, 12)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_color_override("font_color", OneBit.MUTED)
	if badge != "":
		var tag := Label.new()
		tag.text = badge
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", OneBit.PAPER)
		tag.add_theme_stylebox_override("normal", OneBit.box(OneBit.INK, OneBit.INK, 0, 3))
		tag.position = Vector2(TILE.x - 44, 4)
		tag.size = Vector2(40, 18)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
	return b


# --- right: detail of the chosen card, and the barter tray -------------------

func _detail_side(side: VBoxContainer) -> void:
	var sel := int(data("cardMasterTrade.selectedId", -1))
	var item := _catalog_item(sel)
	if item.is_empty():
		label(side, I18n.t("cm.pick"))
		return
	side.add_child(_framed_art(sel, Vector2(300, 224)))
	var name_l := label(side, str(item.get("name", "")), 22)
	name_l.add_theme_font_override("font", OneBit.title_font())
	var facts := VBoxContainer.new()
	facts.add_theme_constant_override("separation", 4)
	side.add_child(facts)
	_muted(facts, I18n.t("cm.value", {"v": int(item.get("value", 0))}))
	var price: Array = item.get("price", [])
	if price.is_empty():
		_muted(facts, I18n.t("cm.barter_only"))
	else:
		var p := HBoxContainer.new()
		p.add_theme_constant_override("separation", 6)
		facts.add_child(p)
		_muted(p, I18n.t("cm.price"))
		for c in price:
			_amount(p, int(c.get("type", 1)), int(c.get("amount", 0)), 16)
	_muted(facts, I18n.t("cm.owned", {"n": int(item.get("owned", 0))}))
	if bool(item.get("uniqueOwned", false)):
		_muted(facts, I18n.t("cm.unique_owned"))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(spacer)
	_status(side)
	var actions := row(side)
	actions.add_theme_constant_override("separation", 16)
	var barter_btn := Button.new()
	barter_btn.text = I18n.t("cm.barter")
	barter_btn.name = "Barter"
	barter_btn.disabled = bool(item.get("uniqueOwned", false))
	barter_btn.pressed.connect(func():
		bartering = true
		schedule_refresh())
	if price.is_empty():
		# Barter-only (most retail sets): barter is the screen's action.
		OneBit.primary(barter_btn, 20)
		barter_btn.custom_minimum_size = Vector2(200, 54)
		actions.add_child(barter_btn)
		return
	var buy := Button.new()
	buy.name = "Buy"
	buy.text = I18n.t("cm.buy")
	buy.custom_minimum_size = Vector2(170, 54)
	buy.disabled = not bool(item.get("canBuyTokens", false))
	OneBit.primary(buy, 20)
	buy.pressed.connect(func(): send("nativeCmBuy"))
	actions.add_child(buy)
	barter_btn.custom_minimum_size = Vector2(150, 46)
	barter_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_child(barter_btn)


func _barter_side(side: VBoxContainer) -> void:
	var sel := int(data("cardMasterTrade.selectedId", -1))
	var item := _catalog_item(sel)
	side.add_child(OneBit.caption(I18n.t("cm.wanted")))
	var head := row(side)
	head.add_child(_framed_art(sel, Vector2(150, 112)))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(info)
	var name_l := label(info, str(item.get("name", "")), 18)
	name_l.add_theme_font_override("font", OneBit.title_font())
	_muted(info, I18n.t("cm.value", {"v": int(item.get("value", 0))}))
	var offered := int(data("cardMasterTrade.offered", 0))
	var wanted := int(data("cardMasterTrade.wanted", 0))
	label(side, I18n.t("cm.offered", {"a": offered, "b": wanted}), 17)
	side.add_child(_meter(offered, wanted))
	var staged: Array = data("cardMasterTrade.staged", [])
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(list)
	if staged.is_empty():
		var hint := label(list, I18n.t("cm.offer_hint"), 16)
		hint.add_theme_color_override("font_color", OneBit.MUTED)
	for s in staged:
		var cid := int(s.get("id", 0))
		var b := Button.new()
		b.name = "Staged%d" % cid
		b.text = "%s  ×%d   ✕" % [str(s.get("name", "")), int(s.get("count", 0))]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.tooltip_text = I18n.t("cm.unstage")
		b.pressed.connect(func(): send("nativeCmUnstage", [cid]))
		list.add_child(b)
	_status(side)
	var actions := row(side)
	actions.add_theme_constant_override("separation", 16)
	var trade := Button.new()
	trade.name = "Trade"
	trade.text = I18n.t("cm.trade")
	trade.custom_minimum_size = Vector2(200, 54)
	trade.disabled = not bool(data("cardMasterTrade.canBuyCards", false))
	OneBit.primary(trade, 20)
	trade.pressed.connect(func(): send("nativeCmBarter"))
	actions.add_child(trade)
	var back := Button.new()
	back.name = "Back"
	back.text = I18n.t("cm.back")
	back.custom_minimum_size = Vector2(120, 46)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func():
		bartering = false
		send("nativeCmClear"))
	actions.add_child(back)


## Offered vs wanted value: a white bar in a white-ruled box; no grey.
func _meter(have: int, need: int) -> Control:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(0, 16)
	box.add_theme_stylebox_override("panel", OneBit.box(OneBit.PAPER, OneBit.INK, 2, 0))
	var fill := ColorRect.new()
	fill.color = OneBit.INK
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(have) / maxf(1.0, float(need)), 0.0, 1.0)
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_bottom = -4
	fill.offset_right = -4 if fill.anchor_right >= 1.0 else 0
	box.add_child(fill)
	return box


func _status(parent: Node) -> void:
	var text := str(data("cardMasterTrade.status", ""))
	if text == "":
		return
	var l := label(parent, text, 15)
	l.name = "Status"
	if not bool(data("cardMasterTrade.statusOk", false)):
		l.add_theme_color_override("font_color", OneBit.MUTED)


# --- small pieces ------------------------------------------------------------

func _catalog_item(cid: int) -> Dictionary:
	for item in data("cardMasterTrade.catalog", []):
		if int(item.get("id", 0)) == cid:
			return item
	return {}


func _fill_wallet() -> void:
	if _wallet_box == null:
		return
	for c in _wallet_box.get_children():
		c.queue_free()
	for c in data("cardMasterTrade.wallet", []):
		_amount(_wallet_box, int(c.get("type", 1)), int(c.get("amount", 0)), 18)


## "300 ◉": an amount and its token's icon.
func _amount(parent: Node, type: int, amount: int, font_size: int) -> void:
	var l := _small(parent, _thousands(amount), font_size)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tex: Texture2D = _token(type)
	if tex == null:
		l.text += " t%d" % type
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(font_size + 6, font_size + 6)
	icon.material = OneBit.art_material()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _small(parent: Node, text: String, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _muted(parent: Node, text: String) -> Label:
	var l := _small(parent, text, 16)
	l.add_theme_color_override("font_color", OneBit.MUTED)
	return l


## The big art, in a box with the hard shadow, like the selected tile.
func _framed_art(cid: int, size: Vector2) -> Control:
	var frame_box := PanelContainer.new()
	var st := OneBit.box(OneBit.PAPER, OneBit.INK, 3, 8)
	st.shadow_color = OneBit.INK
	st.shadow_size = 1
	st.shadow_offset = Vector2(6, 6)
	frame_box.add_theme_stylebox_override("panel", st)
	frame_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame_box.add_child(_art(cid, size))
	return frame_box


func _art(cid: int, size: Vector2) -> Control:
	var tr := TextureRect.new()
	tr.texture = _card_art(cid)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.material = OneBit.art_material()
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _card_art(cid: int) -> Texture2D:
	if _art_cache.has(cid):
		return _art_cache[cid]
	var tex: Texture2D = null
	for dir in ART_DIRS:
		var img := AssetPaths.load_image(dir + "%d.png" % cid)
		if img != null:
			tex = ImageTexture.create_from_image(img)
			break
	_art_cache[cid] = tex
	return tex


static func _token(type: int) -> Texture2D:
	if not _token_cache.has(type):
		var img := AssetPaths.load_image("gui/images/tokens/icons/%d.png" % type)
		_token_cache[type] = ImageTexture.create_from_image(img) if img != null else null
	return _token_cache[type]
