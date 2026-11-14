class_name LobbyPanel
extends Control

const UiStyle := preload("res://src/ui/ui_style.gd")
const StyleB := preload("res://src/ui/style_b.gd")
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
	# a pale veil over the screen behind, and the style B sheet (S45,
	# src/ui/style_b.gd): white, an ink rule on top, the tag and the big
	# title in its header, "?" and close as thin icons at the right
	_shade = ColorRect.new()
	(_shade as ColorRect).color = Color(0.91, 0.925, 0.945, 0.78)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
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
	var ps := StyleB.plate(0.97)
	ps.content_margin_left = 32
	ps.content_margin_right = 32
	ps.content_margin_top = 22
	ps.content_margin_bottom = 22
	frame.add_theme_stylebox_override("panel", ps)
	_sheet.add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	frame.add_child(column)
	# the header: the tag and the title, then what a panel adds there (the
	# Card Master's wallet), "?" and close
	var header := row(column)
	header.name = "Header"
	header.add_theme_constant_override("separation", 14)
	var head := VBoxContainer.new()
	head.add_theme_constant_override("separation", -4)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(UiStyle.tag("PPA // " + panel_name.trim_suffix("Dialog").to_upper()))
	title = Label.new()
	title.name = "Title"
	UiStyle.display(title, 40)
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	head.add_child(title)
	header.add_child(head)
	# "?" (S21): what this window is for, in two lines, where it is used —
	# the help no longer lives only in the Ayuda panel
	var help_key := "help.panel." + panel_name
	if I18n.has(help_key):
		var about := _icon_button("?")
		about.name = "About"
		about.tooltip_text = I18n.t("help.about_tip")
		about.pressed.connect(func(): _about.visible = not _about.visible)
		header.add_child(about)
	close_button = _icon_button("x")
	close_button.name = "Close"
	close_button.tooltip_text = I18n.t("panel.close")
	close_button.pressed.connect(func(): closed.emit())
	header.add_child(close_button)
	if I18n.has(help_key):
		_about = label(column, I18n.t(help_key), 15)
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
	# The footer (S15, the owner: "no se nota el footer del modal"): under a
	# thin rule, holding the window's actions and the key hint, so they read
	# apart from the content that scrolls above.
	var footer := PanelContainer.new()
	footer.name = "Footer"
	var fs := StyleBoxFlat.new()
	fs.bg_color = UiStyle.SLOT
	fs.border_color = Color(UiStyle.B_INK, 0.2)
	fs.border_width_top = 1
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
	var hint := label(foot, I18n.t("panel.hint"), 12)
	hint.add_theme_color_override("font_color", UiStyle.BROWN)
	get_viewport().size_changed.connect(_layout)
	_layout()
	model.changed.connect(_model_changed)
	I18n.locale_changed.connect(func(_l): schedule_refresh())
	refresh()
	_layout.call_deferred()
	_bind_focus.call_deferred()
	close_button.grab_focus()
	# S39: a panel sounds as it opens and as it goes
	_sound("open")
	tree_exiting.connect(func(): _sound("close"))
	# the sheet rises in (S45: everything moves)
	var to := _sheet.position
	_sheet.position = to + Vector2(0, 24)
	_sheet.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tw.tween_property(_sheet, "position", to, 0.3)
	tw.tween_property(_sheet, "modulate:a", 1.0, 0.22)


## An interface sound (S39, the Audio autoload), when the autoload is there.
func _sound(kind: String) -> void:
	var a := get_node_or_null("/root/Audio")
	if a != null:
		a.ui(kind)


## A thin icon button of the header ("?" or a close cross), ink, coral
## under the pointer or the focus.
func _icon_button(kind: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(40, 40)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.draw.connect(func():
		var lit := b.is_hovered() or b.has_focus()
		var col := UiStyle.B_CORAL if lit else UiStyle.B_INK
		var c := b.size * 0.5
		if kind == "x":
			b.draw_line(c - Vector2(9, 9), c + Vector2(9, 9), col, 2.5, true)
			b.draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), col, 2.5, true)
		else:
			var f := UiStyle.display_font()
			var w := f.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
			b.draw_string(f, c + Vector2(-w * 0.5, 11), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, col)
		if lit:
			b.draw_line(Vector2(6, b.size.y - 2), Vector2(b.size.x - 6, b.size.y - 2), col, 2.0))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
		sig.connect(b.queue_redraw)
	return b


func _layout() -> void:
	var vp := get_viewport_rect().size
	# Sized by hand: under a Node2D (the UI previews) full-rect anchors
	# have no parent rect and the shade came out 0x0.
	_shade.position = -position
	_shade.size = vp
	var factor := minf(1.0, minf((vp.x - 32) / frame_size.x, (vp.y - 32) / frame_size.y))
	frame.size = frame_size
	_sheet.size = frame_size
	_sheet.scale = Vector2(factor, factor)
	_sheet.position = (vp - frame_size * factor) / 2


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
