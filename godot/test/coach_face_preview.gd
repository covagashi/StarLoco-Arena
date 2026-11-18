extends SceneTree
## S47 (owner, point 1: "al cambiar el color del pelo cambia el de los
## ojos"): the two coaches' faces up close, each with two hair colours, so
## a mask that tints the eyes shows at once (green and red hair, front).
##
##   xvfb-run -a godot --path godot --resolution 1280x720 -s test/coach_face_preview.gd -- OUT.png [--body] [--male]

const Direction8 := preload("res://src/util/direction8.gd")
const Fighter3D := preload("res://src/anims/fighter3d.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/coach_faces.png"
	var k := 14.0
	var foot_y := 1500.0
	var sexes := [0, 1]
	for a in OS.get_cmdline_user_args():
		if a.ends_with(".png"):
			out = a
		elif a == "--body":   # the whole figure at the creation screen's size
			k = 5.0
			foot_y = 690.0
		elif a == "--male":
			sexes = [0]
	var bg := ColorRect.new()
	bg.color = Color("e9ecf1")
	bg.size = Vector2(1280, 720)
	root.add_child(bg)
	# hair: a vivid green, a red and black; skin: the second tone
	# hair: a vivid green and a red; skin: the second tone
	var hairs := [Vector3(0.1, 1.0, 0.1), Vector3(1.0, 0.2, 0.2)]
	var col := 0
	for sex in sexes:
		for h in hairs:
			var spr = load("res://src/anims/figure.gd").new()
			spr.foot_pivot = true
			spr.tints = {1: Palettes.SKIN[1] * 1.25, 2: h * 1.25}
			spr.scale = Vector2(k, k)
			# the head of a ~110 px figure at this scale: feet far below
			spr.position = Vector2(160 + col * 320, foot_y)
			root.add_child(spr)
			if not Direction8.load_idle(spr, Fighter3D.coach_key(sex), Direction8.FRONT, "AnimMenu"):
				Direction8.load_idle_any(spr, Fighter3D.coach_key(sex))
			col += 1
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("[faces] ", out)
	quit(0)
