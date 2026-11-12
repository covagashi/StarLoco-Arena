extends Node2D

## S35 pilot: a rigged 3D fighter (tools/blender/characters/meshy_fighter.py:
## the common 20 bones, the 11 base animations) drawn inside the fight.
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
static var _boxes := {}       # "path|bones" -> AABB of those bones' vertices in skeleton space
static var _radii := {}       # "path|bone" -> how thick that limb is (m)

## S35c: rigid equipment pieces (art/equipment, kiln) hung from a bone of
## the common rig, so a change of equipment swaps one node, not the figure.
## A hat sits on the figure's own head (its size measured on the mesh); a
## dofus floats beside the figure, with no bone. A cape hangs on the back
## and a pet rides the left shoulder, both placed on the torso as measured.
const EQUIP_DIR := "equipment/out/models/%s.glb"
const BONE_OF := {"hat": "head", "weapon": "hand.R", "cape": "chest", "pet": "chest",
	"shoulders": "upper_arm.L", "bracelets": "forearm.L"}
const HAT_CROWN := 0.27      # inner width of a hat's crown as modelled (m)
const HAT_SINK := 0.36       # how far down the head (of its height) a hat sits
## The head box counts hair, horns and ears: a wide one would blow the hat
## up, so its scale stays near the modelled size.
const HAT_MIN := 0.8
const HAT_MAX := 1.15
## A cape (art/equipment/capes.kx.js) is modelled with the middle of its
## collar at the origin, hanging down -Y behind -Z; it sits on the back at
## shoulder height, scaled to the torso's width.
const CAPE_WIDTH := 0.34     # shoulder width a cape is modelled for (m)
const CAPE_TOP := 0.05       # how far below the torso's top the collar sits (m)
const CAPE_MIN := 0.85
const CAPE_MAX := 1.2
## A pet (art/equipment/pets.kx.js) stands on its feet at the origin,
## facing +Z, on the left shoulder.
const PET_OUT := 0.1         # how far out from the arm's joint it stands (m)
const PET_SCALE := 1.4       # modelled small: at game scale it reads beside the head
## A cape is rigid but swings from its collar (owner, 2026-11-11: "estaría
## bien que ondeen"): a slow sway standing, flared back and fluttering
## while walking. Degrees about the model's X; + lifts the hem backwards.
const CAPE_SWAY := 2.0
const CAPE_WALK := 12.0
const CAPE_FLUTTER := 4.0
const DOFUS_AT := Vector3(0.38, 0.95, 0.1)   # beside the figure, at chest height
## The coach's shoulderpads and bracelets come in pairs, one per arm, on the
## upper arm and the forearm (they follow the arm when it lifts). A piece is
## modelled for the left arm, its outside towards +X; the right arm wears it
## mirrored, or "<piece>_r" when the pair differs (Jalatranki, yellow and
## red). Both are scaled to the arm's thickness as measured on the figure.
## A shoulderpad (coach_shoulders.kx.js): upright, facing +Z, its origin
## on the skin at the top of the shoulder (measured on the figure), a little
## out from the joint, over the deltoid. A bracelet
## (coach_bracelets.kx.js): a sleeve about +Y (along the forearm, +Y towards
## the elbow), centred on the origin, facing +Z, set down the forearm.
const PAD_ARM := 0.05         # upper arm radius a shoulderpad is modelled for (m)
const PAD_OUT := 0.3          # how far out from the joint it sits (of the arm's radius)
const CUFF_ARM := 0.04        # forearm radius a bracelet is modelled for (m)
const CUFF_AT := 0.6          # how far down the forearm (of its length) it sits
const ARM_MIN := 0.75
const ARM_MAX := 1.4
## A weapon is modelled upright with the middle of its grip at the origin
## (art/equipment/weapons.kx.js): held in the middle of the hand, the blade
## forward and a little down. Its family (the name's prefix) can change the
## hand and the direction: a bow in the left hand, upright; a staff upright
## (a standard too, turned so its cloth hangs out and back);
## daggers come in pairs, one per hand. No figure holds a weapon of its own
## (owner, 2026-11-11: meshy_fighter.py --drop_weapon=1 took the Yopuka f's
## sword out).
const WEAPON_HAND := 0.06     # how far down the hand bone the grip sits (m)
const WEAPON_DIR := Vector3(0, -0.35, 1)
const WEAPON_STYLES := {
	"bow_": {"hand": "hand.L", "dir": Vector3(0, 1, 0.15)},
	"staff_": {"dir": Vector3(0, 1, 0.35)},
	# a standard (coach_staffs.kx.js): upright like a staff, its cloth (on the
	# piece's -X) turned about the pole to hang out and back; straight out, the
	# isometric camera drew it across the body (owner, 2026-11-11)
	"banner_": {"dir": Vector3(0, 1, 0.2), "turn": 55.0},
	"dagger_": {"pair": true},
}
## Fighter equipment card type (fightercards.json) → slot.
const FIGHTER_SLOT := {1: "weapon", 2: "pet", 3: "cape", 4: "hat", 5: "dofus"}
## Coach equipment slot (5201's 0-based, as 5200 and 60040 carry it) → the
## piece slot on the figure: hat, shoulderpads, bracelets, staff (held like a
## weapon), cape, pet, and the garments: skirt, trousers, boots, torso,
## and the mark (a tattoo on the skin, made like a garment); hair (2) is
## only a colour.
const COACH_SLOT := {0: "hat", 1: "mark", 3: "shoulders", 4: "bracelets", 5: "skirt", 6: "pants", 7: "weapon",
	8: "cape", 9: "pet", 10: "boots", 11: "torso"}
## S35c: the coach's garments bend with the body
## (tools/blender/characters/coach_garment.py): made from each coach figure
## with its skin weights, so the file is per figure; the garment's mesh goes
## on the figure's own skeleton, beside the body.
const GARMENT_DIR := "equipment/out/garments/%s/%s.glb"
const GARMENTS := ["skirt", "pants", "boots", "torso", "mark"]
## Which piece each card shows: art/equipment/pieces.json
## {"fighter": {"<card id>": "<piece>"}, "coach": {…}}.
const PIECES := "equipment/pieces.json"
static var _pieces = null
var _worn := {}               # slot -> the piece's node
var _hair_fx := 0             # S37: the hair effect shown (HAIR_FX id)
var _hair_node: Node3D        # its particles, on the head bone
var _path := ""
var _worn_piece := {}         # slot -> piece name asked for (equip)
var _t := 0.0
var _cape_flare := 0.0       # degrees the cape is lifted back now (_swing)

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
	if _hair_fx != 0:   # the dress swapped its own materials back in
		set_hair_fx(_hair_fx)


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
		var old: Node = _worn[slot]
		if old.has_meta("twin"):   # the left dagger of a pair
			(old.get_meta("twin") as Node).queue_free()
		old.queue_free()
		_worn.erase(slot)
	var n := hang(_model, _path, slot, piece)
	if n != null:
		_worn[slot] = n
	_worn_piece[slot] = piece


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


## The slot → piece a coach's worn cards ([{slot, id}], 5200 / 60040) show.
static func coach_pieces(cards: Array) -> Dictionary:
	var out := {}
	for c in cards:
		var slot: String = COACH_SLOT.get(int(c.get("slot", -1)), "")
		var piece := piece_of("coach", int(c.get("id", -1)))
		if slot != "" and piece != "":
			out[slot] = piece
	return out


## Dress a fighter in its equipped cards: every slot it has a piece for,
## the others taken off.
func wear_fighter_cards(cards: Array) -> void:
	_wear(fighter_pieces(cards), FIGHTER_SLOT.values())


## Dress a coach in its worn cards, the same way.
func wear_coach_cards(cards: Array) -> void:
	_wear(coach_pieces(cards), COACH_SLOT.values())


func _wear(want: Dictionary, slots: Array) -> void:
	for slot in slots:
		if String(want.get(slot, "")) != String(_worn_piece.get(slot, "")):
			equip(slot, want.get(slot, ""))


func worn() -> Dictionary:
	return _worn


## Hang `piece` on `model` (built from `path`) at `slot`; returns the node
## that holds it (free it to take it off), or null.
## S37: the few garments that are alive, by piece — Toon.dress's `live`:
## gelatina trembles, the Superjefe's gold glints, the Aurea flamma burns
## ("embers": where, in the piece, a few sparks rise from its flame).
const LIVE := {
	"pants_gelatina": {"jelly": 0.014},
	"torso_gelatina": {"jelly": 0.01},
	"boots_gelatina": {"jelly": 0.009},
	"hat_jelly": {"jelly": 0.012},
	"pants_superjefe": {"shine": 1.4},
	"banner_flame": {"flame": 1.0, "only": "flameR", "embers": Vector3(-0.08, 0.62, 0.0)},
}


## S37: the hair effect cosmetics (server game/cosmetics.go ids): the
## hair texels of the coach's mask take a colour and glow (glow rgb +
## strength, pulse speed) and a few particles come off the hair — sizes
## and speeds in head widths, from `low` (of the head's height) under its top.
const HAIR_FX := {
	1: {"glow": Color(1.0, 0.45, 0.1, 0.65), "pulse": 9.0,      # fire
		"n": 18, "life": 0.6, "speed": [1.0, 2.0], "lift": 1.4, "spread": 25.0, "size": 0.24, "low": 0.45,
		"ramp": [Color(1.0, 0.92, 0.5), Color(1.0, 0.45, 0.08), Color(0.8, 0.1, 0.02, 0.0)]},
	2: {"glow": Color(0.55, 0.85, 1.0, 0.5), "pulse": 1.5,      # frost
		"n": 12, "life": 1.6, "speed": [0.3, 0.6], "lift": -0.25, "spread": 70.0, "size": 0.17, "low": 0.3,
		"ramp": [Color(1.0, 1.0, 1.0), Color(0.7, 0.92, 1.0), Color(0.4, 0.7, 1.0, 0.0)]},
	3: {"glow": Color(0.5, 0.62, 1.0, 0.6), "pulse": 30.0,      # storm
		"n": 14, "life": 0.25, "speed": [2.0, 4.0], "lift": 0.0, "spread": 180.0, "size": 0.14, "low": 0.3,
		"ramp": [Color(1.0, 1.0, 1.0), Color(0.6, 0.75, 1.0), Color(0.5, 0.4, 1.0, 0.0)]},
	4: {"glow": Color(1.0, 0.8, 0.3, 0.5), "pulse": 3.0,        # gold
		"n": 8, "life": 1.2, "speed": [0.2, 0.5], "lift": 0.3, "spread": 60.0, "size": 0.15, "low": 0.3,
		"ramp": [Color(1.0, 1.0, 0.85), Color(1.0, 0.82, 0.3), Color(0.9, 0.6, 0.1, 0.0)]},
}


## Show hair effect `id` (HAIR_FX; 0 or unknown = none) on a coach figure
## (one built from a masked Meshy coach; others have no hair texels).
func set_hair_fx(id: int) -> void:
	_hair_fx = id
	if _hair_node != null:
		_hair_node.queue_free()
		_hair_node = null
	if _model != null:
		_hair_node = hair_fx(_model, _path, id)


## The hair effect on `model` (built from `path`): its hair texels glow, and
## the particles (returned, on the head bone; null without them) rise.
static func hair_fx(model: Node3D, path: String, id: int) -> Node3D:
	var fx: Dictionary = HAIR_FX.get(id, {})
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("garment") or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as ShaderMaterial
			if mat == null or not mat.get_shader_parameter("has_mask"):
				continue
			if not mat.has_meta("own"):   # toon.gd shares materials between figures
				mat = mat.duplicate()
				mat.set_meta("own", true)
				mi.set_surface_override_material(s, mat)
			mat.set_shader_parameter("hair_glow", fx.get("glow", Color(0, 0, 0, 0)))
			mat.set_shader_parameter("hair_pulse", float(fx.get("pulse", 0.0)))
	var skel := _skeleton(model)
	var bone := skel.find_bone("head") if skel != null else -1
	if fx.is_empty() or bone < 0:
		return null
	var head := _bones_box(model, path, skel, ["head"])
	var w := head.size.x
	var at := Vector3(head.get_center().x, head.end.y - head.size.y * float(fx.low), head.get_center().z)
	var p := _sparks(fx.ramp, w * float(fx.size))
	p.amount = int(fx.n)
	p.lifetime = float(fx.life)
	p.emission_sphere_radius = w * 0.38
	p.spread = float(fx.spread)
	p.initial_velocity_min = w * float(fx.speed[0])
	p.initial_velocity_max = w * float(fx.speed[1])
	p.gravity = Vector3(0, w * float(fx.lift), 0)
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	skel.add_child(att)
	att.add_child(p)
	p.transform = skel.get_bone_global_rest(bone).affine_inverse() * Transform3D(Basis(), at)
	return att


## A thin stream of sparks rising from `at` (piece space): ten unshaded
## billboards, light enough for the web demo.
static func _embers(at: Vector3) -> CPUParticles3D:
	var e := _sparks([Color(1.0, 0.9, 0.45), Color(1.0, 0.45, 0.1), Color(0.9, 0.15, 0.05, 0.0)], 0.05)
	e.position = at
	e.amount = 10
	e.lifetime = 0.9
	e.emission_sphere_radius = 0.03
	e.spread = 25.0
	e.initial_velocity_min = 0.18
	e.initial_velocity_max = 0.32
	e.gravity = Vector3(0, 0.2, 0)
	return e


static var _spark_mat: StandardMaterial3D


## Soft round additive billboards going up, coloured by `ramp` (start, mid,
## end); callers set the amount, life and motion.
static func _sparks(ramp: Array, size: float) -> CPUParticles3D:
	if _spark_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		var dot := GradientTexture2D.new()   # a soft round spark
		dot.fill = GradientTexture2D.FILL_RADIAL
		dot.fill_from = Vector2(0.5, 0.5)
		dot.fill_to = Vector2(1.0, 0.5)
		dot.gradient = Gradient.new()
		dot.gradient.set_color(0, Color.WHITE)
		dot.gradient.set_color(1, Color(1, 1, 1, 0))
		dot.gradient.add_point(0.45, Color(1, 1, 1, 0.9))
		dot.width = 16
		dot.height = 16
		m.albedo_texture = dot
		_spark_mat = m
	var e := CPUParticles3D.new()
	e.lifetime_randomness = 0.4
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = _spark_mat
	e.mesh = quad
	e.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	e.direction = Vector3.UP
	e.scale_amount_min = 0.5
	e.scale_amount_max = 1.0
	var g := Gradient.new()
	g.set_color(0, ramp[0])
	g.set_color(1, ramp[2])
	g.add_point(0.35, ramp[1])
	e.color_ramp = g
	return e


static func hang(model: Node3D, path: String, slot: String, piece: String) -> Node3D:
	if slot in GARMENTS:
		return _dress_garment(model, path, piece)
	var pp := piece_path(piece)
	var t := _template(pp) if pp != "" else null
	if t == null or model == null:
		return null
	var p: Node3D = t.duplicate()
	Toon.dress(p, {}, {}, LIVE.get(piece, {}))
	if LIVE.get(piece, {}).has("embers"):
		p.add_child(_embers(LIVE[piece].embers))
	var skel := _skeleton(model)
	if slot == "weapon" and skel != null:
		var st := weapon_style(piece)
		var hold := _grip(skel, p, st.get("hand", "hand.R"), st.get("dir", WEAPON_DIR), st.get("turn", 0.0))
		if hold == null:
			p.free()
			return null
		if st.get("pair", false):
			var p2: Node3D = t.duplicate()
			Toon.dress(p2)
			var twin := _grip(skel, p2, "hand.L", st.get("dir", WEAPON_DIR), st.get("turn", 0.0))
			if twin != null:
				hold.set_meta("twin", twin)
		return hold
	if slot in ["shoulders", "bracelets"] and skel != null:
		var left := _on_arm(model, path, skel, slot, p, ".L")
		if left == null:
			p.free()
			return null
		var rp := piece_path(piece + "_r")
		var p2: Node3D = (_template(rp) if rp != "" else t).duplicate()
		Toon.dress(p2)
		var right := _on_arm(model, path, skel, slot, p2, ".R")
		if right != null:
			left.set_meta("twin", right)
		else:
			p2.free()
		return left
	if slot != "dofus" and (skel == null or not BONE_OF.has(slot)):
		p.free()   # a slot with no bone (yet) shows nothing
		return null
	if slot == "dofus":
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
	var k := 1.0
	var at := Vector3.ZERO
	if slot == "hat":
		var head := _bones_box(model, path, skel, ["head"])
		k = clampf(head.size.x * 0.85 / HAT_CROWN, HAT_MIN, HAT_MAX)
		at = Vector3(head.get_center().x, head.end.y - head.size.y * HAT_SINK, head.get_center().z)
	else:
		var torso := _bones_box(model, path, skel, ["spine", "chest"])
		if slot == "cape":
			k = clampf(torso.size.x / CAPE_WIDTH, CAPE_MIN, CAPE_MAX)
			at = Vector3(torso.get_center().x, torso.end.y - CAPE_TOP, torso.position.z)
		else:   # pet: on top of the left shoulder, out from the arm's joint
			var arm := skel.find_bone("upper_arm.L")
			var j := skel.get_bone_global_rest(arm).origin if arm >= 0 else Vector3(torso.end.x, torso.end.y, 0)
			var top := _bones_box(model, path, skel, ["shoulder.L", "upper_arm.L"]).end.y
			at = Vector3(j.x + PET_OUT * signf(j.x), maxf(top, j.y), torso.get_center().z)
			k = PET_SCALE
	# skeleton space → the bone's rest frame
	var rest := skel.get_bone_global_rest(bone)
	p.transform = rest.affine_inverse() * Transform3D(Basis.from_scale(Vector3.ONE * k), at)
	p.set_meta("rest", p.transform)   # a cape swings about it (_swing)
	return att


## The built garment `piece` for the figure at `path`, or "".
static func garment_path(path: String, piece: String) -> String:
	if old_art() or piece == "":
		return ""
	var p := ArenaLayout.root().path_join(GARMENT_DIR % [path.get_file().get_basename(), piece])
	return p if FileAccess.file_exists(p) else ""


## Put the garment's mesh on the figure's skeleton, beside the body (same
## parent, same transform), bound by bone name; null without it.
static func _dress_garment(model: Node3D, path: String, piece: String) -> Node3D:
	var gp := garment_path(path, piece)
	var t := _template(gp) if gp != "" else null
	var skel := _skeleton(model)
	if t == null or skel == null:
		return null
	var body: MeshInstance3D = null
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and not mi.has_meta("garment"):
			body = mi
			break
	var src := t.find_children("*", "MeshInstance3D", true, false)
	if body == null or src.is_empty():
		return null
	var g: MeshInstance3D = (src[0] as MeshInstance3D).duplicate()
	g.set_meta("garment", piece)
	g.transform = body.transform
	body.get_parent().add_child(g)
	g.skeleton = g.get_path_to(skel)
	Toon.dress(g, {}, {}, LIVE.get(piece, {}))
	return g


## `p` (a shoulderpad or a bracelet, modelled for the left arm) on the arm
## of `side` (".L" or ".R"), mirrored on the arm whose outside is -X; null
## without the bones.
static func _on_arm(model: Node3D, path: String, skel: Skeleton3D, slot: String, p: Node3D, side: String) -> BoneAttachment3D:
	var name := ("upper_arm" if slot == "shoulders" else "forearm") + side
	var bone := skel.find_bone(name)
	var next := skel.find_bone(("forearm" if slot == "shoulders" else "hand") + side)
	if bone < 0 or next < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = name
	skel.add_child(att)
	att.add_child(p)
	var a := skel.get_bone_global_rest(bone).origin
	var b := skel.get_bone_global_rest(next).origin
	var out := signf(a.x) if a.x != 0.0 else 1.0
	var r := _limb_radius(model, path, skel, name, a, b)
	var place: Transform3D
	if slot == "shoulders":
		var k := clampf(r / PAD_ARM, ARM_MIN, ARM_MAX)
		var top := _shoulder_top(model, path, skel, side, a, r)
		place = Transform3D(Basis.from_scale(Vector3(out * k, k, k)), Vector3(a.x + out * r * PAD_OUT, top, a.z))
	else:   # along the forearm, +Y to the elbow, +Z to the front
		var k := clampf(r / CUFF_ARM, ARM_MIN, ARM_MAX)
		var y := (a - b).normalized()
		var x := y.cross(Vector3.BACK).normalized()
		var z := x.cross(y)
		place = Transform3D(Basis(x, y, z) * Basis.from_scale(Vector3(out * k, k, k)), a.lerp(b, CUFF_AT))
	var rest := skel.get_bone_global_rest(bone)
	p.transform = rest.affine_inverse() * place
	return att


## How thick the limb `name` (from joint `a` to joint `b`) is: the median
## distance from that line of the vertices mostly weighted to it, in
## skeleton space; measured once per figure.
static func _limb_radius(model: Node3D, path: String, skel: Skeleton3D, name: String, a: Vector3, b: Vector3) -> float:
	var key := path + "|" + name
	if _radii.has(key):
		return _radii[key]
	var d: Array[float] = []
	var ab := b - a
	for v in _owned_verts(model, skel, [name]):
		var u := clampf((v - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if u > 0.15 and u < 0.85:   # off the joints, where the next limb bulges
			d.append(v.distance_to(a + ab * u))
	d.sort()
	var r: float = d[d.size() / 2] if not d.is_empty() else 0.0
	_radii[key] = r
	return r


## The height of the skin on top of the shoulder: the highest vertex of the
## shoulder and the upper arm right over the joint `a` (within half the arm's
## radius `r` across); measured once per figure.
static func _shoulder_top(model: Node3D, path: String, skel: Skeleton3D, side: String, a: Vector3, r: float) -> float:
	var key := path + "|top" + side
	if _radii.has(key):
		return _radii[key]
	var top := a.y + r
	var found := false
	for v in _owned_verts(model, skel, ["shoulder" + side, "upper_arm" + side]):
		if absf(v.x - a.x) < r * 0.5 and absf(v.z - a.z) < r:
			top = v.y if not found else maxf(top, v.y)
			found = true
	_radii[key] = top
	return top


## A weapon's family by its name: {hand, dir, pair}, all optional.
static func weapon_style(piece: String) -> Dictionary:
	for pre in WEAPON_STYLES:
		if piece.begins_with(pre):
			return WEAPON_STYLES[pre]
	return {}


## `p` held in `hand`, its grip (the origin) in the middle of the hand and
## its +Y along `dir` (model space, at rest), turned `turn` degrees about
## that axis, or null without that bone.
static func _grip(skel: Skeleton3D, p: Node3D, hand: String, dir: Vector3, turn := 0.0) -> BoneAttachment3D:
	var bone := skel.find_bone(hand)
	if bone < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = hand
	skel.add_child(att)
	att.add_child(p)
	var rest := skel.get_bone_global_rest(bone)
	var y := dir.normalized()
	var x := Vector3.RIGHT
	var z := x.cross(y).normalized()
	x = y.cross(z)
	var b := Basis(x, y, z) * Basis(Vector3.UP, deg_to_rad(turn))
	p.transform = rest.affine_inverse() * Transform3D(b, rest * Vector3(0, WEAPON_HAND, 0))
	return att


static func _skeleton(model: Node3D) -> Skeleton3D:
	var all := model.find_children("*", "Skeleton3D", true, false)
	return all[0] if not all.is_empty() else null


## The box of the vertices mostly weighted to `names` (e.g. the head with
## its hair, or the torso), in skeleton space; measured once per figure.
static func _bones_box(model: Node3D, path: String, skel: Skeleton3D, names: Array) -> AABB:
	var key := path + "|" + ",".join(names)
	if _boxes.has(key):
		return _boxes[key]
	var box := AABB()
	var first := true
	for v in _owned_verts(model, skel, names):
		if first:
			box = AABB(v, Vector3.ZERO)
			first = false
		else:
			box = box.expand(v)
	_boxes[key] = box
	return box


## The vertices mostly weighted to `names`, in skeleton space.
static func _owned_verts(model: Node3D, skel: Skeleton3D, names: Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin == null or mi.has_meta("garment"):   # the body only
			continue
		var own := {}
		for b in mi.skin.get_bind_count():
			var bn := String(mi.skin.get_bind_name(b))
			if bn == "":
				bn = skel.get_bone_name(mi.skin.get_bind_bone(b))
			if bn in names:
				own[b] = true
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
				if own.has(int(bones[i * per + best])):
					out.append(to_skel * verts[i])
	return out


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
	if a == "melee" and _shoots(base):
		a = "shoot"
	_dir = int(action.substr(0, cut))
	var end := a == "die_end"
	if end:
		a = "die"
	if not _player.has_animation(a):
		if a != "menu_loop" or not _player.has_animation("idle_loop"):
			return false
		a = "idle_loop"   # a figure built before the menu clips (S45)
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


## S35c: a weapon strike (fight_view._play_weapon: AnimStatique03-<fam>,
## not the bare fists' -219) by a fighter holding a bow shoots it instead
## of the melee swing.
func _shoots(base: String) -> bool:
	return base.begins_with("AnimStatique03") and not base.ends_with("-219") and _worn.has("weapon") \
		and String(_worn_piece.get("weapon", "")).begins_with("bow_") and _player.has_animation("shoot")


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
	# S45: the menus' own clips (rig_anims "menu", "greet", "pose")
	if base == "AnimMenu":
		return "menu_loop"
	if base == "AnimSalut":
		return "greet"
	if base == "AnimPose":
		return "pose"
	return ""


func _process(dt: float) -> void:
	_face()
	_t += dt
	if _worn.has("cape"):
		_swing(dt)
	if _worn.has("dofus"):   # a slow bob and turn
		var d: Node3D = _worn.dofus
		d.position = DOFUS_AT + Vector3(0, sin(_t * 2.0) * 0.03, 0)
		d.rotation.y = _t * 0.8


## The cape eases towards its flare (walking or not) and flutters about it.
func _swing(dt: float) -> void:
	var att: Node3D = _worn.cape
	if att.get_child_count() == 0:
		return
	var p := att.get_child(0) as Node3D
	var walking := anim == "walk_loop"
	_cape_flare = lerpf(_cape_flare, CAPE_WALK if walking else 0.0, minf(1.0, dt * 4.0))
	var wave := sin(_t * 9.0) * CAPE_FLUTTER if walking else sin(_t * 1.7) * CAPE_SWAY
	p.transform = (p.get_meta("rest") as Transform3D) * Transform3D(Basis(Vector3.RIGHT, deg_to_rad(_cape_flare + wave)), Vector3.ZERO)


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
