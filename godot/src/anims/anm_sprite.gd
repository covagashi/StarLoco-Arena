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
## One-shot mode (cast/hit/death gestures): plays to the last frame, stops,
## emits action_finished. `hold_last` keeps that frame (death); otherwise the
## caller usually reloads the idle action.
var once := false
var hold_last := false
var current := ""       # "<set>/<action>" of the loaded action — tests hook
signal action_finished
## When true, the node origin pins each frame's bottom-center VISIBLE pixel
## (feet on the iso cell) instead of the authored scene anchor — the alpha
## margin under the feet is measured per frame at load.
var foot_pivot := false
## When set, the sprite's own _draw is skipped — map_gfx's merged painter
## calls draw_on() instead so the frame interleaves with map elements.
var external_draw := false

## meta.json "sfx" — {frame index: [sound ids]} baked from Sons* parts.
## Played through a small round-robin pool; streams are cached by path.
var _sfx: Dictionary = {}
var _sfx_pool: Array = []
var _sfx_next := 0

## Decoded actions are shared read-only across sprites — direction flips
## during a walk reload the same action set many times per second.
static var _cache := {}   # "set/action" -> {fps, frames, sfx}
static var _snd_cache := {}   # ogg path -> AudioStreamOggVorbis | false


func load_action(set_dir: String, action: String) -> bool:
	var key := "%s/%s" % [set_dir, action]
	if _cache.has(key):
		var c: Dictionary = _cache[key]
		_fps = c.fps
		_frames = c.frames
		_sfx = c.get("sfx", {})
		_cur = 0
		_time = 0.0
		once = false
		hold_last = false
		current = key
		playing = true
		queue_redraw()
		_play_sfx(0)
		return not _frames.is_empty()
	var meta_path := "%s/%s/meta.json" % [set_dir, action]
	if not FileAccess.file_exists(meta_path):
		return false   # keep the previous animation rather than going blank
	_frames = []
	_sfx = {}
	_cur = 0
	_time = 0.0
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
	_sfx = {}
	for k in meta.get("sfx", {}):
		_sfx[int(k)] = meta["sfx"][k]
	_cache[key] = {"fps": _fps, "frames": _frames, "sfx": _sfx}
	once = false
	hold_last = false
	current = key
	playing = true
	queue_redraw()
	_play_sfx(0)
	return not _frames.is_empty()


## Load + play a gesture once (cast/hit/death). Returns false when the set
## lacks the action — callers fall back silently, assets are optional.
func play_once(set_dir: String, action: String, hold := false) -> bool:
	if not load_action(set_dir, action):
		return false
	once = true
	hold_last = hold
	return true


func _process(delta: float) -> void:
	if not playing or _frames.is_empty():
		return
	if once and _frames.size() < 2:
		playing = false            # single-frame gesture: hold + finish now
		action_finished.emit()
		return
	if not playing or _frames.size() < 2:
		return
	_time += delta * _fps
	if once:
		# clamp to the last frame instead of wrapping; hold freezes there
		var f := mini(int(_time), _frames.size() - 1)
		if f != _cur:
			_cur = f
			_play_sfx(f)
			queue_redraw()
		if int(_time) >= _frames.size():
			playing = false
			action_finished.emit()
		return
	var f := int(_time) % _frames.size()
	if f != _cur:
		_cur = f
		_play_sfx(f)
		queue_redraw()


func _draw() -> void:
	if external_draw or _frames.is_empty():
		return
	_draw_frame(self, Vector2.ZERO)


## Draw the current frame onto another canvas item at `world_pos` (the
## sprite's own position, since the caller draws in the parent's space).
## Honors foot_pivot and the horizontal mirror (negative scale.x).
func draw_on(ci: CanvasItem, world_pos: Vector2) -> void:
	if _frames.is_empty():
		return
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


## Play one sound id on this sprite's pool (script-driven spell sfx —
## retail Sound.playSound in cast scripts). Silent no-op headless or when
## the ogg is absent.
func play_sound(sid: int) -> void:
	if not is_inside_tree():
		return
	if _sfx_pool.is_empty():
		for i in 8:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_pool.append(p)
	var st := _snd_stream(sid)
	if st == null:
		return
	var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.stream = st
	p.play()


## Play the Sons* triggers baked for this frame. Round-robin pool so
## overlapping casts/hits don't cut each other; headless just no-ops.
func _play_sfx(frame_idx: int) -> void:
	var ids: Array = _sfx.get(frame_idx, [])
	if ids.is_empty() or not is_inside_tree():
		return
	if _sfx_pool.is_empty():
		for i in 8:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_pool.append(p)
	for sid in ids:
		var st := _snd_stream(int(sid))
		if st == null:
			continue
		var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
		_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
		p.stream = st
		p.play()


static func _snd_stream(sid: int) -> AudioStream:
	var path := "res://assets/sounds/%d.ogg" % sid
	if _snd_cache.has(path):
		var hit = _snd_cache[path]
		return hit if hit is AudioStream else null
	var st: AudioStream = null
	if FileAccess.file_exists(path):
		st = AudioStreamOggVorbis.load_from_file(path)
	_snd_cache[path] = st if st != null else false
	return st
