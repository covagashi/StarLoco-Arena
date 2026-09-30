extends Node2D

## Placeholder isometric fight-map view: topology ground cells shaded by
## altitude + .fmd spawn cells. Original art replaces this once the asset
## pipeline lands — positions/projection stay identical.
##
## Projection (maprender.go): screen = ((x-y)*43, (x+y)*21.5 - alt*10).

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")
const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const MapGfx := preload("res://src/maps/map_gfx.gd")
const State := preload("res://src/state.gd")
const Codec := preload("res://src/net/codec.gd")
const Spells := preload("res://src/gamedata/spells.gd")
const FighterCards := preload("res://src/gamedata/fightercards.gd")
const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const Effects := preload("res://src/gamedata/effects.gd")
const Areas := preload("res://src/gamedata/areas.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")

## Placeholder coach sprite until fight-setup wire data gives the real
## per-pedestal coach anm id.
const COACH_SET := "res://assets/anims/coach_805"
const FIGHTER_SET := "res://assets/anims/fighter_%s"

## Breed -> Players/<file>.anm (client zh_1.cdN): entry i = breed i/2+1,
## sex i%2. 7000/7001 are special fighter skins appended at the end.
const FIGHTER_FILES := [
	"-110", "-111", "-120", "-121", "-130", "-131", "-140", "-141",
	"-150", "-151", "-160", "-161", "-170", "-171", "-180", "-181",
	"-190", "-191", "-1100", "-1101", "-1110", "-1111", "-1120", "-1121",
	"7000", "7001",
]

## Server direction (Direction8) -> anm direction. The anm only ships
## {0,1,2,5,6}; 3/4/7 are horizontal mirrors of 1/0/5 (gw_2.ao).
const DIR_MAP := {0: 0, 1: 1, 2: 2, 3: 1, 4: 0, 5: 5, 6: 6, 7: 5}
const DIR_FLIP := {0: false, 1: false, 2: false, 3: true,
	4: true, 5: false, 6: false, 7: true}

const HW := 43.0   # half cell width
const HH := 21.5   # half cell height
const EL := 10.0   # elevation unit

var _cells := {}
var _fmd := {}
var _alt_min := 0
var _alt_max := 0
var _sorted := []    # ground cell positions, back-to-front (x+y, then x)
var _sprites := {}   # actor id -> AnmSprite
var _gfx: Node2D           # painted backdrop layer (created in _ready)
var _gfx_active := false   # painted backdrop loaded → skip placeholder floors

@onready var cam: Camera2D = $Camera
@onready var info: Label = $UI/Info
@onready var _actors: Node2D = $Actors
@onready var _end_turn: Button = $UI/TopBar/EndTurnBtn
@onready var _face_btn: Button = $UI/TopBar/FaceBtn
@onready var _timeline: HBoxContainer = $UI/TopBar/Timeline
@onready var _turn_timer: Label = $UI/TopBar/TurnTimer
var _dragging := false
var _press_pos := Vector2.ZERO
var _hover := Vector2i(-9999, -9999)   # hovered cell (our turn only)


func _ready() -> void:
	$UI/TopBar/LoadBtn.pressed.connect(_load)
	_end_turn.pressed.connect(_on_action_button)
	_face_btn.pressed.connect(_on_face_pressed)
	if State.spectating:
		# Read-only viewer: no actions leave the client, but the phase acks
		# (8011/8031) still fire — the fight actor ignores them for
		# non-combatants either way.
		_end_turn.disabled = true
		_face_btn.disabled = true
		_end_turn.text = "Spectating"
		$UI/TopBar/SurrenderBtn.disabled = true
	else:
		$UI/TopBar/SurrenderBtn.pressed.connect(func():
			if State.net != null:
				State.net.send_message(8151, PackedByteArray(), 3))
	$UI/TopBar/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/main.tscn"))
	$UI/Chat.bubble.connect(chat_bubble)
	$UI/Chat.emote.connect(func(id, anim):
		chat_bubble(id, "* %s *" % anim.trim_prefix("AnimEmote-")
			.trim_suffix("-Debut").to_lower()))
	_gfx = MapGfx.new()
	_gfx.name = "MapGfx"
	_gfx.show_behind_parent = true   # art under overlays; registered actors merge inside
	add_child(_gfx)
	move_child(_gfx, 0)   # painted layer draws first, under floors+actors
	# When we arrived here from a live fight the world id is the arena id.
	if State.fight_world >= 0:
		$UI/TopBar/MapId.text = str(State.fight_world)
	_load()
	_build_timeline()
	if State.net != null:
		for m in State.net.drain():
			_on_net_message(m.op, m.raw)
		State.net.message_received.connect(_on_net_message)
		State.net.scene_active = true


func _load() -> void:
	var map_id := int($UI/TopBar/MapId.text)
	_gfx_active = _gfx.load_world(map_id)
	_fmd = FightMap.load(map_id)
	var topo := Topology.load_world(map_id, Topology.SCOPE_ARENA)
	_cells = topo.get("cells", {})
	_alt_min = 0
	_alt_max = 0
	for c in _cells.values():
		if not c.ground:
			continue
		_alt_min = mini(_alt_min, c.alt)
		_alt_max = maxi(_alt_max, c.alt)
	_sorted = []
	for pos in _cells:
		if _cells[pos].ground:
			_sorted.append(pos)
	_sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y < b.x + b.y or (a.x + a.y == b.x + b.y and a.x < b.x))
	var n_teams: int = _fmd.get("team0", []).size() + _fmd.get("team1", []).size()
	info.text = "map %d — %d cells, alt %d..%d, spawns t0=%d t1=%d coach=%d" % [
		map_id, _cells.size(), _alt_min, _alt_max,
		_fmd.get("team0", []).size(), _fmd.get("team1", []).size(),
		_fmd.get("coach", []).size()] if not _cells.is_empty() else "map %d: no arena data" % map_id
	_spawn_actors()
	queue_redraw()
	if topo.has("bounds"):
		var b: Rect2i = topo.bounds
		var center := _iso(b.get_center().x, b.get_center().y, 0)
		cam.position = center
		cam.make_current()


func _iso(x: float, y: float, alt: float) -> Vector2:
	return Vector2((x - y) * HW, (x + y) * HH - alt * EL)


func _spawn_actors() -> void:
	for n in _actors.get_children():
		n.queue_free()
	_sprites = {}
	# Preview mode only: with a live fight the real coach/fighter positions
	# arrive via ACTOR_APPEAR (4102) and _place_actor owns the actors list.
	if not State.fighters.is_empty():
		return
	for c in _fmd.get("coach", []):
		if c.x <= -2047:
			continue   # unused pedestal slot (arena.go emptyPedestalXY)
		var spr := AnmSprite.new()
		spr.foot_pivot = true
		# coaches stand on top of the pedestal they are parked on
		spr.position = _iso(c.x + 0.5, c.y + 0.5, c.z + 1.0)
		spr.z_index = clampi(int(c.x + c.y) * 4 + 1, -4096, 4096)
		_actors.add_child(spr)
		spr.load_action(COACH_SET, "5_AnimStatique")


## --- live fight wiring -----------------------------------------------------

## Server opcodes consumed here after scene entry.
const OP_ACTOR_APPEAR := 4102
const OP_PLACEMENT := 8022
const OP_START_PRESENTATION := 8010
const OP_END_PRESENTATION := 8014
const OP_START_PLACEMENT := 8020
const OP_READY_OBSERVATION := 8023
const OP_END_PLACEMENT := 8028
const OP_START_OBSERVATION := 8030
const OP_START_ACTION := 8040
const OP_READY_PLACEMENT := 8011
const OP_READY_ACTION := 8031

## In-combat ops.
const OP_TABLE_TURN := 8100    # [i32][i32][i8 turn][i32] — round counter
const OP_TURN_BEGIN := 8104    # [i32][i32][i64 fighterId]
const OP_END_TURN := 8105      # C2S [i64 fighterId]
const OP_TURN_END := 8106      # S2C [i32][i32][i64 fighterId]
const OP_FIGHTER_MOVE := 4524  # [i32][i32][i64 fighterId] + path i32x,i32y,i16z
const OP_FIGHTER_DIES := 4520  # [i32][i32][i64 fighterId]
const OP_RUNNING_EFFECT := 8120  # header + BinarSerial blob (see codec)
const OP_BUFF_ATTACH := 8121     # S2C buff re-attach (resync) — no execution
const OP_AREA_ACTION := 6200     # S2C hdr+[u8 in][i64 inst][i64 tpl][i64 fid]
const OP_END_FIGHT := 8300     # S2C result screen — ack with 26321
const OP_END_FIGHT_DONE := 26321  # C2S empty — server returns us to overworld
const OP_ENTER_INSTANCE := 4600
const OP_SPELL_CAST_REQ := 8109  # C2S [i64 fid][i32 spell][i32 x][i32 y][i16 z]
const OP_SPELL_CAST := 8110      # S2C header+[i64 caster][i32 spell][i8 miss]
const OP_CLOSE_COMBAT_REQ := 8111  # C2S [i64 fid][i32 x][i32 y][i16 z] (weapon)
const OP_CLOSE_COMBAT := 8112    # S2C header+[i64 attacker][i8 miss]
const OP_CARD_USE_REQ := 8107    # C2S [i64 fid][i32 card][i32 x][i32 y][i16 z]
const OP_CARD_USE := 8108        # S2C header+[i64 user][i32 card][i8 miss]
const OP_DIR_CHANGE_REQ := 4521  # C2S [i64 fid][u8 dir] — facing (free action)
const OP_DIR_CHANGE := 4522      # S2C header+[i64 fid][u8 dir]

## Breed base stats (server breed.go): [HP, AP, MP] — AP/MP refill each turn.
const BREED_STATS := {1: [70, 6, 3], 2: [65, 6, 3], 3: [65, 6, 3],
	4: [70, 6, 3], 5: [60, 6, 3], 6: [70, 6, 3], 7: [60, 6, 3],
	8: [75, 6, 3], 9: [65, 6, 3], 10: [65, 6, 3], 11: [80, 6, 3],
	12: [75, 6, 3]}

var _fight_over := false
var _actor_cells := {}   # id -> Vector3i
var _current_fid := -1   # fighter whose turn is running (8104 → 8106)
var _spell_mode := -1    # >=0: next click targets this spell id (8109)
var _card_mode := -1     # >=0: next click fires this equipment card (8107)
var _ap_left := 0        # current fighter AP/MP, debited by 8120 fx 91/92
var _mp_left := 0
var _walk := {}          # actor id -> Array[Vector3i] remaining walk cells
var _actor_dir := {}     # actor id -> last server dir (facing during walk)
var _hp_lost := {}       # fighter id -> accumulated damage (8000 + 8120)
var _dead := {}          # fighter id -> true once 4520 arrives
var _carried_by := {}    # carried fighter id -> carrier fighter id (58/59)
var _buffs := {}         # fighter id -> [{label,left,inf,src}] effect chips
var _areas := []         # placed traps/glyphs/auras {tpl,ctr,caster,aura,left,turns}
var _cast_hist := {}     # fid -> {limitKey: {last,n,tgt}} — client sH history
var _table_turn := 0     # last 8100 round counter (cooldowns compare it)
var _spell_btns := {}    # spell id -> Button (for the cooldown lock refresh)
var _turns_taken := {}   # fighter id -> own-turn count (client alh_1.NC)
var _placement := false  # 8020 → 8028 window: 8021 moves are legal
var _selected := -1      # our fighter selected for placement
var _turn_left := -1.0   # countdown of the acting fighter's clock (−1 off)

## Emitted on 8104 — a harness (fight_smoke's scripted policy) or the human
## drives from here: request_move_to() then request_end_turn().
signal turn_began(fid: int, ours: bool)
## Emitted on 8020 — placement window is open until confirm_placement()
## sends 8023. The human version finishes by pressing the Ready button.
signal placement_began

## White crosshairs at each actor's cell center (placement debugging).
var debug_overlay := false

const WALK_SPEED := 160.0   # px/sec along the path
## Server turnClock (internal/game/fight.go) — the per-fighter turn budget;
## tournament TurnDurationMS params can shift it, but they only ride the
## fight-params tail, so the display assumes the standard 30s.
const TURN_CLOCK := 30.0
## Orthogonal grid step -> server Direction8 (iso diagonals):
## +x down-right=SE(1), +y down-left=SW(3), -x=NW(5), -y=NE(7).
const STEP_DIR := {
	Vector2i(1, 0): 1, Vector2i(0, 1): 3,
	Vector2i(-1, 0): 5, Vector2i(0, -1): 7}


func _exit_tree() -> void:
	# If we leave the tree without being freed (e.g. replaced by an explicit
	# add_child in tests), drop the net subscription — a stale instance would
	# keep consuming the shared WireReader and starve the new scene.
	if State.net != null:
		State.net.scene_active = false
		if State.net.message_received.is_connected(_on_net_message):
			State.net.message_received.disconnect(_on_net_message)


func _on_net_message(opcode: int, raw: PackedByteArray) -> void:
	var payload := WireReader.new(raw)
	if $UI/Chat.feed(opcode, payload):
		return  # chat family handled by the chat box
	if opcode >= 8010 and opcode <= 8040:
		print("[fight] phase op %d" % opcode)
	match opcode:
		OP_ACTOR_APPEAR:
			var d := Codec.decode(opcode, payload)
			for a in d.get("actors", []):
				_place_actor(a)
		OP_PLACEMENT:
			var d := Codec.decode(opcode, payload)
			_move_actor(int(d.id), Vector3i(int(d.x), int(d.y), int(d.z)))
		OP_START_PRESENTATION:
			# retail auto-acks presentation; server needs every coach's 8011
			# (arch 3, empty payload) before advancing to placement.
			if State.net != null:
				State.net.send_message(OP_READY_PLACEMENT, PackedByteArray(), 3)
			info.text += " | presentation"
		OP_START_PLACEMENT:
			# Placement window: our team's start cells light up; clicking one
			# sends 8021 for the selected fighter. Ready = 8023.
			_placement = true
			_turn_left = TURN_CLOCK          # placementClock is the same 30s
			_end_turn.text = "Ready"
			_end_turn.disabled = false
			for fid in State.fighters:
				var f: Dictionary = State.fighters[fid]
				if int(f.get("coach", -1)) == State.my_coach_id:
					_selected = int(fid)
					break
			info.text += " | placement — click a spawn cell"
			placement_began.emit()
			queue_redraw()
		OP_END_PLACEMENT:
			_placement = false
			_turn_left = -1.0
			_turn_timer.text = ""
			_end_turn.text = "End turn"
			_end_turn.disabled = true
		OP_START_OBSERVATION:
			# third gate: 8031 (arch 3, empty) advances to the action phase.
			_placement = false
			_turn_left = -1.0
			_turn_timer.text = ""
			_end_turn.text = "End turn"
			if State.net != null:
				State.net.send_message(OP_READY_ACTION, PackedByteArray(), 3)
			info.text += " | observation"
		OP_START_ACTION:
			info.text += " | combat!"
		OP_TABLE_TURN:
			var d := Codec.decode(opcode, payload)
			_table_turn = int(d.get("f2", 0))
			info.text = "map %s — turn %d" % [$UI/TopBar/MapId.text, _table_turn]
			_age_buffs()
			_age_areas()
		OP_TURN_BEGIN:
			var d := Codec.decode(opcode, payload)
			_on_turn_begin(int(d.get("f2", -1)))
		OP_TURN_END:
			_current_fid = -1
			_turn_left = -1.0
			_turn_timer.text = ""
			_end_turn.disabled = true
			_face_btn.disabled = true
			_clear_spell_bar()
			_refresh_timeline()
		OP_SPELL_CAST:
			# [i32 uid][i32 -1][i64 caster][i32 spell][i8 miss](+crit+target)
			payload.get_i32()
			payload.get_i32()
			var caster := int(payload.get_i64())
			var sid := int(payload.get_i32())
			var miss := int(payload.get_i8())
			var crit := int(payload.get_i8()) if not miss and payload.remaining() > 0 else 0
			var aimed := Vector2i(-9999, -9999)
			if not miss and payload.remaining() >= 10:
				aimed = Vector2i(payload.get_i32(), payload.get_i32())
			_float_text(caster,
				"miss!" if miss else
				("critical! " if crit else "") + Spells.name_of(sid),
				Color(1, 1, 0.4) if miss else
				Color(1.0, 0.6, 0.2) if crit else Color(0.6, 0.8, 1.0))
			# even a fumble counts against the frequency limits (the server
			# storeCasts after the roll); a bare-cell cast has no target
			_note_cast(caster, sid, aimed)
		OP_CLOSE_COMBAT:
			payload.get_i32()
			payload.get_i32()
			var atk := int(payload.get_i64())
			var wmiss := int(payload.get_i8()) if payload.remaining() > 0 else 0
			var wcrit := int(payload.get_i8()) if not wmiss and payload.remaining() > 0 else 0
			_float_text(atk, "miss!" if wmiss else
				"critical hit!" if wcrit else "hit!",
				Color(1, 1, 0.4) if wmiss else
				Color(1.0, 0.6, 0.2) if wcrit else Color(1.0, 0.7, 0.3))
		OP_CARD_USE:
			# [i32 uid][i32 -1][i64 user][i32 card][i8 miss](+crit+target)
			payload.get_i32()
			payload.get_i32()
			var user := int(payload.get_i64())
			var cid := int(payload.get_i32())
			var cmiss := int(payload.get_i8()) if payload.remaining() > 0 else 0
			var ccrit := int(payload.get_i8()) if not cmiss and payload.remaining() > 0 else 0
			_float_text(user, "miss!" if cmiss else
				("critical! " if ccrit else "") + FighterCards.label(cid),
				Color(1, 1, 0.4) if cmiss else
				Color(1.0, 0.6, 0.2) if ccrit else Color(0.9, 0.6, 1.0))
		OP_FIGHTER_MOVE:
			# [i32 uid][i32 -1][i64 fighterId] + path — server prepends the
			# origin cell (applyFighterMove), so path[0] is where the fighter
			# already stands; the remaining cells are the walk steps.
			payload.get_i32()
			payload.get_i32()
			var fid := int(payload.get_i64())
			var path: Array = []
			while payload.remaining() >= 10:
				path.append(Vector3i(payload.get_i32(), payload.get_i32(), payload.get_i16()))
			_carried_by.erase(fid)   # walking breaks a carry (dismountIfCarried)
			if path.size() > 1:
				path.pop_front()   # drop the origin cell
				_walk[fid] = path
				_face_step(fid)
			elif path.size() == 1:
				_move_actor(fid, path[0])
		OP_DIR_CHANGE:
			# [i32 uid][i32 -1][i64 fid][u8 dir] — re-face the sprite.
			payload.get_i32()
			payload.get_i32()
			var rfid := int(payload.get_i64())
			var rdir := payload.get_u8()
			_actor_dir[rfid] = rdir
			_reface(rfid, rdir)
		OP_FIGHTER_DIES:
			payload.get_i32()
			payload.get_i32()
			_kill_actor(int(payload.get_i64()))
		OP_RUNNING_EFFECT:
			_on_running_effect(Codec.decode(opcode, payload))
		OP_BUFF_ATTACH:
			_on_buff_attach(Codec.decode(opcode, payload))
		OP_AREA_ACTION:
			# [i32 uid][i32 -1][u8 entering][i64 inst][i64 tpl][i64 fid] —
			# the tile's own animation trigger; float its kind name instead.
			payload.get_i32()
			payload.get_i32()
			var entering := int(payload.get_u8())
			payload.get_i64()              # area instance id
			var tpl := int(payload.get_i64())
			var vfid := int(payload.get_i64())
			if entering and SPECIAL_CELLS.has(tpl):
				_float_text(vfid, SPECIAL_CELLS[tpl][1], SPECIAL_CELLS[tpl][2])
		OP_END_FIGHT:
			# Result screen — decode the debrief (winners, cards, per-fighter
			# OW reports) for the lobby's result panel, then ack (26321); the
			# server answers with a fresh 4600 back to the overworld.
			State.fight_result = Codec.decode(opcode, payload)
			_fight_over = true
			_turn_left = -1.0
			_turn_timer.text = ""
			State.spectating = false
			if State.net != null:
				State.net.send_message(OP_END_FIGHT_DONE, PackedByteArray(), 3)
			info.text = "map %s — fight over" % $UI/TopBar/MapId.text
		OP_ENTER_INSTANCE:
			# Post-fight re-entry (world != arena id) → back to the lobby scene.
			# The fight-entry 4600 that drained during _ready has
			# world == fight_world and is ignored.
			if _fight_over:
				State.fight_world = -1
				State.fighters = {}
				# a test harness may have removed us from the tree already.
				if is_inside_tree():
					get_tree().change_scene_to_file("res://src/main.tscn")


## Spawn (or move) one actor from a 4102 entry {id,x,y,z,dir}.
func _place_actor(a: Dictionary) -> void:
	var spr: AnmSprite = _sprites.get(a.id)
	if spr == null:
		spr = AnmSprite.new()
		spr.foot_pivot = true
		_sprites[a.id] = spr
		_actors.add_child(spr)
	var dir: int = DIR_MAP.get(a.dir, 1)
	_actor_dir[a.id] = int(a.dir)
	_set_flip(spr, DIR_FLIP.get(a.dir, false))
	if State.fighters.has(a.id):
		var f: Dictionary = State.fighters[a.id]
		_load_fighter_anim(spr, a.id, a.dir)
		_hp_lost[a.id] = int(f.get("hp_lost", 0))
		_nameplate(spr, a.id)
	else:
		spr.load_action(COACH_SET, "%d_AnimStatique" % dir)
	spr.position = _iso(a.x + 0.5, a.y + 0.5, a.z)
	spr.z_index = clampi(int(a.x + a.y) * 4 + 1, -4096, 4096)
	_actor_cells[a.id] = Vector3i(a.x, a.y, a.z)
	if _gfx_active:
		# merged painter: the map-gfx layer calls draw_on at our zkey slot
		spr.external_draw = true
		_gfx.register_dynamic(a.id,
			func(): return MapGfx.actor_key_cell(
				_actor_cells.get(a.id, Vector3i.ZERO)),
			func(ci): spr.draw_on(ci, spr.position))
	queue_redraw()


func _move_actor(id: int, p: Vector3i) -> void:
	var spr: AnmSprite = _sprites.get(id)
	if spr == null:
		return
	spr.position = _iso(p.x + 0.5, p.y + 0.5, p.z)
	spr.z_index = clampi((p.x + p.y) * 4 + 1, -4096, 4096)
	_actor_cells[id] = p
	queue_redraw()


## Running-effect ids that mean "target loses HP" (mh_2 table):
## 1-5 direct damage by element, 6-10 life steal, 125 %-loss,
## 130-134 the same five elements "par sort".
const FX_HP_LOSS := {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0, 8: 0,
	9: 0, 10: 0, 125: 0, 130: 0, 131: 0, 132: 0, 133: 0, 134: 0}
const FX_HP_GAIN := {11: 0}   # "Boost de HP"

## Running-effect action ids that spawn a summon fighter mid-fight
## (gamedata KindSummon / client hy_1 + gn_0.d): 67 "invoque une créature"
## (adT — creature from the type-300 template), 75 "un double" (wo_1 — a
## copy of the caster), 97 "un miroir" (aad_0 — template, mirrored skin).
const FX_SUMMON := {67: 0, 75: 0, 97: 0}

## Running-effect action ids that displace a fighter mid-fight
## (gamedata effect kinds / client classes): 37 push + 38 pull (na_2 moves
## the target to the part-3 dest), 39 teleport (moves the caster to the
## part-0 cell), 64 swap (aox_1 exchanges both live cells), 153 self-push
## (azw_0 moves the CASTER to the part-3 dest), 58 carry + 59 throw (target
## lands on the part-0 cell).
const FX_DISPLACE := {37: 0, 38: 0, 39: 0, 64: 0, 58: 0, 59: 0, 153: 0}

## Stat/resource floats — action id -> [sign, label]. The wire `value` is
## the real applied amount; the sign is baked into the id (a loss action
## carries a positive magnitude). Element families are generated below.
const FX_RES_ID := {
	15: [1, "AP"], 16: [-1, "AP"], 19: [1, "MP"], 20: [-1, "MP"],
	85: [-1, "AP"], 103: [-1, "MP"],   # steals float on the drained side
	99: [1, "AP"], 100: [-1, "AP"], 101: [1, "MP"], 102: [-1, "MP"],
	13: [1, "AP"], 14: [-1, "AP"], 17: [1, "MP"], 18: [-1, "MP"],
	11: [1, "HP"], 12: [-1, "HP"],
	72: [1, "RG"], 73: [-1, "RG"], 74: [1, "SUM"],
	76: [1, "INI"], 77: [-1, "INI"], 78: [1, "HEAL"], 79: [-1, "HEAL"],
	70: [1, "CRIT"], 147: [-1, "CRIT"], 71: [1, "FUMB"], 148: [-1, "FUMB"],
	86: [1, "AP-res"], 87: [1, "MP-res"], 89: [1, "REFL"],
	120: [1, "BLOCK"], 121: [-1, "BLOCK"],
	122: [1, "DODGE"], 123: [-1, "DODGE"],
	135: [1, "DMG"], 136: [1, "DMG"], 137: [1, "DMG"], 138: [1, "DMG"],
	141: [1, "LEECH"], 154: [1, "ZONE-res"], 164: [-1, "ZONE-res"],
}
const ELEM_ABBR := ["FR", "ER", "WT", "AR"]   # fire/earth/water/air

## Elemental res/dmg buff ids are +/- pairs per element (server
## elementalStatOps): res 21-28, res% 29-36, dmg 40-47, dmg% 48-55;
## 80/81 all-res%, 82/83 all-dmg%. Returns [sign, label] or [].
static func _elem_fx(id: int) -> Array:
	for fam in [[21, "res"], [29, "res%"], [40, "dmg"], [48, "dmg%"]]:
		var span := id - int(fam[0])
		if span >= 0 and span < 8:
			return [1 if span % 2 == 0 else -1,
				"%s %s" % [ELEM_ABBR[span / 2], fam[1]]]
	match id:
		80: return [1, "res% all"]
		81: return [-1, "res% all"]
		82: return [1, "dmg% all"]
		83: return [-1, "dmg% all"]
	return []


## Special battlefield tiles (arena .fmd specials / wire special_detail —
## server specialcells.go): template id -> [abbr, label, color]. The tile
## animates only when a fighter STARTS its turn on it (6200 broadcast).
const SPECIAL_CELLS := {
	1002: ["K", "Killer cell", Color(1.0, 0.15, 0.1)],
	1003: ["T", "Trap", Color(0.85, 0.5, 0.1)],
	1004: ["E", "Eagle eye", Color(0.3, 0.9, 1.0)],
	1005: ["S", "Shield", Color(0.3, 0.5, 1.0)],
	1006: ["P", "Panacea", Color(0.4, 1.0, 0.5)],
	1007: ["X", "Enthusiasm", Color(1.0, 0.6, 0.2)],
	1008: ["M", "Motivation", Color(1.0, 0.9, 0.2)],
	1009: ["H", "Healing heart", Color(1.0, 0.4, 0.6)],
}

## Status states (server stateByAction) — a pale float over the target.
const FX_STATE := {
	65: "Rooted", 96: "Petrified", 94: "Stabilised", 127: "Anchored",
	128: "Intransposable", 57: "Invisible", 95: "Immune", 124: "Immune",
	56: "Skip turn", 111: "Skip turn", 126: "Drunk",
	173: "Class mask", 174: "Cowardly mask", 175: "Berzerk mask",
}


## 8120 — apply a running effect visually: HP effects float text and update
## the nameplate counter; AP/MP debits (91/92) and upkeep are silent. The
## summon actions create a whole new fighter instead, and the displacement
## actions move an existing one.
func _on_running_effect(d: Dictionary) -> void:
	_note_area_fire(d)
	var act := int(d.get("effect_id", -1))
	if FX_SUMMON.has(act):
		_spawn_summon(d)
		return
	if FX_DISPLACE.has(act):
		_apply_displacement(d)
		return
	if act == 66:                    # trap/glyph placed on a cell — no float
		_place_area(d, false)
		return
	if act == 176:                   # caster-followed aura — also chips up
		_place_area(d, true)
	if not d.has("value"):
		return
	var target := int(d.get("target", -1))
	var value := int(d.value)
	if FX_HP_LOSS.has(int(d.effect_id)):
		_hp_lost[target] = int(_hp_lost.get(target, 0)) + value
		_refresh_nameplate(target)
		_float_text(target, "-%d" % value, Color(1.0, 0.35, 0.3))
	elif FX_HP_GAIN.has(int(d.effect_id)):
		_hp_lost[target] = int(_hp_lost.get(target, 0)) - value
		_refresh_nameplate(target)
		_float_text(target, "+%d" % value, Color(0.45, 1.0, 0.45))
	elif int(d.effect_id) == 91 and target == _current_fid:
		_ap_left -= value
		_refresh_apmp()
	elif int(d.effect_id) == 92 and target == _current_fid:
		_mp_left -= value
		_refresh_apmp()
	elif FX_RES_ID.has(int(d.effect_id)) or not _elem_fx(int(d.effect_id)).is_empty():
		var e: Array = FX_RES_ID.get(int(d.effect_id), _elem_fx(int(d.effect_id)))
		_float_text(target, "%s%d %s" % ["-" if int(e[0]) < 0 else "+",
			value, e[1]],
			Color(0.55, 0.85, 1.0) if int(e[0]) > 0 else Color(1.0, 0.75, 0.35))
		if target == _current_fid:
			match int(d.effect_id):
				15:
					_ap_left += value
				16, 85:
					_ap_left -= value
				19:
					_mp_left += value
				20, 103:
					_mp_left -= value
			_refresh_apmp()
	elif FX_STATE.has(int(d.effect_id)):
		_float_text(target, FX_STATE[int(d.effect_id)], Color(0.9, 0.9, 1.0))
		var spr: AnmSprite = _sprites.get(target)
		if int(d.effect_id) == 57 and spr != null:
			spr.modulate.a = 0.35      # invisible — retail fades the sprite
	elif int(d.effect_id) == 62:      # dispel — clears the invisibility tint
		_float_text(target, "Dispelled", Color(0.9, 0.9, 1.0))
		var spr: AnmSprite = _sprites.get(target)
		if spr != null:
			spr.modulate.a = 1.0
		# strips by SOURCE effectId — the dispel's params[0] (server
		# removeEffectByID); params-free dispels remove nothing
		var p: Variant = Effects.meta(int(d.get("gen_effect", 0))).get("p", [])
		if p is Array and not p.is_empty():
			var rid := int(p[0])
			_buffs[target] = _buffs.get(target, []).filter(
				func(b): return int(b.src) != rid)
			_refresh_buffs(target)
	# a timed/infinite effect also joins the buff strip — the client's PJ()
	# container gains it when the running effect executes; instant effects
	# resolve to {} in effects.json and skip. Duration comes from the data
	# (never on the wire); the server ages buffs per table-turn (tickBuffs).
	var em := Effects.meta(int(d.get("gen_effect", 0)))
	if not em.is_empty():
		_attach_buff(target, int(d.effect_id), int(d.gen_effect), value,
			int(em.get("d", 0)), bool(em.get("i", false)))


## Summon spawn (8120 action 67/75/97 → hy_1.gn_0.d): the wire carries the new
## fighter's wire id in `target`, the type-300 template id in `value`, and the
## spawn cell in x/y/z — everything else (name/stats/look, team, timeline slot)
## resolves locally. The summon inherits the caster's coach+team, is AI-driven
## (never ours to control), and joins the timeline right after its caster and
## the caster's older summons (insertSummonIntoTimeline, summon.go).
func _spawn_summon(d: Dictionary) -> void:
	var fid := int(d.get("target", -1))
	var caster_fid := int(d.get("caster", -1))
	if fid <= 0 or _sprites.has(fid) or State.fighters.has(fid):
		return
	var cf: Dictionary = State.fighters.get(caster_fid, {})
	var tpl := int(d.get("value", 0))
	var meta: Dictionary = NpcDialogs.summon(tpl)
	var is_double := int(d.get("effect_id", -1)) == 75
	# retail names: creatures/mirrors are "Gobball (Humo)" — template name plus
	# the summoner in parens (adT.setName); a double is the caster's own name.
	var tpl_name := NpcDialogs.summon_name(tpl)
	if tpl_name.is_empty():
		tpl_name = "Summon %d" % tpl
	var sname := str(cf.get("name", caster_fid)) if is_double \
		else "%s (%s)" % [tpl_name, str(cf.get("name", caster_fid))]
	var f := {"id": fid, "type": "summon", "summon": true,
		"summon_of": caster_fid, "name": sname,
		"coach": int(cf.get("coach", -1)), "team": int(cf.get("team", 0)),
		"hp": int(meta.get("hp", 0)), "ap": int(meta.get("ap", 0)),
		"mp": int(meta.get("mp", 0)), "spells": [],
		# the double mirrors its caster's sprite; creatures have their own
		# gfx ids we don't ship — they fall back to the coach anm.
		"breed": int(cf.get("breed", 1)) if is_double else -1,
		"sex": int(cf.get("sex", 0))}
	State.fighters[fid] = f
	_hp_lost[fid] = 0
	_place_actor({"id": fid, "x": int(d.get("x", 0)),
		"y": int(d.get("y", 0)), "z": int(d.get("z", 0)),
		"dir": int(_actor_dir.get(caster_fid, 5))})
	var tl: Array = State.fight_data.get("timeline", [])
	var at := tl.find(caster_fid) + 1
	if at <= 0:
		tl.append(fid)
	else:
		while at < tl.size() and int(State.fighters.get(tl[at], {})
				.get("summon_of", -1)) == caster_fid:
			at += 1
		tl.insert(at, fid)
	_build_timeline()
	_float_text(fid, sname, Color(0.7, 0.9, 1.0))
	print("[fight] summon %d '%s' spawned by %d at (%d,%d)" % [
		fid, sname, caster_fid, int(d.get("x", 0)), int(d.get("y", 0))])


## Displacement effects (push 37, pull 38, teleport 39, swap 64, carry 58,
## throw 59, self-push 153): who moves and where to comes straight from the
## client's own classes — na_2/azw_0 trust the part-3 destination verbatim
## (the compute path is skipped on wire effects), aox_1 swaps the two live
## cells itself. Server-side collision damage is NOT broadcast (it rides in
## the client's own float), so a blocked shove's HP loss is invisible here.
func _apply_displacement(d: Dictionary) -> void:
	var act := int(d.get("effect_id", -1))
	var caster := int(d.get("caster", -1))
	var target := int(d.get("target", -1))
	if act == 64:  # swap — both cells taken from the live positions
		var a: Vector3i = _actor_cells.get(caster, Vector3i(-1, -1, -1))
		var b: Vector3i = _actor_cells.get(target, Vector3i(-1, -1, -1))
		if a.x >= 0 and b.x >= 0:
			_move_actor(caster, b)
			_move_actor(target, a)
		return
	var mover := caster if act == 39 or act == 153 else target
	# part-3 (dx/dy/dz) is the forced destination for shoves; teleport/carry/
	# throw land on the part-0 cell.
	var dest := Vector3i(int(d.get("dx", 0)), int(d.get("dy", 0)),
		int(d.get("dz", 0))) if d.has("dx") else Vector3i(
		int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))
	if mover > 0 and _actor_cells.has(mover):
		_move_actor(mover, dest)
		for cid in _carried_by.keys():   # a displaced carrier takes its cargo
			if _carried_by[cid] == mover:
				_move_actor(cid, dest)
		if _carried_by.has(mover):       # a carried fighter teleported/thrown?
			_carried_by.erase(mover)     # it lands on its own cell — link broken
	match act:
		58:                       # carry — the target rides on the caster's cell
			if mover > 0:
				_carried_by[mover] = caster
		59:                       # throw — the carried lands, link broken
			_carried_by.erase(mover)
		_:
			pass


## Effect areas (8120 action 66 trap/glyph on a cell, 176 aura on the caster).
## Retail builds the live yl_1 from the template id carried in `value` — the
## footprint shape/size and the fire budget are data-side (areas.json, the
## type-210 catalog). An area renders only while its caster is a visible
## fighter (aew_1: caster !PR() && !PT(), else aoy() hides it — an invisible
## fighter's traps don't show), so draw-time visibility follows the sprite's
## invisibility fade rather than a stored flag. Auras (176) re-centre on the
## caster's live cell every frame and age one step per table turn.
func _place_area(d: Dictionary, aura: bool) -> void:
	var tpl := int(d.get("value", 0))
	var m := Areas.meta(tpl)
	if m.is_empty():
		return                     # unknown template — nothing to draw
	var turns := 0
	if aura:
		var ge := int(d.get("gen_effect", 0))
		turns = -1 if Effects.is_infinite(ge) else Effects.duration(ge)
	_areas.append({"tpl": tpl, "aura": aura,
		"ctr": Vector3i(int(d.get("x", 0)), int(d.get("y", 0)),
			int(d.get("z", 0))),
		"caster": int(d.get("caster", -1)),
		"left": int(m.get("m", 1)),
		"turns": turns})
	queue_redraw()


## Inner-effect attribution — a trap firing broadcasts its template's inner
## effects as ordinary 8120s (no area id on the wire), so we count a fire when
## the gen_effect is one of the area's inners, the caster matches and the
## victim stands inside the footprint. Finite areas (maxExec < 63) die at 0 —
## matching the server's pruneEffectAreas, which has no removal broadcast.
func _note_area_fire(d: Dictionary) -> void:
	var gen := int(d.get("gen_effect", 0))
	var caster := int(d.get("caster", -1))
	var target := int(d.get("target", -1))
	var tpos: Vector3i = _actor_cells.get(target, Vector3i(-9999, 0, 0))
	for a in _areas.duplicate():
		if a.aura or int(a.caster) != caster:
			continue
		var inner: Array = Areas.meta(int(a.tpl)).get("e", [])
		if inner.is_empty() or not inner.has(gen):
			continue
		var cells: Array = Areas.footprint(int(a.tpl), a.ctr)
		if not cells.has(Vector2i(tpos.x, tpos.y)):
			continue
		var m := int(Areas.meta(int(a.tpl)).get("m", 1))
		if m >= 0 and m < 63:
			a.left = int(a.left) - 1
			if int(a.left) <= 0:
				_areas.erase(a)
		queue_redraw()
		break


## 8110 — record the cast in the client's own cast-frequency history (sH).
## The server storeCasts after the fumble/crit roll, so even a miss counts;
## limits key on LimitKeyID (a variant shares its parent's budget). Only the
## fields the spell actually constrains are written — a zero limit is
## unconstrained and stays absent.
func _note_cast(caster: int, sid: int, aimed: Vector2i) -> void:
	var sm := Spells.meta(sid)
	var cd := int(sm.get("cd", 0))
	var mpt := int(sm.get("mpt", 0))
	var mptt := int(sm.get("mptt", 0))
	if cd == 0 and mpt == 0 and mptt == 0:
		return
	var lk := int(sm.get("lk", sid))
	var h: Dictionary = _cast_hist.get_or_add(caster, {})
	var rec: Dictionary = h.get_or_add(lk, {"last": -1, "n": 0, "tgt": {}})
	if cd > 0:
		rec.last = _table_turn
	if mpt > 0:
		rec.n = int(rec.n) + 1
	var tf := _occupied_fighter(aimed) if aimed.x > -9000 else -1
	if mptt > 0 and tf >= 0:
		var tgt: Dictionary = rec.get("tgt", {})
		tgt[tf] = int(tgt.get(tf, 0)) + 1
		rec.tgt = tgt
	if caster == _current_fid:
		_refresh_spell_locks()


## Is the spell locked for the acting fighter? Mirrors canCast: cooldown
## counts TABLE turns since the last cast (63 = once per fight); the per-turn
## cap resets on the fighter's own turn begin (onNewTurn).
func _spell_locked(sid: int) -> bool:
	var sm := Spells.meta(sid)
	var lk := int(sm.get("lk", sid))
	var rec: Dictionary = _cast_hist.get(_current_fid, {}).get(lk, {})
	if rec.is_empty():
		return false
	var cd := int(sm.get("cd", 0))
	if cd > 0 and int(rec.get("last", -1)) >= 0 and \
			(cd == 63 or _table_turn - int(rec.last) < cd):
		return true
	var mpt := int(sm.get("mpt", 0))
	return mpt > 0 and int(rec.get("n", 0)) >= mpt


## Per-target cap — the aimed cell's fighter may already be at its casts-per-
## target count this turn (CastMaxPerTarget, field 7).
func _target_capped(pos: Vector2i, meta: Dictionary) -> bool:
	var fid := _occupied_fighter(pos)
	if fid < 0:
		return false
	var lk := int(meta.get("lk", meta.get("id", -1)))
	var rec: Dictionary = _cast_hist.get(_current_fid, {}).get(lk, {})
	return int(rec.get("tgt", {}).get(fid, 0)) >= int(meta.get("mptt", 0))


## 8100 — auras age one table turn (server tickEffectAreas); traps don't age.
func _age_areas() -> void:
	for a in _areas.duplicate():
		if a.aura and int(a.turns) > 0:
			a.turns = int(a.turns) - 1
			if int(a.turns) <= 0:
				_areas.erase(a)
				queue_redraw()


## Vicinity chat bubble over a fighter's head — chat actor ids are coach ids;
## map them to that coach's fighter sprite.
func chat_bubble(coach_id: int, text: String) -> void:
	var fid := -1
	for id in State.fighters:
		var f: Dictionary = State.fighters[id]
		if int(f.get("coach", -2)) == coach_id and not f.get("summon", false):
			fid = int(id)
			break
	var spr: AnmSprite = _sprites.get(fid if fid >= 0 else coach_id)
	if spr == null:
		return
	var old := spr.get_node_or_null("Bubble")
	if old != null:
		old.queue_free()
	var b := Label.new()
	b.name = "Bubble"
	b.text = text.left(120)
	b.add_theme_font_size_override("font_size", 11)
	b.add_theme_color_override("font_color", Color(1, 1, 0.85))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	b.add_theme_constant_override("shadow_offset_x", 1)
	b.add_theme_constant_override("shadow_offset_y", 1)
	b.position = Vector2(-b.size.x / 2.0, -150)
	if spr.scale.x < 0:
		b.scale.x = -1.0   # counter the mirrored flip so text stays readable
	spr.add_child(b)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(b, "modulate:a", 0.0, 1.2)
	tw.tween_callback(b.queue_free)


## 4520 — grey out the corpse; its cell stays occupied for pathing.
func _kill_actor(fid: int) -> void:
	_dead[fid] = true
	_buffs.erase(fid)                  # a dead fighter's icons are moot
	_refresh_buffs(fid)
	_carried_by.erase(fid)             # dying breaks both carry directions
	for cid in _carried_by.keys():     # (breakCarryLinks) — the carried drops
		if _carried_by[cid] == fid:      # onto the carrier's cell, where it is
			_carried_by.erase(cid)
	for a in _areas.duplicate():       # a dead caster's aura dies with it
		if a.aura and int(a.caster) == fid:
			_areas.erase(a)
	var spr: AnmSprite = _sprites.get(fid)
	if spr != null:
		spr.playing = false
		spr.modulate = Color(0.55, 0.55, 0.6, 0.85)
		# back to its own canvas item so the corpse greys out via modulate
		_gfx.unregister_dynamic(fid)
		spr.external_draw = false
		spr.queue_redraw()
	if _current_fid == fid:
		_current_fid = -1
		_end_turn.disabled = true
	_refresh_timeline()


## Name + cumulative damage label above each fighter, childed to the sprite
## so it follows walks. Coaches stay unlabeled.
func _nameplate(spr: AnmSprite, fid: int) -> void:
	var lbl := Label.new()
	lbl.name = "Plate"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-60, -96)
	lbl.size = Vector2(120, 16)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	spr.add_child(lbl)
	_refresh_nameplate(fid)


## Mirror the sprite; child Labels counter-flip so text stays readable.
func _set_flip(spr: AnmSprite, flip: bool) -> void:
	spr.scale.x = -absf(spr.scale.x) if flip else absf(spr.scale.x)
	for c in spr.get_children():
		if c is Label:
			c.scale.x = -1.0 if flip else 1.0


func _refresh_nameplate(fid: int) -> void:
	var spr: AnmSprite = _sprites.get(fid)
	if spr == null:
		return
	var lbl := spr.get_node_or_null("Plate") as Label
	var f: Dictionary = State.fighters.get(fid, {})
	if lbl == null:
		return
	var lost := int(_hp_lost.get(fid, 0))
	lbl.text = str(f.get("name", fid)) + ("" if lost == 0 else "  -%d" % lost)


## Floating combat text — rises ~26px over ~0.9s and fades out.
func _float_text(fid: int, text: String, color: Color) -> void:
	var spr: AnmSprite = _sprites.get(fid)
	if spr == null or not is_inside_tree():
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-40, -104)
	lbl.size = Vector2(80, 16)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	spr.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)


## --- Buff strip ------------------------------------------------------
## One chip line under the nameplate ("Buffs" label) — the client's own
## effect container (PJ()): +2 AP·3, Rooted·∞… Chip text reuses the
## float label maps; `left` counts table-turns (server tickBuffs ages on
## 8100) and `src` is the source effectId so dispel can strip by params[0].

func _buff_label(action_id: int, value: int) -> String:
	if FX_RES_ID.has(action_id) or not _elem_fx(action_id).is_empty():
		var e: Array = FX_RES_ID.get(action_id, _elem_fx(action_id))
		return "%s%d %s" % ["-" if int(e[0]) < 0 else "+", value, e[1]]
	if FX_STATE.has(action_id):
		return FX_STATE[action_id]
	if FX_HP_GAIN.has(action_id):
		return "+%d HP" % value
	if FX_HP_LOSS.has(action_id):
		return "-%d HP" % value
	return ""


func _attach_buff(fid: int, action_id: int, src: int, value: int,
		left: int, inf: bool) -> void:
	var label := _buff_label(action_id, value)
	if fid <= 0 or label.is_empty():
		return
	var list: Array = _buffs.get_or_add(fid, [])
	for b in list:
		if int(b.src) == src:            # re-fire refreshes, never doubles
			b.left = left
			b.inf = inf
			_refresh_buffs(fid)
			return
	list.append({"label": label, "left": left, "inf": inf, "src": src})
	_refresh_buffs(fid)


## 8100 — every fighter's finite buffs lose one table-turn (tickBuffs);
## expired chips drop. Infinite (≥63 → sentinel) chips never age.
func _age_buffs() -> void:
	for fid in _buffs.keys():
		var kept := []
		for b in _buffs[fid]:
			if not b.inf:
				b.left = int(b.left) - 1
			if b.inf or int(b.left) > 0:
				kept.append(b)
		_buffs[fid] = kept
		_refresh_buffs(int(fid))


func _refresh_buffs(fid: int) -> void:
	var spr: AnmSprite = _sprites.get(fid)
	if spr == null:
		return
	var lbl := spr.get_node_or_null("Buffs") as Label
	if lbl == null:
		lbl = Label.new()
		lbl.name = "Buffs"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(-80, -112)
		lbl.size = Vector2(160, 14)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0))
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("shadow_offset_x", 1)
		lbl.add_theme_constant_override("shadow_offset_y", 1)
		spr.add_child(lbl)
		lbl.scale.x = -1.0 if spr.scale.x < 0 else 1.0   # counter-flip like Plate
	var parts := []
	for b in _buffs.get(fid, []):
		parts.append(str(b.label) if b.inf else "%s·%d" % [b.label, b.left])
	lbl.text = "  ".join(parts)
	lbl.visible = not parts.is_empty()


## 8121 — a buff re-attach for a viewer that missed the cast (reconnect /
## spectator join). It does NOT execute; expiry is an absolute mark on the
## fighter's own turn counter: rounds-left = expiry - turnsTaken (server
## buffExpiryMark), negative = infinite.
func _on_buff_attach(d: Dictionary) -> void:
	var fid := int(d.get("fighter", -1))
	var expiry := int(d.get("expiry", 0))
	_attach_buff(fid, int(d.get("action_id", 0)), int(d.get("gen_effect", 0)),
		int(d.get("value", 0)), expiry - int(_turns_taken.get(fid, 0)),
		expiry < 0)


## 8104 — a fighter's turn started. Ours: spell bar (8109 casts / 8111
## weapon), click a cell to move (4503), End turn sends 8105. The
## turn_began signal lets a harness drive instead.
func _on_turn_begin(fid: int) -> void:
	_current_fid = fid
	_spell_mode = -1
	_card_mode = -1
	_range_overlay.clear()
	# the client's per-fighter timeline counter (alh_1.aAw) bumps here —
	# 8121 buff expiries are absolute marks against it
	_turns_taken[fid] = int(_turns_taken.get(fid, 0)) + 1
	# onNewTurn — the fighter's own turn resets its per-turn cast counters
	for rec in _cast_hist.get(fid, {}).values():
		rec.n = 0
		rec.tgt = {}
	# mv_1.byv — the 8000 carries turnClockMs; retail floors it at 31s.
	_turn_left = maxf(31.0, float(State.fight_data.get("ca", 0)) / 1000.0)
	var f: Dictionary = State.fighters.get(fid, {})
	# Summons share their caster's coach id but are server-AI-driven
	# (Father set, ai.go) — no bar, no End turn for them.
	var ours: bool = int(f.get("coach", -1)) == State.my_coach_id \
		and not f.get("summon", false)
	_end_turn.disabled = not ours
	_face_btn.disabled = not ours
	if ours:
		var stats: Array = BREED_STATS.get(int(f.get("breed", 1)), [60, 6, 3])
		_ap_left = int(stats[1])
		_mp_left = int(stats[2])
		_build_spell_bar(f)
	else:
		_clear_spell_bar()
	info.text = "map %s — turn: %s%s" % [$UI/TopBar/MapId.text,
		f.get("name", str(fid)),
		" (yours — click a cell to move)" if ours else ""]
	_refresh_timeline()
	turn_began.emit(fid, ours)


## --- turn timeline ---------------------------------------------------------
## The 8000 `timeline` block is the initiative-descending fighter order —
## retail renders it as the top-of-screen portrait strip. Here: one chip per
## fighter, team-tinted like the placement cells (team0 blue / team1 red),
## acting fighter pressed, dead dimmed; clicking a chip centres the camera.
const TEAM_TINTS := [Color(0.3, 0.5, 1.0), Color(1.0, 0.4, 0.3)]

func _build_timeline() -> void:
	for c in _timeline.get_children():
		c.queue_free()
	if State.fighters.is_empty():
		return  # preview mode (Load) — no fight, no timeline
	for fid in State.fight_data.get("timeline", []):
		var f: Dictionary = State.fighters.get(fid, {})
		var tint: Color = TEAM_TINTS[clampi(int(f.get("team", 0)), 0, 1)]
		var b := Button.new()
		b.text = str(f.get("name", fid))
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_color_override("font_color", tint)
		b.add_theme_color_override("font_pressed_color", tint.lightened(0.35))
		b.tooltip_text = "turn order — click to centre"
		b.pressed.connect(_on_timeline_chip.bind(int(fid)))
		_timeline.add_child(b)
	_refresh_timeline()


func _refresh_timeline() -> void:
	var tl: Array = State.fight_data.get("timeline", [])
	var n: int = mini(tl.size(), _timeline.get_child_count())
	for i in n:
		var fid := int(tl[i])
		var b: Button = _timeline.get_child(i)
		b.set_pressed_no_signal(fid == _current_fid)
		b.modulate = Color(0.45, 0.45, 0.5, 0.7) \
			if _dead.get(fid, false) else Color.WHITE


func _on_timeline_chip(fid: int) -> void:
	var spr: AnmSprite = _sprites.get(fid)
	if spr != null:
		cam.position = spr.position


## --- spell casting ---------------------------------------------------------
## 8109 C2S [i64 fid][i32 spellId][i32 x][i32 y][i16 z] arch 3 — the server
## validates AP, ownership, range, LoS; silence = refused. 8111 is the weapon
## attack (same shape minus the spell id).

func _build_spell_bar(f: Dictionary) -> void:
	_clear_spell_bar()
	var bar: HBoxContainer = $UI/SpellBar
	for sid in f.get("spells", []):
		var b := Button.new()
		var sm := Spells.meta(int(sid))
		b.text = sm.get("name", "S%d" % int(sid))
		b.tooltip_text = "%s — %d AP, range %d-%d — click a target cell" % [
			b.text, int(sm.get("ap", -1)), int(sm.get("min", 0)),
			int(sm.get("max", 0))]
		b.disabled = _spell_locked(int(sid))
		b.pressed.connect(_on_spell_button.bind(int(sid)))
		bar.add_child(b)
		_spell_btns[int(sid)] = b
	var wb := Button.new()
	wb.text = "Wpn"
	wb.tooltip_text = "weapon attack — click an adjacent cell"
	wb.pressed.connect(_on_spell_button.bind(-2))
	bar.add_child(wb)
	# Equipped fighter cards with an ACTIVE ability (server jb_2.isUsable)
	# join the bar too — retail shows them as equipment icons feeding 8107.
	for ec in f.get("cards", []):
		var cid := int(ec.get("id", -1))
		if not FighterCards.usable(cid):
			continue
		var eb := Button.new()
		var ab := FighterCards.ability(cid)
		eb.text = FighterCards.label(cid)
		eb.tooltip_text = "%s — %d AP, range %d-%d (equipment)" % [
			eb.text, int(ab.get("ap", -1)), int(ab.get("min", 0)),
			int(ab.get("max", 0))]
		eb.pressed.connect(_on_card_button.bind(cid))
		bar.add_child(eb)
	var res := Label.new()
	res.name = "APMP"
	res.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(res)
	_refresh_apmp()


func _clear_spell_bar() -> void:
	for c in $UI/SpellBar.get_children():
		c.queue_free()
	_spell_btns.clear()


## Re-evaluate every spell button's lock after a cast lands (8110) — the
## per-turn cap and cooldown kick in immediately, retail greys the icon.
func _refresh_spell_locks() -> void:
	for sid in _spell_btns:
		var b: Button = _spell_btns[sid]
		if is_instance_valid(b):
			b.disabled = _spell_locked(int(sid))


func _refresh_apmp() -> void:
	var res := $UI/SpellBar.get_node_or_null("APMP") as Label
	if res != null:
		res.text = "  AP %d  MP %d" % [_ap_left, _mp_left]


## --- cast-range overlay -----------------------------------------------------
## While a spell/card/weapon is armed, retail tints the cells a cast could
## legally land on (the "zone de portée"). The overlay mirrors the server's
## spellTargetValidFrom gates — Manhattan range, only-line, line-of-sight,
## free-cell, enforced target mask — so a bright cell will not be refused.
## Dim cells are in range but blocked by one gate.
var _range_overlay := {}   # Vector2i -> 1 in-range-blocked / 2 castable
var _overlay_from := Vector3i(-9999, -9999, -9999)  # caster cell it was built for

# LoS constants mirroring server line_of_sight.go (client ahc_2/ahC):
const LOS_EYE := 4        # eye height over the cell floor (fighter PE*0.8)
const LOS_LOW := -30000   # a void/off-map cell never blocks the ray
const LOS_HIGH := 30000   # a scenery cell always blocks it

# Cast-level target-mask bits (client aLc / server target_conditions.go):
# 2 caster, 4 ally, 8 enemy, 16 human, 32 summoned, 64 effect-area,
# 128 ally-except-caster, 256 not-caster, 512 breed-0, 1024 breed-nonzero,
# bits 16-29 breed IS k+1, bits 32-45 breed NOT k+1. Anything else (the
# state bank 49-57, bit 62 ground-area) is unevaluable here → permissive,
# the same escape hatch the server takes in spellTargetMaskAllows.
const COND_EVALUABLE := 1 | 2 | 4 | 8 | 16 | 32 | 64 | 128 | 256 | 512 | 1024 \
	| 0x3FFF0000 | 0x3FFF00000000


func _refresh_range_overlay() -> void:
	_range_overlay.clear()
	_overlay_from = _actor_cells.get(_current_fid, Vector3i(-9999, -9999, -9999))
	if _placement or not _is_my_turn():
		return
	var meta := {}
	if _spell_mode == -2:
		meta = {"min": 1, "max": 1}              # weapon — adjacent melee
	elif _spell_mode >= 0:
		meta = Spells.meta(_spell_mode)
	elif _card_mode >= 0:
		meta = FighterCards.ability(_card_mode)
	if meta.is_empty():
		return
	var from := Vector2i(_overlay_from.x, _overlay_from.y)
	var rmin := int(meta.get("min", 0))
	var rmax := int(meta.get("max", 0))
	for pos in _cells:
		var c: Dictionary = _cells[pos]
		if not c.get("ground", false):
			continue                             # unaimable (walkable gate)
		var dist := absi(pos.x - from.x) + absi(pos.y - from.y)
		if dist < rmin or dist > rmax:
			continue
		var castable := true
		if meta.get("line", false) and pos.x != from.x and pos.y != from.y:
			castable = false
		elif meta.get("los", false) and not _los_clear(from, pos):
			castable = false
		elif meta.get("free", false) and _occupied_fighter(pos) >= 0:
			castable = false
		elif not _mask_passes(meta.get("mask", []), pos):
			castable = false
		elif int(meta.get("mptt", 0)) > 0 and _target_capped(pos, meta):
			castable = false
		_range_overlay[pos] = 2 if castable else 1
	queue_redraw()


## Living, un-carried fighter on a cell — the occupancy rule the server's
## cellOccupied applies to free-cell and target-mask gates.
func _occupied_fighter(pos: Vector2i) -> int:
	for fid in _actor_cells:
		if _dead.get(fid, false) or _carried_by.has(fid):
			continue
		var p: Vector3i = _actor_cells[fid]
		if p.x == pos.x and p.y == pos.y:
			return int(fid)
	return -1


## Cast-level target mask (spell field 22 — only the few spells flagged
## EnforceTargetMasks reach the export): the aimed cell must hold a fighter
## satisfying ONE condition, and a condition needs every set bit to hold.
func _mask_passes(masks: Array, pos: Vector2i) -> bool:
	if masks.is_empty():
		return true
	var fid := _occupied_fighter(pos)
	if fid < 0:
		return false                        # every mask names a fighter property
	var f: Dictionary = State.fighters.get(fid, {})
	var cf: Dictionary = State.fighters.get(_current_fid, {})
	var is_self := fid == _current_fid
	var same_team := int(f.get("team", -1)) == int(cf.get("team", -2))
	var is_summon := bool(f.get("summon", false)) \
		or str(f.get("type", "")) == "summon"
	var breed := 0 if is_summon else int(f.get("breed", 0))
	for m in masks:
		var cond := int(m)
		if cond & ~COND_EVALUABLE != 0:
			return true                     # unrepresentable bit — permissive
		var ok := true
		if cond & 2 and not is_self:
			ok = false
		if cond & 256 and is_self:
			ok = false
		if cond & 4 and not same_team:
			ok = false
		if cond & 128 and (is_self or not same_team):
			ok = false
		if cond & 8 and same_team:
			ok = false
		if cond & 16 and is_summon:
			ok = false
		if cond & 32 and not is_summon:
			ok = false
		if cond & 64:
			ok = false                      # a fighter is never an effect area
		if cond & 512 and breed != 0:
			ok = false
		if cond & 1024 and breed == 0:
			ok = false
		var is_bank := int(cond >> 16) & 0x3FFF
		var not_bank := int(cond >> 32) & 0x3FFF
		for k in 14:
			if is_bank & (1 << k) and breed != k + 1:
				ok = false
			if not_bank & (1 << k) and breed == k + 1:
				ok = false
		if ok:
			return true
	return false


func _los_altitude(pos: Vector2i) -> int:
	var c: Variant = _cells.get(pos)
	if c == null:
		return LOS_LOW
	if not c.get("ground", false):
		return LOS_HIGH
	return int(c.get("alt", 0))


## Client ahc_2 two-try check: eye→eye, then eye→feet.
func _los_clear(from: Vector2i, to: Vector2i) -> bool:
	var feet0 := _los_altitude(from)
	var feet1 := _los_altitude(to)
	if _ray_clear(from, to, feet0 + LOS_EYE, feet1 + LOS_EYE):
		return true
	return _ray_clear(from, to, feet0 + LOS_EYE, feet1)


## Samples the ray 8× per crossed cell; an intermediate cell blocks sight
## when its terrain altitude pokes above the ray's lowest altitude over it.
## The endpoint cells are exempt, exactly like the server's rayClear.
func _ray_clear(from: Vector2i, to: Vector2i, z0: int, z1: int) -> bool:
	var steps := maxi(absi(to.x - from.x), absi(to.y - from.y))
	if steps == 0:
		return true
	var n := steps * 8
	var min_ray := {}
	for i in n + 1:
		var t := float(i) / n
		var k := Vector2i(int(round(from.x + (to.x - from.x) * t)),
			int(round(from.y + (to.y - from.y) * t)))
		var z := int(round(z0 + (z1 - z0) * t))
		if not min_ray.has(k) or z < min_ray[k]:
			min_ray[k] = z
	for k in min_ray:
		if k == from or k == to:
			continue
		if _los_altitude(k) > min_ray[k]:
			return false
	return true


func _on_spell_button(sid: int) -> void:
	_spell_mode = -2 if _spell_mode == sid else sid
	_card_mode = -1
	info.text = "map %s — %s: click a target" % [$UI/TopBar/MapId.text,
		"weapon" if sid == -2 else "spell %d" % sid]
	_refresh_range_overlay()


func _on_card_button(cid: int) -> void:
	_card_mode = -1 if _card_mode == cid else cid
	_spell_mode = -1
	info.text = "map %s — card %s: click a target" % [
		$UI/TopBar/MapId.text, FighterCards.label(cid)]
	_refresh_range_overlay()


func _is_my_turn() -> bool:
	if _current_fid < 0 or _dead.get(_current_fid, false):
		return false
	var f: Dictionary = State.fighters.get(_current_fid, {})
	# our own coach's summon is AI-driven server-side (Father set) — the UI
	# never sends its inputs.
	return int(f.get("coach", -1)) == State.my_coach_id \
		and not f.get("summon", false)


## Send 8109 (spell) or sid=-2 → 8111 (weapon) at `cell`.
func request_cast_at(sid: int, cell: Vector2i) -> bool:
	if not _is_my_turn() or State.net == null or sid == -1:
		return false
	var c: Dictionary = _cells.get(cell, {})
	var w := WireWriter.new()
	w.put_i64(_current_fid)
	if sid >= 0:
		w.put_i32(sid)
	w.put_i32(cell.x)
	w.put_i32(cell.y)
	w.put_i16(int(c.get("alt", 0)))
	State.net.send_message(
		OP_SPELL_CAST_REQ if sid >= 0 else OP_CLOSE_COMBAT_REQ, w.raw(), 3)
	print("[fight] %s fid=%d -> (%d,%d)" % [
		"cast %d" % sid if sid >= 0 else "weapon", _current_fid, cell.x, cell.y])
	_spell_mode = -1
	_range_overlay.clear()
	queue_redraw()
	return true


## Send 8107 (fighter-equipment active) at `cell` — same target shape as the
## weapon attack plus the card id; the server validates AP/range/equipped.
func request_card_at(cid: int, cell: Vector2i) -> bool:
	if not _is_my_turn() or State.net == null or cid < 0:
		return false
	var c: Dictionary = _cells.get(cell, {})
	var w := WireWriter.new()
	w.put_i64(_current_fid)
	w.put_i32(cid)
	w.put_i32(cell.x)
	w.put_i32(cell.y)
	w.put_i16(int(c.get("alt", 0)))
	State.net.send_message(OP_CARD_USE_REQ, w.raw(), 3)
	print("[fight] card %d fid=%d -> (%d,%d)" % [cid, _current_fid,
		cell.x, cell.y])
	_card_mode = -1
	_range_overlay.clear()
	queue_redraw()
	return true


func request_end_turn() -> void:
	_end_turn.disabled = true
	if _current_fid < 0 or State.net == null:
		return
	var w := WireWriter.new()
	w.put_i64(_current_fid)
	State.net.send_message(OP_END_TURN, w.raw(), 3)


## The top-bar action button is "Ready" during placement, "End turn" in combat.
func _on_action_button() -> void:
	if State.spectating:
		return
	if _placement:
		confirm_placement()
	else:
		request_end_turn()


## --- placement phase -------------------------------------------------------
## 8021 C2S: [i64 fighterId][i32 x][i32 y][i16 z] — server validates the cell
## is one of OUR team's start cells, walkable and unoccupied (8022 confirms).

const OP_PLACE_REQ := 8021


func confirm_placement() -> void:
	if not _placement or State.spectating:
		return
	_placement = false
	_end_turn.disabled = true
	if State.net != null:
		State.net.send_message(OP_READY_OBSERVATION, PackedByteArray(), 3)


## Our team's id from the fighter index (-1 when ours aren't indexed yet).
func _my_team() -> int:
	for fid in State.fighters:
		var f: Dictionary = State.fighters[fid]
		if int(f.get("coach", -1)) == State.my_coach_id:
			return int(f.get("team", -1))
	return -1


func request_place_at(cell: Vector2i) -> bool:
	if not _placement or _selected < 0 or State.net == null:
		return false
	var t := _my_team()
	var cells: Array = _fmd.get("team%d" % t, [])
	var legal := false
	var z := 0
	for c in cells:
		if c.x == cell.x and c.y == cell.y:
			legal = true
			z = int(c.z)
	# .fmd spawn z can be a sentinel (-1): fall back to the terrain altitude
	var gc: Variant = _cells.get(cell)
	if z < 0 and gc != null:
		z = int(gc.alt)
	if not legal:
		return false
	for id in _actor_cells:
		if id == _selected:
			continue
		var p: Vector3i = _actor_cells[id]
		if p.x == cell.x and p.y == cell.y:
			return false   # occupied
	var w := WireWriter.new()
	w.put_i64(_selected)
	w.put_i32(cell.x)
	w.put_i32(cell.y)
	w.put_i16(z)
	State.net.send_message(OP_PLACE_REQ, w.raw(), 3)
	print("[fight] place req fid=%d -> (%d,%d,%d)" % [_selected, cell.x, cell.y, z])
	return true


## Our (living) fighter standing on `cell`, for click-to-select in placement.
func _own_fighter_at(cell: Vector2i) -> int:
	for id in _actor_cells:
		var p: Vector3i = _actor_cells[id]
		if p.x != cell.x or p.y != cell.y:
			continue
		var f: Dictionary = State.fighters.get(id, {})
		if int(f.get("coach", -1)) == State.my_coach_id and not _dead.get(id, false):
			return int(id)
	return -1


## --- interactive movement --------------------------------------------------
## 4503 C2S: [i64 fighterId] + step cells {i32 x, i32 y, i16 z} — the retail
## client sends the steps EXCLUDING the origin (server comment, verified).
## Server validates each step: adjacent, walkable, unoccupied, within MP.

const OP_MOVE_REQ := 4503


func _process(delta: float) -> void:
	if _turn_left >= 0.0:
		_turn_left = maxf(_turn_left - delta, 0.0)
		_turn_timer.text = "%d" % ceili(_turn_left)
		_turn_timer.modulate = Color(1.0, 0.45, 0.3) if _turn_left <= 5.5 \
			else Color(0.9, 0.9, 0.9)
	if _spell_mode != -1 or _card_mode != -1:
		# the reach ring follows the acting fighter — recompute after a move
		var at: Vector3i = _actor_cells.get(_current_fid,
			Vector3i(-9999, -9999, -9999))
		if at != _overlay_from:
			_refresh_range_overlay()
	if _walk.is_empty():
		return
	for fid in _walk.keys():
		var path: Array = _walk[fid]
		var spr: AnmSprite = _sprites.get(fid)
		if spr == null or path.is_empty():
			_walk.erase(fid)
			continue
		var c: Vector3i = path[0]
		var target := _iso(c.x + 0.5, c.y + 0.5, c.z)
		var d := target - spr.position
		if d.length() <= WALK_SPEED * delta:
			path.pop_front()
			spr.position = target
			spr.z_index = clampi((c.x + c.y) * 4 + 1, -4096, 4096)
			_actor_cells[fid] = c
			if path.is_empty():
				_walk.erase(fid)
			else:
				_face_step(fid)
		else:
			spr.position += d / d.length() * WALK_SPEED * delta
		_carry_follow(fid, spr)
	queue_redraw()


## A carried fighter rides on its carrier (58): it glides with the carrier's
## sprite, offset upward so both stay visible, and tracks its cell.
func _carry_follow(fid: int, spr: AnmSprite) -> void:
	for cid in _carried_by:
		if _carried_by[cid] != fid:
			continue
		var cspr: AnmSprite = _sprites.get(cid)
		if cspr != null:
			cspr.position = spr.position + Vector2(0, -70)
			_actor_cells[cid] = _actor_cells.get(fid, Vector3i.ZERO)


## Face the fighter toward its next path cell.
func _face_step(fid: int) -> void:
	var path: Array = _walk.get(fid, [])
	var cur: Vector3i = _actor_cells.get(fid, Vector3i.ZERO)
	if path.is_empty():
		return
	var d := Vector2i(path[0].x - cur.x, path[0].y - cur.y)
	var dir: int = STEP_DIR.get(d, -1)
	if dir < 0 or _actor_dir.get(fid, -1) == dir:
		return
	_actor_dir[fid] = dir
	var spr: AnmSprite = _sprites.get(fid)
	if spr == null or not State.fighters.has(fid):
		return
	_set_flip(spr, DIR_FLIP.get(dir, false))
	_load_fighter_anim(spr, fid, dir)


## Re-face one actor to a server direction (4522 or 4521-driven).
func _reface(fid: int, dir: int) -> void:
	var spr: AnmSprite = _sprites.get(fid)
	if spr == null or not State.fighters.has(fid):
		return
	_set_flip(spr, DIR_FLIP.get(dir, false))
	_load_fighter_anim(spr, fid, dir)


## Load the idle animation for a fighter in a given wire direction, falling
## back to the coach sprite when the breed's fighter set has no asset —
## summons carry breed -1 and never have a fighter file.
func _load_fighter_anim(spr: AnmSprite, fid: int, wire_dir: int) -> void:
	var f: Dictionary = State.fighters[fid]
	var breed := int(f.get("breed", 1))
	var action := "%d_AnimStatique" % DIR_MAP.get(wire_dir, 1)
	if breed >= 1 and spr.load_action(FIGHTER_SET % _fighter_file(
			breed, int(f.get("sex", 0))), action):
		return
	spr.load_action(COACH_SET, action)


## Face button: cycle the acting fighter's facing one diagonal clockwise and
## send 4521 — a free action the server broadcasts back as 4522.
func _on_face_pressed() -> void:
	if not _is_my_turn() or State.net == null:
		return
	var cur: int = _actor_dir.get(_current_fid, 1)
	var dirs := [1, 3, 5, 7]
	var nxt: int = dirs[(dirs.find(cur) + 1) % dirs.size()]
	var w := WireWriter.new()
	w.put_i64(_current_fid)
	w.put_u8(nxt)
	State.net.send_message(OP_DIR_CHANGE_REQ, w.raw(), 3)


## World pixel -> grid cell: nearest ground-cell center within a cell diag.
func _cell_at(world: Vector2) -> Variant:
	var best := Vector2i.ZERO
	var best_d := HW * HW + HH * HH   # ~half-cell radius
	var found := false
	for pos in _cells:
		var c: Dictionary = _cells[pos]
		if not c.ground:
			continue
		var d := world.distance_squared_to(_iso(pos.x + 0.5, pos.y + 0.5, c.alt))
		if d < best_d:
			best_d = d
			best = pos
			found = true
	return best if found else null


## BFS over ground cells, 4-connected, sidestepping occupied cells.
## Returns the step list EXCLUDING `from` (the 4503 format), or [].
func _find_path(from: Vector2i, to: Vector2i, ignore_fid: int) -> Array:
	var blocked := {}
	for id in _actor_cells:
		if id == ignore_fid:
			continue
		var p: Vector3i = _actor_cells[id]
		blocked[Vector2i(p.x, p.y)] = true
	var prev := {from: from}
	var queue := [from]
	var qi := 0
	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while qi < queue.size():
		var c: Vector2i = queue[qi]
		qi += 1
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if prev.has(n) or blocked.has(n):
				continue
			var cell: Variant = _cells.get(n)
			if cell == null or not cell.ground:
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(to):
		return []
	var path := []
	var cur := to
	while cur != from:
		var cell: Dictionary = _cells[cur]
		path.push_front(Vector3i(cur.x, cur.y, int(cell.alt)))
		cur = prev[cur]
	return path


## Walk preview for the hovered cell on our turn — the same _find_path the
## click sends, so the dots/MP label always match what would go out on 4503.
## Empty during placement, with a spell/card armed, or off-turn.
func _preview_path() -> Array:
	if _placement or _spell_mode != -1 or _card_mode != -1:
		return []
	if not _is_my_turn() or not _cells.has(_hover):
		return []
	if not _cells[_hover].ground:
		return []
	var cur: Vector3i = _actor_cells.get(_current_fid, Vector3i.ZERO)
	return _find_path(Vector2i(cur.x, cur.y), _hover, _current_fid)


func _try_move() -> void:
	if State.spectating:
		return   # read-only viewer: clicks only pan/zoom
	var cell: Variant = _cell_at(cam.get_global_mouse_position())
	if cell == null:
		return
	if _placement:
		# click own fighter -> select; click a free spawn cell -> 8021
		var who := _own_fighter_at(cell)
		if who >= 0:
			_selected = who
			queue_redraw()
		else:
			request_place_at(cell)
	elif _spell_mode != -1:
		request_cast_at(_spell_mode, cell)
	elif _card_mode != -1:
		request_card_at(_card_mode, cell)
	else:
		request_move_to(cell)


## Public move entry — click handler and scripted drivers both land here.
## Returns true if a 4503 went out (the 4524 broadcast confirms it).
func request_move_to(cell: Vector2i) -> bool:
	if not _is_my_turn() or State.net == null:
		return false
	var cur: Vector3i = _actor_cells.get(_current_fid, Vector3i.ZERO)
	var path := _find_path(Vector2i(cur.x, cur.y), cell, _current_fid)
	if path.is_empty():
		return false
	var w := WireWriter.new()
	w.put_i64(_current_fid)
	for p in path:
		w.put_i32(p.x)
		w.put_i32(p.y)
		w.put_i16(p.z)
	State.net.send_message(OP_MOVE_REQ, w.raw(), 3)
	print("[fight] move req fid=%d -> (%d,%d) %d steps" % [
		_current_fid, cell.x, cell.y, path.size()])
	return true


static func _fighter_file(breed: int, sex: int) -> String:
	if breed >= 1 and breed <= 12:
		return FIGHTER_FILES[(breed - 1) * 2 + clampi(sex, 0, 1)]
	return FIGHTER_FILES[24 + clampi(breed - 7000, 0, 1)]


func _cell_poly(x: int, y: int, alt: float) -> PackedVector2Array:
	var c := _iso(x + 0.5, y + 0.5, alt)
	return PackedVector2Array([
		c + Vector2(0, -HH), c + Vector2(HW, 0),
		c + Vector2(0, HH), c + Vector2(-HW, 0)])


func _alt_color(alt: float) -> Color:
	var t := 0.5 if _alt_max == _alt_min else inverse_lerp(_alt_min, _alt_max, alt)
	return Color(0.25 + 0.45 * t, 0.35 + 0.35 * t, 0.3, 1.0)


func _draw() -> void:
	if _gfx_active:
		# painted backdrop already carries ground+walls — keep only the
		# gameplay overlays (spawn zones, placement/hover rings)
		_draw_overlays()
		return
	# pass 1: floor tops, back-to-front so lower rows paint over upper walls
	for pos in _sorted:
		var c: Dictionary = _cells[pos]
		var poly := _cell_poly(pos.x, pos.y, c.alt)
		draw_colored_polygon(poly, _alt_color(c.alt))
		draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0, 0, 0, 0.25), 1.0)
	# pass 2: wall faces where a cell drops toward a lower/void +x or +y
	# neighbour — the "aba" drop height retail draws as a cliff skirt.
	const FRONT := [Vector2i(1, 0), Vector2i(0, 1)]
	for pos in _sorted:
		var c: Dictionary = _cells[pos]
		var top := _cell_poly(pos.x, pos.y, c.alt)
		for d in FRONT:
			var n: Variant = _cells.get(pos + d)
			var drop := 0.0
			if n == null or not n.ground:
				drop = minf(float(c.alt - _alt_min + 1) * EL, 4.0 * EL)
			elif n.alt < c.alt:
				drop = float(c.alt - n.alt) * EL
			if drop <= 0.0:
				continue
			var down := Vector2(0, drop)
			var wall := PackedVector2Array([top[2], top[1], top[1] + down, top[2] + down] \
				if d.x > 0 else [top[3], top[2], top[2] + down, top[3] + down])
			var shade := 0.38 if d.x > 0 else 0.55
			draw_colored_polygon(wall, _alt_color(c.alt).darkened(shade))
	_draw_overlays()


func _draw_overlays() -> void:
	for pos in _cells:
		var c = _cells[pos]
		if not c.ground:
			draw_polyline(_cell_poly(pos.x, pos.y, 0) + PackedVector2Array([
				_cell_poly(pos.x, pos.y, 0)[0]]), Color(1, 1, 1, 0.06), 1.0)
	for c in _fmd.get("team0", []):
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(0.3, 0.5, 1.0, 0.6))
	for c in _fmd.get("team1", []):
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(1.0, 0.4, 0.3, 0.6))
	for c in _fmd.get("coach", []):
		if c.x <= -2047:
			continue
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(1.0, 0.85, 0.2, 0.5))
	# special battlefield tiles — a small lettered diamond marks each
	for sc in _fmd.get("specials", []):
		var sp: Dictionary = sc.pos          # {x,y,z} — z is the altitude
		var sm: Array = SPECIAL_CELLS.get(int(sc.template), ["?", "?", Color(0.7, 0.7, 0.7)])
		var ctr := _iso(float(sp.x) + 0.5, float(sp.y) + 0.5, float(sp.z))
		var dm := PackedVector2Array([ctr + Vector2(0, -7), ctr + Vector2(7, 0),
			ctr + Vector2(0, 7), ctr + Vector2(-7, 0)])
		var col: Color = sm[2]
		draw_colored_polygon(dm, Color(col.r, col.g, col.b, 0.25))
		draw_polyline(dm + PackedVector2Array([dm[0]]), col, 1.5)
		draw_string(ThemeDB.fallback_font, ctr + Vector2(-3.5, 4), sm[0],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col)
	# placed traps/glyphs/auras — footprint tinted per the type-210 template
	for a in _areas:
		var csp: AnmSprite = _sprites.get(int(a.caster))
		if csp != null and csp.modulate.a < 0.9:
			continue                # hidden caster → hidden area (aew_1.aoy)
		var m: Dictionary = Areas.meta(int(a.tpl))
		var actr: Vector3i = _actor_cells.get(int(a.caster), a.ctr) \
			if a.aura else a.ctr
		var acol := Color(0.3, 0.9, 1.0) if a.aura else \
			(Color(1.0, 0.6, 0.15) if bool(m.get("w", false))
				else Color(0.65, 0.4, 1.0))
		for cell: Vector2i in Areas.footprint(int(a.tpl), actr):
			var cz := int(_cells.get(cell, {}).get("alt", actr.z))
			var fp := _cell_poly(cell.x, cell.y, cz)
			draw_colored_polygon(fp, Color(acol.r, acol.g, acol.b, 0.14))
			draw_polyline(fp + PackedVector2Array([fp[0]]),
				Color(acol.r, acol.g, acol.b, 0.7), 1.0)
		draw_circle(_iso(float(actr.x) + 0.5, float(actr.y) + 0.5,
			float(actr.z)), 3.0, acol)
	if _placement:
		# our start cells glow; selected fighter gets a ring
		var t := _my_team()
		for c in _fmd.get("team%d" % t, []):
			draw_colored_polygon(_cell_poly(c.x, c.y, c.z),
				Color(0.4, 0.9, 1.0, 0.55))
		if _selected >= 0 and _actor_cells.has(_selected):
			var p: Vector3i = _actor_cells[_selected]
			draw_arc(_iso(p.x + 0.5, p.y + 0.5, p.z), 14.0, 0, TAU, 24,
				Color(1, 1, 1), 2.0)
	for pos in _range_overlay:
		var rc: Dictionary = _cells[pos]
		var legal: bool = _range_overlay[pos] == 2
		draw_colored_polygon(_cell_poly(pos.x, pos.y, rc.alt),
			Color(1.0, 0.5, 0.1, 0.45) if legal
			else Color(1.0, 0.5, 0.1, 0.12))
	# movement path preview — retail dots the walk steps and floats the MP
	# cost at the target; red once the path exceeds the MP we have left.
	var path := _preview_path()
	if not path.is_empty():
		var pc := Color(0.4, 1.0, 0.4, 0.9) if path.size() <= _mp_left \
			else Color(1.0, 0.35, 0.3, 0.9)
		for p in path:
			draw_circle(_iso(p.x + 0.5, p.y + 0.5, p.z), 3.5, pc)
		draw_string(ThemeDB.fallback_font,
			_iso(_hover.x + 0.5, _hover.y + 0.5, _cells[_hover].alt) + Vector2(8, -10),
			"%d MP" % path.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, pc)
	if not _placement and _is_my_turn() and _cells.has(_hover):
		var hc: Dictionary = _cells[_hover]
		# AoE preview — an armed spell/card's effect zones (data-side `zn`,
		# the same areaShape/areaSize the server feeds areaFighters) tint the
		# cells they would hit. Only on a castable hover — matching retail,
		# which shows the zone only where the cast would land.
		if (_spell_mode >= 0 or _card_mode >= 0) and \
				int(_range_overlay.get(_hover, 0)) == 2:
			var meta: Dictionary = Spells.meta(_spell_mode) \
				if _spell_mode >= 0 else FighterCards.ability(_card_mode)
			var src3: Vector3i = _actor_cells.get(_current_fid, Vector3i.ZERO)
			var aim := Vector3i(_hover.x, _hover.y, int(hc.alt))
			for zn in meta.get("zn", []):
				for cell: Vector2i in Areas.footprint_cells(int(zn[0]),
						zn.slice(1), aim, src3):
					if _cells.has(cell):
						var zp := _cell_poly(cell.x, cell.y,
							int(_cells[cell].get("alt", 0)))
						draw_colored_polygon(zp,
							Color(1.0, 0.45, 0.15, 0.22))
		var poly := _cell_poly(_hover.x, _hover.y, hc.alt)
		draw_polyline(poly + PackedVector2Array([poly[0]]),
			Color(1, 0.3, 0.25, 0.9) if _spell_mode != -1
			else Color(1, 1, 1, 0.8), 2.0)
	if debug_overlay:
		# white crosshair at each live actor's cell center
		for id in _actor_cells:
			var p: Vector3i = _actor_cells[id]
			var c := _iso(p.x + 0.5, p.y + 0.5, p.z)
			draw_circle(c, 3.0, Color(1, 1, 1))
			draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(1, 1, 1), 1.0)
			draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(1, 1, 1), 1.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_ENTER:
		$UI/Chat.grab_chat_focus()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam.zoom *= 1.15
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam.zoom *= 0.87
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
				_dragging = true
			else:
				_dragging = false
				# a press+release under ~6px is a click, not a camera drag
				if event.position.distance_to(_press_pos) < 6.0:
					_try_move()
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion:
		if _dragging:
			cam.position -= event.relative / cam.zoom
		elif _is_my_turn() or _placement:
			var cell: Variant = _cell_at(get_global_mouse_position())
			var h: Vector2i = cell if cell != null else Vector2i(-9999, -9999)
			if h != _hover:
				_hover = h
				queue_redraw()
