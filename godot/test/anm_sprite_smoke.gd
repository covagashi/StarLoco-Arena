extends SceneTree

## Headless check: the AnmSprite node loads an exported action dir and
## advances frames. Skips when converted assets are absent (git-ignored).
##
##   godot --headless --path godot -s test/anm_sprite_smoke.gd

const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const SET := "res://assets/anims/coach_805"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(SET):
		print("[skip] %s absent — run tools/asset-import export first" % SET)
		quit(0)
		return
	var spr := AnmSprite.new()
	root.add_child(spr)
	assert(spr.load_action(SET, "5_AnimStatique"), "load_action failed")
	assert(spr._frames.size() == 62, "expected 62 frames, got %d"
		% spr._frames.size())
	var f0: Dictionary = spr._frames[0]
	assert(f0.tex != null and f0.off is Vector2, "frame fields missing")
	spr._process(0.5)  # ~12 frames at 25fps
	assert(spr._cur != 0, "frame did not advance")
	print("[smoke] anm_sprite OK — %d frames @%.0ffps, f0 off=%s"
		% [spr._frames.size(), spr._fps, f0.off])
	quit(0)
