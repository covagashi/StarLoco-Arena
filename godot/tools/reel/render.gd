extends SceneTree

## Reel director, part 2 (S11): play a replay into fight_view as a vertical
## clip. Run it under Godot's movie maker — tools/reel/make_reel.sh does — so
## every frame is written at a fixed 30 fps however slow the machine is, at
## the 540x960 its override.cfg sets.
##
## On top of the plain replay: a title card (the two sides, no brand), the camera on whoever acts, a
## slow-motion beat on every death, the winner card at the end, and only the
## fight's own banner/HUD on screen (no buttons, chat or transport).
##
##   godot --path godot --write-movie out/f.png \
##       --fixed-fps 30 -s tools/reel/render.gd -- --replay=<file.slr> \
##       [--speed=1.5] [--hud=banner|full] [--zoom=1.8 (max)]

const ReplayFile := preload("res://src/net/replay_file.gd")
const ReplayPlayer := preload("res://src/fight/replay_player.gd")
const State := preload("res://src/state.gd")

const FPS := 30.0
const INTRO_FRAMES := 45        # title card
const OUTRO_FRAMES := 75        # winner card
const SLOWMO_FRAMES := 36       # a death plays at SLOWMO of the speed
const SLOWMO := 0.3
const OP_FIGHTER_DIES := 4520
const OP_END_FIGHT := 8300

var opts := {"replay": "", "speed": "1.5", "hud": "banner", "zoom": "1.8"}
var fv: Node
var rc: Node
var head := {}
var _card: Control
var _frame := 0
var _slowmo := 0
var _focus := -1           # fighter the camera follows
var _end_at := -1
var _speed := 1.5


func _initialize() -> void:
	_start.call_deferred()


func _start() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	var replay := ReplayFile.read(str(opts.replay))
	if replay.is_empty():
		print("[reel] cannot read %s" % opts.replay)
		quit(1)
		return
	head = replay.header
	_speed = float(opts.speed)
	if ReplayPlayer.play_data(self, replay, false) != "":
		quit(1)
		return
	rc = State.replay
	rc.message_received.connect(_on_frame)
	rc.paused = true                       # held behind the title card
	fv = load("res://src/fight/fight_view.tscn").instantiate()
	root.add_child(fv)
	_strip_ui()
	var sides := _sides()
	_card = _title_card(sides[0], sides[1])
	root.add_child(_card)
	process_frame.connect(_tick)


## Only what a viewer of the fight needs: the map, the fighters, the floats,
## the versus, the event cards and the turn banner (or the whole HUD).
func _strip_ui() -> void:
	for p in ["UI/TopBar", "UI/Menu", "UI/Chat", "UI/SpellScroll", "UI/PassBtn",
			"UI/Info", "UI/ReplayBar"]:
		var n: Node = fv.get_node_or_null(p)
		if n != null:
			n.visible = false
			n.set_process(false)
	# the versus is laid out for landscape; the title card does its job
	if fv._versus != null and is_instance_valid(fv._versus):
		fv._versus.visible = false
	if str(opts.hud) == "banner":
		var hud: Node = fv._fight_hud
		for c in hud.get_children():
			if c.name != "Banner":
				c.visible = false


func _tick() -> void:
	_frame += 1
	# the UI rebuilds itself on layout passes: keep it stripped
	if _frame % 5 == 0:
		_strip_ui()
	if _frame == INTRO_FRAMES:
		_fade_out(_card)
		rc.paused = false
		rc.speed = _speed
	if _slowmo > 0:
		_slowmo -= 1
		if _slowmo == 0 and not rc.paused:
			Engine.time_scale = _speed
	_follow()
	if OS.get_environment("REEL_DEBUG") != "" and _frame % 30 == 0:
		print("[reel] f=%d cursor=%d/%d clock=%d scale=%.2f focus=%d" % [
			_frame, rc.cursor, rc.frames.size(), rc.elapsed_ms(), Engine.time_scale, _focus])
	if _end_at < 0 and fv._fight_over:
		_end_at = _frame
		# the result screen is the player's, not the clip's
		if fv._result_modal != null:
			fv._result_modal.visible = false
		Engine.time_scale = 1.0
		root.add_child(_winner_card())
	if _end_at >= 0:
		if fv._result_modal != null:
			fv._result_modal.visible = false
		if _frame - _end_at >= OUTRO_FRAMES:
			print("[reel] done: %d frames" % _frame)
			Engine.time_scale = 1.0
			quit(0)


func _on_frame(op: int, raw: PackedByteArray) -> void:
	match op:
		8104:   # turn begin: [i32][i32][i64 fighter]
			if raw.size() >= 16:
				_focus = _be64(raw, 8)
		OP_FIGHTER_DIES:
			if raw.size() >= 16:
				_focus = _be64(raw, 8)
			_slowmo = SLOWMO_FRAMES
			Engine.time_scale = _speed * SLOWMO


static func _be64(b: PackedByteArray, at: int) -> int:
	var v := 0
	for i in 8:
		v = (v << 8) | b[at + i]
	return v


## Frame the living fighters: the camera eases onto their bounding box, as
## tight as the portrait allows (zoom between 1 and --zoom), leaning toward
## whoever acts — unless a cast's own punch-in (fight_view's _zoom_tween)
## is running.
func _follow() -> void:
	var cam: Camera2D = fv.cam
	var tw: Tween = fv._zoom_tween
	if tw != null and tw.is_valid() and tw.is_running():
		return
	var box := Rect2()
	var any := false
	for id in fv._sprites:
		var spr: Node2D = fv._sprites[id]
		if not is_instance_valid(spr) or not State.fighters.has(id) or fv._dead.get(id, false):
			continue
		var p := spr.position + Vector2(0, -40)   # their middle, not their feet
		box = box.expand(p) if any else Rect2(p, Vector2.ZERO)
		any = true
	if not any:
		return
	var focus: Node2D = fv._sprites.get(_focus)
	var at := box.get_center()
	if focus != null and is_instance_valid(focus):
		at = at.lerp(focus.position + Vector2(0, -40), 0.35)
	var vp := Vector2(root.size)
	var grow := box.grow(90.0).size
	var z := clampf(minf(vp.x / maxf(grow.x, 1.0), vp.y * 0.6 / maxf(grow.y, 1.0)),
		1.0, float(opts.zoom))
	cam.zoom = cam.zoom.lerp(Vector2(z, z), 0.05)
	cam.position = cam.position.lerp(at, 0.07)


## The two sides' coach names, localised as the fight view shows them (the
## header keeps the server's French AI names): the recorder's side first.
func _sides() -> Array:
	var names := {}
	for c in State.fight_data.get("coaches", []):
		names[int(c.id)] = str(c.name)
	var out := []
	var mine := -1
	for t in State.fight_data.get("teams", []):
		var side := []
		for f in t.get("fighters", []):
			var cid := int(f.get("coach", -1))
			if cid == int(head.get("coach_id", -2)):
				mine = out.size()
			var n: String = names.get(cid, "")
			if n != "" and n not in side:
				side.append(n)
		out.append(" & ".join(side) if not side.is_empty() else str(t.get("name", "?")))
	while out.size() < 2:
		out.append("?")
	return [out[1], out[0]] if mine == 1 else out


func _base_card() -> Control:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, 0.88)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.name = "Box"
	c.add_child(box)
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.add_child(c)
	var holder := Control.new()
	holder.add_child(layer)
	return holder


func _line(card: Control, text: String, size: int, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 480
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	card.get_child(0).get_child(0).get_node("Box").add_child(l)


func _gold() -> Color:
	return Color("e8c66a")


func _title_card(left: String, right: String) -> Control:
	var card := _base_card()
	_line(card, left, 30)
	_line(card, "VS", 24, _gold())
	_line(card, right, 30)
	return card


func _winner_card() -> Control:
	var card := _base_card()
	var names := {}
	for c in State.fight_data.get("coaches", []):
		names[int(c.id)] = str(c.name)
	var won := []
	for id in State.fight_result.get("win_str", {}).keys():
		won.append(names.get(int(id), "?"))
	_line(card, I18n_t("replay.reel.winner"), 26, _gold())
	_line(card, " & ".join(won) if not won.is_empty() else "—", 36)
	var rect: Control = card.get_child(0).get_child(0)
	rect.modulate.a = 0.0
	create_tween().tween_property(rect, "modulate:a", 1.0, 0.4)
	return card


func _fade_out(card: Control) -> void:
	var rect: Control = card.get_child(0).get_child(0)
	var tw := create_tween()
	tw.tween_property(rect, "modulate:a", 0.0, 0.4)
	tw.tween_callback(card.queue_free)


func I18n_t(key: String) -> String:
	return root.get_node("I18n").t(key)
