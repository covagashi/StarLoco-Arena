extends "res://src/ui/lobby_panel.gd"
## Shared pieces for the native panels that show game cards (S18): the Card
## Master, the fusion altar and whatever comes next. A card tile with its art,
## the big framed art, token amounts, small and muted
## text, and the have/need meter. Nothing here touches the wire or a model
## field; the panels decide what each piece means.

const TILE := Vector2(150, 180)
const CardFace := preload("res://src/ui/card_face.gd")

## One card: art, name and an optional value line; a badge (copies) top
## right. Selected = a thick gold rim.
func _tile(parent: Node, item: Dictionary, chosen: bool, badge := "",
		sub := "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = TILE
	b.focus_mode = Control.FOCUS_ALL
	# S38b: the tile is the card (card_face.gd, the owner's template B); the
	# button only rings it — coral and thick when chosen, thin on hover
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.set_corner_radius_all(8)
	if chosen:
		normal.border_color = UiStyle.B_CORAL
		normal.set_border_width_all(3)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = UiStyle.B_CORAL
	hover.set_border_width_all(3 if chosen else 2)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("hover_pressed", hover)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", UiStyle.focus_ring())
	parent.add_child(b)
	var face := CardFace.make(int(item.get("id", 0)), TILE - Vector2(8, 8),
		bool(item.get("fighter", false)), str(item.get("name", "")), sub)
	face.name = "Face"
	face.position = Vector2(4, 4)
	face.size = TILE - Vector2(8, 8)
	b.add_child(face)
	# a disabled tile (a caller sets it after) fades its card; the button
	# redraws when that changes
	b.draw.connect(func(): face.modulate = Color(1, 1, 1, 0.45 if b.disabled else 1.0))
	# the name and the foot as (hidden) labels too: what the smokes and a
	# screen reader find on a tile
	var name_l := Label.new()
	name_l.name = "TileName"
	name_l.text = str(item.get("name", ""))
	name_l.visible = false
	b.add_child(name_l)
	if sub != "":
		var s := Label.new()
		s.name = "TileSub"
		s.text = sub
		s.visible = false
		b.add_child(s)
	if badge != "":
		var tag := Label.new()
		tag.text = badge
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_font_override("font", UiStyle.bold(900))
		tag.add_theme_color_override("font_color", Color.WHITE)
		var ts := StyleBoxFlat.new()
		ts.bg_color = UiStyle.B_INK
		ts.content_margin_left = 4
		ts.content_margin_right = 4
		tag.add_theme_stylebox_override("normal", ts)
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
	var rail := StyleBoxFlat.new()
	rail.bg_color = Color(UiStyle.B_INK, 0.1)
	box.add_theme_stylebox_override("panel", rail)
	var fill := ColorRect.new()
	fill.color = UiStyle.B_CORAL
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
	var tex: Texture2D = UiStyle.token_icon(type)
	if tex == null:
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
	l.add_theme_color_override("font_color", UiStyle.BROWN)
	return l


## The big art: the card itself (S38b template), as large as `size` allows
## at the card's 5:6 shape.
func _framed_art(cid: int, size: Vector2) -> Control:
	var face := CardFace.make(cid, size)
	face.name = "CardArt"
	face.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return face


func _art(cid: int, size: Vector2) -> Control:
	var tr := TextureRect.new()
	tr.texture = UiStyle.card_art(cid)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = size
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr
