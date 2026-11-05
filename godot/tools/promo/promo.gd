extends SceneTree

## Marketing renders of our own art: an arena layout (art/layouts) built with
## arena_scene.gd, or a single kiln model, photographed as a still or as a
## numbered PNG sequence for ffmpeg. Never loads retail gfx.
##
##   xvfb-run -a -s "-screen 0 1080x1920x24" godot --path godot -s tools/promo/promo.gd -- \
##       --mode=map|build|orbit|spin --arena=10 | --model=res://art/arena10/out/models/x.glb \
##       --out=<png or dir> [--size=1080x1350] [--view=game|persp] [--yaw=45] [--pitch=32]
##       [--zoom=1] [--frames=1] [--bg=1c232c] [--focus=x,y,z] [--wire=1]   (wireframe)

const Layout := preload("res://src/maps/arena_layout.gd")
const ArenaScene := preload("res://src/maps/arena_scene.gd")

var opts := {"mode": "map", "arena": "10", "out": "/tmp/promo.png", "size": "1080x1350", "view": "persp",
	"yaw": "45", "pitch": "32", "zoom": "1", "frames": "1", "bg": "1c232c", "zoom_spin": "0.75", "sun": "0.75", "amb": "0.4"}
var builder := ArenaScene.new()
var world := Node3D.new()
var cam := Camera3D.new()
var center := Vector3.ZERO
var radius := 5.0
var cells := {}   # Vector2i -> Node3D, for the build animation


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	if opts.has("wire"):  # before any mesh loads
		RenderingServer.set_debug_generate_wireframes(true)
	var sz: PackedStringArray = String(opts.size).split("x")
	DisplayServer.window_set_size(Vector2i(int(sz[0]), int(sz[1])))
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	_run.call_deferred()


func _run() -> void:
	root.add_child(world)
	_lights()
	if opts.mode == "spin":
		_load_model(opts.model)
	else:
		_load_arena(int(opts.arena))
	if opts.has("focus"):
		var f: PackedStringArray = String(opts.focus).split(",")
		center = Vector3(float(f[0]), float(f[1]), float(f[2]))
	root.add_child(cam)
	if opts.has("wire"):
		root.debug_draw = Viewport.DEBUG_DRAW_WIREFRAME
	var n := int(opts.frames)
	var still := n <= 1
	if not still:
		DirAccess.make_dir_recursive_absolute(opts.out)
	for i in n:
		var t := float(i) / maxf(1.0, n - 1)
		_pose(t, i)
		for k in (8 if i == 0 else 1):
			await process_frame
		await RenderingServer.frame_post_draw
		var img := root.get_texture().get_image()
		img.save_png(opts.out if still else "%s/%04d.png" % [opts.out, i])
	print("[promo] %s %d frame(s) -> %s" % [opts.mode, n, opts.out])
	quit(0)


func _lights() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color.html(opts.bg)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe8ff")
	e.ambient_light_energy = float(opts.amb)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 20, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = float(opts.sun)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 60.0
	root.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-25, 200, 0)
	rim.light_color = Color("9fc0ff")
	rim.light_energy = 0.25
	root.add_child(rim)


func _load_arena(n: int) -> void:
	var shape := Layout.shape(Layout.world_of(n))
	var layout := Layout.load_layout(n)
	Layout.apply_roles(shape, layout.roles)
	Layout.apply_alts(shape, layout.alts)
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	for p: Vector2i in layout.cells:
		var items: Array = layout.cells[p]
		if items.is_empty() or not shape.cells.has(p) or shape.cells[p].role == "void":
			continue
		var c := builder.build_cell(p, shape.cells[p], items, shape.floor_y)
		world.add_child(c)
		cells[p] = c
		c.set_meta("home", c.position)
		lo = lo.min(c.position)
		hi = hi.max(c.position)
	center = (lo + hi) * 0.5
	radius = (Vector2(hi.x - lo.x, hi.z - lo.z).length()) * 0.5 + 1.0


func _load_model(path: String) -> void:
	var m := builder.model(path)
	if m == null:
		push_error("missing model " + path)
		quit(1)
		return
	world.add_child(m)
	var bb := ArenaScene.node_bounds(m)
	center = bb.get_center()
	radius = maxf(bb.size.length() * 0.5, 0.3)
	# a dark plinth to catch the shadow
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	var r := maxf(bb.size.x, bb.size.z) * 0.5 + radius * 0.35
	cyl.top_radius = r
	cyl.bottom_radius = r
	cyl.height = 0.06
	cyl.radial_segments = 48
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.html(opts.bg).lightened(0.08)
	mat.roughness = 1.0
	cyl.material = mat
	disc.mesh = cyl
	disc.position = Vector3(center.x, bb.position.y - 0.031, center.z)
	world.add_child(disc)


## Camera (and, for build, the cells) at time t in 0..1.
func _pose(t: float, _i: int) -> void:
	var yaw := float(opts.yaw)
	var pitch := float(opts.pitch)
	var zoom := float(opts.zoom)
	if opts.mode == "spin" and not opts.has("zoom_set"):
		zoom *= float(opts.zoom_spin)
	match opts.mode:
		"orbit":
			yaw += lerpf(-35.0, 35.0, ease_io(t))
		"spin":
			yaw += 360.0 * t
		"build":
			_build_step(t)
			yaw += lerpf(-20.0, 10.0, t)
	# --fitw: frame by the narrower side (portrait shots)
	var aspect := float(root.size.x) / float(root.size.y)
	var narrow := minf(1.0, aspect) if opts.has("fitw") else 1.0
	if opts.view == "game":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = radius * 1.25 / zoom / narrow
		pitch = 30.0
	else:
		cam.fov = 30.0
	var dir := Vector3(sin(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)), sin(deg_to_rad(pitch)),
		cos(deg_to_rad(yaw)) * cos(deg_to_rad(pitch)))
	var half := atan(tan(deg_to_rad(15.0)) * narrow)
	var dist := radius / tan(half) / zoom if opts.view != "game" else 80.0
	cam.far = dist + radius * 4.0 + 100.0
	cam.look_at_from_position(center + dir * dist, center)


## Cells drop in along the diagonal, back to front, over the first 70 %.
func _build_step(t: float) -> void:
	var lo := 1e9
	var hi := -1e9
	for p: Vector2i in cells:
		lo = minf(lo, p.x + p.y)
		hi = maxf(hi, p.x + p.y)
	for p: Vector2i in cells:
		var c: Node3D = cells[p]
		var start := (p.x + p.y - lo) / maxf(1.0, hi - lo) * 0.6 + (hash(p) % 100) * 0.0006
		var k := clampf((t - start) / 0.1, 0.0, 1.0)
		var home: Vector3 = c.get_meta("home")
		c.visible = k > 0.0
		c.position = home + Vector3(0, (1.0 - ease_out_back(k)) * 3.0, 0)


static func ease_io(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


static func ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3) + c1 * pow(t - 1.0, 2)
