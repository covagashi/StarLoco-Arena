class_name PippopLobby
extends Control
## The hub (S20B, 2026-10-24). Replaces the 2026-10-05 lobby-first wireframe
## (coach left, six actions centre, nine menus below), which put four ways to
## the same fight on one screen. Now: a top bar (logo; Estadísticas, Social,
## Ayuda), the coach on the left, one card per mode the owner kept (Historia,
## Ranking, Torneos) with what it is, what it pays and which team plays, and
## the chat plus the six everyday panels below. Built for 1280x720 scaled,
## mouse, keyboard and pad (the Ally).
##
## Reads `localCoach` and `hub` {story:{titulars, bench}, ranked:{teams:[{id,
## name}], selected}, tourn:{registered, label, search_tid}} from the model;
## emits action_requested(evo|fight|practice|ghost|team_story|team_elite|
## tourn_search|cancel_search), dialog_requested(name) and team_picked(id).

signal action_requested(action: String)
signal dialog_requested(dialog: String)
signal coach_rotated(delta: int)
signal team_picked(preset_id: int)

const Direction8 := preload("res://src/util/direction8.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const Features := preload("res://src/features.gd")
const REF := Vector2(1280, 720)
const CHAT_RECT := Rect2(50, 524, 630, 134)
const CHAT_FRAME := Rect2(40, 512, 650, 182)
const COACH_RECT := Rect2(40, 84, 320, 416)
const CARDS_RECT := Rect2(380, 84, 860, 416)
const MENU_RECT := Rect2(720, 512, 520, 182)
## Every lobby menu: [label key, dialog, place]. "nav" = the six big buttons
## below; "top" = the top bar. The order is the icon atlas's (slot i + 1).
const MENUS := [
	["nav.team", "teamManagementDialog", "nav"],
	["nav.stats", "coachStatisticsDialog", "top"],
	["nav.inventory", "coachInventoryDialog", "nav"],
	["nav.ladder", "ladderInformationDialog", "nav"],
	["nav.calendar", "calendarDialog", "nav"],
	["nav.achievements", "achievementDialog", "nav"],
	["nav.social", "socialDialog", "top"],
	["nav.help", "tooltipDialog", "top"],
	["nav.city", "cityDialog", "nav"],
]
## The three mode cards: [id, title key].
const MODES := [["story", "hub.story"], ["ranked", "hub.ranked"], ["tourn", "hub.tourn"]]

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
var _subtitle: Label            # the search card's heading
var _hint: Label
var _menu_buttons: Array = []
var _actions: Array[Button] = []   # every button that starts something
var _cards := {}                # mode id -> {root, title, phrase, wins, team, warn, play, extra, pick}
var _cancel_search: Button
var _ghost_offer: Button
var _searching := false
var _search_panel: Panel
var _search_mode: Label
var _search_clock: Label
var _search_started := 0
var _last_action := ""
var _ready_state := false
var _sky: Control
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Control.new()
	_box.size = REF
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_box.theme = UiStyle.theme()
	_box.add_child(UiStyle.backdrop(REF))
	# the sky the fireworks play in: over the backdrop, behind the windows
	_sky = Control.new()
	_sky.size = REF
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.clip_contents = true
	_box.add_child(_sky)
	_font = UiStyle.title_font()
	for r in [COACH_RECT, CHAT_FRAME, MENU_RECT]:
		_window(r)
	# top bar: one line of logo, the three occasional panels on the right
	var brand := _label(Rect2(40, 20, 420, 44), "PIPPOP ARENA", 34)
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	brand.add_theme_constant_override("outline_size", 10)
	brand.add_theme_color_override("font_color", UiStyle.GOLD)
	# the coach
	_name = _label(Rect2(60, 98, 280, 36), "", 25)
	_level = _label(Rect2(60, 134, 280, 26), "", 16)
	var pedestal := Panel.new()
	pedestal.position = Vector2(95, 408)
	pedestal.size = Vector2(210, 40)
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ps := UiStyle.box(UiStyle.PAPER, UiStyle.INK, 2, 0)
	ps.set_corner_radius_all(20)
	ps.anti_aliasing = true
	pedestal.add_theme_stylebox_override("panel", ps)
	_box.add_child(pedestal)
	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = Vector2(200, 425)
	_spr.scale = Vector2(2.5, 2.5)
	_box.add_child(_spr)
	# « » turn the paper-doll (a qc_0 wire dir, as in coach creation)
	var prev := _button(Rect2(60, 448, 52, 40), "«", func(): _rotate(-1), 20)
	prev.tooltip_text = _t("lobby.rotate.tip")
	var next := _button(Rect2(288, 448, 52, 40), "»", func(): _rotate(1), 20)
	next.tooltip_text = _t("lobby.rotate.tip")
	_bubble = _label(Rect2(112, 456, 176, 30), "", 15)
	# the mode cards
	var w := (CARDS_RECT.size.x - 32) / 3.0
	for i in MODES.size():
		_card(str(MODES[i][0]), Rect2(CARDS_RECT.position.x + i * (w + 16),
			CARDS_RECT.position.y, w, CARDS_RECT.size.y))
	_search_card()
	# menus: six big buttons below, three in the top bar
	var icons := ImageTexture.create_from_image(
		AssetPaths.load_image("ui/lobby_icons.png"))
	var nav_i := 0
	var top_i := 0
	for i in range(MENUS.size()):
		var entry: Array = MENUS[i]
		var r: Rect2
		if str(entry[2]) == "nav":
			r = Rect2(MENU_RECT.position.x + 14 + (nav_i % 3) * 166,
				MENU_RECT.position.y + 16 + (nav_i / 3) * 80, 158, 70)
			nav_i += 1
		else:
			r = Rect2(REF.x - 40 - (3 - top_i) * 160 + 10, 22, 150, 42)
			top_i += 1
		var button := _button(r, "", func(): dialog_requested.emit(str(entry[1])),
			15)
		button.name = "Menu_" + str(entry[1])
		var icon := AtlasTexture.new()
		icon.atlas = icons
		# slot 0 of the atlas is retail's "Menu" entry (it lives on Esc)
		icon.region = Rect2((i + 1) * 32, 0, 32, 32)
		button.icon = icon
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 26 if str(entry[2]) == "nav" else 20)
		if str(entry[2]) == "nav":
			# a tile: the icon over the label, so "Clasificación" no longer
			# squeezes the icon out
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		_menu_buttons.append(button)
	_hint = _label(Rect2(40, 697, 650, 22), "", 13)
	_wire_focus()
	resized.connect(_relayout)
	I18n.locale_changed.connect(func(_l): _retranslate())
	_retranslate()


## Pad and keyboard paths (S20B): Godot's guess sent "right" from Ranking
## to Inventario. Cards go left/right between their buttons, down from a
## card's button leaves for the panels below, up from those returns.
func _wire_focus() -> void:
	var ids := ["story", "ranked", "tourn"]
	var nav: Array = []
	var top: Array = []
	for i in MENUS.size():
		(nav if str(MENUS[i][2]) == "nav" else top).append(_menu_buttons[i])
	for i in ids.size():
		var c: Dictionary = _cards[ids[i]]
		var left: Dictionary = _cards[ids[maxi(i - 1, 0)]]
		var right: Dictionary = _cards[ids[mini(i + 1, ids.size() - 1)]]
		for k in ["extra", "play"]:
			var b: Button = c[k]
			b.focus_neighbor_left = b.get_path_to(left[k])
			b.focus_neighbor_right = b.get_path_to(right[k])
		c.extra.focus_neighbor_bottom = c.extra.get_path_to(c.play)
		c.play.focus_neighbor_top = c.play.get_path_to(c.extra)
		c.play.focus_neighbor_bottom = c.play.get_path_to(nav[mini(i, 2)])
		c.extra.focus_neighbor_top = c.extra.get_path_to(top[mini(i, 2)])
	for j in nav.size():
		if j < 3:
			nav[j].focus_neighbor_top = nav[j].get_path_to(_cards[ids[j]].play)
	for j in top.size():
		top[j].focus_neighbor_bottom = top[j].get_path_to(_cards[ids[j]].extra)


func _window(r: Rect2) -> Panel:
	var w := Panel.new()
	w.position = r.position
	w.size = r.size
	w.mouse_filter = Control.MOUSE_FILTER_IGNORE
	w.add_theme_stylebox_override("panel", UiStyle.window())
	_box.add_child(w)
	return w


## One mode card: title, what it is, what you win, which team plays, a
## warning line, a secondary action and the big one.
func _card(id: String, r: Rect2) -> void:
	var root := _window(r)
	root.name = "Card_" + id
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	var c := {"root": root}
	var inner := r.size.x - 36
	c.title = _in(root, Rect2(18, 16, inner, 40), 30, UiStyle.GOLD, true)
	c.phrase = _in(root, Rect2(18, 60, inner, 70), 15, UiStyle.INK)
	c.wins_cap = _in(root, Rect2(18, 134, inner, 18), 12, UiStyle.MUTED)
	c.wins = _in(root, Rect2(18, 152, inner, 44), 15, UiStyle.INK)
	c.team_cap = _in(root, Rect2(18, 200, inner, 18), 12, UiStyle.MUTED)
	c.team = _in(root, Rect2(18, 218, inner, 40), 15, UiStyle.INK)
	c.warn = _in(root, Rect2(18, 262, inner, 40), 13, UiStyle.MUTED)
	if id == "ranked":
		var pick := OptionButton.new()
		pick.position = Vector2(18, 218)
		pick.size = Vector2(inner, 38)
		pick.name = "TeamPick"
		pick.add_theme_font_size_override("font_size", 15)
		pick.item_selected.connect(func(i): team_picked.emit(int(pick.get_item_id(i))))
		root.add_child(pick)
		c.pick = pick
	var extra := Button.new()
	extra.position = Vector2(18, 306)
	extra.size = Vector2(inner, 38)
	_style_button(extra, 15)
	extra.name = "Extra_" + id
	extra.pressed.connect(func(): _card_pressed(id, true))
	root.add_child(extra)
	c.extra = extra
	var play := Button.new()
	play.position = Vector2(18, 352)
	play.size = Vector2(inner, 50)
	_style_button(play, 24)
	UiStyle.primary(play, 24)
	play.name = "Play_" + id
	play.pressed.connect(func(): _card_pressed(id, false))
	root.add_child(play)
	c.play = play
	_actions.append(play)
	_actions.append(extra)
	_cards[id] = c


func _in(parent: Control, r: Rect2, size: int, colour: Color, title := false) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title:
		l.add_theme_font_override("font", _font)
		l.add_theme_constant_override("outline_size", 6)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	parent.add_child(l)
	return l


## A card's button: what it does depends on the hub model (no team yet →
## go make one; a tournament search open → search it).
func _card_pressed(id: String, extra: bool) -> void:
	var hub := _hub()
	match id:
		"story":
			if extra:
				_emit("practice")
			elif int(hub.get("story", {}).get("titulars", 0)) <= 0:
				_emit("team_story")
			else:
				_emit("evo")
		"ranked":
			if extra:
				_emit("ghost")
			elif hub.get("ranked", {}).get("teams", []).is_empty():
				_emit("team_elite")
			else:
				_emit("fight")
		"tourn":
			if extra or int(hub.get("tourn", {}).get("search_tid", -1)) < 0:
				dialog_requested.emit("calendarDialog")
			else:
				_emit("tourn_search")


func _emit(action: String) -> void:
	_last_action = action
	action_requested.emit(action)


## Matchmaking: a card over the mode cards with the mode, a running clock
## and a full-size Cancelar (Esc too); after 20 s of a ranked search, an
## offer to fight a ghost instead (S20B: with few players, the queue is
## often empty).
func _search_card() -> void:
	_search_panel = Panel.new()
	_search_panel.position = CARDS_RECT.position
	_search_panel.size = CARDS_RECT.size
	_search_panel.add_theme_stylebox_override("panel",
		UiStyle.box(UiStyle.PAPER, UiStyle.RIM_HI, 2, 16))
	_search_panel.visible = false
	_box.add_child(_search_panel)
	var sw := CARDS_RECT.size.x
	_subtitle = _panel_label(Rect2(0, 40, sw, 44), "lobby.searching", 34)
	_subtitle.name = "SearchHeading"
	_search_mode = _panel_label(Rect2(0, 90, sw, 28), "", 19)
	_search_mode.add_theme_color_override("font_color", UiStyle.MUTED)
	_search_clock = _panel_label(Rect2(0, 128, sw, 90), "0:00", 76)
	_search_clock.name = "SearchClock"
	_search_clock.add_theme_color_override("font_color", UiStyle.GOLD)
	_cancel_search = Button.new()
	_cancel_search.position = Vector2((sw - 300) / 2.0, 236)
	_cancel_search.size = Vector2(300, 60)
	_style_button(_cancel_search, 24)
	UiStyle.primary(_cancel_search, 24)
	_cancel_search.pressed.connect(func(): action_requested.emit("cancel_search"))
	_cancel_search.name = "CancelSearch"
	_search_panel.add_child(_cancel_search)
	_ghost_offer = Button.new()
	_ghost_offer.position = Vector2((sw - 300) / 2.0, 312)
	_ghost_offer.size = Vector2(300, 44)
	_style_button(_ghost_offer, 17)
	_ghost_offer.pressed.connect(func(): _emit("ghost"))
	_ghost_offer.name = "GhostOffer"
	_ghost_offer.visible = false
	_search_panel.add_child(_ghost_offer)


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
	_sync_hub()
	_relayout()


## Matchmaking state: "Buscando rival…" + Cancelar while a search runs.
func set_searching(on: bool) -> void:
	if on and not _searching:
		_search_started = Time.get_ticks_msec()
	_searching = on
	_search_panel.visible = on
	for id in _cards:
		_cards[id].root.visible = not on
	_ghost_offer.visible = false
	_subtitle.text = _t("lobby.searching") if on else _t("lobby.subtitle")
	_search_mode.text = _search_mode_text()
	_tick_clock()
	if on:
		_cancel_search.grab_focus()


func _search_mode_text() -> String:
	match _last_action:
		"evo": return _t("hub.story")
		"fight": return _t("hub.ranked")
		"tourn_search": return _t("hub.tourn")
	return ""


func _process(_dt: float) -> void:
	if _searching:
		_tick_clock()
		# a ranked queue that stays empty: offer a ghost (S20B)
		if not _ghost_offer.visible and _last_action == "fight" \
				and Time.get_ticks_msec() - _search_started >= 20000:
			_ghost_offer.visible = true


func _tick_clock() -> void:
	var secs := maxi(0, (Time.get_ticks_msec() - _search_started) / 1000)
	_search_clock.text = "%d:%02d" % [secs / 60, secs % 60]


## Esc cancels a running search when no window is open (the dialog layer
## takes Esc first to close its windows).
func _unhandled_key_input(event: InputEvent) -> void:
	if _searching and event.is_pressed() and not event.is_echo() \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		action_requested.emit("cancel_search")


func set_actions_ready(ready: bool) -> void:
	_ready_state = ready
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
	elif model_name == "hub":
		_sync_hub()


func _hub() -> Dictionary:
	var v: Variant = _model.get_value("hub") if _model != null else null
	return v if v is Dictionary else {}


## The cards' live lines: which team plays, the next tournament, and what the
## big button does when there is nothing to play with yet.
func _sync_hub() -> void:
	if _cards.is_empty():
		return
	var hub := _hub()
	var story: Dictionary = hub.get("story", {})
	var n := int(story.get("titulars", 0))
	var c: Dictionary = _cards.story
	c.team.text = _t("hub.story.team", {"n": n, "bench": int(story.get("bench", 0))}) if n > 0 else _t("hub.story.no_team")
	c.play.text = _t("hub.play") if n > 0 else _t("hub.story.recruit")
	var ranked: Dictionary = hub.get("ranked", {})
	var teams: Array = ranked.get("teams", [])
	c = _cards.ranked
	var pick: OptionButton = c.pick
	pick.clear()
	for t in teams:
		pick.add_item(str(t.get("name", "")), int(t.get("id", 0)))
	pick.visible = not teams.is_empty()
	var sel := pick.get_item_index(int(ranked.get("selected", -1)))
	if sel >= 0:
		pick.select(sel)
	c.team.text = "" if not teams.is_empty() else _t("hub.ranked.no_team")
	c.play.text = _t("hub.play") if not teams.is_empty() else _t("hub.ranked.make_team")
	var tourn: Dictionary = hub.get("tourn", {})
	c = _cards.tourn
	var label := str(tourn.get("label", ""))
	c.team.text = label if label != "" else _t("hub.tourn.none")
	var open := int(tourn.get("search_tid", -1)) >= 0
	c.play.text = _t("hub.tourn.search") if open else _t("hub.tourn.view")
	c.extra.visible = open


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
	# write the model FIRST: _sync() reads actorDirection back, and calling it
	# before the write put the old direction back, so « » did nothing (S20)
	if _model != null and _model.get_value("localCoach") is Dictionary:
		_model.set_value("localCoach", _dir, "actorDirection")
	_sync()
	coach_rotated.emit(delta)


func _retranslate() -> void:
	_subtitle.text = _t("lobby.searching") if _searching else _t("lobby.subtitle")
	_cancel_search.text = _t("lobby.cancel_search")
	_ghost_offer.text = _t("hub.ghost_offer")
	_search_mode.text = _search_mode_text()
	_hint.text = _t("lobby.chat_hint")
	for m in MODES:
		var c: Dictionary = _cards[str(m[0])]
		var key := str(m[1])
		c.title.text = _t(key)
		c.phrase.text = _t(key + ".phrase")
		c.wins_cap.text = _t("hub.wins").to_upper()
		c.wins.text = _t(key + ".wins")
		c.team_cap.text = _t("hub.team").to_upper()
		c.warn.text = _t(key + ".warn")
	_cards.story.extra.text = _t("hub.story.practice")
	_cards.story.extra.tooltip_text = _t("lobby.action.practice.tip")
	_cards.ranked.extra.text = _t("hub.ranked.ghost")
	_cards.ranked.extra.tooltip_text = _t("hub.ranked.ghost.tip")
	_cards.tourn.extra.text = _t("hub.tourn.view")
	for i in range(_menu_buttons.size()):
		_menu_buttons[i].text = _t(str(MENUS[i][0]))
		_menu_buttons[i].tooltip_text = _t(str(MENUS[i][0]))
	_sync_hub()


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


## A centred label inside the search card (not on _box).
func _panel_label(r: Rect2, key: String, font_size: int) -> Label:
	var label := Label.new()
	label.position = r.position
	label.size = r.size
	label.text = _t(key) if key != "" else ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_search_panel.add_child(label)
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
