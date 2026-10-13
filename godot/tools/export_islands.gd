extends SceneTree

## Island topology exporter — offline dump of every overworld island's floor
## plan as JSON, raw material for event maps (pendiente/README.md §5).
##
##   Godot --headless --path godot -s tools/export_islands.gd -- <outdir> \
##       [--ids=A-B] [--env-dir=<dir of <id>.jar env layers>]
##
## Writes <outdir>/map<ID>.json per island plus <outdir>/index.json (what was
## exported, per-island counts, and what was skipped and why). Exits 0 when
## every island parsed and wrote cleanly, 1 when any failed (a tplg jar that
## exists but decodes to nothing, a write error, a JSON that does not
## round-trip), 2 on a usage error. Output has no timestamps and a fixed
## cell/element order, so two runs produce byte-identical files and diff
## cleanly. A missing or undecodable maps/env jar is NOT a failure: that island
## still exports, with empty `elements`/`zones`, and the reason lands in the
## island's `env` field, in the index `env_issues` list and on stderr (WARN).
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
##   elements     one object per line, sorted by instance id: the interactive
##                elements (Zaaps, Card Masters, totems, NPCs, zone triggers...)
##                of maps/env/<world>.jar, decoded OFFLINE. Keys:
##                  id     instance id (aEG.nD, i64; unique within the world)
##                  type   env type 1..15 (gamedata/elements.gd KIND_NAMES)
##                  x,y,z  cell and the DECORATION altitude (not the walkable
##                         ground — server envmaps.go is emphatic about that)
##                  dir    facing byte; flags = approach-direction bitmask
##                  views  sprite ids (data.bdat record type 360)
##                  paths  [[x, y, z], ...] extra cells the element covers; only
##                         zone triggers have any (the Go decoder drops them)
##                  desc   the RU part's ';'-separated descriptor, verbatim
##                         ("null" = none)
##                id/type/x/y/z/dir/flags/desc are what server/cmd/dumpelements
##                writes (keys in this order, id first); `views` and `paths`
##                are decoded but dumped nowhere else.
##   zones        the kind-8 elements again, in the shape a map editor wants:
##                {id, x, y, z, cells, script, requires, blocked_by, desc};
##                `cells` is the footprint. See _zone_of() for what a zone
##                is here (there is no separate zone table) and its caveats.
##
## Env byte layout (all of it verified against server/internal/gamedata/
## envmaps.go, and cross-checked element for element against its output):
## each jar entry "<cx>_<cy>" is one 18x18 chunk, LITTLE-endian framing around
## BIG-endian element payloads — see _decode_chunk() / _decode_payload().
##
## Deliberately NOT exported (a follow-up, not faked):
##   mapNN.png   needs godot/assets/mapgfx/ (retail art, git-ignored).

const Topology := preload("res://src/maps/topology.gd")
const Jar := preload("res://src/maps/jar.gd")
const LeReader := preload("res://src/util/le_reader.gd")

const DEFAULT_FIRST := 23
const DEFAULT_LAST := 109

const EXIT_OK := 0
const EXIT_FAILED := 1
const EXIT_USAGE := 2

# env chunk framing (server/internal/gamedata/envmaps.go)
const ENV_PARTICLE_SIZE := 13    # aDv
const ENV_SOUND_SIZE := 8        # axs_0
const ENV_DYNAMIC_SIZE := 15     # ty_1
const ENV_AMBIANCE_MASK := 81    # ru_2.ais: 324 cells x 2 bits / 8
const ENV_PART_POSITION := 1     # do_1.Kl() slot 1 = RU, position + descriptor
const ENV_TYPE_ZONE_TRIGGER := 8

var _env_dir := ""   # "" = the repo's server/data-dist/maps/env
var _chunk_name := RegEx.create_from_string("^-?[0-9]+_-?[0-9]+$")


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
		elif a.begins_with("--env-dir="):
			_env_dir = a.substr(10)
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
	var env_issues: Array = []
	var failures := 0
	for world in range(first, last + 1):
		var res := _export_world(world, outdir)
		match res.status:
			"ok":
				exported.append(res.entry)
				print("ok   map%-4d cells=%-6d layered=%-6d multi=%-5d elements=%-3d zones=%-2d %d bytes" % [
					world, res.entry.cells, res.entry.layered_cells,
					res.entry.multi_floor_cells, res.entry.elements,
					res.entry.zones, res.entry.bytes])
				if res.entry.env != "ok":
					env_issues.append({"world": world, "env": res.entry.env})
					printerr("WARN map%d: env %s -> exported with no elements" % [
						world, res.entry.env])
			"skip":
				skipped.append({"world": world, "reason": res.reason})
				print("skip map%-4d %s" % [world, res.reason])
			_:
				failures += 1
				printerr("FAIL map%d: %s" % [world, res.reason])

	var index_err := _write_index(outdir, first, last, exported, skipped, env_issues)
	if index_err != "":
		failures += 1
		printerr("FAIL index.json: " + index_err)

	print("---")
	var n_elements := 0
	var n_zones := 0
	for e in exported:
		n_elements += e.elements
		n_zones += e.zones
	print("%d islands exported (%d elements, %d zones, %d env issues), %d skipped, %d failed (window %d-%d) -> %s" % [
		exported.size(), n_elements, n_zones, env_issues.size(), skipped.size(),
		failures, first, last, outdir])
	return EXIT_FAILED if failures > 0 else EXIT_OK


func _usage(msg: String) -> int:
	printerr("export_islands: " + msg)
	printerr("usage: Godot --headless --path godot -s tools/export_islands.gd"
		+ " -- <outdir> [--ids=A-B] [--env-dir=<dir>]")
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

	# A broken env layer must not cost the island its floor plan: the topology
	# is the part of this export that already worked and is the more valuable.
	var env := _load_env(world)
	var element_rows := PackedStringArray()
	var zone_rows := PackedStringArray()
	for e in env.elements:
		element_rows.append(JSON.stringify(e, "", false))
		if e.type == ENV_TYPE_ZONE_TRIGGER:
			zone_rows.append(JSON.stringify(_zone_of(e), "", false))

	var text := '{\n"world": %d,\n"bounds": {"x": %d, "y": %d, "w": %d, "h": %d},\n' % [
		world, b.position.x, b.position.y, b.size.x, b.size.y]
	text += '"cells": [\n' + ",\n".join(floor_rows) + "\n],\n"
	text += '"layers": [\n' + ",\n".join(layer_rows) + "\n],\n"
	text += '"elements": [\n' + ",\n".join(element_rows) + "\n],\n"
	text += '"zones": [\n' + ",\n".join(zone_rows) + "\n]\n}\n"

	# Hand-assembled for one-row-per-cell diffs; prove it is still JSON and
	# still says what the decoder said before trusting it on disk.
	var back: Variant = JSON.parse_string(text)
	if typeof(back) != TYPE_DICTIONARY \
			or back.cells.size() != floor_rows.size() \
			or back.layers.size() != layer_rows.size() \
			or back.elements.size() != element_rows.size() \
			or back.zones.size() != zone_rows.size():
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
		"elements": element_rows.size(),
		"zones": zone_rows.size(),
		"env": env.status,
		"bounds": {"x": b.position.x, "y": b.position.y,
			"w": b.size.x, "h": b.size.y},
		"bytes": text.to_utf8_buffer().size(),
	}}


func _write_index(outdir: String, first: int, last: int,
		exported: Array, skipped: Array, env_issues: Array) -> String:
	var rows := PackedStringArray()
	for e in exported:
		rows.append(JSON.stringify(e, "", true))
	var skip_rows := PackedStringArray()
	for s in skipped:
		skip_rows.append(JSON.stringify(s, "", true))
	var text := '{\n"source": ["server/data-dist/maps/tplg", "server/data-dist/maps/env"],\n'
	text += '"window": [%d, %d],\n' % [first, last]
	text += '"not_exported": ["png"],\n'
	var issue_rows := PackedStringArray()
	for i in env_issues:
		issue_rows.append(JSON.stringify(i, "", true))
	text += '"islands": [\n' + ",\n".join(rows) + "\n],\n"
	text += '"skipped": [\n' + ",\n".join(skip_rows) + "\n],\n"
	text += '"env_issues": [\n' + ",\n".join(issue_rows) + "\n]\n}\n"
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


## Big-endian cursor over an element payload. Latches `err` instead of reading
## past the end, like the Go `cur` it mirrors: a payload that runs short is data
## drift, and every later field would be garbage, so callers check `err` once
## at the end rather than after each read.
class BeCursor:
	var b: PackedByteArray
	var pos := 0
	var err := false

	func _init(buf: PackedByteArray) -> void:
		b = buf

	func need(n: int) -> bool:
		if err or n < 0 or pos + n > b.size():
			err = true
			return false
		return true

	func u8() -> int:
		if not need(1):
			return 0
		pos += 1
		return b[pos - 1]

	func u16() -> int:
		if not need(2):
			return 0
		pos += 2
		return (b[pos - 2] << 8) | b[pos - 1]

	func i16() -> int:
		var v := u16()
		return v - 0x10000 if v >= 0x8000 else v

	func i32() -> int:
		if not need(4):
			return 0
		pos += 4
		var v := (b[pos - 4] << 24) | (b[pos - 3] << 16) | (b[pos - 2] << 8) | b[pos - 1]
		return v - 0x100000000 if v >= 0x80000000 else v


func _s16(v: int) -> int:
	return v - 0x10000 if v >= 0x8000 else v


## {status, elements}. status is "ok", "missing" (no env jar for this world) or
## "unreadable: <why>" (the jar is there but does not decode). Every non-ok
## status comes with an EMPTY elements list — a half-decoded layer would be
## worse than none, since the chunk walk is positional and one short read
## poisons everything after it. Elements are sorted by instance id.
func _load_env(world: int) -> Dictionary:
	var path := _env_jar(world)
	if not FileAccess.file_exists(path):
		return {"status": "missing", "elements": []}
	var z := Jar.open(path)
	if z == null:
		return {"status": "unreadable: not a zip archive", "elements": []}
	var out: Array = []
	var chunks := 0
	for entry in z.get_files():
		# env jars also carry META-INF and a 4-byte `data.amd` marker, and
		# (unlike tplg) no `coord` entry; chunks are named "<cx>_<cy>"
		if not _chunk_name.search(entry):
			continue
		chunks += 1
		var res := _decode_chunk(z.read_file(entry), entry, world)
		if res.err != "":
			z.close()
			return {"status": "unreadable: chunk %s: %s" % [entry, res.err],
				"elements": []}
		out.append_array(res.elements)
	z.close()
	if chunks == 0:
		return {"status": "unreadable: no chunk entries", "elements": []}

	# Jar entry order is not part of the data. Instance ids are unique within
	# a world, so id alone orders them; the tail keys only keep a duplicate
	# (which would be a data bug) from making the output order-dependent.
	out.sort_custom(func(a, b):
		if a.id != b.id:
			return a.id < b.id
		return [a.x, a.y, a.type] < [b.x, b.y, b.type])
	for i in range(1, out.size()):
		if out[i].id == out[i - 1].id:
			return {"status": "unreadable: duplicate instance id %d" % out[i].id,
				"elements": []}
	return {"status": "ok", "elements": out}


func _env_jar(world: int) -> String:
	var dir := _env_dir
	if dir == "":
		dir = ProjectSettings.globalize_path(Jar.DATA_DIST + "/maps/env")
	elif not dir.is_absolute_path():
		dir = OS.get_environment("PWD").path_join(dir)
	return dir.path_join("%d.jar" % world)


## Skips `n` bytes; false when the chunk is too short to hold them.
func _skip(r: LeReader, n: int) -> bool:
	if n < 0 or r.remaining() < n:
		return false
	r.bytes(n)
	return true


## One env chunk entry -> {err, elements}. Port of decodeEnvChunk in
## server/internal/gamedata/envmaps.go. The framing is LITTLE-endian, sections
## in this fixed order, every count a u8:
##
##   u8  version (0)             i16 chunkX, i16 chunkY (must match the name)
##   u8  n, n x 13 bytes         particles (aDv)
##   u8  n, n x  8 bytes         sounds (axs_0)
##   u8  n, n x i32 ids; and only if n > 0: u8 maskLen (81) + that many bytes
##   u8  n, n x element          interactive elements (below)
##   u8  n, n x 15 bytes         dynamic elements (ty_1)
##
## and it must end EXACTLY at the last byte. The sections are variable length
## and only reachable in order, so landing anywhere else means every offset
## after the slip was wrong and the elements cannot be trusted.
##
## Element: i64 id, u16 type, u8 viewCount + viewCount x i32, u16 payloadLen +
## payload bytes (the part table, BIG-endian — see _decode_payload), then 3
## bytes the client reads and discards (a bit-reader byte and an i16 state
## slot, -1 in all retail data).
func _decode_chunk(data: PackedByteArray, entry: String, world: int) -> Dictionary:
	var r := LeReader.new(data)
	if r.remaining() < 5:
		return {"err": "truncated header"}
	var version := r.u8()
	if version != 0:
		return {"err": "unexpected env version %d (want 0)" % version}
	var name := "%d_%d" % [r.i16(), r.i16()]
	if name != entry:
		# the header repeats the entry name; a mismatch is drift, not a quirk
		return {"err": "header says chunk %s" % name}

	for size in [ENV_PARTICLE_SIZE, ENV_SOUND_SIZE]:
		if r.remaining() < 1:
			return {"err": "truncated before a fixed-size section"}
		if not _skip(r, r.u8() * size):
			return {"err": "fixed-size section runs past the end"}

	if r.remaining() < 1:
		return {"err": "truncated before ambiance"}
	var ambiance := r.u8()
	if ambiance > 0:
		if not _skip(r, ambiance * 4) or r.remaining() < 1:
			return {"err": "ambiance runs past the end"}
		var mask_len := r.u8()
		if mask_len > 0:
			if mask_len != ENV_AMBIANCE_MASK:
				return {"err": "ambiance mask is %d bytes (want %d)" % [
					mask_len, ENV_AMBIANCE_MASK]}
			if not _skip(r, mask_len):
				return {"err": "ambiance mask runs past the end"}

	if r.remaining() < 1:
		return {"err": "truncated before the element count"}
	var count := r.u8()
	var elements: Array = []
	for i in count:
		var el := _decode_element(r, world)
		if el.has("err"):
			return {"err": "element %d/%d: %s" % [i + 1, count, el.err]}
		elements.append(el)

	if r.remaining() < 1:
		return {"err": "truncated before the dynamic section"}
	if not _skip(r, r.u8() * ENV_DYNAMIC_SIZE):
		return {"err": "dynamic section runs past the end"}
	if r.remaining() != 0:
		return {"err": "walked %d of %d bytes - layout drift" % [
			data.size() - r.remaining(), data.size()]}
	return {"err": "", "elements": elements}


## One element -> its export dictionary (key order is the line layout), or
## {err}. Port of decodeEnvElement.
func _decode_element(r: LeReader, world: int) -> Dictionary:
	if r.remaining() < 8 + 2 + 1:
		return {"err": "truncated element header"}
	var lo := r.u32()
	var hi := r.u32()
	var id := lo | (hi << 32)             # i64 LE; GDScript ints are 64-bit
	var type := _s16(r.u16())
	var view_count := r.u8()
	if r.remaining() < view_count * 4 + 2:
		return {"err": "truncated view list"}
	var views: Array = []
	for i in view_count:
		views.append(r.i32())
	var payload_len := r.u16()
	if r.remaining() < payload_len + 3:
		return {"err": "payload of %d bytes does not fit" % payload_len}
	var payload := r.bytes(payload_len)
	r.bytes(3)   # bit-reader byte + i16 state slot, both discarded

	var ru := _decode_payload(payload)
	if ru.has("err"):
		return {"err": "id %d: %s" % [id, ru.err]}
	if ru.world != world:
		# always equal in retail data, so a mismatch means the parse drifted
		return {"err": "id %d: payload says world %d" % [id, ru.world]}
	return {"id": id, "type": type, "x": ru.x, "y": ru.y, "z": ru.z,
		"dir": ru.dir, "flags": ru.flags, "views": views, "paths": ru.paths,
		"desc": ru.desc}


## The element's part table -> the RU part's fields, or {err}. BIG-endian,
## unlike everything around it. Port of decodeEnvPayload / decodeEnvRU.
##
## Container: u8 partCount, then partCount x {u8 partId, i32 offset}. A part's
## length runs to the next part's offset (or the blob end) minus one, because
## the byte AT the offset repeats the part id (a checksum, and checked here).
## Only part 1 (RU) carries position and descriptor, and its body is:
##
##   i16 world, i32 x, i32 y, i16 z (decoration height), i16 state, u8 visible,
##   u8 agj, u8 dir, i16 flags (approach bitmask; 0x100 = from anywhere),
##   i16 pathCount + pathCount x {i32 x, i32 y, i16 z}   extra covered cells,
##   u16 descLen + descriptor bytes, u8 propertyCount (always 0)
func _decode_payload(p: PackedByteArray) -> Dictionary:
	var c := BeCursor.new(p)
	var part_count := c.u8()
	if c.err or part_count == 0:
		return {"err": "empty part table"}
	var ids: Array = []
	var offs: Array = []
	for i in part_count:
		ids.append(c.u8())
		offs.append(c.i32())
	if c.err:
		return {"err": "truncated part header"}

	for i in part_count:
		var start: int = offs[i]
		var end: int = offs[i + 1] if i < part_count - 1 else p.size()
		var length := end - start - 1
		if start < 0 or start >= p.size() or length <= 0:
			continue   # empty part; the client skips these too
		if p[start] != ids[i]:
			return {"err": "part %d marker is %d, expected part id %d" % [
				i, p[start], ids[i]]}
		if ids[i] != ENV_PART_POSITION:
			continue
		if start + 1 + length > p.size():
			return {"err": "RU part overruns the payload"}
		return _decode_ru(p.slice(start + 1, start + 1 + length))
	return {"err": "no RU part"}


func _decode_ru(b: PackedByteArray) -> Dictionary:
	var c := BeCursor.new(b)
	var out := {}
	out.world = c.i16()
	out.x = c.i32()
	out.y = c.i32()
	out.z = c.i16()
	c.i16()   # element state (1 throughout retail)
	c.u8()    # visible
	c.u8()    # agj, a second boolean
	out.dir = c.u8()
	out.flags = c.i16()
	var paths: Array = []
	var path_count := c.i16()
	for i in path_count:
		var px := c.i32()
		var py := c.i32()
		var pz := c.i16()
		if c.err:
			break
		paths.append([px, py, pz])
	out.paths = paths
	var name_len := c.u16()
	out.desc = ""
	if name_len > 0:
		if not c.need(name_len):
			return {"err": "descriptor of %d bytes does not fit" % name_len}
		out.desc = b.slice(c.pos, c.pos + name_len).get_string_from_utf8()
		c.pos += name_len
	var props := c.u8()
	if c.err:
		return {"err": "truncated RU part"}
	if props != 0:
		return {"err": "%d properties, expected none" % props}
	if c.pos != b.size():
		return {"err": "RU part left %d of %d bytes unread" % [
			b.size() - c.pos, b.size()]}
	return out


## A kind-8 element as a zone. WHAT THIS IS: there is no separate zone table
## anywhere in the env data — the only "zones" in the game are the ZoneTrigger
## elements (env type 8; 9 in the whole retail set, all on islands 35 and 37),
## which fire when a walking coach ENTERS a covered cell. The geometry is the
## element's `paths`: the extra cells its RU part lists next to the anchor
## cell (the client tests `x,y == cell or cell in cells`, main.gd
## _zone_triggers_at). Retail triggers do use them, 1 to 15 extra cells each, a
## line or a block — and server/internal/gamedata/envmaps.go reads and DISCARDS
## them, so this is the one place the footprints are exported. Several
## `paths` repeat the anchor, so `cells` is the deduplicated union, sorted by
## y then x; the per-cell altitude stays in the element's own `paths`.
##
## The descriptor is "script;requires;blocked_by" — read off the client
## (main.gd _check_zone_trigger), not off the Go decoder, which keeps it as an
## opaque string: `script` the scenario id (gamedata/scenarios.gd), `requires` an
## achievement that must be done first (0 = none), `blocked_by` one that
## suppresses it once done (0 = none). A missing or non-numeric field reads as
## the client reads it: script -1, the others 0. `desc` stays verbatim next to
## the parsed fields so nothing depends on this interpretation.
func _zone_of(e: Dictionary) -> Dictionary:
	var f: PackedStringArray = e.desc.split(";")
	var seen := {Vector2i(e.x, e.y): true}
	for p in e.paths:
		seen[Vector2i(p[0], p[1])] = true
	var pts: Array = seen.keys()
	pts.sort_custom(func(a, b): return a.y < b.y or (a.y == b.y and a.x < b.x))
	var cells: Array = []
	for pt in pts:
		cells.append([pt.x, pt.y])
	return {"id": e.id, "x": e.x, "y": e.y, "z": e.z, "cells": cells,
		"script": int(f[0]) if f.size() > 0 and f[0].is_valid_int() else -1,
		"requires": int(f[1]) if f.size() > 1 and f[1].is_valid_int() else 0,
		"blocked_by": int(f[2]) if f.size() > 2 and f[2].is_valid_int() else 0,
		"desc": e.desc}
