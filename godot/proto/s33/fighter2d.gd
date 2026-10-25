extends Node2D

## S33 prototype, technique C: a 2D cutout fighter — flat shapes on pivots,
## two drawn views (front-3/4 and back-3/4) mirrored for the other two
## diagonals, animated by the same procedural poses as the 3D rig.
##
## In production every shape would be a painted piece (PNG) instead of a
## polygon; the rig, pivots, draw order and poses are what this proves.

const Pose := preload("res://proto/s33/pose.gd")
const Pal := preload("res://proto/s33/palette.gd")
const LINE := 2.0

var anim := "idle"
var t := 0.0
var element := "fuego"
var facing := "SE":
	set(v):
		if v != facing or _fig == null:
			facing = v
			if is_inside_tree():
				_build()

var _fig: Node2D
var _hips: Node2D
var _head: Node2D
var _arm := {}
var _leg := {}
var _gem: Node2D
var _gem_part: Part
var _flip := 1.0

static var _flash_shader: Shader


class Part extends Node2D:
	var shapes: Array = []

	func add(poly: PackedVector2Array, base: Color, shade: Color, k := 2.5) -> void:
		var shifted := PackedVector2Array()
		for p in poly:
			shifted.append(p + Vector2(-k, -k))
		var sh: Array = Array(Geometry2D.clip_polygons(poly, shifted)) if k > 0.0 else []
		shapes.append({"poly": poly, "base": base, "shade": shade, "sh": sh})

	func _draw() -> void:
		for s in shapes:
			draw_colored_polygon(s.poly, s.base)
			for p in s.sh:
				draw_colored_polygon(p, s.shade)
			var loop: PackedVector2Array = s.poly.duplicate()
			loop.append(s.poly[0])
			draw_polyline(loop, Pal.OUTLINE, LINE, true)


func _ready() -> void:
	_build()


func _process(_dt: float) -> void:
	_apply_pose()


func _apply_pose() -> void:
	if _fig == null:
		return
	var p := Pose.pose(anim, t)
	var s: float = p.squash
	_fig.scale = Vector2(_flip / sqrt(s), s)
	_fig.rotation = p.fall * 0.95 * _flip
	_fig.position = Vector2(6.0 * p.fall * _flip, 0)
	_hips.position = Vector2(0, -24 - p.bob * 60.0)
	_hips.rotation = -p.lean * 0.6
	_head.rotation = -p.head * 0.7
	_arm.near.rotation = p.arm_r * 0.85 if _arm.near_is_r else p.arm_l * 0.85
	_arm.far.rotation = p.arm_l * 0.85 if _arm.near_is_r else p.arm_r * 0.85
	_leg.near.rotation = p.leg_r * 0.7
	_leg.far.rotation = p.leg_l * 0.7
	(_fig.material as ShaderMaterial).set_shader_parameter("flash", p.flash)
	var ec: Array = Pal.ELEMENT[element]
	var gc: Color = ec[1].lerp(ec[0], 0.3 + 0.7 * p.staff)
	if _gem_part.shapes[0].base != gc:
		_gem_part.shapes[0].base = gc
		_gem_part.shapes[0].shade = gc
		_gem_part.queue_redraw()


func staff_tip() -> Vector2:
	return to_local(_gem.global_position)


func _build() -> void:
	if _fig:
		_fig.queue_free()
	var back := facing in ["NE", "NW", "N"]
	_flip = -1.0 if facing in ["SE", "NE", "E"] else 1.0
	_fig = Node2D.new()
	var m := ShaderMaterial.new()
	m.shader = _flash()
	_fig.material = m
	add_child(_fig)
	_hips = _node(_fig, Vector2(0, -24))
	# far side first, then body, then near side (draw order = depth)
	_leg.far = _limb_leg(_hips, Vector2(5, -1))
	var staff_far := back
	_arm.far = _limb_arm(_hips, Vector2(10, -21), staff_far)
	_leg.near = _limb_leg(_hips, Vector2(-5, 0))
	var body := _part(_hips)
	body.add(_ellipse(Vector2(0, -11), 13, 15), Pal.TUNIC, Pal.TUNIC_SH)
	body.add(_ellipse(Vector2(0, -1), 13, 3.4), Pal.LEATHER, Pal.LEATHER_SH, 0.0)
	body.add(_ellipse(Vector2(0, -23), 11, 4.2), Pal.GOLD, Pal.GOLD_SH, 1.5)
	if back:   # scarf tail down the back
		body.add(PackedVector2Array([Vector2(-2, -22), Vector2(5, -22), Vector2(7, -5),
			Vector2(1, -4)]), Pal.GOLD, Pal.GOLD_SH, 1.5)
	_head = _node(_hips, Vector2(0, -25))
	var head := _part(_head)
	head.add(_ellipse(Vector2(0, -14), 15, 14), Pal.SKIN, Pal.SKIN_SH, 3.5)
	if not back:
		head.add(_ellipse(Vector2(-8, -13), 2.0, 3.0), Pal.EYE, Pal.EYE, 0.0)
		head.add(_ellipse(Vector2(1, -13), 2.0, 3.0), Pal.EYE, Pal.EYE, 0.0)
	head.add(_ellipse(Vector2(0, -24), 17, 4.5), Pal.HAT, Pal.HAT_SH, 1.5)
	head.add(PackedVector2Array([Vector2(-12, -26), Vector2(12, -26), Vector2(8, -47)]),
		Pal.HAT, Pal.HAT_SH, 3.0)
	head.add(_ellipse(Vector2(8, -48), 4, 4), Pal.GOLD, Pal.GOLD_SH, 1.0)
	_arm.near = _limb_arm(_hips, Vector2(-12, -21), not staff_far)
	# the staff is held in the right hand: near side from the front, far from behind
	_arm.near_is_r = not back
	_set_parent_material(_fig)
	_apply_pose()


func _limb_leg(parent: Node2D, at: Vector2) -> Node2D:
	var pv := _node(parent, at)
	var p := _part(pv)
	p.add(_capsule(Vector2.ZERO, Vector2(0, 17), 4.5), Pal.TUNIC_SH, Pal.TUNIC_SH.darkened(0.2), 1.5)
	p.add(_ellipse(Vector2(-2, 19), 7, 4), Pal.LEATHER, Pal.LEATHER_SH, 1.5)
	return pv


func _limb_arm(parent: Node2D, at: Vector2, staff: bool) -> Node2D:
	var pv := _node(parent, at)
	if staff:
		var st := _part(pv)
		st.add(_capsule(Vector2(1, 30), Vector2(-5, -6), 1.8), Pal.WOOD, Pal.LEATHER_SH, 0.0)
		_gem = _node(pv, Vector2(-5, -9))
		_gem_part = _part(_gem)
		_gem_part.add(_ellipse(Vector2.ZERO, 4.5, 4.5), Pal.GOLD, Pal.GOLD, 0.0)
	var p := _part(pv)
	p.add(_capsule(Vector2.ZERO, Vector2(0, 14), 3.6), Pal.TUNIC, Pal.TUNIC_SH, 1.5)
	p.add(_ellipse(Vector2(0, 16), 4.5, 4.5), Pal.SKIN, Pal.SKIN_SH, 1.5)
	return pv


func _node(parent: Node2D, at: Vector2) -> Node2D:
	var n := Node2D.new()
	n.position = at
	parent.add_child(n)
	return n


func _part(parent: Node2D) -> Part:
	var p := Part.new()
	parent.add_child(p)
	return p


func _set_parent_material(n: Node) -> void:
	for c in n.get_children():
		if c is CanvasItem:
			(c as CanvasItem).use_parent_material = true
		_set_parent_material(c)


static func _ellipse(c: Vector2, rx: float, ry: float, n := 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


static func _capsule(a: Vector2, b: Vector2, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d := (b - a).normalized()
	var ang := d.angle()
	for i in 9:
		out.append(b + Vector2.from_angle(ang - PI / 2 + PI * i / 8.0) * r)
	for i in 9:
		out.append(a + Vector2.from_angle(ang + PI / 2 + PI * i / 8.0) * r)
	return out


static func _flash() -> Shader:
	if _flash_shader == null:
		_flash_shader = Shader.new()
		_flash_shader.code = """
shader_type canvas_item;
uniform float flash = 0.0;
void fragment() { COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash); }
"""
	return _flash_shader
