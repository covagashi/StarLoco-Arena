extends RefCounted

## Replay file format (S11) — the fight's S2C frames as they arrived.
##
## The retail recorded `game/replays/*.rda` (tu_1): one text line per entry of
## its own internal action timeline (codes 100-500, classes vu_0, act, mv_0…).
## This client has no such timeline — it paints from the wire — so a replay is
## the wire itself: every frame from FightCreation (8000) to EndFight (8300),
## with its arrival time. fight_view replays it unchanged (replay_client.gd).
##
## Layout, gzip-compressed (FileAccess.open_compressed):
##   "SLRP" [u8 version] [u32 header_len][header JSON, utf8]
##   then per frame: [u32 t_ms][u16 opcode][u32 len][payload]
## The header goes first but is written last (the recorder keeps the frames
## in memory), so it can carry the result and the duration.

const MAGIC := "SLRP"
const VERSION := 1
const EXT := "slr"
const DIR := "user://replays"
## Older recordings beyond this many are deleted on each save.
const KEEP := 30


## Write `header` + `frames` ([{t, op, raw}]) to `path`. Returns the error.
static func write(path: String, header: Dictionary, frames: Array) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open_compressed(path, FileAccess.WRITE,
		FileAccess.COMPRESSION_GZIP)
	if f == null:
		return FileAccess.get_open_error()
	f.big_endian = true
	f.store_buffer(MAGIC.to_ascii_buffer())
	f.store_8(VERSION)
	var head := JSON.stringify(header).to_utf8_buffer()
	f.store_32(head.size())
	f.store_buffer(head)
	for fr in frames:
		var raw: PackedByteArray = fr.raw
		f.store_32(maxi(int(fr.t), 0))
		f.store_16(int(fr.op))
		f.store_32(raw.size())
		f.store_buffer(raw)
	f.close()
	return OK


## Read the header only (the replay list) — {} when the file isn't a replay.
static func read_header(path: String) -> Dictionary:
	var f := _open(path)
	if f == null:
		return {}
	var head := _header(f)
	f.close()
	return head


## Read the whole replay: {header, frames: [{t, op, raw}]}, or {} when the
## file isn't one. A truncated tail (a crash mid-write) keeps what is whole.
static func read(path: String) -> Dictionary:
	var f := _open(path)
	if f == null:
		return {}
	var head := _header(f)
	if head.is_empty():
		f.close()
		return {}
	var frames := []
	while true:
		var t := f.get_32()
		var op := f.get_16()
		var n := f.get_32()
		if f.eof_reached():
			break
		var raw := f.get_buffer(n)
		if raw.size() < n:
			break
		frames.append({"t": t, "op": op, "raw": raw})
	f.close()
	return {"header": head, "frames": frames}


## Every replay in DIR, newest first: [{path, header}].
static func list(dir := DIR) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for name in d.get_files():
		if name.get_extension() != EXT:
			continue
		var path := dir.path_join(name)
		var head := read_header(path)
		if not head.is_empty():
			out.append({"path": path, "header": head})
	out.sort_custom(func(a, b):
		return int(a.header.get("recorded_at", 0)) > int(b.header.get("recorded_at", 0)))
	return out


## Delete all but the newest `keep` replays.
static func prune(dir := DIR, keep := KEEP) -> void:
	var all := list(dir)
	for i in range(keep, all.size()):
		DirAccess.remove_absolute(all[i].path)


## retail-style file name: AAMMDDhhmm_A_VS_B.slr
static func file_name(unix: int, left: String, right: String) -> String:
	var d := Time.get_datetime_dict_from_unix_time(unix)
	return "%02d%02d%02d%02d%02d_%s_VS_%s.%s" % [d.year % 100, d.month, d.day,
		d.hour, d.minute, _safe(left), _safe(right), EXT]


static func _safe(s: String) -> String:
	var out := ""
	for c in s:
		out += c if (c.is_valid_identifier() or c.is_valid_int()) else ""
	return out.left(20) if out != "" else "X"


static func _open(path: String) -> FileAccess:
	var f := FileAccess.open_compressed(path, FileAccess.READ,
		FileAccess.COMPRESSION_GZIP)
	if f != null:
		f.big_endian = true
	return f


static func _header(f: FileAccess) -> Dictionary:
	if f.get_buffer(4).get_string_from_ascii() != MAGIC:
		return {}
	if f.get_8() != VERSION:
		return {}
	var n := f.get_32()
	if n <= 0 or n > 1 << 20:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_buffer(n).get_string_from_utf8())
	return parsed if parsed is Dictionary else {}
