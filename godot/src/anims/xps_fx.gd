extends Node2D

## Retail spell .xps burst — CPUParticles2D billboard approximating the first
## emitter of sfx.jar particle systems. Full affector/keyframe behaviours from
## the binary (Deformer curves, DirectionFollower, …) are intentionally omitted;
## see tools/asset-import/xps_dump.py for the complete decode matrix.
##
## Also covers the script Particle.addTweenParticleSystem projectile: a burst
## riding the retail avw_0 ballistic arc (v0 = sqrt(g*dist/sin 2a), flight
## ms = 2*v0*sin(a)/g * 1000/timeCoef) from caster cell to aimed cell —
## spawn_projectile() returns a node whose `arrived` signal drives the
## script's invoke(time, …) impact scheduling.

const INDEX_PATH := "res://assets/gamedata/xps_index.json"
const DOC_DIR := "res://assets/gamedata/xps"
const TEX_DIR := "res://assets/fx"

const G := 9.81           # avw_0 dhf — projectile gravity (cells/s²)
const ALT_Z := 8.6        # avw_0 — physics-z -> altitude units

static var _index: Dictionary = {}
static var _loaded := false


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(INDEX_PATH):
		return
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(INDEX_PATH))
	if parsed is Dictionary:
		_index = parsed


## Resolve a possibly direction-keyed xps id from spell_fx.json: a plain int
## passes through; {"1":a,"3":b,"5":c,"7":d,"_":def} is picked by the caster's
## Direction8 — the scripts only author the four diagonals (setMobileLookAt
## snaps to 4 dirs), so an even dir tries itself then the adjacent odds,
## then "_" then any authored entry.
static func pick_id(id: Variant, dir8: int) -> int:
	if not (id is Dictionary):
		return int(id)
	var keys: Array = [str(dir8)]
	if dir8 % 2 == 0:
		keys.append(str((dir8 + 1) % 8))
		keys.append(str((dir8 + 7) % 8))
	keys.append("_")
	for k in keys:
		if id.has(k):
			return int(id[k])
	for k in id.keys():
		return int(id[k])
	return 0


static func _load_doc(xps_id: int) -> Dictionary:
	var path := "%s/%d.json" % [DOC_DIR, xps_id]
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func _first_emitter(doc: Dictionary) -> Dictionary:
	var emitters: Array = doc.get("emitters", [])
	if emitters.is_empty():
		return {}
	var em: Variant = emitters[0]
	return em if em is Dictionary else {}


## Build the burst node (unpositioned, not yet in the tree). Meta "free_s" is
## the auto-free delay for plain spawn(); "particles" is the CPUParticles2D.
## `flying` keeps it emitting continuously for a projectile ride.
static func _build(xps_id: int, flying := false) -> Node2D:
	_ensure()
	var doc := _load_doc(xps_id)
	var meta: Dictionary = _index.get(str(xps_id), {})
	if not doc.is_empty():
		meta = doc
	var em := _first_emitter(doc)
	var tex_id := int(meta.get("textureId", xps_id))
	if tex_id == 0 and bool(meta.get("compactHeader", false)):
		tex_id = xps_id
	var dur_ms := int(meta.get("durationMs", 1200))
	var dst_blend := int(meta.get("dstBlend", 771))
	var tex := load("%s/%d.png" % [TEX_DIR, tex_id]) as Texture2D
	if tex == null:
		return null

	var n := Node2D.new()
	n.name = "xps_%d" % xps_id

	var max_p := int(em.get("maxParticles", 24))
	var life := float(em.get("particleLifeTime", 0.0))
	if life <= 0.0:
		life = clampf(float(dur_ms) / 1000.0 * 0.35, 0.25, 2.5)
	else:
		life = clampf(life, 0.08, 4.0)
	var freq := float(em.get("spawnFrequency", 0.0))
	var amount := clampi(max_p if max_p > 0 else 24, 4, 128)
	var explos := 0.92 if freq <= 0.0 else clampf(1.0 - freq * 4.0, 0.15, 0.95)
	var vx := float(em.get("velocityX", 0.0))
	var vy := float(em.get("velocityY", 0.0))
	var vlen := sqrt(vx * vx + vy * vy)
	var dir := Vector2(vx, vy).normalized() if vlen > 0.01 else Vector2(0, -1)
	var scale_base := 0.5
	var models: Array = em.get("models", [])
	if not models.is_empty() and models[0] is Dictionary:
		scale_base = clampf(float(models[0].get("scaleY", 0.5)), 0.05, 2.0)

	var p := CPUParticles2D.new()
	p.name = "particles"
	p.one_shot = not flying
	p.emitting = true
	p.explosiveness = explos if not flying else 0.0
	if flying:
		amount = mini(amount, 16)
		life = clampf(life * 0.5, 0.15, 1.2)
	p.randomness = clampf(float(em.get("particleLifeTimeRandom", 0.35)), 0.0, 1.0)
	p.amount = amount
	p.lifetime = life
	p.speed_scale = 1.0
	p.direction = dir
	p.spread = 45.0
	p.gravity = Vector2(0, 120)
	var v0 := maxf(vlen, 40.0)
	var vr := float(em.get("velocityRandX", 0.0)) + float(em.get("velocityRandY", 0.0))
	p.initial_velocity_min = maxf(10.0, v0 - vr * 0.5)
	p.initial_velocity_max = v0 + vr
	p.scale_amount_min = scale_base * 0.6
	p.scale_amount_max = scale_base * 1.2
	var col := Color.WHITE
	if not models.is_empty() and models[0] is Dictionary:
		var m: Dictionary = models[0]
		col = Color(
			float(m.get("red", 1.0)),
			float(m.get("green", 1.0)),
			float(m.get("blue", 1.0)),
			clampf(float(m.get("alpha", 0.85)), 0.05, 1.0))
	p.color = col
	p.texture = tex
	# GL_ONE / GL_SRC_ALPHA-style pairs → additive glow
	if dst_blend == 771 or int(meta.get("srcBlend", 0)) == 1:
		p.material = _additive_mat()
	n.add_child(p)
	n.set_meta("free_s", maxf(p.lifetime + 0.15, float(dur_ms) / 1000.0))
	return n


## Spawn a one-shot burst at `at` (screen space). Returns the node (auto-freed).
static func spawn(parent: Node, xps_id: int, at: Vector2) -> Node2D:
	var n := _build(xps_id)
	if n == null:
		return null
	n.position = at
	parent.add_child(n)
	n.get_tree().create_timer(float(n.get_meta("free_s"))).timeout.connect(
		n.queue_free)
	return n


## Ballistic projectile — the script's addTweenParticleSystem: the system id
## flies the avw_0 arc from cell `from` to cell `to` (x/y in cells, z in
## altitude units) over `dur = 2*v0*sin(a)/g / coef` seconds. `project` maps
## (worldX, worldY, altitude) -> screen position (fight_view._iso).
## Connect `arrived` for the script's invoke(time, …) impact events — it
## fires even when the texture is missing so scheduling stays faithful.
static func spawn_projectile(parent: Node, xps_id: int, from: Vector3,
		to: Vector3, angle_deg: float, coef: float,
		project: Callable) -> Node2D:
	var p := _Projectile.new()
	p.name = "xps_tween_%d" % xps_id
	p.setup(from, to, angle_deg, coef, project)
	parent.add_child(p)
	var body := _build(xps_id, true)
	if body != null:
		body.position = Vector2.ZERO
		p.add_child(body)
		p.set_meta("tail_s", float(body.get_meta("free_s")) * 0.5)
	p.position = project.call(from.x, from.y, from.z)
	return p


class _Projectile:
	extends Node2D
	## avw_0 port — sim time advances coef× real time (IP * dhe / 1000).

	signal arrived

	var _from := Vector3.ZERO
	var _to := Vector3.ZERO
	var _az := Vector2.ZERO      # horizontal unit vector, cell space
	var _v0 := 0.0
	var _sin := 0.0              # sin/cos of the launch angle
	var _cos := 1.0
	var _dur := 0.0              # sim-seconds total (dhl)
	var _coef := 1.0
	var _sim := 0.0
	var _project: Callable
	var _done := false


	func setup(from: Vector3, to: Vector3, angle_deg: float, coef: float,
			project: Callable) -> void:
		_from = from
		_to = to
		_project = project
		_coef = coef if coef > 0.0 else 1.0
		var d := Vector2(to.x - from.x, to.y - from.y)
		var dist := d.length()
		if dist > 0.0:
			_az = d / dist
		var th := deg_to_rad(angle_deg if angle_deg != 0.0 else 1.0)
		_sin = sin(th)
		_cos = cos(th)
		var s2 := sin(2.0 * th)
		if dist <= 0.0 or s2 <= 0.0:
			_dur = 0.0
			return
		_v0 = sqrt(G * dist / s2)
		_dur = 2.0 * _v0 * _sin / G
		set_meta("duration_s", _dur / _coef)


	func _process(dt: float) -> void:
		if _done:
			return
		_sim += dt * _coef
		if _sim >= _dur:
			_done = true
			position = _project.call(_to.x, _to.y, _to.z)
			arrived.emit()
			set_process(false)
			var tail := float(get_meta("tail_s", 0.6))
			var particles := find_child("particles", true, false)
			if particles != null:
				particles.emitting = false
			if is_inside_tree():
				get_tree().create_timer(minf(tail, 1.5)).timeout.connect(
					queue_free)
			return
		var wx := _from.x + _az.x * _v0 * _cos * _sim
		var wy := _from.y + _az.y * _v0 * _cos * _sim
		var z := -G * 0.5 * _sim * _sim + _v0 * _sin * _sim
		var alt := ALT_Z * z + _from.z + \
			_sim * (_to.z - _from.z) / _dur
		position = _project.call(wx, wy, alt)


static func _additive_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
