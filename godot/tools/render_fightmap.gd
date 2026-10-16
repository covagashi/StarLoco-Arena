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
##       [--actors=color|onebit|team] [--fighters]
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
const ACTOR_STYLES := {"color": 0, "onebit": 1, "team": 2}
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
		_spawn_demo_fighters(scene)
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

	if not await _save(opt.out):
		quit(1)
		return
	quit(0)


## Three fighters per team on the map's own spawn cells, so the actor styles
## can be judged in place (the preview otherwise only shows pedestal coaches).
func _spawn_demo_fighters(scene: Node2D) -> void:
	var i := 0
	for team in [0, 1]:
		var cells: Array = scene._fmd.get("team%d" % team, [])
		for k in mini(3, cells.size()):
			var c: Dictionary = cells[k]
			var spec: Array = DEMO_FIGHTERS[i]
			i += 1
			var spr: Node2D = AnmSpriteScript.new()
			spr.foot_pivot = true
			spr.team_color = TEAM_COLORS[team]
			spr.tints = Palettes.fighter_tints(spec[1][0], spec[1][1], spec[1][2])
			spr.position = scene._iso(c.x + 0.5, c.y + 0.5, c.z)
			spr.z_index = clampi(int(c.x + c.y) * 4 + 1, -4096, 4096)
			if team == 1:
				spr.scale.x = -1   # face the other team
			scene._actors.add_child(spr)
			spr.load_action("anims/" + spec[0], "1_AnimStatique")


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
		"fighters": false, "detail": 1.0, "detail-radius": 3.0}
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
			"out", "raw":
				o[k] = v
			"fighters":
				o.fighters = true
			"actors":
				if not ACTOR_STYLES.has(v):
					printerr("[render] --actors is color, onebit or team, got '%s'" % v)
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
