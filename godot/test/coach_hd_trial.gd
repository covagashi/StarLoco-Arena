extends SceneTree
## S54 (paso 0): the coach-creation screen with the woman as today's 3D
## (the 40k figure) and as an image of the 676k Meshy original, the way the
## menus would show it: the original posed by
## tools/blender/characters/coach_hd_pose.py, rendered once in the
## figure's own viewport (same camera, light and ink) into three layers —
## the colour unlit (with its ink), the light alone (a grey figure: lit
## white goes past 1 and clips) and the skin and hair mask — and tinted in
## 2D: the colour takes the tint as toon.gdshaderinc does, times the light.
## The 40k stops on the same frame of its menu clip, so only the mesh and
## the texture differ.
##
##   xvfb-run -a godot --path godot --resolution 1920x1080 -s test/coach_hd_trial.gd -- \
##       --hd=<posed.glb> --out=<dir> [--combos=s,h;s,h…]
##
## Writes <dir>/40k-s<s>-h<h>.png and <dir>/hd-s<s>-h<h>.png (the whole
## screen) and the layers (<dir>/layer-*.png).

var Creation: GDScript
const Toon := preload("res://src/anims/toon.gd")
const Fighter3D := preload("res://src/anims/fighter3d.gd")

const COMPOSE := """
shader_type canvas_item;
uniform sampler2D light_tex : filter_linear;
uniform sampler2D mask_tex : filter_linear;
uniform vec4 skin_tint = vec4(1.0);
uniform vec4 hair_tint = vec4(1.0);
uniform float skin_ref = 1.0;
uniform float hair_ref = 1.0;

vec3 lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 srgb(vec3 c) { return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }

void fragment() {
	vec4 p = texture(TEXTURE, UV);
	vec2 m = texture(mask_tex, UV).rg;
	vec4 lt = texture(light_tex, UV);
	vec3 c = lin(p.rgb);
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, skin_tint.rgb * min(lum / skin_ref, 1.1), m.r);
	c = mix(c, hair_tint.rgb * min(lum / hair_ref, 1.1), m.g);
	// the light layer is drawn at half (the ink at full: it is unlit)
	p.rgb = srgb(c * mix(vec3(1.0), 2.0 * lin(lt.rgb), lt.a));
	COLOR = p;
}
"""

const FLAT_PASS := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
void fragment() { ALBEDO = texture(albedo_tex, UV).rgb; }
"""

const MASK_PASS := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment() { ALBEDO = COLOR.rgb; }
"""

var _out := "/tmp/s54"
var _creation
var _model: GuiModel


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var hd_path := ""
	var combos := [[1, 0], [1, 3], [3, 0], [3, 3]]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--hd="):
			hd_path = a.trim_prefix("--hd=")
		elif a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--combos="):
			combos = Array(a.trim_prefix("--combos=").split(";")).map(
				func(s): return Array(s.split(",")).map(func(x): return int(x)))
	DirAccess.make_dir_recursive_absolute(_out)
	Creation = load("res://src/ui/creation_screen.gd")
	_model = GuiModel.new()
	_set_look(combos[0][0], combos[0][1])
	var layer := CanvasLayer.new()
	root.add_child(layer)
	_creation = Creation.new()
	layer.add_child(_creation)
	_creation.bind_model(_model)
	await create_timer(2.0).timeout   # its entrance
	var f = _creation._spr.model3d
	var low: Node3D = f._model
	# the same instant of the menu clip on both
	_freeze(f)
	# the original, where the 40k stands
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(hd_path, st) != OK:
		push_error("[coach_hd_trial] can't read " + hd_path)
		quit(1)
		return
	var hd: Node3D = doc.generate_scene(st)
	hd.transform = low.transform
	f._vp.add_child(hd)
	var meshes: Array = hd.find_children("*", "MeshInstance3D", true, false)
	low.visible = false
	var t0 := Time.get_ticks_msec()
	# layer 1: the colour, unlit, with the figure's ink
	Toon.dress(hd, {}, {})
	var flat := Shader.new()
	flat.code = FLAT_PASS
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			var t := mi.get_surface_override_material(s) as ShaderMaterial
			var u := ShaderMaterial.new()
			u.shader = flat
			u.set_shader_parameter("albedo_tex", t.get_shader_parameter("albedo_tex"))
			u.next_pass = t.next_pass
			mi.set_surface_override_material(s, u)
	var lit := await _grab(f)
	# layer 2: the light alone, grey at half (white lit goes past 1 and
	# clips), its ink at half too so the ink comes out untouched
	var half := Color(0.5, 0.5, 0.5).linear_to_srgb()
	var white := ShaderMaterial.new()
	white.shader = Toon.TOON
	white.set_shader_parameter("albedo", half)
	var ink := ShaderMaterial.new()
	ink.shader = Toon.OUTLINE
	ink.set_shader_parameter("px_world", Toon.px_world)
	ink.set_shader_parameter("color", half)
	white.next_pass = ink
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, white)
	var light := await _grab(f)
	# layer 3: the mask (R skin, G hair)
	var mk := ShaderMaterial.new()
	mk.shader = Shader.new()
	mk.shader.code = MASK_PASS
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mk)
	var mask := await _grab(f)
	print("[coach_hd_trial] layers in %d ms, %dx%d" % [Time.get_ticks_msec() - t0, lit.get_width(), lit.get_height()])
	hd.visible = false
	for p in [["lit", lit], ["light", light], ["mask", mask]]:
		p[1].save_png(_out.path_join("layer-%s.png" % p[0]))
		p[1].save_webp(_out.path_join("layer-%s.webp" % p[0]), true, 0.85)
	var mat := ShaderMaterial.new()
	mat.shader = Shader.new()
	mat.shader.code = COMPOSE
	mat.set_shader_parameter("light_tex", ImageTexture.create_from_image(light))
	mat.set_shader_parameter("mask_tex", ImageTexture.create_from_image(mask))
	# the brightness the tint divides by, as coach_masks.py measures it on
	# the 40k's texture (its 80th percentile under each mask), here on the
	# original's colour
	var refs := _refs(lit, mask)
	print("[coach_hd_trial] refs skin %.3f hair %.3f" % [refs.x, refs.y])
	mat.set_shader_parameter("skin_ref", refs.x)
	mat.set_shader_parameter("hair_ref", refs.y)
	var lit_tex := ImageTexture.create_from_image(lit)
	var vp_tex: Texture2D = f._spr.texture
	for c in combos:
		_set_look(c[0], c[1])
		_creation._sync()
		await process_frame
		f = _creation._spr.model3d
		_freeze(f)
		# today's 3D
		f._model.visible = true
		f._spr.texture = vp_tex
		f._spr.material = null
		f._spr.use_parent_material = true
		await _shot("40k-s%d-h%d" % c)
		# the image
		var tints := Fighter3D.coach_tints(c[0], c[1])
		mat.set_shader_parameter("skin_tint", tints.skin.srgb_to_linear())
		mat.set_shader_parameter("hair_tint", tints.hair.srgb_to_linear())
		f._spr.texture = lit_tex
		f._spr.use_parent_material = false
		f._spr.material = mat
		await _shot("hd-s%d-h%d" % c)
	quit(0)


func _refs(lit: Image, mask: Image) -> Vector2:
	var skin: Array[float] = []
	var hair: Array[float] = []
	var r := mask.get_used_rect()
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var m := mask.get_pixel(x, y)
			if m.r < 0.5 and m.g < 0.5:
				continue
			var p := lit.get_pixel(x, y).srgb_to_linear()
			var lum := 0.299 * p.r + 0.587 * p.g + 0.114 * p.b
			(skin if m.r >= 0.5 else hair).append(lum)
	return Vector2(_p80(skin), _p80(hair))


func _p80(a: Array[float]) -> float:
	if a.is_empty():
		return 1.0
	a.sort()
	return a[int(a.size() * 0.8)]


func _set_look(skin: int, hair: int) -> void:
	_model.set_value("localCoach", {"name": "Arel", "level": 1, "sex": 1,
		"skin": skin, "hair": hair, "actorDirection": 3,
		"actorDescriptorLibrary": "coach_7001",
		"actorMaterial": Palettes.coach_tints(skin, hair)})


func _freeze(f) -> void:
	if f._player:
		f._player.play(f._player.current_animation)
		f._player.seek(0.0, true)
		f._player.pause()


func _grab(f) -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return f._vp.get_texture().get_image()


func _shot(name: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var p := _out.path_join(name + ".png")
	root.get_texture().get_image().save_png(p)
	print("[coach_hd_trial] ", p)
