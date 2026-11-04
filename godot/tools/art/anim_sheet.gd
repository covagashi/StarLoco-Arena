extends SceneTree

## S35: photographs a rigged character GLB (tools/blender/characters/) as
## the game sees it: orthographic 2:1 camera, the arena sun, on one stone
## cell. Writes a few frames of every animation for a sheet, or every frame
## at 30 fps for a video. tools/art/anim_sheet.py builds both.
##
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot -s tools/art/anim_sheet.gd -- \
##       --model=art/characters/out/mannequin.glb --out=<dir> [--frames=6 | --video]
##       [--dirs=SE,SW,NE] [--size=200x240] [--zoom=1.6] [--anims=idle,walk]
##       [--focus=0.62]   (height the camera centres on: 1.1 = the face)
##       [--lift=0]       (raise a lone part off the cell)
##       [--pbr]          (the arenas' PBR look instead of the fighters' toon)
##
## Output: <dir>/<anim>/<dir>_<nn>.png and <dir>/index.json.

const ArenaScene := preload("res://src/maps/arena_scene.gd")
const Dress := preload("res://src/maps/kit_dress.gd")
const Toon := preload("res://src/anims/toon.gd")
const PX := 43.0 * 1.41421356
## Screen direction → model yaw (the model faces +Z; the camera sits at
## yaw 45, so yaw 45 faces the viewer).
const YAW := {"S": 45.0, "SE": 90.0, "E": 135.0, "NE": 180.0, "N": 225.0, "NW": 270.0, "W": 315.0, "SW": 0.0}

var opts := {"model": "art/characters/out/mannequin.glb", "out": "/tmp/anim_sheet", "frames": "6",
	"dirs": "SE", "size": "200x240", "zoom": "1.6", "anims": "", "focus": "0.62", "lift": "0"}
var cam := Camera3D.new()
var model: Node3D
var player: AnimationPlayer


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1]
		elif a == "--video":
			opts.video = true
		elif a == "--pbr":
			opts.pbr = true
	var sz: PackedStringArray = String(opts.size).split("x")
	DisplayServer.window_set_size(Vector2i(int(sz[0]), int(sz[1])))
	root.size = Vector2i(int(sz[0]), int(sz[1]))
	_run.call_deferred()


func _run() -> void:
	_stage()
	var path := ProjectSettings.globalize_path("res://" + String(opts.model)) \
		if not String(opts.model).begins_with("/") else String(opts.model)
	var doc := GLTFDocument.new()
	var st := GLTFState.new()
	if doc.append_from_file(path, st) != OK:
		push_error("can't read " + path)
		quit(1)
		return
	model = doc.generate_scene(st)
	model.position.y = float(opts.lift)
	if opts.has("pbr"):  # the arenas' look, for comparison
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			Dress.dress(mi)
	else:
		Toon.set_pixel(1.0 / (PX * float(opts.zoom)))
		Toon.dress(model)
	root.add_child(model)
	var players := model.find_children("*", "AnimationPlayer", true, false)
	# a part without animations (tools/blender/characters/parts) shows as "rest"
	player = players[0] if not players.is_empty() else null
	var names: Array = Array(player.get_animation_list()) if player else ["rest"]
	if opts.anims != "":
		names = Array(String(opts.anims).split(","))
	var index := {}
	var fps := 30.0
	for anim: String in names:
		var length := player.get_animation(anim).length if player else 0.0
		var n := ceili(length * fps) + 1 if opts.has("video") and player else int(opts.frames) if player else 1
		index[anim] = {"length": length, "frames": n}
		DirAccess.make_dir_recursive_absolute("%s/%s" % [opts.out, anim])
		for d: String in String(opts.dirs).split(","):
			model.rotation_degrees.y = YAW[d]
			for i in n:
				if player:
					var t := i / fps if opts.has("video") else length * i / maxf(1.0, n - 1)
					player.play(anim)
					player.seek(minf(t, length), true)
					player.pause()
				for k in (3 if i == 0 else 1):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("%s/%s/%s_%02d.png" % [opts.out, anim, d, i])
	var f := FileAccess.open(opts.out + "/index.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"anims": names, "dirs": String(opts.dirs).split(","), "index": index}))
	f.close()
	print("[anim_sheet] %d animations -> %s" % [names.size(), opts.out])
	quit(0)


## The game's light (arena_scene.gd), one stone cell under the feet, the game's
## orthographic camera at the given zoom.
func _stage() -> void:
	ArenaScene.add_lights(root)
	var cell := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1, 0.1, 1)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("8a8370")
	m.roughness = 1.0
	box.material = m
	cell.mesh = box
	cell.position.y = -0.05
	root.add_child(cell)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	var zoom := float(opts.zoom)
	cam.size = root.size.y / (PX * zoom)
	cam.rotation_degrees = Vector3(-30, 45, 0)
	var b := cam.transform.basis
	cam.position = Vector3(0, float(opts.focus), 0) + b.z * 20.0
	cam.near = 0.1
	cam.far = 60.0
	root.add_child(cam)
