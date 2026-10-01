extends Node2D

## Retail spell .xps burst — CPUParticles2D billboard approximating the first
## emitter of sfx.jar particle systems. Full affector/keyframe behaviours from
## the binary (Deformer curves, DirectionFollower, …) are intentionally omitted;
## see tools/asset-import/xps_dump.py for the complete decode matrix.

const INDEX_PATH := "res://assets/gamedata/xps_index.json"
const DOC_DIR := "res://assets/gamedata/xps"
const TEX_DIR := "res://assets/fx"

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


## Spawn a one-shot burst at `at` (screen space). Returns the node (auto-freed).
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


static func spawn(parent: Node, xps_id: int, at: Vector2) -> Node2D:
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
	n.position = at
	parent.add_child(n)

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
	p.one_shot = true
	p.emitting = true
	p.explosiveness = explos
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

	var wait := maxf(p.lifetime + 0.15, float(dur_ms) / 1000.0)
	n.get_tree().create_timer(wait).timeout.connect(n.queue_free)
	return n


static func _additive_mat() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m
