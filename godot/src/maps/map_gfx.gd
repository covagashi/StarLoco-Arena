extends Node2D

## Painted map-art layer, fed by tools/asset-import/map_gfx.py output:
##   res://assets/mapgfx/<world>.json  {tex:{id:{w,h}}, sprites:[{tex,sx,sy,w,h,uv,z}]}
##   res://assets/mapgfx/tex/<gfx>.png
## Each sprite is an atlas region drawn at an authored scene position,
## z-sorted by the retail render key. Elements draw UNDER the actors
## (full painter interleave vs sprites is a later refinement).

var _sprites := []       # sorted by z ascending
var _tex := {}           # gfxId -> Texture2D
var _xs := PackedFloat32Array()   # sprite sx values, same order as _sprites
var _ready_ok := false
var debug := OS.has_environment("MAPGFX_DEBUG")


func load_world(world_id: int) -> bool:
	clear()
	var json_path := "res://assets/mapgfx/%d.json" % world_id
	if not FileAccess.file_exists(json_path):
		return false
	var meta: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(json_path))
	var sprites: Array = meta.get("sprites", [])
	sprites.sort_custom(func(a, b): return a.z < b.z)
	var tex_meta: Dictionary = meta.get("tex", {})
	for gfx in tex_meta:
		# JSON object keys arrive as strings; sprite.tex is numeric
		var p := "res://assets/mapgfx/tex/%s.png" % gfx
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img != null:
				_tex[int(gfx)] = ImageTexture.create_from_image(img)
	for s in sprites:
		var t: Texture2D = _tex.get(int(s.tex))
		if t == null:
			continue
		_sprites.append({"t": t, "sx": float(s.sx), "sy": float(s.sy),
			"w": float(s.w), "h": float(s.h), "uv": s.uv})
	_xs.resize(_sprites.size())
	for i in _sprites.size():
		_xs[i] = _sprites[i].sx
	_ready_ok = true
	queue_redraw()
	return true


func clear() -> void:
	_sprites = []
	_tex = {}
	_xs = PackedFloat32Array()
	_ready_ok = false
	queue_redraw()


func _draw() -> void:
	if not _ready_ok:
		return
	# camera-space cull: visible world rect -> sx band
	var xf := get_canvas_transform()
	var view := get_viewport_rect()
	var world_rect := Rect2(xf.affine_inverse() * view.position,
		view.size * xf.affine_inverse().get_scale().abs())
	# widen for tall sprites extending above their anchor
	world_rect = world_rect.grow(200.0)
	if debug:
		print("[mapgfx] sprites=%d tex=%d rect=%s s0=%s" % [
			_sprites.size(), _tex.size(), world_rect,
			_sprites[0] if _sprites.size() else {}])
	var drawn := 0
	for s in _sprites:
		if s.sx + s.w < world_rect.position.x or s.sx > world_rect.end.x:
			continue
		if s.sy + s.h < world_rect.position.y or s.sy > world_rect.end.y:
			continue
		var uv = s.uv
		if uv != null:
			draw_texture_rect_region(s.t,
				Rect2(s.sx, s.sy, s.w, s.h),
				Rect2(uv[0], uv[1], uv[2], uv[3]))
		else:
			# static element — zl_1.d(): the whole texture stretched to w×h
			draw_texture_rect(s.t, Rect2(s.sx, s.sy, s.w, s.h), false)
		drawn += 1
	if debug:
		print("[mapgfx] drawn %d" % drawn)
