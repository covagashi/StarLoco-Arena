extends "res://src/ui/hero_panel.gd"
## Reclutar (S47, owner points 3 and 5): a screen of its own for a new
## fighter, after the owner's references (sprints/ref/S47/): the twelve
## classes as ringed portraits on a plate at the left with the sex and the
## mode above them, the fighter large in the middle on a stone drum (the
## chevrons turn it), the name and "¡RECLUTAR!" on a plinth under the drum,
## and on the paper at the right the class — its difficulty as outlined
## stars, its roles as medallions, what it is like and its ten attacks.
##
## Replaces the old fighterCreationDialog modal (it keeps its name, so every
## way in still lands here: Equipo → "Crear luchador", a class master's
## "Reclutar", the Historia tile and "¡A luchar!" with nobody to play).
## Drives the same model and events: teamManagement.editableFighter,
## setFighterBreedId / setFighterSex / setFighterVersion / createFighter.
## main answers in `recruit` {status, error}: "sent" while the server
## decides; an error stays on the screen, a success closes it.

const Direction8 := preload("res://src/util/direction8.gd")
const Spells := preload("res://src/gamedata/spells.gd")
const FOOT := Vector2(548, 576)
const DOLL_SCALE := 5.6
const CLASS_TILE := 64.0
const GRID_GAP := 8.0
const R_PLATE := Rect2(20, 258, 298, 294)   # the classes' plate
const GRID_AT := Vector2(29, 296)
const R_PLINTH := Rect2(285, 606, 526, 94)  # the name and the button sit here
const R_PAPER := Vector2(430, 540)           # the sheet, taller than hero_panel's
const STONE := Color("e2e5ec")
const STONE_DARK := Color("c3c8d4")
## Per class (breed 1..12): difficulty 1-3 and its roles (keys of role.*).
const CLASS_INFO := {
	1: [1, ["tank", "sup"]], 2: [3, ["summ", "sup"]], 3: [2, ["ctrl", "sup"]],
	4: [2, ["dmg", "ctrl"]], 5: [3, ["ctrl", "mob"]], 6: [2, ["dmg"]],
	7: [2, ["heal", "sup"]], 8: [1, ["dmg", "mob"]], 9: [1, ["dmg"]],
	10: [2, ["summ", "ctrl"]], 11: [2, ["dmg", "mob"]], 12: [3, ["ctrl", "tank"]],
}
## Element → the corner of an attack tile (the spell's fx colour).
const ELEMENT_COL := {"fire": Color("ff6a3d"), "water": Color("2f9df0"),
	"air": Color("39c08a"), "earth": Color("a0743c"), "neutral": Color("8a8fa0")}

var _spr
var _dir := Direction8.FRONT
var _look := ""
var _class_btns := {}     # breed -> Button
var _sex_btns := {}       # 0/1 -> Button
var _mode_btns := {}      # 2 evo / 1 classic -> Button
var _mode_tip: Label
var _name: LineEdit
var _go: Button
var _status: Label
var _hint: Control        # the ink ribbon under the grid: the class under the pointer
var _hint_breed := 0
var _picker: Control      # the whole left column (one node, for the entrance)
var _ped: Control         # the drum and the plinth
var _built := false


func _ready() -> void:
	panel_name = "fighterCreationDialog"
	super._ready()
	_harden_sheet()
	_left_column()
	_ped = Control.new()
	_ped.size = HREF
	_ped.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ped.draw.connect(_draw_pedestal.bind(_ped))
	stage.add_child(_ped)
	stage.move_child(_ped, pinned_actions.get_index())
	_spr = preload("res://src/anims/figure.gd").new()
	_spr.foot_pivot = true
	_spr.position = FOOT
	_spr.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	stage.add_child(_spr)
	stage.move_child(_spr, pinned_actions.get_index())
	for left in [true, false]:
		var b := UiStyle.chevron_button(left, UiStyle.B_INK)
		b.name = "TurnLeft" if left else "TurnRight"
		b.scale = Vector2(0.55, 0.55)
		b.position = FOOT + Vector2(-210 if left else 180, -290)
		b.tooltip_text = I18n.t("creation.rotate_left" if left else "creation.rotate_right")
		b.pressed.connect(func():
			_dir = (_dir + (-1 if left else 1)) & 7
			_look = ""
			_dress())
		stage.add_child(b)
	_actions()
	_built = true
	refresh()
	_name.grab_focus.call_deferred()
	_enter.call_deferred()


func hero_word() -> String:
	return "RECRUIT"


func hero_tag() -> String:
	return "RECRUIT · " + I18n.t("recruit.tag_mode_evo" if _version() == 2 else "recruit.tag_mode_classic").to_upper()


func _fighter() -> Dictionary:
	var f: Variant = data("teamManagement.editableFighter", {})
	return f if f is Dictionary else {}


func _breed() -> int:
	return clampi(int(_fighter().get("breedId", 1)), 1, 12)


func _version() -> int:
	return 2 if int(_fighter().get("version", 1)) == 2 else 1


## The entrance: the fighter sweeps in, the plate slides from the left.
func _enter() -> void:
	var to: Vector2 = _spr.position
	_spr.position = to - Vector2(160, 0)
	_spr.modulate.a = 0.0
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(_spr, "position", to, 0.7)
	tw.tween_property(_spr, "modulate:a", 1.0, 0.35)
	StyleB.enter(self, [_picker], Vector2(-40, 0), 0.15, 0.0, 0.5)


## The paper hero_panel built: taller (the ten attacks and their line
## fit without a scrollbar), a hard ink shadow and an ink rim instead of
## the soft shade, like every other box on this screen.
func _harden_sheet() -> void:
	var sheet: Control = stage.get_node("Sheet")
	sheet.size = R_PAPER
	var paper: PanelContainer = sheet.get_child(0)
	paper.size = R_PAPER
	var ps: StyleBoxFlat = paper.get_theme_stylebox("panel").duplicate()
	ps.shadow_size = 0
	ps.border_width_left = 2
	ps.border_width_right = 2
	ps.border_width_bottom = 2
	ps.border_width_top = 4
	ps.bg_color = Color(1, 1, 1, 0.96)
	paper.add_theme_stylebox_override("panel", ps)
	var sh := Control.new()
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sh.draw.connect(func(): sh.draw_rect(Rect2(Vector2(7, 7), R_PAPER), Color(UiStyle.B_INK, 0.9)))
	sheet.add_child(sh)
	sheet.move_child(sh, 0)
	var corner := Control.new()   # a coral corner cut at the bottom right, over the paper
	corner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	corner.draw.connect(func():
		var c := Vector2(R_PAPER.x, R_PAPER.y)
		corner.draw_colored_polygon(PackedVector2Array([c + Vector2(-34, 0), c, c + Vector2(0, -34)]), UiStyle.B_CORAL)
		corner.draw_line(c + Vector2(-34, 0), c + Vector2(0, -34), UiStyle.B_INK, 2.0, true))
	sheet.add_child(corner)
	var inner: VBoxContainer = paper.get_child(0)
	inner.add_theme_constant_override("separation", 4)
	body.add_theme_constant_override("separation", 8)


## Left: the sex, the mode with what it means, then the twelve classes on
## a plate under a coral ribbon, the class under the pointer on an ink one.
func _left_column() -> void:
	_picker = Control.new()
	_picker.name = "Picker"
	_picker.size = HREF
	_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_picker)
	stage.move_child(_picker, pinned_actions.get_index())
	var sexes := HBoxContainer.new()
	sexes.position = Vector2(28, 104)
	sexes.add_theme_constant_override("separation", 8)
	_picker.add_child(sexes)
	for sex in [0, 1]:
		var b := _choice()
		b.name = "Sex%d" % sex
		b.text = I18n.t("fc.sex_m" if sex == 0 else "fc.sex_f")
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(139, 38)
		b.pressed.connect(func(): send("setFighterSex", [sex]))
		sexes.add_child(b)
		_sex_btns[sex] = b
	var modes := HBoxContainer.new()
	modes.position = Vector2(28, 148)
	modes.add_theme_constant_override("separation", 8)
	_picker.add_child(modes)
	for v in [2, 1]:
		var b := _choice()
		b.name = "Mode%s" % ("Story" if v == 2 else "Elite")
		b.text = I18n.t("recruit.mode_story" if v == 2 else "recruit.mode_elite")
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(139, 38)
		b.pressed.connect(func(): send("setFighterVersion", [v]))
		modes.add_child(b)
		_mode_btns[v] = b
	_mode_tip = Label.new()
	_mode_tip.name = "ModeTip"
	_mode_tip.position = Vector2(28, 192)
	_mode_tip.size = Vector2(286, 42)
	_mode_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mode_tip.add_theme_font_size_override("font_size", 13)
	_mode_tip.add_theme_color_override("font_color", UiStyle.B_MUTE)
	_mode_tip.add_theme_constant_override("outline_size", 0)
	_picker.add_child(_mode_tip)
	# the plate: a white slab with a hard ink shadow and a cut corner
	var plate := Control.new()
	plate.position = R_PLATE.position
	plate.size = R_PLATE.size
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.draw.connect(func():
		var s := plate.size
		var c := 22.0
		var face := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x, s.y - c),
			Vector2(s.x - c, s.y), Vector2(0, s.y)])
		var sh := PackedVector2Array()
		for p in face:
			sh.append(p + Vector2(6, 6))
		plate.draw_colored_polygon(sh, Color(UiStyle.B_INK, 0.9))
		plate.draw_colored_polygon(face, Color(1, 1, 1, 0.96))
		var loop := face.duplicate()
		loop.append(face[0])
		plate.draw_polyline(loop, UiStyle.B_INK, 2.5, true)
		# a faint grid of the splash's technical lines, so the plate is paper
		for i in 3:
			var y := 60.0 + i * 72.0
			plate.draw_line(Vector2(10, y), Vector2(s.x - 10, y), Color(UiStyle.B_INK, 0.06), 1.0))
	_picker.add_child(plate)
	var cap := Control.new()
	cap.position = Vector2(R_PLATE.position.x - 6, R_PLATE.position.y - 12)
	cap.size = Vector2(R_PLATE.size.x + 12, 26)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.draw.connect(func(): _draw_ribbon(cap, I18n.t("recruit.pick_class"), UiStyle.B_CORAL, 15))
	_picker.add_child(cap)
	for i in 12:
		var breed := i + 1
		var b := Button.new()
		b.name = "Class%d" % breed
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_ALL
		b.size = Vector2(CLASS_TILE, CLASS_TILE)
		b.position = GRID_AT + Vector2((i % 4) * (CLASS_TILE + GRID_GAP), (i / 4) * (CLASS_TILE + GRID_GAP))
		b.tooltip_text = I18n.t("breed.%d" % breed)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		b.draw.connect(_draw_class.bind(b, breed))
		for sig in [b.mouse_entered, b.focus_entered]:
			sig.connect(func():
				_hint_breed = breed
				_hint.queue_redraw()
				b.queue_redraw())
		for sig in [b.mouse_exited, b.focus_exited]:
			sig.connect(func():
				if _hint_breed == breed:
					_hint_breed = 0
					_hint.queue_redraw()
				b.queue_redraw())
		b.pressed.connect(func(): send("setFighterBreedId", [breed]))
		_picker.add_child(b)
		_class_btns[breed] = b
	_hint = Control.new()
	_hint.name = "ClassHint"
	_hint.position = Vector2(R_PLATE.position.x + 14, R_PLATE.end.y - 42)
	_hint.size = Vector2(R_PLATE.size.x - 28 - 16, 28)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.draw.connect(func():
		var breed := _hint_breed if _hint_breed > 0 else _breed()
		_draw_ribbon(_hint, I18n.t("breed.%d" % breed), UiStyle.B_INK, 16, _hint_breed > 0))
	_picker.add_child(_hint)


## A ribbon with swallowtail ends and a hard shadow, its text white and
## leaning. `lit`: a coral rule under the text (the pointer is on a class).
static func _draw_ribbon(c: Control, text: String, fill: Color, font_size: int, lit := false) -> void:
	var s := c.size
	var k := s.y * 0.4
	var shape := PackedVector2Array([Vector2(0, 0), Vector2(s.x, 0), Vector2(s.x - k, s.y * 0.5),
		Vector2(s.x, s.y), Vector2(0, s.y), Vector2(k, s.y * 0.5)])
	var sh := PackedVector2Array()
	for p in shape:
		sh.append(p + Vector2(3, 3))
	c.draw_colored_polygon(sh, Color(UiStyle.B_INK, 0.9 if fill != UiStyle.B_INK else 0.35))
	c.draw_colored_polygon(shape, fill)
	var font := UiStyle.display_font()
	var t := text.to_upper()
	var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var at := Vector2((s.x - ts.x) * 0.5, (s.y + font_size * 0.72) * 0.5)
	c.draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
	if lit:
		c.draw_line(Vector2(at.x, at.y + 4), Vector2(at.x + ts.x, at.y + 4), UiStyle.B_CORAL, 2.0)


## A two-way choice (sex, mode): a slanted face with a hard shadow, coral
## and white text when picked, white with an ink rim and ink text when not.
func _choice() -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_ALL
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for col in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
			"font_hover_pressed_color", "font_disabled_color"]:
		b.add_theme_color_override(col, Color(0, 0, 0, 0))
	b.add_theme_constant_override("outline_size", 0)
	var font := UiStyle.display_font()
	b.draw.connect(func():
		var s := b.size - Vector2(4, 4)
		var k := 10.0
		var face := PackedVector2Array([Vector2(k, 0), Vector2(s.x, 0), Vector2(s.x - k, s.y), Vector2(0, s.y)])
		var on := b.button_pressed
		var lit := b.is_hovered() or b.has_focus()
		var sh := PackedVector2Array()
		for p in face:
			sh.append(p + Vector2(4, 4))
		b.draw_colored_polygon(sh, Color(UiStyle.B_INK, 0.9 if on else 0.25))
		b.draw_colored_polygon(face, UiStyle.B_CORAL if on else Color.WHITE)
		var loop := face.duplicate()
		loop.append(face[0])
		b.draw_polyline(loop, UiStyle.B_CORAL if lit and not on else UiStyle.B_INK, 2.0, true)
		var t := b.text.to_upper()
		var ts := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
		b.draw_string(font, Vector2((s.x - ts.x) * 0.5, (s.y + 16 * 0.72) * 0.5), t,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE if on else UiStyle.B_INK))
	for sig in [b.mouse_entered, b.mouse_exited, b.focus_entered, b.focus_exited, b.toggled]:
		sig.connect(func(_a = null): b.queue_redraw())
	return b


## A class tile: its portrait in a ring (the combat HUD's), a hard ink
## shadow under it; the picked one bigger, coral-ringed on a gold glow;
## under the pointer, a coral ring.
func _draw_class(b: Button, breed: int) -> void:
	var picked := breed == _breed()
	var lit := b.is_hovered() or b.has_focus()
	var c := b.size * 0.5
	var r := 27.0 if picked else 25.0
	if picked:
		for i in 3:
			b.draw_circle(c, r + 11 - i * 3, Color(UiStyle.B_GOLD, 0.16))
	b.draw_circle(c + Vector2(3, 3), r + 3, Color(UiStyle.B_INK, 0.9))
	b.draw_circle(c, r + 3, UiStyle.B_INK)
	b.draw_circle(c, r, Color.WHITE)
	var tex := _portrait(breed, int(_fighter().get("sex", 0)))
	if tex != null:
		var pts := PackedVector2Array()
		var uvs := PackedVector2Array()
		for i in 40:
			var a := TAU * i / 40.0
			var d := Vector2(cos(a), sin(a))
			pts.append(c + d * r)
			uvs.append(Vector2(0.5, 0.5) + d * 0.49)
		b.draw_polygon(pts, PackedColorArray([Color.WHITE if picked or lit else Color(0.88, 0.88, 0.9)]), uvs, tex)
	if picked:
		b.draw_arc(c, r + 1.5, 0, TAU, 64, UiStyle.B_CORAL, 4.0, true)
	elif lit:
		b.draw_arc(c, r + 1.5, 0, TAU, 64, UiStyle.B_CORAL, 2.5, true)


static var _portraits := {}


static func _portrait(breed: int, sex: int) -> Texture2D:
	var rel := "ui/portraits/%d.png" % (breed * 10 + sex)
	if not _portraits.has(rel):
		var img := AssetPaths.load_image(rel)
		_portraits[rel] = ImageTexture.create_from_image(img) if img != null else null
	return _portraits[rel]


## The drum the fighter stands on (a stone disc with its side and a hard
## shadow, the figure's own shadow on top) and the plinth under it that
## holds the name and the button.
func _draw_pedestal(c: Control) -> void:
	var ink := UiStyle.B_INK
	var top := FOOT + Vector2(0, -2)
	var rx := 150.0
	var ry := 27.0
	var side := 14.0
	# the shadow, then the side (the lower half of the disc dropped), then the top
	c.draw_set_transform(top + Vector2(5, side + 5), 0.0, Vector2(1.0, ry / rx))
	c.draw_circle(Vector2.ZERO, rx, Color(ink, 0.9))
	c.draw_set_transform(top + Vector2(0, side), 0.0, Vector2(1.0, ry / rx))
	c.draw_circle(Vector2.ZERO, rx, STONE_DARK)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	c.draw_rect(Rect2(top + Vector2(-rx, 0), Vector2(rx * 2, side)), STONE_DARK)
	c.draw_line(top + Vector2(-rx, 0), top + Vector2(-rx, side), ink, 2.5)
	c.draw_line(top + Vector2(rx, 0), top + Vector2(rx, side), ink, 2.5)
	c.draw_set_transform(top + Vector2(0, side), 0.0, Vector2(1.0, ry / rx))
	c.draw_arc(Vector2.ZERO, rx, 0, PI, 48, ink, 2.5, true)
	c.draw_set_transform(top, 0.0, Vector2(1.0, ry / rx))
	c.draw_circle(Vector2.ZERO, rx, STONE)
	c.draw_arc(Vector2.ZERO, rx * 0.78, 0, TAU, 64, Color(ink, 0.18), 2.0, true)
	c.draw_arc(Vector2.ZERO, rx * 0.62, 0, TAU, 64, Color(UiStyle.B_CORAL, 0.75), 2.5, true)
	for i in 4:   # four ticks on the rim, a compass
		var d := Vector2(cos(i * PI / 2), sin(i * PI / 2))
		c.draw_line(d * rx * 0.86, d * rx * 0.96, ink, 2.5, true)
	c.draw_circle(Vector2(0, 2), rx * 0.42, Color(ink, 0.16))   # the figure's shadow
	c.draw_arc(Vector2.ZERO, rx, 0, TAU, 72, ink, 2.5, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# the plinth: a wider stone slab, cut at both top corners
	var p := R_PLINTH
	var k := 16.0
	var face := PackedVector2Array([p.position + Vector2(k, 0), p.position + Vector2(p.size.x - k, 0),
		p.end, Vector2(p.position.x, p.end.y)])
	var sh := PackedVector2Array()
	for v in face:
		sh.append(v + Vector2(6, 6))
	c.draw_colored_polygon(sh, Color(ink, 0.9))
	c.draw_colored_polygon(face, STONE)
	c.draw_rect(Rect2(p.position + Vector2(k, 0), Vector2(p.size.x - 2 * k, 7)), Color.WHITE)
	var loop := face.duplicate()
	loop.append(face[0])
	c.draw_polyline(loop, ink, 2.5, true)
	for x in [p.position.x + 10.0, p.end.x - 10.0]:
		StyleB.sparkle(c, Vector2(x, p.position.y + p.size.y * 0.5), 5.0, UiStyle.B_CORAL)
	if _status == null or _status.text.is_empty():   # the engraved band the error line replaces
		var y := p.position.y + 20.0
		var m := Vector2(p.position.x + p.size.x * 0.5, y)
		c.draw_line(Vector2(p.position.x + 36, y), m - Vector2(16, 0), Color(ink, 0.35), 1.5)
		c.draw_line(m + Vector2(16, 0), Vector2(p.end.x - 36, y), Color(ink, 0.35), 1.5)
		c.draw_colored_polygon(PackedVector2Array([m + Vector2(0, -5), m + Vector2(5, 0), m + Vector2(0, 5), m + Vector2(-5, 0)]), UiStyle.B_CORAL)


## The plinth's row: the name and "¡RECLUTAR!"; the error line between the
## drum and the plinth.
func _actions() -> void:
	_status = Label.new()
	_status.name = "Status"
	_status.position = Vector2(R_PLINTH.position.x, R_PLINTH.position.y + 12)
	_status.size = Vector2(R_PLINTH.size.x, 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_override("font", UiStyle.bold(800))
	_status.add_theme_color_override("font_color", UiStyle.B_CORAL)
	_status.add_theme_font_size_override("font_size", 14)
	_status.add_theme_constant_override("outline_size", 0)
	stage.add_child(_status)
	_name = LineEdit.new()
	_name.name = "FighterName"
	_name.max_length = 20
	_name.placeholder_text = I18n.t("recruit.name_ph")
	_name.custom_minimum_size = Vector2(286, 48)
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	StyleB.field(_name, 22)
	_name.add_theme_font_override("font", UiStyle.display_font())
	for st in ["normal", "focus"]:   # a full ink rim: a nameplate set in the stone
		var sb: StyleBoxFlat = _name.get_theme_stylebox(st)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 3 if st == "normal" else 4
		sb.bg_color = Color.WHITE
	_name.text = str(_fighter().get("name", ""))
	_name.text_submitted.connect(func(_t): _submit())
	var bar := HBoxContainer.new()
	bar.name = "RecruitBar"
	bar.add_theme_constant_override("separation", 14)
	bar.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.position = R_PLINTH.position + Vector2(0, 32)
	bar.size = Vector2(R_PLINTH.size.x, 56)
	stage.add_child(bar)
	bar.add_child(_name)
	_go = StyleB.button(true, 28)
	_go.name = "Recruit"
	_go.text = I18n.t("recruit.go")
	_go.custom_minimum_size = Vector2(212, 56)
	_go.pressed.connect(_submit)
	bar.add_child(_go)


func _submit() -> void:
	var n := _name.text.strip_edges()
	if n.is_empty():
		_status.text = I18n.t("recruit.err_name")
		_ped.queue_redraw()
		_name.grab_focus()
		return
	model.set_value("teamManagement", n, "editableFighter.name")
	model.set_value("recruit", {"status": "sent", "error": ""})
	send("createFighter")


func _model_changed(model_name: String, _field: String, _value: Variant) -> void:
	var root := model_name.split(".")[0]
	if root == "teamManagement" or root == "recruit":
		schedule_refresh()


func refresh() -> void:
	super.refresh()
	if body == null or not _built:
		return
	clear_body()
	pinned_actions.hide()
	var breed := _breed()
	var version := _version()
	var sex := int(_fighter().get("sex", 0))
	title.text = I18n.t("recruit.title")
	for b in _class_btns:
		_class_btns[b].set_pressed_no_signal(b == breed)
		_class_btns[b].queue_redraw()
	_hint.queue_redraw()
	for s in _sex_btns:
		_sex_btns[s].set_pressed_no_signal(s == sex)
	for v in _mode_btns:
		_mode_btns[v].set_pressed_no_signal(v == version)
	_mode_tip.text = I18n.t("recruit.mode_story_tip" if version == 2 else "recruit.mode_elite_tip")
	var r: Dictionary = data("recruit", {}) if data("recruit", {}) is Dictionary else {}
	var sent := str(r.get("status", "")) == "sent"
	_go.disabled = sent
	_status.text = str(r.get("error", ""))
	_ped.queue_redraw()
	_dress()
	_class_sheet(breed)


## The paper: the class, its difficulty (outlined stars) and roles
## (medallions), what it is like, and its ten attacks (a pointer over one
## says its cost and range).
func _class_sheet(breed: int) -> void:
	sheet_title.text = I18n.t("breed.%d" % breed)
	sheet_tag.text = I18n.t("recruit.class_tag").to_upper()
	var info: Array = CLASS_INFO.get(breed, [1, []])
	var line := row(body)
	line.add_theme_constant_override("separation", 10)
	var dl := _small(line, I18n.t("recruit.difficulty"), 15)
	dl.add_theme_font_override("font", UiStyle.bold(800))
	var stars := Control.new()
	stars.name = "Difficulty"
	stars.custom_minimum_size = Vector2(90, 26)
	stars.set_meta("n", int(info[0]))
	stars.draw.connect(func():
		for i in 3:
			var at := Vector2(14 + i * 28, 13)
			var on := i < int(info[0])
			_star(stars, at + Vector2(2, 2), 12.0, Color(UiStyle.B_INK, 0.9))
			_star(stars, at, 12.0, UiStyle.B_INK)
			_star(stars, at, 8.5, UiStyle.B_GOLD if on else Color.WHITE))
	line.add_child(stars)
	var roles := HBoxContainer.new()
	roles.name = "Roles"
	roles.add_theme_constant_override("separation", 10)
	body.add_child(roles)
	for role in info[1]:
		roles.add_child(_medal(str(role)))
	var desc := label(body, I18n.t("recruit.desc.%d" % breed), 14)
	desc.name = "ClassDesc"
	desc.add_theme_font_override("font", UiStyle.bold(800))
	body.add_child(UiStyle.caption(I18n.t("recruit.attacks")))
	var grid := HFlowContainer.new()
	grid.name = "Attacks"
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	var detail := label(body, I18n.t("recruit.attack_hint"), 13)
	detail.name = "AttackDetail"
	detail.add_theme_font_override("font", UiStyle.bold(800))
	detail.add_theme_color_override("font_color", UiStyle.B_MUTE)
	for s in Spells.for_breed(breed):
		grid.add_child(_attack(s, detail))


## A role as a medallion: a ringed disc with a hard shadow, its pictogram
## drawn here, and its name under it.
func _medal(role: String) -> Control:
	var c := Control.new()
	c.name = "Role_" + role
	c.custom_minimum_size = Vector2(100, 68)
	c.tooltip_text = I18n.t("role." + role)
	c.draw.connect(func():
		var at := Vector2(c.size.x * 0.5, 23)
		c.draw_circle(at + Vector2(3, 3), 22, Color(UiStyle.B_INK, 0.9))
		c.draw_circle(at, 22, UiStyle.B_INK)
		c.draw_circle(at, 19, Color.WHITE)
		c.draw_arc(at, 16, 0, TAU, 48, Color(UiStyle.B_GOLD, 0.6), 1.5, true)
		_role_icon(c, role, at)
		var f := UiStyle.bold(900)
		var t := I18n.t("role." + role).to_upper()
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		c.draw_string(f, Vector2((c.size.x - w) * 0.5, 64), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.B_INK))
	return c


## The pictograms, in ink with a coral touch, 24 px across.
static func _role_icon(c: Control, role: String, at: Vector2) -> void:
	var ink := UiStyle.B_INK
	var coral := UiStyle.B_CORAL
	match role:
		"tank":   # a shield
			var sh := PackedVector2Array([at + Vector2(-11, -10), at + Vector2(11, -10), at + Vector2(10, 2),
				at + Vector2(0, 12), at + Vector2(-10, 2)])
			c.draw_colored_polygon(sh, ink)
			c.draw_colored_polygon(PackedVector2Array([at + Vector2(-2, -6), at + Vector2(2, -6),
				at + Vector2(2, 6), at + Vector2(-2, 6)]), coral)
		"dmg":    # a sword
			c.draw_line(at + Vector2(-9, 9), at + Vector2(9, -9), ink, 4.0, true)
			c.draw_line(at + Vector2(-9, 1), at + Vector2(-1, 9), ink, 3.5, true)
			c.draw_circle(at + Vector2(-10, 10), 3.0, coral)
			c.draw_line(at + Vector2(4, -4), at + Vector2(9, -9), coral, 2.0, true)
		"heal":   # a cross
			c.draw_rect(Rect2(at + Vector2(-3.5, -11), Vector2(7, 22)), coral)
			c.draw_rect(Rect2(at + Vector2(-11, -3.5), Vector2(22, 7)), coral)
			c.draw_rect(Rect2(at + Vector2(-3.5, -11), Vector2(7, 22)), ink, false, 1.5)
			c.draw_rect(Rect2(at + Vector2(-11, -3.5), Vector2(22, 7)), ink, false, 1.5)
		"ctrl":   # a target
			c.draw_arc(at, 10, 0, TAU, 32, ink, 3.0, true)
			c.draw_circle(at, 3.5, coral)
			for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				c.draw_line(at + d * 6, at + d * 13, ink, 2.0, true)
		"sup":    # a sparkle
			StyleB.sparkle(c, at, 12.0, ink)
			StyleB.sparkle(c, at, 7.0, coral)
		"summ":   # a paw
			c.draw_circle(at + Vector2(0, 4), 6.5, ink)
			for p in [Vector2(-8, -3), Vector2(-3, -8), Vector2(3, -8), Vector2(8, -3)]:
				c.draw_circle(at + p, 3.2, ink)
			c.draw_circle(at + Vector2(0, 4), 2.5, coral)
		"mob":    # a double chevron
			for x in [-7.0, 3.0]:
				c.draw_polyline(PackedVector2Array([at + Vector2(x - 4, -9), at + Vector2(x + 4, 0), at + Vector2(x - 4, 9)]),
					coral if x > 0 else ink, 3.5, true)
		_:
			c.draw_circle(at, 6.0, ink)


## An attack as a game icon: a tile with a hard shadow, the spell's image,
## its element as a cut corner and its cost on an ink tab.
func _attack(s: Dictionary, detail: Label) -> Control:
	var sid := int(s.id)
	var line := I18n.t("recruit.attack_line", {"name": Spells.name_of(sid),
		"ap": int(s.get("ap", 0)), "min": int(s.get("min", 0)), "max": int(s.get("max", 0))})
	var b := Button.new()
	b.name = "Spell%d" % sid
	b.custom_minimum_size = Vector2(64, 64)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = line
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var img := AssetPaths.load_image("ui/spells/%d.png" % sid)
	var tex: Texture2D = ImageTexture.create_from_image(img) if img != null else null
	var el := str(s.get("fx", {}).get("e", "neutral")) if s.get("fx") is Dictionary else "neutral"
	var ec: Color = ELEMENT_COL.get(el, ELEMENT_COL.neutral)
	b.draw.connect(func():
		var lit := b.is_hovered() or b.has_focus()
		var r := Rect2(Vector2(1, 1), b.size - Vector2(5, 5))
		b.draw_rect(Rect2(r.position + Vector2(3, 3), r.size), Color(UiStyle.B_INK, 0.9))
		b.draw_rect(r, Color.WHITE)
		if tex != null:
			b.draw_texture_rect(tex, r.grow(-5), false)
		var tr := r.position + Vector2(r.size.x, 0)
		b.draw_colored_polygon(PackedVector2Array([tr + Vector2(-19, 0), tr, tr + Vector2(0, 19)]), ec)
		b.draw_line(tr + Vector2(-19, 0), tr + Vector2(0, 19), UiStyle.B_INK, 2.0, true)
		var h := r.size.y
		b.draw_colored_polygon(PackedVector2Array([r.position + Vector2(0, h - 19), r.position + Vector2(25, h - 19),
			r.position + Vector2(20, h), r.position + Vector2(0, h)]), UiStyle.B_INK)
		b.draw_string(UiStyle.bold(900), r.position + Vector2(5, h - 5), str(int(s.get("ap", 0))),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.B_GOLD)
		b.draw_rect(r, UiStyle.B_CORAL if lit else UiStyle.B_INK, false, 3.0 if lit else 2.0))
	for sig in [b.mouse_entered, b.focus_entered]:
		sig.connect(func():
			detail.text = line
			detail.add_theme_color_override("font_color", UiStyle.B_INK)
			b.queue_redraw())
	for sig in [b.mouse_exited, b.focus_exited]:
		sig.connect(b.queue_redraw)
	return b


static func _star(c: Control, at: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2 + i * PI / 5
		pts.append(at + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.45))
	c.draw_colored_polygon(pts, col)


## The fighter on the drum, turned to `_dir`.
func _dress() -> void:
	var f := _fighter()
	var lib := str(f.get("actorDescriptorLibrary", ""))
	if lib.is_empty():
		return
	var look := "%s/%d" % [lib, _dir]
	if look == _look:
		return
	_look = look
	_spr.tints = f.get("actorMaterial", {})
	if not Direction8.load_idle(_spr, lib, _dir, "AnimMenu"):
		if not Direction8.load_idle(_spr, lib, _dir):
			Direction8.load_idle_any(_spr, lib)
