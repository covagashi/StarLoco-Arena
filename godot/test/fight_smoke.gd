extends SceneTree

## Fight-entry smoke: login, launch overworld challenge 34 (single-client
## fight), decode 8000 into State, then instantiate fight_view — which
## consumes State.net.message_received itself: 4102 placements, phase
## acks (8011/8023), everything after.
##   godot --headless --path godot -s test/fight_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

var client: ArenaClient
var finished := false
var fight_scene: Node2D = null
var _combat_seen := false


func _init() -> void:
	client = ArenaClient.new()
	root.add_child(client)
	# NOTE: the Session autoload still gets instantiated under -s (only the
	# global identifier fails to resolve) and its _ready overwrites State.net
	# with its own idle client — so we re-assign before opening fight_view.
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(_finish.bind(1, "disconnected"))
	print("[smoke] connecting 127.0.0.1:5555")
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(55.0).timeout.connect(_finish.bind(1, "timeout"))


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
	# fight_view._ready drains client.pending itself, then hooks
	# message_received — same path the real scene-change flow takes.
	State.net = client
	# We're root.add_child-ing, not change_scene_to_file — the previous
	# instance survives a "scene change", so drop it ourselves (remove_child
	# fires _exit_tree synchronously → its net subscription is released).
	if fight_scene != null:
		root.remove_child(fight_scene)
		fight_scene.queue_free()
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	# Scripted policy: on our turns try a short move (exercises the real
	# 4503 path + 4524 walk animation), then end the turn.
	fight_scene.turn_began.connect(_on_fight_turn)
	fight_scene.placement_began.connect(_on_placement)
	root.add_child(fight_scene)
	# Capture mid-combat: first turn means actors placed + phases done.
	_combat_seen = false
	var deadline := 0.0
	while not _combat_seen and deadline < 12.0:
		await create_timer(0.25).timeout
		deadline += 0.25
	await create_timer(1.5).timeout   # let a couple of turns land
	var img := root.get_texture().get_image() if root.get_texture() != null else null
	if img != null:
		img.save_png("/tmp/fight_live.png")
		print("[smoke] combat shot -> /tmp/fight_live.png %dx%d"
			% [img.get_width(), img.get_height()])
	await create_timer(14.0).timeout # surrender fires inside; loop or finish
	_finish(0, "fight rendered")


## placement_began policy: hop the selected fighter to another of our own
## start cells (exercises 8021 -> 8022), then confirm ready (8023).
func _on_placement() -> void:
	if finished or fight_scene == null:
		return
	await create_timer(0.4).timeout
	if finished or fight_scene == null:
		return
	var t: int = fight_scene._my_team()
	var cur: Vector3i = fight_scene._actor_cells.get(
		fight_scene._selected, Vector3i.ZERO)
	for c in fight_scene._fmd.get("team%d" % t, []):
		var cell := Vector2i(int(c.x), int(c.y))
		if cur.x == cell.x and cur.y == cell.y:
			continue
		if fight_scene.request_place_at(cell):
			print("[smoke] scripted placement -> %s" % cell)
			break
	create_timer(0.6).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.confirm_placement())


## turn_began policy for the harness: one short move request, then pass.
func _on_fight_turn(fid: int, ours: bool) -> void:
	if not ours or finished:
		return
	var cur: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
	var moved := false
	for d in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0), Vector2i(0, -2),
			Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		if fight_scene.request_move_to(Vector2i(cur.x, cur.y) + d):
			print("[smoke] scripted move fid=%d -> %s" % [fid, Vector2i(cur.x, cur.y) + d])
			moved = true
			break
	if not moved:
		print("[smoke] no move target for fid=%d at %s" % [fid, cur])
	# exercise the cast path too: first known spell at the closest enemy
	# cell, else the weapon attack (8111). Server validates range/LoS —
	# silence means refused, which is fine for the harness.
	var f: Dictionary = State.fighters.get(fid, {})
	var spells: Array = f.get("spells", [])
	if true:
		var best := Vector2i.ZERO
		var best_d := 1 << 30
		for id in fight_scene._actor_cells:
			var e: Dictionary = State.fighters.get(id, {})
			if e.is_empty() or int(e.get("coach", -1)) == State.my_coach_id:
				continue
			var p: Vector3i = fight_scene._actor_cells[id]
			var dd := absi(p.x - cur.x) + absi(p.y - cur.y)
			if dd < best_d:
				best_d = dd
				best = Vector2i(p.x, p.y)
		if best_d < 1 << 30:
			var sid: int = int(spells[0]) if not spells.is_empty() else -2
			if fight_scene.request_cast_at(sid, best):
				print("[smoke] scripted cast %s -> %s" % [
					"spell %d" % sid if sid >= 0 else "weapon", best])
	# give the 4524 broadcast a beat to land, then pass the turn
	create_timer(1.0).timeout.connect(func():
		if fight_scene != null and not finished:
			fight_scene.request_end_turn())


func _on_message(opcode: int, payload) -> void:
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	match opcode:
		1024:
			if decoded.get("result") == 0:
				print("[smoke] 1024 auth OK")
			else:
				_finish(1, "auth refused %s" % decoded.get("result"))
		2048:
			_send_coach("fightone")
		2052:
			State.my_coach_id = int(decoded.get("id", -1))
			print("[smoke] coach id=%s name='%s'" % [
				decoded.get("id"), decoded.get("name")])
		4600:
			State.current_world = int(decoded.get("world_id", -1))
			print("[smoke] enter instance world=%s pos=(%s,%s)" % [
				State.current_world, decoded.get("x"), decoded.get("y")])
			# Post-fight return: world != arena → drop the fight view (the
			# scene also self-transitions via change_scene_to_file, which only
			# frees the tracked current_scene — none under -s).
			if fight_scene != null and State.current_world != State.fight_world:
				root.remove_child(fight_scene)
				fight_scene.queue_free()
				fight_scene = null
				# Late combat ops (8104s still in flight at 8300) sit in
				# pending — flush so the NEXT fight's _ready doesn't drain
				# stale turn_begins and fire bogus scripted moves.
				client.drain()
		4516:
			_launch_challenge()
		8000:
			var raw: PackedByteArray = payload
			print("[smoke] FIGHT CREATION — %d bytes" % raw.size())
			var fh := FileAccess.open("/tmp/fight8000.bin", FileAccess.WRITE)
			fh.store_buffer(raw)
			fh.close()
			State.fight_world = State.current_world
			State.fight_data = decoded
			State.index_fighters(decoded)
			for t in decoded.get("teams", []):
				for f in t.get("fighters", []):
					print("[smoke]   fighter '%s' breed=%d team=%d id=%d"
						% [f.name, f.get("breed", -1), t.id, f.id])
			_show_fight()
		4102:
			print("[smoke] ACTOR_APPEAR: %s" % str(decoded.get("actors", [])))
		8040:
			_combat_seen = true
			print("[smoke] COMBAT STARTED — surrender at +8s")
			create_timer(8.0).timeout.connect(func():
				client.send_message(8151, PackedByteArray(), 3))
		8300:
			print("[smoke] END FIGHT (8300)")
		8100, 8104, 8106:
			print("[smoke]   op %d raw=%dB hex=%s" % [
				opcode, payload.size(), payload.hex_encode()])
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
