extends SceneTree

## M7: lay an arena out the way the retail map has it, with our own kiln
## models in place of the retail pieces: every retail sprite in
## assets/mapgfx/<map>.json names its cell (its sort key) and, through its
## screen position, the height of the block it draws; its tint, the colour. The layout file says
## which of our models stands in for which retail gfx; gfx it doesn't list
## are left out. The picture comes out on the same canvas as the retail map
## in ~/codigo/m7-referencias/arena_sheet.py (same scale, same framing), so
## the two can sit side by side.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot \
##       -s tools/art/build_arena.gd -- --layout=art/arena1/layout.json --out=<png>

const Dress := preload("res://tools/art/dress.gd")

const PX := 43.0 * 1.41421356          # screen px per world unit across
const ALT := 10.0 / (PX * 0.8660254)   # world units per altitude step (10 px)
const PAD := 30.0                      # arena_sheet.py's margin round the map
const GROUND := 8191                   # retail intra key of a cell's ground element
const DECAL := 8207                    # flat decals and props standing on the cell

var opts := {"layout": "art/arena1/layout.json", "out": "/tmp/arena.png"}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
	_run.call_deferred()


func _run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + opts.layout))
	var dir: String = String(opts.layout).get_base_dir()
	var map_id := int(layout.map)
	var gfx: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/mapgfx/%d.json" % map_id))
	var sprites: Array = gfx.sprites

	# retail canvas, as arena_sheet.py frames it
	var minx := INF
	var miny := INF
	var maxx := -INF
	var maxy := -INF
	for s in sprites:
		minx = minf(minx, s.sx); miny = minf(miny, s.sy)
		maxx = maxf(maxx, s.sx + s.w); maxy = maxf(maxy, s.sy + s.h)
	var size := Vector2i(int(maxx - minx) + 2 * int(PAD), int(maxy - miny) + 2 * int(PAD))
	DisplayServer.window_set_size(size)
	root.size = size

	# per cell: its ground sprites (the top one is the block, the rest the
	# blocks stacked under it) and the decoration standing on it
	var ground := {}
	var deco := {}
	for s in sprites:
		var z := int(s.z)
		var p := Vector2i(((z >> 14) & 0x3FFFF) - 131072, (z >> 32) - 131072)
		var key := str(int(s.tex))
		if z & 0x3FFF == GROUND and layout.tiles.has(key):
			ground[p] = ground.get(p, []) + [s]
		elif layout.props.has(key):
			deco[p] = deco.get(p, []) + [s]

	# where each tile sprite's top face sits under its top edge: the first
	# opaque pixel down the middle is the face's back corner, half a cell
	# above its centre
	var face := {}
	for k in layout.tiles:
		var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/mapgfx/tex/%s.png" % k))
		var y0 := 0
		if img:
			while y0 < img.get_height() - 1 and img.get_pixel(img.get_width() / 2, y0).a < 0.5:
				y0 += 1
		face[k] = y0 + 21.5

	var models := {}
	for k in layout.tiles:
		for m in [layout.tiles[k][0], layout.tiles[k][2]]:
			models[m] = null
	for k in layout.props:
		models[layout.props[k]] = null
	for m in models:
		models[m] = _load("res://%s/out/models/%s.glb" % [dir, m])
		if models[m] == null:
			quit(1)
			return

	var world := Node3D.new()
	root.add_child(world)
	var counts := {}
	var stand_in := {}
	for p: Vector2i in ground:
		var top: Dictionary = _top(ground[p])
		var k := str(int(top.tex))
		var t: Array = layout.tiles[k]
		# the retail face centre and ours land on the same screen point
		var y: float = (_v(p) - (float(top.sy) + face[k])) * ALT / 10.0
		var blk: Node3D = models[t[0]].duplicate()
		blk.position = Vector3(p.x + 0.5, y - t[1], p.y + 0.5)
		_tint(blk, top.get("c"))
		world.add_child(blk)
		counts[t[0]] = counts.get(t[0], 0) + 1
		if t.size() > 3:
			stand_in[k] = t[0]
		# columns down to where the retail blocks end (front corner of the cell)
		var bottom := -INF
		for s in ground[p]:
			bottom = maxf(bottom, s.sy + s.h)
		var y_bot := ((p.x + p.y) * 21.5 - bottom) * ALT / 10.0
		var yc: float = y - t[1]
		while yc > y_bot + 0.02:
			var h := minf(1.0, yc - y_bot)
			var col: Node3D = models[t[2]].duplicate()
			col.position = Vector3(p.x + 0.5, yc - h, p.y + 0.5)
			col.scale = Vector3(1, h, 1)
			_tint(col, top.get("c"))
			world.add_child(col)
			yc -= h
		for s in deco.get(p, []):
			var m: String = layout.props[str(int(s.tex))]
			var pr: Node3D = models[m].duplicate()
			# as tall on screen as the retail sprite (less the cell it stands on)
			var tall := _height(pr)
			var sc := (float(s.h) - 21.5) / (tall / ALT * 10.0) if tall > 0.0 else 1.0
			pr.scale = Vector3.ONE * sc
			pr.position = Vector3(p.x + 0.5, y - 0.02, p.y + 0.5)
			pr.rotation.y = (hash(p * 7349) % 360) * PI / 180.0
			_tint(pr, s.get("c"))
			world.add_child(pr)
			counts[m] = counts.get(m, 0) + 1
	print("[arena] map %d: %s; stand-ins %s" % [map_id, counts, stand_in])

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
	sun.shadow_blur = 2.0
	world.add_child(sun)

	# the canvas centre, in retail screen space, back to a point on y = 0:
	# u = (X - Z) * 43, v = (X + Z - 2) * 21.5 - Y / ALT * 10
	var u0 := minx - PAD + size.x / 2.0
	var v0 := miny - PAD + size.y / 2.0
	var d := u0 / 43.0
	var sm := v0 / 21.5 + 2.0
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = size.y / PX
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = Vector3((sm + d) / 2.0, 0, (sm - d) / 2.0) + cam.transform.basis.z * 80.0
	cam.far = 300.0
	world.add_child(cam)
	cam.make_current()

	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(opts.out)
	print("[arena] %s (%dx%d)" % [opts.out, size.x, size.y])
	quit(0)


## Retail screen y of cell p's centre at altitude 0.
func _v(p: Vector2i) -> float:
	return (p.x + p.y - 1) * 21.5


## The highest of a cell's ground sprites: the block on top.
func _top(list: Array) -> Dictionary:
	var top: Dictionary = list[0]
	for s in list:
		if s.sy < top.sy:
			top = s
	return top


## The retail colours the same piece per placement (a multiply tint, the
## lilac snow is the white block tinted): we do the same on our model.
func _tint(n: Node3D, c: Variant) -> void:
	if not c is Array or c == [1, 1, 1]:
		return
	var col := Color(c[0], c[1], c[2])
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		for i in mi.mesh.get_surface_count():
			var m := (mi.mesh.surface_get_material(i) as BaseMaterial3D).duplicate() as BaseMaterial3D
			m.albedo_color = m.albedo_color * col
			mi.set_surface_override_material(i, m)


func _height(n: Node3D) -> float:
	var hi := 0.0
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var bb: AABB = (mi as MeshInstance3D).get_aabb()
		hi = maxf(hi, bb.end.y)
	return hi


func _load(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), st) != OK:
		push_error("can't read " + path)
		return null
	var scene := doc.generate_scene(st)
	for mi in scene.find_children("*", "MeshInstance3D", true, false) + ([scene] if scene is MeshInstance3D else []):
		Dress.dress(mi)
	return scene
