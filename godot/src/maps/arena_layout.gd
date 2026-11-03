extends RefCounted

## M7 (S36): an arena's layout — which of our kiln pieces stand on which
## cell — plus the arena list, the kits the pieces come from and the arena's
## shape. Pure data and arithmetic: the map editor (tools/map_editor/) writes
## layouts, arena_scene.gd turns one into 3D, and fight_view draws them
## through arena_view.gd.
##
## art/layouts/arena-NN.json (one per arena, readable and diffable):
##   {"arena": 1, "world": 5, "cells": {"x,y": [item, ...]}}
## item: {"kit": "arena1", "piece": "ice_block", "loom": "a"|"b"|"c",
##        "rot": degrees about y, "flip": mirrored, "tint": "rrggbb"
##        multiplier, "scale": uniform, "off": [x, y, z] in m}
## Everything after kit/piece is optional: a missing key is its default.
## "roles": {"x,y": "floor"|"obstacle"|"team0"|"team1"|"coach"|"void"} —
## the cells whose fight role the owner changed (owner, 2026-10-31); only
## the changes are written. "void" takes a cell out of the arena (a retail
## test leftover, like arena 5's pedestal under the map). The cells' heights
## stay fixed unless "alts" changes them.
## "alts": {"x,y": n} — the cells whose height the owner changed
## (owner, 2026-10-31: "hay que poder cambiar la altura"), as the walk
## surface in altitude steps (ALT m each); only the changes are written.
##
## The cells and their altitudes are never edited: they are the fight
## topology the server uses (server/data-dist/maps/). Which cells are
## obstacles or start cells can be changed per layout (roles).

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")

## The 12 modelled arenas (S36, owner 2026-10-28) by retail world id:
## arena N is the N-th. All 12 stay in the map editor.
const WORLDS := [5, 10, 12, 15, 21, 36, 38, 39, 40, 41, 42, 44]
## The prototype ships arenas 1..RELEASE only (owner, 2026-11-03: "al ser
## un prototipo, dejemos solo las 6 arenas"); 7-12 wait until more players
## come in, and the owner builds them then.
const RELEASE := 6
## Where the arena art is read from in the editor and dev runs. art/ has a
## .gdignore (the GLBs are read raw at run time, not imported), so it never
## reaches an exported .pck: a release ships the prototype's part of it as a
## loose art/ folder beside the executable (tools/art/pack_arenas.gd), the
## way assets/ ships. root() picks the one this build reads.
const ART_DIR := "res://art"
## The fight shapes the server plays, exported from the layouts
## (fight_shape / fight_json); the server embeds this folder. A release
## carries them in art/fight/.
const FIGHT_DIR := "res://../server/internal/gamedata/arenas"
## Loom letter -> model file suffix (kit.json "looms").
const LOOMS := {"a": "", "b": "_b", "c": "_c"}
## The fight roles the owner can give a cell; void = no cell there.
const EDITABLE_ROLES := ["floor", "obstacle", "team0", "team1", "coach", "void"]

const PX := 43.0 * 1.41421356          # screen px per world unit across
const ALT := 10.0 / (PX * 0.8660254)   # world units per altitude step (10 px)
## How far the columns run under the lowest cell (as build_map.gd).
const FLOOR_DEPTH := 1.2

## kit dir name ("arena1") -> parsed kit.json; filled on first use.
static var _kits := {}
## Test seam: read the art from here instead (set_root).
static var _root := ""


## The art folder this build reads: res://art in the editor, the art/
## folder beside the executable in an exported game.
static func root() -> String:
	if _root != "":
		return _root
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir().path_join("art")
	return ART_DIR


## Points the art at another folder ("" = back to root()'s choice); the
## kits are read again from there.
static func set_root(dir: String) -> void:
	_root = dir.trim_suffix("/")
	_kits = {}


## Arena number (1..12) -> world id, or -1.
static func world_of(arena: int) -> int:
	return WORLDS[arena - 1] if arena >= 1 and arena <= WORLDS.size() else -1


## The world ids the prototype plays on (arenas 1..RELEASE).
static func release_worlds() -> Array:
	return WORLDS.slice(0, RELEASE)


static func in_release(arena: int) -> bool:
	return arena >= 1 and arena <= RELEASE


static func layout_path(arena: int) -> String:
	return "%s/layouts/arena-%02d.json" % [root(), arena]


## Every tracked kit: art/arena<N>/kit.json. The biome folders (lava/,
## pradera/…) are the discarded agent attempt and stay out.
static func kits() -> Dictionary:
	if _kits.is_empty():
		var d := DirAccess.open(root())
		if d == null:
			return _kits
		for sub in d.get_directories():
			if not (sub.begins_with("arena") and sub.substr(5).is_valid_int()):
				continue
			var path := "%s/%s/kit.json" % [root(), sub]
			if not FileAccess.file_exists(path):
				continue
			var kit = JSON.parse_string(FileAccess.get_file_as_string(path))
			if kit is Dictionary:
				# JSON numbers come back as floats, and [5.0].has(5) is false
				var worlds := []
				for w in kit.get("arenas", []):
					worlds.append(int(w))
				kit.arenas = worlds
				_kits[sub] = kit
	return _kits


## A piece's kit.json entry (plus "kit"), or {}.
static func piece(kit: String, name: String) -> Dictionary:
	var k: Dictionary = kits().get(kit, {})
	for p: Dictionary in k.get("pieces", []):
		if p.name == name:
			var out := p.duplicate()
			out.kit = kit
			return out
	return {}


## The pieces an arena is made of: the pieces of every kit that lists the
## world, then the pieces those kits borrow ("shared"), without repeats.
## all = every piece of every kit.
static func palette(world: int, all := false) -> Array:
	var out := []
	var seen := {}
	var names: Array = kits().keys()
	names.sort_custom(func(a: String, b: String) -> bool:
		return int(a.substr(5)) < int(b.substr(5)))
	for kn: String in names:
		var k: Dictionary = kits()[kn]
		if not all and not world in k.get("arenas", []):
			continue
		var refs := []
		for p: Dictionary in k.get("pieces", []):
			refs.append([kn, p.name])
		for s: Dictionary in k.get("shared", []):
			refs.append([s.kit, s.name])
		for r in refs:
			var key := "%s/%s" % r
			if seen.has(key):
				continue
			var p := piece(r[0], r[1])
			if not p.is_empty():
				seen[key] = true
				out.append(p)
	return out


## The three loom names of a piece, from its kit's loom_names.
static func loom_names(p: Dictionary) -> Array:
	var k: Dictionary = kits().get(p.get("kit", ""), {})
	var names: Array = k.get("loom_names", {}).get(p.get("looms", ""), [])
	return names if names.size() == 3 else ["a", "b", "c"]


static func model_path(kit: String, name: String, loom := "a") -> String:
	return "%s/%s/out/models/%s%s.glb" % [root(), kit, name, LOOMS.get(loom, "")]


## The arena's shape, from the fight topology and the .fmd start cells:
## {cells: {Vector2i: {alt, ground, surface, role}}, alt_min, floor_y}.
## surface = the altitude pieces stand on: a walkable cell's own; an
## obstacle's altitude is the height of the retail prop on it, so it stands
## at its lowest walkable neighbour's. role: floor, obstacle, team0, team1,
## coach (a coach's pedestal).
static func shape(world: int) -> Dictionary:
	var topo := Topology.load_world(world, Topology.SCOPE_ARENA)
	var fmd := FightMap.load(world)
	var raw: Dictionary = topo.get("cells", {})
	var role := {}
	for t in ["team0", "team1", "coach"]:
		for c in fmd.get(t, []):
			role[Vector2i(c.x, c.y)] = t
	var cells := {}
	var alt_min := 1 << 30
	for p: Vector2i in raw:
		var c: Dictionary = raw[p]
		if c.alt == Topology.VOID_ALT:
			continue
		var r: String = role.get(p, "floor" if c.ground else "obstacle")
		var surface: int = c.alt if c.ground or r == "coach" else _floor_near(raw, p, c.alt)
		cells[p] = {"alt": c.alt, "ground": c.ground, "surface": surface, "role": r}
		if c.ground:
			alt_min = mini(alt_min, c.alt)
	if cells.is_empty():
		alt_min = 0
	return {"world": world, "cells": cells, "alt_min": alt_min,
		"floor_y": alt_min * ALT - FLOOR_DEPTH}


## Altitude of the nearest walkable cell (the floor an obstacle stands on):
## the closest ring of cells round p that has one, its lowest. The back rows
## of an arena are obstacles next to obstacles, and must still stand on
## the floor, not at their prop's height.
static func _floor_near(cells: Dictionary, p: Vector2i, fallback: int) -> int:
	var seen := {p: true}
	var ring: Array[Vector2i] = [p]
	while not ring.is_empty():
		var next: Array[Vector2i] = []
		var best := 1 << 30
		for q in ring:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = q + d
				if seen.has(n) or not cells.has(n):
					continue
				seen[n] = true
				var c: Dictionary = cells[n]
				if c.alt == Topology.VOID_ALT:
					continue
				if c.ground:
					best = mini(best, c.alt)
				next.append(n)
		if best != 1 << 30:
			return best
		ring = next
	return fallback


## The shape with a layout's role changes on it: each cell keeps its role
## from the fight data in base_role, and role becomes the layout's one.
## A change on a cell the shape hasn't is ignored.
static func apply_roles(shape: Dictionary, roles: Dictionary) -> void:
	for p: Vector2i in shape.cells:
		var c: Dictionary = shape.cells[p]
		if not c.has("base_role"):
			c.base_role = c.role
		c.role = c.base_role
		if roles.has(p):
			c.role = roles[p]


## The shape with a layout's height changes on it: each cell keeps its
## surface from the fight data in base_surface, and surface becomes the
## layout's one. The floor the columns run down to follows the lowest cell.
static func apply_alts(shape: Dictionary, alts: Dictionary) -> void:
	var lo := 1 << 30
	for p: Vector2i in shape.cells:
		var c: Dictionary = shape.cells[p]
		if not c.has("base_surface"):
			c.base_surface = c.surface
		c.surface = int(alts.get(p, c.base_surface))
		if c.get("role", "") != "void" and (c.ground or alts.has(p)):
			lo = mini(lo, c.surface)
	if lo != 1 << 30:
		shape.alt_min = lo
		shape.floor_y = lo * ALT - FLOOR_DEPTH


## How many start cells each team has, and pedestals: {team0, team1, coach}.
static func start_counts(shape: Dictionary) -> Dictionary:
	var out := {"team0": 0, "team1": 0, "coach": 0}
	for c: Dictionary in shape.cells.values():
		if out.has(c.role):
			out[c.role] += 1
	return out


# --- items ---------------------------------------------------------------

## A new item with every field at its default.
static func new_item(kit: String, name: String, loom := "a") -> Dictionary:
	return {"kit": kit, "piece": name, "loom": loom, "rot": 0.0, "flip": false,
		"tint": "ffffff", "scale": 1.0, "off": [0.0, 0.0, 0.0]}


## An item read from a file (or anything item-shaped) with its defaults back.
static func full_item(src: Dictionary) -> Dictionary:
	var it := new_item(String(src.get("kit", "")), String(src.get("piece", "")),
		String(src.get("loom", "a")))
	it.rot = fposmod(float(src.get("rot", 0.0)), 360.0)
	it.flip = bool(src.get("flip", false))
	it.tint = String(src.get("tint", "ffffff")).trim_prefix("#").to_lower()
	it.scale = float(src.get("scale", 1.0))
	var o = src.get("off", [0, 0, 0])
	if o is Array and o.size() == 3:
		it.off = [float(o[0]), float(o[1]), float(o[2])]
	return it


## The item as it is written: defaults left out, numbers rounded.
static func compact_item(it: Dictionary) -> Dictionary:
	var out := {"kit": it.kit, "piece": it.piece}
	if it.get("loom", "a") != "a":
		out.loom = it.loom
	if not is_zero_approx(float(it.get("rot", 0.0))):
		out.rot = snappedf(float(it.rot), 0.1)
	if it.get("flip", false):
		out.flip = true
	if String(it.get("tint", "ffffff")) != "ffffff":
		out.tint = it.tint
	if not is_equal_approx(float(it.get("scale", 1.0)), 1.0):
		out.scale = snappedf(float(it.scale), 0.001)
	var o: Array = it.get("off", [0.0, 0.0, 0.0])
	if not (is_zero_approx(o[0]) and is_zero_approx(o[1]) and is_zero_approx(o[2])):
		out.off = [snappedf(o[0], 0.001), snappedf(o[1], 0.001), snappedf(o[2], 0.001)]
	return out


static func kind_of(it: Dictionary) -> String:
	return String(piece(it.get("kit", ""), it.get("piece", "")).get("kind", "deco"))


## A cell's items with `it` added: a cell holds one ground block (tile) and
## one cap; a new one replaces the old. Everything else stacks up in order.
static func add_item(items: Array, it: Dictionary) -> Array:
	var kind := kind_of(it)
	var out := []
	for x: Dictionary in items:
		if kind in ["tile", "cap"] and kind_of(x) == kind:
			continue
		out.append(x)
	out.append(it)
	return out


## Index of the item a "remove" takes away: the last decoration, else the
## cap, else the block. -1 on an empty cell.
static func top_index(items: Array) -> int:
	for want in ["", "cap", "tile"]:
		for i in range(items.size() - 1, -1, -1):
			var k := kind_of(items[i])
			if (want == "" and not k in ["tile", "cap"]) or k == want:
				return i
	return -1


## Height of item i over the cell's surface (m), where its origin goes.
## A cap's top is the surface; a block's top is the surface, or the cap's
## underside when the cell has a cap; everything else stands on the surface.
## The item's own off[1] is added on top.
static func item_y(items: Array, i: int) -> float:
	var it: Dictionary = items[i]
	var p := piece(it.kit, it.piece)
	var y: float = it.off[1]
	match String(p.get("kind", "deco")):
		"cap":
			y -= float(p.get("top", 0.0)) * it.scale
		"tile":
			y -= float(p.get("top", 0.0)) * it.scale
			for x: Dictionary in items:
				var xp := piece(x.kit, x.piece)
				if xp.get("kind", "") == "cap":
					y += float(x.off[1]) - float(xp.get("top", 0.0)) * x.scale
					break
	return y


# --- layout files --------------------------------------------------------

static func empty_layout(arena: int) -> Dictionary:
	return {"arena": arena, "world": world_of(arena), "cells": {}, "roles": {}, "alts": {}}


## The arena's saved layout, or an empty one.
static func load_layout(arena: int, path := "") -> Dictionary:
	if path == "":
		path = layout_path(arena)
	if not FileAccess.file_exists(path):
		return empty_layout(arena)
	return parse(FileAccess.get_file_as_string(path), arena)


static func parse(text: String, arena := 0) -> Dictionary:
	var out := empty_layout(arena)
	var json := JSON.new()   # parse() returns the error instead of logging it
	if json.parse(text) != OK or not json.data is Dictionary:
		return out
	var d: Dictionary = json.data
	out.arena = int(d.get("arena", arena))
	out.world = int(d.get("world", world_of(out.arena)))
	for key: String in d.get("cells", {}):
		var xy := key.split(",")
		if xy.size() != 2:
			continue
		var items := []
		for it in d.cells[key]:
			if it is Dictionary and it.has("kit") and it.has("piece"):
				items.append(full_item(it))
		if not items.is_empty():
			out.cells[Vector2i(int(xy[0]), int(xy[1]))] = items
	var roles = d.get("roles", {})
	if roles is Dictionary:
		for key: String in roles:
			var xy := key.split(",")
			if xy.size() == 2 and String(roles[key]) in EDITABLE_ROLES:
				out.roles[Vector2i(int(xy[0]), int(xy[1]))] = String(roles[key])
	var alts = d.get("alts", {})
	if alts is Dictionary:
		for key: String in alts:
			var xy := key.split(",")
			if xy.size() == 2 and (alts[key] is float or alts[key] is int):
				out.alts[Vector2i(int(xy[0]), int(xy[1]))] = int(alts[key])
	return out


## The file text: one line per cell, cells in row order, so a change to a
## cell is a one-line diff.
static func to_json(layout: Dictionary) -> String:
	var keys: Array = layout.cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var lines := []
	for p: Vector2i in keys:
		var items: Array = layout.cells[p]
		if items.is_empty():
			continue
		var row := []
		for it: Dictionary in items:
			row.append(JSON.stringify(compact_item(it), "", false))
		lines.append("\t\t\"%d,%d\": [%s]" % [p.x, p.y, ", ".join(row)])
	var head := "{\n\t\"arena\": %d,\n\t\"world\": %d,\n\t\"cells\": {" % [
		layout.arena, layout.world]
	var body := head + ("}" if lines.is_empty() else "\n" + ",\n".join(lines) + "\n\t}")
	var roles: Dictionary = layout.get("roles", {})
	if not roles.is_empty():
		var rk: Array = roles.keys()
		rk.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		var rl := []
		for p: Vector2i in rk:
			rl.append("\t\t\"%d,%d\": \"%s\"" % [p.x, p.y, roles[p]])
		body += ",\n\t\"roles\": {\n" + ",\n".join(rl) + "\n\t}"
	var alts: Dictionary = layout.get("alts", {})
	if not alts.is_empty():
		var ak: Array = alts.keys()
		ak.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return a.y < b.y or (a.y == b.y and a.x < b.x))
		var al := []
		for p: Vector2i in ak:
			al.append("\t\t\"%d,%d\": %d" % [p.x, p.y, alts[p]])
		body += ",\n\t\"alts\": {\n" + ",\n".join(al) + "\n\t}"
	return body + "\n}\n"


static func save_layout(layout: Dictionary, path := "") -> Error:
	if path == "":
		path = layout_path(layout.arena)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(to_json(layout))
	f.close()
	return OK


# --- the fight's shape (S36 phase D) --------------------------------------

## What the fight plays on: the arena's shape with the layout's roles and
## heights on it, the way the 3D view draws it.
## {world, arena, cells: {Vector2i: {alt, ground}}, team0, team1, coach:
##  [Vector3i], specials: [{pos: Vector3i, template}]}
## A walkable cell's alt is its surface; an obstacle keeps its retail
## altitude unless the owner moved it (only void vs not matters for it on
## the server). Start cells and pedestals stand at their surface: the ones
## the .fmd had keep its order, the owner's new ones follow in row order.
## The .fmd's special cells stay where the cell is still walkable.
static func fight_shape(arena: int) -> Dictionary:
	var world := world_of(arena)
	var layout := load_layout(arena)
	var sh := shape(world)
	apply_roles(sh, layout.roles)
	apply_alts(sh, layout.alts)
	var fmd := FightMap.load(world)
	var out := {"world": world, "arena": arena, "cells": {}, "team0": [], "team1": [],
		"coach": [], "specials": []}
	var keys: Array = sh.cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	var listed := {}
	for role in ["team0", "team1", "coach"]:
		for c in fmd.get(role, []):
			var p := Vector2i(c.x, c.y)
			if sh.cells.has(p) and sh.cells[p].role == role and not listed.has(p):
				listed[p] = true
				out[role].append(Vector3i(p.x, p.y, sh.cells[p].surface))
	for p: Vector2i in keys:
		var c: Dictionary = sh.cells[p]
		match String(c.role):
			"void":
				continue
			"obstacle":
				out.cells[p] = {"alt": c.surface if layout.alts.has(p) else c.alt, "ground": false}
			"coach":
				out.cells[p] = {"alt": c.surface, "ground": false}
			_:
				out.cells[p] = {"alt": c.surface, "ground": true}
		if c.role in ["team0", "team1", "coach"] and not listed.has(p):
			out[c.role].append(Vector3i(p.x, p.y, c.surface))
	for sp in fmd.get("specials", []):
		var p := Vector2i(sp.pos.x, sp.pos.y)
		if out.cells.has(p) and out.cells[p].ground:
			out.specials.append({"pos": Vector3i(p.x, p.y, out.cells[p].alt),
				"template": int(sp.template)})
	return out


## The fight shape as the server reads it (server/internal/gamedata/
## arenas/<world>.json): one line per cell, "x,y": [alt, "floor" | "obstacle"].
static func fight_json(fs: Dictionary) -> String:
	var lines := []
	var keys: Array = fs.cells.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y < b.y or (a.y == b.y and a.x < b.x))
	for p: Vector2i in keys:
		var c: Dictionary = fs.cells[p]
		lines.append('\t\t"%d,%d": [%d, "%s"]' % [p.x, p.y, c.alt,
			"floor" if c.ground else "obstacle"])
	var pos := func(list: Array) -> String:
		var a := []
		for v: Vector3i in list:
			a.append("[%d, %d, %d]" % [v.x, v.y, v.z])
		return "[" + ", ".join(a) + "]"
	var sp := []
	for s: Dictionary in fs.specials:
		sp.append("[%d, %d, %d, %d]" % [s.pos.x, s.pos.y, s.pos.z, s.template])
	return "{\n\t\"world\": %d,\n\t\"arena\": %d,\n" % [fs.world, fs.arena] \
		+ "\t\"team0\": %s,\n\t\"team1\": %s,\n\t\"coach\": %s,\n" % [
			pos.call(fs.team0), pos.call(fs.team1), pos.call(fs.coach)] \
		+ "\t\"specials\": [%s],\n" % ", ".join(sp) \
		+ "\t\"cells\": {\n" + ",\n".join(lines) + "\n\t}\n}\n"


static func fight_path(world: int) -> String:
	if root() != ART_DIR:
		return "%s/fight/%d.json" % [root(), world]
	return "%s/%d.json" % [FIGHT_DIR, world]


## The world's exported fight shape in fight_view's terms, or {} when the
## world has none: {cells: {Vector2i: {alt, ground}}, fmd: {team0, team1,
## coach: [{x, y, z}], specials: [{pos: {x, y, z}, template}]}} — the same
## shapes Topology.load_world and FightMap.load return.
static func load_fight_shape(world: int) -> Dictionary:
	var path := ProjectSettings.globalize_path(fight_path(world))
	if not FileAccess.file_exists(path):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary or not d.get("cells") is Dictionary:
		return {}
	var cells := {}
	for key: String in d.cells:
		var xy := key.split(",")
		var v: Array = d.cells[key]
		cells[Vector2i(int(xy[0]), int(xy[1]))] = {"alt": int(v[0]), "ground": v[1] == "floor"}
	var fmd := {"specials": []}
	for role in ["team0", "team1", "coach"]:
		fmd[role] = []
		for v: Array in d.get(role, []):
			fmd[role].append({"x": int(v[0]), "y": int(v[1]), "z": int(v[2])})
	for v: Array in d.get("specials", []):
		fmd.specials.append({"pos": {"x": int(v[0]), "y": int(v[1]), "z": int(v[2])},
			"template": int(v[3])})
	return {"cells": cells, "fmd": fmd}


## Writes the release arenas' fight shapes for the server. Returns the paths.
static func export_fight_shapes() -> Array:
	var out := []
	for arena in range(1, RELEASE + 1):
		if export_fight_shape(arena) == OK:
			out.append(ProjectSettings.globalize_path(fight_path(world_of(arena))))
	return out


## Writes one release arena's fight shape; arenas 7-12 have none yet.
static func export_fight_shape(arena: int) -> Error:
	if not in_release(arena):
		return ERR_UNAVAILABLE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIGHT_DIR))
	var f := FileAccess.open(ProjectSettings.globalize_path(fight_path(world_of(arena))),
		FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(fight_json(fight_shape(arena)))
	f.close()
	return OK
