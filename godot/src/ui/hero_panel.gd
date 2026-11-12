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
var sheet_title: Label
var _header_title: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade = ColorRect.new()
	(_shade as ColorRect).color = UiStyle.NIGHT
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
	UiStyle.scene_backdrop(stage, "stage_bg", HREF)
	UiStyle.vignette(stage, HREF, Vector2(512, 144), Vector2(358, 396),
		Color(1.0, 0.86, 0.63, 0.3), Color(1.0, 0.86, 0.63, 0.0))
	UiStyle.vignette(stage, HREF, Vector2(486, 396), Vector2(704, 576),
		Color(0.07, 0.08, 0.16, 0.15), Color(0.047, 0.055, 0.118, 0.92))
	close_button = UiStyle.header(stage, "", func(): closed.emit())
	close_button.name = "Close"
	title = close_button.get_meta("title")
	# the sheet of paper at the right, its ribbon across the top
	var sheet := Control.new()
	sheet.name = "Sheet"
	sheet.position = R_SHEET.position
	sheet.size = R_SHEET.size
	sheet.theme = UiStyle.paper_theme()
	stage.add_child(sheet)
	var paper := PanelContainer.new()
	var ps: StyleBox = UiStyle.paper(0)
	ps.content_margin_left = 22
	ps.content_margin_right = 18
	ps.content_margin_top = 42
	ps.content_margin_bottom = 26
	paper.add_theme_stylebox_override("panel", ps)
	paper.size = R_SHEET.size
	sheet.add_child(paper)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	paper.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	var rib := PanelContainer.new()
	rib.position = Vector2(50, -22)
	rib.size = Vector2(R_SHEET.size.x - 100, 48)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon())
	sheet_title = Label.new()
	sheet_title.name = "SheetTitle"
	UiStyle.title(sheet_title, 26)
	sheet_title.uppercase = true
	sheet_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sheet_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	rib.add_child(sheet_title)
	sheet.add_child(rib)
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
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.pressed.connect(callback)
	if main:
		b.custom_minimum_size = Vector2(260, 68)
		UiStyle.primary(b, 28)
	else:
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UiStyle.raised(b, "navy", 20, 14)
	pinned_actions.add_child(b)
	return b


func clear_body() -> void:
	super.clear_body()
	pinned_actions.show()
