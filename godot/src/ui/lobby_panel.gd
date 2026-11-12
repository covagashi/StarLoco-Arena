class_name LobbyPanel
extends Control

const UiStyle := preload("res://src/ui/ui_style.gd")
## Shared native modal surface. Containers own all interior geometry.
## The bounded reference frame scales down to fit; lists scroll internally.

signal closed
signal requested(event: String, args: Array, item: Variant, index: int)

const REF := Vector2(1120, 620)
var panel_name := ""
var frame_size := REF   # a smaller window (a conversation) sets its own
var model: GuiModel
var body: VBoxContainer
var pinned_actions: HBoxContainer
var close_button: Button
var _about: Label    # the "?" explanation, hidden until asked
var frame: PanelContainer
var title: Label
var tab := 0
var selected: Dictionary = {}
var draft := {}
var _refresh_pending := false
var _shade: Control
var _sheet: Control     # the scaled sheet: the paper (frame), its ribbon
var _ribbon: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# a dark shade behind, and the S45 sheet of paper (src/ui/ui_style.gd):
	# the title on a ribbon across its top, "?" and close as medallions
	_shade = UiStyle.shade()
	# sized by hand in _layout (see there), so no full-rect anchors: they
	# would make every size assignment warn
	_shade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	add_child(_shade)
	_sheet = Control.new()
	_sheet.name = "Sheet"
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sheet)
	frame = PanelContainer.new()
	frame.theme = _theme()
	var ps: StyleBox = UiStyle.paper(0)
	ps.content_margin_left = 30
	ps.content_margin_right = 30
	ps.content_margin_top = 62
	ps.content_margin_bottom = 26
	frame.add_theme_stylebox_override("panel", ps)
	_sheet.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)
	# the header (?, close, and what a panel adds there: the Card Master's
	# wallet) sits in the sheet's top right corner, level with the ribbon
	var header := row(_sheet)
	header.name = "Header"
	header.alignment = BoxContainer.ALIGNMENT_END
	header.add_theme_constant_override("separation", 10)
	header.theme = frame.theme
	header.resized.connect(_place_header.bind(header))
	_ribbon = PanelContainer.new()
	_ribbon.name = "Ribbon"
	_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ribbon.add_theme_stylebox_override("panel", UiStyle.ribbon())
	_ribbon.custom_minimum_size = Vector2(320, 54)
	title = Label.new()
	title.name = "Title"
	UiStyle.title(title, 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.uppercase = true
	_ribbon.add_child(title)
	_sheet.add_child(_ribbon)
	title.draw.connect(_place_ribbon)   # its text changes on every refresh
	# "?" (S21): what this window is for, in two lines, where it is used —
	# the help no longer lives only in the Ayuda panel
	var help_key := "help.panel." + panel_name
	if I18n.has(help_key):
		var about := UiStyle.medal_button(44, func(b: Button):
			var f := UiStyle.title_font()
			var at := Vector2(22, 31) - Vector2(f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x / 2.0, 0)
			b.draw_string_outline(f, at, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, UiStyle.OUTLINE)
			b.draw_string(f, at, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UiStyle.SUN))
		about.name = "About"
		about.tooltip_text = I18n.t("help.about_tip")
		about.pressed.connect(func(): _about.visible = not _about.visible)
		header.add_child(about)
	close_button = UiStyle.medal_button(44, func(b: Button):
		var c := Vector2(22, 22)
		for d in [Vector2(7, 7), Vector2(7, -7)]:
			b.draw_line(c - d, c + d, UiStyle.INK, 3.6, true))
	close_button.name = "Close"
	close_button.tooltip_text = I18n.t("panel.close")
	close_button.pressed.connect(func(): closed.emit())
	header.add_child(close_button)
	if I18n.has(help_key):
		_about = label(column, I18n.t(help_key), 16)
		_about.name = "AboutText"
		_about.add_theme_color_override("font_color", UiStyle.ACCENT_INK)
		_about.visible = false
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	# The footer (S15, the owner: "no se nota el footer del modal"): its own
	# band of darker paper under a brown rule, holding the window's actions
	# and the key hint, so they read apart from the content that scrolls above.
	var footer := PanelContainer.new()
	footer.name = "Footer"
	var fs := StyleBoxFlat.new()
	fs.bg_color = UiStyle.SLOT
	fs.border_color = Color("3b2a1a")
	fs.set_border_width_all(2)
	fs.set_corner_radius_all(10)
	fs.content_margin_left = 14
	fs.content_margin_right = 14
	fs.content_margin_top = 10
	fs.content_margin_bottom = 8
	footer.add_theme_stylebox_override("panel", fs)
	column.add_child(footer)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	footer.add_child(foot)
	pinned_actions = row(foot)
	pinned_actions.hide()
	var hint := label(foot, I18n.t("panel.hint"), 13)
	hint.add_theme_color_override("font_color", UiStyle.BROWN)
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
	# Sized by hand: under a Node2D (the UI previews) full-rect anchors
	# have no parent rect and the shade came out 0x0.
	_shade.position = -position
	_shade.size = vp
	# room above the sheet for its ribbon
	var factor := minf(1.0, minf((vp.x - 32) / frame_size.x, (vp.y - 56) / (frame_size.y + 24)))
	frame.size = frame_size
	_sheet.size = frame_size
	_sheet.scale = Vector2(factor, factor)
	_sheet.position = (vp - frame_size * factor) / 2 + Vector2(0, 12 * factor)
	_place_ribbon()
	var header := _sheet.get_node_or_null("Header")
	if header != null:
		_place_header(header)


func _place_header(header: Control) -> void:
	header.size = header.get_combined_minimum_size()
	header.position = Vector2(frame_size.x - 20 - header.size.x, 10)


## The ribbon fits its title (between 320 px and the sheet minus 140) and
## sits centred across the sheet's top edge.
func _place_ribbon() -> void:
	if _ribbon == null or title == null:
		return
	var f := title.get_theme_font("font")
	var want := f.get_string_size(title.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x + 90
	var w := clampf(want, 320, frame_size.x - 140)
	if _ribbon.size.x != w:
		_ribbon.size = Vector2(w, 54)
	_ribbon.position = Vector2((frame_size.x - w) / 2.0, -26)


func _model_changed(_name: String, _field: String, _value: Variant) -> void:
	pass


func schedule_refresh() -> void:
	if _refresh_pending or not is_inside_tree():
		return
	_refresh_pending = true
	call_deferred("refresh")


func refresh() -> void:
	_refresh_pending = false
	_layout.call_deferred()
	_bind_focus.call_deferred()


## Name of the focused control inside the window, before a rebuild ("" if
## none); restore_focus() grabs the rebuilt control with that name.
func remember_focus() -> String:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return String(focused.name) if focused != null and frame.is_ancestor_of(focused) else ""


func restore_focus(focus_name: String) -> void:
	if focus_name == "":
		return
	var target := frame.find_child(focus_name, true, false) as Control
	if target != null and target.is_visible_in_tree() \
			and target.focus_mode != Control.FOCUS_NONE \
			and not (target is BaseButton and target.disabled):
		target.grab_focus()
		if target is LineEdit:
			target.caret_column = target.text.length()


func clear_body() -> void:
	for child in pinned_actions.get_children():
		pinned_actions.remove_child(child)
		child.queue_free()
	pinned_actions.hide()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()


func send(event: String, args: Array = [], item: Variant = null, index := -1) -> void:
	requested.emit(event, args, item, index)


func data(path: String, fallback: Variant = null) -> Variant:
	var value: Variant = model.get_value(path)
	return fallback if value == null else value


func row(parent: Node) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	parent.add_child(box)
	return box


func column(parent: Node, stretch := true) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	if stretch:
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	return box


func label(parent: Node, text: String, font_size := 16) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	return result


func button(parent: Node, text: String, callback: Callable, enabled := true) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 38
	result.disabled = not enabled
	result.pressed.connect(callback)
	parent.add_child(result)
	return result


func field(parent: Node, key: String, placeholder: String, initial := "") -> LineEdit:
	var edit := LineEdit.new()
	edit.placeholder_text = placeholder
	edit.text = str(draft.get(key, initial))
	edit.custom_minimum_size = Vector2(180, 38)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.max_length = 80
	edit.text_changed.connect(func(value): draft[key] = value)
	parent.add_child(edit)
	return edit


func choices(parent: Node, labels: Array, index: int, callback: Callable) -> OptionButton:
	var result := OptionButton.new()
	result.custom_minimum_size = Vector2(170, 38)
	for text in labels:
		result.add_item(str(text))
	result.select(index if index >= 0 and index < labels.size() else -1)
	result.item_selected.connect(callback)
	parent.add_child(result)
	return result


## `ids` (optional) gives each tab its own value for `tab` and the callback,
## so a panel can hide tabs without renumbering what they mean (S20).
func tabs(parent: Node, labels: Array, callback: Callable = Callable(), ids: Array = []) -> void:
	var bar := row(parent)
	for i in labels.size():
		var id: int = int(ids[i]) if i < ids.size() else i
		var b := button(bar, str(labels[i]), func():
			tab = id
			selected = {}
			if callback.is_valid():
				callback.call(id)
			schedule_refresh())
		b.toggle_mode = true
		b.button_pressed = tab == id
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func table(parent: Node, headings: Array, fields: Array, items: Array, callback: Callable = Callable()) -> Tree:
	var tree := Tree.new()
	tree.hide_root = true
	tree.columns = headings.size()
	tree.column_titles_visible = true
	tree.select_mode = Tree.SELECT_ROW
	tree.custom_minimum_size.y = 230
	tree.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for i in headings.size():
		tree.set_column_title(i, str(headings[i]))
	var root := tree.create_item()
	for item in items:
		if not item is Dictionary:
			continue
		var node := tree.create_item(root)
		node.set_metadata(0, item)
		for i in fields.size():
			node.set_text(i, str(item.get(fields[i], "—")))
		if not selected.is_empty() and item.get("id", item.get("name")) == selected.get("id", selected.get("name")):
			selected = item
			node.select(0)
	parent.add_child(tree)
	if items.is_empty():
		var empty := tree.create_item(root)
		empty.set_text(0, I18n.t("common.empty"))
		for i in headings.size():
			empty.set_selectable(i, false)
	if callback.is_valid():
		tree.item_selected.connect(func():
			var item: Variant = tree.get_selected().get_metadata(0)
			if item is Dictionary:
				selected = item
				callback.call(item))
	return tree


func confirm_action(text: String, callback: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = I18n.t("common.confirm")
	dialog.dialog_text = text
	dialog.confirmed.connect(callback)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered()


func _theme() -> Theme:
	return UiStyle.paper_theme()


## Tab stays within the active modal instead of reaching the lobby behind it.
func _bind_focus() -> void:
	var controls: Array[Control] = []
	_collect_focus(frame, controls)
	for i in controls.size():
		controls[i].focus_next = controls[i].get_path_to(controls[(i + 1) % controls.size()])
		controls[i].focus_previous = controls[i].get_path_to(controls[(i - 1 + controls.size()) % controls.size()])


func _collect_focus(node: Node, controls: Array[Control]) -> void:
	if node is Control and node.focus_mode != Control.FOCUS_NONE and node.is_visible_in_tree():
		if not node is BaseButton or not node.disabled:
			controls.append(node)
	for child in node.get_children():
		_collect_focus(child, controls)
