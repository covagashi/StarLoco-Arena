extends SceneTree

## S36 draft: lays each arena out with our pieces where the retail map has
## its own, through the map editor (the same place() a person uses), so the
## owner reviews and corrects drafts instead of starting from an empty map
## (owner, 2026-10-30: "mira de crear los 12 mapas con nuestros assets").
##
## Per retail sprite (archive mapa.json, in retail draw order): the cell it
## belongs to, our piece for its gfx (the arena's kits, their shared
## entries, then names.json "same" and gfx_rules "replace"), mirrored when
## the retail sprite is (flip + 90°: the iso mirror swaps x and z), the
## retail tint, and the retail scale when it differs. A decoration goes on
## top of the cell's highest one when it is the same piece again (pillars
## stacked into walls) or its kit says it stands on something ("on").
## Every shape cell without a block (and no cliff hanging in its place)
## gets the arena's most used block: no cap or decoration over nothing.
##
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path godot \
##       -s tools/map_editor/draft_from_retail.gd -- \
##       --archivo=<archivo-arenas> --shots=<dir> [--arenas=1,2,...] [--save]
##
## Without --save the layouts go to --shots, never into art/layouts/.

const Layout := preload("res://src/maps/arena_layout.gd")

const GROUND := 8191
## The block a cap goes on when the retail cell has no block of its own
## (otherwise the arena's most used block).
## Arenas whose base block is not their most used one: arena 7's grass
## sits on dirt in the retail.
const BASE := {7: "arena5/dirt_block"}
const CAP_BASE := {"arena7/dirt_cap": "arena5/dirt_block"}

var opts := {"archivo": "", "shots": "/tmp/drafts", "arenas": "1,2,3,4,5,6,7,8,9,10,11,12"}
var same := {}
var replace := {}
var skip := {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--"):
			var kv := a.substr(2).split("=", true, 1)
			opts[kv[0]] = kv[1] if kv.size() > 1 else "1"
	DisplayServer.window_set_size(Vector2i(1600, 900))
	root.size = Vector2i(1600, 900)
	_run.call_deferred()


func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _run() -> void:
	var comun: String = opts.archivo.path_join("comun")
	var names: Dictionary = _json(comun.path_join("names.json"))
	for k in names.get("same", {}):
		if str(names.same[k]).is_valid_float():
			same[int(k)] = int(float(str(names.same[k])))
	var rules: Dictionary = _json(comun.path_join("gfx_rules.json"))
	for k in rules.get("replace", {}):
		if str(k).is_valid_int() and str(rules.replace[k]).is_valid_float():
			replace[int(k)] = int(float(str(rules.replace[k])))
	for key in ["drop", "vfx"]:
		var v = rules.get(key, {})
		for k in (v if v is Array else (v as Dictionary).keys()):
			if str(k).is_valid_float():
				skip[int(float(str(k)))] = true
	DirAccess.make_dir_recursive_absolute(opts.shots)

	print("[draft] rules: %d same, %d replace, %d skipped" % [same.size(), replace.size(), skip.size()])
	var ed: Control = load("res://tools/map_editor/map_editor.tscn").instantiate()
	root.add_child(ed)
	for i in 4:
		await process_frame
	for a in String(opts.arenas).split(","):
		await _draft(ed, int(a))
	ed.dirty = false   # no autosave on close
	quit(0)


## gfx -> [kit, piece] for one arena: its own kits' pieces first, then what
## those kits share, so an arena's own drawing wins over a borrowed one.
func _gfx_map(world: int) -> Dictionary:
	var own := {}
	var borrowed := {}
	var minor := {}
	var kits := Layout.kits()
	for kn: String in kits:
		var k: Dictionary = kits[kn]
		if not world in k.get("arenas", []):
			continue
		for p: Dictionary in k.get("pieces", []):
			for g in p.get("gfx", []):
				if not own.has(int(g)):
					own[int(g)] = [kn, p.name]
		for s: Dictionary in k.get("shared", []):
			var sp := Layout.piece(s.kit, s.name)
			for g in s.get("gfx", []) + sp.get("gfx", []):
				# a gfx shared both as a block and as a cap is the block
				var had: Array = borrowed.get(int(g), [])
				if had.is_empty() or (sp.get("kind", "") == "tile" and Layout.piece(had[0], had[1]).get("kind", "") != "tile"):
					borrowed[int(g)] = [s.kit, s.name]
		for g in k.get("minor", []):
			minor[int(g)] = true
	var out := borrowed
	out.merge(own, true)
	out["minor"] = minor
	return out


func _lookup(m: Dictionary, g: int) -> Array:
	for c in [g, replace.get(g, g), same.get(replace.get(g, g), -1), same.get(g, -1)]:
		if m.has(c):
			return m[c]
	return []


func _draft(ed: Control, arena: int) -> void:
	var world := Layout.world_of(arena)
	var mapa: Dictionary = _json(opts.archivo.path_join("arena-%02d/mapa.json" % arena))
	var tex: Dictionary = mapa.get("tex", {})
	var m := _gfx_map(world)
	var minor: Dictionary = m.minor
	print("[draft] arena %d: loading" % arena)
	ed.load_arena(arena)
	ed._grid_check.button_pressed = false
	ed.layout.cells = {}
	ed._commit([])
	var shape: Dictionary = ed.shape.cells

	var sprites: Array = mapa.piezas.duplicate()
	sprites.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.orden < b.orden)
	# the retail map holds exact copies of some sprites (same cell, place
	# and draw key): one piece each
	var seen := {}

	# per cell, the items in retail order; and which block the arena uses most
	var per_cell := {}
	var tile_count := {}
	var unmapped := {}
	var outside := 0
	var hung := 0
	for s: Dictionary in sprites:
		var g := int(s.gfx)
		if skip.has(g) or minor.has(g):
			continue
		var ref := _lookup(m, g)
		if ref.is_empty():
			unmapped[g] = unmapped.get(g, 0) + 1
			continue
		# the archive's celda is the game cell minus (1, 1): measured on the
		# retail ground blocks, whose top lines up with the game cell + (1, 1)
		var p := Vector2i(int(s.celda[0]) + 1, int(s.celda[1]) + 1)
		var dup := "%d/%d/%s/%s/%s" % [p.x, p.y, g, s.sx, s.orden]
		if seen.has(dup):
			continue
		seen[dup] = true
		if not shape.has(p):
			outside += 1
			continue
		var it := Layout.new_item(ref[0], ref[1])
		if float(s.w) < 0.0:
			it.flip = true
			it.rot = 90.0
		var c = s.get("tinte")
		# pure black is the retail's 2D framing silhouette (arenas 7 and 11),
		# not a colour; dark browns and greys (volcano, swamp) are kept
		var silhouette: bool = c is Array and c.size() == 3 and c.max() < 0.1
		if c is Array and c.size() == 3 and c != [1, 1, 1] and not silhouette:
			it.tint = Color(clampf(c[0], 0, 1), clampf(c[1], 0, 1), clampf(c[2], 0, 1)).to_html(false)
		var kind := Layout.kind_of(it)
		# a decoration that starts at the cell's top and reaches far below it
		# hangs down from the cell: the retail draws the island's side that
		# way (arena 9's pillars under its edge). One standing on the cell
		# ends near the cell's front corner (21.5 px under its centre).
		if not kind in ["tile", "cap", "flat", "cliff"]:
			var centre: float = (p.x + p.y) * 21.5 - float(shape[p].surface) * 10.0
			if float(s.sy) - centre > -30.0 and float(s.sy) + absf(float(s.h)) - centre > 80.0:
				hung += 1
				continue
		var size = tex.get(str(g))
		if size is Array and float(size[0]) > 0.0 and not kind in ["tile", "cap", "cliff"]:
			var sc := absf(float(s.w)) / float(size[0])
			if absf(sc - 1.0) > 0.05:
				it.scale = clampf(sc, 0.4, 2.5)
		if kind == "tile":
			var key := "%s/%s" % ref
			tile_count[key] = tile_count.get(key, 0) + 1
		per_cell[p] = per_cell.get(p, []) + [it]

	print("[draft] arena %d: %d cells with items" % [arena, per_cell.size()])
	var base := ""
	for k: String in tile_count:
		if base == "" or tile_count[k] > tile_count[base]:
			base = k
	if base == "":
		var first: int = ed._first_of_kind("tile")
		base = "%s/%s" % [ed.palette[first].kit, ed.palette[first].name]
	if BASE.has(arena):
		base = BASE[arena]
	var bk := base.split("/")

	var keys: Array = shape.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.x + a.y < b.x + b.y or (a.x + a.y == b.x + b.y and a.x < b.x))
	var placed := 0
	var based := 0
	var cells := {}
	for p: Vector2i in keys:
		var items := []
		var kinds := {}
		for it: Dictionary in per_cell.get(p, []):
			kinds[Layout.kind_of(it)] = true
		var far: bool = shape[p].surface < ed.shape.alt_min - 20 and per_cell.get(p, []).is_empty()
		if not kinds.has("tile") and not kinds.has("cliff") and not far:
			var under := bk
			for it: Dictionary in per_cell.get(p, []):
				var cb: String = CAP_BASE.get("%s/%s" % [it.kit, it.piece], "")
				if cb != "":
					under = cb.split("/")
			items = Layout.add_item(items, Layout.new_item(under[0], under[1]))
			based += 1
		var last := ""
		for it: Dictionary in per_cell.get(p, []):
			var kind := Layout.kind_of(it)
			var name := "%s/%s" % [it.kit, it.piece]
			var deco := not kind in ["tile", "cap", "cliff", "flat"]
			if deco and (name == last or Layout.piece(it.kit, it.piece).has("on")):
				it.off[1] = _stack_top(ed, items)
			items = Layout.add_item(items, it)
			placed += 1
			if deco:
				last = name
		if not items.is_empty():
			cells[p] = items
	print("[draft] arena %d: committing %d cells" % [arena, cells.size()])
	ed.layout.cells = cells
	var t0 := Time.get_ticks_msec()
	ed._commit(cells.keys())
	print("[draft] arena %d: built in %d ms" % [arena, Time.get_ticks_msec() - t0])
	ed.selected = {}
	ed._refresh_selection()
	ed.fit_view()
	t0 = Time.get_ticks_msec()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	print("[draft] arena %d: drawn in %d ms" % [arena, Time.get_ticks_msec() - t0])
	var shot: String = opts.shots.path_join("arena-%02d.png" % arena)
	root.get_texture().get_image().save_png(shot)
	var save_to: String = "" if opts.has("save") else String(opts.shots).path_join("arena-%02d.json" % arena)
	var err := Layout.save_layout(ed.layout, save_to)
	ed.dirty = false
	print("[draft] arena %d (world %d): %d items, %d base blocks (%s), %d sprites off the shape, %d hanging under, unmapped %s, missing models %s, saved %s" % [
		arena, world, placed, based, base, outside, hung, unmapped, ed.builder.missing.keys(), error_string(err)])


## As the editor's Shift+click: the top of the cell's highest decoration
## (its height over the surface plus its model's top, scaled).
func _stack_top(ed: Control, items: Array) -> float:
	var top := 0.0
	for i in items.size():
		var it: Dictionary = items[i]
		if Layout.kind_of(it) in ["tile", "cap"]:
			continue
		var bb: AABB = ed.builder.bounds(Layout.model_path(it.kit, it.piece, it.loom))
		top = maxf(top, Layout.item_y(items, i) + bb.end.y * float(it.scale))
	return top
