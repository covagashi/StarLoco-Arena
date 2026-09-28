extends RefCounted

## Message codec: schema-driven decode/encode over the generated DEFS table,
## with hand-written handlers for the variable/nested formats.
##
## Invariant: every message decodes on a payload-scoped WireReader, so a schema
## that under-reads is always safe — the stream can never desync.

const Opcodes := preload("res://src/net/generated/opcodes.gd")
const Defs := preload("res://src/net/generated/message_defs.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")


static func decode(opcode: int, r: WireReader) -> Dictionary:
	var d: Variant = Defs.DEFS.get(opcode)
	if d == null:
		return {"_unknown": true}
	if d.has("handler"):
		return Overrides.dispatch(d.handler, opcode, r)
	var out := {}
	for f in d.fields:
		out[f.n] = _read_field(r, f)
	return out


## Encodes a C2S payload from a value dict. Returns an empty array for
## hand-coded/unresolved messages — callers must handle those explicitly.
static func encode_payload(opcode: int, values: Dictionary) -> PackedByteArray:
	var d: Variant = Defs.DEFS.get(opcode)
	if d == null or d.has("handler"):
		push_warning("codec: opcode %d has no generated encoder" % opcode)
		return PackedByteArray()
	var w := WireWriter.new()
	for f in d.fields:
		_write_field(w, f, values.get(f.n))
	return w.raw()


static func _read_field(r: WireReader, f: Dictionary):
	match f.t:
		"u8": return r.get_u8()
		"i8": return r.get_i8()
		"u16": return r.get_u16()
		"i16": return r.get_i16()
		"i32": return r.get_i32()
		"i64": return r.get_i64()
		"f32": return r.get_f32()
		"f64": return r.get_f64()
		"str_u8": return r.get_str("u8", f.get("enc", "cp1252"))
		"str_u16": return r.get_str("u16", f.get("enc", "cp1252"))
		"str_i32": return r.get_str("i32", f.get("enc", "cp1252"))
		_:
			push_warning("codec: unknown field type %s" % f.t)
			return null


static func _write_field(w: WireWriter, f: Dictionary, v) -> void:
	match f.t:
		"u8": w.put_u8(v)
		"i8": w.put_i8(v)
		"u16": w.put_u16(v)
		"i16": w.put_i16(v)
		"i32": w.put_i32(v)
		"i64": w.put_i64(v)
		"f32": w.put_f32(v)
		"f64": w.put_f64(v)
		"str_u8": w.put_str(v, "u8", f.get("enc", "cp1252"))
		"str_u16": w.put_str(v, "u16", f.get("enc", "cp1252"))
		"str_i32": w.put_str(v, "i32", f.get("enc", "cp1252"))
		_:
			push_warning("codec: cannot write field type %s" % f.t)
