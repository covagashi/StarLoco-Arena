extends SceneTree

## Fight-map renderer for the 1-bit art passes (sprints/S04): paints one fight
## map the way fight_view does, puts the 1-bit filter over it and saves a PNG.
## Every shader knob is a flag, so an art note becomes a re-run, not an edit.
##
##   godot --path godot --resolution 1280x720 -s tools/render_fightmap.gd -- \
##       --map=10 --out=/tmp/map10.png [--raw=/tmp/map10-raw.png] \
##       [--pixel=2] [--black=0] [--white=1] [--gamma=1] [--levels=0] \
##       [--detail=1] [--detail-radius=3] [--edge=0] [--edge-threshold=0.25] \
##       [--ambient=1] [--falloff=1.5] [--lights="x,y,r,i;..."] \
##       [--hud] [--overlays] [--debug=0..4] [--world=color|1bit] \
##       [--actors=color|onebit|team|line|duo] [--fighters] \
##       [--marks=none|cell|aura|ring] [--batch=DIR [--maps=1,2,…]]
##
## --batch=DIR renders every fight map of the art set (--world picks it) to
## DIR/<id>.png with the same knobs, and writes DIR/index.txt: one line per
## map, "ok", "skip" (no .fmd: an overworld map, not an arena) or why it failed
## (no art, no arena cells, missing textures, fell back to the retail art,
## save error, a blank frame). Exits 1 if any arena failed.
##
## --actors picks the AnmSprite 1-bit style (onebit = 1 bit + the actor's own
## mask colours; team = that plus a team-colour outline). --fighters places
## three demo fighters per team on the map's spawn cells.
##
## --world=1bit loads the per-texture 1-bit art (assets/mapgfx_1bit, made by
## tools/asset-import/onebit.py) and leaves the shader only the darkness and
## the lights. --debug=3/4 show the darkness pattern / the light map alone.
##
## By default the map is drawn bare: no HUD and no tactical overlays (spawn
## zones, placement rings). --hud and --overlays put them back.
##
## Lights are given in viewport fractions so they survive a resolution change:
## x and y in 0..1 of the width/height, r as a fraction of the height, i the
## intensity added on top of the ambient.
##
## Needs a real renderer. On a box without a display, wrap it in
## `xvfb-run -a`; --headless uses the dummy renderer, which draws nothing.
## Exits 0 on a written PNG, 1 on a render/save failure, 2 on bad usage.

const SHADER_PATH := "res://src/fight/onebit.gdshader"
const AnmSpriteScript := preload("res://src/anims/anm_sprite.gd")
const TeamAura := preload("res://src/fight/team_aura.gd")
const ACTOR_STYLES := {"color": 0, "onebit": 1, "team": 2, "line": 3, "duo": 4}
## Demo fighters for --fighters: one breed set per spawn slot, with palette
## indices so each one gets different skin/hair/eye tints.
const DEMO_FIGHTERS := [
	["fighter_-110", [1, 3, 5]], ["fighter_-131", [4, 0, 2]],
	["fighter_-150", [6, 2, 1]], ["fighter_-171", [2, 5, 4]],
	["fighter_-1100", [0, 1, 6]], ["fighter_-1121", [5, 4, 3]],
]
const TEAM_COLORS := [Color(0.9, 0.15, 0.1), Color(0.15, 0.4, 1.0)]


# _initialize, not _init: fight_view.gd references autoloads (I18n), which are
# only registered once the tree is up (same reason as test/fight_shot.gd).
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[render] needs a real display: run under xvfb-run, not --headless")
		quit(2)
		return
	var opt := _parse(OS.get_cmdline_user_args())
	if opt.is_empty():
		quit(2)
		return

	# Godot's default grey clear colour is not part of the map; under the filter
	# it dithers into a field of noise. The void around the arena is black.
	RenderingServer.set_default_clear_color(Color.BLACK)
	var scene: Node2D = load("res://src/fight/fight_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	if opt.world == "1bit":
		scene._gfx.use_onebit(true)
	AnmSpriteScript.onebit_style = ACTOR_STYLES[opt.actors]
	scene.get_node("UI/TopBar/MapId").text = str(opt.map)
	scene._load()
	if not opt.hud:
		scene.get_node("UI").visible = false
	scene.overlays_visible = opt.overlays
	scene.queue_redraw()
	if opt.fighters:
		_spawn_demo_fighters(scene, opt.marks)
	await create_timer(0.5).timeout

	if opt.raw != "":
		if not await _save(opt.raw):
			quit(1)
			return

	var layer := CanvasLayer.new()
	layer.layer = 1   # over the map; the HUD layer is lifted above it
	if opt.hud:
		scene.get_node("UI").layer = 2
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	var size := Vector2(root.get_visible_rect().size)
	mat.set_shader_parameter("pixel_size", opt.pixel)
	mat.set_shader_parameter("black_point", opt.black)
	mat.set_shader_parameter("white_point", opt.white)
	mat.set_shader_parameter("gamma", opt.gamma)
	mat.set_shader_parameter("levels", int(opt.levels))
	mat.set_shader_parameter("detail", opt.detail)
	mat.set_shader_parameter("detail_radius", opt["detail-radius"])
	mat.set_shader_parameter("edge_strength", opt.edge)
	mat.set_shader_parameter("edge_threshold", opt["edge-threshold"])
	mat.set_shader_parameter("ambient", opt.ambient)
	mat.set_shader_parameter("light_falloff", opt.falloff)
	mat.set_shader_parameter("debug_view", int(opt.debug))
	mat.set_shader_parameter("world_onebit", opt.world == "1bit")
	var lights := PackedVector4Array()
	for l in opt.lights:
		lights.append(Vector4(l.x * size.x, l.y * size.y, l.z * size.y, l.w))
	lights.resize(16)
	mat.set_shader_parameter("light_count", opt.lights.size())
	mat.set_shader_parameter("lights", lights)
	rect.material = mat
	layer.add_child(rect)
	root.add_child(layer)

	if opt.batch != "":
		root.remove_child(scene)
		scene.free()
		quit(await _batch(opt))
		return
	if not await _save(opt.out):
		quit(1)
		return
	quit(0)


## Every map of the art set under the same filter, each in a fresh
## fight_view: reusing one scene let a huge world (map 0, 327k sprites)
## black out every map after it. Returns the exit code: 0 when every arena
## rendered with all its textures and something on screen.
func _batch(opt: Dictionary) -> int:
	var src := "mapgfx_1bit" if opt.world == "1bit" else "mapgfx"
	var ids: Array[int] = []
	for f in DirAccess.get_files_at(AssetPaths.dir(src)):
		if f.ends_with(".json") and f.get_basename().is_valid_int():
			ids.append(int(f.get_basename()))
	ids.sort()
	if not opt.maps.is_empty():
		ids = ids.filter(func(i): return i in opt.maps)
	if ids.is_empty():
		printerr("[render] no maps in %s (convert them first?)" % src)
		return 1
	DirAccess.make_dir_recursive_absolute(opt.batch)
	var lines := PackedStringArray()
	var failed := 0
	var skipped := 0
	var t0 := Time.get_ticks_msec()
	# fight_view picks the art set itself in _ready (ArtStyle reads the env)
	OS.set_environment("ARENA_ART_STYLE", "onebit" if opt.world == "1bit" else "retail")
	var scene: Node2D = null
	for id in ids:
		if scene != null:
			root.remove_child(scene)
			scene.free()
		scene = load("res://src/fight/fight_view.tscn").instantiate()
		scene.get_node("UI/TopBar/MapId").text = str(id)   # _ready loads it
		root.add_child(scene)
		root.move_child(scene, 0)   # under the filter layer
		AnmSpriteScript.onebit_style = ACTOR_STYLES[opt.actors]
		RenderingServer.set_default_clear_color(Color.BLACK)
		scene.get_node("UI").visible = opt.hud
		scene.overlays_visible = opt.overlays
		scene.queue_redraw()
		await process_frame
		scene.cam.reset_smoothing()   # no pan from the origin into the shot
		await create_timer(0.3).timeout
		if scene._fmd.is_empty():
			# the server's rule (gamedata.LoadFightMaps): a world is an arena
			# only if its fight jar holds a non-empty .fmd — 47 of the 114
			# worlds in 2.70; the rest are overworld topologies sharing ids
			skipped += 1
			lines.append("%d skip not an arena (no .fmd)" % id)
			continue
		var why := _batch_check(scene, src, id)
		var out: String = opt.batch.path_join("%d.png" % id)
		if why.is_empty() and not await _save(out):
			why = "save failed"
		if why.is_empty():
			var lit := _lit_fraction(Image.load_from_file(out))
			if lit < 0.02:
				why = "blank render (%.1f%% lit) — art outside the arena view?" % (lit * 100.0)
		if why.is_empty():
			lines.append("%d ok" % id)
		else:
			failed += 1
			lines.append("%d FAIL %s" % [id, why])
			printerr("[render] map %d: %s" % [id, why])
	lines.append("# %d maps, %d arenas, %d failed, %.1f s" % [ids.size(),
		ids.size() - skipped, failed, (Time.get_ticks_msec() - t0) / 1000.0])
	var idx := FileAccess.open(opt.batch.path_join("index.txt"), FileAccess.WRITE)
	if idx != null:
		idx.store_string("\n".join(lines) + "\n")
	print("[render] batch: %d maps, %d not arenas, %d failed -> %s" % [
		ids.size(), skipped, failed, opt.batch.path_join("index.txt")])
	return 0 if failed == 0 else 1


## Share of pixels that are not the black void, sampled on a coarse grid.
static func _lit_fraction(img: Image) -> float:
	if img == null:
		return 0.0
	var n := 0
	var lit := 0
	for y in range(0, img.get_height(), 8):
		for x in range(0, img.get_width(), 8):
			n += 1
			if img.get_pixel(x, y).get_luminance() > 0.05:
				lit += 1
	return float(lit) / maxf(n, 1)


## Why a loaded map is not a good render ("" = fine).
func _batch_check(scene: Node2D, src: String, id: int) -> String:
	if not scene._gfx_active:
		return "no map art"
	if scene._gfx.source_dir != src:
		return "fell back to %s" % scene._gfx.source_dir
	if scene._cells.is_empty():
		return "no arena cells (topology)"
	var meta: Dictionary = AssetPaths.read_json("%s/%d.json" % [src, id], {})
	var want: int = meta.get("tex", {}).size()
	var got: int = scene._gfx._tex.size()
	if got < want:
		return "missing %d of %d textures" % [want - got, want]
	return ""


## Team-mark designs auditioned for the 1-bit style (sprints/S04):
##   cell = the cell's diamond filled with a checker of the team colour
##   aura = a round glow of team-coloured Bayer dots fading outwards (chosen
##          2026-10-17; drawn by src/fight/team_aura.gd, as in the game)
##   ring = a thick team-colour ground ellipse (the live ring, reinforced)
## The acting fighter's mark is drawn larger / denser.
const HW := 43.0
const HH := 21.5
static var _mark_cache := {}


func _draw_mark(ci: CanvasItem, kind: String, ctr: Vector2, col: Color,
		active: bool) -> void:
	match kind:
		"ring":
			var pts := PackedVector2Array()
			var k := 0.62 if active else 0.55
			for n in 33:
				var a := TAU * float(n) / 32.0
				pts.append(ctr + Vector2(cos(a) * HW * k, sin(a) * HH * k))
			ci.draw_polyline(pts, col, 4.0 if active else 2.5)
		"aura":
			TeamAura.draw(ci, ctr, col, active)   # the design the game uses
		"cell":
			var key := "%s|%s|%s" % [kind, col.to_html(), active]
			if not _mark_cache.has(key):
				_mark_cache[key] = ImageTexture.create_from_image(
					_mark_image(kind, col, active))
			var tex: Texture2D = _mark_cache[key]
			ci.draw_texture(tex, (ctr - tex.get_size() / 2.0).floor())


static func _mark_image(kind: String, col: Color, active: bool) -> Image:
	var bayer := AnmSpriteScript._BAYER8
	var scale := 1.5 if kind == "aura" else 1.0
	if active:
		scale *= 1.25
	var w := int(HW * 2.0 * scale)
	var h := int(HH * 2.0 * scale)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var dx := (float(x) + 0.5 - w / 2.0) / (w / 2.0)
			var dy := (float(y) + 0.5 - h / 2.0) / (h / 2.0)
			var on := false
			if kind == "cell":
				# diamond |dx| + |dy| <= 1; checker fill, solid 1-px rim
				var d := absf(dx) + absf(dy)
				if d <= 1.0:
					var rim := d > 1.0 - 2.5 / (h / 2.0)
					on = rim or (x + y) % 2 == 0 or (active and (x / 2 + y) % 2 == 0)
			else:
				var d := sqrt(dx * dx + dy * dy)
				var v := clampf(1.0 - d, 0.0, 1.0)
				v = pow(v, 0.8) * (1.0 if active else 0.85)
				on = v > (float(bayer[(y & 7) * 8 + (x & 7)]) + 0.5) / 64.0
			if on:
				img.set_pixel(x, y, col)
	return img


## Three fighters per team on the map's own spawn cells, so the actor styles
## can be judged in place (the preview otherwise only shows pedestal coaches).
func _spawn_demo_fighters(scene: Node2D, marks: String) -> void:
	# Team marks are drawn on fight_view's own canvas item, like its live base
	# rings: above the map (a show_behind_parent child) and below the actors.
	# The art pass only auditions designs here.
	var spots := []
	scene.draw.connect(func():
		for sp in spots:
			_draw_mark(scene, marks, sp.ctr, sp.col, sp.active))
	var i := 0
	for team in [0, 1]:
		var cells: Array = scene._fmd.get("team%d" % team, [])
		for k in mini(3, cells.size()):
			var c: Dictionary = cells[k]
			var spec: Array = DEMO_FIGHTERS[i]
			i += 1
			var spr: Node2D = AnmSpriteScript.new()
			spr.team_color = TEAM_COLORS[team]
			spr.tints = Palettes.fighter_tints(spec[1][0], spec[1][1], spec[1][2])
			spr.position = scene._iso(c.x + 0.5, c.y + 0.5, c.z)
			# the first fighter of team 0 plays the acting one (turn marker)
			spots.append({"ctr": spr.position, "col": TEAM_COLORS[team],
				"active": i == 1})
			spr.z_index = clampi(int(c.x + c.y) * 4 + 1, -4096, 4096)
			if team == 1:
				spr.scale.x = -1   # face the other team
			scene._actors.add_child(spr)
			spr.load_action("anims/" + spec[0], "1_AnimStatique")
	scene.queue_redraw()


func _save(path: String) -> bool:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if img == null:
		printerr("[render] no viewport image (dummy renderer?)")
		return false
	if img.save_png(path) != OK:
		printerr("[render] could not write %s" % path)
		return false
	print("[render] %s %dx%d" % [path, img.get_width(), img.get_height()])
	return true


## --key=value pairs (bare --hud is a flag). Returns {} after printing why on
## bad input.
func _parse(args: PackedStringArray) -> Dictionary:
	var o := {"map": 10, "out": "/tmp/fightmap.png", "raw": "", "hud": false,
		"overlays": false, "pixel": 2.0, "black": 0.0, "white": 1.0,
		"gamma": 1.0, "levels": 0.0, "edge": 0.0, "edge-threshold": 0.25,
		"ambient": 1.0, "falloff": 1.5, "lights": [], "debug": 0.0, "world": "color", "actors": "color",
		"fighters": false, "marks": "none", "detail": 1.0, "detail-radius": 3.0,
		"batch": "", "maps": []}
	for a in args:
		if not a.begins_with("--"):
			printerr("[render] unexpected argument: %s" % a)
			return {}
		var kv := a.substr(2).split("=", true, 1)
		var k := kv[0]
		var v := kv[1] if kv.size() > 1 else ""
		match k:
			"map":
				o.map = int(v)
			"out", "raw", "batch":
				o[k] = v
			"maps":
				for m in v.split(",", false):
					o.maps.append(int(m))
			"fighters":
				o.fighters = true
			"marks":
				if not v in ["none", "cell", "aura", "ring"]:
					printerr("[render] --marks is none, cell, aura or ring, got '%s'" % v)
					return {}
				o.marks = v
			"actors":
				if not ACTOR_STYLES.has(v):
					printerr("[render] --actors is color, onebit, team, line or duo, got '%s'" % v)
					return {}
				o.actors = v
			"world":
				if v not in ["color", "1bit"]:
					printerr("[render] --world is color or 1bit, got '%s'" % v)
					return {}
				o.world = v
			"hud", "overlays":
				o[k] = true
			"pixel", "black", "white", "gamma", "levels", "edge", \
					"edge-threshold", "ambient", "falloff", "debug", "detail", \
					"detail-radius":
				if not v.is_valid_float():
					printerr("[render] --%s needs a number, got '%s'" % [k, v])
					return {}
				o[k] = float(v)
			"lights":
				for spec in v.split(";", false):
					var p := spec.split(",")
					if p.size() != 4:
						printerr("[render] a light is x,y,r,i — got '%s'" % spec)
						return {}
					o.lights.append(Vector4(float(p[0]), float(p[1]),
						float(p[2]), float(p[3])))
				if o.lights.size() > 16:
					printerr("[render] at most 16 lights")
					return {}
			_:
				printerr("[render] unknown option --%s" % k)
				return {}
	return o
