extends SceneTree
## S53 (A4, owner: "triángulos feos en los coaches: mujer en codo, muslo y
## pelo junto a la oreja; hombre en las costillas"): one coach, whole, from
## four sides (front, three-quarters, side, back), at the creation screen's
## size, with a hair and a skin colour, so the mask and the toon bands can
## be judged before and after.
##
##   xvfb-run -a godot --path godot --resolution 1600x720 -s test/coach_sheet.gd -- OUT.png [--male] [--hair=r,g,b] [--skin=N|r,g,b] [--k=5]
##       [--y=FOOT_Y] [--dirs=2,1,0,6]   (a bigger --k with a lower foot: up close)

const Direction8 := preload("res://src/util/direction8.gd")
const Fighter3D := preload("res://src/anims/fighter3d.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/coach_sheet.png"
	var sex := 1
	var hair := Vector3(0.1, 1.0, 0.1)
	var skin := Vector3.ZERO   # zero: Palettes.SKIN[1]
	var k := 5.0
	var foot := -1.0
	var dirs := [Direction8.FRONT, 1, 0, 6]   # S, SE, E, N
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			out = a
		elif a == "--male":
			sex = 0
		elif a.begins_with("--hair="):
			var c := a.trim_prefix("--hair=").split(",")
			hair = Vector3(float(c[0]), float(c[1]), float(c[2]))
		elif a.begins_with("--skin="):
			var c := a.trim_prefix("--skin=").split(",")
			skin = Palettes.SKIN[int(c[0])] if c.size() == 1 else Vector3(float(c[0]), float(c[1]), float(c[2]))
		elif a.begins_with("--k="):
			k = float(a.trim_prefix("--k="))
		elif a.begins_with("--y="):
			foot = float(a.trim_prefix("--y="))
		elif a.begins_with("--dirs="):
			dirs = Array(a.trim_prefix("--dirs=").split(",")).map(func(d): return int(d))
	var vp := root.get_visible_rect().size
	var bg := ColorRect.new()
	bg.color = Color("e9ecf1")
	bg.size = vp
	root.add_child(bg)
	for i in dirs.size():
		var spr = load("res://src/anims/figure.gd").new()
		spr.foot_pivot = true
		spr.tints = {1: (skin if skin != Vector3.ZERO else Palettes.SKIN[1]) * 1.25, 2: hair * 1.25}
		spr.scale = Vector2(k, k)
		spr.position = Vector2(vp.x * (i + 0.5) / dirs.size(), foot if foot > 0 else vp.y - 20.0)
		root.add_child(spr)
		if not Direction8.load_idle(spr, Fighter3D.coach_key(sex), dirs[i], "AnimMenu"):
			Direction8.load_idle(spr, Fighter3D.coach_key(sex), dirs[i])
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("[coach_sheet] ", out)
	quit(0)
