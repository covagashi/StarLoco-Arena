extends SceneTree
## S54 (paso 4): the menus' picture of a coach, in layers, from its full
## Meshy original posed by tools/blender/characters/coach_hd_pose.py: front
## on and level (the owner's hub references), in the figure's own light and
## ink (the game's sun, turned with the camera as for Direction8.FRONT).
##
##   xvfb-run -a godot --path godot -s tools/art/coach_portrait.gd -- \
##       --coach=coach_7001 --hd=<posed.glb> --out=<dir> [--frame=thigh|whole] [--px=900]
##       [--pieces=all|<piece>,<piece>]
##
## Writes into <dir>/<coach>/<frame>/:
##   body_lit.webp    the body's colour, unlit, with its ink
##   body_light.webp  the light alone (a grey figure at half: lit white clips)
##   body_mask.webp   R skin, G hair (lossless)
##   <piece>.webp     each piece the coach can wear (art/equipment/pieces.json
##                    "coach"), lit as in the game, without what the body hides
##   index.json       the canvas, each layer's rect in it, the foot point, the
##                    tint's reference brightness (as coach_masks.py measures)
## CoachPortrait (src/ui/coach_portrait.gd) puts them back together and tints.

const Fighter3D := preload("res://src/anims/fighter3d.gd")
const Toon := preload("res://src/anims/toon.gd")

## The rows each framing shows, in metres (the figure is 1.45 high, feet at
## 0): "thigh" from mid-thigh up (the lobby and the creation), "whole" the
## lot (Equipo del coach). Both leave room for a hat and a banner on top.
const FRAMES := {"thigh": [0.42, 2.05], "whole": [-0.05, 2.05]}
const WIDTH := 1.9   # a cape's or a pet's reach on either side

const FLAT := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
void fragment() { ALBEDO = texture(albedo_tex, UV).rgb; }
"""

const MASK := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
void fragment() { ALBEDO = COLOR.rgb; }
"""

## A piece's matte: the piece white, the body black. The body there is
## the built figure, not the original: the pieces were made for it (the
## garments are its own faces pushed out), and the original's skin, a
## little outside it, would poke through them.
const MATTE := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec3 c = vec3(1.0);
void fragment() { ALBEDO = c; }
"""

var _f
var _vp: SubViewport
var _hd: Node3D
var _body: MeshInstance3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var coach := "coach_7001"
	var hd_path := ""
	var out := "/tmp/coach_portrait"
	var frame := "thigh"
	var px := 900.0
	var only := "all"
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"coach": coach = kv[1]
			"hd": hd_path = kv[1]
			"out": out = kv[1]
			"frame": frame = kv[1]
			"px": px = float(kv[1])
			"pieces": only = kv[1]
	var dir := out.path_join(coach).path_join(frame)
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "res://art/" + Fighter3D.MODEL_DIR % coach
	_f = Fighter3D.create(path, {}, 1.0, 1.0)
	if _f == null:
		return _fail("can't build " + path)
	root.add_child(_f)
	_vp = _f._vp
	var rows: Array = FRAMES[frame]
	var h: float = rows[1] - rows[0]
	_vp.size = Vector2i(roundi(WIDTH * px), roundi(h * px))
	Toon.set_pixel(1.0 / px)
	var cam: Camera3D = _vp.find_children("*", "Camera3D", false, false)[0]
	cam.size = h
	cam.rotation_degrees = Vector3(0, 45, 0)
	cam.position = cam.transform.basis.z * 20.0 + Vector3(0, (rows[0] + rows[1]) / 2.0, 0)
	var model: Node3D = _f._model
	_f._dir = 2   # Direction8.FRONT (the figure turns its model to it each frame)
	_f._face()
	_freeze()
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null:
			_body = mi
			break
	# the original, where the built figure stands
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(hd_path, st) != OK:
		return _fail("can't read " + hd_path)
	_hd = doc.generate_scene(st)
	model.add_sibling(_hd)
	_hd.transform = model.transform
	_body.visible = false
	var t0 := Time.get_ticks_msec()
	var index := {"canvas": [_vp.size.x, _vp.size.y], "px": px, "rows": rows,
		"foot": [_vp.size.x / 2.0, rows[1] * px], "layers": {}}
	# the body: colour, light, mask
	var hd_meshes: Array = _hd.find_children("*", "MeshInstance3D", true, false)
	Toon.dress(_hd, {}, {})
	var flat := Shader.new()
	flat.code = FLAT
	for mi: MeshInstance3D in hd_meshes:
		for s in mi.mesh.get_surface_count():
			var t := mi.get_surface_override_material(s) as ShaderMaterial
			var u := ShaderMaterial.new()
			u.shader = flat
			u.set_shader_parameter("albedo_tex", t.get_shader_parameter("albedo_tex"))
			u.next_pass = t.next_pass
			mi.set_surface_override_material(s, u)
	var lit := await _grab()
	var half := Color(0.5, 0.5, 0.5).linear_to_srgb()
	var grey := ShaderMaterial.new()
	grey.shader = Toon.TOON
	grey.set_shader_parameter("albedo", half)
	grey.next_pass = _ink(half)
	_override(hd_meshes, grey)
	var light := await _grab()
	var mk := ShaderMaterial.new()
	mk.shader = Shader.new()
	mk.shader.code = MASK
	_override(hd_meshes, mk)
	var mask := await _grab()
	var refs := _refs(lit, mask)
	index["skin_ref"] = refs.x
	index["hair_ref"] = refs.y
	index.layers["body_lit"] = _save(lit, dir, "body_lit", false)
	index.layers["body_light"] = _save(light, dir, "body_light", false, index.layers.body_lit)
	index.layers["body_mask"] = _save(mask, dir, "body_mask", true, index.layers.body_lit)
	# each piece: lit alone, then a matte with the built body in black
	var black := _matte(Color.BLACK)
	_body.material_override = black
	var white := _matte(Color.WHITE)
	white.next_pass = _ink(Color.WHITE)
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://art/" + Fighter3D.PIECES)).get("coach", {})
	var slot_of := {}
	for card in table:
		var slot: String = _slot_of_card(int(card))
		if slot != "":
			slot_of[table[card]] = slot
	var want: Array = slot_of.keys() if only == "all" else Array(only.split(","))
	want.sort()
	var pieces := {}
	for piece in want:
		if not slot_of.has(piece):
			print("[coach_portrait] unknown piece ", piece)
			continue
		var slot: String = slot_of[piece]
		_f.equip(slot, piece)
		var nodes := _worn_meshes(slot)
		if nodes.is_empty():
			print("[coach_portrait] %s: nothing on %s" % [piece, slot])
			_f.equip(slot, "")
			continue
		_still(nodes)
		_hd.visible = false
		var alone := await _grab()
		_body.visible = true
		var keep := {}
		for mi: MeshInstance3D in nodes:
			keep[mi] = mi.material_override
			mi.material_override = white
		var matte := await _grab()
		_body.visible = false
		for mi: MeshInstance3D in nodes:
			mi.material_override = keep[mi]
		_f.equip(slot, "")
		_cut(alone, matte)
		var r = _save(alone, dir, piece, false)
		if r != null:
			pieces[piece] = {"slot": slot, "rect": r}
	index["pieces"] = pieces
	var fa := FileAccess.open(dir.path_join("index.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(index, " "))
	fa.close()
	print("[coach_portrait] %s %s: %d pieces in %d ms, canvas %dx%d" % [coach, frame, pieces.size(),
		Time.get_ticks_msec() - t0, _vp.size.x, _vp.size.y])
	quit(0)


func _fail(msg: String) -> void:
	push_error("[coach_portrait] " + msg)
	quit(1)


func _freeze() -> void:
	var p: AnimationPlayer = _f._player
	if p and p.has_animation("menu_loop"):
		p.play("menu_loop")
		p.seek(0.0, true)
		p.pause()


func _ink(c: Color) -> ShaderMaterial:
	var ink := ShaderMaterial.new()
	ink.shader = Toon.OUTLINE
	ink.set_shader_parameter("px_world", Toon.px_world)
	ink.set_shader_parameter("color", c)
	return ink


func _matte(c: Color) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = Shader.new()
	m.shader.code = MATTE
	m.set_shader_parameter("c", Vector3(c.r, c.g, c.b))
	return m


func _override(meshes: Array, m: Material) -> void:
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, m)


## The slot a coach card goes on (Fighter3D.COACH_SLOT), from the piece's
## own name (pieces.json names them <slot>_<what>; banners and the staff
## are the weapon card, type 12).
func _slot_of_card(card: int) -> String:
	var piece := Fighter3D.piece_of("coach", card)
	var head := piece.get_slice("_", 0)
	if head == "banner" or head == "staff":
		head = "weapon"
	for s in Fighter3D.COACH_SLOT.values():
		if s == head:
			return s
	return ""


func _worn_meshes(slot: String) -> Array:
	var n: Node = _f._worn.get(slot)
	if n == null:
		return []
	var out: Array = n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else [])
	if n.has_meta("twin"):
		var t: Node = n.get_meta("twin")
		out += t.find_children("*", "MeshInstance3D", true, false) + ([t] if t is MeshInstance3D else [])
	return out


## A live garment (Fighter3D.LIVE) stands still in a picture: the jelly's
## wobble pushes its flat faces apart and the ink shows between them.
func _still(meshes: Array) -> void:
	for mi: MeshInstance3D in meshes:
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s) as ShaderMaterial
			if m != null and m.get_shader_parameter("jelly") != null:
				m.set_shader_parameter("jelly", 0.0)


func _grab() -> Image:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()


## The piece's pixels where the matte says it shows (white), not where the
## body or its ink is in front (black).
func _cut(img: Image, matte: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	matte.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var data := img.get_data()
	var m := matte.get_data()
	for i in range(0, data.size(), 4):
		var a := data[i + 3]
		if a == 0:
			continue
		var vis := m[i] if m[i + 3] > 0 else 255
		data[i + 3] = (a * vis) / 255
	img.set_data(w, img.get_height(), false, Image.FORMAT_RGBA8, data)


## Crop to what is drawn (or to `rect`, another layer's), save as WebP;
## returns the rect in the canvas, or null when the layer is empty.
func _save(img: Image, dir: String, name: String, lossless: bool, rect = null):
	var r: Rect2i
	if rect != null:
		r = Rect2i(rect[0], rect[1], rect[2], rect[3])
	else:
		r = img.get_used_rect()
		if r.size.x == 0:
			return null
		r = r.grow(2).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var c := img.get_region(r)
	c.save_webp(dir.path_join(name + ".webp"), not lossless, 0.9)
	return [r.position.x, r.position.y, r.size.x, r.size.y]


## The brightness the tint divides by: the 80th percentile, in linear
## light, of the colour under each mask (coach_masks.py does the same on
## the 3D figure's texture).
func _refs(lit: Image, mask: Image) -> Vector2:
	var skin: Array[float] = []
	var hair: Array[float] = []
	var r := mask.get_used_rect()
	for y in range(r.position.y, r.end.y, 2):
		for x in range(r.position.x, r.end.x, 2):
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
