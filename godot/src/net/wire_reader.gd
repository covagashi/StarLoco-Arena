extends RefCounted

## Big-endian reader over an S2C payload (header already stripped).
## The dispatcher hands the message class only the payload.
##
## No `class_name` — referenced via preload() (headless-safe).

const CP1252 := preload("res://src/net/cp1252.gd")

var _buf: PackedByteArray
var _pos := 0


func _init(buf: PackedByteArray = PackedByteArray()) -> void:
	_buf = buf


func remaining() -> int:
	return _buf.size() - _pos


## Raw payload access — the part-table container uses absolute offsets into it.
func buffer() -> PackedByteArray:
	return _buf


func get_u8() -> int:
	var v := _buf[_pos]
	_pos += 1
	return v


func get_i8() -> int:
	var v := _buf[_pos]
	_pos += 1
	return v - 256 if v >= 128 else v


func get_u16() -> int:
	var v := (_buf[_pos] << 8) | _buf[_pos + 1]
	_pos += 2
	return v


func get_i16() -> int:
	var v := get_u16()
	return v - 0x10000 if v >= 0x8000 else v


func get_i32() -> int:
	var v := (_buf[_pos] << 24) | (_buf[_pos + 1] << 16) | (_buf[_pos + 2] << 8) | _buf[_pos + 3]
	_pos += 4
	return v - 0x100000000 if v >= 0x80000000 else v


func get_i64() -> int:
	var v := 0
	for i in 8:
		v = (v << 8) | _buf[_pos + i]
	_pos += 8
	return v  # int64 shift overflow wraps to the correct signed value


func get_f32() -> float:
	var b := get_bytes(4)
	b.reverse()
	return b.decode_float(0)


func get_f64() -> float:
	var b := get_bytes(8)
	b.reverse()
	return b.decode_double(0)


func get_bytes(n: int) -> PackedByteArray:
	var v := _buf.slice(_pos, _pos + n)
	_pos += n
	return v


func get_utf() -> String:
	var n := get_u16()
	return get_bytes(n).get_string_from_utf8()


## Length-prefixed string; enc selects cp1252 (server's decode) or utf8.
func get_str(len_t: String, enc: String = "cp1252") -> String:
	var n: int
	match len_t:
		"u8": n = get_u8()
		"u16": n = get_u16()
		"i32": n = get_i32()
	var b := get_bytes(n)
	return b.get_string_from_utf8() if enc == "utf8" else CP1252.decode(b)


func get_rest() -> PackedByteArray:
	return get_bytes(remaining())
