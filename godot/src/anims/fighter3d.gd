extends Node2D

## S35 pilot: a rigged 3D fighter (tools/blender/characters/meshy_fighter.py:
## the common 20 bones, the 10 base animations) drawn inside the fight.
## S33's technique A: the model lives in its own small transparent
## SubViewport with the arena's light and the game's orthographic camera,
## shown as a sprite whose origin is the feet. It hangs off an AnmSprite
## (AnmSprite.model3d), so fight_view keeps placing, sorting, occluding and
## labelling that sprite as before, and keeps asking for retail actions
## ("1_AnimMarche02"): take() turns them into the model's animation and
## facing. One viewport per fighter costs ~4 ms each (S33); a shared
## viewport for twelve fighters is the follow-up.
##
## Only fighters with a built model get one (model_for); the others stay
## retail sprites.

const ArenaScene := preload("res://src/maps/arena_scene.gd")
const Toon := preload("res://src/anims/toon.gd")

signal finished

const PX := 43.0 * 1.41421356     # px per world unit at zoom 1 (arena_layout.PX)
const BASE := Vector2i(220, 200)  # frame at zoom 1: arms up, a jump, a fall
const FEET := Vector2(0.5, 0.8)   # where the feet land inside the frame
const RES := 2.0                  # rendered at 2x: crisp at the usual zoom 2
## Wire Direction8 (0 E … 7 NE) → model yaw; the model faces +Z and the
## camera sits at yaw 45 (tools/art/anim_sheet.gd's table).
const YAW := {0: 135.0, 1: 90.0, 2: 45.0, 3: 0.0, 4: 315.0, 5: 270.0, 6: 225.0, 7: 180.0}
## The direction a horizontal mirror turns a wire direction into.
const MIRROR := {0: 4, 1: 3, 2: 2, 3: 1, 4: 0, 5: 7, 6: 6, 7: 5}
## breed → [male, female] model under art/characters/out (S35 pilot: Feca).
const MODELS := {1: ["feca_m", "feca_f"], 2: ["osamodas_m", "osamodas_f"],
		3: ["anutrof_m", "anutrof_f"], 4: ["sram_m", "sram_f"],
		5: ["xelor_m", "xelor_f"], 6: ["zurcarak_m", "zurcarak_f"],
		7: ["aniripsa_m", "aniripsa_f"], 8: ["yopuka_m", "yopuka_f"],
		9: ["ocra_m", "ocra_f"], 10: ["sadida_m", "sadida_f"],
		11: ["sacrogrito_m", "sacrogrito_f"], 12: ["pandawa_m", "pandawa_f"]}
const MODEL_DIR := "res://art/characters/out/%s.glb"

static var _templates := {}   # path -> Node3D (generated once, duplicated per fighter)

var anim := ""
var _dir := 1
var _once := false
var _hold := false
var _token := 0
var _vp: SubViewport
var _spr: Sprite2D
var _model: Node3D
var _player: AnimationPlayer


## The model path for a breed/sex, or "" when none is built.
static func model_for(breed: int, sex: int) -> String:
	if not MODELS.has(breed):
		return ""
	var path := MODEL_DIR % MODELS[breed][clampi(sex, 0, 1)]
	return path if FileAccess.file_exists(path) else ""


static func _template(path: String) -> Node3D:
	if _templates.has(path):
		return _templates[path]
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var t: Node3D = null
	if doc.append_from_file(ProjectSettings.globalize_path(path), st) == OK:
		t = doc.generate_scene(st)
		for p: AnimationPlayer in t.find_children("*", "AnimationPlayer", true, false):
			for n in p.get_animation_list():
				if n.ends_with("_loop"):
					p.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_templates[path] = t
	return t


## A fighter for `path`, or null when the GLB can't be read.
static func create(path: String, tints := {}) -> Node2D:
	var t := _template(path)
	if t == null:
		return null
	var f: Node2D = (load("res://src/anims/fighter3d.gd") as GDScript).new()
	f._build(t.duplicate(), tints)
	return f


func _build(model: Node3D, tints: Dictionary) -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(roundi(BASE.x * RES), roundi(BASE.y * RES))
	add_child(_vp)
	ArenaScene.add_lights(_vp)
	for we: WorldEnvironment in _vp.find_children("*", "WorldEnvironment", false, false):
		we.environment.background_mode = Environment.BG_CLEAR_COLOR
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = BASE.y / PX
	cam.rotation_degrees = Vector3(-30, 45, 0)
	var b := cam.transform.basis
	cam.position = b.z * 20.0 + b.y * (cam.size * (FEET.y - 0.5))
	cam.near = 0.1
	cam.far = 60.0
	_vp.add_child(cam)
	_model = model
	Toon.set_pixel(1.0 / (PX * RES))
	Toon.dress(_model, tints)
	_vp.add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] if not players.is_empty() else null
	if _player:
		_player.animation_finished.connect(_on_finished)
	_spr = Sprite2D.new()
	_spr.texture = _vp.get_texture()
	_spr.centered = false
	_spr.scale = Vector2.ONE / RES
	_spr.position = -Vector2(BASE) * FEET
	_spr.use_parent_material = true   # the arena occluder on the AnmSprite
	add_child(_spr)


## Retail action → animation: "<dir>_<Name>" as fight_view asks for it.
## Returns false for an action the model has no counterpart for, so the
## caller's fallback chain goes on.
func take(action: String, once: bool, hold: bool) -> bool:
	var cut := action.find("_")
	if cut < 0 or _player == null:
		return false
	var base := action.substr(cut + 1)
	var a := anim_for(base)
	if a == "":
		return false
	_dir = int(action.substr(0, cut))
	var end := a == "die_end"
	if end:
		a = "die"
	if not _player.has_animation(a):
		return false
	_once = once or end
	_hold = hold or end
	anim = a
	_player.play(a)
	if end:   # the corpse loop: lie still on the last frame
		_player.seek(_player.current_animation_length, true)
		_player.pause()
	elif _once and a.ends_with("_loop"):   # a lift into the carry: one cycle counts
		var token := _player.get_instance_id() + Time.get_ticks_usec()
		_token = token
		get_tree().create_timer(_player.current_animation_length).timeout.connect(func():
			if _token == token and anim == a:
				finished.emit())
	_face()
	return true


static func anim_for(base: String) -> String:
	if base.begins_with("AnimKO-Boucle") or base.begins_with("AnimPorte-KO-Boucle"):
		return "die_end"
	for p in ["AnimMort", "AnimKO", "AnimPorte-Mort", "AnimPorte-KO"]:
		if base.begins_with(p):
			return "die"
	for p in ["AnimStatiquePorte", "AnimMarchePorte", "Anim01Porte", "AnimHitPorte", "AnimTaclePorte"]:
		if base.begins_with(p):
			return "hit" if p.begins_with("AnimHit") or p.begins_with("AnimTacle") else "carry_loop"
	if base.begins_with("Anim02Porte") or base.begins_with("Anim03Porte"):
		return "throw"
	if base.begins_with("AnimHit") or base.begins_with("AnimTacle"):
		return "hit"
	for p in ["AnimStatique03", "AnimCarte", "AnimArme"]:
		if base.begins_with(p):
			return "melee"
	if base.begins_with("AnimStatique"):
		return "idle_loop"
	if base.begins_with("AnimMarche") or base.begins_with("AnimCourse"):
		return "walk_loop"
	if base.begins_with("AnimSaut"):
		return "jump"
	if base.begins_with("AnimSort") or base.begins_with("AnimCast"):
		return "cast"
	if base.begins_with("AnimEmote"):
		return "celebrate"
	return ""


func _process(_dt: float) -> void:
	_face()


## The AnmSprite mirrors itself for directions 3, 4 and 7 (the retail sets
## only ship five): cancel the mirror and turn the model to the true one.
func _face() -> void:
	var p := get_parent() as Node2D
	var flipped := p != null and p.scale.x < 0.0
	scale.x = -1.0 if flipped else 1.0
	var d: int = MIRROR[_dir] if flipped else _dir
	if _model:
		_model.rotation_degrees.y = YAW.get(d, 90.0)


func _on_finished(name: StringName) -> void:
	if not _once or String(name) != anim:
		return
	if _hold:
		_player.seek(_player.current_animation_length, true)
		_player.pause()
	finished.emit()
