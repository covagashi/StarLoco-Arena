extends Node2D

## Animated sprite fed by the asset-import pipeline output.
##
## Source of truth on disk (git-ignored, produced by tools/asset-import):
##   <asset root>/anims/<set>/<ActionName>/f000.png … + meta.json
## Set dirs travel as LOGICAL names ("anims/coach_7000") and are resolved
## through AssetPaths, so the same string works from the editor and from an
## exported build (where the frames live beside the executable, not in the
## .pck). Legacy "res://assets/anims/…" callers still work: AssetPaths
## .normalize() strips the prefix, so the top-level smoke scripts and the
## gui model's actorDescriptorLibrary values need no rewrite.
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

## 1-bit actor styles (sprints/S04), applied to each frame at load:
##   0 = off (retail colour)
##   1 = 1 bit + the actor's own colours: the body goes ink/paper on an 8x8
##       Bayer (ordered, so it does not flicker between frames), and only the
##       mask regions (skin/hair/eyes) keep their tint
##       (flat two-tone), plus a 1-px black outline so the silhouette does
##       not melt into the 1-bit ground
##   2 = the same with the outline in team_color
##   3 = line art ("ink drawing"): black lines where the colour changes and
##       around the silhouette, white fill, flat shade (checker / solid
##       black) only for the darkest areas. No dither inside the body
##   4 = team duotone: luminance mapped black -> team_color -> white, every
##       bit of shading kept, no dither
## A static, because it is a renderer-wide choice, like the map art set.
static var onebit_style := 0
## Per-sprite override of onebit_style (-1 = follow the static). The menu
## screens' coach doll is 1-bit (S18) while the lobby keeps the static at 0.
var style := -1
## Outline colour for onebit_style 2 (alpha 0 = black, as in style 1).
var team_color := Color(0, 0, 0, 0)

const _BAYER8 := [0, 32, 8, 40, 2, 34, 10, 42, 48, 16, 56, 24, 50, 18, 58, 26,
	12, 44, 4, 36, 14, 46, 6, 38, 60, 28, 52, 20, 62, 30, 54, 22,
	3, 35, 11, 43, 1, 33, 9, 41, 51, 19, 59, 27, 49, 17, 57, 25,
	15, 47, 7, 39, 13, 45, 5, 37, 63, 31, 55, 23, 61, 29, 53, 21]

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
static var _snd_cache := {}   # ogg rel -> AudioStreamOggVorbis | false
## scripts/anm/<id>.lua resolutions (sound pairs + stop flag), lazy-loaded.
static var _anm_scripts = null


## Optional tints: {channel: Vector3} — gw_2's tE table (1=skin, 2=hair,
## 8=eye).  When the action's meta carries mask PNGs (f*_m.png — R=ch1,
## G=ch2, B=ch8 coverage), each frame's rgb is multiplied by the channel
## tint at load, once per (action, tints) combination — the channel color
## replaces like retail's divide/mul, it never stacks.  The explicit arg
## overrides `self.tints` only when non-empty.
func load_action(set_dir: String, action: String, tints := {}) -> bool:
	set_dir = AssetPaths.normalize(set_dir)   # legacy res:// callers
	var eff: Dictionary = tints if not tints.is_empty() else self.tints
	var st := style if style >= 0 else onebit_style
	if st == 3:
		eff = {}   # line art ignores the tints: one conversion for every palette
	var key := "%s/%s" % [set_dir, action]
	if not eff.is_empty():
		key += _tint_key(eff)
	if st > 0:
		key += "|1b%d" % st
		if st >= 2 and team_color.a > 0.0:
			key += team_color.to_html()
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
	# Resolve the meta, then take the frames out of ITS folder: one probe
	# per action, and a split asset tree can never pair one root's
	# meta.json with another root's PNGs.
	var meta_path := AssetPaths.resolve("%s/%s/meta.json" % [set_dir, action])
	if not FileAccess.file_exists(meta_path):
		return false   # keep the previous animation rather than going blank
	# Parsed BEFORE any state is cleared, and shape-checked (B-174): meta.json
	# is generated by tools/asset-import, so an interrupted run leaves it
	# truncated. Assigning the resulting Nil to a typed Dictionary aborts the
	# rest of this function mid-way — frames empty, cache never populated —
	# which surfaces months later as "the animations don't show" plus one log
	# line. Bailing out here instead keeps the previous animation, exactly as
	# the missing-file branch above already does.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(meta_path)) != OK:
		push_warning("anm: unusable meta.json, keeping previous action: %s (line %d: %s)" % [
			meta_path, json.get_error_line(), json.get_error_message()])
		return false
	if not json.data is Dictionary:
		push_warning("anm: meta.json is not an object, keeping previous action: " + meta_path)
		return false
	var meta: Dictionary = json.data
	_frames = []
	_sfx = {}
	_scr = {}
	_stop_scr_sounds()
	_cur = 0
	_time = 0.0
	_fps = float(meta.get("fps", 25))
	var dir := meta_path.get_base_dir()
	for fr in meta.get("frames", []):
		var img := AssetPaths.load_image_at("%s/%s" % [dir, fr.png])
		if img == null:
			continue
		var mimg: Image = null
		if fr.get("mask", "") != "" and (not eff.is_empty() or st > 0):
			mimg = AssetPaths.load_image_at("%s/%s" % [dir, fr.mask])
		if not eff.is_empty() and mimg != null:
			_apply_tints(img, mimg, eff)
		if st == 3:
			_apply_lineart(img)
		elif st == 4:
			_apply_duotone(img, team_color if team_color.a > 0.0 else Color(0.5, 0.5, 0.5))
		elif st > 0:
			_apply_onebit(img, mimg, eff,
				team_color if st >= 2 and team_color.a > 0.0 else Color.BLACK)
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
			p.bus = "SFX"   # the effects volume (src/audio/audio.gd)
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
		var parsed = AssetPaths.read_json("gamedata/anm_scripts.json")
		if parsed is Dictionary:
			_anm_scripts = parsed
	return _anm_scripts


static func _snd_stream(sid: int) -> AudioStream:
	var rel := "sounds/%d.ogg" % sid
	if _snd_cache.has(rel):
		var hit = _snd_cache[rel]
		return hit if hit is AudioStream else null
	var st: AudioStream = null
	if AssetPaths.exists(rel):
		st = AudioStreamOggVorbis.load_from_file(AssetPaths.resolve(rel))
	_snd_cache[rel] = st if st != null else false
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


## 1 bit + colour (see onebit_style). img is already tinted. Mask pixels keep
## the hue of their dominant channel's tint as a two-tone (lit / shade);
## everything else is ink/paper. Alpha goes hard at 0.5. With an outline
## colour, every transparent pixel touching the silhouette takes it.
static func _apply_onebit(img: Image, mimg: Image, tints: Dictionary,
		outline: Color) -> void:
	img.convert(Image.FORMAT_RGBA8)
	if mimg != null:
		mimg.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var accents := {}
	for ch in [1, 2, 8]:
		var t: Vector3 = tints.get(ch, Vector3.ONE) / 1.25
		accents[ch] = Color(clampf(t.x, 0, 1), clampf(t.y, 0, 1), clampf(t.z, 0, 1))
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			solid[y * w + x] = 1
			# a touch of gamma lift: the retail sprites are dark-ish
			var lum := pow(clampf(c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722, 0, 1), 0.8)
			var thr := (float(_BAYER8[(y & 7) * 8 + (x & 7)]) + 0.5) / 64.0
			var on := lum > thr
			var out := Color.WHITE if on else Color.BLACK
			if mimg != null and x < mimg.get_width() and y < mimg.get_height():
				var m := mimg.get_pixel(x, y)
				var best := maxf(m.r, maxf(m.g, m.b))
				if best > 0.4:
					# flat two-tone, no dither: dithered colour reads as noise
					var ch := 1 if best == m.r else (2 if best == m.g else 8)
					var acc: Color = accents[ch]
					out = acc if lum > 0.42 else acc.darkened(0.55)
			img.set_pixel(x, y, out)
	if outline.a <= 0.0:
		return
	for y in h:
		for x in w:
			if solid[y * w + x] == 1:
				continue
			if (x > 0 and solid[y * w + x - 1] == 1) \
					or (x < w - 1 and solid[y * w + x + 1] == 1) \
					or (y > 0 and solid[(y - 1) * w + x] == 1) \
					or (y < h - 1 and solid[(y + 1) * w + x] == 1):
				img.set_pixel(x, y, outline)


## Line art (onebit_style 3). Lines where neighbouring colours differ by more
## than LINE_EDGE, and around the silhouette; the rest white, except the
## darkest areas: checker below LINE_MID, solid ink below LINE_DARK.
const LINE_EDGE := 0.28
const LINE_MID := 0.45
const LINE_DARK := 0.2


static func _apply_lineart(img: Image) -> void:
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var src := img.duplicate() as Image
	for y in h:
		for x in w:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var edge := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					edge = true
					break
				var n := src.get_pixel(nx, ny)
				if n.a < 0.5:
					edge = true
					break
				# only the darker side of a colour step draws the line, so
				# lines stay one pixel wide instead of doubling up
				var dr := c.r - n.r
				var dg := c.g - n.g
				var db := c.b - n.b
				if sqrt(dr * dr + dg * dg + db * db) > LINE_EDGE \
						and c.get_luminance() <= n.get_luminance():
					edge = true
					break
			var lum := c.get_luminance()
			var out := Color.WHITE
			if edge or lum < LINE_DARK:
				out = Color.BLACK
			elif lum < LINE_MID and (x + y) % 2 == 0:
				out = Color.BLACK
			img.set_pixel(x, y, out)
	# outer contour: a black ring just outside the silhouette, so a white
	# figure still stands out on near-white ground (the heavy outline the
	# Glagstone buildings carry)
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a >= 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h \
						and src.get_pixel(nx, ny).a >= 0.5:
					img.set_pixel(x, y, Color.BLACK)
					break


## Team duotone (onebit_style 4): black -> team -> white along luminance,
## with a little contrast so the small sprites keep their volume.
static func _apply_duotone(img: Image, team: Color) -> void:
	img.convert(Image.FORMAT_RGBA8)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			var t := clampf((c.get_luminance() - 0.5) * 1.3 + 0.5, 0.0, 1.0)
			var out := Color.BLACK.lerp(team, t * 2.0) if t < 0.5 \
				else team.lerp(Color.WHITE, (t - 0.5) * 2.0)
			img.set_pixel(x, y, out)


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
