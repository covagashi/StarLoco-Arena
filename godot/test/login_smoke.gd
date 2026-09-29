extends SceneTree

## Headless M0 smoke test: TCP connect → ClientVersion → ClientAuthentication
## → (coach creation if asked) → wait for EnterInstance+InstanceReady.
##
##   godot --headless --path godot -s test/login_smoke.gd [host] [port] [login] [pass]
##
## Exit 0 on reaching "instance ready"; 1 on refusal/timeout.

const ArenaClient := preload("res://src/net/arena_client.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const Codec := preload("res://src/net/codec.gd")
const Opcodes := preload("res://src/net/generated/opcodes.gd")

var client: ArenaClient
var saw := {}
var finished := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var host: String = args[0] if args.size() > 0 else "127.0.0.1"
	var port := int(args[1]) if args.size() > 1 else 5555
	var login: String = args[2] if args.size() > 2 else "test"
	var password: String = args[3] if args.size() > 3 else "test123"

	client = ArenaClient.new()
	root.add_child(client)
	client.connected.connect(func(): _send_login(login, password))
	client.message_received.connect(_on_message)
	client.disconnected.connect(_finish.bind(1, "disconnected before ready"))

	print("[smoke] connecting %s:%d" % [host, port])
	if client.connect_to(host, port) != OK:
		_finish(1, "connect_to_host failed")
		return
	create_timer(15.0).timeout.connect(_finish.bind(1, "timeout"))


func _send_login(login: String, password: String) -> void:
	var version := WireWriter.new()
	version.put_u8(0x02)
	version.put_u16(70)
	version.put_u8(5)
	version.put_bytes("72909".to_ascii_buffer())
	client.send_message(7, version.raw(), 0)

	var auth := WireWriter.new()
	var l := CP1252.encode(login)
	var p := CP1252.encode(password)
	auth.put_u8(l.size())
	auth.put_bytes(l)
	auth.put_u8(p.size())
	auth.put_bytes(p)
	client.send_message(1025, auth.raw(), 1)
	print("[smoke] sent version(7) + auth(1025)")


func _on_message(opcode: int, payload) -> void:
	saw[opcode] = true
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	var msg_name: String = Opcodes.NAMES.get(opcode, "?")
	match opcode:
		8:
			_finish(1, "opcode 8: version rejected")
		1024:
			if decoded.get("result") == 0:
				print("[smoke] 1024 auth OK")
			else:
				_finish(1, "1024 auth refused code=%s" % decoded.get("result"))
		2048:
			print("[smoke] 2048 coach creation requested — answering 2049")
			_send_coach("test")
		2052:
			print("[smoke] 2052 %s: coach id=%s name='%s'" % [msg_name, decoded.get("id"), decoded.get("name")])
		4600:
			print("[smoke] 4600 enter instance world=%s pos=(%s,%s)" % [
				decoded.get("world_id"), decoded.get("x"), decoded.get("y")])
		4516:
			print("[smoke] 4516 instance ready")
			_finish(0, "LOGIN OK — reached instance ready")
		_:
			print("[smoke]   opcode %d %s (%d bytes) -> %s" % [
				opcode, msg_name, payload.remaining(), str(decoded).left(120)])


func _send_coach(coach_name: String) -> void:
	var n := CP1252.encode(coach_name)
	var w := WireWriter.new()
	w.put_u8(n.size())
	w.put_bytes(n)
	w.put_u8(1)
	w.put_u8(1)
	w.put_u8(0)
	client.send_message(2049, w.raw(), 2)


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
