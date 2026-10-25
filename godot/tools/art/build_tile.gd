extends SceneTree

## M7: photograph ONE tile model (a kiln GLB) the way the game will show it:
## orthographic 2:1, 86-px cells. Snow surfaces get smoothed normals (kiln
## exports flat ones) so they read painted; ice keeps its facets and gets a
## rim highlight. Writes a strip: game size (1x) next to a close-up.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##       -s tools/art/build_tile.gd -- --glb=art/arena5/out/models/ice_block_deco.glb \
##       --out=<png> [--close=4]

const PX := 43.0 * 1.41421356

var opts := {"glb": "", "out": "/tmp/tile.png", "close": "4"}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path("res://" + opts.glb), st) != OK:
		push_error("can't read " + opts.glb)
		quit(1)
		return
	var model := doc.generate_scene(st)
	for mi in model.find_children("*", "MeshInstance3D", true, false) + (
			[model] if model is MeshInstance3D else []):
		_dress(mi)
	var close := float(opts.close)
	var small := await _shoot(model.duplicate(), 1.0, Vector2i(200, 200))
	var big := await _shoot(model, close, Vector2i(roundi(200 * close), roundi(200 * close)))
	var out := Image.create(small.get_width() + big.get_width() + 30, big.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color("4d4d4d"))
	out.blit_rect(small, Rect2i(Vector2i.ZERO, small.get_size()), Vector2i(10, big.get_height() - small.get_height() - 10))
	out.blit_rect(big, Rect2i(Vector2i.ZERO, big.get_size()), Vector2i(small.get_width() + 20, 0))
	out.save_png(opts.out)
	print("[tile] %s" % opts.out)
	quit(0)


func _shoot(model: Node3D, zoom: float, size: Vector2i) -> Image:
	var vp := SubViewport.new()
	vp.size = size
	vp.msaa_3d = Viewport.MSAA_4X
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	vp.add_child(model)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("4d4d4d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe8ff")
	e.ambient_light_energy = 0.32
	env.environment = e
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 20, 0)
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = size.y / (PX * zoom)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = Vector3(0, 0.55, 0) + cam.transform.basis.z * 20.0
	vp.add_child(cam)
	cam.make_current()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


## Snow: smooth normals; ice: rim light; everything: no specular glints.
func _dress(mi: MeshInstance3D) -> void:
	var src: Mesh = mi.mesh
	var mesh := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var mat := src.surface_get_material(s) as BaseMaterial3D
		var mname := mat.resource_name if mat else ""
		if mname.begins_with("snow"):
			arrays[Mesh.ARRAY_NORMAL] = _smooth(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL],
				arrays[Mesh.ARRAY_INDEX])
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if mat:
			mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			if mname.begins_with("ice"):
				mat.rim_enabled = true
				mat.rim = 0.6
				mat.rim_tint = 0.2
			mesh.surface_set_material(s, mat)
	mi.mesh = mesh


## Average the flat normals of every vertex sharing a position.
func _smooth(verts: PackedVector3Array, normals: PackedVector3Array, idx: PackedInt32Array) -> PackedVector3Array:
	var acc := {}
	var tri_n := normals.duplicate()
	if not idx.is_empty():
		# area-weighted face normals
		for t in range(0, idx.size(), 3):
			var a := verts[idx[t]]
			var b := verts[idx[t + 1]]
			var c := verts[idx[t + 2]]
			var fn := (b - a).cross(c - a)
			if fn.dot(normals[idx[t]]) < 0.0:
				fn = -fn
			for k in 3:
				var key := Vector3i((verts[idx[t + k]] * 2000.0).round())
				acc[key] = acc.get(key, Vector3.ZERO) + fn
	else:
		for i in verts.size():
			var key := Vector3i((verts[i] * 2000.0).round())
			acc[key] = acc.get(key, Vector3.ZERO) + normals[i]
	for i in verts.size():
		var key := Vector3i((verts[i] * 2000.0).round())
		tri_n[i] = (acc[key] as Vector3).normalized()
	return tri_n
