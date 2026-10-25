extends Node2D

## S33 prototype: real-time spell VFX by ELEMENT instead of one hand-drawn
## animation per spell. A cast is a projectile with a trail, then a burst and
## a ground ring at the target; the five elements differ only in colours,
## gravity and spread. Particles are CPUParticles2D (the compatibility
## renderer), drawn additively except earth.

const Pal := preload("res://proto/s33/palette.gd")
const FLIGHT := 0.32

static var _dot: Texture2D

var _shots: Array = []   # {from, to, el, age, trail, done}
var _rings: Array = []   # {at, el, age}


static func soft_dot() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 32
		tex.height = 32
		_dot = tex
	return _dot


func cast(from: Vector2, to: Vector2, el: String) -> void:
	var trail := _emitter(el, "trail")
	trail.position = from
	_shots.append({"from": from, "to": to, "el": el, "age": 0.0, "trail": trail})


## Burst on its own (the element row of the sheet).
func burst(at: Vector2, el: String) -> void:
	var b := _emitter(el, "burst")
	b.position = at
	b.emitting = true
	_rings.append({"at": at, "el": el, "age": 0.0})


func step(dt: float) -> void:
	for s in _shots.duplicate():
		s.age += dt
		var k := clampf(s.age / FLIGHT, 0.0, 1.0)
		var p: Vector2 = s.from.lerp(s.to, k) + Vector2(0, -40.0 * sin(PI * k))
		s.trail.position = p
		s.pos = p
		if k >= 1.0:
			s.trail.emitting = false
			burst(s.to, s.el)
			_shots.erase(s)
	for r in _rings.duplicate():
		r.age += dt
		if r.age > 0.6:
			_rings.erase(r)
	queue_redraw()


func _draw() -> void:
	for s in _shots:
		if s.has("pos"):
			var ec: Array = Pal.ELEMENT[s.el]
			draw_circle(s.pos, 9.0, Color(ec[1], 0.35))
			draw_circle(s.pos, 5.5, ec[1])
			draw_circle(s.pos, 3.0, ec[0])
	for r in _rings:
		var k: float = r.age / 0.6
		var ec: Array = Pal.ELEMENT[r.el]
		var pts := PackedVector2Array()
		for i in 33:
			var a := TAU * i / 32.0
			pts.append(r.at + Vector2(cos(a) * 46.0 * k, sin(a) * 23.0 * k))
		draw_polyline(pts, Color(ec[1], 1.0 - k), 4.0 * (1.0 - k) + 1.0, true)


func _emitter(el: String, kind: String) -> CPUParticles2D:
	var e := CPUParticles2D.new()
	e.texture = soft_dot()
	e.local_coords = false
	var ec: Array = Pal.ELEMENT[el]
	var grad := Gradient.new()
	grad.set_color(0, ec[0])
	grad.set_color(1, Color(ec[1], 0.0))
	grad.add_point(0.35, ec[1])
	e.color_ramp = grad
	if el != "tierra":
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		e.material = m
	if kind == "trail":
		e.amount = 40
		e.lifetime = 0.35
		e.emitting = true
		e.spread = 180
		e.initial_velocity_min = 5
		e.initial_velocity_max = 25
		e.gravity = Vector2.ZERO
		e.scale_amount_min = 0.25
		e.scale_amount_max = 0.5
	else:
		e.one_shot = true
		e.explosiveness = 0.92
		e.amount = 48
		e.lifetime = 0.7
		e.spread = 180
		e.scale_amount_min = 0.3
		e.scale_amount_max = 0.8
		match el:
			"fuego":
				e.direction = Vector2(0, -1)
				e.spread = 70
				e.initial_velocity_min = 60
				e.initial_velocity_max = 150
				e.gravity = Vector2(0, -120)
				e.damping_min = 40
				e.damping_max = 80
			"agua":
				e.direction = Vector2(0, -1)
				e.spread = 55
				e.initial_velocity_min = 120
				e.initial_velocity_max = 210
				e.gravity = Vector2(0, 520)
			"tierra":
				e.direction = Vector2(0, -1)
				e.spread = 65
				e.initial_velocity_min = 110
				e.initial_velocity_max = 190
				e.gravity = Vector2(0, 620)
				e.scale_amount_min = 0.35
				e.scale_amount_max = 0.6
				e.texture = null   # square chips
				e.amount = 64
				e.scale_amount_min = 5.0
				e.scale_amount_max = 9.0
				e.angle_min = 0
				e.angle_max = 360
			"aire":
				e.initial_velocity_min = 40
				e.initial_velocity_max = 70
				e.gravity = Vector2.ZERO
				e.tangential_accel_min = 160
				e.tangential_accel_max = 220
				e.radial_accel_min = 30
				e.radial_accel_max = 60
				e.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
				e.emission_sphere_radius = 14
			"neutro":
				e.initial_velocity_min = 90
				e.initial_velocity_max = 110
				e.gravity = Vector2.ZERO
				e.damping_min = 120
				e.damping_max = 160
	add_child(e)
	return e
