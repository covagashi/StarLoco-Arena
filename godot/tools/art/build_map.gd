extends SceneTree

## M7 step 2: assemble an arena from our own tile blocks (kiln pack built
## from godot/art/<arena>/) on the arena's real topology, and photograph it
## with the game's projection: orthographic, 2:1, cells 86×43, 10 px per
## altitude unit — so it can sit 1:1 under fight_view later.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##       -s tools/art/build_map.gd -- --map=5 --pack=art/arena5/out/arena5_tiles.glb \
##       --out=<png> [--size=1280x720] [--zoom=1]

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")

const PX := 43.0 * 1.41421356          # screen px per world unit across
const ALT := 10.0 / (PX * 0.8660254)   # world units per altitude step (10 px)
const FLOOR_DEPTH := 1.2               # how far the slab runs under the lowest cell
## Top surface of each block in its own model space (kiln dimensions).
const TOP := {"t_snow": 0.82, "t_lilac": 0.82, "t_ice": 0.83, "t_stone": 0.58,
	"t_gold": 0.8}

## Props read small next to 86-px cells at kiln's 1 m = 1 cell; the retail
## spikes and trees stand about two cells tall.
const PROP_SCALE := {"p_spike": 1.5, "p_tree": 1.45, "p_crystal": 1.35, "p_lantern": 1.1}

var opts := {"map": "5", "pack": "art/arena5/out/arena5_tiles.glb",
	"props": "art/arena5/out/arena5_props.glb", "out": "/tmp/arena.png", "size": "1280x720", "zoom": "0.85"}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	var sz: PackedStringArray = String(opts.size).split("x")
	DisplayServer.window_set_size(Vector2i(int(sz[0]), int(sz[1])))
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	_run.call_deferred()


func _run() -> void:
	var map_id := int(opts.map)
	var topo := Topology.load_world(map_id, Topology.SCOPE_ARENA)
	var fmd := FightMap.load(map_id)
	var cells: Dictionary = topo.get("cells", {})
	if cells.is_empty():
		push_error("map %d has no arena topology" % map_id)
		quit(1)
		return
	var kit := _load_pack(ProjectSettings.globalize_path("res://" + opts.pack),
		["t_snow", "t_lilac", "t_ice", "t_stone", "t_gold", "t_col"])
	var props := _load_pack(ProjectSettings.globalize_path("res://" + opts.props),
		["p_spike", "p_tree", "p_crystal", "p_lantern", "p_pebbles"])
	if kit.is_empty() or props.is_empty():
		quit(1)
		return
	var spawn := {}
	for t in ["team0", "team1"]:
		for c in fmd.get(t, []):
			spawn[Vector2i(c.x, c.y)] = true
	var coach := {}
	for c in fmd.get("coach", []):
		coach[Vector2i(c.x, c.y)] = true
	var alt_min := 1 << 30
	for p in cells:
		if cells[p].ground:
			alt_min = mini(alt_min, cells[p].alt)
	var floor_y := alt_min * ALT - FLOOR_DEPTH

	var world := Node3D.new()
	root.add_child(world)
	var noise := FastNoiseLite.new()
	noise.seed = map_id * 31
	noise.frequency = 0.12
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var n := 0
	var counts := {}
	for p: Vector2i in cells:
		var c: Dictionary = cells[p]
		if c.alt == Topology.VOID_ALT:
			continue
		# no floor but an altitude: an obstacle, or a coach pedestal
		var kind := _pick(p, c.alt, alt_min, coach, noise) if c.ground else (
			"t_gold" if coach.has(p) else "t_ice")
		counts[kind] = counts.get(kind, 0) + 1
		# an obstacle's altitude is the height of the prop standing on it
		# (spike, tree, crystal: a later step); its block sits at floor level
		var alt: int = c.alt if c.ground or coach.has(p) else _floor_near(cells, p, c.alt)
		var top: float = alt * ALT
		var blk: Node3D = kit[kind].duplicate()
		blk.position = Vector3(p.x + 0.5, top - TOP[kind], p.y + 0.5)
		world.add_child(blk)
		# ice column from under the block down to the slab floor
		var y: float = top - TOP[kind]
		while y > floor_y + 0.001:
			var h := minf(1.0, y - floor_y)
			var col: Node3D = kit.t_col.duplicate()
			col.position = Vector3(p.x + 0.5, y - h, p.y + 0.5)
			col.scale = Vector3(1, h, 1)
			world.add_child(col)
			y -= h
		var prop := _prop_for(p, c, alt, coach, spawn)
		if prop != "":
			var pr: Node3D = props[prop].duplicate()
			var hsh := hash(p * 7349)
			pr.position = Vector3(p.x + 0.5, top, p.y + 0.5)
			pr.rotation.y = (hsh % 360) * PI / 180.0
			pr.scale = Vector3.ONE * PROP_SCALE.get(prop, 1.0) * (0.9 + (hsh % 30) / 100.0)
			world.add_child(pr)
			counts[prop] = counts.get(prop, 0) + 1
		lo = lo.min(Vector3(p.x, floor_y, p.y))
		hi = hi.max(Vector3(p.x + 1, top, p.y + 1))
		n += 1
	var center := (lo + hi) * 0.5
	print("[map] %d cells, alt_min %d, tiles %s" % [n, alt_min, counts])

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("4d4d4d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe8ff")
	e.ambient_light_energy = 0.32
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 20, 0)   # from the upper left of the screen
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	world.add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = root.size.y / (PX * float(opts.zoom))
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = center + cam.transform.basis.z * 60.0
	cam.far = 200.0
	world.add_child(cam)
	cam.make_current()

	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(opts.out)
	print("[map] %s" % opts.out)
	quit(0)


## Decoration for a cell: obstacles get a prop picked by how tall the
## topology says it is (that height is the retail prop's); a few plain
## floor cells get walk-over pebbles. Spawns and pedestals stay clear.
func _prop_for(p: Vector2i, c: Dictionary, floor_alt: int, coach: Dictionary,
		spawn: Dictionary) -> String:
	if coach.has(p) or spawn.has(p):
		return ""
	if c.ground:
		return "p_pebbles" if hash(p * 3571) % 100 < 7 else ""
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if coach.has(p + Vector2i(dx, dy)):
				return "p_lantern"
	var d: int = c.alt - floor_alt
	if d >= 9:
		return "p_spike"
	if d >= 5:
		return "p_tree"
	return "p_crystal"


## Altitude of the lowest walkable neighbour (the floor an obstacle stands on).
func _floor_near(cells: Dictionary, p: Vector2i, fallback: int) -> int:
	var best := fallback
	var found := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Dictionary = cells.get(p + d, {})
		if nb.get("ground", false) and (not found or nb.alt < best):
			best = nb.alt
			found = true
	return best


## Which of our tiles a cell gets. Our own rule, not the retail layout:
## coach pedestals are gold, the lowest floor is frozen ice, one big patch
## of lilac snow and a few dark stone slabs break up the white.
func _pick(p: Vector2i, alt: int, alt_min: int, coach: Dictionary,
		noise: FastNoiseLite) -> String:
	if coach.has(p):
		return "t_gold"
	if alt <= alt_min:
		return "t_ice"
	var v := noise.get_noise_2d(p.x, p.y)
	if v > 0.25:
		return "t_lilac"
	if v < -0.42:
		return "t_stone"
	return "t_snow"


func _load_pack(path: String, need: Array) -> Dictionary:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	var err := doc.append_from_file(path, st)
	if err != OK:
		push_error("can't read %s (%s)" % [path, error_string(err)])
		return {}
	var scene := doc.generate_scene(st)
	var kit := {}
	for c in scene.get_children():
		kit[String(c.name)] = c
		# kiln's lights arrive with glTF's huge range: keep them a local glow
		for l in c.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).omni_range = 1.6
			(l as OmniLight3D).light_energy = 0.8
		# painted look: no specular glints; --unshaded shows the bare albedo
		for mi in c.find_children("*", "MeshInstance3D", true, false) + ([c] if c is MeshInstance3D else []):
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i) as BaseMaterial3D
				m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				if opts.has("unshaded"):
					m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in need:
		if not kit.has(k):
			push_error("pack has no %s (has %s)" % [k, kit.keys()])
			return {}
	return kit
