extends RefCounted
## S19 (B-186): the 2052 LocalCoach's 0x8 blob carries the 1v1 force as
## {u8 ladderType, i16 strength}; the decoder used to read only the count, so
## a ranked coach would have shifted adminRight. Built byte for byte as the
## server's handshake.EncodeCoachInformations writes it.

const Codec := preload("res://src/net/codec.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")


func _frame(ladders: Array) -> PackedByteArray:
	var w := WireWriter.new()
	w.put_i64(7)
	w.put_u8(1)
	w.put_bytes("X".to_utf8_buffer())
	w.put_u8(0); w.put_u8(0); w.put_u8(0)   # skin, hair, sex
	w.put_u16(0)                            # look
	w.put_i32(0); w.put_u16(0)              # 0x100 tournament points + wallet
	w.put_i32(40)                           # 0x400 standing
	for _i in 5:                            # guild, tome, inventory, equipment, criteria
		w.put_u16(0)
	w.put_u8(ladders.size())
	for l in ladders:
		w.put_u8(l[0])
		w.put_u16(l[1])
	w.put_i32(3)                            # 0x800 adminRight
	return w.raw()


func run(t) -> void:
	t.suite("coach_info")
	var ranked := Codec.decode(2052, WireReader.new(_frame([[1, 1500]])))
	t.eq(int(ranked.get("ladders", {}).get(1, -1)), 1500, "1v1 force read from the 0x8 blob")
	t.eq(int(ranked.get("admin_right", -1)), 3, "adminRight still lines up after a ladder entry")
	var unranked := Codec.decode(2052, WireReader.new(_frame([])))
	t.eq(unranked.get("ladders", {}).size(), 0, "an unranked coach has no ladder entry")
	t.eq(int(unranked.get("admin_right", -1)), 3, "adminRight with no ladder entry")
