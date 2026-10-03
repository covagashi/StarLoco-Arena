extends Node2D

## Retail spell .xps burst — one CPUParticles2D per emitter of the sfx.jar
## particle systems (retail stacks 1-14 layers; each keeps its own
## start/endSpawnTime window via _schedule_emit). Ports the three hot
## affectors from the ua_0 update math (ColorFader → lifetime ramp,
## LinearForceEx → accel, FrictionalForce → damping); curves/sub-emitters/
## DirectionFollower/Rebound remain omitted — see
## tools/asset-import/xps_dump.py for the decode matrix.
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



## Build the burst node (unpositioned, not yet in the tree): one
## CPUParticles2D per emitter (retail systems stack 1-14 layers, all
## sharing the doc texture/blend). Meta "free_s" is the auto-free delay
## for plain spawn(); each particle child carries "start_s"/"stop_s"
## metas for its startSpawnTime/endSpawnTime window — _schedule_emit()
## runs them once the node is in the tree. `flying` keeps it emitting
## continuously for a projectile ride.
static func _build(xps_id: int, flying := false) -> Node2D:
	_ensure()
	var doc := _load_doc(xps_id)
	var meta: Dictionary = _index.get(str(xps_id), {})
	if not doc.is_empty():
		meta = doc
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
	if bool(meta.get("behindMobile", false)):
		n.z_index = -8

	var emitters: Array = doc.get("emitters", [])
	if emitters.is_empty():
		emitters = [{}]                    # index-only entry: generic burst
	var tail := float(dur_ms) / 1000.0
	for e in emitters:
		if not (e is Dictionary):
			continue
		var p := _build_emitter(e, tex, dst_blend, int(meta.get("srcBlend", 0)),
			float(dur_ms) / 1000.0, flying)
		n.add_child(p)
		tail = maxf(tail, float(p.get_meta("stop_s")) + p.lifetime)
	if n.get_child_count() == 0:
		return null
	n.set_meta("free_s", tail + 0.15)
	return n


## One emitter → one CPUParticles2D. Spawn window: spawnFrequency is the
## retail interval between spawn ticks (Emitter.b — dnG += dt vs auL);
## start/endSpawnTime bound emission. freq<=0 is a single burst at start.
static func _build_emitter(em: Dictionary, tex: Texture2D, dst_blend: int,
		src_blend: int, dur_s: float, flying: bool) -> CPUParticles2D:
	var life := float(em.get("particleLifeTime", 0.0))
	if life <= 0.0:
		life = clampf(dur_s * 0.35, 0.25, 2.5) if dur_s > 0.0 else 0.5
	else:
		life = clampf(life, 0.08, 4.0)
	var start := maxf(0.0, float(em.get("startSpawnTime", 0.0)))
	var end := float(em.get("endSpawnTime", 0.0))
	if end <= start:
		end = maxf(dur_s, start + life) if dur_s > 0.0 else start + life
	end = minf(end, dur_s + life) if dur_s > 0.0 else end
	var freq := float(em.get("spawnFrequency", 0.0))
	var max_p := int(em.get("maxParticles", 24))
	var mps := int(em.get("maxPerSpawn", 1))

	var p := CPUParticles2D.new()
	p.name = "particles"
	p.randomness = clampf(float(em.get("particleLifeTimeRandom", 0.35)), 0.0, 1.0)
	p.lifetime = life
	p.speed_scale = 1.0
	if flying:
		p.amount = mini(maxi(max_p, 4), 16)
		p.lifetime = clampf(life * 0.5, 0.15, 1.2)
	elif freq > 0.0:
		# continuous stream: amount/lifetime ≈ spawn rate (mps per freq)
		var rate := float(mps) / freq
		p.amount = clampi(int(ceilf(rate * life)), 1, mini(max_p, 96))
	else:
		p.amount = clampi(max_p if max_p > 0 else 24, 4, 128)
		p.one_shot = true
		p.explosiveness = 0.92
	p.emitting = flying or start <= 0.0
	p.set_meta("start_s", 0.0 if flying else start)
	p.set_meta("stop_s", 0.0 if flying else end)

	var vx := float(em.get("velocityX", 0.0))
	var vy := float(em.get("velocityY", 0.0))
	var vz := float(em.get("velocityZ", 0.0))
	var vlen := sqrt(vx * vx + vy * vy + vz * vz)
	var dir := Vector2(vx - vy, (vx + vy) * 0.5 - vz)
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector2(0, -1)
	p.spread = 45.0
	var v0 := maxf(vlen * 43.0, 40.0)          # cells/s → iso px/s
	var vr := (float(em.get("velocityRandX", 0.0))
		+ float(em.get("velocityRandY", 0.0))) * 43.0
	p.initial_velocity_min = maxf(10.0, v0 - vr * 0.5)
	p.initial_velocity_max = v0 + vr
	var ox := float(em.get("offsetX", 0.0))
	var oy := float(em.get("offsetY", 0.0))
	var oz := float(em.get("offsetZ", 0.0))
	p.position = Vector2((ox - oy) * 43.0, (ox + oy) * 21.5 - oz * 10.0)
	var rx := absf(float(em.get("offsetRandX", 0.0)))
	var ry := absf(float(em.get("offsetRandY", 0.0)))
	var rz := absf(float(em.get("offsetRandZ", 0.0)))
	if rx + ry + rz > 0.01:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = Vector2((rx + ry) * 43.0,
			(rx + ry) * 21.5 + rz * 10.0)

	var scale_base := 0.5
	var col := Color.WHITE
	var models: Array = em.get("models", [])
	if not models.is_empty() and models[0] is Dictionary:
		var m: Dictionary = models[0]
		scale_base = clampf(float(m.get("scaleY", 0.5)), 0.05, 2.0)
		col = Color(float(m.get("red", 1.0)), float(m.get("green", 1.0)),
			float(m.get("blue", 1.0)),
			clampf(float(m.get("alpha", 0.85)), 0.05, 1.0))
	p.scale_amount_min = scale_base * 0.6
	p.scale_amount_max = scale_base * 1.2
	p.texture = tex
	_apply_affectors(p, em, col, p.lifetime)
	# GL_ONE / GL_SRC_ALPHA-style pairs → additive glow
	if dst_blend == 771 or src_blend == 1:
		p.material = _additive_mat()
	return p


## Kick the emitters' start/stop windows once `n` is in the tree.
static func _schedule_emit(n: Node2D) -> void:
	if not n.is_inside_tree():
		return
	for p in n.get_children():
		if not (p is CPUParticles2D):
			continue
		var start := float(p.get_meta("start_s", 0.0))
		var stop := float(p.get_meta("stop_s", 0.0))
		if start > 0.0:
			var tree := n.get_tree()
			tree.create_timer(start).timeout.connect(
				func(): if is_instance_valid(p): p.emitting = true)
		if stop > 0.0:
			var tree2 := n.get_tree()
			tree2.create_timer(stop).timeout.connect(
				func(): if is_instance_valid(p): p.emitting = false)


## Spawn a one-shot burst at `at` (screen space). Returns the node (auto-freed).
static func spawn(parent: Node, xps_id: int, at: Vector2) -> Node2D:
	var n := _build(xps_id)
	if n == null:
		return null
	n.position = at
	parent.add_child(n)
	_schedule_emit(n)
	if n.is_inside_tree():
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
		_schedule_emit(body)
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
			for c in get_children():
				for em in c.get_children():
					if em is CPUParticles2D:
						em.emitting = false
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


## Retail affector port (update math from the decompiled ua_0 subclasses):
## - LinearForceEx (lv, tag 8): vel += F * 33 * dt — a constant accel in
##   world cells/s² when `geocentric`, a flat drift otherwise; projected
##   through the iso transform (x-y → screen x, x+y and -z → screen y).
## - FrictionalForce (nt, tag 7): vel *= 1 - (33 - friction) * dt.
## - ColorFader (oo_0, tag 4): c += (target - c) * speed * dt, gated by
##   TimeCondition windows — simulated into a lifetime color ramp.
## Rebound/DirectionFollower/keyframed affectors have no 2D analogue — skipped.
static func _apply_affectors(p: CPUParticles2D, em: Dictionary,
		base: Color, life: float) -> void:
	var accel := Vector3.ZERO
	var damp := 0.0
	var faders: Array = []
	for a in em.get("affectors", []):
		if not (a is Dictionary):
			continue
		match int(a.get("type", 0)):
			7:
				var fr := float(a.get("friction", 0.0))
				damp = 60.0 if fr < 1e-4 else maxf(damp, 33.0 - fr)
			8:
				accel += Vector3(float(a.get("x", 0.0)),
					float(a.get("y", 0.0)), float(a.get("z", 0.0)))
			4:
				var w := Vector2(0.0, 1e9)
				for c in a.get("conditions", []):
					if int(c.get("type", 0)) == 1:
						w = Vector2(float(c.get("minTime", 0.0)),
							float(c.get("maxTime", 1e9)))
				faders.append([Color(float(a.get("r", 0.0)),
						float(a.get("g", 0.0)), float(a.get("b", 0.0)),
						float(a.get("a", 0.0))),
					float(a.get("speed", 1.0)), w])
	var v33 := accel * 33.0                     # retail stores force/33
	p.gravity = Vector2((v33.x - v33.y) * 43.0,
		(v33.x + v33.y) * 21.5 - v33.z * 10.0)
	if damp > 0.0:
		p.damping_min = damp
		p.damping_max = damp
	var ramp := _fader_ramp(faders, base, life)
	if ramp != null:
		p.color = Color.WHITE
		p.color_ramp = ramp


## Simulate the ColorFader chain: boundaries at every window edge; within a
## window the color chases the rate-weighted target exponentially. Emitted
## as a Gradient over the particle lifetime.
static func _fader_ramp(faders: Array, base: Color, life: float) -> Gradient:
	if faders.is_empty():
		return null
	var cuts := {0.0: true, life: true}
	for f in faders:
		var w: Vector2 = f[2]
		for t in [w.x, w.y]:
			if t > 0.0 and t < life:
				cuts[t] = true
	var times: Array = cuts.keys()
	times.sort()
	var grad := Gradient.new()
	grad.remove_point(1)
	grad.set_color(0, base)
	var col := base
	for i in range(times.size() - 1):
		var a: float = times[i]
		var b: float = times[i + 1]
		var mid := (a + b) * 0.5
		var r := 0.0
		var tgt := Color(0, 0, 0, 0)
		for f in faders:
			var w: Vector2 = f[2]
			if mid >= w.x and mid <= w.y:
				var s: float = f[1]
				tgt += (f[0] as Color) * s
				r += s
		if r > 0.0:
			tgt /= r
			col = tgt + (col - tgt) * exp(-r * (b - a))
		grad.add_point(clampf(b / life, 0.0, 1.0), col)
	return grad
