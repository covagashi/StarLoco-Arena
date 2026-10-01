extends Node2D

## Retail spell .xps burst — CPUParticles2D billboard approximating the first
## emitter of sfx.jar particle systems. Full affector/keyframe behaviours from
## the binary (Deformer curves, DirectionFollower, …) are intentionally omitted;
## see tools/asset-import/xps_dump.py for the complete decode matrix.

const INDEX_PATH := "res://assets/gamedata/xps_index.json"
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
static func spawn(parent: Node, xps_id: int, at: Vector2) -> Node2D:
	_ensure()
	var meta: Dictionary = _index.get(str(xps_id), {})
	var tex_id := int(meta.get("textureId", xps_id))
	var dur_ms := int(meta.get("durationMs", 1200))
	var dst_blend := int(meta.get("dstBlend", 771))
	var tex := load("%s/%d.png" % [TEX_DIR, tex_id]) as Texture2D
	if tex == null:
		return null

	var n := Node2D.new()
	n.name = "xps_%d" % xps_id
	n.position = at
	parent.add_child(n)

	var p := CPUParticles2D.new()
	p.name = "particles"
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 0.85
	p.randomness = 0.35
	p.amount = 24
	p.lifetime = clampf(float(dur_ms) / 1000.0 * 0.35, 0.25, 2.5)
	p.speed_scale = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 45.0
	p.gravity = Vector2(0, 120)
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.75
	p.color = Color(1, 1, 1, 0.85)
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
