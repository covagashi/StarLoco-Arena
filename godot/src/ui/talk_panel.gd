extends "res://src/ui/lobby_panel.gd"
## The native conversation window (S18, tanda 2): replaces the debug
## ElementDlg for every talking element — challenges, breed masters, the
## demons, NPCs — and the tutorial monologues.
##
## S38b (owner: "¿toda la pantalla blanca para ese poco texto?"): laid out
## like the references' character screens and a visual novel, not a sheet —
## the screen behind stays in sight under a light veil, the speaker stands
## big on the left, what they say sits on a plate along the bottom under a
## ribbon with their name, the replies stack on the right above it, and
## "Siguiente" / "Aceptar" / "Cerrar" sit in the plate's corner. Without a
## face the plate spans the width.
##
## Reads the `talk` model (main.gd _talk_show): {name, text (BBCode), page,
## pages, face, choices:[{label, kind}]} with kind reply / challenge /
## primary / secondary. A click sends "nativeTalk" [index]; main.gd runs
## the choice.

const STAGE := Vector2(1280, 720)
const BOX := Rect2(410, 520, 830, 172)          # the plate, beside a face
const BOX_WIDE := Rect2(40, 520, 1200, 172)     # …and without one
const PORTRAIT := Rect2(-14, 166, 476, 560)     # a standing portrait (ours), to the bottom edge
const MEDAL := Rect2(110, 270, 230, 230)        # a small square one (a class)
const MAX_H := 330.0                            # the tallest the plate grows
const CHOICES := Rect2(690, 64, 550, 432)       # the replies, bottom-aligned
## the old name of the face box's size; the portraits are drawn to it
const FACE_SIZE := Vector2(170, 200)

var _stage: Control
var _plate: PanelContainer
var _name_ribbon: PanelContainer
var _who: Label
var _speech: RichTextLabel
var _page: Label
var _face_slot: Control
var _choice_scroll: ScrollContainer
var _caption: Label
var _face_key := ""


func _ready() -> void:
	panel_name = "npcTalkDialog"
	super._ready()
	# the sheet of the other panels is not used here: the stage replaces it,
	# and the base class's frame / body / title / actions point into it
	_sheet.hide()
	(_shade as ColorRect).color = Color(0.91, 0.925, 0.945, 0.82)
	_build_stage()
	refresh()
	_enter()


func _build_stage() -> void:
	# frame (what focus and remember_focus look in) is an empty panel holding
	# the stage, whose pieces are placed by hand
	frame = PanelContainer.new()
	frame.name = "StageFrame"
	frame.theme = _theme()
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.size = STAGE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(_stage)
	# a soft white rise behind the plate, so the text never sits on the lobby
	var rise := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0))
	g.set_color(1, Color(1, 1, 1, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	rise.texture = gt
	rise.position = Vector2(0, 380)
	rise.size = Vector2(STAGE.x, STAGE.y - 380)
	rise.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(rise)
	_face_slot = Control.new()
	_face_slot.name = "FaceSlot"
	_face_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_face_slot)
	# the replies: a column on the right, its last one just over the plate
	_choice_scroll = ScrollContainer.new()
	_choice_scroll.name = "Choices"
	_choice_scroll.position = CHOICES.position
	_choice_scroll.size = CHOICES.size
	_choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_stage.add_child(_choice_scroll)
	body = VBoxContainer.new()
	body.alignment = BoxContainer.ALIGNMENT_END
	body.custom_minimum_size = Vector2(CHOICES.size.x - 12, CHOICES.size.y)
	body.add_theme_constant_override("separation", 8)
	_choice_scroll.add_child(body)
	# the plate: what they say, the page, the actions in its corner
	_plate = PanelContainer.new()
	_plate.name = "Plate"
	var ps := StyleB.plate(0.97)
	ps.content_margin_left = 30
	ps.content_margin_right = 58   # room for the close cross
	ps.content_margin_top = 26
	ps.content_margin_bottom = 16
	_plate.add_theme_stylebox_override("panel", ps)
	_stage.add_child(_plate)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_plate.add_child(col)
	_speech = RichTextLabel.new()
	_speech.name = "Speech"
	_speech.bbcode_enabled = true
	_speech.scroll_active = true   # past MAX_H it scrolls
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_speech.add_theme_font_override("normal_font", UiStyle.body_font())
	_speech.add_theme_font_size_override("normal_font_size", 21)
	_speech.add_theme_font_size_override("bold_font_size", 21)
	_speech.add_theme_color_override("default_color", UiStyle.PAPER_INK)
	col.add_child(_speech)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	col.add_child(foot)
	_page = UiStyle.caption("")
	_page.name = "Page"
	_page.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	foot.add_child(_page)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(spacer)
	pinned_actions = HBoxContainer.new()
	pinned_actions.add_theme_constant_override("separation", 12)
	foot.add_child(pinned_actions)
	# the name on an ink ribbon over the plate's edge, who they are beside it
	_name_ribbon = PanelContainer.new()
	_name_ribbon.name = "Ribbon"
	var rs := StyleBoxFlat.new()
	rs.bg_color = UiStyle.B_INK
	rs.skew = Vector2(0.25, 0)
	rs.content_margin_left = 22
	rs.content_margin_right = 26
	rs.content_margin_top = 2
	rs.content_margin_bottom = 2
	rs.border_color = UiStyle.B_CORAL
	rs.border_width_bottom = 4
	_name_ribbon.add_theme_stylebox_override("panel", rs)
	_stage.add_child(_name_ribbon)
	title = Label.new()
	title.name = "Title"
	UiStyle.display(title, 30, Color.WHITE)
	_name_ribbon.add_child(title)
	_who = UiStyle.caption("")
	_who.name = "Who"
	_stage.add_child(_who)
	_caption = UiStyle.caption(I18n.t("talk.challenges"))
	_caption.name = "ChallengesCaption"
	# close, at the plate's top right
	close_button = _icon_button("x")
	close_button.name = "Close"
	close_button.tooltip_text = I18n.t("panel.close")
	close_button.pressed.connect(func(): closed.emit())
	_stage.add_child(close_button)


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name.split(".")[0] == "talk":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if _stage == null:
		return
	clear_body()
	var talk: Dictionary = data("talk", {})
	title.text = str(talk.get("name", "")) if str(talk.get("name", "")) != "" else I18n.t("talk.title")
	_speech.text = str(talk.get("text", ""))
	var face: Dictionary = talk.get("face", {})
	var has_face := _show_face(face)
	_who.text = I18n.t(str(face.who)).to_upper() if has_face and str(face.get("who", "")) != "" else ""
	var pages := int(talk.get("pages", 0))
	_page.text = I18n.t("talk.page", {"n": int(talk.get("page", 1)), "of": pages}).to_upper() if pages > 1 else ""
	var rows: Array = talk.get("choices", [])
	var listed := rows.filter(func(c): return str(c.kind) in ["reply", "challenge"])
	if listed.any(func(c): return str(c.kind) == "challenge"):
		_caption = UiStyle.caption(I18n.t("talk.challenges"))
		_caption.name = "ChallengesCaption"
		_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		body.add_child(_caption)
	var first: Button = null
	var main: Button = null
	for i in rows.size():
		var c: Dictionary = rows[i]
		if str(c.kind) in ["reply", "challenge"]:
			var b := _choice_button(("› " if str(c.kind) == "reply" else "") + str(c.label))
			b.name = "Choice%d" % i
			b.pressed.connect(func(): send("nativeTalk", [i]))
			body.add_child(b)
			if first == null:
				first = b
	pinned_actions.show()
	for kind in ["secondary", "primary"]:
		for i in rows.size():
			if str(rows[i].kind) != kind:
				continue
			var b := button(pinned_actions, str(rows[i].label), func(): send("nativeTalk", [i]))
			b.name = "Choice%d" % i
			b.custom_minimum_size.x = 150
			if kind == "primary":
				UiStyle.primary(b, 20)
				main = b
	_place(has_face)   # after the actions: the plate's height counts them
	var target: Button = main if main != null else first
	if target != null:
		target.grab_focus.call_deferred()
	_choice_scroll.scroll_vertical = 1 << 20   # the newest reply, at the bottom


## A reply: a white slanted plate, ink text from the left; coral under the
## pointer or the focus.
func _choice_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 44)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.add_theme_font_override("font", UiStyle.body_font())
	b.add_theme_font_size_override("font_size", 17)
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var s := StyleBoxFlat.new()
		var lit: bool = st != "normal"
		s.bg_color = UiStyle.B_CORAL if lit else Color(1, 1, 1, 0.96)
		s.skew = Vector2(0.18, 0)
		s.border_color = UiStyle.B_INK
		s.border_width_left = 0 if lit else 4
		s.content_margin_left = 22
		s.content_margin_right = 18
		s.shadow_color = Color(UiStyle.B_INK, 0.12)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 4)
		b.add_theme_stylebox_override(st, s)
	b.add_theme_color_override("font_color", UiStyle.B_INK)
	for c in ["font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	return b


## The speaker on the left: our standing portraits big, a small square one
## (a class portrait) in a medallion, a retail animation in its old box.
## False when there is no face to show.
func _show_face(face: Dictionary) -> bool:
	var key := str(face.get("image", face.get("anim", "")))
	if key == _face_key and _face_slot.get_child_count() > 0:
		return true
	_face_key = key
	for c in _face_slot.get_children():
		c.queue_free()
	if face.has("image"):
		var img := AssetPaths.load_image(str(face.image))
		if img == null:
			return false
		var tr := TextureRect.new()
		tr.name = "Face"
		tr.texture = ImageTexture.create_from_image(img)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if img.get_height() >= 300:   # ours, drawn to stand (tools/portraits)
			_face_slot.position = PORTRAIT.position
			tr.size = PORTRAIT.size
			_face_slot.add_child(tr)
		else:
			_face_slot.position = MEDAL.position
			var m := PanelContainer.new()
			var ms := UiStyle.box(UiStyle.SLOT, UiStyle.B_INK, 4, 10)
			ms.set_corner_radius_all(int(MEDAL.size.x / 2))
			m.add_theme_stylebox_override("panel", ms)
			m.size = MEDAL.size
			tr.custom_minimum_size = MEDAL.size - Vector2(20, 20)
			m.add_child(tr)
			_face_slot.add_child(m)
		return true
	if not face.has("anim"):
		return false
	var spr = preload("res://src/anims/anm_sprite.gd").new()
	if not spr.load_action(str(face.anim), str(face.get("action", ""))):
		spr.free()
		return false
	var holder := Control.new()
	holder.name = "Face"
	holder.size = PORTRAIT.size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(spr)
	var w := 1.0
	var h := 1.0
	for f in spr._frames:
		w = maxf(w, float(f.w))
		h = maxf(h, float(f.h))
	var k := minf(minf(PORTRAIT.size.x / w, PORTRAIT.size.y / h), 3.0)
	spr.scale = Vector2(k, k)
	spr.foot_pivot = true
	spr.position = Vector2(PORTRAIT.size.x / 2.0, PORTRAIT.size.y)
	_face_slot.position = PORTRAIT.position
	_face_slot.add_child(holder)
	return true


## The plate, the ribbon, "who" and close, beside a face or across.
func _place(has_face: bool) -> void:
	var box := BOX if has_face else BOX_WIDE
	_face_slot.visible = has_face
	# as tall as what they say needs, growing upwards from the bottom edge
	# (measured with the font: the label has no width yet on a rebuild)
	var width := box.size.x - 30 - 58
	var text_h := UiStyle.body_font().get_multiline_string_size(_speech.get_parsed_text(),
		HORIZONTAL_ALIGNMENT_LEFT, width, 21).y + 8
	var foot_h := maxf(pinned_actions.get_combined_minimum_size().y, _page.get_combined_minimum_size().y)
	var h := clampf(26 + text_h + 6 + foot_h + 16, box.size.y, MAX_H)
	_speech.custom_minimum_size.y = minf(text_h, MAX_H - 26 - 6 - foot_h - 16)
	box = Rect2(box.position.x, box.end.y - h, box.size.x, h)
	_plate.position = box.position
	_plate.size = box.size
	_choice_scroll.size.y = box.position.y - 16 - CHOICES.position.y
	body.custom_minimum_size.y = _choice_scroll.size.y
	_name_ribbon.reset_size()
	_name_ribbon.position = box.position + Vector2(22, -_name_ribbon.get_combined_minimum_size().y + 8)
	_who.position = Vector2(_name_ribbon.position.x + _name_ribbon.get_combined_minimum_size().x + 18, box.position.y - 28)
	_who.visible = _who.text != ""
	close_button.position = Vector2(box.end.x - 46, box.position.y + 6)


func _layout() -> void:
	var vp := get_viewport_rect().size
	_shade.position = -position
	_shade.size = vp
	if _stage == null:
		return
	var factor := minf(vp.x / STAGE.x, vp.y / STAGE.y)
	frame.size = STAGE
	frame.scale = Vector2(factor, factor)
	frame.position = (vp - STAGE * factor) / 2


## The entrance: the speaker slides in from the left, the plate rises.
func _enter() -> void:
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for n: Control in [_face_slot, _plate, _name_ribbon, _choice_scroll]:
		var off := Vector2(-40, 0) if n == _face_slot else Vector2(0, 24)
		var to := n.position
		n.position = to + off
		n.modulate.a = 0.0
		tw.tween_property(n, "position", to, 0.35)
		tw.tween_property(n, "modulate:a", 1.0, 0.25)
