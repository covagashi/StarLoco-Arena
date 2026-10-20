extends Node2D
## One firework on the lobby sky (S18): the hall's particle show had no world
## to play in, so a 22094 now lands here. Square pixel particles in the
## card's own colour (in 1 bit, content keeps its colour) with a white core.
##
## kind — the card's fwType (dumpcards → cards.json):
##   1 Fairywork  a rocket climbs from the ground, then bursts
##   2 Fountain   a jet from the ground for a couple of seconds
##   0 Explosive  a burst right away, then a white crackle
## The node frees itself when its particles are done.

var kind := 1
var colour := Color.WHITE
var burst_at := Vector2.ZERO   # where it bursts (rocket / explosive)
var ground := Vector2.ZERO     # where it starts (rocket / fountain)

static var _pixel: ImageTexture


static func pixel() -> ImageTexture:
	if _pixel == null:
		var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_pixel = ImageTexture.create_from_image(img)
	return _pixel


func _ready() -> void:
	match kind:
		2:
			_fountain()
		0:
			_burst(burst_at, 110, colour)
			_after(0.45, func(): _burst(burst_at, 40, Color.WHITE, 0.6))
		_:
			_rocket()
	_after(4.0, queue_free)


func _after(secs: float, cb: Callable) -> void:
	get_tree().create_timer(secs).timeout.connect(func():
		if is_instance_valid(self):
			cb.call())


func _particles(amount: int, lifetime: float) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = pixel()
	p.amount = amount
	p.lifetime = lifetime
	p.local_coords = false
	p.scale_amount_min = 1.0
	p.scale_amount_max = 1.6
	# additive: a burst glows over the dithered backdrop instead of greying
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	add_child(p)
	return p


## Full colour for most of the life, then out.
func _fade(c: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, c)
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	g.add_point(0.65, c)
	return g


func _burst(at: Vector2, amount: int, c: Color, scale_v := 1.0) -> void:
	var p := _particles(int(amount * 1.5), 1.7)
	p.position = at
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = 150.0 * scale_v
	p.initial_velocity_max = 260.0 * scale_v
	p.gravity = Vector2(0, 90)
	p.damping_min = 40.0
	p.damping_max = 70.0
	p.color_ramp = _fade(c)
	p.emitting = true
	# the white core every burst has
	var core := _particles(14, 0.5)
	core.position = at
	core.one_shot = true
	core.explosiveness = 1.0
	core.spread = 180.0
	core.initial_velocity_min = 20.0
	core.initial_velocity_max = 60.0
	core.color_ramp = _fade(Color.WHITE)
	core.emitting = true


func _rocket() -> void:
	var trail := _particles(30, 0.4)
	trail.position = ground
	trail.direction = Vector2.DOWN
	trail.spread = 12.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 30.0
	trail.color_ramp = _fade(Color.WHITE)
	trail.emitting = true
	var climb := create_tween()
	climb.tween_property(trail, "position", burst_at, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	climb.tween_callback(func():
		trail.emitting = false
		_burst(burst_at, 90, colour))


func _fountain() -> void:
	var p := _particles(80, 1.3)
	p.position = ground
	p.direction = Vector2.UP
	p.spread = 20.0
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 340.0
	p.gravity = Vector2(0, 380)
	p.color_ramp = _fade(colour)
	p.emitting = true
	_after(2.4, func(): p.emitting = false)
