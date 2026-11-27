extends SceneTree
## S54 (paso 4): the coach-creation screen with a coach of our choosing, for
## the owner's sheets: no server.
##
##   xvfb-run -a godot --path godot --resolution 1920x1080 -s test/creation_coach_sheet.gd -- \
##       --out=<png> [--sex=0|1] [--skin=N] [--hair=N] [--wait=2]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := "/tmp/creation_coach.png"
	var sex := 1
	var skin := 1
	var hair := 0
	var wait := 2.0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv.size() < 2:
			continue
		match kv[0]:
			"out": out = kv[1]
			"sex": sex = int(kv[1])
			"skin": skin = int(kv[1])
			"hair": hair = int(kv[1])
			"wait": wait = float(kv[1])
	var model := GuiModel.new()
	model.set_value("localCoach", {"name": "Arel", "level": 1, "sex": sex, "skin": skin, "hair": hair,
		"actorDirection": 3, "actorMaterial": Palettes.coach_tints(skin, hair)})
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var c = load("res://src/ui/creation_screen.gd").new()
	layer.add_child(c)
	c.bind_model(model)
	await create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out)
	print("[creation_coach_sheet] ", out)
	quit(0)
