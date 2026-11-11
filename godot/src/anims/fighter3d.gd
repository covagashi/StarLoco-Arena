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
const ArenaLayout := preload("res://src/maps/arena_layout.gd")
const Toon := preload("res://src/anims/toon.gd")
const FighterCards := preload("res://src/gamedata/fightercards.gd")

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
## summon look → [model, height in cells]; built at 1.45 like a fighter and
## scaled down here (owner, 2026-11-10: smaller than a fighter, ~0.9; the
## golem and the tree ~1.2; the crystal 8010, crystal_8010.py, 1.3 so its
## oval reads at the retail size).
const SUMMONS := {8001: ["summon_8001", 0.9], 8002: ["summon_8002", 0.9], 8003: ["summon_8003", 0.9],
		8004: ["summon_8004", 0.9], 8005: ["summon_8005", 0.9], 8006: ["summon_8006", 0.9],
		8007: ["summon_8007", 1.2], 8009: ["summon_8009", 1.2], 8010: ["summon_8010", 1.3]}
## coach sex → model (S35b: Meshy, one baked texture; skin and hair are
## tinted through <model>_mask.png, tools/art/coach_masks.py).
const COACHES := {0: "coach_7000", 1: "coach_7001"}
const BUILT_HEIGHT := 1.45
## Under the art root (ArenaLayout.root(): res://art in the editor, the
## art/ folder beside an exported game's executable, tools/art/pack_arenas.gd).
const MODEL_DIR := "characters/out/%s.glb"

static var _templates := {}   # path -> Node3D (generated once, duplicated per fighter)
static var _masks := {}       # path -> {tex, skin_ref, hair_ref} or {} (no mask beside it)
static var _heads := {}       # path -> AABB of the head (and hair) in skeleton space

## S35c: rigid equipment pieces (art/equipment, kiln) hung from a bone of
## the common rig, so a change of equipment swaps one node, not the figure.
## A hat sits on the figure's own head (its size measured on the mesh); a
## dofus floats beside the figure, with no bone.
const EQUIP_DIR := "equipment/out/models/%s.glb"
const BONE_OF := {"hat": "head", "weapon": "hand.R", "cape": "chest", "pet": "chest"}
const HAT_CROWN := 0.27      # inner width of a hat's crown as modelled (m)
const HAT_SINK := 0.36       # how far down the head (of its height) a hat sits
const DOFUS_AT := Vector3(0.38, 0.95, 0.1)   # beside the figure, at chest height
## A weapon is modelled upright with its grip at the base: held in the
## middle of the hand, the blade forward and a little down. It replaces the
## class's own weapon (owner, 2026-11-11): meshy_fighter.py --weapon=1 cuts
## that one out as the "class_weapon" mesh, hidden while a weapon is worn.
const WEAPON_GRIP := 0.06     # grip centre above the piece's base (m)
const WEAPON_HAND := 0.06     # how far down the hand bone the grip sits (m)
const WEAPON_DIR := Vector3(0, -0.35, 1)
const CLASS_WEAPON := "class_weapon"
## Fighter equipment card type (fightercards.json) → slot.
const FIGHTER_SLOT := {1: "weapon", 2: "pet", 3: "cape", 4: "hat", 5: "dofus"}
## Which piece each card shows: art/equipment/pieces.json
## {"fighter": {"<card id>": "<piece>"}, "coach": {…}}.
const PIECES := "equipment/pieces.json"
static var _pieces = null
var _worn := {}               # slot -> the piece's node
var _path := ""
var _worn_piece := {}         # slot -> piece name (wear_fighter_cards)
var _t := 0.0

var anim := ""
var _dir := 1
var _once := false
var _hold := false
var _token := 0
var _vp: SubViewport
var _spr: Sprite2D
var _model: Node3D
var _player: AnimationPlayer
var _res := RES
## The shadow on the floor (S35b: the figure's viewport has no floor, and
## the crystal 8010 floats): a soft ellipse under the feet, as wide as the
## figure is tall.
const SHADOW_R := 17.0            # px at zoom 1 for a fighter (1.45)
const SHADOW := Color(0.05, 0.04, 0.1, 0.4)
var _shadow_r := SHADOW_R


## S34: `--old-art` on the command line (after `--`) or PIPPOP_OLD_ART=1
## plays with the retail sprites while both kinds of art live side by side:
## every lookup below then answers "not built".
static func old_art() -> bool:
	return OS.get_environment("PIPPOP_OLD_ART") == "1" or "--old-art" in OS.get_cmdline_user_args()


## The path of a built model by name, or "" when it isn't built.
static func model_path(model: String) -> String:
	if old_art():
		return ""
	var path := ArenaLayout.root().path_join(MODEL_DIR % model)
	return path if FileAccess.file_exists(path) else ""


## The model path for a breed/sex, or "" when none is built.
static func model_for(breed: int, sex: int) -> String:
	if not MODELS.has(breed):
		return ""
	return model_path(MODELS[breed][clampi(sex, 0, 1)])


## The model path for a summon look, or "" when none is built.
static func summon_for(look: int) -> String:
	if not SUMMONS.has(look):
		return ""
	return model_path(SUMMONS[look][0])


## The coach model path for a sex, or "" when none is built.
static func coach_for(sex: int) -> String:
	return model_path(COACHES[clampi(sex, 0, 1)])


## The coach's picked skin and hair (Palettes.SKIN / HAIR, the swatches of
## the creation screen) as Toon tints.
static func coach_tints(skin: int, hair: int) -> Dictionary:
	var s: Vector3 = Palettes.pick(Palettes.SKIN, skin)
	var h: Vector3 = Palettes.pick(Palettes.HAIR, hair)
	return {"skin": Color(clampf(s.x, 0.0, 1.0), clampf(s.y, 0.0, 1.0), clampf(s.z, 0.0, 1.0)),
		"hair": Color(clampf(h.x, 0.0, 1.0), clampf(h.y, 0.0, 1.0), clampf(h.z, 0.0, 1.0))}


## The 3D figure for a retail anim set, or {} when none is built:
## {path, scale, coach}.
static func for_set(set_dir: String) -> Dictionary:
	var fig := figure_of(set_dir)
	if fig.is_empty():
		return {}
	var path := model_path(fig.model)
	if path == "":
		return {}
	return {"path": path, "scale": fig.scale, "coach": fig.coach}


## Which figure a retail anim set stands for, built or not: {model, scale,
## coach}. "anims/coach_700<sex>" is a coach, and so is
## "anims/fighter_700<sex>"; "anims/fighter_-1<breed><sex>" a fighter
## (fight_view.FIGHTER_FILES); "anims/npc_<look>" a summon.
static func figure_of(set_dir: String) -> Dictionary:
	var name := set_dir.get_file()
	if name in ["coach_7000", "coach_7001", "fighter_7000", "fighter_7001"]:
		return {"model": COACHES[int(name.right(1))], "scale": 1.0, "coach": true}
	if name.begins_with("fighter_-1") and name.length() >= 12:
		var code := name.substr(10)
		var breed := int(code.left(-1))
		if MODELS.has(breed):
			return {"model": MODELS[breed][clampi(int(code.right(1)), 0, 1)], "scale": 1.0, "coach": false}
	elif name.begins_with("npc_"):
		var look := int(name.substr(4))
		if SUMMONS.has(look):
			return {"model": SUMMONS[look][0], "scale": summon_scale(look), "coach": false}
	return {}


## Retail channel tints (Palettes.coach_tints: {1: skin, 2: hair}, ×1.25)
## back to the swatch colours Toon tints with.
static func from_channels(tints: Dictionary) -> Dictionary:
	var out := {}
	for pair in [[1, "skin"], [2, "hair"]]:
		if tints.get(pair[0]) is Vector3:
			var v: Vector3 = tints[pair[0]] / 1.25
			out[pair[1]] = Color(clampf(v.x, 0.0, 1.0), clampf(v.y, 0.0, 1.0), clampf(v.z, 0.0, 1.0))
	return out


## A summon's height relative to a fighter's.
static func summon_scale(look: int) -> float:
	return float(SUMMONS[look][1]) / BUILT_HEIGHT if SUMMONS.has(look) else 1.0


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
## `res`: render scale; a menu that draws the figure 2.5× big asks for
## 2.5 so it stays crisp.
static func create(path: String, tints := {}, scale := 1.0, res := RES) -> Node2D:
	var t := _template(path)
	if t == null:
		return null
	var f: Node2D = (load("res://src/anims/fighter3d.gd") as GDScript).new()
	var m: Node3D = t.duplicate()
	m.scale = Vector3.ONE * scale
	f._res = res
	f._shadow_r = SHADOW_R * scale
	f._path = path
	f.use_parent_material = true   # the arena occluder hides the shadow too
	f._build(m, tints, _mask(path))
	return f


## The skin/hair mask beside a model (coach_masks.py), or {}.
static func _mask(path: String) -> Dictionary:
	if _masks.has(path):
		return _masks[path]
	var out := {}
	var png := path.get_basename() + "_mask.png"
	if FileAccess.file_exists(png):
		var img := Image.load_from_file(ProjectSettings.globalize_path(png))
		if img != null:
			out = {"tex": ImageTexture.create_from_image(img)}
			var refs = JSON.parse_string(FileAccess.get_file_as_string(path.get_basename() + "_mask.json"))
			if refs is Dictionary:
				out.merge(refs)
	_masks[path] = out
	return out


## Retint a built figure (the creation screen's swatches) without a rebuild.
func retint(tints: Dictionary, path: String) -> void:
	Toon.dress(_model, tints, _mask(path))


func _build(model: Node3D, tints: Dictionary, mask := {}) -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = Vector2i(roundi(BASE.x * _res), roundi(BASE.y * _res))
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
	Toon.set_pixel(1.0 / (PX * _res))
	Toon.dress(_model, tints, mask)
	_vp.add_child(_model)
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	_player = players[0] if not players.is_empty() else null
	if _player:
		_player.animation_finished.connect(_on_finished)
	_spr = Sprite2D.new()
	_spr.texture = _vp.get_texture()
	_spr.centered = false
	_spr.scale = Vector2.ONE / _res
	_spr.position = -Vector2(BASE) * FEET
	_spr.use_parent_material = true   # the arena occluder on the AnmSprite
	add_child(_spr)


## The path of a built equipment piece by name, or "" when it isn't built.
static func piece_path(piece: String) -> String:
	if old_art() or piece == "":
		return ""
	var path := ArenaLayout.root().path_join(EQUIP_DIR % piece)
	return path if FileAccess.file_exists(path) else ""


## Put `piece` (an art/equipment model name) on `slot`, or take the slot
## off with "". Unknown pieces leave the slot empty.
func equip(slot: String, piece: String) -> void:
	if _worn.has(slot):
		(_worn[slot] as Node).queue_free()
		_worn.erase(slot)
		if slot == "weapon":
			show_class_weapon(_model, true)
	var n := hang(_model, _path, slot, piece)
	if n != null:
		_worn[slot] = n


## The piece a card shows ("fighter" or "coach" table), or "".
static func piece_of(table: String, card: int) -> String:
	if _pieces == null:
		_pieces = JSON.parse_string(FileAccess.get_file_as_string(ArenaLayout.root().path_join(PIECES)))
		if not (_pieces is Dictionary):
			_pieces = {}
	return String((_pieces as Dictionary).get(table, {}).get(str(card), ""))


## The slot → piece a fighter's equipped cards ([{slot, id}], ET2) show.
static func fighter_pieces(cards: Array) -> Dictionary:
	var out := {}
	for c in cards:
		var cid := int(c.get("id", -1))
		var slot: String = FIGHTER_SLOT.get(FighterCards.slot_type(cid), "")
		if slot != "" and piece_of("fighter", cid) != "":
			out[slot] = piece_of("fighter", cid)
	return out


## Dress a fighter in its equipped cards: every slot it has a piece for,
## the others taken off.
func wear_fighter_cards(cards: Array) -> void:
	var want := fighter_pieces(cards)
	for slot in FIGHTER_SLOT.values():
		if String(want.get(slot, "")) != String(_worn_piece.get(slot, "")):
			equip(slot, want.get(slot, ""))
			_worn_piece[slot] = want.get(slot, "")


func worn() -> Dictionary:
	return _worn


## Hang `piece` on `model` (built from `path`) at `slot`; returns the node
## that holds it (free it to take it off), or null.
static func hang(model: Node3D, path: String, slot: String, piece: String) -> Node3D:
	var pp := piece_path(piece)
	var t := _template(pp) if pp != "" else null
	if t == null or model == null:
		return null
	var p: Node3D = t.duplicate()
	Toon.dress(p)
	var skel := _skeleton(model)
	if slot == "dofus" or skel == null or not BONE_OF.has(slot):
		var holder := Node3D.new()
		holder.name = "dofus"
		holder.position = DOFUS_AT
		holder.add_child(p)
		model.add_child(holder)
		return holder
	var bone := skel.find_bone(BONE_OF[slot])
	if bone < 0:
		p.free()
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = BONE_OF[slot]
	skel.add_child(att)
	att.add_child(p)
	if slot == "hat":
		var head := _head_box(model, path, skel)
		var k := clampf(head.size.x * 0.85 / HAT_CROWN, 0.5, 1.6)
		var at := Vector3(head.get_center().x, head.end.y - head.size.y * HAT_SINK, head.get_center().z)
		# skeleton space → the head bone's rest frame
		var rest := skel.get_bone_global_rest(bone)
		p.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3.ONE * k), at)
	elif slot == "weapon":
		var rest := skel.get_bone_global_rest(bone)
		var grip := rest * Vector3(0, WEAPON_HAND, 0)
		var y := WEAPON_DIR.normalized()
		var x := Vector3.RIGHT
		var z := x.cross(y).normalized()
		var b := Basis(x, y, z)
		p.transform = rest.affine_inverse() * Transform3D(b, grip - y * WEAPON_GRIP)
		show_class_weapon(model, false)
	return att


## Show or hide the class's own weapon (a mesh cut out by meshy_fighter.py).
static func show_class_weapon(model: Node3D, on: bool) -> void:
	for n in model.find_children(CLASS_WEAPON + "*", "MeshInstance3D", true, false):
		(n as Node3D).visible = on


static func _skeleton(model: Node3D) -> Skeleton3D:
	var all := model.find_children("*", "Skeleton3D", true, false)
	return all[0] if not all.is_empty() else null


## The box around every vertex the head bone moves most (head and hair),
## in skeleton space, measured once per model.
static func _head_box(model: Node3D, path: String, skel: Skeleton3D) -> AABB:
	if _heads.has(path):
		return _heads[path]
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null:
			continue
		var head_binds := {}
		for b in mi.skin.get_bind_count():
			var bn := String(mi.skin.get_bind_name(b))
			if bn == "":
				bn = skel.get_bone_name(mi.skin.get_bind_bone(b))
			if bn == "head":
				head_binds[b] = true
		# mesh space → skeleton space (both under the model)
		var to_skel := _rel(model, skel).affine_inverse() * _rel(model, mi)
		for s in mi.mesh.get_surface_count():
			var a := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones = a[Mesh.ARRAY_BONES]
			var weights = a[Mesh.ARRAY_WEIGHTS]
			if bones == null or weights == null:
				continue
			var per: int = bones.size() / verts.size()
			for i in verts.size():
				var best := 0
				for j in per:
					if weights[i * per + j] > weights[i * per + best]:
						best = j
				if not head_binds.has(int(bones[i * per + best])):
					continue
				var v := to_skel * verts[i]
				if first:
					box = AABB(v, Vector3.ZERO)
					first = false
				else:
					box = box.expand(v)
	_heads[path] = box
	return box


## A node's transform relative to the model root.
static func _rel(model: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null and n != model:
		t = n.transform * t
		n = n.get_parent() as Node3D
	return t


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


func _process(dt: float) -> void:
	_face()
	if _worn.has("dofus"):   # a slow bob and turn
		_t += dt
		var d: Node3D = _worn.dofus
		d.position = DOFUS_AT + Vector3(0, sin(_t * 2.0) * 0.03, 0)
		d.rotation.y = _t * 0.8


func _draw() -> void:   # drawn before the child sprite: under the feet
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
	draw_circle(Vector2.ZERO, _shadow_r, SHADOW, true, -1.0, true)
	draw_circle(Vector2.ZERO, _shadow_r * 0.65, SHADOW, true, -1.0, true)


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
