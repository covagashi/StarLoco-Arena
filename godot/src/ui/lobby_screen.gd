class_name PippopLobby
extends Control
## The hub in style B (S45, owner 2026-11-12: "minimalista pero buenas
## animaciones"): a light backdrop of its own — pearl grey, a huge outlined
## PIPPOP, the coach's soft ghost, a coral band and thin technical lines —
## the coach large and sharp in front; top left who you are, top centre the
## season, top right your coins and the three occasional panels; a numbered
## list of the six everyday panels on the left; on the right one pale tile
## per mode the owner kept (Historia, Ranking, Torneos, S20B), cut on the
## diagonal, and the coral "¡A LUCHAR!" (Ranking straight away); the chat at
## the bottom left. Everything slides in when the lobby opens, the tiles
## lean towards the pointer, the backdrop drifts. 1280x720 scaled, mouse,
## keyboard and pad (the Ally).
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
const CHAT_RECT := Rect2(24, 540, 330, 150)
const TILES := Vector2(690, 108)       # the tiles' corner (566 x 460)
const R_SEARCH := Rect2(690, 108, 566, 460)
const COACH_FOOT := Vector2(480, 646)
const COACH_SCALE := 6.0
const TOKENS := 1                      # wallet slot of the Card Master tokens
const PESETAS := 10                    # …and of the pesetas (domain.CurrencyPesetas)
const INK := UiStyle.B_INK
const CORAL := UiStyle.B_CORAL
## Every lobby menu: [label key, dialog, place]. "nav" = the list on the
## left; "top" = icons top right. The order is the icon atlas's (slot i + 1).
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
## The three mode tiles: [id, title key, rect inside TILES, tag, field colour, dot colour].
const MODES := [
	["story", "hub.story", Rect2(0, 0, 566, 232), "STORY · 01", Color("f3d9de"), Color(1.0, 0.3, 0.43, 0.2)],
	["ranked", "hub.ranked", Rect2(0, 248, 280, 212), "RANKED · 02", Color("d8e3f6"), Color(0.18, 0.45, 0.94, 0.2)],
	["tourn", "hub.tourn", Rect2(288, 248, 278, 212), "TOURNAMENT · 03", Color("f4e7cd"), Color(0.85, 0.6, 0.17, 0.27)]]

## Pale field + halftone dots that drift (faster under the pointer).
const _DOTS := """shader_type canvas_item;
uniform vec4 field : source_color;
uniform vec4 dot : source_color;
uniform float speed = 4.0;
uniform float fade = 0.0;
void fragment() {
	vec2 p = FRAGCOORD.xy + vec2(TIME * speed, 0.0);
	vec2 g = mod(p, 12.0) - 6.0;
	float d = 1.0 - smoothstep(1.2, 1.7, length(g));
	float m = mix(1.0, smoothstep(0.25, 0.9, UV.x), fade);
	vec3 base = mix(vec3(1.0), field.rgb, smoothstep(0.0, 1.0, UV.x * 0.8 + UV.y * 0.2));
	COLOR = vec4(mix(base, dot.rgb, d * dot.a * m), 1.0);
}"""
const _LIGHT := """shader_type canvas_item;
void fragment() {
	float d = length((UV - vec2(0.3, 0.4)) * vec2(1.0 / 0.7, 1.0 / 0.9));
	vec3 c = mix(vec3(1.0), vec3(0.914, 0.925, 0.945), smoothstep(0.0, 0.6, d));
	c = mix(c, vec3(0.875, 0.89, 0.918), smoothstep(0.6, 1.2, d));
	COLOR = vec4(c, 1.0);
}"""

var _box: Control
var _font: Font
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
var _cards := {}                # mode id -> {root, title, phrase, wins, team, warn, play, extra, pick, chip, mask, figs}
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
var _season: Control
var _top_row: HBoxContainer   # the coins and the top icons, right-aligned
var _season_n: Label
var _season_left: Label
var _coins := {}                # currency type -> Label
var _rng := RandomNumberGenerator.new()
var _drift: Array = []          # [node, base position, amplitude, period]
var _clock_t := 0.0
var _intro_done := false
var _top: Array = []            # the top bar's pieces, for the entrance
var _lib := ""                  # the coach's set, for its gestures
var _next_pose := 14.0          # seconds to the next idle gesture


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = Control.new()
	_box.size = REF
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.clip_contents = true
	add_child(_box)
	_box.theme = UiStyle.theme()
	_font = UiStyle.display_font()
	_backdrop()
	# the sky the fireworks play in: over the backdrop, behind everything else
	_sky = Control.new()
	_sky.size = REF
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sky.clip_contents = true
	_box.add_child(_sky)
	_coach()
	_identity()
	_season_line()
	var icons := ImageTexture.create_from_image(AssetPaths.load_image("ui/lobby_icons.png"))
	_coins_and_top(icons)
	_rail(icons)
	for m in MODES:
		_card(m)
	_quick = _b_button(true, 34)
	_quick.name = "Quick"
	_quick.size = Vector2(300, 64)
	_quick.position = Vector2(REF.x - 24 - 300, 578)
	_quick.pressed.connect(func(): _card_pressed("ranked", false))
	_box.add_child(_quick)
	_actions.append(_quick)
	_quick_hint = Label.new()
	_quick_hint.position = Vector2(TILES.x + 4, 592)
	_quick_hint.size = Vector2(300, 40)
	_quick_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text(_quick_hint, 13, UiStyle.B_MUTE)
	_box.add_child(_quick_hint)
	_search_card()
	_hint = Label.new()
	_hint.position = Vector2(CHAT_RECT.position.x, 698)
	_hint.size = Vector2(CHAT_RECT.size.x, 16)
	_text(_hint, 11, UiStyle.B_FAINT)
	_box.add_child(_hint)
	_wire_focus()
	resized.connect(_relayout)
	I18n.locale_changed.connect(func(_l): _retranslate())
	_retranslate()


## The backdrop of its own: pearl light, the outlined PIPPOP and the coach's
## ghost (both drift), a coral band, the frame's thin lines and crosses.
func _backdrop() -> void:
	var light := ColorRect.new()
	light.size = REF
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = _LIGHT
	light.material = mat
	_box.add_child(light)
	var word := Label.new()
	word.text = "PIPPOP"
	UiStyle.display(word, 300, Color(0, 0, 0, 0))
	word.add_theme_color_override("font_outline_color", Color(INK, 0.07))
	word.add_theme_constant_override("outline_size", 4)
	word.position = Vector2(-30, 40)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(word)
	_drift.append([word, word.position, Vector2(40, 0), 38.0])
	var tex := UiStyle.scene_texture("coach_ghost")
	if tex != null:
		var ghost := TextureRect.new()
		ghost.texture = tex
		ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ghost.stretch_mode = TextureRect.STRETCH_SCALE
		var h := 1200.0
		ghost.size = Vector2(h * tex.get_width() / tex.get_height(), h)
		ghost.position = Vector2(250, -220)
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.modulate.a = 0.55
		_box.add_child(ghost)
		_drift.append([ghost, ghost.position, Vector2(0, 16), 23.0])
	var band := Polygon2D.new()
	band.polygon = PackedVector2Array([Vector2(0, 360), Vector2(720, 260), Vector2(720, 430), Vector2(0, 530)])
	band.vertex_colors = PackedColorArray([Color(CORAL, 0.1), Color(CORAL, 0.0), Color(CORAL, 0.0), Color(CORAL, 0.1)])
	_box.add_child(band)
	_drift.append([band, band.position, Vector2(0, 10), 17.0])
	var lines := Control.new()
	lines.size = REF
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.draw.connect(func():
		var c := Color(INK, 0.25)
		lines.draw_line(Vector2(24, 92), Vector2(REF.x - 24, 92), c, 1.0)
		lines.draw_line(Vector2(24, 664), Vector2(REF.x - 24, 664), c, 1.0)
		lines.draw_line(Vector2(640, 92), Vector2(640, 664), Color(INK, 0.1), 1.0)
		for p in [Vector2(640, 92), Vector2(24, 664), Vector2(REF.x - 24, 664)]:
			lines.draw_line(p - Vector2(7, 0), p + Vector2(7, 0), INK, 2.0)
			lines.draw_line(p - Vector2(0, 7), p + Vector2(0, 7), INK, 2.0)
		var f := UiStyle.bold(700)
		var t := "PPA // LOBBY · 01"
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		lines.draw_string(f, Vector2(REF.x - 24 - w, 104), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.B_FAINT))
	_box.add_child(lines)


## The 3D coach, large and sharp, the chevrons that turn it (a qc_0 wire
## dir, as in coach creation) and the bubble its emotes show.
func _coach() -> void:
	_spr = preload("res://src/anims/anm_sprite.gd").new()
	_spr.foot_pivot = true
	_spr.position = COACH_FOOT
	_spr.scale = Vector2(COACH_SCALE, COACH_SCALE)
	_box.add_child(_spr)
	for left in [true, false]:
		var b := UiStyle.chevron_button(left, INK)
		b.name = "TurnLeft" if left else "TurnRight"
		# « » as its (hidden) text, as the old buttons had: tests find them by it
		b.text = "«" if left else "»"
		for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(col, Color(0, 0, 0, 0))
		b.scale = Vector2(0.42, 0.42)
		b.position = COACH_FOOT + Vector2(-150 if left else 128, -60)
		b.tooltip_text = _t("lobby.rotate.tip")
		b.pressed.connect(_rotate.bind(-1 if left else 1))
		_box.add_child(b)
	_bubble = Label.new()
	_bubble.position = COACH_FOOT + Vector2(-170, -600)
	_bubble.size = Vector2(340, 40)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UiStyle.display(_bubble, 26, CORAL)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_bubble)


## Top left: the level in a dark slanted box, the tag and the coach's name.
func _identity() -> void:
	var lv := Control.new()
	lv.position = Vector2(24, 20)
	lv.size = Vector2(56, 52)
	lv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lv.draw.connect(func():
		lv.draw_colored_polygon(PackedVector2Array([Vector2(10, 0), Vector2(56, 0), Vector2(46, 52), Vector2(0, 52)]), INK))
	_box.add_child(lv)
	_level = Label.new()
	_level.name = "CoachLevel"
	UiStyle.display(_level, 28, Color.WHITE)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_level.size = lv.size
	lv.add_child(_level)
	var col := VBoxContainer.new()
	col.position = Vector2(92, 18)
	col.add_theme_constant_override("separation", -2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(UiStyle.tag("COACH · LV"))
	_name = Label.new()
	_name.name = "CoachName"
	UiStyle.display(_name, 30)
	col.add_child(_name)
	_box.add_child(col)
	_top.append_array([lv, col])


## The season centred, or moved left of the coins when centred it would
## touch them (a long "quedan N días" beside big amounts).
func _place_season() -> void:
	var x := (REF.x - _season.size.x) / 2.0
	if _top_row != null and _top_row.get_child_count() > 0:
		var coins_left: float = _top_row.position.x + (_top_row.get_child(0) as Control).position.x
		x = minf(x, coins_left - 28.0 - _season.size.x)
	_season.position = Vector2(x, 18)


## Top centre: the season (60031), hidden without one.
func _season_line() -> void:
	var col := VBoxContainer.new()
	col.name = "Season"
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -2)
	var tag := UiStyle.tag("SEASON")
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_season_n = Label.new()
	UiStyle.display(_season_n, 24)
	row.add_child(_season_n)
	_season_left = Label.new()
	UiStyle.display(_season_left, 24, CORAL)
	row.add_child(_season_left)
	col.add_child(row)
	_season = col
	_season.visible = false
	_season.resized.connect(_place_season)
	_box.add_child(_season)
	_top.append(col)


## Top right: tokens and pesetas as tag + number, then the three occasional
## panels (Estadísticas, Social, Ayuda) as thin icons.
func _coins_and_top(icons: Texture2D) -> void:
	var row := HBoxContainer.new()
	row.name = "TopRight"
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 20)
	row.size = Vector2(700, 56)
	row.position = Vector2(REF.x - 24 - 700, 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(row)
	_top_row = row
	# laid out again whenever an amount changes: the season keeps its gap
	row.sort_children.connect(func(): if _season != null: _place_season())
	for c in [[TOKENS, "hub.tokens"], [PESETAS, "hub.pesetas"]]:
		var col := VBoxContainer.new()
		col.name = "Coin_%d" % int(c[0])
		col.add_theme_constant_override("separation", -2)
		col.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(UiStyle.tag(_t(str(c[1]))))
		# S38b: the amount beside its coin (tools/icons/badge_icons.py)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		line.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(line)
		var amount := Label.new()
		UiStyle.display(amount, 24)
		amount.text = "0"
		line.add_child(amount)
		var coin := TextureRect.new()
		coin.name = "Coin"
		coin.texture = UiStyle.token_icon(int(c[0]))
		coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		coin.custom_minimum_size = Vector2(28, 28)
		coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_child(coin)
		_coins[int(c[0])] = amount
		row.add_child(col)
	for i in MENUS.size():
		var entry: Array = MENUS[i]
		if str(entry[2]) != "top":
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = icons
		atlas.region = Rect2((i + 1) * 32, 0, 32, 32)
		var b := Button.new()
		b.name = "Menu_" + str(entry[1])
		b.custom_minimum_size = Vector2(40, 40)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.draw.connect(func():
			var col := CORAL if b.is_hovered() or b.has_focus() else INK
			b.draw_texture_rect(atlas, Rect2(6, 6, 28, 28), false, col)
			if b.has_focus():
				b.draw_line(Vector2(6, 38), Vector2(34, 38), CORAL, 2.0))
		for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
			sig.connect(b.queue_redraw)
		b.pressed.connect(func(): dialog_requested.emit(str(entry[1])))
		row.add_child(b)
		_menu_buttons.append(b)
	_reorder_menus()
	_top.append(row)


## The numbered list of the six everyday panels on the left.
func _rail(icons: Texture2D) -> void:
	var y := 112.0
	var n := 1
	for i in MENUS.size():
		var entry: Array = MENUS[i]
		if str(entry[2]) != "nav":
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = icons
		atlas.region = Rect2((i + 1) * 32, 0, 32, 32)
		var b := Button.new()
		b.name = "Menu_" + str(entry[1])
		b.position = Vector2(24, y)
		b.size = Vector2(230, 50)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			var e := StyleBoxEmpty.new()
			e.content_margin_left = 70
			b.add_theme_stylebox_override(st, e)
		b.add_theme_font_override("font", _font)
		b.add_theme_font_size_override("font_size", 21)
		b.add_theme_constant_override("outline_size", 0)
		# the text stays as it is (tests and screen readers find it); it is
		# drawn in capitals here
		for col in ["font_color", "font_pressed_color", "font_disabled_color", "font_hover_color",
				"font_focus_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(col, Color(0, 0, 0, 0))
		var num := "%02d" % n
		b.draw.connect(func():
			var lit := b.is_hovered() or b.has_focus()
			var f := UiStyle.bold(700)
			b.draw_string(f, Vector2(0, 30), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UiStyle.B_FAINT)
			b.draw_string(_font, Vector2(70, 33), b.text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 21,
				CORAL if lit else INK)
			b.draw_texture_rect(atlas, Rect2(28, 11, 28, 28), false, CORAL if lit else INK)
			if lit:
				b.draw_line(Vector2(70, 42), Vector2(200, 42), CORAL, 2.0))
		for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited]:
			sig.connect(func():
				b.queue_redraw()
				var lit := b.is_hovered() or b.has_focus()
				var tw := b.create_tween()
				tw.tween_property(b, "position:x", 32.0 if lit else 24.0, 0.12).set_trans(Tween.TRANS_QUAD))
		b.pressed.connect(func(): dialog_requested.emit(str(entry[1])))
		_box.add_child(b)
		_menu_buttons.append(b)
		y += 52.0
		n += 1
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
## down from a tile's play leaves for the list, up from the list returns.
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


## A style B button: a slanted box, coral for the action, ink otherwise,
## its text white and leaning. Drawn by hand (no stylebox has the slant).
func _b_button(primary: bool, font_size := 18) -> Button:
	var b := Button.new()
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("outline_size", 0)
	# the box is drawn over the button, so its text is drawn here too
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(col, Color(0, 0, 0, 0))
	b.draw.connect(func():
		var s := b.size
		var k := minf(18.0, s.y * 0.3)
		var dy := 2.0 if b.is_pressed() else 0.0
		var face := PackedVector2Array([Vector2(k, dy), Vector2(s.x, dy), Vector2(s.x - k, s.y + dy), Vector2(0, s.y + dy)])
		var col: Color = (CORAL if primary else INK)
		if b.disabled:
			col = Color("b8bcc8")
		elif b.is_hovered():
			col = col.lightened(0.12)
		if primary and not b.disabled and not b.is_pressed():
			var sh := PackedVector2Array()
			for p in face:
				sh.append(p + Vector2(5, 5))
			b.draw_colored_polygon(sh, Color(INK, 0.9))
		b.draw_colored_polygon(face, col)
		if b.has_focus():
			var loop := face.duplicate()
			loop.append(face[0])
			b.draw_polyline(loop, UiStyle.B_GOLD if primary else CORAL, 2.0, true)
		var t := b.text.to_upper()
		var fs := b.get_theme_font_size("font_size")
		var ts := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
		var at := Vector2((s.x - ts.x) * 0.5, (s.y + fs * 0.72) * 0.5 + dy)
		b.draw_string(_font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs,
			Color(1, 1, 1, 0.7) if b.disabled else Color.WHITE))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited, b.button_down, b.button_up]:
		sig.connect(b.queue_redraw)
	return b


## One mode tile: a pale field with drifting halftone, cut on the diagonal,
## a dark rule along its top, its tag and title, the team chip, a secondary
## action, and the tile itself as the big button ("JUGAR ▸" in coral).
func _card(m: Array) -> void:
	var id := str(m[0])
	var r: Rect2 = m[2]
	var root := Control.new()
	root.name = "Card_" + id
	root.position = TILES + r.position
	root.size = r.size
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(root)
	var c := {"root": root, "base": root.position, "figs": []}
	var w := r.size.x
	var h := r.size.y
	var cut := func(inset: float) -> PackedVector2Array:
		return PackedVector2Array([Vector2(20 + inset * 0.4, inset), Vector2(w - inset, inset),
			Vector2(w - 20 - inset * 0.4, h - inset), Vector2(inset, h - inset)])
	var mask := Control.new()
	mask.name = "Art"
	mask.size = r.size
	mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mask.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	mask.draw.connect(func(): mask.draw_colored_polygon(cut.call(0.0), Color.WHITE))
	root.add_child(mask)
	var dots := ColorRect.new()
	dots.size = r.size
	dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = _dots_shader()
	mat.set_shader_parameter("field", m[4])
	mat.set_shader_parameter("dot", m[5])
	mat.set_shader_parameter("fade", 1.0 if id == "story" else 0.0)
	dots.material = mat
	mask.add_child(dots)
	c.dots = mat
	_tile_figures(id, mask, r.size, c)
	var rule := Control.new()
	rule.size = r.size
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func():
		rule.draw_line(Vector2(20, 1.5), Vector2(w, 1.5), INK, 3.0))
	root.add_child(rule)
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
		sig.connect(_tile_lean.bind(id))
	root.add_child(play)
	c.play = play
	var big := id == "story"
	var pad := 38.0 if big else 34.0
	var head := VBoxContainer.new()
	head.position = Vector2(pad, 20 if big else 12)
	head.add_theme_constant_override("separation", -4)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(UiStyle.tag(str(m[3])))
	c.title = Label.new()
	UiStyle.display(c.title, 66 if big else 38)
	c.title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(c.title)
	root.add_child(head)
	c.phrase = Label.new()
	c.phrase.position = Vector2(pad, 126)
	c.phrase.size = Vector2(270, 60)
	c.phrase.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.phrase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text(c.phrase, 13, Color("4a5064"))
	c.phrase.visible = big
	root.add_child(c.phrase)
	# what it pays and its warning: the tile's tooltip (_retranslate)
	c.wins_cap = Label.new()
	c.wins = Label.new()
	c.team_cap = Label.new()   # kept for the texts; the chip says it
	c.warn = Label.new()
	# the chip with the team (or the next tournament): white, ink text
	var chip := PanelContainer.new()
	chip.name = "Chip"
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color.WHITE
	cs.content_margin_left = 10
	cs.content_margin_right = 10
	cs.content_margin_top = 3
	cs.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", cs)
	# on the small tiles the chip sits a row above "JUGAR ▸"
	chip.position = Vector2(pad - 6, h - 16 - 26 - (0 if big else 30))
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.team = Label.new()
	_text(c.team, 12, INK)
	chip.add_child(c.team)
	root.add_child(chip)
	c.chip = chip
	if id == "ranked":
		var pick := OptionButton.new()
		pick.name = "TeamPick"
		pick.position = chip.position
		pick.size = Vector2(150, 26)
		pick.fit_to_longest_item = false
		pick.clip_text = true
		var ph: StyleBoxFlat = cs.duplicate()
		ph.bg_color = Color("f3f4f8")
		for st in ["normal", "pressed", "hover_pressed", "disabled"]:
			pick.add_theme_stylebox_override(st, cs)
		pick.add_theme_stylebox_override("hover", ph)
		pick.add_theme_stylebox_override("focus", UiStyle.box(Color(0, 0, 0, 0), CORAL, 2, 0))
		pick.add_theme_font_override("font", UiStyle.bold(800))
		pick.add_theme_font_size_override("font_size", 12)
		pick.add_theme_constant_override("outline_size", 0)
		for col in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
			pick.add_theme_color_override(col, INK)
		pick.add_theme_color_override("arrow_modulate", INK)
		pick.tooltip_text = _t("hub.team")
		pick.item_selected.connect(func(i): team_picked.emit(int(pick.get_item_id(i))))
		root.add_child(pick)
		c.pick = pick
	# the secondary action: a small ink box
	var extra := _b_button(false, 15)
	extra.name = "Extra_" + id
	if big:
		extra.position = Vector2(w - 44 - 160, 22)
		extra.size = Vector2(160, 34)
	else:
		extra.position = Vector2(pad - 6, 86)
		extra.size = Vector2(0, 30)
		extra.custom_minimum_size = Vector2(0, 30)
	extra.add_theme_constant_override("h_separation", 0)
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_left = 16
		e.content_margin_right = 16
		extra.add_theme_stylebox_override(st, e)
	extra.pressed.connect(func(): _card_pressed(id, true))
	root.add_child(extra)
	c.extra = extra
	_actions.append(play)
	_actions.append(extra)
	_cards[id] = c


## The tile under the pointer (or the focus) leans out and its dots hurry.
func _tile_lean(id: String) -> void:
	var c: Dictionary = _cards[id]
	var play: Button = c.play
	var on := play.is_hovered() or play.has_focus()
	var tw: Tween = (c.root as Control).create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c.root, "position", c.base + (Vector2(-6, -3) if on else Vector2.ZERO), 0.16)
	for f in c.figs:
		tw.tween_property(f, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.2)
	(c.dots as ShaderMaterial).set_shader_parameter("speed", 14.0 if on else 4.0)
	play.queue_redraw()


## "JUGAR ▸" (the play button's own text) in coral at the tile's bottom
## right, and a coral outline when it has the focus.
func _draw_play(play: Button, cut: Callable) -> void:
	var size := 22 if play.size.x > 400 else 18
	var t := play.text.to_upper() + " ▸"
	var x := _pill_x(play)
	var y := play.size.y - 16.0
	var col := UiStyle.B_FAINT if play.disabled else CORAL
	play.draw_string(_font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if play.has_focus() or play.is_hovered():
		var pts: PackedVector2Array = cut.call(-3.0)
		pts.append(pts[0])
		play.draw_polyline(pts, Color(CORAL, 0.9 if play.has_focus() else 0.5), 2.0, true)


## Where a tile's "JUGAR ▸" starts (left edge), from its text.
func _pill_x(play: Button) -> float:
	var size := 22 if play.size.x > 400 else 18
	var w := _font.get_string_size(play.text.to_upper() + " ▸", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return play.size.x - 30.0 - w


static var _dots_sh: Shader


static func _dots_shader() -> Shader:
	if _dots_sh == null:
		_dots_sh = Shader.new()
		_dots_sh.code = _DOTS
	return _dots_sh


## Each tile's figures (renders of our own game, tools/make_ui_scene.py).
func _tile_figures(id: String, mask: Control, size: Vector2, c: Dictionary) -> void:
	var add := func(n: String, at: Vector2, h: float, deg := 0.0) -> void:
		var f := UiStyle.figure(mask, n, at, h)
		f.pivot_offset = f.size * Vector2(0.5, 0.9)
		f.rotation_degrees = deg
		c.figs.append(f)
	match id:
		"story":
			add.call("story_a", Vector2(size.x - 60 - 135, 18), 240)
			add.call("story_b", Vector2(size.x - 250 - 70, 110), 140, -6.0)
		"ranked":
			add.call("fighter_a", Vector2(24, 36), 200)
			add.call("fighter_b", Vector2(size.x - 26 - 70, 36), 200)
		"tourn":
			add.call("tour", Vector2(size.x - 30 - 70, 26), 210)


## Bold Nunito in ink for reading on the light backdrop.
func _text(l: Label, size: int, colour: Color) -> void:
	l.add_theme_font_override("font", UiStyle.bold(800))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.add_theme_constant_override("outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Matchmaking: a white plate over the tiles (a dark rule on top) with the
## mode, a big coral clock and a full-size Cancelar (Esc too); after 20 s of
## a ranked search, an offer to fight a ghost instead (S20B: with few
## players, the queue is often empty).
func _search_card() -> void:
	_search_panel = Control.new()
	_search_panel.name = "Search"
	_search_panel.position = R_SEARCH.position
	_search_panel.size = R_SEARCH.size
	_search_panel.visible = false
	_box.add_child(_search_panel)
	var plate := Panel.new()
	plate.size = R_SEARCH.size
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(1, 1, 1, 0.92)
	ps.border_color = INK
	ps.border_width_top = 3
	plate.add_theme_stylebox_override("panel", ps)
	_search_panel.add_child(plate)
	var sw := R_SEARCH.size.x
	var t := UiStyle.tag("MATCHMAKING · LIVE")
	t.position = Vector2(0, 40)
	t.size = Vector2(sw, 14)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_panel.add_child(t)
	_subtitle = Label.new()
	_subtitle.name = "SearchHeading"
	UiStyle.display(_subtitle, 40)
	_subtitle.position = Vector2(0, 54)
	_subtitle.size = Vector2(sw, 50)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_panel.add_child(_subtitle)
	_search_mode = Label.new()
	_text(_search_mode, 15, UiStyle.B_MUTE)
	_search_mode.position = Vector2(0, 106)
	_search_mode.size = Vector2(sw, 22)
	_search_mode.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_panel.add_child(_search_mode)
	_search_clock = Label.new()
	_search_clock.name = "SearchClock"
	UiStyle.display(_search_clock, 110, CORAL)
	_search_clock.position = Vector2(0, 130)
	_search_clock.size = Vector2(sw, 120)
	_search_clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_search_panel.add_child(_search_clock)
	_cancel_search = _b_button(true, 28)
	_cancel_search.name = "CancelSearch"
	_cancel_search.position = Vector2((sw - 300) / 2.0, 286)
	_cancel_search.size = Vector2(300, 62)
	_cancel_search.pressed.connect(func(): action_requested.emit("cancel_search"))
	_search_panel.add_child(_cancel_search)
	_ghost_offer = _b_button(false, 18)
	_ghost_offer.name = "GhostOffer"
	_ghost_offer.position = Vector2((sw - 300) / 2.0, 368)
	_ghost_offer.size = Vector2(300, 46)
	_ghost_offer.pressed.connect(func(): _emit("ghost"))
	_ghost_offer.visible = false
	_search_panel.add_child(_ghost_offer)


## The entrance (owner: "buenas animaciones"): the coach sweeps in from the
## left with a coral smear, the top bar drops, the list types itself in and
## the tiles cascade from the right. Once per lobby.
func _intro() -> void:
	if _intro_done:
		return
	_intro_done = true
	var smear := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(CORAL, 0.4))
	g.gradient.set_color(1, Color(CORAL, 0.0))
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	smear.texture = g
	smear.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	smear.size = Vector2(420, 520)
	smear.position = COACH_FOOT - Vector2(470, 540)
	smear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(smear)
	_box.move_child(smear, _spr.get_index())
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_spr.position = COACH_FOOT - Vector2(220, 0)
	_spr.modulate.a = 0.0
	tw.tween_property(_spr, "position", COACH_FOOT, 0.7)
	tw.tween_property(_spr, "modulate:a", 1.0, 0.35)
	tw.tween_property(smear, "position:x", COACH_FOOT.x - 200.0, 0.7)
	tw.tween_property(smear, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(smear.queue_free)
	var t2 := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var k := 0
	for node in _top:
		# only y: the season may still move sideways to clear the coins
		var to: float = node.position.y
		node.position.y = to - 24.0
		node.modulate.a = 0.0
		t2.tween_property(node, "position:y", to, 0.5).set_delay(0.1 + 0.05 * k)
		t2.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(0.1 + 0.05 * k)
		k += 1
	k = 0
	for b in _menu_buttons:
		if b.get_parent() != _box:
			continue
		var to: Vector2 = b.position
		b.position = to - Vector2(30, 0)
		b.modulate.a = 0.0
		t2.tween_property(b, "position", to, 0.4).set_delay(0.25 + 0.06 * k)
		t2.tween_property(b, "modulate:a", 1.0, 0.3).set_delay(0.25 + 0.06 * k)
		k += 1
	k = 0
	for id in ["story", "ranked", "tourn"]:
		var c: Dictionary = _cards[id]
		c.root.position = c.base + Vector2(120, 0)
		c.root.modulate.a = 0.0
		t2.tween_property(c.root, "position", c.base, 0.6).set_delay(0.3 + 0.1 * k)
		t2.tween_property(c.root, "modulate:a", 1.0, 0.4).set_delay(0.3 + 0.1 * k)
		k += 1
	# and once it has arrived, the coach waves
	t2.tween_callback(func():
		if _lib != "":
			Direction8.gesture(_spr, _lib, _dir, "AnimSalut")).set_delay(0.75)
	for node in [_quick, _quick_hint]:
		var to: Vector2 = node.position
		node.position = to + Vector2(0, 30)
		node.modulate.a = 0.0
		t2.tween_property(node, "position", to, 0.5).set_delay(0.7)
		t2.tween_property(node, "modulate:a", 1.0, 0.4).set_delay(0.7)


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
	_intro.call_deferred()


func bind_model(model, chat: Control) -> void:
	_model = model
	_chat = chat
	if is_instance_valid(_chat):
		_chat.theme = _chat_theme()
		var display: Control = _chat.get_node_or_null("Display")
		if display != null:
			var ds := StyleBoxFlat.new()
			ds.bg_color = Color(1, 1, 1, 0.55)
			ds.border_color = INK
			ds.border_width_top = 2
			ds.content_margin_left = 10
			ds.content_margin_right = 10
			ds.content_margin_top = 6
			ds.content_margin_bottom = 6
			display.add_theme_stylebox_override("normal", ds)
			display.add_theme_font_override("normal_font", UiStyle.bold(800))
			display.add_theme_font_override("bold_font", UiStyle.bold(900))
			display.add_theme_font_size_override("normal_font_size", 13)
			display.add_theme_font_size_override("bold_font_size", 13)
			display.add_theme_color_override("default_color", INK)
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


func _process(dt: float) -> void:
	# the backdrop drifts, slowly (each piece on its own period)
	_clock_t += dt
	for d in _drift:
		var phase: float = TAU * _clock_t / float(d[3])
		d[0].position = d[1] + d[2] * sin(phase)
	# now and then the coach strikes its pose (not stiff: owner, S45)
	_next_pose -= dt
	if _next_pose <= 0.0 and _lib != "" and not _searching:
		_next_pose = _rng.randf_range(12.0, 20.0)
		Direction8.gesture(_spr, _lib, _dir, "AnimPose")
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
		var cap: float = (_pill_x(cd.play) if id == "story" else cd.root.size.x - 40.0) - cd.chip.position.x - 32.0
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
	_level.text = str(int(coach.get("level", 0)))
	_level.tooltip_text = I18n.t("lobby.level", {"n": int(coach.get("level", 0))})
	# actorDirection is a qc_0 wire dir the rest of the client already writes
	# (creation screen arrows). Honor it when present.
	_dir = int(coach.get("actorDirection", _dir)) & 7
	var look := "%s/%s/%s/%d" % [coach.get("sex", 0), coach.get("skin", 0),
		coach.get("hair", 0), _dir]
	if look != _look:
		_look = look
		_spr.tints = Palettes.coach_tints(int(coach.get("skin", 0)), int(coach.get("hair", 0)))
		var lib := "anims/coach_700%d" % int(coach.get("sex", 0))
		# the menu stance (S45), not the fight's idle
		if not Direction8.load_idle(_spr, lib, _dir, "AnimMenu") \
				and not Direction8.load_idle(_spr, lib, _dir):
			Direction8.load_idle_any(_spr, lib)
		_lib = lib
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
		_coins[t].get_parent().get_parent().tooltip_text = _t("hub.tokens" if t == TOKENS else "hub.pesetas")
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


## The chat on the light backdrop: flat tabs (coral when picked), a white
## field with an ink rule, ink text.
func _chat_theme() -> Theme:
	var t := UiStyle.theme(3)
	var flat := StyleBoxEmpty.new()
	flat.content_margin_left = 6
	flat.content_margin_right = 6
	var on := StyleBoxFlat.new()
	on.bg_color = INK
	on.content_margin_left = 6
	on.content_margin_right = 6
	for st in ["normal", "hover", "disabled", "focus"]:
		t.set_stylebox(st, "Button", flat)
	t.set_stylebox("pressed", "Button", on)
	t.set_stylebox("hover_pressed", "Button", on)
	t.set_font("font", "Button", UiStyle.display_font())
	t.set_font_size("font_size", "Button", 13)
	t.set_constant("outline_size", "Button", 0)
	t.set_color("font_color", "Button", UiStyle.B_MUTE)
	t.set_color("font_hover_color", "Button", CORAL)
	t.set_color("font_focus_color", "Button", CORAL)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1, 1, 1, 0.85)
	field.border_color = INK
	field.border_width_bottom = 2
	field.content_margin_left = 8
	field.content_margin_right = 8
	t.set_stylebox("normal", "LineEdit", field)
	var ff: StyleBoxFlat = field.duplicate()
	ff.border_color = CORAL
	t.set_stylebox("focus", "LineEdit", ff)
	for c in ["font_color", "font_selected_color"]:
		t.set_color(c, "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", UiStyle.B_FAINT)
	t.set_color("caret_color", "LineEdit", CORAL)
	t.set_font("font", "LineEdit", UiStyle.bold(800))
	return t
