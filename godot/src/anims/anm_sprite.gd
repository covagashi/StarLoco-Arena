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
## When set, the sprite's own _draw is skipped — map_gfx's merged painter
## calls draw_on() instead so the frame interleaves with map elements.
var external_draw := false

## Decoded actions are shared read-only across sprites — direction flips
## during a walk reload the same action set many times per second.
static var _cache := {}   # "set/action" -> {fps, frames}


func load_action(set_dir: String, action: String) -> bool:
	_frames = []
	_cur = 0
	_time = 0.0
	var key := "%s/%s" % [set_dir, action]
	if _cache.has(key):
		var c: Dictionary = _cache[key]
		_fps = c.fps
		_frames = c.frames
		queue_redraw()
		return not _frames.is_empty()
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
	_cache[key] = {"fps": _fps, "frames": _frames}
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
	if external_draw or _frames.is_empty():
		return
	_draw_frame(self, Vector2.ZERO)


## Draw the current frame onto another canvas item at `world_pos` (the
## sprite's own position, since the caller draws in the parent's space).
## Honors foot_pivot and the horizontal mirror (negative scale.x).
func draw_on(ci: CanvasItem, world_pos: Vector2) -> void:
	ci.draw_set_transform(world_pos, 0.0, Vector2(scale.x, 1.0))
	_draw_frame(ci, Vector2.ZERO)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_frame(ci: CanvasItem, at: Vector2) -> void:
	var fr: Dictionary = _frames[_cur]
	var pos: Vector2 = at + fr.off
	if foot_pivot:
		# pin the feet (lowest visible row), centered, to the node origin
		pos = at + Vector2(-fr.w * 0.5, -float(fr.foot) - 1.0)
	ci.draw_texture(fr.tex, pos)
