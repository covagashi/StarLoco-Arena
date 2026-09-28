extends Node2D

## Placeholder isometric fight-map view: topology ground cells shaded by
## altitude + .fmd spawn cells. Original art replaces this once the asset
## pipeline lands — positions/projection stay identical.
##
## Projection (maprender.go): screen = ((x-y)*43, (x+y)*21.5 - alt*10).

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")
const AnmSprite := preload("res://src/anims/anm_sprite.gd")

## Placeholder coach sprite until fight-setup wire data gives the real
## per-pedestal coach anm id.
const COACH_SET := "res://assets/anims/coach_805"

const HW := 43.0   # half cell width
const HH := 21.5   # half cell height
const EL := 10.0   # elevation unit

var _cells := {}
var _fmd := {}
var _alt_min := 0
var _alt_max := 0

@onready var cam: Camera2D = $Camera
@onready var info: Label = $UI/Info
@onready var _actors: Node2D = $Actors
var _dragging := false


func _ready() -> void:
	$UI/TopBar/LoadBtn.pressed.connect(_load)
	$UI/TopBar/BackBtn.pressed.connect(func(): get_tree().change_scene_to_file("res://src/main.tscn"))
	_load()


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
	for c in _fmd.get("coach", []):
		var spr := AnmSprite.new()
		spr.foot_pivot = true
		# coaches stand on top of the pedestal they are parked on
		spr.position = _iso(c.x + 0.5, c.y + 0.5, c.z + 1.0)
		spr.z_index = int(c.x + c.y) * 4 + 1
		_actors.add_child(spr)
		spr.load_action(COACH_SET, "5_AnimStatique")


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
