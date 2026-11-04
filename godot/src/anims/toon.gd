extends RefCounted

## S35: dresses a character model (a GLB from tools/blender/characters) in
## the drawn look: every lit material becomes toon.gdshader with an outline
## pass (toon_outline.gdshader). Face features (eyes, brows, mouth) get the
## two tones but no outline, which would smear them.

const TOON := preload("res://src/anims/toon.gdshader")
const OUTLINE := preload("res://src/anims/toon_outline.gdshader")
const NO_OUTLINE := ["sclera", "iris", "pupil", "glint", "lash", "brow", "mouth", "eye"]

static var _cache := {}   # source material id -> ShaderMaterial
static var _outlines: Array[ShaderMaterial] = []
## world size of one screen pixel (orthographic camera size / viewport
## height); the outline is width_px of these
static var px_world := 1.0 / 60.8


## Call when the camera zoom or the viewport height changes.
static func set_pixel(size: float) -> void:
	px_world = size
	for o in _outlines:
		o.set_shader_parameter("px_world", size)


static func dress(root: Node) -> void:
	for mi in root.find_children("*", "MeshInstance3D", true, false) + ([root] if root is MeshInstance3D else []):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(s) as BaseMaterial3D
			if src != null and src.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED:
				m.set_surface_override_material(s, material(src))


static func material(src: BaseMaterial3D) -> ShaderMaterial:
	var key := src.get_instance_id()
	if _cache.has(key):
		return _cache[key]
	var t := ShaderMaterial.new()
	t.shader = TOON
	t.set_shader_parameter("albedo", src.albedo_color)
	if src.albedo_texture:
		t.set_shader_parameter("albedo_tex", src.albedo_texture)
		t.set_shader_parameter("has_tex", true)
	if not NO_OUTLINE.has(src.resource_name.get_slice(".", 0)):
		var o := ShaderMaterial.new()
		o.shader = OUTLINE
		o.set_shader_parameter("px_world", px_world)
		_outlines.append(o)
		t.next_pass = o
	_cache[key] = t
	return t
