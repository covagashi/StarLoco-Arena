extends SceneTree

## Fight-entry smoke: login, then launch overworld challenge 34
## (single-client fight — the server synthesizes the opponent side).
## On FightCreation (8000) we decode the roster into State, instantiate
## fight_view, then forward subsequent wire messages (4102 placements...)
## to it — same as the real flow via Session.
##   godot --headless --path godot -s test/fight_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

var client: ArenaClient
var finished := false
var last_world := -1
var fight_scene: Node2D = null


func _init() -> void:
	client = ArenaClient.new()
	root.add_child(client)
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(_finish.bind(1, "disconnected"))
	print("[smoke] connecting 127.0.0.1:5555")
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(20.0).timeout.connect(_finish.bind(1, "timeout"))


func _send_login() -> void:
	var version := WireWriter.new()
	version.put_u8(0x02)
	version.put_u16(70)
	version.put_u8(5)
	version.put_bytes("72909".to_ascii_buffer())
	client.send_message(7, version.raw(), 0)
	var auth := WireWriter.new()
	var l := CP1252.encode("test")
	var p := CP1252.encode("test123")
	auth.put_u8(l.size())
	auth.put_bytes(l)
	auth.put_u8(p.size())
	auth.put_bytes(p)
	client.send_message(1025, auth.raw(), 1)
	print("[smoke] sent login")


func _send_coach(coach_name: String) -> void:
	var n := CP1252.encode(coach_name)
	var w := WireWriter.new()
	w.put_u8(n.size())
	w.put_bytes(n)
	client.send_message(2049, w.raw(), 2)


func _launch_challenge() -> void:
	var w := WireWriter.new()
	w.put_i32(34)      # challenge id 34 — "Démon de la 58ème minute"
	w.put_u16(99)      # 99 = overworld challenge (not team preset)
	client.send_message(26330, w.raw(), 2)
	print("[smoke] challenge 34 sent")


func _show_fight() -> void:
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	root.add_child(fight_scene)
	await create_timer(1.5).timeout   # let 4102 placements land + frames draw
	var tex := root.get_texture()
	var img := tex.get_image() if tex != null else null
	if img != null:
		img.save_png("/tmp/fight_live.png")
		print("[smoke] screenshot -> /tmp/fight_live.png %dx%d"
			% [img.get_width(), img.get_height()])
	_finish(0, "8000 received — fight view rendered")


func _on_message(opcode: int, payload) -> void:
	# Once the fight view is up, every fight message also goes to it.
	if fight_scene != null:
		var raw: PackedByteArray = payload.buffer()
		fight_scene._on_net_message(opcode, WireReader.new(raw))
	var decoded := Codec.decode(opcode, WireReader.new(payload.buffer()))
	match opcode:
		1024:
			if decoded.get("result") == 0:
				print("[smoke] 1024 auth OK")
			else:
				_finish(1, "auth refused %s" % decoded.get("result"))
		2048:
			_send_coach("fightone")
		2052:
			print("[smoke] coach id=%s name='%s'" % [
				decoded.get("id"), decoded.get("name")])
		4600:
			last_world = int(decoded.get("world_id", -1))
			print("[smoke] enter instance world=%s pos=(%s,%s)" % [
				last_world, decoded.get("x"), decoded.get("y")])
		4516:
			_launch_challenge()
		8000:
			var raw: PackedByteArray = payload.buffer()
			print("[smoke] FIGHT CREATION — %d bytes" % raw.size())
			var fh := FileAccess.open("/tmp/fight8000.bin", FileAccess.WRITE)
			fh.store_buffer(raw)
			fh.close()
			State.fight_world = last_world
			State.fight_data = decoded
			State.index_fighters(decoded)
			for t in decoded.get("teams", []):
				for f in t.get("fighters", []):
					print("[smoke]   fighter '%s' breed=%d team=%d id=%d"
						% [f.name, f.get("breed", -1), t.id, f.id])
			_show_fight()
		4102:
			print("[smoke] ACTOR_APPEAR: %s" % str(decoded.get("actors", [])))
		26310:
			_finish(1, "challenge refused")
		_:
			print("[smoke]   op %d" % opcode)


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
