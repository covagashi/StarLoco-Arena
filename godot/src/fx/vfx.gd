extends RefCounted

## S37: the fight's own effect library. A spell is drawn from a recipe —
## shape + element + intensity (dumpspells/vfx.go → spells.json "fx") —
## instead of a per-spell animation:
##
##   bolt    a shot flies caster → cell, bursts on landing
##   hit     a burst on the target (melee)
##   area    a ring over the zone, the burst on every cell of it
##   aura    a ring at the feet, motes rising round the target (buffs)
##   curse   motes sinking into the target (debuffs, AP/MP loss)
##   heal    green-gold crosses rising, a soft ring
##   summon  a growing ground circle, then a puff
##   trap    a glyph on the zone's cells that flares and fades
##   tp      an implosion at the caster, a burst at the cell
##
## The element sets the colours and how particles move: fire rises,
## earth falls in chunks, water drips, air swirls, neutral spreads.
## Everything is drawn here (no image files): CPUParticles2D, which the
## Compatibility renderer and the web demo's 2 GB phones run, and small
## _draw() rings. Each spawned node frees itself when it's done.

const HW := 43.0    # half a cell, screen px (fight_view._iso)
const HH := 21.5

const SHAPES := ["bolt", "hit", "area", "aura", "curse", "heal", "summon", "trap", "tp"]
const ELEMS := ["neutral", "fire", "earth", "water", "air"]

## Per element: c = colour ramp (core, body, fade), g = gravity px/s²,
## add = additive glow, swirl = tangential accel, tex = particle texture.
const ELEM := {
	"neutral": {"c": [Color(1.0, 1.0, 0.94), Color(1.0, 0.86, 0.55), Color(0.75, 0.65, 0.5, 0.0)],
		"g": 0.0, "add": true, "swirl": 0.0, "tex": "spark"},
	"fire": {"c": [Color(1.0, 0.97, 0.7), Color(1.0, 0.5, 0.08), Color(0.55, 0.06, 0.02, 0.0)],
		"g": -170.0, "add": true, "swirl": 0.0, "tex": "dot"},
	"earth": {"c": [Color(0.93, 0.82, 0.58), Color(0.58, 0.42, 0.24), Color(0.32, 0.24, 0.14, 0.0)],
		"g": 560.0, "add": false, "swirl": 0.0, "tex": "chunk"},
	"water": {"c": [Color(0.92, 1.0, 1.0), Color(0.32, 0.72, 1.0), Color(0.06, 0.22, 0.62, 0.0)],
		"g": 320.0, "add": true, "swirl": 0.0, "tex": "spark"},
	"air": {"c": [Color(1.0, 1.0, 1.0), Color(0.62, 1.0, 0.82), Color(0.3, 0.7, 0.62, 0.0)],
		"g": -30.0, "add": true, "swirl": 280.0, "tex": "dot"},
}
const HEAL := [Color(1.0, 1.0, 0.85), Color(0.55, 1.0, 0.45), Color(0.9, 0.85, 0.3, 0.0)]
const CURSE_TINT := Color(0.55, 0.3, 0.85)

static var _tex := {}
static var _mat_add: CanvasItemMaterial


## Draw one spell. `from` / `to` are the caster's and the aimed cell's
## screen points (feet), `cells` the zone's cell centres for area / trap
## (empty = one cell round `to`). Returns the seconds until the effect
## lands on `to`, for callers that time a hit on it.
static func play(parent: Node2D, recipe: Dictionary, from: Vector2, to: Vector2,
		cells: PackedVector2Array = PackedVector2Array()) -> float:
	var shape := str(recipe.get("s", "hit"))
	var elem := str(recipe.get("e", "neutral"))
	if not ELEM.has(elem):
		elem = "neutral"
	var k := clampi(int(recipe.get("k", 1)), 1, 3)
	var z := int(recipe.get("z", 0))
	if cells.is_empty():
		cells = zone_cells(to, z)
	var root := Node2D.new()
	root.z_index = 20
	parent.add_child(root)
	_free_after(root, 3.0)
	match shape:
		"bolt":
			return _bolt(root, elem, k, from, to)
		"area":
			_area(root, elem, k, to, cells, z)
		"aura":
			_aura(root, elem, k, to)
		"curse":
			_curse(root, elem, k, to)
		"heal":
			_heal(root, k, to)
		"summon":
			_summon(root, elem, k, to)
		"trap":
			_trap(root, elem, k, to, cells)
		"tp":
			return _tp(root, elem, k, from, to)
		_:
			_impact(root, elem, k, to, from)
	return 0.0


## Cell centres of a circle of `z` cells round `at` (screen space), the
## spells' most common zone; the fight passes the real zone when it has it.
static func zone_cells(at: Vector2, z: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for dx in range(-z, z + 1):
		for dy in range(-z, z + 1):
			if absi(dx) + absi(dy) <= z:
				out.append(at + Vector2((dx - dy) * HW, (dx + dy) * HH))
	return out


# --- shapes ----------------------------------------------------------------

static func _impact(root: Node2D, elem: String, k: int, at: Vector2, from: Vector2) -> void:
	var e: Dictionary = ELEM[elem]
	var up := at + Vector2(0, -34)
	_flash(root, up, e.c[1], 34.0 + 10.0 * k, 0.22)
	var away := (at - from).normalized() if from.distance_to(at) > 1.0 else Vector2.UP
	var p := _particles(root, up, e.c, e.tex, 14 + 8 * k, 0.55, e.add)
	p.direction = (away + Vector2(0, -0.6)).normalized()
	p.spread = 70.0
	p.initial_velocity_min = 90.0 + 30.0 * k
	p.initial_velocity_max = 180.0 + 50.0 * k
	p.gravity = Vector2(0, e.g * 0.6 + 120.0)
	p.damping_min = 60.0
	p.damping_max = 120.0
	_elem_motion(p, elem)
	_ring(root, at, e.c[1], 8.0, HW * (0.7 + 0.15 * k), 0.4, 3.0)
	if elem == "earth":
		_dust(root, at, k)


static func _bolt(root: Node2D, elem: String, k: int, from: Vector2, to: Vector2) -> float:
	var e: Dictionary = ELEM[elem]
	var a := from + Vector2(0, -40)
	var b := to + Vector2(0, -34)
	var dur := 0.16 + a.distance_to(b) / 900.0
	_flash(root, a, e.c[1], 20.0 + 4.0 * k, 0.15)
	var bolt := Bolt.new()
	bolt.from = a
	bolt.to = b
	bolt.dur = dur
	bolt.arc = clampf(a.distance_to(b) * 0.18, 6.0, 60.0) if elem == "earth" else \
		clampf(a.distance_to(b) * 0.06, 0.0, 24.0)
	root.add_child(bolt)
	var core := _sprite(bolt, Vector2.ZERO, "dot", e.c[0], 0.5 + 0.12 * k, e.add or elem == "earth")
	if elem == "earth":
		core.texture = tex("chunk")
		core.modulate = e.c[1]
		core.scale = Vector2.ONE * (1.1 + 0.25 * k)
	var glow := _sprite(bolt, Vector2.ZERO, "dot", e.c[1], 0.9 + 0.2 * k, true)
	glow.modulate.a = 0.55 if elem != "earth" else 0.0
	var trail := _particles(bolt, Vector2.ZERO, e.c, "dot", 26 + 8 * k, 0.35, e.add)
	trail.one_shot = false
	trail.explosiveness = 0.0
	trail.local_coords = false
	trail.initial_velocity_min = 4.0
	trail.initial_velocity_max = 20.0
	trail.spread = 180.0
	trail.gravity = Vector2(0, e.g * 0.25)
	trail.scale_amount_min = 0.25
	trail.scale_amount_max = 0.45 + 0.08 * k
	if elem == "air":
		trail.tangential_accel_min = -e.swirl
		trail.tangential_accel_max = e.swirl
	bolt.arrived.connect(func() -> void:
		trail.emitting = false
		core.visible = false
		glow.visible = false
		_impact(root, elem, k, to, from))
	return dur


static func _area(root: Node2D, elem: String, k: int, at: Vector2,
		cells: PackedVector2Array, z: int) -> void:
	var e: Dictionary = ELEM[elem]
	var r := HW * (z + 0.6)
	_ring(root, at, e.c[1], r * 0.2, r, 0.55, 4.0)
	_ring(root, at, e.c[0], r * 0.1, r * 0.75, 0.4, 2.0, 0.08)
	_flash(root, at + Vector2(0, -20), e.c[1], 40.0 + 14.0 * z + 8.0 * k, 0.3)
	var p := _particles(root, Vector2.ZERO, e.c, e.tex, mini(14 + 6 * cells.size() + 6 * k, 70),
		0.7, e.add)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = cells
	p.direction = Vector2.UP
	p.spread = 35.0
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 170.0 + 30.0 * k
	p.gravity = Vector2(0, e.g * 0.7 + 200.0)
	p.explosiveness = 0.8
	_elem_motion(p, elem)
	if elem == "earth":
		for c in cells:
			_dust(root, c, 1)


static func _aura(root: Node2D, elem: String, k: int, at: Vector2) -> void:
	var e: Dictionary = ELEM[elem]
	_ring(root, at, e.c[1], HW * 0.9, HW * 0.6, 1.1, 3.0, 0.0, true)
	var col := _sprite(root, at + Vector2(0, -36), "dot", e.c[1], 1.0, true)
	col.scale = Vector2(0.9, 2.6)
	col.modulate.a = 0.0
	var tw := col.create_tween()
	tw.tween_property(col, "modulate:a", 0.35, 0.2)
	tw.tween_property(col, "modulate:a", 0.0, 0.8)
	var p := _particles(root, at, e.c, "dot", 16 + 6 * k, 0.9, true)
	p.one_shot = true
	p.explosiveness = 0.15
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RING
	p.emission_ring_radius = HW * 0.7
	p.emission_ring_inner_radius = HW * 0.5
	p.scale = Vector2(1, 0.5)
	p.direction = Vector2.UP
	p.spread = 10.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 130.0
	p.gravity = Vector2(0, -60.0)
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.6
	if elem == "air":
		p.tangential_accel_min = 120.0
		p.tangential_accel_max = 200.0


static func _curse(root: Node2D, elem: String, k: int, at: Vector2) -> void:
	var e: Dictionary = ELEM[elem]
	var c: Array = [e.c[0].lerp(CURSE_TINT, 0.5), e.c[1].lerp(CURSE_TINT, 0.6),
		Color(0.15, 0.05, 0.25, 0.0)]
	_ring(root, at, c[1], HW * 0.5, HW * 1.0, 0.8, 3.0, 0.0, true)
	var p := _particles(root, at + Vector2(0, -70), c, "dot", 14 + 6 * k, 0.75, false)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 34.0
	p.explosiveness = 0.3
	p.direction = Vector2.DOWN
	p.spread = 15.0
	p.initial_velocity_min = 20.0
	p.initial_velocity_max = 50.0
	p.gravity = Vector2(0, 140.0)
	p.radial_accel_min = -90.0
	p.radial_accel_max = -60.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.6
	_flash(root, at + Vector2(0, -30), c[1], 26.0, 0.5, 0.35)


static func _heal(root: Node2D, k: int, at: Vector2) -> void:
	_ring(root, at, HEAL[1], HW * 0.3, HW * 0.9, 0.8, 3.0)
	_flash(root, at + Vector2(0, -34), HEAL[1], 34.0, 0.45, 0.5)
	var p := _particles(root, at + Vector2(0, -20), HEAL, "plus", 8 + 4 * k, 1.0, true)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 22.0
	p.explosiveness = 0.4
	p.direction = Vector2.UP
	p.spread = 12.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 80.0
	p.gravity = Vector2(0, -30.0)
	p.scale_amount_min = 0.55
	p.scale_amount_max = 0.9


static func _summon(root: Node2D, elem: String, k: int, at: Vector2) -> void:
	var e: Dictionary = ELEM[elem]
	var glyph := Glyph.new()
	glyph.position = at
	glyph.color = e.c[1]
	glyph.cells = PackedVector2Array()
	glyph.radius = HW * 0.95
	glyph.dur = 0.9
	root.add_child(glyph)
	var puff := func() -> void:
		_flash(root, at + Vector2(0, -30), e.c[0], 46.0, 0.35)
		var p := _particles(root, at, [Color(1, 1, 1, 0.9), e.c[1].lerp(Color.WHITE, 0.4),
			Color(0.7, 0.7, 0.75, 0.0)], "dot", 18 + 6 * k, 0.8, false)
		p.direction = Vector2.UP
		p.spread = 60.0
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 110.0
		p.gravity = Vector2(0, -40.0)
		p.damping_min = 40.0
		p.damping_max = 80.0
		p.scale_amount_min = 0.7
		p.scale_amount_max = 1.3
	root.get_tree().create_timer(0.45).timeout.connect(puff)


static func _trap(root: Node2D, elem: String, k: int, at: Vector2,
		cells: PackedVector2Array) -> void:
	var e: Dictionary = ELEM[elem]
	var glyph := Glyph.new()
	glyph.position = at
	glyph.color = e.c[1]
	glyph.radius = HW * 0.6
	glyph.dur = 1.6
	var rel := PackedVector2Array()
	for c in cells:
		rel.append(c - at)
	glyph.cells = rel
	root.add_child(glyph)
	var p := _particles(root, Vector2.ZERO, e.c, "spark", mini(6 + 4 * cells.size() + 4 * k, 40),
		0.5, e.add)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_POINTS
	p.emission_points = cells
	p.direction = Vector2.UP
	p.spread = 25.0
	p.explosiveness = 0.2
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.gravity = Vector2(0, 60.0)
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.45


static func _tp(root: Node2D, elem: String, k: int, from: Vector2, to: Vector2) -> float:
	var e: Dictionary = ELEM[elem]
	var c: Array = [Color(1, 1, 1), e.c[1].lerp(Color(0.7, 0.85, 1.0), 0.5), Color(0.5, 0.6, 1.0, 0.0)]
	var p := _particles(root, from + Vector2(0, -34), c, "dot", 16 + 4 * k, 0.3, true)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 40.0
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 0.0
	p.gravity = Vector2.ZERO
	p.radial_accel_min = -900.0
	p.radial_accel_max = -700.0
	p.scale_amount_min = 0.3
	p.scale_amount_max = 0.5
	_flash(root, from + Vector2(0, -34), c[1], 30.0, 0.3)
	var arrive := func() -> void:
		_flash(root, to + Vector2(0, -34), c[0], 40.0, 0.3)
		_ring(root, to, c[1], 6.0, HW * 0.9, 0.4, 3.0)
		var q := _particles(root, to + Vector2(0, -34), c, "spark", 14 + 4 * k, 0.45, true)
		q.initial_velocity_min = 100.0
		q.initial_velocity_max = 200.0
		q.damping_min = 120.0
		q.damping_max = 200.0
	root.get_tree().create_timer(0.28).timeout.connect(arrive)
	return 0.28


# --- building blocks ---------------------------------------------------------

## A one-shot burst; callers tweak the motion after.
static func _particles(parent: Node2D, at: Vector2, ramp: Array, texture: String,
		amount: int, life: float, additive: bool) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.position = at
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.randomness = 0.4
	p.lifetime_randomness = 0.35
	p.texture = tex(texture)
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.7
	var g := Gradient.new()
	g.set_color(0, ramp[0])
	g.set_color(1, ramp[2])
	g.add_point(0.3, ramp[1])
	p.color_ramp = g
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.25))
	p.scale_amount_curve = curve
	if texture == "spark":
		p.particle_flag_align_y = true
	if texture == "chunk":
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.angle_min = 0.0
		p.angle_max = 360.0
	if additive:
		p.material = _additive()
	parent.add_child(p)
	p.emitting = true
	return p


static func _elem_motion(p: CPUParticles2D, elem: String) -> void:
	match elem:
		"fire":
			p.scale_amount_max *= 1.3
		"air":
			p.tangential_accel_min = 200.0
			p.tangential_accel_max = ELEM.air.swirl
			p.damping_min = 80.0
			p.damping_max = 140.0
		"earth":
			p.scale_amount_min = 0.6
			p.scale_amount_max = 1.1


## A puff of dust hugging the floor (earth).
static func _dust(parent: Node2D, at: Vector2, k: int) -> void:
	var p := _particles(parent, at, [Color(0.85, 0.78, 0.62, 0.7), Color(0.7, 0.62, 0.48, 0.5),
		Color(0.6, 0.55, 0.45, 0.0)], "dot", 6 + 3 * k, 0.7, false)
	p.scale = Vector2(1, 0.5)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.damping_min = 50.0
	p.damping_max = 90.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3


static func _flash(parent: Node2D, at: Vector2, color: Color, size: float, dur: float,
		alpha := 0.85) -> void:
	var s := _sprite(parent, at, "dot", color, size / 16.0, true)
	s.modulate.a = alpha
	var tw := s.create_tween()
	tw.set_parallel(true)
	tw.tween_property(s, "scale", s.scale * 1.5, dur)
	tw.tween_property(s, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(s.queue_free)


static func _ring(parent: Node2D, at: Vector2, color: Color, r0: float, r1: float, dur: float,
		width: float, delay := 0.0, hold := false) -> void:
	var r := Ring.new()
	r.position = at
	r.color = color
	r.r0 = r0
	r.r1 = r1
	r.dur = dur
	r.width = width
	r.delay = delay
	r.hold = hold
	parent.add_child(r)


static func _sprite(parent: Node2D, at: Vector2, texture: String, color: Color, s: float,
		additive: bool) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.texture = tex(texture)
	sp.position = at
	sp.modulate = color
	sp.scale = Vector2.ONE * s
	if additive:
		sp.material = _additive()
	parent.add_child(sp)
	return sp


static func _additive() -> CanvasItemMaterial:
	if _mat_add == null:
		_mat_add = CanvasItemMaterial.new()
		_mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return _mat_add


static func _free_after(n: Node, secs: float) -> void:
	n.get_tree().create_timer(secs).timeout.connect(n.queue_free)


## The particle textures, drawn once: a soft dot, a streak (spark), an
## earth chunk and a heal cross. All white, tinted by the colour ramp.
static func tex(name: String) -> Texture2D:
	if _tex.has(name):
		return _tex[name]
	var img: Image
	match name:
		"spark":
			img = _soft(10, 30)
		"chunk":
			img = Image.create(12, 12, false, Image.FORMAT_RGBA8)
			for y in 12:
				for x in 12:
					var edge := x == 0 or y == 0 or x == 11 or y == 11
					var corner := (x < 2 or x > 9) and (y < 2 or y > 9)
					if corner:
						continue
					var v := 1.0 - 0.35 * float(y) / 11.0
					img.set_pixel(x, y, Color(v, v, v, 0.75 if edge else 1.0))
		"plus":
			img = Image.create(24, 24, false, Image.FORMAT_RGBA8)
			for y in 24:
				for x in 24:
					var arm := (absi(x - 12) <= 3 and absi(y - 12) <= 10) \
						or (absi(y - 12) <= 3 and absi(x - 12) <= 10)
					if arm:
						var d := maxf(absf(x - 11.5), absf(y - 11.5)) / 11.0
						img.set_pixel(x, y, Color(1, 1, 1, 1.0 - 0.5 * d))
		_:
			img = _soft(32, 32)
	var t := ImageTexture.create_from_image(img)
	_tex[name] = t
	return t


static func _soft(w: int, h: int) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (x + 0.5 - w * 0.5) / (w * 0.5)
			var dy := (y + 0.5 - h * 0.5) / (h * 0.5)
			var d := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return img


# --- drawn pieces --------------------------------------------------------------

## A ring on the floor (an iso ellipse) growing r0 → r1 and fading out;
## `hold` keeps it up for most of its time first (auras).
class Ring extends Node2D:
	var color := Color.WHITE
	var r0 := 0.0
	var r1 := 40.0
	var dur := 0.5
	var width := 3.0
	var delay := 0.0
	var hold := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= delay + dur:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := clampf((_t - delay) / dur, 0.0, 1.0)
		if _t < delay:
			return
		var ease_t := 1.0 - pow(1.0 - t, 3.0)
		var r := lerpf(r0, r1, ease_t)
		var a := (1.0 - t) if not hold else clampf((1.0 - t) * 4.0, 0.0, 1.0)
		var c := color
		c.a *= a
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, width * 2.0, true)
		var inner := c
		inner.a *= 0.18
		draw_circle(Vector2.ZERO, r, inner)


## A summoning circle / trap glyph: the zone's cell diamonds outlined, a
## double ring with ticks turning slowly, fading in then out.
class Glyph extends Node2D:
	var color := Color.WHITE
	var cells := PackedVector2Array()
	var radius := 40.0
	var dur := 1.2
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		if _t >= dur:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var t := _t / dur
		var a := clampf(t * 5.0, 0.0, 1.0) * clampf((1.0 - t) * 3.0, 0.0, 1.0)
		var c := color
		c.a *= a
		for p in cells:
			var d := PackedVector2Array([p + Vector2(0, -HH * 0.86), p + Vector2(HW * 0.86, 0),
				p + Vector2(0, HH * 0.86), p + Vector2(-HW * 0.86, 0), p + Vector2(0, -HH * 0.86)])
			var fill := c
			fill.a *= 0.22
			draw_colored_polygon(d.slice(0, 4), fill)
			draw_polyline(d, c, 2.0, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.5))
		var r := radius * (0.6 + 0.4 * minf(t * 3.0, 1.0))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, c, 4.0, true)
		draw_arc(Vector2.ZERO, r * 0.78, 0.0, TAU, 40, c, 2.0, true)
		var spin := _t * 1.6
		for i in 6:
			var ang := spin + TAU * i / 6.0
			var dir := Vector2(cos(ang), sin(ang))
			draw_line(dir * r * 0.78, dir * r, c, 3.0, true)
		var tri := PackedVector2Array()
		for i in 4:
			var ang := -spin + TAU * (i % 3) / 3.0
			tri.append(Vector2(cos(ang), sin(ang)) * r * 0.74)
		draw_polyline(tri, c, 2.0, true)


## The bolt's body: flies from → to in `dur` along a little arc, then
## signals and lets its trail die out.
class Bolt extends Node2D:
	signal arrived
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var dur := 0.3
	var arc := 0.0
	var _t := 0.0
	var _done := false

	func _ready() -> void:
		position = from

	func _process(delta: float) -> void:
		if _done:
			return
		_t += delta
		var t := clampf(_t / dur, 0.0, 1.0)
		position = from.lerp(to, t) + Vector2(0, -arc * 4.0 * t * (1.0 - t))
		if t >= 1.0:
			_done = true
			arrived.emit()
