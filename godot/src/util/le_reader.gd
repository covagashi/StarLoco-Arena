extends RefCounted

## Little-endian reader for ASSET files (maps, .fmd, sprites).
## Opposite of the wire format, which is big-endian — mirrors the client's
## `acf` reader. PackedByteArray.decode_* are natively little-endian.

var _buf: PackedByteArray
var _pos := 0


func _init(buf: PackedByteArray = PackedByteArray()) -> void:
	_buf = buf


func remaining() -> int:
	return _buf.size() - _pos


func buffer() -> PackedByteArray:
	return _buf


func u8() -> int:
	var v := _buf[_pos]
	_pos += 1
	return v


func i8() -> int:
	var v := _buf[_pos]
	_pos += 1
	return v - 256 if v >= 128 else v


func u16() -> int:
	var v := _buf.decode_u16(_pos)
	_pos += 2
	return v


func i16() -> int:
	var v := _buf.decode_s16(_pos)
	_pos += 2
	return v


func u32() -> int:
	var v := _buf.decode_u32(_pos)
	_pos += 4
	return v


func i32() -> int:
	var v := _buf.decode_s32(_pos)
	_pos += 4
	return v


func bytes(n: int) -> PackedByteArray:
	var v := _buf.slice(_pos, _pos + n)
	_pos += n
	return v
