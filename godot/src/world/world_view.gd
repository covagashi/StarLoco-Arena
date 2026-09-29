extends Node2D

## Overworld island view: volumetric topology + coach avatars + click-to-move.
##
## The island is the same chunked .tplg format as arenas (world scope accepts
## the filler chunk types). Coaches come from ACTOR_SPAWN (4096); the local
## coach walks client-authoritatively — we animate immediately and send
## COACH_MOVEMENT (4501, full path including origin) so the server updates AoI
## and rebroadcasts ACTOR_MOVEMENT (4500) to the other clients.

const Topology := preload("res://src/maps/topology.gd")
const MapGfx := preload("res://src/maps/map_gfx.gd")
const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const State := preload("res://src/state.gd")

const OP_COACH_MOVE := 4501

const HW := 43.0
const HH := 21.5
const EL := 10.0
const WALK_SPEED := 3.0
const DIR_MAP := {1: 2, 3: 1, 5: 0, 7: 5}
const DIR_FLIP := {1: false, 3: false, 5: false, 7: true}
const COACH_SET := "res://assets/anims/coach_805"

var _cells := {}
var _sorted := []
var _alt_min := 0
var _alt_max := 0
var _loaded := false
var _sprites := {}      # coach id -> AnmSprite
var _names := {}        # coach id -> String
var _pos := {}          # coach id -> Vector3i
var _walk := {}         # coach id -> {steps, seg, t}
var _hover: Vector2i = Vector2i(-9999, -9999)
var _gfx: Node2D
var _gfx_active := false

@onready var _cam: Camera2D = $Camera


func _ready() -> void:
	_gfx = MapGfx.new()
	_gfx.name = "MapGfx"
	_gfx.show_behind_parent = true
	add_child(_gfx)
	move_child(_gfx, 0)   # painted island under the topology+coaches


func show_world(world_id: int, my_pos: Vector3) -> void:
	_gfx_active = _gfx.load_world(world_id)
	var topo := Topology.load_world(world_id, Topology.SCOPE_WORLD)
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
	_loaded = not _cells.is_empty()
	_spawn_coach(State.my_coach_id, "you", int(my_pos.x), int(my_pos.y), int(my_pos.z))
	_cam.make_current()
	_cam.zoom = Vector2(0.7, 0.7)
	_cam.position = _sprites[State.my_coach_id].position
	visible = true
	queue_redraw()


func hide_world() -> void:
	visible = false
	_loaded = false
	_gfx_active = false
	_gfx.clear()
	_cells = {}
	_sorted = []
	_walk = {}
	for id in _sprites:
		_sprites[id].queue_free()
	_sprites = {}
	_names = {}
	_pos = {}


func _spawn_coach(id: int, cname: String, x: int, y: int, z: int) -> void:
	var spr: AnmSprite = _sprites.get(id)
	if spr == null:
		spr = AnmSprite.new()
		spr.foot_pivot = true
		_sprites[id] = spr
		add_child(spr)
	spr.load_action(COACH_SET, "2_AnimStatique")
	spr.position = _iso(x + 0.5, y + 0.5, z)
	spr.z_index = clampi((x + y) * 4 + 1, -4096, 4096)
	_pos[id] = Vector3i(x, y, z)
	if _gfx_active:
		spr.external_draw = true
		_gfx.register_dynamic(id,
			func(): return MapGfx.actor_key_cell(
				_pos.get(id, Vector3i.ZERO)),
			func(ci): spr.draw_on(ci, spr.position))
	_names[id] = cname
	var tag := spr.get_node_or_null("Tag")
	if tag == null:
		tag = Label.new()
		tag.name = "Tag"
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(1, 1, 1))
		tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		tag.add_theme_constant_override("shadow_offset_x", 1)
		tag.add_theme_constant_override("shadow_offset_y", 1)
		spr.add_child(tag)
	tag.text = cname
	tag.position = Vector2(-tag.size.x / 2.0, -70)


func actor_spawned(id: int, cname: String, x: int, y: int, z: int) -> void:
	_spawn_coach(id, cname, x, y, z)


## Vicinity chat bubble over a coach's head, fading after a few seconds —
## retail shows the line both in the chat panel and as a bubble in-world.
func chat_bubble(id: int, text: String) -> void:
	var spr: AnmSprite = _sprites.get(id)
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
	b.position = Vector2(-b.size.x / 2.0, -92)
	spr.add_child(b)
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(b, "modulate:a", 0.0, 1.2)
	tw.tween_callback(b.queue_free)


func actor_despawned(id: int) -> void:
	_gfx.unregister_dynamic(id)
	var spr: AnmSprite = _sprites.get(id)
	if spr != null:
		spr.queue_free()
		_sprites.erase(id)
		_pos.erase(id)
		_names.erase(id)


func actor_moved(id: int, path: Array) -> void:
	# 4500 carries the full path (origin first) — animate over the steps.
	if _pos.has(id) and path.size() > 1:
		_walk[id] = {"steps": path, "seg": 1, "t": 0.0}
		_pos[id] = path[0]   # _process advances the cell per segment


func click_to(cell: Vector2i) -> void:
	if not _loaded or not _pos.has(State.my_coach_id):
		return
	var path := _find_path(Vector2i(_pos[State.my_coach_id].x, _pos[State.my_coach_id].y), cell)
	if path.size() < 2:
		return
	var steps := []
	for p in path:
		var c: Dictionary = _cells.get(p, {})
		steps.append(Vector3i(p.x, p.y, int(c.get("alt", 0))))
	_walk[State.my_coach_id] = {"steps": steps, "seg": 1, "t": 0.0}
	_pos[State.my_coach_id] = steps[steps.size() - 1]
	var w := WireWriter.new()
	for s in steps:
		w.put_i32(s.x)
		w.put_i32(s.y)
		w.put_i16(s.z)
	State.net.send_message(OP_COACH_MOVE, w.raw(), 0)


func _find_path(from: Vector2i, to: Vector2i) -> Array:
	if not _cells.get(to, {}).get("ground", false):
		return []
	var frontier := [from]
	var came := {from: from}
	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var head := 0
	while head < frontier.size():
		var c: Vector2i = frontier[head]
		head += 1
		if c == to:
			break
		for d in DIRS:
			var n: Vector2i = c + d
			if came.has(n):
				continue
			var nc = _cells.get(n)
			if nc == null or not nc.ground:
				continue
			came[n] = c
			frontier.append(n)
	if not came.has(to):
		return []
	var path := [to]
	var cur := to
	while cur != from:
		cur = came[cur]
		path.push_front(cur)
	return path


func _iso(x: float, y: float, z: int) -> Vector2:
	return Vector2((x - y) * HW, (x + y) * HH - z * EL)


func screen_to_cell(pos: Vector2) -> Variant:
	# inverse projection: screen_x/(HW) = x-y ; screen_y/HH ≈ x+y+z' — z unknown,
	# so unproject at each candidate altitude in range and keep the cell whose
	# diamond contains the point.
	var x := pos.x / (2.0 * HW) + pos.y / (2.0 * HH)
	var y := pos.y / (2.0 * HH) - pos.x / (2.0 * HW)
	for dy in range(2):
		for dx in range(2):
			var c := Vector2i(int(floor(x)) + dx, int(floor(y)) + dy)
			var cd = _cells.get(c)
			if cd == null or not cd.ground:
				continue
			var rel := pos - _iso(c.x + 0.5, c.y + 0.5, cd.alt)
			if absf(rel.x) / HW + absf(rel.y) / HH <= 1.0:
				return c
	return null


func set_hover(pos: Vector2) -> void:
	var cell: Variant = screen_to_cell(pos)
	var h: Vector2i = cell if cell != null else Vector2i(-9999, -9999)
	if h != _hover:
		_hover = h
		queue_redraw()


func _process(delta: float) -> void:
	if not _loaded:
		return
	for id in _walk.keys():
		var w: Dictionary = _walk[id]
		w.t += delta * WALK_SPEED
		var spr: AnmSprite = _sprites.get(id)
		if spr == null:
			_walk.erase(id)
			continue
		var steps: Array = w.steps
		while w.seg < steps.size() and w.t >= 1.0:
			w.t -= 1.0
			w.seg += 1
			_pos[id] = steps[w.seg - 1]   # keep the zkey cell current mid-walk
		if w.seg >= steps.size():
			spr.position = _iso(steps[-1].x + 0.5, steps[-1].y + 0.5, steps[-1].z)
			spr.z_index = clampi((steps[-1].x + steps[-1].y) * 4 + 1, -4096, 4096)
			_walk.erase(id)
			continue
		var a: Vector3i = steps[w.seg - 1]
		var b: Vector3i = steps[w.seg]
		var pa := _iso(a.x + 0.5, a.y + 0.5, a.z)
		var pb := _iso(b.x + 0.5, b.y + 0.5, b.z)
		spr.position = pa.lerp(pb, w.t)
		spr.z_index = clampi((b.x + b.y) * 4 + 1, -4096, 4096)
		if id == State.my_coach_id:
			_cam.position = spr.position


func _draw() -> void:
	if not _loaded:
		return
	if not _gfx_active:
		# no painted art — fall back to the volumetric polygons
		for pos in _sorted:
			var c: Dictionary = _cells[pos]
			var poly := _cell_poly(pos.x, pos.y, c.alt)
			draw_colored_polygon(poly, _alt_color(c.alt))
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
	if _cells.has(_hover):
		var c: Dictionary = _cells[_hover]
		if c.ground:
			draw_polyline(_cell_poly(_hover.x, _hover.y, c.alt) + PackedVector2Array([
				_cell_poly(_hover.x, _hover.y, c.alt)[0]]), Color(1, 1, 1, 0.8), 1.5)


func _cell_poly(x: int, y: int, alt: int) -> PackedVector2Array:
	var c := _iso(x + 0.5, y + 0.5, alt)
	return PackedVector2Array([c + Vector2(0, -HH), c + Vector2(HW, 0),
		c + Vector2(0, HH), c + Vector2(-HW, 0)])


func _alt_color(alt: int) -> Color:
	var t := 0.5 if _alt_max == _alt_min else inverse_lerp(_alt_min, _alt_max, alt)
	return Color(0.25 + 0.45 * t, 0.45 + 0.30 * t, 0.28, 1.0)
