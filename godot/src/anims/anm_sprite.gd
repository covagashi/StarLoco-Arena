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

## gw_2 tE channel tints — {1: Vector3 skin, 2: Vector3 hair, 8: Vector3
## eye}.  Set once at spawn; every load_action/play_once applies them via
## the frame's mask (R=ch1, G=ch2, B=ch8) unless overridden per-call.
var tints := {}

## meta.json "sfx" — {frame index: [sound ids]} baked from Sons* parts.
## Played through a small round-robin pool; streams are cached by path.
var _sfx: Dictionary = {}
## meta.json "scr" — {frame index: [script ids]} baked from runScript parts
## (pb_1). Each id resolves through anm_scripts.json to {s:[[id,gain],…],
## stop} — playLocalSound / uniform-random playLocalRandomSound.
var _scr: Dictionary = {}
## Players flagged stopOnAnimationChange — killed when the action swaps.
var _scr_stop: Array = []
var _sfx_pool: Array = []
var _sfx_next := 0

## Decoded actions are shared read-only across sprites — direction flips
## during a walk reload the same action set many times per second.
static var _cache := {}   # "set/action" -> {fps, frames, sfx, scr}
static var _snd_cache := {}   # ogg path -> AudioStreamOggVorbis | false
## scripts/anm/<id>.lua resolutions (sound pairs + stop flag), lazy-loaded.
static var _anm_scripts = null


## Optional tints: {channel: Vector3} — gw_2's tE table (1=skin, 2=hair,
## 8=eye).  When the action's meta carries mask PNGs (f*_m.png — R=ch1,
## G=ch2, B=ch8 coverage), each frame's rgb is multiplied by the channel
## tint at load, once per (action, tints) combination — the channel color
## replaces like retail's divide/mul, it never stacks.  The explicit arg
## overrides `self.tints` only when non-empty.
func load_action(set_dir: String, action: String, tints := {}) -> bool:
	var eff: Dictionary = tints if not tints.is_empty() else self.tints
	var key := "%s/%s" % [set_dir, action]
	if not eff.is_empty():
		key += _tint_key(eff)
	if _cache.has(key):
		var c: Dictionary = _cache[key]
		_fps = c.fps
		_frames = c.frames
		_sfx = c.get("sfx", {})
		_scr = c.get("scr", {})
		_stop_scr_sounds()
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
	_scr = {}
	_stop_scr_sounds()
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
		if not eff.is_empty() and fr.get("mask", "") != "":
			var mimg := Image.load_from_file("%s/%s" % [dir, fr.mask])
			if mimg != null:
				_apply_tints(img, mimg, eff)
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
	_scr = {}
	for k in meta.get("scr", {}):
		_scr[int(k)] = meta["scr"][k]
	_cache[key] = {"fps": _fps, "frames": _frames, "sfx": _sfx, "scr": _scr}
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
	var st := _snd_stream(sid)
	if st == null:
		return
	var p := _sfx_player()
	p.stream = st
	p.play()


func _sfx_player() -> AudioStreamPlayer:
	if _sfx_pool.is_empty():
		for i in 8:
			var p := AudioStreamPlayer.new()
			add_child(p)
			_sfx_pool.append(p)
	var p: AudioStreamPlayer = _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_pool.size()
	p.volume_db = 0.0    # pooled slot — reset any prior script gain
	return p


## Play the Sons* + runScript triggers baked for this frame. Round-robin
## pool so overlapping casts/hits don't cut each other; headless just no-ops.
func _play_sfx(frame_idx: int) -> void:
	var ids: Array = _sfx.get(frame_idx, [])
	var scrs: Array = _scr.get(frame_idx, [])
	if (ids.is_empty() and scrs.is_empty()) or not is_inside_tree():
		return
	for sid in ids:
		var st := _snd_stream(int(sid))
		if st == null:
			continue
		var p := _sfx_player()
		p.stream = st
		p.play()
	var table := _anm_script_table()
	for scr in scrs:
		var e = table.get(str(int(scr)))
		if e == null or e.get("s", []).is_empty():
			continue
		var pair: Array = e["s"][randi() % e["s"].size()]
		var st := _snd_stream(int(pair[0]))
		if st == null:
			continue
		var p := _sfx_player()
		p.stream = st
		p.volume_db = linear_to_db(clampf(float(pair[1]), 0.0, 100.0) / 100.0)
		p.play()
		if e.get("stop", false):
			_scr_stop.append(p)


## stopOnAnimationChange — retail registers the stream handle and kills it
## when the entity's animation swaps; mirror that on load_action.
func _stop_scr_sounds() -> void:
	for p in _scr_stop:
		p.stop()
	_scr_stop.clear()


static func _anm_script_table() -> Dictionary:
	if _anm_scripts == null:
		_anm_scripts = {}
		var p := "res://assets/gamedata/anm_scripts.json"
		if FileAccess.file_exists(p):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if parsed is Dictionary:
				_anm_scripts = parsed
	return _anm_scripts


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


## Cache discriminant for a tints dict — stable order, 3 decimals enough
## to separate every palette entry.
static func _tint_key(tints: Dictionary) -> String:
	var chans: Array = tints.keys()
	chans.sort()
	var parts := PackedStringArray()
	for c in chans:
		var v: Vector3 = tints[c]
		parts.append("%d:%.3f,%.3f,%.3f" % [int(c), v.x, v.y, v.z])
	return "@t" + ";".join(parts)


## Per-pixel channel tint — mask.r/g/b hold ch1/ch2/ch8 coverage; the
## channel color multiplies rgb (clamped like the float path — authored
## textures can exceed 1.0 after ×1.25 boosting, same as retail floats).
static func _apply_tints(img: Image, mimg: Image, tints: Dictionary) -> void:
	var t1: Vector3 = tints.get(1, Vector3.ONE)
	var t2: Vector3 = tints.get(2, Vector3.ONE)
	var t8: Vector3 = tints.get(8, Vector3.ONE)
	if t1 == Vector3.ONE and t2 == Vector3.ONE and t8 == Vector3.ONE:
		return
	img.convert(Image.FORMAT_RGBA8)
	mimg.convert(Image.FORMAT_RGBA8)
	var w := mini(img.get_width(), mimg.get_width())
	var h := mini(img.get_height(), mimg.get_height())
	for y in h:
		for x in w:
			var m := mimg.get_pixel(x, y)
			if m.r + m.g + m.b <= 0.0:
				continue
			var c := img.get_pixel(x, y)
			c.r *= lerpf(1.0, t1.x, m.r) * lerpf(1.0, t2.x, m.g) * lerpf(1.0, t8.x, m.b)
			c.g *= lerpf(1.0, t1.y, m.r) * lerpf(1.0, t2.y, m.g) * lerpf(1.0, t8.y, m.b)
			c.b *= lerpf(1.0, t1.z, m.r) * lerpf(1.0, t2.z, m.g) * lerpf(1.0, t8.z, m.b)
			img.set_pixel(x, y, c)
