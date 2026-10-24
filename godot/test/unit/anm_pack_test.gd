extends RefCounted
## S15: AnmSprite reads a packed action (one atlas.png + `r` rects, from
## tools/asset-import/anm_pack.py) exactly like the loose f*.png frames it
## replaces — same pixels, offsets and sizes, and the tint masks too.

const AnmSprite := preload("res://src/anims/anm_sprite.gd")
const ROOT := "user://anm_pack_test/"


func run(t) -> void:
	t.suite("anm_pack")
	var sizes := [Vector2i(5, 7), Vector2i(9, 3), Vector2i(4, 4)]
	var dir := ROOT + "anims/set"
	DirAccess.make_dir_recursive_absolute(dir + "/Loose")
	DirAccess.make_dir_recursive_absolute(dir + "/Packed")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var frames_loose := []
	var frames_packed := []
	var atlas := Image.create(20, 7, false, Image.FORMAT_RGBA8)
	var matlas := Image.create(20, 7, false, Image.FORMAT_RGBA8)
	var x := 0
	for i in sizes.size():
		var sz: Vector2i = sizes[i]
		var img := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		var mask := Image.create(sz.x, sz.y, false, Image.FORMAT_RGBA8)
		for yy in sz.y:
			for xx in sz.x:
				img.set_pixel(xx, yy, Color(rng.randf(), rng.randf(), rng.randf(), 1.0))
				mask.set_pixel(xx, yy, Color(1, 0, 0, 1) if (xx + yy) % 2 == 0 else Color(0, 0, 0, 1))
		img.save_png(dir + "/Loose/f%03d.png" % i)
		mask.save_png(dir + "/Loose/f%03d_m.png" % i)
		atlas.blit_rect(img, Rect2i(Vector2i.ZERO, sz), Vector2i(x, 0))
		matlas.blit_rect(mask, Rect2i(Vector2i.ZERO, sz), Vector2i(x, 0))
		frames_loose.append({"png": "f%03d.png" % i, "mask": "f%03d_m.png" % i, "w": sz.x, "h": sz.y, "ox": -i, "oy": -2 * i})
		frames_packed.append({"r": [x, 0, sz.x, sz.y], "masked": true, "w": sz.x, "h": sz.y, "ox": -i, "oy": -2 * i})
		x += sz.x
	atlas.save_png(dir + "/Packed/atlas.png")
	matlas.save_png(dir + "/Packed/atlas_m.png")
	_write(dir + "/Loose/meta.json", {"fps": 12, "frames": frames_loose})
	_write(dir + "/Packed/meta.json", {"fps": 12, "frames": frames_packed, "atlas": "atlas.png", "mask_atlas": "atlas_m.png"})
	AssetPaths.set_roots([ROOT])
	for tints in [{}, {1: Vector3(0.5, 0.2, 0.9)}]:
		var a = AnmSprite.new()
		var b = AnmSprite.new()
		var ok_a: bool = a.load_action("anims/set", "Loose", tints)
		var ok_b: bool = b.load_action("anims/set", "Packed", tints)
		t.ok(ok_a and ok_b, "both layouts load (tints %s)" % str(tints))
		t.eq(b._frames.size(), a._frames.size(), "same frame count")
		var same := true
		for i in a._frames.size():
			var fa: Dictionary = a._frames[i]
			var fb: Dictionary = b._frames[i]
			if fa.off != fb.off or fa.w != fb.w or fa.h != fb.h \
					or fa.tex.get_image().get_data() != fb.tex.get_image().get_data():
				same = false
		t.ok(same, "packed frames equal the loose ones, pixel for pixel (tints %s)" % str(tints))
		a.free()
		b.free()
	AssetPaths.reset_roots()


func _write(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
