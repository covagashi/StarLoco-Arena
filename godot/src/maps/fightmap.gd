extends RefCounted

## .fmd decoder — port of server/cmd/studio/mapfmd.go (client class `Om`).
##
## maps/fight/<id>.jar!/<id>.fmd, little-endian:
##   6× i32 packed coach-pedestal cells (slot 0 = side 0, slot 1 = side 1)
##   u16 word: hi byte = team0 count, lo byte = team1 count
##   t0× i32 + t1× i32 packed fighter start cells
##   u8 count + {i32,i32} specials (skipped)
## Packed cell: x=(v>>20&0xFFF)-2047, y=(v>>8&0xFFF)-2047, z=(v&0xFF)-127.

const LeReader := preload("res://src/util/le_reader.gd")
const Jar := preload("res://src/maps/jar.gd")


static func _unpack(v: int) -> Dictionary:
	return {
		"x": int((v >> 20) & 0xFFF) - 2047,
		"y": int((v >> 8) & 0xFFF) - 2047,
		"z": int(v & 0xFF) - 127,
	}


## map_id -> {coach:[cells], team0:[cells], team1:[cells]} or {} if not an arena.
static func load(map_id: int) -> Dictionary:
	var data := Jar.read_entry(Jar.fight_jar(map_id), "%d.fmd" % map_id)
	if data.is_empty():
		return {}
	var r := LeReader.new(data)
	var coach := []
	for i in 6:
		coach.append(_unpack(r.u32()))
	var word := r.u16()
	var t0: int = word >> 8
	var t1: int = word & 0xFF
	if t0 > 4096 or t1 > 4096:
		return {}
	var team0 := []
	var team1 := []
	for i in t0:
		team0.append(_unpack(r.u32()))
	for i in t1:
		team1.append(_unpack(r.u32()))
	var specials := []
	for i in r.u8():
		specials.append({"pos": _unpack(r.u32()), "template": r.u32()})
	return {"coach": coach, "team0": team0, "team1": team1, "specials": specials}
