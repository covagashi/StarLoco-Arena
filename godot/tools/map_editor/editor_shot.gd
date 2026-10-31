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
	if opts.has("cells"):
		await _cells_demo(ed, cells)
	if opts.has("alts"):
		await _alts_demo(ed, cells)
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


## The cells tool: a floor cell to obstacle, a team 2 start to floor, a
## floor cell to a team 1 start; undo and redo; a pedestal stays one.
func _cells_demo(ed: Control, cells: Dictionary) -> void:
	ed._set_tool("cells")
	var keys: Array = cells.keys()
	keys.sort()
	var picks := {}
	for p: Vector2i in keys:
		var r: String = cells[p].role
		if not picks.has(r):
			picks[r] = p
	var before: Dictionary = Layout.start_counts(ed.shape)
	ed.set_role(picks.floor, "obstacle")
	ed.set_role(picks.team1, "floor")
	var keys2: Array = keys.filter(func(p: Vector2i) -> bool: return cells[p].role == "floor")
	ed.set_role(keys2[0], "team0")
	if picks.has("coach"):
		ed.set_role(picks.coach, "obstacle")
	var after: Dictionary = Layout.start_counts(ed.shape)
	ed.undo()
	var undone: Dictionary = Layout.start_counts(ed.shape)
	ed.redo()
	print("[shot] cells: starts %s -> %s, undo %s, redo %s; %d changes; pedestal %s" % [
		before, after, undone, Layout.start_counts(ed.shape), ed.layout.roles.size(),
		cells[picks.coach].role if picks.has("coach") else "-"])
	await process_frame


## Heights: a floor cell up five steps, another under every cell; undo and
## redo; the cell's node moves with its surface and the columns reach the
## new floor.
func _alts_demo(ed: Control, cells: Dictionary) -> void:
	var keys: Array = cells.keys().filter(func(p: Vector2i) -> bool: return cells[p].role == "floor")
	keys.sort()
	var a: Vector2i = keys[keys.size() / 2]
	var b: Vector2i = keys[keys.size() / 3]
	var sa: int = cells[a].surface
	var floor0: float = ed.shape.floor_y
	ed.change_alt(a, 5)
	ed.change_alt(b, ed.shape.alt_min - 6 - cells[b].surface)
	var up: int = cells[a].surface
	var floor1: float = ed.shape.floor_y
	var node_y: float = ed._cells[a].position.y if ed._cells.has(a) else -999.0
	ed.undo()
	var after_undo: float = ed.shape.floor_y
	ed.redo()
	print("[shot] alts: %s %d -> %d (node y %.2f = %.2f); floor %.2f -> %.2f, undo %.2f, redo %.2f; %d changes" % [
		a, sa, up, node_y, up * Layout.ALT, floor0, floor1, after_undo, ed.shape.floor_y, ed.layout.alts.size()])
	await process_frame
