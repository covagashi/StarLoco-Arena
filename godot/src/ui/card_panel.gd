extends "res://src/ui/lobby_panel.gd"
## Shared pieces for the native panels that show game cards (S18): the Card
## Master, the fusion altar and whatever comes next. A card tile with its art,
## the big framed art, token amounts, small and muted
## text, and the have/need meter. Nothing here touches the wire or a model
## field; the panels decide what each piece means.

const TILE := Vector2(150, 180)

static var _token_cache := {}


## One card: art, name and an optional value line; a badge (copies) top
## right. Selected = a thick gold rim.
func _tile(parent: Node, item: Dictionary, chosen: bool, badge := "",
		sub := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_ALL
	var normal := UiStyle.box(UiStyle.PAPER, UiStyle.INK, 4 if chosen else 2, 6)
	if chosen:
		normal.border_color = UiStyle.RIM_HI
	var hover := normal.duplicate()
	hover.set_border_width_all(4)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("disabled", UiStyle.box(UiStyle.PAPER, UiStyle.MUTED, 1, 6))
	b.add_theme_stylebox_override("focus", UiStyle.focus_ring())
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
	if bool(item.get("fighter", false)):   # fighter equipment: its own art (S22)
		(art as TextureRect).texture = UiStyle.fighter_card_art(int(item.get("id", 0)))
	col.add_child(art)
	var name_l := _small(col, str(item.get("name", "")), 13)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if sub != "":
		var s := _small(col, sub, 12)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s.add_theme_color_override("font_color", UiStyle.MUTED)
	if badge != "":
		var tag := Label.new()
		tag.text = badge
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", UiStyle.PAPER)
		tag.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.INK, UiStyle.INK, 0, 3))
		tag.position = Vector2(TILE.x - 44, 4)
		tag.size = Vector2(40, 18)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
	return b


## A have/need bar (offered vs wanted value, power vs cost…): white fill in
## a white-ruled box; no grey.
func _meter(have: int, need: int) -> Control:
	var box := Panel.new()
	box.custom_minimum_size = Vector2(0, 16)
	box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PAPER, UiStyle.INK, 2, 0))
	var fill := ColorRect.new()
	fill.color = UiStyle.INK
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(float(have) / maxf(1.0, float(need)), 0.0, 1.0)
	fill.offset_left = 4
	fill.offset_top = 4
	fill.offset_bottom = -4
	fill.offset_right = -4 if fill.anchor_right >= 1.0 else 0
	box.add_child(fill)
	return box


## "300 ◉": an amount and its token's icon.
func _amount(parent: Node, type: int, amount: int, font_size: int) -> void:
	var l := _small(parent, _thousands(amount), font_size)
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tex: Texture2D = _token(type)
	if tex == null:
		# pesetas (type 10, S25) are ours: the retail client has no icon for them
		l.text += " " + (I18n.t("cur.pesetas") if type == 10 else "t%d" % type)
		return
	var icon := TextureRect.new()
	icon.texture = tex
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(font_size + 6, font_size + 6)
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
	l.add_theme_color_override("font_color", UiStyle.MUTED)
	return l


## The big art, in a box with the gold rim of the selected tile.
func _framed_art(cid: int, size: Vector2) -> Control:
	var frame_box := PanelContainer.new()
	var st := UiStyle.box(UiStyle.PAPER, UiStyle.INK, 3, 8)
	st.border_color = UiStyle.RIM_HI
	frame_box.add_theme_stylebox_override("panel", st)
	frame_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	frame_box.add_child(_art(cid, size))
	return frame_box


func _art(cid: int, size: Vector2) -> Control:
	var tr := TextureRect.new()
	tr.texture = UiStyle.card_art(cid)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


static func _token(type: int) -> Texture2D:
	if not _token_cache.has(type):
		var img := AssetPaths.load_image("gui/images/tokens/icons/%d.png" % type)
		_token_cache[type] = ImageTexture.create_from_image(img) if img != null else null
	return _token_cache[type]
