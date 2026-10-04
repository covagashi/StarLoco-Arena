extends SceneTree

## Visual check: dump coach_7000 frames — untinted vs skin/hair tinted —
## plus a tinted fighter frame, side by side for screenshot review.
##   godot --headless --path godot -s test/tint_shot.gd

const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const Palettes := preload("res://src/gamedata/palettes.gd")


func _init() -> void:
	var out := "user://tint_check"
	DirAccess.make_dir_recursive_absolute(out)
	_dump("res://assets/anims/coach_7000", "2_AnimStatique", {},
		"%s/coach_plain.png" % out)
	_dump("res://assets/anims/coach_7000", "2_AnimStatique",
		Palettes.coach_tints(0, 5), "%s/coach_s0_h5.png" % out)
	_dump("res://assets/anims/coach_7000", "2_AnimStatique",
		Palettes.coach_tints(2, 10), "%s/coach_s2_h10.png" % out)
	_dump("res://assets/anims/coach_7001", "2_AnimStatique",
		Palettes.coach_tints(0, 3), "%s/coach7001_s0_h3.png" % out)
	_dump("res://assets/anims/coach_7000", "2_AnimMarche",
		Palettes.coach_tints(0, 5), "%s/coach_marche.png" % out)
	_dump("res://assets/anims/fighter_-110", "2_AnimStatique",
		Palettes.fighter_tints(9, 3, 25), "%s/fighter_-110_tint.png" % out)
	_dump("res://assets/anims/fighter_-110", "2_AnimStatique", {},
		"%s/fighter_-110_plain.png" % out)
	print("[shot] dumped to %s" % ProjectSettings.globalize_path(out))
	quit(0)


func _dump(set_dir: String, action: String, tints: Dictionary,
		path: String) -> void:
	var spr := AnmSprite.new()
	root.add_child(spr)
	if not spr.load_action(set_dir, action, tints):
		print("[shot] MISSING %s/%s" % [set_dir, action])
		spr.queue_free()
		return
	var img: Image = (spr._frames[0].tex as Texture2D).get_image()
	img.save_png(path)
	print("[shot] %s ← %s/%s" % [path.get_file(), set_dir.get_file(),
		action])
	spr.queue_free()
