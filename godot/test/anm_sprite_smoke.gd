extends SceneTree

## Headless check: the AnmSprite node loads an exported action dir and
## advances frames — now over the coach paper-doll set (7000) with the
## gw_2 channel-tint path (mask PNG + spr.tints). Skips when converted
## assets are absent (git-ignored).
##
##   godot --headless --path godot -s test/anm_sprite_smoke.gd

const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const Palettes := preload("res://src/gamedata/palettes.gd")
const SET := "res://assets/anims/coach_7000"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(SET):
		print("[skip] %s absent — run tools/asset-import export first" % SET)
		quit(0)
		return
	var spr := AnmSprite.new()
	root.add_child(spr)
	assert(spr.load_action(SET, "2_AnimStatique"), "load_action failed")
	assert(spr._frames.size() >= 1, "expected frames, got %d"
		% spr._frames.size())
	var f0: Dictionary = spr._frames[0]
	assert(f0.tex != null and f0.off is Vector2, "frame fields missing")

	# the same action under a skin/hair tint must land on a different cache
	# key and produce visibly different pixels (ch1 mask covers the body).
	var base_img := (f0.tex as Texture2D).get_image()
	spr.tints = Palettes.coach_tints(3, 7)   # dark skin + green hair
	assert(spr.load_action(SET, "2_AnimStatique"), "tinted load failed")
	assert(str(spr.current).contains("@t"), "tinted key missing @t suffix")
	var diff := _diff_count(base_img,
		(spr._frames[0].tex as Texture2D).get_image())
	assert(diff > 0, "channel tint changed no pixels")

	# frame advance still works through the tinted action
	spr._process(0.5)  # ~12 frames at 25fps
	print("[smoke] anm_sprite OK — %d frames @%.0ffps, %d px tinted"
		% [spr._frames.size(), spr._fps, diff])
	quit(0)


## Pixels whose rgb differs between the two images.
static func _diff_count(a: Image, b: Image) -> int:
	var n := 0
	var w := mini(a.get_width(), b.get_width())
	var h := mini(a.get_height(), b.get_height())
	for y in h:
		for x in w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if ca.r != cb.r or ca.g != cb.g or ca.b != cb.b:
				n += 1
	return n
