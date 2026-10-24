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
const CHAT_FRAME := Rect2(40, 512, 650, 182)
const COACH_RECT := Rect2(40, 150, 320, 350)
const MENU_RECT := Rect2(720, 512, 510, 182)
const UiStyle := preload("res://src/ui/ui_style.gd")
const MENUS := [
	["nav.team", "teamManagementDialog"],
	["nav.stats", "coachStatisticsDialog"], ["nav.inventory", "coachInventoryDialog"],
	["nav.ladder", "ladderInformationDialog"], ["nav.calendar", "calendarDialog"],
	["nav.achievements", "achievementDialog"], ["nav.social", "socialDialog"],
	["nav.help", "tooltipDialog"], ["nav.city", "cityDialog"],
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
var _cancel_search: Button
var _searching := false
var _sky: Control
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Control.new()
	_box.size = REF
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	# the stone backdrop and native windows where the baked slabs used to
	# be; the controls take the shared theme (src/ui/ui_style.gd).
	_box.theme = UiStyle.theme()
	var bd := UiStyle.backdrop(REF)
	_box.add_child(bd)
	# the sky the fireworks play in: over the backdrop, behind the windows
	_sky = Control.new()
	_sky.size = REF
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.clip_contents = true
	_box.add_child(_sky)
	for r in [COACH_RECT, CHAT_FRAME, MENU_RECT]:
		var w := Panel.new()
		w.position = r.position
		w.size = r.size
		w.mouse_filter = Control.MOUSE_FILTER_IGNORE
		w.add_theme_stylebox_override("panel", UiStyle.window())
		_box.add_child(w)
	var pedestal := Panel.new()
	pedestal.position = Vector2(95, 426)
	pedestal.size = Vector2(210, 40)
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := UiStyle.box(UiStyle.PAPER, UiStyle.INK, 2, 0)
	ps.set_corner_radius_all(20)
	ps.anti_aliasing = true
	pedestal.add_theme_stylebox_override("panel", ps)
	_box.add_child(pedestal)
	_font = UiStyle.title_font()
	var brand := _label(Rect2(0, 14, REF.x, 34), "PIPPOP", 26)
	brand.add_theme_constant_override("outline_size", 8)
	brand.add_theme_color_override("font_color", UiStyle.GOLD)
	var logo := _label(Rect2(0, 52, REF.x, 90), "ARENA", 72)
	logo.add_theme_constant_override("outline_size", 12)
	logo.add_theme_color_override("font_color", UiStyle.GOLD)
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
		if str(row[1]) == "fight":
			UiStyle.primary(b, 28)
		_actions.append(b)
	_subtitle = _label(Rect2(400, 456, 824, 30), "", 16)
	# matchmaking in progress (S18): the subtitle says so and Cancelar stops
	# it — before, only the hidden debug row could cancel a search
	_cancel_search = _button(Rect2(1080, 452, 144, 38), "",
		func(): action_requested.emit("cancel_search"), 16)
	_cancel_search.name = "CancelSearch"
	_cancel_search.visible = false
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
	var icons := ImageTexture.create_from_image(
		AssetPaths.load_image("ui/lobby_icons.png"))
	for i in range(MENUS.size()):
		var entry: Array = MENUS[i]
		var button := _button(Rect2(732 + (i % 3) * 164, 536 + (i / 3) * 50, 158, 40),
			"", func(): dialog_requested.emit(str(entry[1])), 14)
		var icon := AtlasTexture.new()
		icon.atlas = icons
		# Slot 0 of the atlas is retail's "Menu" entry, which the lobby
		# dropped (it lives on Esc): the nav menus start at slot 1.
		icon.region = Rect2((i + 1) * 32, 0, 32, 32)
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 20)
		_menu_buttons.append(button)
	_hint = _label(Rect2(40, 697, 650, 22), "", 13)
	resized.connect(_relayout)
	I18n.locale_changed.connect(func(_l): _retranslate())
	_retranslate()


## A firework on the lobby sky (22094; S18). kind/colour come from the card
## (cards.json fwType / fwColour): see firework_fx.gd.
func firework(kind: int, colour: Color) -> Node2D:
	var fx := preload("res://src/ui/firework_fx.gd").new()
	fx.kind = kind
	fx.colour = colour
	var x := _rng.randf_range(80.0, REF.x - 80.0)
	fx.burst_at = Vector2(x, _rng.randf_range(60.0, 220.0))
	fx.ground = Vector2(x + _rng.randf_range(-60.0, 60.0), REF.y - 40.0)
	fx.name = "Firework"
	_sky.add_child(fx)
	return fx


func _ready() -> void:
	_relayout()


func bind_model(model, chat: Control) -> void:
	_model = model
	_chat = chat
	if is_instance_valid(_chat):
		_chat.theme = UiStyle.theme(3)
		var display: Control = _chat.get_node_or_null("Display")
		if display != null:
			display.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.PAPER, UiStyle.PAPER, 0, 8))
	_model.changed.connect(_on_model_changed)
	_sync()
	_relayout()


## Matchmaking state: "Buscando rival…" + Cancelar while a search runs.
func set_searching(on: bool) -> void:
	_searching = on
	_cancel_search.visible = on
	_subtitle.text = _t("lobby.searching") if on else _t("lobby.subtitle")


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
		var lib := "anims/coach_700%d" % int(coach.get("sex", 0))
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
	_subtitle.text = _t("lobby.searching") if _searching else _t("lobby.subtitle")
	_cancel_search.text = _t("lobby.cancel_search")
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
	label.add_theme_constant_override("outline_size", 6)
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
