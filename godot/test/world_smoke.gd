extends SceneTree

## Live overworld check: login -> EnterInstance -> world view + a scripted
## click-move. Run: godot --path godot -s test/world_smoke.gd
## Uses the real Session autoload (it IS instantiated under -s; only the
## global identifier doesn't resolve, so we grab the node by name).

const Codec := preload("res://src/net/codec.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")

var _sess: Node
var _main
var _entered := false


func _init() -> void:
	# autoloads are already instanced when a -s script's deferred work runs;
	# give them a frame then drive through the real Session node.
	await process_frame
	_sess = root.get_node("Session")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_sess.message.connect(_on_msg)
	_sess.connect_to("127.0.0.1", 5555)
	await create_timer(0.5).timeout
	_send_login()


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
	var payload := WireReader.new(raw)
	match op:
		2048:
			var w := WireWriter.new()
			w.put_u8(4)
			w.put_bytes("test".to_ascii_buffer())
			w.put_u8(1)
			w.put_u8(1)
			w.put_u8(0)
			_sess.send(2049, w.raw(), 2)
		2052:
			var d := Codec.decode(op, payload)
			State.my_coach_id = int(d.get("id", -1))
			print("[smoke] coach id=", State.my_coach_id)
		4600:
			var d := Codec.decode(op, payload)
			print("[smoke] enter world=", d.get("world_id"), " pos=",
				d.get("x"), ",", d.get("y"), " alt=", d.get("alt"))
		4516:
			if not _entered:
				_entered = true
				print("[smoke] instance ready — world shown")
				_move_and_shoot()
		6006:
			var d := Codec.decode(op, payload)
			print("[smoke] roster:", d.fighters.map(func(f): return "%s breed=%d spells=%d cards=%d" % [
				f.get("name", "?"), int(f.get("breed", 0)),
				f.get("spells", []).size(), f.get("cards", []).size()]))
		6030:
			var d := Codec.decode(op, payload)
			print("[smoke] presets:", d.presets.map(func(p): return "type=%d '%s' f=%d c=%d" % [
				int(p.type), p.name, p.fighters.size(), p.coaches.size()]))
		4096:
			var d := Codec.decode(op, payload)
			var body := WireReader.new(d.get("actors_raw", PackedByteArray()))
			var n := body.get_i32()
			print("[smoke] actor spawn n=", n)


func _move_and_shoot() -> void:
	await create_timer(2.0).timeout
	var w = _main.get_node("World")
	if w._pos.has(State.my_coach_id):
		var p: Vector3i = w._pos[State.my_coach_id]
		w.click_to(Vector2i(p.x + 4, p.y + 2))
		print("[smoke] scripted world move -> ", p.x + 4, ",", p.y + 2)
	await create_timer(3.0).timeout
	var tex := root.get_texture()
	var img = tex.get_image() if tex != null else null
	if img != null:
		img.save_png("/tmp/world_live.png")
		print("[smoke] shot -> /tmp/world_live.png")
	quit()
