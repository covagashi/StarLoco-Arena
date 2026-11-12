class_name PippopLobby
extends Control
## The hub, as in the S45 mockup ("3 · Lobby"): the arena behind and the
## coach large in the middle of it; top left who you are (level medallion,
## name ribbon), top centre the season, top right your coins and the three
## occasional panels as medallions; a rail of medallions on the left for the
## six everyday panels; on the right one illustrated tile per mode the owner
## kept (Historia, Ranking, Torneos, S20B), cut on the diagonal, and the big
## "¡A LUCHAR!" (Ranking straight away); the chat at the bottom left.
## Built for 1280x720 scaled, mouse, keyboard and pad (the Ally).
##
## Reads `localCoach` (its `worn` cards dress the 3D coach, S35c), `hub`
## {story:{titulars, bench}, ranked:{teams:[{id, name}], selected},
## tourn:{registered, label, search_tid}}, `season` {number, ends} and
## `wallet` {currency type: amount} from the model; emits
## action_requested(evo|story|fight|practice|ghost|team_story|team_elite|
## tourn_search|cancel_search), dialog_requested(name) and team_picked(id).

signal action_requested(action: String)
signal dialog_requested(dialog: String)
signal coach_rotated(delta: int)
signal team_picked(preset_id: int)

const Direction8 := preload("res://src/util/direction8.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const Features := preload("res://src/features.gd")
const REF := Vector2(1280, 720)
const CHAT_RECT := Rect2(112, 556, 520, 140)
const TILES := Vector2(680, 76)        # the tiles' corner (580 x 506)
const R_SEARCH := Rect2(680, 76, 580, 506)
const COACH_FOOT := Vector2(392, 548)
const COACH_SCALE := 5.6
const TOKENS := 1                      # wallet slot of the Card Master tokens
const PESETAS := 10                    # …and of the pesetas (domain.CurrencyPesetas)
## Every lobby menu: [label key, dialog, place]. "nav" = the rail on the
## left; "top" = medallions top right. The order is the icon atlas's (slot i + 1).
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
## The three mode tiles: [id, title key, rect inside TILES].
const MODES := [["story", "hub.story", Rect2(0, 0, 580, 250)],
	["ranked", "hub.ranked", Rect2(0, 270, 286, 236)],
	["tourn", "hub.tourn", Rect2(298, 270, 282, 236)]]

var _box: Control
var _font: FontFile
var _name: Label
var _level: Label
var _bubble: Label
var _spr
var _model
var _chat: Control
var _look := ""
var _hair_fx := 0     # S37: the hair effect on the figure now
var _hair_on: Object  # …and the figure it was put on (a rebuild drops it)
var _dir := Direction8.FRONT    # wire dir the coach sprite faces
var _subtitle: Label            # the search card's heading
var _hint: Label
var _menu_buttons: Array = []
var _actions: Array[Button] = []   # every button that starts something
var _cards := {}                # mode id -> {root, title, phrase, wins, team, warn, play, extra, pick}
var _cancel_search: Button
var _ghost_offer: Button
var _quick: Button
var _quick_hint: Label
var _searching := false
var _search_panel: Control
var _search_mode: Label
var _search_clock: Label
var _search_started := 0
var _last_action := ""
var _ready_state := false
var _sky: Control
var _season: PanelContainer
var _season_n: Label
var _season_left: Label
var _coins := {}                # currency type -> Label
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Control.new()
	_box.size = REF
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.clip_contents = true
	add_child(_box)
	_box.theme = UiStyle.theme()
	_font = UiStyle.title_font()
	_scene()
	# the sky the fireworks play in: over the arena, behind everything else
	_sky = Control.new()
	_sky.size = REF
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.clip_contents = true
	_box.add_child(_sky)
	_coach()
	_identity()
	_season_ribbon()
	var icons := ImageTexture.create_from_image(AssetPaths.load_image("ui/lobby_icons.png"))
	_coins_and_top(icons)
	_rail(icons)
	for m in MODES:
		_card(str(m[0]), m[2])
	_quick = Button.new()
	_quick.name = "Quick"
	_quick.size = Vector2(250, 62)
	_quick.position = TILES + Vector2(580 - 8 - 250, 518)
	UiStyle.primary(_quick, 30)
	_quick.pressed.connect(func(): _card_pressed("ranked", false))
	_box.add_child(_quick)
	_actions.append(_quick)
	_quick_hint = Label.new()
	_quick_hint.position = TILES + Vector2(20, 532)
	_quick_hint.size = Vector2(300, 40)
	_quick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_shadowed(_quick_hint, 14, Color("c9cdeb"))
	_box.add_child(_quick_hint)
	_search_card()
	_hint = Label.new()
	_hint.position = Vector2(CHAT_RECT.position.x, 699)
	_hint.size = Vector2(CHAT_RECT.size.x, 18)
	_shadowed(_hint, 12, UiStyle.MUTED)
	_box.add_child(_hint)
	_wire_focus()
	resized.connect(_relayout)
	I18n.locale_changed.connect(func(_l): _retranslate())
	_retranslate()


## The arena (background-position 30% 40%, 1500 px wide), its shade, the
## darker floor under the chat and the warm glow at the coach's feet.
func _scene() -> void:
	var night := ColorRect.new()
	night.color = UiStyle.NIGHT
	night.size = REF
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(night)
	var tex := UiStyle.scene_texture("arena_bg")
	if tex != null:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		var sz := Vector2(1500, 1500.0 * tex.get_height() / tex.get_width())
		bg.size = sz
		bg.position = Vector2(0.3 * (REF.x - sz.x), 0.4 * (REF.y - sz.y))
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(bg)
	UiStyle.vignette(_box, REF, Vector2(410, 432), Vector2(896, 648),
		Color(0.07, 0.08, 0.16, 0.0), Color(0.047, 0.055, 0.118, 0.92))
	var floor_shade := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(0.047, 0.055, 0.118, 0.0))
	g.gradient.set_color(1, Color(0.047, 0.055, 0.118, 0.85))
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	floor_shade.texture = g
	floor_shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	floor_shade.position = Vector2(0, REF.y - 180)
	floor_shade.size = Vector2(REF.x, 180)
	floor_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(floor_shade)
	UiStyle.vignette(_box, REF, Vector2(392, 540), Vector2(190, 50),
		Color(1.0, 0.67, 0.35, 0.55), Color(1.0, 0.47, 0.24, 0.0))


## The 3D coach, large, with the chevrons that turn it (a qc_0 wire dir, as
## in coach creation) and the bubble its emotes show.
func _coach() -> void:
	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = COACH_FOOT
	_spr.scale = Vector2(COACH_SCALE, COACH_SCALE)
	_box.add_child(_spr)
	for left in [true, false]:
		var b := UiStyle.chevron_button(left)
		b.name = "TurnLeft" if left else "TurnRight"
		b.scale = Vector2(0.6, 0.6)
		b.position = COACH_FOOT + Vector2(-170 if left else 138, -96)
		b.tooltip_text = _t("lobby.rotate.tip")
		b.pressed.connect(_rotate.bind(-1 if left else 1))
		_box.add_child(b)
	_bubble = Label.new()
	_bubble.position = COACH_FOOT + Vector2(-160, -600)
	_bubble.size = Vector2(320, 40)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.title(_bubble, 22)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_bubble)


## Top left: a medallion with the coach's level, the name on a pop ribbon
## and the level chip under it.
func _identity() -> void:
	var medal := Control.new()
	medal.position = Vector2(18, 14)
	medal.size = Vector2(74, 79)
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := UiStyle.kit_texture("medal")
	medal.draw.connect(func():
		if tex != null:
			medal.draw_texture_rect(tex, Rect2(0, 0, 74, 79), false)
		var c := Vector2(37, 37)
		medal.draw_arc(c + Vector2(0, -8), 8, 0, TAU, 24, UiStyle.INK, 3.0, true)
		medal.draw_arc(c + Vector2(0, 20), 17, PI, TAU, 24, UiStyle.INK, 3.0, true))
	_box.add_child(medal)
	var rib := PanelContainer.new()
	rib.position = Vector2(80, 18)
	rib.custom_minimum_size = Vector2(150, 34)
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon())
	_name = Label.new()
	_name.name = "CoachName"
	UiStyle.title(_name, 22)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(_name)
	_box.add_child(rib)
	_box.move_child(rib, medal.get_index())   # the medallion overlaps the ribbon
	var chip := PanelContainer.new()
	chip.position = Vector2(98, 58)
	var cs := UiStyle.box(UiStyle.SUN, UiStyle.RIM, 2, 2)
	cs.set_corner_radius_all(6)
	cs.content_margin_left = 8
	cs.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", cs)
	_level = Label.new()
	_level.name = "CoachLevel"
	_level.add_theme_font_override("font", UiStyle.bold(900))
	_level.add_theme_font_size_override("font_size", 12)
	_level.add_theme_color_override("font_color", Color("1a1206"))
	chip.add_child(_level)
	_box.add_child(chip)


## Top centre: the season (60031) on a navy ribbon, hidden without one.
func _season_ribbon() -> void:
	_season = PanelContainer.new()
	_season.name = "Season"
	_season.add_theme_stylebox_override("panel", UiStyle.ribbon("navy"))
	_season.custom_minimum_size.y = 40
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_season_n = Label.new()
	UiStyle.title(_season_n, 20, UiStyle.SUN)
	_season_n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_season_n)
	_season_left = Label.new()
	_season_left.add_theme_font_override("font", UiStyle.bold(900))
	_season_left.add_theme_font_size_override("font_size", 14)
	_season_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_season_left)
	_season.add_child(row)
	_season.visible = false
	_season.resized.connect(func():
		_season.position = Vector2((REF.x - _season.size.x) / 2.0, 12))
	_box.add_child(_season)


## Top right: tokens and pesetas in their capsules, then the three
## occasional panels (Estadísticas, Social, Ayuda) as medallions.
func _coins_and_top(icons: Texture2D) -> void:
	var row := HBoxContainer.new()
	row.name = "TopRight"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 12)
	row.size = Vector2(760, 50)
	row.position = Vector2(REF.x - 16 - 760, 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	for c in [[TOKENS, "F", Color("bfd6ff"), Color("4c8dff"), Color("2453b8"), Color("0b1a45"), "hub.tokens"],
			[PESETAS, "₧", Color("ffe9a0"), Color("ffb020"), Color("c77d08"), Color("5a3a00"), "hub.pesetas"]]:
		row.add_child(_capsule(c))
	for i in MENUS.size():
		var entry: Array = MENUS[i]
		if str(entry[2]) != "top":
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = icons
		atlas.region = Rect2((i + 1) * 32, 0, 32, 32)
		var b := UiStyle.medal_button(46, func(btn: Button):
			btn.draw_texture_rect(atlas, Rect2(10, 10, 26, 26), false))
		b.name = "Menu_" + str(entry[1])
		b.pressed.connect(func(): dialog_requested.emit(str(entry[1])))
		row.add_child(b)
		_menu_buttons.append(b)
	_reorder_menus()


## A coin capsule: the dark pill, the coin overlapping its left end.
func _capsule(c: Array) -> Control:
	var cap := Control.new()
	cap.name = "Coin_%d" % int(c[0])
	cap.custom_minimum_size = Vector2(110, 46)
	cap.mouse_filter = Control.MOUSE_FILTER_PASS
	cap.tooltip_text = _t(str(c[6]))
	var amount := Label.new()
	amount.add_theme_font_override("font", UiStyle.bold(900))
	amount.add_theme_font_size_override("font_size", 16)
	amount.position = Vector2(48, 8)
	amount.size = Vector2(56, 28)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	amount.text = "0"
	cap.add_child(amount)
	_coins[int(c[0])] = amount
	cap.draw.connect(func():
		var w := cap.size.x
		var pill := UiStyle.box(Color(0.047, 0.055, 0.118, 0.85), UiStyle.RIM, 3, 0)
		pill.set_corner_radius_all(18)
		cap.draw_style_box(pill, Rect2(14, 5, w - 14, 36))
		var cc := Vector2(21, 23)
		cap.draw_circle(cc, 21, UiStyle.OUTLINE)
		cap.draw_circle(cc, 18, c[4])
		cap.draw_circle(cc + Vector2(-1, -1), 14, c[3])
		cap.draw_circle(cc + Vector2(-4, -5), 6, Color(c[2], 0.7))
		var f := UiStyle.title_font()
		var s := f.get_string_size(str(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20)
		cap.draw_string(f, cc + Vector2(-s.x / 2.0, 7), str(c[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, c[5]))
	return cap


## The rail of medallions on the left, each with its name under it.
func _rail(icons: Texture2D) -> void:
	var y := 112.0
	for i in MENUS.size():
		var entry: Array = MENUS[i]
		if str(entry[2]) != "nav":
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = icons
		atlas.region = Rect2((i + 1) * 32, 0, 32, 32)
		var b := Button.new()
		b.name = "Menu_" + str(entry[1])
		b.position = Vector2(14, y)
		b.size = Vector2(92, 80)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var e := StyleBoxEmpty.new()
			e.content_margin_top = 58
			b.add_theme_stylebox_override(st, e)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_constant_override("outline_size", 6)
		b.add_theme_color_override("font_outline_color", UiStyle.OUTLINE)
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(col, UiStyle.INK)
		b.add_theme_color_override("font_hover_color", UiStyle.SUN)
		b.add_theme_color_override("font_focus_color", UiStyle.SUN)
		b.clip_text = false
		var medal := UiStyle.kit_texture("medal")
		b.draw.connect(func():
			var r := Rect2(19, 0, 54, 57)
			if b.is_pressed():
				r.position.y += 2
			if medal != null:
				b.draw_texture_rect(medal, r, false,
					Color(1.15, 1.15, 1.15) if b.is_hovered() else Color.WHITE)
			b.draw_texture_rect(atlas, Rect2(r.position + Vector2(13, 13), Vector2(28, 28)), false)
			if b.has_focus():
				b.draw_arc(r.position + Vector2(27, 27), 31, 0, TAU, 40, UiStyle.SUN, 2.5, true))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		b.focus_entered.connect(b.queue_redraw)
		b.focus_exited.connect(b.queue_redraw)
		b.pressed.connect(func(): dialog_requested.emit(str(entry[1])))
		_box.add_child(b)
		_menu_buttons.append(b)
		y += 82.0
	_reorder_menus()


## _menu_buttons in MENUS order (texts and tests index them by it).
func _reorder_menus() -> void:
	var by_name := {}
	for b in _menu_buttons:
		by_name[str(b.name)] = b
	var out: Array = []
	for entry in MENUS:
		var n := "Menu_" + str(entry[1])
		if by_name.has(n):
			out.append(by_name[n])
	_menu_buttons = out


## Pad and keyboard paths (S20B): left/right between the tiles' buttons,
## down from a tile's play leaves for the rail, up from the rail returns.
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
		c.play.focus_neighbor_bottom = c.play.get_path_to(nav[mini(i, nav.size() - 1)])
		c.extra.focus_neighbor_top = c.extra.get_path_to(top[mini(i, 2)])
	for j in nav.size():
		nav[j].focus_neighbor_right = nav[j].get_path_to(_cards[ids[mini(j, 2)]].play)
		if j > 0:
			nav[j].focus_neighbor_top = nav[j].get_path_to(nav[j - 1])
		if j < nav.size() - 1:
			nav[j].focus_neighbor_bottom = nav[j].get_path_to(nav[j + 1])
	for j in top.size():
		top[j].focus_neighbor_bottom = top[j].get_path_to(_cards[ids[mini(j, 2)]].extra)


## One mode tile: art cut on the diagonal, the title, what it is and pays,
## a chip with the team that plays, a secondary action, and the tile itself
## as the big button (its action in the pop pill at the bottom right).
func _card(id: String, r: Rect2) -> void:
	var root := Control.new()
	root.name = "Card_" + id
	root.position = TILES + r.position
	root.size = r.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(root)
	var c := {"root": root}
	var w := r.size.x
	var h := r.size.y
	var cut := func(inset: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(w * 0.05 + inset * 0.6, inset), Vector2(w - inset, inset),
			Vector2(w * 0.95 - inset * 0.6, h - inset), Vector2(inset, h - inset)])
	# the hard shadow and the ink outline
	var frame := Control.new()
	frame.size = r.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(func():
		var sh: PackedVector2Array = cut.call(0.0)
		for i in sh.size():
			sh[i] += Vector2(0, 7)
		frame.draw_colored_polygon(sh, UiStyle.OUTLINE)
		frame.draw_colored_polygon(cut.call(0.0), UiStyle.OUTLINE))
	root.add_child(frame)
	# the art, clipped to the inner cut
	var mask := Control.new()
	mask.name = "Art"
	mask.size = r.size
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var base: Color = {"story": Color("1e5a43"), "ranked": Color("2a3f8f"), "tourn": Color("8f6418")}[id]
	mask.draw.connect(func(): mask.draw_colored_polygon(cut.call(4.0), base))
	root.add_child(mask)
	_tile_art(id, mask, r.size)
	c.mask = mask
	# the tile is the button
	var play := Button.new()
	play.name = "Play_" + id
	play.size = r.size
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		play.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		play.add_theme_color_override(col, Color(0, 0, 0, 0))
	play.add_theme_constant_override("outline_size", 0)
	play.pressed.connect(func(): _card_pressed(id, false))
	play.draw.connect(_draw_play.bind(play, cut))
	for sig in [play.mouse_entered, play.mouse_exited, play.focus_entered, play.focus_exited]:
		sig.connect(func():
			mask.modulate = Color(1.12, 1.12, 1.12) if play.is_hovered() or play.has_focus() else Color.WHITE
			play.queue_redraw())
	root.add_child(play)
	c.play = play
	var big := id == "story"
	var pad := 44.0 if big else 30.0
	c.title = _in(root, Rect2(pad, 18 if big else 14, w - pad - 20, 60 if big else 44), 54 if big else 38, UiStyle.INK, true)
	c.phrase = _in(root, Rect2(pad, 84, 290, 80), 17, UiStyle.INK)
	c.phrase.visible = big
	# what it pays and its warning: the tile's tooltip (_retranslate)
	c.wins_cap = Label.new()
	c.wins = Label.new()
	c.team_cap = Label.new()   # kept for the texts; the chip says it
	c.warn = Label.new()
	# the chip with the team (or the next tournament)
	var chip_col: Color = {"story": UiStyle.OK, "ranked": Color("a9c6ff"), "tourn": Color("ffe08a")}[id]
	var chip_ink: Color = {"story": Color("08261a"), "ranked": Color("0b1a45"), "tourn": Color("3a2600")}[id]
	var chip := PanelContainer.new()
	chip.name = "Chip"
	var cs := UiStyle.box(chip_col, UiStyle.RIM, 2, 3)
	cs.set_corner_radius_all(8)
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	chip.add_theme_stylebox_override("panel", cs)
	chip.position = Vector2(pad - 4, h - 22 - 30)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.team = Label.new()
	c.team.add_theme_font_override("font", UiStyle.bold(900))
	c.team.add_theme_font_size_override("font_size", 14 if big else 13)
	c.team.add_theme_color_override("font_color", chip_ink)
	chip.add_child(c.team)
	root.add_child(chip)
	c.chip = chip
	if id == "ranked":
		var pick := OptionButton.new()
		pick.name = "TeamPick"
		pick.position = chip.position
		pick.size = Vector2(150, 30)
		pick.fit_to_longest_item = false
		pick.clip_text = true
		var ps: StyleBoxFlat = cs.duplicate()
		var ph: StyleBoxFlat = cs.duplicate()
		ph.bg_color = chip_col.lightened(0.2)
		for st in ["normal", "pressed", "hover_pressed", "disabled"]:
			pick.add_theme_stylebox_override(st, ps)
		pick.add_theme_stylebox_override("hover", ph)
		pick.add_theme_font_override("font", UiStyle.bold(900))
		pick.add_theme_font_size_override("font_size", 13)
		pick.add_theme_constant_override("outline_size", 0)
		for col in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			pick.add_theme_color_override(col, chip_ink)
		pick.tooltip_text = _t("hub.team")
		pick.item_selected.connect(func(i): team_picked.emit(int(pick.get_item_id(i))))
		root.add_child(pick)
		c.pick = pick
	# the secondary action
	var extra := Button.new()
	extra.name = "Extra_" + id
	UiStyle.raised(extra, "navy", 15, 8)
	if big:
		extra.position = Vector2(w - 40 - 170, h - 22 - 44)
		extra.size = Vector2(150, 42)
	else:
		extra.position = Vector2(pad - 4, 62)
		extra.size = Vector2(0, 38)
	extra.pressed.connect(func(): _card_pressed(id, true))
	root.add_child(extra)
	c.extra = extra
	_actions.append(play)
	_actions.append(extra)
	_cards[id] = c


## The pop pill with the tile's action (the play button's own text), and a
## sun outline when it has the focus.
func _draw_play(play: Button, cut: Callable) -> void:
	var f := UiStyle.title_font()
	var size := 22 if play.size.x > 400 else 18
	var s := f.get_string_size(play.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var pw := s.x + 36
	var ph := 40.0 if size == 22 else 34.0
	var x := _pill_x(play)
	var y := play.size.y - 20 - ph
	var dis := play.disabled
	var pill := UiStyle.box(UiStyle.PRESSED if not dis else Color("3a3f63"), UiStyle.RIM, 3, 0)
	pill.set_corner_radius_all(int(ph / 2))
	pill.shadow_color = UiStyle.OUTLINE
	pill.shadow_offset = Vector2(0, 4)
	if play.is_hovered() and not dis:
		pill.bg_color = UiStyle.POP
	play.draw_style_box(pill, Rect2(x, y, pw, ph))
	var at := Vector2(x + 18, y + ph / 2 + s.y * 0.32)
	play.draw_string_outline(f, at, play.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, UiStyle.OUTLINE)
	play.draw_string(f, at, play.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UiStyle.INK if not dis else UiStyle.MUTED)
	if play.has_focus():
		var pts: PackedVector2Array = cut.call(-3.0)
		pts.append(pts[0])
		play.draw_polyline(pts, UiStyle.SUN, 3.0, true)


## Where a tile's pop pill starts (left edge), from its text.
func _pill_x(play: Button) -> float:
	var size := 22 if play.size.x > 400 else 18
	var pw := UiStyle.title_font().get_string_size(play.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 36
	if play.size.x > 400:
		return play.size.x * 0.95 - 210 - pw
	return play.size.x * 0.95 - 18 - pw


## Each tile's art: the arena behind (its own crop and tint) and figures.
func _tile_art(id: String, mask: Control, size: Vector2) -> void:
	var tex := UiStyle.scene_texture("arena_bg")
	var inner := size - Vector2(8, 8)
	var spec: Dictionary = {
		"story": {"w": 1100.0, "at": Vector2(0.2, 0.7), "from": Color(0.07, 0.16, 0.12, 0.15), "to": Color(0.07, 0.16, 0.12, 0.75), "h": true},
		"ranked": {"w": 900.0, "at": Vector2(0.7, 0.45), "from": Color(0.08, 0.12, 0.31, 0.2), "to": Color(0.08, 0.12, 0.31, 0.85), "h": false},
		"tourn": {"w": 900.0, "at": Vector2(0.55, 0.3), "from": Color(0.31, 0.2, 0.04, 0.15), "to": Color(0.31, 0.2, 0.04, 0.85), "h": false},
	}[id]
	if tex != null:
		var bg := TextureRect.new()
		bg.texture = tex
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		var sz := Vector2(spec.w, spec.w * tex.get_height() / tex.get_width())
		bg.size = sz
		bg.position = Vector2(4, 4) + (inner - sz) * spec.at
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mask.add_child(bg)
	var tint := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, spec.from)
	g.gradient.set_color(1, spec.to)
	g.fill_to = Vector2(1, 0) if spec.h else Vector2(0, 1)
	tint.texture = g
	tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tint.size = size
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.add_child(tint)
	match id:
		"story":
			var a := UiStyle.figure(mask, "story_a", Vector2(size.x - 40 - 140, 24), 250)
			a.pivot_offset = a.size / 2.0
			a.rotation_degrees = 6
			var b := UiStyle.figure(mask, "story_b", Vector2(size.x - 230 - 77, 110), 150)
			b.pivot_offset = b.size / 2.0
			b.rotation_degrees = -8
		"ranked":
			UiStyle.figure(mask, "fighter_a", Vector2(18, 46), 230)
			UiStyle.figure(mask, "fighter_b", Vector2(size.x - 20 - 80, 42), 234)
			var vs := Control.new()
			vs.size = size
			vs.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vs.draw.connect(func():
				UiStyle.draw_spark(vs, Vector2(144, 124), 32, UiStyle.SUN)
				var f := UiStyle.title_font()
				vs.draw_string_outline(f, Vector2(124, 136), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 9, UiStyle.OUTLINE)
				vs.draw_string(f, Vector2(124, 136), "VS", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, UiStyle.POP))
			mask.add_child(vs)
		"tourn":
			UiStyle.figure(mask, "tour", Vector2(130, 40), 240)
			var cup := Control.new()
			cup.size = size
			cup.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cup.draw.connect(_draw_cup.bind(cup, Vector2(34, 80), 2.0))
			mask.add_child(cup)


## The trophy of the Torneos tile (the mockup's svg, 48x56 units × k).
func _draw_cup(ci: Control, at: Vector2, k: float) -> void:
	var ink := UiStyle.OUTLINE
	var t := func(p: Vector2) -> Vector2: return at + p * k
	var cup := PackedVector2Array()
	cup.append(t.call(Vector2(12, 4)))
	cup.append(t.call(Vector2(36, 4)))
	for i in range(0, 13):
		var a := PI * i / 12.0
		cup.append(t.call(Vector2(24 + 12 * cos(a), 18 + 12 * sin(a))))
	cup.append(t.call(Vector2(12, 4)))
	ci.draw_colored_polygon(cup, UiStyle.SUN)
	ci.draw_polyline(cup, ink, 3.0 * k / 2.0, true)
	for side: float in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 9:
			pts.append(t.call(Vector2(24 + side * 12 + side * 3.5 * absf(sin(PI * i / 8.0)) * 1.4, 8 + 5 * (1.0 - cos(PI * i / 8.0)))))
		ci.draw_polyline(pts, ink, 3.0 * k / 2.0, true)
	ci.draw_rect(Rect2(t.call(Vector2(20, 30)), Vector2(8, 8) * k), Color("e9a93a"))
	ci.draw_rect(Rect2(t.call(Vector2(20, 30)), Vector2(8, 8) * k), ink, false, 3.0)
	ci.draw_rect(Rect2(t.call(Vector2(13, 38)), Vector2(22, 8) * k), UiStyle.SUN)
	ci.draw_rect(Rect2(t.call(Vector2(13, 38)), Vector2(22, 8) * k), ink, false, 3.0)
	ci.draw_line(t.call(Vector2(17, 8)), t.call(Vector2(17, 18)), Color("fff3c4"), 3.0 * k / 2.0, true)


func _in(parent: Control, r: Rect2, size: int, colour: Color, title := false) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title:
		UiStyle.title(l, size, colour)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		_shadowed(l, size, colour)
	parent.add_child(l)
	return l


## Bold text over the art: a hard ink shadow keeps it readable.
func _shadowed(l: Label, size: int, colour: Color) -> void:
	l.add_theme_font_override("font", UiStyle.bold(900))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_color_override("font_shadow_color", UiStyle.OUTLINE)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 3)


## A tile's button: what it does depends on the hub model (no team yet →
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
				# the campaign (S21); the evolution PvP queue only if switched on
				_emit("evo" if Features.EVO_PVP else "story")
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


## Matchmaking: a sheet of paper over the tiles with the mode, a running
## clock and a full-size Cancelar (Esc too); after 20 s of a ranked search,
## an offer to fight a ghost instead (S20B: with few players, the queue is
## often empty).
func _search_card() -> void:
	_search_panel = Control.new()
	_search_panel.name = "Search"
	_search_panel.position = R_SEARCH.position + Vector2(40, 40)
	_search_panel.size = R_SEARCH.size - Vector2(80, 80)
	_search_panel.visible = false
	_box.add_child(_search_panel)
	var paper := Panel.new()
	paper.size = _search_panel.size
	paper.add_theme_stylebox_override("panel", UiStyle.paper(0))
	_search_panel.add_child(paper)
	var sw := _search_panel.size.x
	var rib := PanelContainer.new()
	rib.position = Vector2(-24, -22)
	rib.size = Vector2(sw + 48, 54)
	rib.add_theme_stylebox_override("panel", UiStyle.ribbon())
	_subtitle = Label.new()
	_subtitle.name = "SearchHeading"
	UiStyle.title(_subtitle, 28)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rib.add_child(_subtitle)
	_search_panel.add_child(rib)
	_search_mode = _paper_label(Rect2(0, 62, sw, 28), 19, Color("7a4a1e"))
	_search_clock = _paper_label(Rect2(0, 96, sw, 110), 0, UiStyle.PRESSED)
	_search_clock.name = "SearchClock"
	UiStyle.title(_search_clock, 92, UiStyle.SUN)
	_search_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cancel_search = Button.new()
	_cancel_search.name = "CancelSearch"
	_cancel_search.position = Vector2((sw - 300) / 2.0, 236)
	_cancel_search.size = Vector2(300, 66)
	UiStyle.raised(_cancel_search, "pop", 28)
	_cancel_search.pressed.connect(func(): action_requested.emit("cancel_search"))
	_search_panel.add_child(_cancel_search)
	_ghost_offer = Button.new()
	_ghost_offer.name = "GhostOffer"
	_ghost_offer.position = Vector2((sw - 300) / 2.0, 324)
	_ghost_offer.size = Vector2(300, 50)
	UiStyle.raised(_ghost_offer, "navy", 18)
	_ghost_offer.pressed.connect(func(): _emit("ghost"))
	_ghost_offer.visible = false
	_search_panel.add_child(_ghost_offer)


func _paper_label(r: Rect2, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", UiStyle.bold(900))
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_search_panel.add_child(l)
	return l


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
			var ds := UiStyle.box(Color(0.047, 0.055, 0.118, 0.6), Color(0, 0, 0, 0), 0, 8)
			ds.set_corner_radius_all(12)
			display.add_theme_stylebox_override("normal", ds)
			display.add_theme_font_override("normal_font", UiStyle.bold(800))
			display.add_theme_font_override("bold_font", UiStyle.bold(900))
			display.add_theme_font_size_override("normal_font_size", 14)
			display.add_theme_font_size_override("bold_font_size", 14)
			display.add_theme_color_override("font_shadow_color", UiStyle.OUTLINE)
			display.add_theme_constant_override("shadow_offset_y", 2)
			display.add_theme_constant_override("shadow_offset_x", 0)
	_model.changed.connect(_on_model_changed)
	_sync()
	_sync_hub()
	_sync_season()
	_sync_wallet()
	_relayout()


## Matchmaking state: "Buscando rival…" + Cancelar while a search runs.
func set_searching(on: bool) -> void:
	if on and not _searching:
		_search_started = Time.get_ticks_msec()
	_searching = on
	_search_panel.visible = on
	for id in _cards:
		_cards[id].root.visible = not on
	_quick.visible = not on
	_quick_hint.visible = not on
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
		b.queue_redraw()


func show_bubble(text: String) -> void:
	_bubble.text = text.trim_prefix("AnimEmote-").replace("-Debut", "")
	var current := _bubble.text
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(_bubble) and _bubble.text == current:
			_bubble.text = "")


func _on_model_changed(model_name: String, _field: String, _value: Variant) -> void:
	match model_name:
		"localCoach": _sync()
		"hub": _sync_hub()
		"season": _sync_season()
		"wallet": _sync_wallet()


func _hub() -> Dictionary:
	var v: Variant = _model.get_value("hub") if _model != null else null
	return v if v is Dictionary else {}


## The tiles' live lines: which team plays, the next tournament, and what the
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
	c.chip.visible = teams.is_empty()
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
	_cards.ranked.chip.visible = teams.is_empty() and _cards.ranked.team.text != ""
	for id in _cards:
		var cd: Dictionary = _cards[id]
		cd.play.queue_redraw()
		if id != "ranked":
			cd.chip.visible = cd.team.text != ""
		# a long line is cut with "…" at the room the tile has for it
		var cap: float = _pill_x(cd.play) - cd.chip.position.x - 32.0
		var f: Font = cd.team.get_theme_font("font")
		var wide := f.get_string_size(cd.team.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			cd.team.get_theme_font_size("font_size")).x > cap
		cd.team.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS if wide else TextServer.OVERRUN_NO_TRIMMING
		cd.team.custom_minimum_size.x = cap if wide else 0.0
		cd.chip.size = Vector2.ZERO


func _sync_season() -> void:
	var s: Variant = _model.get_value("season") if _model != null else null
	if not (s is Dictionary) or int(s.get("number", 0)) <= 0:
		_season.visible = false
		return
	var days := maxi(0, ceili((int(s.get("ends", 0)) - Time.get_unix_time_from_system()) / 86400.0))
	_season_n.text = _t("hub.season", {"n": int(s.number)})
	_season_left.text = _t("hub.season_left", {"days": days})
	_season.visible = true
	_season.size = Vector2.ZERO


func _sync_wallet() -> void:
	var w: Variant = _model.get_value("wallet") if _model != null else null
	var wallet: Dictionary = w if w is Dictionary else {}
	for t in _coins:
		_coins[t].text = _thousands(int(wallet.get(t, 0)))


static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _sync() -> void:
	var coach: Variant = _model.get_value("localCoach")
	if not coach is Dictionary:
		return
	_name.text = str(coach.get("name", ""))
	_level.text = I18n.t("lobby.level", {"n": int(coach.get("level", 0))}).to_upper()
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
	# S35c: the 3D figure wears the coach's cards (main._push_coach_worn)
	if _spr.model3d != null and _spr.model3d.has_method("wear_coach_cards"):
		_spr.model3d.wear_coach_cards(coach.get("worn", []))
		# S37: its hair effect cosmetic (60043, main → localCoach.hairFx)
		if int(coach.get("hairFx", 0)) != _hair_fx or _hair_on != _spr.model3d:
			_hair_fx = int(coach.get("hairFx", 0))
			_hair_on = _spr.model3d
			_spr.model3d.set_hair_fx(_hair_fx)


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
	_quick.text = _t("hub.quick")
	_quick_hint.text = _t("hub.quick_hint")
	for m in MODES:
		var c: Dictionary = _cards[str(m[0])]
		var key := str(m[1])
		c.title.text = _t(key)
		c.title.uppercase = true
		c.phrase.text = _t(key + ".phrase")
		c.wins_cap.text = _t("hub.wins").to_upper()
		c.wins.text = _t(key + ".wins")
		c.team_cap.text = _t("hub.team").to_upper()
		c.warn.text = _t(key + ".warn")
		# what a small tile has no room for goes in its tooltip
		c.play.tooltip_text = "%s\n%s: %s\n%s" % [c.phrase.text, _t("hub.wins"), c.wins.text, c.warn.text]
	_cards.story.extra.text = _t("hub.story.practice")
	_cards.story.extra.tooltip_text = _t("lobby.action.practice.tip")
	_cards.ranked.extra.text = _t("hub.ranked.ghost")
	_cards.ranked.extra.tooltip_text = _t("hub.ranked.ghost.tip")
	_cards.tourn.extra.text = _t("hub.tourn.view")
	for i in range(_menu_buttons.size()):
		_menu_buttons[i].tooltip_text = _t(str(MENUS[i][0]))
		_menu_buttons[i].text = _t(str(MENUS[i][0])) if str(MENUS[i][2]) == "nav" else ""
	for t in _coins:
		_coins[t].get_parent().tooltip_text = _t("hub.tokens" if t == TOKENS else "hub.pesetas")
	_sync_hub()
	if _model != null:
		_sync_season()


static func _t(key: String, args: Dictionary = {}) -> String:
	return I18n.t(key, args)


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
