extends RefCounted

## M7 (S36): builds an arena layout (arena_layout.gd) in 3D with our kiln
## models, the way the tools/art renders show them: GLBs read at run time,
## dressed by kit_dress.gd, tinted per item, columns run down to the floor.
## One node per cell, so the editor can rebuild a single cell.
##
## The light and camera are the game's (build_map.gd, kit_shots.gd):
## orthographic, 2:1, 86-px cells at zoom 1, sun from the upper left.

const Layout := preload("res://src/maps/arena_layout.gd")
const Dress := preload("res://src/maps/kit_dress.gd")

## model path -> dressed Node3D (template, duplicated per use); null = missing
var _models := {}
## model path -> AABB of its meshes
var _bounds := {}
## "<material id>/<tint>" -> tinted copy
var _tinted := {}
## model paths that failed to load, for the editor's status line
var missing := {}


## The dressed model, a fresh copy, or null when its GLB isn't built.
func model(path: String) -> Node3D:
	if not _models.has(path):
		_models[path] = _load(path)
	var m = _models[path]
	return (m as Node3D).duplicate() if m != null else null


func _load(path: String) -> Node3D:
	var abs := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(abs):
		missing[path] = true
		return null
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(abs, st) != OK:
		missing[path] = true
		return null
	var scene := doc.generate_scene(st)
	for mi in scene.find_children("*", "MeshInstance3D", true, false) + ([scene] if scene is MeshInstance3D else []):
		Dress.dress(mi)
	# kiln's lights arrive with glTF's huge range: keep them a local glow
	for l in scene.find_children("*", "OmniLight3D", true, false):
		(l as OmniLight3D).omni_range = 1.6
		(l as OmniLight3D).light_energy = 0.8
	return scene


## The model's box in its own space (meshes only).
func bounds(path: String) -> AABB:
	if not _bounds.has(path):
		var m := model(path)
		_bounds[path] = node_bounds(m) if m != null else AABB()
		if m != null:
			m.free()
	return _bounds[path]


static func node_bounds(n: Node3D, space: Node3D = null) -> AABB:
	if space == null:
		space = n
	var bb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		var t := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != space:
			t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var b: AABB = t * m.get_aabb()
		bb = b if first else bb.merge(b)
		first = false
	return bb


## A cell's node: at the cell's centre on its surface, one child per item
## (meta "item" = its index) plus the columns under the block.
func build_cell(p: Vector2i, cell: Dictionary, items: Array, floor_y: float) -> Node3D:
	var root := Node3D.new()
	root.name = "c%d_%d" % [p.x, p.y]
	var surface_y: float = cell.surface * Layout.ALT
	root.position = Vector3(p.x + 0.5, surface_y, p.y + 0.5)
	for i in items.size():
		var it: Dictionary = items[i]
		var n := build_item(it, Layout.item_y(items, i))
		if n == null:
			continue
		n.set_meta("item", i)
		root.add_child(n)
		var pc := Layout.piece(it.kit, it.piece)
		if pc.get("kind", "") == "tile" and pc.get("col", "") != "":
			_columns(root, it, Layout.model_path(it.kit, pc.col, it.loom),
				Layout.item_y(items, i), floor_y - surface_y, i)
	return root


## One placed item: its model in its loom, turned, mirrored, scaled,
## offset and tinted. y = its origin's height over the cell's surface.
func build_item(it: Dictionary, y: float) -> Node3D:
	var m := model(Layout.model_path(it.kit, it.piece, it.loom))
	if m == null:
		return null
	var n := Node3D.new()
	n.add_child(m)
	n.position = Vector3(it.off[0], y, it.off[2])
	n.rotation.y = deg_to_rad(it.rot)
	n.scale = Vector3(-it.scale if it.flip else it.scale, it.scale, it.scale)
	tint(m, Color.html(it.tint))
	return n


## Columns from under the block (top_y, cell space) down to floor_y, one
## model-height at a time; the last one is squashed to fit.
func _columns(root: Node3D, it: Dictionary, path: String, top_y: float,
		floor_y: float, index: int) -> void:
	var bb := bounds(path)
	if bb.size.y <= 0.01:
		return
	var y := top_y
	var guard := 0
	while y > floor_y + 0.001 and guard < 64:
		var h := minf(bb.size.y, y - floor_y)
		var col := model(path)
		if col == null:
			return
		var n := Node3D.new()
		n.add_child(col)
		var k := h / bb.size.y
		n.position = Vector3(it.off[0], y - h - bb.position.y * k, it.off[2])
		n.rotation.y = deg_to_rad(it.rot)
		n.scale = Vector3(-1.0 if it.flip else 1.0, k, 1.0)
		n.set_meta("item", index)
		n.set_meta("column", true)
		tint(col, Color.html(it.tint))
		root.add_child(n)
		y -= h
		guard += 1


## The built arena (cells from build_cell under src) redone for the GPU:
## every mesh placed more than once becomes one MultiMesh, one draw call per
## surface however many times it stands, instead of one per copy (a big
## arena had 1,000-7,000 draw calls). A copy keeps its tint (as the
## instance's colour when the mesh has no vertex colours, so differently
## tinted copies still share a MultiMesh; else as its own tinted mesh) and
## its shadow setting; a mirrored copy goes with the other mirrored ones,
## its faces culled the other way round. The models' lights move over as
## they are.
## The fight's arena is static, so this is done once, after building; the
## editor keeps the per-cell nodes it edits.
func flatten(src: Node3D) -> Node3D:
	var out := Node3D.new()
	out.name = "Arena"
	var groups := {}   # key -> {mesh, shadow, at: [Transform3D], tint: [Color]}
	for n in src.find_children("*", "", true, false):
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			var t := _in_space(mi, src)
			var mirrored := t.basis.determinant() < 0.0
			var c: Color = mi.get_meta("tint", Color.WHITE)
			var by_colour := _plain(mi.mesh)
			var mesh := _coloured_mesh(mi.mesh, mirrored) if by_colour \
				else _placed_mesh(mi, mirrored)
			var key := "%d/%d" % [mesh.get_instance_id(), mi.cast_shadow]
			if not groups.has(key):
				groups[key] = {"mesh": mesh, "shadow": mi.cast_shadow, "at": [],
					"tint": [], "coloured": by_colour}
			groups[key].at.append(t)
			groups[key].tint.append(c)
		elif n is Light3D:
			var l := (n as Light3D).duplicate() as Light3D
			for ch in l.get_children():
				ch.free()
			l.transform = _in_space(n, src)
			out.add_child(l)
	for g: Dictionary in groups.values():
		var at: Array = g.at
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = g.coloured
		mm.mesh = g.mesh
		mm.instance_count = at.size()
		for i in at.size():
			mm.set_instance_transform(i, at[i])
			if g.coloured:
				mm.set_instance_color(i, g.tint[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = g.shadow
		out.add_child(mmi)
	return out


## n's transform in space's coordinates (n need not be in the tree).
static func _in_space(n: Node3D, space: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != space:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## "<mesh>/<override materials>/<mirrored>" -> the mesh a copy draws with
var _placed := {}
## "<mesh>/<mirrored>" -> its copy that takes the tint from the instance
var _coloured := {}
## material id (+ mirrored) -> its copy tinted by the instance colour
var _coloured_mat := {}


## True when no surface of the mesh has vertex colours: the instance colour
## can then carry the tint (it multiplies COLOR, which is white here).
static func _plain(mesh: Mesh) -> bool:
	for s in mesh.get_surface_count():
		if mesh.surface_get_format(s) & Mesh.ARRAY_FORMAT_COLOR:
			return false
		if not mesh.surface_get_material(s) is BaseMaterial3D:
			return false
	return true


## The mesh with every material taking the instance colour as a tint, the
## same multiply as tint() (in sRGB, like albedo_color).
func _coloured_mesh(src: Mesh, mirrored: bool) -> Mesh:
	var key := "%d/%s" % [src.get_instance_id(), mirrored]
	if not _coloured.has(key):
		var mesh := src.duplicate() as Mesh
		for s in mesh.get_surface_count():
			var m := src.surface_get_material(s) as BaseMaterial3D
			var mkey := "%d/%s" % [m.get_instance_id(), mirrored]
			if not _coloured_mat.has(mkey):
				var c := (_flip_cull(m) if mirrored else m).duplicate() as BaseMaterial3D
				c.vertex_color_use_as_albedo = true
				c.vertex_color_is_srgb = true
				_coloured_mat[mkey] = c
			mesh.surface_set_material(s, _coloured_mat[mkey])
		_coloured[key] = mesh
	return _coloured[key]
## material id -> its copy with the faces culled the other way round
var _mirrored_mat := {}


## The mesh mi draws, its tint (surface overrides) baked into the surfaces'
## materials, and the culling turned round when the copy is mirrored. Copies
## that look the same share one mesh, so they share one MultiMesh.
func _placed_mesh(mi: MeshInstance3D, mirrored: bool) -> Mesh:
	var src := mi.mesh
	var mats := []
	var changed := mirrored
	for s in src.get_surface_count():
		var m := mi.get_surface_override_material(s)
		if m != null:
			changed = true
		else:
			m = src.surface_get_material(s)
		if mirrored and m is BaseMaterial3D:
			m = _flip_cull(m)
		mats.append(m)
	if not changed:
		return src
	var ids := []
	for m in mats:
		ids.append(m.get_instance_id() if m != null else 0)
	var key := "%d/%s" % [src.get_instance_id(), ids]
	if not _placed.has(key):
		var mesh := src.duplicate() as Mesh
		for s in mats.size():
			mesh.surface_set_material(s, mats[s])
		_placed[key] = mesh
	return _placed[key]


func _flip_cull(m: BaseMaterial3D) -> BaseMaterial3D:
	if m.cull_mode == BaseMaterial3D.CULL_DISABLED:
		return m
	var id := m.get_instance_id()
	if not _mirrored_mat.has(id):
		var f := m.duplicate() as BaseMaterial3D
		f.cull_mode = BaseMaterial3D.CULL_FRONT if m.cull_mode == BaseMaterial3D.CULL_BACK \
			else BaseMaterial3D.CULL_BACK
		_mirrored_mat[id] = f
	return _mirrored_mat[id]


## Multiplies every surface's albedo by c (white leaves the model alone).
func tint(n: Node3D, c: Color) -> void:
	if c.is_equal_approx(Color.WHITE):
		return
	var hex := c.to_html(false)
	for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		m.set_meta("tint", c)   # flatten() hands it to the instance
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as BaseMaterial3D
			if src == null:
				continue
			var key := "%d/%s" % [src.get_instance_id(), hex]
			if not _tinted.has(key):
				var t := src.duplicate() as BaseMaterial3D
				t.albedo_color = src.albedo_color * c
				_tinted[key] = t
			m.set_surface_override_material(s, _tinted[key])


## The game's light: grey backdrop, cool ambient, warm sun from the upper
## left with soft shadows.
static func add_lights(parent: Node) -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("4d4d4d")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("dfe8ff")
	e.ambient_light_energy = 0.32
	env.environment = e
	parent.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, 20, 0)
	sun.light_color = Color("fff4e0")
	sun.light_energy = 0.5
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	parent.add_child(sun)


## The game's camera: orthographic, looking down 30° from the +x+z corner,
## so a cell is 86×43 px and an altitude step 10 px at zoom 1.
static func game_camera(view_h: float, zoom: float, center: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view_h / (Layout.PX * zoom)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	cam.position = center + cam.transform.basis.z * 60.0
	cam.far = 200.0
	return cam
