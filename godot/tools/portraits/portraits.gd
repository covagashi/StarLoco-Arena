extends Node2D
## S38: the fight's portraits from the 3D figures (owner, 2026-11-11: the
## current fighter's circle and the turn order still showed the retail
## art). Each class and sex, the two coaches and every summon is rendered
## on a transparent background, its outline found, and a square cut: head
## and shoulders for the humanoids, the whole body for the summons. Writes
## assets/ui/portraits/<id>.png (fighters breed*10+sex, coaches 7000/7001,
## summons their look), which FighterCard.portrait_for() reads first.
##   xvfb-run godot --path godot --resolution 1280x720 tools/portraits/portraits.tscn

const Direction8 := preload("res://src/util/direction8.gd")
const Fighter3D := preload("res://src/anims/fighter3d.gd")
const OUT := "res://assets/ui/portraits/"
const SIDE := 160
const FOOT := Vector2(640, 700)
const SCALE := 6.0


func _ready() -> void:
	get_viewport().transparent_bg = true
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var jobs: Array = []   # [id, set, tints, whole body]
	for breed in range(1, 13):
		for sex in 2:
			jobs.append([breed * 10 + sex, "anims/fighter_-1%d%d" % [breed, sex], {}, false])
	for sex in 2:
		jobs.append([7000 + sex, "anims/coach_700%d" % sex, Palettes.coach_tints(1, 1), false])
	for look in Fighter3D.SUMMONS:
		jobs.append([int(look), "anims/npc_%d" % int(look), {}, true])
	var made := 0
	for j in jobs:
		var spr = preload("res://src/anims/anm_sprite.gd").new()
		spr.foot_pivot = true
		spr.position = FOOT
		spr.scale = Vector2(SCALE, SCALE)
		if not (j[2] as Dictionary).is_empty():
			spr.tints = j[2]
		add_child(spr)
		if not Direction8.load_idle(spr, str(j[1]), 1):
			spr.queue_free()
			print("[portraits] no figure for ", j[1])
			continue
		await get_tree().create_timer(0.6).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var used := img.get_used_rect()
		if used.size.x < 8 or used.size.y < 8:
			spr.queue_free()
			continue
		var side: int
		var at: Vector2i
		if j[3]:
			side = int(maxf(used.size.x, used.size.y) * 1.08)
			at = Vector2i(used.get_center()) - Vector2i(side / 2, side / 2)
		else:
			side = int(used.size.y * 0.42)
			at = Vector2i(used.get_center().x - side / 2, used.position.y - int(side * 0.04))
		var crop := Image.create(side, side, false, Image.FORMAT_RGBA8)
		crop.fill(Color(0, 0, 0, 0))
		crop.blit_rect(img, Rect2i(at, Vector2i(side, side)), Vector2i.ZERO)
		crop.resize(SIDE, SIDE, Image.INTERPOLATE_LANCZOS)
		crop.save_png(OUT + "%d.png" % int(j[0]))
		made += 1
		spr.queue_free()
		await get_tree().process_frame
	print("[portraits] made ", made, " of ", jobs.size())
	get_tree().quit()
