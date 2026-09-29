extends SceneTree

## Keepalive check: login, stay idle ~66s, count 107->108 pong replies.
## Retail pings once per arch in {1,2} every 60s — expect >= 2 pongs.
## Run: godot --headless --path godot -s test/ping_smoke.gd

const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")

var _sess: Node
var _pongs := 0


func _init() -> void:
	await process_frame
	_sess = root.get_node("Session")
	_sess.message.connect(_on_msg)
	_sess.connect_to("127.0.0.1", 5555)
	await create_timer(0.5).timeout
	_send_login()
	await create_timer(66.0).timeout
	print("[smoke] pongs received=%d" % _pongs)
	quit(0 if _pongs >= 2 else 1)


func _send_login() -> void:
	var v := WireWriter.new()
	v.put_u8(0x02)
	v.put_u16(70)
	v.put_u8(5)
	v.put_bytes("72909".to_ascii_buffer())
	_sess.send(7, v.raw(), 0)
	var a := WireWriter.new()
	var l := CP1252.encode("test")
	var p := CP1252.encode("test123")
	a.put_u8(l.size())
	a.put_bytes(l)
	a.put_u8(p.size())
	a.put_bytes(p)
	_sess.send(1025, a.raw(), 1)


func _on_msg(op: int, raw: PackedByteArray) -> void:
	if op == 2048:
		var w := WireWriter.new()
		w.put_u8(4)
		w.put_bytes("test".to_ascii_buffer())
		w.put_u8(1)
		w.put_u8(1)
		w.put_u8(0)
		_sess.send(2049, w.raw(), 2)
	elif op == 108:
		_pongs += 1
		print("[smoke] pong %d — %d bytes: %s"
			% [_pongs, raw.size(), raw.slice(0, 5).hex_encode()])
