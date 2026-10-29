extends RefCounted

## M7 (S36): an arena's layout — which of our kiln pieces stand on which
## cell — plus the arena list, the kits the pieces come from and the arena's
## shape. Pure data and arithmetic: the map editor (tools/map_editor/) writes
## layouts, arena_scene.gd turns one into 3D, and phase D's fight_view will
## read the same files.
##
## art/layouts/arena-NN.json (one per arena, readable and diffable):
##   {"arena": 1, "world": 5, "cells": {"x,y": [item, ...]}}
## item: {"kit": "arena1", "piece": "ice_block", "loom": "a"|"b"|"c",
##        "rot": degrees about y, "flip": mirrored, "tint": "rrggbb"
##        multiplier, "scale": uniform, "off": [x, y, z] in m}
## Everything after kit/piece is optional: a missing key is its default.
##
## The shape is never edited: cells, altitudes, obstacles and start cells are
## the fight topology the server uses (server/data-dist/maps/).

const Topology := preload("res://src/maps/topology.gd")
const FightMap := preload("res://src/maps/fightmap.gd")

## The 12 arenas of 1.0 (S36 scope, owner 2026-10-28) by retail world id:
## arena N is the N-th.
const WORLDS := [5, 10, 12, 15, 21, 36, 38, 39, 40, 41, 42, 44]
const ART_DIR := "res://art"
const LAYOUT_DIR := "res://art/layouts"
## Loom letter -> model file suffix (kit.json "looms").
const LOOMS := {"a": "", "b": "_b", "c": "_c"}

const PX := 43.0 * 1.41421356          # screen px per world unit across
const ALT := 10.0 / (PX * 0.8660254)   # world units per altitude step (10 px)
## How far the columns run under the lowest cell (as build_map.gd).
const FLOOR_DEPTH := 1.2

## kit dir name ("arena1") -> parsed kit.json; filled on first use.
static var _kits := {}


## Arena number (1..12) -> world id, or -1.
static func world_of(arena: int) -> int:
	return WORLDS[arena - 1] if arena >= 1 and arena <= WORLDS.size() else -1


static func layout_path(arena: int) -> String:
	return "%s/arena-%02d.json" % [LAYOUT_DIR, arena]


## Every tracked kit: art/arena<N>/kit.json. The biome folders (lava/,
## pradera/…) are the discarded agent attempt and stay out.
static func kits() -> Dictionary:
	if _kits.is_empty():
		var d := DirAccess.open(ART_DIR)
		if d == null:
			return _kits
		for sub in d.get_directories():
			if not (sub.begins_with("arena") and sub.substr(5).is_valid_int()):
				continue
			var path := "%s/%s/kit.json" % [ART_DIR, sub]
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
	return "%s/%s/out/models/%s%s.glb" % [ART_DIR, kit, name, LOOMS.get(loom, "")]


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


## Altitude of the lowest walkable neighbour (the floor an obstacle stands on).
static func _floor_near(cells: Dictionary, p: Vector2i, fallback: int) -> int:
	var best := fallback
	var found := false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Dictionary = cells.get(p + d, {})
		if nb.get("ground", false) and (not found or nb.alt < best):
			best = nb.alt
			found = true
	return best


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
	return {"arena": arena, "world": world_of(arena), "cells": {}}


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
	if lines.is_empty():
		return head + "}\n}\n"
	return head + "\n" + ",\n".join(lines) + "\n\t}\n}\n"


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
