extends SceneTree

## Drives the map editor without a person, for evidence: loads an arena,
## fills it with the first block, drops a few decorations, undoes and redoes,
## saves the layout to --save (never into art/layouts/) and photographs the
## window. Needs a real display (xvfb is fine), not --headless.
##
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot \
##       -s tools/map_editor/editor_shot.gd -- --arena=1 --out=<png> --save=<json> [--retail]

const Layout := preload("res://src/maps/arena_layout.gd")

var opts := {"arena": "1", "out": "/tmp/editor.png", "save": "/tmp/layout.json"}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	_run.call_deferred()


func _run() -> void:
	var ed: Control = load("res://tools/map_editor/map_editor.tscn").instantiate()
	root.add_child(ed)
	for i in 4:
		await process_frame
	ed.load_arena(int(opts.arena))
	var cells: Dictionary = ed.shape.cells
	print("[shot] arena %s: %d cells, palette %d" % [opts.arena, cells.size(), ed.palette.size()])
	if opts.has("demo"):
		await _demo(ed, cells)
	if opts.has("retail"):
		ed._retail_check.button_pressed = true
	if opts.has("game"):
		ed.game_scale()
	if opts.has("help"):
		ed._help.visible = true
	# let the thumbnails finish
	for i in 600:
		if not ed._thumb_busy:
			break
		await process_frame
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(opts.out)
	print("[shot] %s" % opts.out)
	var err := Layout.save_layout(ed.layout, opts.save)
	print("[shot] saved %s (%s), missing models %s" % [opts.save, error_string(err), ed.builder.missing.keys()])
	ed.dirty = false   # don't let the close autosave into art/layouts/
	quit(0)


func _demo(ed: Control, cells: Dictionary) -> void:
	var tile: int = ed._first_of_kind("tile")
	ed._pick_piece(tile)
	ed.random_rot = true
	ed.fill_empty()
	var filled: int = ed.layout.cells.size()
	# one ground cell in three of loom b, then decorations on obstacles
	var keys: Array = cells.keys()
	keys.sort()
	var n := 0
	for p: Vector2i in keys:
		if cells[p].role == "floor" and hash(p) % 3 == 0:
			ed.selected = {"cell": p, "i": 0}
			ed.set_loom("b")
			n += 1
	ed.selected = {}
	var decos := []
	for i in ed.palette.size():
		if ed.palette[i].kind == "deco":
			decos.append(i)
	var k := 0
	for p: Vector2i in keys:
		if cells[p].role == "obstacle" and not decos.is_empty():
			ed._pick_piece(decos[k % decos.size()])
			ed.place(p)
			k += 1
	ed.random_rot = false
	var before: int = _count(ed)
	ed.undo()
	var after_undo: int = _count(ed)
	ed.redo()
	print("[shot] filled %d cells, %d to loom b, %d decorations; undo %d -> %d -> %d" % [
		filled, n, k, before, after_undo, _count(ed)])
	await process_frame


func _count(ed: Control) -> int:
	var n := 0
	for items in ed.layout.cells.values():
		n += items.size()
	return n
