extends Node2D

## Animated sprite fed by the asset-import pipeline output.
##
## Source of truth on disk (git-ignored, produced by tools/asset-import):
##   res://assets/anims/<set>/<ActionName>/f000.png … + meta.json
## meta.json: {fps, frames:[{png, w, h, ox, oy}]} — ox/oy is the frame's
## top-left offset in scene space, preserving the authored pivot.

var _frames: Array = []   # [{tex: Texture2D, off: Vector2, w: int, h: int, foot: int}]
var _fps := 25.0
var _time := 0.0
var _cur := 0
var playing := true
## When true, the node origin pins each frame's bottom-center VISIBLE pixel
## (feet on the iso cell) instead of the authored scene anchor — the alpha
## margin under the feet is measured per frame at load.
var foot_pivot := false


func load_action(set_dir: String, action: String) -> bool:
	_frames = []
	_cur = 0
	_time = 0.0
	var meta_path := "%s/%s/meta.json" % [set_dir, action]
	if not FileAccess.file_exists(meta_path):
		return false
	var meta: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(meta_path))
	_fps = float(meta.get("fps", 25))
	var dir := "%s/%s" % [set_dir, action]
	for fr in meta.get("frames", []):
		var img := Image.load_from_file("%s/%s" % [dir, fr.png])
		if img == null:
			continue
		var w := int(fr.w)
		var h := int(fr.h)
		# lowest row containing visible pixels — the authored PNG bottom can
		# carry a transparent margin that lifts the feet off the ground.
		var foot := h - 1
		for y in range(h - 1, -1, -1):
			var found := false
			for x in w:
				if img.get_pixel(x, y).a > 0.15:
					found = true
					break
			if found:
				foot = y
				break
		_frames.append({
			"tex": ImageTexture.create_from_image(img),
			"off": Vector2(fr.ox, fr.oy),
			"w": w, "h": h, "foot": foot,
		})
	playing = true
	queue_redraw()
	return not _frames.is_empty()


func _process(delta: float) -> void:
	if not playing or _frames.size() < 2:
		return
	_time += delta * _fps
	var f := int(_time) % _frames.size()
	if f != _cur:
		_cur = f
		queue_redraw()


func _draw() -> void:
	if _frames.is_empty():
		return
	var fr: Dictionary = _frames[_cur]
	var pos: Vector2 = fr.off
	if foot_pivot:
		# pin the feet (lowest visible row), centered, to the node origin
		pos = Vector2(-fr.w * 0.5, -float(fr.foot) - 1.0)
	draw_texture(fr.tex, pos)
