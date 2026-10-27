extends SceneTree

## M7: photograph every piece of an arena kit (art/<arena>/kit.json) in its
## three looms, the way the game shows it (orthographic 2:1, 86-px cells,
## zoomed by --zoom), each piece on its own. One PNG per piece and loom, for
## a review sheet. The zoom never changes: a tall piece gets a taller shot.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##       -s tools/art/kit_shots.gd -- --kit=art/arena1/kit.json --out=<dir> [--zoom=1.6]

const Dress := preload("res://tools/art/dress.gd")
const PX := 43.0 * 1.41421356
const SIZE := Vector2i(300, 340)

var opts := {"kit": "art/arena1/kit.json", "out": "/tmp/kit", "zoom": "1.6"}
var _cache := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	var kit: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + opts.kit))
	var dir: String = String(opts.kit).get_base_dir()
	DirAccess.make_dir_recursive_absolute(opts.out)
	for p: Dictionary in kit.pieces:
		for loom: String in kit.looms:
			var root3 := Node3D.new()
			var piece := _model(dir, p.name + loom)
			if piece == null:
				quit(1)
				return
			root3.add_child(piece)
			if p.kind == "tile":
				piece.position.y = -p.top
			# frame the piece: centre on its box; the shot grows with the piece
			var bb := _bounds(root3)
			var need := int(ceil((bb.size.y * 0.866 + maxf(bb.size.x, bb.size.z) * 0.6 + 0.4) * PX * float(opts.zoom)))
			var img := await _shoot(root3, bb.get_center().y, Vector2i(SIZE.x, maxi(SIZE.y, need)))
			img.save_png("%s/%s%s.png" % [opts.out, p.name, loom])
	print("[kit] %d pieces x %d looms -> %s" % [kit.pieces.size(), kit.looms.size(), opts.out])
	quit(0)


func _model(dir: String, name: String) -> Node3D:
	if not _cache.has(name):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		var path := ProjectSettings.globalize_path("res://%s/out/models/%s.glb" % [dir, name])
		if doc.append_from_file(path, st) != OK:
			push_error("can't read " + path)
			return null
		var scene := doc.generate_scene(st)
		for mi in scene.find_children("*", "MeshInstance3D", true, false) + ([scene] if scene is MeshInstance3D else []):
			Dress.dress(mi)
		# kiln's lights arrive with glTF's huge range: keep them a local glow
		for l in scene.find_children("*", "OmniLight3D", true, false):
			(l as OmniLight3D).omni_range = 1.6
			(l as OmniLight3D).light_energy = 0.8
		_cache[name] = scene
	return (_cache[name] as Node3D).duplicate()


## The piece's box in its own space (meshes only).
func _bounds(n: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b: AABB = t * m.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb


func _shoot(model: Node3D, cy: float, size: Vector2i) -> Image:
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
	cam.size = size.y / (PX * float(opts.zoom))
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = Vector3(0, cy, 0) + cam.transform.basis.z * 20.0
	vp.add_child(cam)
	cam.make_current()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img
