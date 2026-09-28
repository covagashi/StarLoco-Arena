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
var _dragging := false


func _ready() -> void:
	$UI/TopBar/LoadBtn.pressed.connect(_load)
	$UI/TopBar/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/main.tscn"))
	# When we arrived here from a live fight the world id is the arena id.
	if State.fight_world >= 0:
		$UI/TopBar/MapId.text = str(State.fight_world)
	_load()
	for m in Session.drain():
		_on_net_message(m.op, WireReader.new(m.raw))
	Session.message.connect(_on_net_message)


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
const OP_END_PLACEMENT := 8028
const OP_START_OBSERVATION := 8030
const OP_START_ACTION := 8040


func _on_net_message(opcode: int, payload: WireReader) -> void:
	match opcode:
		OP_ACTOR_APPEAR:
			var d := Codec.decode(opcode, payload)
			for a in d.get("actors", []):
				_place_actor(a)
		OP_PLACEMENT:
			var d := Codec.decode(opcode, payload)
			_move_actor(int(d.id), Vector3i(int(d.x), int(d.y), int(d.z)))


## Spawn (or move) one actor from a 4102 entry {id,x,y,z,dir}.
func _place_actor(a: Dictionary) -> void:
	var spr: AnmSprite = _sprites.get(a.id)
	if spr == null:
		spr = AnmSprite.new()
		spr.foot_pivot = true
		_sprites[a.id] = spr
		_actors.add_child(spr)
	var dir: int = DIR_MAP.get(a.dir, 1)
	spr.scale.x = -abs(spr.scale.x) if DIR_FLIP.get(a.dir, false) else abs(spr.scale.x)
	if State.fighters.has(a.id):
		var f: Dictionary = State.fighters[a.id]
		var file := _fighter_file(int(f.get("breed", 1)), int(f.get("sex", 0)))
		var action := "%d_AnimStatique" % dir
		if not spr.load_action(FIGHTER_SET % file, action):
			spr.load_action(COACH_SET, "5_AnimStatique")
	else:
		spr.load_action(COACH_SET, "%d_AnimStatique" % dir)
	spr.position = _iso(a.x + 0.5, a.y + 0.5, a.z)
	spr.z_index = clampi(int(a.x + a.y) * 4 + 1, -4096, 4096)


func _move_actor(id: int, p: Vector3i) -> void:
	var spr: AnmSprite = _sprites.get(id)
	if spr == null:
		return
	spr.position = _iso(p.x + 0.5, p.y + 0.5, p.z)
	spr.z_index = clampi((p.x + p.y) * 4 + 1, -4096, 4096)


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
		draw_colored_polygon(_cell_poly(c.x, c.y, c.z), Color(1.0, 0.85, 0.2, 0.5))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			cam.zoom *= 1.15
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			cam.zoom *= 0.87
		elif event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		cam.position -= event.relative / cam.zoom
