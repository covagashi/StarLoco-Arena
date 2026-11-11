extends Node2D

## S35b-marketing (tanda 3, post 38): a short staged fight with nothing but
## the 3D figures, on an arena cleared for marketing (1–6), for the movie
## maker. The HUD is hidden; fight_view places, sorts and lights everyone
## as in a real fight, and plays the 3D clips through the retail action
## names it already uses (Fighter3D.anim_for).
##
##   tools/promo/tanda3_render.sh 38    (writes override.cfg for the portrait
##   window and runs this under --write-movie)
##
## PROMO_MAP=<arena 1–6> (default 5), PROMO_ZOOM=<camera zoom> (default 2).

const State := preload("res://src/state.gd")
const Layout := preload("res://src/maps/arena_layout.gd")

const FIGHTERS := [
	# id, name, coach, team, breed, sex
	[1, "Arel", 7, 0, 8, 1],      # Yopuka f
	[3, "Cael", 7, 0, 2, 0],      # Osamodas m: the summoner
	[5, "Eris", 7, 0, 11, 1],     # Sacrogrito f
	[2, "Brune", 8, 1, 12, 0],    # Pandawa m
	[4, "Dorna", 8, 1, 4, 1],     # Sram f
	[6, "Faro", 8, 1, 5, 0],      # Xelor m
]
const SUMMON := 50

var fight: Node


func _ready() -> void:
	State.fight_world = Layout.world_of(5 if OS.get_environment("PROMO_MAP") == "" else int(OS.get_environment("PROMO_MAP")))
	State.my_coach_id = 7
	State.spectating = true
	State.fighters = {}
	var timeline := []
	for r in FIGHTERS:
		State.fighters[r[0]] = {"id": r[0], "name": r[1], "coach": r[2], "team": r[3],
			"breed": r[4], "sex": r[5], "spells": [], "cards": []}
		timeline.append(r[0])
	State.fight_data = {"timeline": timeline, "ca": 30000}
	fight = preload("res://src/fight/fight_view.tscn").instantiate()
	add_child(fight)
	var slots := {0: fight._fmd.get("team0", []), 1: fight._fmd.get("team1", [])}
	var used := {0: 0, 1: 0}
	for fid in timeline:
		var t := int(State.fighters[fid].team)
		var c: Dictionary = slots[t][used[t] % slots[t].size()]
		used[t] += 1
		fight._place_actor({"id": fid, "x": int(c.x), "y": int(c.y), "z": int(c.z), "dir": 1 if t == 0 else 5})
	fight._table_turn = 3
	fight._on_turn_begin(1)
	for n in fight.get_children():   # the HUD; the 3D arena is a CanvasLayer too (layer -1)
		if n is CanvasLayer and n.layer >= 0:
			n.visible = false
	for fid in fight._sprites:
		for c in fight._sprites[fid].get_children():
			if c is Label:
				c.visible = false
	fight.cam.zoom = Vector2.ONE * float(OS.get_environment("PROMO_ZOOM") if OS.get_environment("PROMO_ZOOM") != "" else "2.0")
	_aim(_middle(), true)
	_run()


func _middle() -> Vector2:
	var p := Vector2.ZERO
	for fid in fight._sprites:
		p += fight._sprites[fid].position
	return p / max(1, fight._sprites.size()) + Vector2(0, -30)


func _pos(fid: int) -> Vector2:
	return fight._sprites[fid].position + Vector2(0, -40)


func _aim(p: Vector2, now := false, zoom := 0.0, sec := 0.8) -> void:
	if now:
		fight.cam.position = p
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(fight.cam, "position", p, sec)
	if zoom > 0.0:
		tw.tween_property(fight.cam, "zoom", Vector2.ONE * zoom, sec)


func _act(fid: int, base: String, hold := false) -> void:
	var spr = fight._sprites.get(fid)
	if spr == null:
		return
	var dir := int(fight._actor_dir.get(fid, 1))
	if spr.play_once(fight._anim_set(State.fighters[fid]), "%d_%s" % [dir, base], hold) and not hold:
		var cb: Callable = fight._restore_idle.bind(spr, fid)
		if not spr.action_finished.is_connected(cb):
			spr.action_finished.connect(cb, CONNECT_ONE_SHOT)


func _hit(fid: int, n: int) -> void:
	_act(fid, "AnimHit")
	fight._float_text(fid, "-%d" % n, Color(1.0, 0.35, 0.3))


func _cell(fid: int) -> Vector3i:
	return fight._actor_cells[fid]


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _run() -> void:
	var z: float = fight.cam.zoom.x
	await _wait(1.0)
	# the summoner calls a sheep next to him
	_aim(_pos(3), false, z * 1.5)
	await _wait(0.9)
	fight._face_toward(3, Vector2i(_cell(3).x + 1, _cell(3).y))
	_act(3, "AnimSort-Cast")
	await _wait(0.7)
	var c := _cell(3)
	var at := Vector2i(c.x + 1, c.y)
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1)]:
		var p: Vector2i = Vector2i(c.x, c.y) + d
		if fight._cells.has(p) and fight._cells[p].ground and fight._occupied_fighter(p) < 0:
			at = p
			break
	State.fighters[SUMMON] = {"id": SUMMON, "name": "Sheep", "coach": 7, "team": 0, "look": 8006,
		"summon": true, "summon_of": 3, "hp": 30, "spells": [], "cards": []}
	fight._place_actor({"id": SUMMON, "x": at.x, "y": at.y, "z": c.z, "dir": 1})
	var sspr: Node2D = fight._sprites[SUMMON]
	for l in sspr.get_children():
		if l is Label:
			l.visible = false
	sspr.scale = Vector2(0.05, 0.05)
	create_tween().tween_property(sspr, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await _wait(1.2)
	# the Yopuka strikes the closest enemy; while the camera is on the
	# summon she steps next to it (off screen), so both are in the shot
	var target := 2
	var best := 999
	for fid in [2, 4, 6]:
		var d: int = abs(_cell(fid).x - _cell(1).x) + abs(_cell(fid).y - _cell(1).y)
		if d < best:
			best = d
			target = fid
	var tc := _cell(target)
	for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var p: Vector2i = Vector2i(tc.x, tc.y) + d
		if fight._cells.has(p) and fight._cells[p].ground and fight._occupied_fighter(p) < 0:
			fight._move_actor(1, Vector3i(p.x, p.y, tc.z))
			break
	_aim((_pos(1) + _pos(target)) / 2, false, z * 1.4)
	await _wait(0.8)
	fight._face_toward(1, Vector2i(_cell(target).x, _cell(target).y))
	fight._face_toward(target, Vector2i(_cell(1).x, _cell(1).y))
	_act(1, "AnimArme")
	await _wait(0.35)
	_hit(target, 42)
	await _wait(1.0)
	# the Sram answers with a spell at the sheep
	_aim((_pos(4) + _pos(SUMMON)) / 2, false, z * 1.15)
	await _wait(0.7)
	fight._face_toward(4, Vector2i(_cell(SUMMON).x, _cell(SUMMON).y))
	_act(4, "AnimSort-Cast")
	await _wait(0.5)
	_hit(SUMMON, 18)
	await _wait(1.0)
	# the Xelor goes down
	_aim(_pos(6), false, z * 1.5)
	await _wait(0.6)
	_hit(6, 57)
	await _wait(0.35)
	_act(6, "AnimMort", true)
	await _wait(1.4)
	# the winners celebrate
	_aim(_middle(), false, z)
	await _wait(0.6)
	for fid in [1, 3, 5]:
		_act(fid, "AnimEmote")
	_act(SUMMON, "AnimEmote")
	await _wait(2.0)
	get_tree().quit()
