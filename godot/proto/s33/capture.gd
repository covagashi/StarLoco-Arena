extends SceneTree

## S33 prototype director: the same fighter in three techniques on our own
## arena, captured for the owner to choose from.
##
##   xvfb-run -s "-screen 0 1280x720x24" godot --path godot --fixed-fps 30 \
##       -s proto/s33/capture.gd -- --out=<dir> [--video] [--measure]
##
## Writes <out>/<tech>_<state>[_close].png (tech = A live 3D, B 3D→sprite,
## C 2D cutout; state = idle/walk/cast/hit/die/dirs), <out>/elements.png,
## with --video <out>/video/<tech>/NNNN.png, and with --measure
## <out>/measure.json (bake weight, frame times).

const F3 := preload("res://proto/s33/fighter3d.gd")
const F2 := preload("res://proto/s33/fighter2d.gd")
const Arena := preload("res://proto/s33/arena.gd")
const Vfx := preload("res://proto/s33/vfx.gd")
const Pose := preload("res://proto/s33/pose.gd")

const W := 560
const H := 330
const DT := 1.0 / 30.0
const ELEMENTS := ["fuego", "agua", "tierra", "aire", "neutro"]
const CAST_EVERY := 1.25
const CAST_FROM := 2.4

var out := ""
var video := false
var measure := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a == "--video":
			video = true
		elif a == "--measure":
			measure = true
	if out == "":
		push_error("--out=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	RenderingServer.set_default_clear_color(Color("1e1f18"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_set_size(Vector2i(W, H))
	root.size = Vector2i(W, H)
	_run.call_deferred()


func _run() -> void:
	for tech in ["A", "B", "C"]:
		await _timeline(tech)
		await _directions(tech)
	await _elements()
	if measure:
		await _measure()
	quit(0)


# --- stage -----------------------------------------------------------------

func _fighter(tech: String) -> Node2D:
	var f: Node2D = F2.new() if tech == "C" else F3.new()
	if tech == "B":
		f.baked = true
	return f


func _stage(tech: String) -> Dictionary:
	var world := Node2D.new()
	root.add_child(world)
	var arena := Arena.new()
	arena.position = Vector2(W / 2.0, 70)
	world.add_child(arena)
	var actors := Node2D.new()
	actors.y_sort_enabled = true
	arena.add_child(actors)
	var vfx := Vfx.new()
	arena.add_child(vfx)
	var cam := Camera2D.new()
	cam.position = Vector2(W / 2.0, H / 2.0)
	world.add_child(cam)
	cam.make_current()
	return {"world": world, "arena": arena, "actors": actors, "vfx": vfx,
		"cam": cam, "tech": tech}


func _add(st: Dictionary, c: Vector2i, facing: String, team: int) -> Node2D:
	var f := _fighter(st.tech)
	f.position = st.arena.cell(c)
	st.actors.add_child(f)
	f.facing = facing
	st.arena.rings[c] = team
	st.arena.queue_redraw()
	return f


func _close(st: Dictionary, on: Node2D, zoom: float) -> void:
	st.cam.zoom = Vector2(zoom, zoom)
	st.cam.position = st.arena.to_global(on.position + Vector2(0, -36))
	_set_res(st, zoom)


func _wide(st: Dictionary) -> void:
	st.cam.zoom = Vector2.ONE
	st.cam.position = Vector2(W / 2.0, H / 2.0)
	_set_res(st, 1.0)


func _set_res(st: Dictionary, s: float) -> void:
	for f in st.actors.get_children():
		if "res_scale" in f:
			f.res_scale = s


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])


# --- the timeline: idle → walk → five casts (one per element) → death -------

func _timeline(tech: String) -> void:
	var st := _stage(tech)
	var caster := _add(st, Vector2i(0, 2), "SE", 0)
	var target := _add(st, Vector2i(3, 2), "NW", 1)
	var vdir := "%s/video/%s" % [out, tech]
	if video:
		DirAccess.make_dir_recursive_absolute(vdir)
	var shots := {0.5: ["idle", caster], 1.775: ["walk", caster],
		2.94: ["cast", caster], 3.2: ["hit", target], 9.55: ["die", target]}
	var end := CAST_FROM + CAST_EVERY * ELEMENTS.size() + 1.6
	var n := 0
	var t := 0.0
	var fired := {}
	while t < end:
		# caster
		if t < 1.6:
			_play(caster, "idle", t)
		elif t < 2.3:
			_play(caster, "walk", t - 1.6)
			var k := (t - 1.6) / 0.7
			caster.position = st.arena.cell(Vector2i(0, 2)).lerp(st.arena.cell(Vector2i(1, 2)), k)
			st.arena.rings.erase(Vector2i(0, 2))
			st.arena.rings[Vector2i(1, 2)] = 0
			st.arena.queue_redraw()
		elif t < CAST_FROM:
			caster.position = st.arena.cell(Vector2i(1, 2))
			_play(caster, "idle", t)
		else:
			var i := int((t - CAST_FROM) / CAST_EVERY)
			var lt := t - CAST_FROM - i * CAST_EVERY
			if i < ELEMENTS.size():
				caster.element = ELEMENTS[i]
				_play(caster, "cast" if lt < Pose.LENGTH.cast else "idle", lt)
				if lt >= Pose.CAST_RELEASE and not fired.has(i):
					fired[i] = true
					var from: Vector2 = st.arena.to_local(caster.to_global(caster.staff_tip()))
					st.vfx.cast(from, target.position + Vector2(0, -30), ELEMENTS[i])
			else:
				_play(caster, "idle", lt)
		# target
		var tt := t - CAST_FROM
		var ti := int(tt / CAST_EVERY) if tt >= 0.0 else -1
		var hit_t := tt - ti * CAST_EVERY - (Pose.CAST_RELEASE + Vfx.FLIGHT)
		var die_at := CAST_FROM + CAST_EVERY * ELEMENTS.size()
		if t >= die_at:
			_play(target, "die", t - die_at)
		elif ti >= 0 and hit_t >= 0.0 and hit_t < Pose.LENGTH.hit:
			_play(target, "hit", hit_t)
		else:
			_play(target, "idle", t + 0.7)
		st.vfx.step(DT)
		await process_frame
		if video:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%04d.png" % [vdir, n])
		for at in shots:
			if absf(t - at) < DT * 0.5:
				var s: Array = shots[at]
				paused = true
				await _shot("%s_%s" % [tech, s[0]])
				_close(st, s[1], 3.0)
				await _shot("%s_%s_close" % [tech, s[0]])
				_wide(st)
				paused = false
		t += DT
		n += 1
	st.world.queue_free()
	await process_frame


func _play(f: Node2D, anim: String, t: float) -> void:
	f.anim = anim
	f.t = t


func _directions(tech: String) -> void:
	var st := _stage(tech)
	var fs := []
	var dirs := ["SW", "SE", "NW", "NE"]
	for i in 4:
		var f := _add(st, Vector2i(i, 3 - i), dirs[i], 0)
		_play(f, "idle", 0.5)
		fs.append(f)
	st.cam.zoom = Vector2(1.7, 1.7)
	st.cam.position = st.arena.to_global(st.arena.cell(Vector2i(1, 2)).lerp(
		st.arena.cell(Vector2i(2, 1)), 0.5) + Vector2(0, -36))
	_set_res(st, 1.7)
	await _shot("%s_dirs" % tech)
	st.world.queue_free()
	await process_frame


func _elements() -> void:
	var st := _stage("C")
	st.cam.zoom = Vector2(1.25, 1.25)
	for i in ELEMENTS.size():
		st.vfx.burst(st.arena.cell(Vector2i(i, 4 - i)) + Vector2(0, -10), ELEMENTS[i])
	var frames := 0
	while frames < 6:
		st.vfx.step(DT)
		await process_frame
		frames += 1
	st.cam.position = st.arena.to_global(st.arena.cell(Vector2i(2, 2)) + Vector2(0, -24))
	await _shot("elements")
	st.world.queue_free()
	await process_frame


# --- measurements -------------------------------------------------------------

func _measure() -> void:
	var res := {}
	# B: what an offline bake ships for the 5 prototype anims × 5 directions
	# (the other 3 are mirrors) at 12 fps, game resolution.
	var st := _stage("A")
	var f: Node2D = _add(st, Vector2i(2, 2), "SE", 0)
	await process_frame
	var t0 := Time.get_ticks_msec()
	var bytes: int = await f.bake_frames("%s/bake" % out, Pose.ANIMS,
		["S", "SE", "E", "NE", "N"])
	res["bake_bytes_5anims_5dirs"] = bytes
	res["bake_files"] = DirAccess.get_files_at("%s/bake" % out).size()
	res["bake_ms"] = Time.get_ticks_msec() - t0
	st.world.queue_free()
	await process_frame
	# frame time with 12 fighters walking, per technique (llvmpipe under xvfb:
	# relative numbers, not the Ally's GPU)
	for tech in ["A", "B", "C"]:
		var s2 := _stage(tech)
		var all := []
		for i in 12:
			var g := _add(s2, Vector2i(i % 4, i / 4), "SE", i % 2)
			all.append(g)
		for w in 10:
			await process_frame
		var tt := 0.0
		var start := Time.get_ticks_usec()
		for k in 120:
			tt += DT
			for g in all:
				_play(g, "walk", tt)
			await process_frame
		res["frame_ms_12_fighters_" + tech] = (Time.get_ticks_usec() - start) / 120000.0
		s2.world.queue_free()
		await process_frame
	var fa := FileAccess.open("%s/measure.json" % out, FileAccess.WRITE)
	fa.store_string(JSON.stringify(res, "  "))
	print(JSON.stringify(res))
