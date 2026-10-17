class_name LobbyPanel
extends Control

const OneBit := preload("res://src/ui/onebit.gd")
## Shared native modal surface. Containers own all interior geometry.
## The bounded reference frame scales down to fit; lists scroll internally.

signal closed
signal requested(event: String, args: Array, item: Variant, index: int)

const REF := Vector2(1120, 620)
var panel_name := ""
var model: GuiModel
var body: VBoxContainer
var pinned_actions: HBoxContainer
var close_button: Button
var frame: PanelContainer
var title: Label
var tab := 0
var selected: Dictionary = {}
var draft := {}
var _refresh_pending := false
var _shade: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 1-bit (S18): a dither shade instead of a translucent one, and a
	# black window with a hard white shadow.
	_shade = OneBit.shade()
	add_child(_shade)
	frame = PanelContainer.new()
	frame.theme = _theme()
	frame.add_theme_stylebox_override("panel", OneBit.window())
	add_child(frame)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	frame.add_child(column)
	var header := row(column)
	title = label(header, "", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var font := FontFile.new()
	font.load_dynamic_font(AssetPaths.resolve("gui/fonts/COPRGTB.TTF"))
	title.add_theme_font_override("font", font)
	close_button = button(header, I18n.t("panel.close"), func(): closed.emit())
	close_button.name = "Close"
	column.add_child(HSeparator.new())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	pinned_actions = row(column)
	pinned_actions.hide()
	label(column, I18n.t("panel.hint"), 13)
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
	var factor := minf(1.0, minf((vp.x - 32) / REF.x, (vp.y - 32) / REF.y))
	frame.size = REF
	frame.scale = Vector2(factor, factor)
	frame.position = (vp - REF * factor) / 2


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


func tabs(parent: Node, labels: Array, callback: Callable = Callable()) -> void:
	var bar := row(parent)
	for i in labels.size():
		var b := button(bar, str(labels[i]), func():
			tab = i
			selected = {}
			if callback.is_valid():
				callback.call(i)
			schedule_refresh())
		b.toggle_mode = true
		b.button_pressed = tab == i
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
	return OneBit.theme()


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
