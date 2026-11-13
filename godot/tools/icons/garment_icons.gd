extends Node2D
## S38: icons for the coach garments (S35c: shirts, trousers, skirts, boots
## and marks, fitted to the coach's body, so they can't be shown alone): the
## coach, its pose frozen, is rendered bare once (_bare.png) and then wearing
## only each garment (casting no shadow), full frame, beside the other coach pieces' renders
## (art/ui/out/equip_coach/<card>.png). equip_icons.py --coach takes the
## difference with the bare render as the garment's outline, cuts to it and
## dims the body around it, then plates them all.
##   xvfb-run godot --path godot --resolution 1280x720 tools/icons/garment_icons.tscn

const Direction8 := preload("res://src/util/direction8.gd")
const OUT := "res://art/ui/out/equip_coach/"
const FOOT := Vector2(640, 660)
const SCALE := 6.0
const SLOTS := ["torso", "mark", "pants", "skirt", "boots"]


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
	if m == null:
		get_tree().quit(1)
		return
	# one still pose, so the bare render and the dressed ones line up
	if m._player != null:
		m._player.seek(0.0, true)
		m._player.pause()
	for s in SLOTS:
		m.equip(s, "")
	await _shot(OUT + "_bare.png")
	for cid in pieces:
		var piece := str(pieces[cid])
		var slot := piece.get_slice("_", 0)
		if not slot in SLOTS:
			continue
		for s in SLOTS:
			m.equip(s, "")
		m.equip(slot, piece)
		# its shadow on the body would count as garment in the difference
		for g: MeshInstance3D in m.find_children("*", "MeshInstance3D", true, false):
			if g.has_meta("garment"):
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		await _shot(OUT + "%s.png" % str(cid))
		_done.append(str(cid))
		made += 1
	# equip_icons.py cuts these against _bare.png
	var f := FileAccess.open(OUT + "garments.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(_done))
	print("[garments] made ", made)
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
