extends SceneTree

## Dev utility: render fight_view to a PNG — requires a real display driver
## (dummy driver in --headless yields a null texture; run windowed).
##   godot --path godot -s test/fight_shot.gd -- <map_id> <out.png>


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var map_id := int(args[0]) if args.size() > 0 else 10
	var out := args[1] if args.size() > 1 else "/tmp/fight.png"
	var scene: Node2D = load("res://src/fight/fight_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame  # let _ready run (onready vars + initial _load)
	if args.size() > 0:
		scene.get_node("UI/TopBar/MapId").text = str(map_id)
		scene._load()
	await create_timer(0.5).timeout
	var tex := root.get_texture()
	var img := tex.get_image() if tex != null else null
	if img == null:
		print("[skip] no renderer (headless dummy driver)")
		quit(0)
		return
	img.save_png(out)
	print("[shot] %s %dx%d" % [out, img.get_width(), img.get_height()])
	quit(0)
