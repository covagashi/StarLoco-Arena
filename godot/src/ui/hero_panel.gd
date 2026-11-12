extends "res://src/ui/card_panel.gd"
## A panel as a screen of its own (S45, the mockup's "4 · Panel: equipo del
## coach"): a lit stage behind, the back medallion and the pop header, a
## `stage` the panel draws on (the figure, its slots) and, on the right, a
## sheet of paper with a ribbon (`sheet_title`) holding `body`; the actions
## (`pinned_actions`) at the bottom right. The LobbyPanel API is the same
## (title, body, close_button, refresh, the row/label/button helpers), so a
## panel moves here by extending this instead.

const StyleB := preload("res://src/ui/style_b.gd")
const HREF := Vector2(1280, 720)
const R_SHEET := Rect2(820, 100, 430, 480)

var stage: Control
var sheet_title: Label
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
	_drifts = StyleB.backdrop(stage, HREF, hero_word(), "PPA // " + panel_name.trim_suffix("Dialog").to_upper(),
		"", Vector2(0.4, 0.45), 400.0)
	# top left: back (an ink box), the tag and the title
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
	head.add_child(UiStyle.tag(hero_tag()))
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
	inner.add_child(UiStyle.tag("SLOT"))
	inner.add_child(sheet_title)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
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


## The word outlined behind the screen and the tag over the title; a
## panel sets its own.
func hero_word() -> String:
	return "PIPPOP"


func hero_tag() -> String:
	return panel_name.trim_suffix("Dialog").to_upper()


func _process(dt: float) -> void:
	_t += dt
	StyleB.drift(_drifts, _t)


func _layout() -> void:
	var vp := get_viewport_rect().size
	_shade.position = -position
	_shade.size = vp
	var s := minf(vp.x / HREF.x, vp.y / HREF.y)
	_sheet.scale = Vector2(s, s)
	_sheet.position = (vp - HREF * s) / 2.0


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
