extends Node2D

## S33 prototype, techniques A and B: a low-poly 3D fighter drawn by Godot
## into a transparent SubViewport and shown as a 2D sprite standing on the
## 2D isometric map — the way it would sit inside fight_view.
##
##   A (live 3D):   rendered every frame at screen resolution.
##   B (3D → sprite): the same model as an offline bake would see it —
##                  game resolution, 12 fps, posterized, hard alpha, nearest
##                  filtering. bake_frames() writes the real PNGs.
##
## Cells are 1 unit a side; the camera is orthographic at the map's 2:1
## projection (pitch 30°, yaw 45°), so 1 unit = HW·√2 px across.

const Pose := preload("res://proto/s33/pose.gd")
const Pal := preload("res://proto/s33/palette.gd")

const PX_PER_UNIT := 43.0 * 1.41421356
const BASE := Vector2i(150, 180)
const FEET := Vector2(0.5, 0.86)   # where the feet land inside the viewport

## Screen direction → model yaw. The model faces +Z.
const YAW := {"SE": 90.0, "SW": 0.0, "NE": 180.0, "NW": -90.0, "S": 45.0,
	"E": 135.0, "N": -135.0, "W": -45.0}

var anim := "idle"
var t := 0.0
var facing := "SE"
var element := "fuego"
var baked := false:
	set(v):
		baked = v
		if _spr:
			_apply_look()
var res_scale := 1.0:
	set(v):
		res_scale = v
		if _vp:
			_apply_look()

var _vp: SubViewport
var _spr: Sprite2D
var _cam: Camera3D
var _root: Node3D
var _fall: Node3D
var _hips: Node3D
var _head: Node3D
var _arm := {}
var _leg := {}
var _gem_mat: ShaderMaterial
var _mats: Array[ShaderMaterial] = []

static var _toon: Shader
static var _outline: Shader
static var _poster: Shader


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.size = BASE.y / PX_PER_UNIT
	_cam.rotation_degrees = Vector3(-30, 45, 0)
	var b := _cam.transform.basis
	# put the origin (the feet) at FEET inside the frame
	_cam.position = b.z * 20.0 + b.y * (_cam.size * (FEET.y - 0.5))
	_cam.near = 0.1
	_cam.far = 60.0
	_vp.add_child(_cam)
	_build_rig()
	_spr = Sprite2D.new()
	_spr.texture = _vp.get_texture()
	_spr.centered = false
	add_child(_spr)
	_apply_look()
	_apply_pose()


func _process(_dt: float) -> void:
	_apply_pose()


func _apply_look() -> void:
	var s := 1.0 if baked else res_scale
	_vp.size = Vector2i(roundi(BASE.x * s), roundi(BASE.y * s))
	_vp.msaa_3d = Viewport.MSAA_DISABLED if baked else Viewport.MSAA_4X
	_spr.scale = Vector2.ONE / s
	_spr.position = -Vector2(BASE) * FEET
	if baked:
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var m := ShaderMaterial.new()
		m.shader = _poster_shader()
		_spr.material = m
	else:
		_spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		_spr.material = null


func _apply_pose() -> void:
	var tt := t
	if baked:
		tt = floorf(t * 12.0) / 12.0
	var p := Pose.pose(anim, tt)
	_root.rotation_degrees.y = YAW.get(facing, 0.0)
	_fall.rotation.x = -p.fall
	_hips.position.y = 0.36 + p.bob
	_hips.rotation.x = p.lean
	var s: float = p.squash
	_hips.scale = Vector3(1.0 / sqrt(s), s, 1.0 / sqrt(s))
	_head.rotation.x = p.head
	_arm.l.rotation.x = -p.arm_l
	_arm.r.rotation.x = -p.arm_r
	_leg.l.rotation.x = -p.leg_l
	_leg.r.rotation.x = -p.leg_r
	for m in _mats:
		m.set_shader_parameter("flash", p.flash)
	var ec: Array = Pal.ELEMENT[element]
	_gem_mat.set_shader_parameter("base", ec[1].lerp(ec[0], 0.3 + 0.7 * p.staff))


## Gem tip of the staff, in this node's 2D space — where a spell leaves from.
func staff_tip() -> Vector2:
	var g: Node3D = _arm.r.get_node("gem")
	var px := _cam.unproject_position(g.global_position)
	var s := float(_vp.size.y) / BASE.y
	return px / s - Vector2(BASE) * FEET


func _build_rig() -> void:
	_root = Node3D.new()
	_vp.add_child(_root)
	_fall = Node3D.new()
	_root.add_child(_fall)
	_hips = Node3D.new()
	_fall.add_child(_hips)
	# body
	_part(_hips, _capsule(0.17, 0.46), Vector3(0, 0.12, 0), Pal.TUNIC, Pal.TUNIC_SH)
	_part(_hips, _cyl(0.178, 0.178, 0.05), Vector3(0, -0.02, 0), Pal.LEATHER, Pal.LEATHER_SH)
	_part(_hips, _cyl(0.13, 0.17, 0.08), Vector3(0, 0.3, 0), Pal.GOLD, Pal.GOLD_SH)
	# scarf tail down the back: makes the back views read at a glance
	var tail := _part(_hips, _box(Vector3(0.11, 0.26, 0.035)), Vector3(0.05, 0.16, -0.18), Pal.GOLD, Pal.GOLD_SH)
	tail.rotation = Vector3(-0.15, 0, 0.12)
	# head
	_head = Node3D.new()
	_head.position = Vector3(0, 0.34, 0)
	_hips.add_child(_head)
	_part(_head, _sphere(0.25), Vector3(0, 0.2, 0), Pal.SKIN, Pal.SKIN_SH)
	for sx in [-1.0, 1.0]:
		var e := _part(_head, _sphere(0.045), Vector3(0.09 * sx, 0.2, 0.228), Pal.EYE, Pal.EYE, false)
		e.scale = Vector3(1, 1.4, 0.5)
	_part(_head, _cyl(0.27, 0.27, 0.04), Vector3(0, 0.38, -0.02), Pal.HAT, Pal.HAT_SH)
	var hat := _part(_head, _cyl(0.0, 0.22, 0.42), Vector3(0, 0.6, -0.06), Pal.HAT, Pal.HAT_SH)
	hat.rotation.x = -0.35
	_part(hat, _sphere(0.07), Vector3(0, 0.22, 0), Pal.GOLD, Pal.GOLD_SH)
	# limbs
	for side in ["l", "r"]:
		var sx := -1.0 if side == "l" else 1.0
		var a := Node3D.new()
		a.position = Vector3(0.21 * sx, 0.26, 0)
		_hips.add_child(a)
		_arm[side] = a
		_part(a, _capsule(0.055, 0.3), Vector3(0, -0.12, 0), Pal.TUNIC, Pal.TUNIC_SH)
		_part(a, _sphere(0.07), Vector3(0, -0.27, 0), Pal.SKIN, Pal.SKIN_SH)
		var lg := Node3D.new()
		lg.position = Vector3(0.09 * sx, -0.02, 0)
		_hips.add_child(lg)
		_leg[side] = lg
		_part(lg, _capsule(0.065, 0.3), Vector3(0, -0.15, 0), Pal.TUNIC_SH, Pal.TUNIC_SH)
		var f := _part(lg, _sphere(0.08), Vector3(0, -0.31, 0.04), Pal.LEATHER, Pal.LEATHER_SH)
		f.scale = Vector3(1, 0.6, 1.5)
	# staff in the right hand, gem on top
	var staff := _part(_arm.r, _cyl(0.022, 0.022, 0.75), Vector3(0, -0.2, 0.05), Pal.WOOD, Pal.LEATHER_SH)
	staff.rotation.x = 0.15
	var gem := _part(_arm.r, _sphere(0.065), Vector3(0, 0.17, 0.1), Pal.GOLD, Pal.GOLD)
	gem.name = "gem"
	_gem_mat = gem.material_override


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, base: Color, shade: Color,
		outline := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var m := ShaderMaterial.new()
	m.shader = _toon_shader()
	m.set_shader_parameter("base", base)
	m.set_shader_parameter("shade", shade)
	mi.material_override = m
	_mats.append(m)
	parent.add_child(mi)
	if outline:
		var o := MeshInstance3D.new()
		o.mesh = mesh
		var om := ShaderMaterial.new()
		om.shader = _outline_shader()
		om.set_shader_parameter("col", Pal.OUTLINE)
		o.material_override = om
		mi.add_child(o)
	return mi


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


static func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 14
	m.rings = 8
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 12
	m.rings = 1
	return m


static func _toon_shader() -> Shader:
	if _toon == null:
		_toon = Shader.new()
		_toon.code = """
shader_type spatial;
render_mode unshaded;
uniform vec4 base : source_color;
uniform vec4 shade : source_color;
uniform float flash = 0.0;
void fragment() {
	vec3 l = normalize((VIEW_MATRIX * vec4(normalize(vec3(-0.6, 1.0, 0.25)), 0.0)).xyz);
	vec3 n = normalize(NORMAL);
	float d = dot(n, l);
	vec3 c = d > 0.05 ? base.rgb : shade.rgb;
	float rim = 1.0 - max(dot(n, VIEW), 0.0);
	c = mix(c, min(c * 1.25, vec3(1.0)), step(0.82, rim) * step(0.05, d));
	ALBEDO = mix(c, vec3(1.0), flash);
}
"""
	return _toon


static func _outline_shader() -> Shader:
	if _outline == null:
		_outline = Shader.new()
		_outline.code = """
shader_type spatial;
render_mode unshaded, cull_front;
uniform vec4 col : source_color;
uniform float width = 0.022;
void vertex() { VERTEX += NORMAL * width; }
void fragment() { ALBEDO = col.rgb; }
"""
	return _outline


static func _poster_shader() -> Shader:
	if _poster == null:
		_poster = Shader.new()
		_poster.code = """
shader_type canvas_item;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	c.rgb = floor(c.rgb * 6.0 + 0.5) / 6.0;
	c.a = step(0.5, c.a);
	COLOR = c;
}
"""
	return _poster


## Technique B for real: write every frame an offline bake would ship
## (anims × directions at 12 fps, game resolution) and return the bytes.
func bake_frames(dir: String, anims: Array, dirs: Array) -> int:
	DirAccess.make_dir_recursive_absolute(dir)
	var total := 0
	var was := baked
	baked = true
	for a in anims:
		for d in dirs:
			anim = a
			facing = d
			var n := ceili(Pose.LENGTH[a] * 12.0)
			for i in n:
				t = i / 12.0
				_apply_pose()
				await RenderingServer.frame_post_draw
				var img := _vp.get_texture().get_image()
				img = img.get_region(img.get_used_rect())   # trimmed, as a packer would
				var path := "%s/%s_%s_%02d.png" % [dir, a, d, i]
				img.save_png(path)
				total += FileAccess.get_file_as_bytes(path).size()
	baked = was
	return total
