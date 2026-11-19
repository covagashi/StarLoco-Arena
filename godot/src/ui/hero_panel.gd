extends "res://src/ui/card_panel.gd"
## A panel as a screen of its own (S45, the mockup's "4 · Panel: equipo del
## coach"): a lit stage behind, the back medallion and the pop header, a
## `stage` the panel draws on (the figure, its slots) and, on the right, a
## sheet of paper with a ribbon (`sheet_title`) holding `body`; the actions
## (`pinned_actions`) at the bottom right. The LobbyPanel API is the same
## (title, body, close_button, refresh, the row/label/button helpers), so a
## panel moves here by extending this instead.

const HREF := Vector2(1280, 720)
const R_SHEET := Rect2(820, 100, 430, 480)

var stage: Control
var _back: Control      # the backdrop, scaled to cover the window (W4)
var sheet_title: Label
var sheet_tag: Label    # the small tag over sheet_title ("SLOT" unless a panel says)
var sheet_scroll: ScrollContainer   # `body` scrolls inside it when the paper is short
var _paper: PanelContainer
var _more: Control      # the cue at the paper's foot: it goes on below
var _header_title: Label
var _drifts: Array = []
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	(_shade as ColorRect).color = UiStyle.B_BG
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_shade)
	_back = StyleB.back_layer(self, HREF)
	_sheet = Control.new()
	_sheet.name = "Screen"
	_sheet.size = HREF
	_sheet.clip_contents = true
	add_child(_sheet)
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	frame.theme = UiStyle.theme()
	frame.size = HREF
	_sheet.add_child(frame)
	stage = Control.new()
	stage.name = "Stage"
	stage.custom_minimum_size = HREF
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stage)
	_drifts = StyleB.backdrop(_back, HREF, "", "", "", Vector2(0.4, 0.45), 400.0, stage)
	# top left: back (an ink box) and the title
	close_button = StyleB.button(false, 26)
	close_button.name = "Close"
	close_button.text = "‹"
	close_button.size = Vector2(58, 52)
	close_button.position = Vector2(24, 20)
	close_button.tooltip_text = I18n.t("panel.close")
	close_button.pressed.connect(func(): closed.emit())
	stage.add_child(close_button)
	var head := VBoxContainer.new()
	head.position = Vector2(96, 16)
	head.add_theme_constant_override("separation", -4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title = Label.new()
	UiStyle.display(title, 44)
	head.add_child(title)
	stage.add_child(head)
	# the sheet of paper at the right, its ribbon across the top
	var sheet := Control.new()
	sheet.name = "Sheet"
	sheet.position = R_SHEET.position
	sheet.size = R_SHEET.size
	sheet.theme = UiStyle.paper_theme()
	stage.add_child(sheet)
	var paper := PanelContainer.new()
	_paper = paper
	var ps := StyleB.plate()
	ps.content_margin_left = 26
	ps.content_margin_right = 22
	ps.content_margin_top = 22
	ps.content_margin_bottom = 22
	paper.add_theme_stylebox_override("panel", ps)
	paper.size = R_SHEET.size
	sheet.add_child(paper)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	paper.add_child(inner)
	sheet_title = Label.new()
	sheet_title.name = "SheetTitle"
	UiStyle.display(sheet_title, 30)
	sheet_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	sheet_tag = UiStyle.tag("SLOT")
	inner.add_child(sheet_tag)
	inner.add_child(sheet_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)
	sheet_scroll = scroll
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	# the paper goes on below: a fade over the last lines and a coral chevron
	# on the foot margin, only while the body can still scroll down
	_more = Control.new()
	_more.name = "More"
	_more.size = R_SHEET.size
	_more.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_more.draw.connect(_draw_more)
	sheet.add_child(_more)
	scroll.get_v_scroll_bar().value_changed.connect(func(_v): _more.queue_redraw())
	scroll.get_v_scroll_bar().changed.connect(_more.queue_redraw)
	pinned_actions = HBoxContainer.new()
	pinned_actions.name = "Actions"
	pinned_actions.alignment = BoxContainer.ALIGNMENT_END
	pinned_actions.add_theme_constant_override("separation", 14)
	pinned_actions.size = Vector2(760, 72)
	pinned_actions.position = HREF - Vector2(36 + 760, 28 + 72)
	stage.add_child(pinned_actions)
	get_viewport().size_changed.connect(_layout)
	_layout()
	model.changed.connect(_model_changed)
	I18n.locale_changed.connect(func(_l): schedule_refresh())
	refresh()
	_layout.call_deferred()
	_bind_focus.call_deferred()
	close_button.grab_focus()
	StyleB.enter(self, [sheet], Vector2(60, 0), 0.2, 0.0, 0.5)
	StyleB.enter(self, [head], Vector2(0, -24), 0.1)


func _process(dt: float) -> void:
	_t += dt
	StyleB.drift(_drifts, _t)


func _draw_more() -> void:
	var bar := sheet_scroll.get_v_scroll_bar()
	if bar.max_value - bar.page - bar.value <= 1.0:
		return
	var ps: StyleBoxFlat = _paper.get_theme_stylebox("panel")
	var w := _paper.size.x
	var foot := _paper.size.y - ps.content_margin_bottom
	var x0 := ps.content_margin_left
	var x1 := w - ps.content_margin_right - bar.size.x
	var fade := 44.0
	_more.draw_polygon(PackedVector2Array([Vector2(x0, foot - fade), Vector2(x1, foot - fade), Vector2(x1, foot), Vector2(x0, foot)]),
		PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.96), Color(1, 1, 1, 0.96)]))
	var m := Vector2(w * 0.5, foot + ps.content_margin_bottom * 0.5)
	var chevron := PackedVector2Array([m + Vector2(-9, -4), m + Vector2(0, 4), m + Vector2(9, -4)])
	var shadow := PackedVector2Array()
	for p in chevron:
		shadow.append(p + Vector2(2, 2))
	_more.draw_polyline(shadow, Color(UiStyle.B_INK, 0.9), 3.0, true)
	_more.draw_polyline(chevron, UiStyle.B_CORAL, 3.0, true)


## The paper hardened (the recruit's, S47): `size` tall, a hard ink shadow
## and an ink rim instead of the soft shade, a coral corner cut at the
## bottom right — like every other box on a screen whose stage draws slabs.
func harden_sheet(size: Vector2) -> void:
	var sheet: Control = stage.get_node("Sheet")
	sheet.size = size
	_paper.size = size
	_more.size = size
	var ps: StyleBoxFlat = _paper.get_theme_stylebox("panel").duplicate()
	ps.shadow_size = 0
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_width_bottom = 2
	ps.border_width_top = 4
	ps.bg_color = Color(1, 1, 1, 0.96)
	_paper.add_theme_stylebox_override("panel", ps)
	var sh := Control.new()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.draw.connect(func(): sh.draw_rect(Rect2(Vector2(7, 7), size), Color(UiStyle.B_INK, 0.9)))
	sheet.add_child(sh)
	sheet.move_child(sh, 0)
	var corner := Control.new()   # a coral corner cut at the bottom right, over the paper
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.draw.connect(func():
		var c := size
		corner.draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 0), c, c + Vector2(0, -34)]), UiStyle.B_CORAL)
		corner.draw_line(c + Vector2(-34, 0), c + Vector2(0, -34), UiStyle.B_INK, 2.0, true))
	sheet.add_child(corner)
	var inner: VBoxContainer = _paper.get_child(0)
	inner.add_theme_constant_override("separation", 4)
	body.add_theme_constant_override("separation", 8)


func _layout() -> void:
	var vp := get_viewport_rect().size
	_shade.position = -position
	_shade.size = vp
	var s := minf(vp.x / HREF.x, vp.y / HREF.y)
	_sheet.scale = Vector2(s, s)
	_sheet.position = (vp - HREF * s) / 2.0
	StyleB.cover(_back, HREF, vp)


## A raised button for the actions row: "Deshacer" in navy, the main one
## leaning in pop.
func hero_button(text: String, callback: Callable, enabled: bool, main := false) -> Button:
	var b := StyleB.button(main, 30 if main else 20)
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(callback)
	if main:
		b.custom_minimum_size = Vector2(280, 66)
	else:
		b.custom_minimum_size = Vector2(170, 52)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pinned_actions.add_child(b)
	return b


func clear_body() -> void:
	super.clear_body()
	pinned_actions.show()
