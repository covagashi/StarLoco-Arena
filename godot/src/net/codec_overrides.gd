extends RefCounted

## Hand-written decoders for the messages the generator marks "handler".
## Dispatch is by handler name; each returns a Dictionary of decoded fields.

const WireReader := preload("res://src/net/wire_reader.gd")


static func dispatch(handler: String, opcode: int, r: WireReader) -> Dictionary:
	match handler:
		"coach_info": return _coach_info(r)
		"part_table": return _part_table(r)
		"actor_spawn": return _actor_spawn(r)
		"fighter_list": return _fighter_list(r)
		"friend_list": return _friend_list(r)
		"ignore_list": return _ignore_list(r)
		"wallet": return _wallet(r)
		"inventory": return _inventory(r)
		"stat_map": return _stat_map(r)
		"preset_list": return _preset_list(r)
		_:
			return {"_opcode": opcode, "_raw": r.get_rest(),
					"_handler": handler}


## Opcode 2052 — LocalCoach at flags=4014, source order, mirrors
## server/internal/handshake/coach.go:238-291. Blobs are length-prefixed and
## captured raw; their internals decode on demand.
static func _coach_info(r: WireReader) -> Dictionary:
	var out := {}
	out.id = r.get_i64()
	out.name = r.get_str("u8")
	out.skin = r.get_u8()
	out.hair = r.get_u8()
	out.sex = r.get_u8()
	out.look = r.get_u16()
	out.tournament_points = r.get_i32()
	out.ladder_blob = r.get_bytes(r.get_u16())
	out.standing = r.get_i32()
	out.guild_blob = r.get_bytes(r.get_u16())
	out.tome_blob = r.get_bytes(r.get_u16())
	out.card_inv_blob = r.get_bytes(r.get_u16())
	out.equip_blob = r.get_bytes(r.get_u16())
	out.criteria_blob = r.get_bytes(r.get_u16())
	out.ladder_count = r.get_u8()
	out.admin_right = r.get_i32()
	return out


## Generic part-table container (aJj.ad — PROTOCOL-parttable.md §1):
##   [u8 partCount] partCount × {u8 partId, i32 offset}
##   part bytes = buffer[offset+1 .. nextOffset-1]; last ends at limit-1.
## Returns {"parts": {partId: PackedByteArray}} — per-part decoders layer on top.
static func _part_table(r: WireReader) -> Dictionary:
	var buf: PackedByteArray = r.buffer()
	var count := r.get_u8()
	var index := []
	for i in count:
		index.append({"id": r.get_u8(), "off": r.get_i32()})
	var parts := {}
	for i in index.size():
		var start: int = index[i].off + 1
		var end: int = (index[i + 1].off - 1) if i + 1 < index.size() else buf.size() - 1
		parts[index[i].id] = buf.slice(start, end)
	return {"parts": parts}


## Opcode 4096 — i32 prefix: negative = that many raw bytes follow;
## positive = zlib-inflated length (wa_1.java:75-102).
static func _actor_spawn(r: WireReader) -> Dictionary:
	var n := r.get_i32()
	if n < 0:
		return {"actors_raw": r.get_bytes(-n), "compressed": false}
	var raw := r.get_bytes(r.remaining())
	var data := raw.decompress_dynamic(-1, FileAccess.COMPRESSION_DEFLATE)
	return {"actors_raw": data, "compressed": not data.is_empty()}


## Opcode 6006 — [i64 leadId][u8 count]{i64 id, u16 len, et_2 blob}.
static func _fighter_list(r: WireReader) -> Dictionary:
	var out := {"lead_id": r.get_i64(), "fighters": []}
	var count := r.get_u8()
	for i in count:
		var fid := r.get_i64()
		var blob := r.get_bytes(r.get_u16())
		out.fighters.append({"id": fid, "blob": blob})
	return out


## Opcode 3144 — [u8 n]{u16 len, friend blob}. Blob internals (presence,
## status, guild) decode later.
static func _friend_list(r: WireReader) -> Dictionary:
	var out := {"friends": []}
	for i in r.get_u8():
		out.friends.append(r.get_bytes(r.get_u16()))
	return out


## Opcode 3146 — [u8 n]{str:u8 name}.
static func _ignore_list(r: WireReader) -> Dictionary:
	var out := {"names": []}
	for i in r.get_u8():
		out.names.append(r.get_str("u8"))
	return out


## Opcode 4001 — [u8 n]{u8 currencyType, i32 amount}.
static func _wallet(r: WireReader) -> Dictionary:
	var out := {"currencies": []}
	for i in r.get_u8():
		out.currencies.append({"type": r.get_u8(), "amount": r.get_i32()})
	return out


## Opcode 5200 — [u16][u16][u16 n]{i32 cardId, u16 qty}[u16]
## (handlers_inventory.go:43). Leading/trailing u16s captured verbatim.
static func _inventory(r: WireReader) -> Dictionary:
	var out := {"head0": r.get_u16(), "head1": r.get_u16(), "cards": []}
	for i in r.get_u16():
		out.cards.append({"card_id": r.get_i32(), "qty": r.get_u16()})
	out.tail = r.get_u16() if r.remaining() >= 2 else 0
	return out


## Opcodes 2400/2401 — rs_2 typed stat-map:
## [u16 blobLen][u16 modelId][i64 owner][u16 n]{u16 statId, u8 type, value}
## value: type 1 = i32, 2 = i64, 3 = f32 (OPCODE-INVENTORY.md:216).
static func _stat_map(r: WireReader) -> Dictionary:
	var blob := r.get_bytes(r.get_u16())
	var br := WireReader.new(blob)
	var out := {"model_id": br.get_u16(), "owner": br.get_i64(), "stats": []}
	for i in br.get_u16():
		var entry := {"id": br.get_u16(), "type": br.get_u8()}
		match entry.type:
			1: entry.value = br.get_i32()
			2: entry.value = br.get_i64()
			3: entry.value = br.get_f32()
		out.stats.append(entry)
	return out


## Opcode 6030 — [u8 n]{u16 len, sw_1 preset blob}. Preset internals are
## conditional (appearance block); captured raw for now.
static func _preset_list(r: WireReader) -> Dictionary:
	var out := {"presets": []}
	for i in r.get_u8():
		out.presets.append(r.get_bytes(r.get_u16()))
	return out
