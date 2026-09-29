extends Node2D

## Placeholder isometric fight-map view: topology ground cells shaded by
## altitude + .fmd spawn cells. Original art replaces this once the asset
## pipeline lands — positions/projection stay identical.
##
## Projection (maprender.go): screen = ((x-y)*43, (x+y)*21.5 - alt*10).

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")
const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const State := preload("res://src/state.gd")
const Codec := preload("res://src/net/codec.gd")
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
var _sprites := {}   # actor id -> AnmSprite

@onready var cam: Camera2D = $Camera
@onready var info: Label = $UI/Info
@onready var _actors: Node2D = $Actors
@onready var _end_turn: Button = $UI/TopBar/EndTurnBtn
var _dragging := false
var _press_pos := Vector2.ZERO
var _hover := Vector2i(-9999, -9999)   # hovered cell (our turn only)


func _ready() -> void:
	$UI/TopBar/LoadBtn.pressed.connect(_load)
	_end_turn.pressed.connect(_on_action_button)
	$UI/TopBar/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/main.tscn"))
	# When we arrived here from a live fight the world id is the arena id.
	if State.fight_world >= 0:
		$UI/TopBar/MapId.text = str(State.fight_world)
	_load()
	if State.net != null:
		for m in State.net.drain():
			_on_net_message(m.op, WireReader.new(m.raw))
		State.net.message_received.connect(_on_net_message)
		State.net.scene_active = true


func _load() -> void:
	var map_id := int($UI/TopBar/MapId.text)
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
const OP_END_FIGHT := 8300     # S2C result screen — ack with 26321
const OP_END_FIGHT_DONE := 26321  # C2S empty — server returns us to overworld
const OP_ENTER_INSTANCE := 4600

var _fight_over := false
var _actor_cells := {}   # id -> Vector3i
var _current_fid := -1   # fighter whose turn is running (8104 → 8106)
var _walk := {}          # actor id -> Array[Vector3i] remaining walk cells
var _actor_dir := {}     # actor id -> last server dir (facing during walk)
var _hp_lost := {}       # fighter id -> accumulated damage (8000 + 8120)
var _dead := {}          # fighter id -> true once 4520 arrives
var _placement := false  # 8020 → 8028 window: 8021 moves are legal
var _selected := -1      # our fighter selected for placement

## Emitted on 8104 — a harness (fight_smoke's scripted policy) or the human
## drives from here: request_move_to() then request_end_turn().
signal turn_began(fid: int, ours: bool)
## Emitted on 8020 — placement window is open until confirm_placement()
## sends 8023. The human version finishes by pressing the Ready button.
signal placement_began

## White crosshairs at each actor's cell center (placement debugging).
var debug_overlay := false

const WALK_SPEED := 160.0   # px/sec along the path
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


func _on_net_message(opcode: int, payload: WireReader) -> void:
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
			_end_turn.text = "End turn"
			_end_turn.disabled = true
		OP_START_OBSERVATION:
			# third gate: 8031 (arch 3, empty) advances to the action phase.
			_placement = false
			_end_turn.text = "End turn"
			if State.net != null:
				State.net.send_message(OP_READY_ACTION, PackedByteArray(), 3)
			info.text += " | observation"
		OP_START_ACTION:
			info.text += " | combat!"
		OP_TABLE_TURN:
			var d := Codec.decode(opcode, payload)
			info.text = "map %s — turn %d" % [$UI/TopBar/MapId.text, int(d.get("f2", 0))]
		OP_TURN_BEGIN:
			var d := Codec.decode(opcode, payload)
			_on_turn_begin(int(d.get("f2", -1)))
		OP_TURN_END:
			_current_fid = -1
			_end_turn.disabled = true
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
			if path.size() > 1:
				path.pop_front()   # drop the origin cell
				_walk[fid] = path
				_face_step(fid)
			elif path.size() == 1:
				_move_actor(fid, path[0])
		OP_FIGHTER_DIES:
			payload.get_i32()
			payload.get_i32()
			_kill_actor(int(payload.get_i64()))
		OP_RUNNING_EFFECT:
			_on_running_effect(Codec.decode(opcode, payload))
		OP_END_FIGHT:
			# Result screen — we ack (26321 empty); the server then sends a
			# fresh 4600 to put the coach back into its overworld.
			_fight_over = true
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
		var file := _fighter_file(int(f.get("breed", 1)), int(f.get("sex", 0)))
		var action := "%d_AnimStatique" % dir
		if not spr.load_action(FIGHTER_SET % file, action):
			spr.load_action(COACH_SET, "5_AnimStatique")
		_hp_lost[a.id] = int(f.get("hp_lost", 0))
		_nameplate(spr, a.id)
	else:
		spr.load_action(COACH_SET, "%d_AnimStatique" % dir)
	spr.position = _iso(a.x + 0.5, a.y + 0.5, a.z)
	spr.z_index = clampi(int(a.x + a.y) * 4 + 1, -4096, 4096)
	_actor_cells[a.id] = Vector3i(a.x, a.y, a.z)
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


## 8120 — apply a running effect visually: HP effects float text and update
## the nameplate counter; AP/MP debits (91/92) and upkeep are silent.
func _on_running_effect(d: Dictionary) -> void:
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


## 4520 — grey out the corpse; its cell stays occupied for pathing.
func _kill_actor(fid: int) -> void:
	_dead[fid] = true
	var spr: AnmSprite = _sprites.get(fid)
	if spr != null:
		spr.playing = false
		spr.modulate = Color(0.55, 0.55, 0.6, 0.85)
	if _current_fid == fid:
		_current_fid = -1
		_end_turn.disabled = true


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


## 8104 — a fighter's turn started. Ours: click a cell to move (4503),
## End turn sends 8105. The turn_began signal lets a harness drive instead.
func _on_turn_begin(fid: int) -> void:
	_current_fid = fid
	var f: Dictionary = State.fighters.get(fid, {})
	var ours := int(f.get("coach", -1)) == State.my_coach_id
	_end_turn.disabled = not ours
	info.text = "map %s — turn: %s%s" % [$UI/TopBar/MapId.text,
		f.get("name", str(fid)),
		" (yours — click a cell to move)" if ours else ""]
	turn_began.emit(fid, ours)


func request_end_turn() -> void:
	_end_turn.disabled = true
	if _current_fid < 0 or State.net == null:
		return
	var w := WireWriter.new()
	w.put_i64(_current_fid)
	State.net.send_message(OP_END_TURN, w.raw(), 3)


## The top-bar action button is "Ready" during placement, "End turn" in combat.
func _on_action_button() -> void:
	if _placement:
		confirm_placement()
	else:
		request_end_turn()


## --- placement phase -------------------------------------------------------
## 8021 C2S: [i64 fighterId][i32 x][i32 y][i16 z] — server validates the cell
## is one of OUR team's start cells, walkable and unoccupied (8022 confirms).

const OP_PLACE_REQ := 8021


func confirm_placement() -> void:
	if not _placement:
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
	queue_redraw()


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
	var f: Dictionary = State.fighters[fid]
	spr.load_action(FIGHTER_SET % _fighter_file(
		int(f.get("breed", 1)), int(f.get("sex", 0))),
		"%d_AnimStatique" % DIR_MAP.get(dir, 1))


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


func _try_move() -> void:
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
	for pos in _cells:
		var c = _cells[pos]
		var poly := _cell_poly(pos.x, pos.y, c.alt if c.ground else 0)
		if c.ground:
			draw_colored_polygon(poly, _alt_color(c.alt))
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0, 0, 0, 0.25), 1.0)
		else:
			draw_polyline(poly + PackedVector2Array([poly[0]]), Color(1, 0, 0, 0.15), 1.0)
	for c in _fmd.get("team0", []):
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(0.3, 0.5, 1.0, 0.6))
	for c in _fmd.get("team1", []):
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(1.0, 0.4, 0.3, 0.6))
	for c in _fmd.get("coach", []):
		if c.x <= -2047:
			continue
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(1.0, 0.85, 0.2, 0.5))
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
	elif _is_my_turn() and _cells.has(_hover):
		var hc: Dictionary = _cells[_hover]
		var poly := _cell_poly(_hover.x, _hover.y, hc.alt)
		draw_polyline(poly + PackedVector2Array([poly[0]]),
			Color(1, 1, 1, 0.8), 2.0)
	if debug_overlay:
		# white crosshair at each live actor's cell center
		for id in _actor_cells:
			var p: Vector3i = _actor_cells[id]
			var c := _iso(p.x + 0.5, p.y + 0.5, p.z)
			draw_circle(c, 3.0, Color(1, 1, 1))
			draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color(1, 1, 1), 1.0)
			draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color(1, 1, 1), 1.0)


func _unhandled_input(event: InputEvent) -> void:
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


func _is_my_turn() -> bool:
	if _current_fid < 0 or _dead.get(_current_fid, false):
		return false
	var f: Dictionary = State.fighters.get(_current_fid, {})
	return int(f.get("coach", -1)) == State.my_coach_id
