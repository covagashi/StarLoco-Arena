extends RefCounted

## Big-endian wire writer matching the DofusArena 2.70 protocol.
##
## The wire is big-endian everywhere (client messages decode via plain
## ByteBuffer.wrap()). C2S frame: [u16 totalLen][u8 archTarget][u16 opcode][payload]
## where totalLen = 5 + payloadLen. See client/analysis/PROTOCOL.md §1.
##
## No `class_name` on purpose: this library is referenced via preload() so it
## parses independently of the editor's global class cache (headless-safe).

var _buf := PackedByteArray()


func put_u8(v: int) -> void:
	_buf.append(v & 0xFF)


func put_i8(v: int) -> void:
	put_u8(v)


func put_i16(v: int) -> void:
	put_u16(v)


func put_u16(v: int) -> void:
	_buf.append((v >> 8) & 0xFF)
	_buf.append(v & 0xFF)


func put_i32(v: int) -> void:
	_buf.append((v >> 24) & 0xFF)
	_buf.append((v >> 16) & 0xFF)
	_buf.append((v >> 8) & 0xFF)
	_buf.append(v & 0xFF)


func put_i64(v: int) -> void:
	for i in range(7, -1, -1):
		_buf.append((v >> (i * 8)) & 0xFF)


func put_f32(v: float) -> void:
	var b := PackedByteArray([0, 0, 0, 0])
	b.encode_float(0, v)
	b.reverse()
	put_bytes(b)


func put_f64(v: float) -> void:
	var b := PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	b.encode_double(0, v)
	b.reverse()
	put_bytes(b)


const CP1252 := preload("res://src/net/cp1252.gd")

## Length-prefixed string; enc selects cp1252 (what the server decodes) or utf8.
func put_str(s: String, len_t: String, enc: String = "cp1252") -> void:
	var b := s.to_utf8_buffer() if enc == "utf8" else CP1252.encode(s)
	match len_t:
		"u8": put_u8(b.size())
		"u16": put_u16(b.size())
		"i32": put_i32(b.size())
	put_bytes(b)


func put_bytes(b: PackedByteArray) -> void:
	_buf.append_array(b)


## Java modified-UTF style string: u16 length prefix + UTF-8 bytes.
func put_utf(s: String) -> void:
	var b := s.to_utf8_buffer()
	put_u16(b.size())
	put_bytes(b)


func raw() -> PackedByteArray:
	return _buf


func size() -> int:
	return _buf.size()


## Wraps a payload in the C2S 5-byte header.
static func frame(opcode: int, payload: PackedByteArray, arch_target: int = 3) -> PackedByteArray:
	var total := 5 + payload.size()
	var out := PackedByteArray()
	out.append_array([
		(total >> 8) & 0xFF, total & 0xFF,
		arch_target & 0xFF,
		(opcode >> 8) & 0xFF, opcode & 0xFF,
	])
	out.append_array(payload)
	return out
