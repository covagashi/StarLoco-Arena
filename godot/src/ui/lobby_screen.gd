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
signal coach_rotated(delta: int)

const Direction8 := preload("res://src/util/direction8.gd")
const REF := Vector2(1280, 720)
const CHAT_RECT := Rect2(50, 524, 630, 134)
const MENUS := [
	["nav.team", "teamManagementDialog"],
	["nav.stats", "coachStatisticsDialog"], ["nav.inventory", "coachInventoryDialog"],
	["nav.ladder", "ladderInformationDialog"], ["nav.calendar", "calendarDialog"],
	["nav.achievements", "achievementDialog"], ["nav.social", "socialDialog"],
	["nav.help", "tooltipDialog"],
]
const ACTIONS := [
	["lobby.action.practice", "practice", "lobby.action.practice.tip"],
	["lobby.action.fight", "fight", "lobby.action.fight.tip"],
	["lobby.action.quick", "quick", "lobby.action.quick.tip"],
	["lobby.action.evo", "evo", "lobby.action.evo.tip"],
	["lobby.action.duo", "duo", "lobby.action.duo.tip"],
	["lobby.action.team", "team", "lobby.action.team.tip"],
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
var _dir := Direction8.FRONT    # wire dir the coach sprite faces
var _title: Label
var _subtitle: Label
var _hint: Label
var _menu_buttons: Array = []
var _actions: Array[Button] = []
var _social_btn: Button


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
	_spr.scale = Vector2(2.5, 2.5)
	_box.add_child(_spr)
	_bubble = _label(Rect2(70, 460, 260, 30), "", 16)
	_title = _label(Rect2(400, 159, 824, 32), "", 24)
	for i in range(ACTIONS.size()):
		var row: Array = ACTIONS[i]
		var r := Rect2(400 + (i % 3) * 280, 210 if i < 3 else 352, 264, 126 if i < 3 else 92)
		var b := _button(r, "", func(): action_requested.emit(str(row[1])), 24)
		_actions.append(b)
	_subtitle = _label(Rect2(400, 456, 824, 30), "", 16)
	# Coach rotation: << turns the paper-doll one step anticlockwise, >> the
	# other way. Purely cosmetic — the direction is a qc_0 index like in
	# retail's coach-creation screen.
	var prev := _button(Rect2(60, 400, 44, 34), "«",
		func(): _rotate(-1), 18)
	prev.tooltip_text = _t("lobby.rotate.tip")
	var next := _button(Rect2(296, 400, 44, 34), "»",
		func(): _rotate(1), 18)
	next.tooltip_text = _t("lobby.rotate.tip")
	_social_btn = _button(Rect2(120, 90, 120, 40), "",
		func(): dialog_requested.emit("socialDialog"), 16)
	var icons := ImageTexture.create_from_image(Image.load_from_file(
		ProjectSettings.globalize_path("res://assets/ui/lobby_icons.png")))
	for i in range(MENUS.size()):
		var entry: Array = MENUS[i]
		var button := _button(Rect2(732 + (i % 3) * 164, 526 + (i / 3) * 43, 158, 37),
			"", func(): dialog_requested.emit(str(entry[1])), 14)
		var icon := AtlasTexture.new()
		icon.atlas = icons
		icon.region = Rect2(i * 32, 0, 32, 32)
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 20)
		_menu_buttons.append(button)
	_hint = _label(Rect2(40, 672, 650, 24), "", 13)
	resized.connect(_relayout)
	I18n.locale_changed.connect(func(_l): _retranslate())
	_retranslate()


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
	if model_name == "localCoach":
		_sync()


func _sync() -> void:
	var coach: Variant = _model.get_value("localCoach")
	if not coach is Dictionary:
		return
	_name.text = str(coach.get("name", ""))
	_level.text = I18n.t("lobby.level", {"n": int(coach.get("level", 0))})
	# actorDirection is a qc_0 wire dir the rest of the client already writes
	# (creation screen arrows). Honor it when present.
	_dir = int(coach.get("actorDirection", _dir)) & 7
	var look := "%s/%s/%s/%d" % [coach.get("sex", 0), coach.get("skin", 0),
		coach.get("hair", 0), _dir]
	if look != _look:
		_look = look
		_spr.tints = Palettes.coach_tints(int(coach.get("skin", 0)), int(coach.get("hair", 0)))
		var lib := "res://assets/anims/coach_700%d" % int(coach.get("sex", 0))
		if not Direction8.load_idle(_spr, lib, _dir):
			Direction8.load_idle_any(_spr, lib)


func _rotate(delta: int) -> void:
	_dir = (_dir + delta) & 7
	_look = ""
	_sync()
	if _model != null:
		var coach: Variant = _model.get_value("localCoach")
		if coach is Dictionary:
			_model.set_value("localCoach", _dir, "actorDirection")
	coach_rotated.emit(delta)


func _retranslate() -> void:
	_title.text = _t("lobby.title")
	_subtitle.text = _t("lobby.subtitle")
	_hint.text = _t("lobby.chat_hint")
	for i in range(_actions.size()):
		_actions[i].text = _t(str(ACTIONS[i][0]))
		_actions[i].tooltip_text = _t(str(ACTIONS[i][2]))
	for i in range(_menu_buttons.size()):
		_menu_buttons[i].text = _t(str(MENUS[i][0]))
		_menu_buttons[i].tooltip_text = _t(str(MENUS[i][0]))
	if _social_btn != null:
		_social_btn.text = _t("lobby.social")


static func _t(key: String, args: Dictionary = {}) -> String:
	return I18n.t(key, args)


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
