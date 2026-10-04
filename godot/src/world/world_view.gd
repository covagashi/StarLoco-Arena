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
## Orthogonal grid step -> coach anm wire direction (mapped onto the
## packed {0,1,2,5,6} export + horizontal mirror via DIR_MAP/DIR_FLIP).
const STEP_DIR := {
	Vector2i(1, 0): 1, Vector2i(0, 1): 3,
	Vector2i(-1, 0): 5, Vector2i(0, -1): 7}
## Coach paper-doll sets carry the packed 5-dir complement {0,1,2,5,6} —
## 3/4/7 mirror 1/0/5 (same DIR_MAP/DIR_FLIP as fight_view).
const DIR_MAP := {0: 0, 1: 1, 2: 2, 3: 1, 4: 0, 5: 5, 6: 6, 7: 5}
const DIR_FLIP := {0: false, 1: false, 2: false, 3: true,
	4: true, 5: false, 6: false, 7: true}
const COACH_SET := "res://assets/anims/coach_7000"
const Palettes := preload("res://src/gamedata/palettes.gd")

var _cells := {}
var _sorted := []
var _alt_min := 0
var _alt_max := 0
var _loaded := false
var _sprites := {}      # coach id -> AnmSprite
var _names := {}        # coach id -> String
var _looks := {}        # coach id -> {skin, hair, sex}
var _pos := {}          # coach id -> Vector3i
var _walk := {}         # coach id -> {steps, seg, t}
var _hover: Vector2i = Vector2i(-9999, -9999)
var _gfx: Node2D
var _gfx_active := false
var _elems := {}          # instanceId -> {pos: Vector3i, kind, desc}

## Kind colors for the map markers (env type ids — elements.gd KIND_NAMES).
## Type 8 (zone trigger) is invisible in retail: fires on walk-on, not click.
const ELEM_COLORS := {
	1: Color(1.0, 0.8, 0.2),    # Card Master — gold
	2: Color(0.7, 0.7, 0.75),   # Mailbox
	3: Color(1.0, 0.45, 0.3),   # Challenge bubble
	4: Color(0.35, 0.7, 1.0),   # Zaap
	5: Color(0.6, 1.0, 0.4),    # Breed Master
	6: Color(0.8, 0.4, 1.0),    # Demon
	7: Color(1.0, 0.3, 0.5),    # Demon challenge
	9: Color(0.8, 0.4, 1.0),    # Demon
	10: Color(0.9, 0.9, 0.9),   # Graveyard
	11: Color(1.0, 0.4, 0.8),   # Demon totem
	12: Color(1.0, 0.65, 0.2),  # Firework dispenser
	13: Color(0.95, 0.55, 0.95),# Tournament totem
	14: Color(0.4, 0.9, 0.85),  # Fusion altar
	15: Color(0.5, 0.9, 0.5),   # NPC
}

@onready var _cam: Camera2D = $Camera

## Emitted each time the LOCAL coach crosses into a new cell mid-walk (and
## once for its spawn cell on world entry). main.gd polls zone triggers off it.
signal cell_entered(cell: Vector2i)


func _ready() -> void:
	_gfx = MapGfx.new()
	_gfx.name = "MapGfx"
	_gfx.show_behind_parent = true
	add_child(_gfx)
	move_child(_gfx, 0)   # painted island under the topology+coaches


func show_world(world_id: int, my_pos: Vector3) -> void:
	_gfx_active = _gfx.load_world(world_id)
	_elems = {}
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
	_spawn_coach(State.my_coach_id, State.my_coach_name,
		int(my_pos.x), int(my_pos.y), int(my_pos.z))
	_cam.make_current()
	_cam.zoom = Vector2(0.85, 0.85)
	_cam.position = _sprites[State.my_coach_id].position
	visible = true
	var sp: Vector3i = _pos[State.my_coach_id]
	cell_entered.emit(Vector2i(sp.x, sp.y))   # spawn cell counts as entry
	queue_redraw()


func hide_world() -> void:
	visible = false
	_loaded = false
	_gfx_active = false
	_gfx.clear()
	_cells = {}
	_sorted = []
	_walk = {}
	_elems = {}
	for id in _sprites:
		_sprites[id].queue_free()
	_sprites = {}
	_names = {}
	_looks = {}
	_pos = {}


func _coach_look(id: int) -> Dictionary:
	if id == State.my_coach_id:
		return State.my_coach_look
	return _looks.get(id, {})


func _coach_set(id: int) -> String:
	return "res://assets/anims/coach_700%d" % int(
		_coach_look(id).get("sex", 0))


func _coach_tints(id: int) -> Dictionary:
	var l := _coach_look(id)
	if l.is_empty():
		return {}
	return Palettes.coach_tints(int(l.get("skin", 0)), int(l.get("hair", 0)))


func _set_flip(spr: AnmSprite, flip: bool) -> void:
	spr.scale.x = -absf(spr.scale.x) if flip else absf(spr.scale.x)
	for c in spr.get_children():
		if c is Label:
			c.scale.x = -1.0 if flip else 1.0


func _spawn_coach(id: int, cname: String, x: int, y: int, z: int,
		look := {}) -> void:
	var spr: AnmSprite = _sprites.get(id)
	if spr == null:
		spr = AnmSprite.new()
		spr.foot_pivot = true
		_sprites[id] = spr
		add_child(spr)
	if not look.is_empty():
		_looks[id] = look
	spr.tints = _coach_tints(id)
	var wdir: int = int(_coach_look(id).get("dir", 2))
	_set_flip(spr, DIR_FLIP.get(wdir, false))
	spr.load_action(_coach_set(id),
		"%d_AnimStatique" % DIR_MAP.get(wdir, 2))
	spr.position = _iso(x + 0.5, y + 0.5, z)
	spr.z_index = clampi((x + y) * 4 + 1, -4096, 4096)
	_pos[id] = Vector3i(x, y, z)
	if _gfx_active:
		spr.external_draw = true
		_gfx.register_dynamic(id,
			func(): return MapGfx.actor_key_cell(
				_pos.get(id, Vector3i.ZERO)),
			func(ci): _draw_actor(ci, id))
	_names[id] = cname
	var tag := spr.get_node_or_null("Tag")
	if tag == null:
		tag = Label.new()
		tag.name = "Tag"
		tag.add_theme_font_size_override("font_size", 13)
		tag.add_theme_color_override("font_color", Color(1, 1, 1))
		tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		tag.add_theme_constant_override("shadow_offset_x", 1)
		tag.add_theme_constant_override("shadow_offset_y", 1)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.size = Vector2(140, 18)
		spr.add_child(tag)
	tag.text = cname
	tag.position = Vector2(-70, -95)


## Merged-painter draw for one live coach: ground ring (gold for the local
## coach, pale for others) squashed to iso proportions, then the frame.
func _draw_actor(ci: CanvasItem, id: int) -> void:
	var spr: AnmSprite = _sprites.get(id)
	if spr == null:
		return
	if OS.has_environment("DRAW_ACTOR_DEBUG"):
		print("[actor] id=%d pos=%s scale=%s frames=%d" % [
			id, spr.position, spr.scale, spr._frames.size()])
	var ring := Color(1.0, 0.82, 0.25, 0.55) if id == State.my_coach_id \
		else Color(1.0, 1.0, 1.0, 0.35)
	ci.draw_set_transform(spr.position, 0.0, Vector2(1.0, 0.45))
	ci.draw_circle(Vector2.ZERO, 14.0, ring)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	spr.draw_on(ci, spr.position)


func actor_spawned(id: int, cname: String, x: int, y: int, z: int,
		look := {}) -> void:
	_spawn_coach(id, cname, x, y, z, look)


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


## Hit-test for the challenge flow: coach id whose sprite overlaps pos,
## -1 for none. Sprites are foot-pivoted so test a box around the body.
func actor_at(pos: Vector2) -> int:
	var best := -1
	var best_d := 55.0
	for id in _sprites:
		if id == State.my_coach_id:
			continue
		var spr: AnmSprite = _sprites[id]
		var d: float = (pos - (spr.position + Vector2(0, -30))).length()
		if d < best_d:
			best_d = d
			best = id
	return best


func actor_name(id: int) -> String:
	return _names.get(id, "coach %d" % id)


## Coach id by display name (case-insensitive) — for /trade <name>.
func coach_id_by_name(cname: String) -> int:
	for id in _names:
		if String(_names[id]).to_lower() == cname.to_lower():
			return int(id)
	return -1


## EmotePlayed (4700): the coach anm set has no AnimEmote-* actions, so show
## the emote name as an italic bubble over the actor instead.
func emote(id: int, anim: String) -> void:
	var what := anim.trim_prefix("AnimEmote-").trim_suffix("-Debut").to_lower()
	chat_bubble(id, "* %s *" % what)


## Interactive elements (opcode 200 spawn / 206 despawn). kind comes from the
## exported env table — the wire payload only carries position/descriptor.
func element_spawned(e: Dictionary) -> void:
	var x := int(e.get("x", 0))
	var y := int(e.get("y", 0))
	# ground altitude from topology beats the wire z only when present
	var z := int(e.get("z", 0))
	var c: Dictionary = _cells.get(Vector2i(x, y), {})
	if c.get("ground", false):
		z = int(c.alt)
	_elems[int(e.id)] = {"pos": Vector3i(x, y, z),
		"kind": int(e.get("kind", -1)), "desc": str(e.get("desc", "")),
		"cells": e.get("cells", [])}
	queue_redraw()


## Zone triggers (kind 8, client `oq`): element ids whose cell list contains
## `cell`. They fire on walk-on (action `avr_0.dgp`) — the client polls this
## whenever the local coach crosses into a new cell.
func zone_triggers_at(cell: Vector2i) -> Array:
	var out := []
	for id in _elems:
		var e: Dictionary = _elems[id]
		if e.kind != 8:
			continue
		if Vector2i(e.pos.x, e.pos.y) == cell or e.cells.has(cell):
			out.append(id)
	return out


func element_despawned(ids: Array) -> void:
	for id in ids:
		_elems.erase(int(id))
	queue_redraw()


## Hit-test for element clicks: instance id whose marker is near pos, -1 none.
func element_at(pos: Vector2) -> int:
	var best := -1
	var best_d := 26.0
	for id in _elems:
		if _elems[id].kind == 8:
			continue   # zone triggers are not clickable
		var p: Vector3i = _elems[id].pos
		var c := _iso(p.x + 0.5, p.y + 0.5, p.z)
		var d: float = (pos - (c + Vector2(0, -HH - 14))).length()
		if d < best_d:
			best_d = d
			best = id
	return best


func element_info(id: int) -> Dictionary:
	return _elems.get(id, {})


## The local coach's current cell (last step walked or the spawn point).
func my_cell() -> Vector2i:
	var p: Vector3i = _pos.get(State.my_coach_id, Vector3i.ZERO)
	return Vector2i(p.x, p.y)


## ActorTeleports (4510): snap an actor to a cell — no walk animation, and
## the local coach's camera recentres on the landing cell.
func actor_teleported(id: int, x: int, y: int, z: int) -> void:
	var cell := Vector3i(x, y, z)
	_pos[id] = cell
	var spr: AnmSprite = _sprites.get(id)
	if spr != null:
		spr.position = _iso(x + 0.5, y + 0.5, z)
		spr.z_index = clampi((x + y) * 4 + 1, -4096, 4096)
	_walk.erase(id)
	if id == State.my_coach_id:
		_cam.position = _iso(x + 0.5, y + 0.5, z)
		cell_entered.emit(Vector2i(x, y))


func actor_despawned(id: int) -> void:
	_gfx.unregister_dynamic(id)
	var spr: AnmSprite = _sprites.get(id)
	if spr != null:
		spr.queue_free()
		_sprites.erase(id)
		_pos.erase(id)
		_names.erase(id)
		_looks.erase(id)


func actor_moved(id: int, path: Array) -> void:
	# 4500 carries the full path (origin first) — animate over the steps.
	if _pos.has(id) and path.size() > 1:
		_walk[id] = {"steps": path, "seg": 1, "t": 0.0}
		_pos[id] = path[0]   # _process advances the cell per segment
		_face_step(id, path[0], path[1])


## Switch the coach sprite into the march cycle facing the step direction.
## Wire dirs map onto the packed 5-dir export; 3/4/7 mirror via scale.x.
func _face_step(id: int, a: Vector3i, b: Vector3i) -> void:
	var spr: AnmSprite = _sprites.get(id)
	if spr == null:
		return
	var dir: int = STEP_DIR.get(Vector2i(b.x - a.x, b.y - a.y), -1)
	if dir < 0:
		return
	var asset_dir: int = DIR_MAP.get(dir, 1)
	_set_flip(spr, DIR_FLIP.get(dir, false))
	# current is "<set>/<action>@t<tints>" — match action before the @
	if not str(spr.current).get_slice("@", 0).ends_with(
			"%d_AnimMarche" % asset_dir):
		spr.load_action(_coach_set(id), "%d_AnimMarche" % asset_dir)


func click_to(cell: Vector2i) -> void:
	if not _loaded or not _pos.has(State.my_coach_id):
		return
	var path := _find_path(_pos[State.my_coach_id], cell)
	if path.size() < 2:
		return
	_walk[State.my_coach_id] = {"steps": path, "seg": 1, "t": 0.0}
	_pos[State.my_coach_id] = path[path.size() - 1]
	_face_step(State.my_coach_id, path[0], path[1])
	var w := WireWriter.new()
	for s in path:
		w.put_i32(s.x)
		w.put_i32(s.y)
		w.put_i16(s.z)
	State.net.send_message(OP_COACH_MOVE, w.raw(), 0)


## Per-cell floor altitudes: layered cells can stack a bridge over ground —
## `layers` holds every floored z; plain cells expose just `alt`.
func _layers_of(cd: Dictionary) -> Array:
	var l = cd.get("layers")
	if l is Array and l.size() > 0:
		return l
	return [cd.alt] if cd.get("ground", false) else []


## Max altitude change per step — ramps climb in +2/+3 increments; real
## floor jumps are ≥8. Retail penalizes big dz but the wall-blocking itself
## comes from having no reachable layer.
const MAX_STEP := 5


## BFS over (cell, z) states — retail seeds its A* on cell+altitude and a
## step is legal only onto a floor layer reachable from the current z,
## picking the layer closest to it (walk UNDER arches, ONTO bridges).
func _find_path(from: Vector3i, to: Vector2i) -> Array:
	var target = _cells.get(to)
	if target == null or not target.ground:
		return []
	const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var start := Vector3i(from.x, from.y, from.z)
	var frontier := [start]
	var came := {start: start}
	var goal := Vector3i(-99999, -99999, 0)
	var head := 0
	while head < frontier.size():
		var c: Vector3i = frontier[head]
		head += 1
		var cp := Vector2i(c.x, c.y)
		if cp == to:
			goal = c
			break
		for d in DIRS:
			var np: Vector2i = cp + d
			var nc = _cells.get(np)
			if nc == null or not nc.ground:
				continue
			var best := -1
			var bd := 1 << 30
			for l in _layers_of(nc):
				var dd := absi(int(l) - c.z)
				if dd <= MAX_STEP and dd < bd:
					bd = dd
					best = int(l)
			if best == -1:
				continue
			var nk := Vector3i(np.x, np.y, best)
			if came.has(nk):
				continue
			came[nk] = c
			frontier.append(nk)
	if not came.has(goal):
		return []
	var path := []
	var cur := goal
	while cur != start:
		path.push_front(cur)
		cur = came[cur]
	path.push_front(start)
	return path


func _iso(x: float, y: float, z: int) -> Vector2:
	return Vector2((x - y) * HW, (x + y) * HH - z * EL)


func screen_to_cell(pos: Vector2) -> Variant:
	# A click can only land inside diamonds whose center column d = x-y sits
	# within |rel.x| <= HW — three integer diagonals. Altitudes just shift
	# the diamond up by z*EL, so enumerate the diagonals over the s = x+y
	# band spanning every possible layer height and diamond-test each cell
	# at each of its floor layers. Overlapping diamonds resolve to the one
	# painted last (painter z-key = what the cursor actually points at).
	var d0 := int(floor(pos.x / HW))
	var smin := int(floor((pos.y + _alt_min * EL - HH - 4.0) / HH)) - 1
	var smax := int(ceil((pos.y + _alt_max * EL + HH + 4.0) / HH)) + 1
	var best: Variant = null
	var best_key := -1
	for d in range(d0 - 1, d0 + 2):
		for s in range(smin, smax + 1):
			if (d + s) & 1:
				continue
			var cx := (d + s) / 2
			var cy := (s - d) / 2
			var cd = _cells.get(Vector2i(cx, cy))
			if cd == null or not cd.ground:
				continue
			for l in _layers_of(cd):
				var rel := pos - _iso(cx + 0.5, cy + 0.5, int(l))
				if absf(rel.x) / HW + absf(rel.y) / HH <= 1.0:
					var key := ((cy + 131071) << 32) | ((cx + 131071) << 14)
					if key > best_key:
						best_key = key
						best = Vector2i(cx, cy)
					break
	return best


func zoom_by(f: float) -> void:
	if _cam == null:
		return
	var z: float = clampf(_cam.zoom.x * f, 0.45, 1.6)
	_cam.zoom = Vector2(z, z)


func set_hover(pos: Vector2) -> void:
	var cell: Variant = screen_to_cell(pos)
	var h: Vector2i = cell if cell != null else Vector2i(-9999, -9999)
	if h != _hover:
		_hover = h
		queue_redraw()


func _process(delta: float) -> void:
	if not _loaded:
		return
	if not _elems.is_empty():
		queue_redraw()   # marker bob animation
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
			# facing follows the step direction — retail walks the coach in
			# AnimMarche, back to AnimStatique when the path runs out
			if w.seg < steps.size():
				_face_step(id, steps[w.seg - 1], steps[w.seg])
			if id == State.my_coach_id:
				var st: Vector3i = steps[w.seg - 1]
				cell_entered.emit(Vector2i(st.x, st.y))
		if w.seg >= steps.size():
			spr.position = _iso(steps[-1].x + 0.5, steps[-1].y + 0.5, steps[-1].z)
			spr.z_index = clampi((steps[-1].x + steps[-1].y) * 4 + 1, -4096, 4096)
			var last_dir := -1
			if steps.size() >= 2:
				var dl := Vector2i(steps[-1].x - steps[-2].x,
					steps[-1].y - steps[-2].y)
				last_dir = STEP_DIR.get(dl, -1)
			var adir: int = DIR_MAP.get(last_dir, 2)
			_set_flip(spr, DIR_FLIP.get(last_dir, false))
			spr.load_action(_coach_set(id), "%d_AnimStatique" % adir)
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
	for id in _elems:
		var e: Dictionary = _elems[id]
		if e.kind == 8:
			continue   # zone trigger — invisible in retail, fires on walk-on
		var col: Color = ELEM_COLORS.get(e.kind, Color(1, 1, 1))
		var p: Vector3i = e.pos
		var c := _iso(p.x + 0.5, p.y + 0.5, p.z)
		# floating marker: small diamond + dot, pulsing gently
		var bob := sin(Time.get_ticks_msec() / 400.0 + float(id % 97)) * 3.0
		var m := c + Vector2(0, -HH - 14 + bob)
		draw_colored_polygon(PackedVector2Array([
			m + Vector2(0, -7), m + Vector2(6, 0), m + Vector2(0, 7),
			m + Vector2(-6, 0)]), col)
		draw_circle(m, 2.5, Color(0.1, 0.1, 0.1))
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
