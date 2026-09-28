extends RefCounted

## Topology decoder — port of server/internal/gamedata/worldtopo.go.
##
## maps/tplg/<world>.jar holds one entry per 18×18 chunk ("<cx>_<cy>"),
## little-endian: u8 type(&0xF) + i16 chunkX + i16 chunkY (×18 = origin) +
## i16 wp (base altitude). Tile kinds: 0 uniform, 1 nibble, 2 flat,
## 3 packed, 5 layered (client afg.az factory). Arena scope accepts 2/3/5;
## world scope accepts all (uniform/nibble are most overworld ground).

const LeReader := preload("res://src/util/le_reader.gd")
const Jar := preload("res://src/maps/jar.gd")

const CHUNK_SIDE := 18
const VOID_ALT := -32768
const SCOPE_ARENA := 0
const SCOPE_WORLD := 1


## world_id -> {cells: {"x,y": {alt, ground}}, bounds: Rect2i}
static func load_world(world_id: int, scope: int = SCOPE_WORLD) -> Dictionary:
	var z := Jar.open(Jar.tplg_jar(world_id))
	if z == null:
		return {}
	var cells := {}
	var bounds := Rect2i()
	var have_bounds := false
	for entry in z.get_files():
		if entry.begins_with("META-INF") or entry == "coord":
			continue
		var data := z.read_file(entry)
		if data.size() < 8:
			continue
		var r := LeReader.new(data)
		var typ := r.u8() & 0x0F
		var ox := r.i16() * CHUNK_SIDE
		var oy := r.i16() * CHUNK_SIDE
		var wp := r.i16()
		var chunk := _decode_tiles(r, typ, wp, scope)
		if chunk.is_empty():
			continue
		for i in CHUNK_SIDE * CHUNK_SIDE:
			var x := ox + (i % CHUNK_SIDE)
			var y := oy + (i / CHUNK_SIDE)
			var cell := {"alt": chunk.alt[i], "ground": chunk.ground[i]}
			# layered chunks can stack floors — keep every walkable altitude so
			# authored spawn z can be validated per-layer (HasWalkableLayerAt)
			if chunk.walkable.has(i):
				cell.layers = chunk.walkable[i]
			cells[Vector2i(x, y)] = cell
			if not have_bounds:
				bounds = Rect2i(x, y, 1, 1)
				have_bounds = true
			else:
				bounds = bounds.expand(Vector2i(x, y))
	z.close()
	return {"world": world_id, "cells": cells, "bounds": bounds}


## Go stores altitudes in int16 fields — sums wrap. Match that or values like
## 65537 silently compare wrong against the i16-bounded .fmd z.
static func _s16(v: int) -> int:
	v = v & 0xFFFF
	return v - 0x10000 if v >= 0x8000 else v


static func _decode_tiles(r: LeReader, typ: int, wp: int, scope: int) -> Dictionary:
	var alt := []
	var ground := []
	var walkable := {}
	alt.resize(CHUNK_SIDE * CHUNK_SIDE)
	ground.resize(CHUNK_SIDE * CHUNK_SIDE)
	alt.fill(VOID_ALT)
	ground.fill(false)

	match typ:
		0:  # uniform — one ground byte over all cells (world filler)
			if scope != SCOPE_WORLD:
				return {}
			var g := r.i8() != -1
			for i in alt.size():
				alt[i] = wp
				ground[i] = g
		1:  # nibble — 8-alt palette, 2 ground entries, 4-bit grid
			if scope != SCOPE_WORLD:
				return {}
			var alt_pal := []
			for i in 8:
				alt_pal.append(_s16(wp + r.i16()))
			var gnd_pal := [r.i8(), r.i8()]
			var grid := r.bytes(162)
			for i in CHUNK_SIDE * CHUNK_SIDE:
				var n: int = (grid[i >> 1] & 0x0F) if i & 1 else (grid[i >> 1] >> 4)
				alt[i] = alt_pal[n >> 1]
				ground[i] = gnd_pal[n & 1] != -1
		2:  # flat — one palette-indexed layer
			var alt_pal := []
			for i in 16:
				alt_pal.append(_s16(wp + r.i16()))
			var gnd_pal := [r.i8(), r.i8(), r.i8(), r.i8()]
			for i in CHUNK_SIDE * CHUNK_SIDE:
				var b := r.u8()
				alt[i] = alt_pal[b & 0x0F]
				ground[i] = gnd_pal[(b & 0x30) >> 4] != -1
		3:  # packed — i16 per cell: sign-extended >>12 = floor flag, low10 = alt
			for i in CHUNK_SIDE * CHUNK_SIDE:
				var raw := r.u16()
				var cc := (raw >> 12) & 0xF
				var cc_signed := cc - 16 if cc >= 8 else cc  # sign-extend nibble
				var alt_raw := raw & 0x3FF
				alt[i] = VOID_ALT if alt_raw == 0 else _s16(wp - 512 + alt_raw)
				ground[i] = cc_signed != -1
		5:  # layered — sorted packed per-layer entries
			for i in 64:
				r.u8()  # dSi render palette
			var n := r.u16()
			var seen := {}
			for i in n:
				var v := r.u32()
				var cx := int(v & 0x1F)
				var cy := int((v >> 5) & 0x1F)
				if cx >= CHUNK_SIDE or cy >= CHUNK_SIDE:
					continue
				var idx := cy * CHUNK_SIDE + cx
				var alt_raw := int((v >> 10) & 0x3FF)
				var a := VOID_ALT if alt_raw == 0 else _s16(wp - 512 + alt_raw)
				var g := ((v >> 22) & 0xF) != 15  # 15 encodes -1: no floor
				if g:
					walkable[idx] = walkable.get(idx, []) + [a]
				# standing surface = highest floored layer (verified vs .fmd)
				if not seen.has(idx):
					seen[idx] = true
					alt[idx] = a
					ground[idx] = g
				elif g and (not ground[idx] or a > alt[idx]):
					alt[idx] = a
					ground[idx] = true
		_:
			return {}
	return {"alt": alt, "ground": ground, "walkable": walkable}


## True if the cell has a walkable floor at exactly this altitude —
## the check an authored arrival z has to pass (client pathfinder semantics).
static func has_walkable_layer_at(cell: Variant, z: int) -> bool:
	if cell == null or not cell.ground:
		return false
	if cell.alt == z:
		return true
	return cell.get("layers", []).has(z)
