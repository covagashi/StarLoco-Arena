extends SceneTree

## S45: an arena with no interface, for the screens' backdrops (each screen
## its own arena, not the same map behind everything). Needs a real display.
##   godot --path godot --resolution 1280x720 -s test/arena_backdrop.gd -- <map_id> <out.png> [zoom]


func _initialize() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("[backdrop] needs a real display (xvfb-run), not --headless")
		quit(1)
		return
	var args := OS.get_cmdline_user_args()
	var map_id := int(args[0]) if args.size() > 0 else 1
	var out := args[1] if args.size() > 1 else "/tmp/arena.png"
	var zoom := float(args[2]) if args.size() > 2 else 1.0
	var scene: Node2D = load("res://src/fight/fight_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.get_node("UI/TopBar/MapId").text = str(map_id)
	scene._load()
	for n in ["UI"]:
		var ui = scene.get_node_or_null(n)
		if ui != null:
			ui.visible = false
	if scene.get("cam") != null:
		scene.cam.zoom = Vector2(zoom, zoom)
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("[backdrop] ", out)
	quit(0)
