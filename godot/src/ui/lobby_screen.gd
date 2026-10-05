class_name PippopLobby
extends Control
## THESIS: a native coach-and-combat shell replaces the deprecated hall.
## OWN-WORLD: incumbent olive stone, gold letter tiles, Copperplate and Baybayin.
## STORY: inspect your coach, prepare a team, then choose a fight mode.
## FIRST VIEWPORT: coach left; six actions center; chat and retail menus below.
## FORM: pinned 1280x720 extension; no concept seed or identity replacement.
## FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
## Baked slots are shared with tools/make_lobby_bg.py; XML stays above us.

signal action_requested(action: String)
signal dialog_requested(dialog: String)
signal item_requested(event: String, item: Variant)
signal debug_requested

const REF := Vector2(1280, 720)
const CHAT_RECT := Rect2(50, 524, 630, 134)
const MENUS := [
	["Menú", "menuDialog"], ["Equipo", "teamManagementDialog"],
	["Estadísticas", "coachStatisticsDialog"], ["Inventario", "coachInventoryDialog"],
	["Clasificación", "ladderInformationDialog"], ["Calendario", "calendarDialog"],
	["Logros", "achievementDialog"], ["Social", "socialDialog"],
	["Ayuda", "tooltipDialog"],
]

var _box: Control
var _font: FontFile
var _name: Label
var _level: Label
var _bubble: Label
var _spr
var _model
var _chat: Control
var _look := ""
var _actions: Array[Button] = []
var _emotes: MenuButton
var _tools: MenuButton


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Control.new()
	_box.size = REF
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	var bg := TextureRect.new()
	bg.texture = ImageTexture.create_from_image(Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/ui/lobby_bg.png")))
	bg.size = REF
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(bg)
	_font = FontFile.new()
	_font.load_dynamic_font("res://assets/gui/fonts/COPRGTB.TTF")
	_name = _label(Rect2(60, 158, 280, 36), "", 25)
	_level = _label(Rect2(60, 194, 280, 26), "", 16)
	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = Vector2(200, 443)
	_spr.scale = Vector2(-2.5, 2.5)
	_box.add_child(_spr)
	_bubble = _label(Rect2(70, 460, 260, 30), "", 16)
	_label(Rect2(400, 159, 824, 32), "Elige tu próximo combate", 24)
	var actions := [
		["Entrenamiento", "practice", "Practica contra la IA"],
		["Combate", "fight", "Buscar rival · Clasificado"],
		["Aleatorio", "quick", "Buscar partida aleatoria"],
		["Evolución", "evo", "Combate de evolución"],
		["2v2 dúo", "duo", "Gestionar tu equipo de dos"],
		["Equipo", "team", "Luchadores y composiciones"],
	]
	for i in range(actions.size()):
		var row: Array = actions[i]
		var r := Rect2(400 + (i % 3) * 280, 210 if i < 3 else 352, 264, 126 if i < 3 else 92)
		var b := _button(r, str(row[0]), func(): action_requested.emit(str(row[1])), 24)
		b.tooltip_text = str(row[2])
		_actions.append(b)
	_label(Rect2(400, 456, 824, 30), "Prepara tu equipo y entra en la arena", 16)
	_emotes = _item_menu(Rect2(40, 90, 106, 40), "Emotes")
	_tools = _item_menu(Rect2(152, 90, 134, 40), "Herramientas")
	_button(Rect2(292, 90, 84, 40), "Social", func(): dialog_requested.emit("socialDialog"), 16)
	var icons := ImageTexture.create_from_image(Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/ui/lobby_icons.png")))
	for i in range(MENUS.size()):
		var entry: Array = MENUS[i]
		var button := _button(Rect2(732 + (i % 3) * 164, 526 + (i / 3) * 43, 158, 37),
			str(entry[0]), func(): dialog_requested.emit(str(entry[1])), 14)
		var icon := AtlasTexture.new()
		icon.atlas = icons
		icon.region = Rect2(i * 32, 0, 32, 32)
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 20)
		button.tooltip_text = str(entry[0])
	_button(Rect2(1152, 674, 78, 26), "Debug", func(): debug_requested.emit(), 13)
	_label(Rect2(40, 672, 650, 24), "Enter para escribir en el chat", 13)
	resized.connect(_relayout)


func _ready() -> void:
	_relayout()


func bind_model(model, chat: Control) -> void:
	_model = model
	_chat = chat
	_model.changed.connect(_on_model_changed)
	_sync()
	_relayout()


func set_actions_ready(ready: bool) -> void:
	for b in _actions:
		b.disabled = not ready


func show_bubble(text: String) -> void:
	_bubble.text = text.trim_prefix("AnimEmote-").replace("-Debut", "")
	var current := _bubble.text
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(_bubble) and _bubble.text == current:
			_bubble.text = "")


func _on_model_changed(model_name: String, _field: String, _value: Variant) -> void:
	if model_name in ["localCoach", "tools"]:
		_sync()


func _sync() -> void:
	var coach: Variant = _model.get_value("localCoach")
	if not coach is Dictionary:
		return
	_name.text = str(coach.get("name", ""))
	_level.text = "Nivel %d" % int(coach.get("level", 0))
	var look := "%s/%s/%s" % [coach.get("sex", 0), coach.get("skin", 0), coach.get("hair", 0)]
	if look != _look:
		_look = look
		_spr.tints = Palettes.coach_tints(int(coach.get("skin", 0)), int(coach.get("hair", 0)))
		var lib := "res://assets/anims/coach_700%d" % int(coach.get("sex", 0))
		for dir in [3, 5, 2, 0, 6, 1, 7, 4]:
			if _spr.load_action(lib, "%d_AnimStatique" % dir):
				_spr.scale.x = -2.5 if dir in [1, 2, 3] else 2.5
				break
	_fill_items(_emotes, coach.get("equipedEmotes", []), true)
	var tools: Variant = coach.get("tools", _model.get_value("tools"))
	_fill_items(_tools, tools if tools is Array else [], false)


func _item_menu(r: Rect2, title: String) -> MenuButton:
	var b := MenuButton.new()
	b.position = r.position
	b.size = r.size
	b.text = title
	_style_button(b, 16)
	_box.add_child(b)
	b.get_popup().index_pressed.connect(func(index: int):
		var data: Dictionary = b.get_popup().get_item_metadata(index)
		item_requested.emit(data.event, data.item))
	return b


func _fill_items(b: MenuButton, items: Array, emotes: bool) -> void:
	var popup := b.get_popup()
	popup.clear()
	if items.is_empty():
		popup.add_item("Sin emotes equipados" if emotes else "Sin herramientas")
		popup.set_item_disabled(0, true)
	for item in items:
		if item == null:
			continue
		var title := str(item.get("name", item.get("id", ""))) if item is Dictionary else str(item)
		popup.add_item(title)
		popup.set_item_metadata(popup.item_count - 1, {"event": "playEmote" if emotes else "useToolRequest", "item": item})
		if emotes:
			popup.add_item("Desequipar: " + title)
			popup.set_item_metadata(popup.item_count - 1, {"event": "unequipEmote", "item": item})


func _label(r: Rect2, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = r.position
	label.size = r.size
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("e5d9ae"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(label)
	return label


func _button(r: Rect2, text: String, cb: Callable, font_size: int) -> Button:
	var b := Button.new()
	b.position = r.position
	b.size = r.size
	b.text = text
	_style_button(b, font_size)
	b.pressed.connect(cb)
	_box.add_child(b)
	return b


func _style_button(b: Button, font_size: int) -> void:
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color("fff0c5"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.set_corner_radius_all(10)
		if state == "hover":
			style.bg_color = Color(1, 0.9, 0.6, 0.13)
		elif state == "pressed":
			style.bg_color = Color(0, 0, 0, 0.25)
		elif state == "focus":
			style.border_color = Color("ffe6a0")
			style.set_border_width_all(2)
		b.add_theme_stylebox_override(state, style)


func _relayout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / REF.x, vp.y / REF.y)
	_box.scale = Vector2(s, s)
	_box.position = (vp - REF * s) / 2.0
	if is_instance_valid(_chat):
		_chat.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_chat.custom_minimum_size = Vector2.ZERO
		_chat.scale = Vector2(s, s)
		_chat.position = _box.position + CHAT_RECT.position * s
		_chat.size = CHAT_RECT.size
