extends SceneTree

## Island topology exporter — offline dump of every overworld island's floor
## plan as JSON, raw material for event maps (pendiente/README.md §5).
##
##   Godot --headless --path godot -s tools/export_islands.gd -- <outdir> [--ids=A-B]
##
## Writes <outdir>/map<ID>.json per island plus <outdir>/index.json (what was
## exported, per-island counts, and what was skipped and why). Exits 0 when
## every island parsed and wrote cleanly, 1 when any failed (a tplg jar that
## exists but decodes to nothing, a write error, a JSON that does not
## round-trip), 2 on a usage error. Output has no timestamps and a fixed
## cell order, so two runs produce byte-identical files and diff cleanly.
##
## What an "island" is: the data has no explicit list. The tracker's "ids
## 23-109" is only the default window; inside it a world counts as an island
## when it ships NO fight map (maps/fight/<id>.jar empty — those are arenas)
## and has at least one floored cell. Everything else is listed in the index
## under `skipped` with its reason instead of being dropped silently.
##
## JSON shape, per island (`--ids` defaults to 23-109):
##   world        world id
##   bounds       {x, y, w, h} of every decoded cell, void included (measured
##                here; topology.gd's own bounds are one cell short)
##   cells        [[x, y, alt], ...] FLOORED cells only (Topology "ground"),
##                alt = the standing surface. Sorted by y then x. Unfloored
##                cells are implied by absence, which keeps the big islands
##                a fraction of their raw size without losing the floor plan.
##   layers       [[x, y, [alt, ...]], ...] cells whose chunk is "layered"
##                (kind 5): every floored altitude stacked on that cell,
##                ascending. >1 entry = bridge/ramp/multi-storey. Same order.
##
## Deliberately NOT exported (follow-ups, not faked):
##   mapNN.png   needs godot/assets/mapgfx/ (retail art, git-ignored).
##   elements    interactive elements. The tracker says they only arrive over
##               opcodes 200/206, but the client's own maps/env/<id>.jar
##               holds them too (server/cmd/genelements already reads that),
##               so an offline `elements` key is feasible; it needs the env
##               decoder in Go ported, which is outside this script's scope.
##   zones       topology.gd has no zone concept; the tracker's zones are
##               presumably the kind-8 zone triggers, which are elements.

const Topology := preload("res://src/maps/topology.gd")
const Jar := preload("res://src/maps/jar.gd")

const DEFAULT_FIRST := 23
const DEFAULT_LAST := 109

const EXIT_OK := 0
const EXIT_FAILED := 1
const EXIT_USAGE := 2


func _init() -> void:
	quit(_run(OS.get_cmdline_user_args()))


func _run(args: PackedStringArray) -> int:
	var first := DEFAULT_FIRST
	var last := DEFAULT_LAST
	var outdir := ""
	for a in args:
		if a.begins_with("--ids="):
			var parts := a.substr(6).split("-")
			if parts.size() != 2 or not parts[0].is_valid_int() \
					or not parts[1].is_valid_int():
				return _usage("bad --ids value '%s' (want A-B)" % a)
			first = int(parts[0])
			last = int(parts[1])
		elif a.begins_with("--"):
			return _usage("unknown option '%s'" % a)
		elif outdir == "":
			outdir = a
		else:
			return _usage("more than one output directory")
	if outdir == "":
		return _usage("missing <outdir>")
	if first > last or first < 0:
		return _usage("empty id window %d-%d" % [first, last])

	# a relative outdir means relative to where the user ran Godot from, not
	# to the project dir --path switches into
	if not outdir.is_absolute_path():
		outdir = OS.get_environment("PWD").path_join(outdir)
	var err := DirAccess.make_dir_recursive_absolute(outdir)
	if err != OK:
		printerr("FAIL cannot create '%s': %s" % [outdir, error_string(err)])
		return EXIT_FAILED

	var exported: Array = []
	var skipped: Array = []
	var failures := 0
	for world in range(first, last + 1):
		var res := _export_world(world, outdir)
		match res.status:
			"ok":
				exported.append(res.entry)
				print("ok   map%-4d cells=%-6d layered=%-6d multi=%-5d %d bytes" % [
					world, res.entry.cells, res.entry.layered_cells,
					res.entry.multi_floor_cells, res.entry.bytes])
			"skip":
				skipped.append({"world": world, "reason": res.reason})
				print("skip map%-4d %s" % [world, res.reason])
			_:
				failures += 1
				printerr("FAIL map%d: %s" % [world, res.reason])

	var index_err := _write_index(outdir, first, last, exported, skipped)
	if index_err != "":
		failures += 1
		printerr("FAIL index.json: " + index_err)

	print("---")
	print("%d islands exported, %d skipped, %d failed (window %d-%d) -> %s" % [
		exported.size(), skipped.size(), failures, first, last, outdir])
	return EXIT_FAILED if failures > 0 else EXIT_OK


func _usage(msg: String) -> int:
	printerr("export_islands: " + msg)
	printerr("usage: Godot --headless --path godot -s tools/export_islands.gd"
		+ " -- <outdir> [--ids=A-B]")
	return EXIT_USAGE


## {status: ok|skip|fail, entry|reason}. Skips are expected classifications
## (arena, no floor, no jar in the window); a fail means data that exists
## did not decode or did not write back faithfully.
func _export_world(world: int, outdir: String) -> Dictionary:
	var jar := ProjectSettings.globalize_path(Jar.tplg_jar(world))
	if not FileAccess.file_exists(jar):
		return {"status": "skip", "reason": "no tplg jar"}
	if Jar.list(Jar.fight_jar(world)).size() > 0:
		return {"status": "skip", "reason": "arena (ships a fight map)"}

	var topo := Topology.load_world(world, Topology.SCOPE_WORLD)
	var cells: Dictionary = topo.get("cells", {})
	if cells.is_empty():
		return {"status": "fail", "reason": "tplg jar decoded to zero cells"}

	# Not topo.bounds: Topology grows it with Rect2i.expand(), whose end is
	# exclusive, so its w/h come out one short and the last row/column of
	# cells falls outside it (island 24 loses 26 floored cells that way).
	var lo := Vector2i(1 << 30, 1 << 30)
	var hi := Vector2i(-(1 << 30), -(1 << 30))
	for pos in cells:
		lo = lo.min(pos)
		hi = hi.max(pos)
	var b := Rect2i(lo, hi - lo + Vector2i.ONE)
	var floor_rows := PackedStringArray()
	var layer_rows := PackedStringArray()
	var multi := 0
	# Walk the bounds in row order instead of sorting the dictionary keys:
	# dictionary order follows jar entry order, which is not part of the
	# data, and a 130k-key sort_custom is the slow way to the same answer.
	for y in range(b.position.y, b.end.y):
		for x in range(b.position.x, b.end.x):
			var cell: Variant = cells.get(Vector2i(x, y))
			if cell == null:
				continue
			if cell.ground:
				floor_rows.append("[%d,%d,%d]" % [x, y, cell.alt])
			if cell.has("layers"):
				var alts: Array = cell.layers.duplicate()
				alts.sort()
				if alts.size() > 1:
					multi += 1
				layer_rows.append("[%d,%d,%s]" % [x, y, JSON.stringify(alts)])

	if floor_rows.is_empty():
		return {"status": "skip", "reason": "no floored cells"}

	var text := '{\n"world": %d,\n"bounds": {"x": %d, "y": %d, "w": %d, "h": %d},\n' % [
		world, b.position.x, b.position.y, b.size.x, b.size.y]
	text += '"cells": [\n' + ",\n".join(floor_rows) + "\n],\n"
	text += '"layers": [\n' + ",\n".join(layer_rows) + "\n]\n}\n"

	# Hand-assembled for one-row-per-cell diffs; prove it is still JSON and
	# still says what the decoder said before trusting it on disk.
	var back: Variant = JSON.parse_string(text)
	if typeof(back) != TYPE_DICTIONARY \
			or back.cells.size() != floor_rows.size() \
			or back.layers.size() != layer_rows.size():
		return {"status": "fail", "reason": "JSON did not round-trip"}

	var werr := _write(outdir.path_join("map%d.json" % world), text)
	if werr != "":
		return {"status": "fail", "reason": werr}
	return {"status": "ok", "entry": {
		"world": world,
		"file": "map%d.json" % world,
		"cells": floor_rows.size(),
		"layered_cells": layer_rows.size(),
		"multi_floor_cells": multi,
		"decoded_cells": cells.size(),
		"bounds": {"x": b.position.x, "y": b.position.y,
			"w": b.size.x, "h": b.size.y},
		"bytes": text.to_utf8_buffer().size(),
	}}


func _write_index(outdir: String, first: int, last: int,
		exported: Array, skipped: Array) -> String:
	var rows := PackedStringArray()
	for e in exported:
		rows.append(JSON.stringify(e, "", true))
	var skip_rows := PackedStringArray()
	for s in skipped:
		skip_rows.append(JSON.stringify(s, "", true))
	var text := '{\n"source": "server/data-dist/maps/tplg",\n'
	text += '"window": [%d, %d],\n' % [first, last]
	text += '"not_exported": ["elements", "zones", "png"],\n'
	text += '"islands": [\n' + ",\n".join(rows) + "\n],\n"
	text += '"skipped": [\n' + ",\n".join(skip_rows) + "\n]\n}\n"
	if typeof(JSON.parse_string(text)) != TYPE_DICTIONARY:
		return "index did not round-trip"
	return _write(outdir.path_join("index.json"), text)


## "" on success, else a human-readable reason.
func _write(path: String, text: String) -> String:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "cannot open '%s': %s" % [path, error_string(FileAccess.get_open_error())]
	f.store_string(text)
	f.close()
	return ""
