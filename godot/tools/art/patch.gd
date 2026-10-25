extends SceneTree

## M7: a small patch of arena at the game's real scale (1x, 86-px cells),
## built from kiln GLBs drawn live in 3D: one tile model on every cell and a
## prop on a few. For judging assets at map size, not zoomed in.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot -s tools/art/patch.gd -- \
##       --tile=art/arena5/out/models/ice_block.glb --prop=art/arena5/out/models/tree.glb \
##       --out=<png> [--n=6] [--size=700x460]

const PX := 43.0 * 1.41421356
const TILE_TOP := 0.86   # walk surface of the block model
## cells that get the prop
const PROP_CELLS := [Vector2i(1, 2), Vector2i(4, 1), Vector2i(3, 4)]

var opts := {"tile": "", "prop": "", "out": "/tmp/patch.png", "n": "6", "size": "700x460"}


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
	var tile := _load(opts.tile)
	var prop := _load(opts.prop) if opts.prop != "" else null
	var n := int(opts.n)
	var world := Node3D.new()
	root.add_child(world)
	for y in n:
		for x in n:
			var t: Node3D = tile.duplicate()
			t.position = Vector3(x + 0.5, -TILE_TOP, y + 0.5)
			world.add_child(t)
			if prop and Vector2i(x, y) in PROP_CELLS:
				var p: Node3D = prop.duplicate()
				p.position = Vector3(x + 0.5, -0.02, y + 0.5)
				p.rotation.y = hash(Vector2i(x, y)) % 360 * PI / 180.0
				world.add_child(p)
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
	sun.rotation_degrees = Vector3(-58, 20, 0)
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = root.size.y / PX
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = Vector3(n / 2.0, 0.1, n / 2.0) + cam.transform.basis.z * 30.0
	world.add_child(cam)
	cam.make_current()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(opts.out)
	print("[patch] %s" % opts.out)
	quit(0)


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	doc.append_from_file(ProjectSettings.globalize_path("res://" + path), st)
	var node := doc.generate_scene(st)
	for mi in node.find_children("*", "MeshInstance3D", true, false) + ([node] if node is MeshInstance3D else []):
		_dress(mi)
	return node


## Same treatment as build_tile.gd: smooth snow, rim on ice, no specular.
func _dress(mi: MeshInstance3D) -> void:
	var src: Mesh = mi.mesh
	var mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s) as BaseMaterial3D
		var mname := mat.resource_name if mat else ""
		if mname.begins_with("snow"):
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var acc := {}
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				var k := Vector3i((verts[i] * 2000.0).round())
				acc[k] = acc.get(k, Vector3.ZERO) + normals[i]
			for i in verts.size():
				normals[i] = (acc[Vector3i((verts[i] * 2000.0).round())] as Vector3).normalized()
			arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if mat:
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			if mname.begins_with("ice"):
				mat.rim_enabled = true
				mat.rim = 0.6
				mat.rim_tint = 0.2
			mesh.surface_set_material(s, mat)
	mi.mesh = mesh
