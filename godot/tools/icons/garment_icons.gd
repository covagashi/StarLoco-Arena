extends Node2D
## S38: icons for the coach garments (S35c: shirts, trousers, skirts, boots
## and marks, fitted to the coach's body, so they can't be shown alone): the
## coach wears only that garment, facing three-quarters, and the render is
## cut to the part of the body it covers. Writes the bare renders beside the
## other coach pieces' (art/ui/out/equip_coach/<card>.png); equip_icons.py
## --coach plates them all.
##   xvfb-run godot --path godot --resolution 1280x720 tools/icons/garment_icons.tscn

const Direction8 := preload("res://src/util/direction8.gd")
const OUT := "res://art/ui/out/equip_coach/"
const FOOT := Vector2(640, 700)
const SCALE := 6.0
## slot → the band of the figure's height it covers (top, bottom)
const BAND := {"torso": [0.30, 0.66], "mark": [0.30, 0.62], "pants": [0.52, 0.96],
	"skirt": [0.50, 0.80], "boots": [0.80, 1.0]}


var _done: Array = []


func _ready() -> void:
	get_viewport().transparent_bg = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var pieces: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/equipment/pieces.json"))["coach"]
	var made := 0
	var spr = preload("res://src/anims/anm_sprite.gd").new()
	spr.foot_pivot = true
	spr.position = FOOT
	spr.scale = Vector2(SCALE, SCALE)
	spr.tints = Palettes.coach_tints(1, 1)
	add_child(spr)
	Direction8.load_idle(spr, "anims/coach_7000", 1)
	await get_tree().create_timer(0.8).timeout
	var m = spr.model3d
	for cid in pieces:
		var piece := str(pieces[cid])
		var slot := piece.get_slice("_", 0)
		if not BAND.has(slot) or m == null:
			continue
		for s in BAND:
			m.equip(s, "")
		m.equip(slot, piece)
		await get_tree().create_timer(0.35).timeout
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var used := img.get_used_rect()
		var band: Array = BAND[slot]
		var top := used.position.y + int(used.size.y * float(band[0]))
		var bot := used.position.y + int(used.size.y * float(band[1]))
		var h := bot - top
		var side := maxi(h, int(used.size.x * 0.9))
		var at := Vector2i(used.get_center().x - side / 2, top - (side - h) / 2)
		var crop := Image.create(side, side, false, Image.FORMAT_RGBA8)
		crop.fill(Color(0, 0, 0, 0))
		crop.blit_rect(img, Rect2i(at, Vector2i(side, side)), Vector2i.ZERO)
		crop.resize(256, 256, Image.INTERPOLATE_LANCZOS)
		crop.save_png(OUT + "%s.png" % str(cid))
		_done.append(str(cid))
		made += 1
	# equip_icons.py keeps these squares as they are (the band is the crop)
	var f := FileAccess.open(OUT + "garments.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_done))
	print("[garments] made ", made)
	get_tree().quit()
