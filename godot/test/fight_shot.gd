extends SceneTree

## Dev utility: render fight_view to a PNG — requires a real display driver
## (dummy driver in --headless yields a null texture; run windowed).
##   godot --path godot -s test/fight_shot.gd -- <map_id> <out.png>


# _initialize, not _init: fight_view.gd references autoloads (I18n), which are
# only registered once the tree is up -- loading it from _init fails to compile.
func _initialize() -> void:
	# This tool exists only to produce a PNG. The dummy/headless renderer has no
	# viewport texture, so there is nothing useful to do there -- fail fast
	# instead of erroring mid-function and leaving the process hung.
	if DisplayServer.get_name() == "headless":
		printerr("[shot] fight_shot needs a real display, not --headless. "
			+ "Run: godot --path godot -s test/fight_shot.gd -- <map_id> <out.png>")
		quit(1)
		return
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
