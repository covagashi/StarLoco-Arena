extends SceneTree

## Special-cell smoke (S08): a special tile must FIRE live, not only on paper.
##   The manual (§5.0.4): walking over a special cell does nothing; a fighter
##   must START its turn on it. Arena 12 (pinned with /ARENA) has a Panacea
##   (template 1006, +heal) at (11,4), next to four team-0 spawns.
##   6001 one fighter, 6021 a preset, 26330 practice on arena 12;
##   placement on (10,4); turn 1 walks onto (11,4); turn 2 starts there →
##   the server must send 6200 (EFFECT_AREA_ACTION, entering, tpl 1006, our
##   fighter) and the 8120 heal boost (action 78) on our fighter.
##   Then surrender + delete the preset and the fighter.
##   godot --headless --path godot -s test/special_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

const ARENA := 12
const SPECIAL := Vector2i(11, 4)
const SPECIAL_TPL := 1006          # Panacea
const SPAWN := Vector2i(10, 4)
const HEAL_BOOST := 78             # runEffectHealBoost
const TEAM_TEST_TYPE := 12
var TEAM_NAME := "zzspecial%d" % (Time.get_unix_time_from_system() as int % 100000)
var FIGHTER_NAME := "zzspc%d" % (Time.get_unix_time_from_system() as int % 100000)

var client: ArenaClient
var _sweep: RefCounted
var finished := false
var fight_scene: Node2D = null
var _created_fid := -1
var _preset_id := -1
var _our_wire := -1
var _turns := 0
var _area_fired := false
var _boost_seen := false
var _combat_seen := false


func _init() -> void:
	client = ArenaClient.new()
	_sweep = load("res://test/smoke_sweep.gd").new(client, _create_fighter)
	root.add_child(client)
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	client.disconnected.connect(func(): _finish(1, "disconnected"))
	print("[smoke] connecting 127.0.0.1:5555")
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(120.0).timeout.connect(_finish.bind(1, "timeout"))


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


func _create_fighter() -> void:
	var blob := Overrides.encode_fighter_blob(8, FIGHTER_NAME, 0, [])
	var w := WireWriter.new()
	w.put_u8(0)
	w.put_u16(0)
	w.put_u16(blob.size())
	w.put_bytes(blob)
	client.send_message(6001, w.raw(), 2)


func _save_preset() -> void:
	var w := WireWriter.new()
	w.put_i16(0)
	w.put_i16(0)
	w.put_i16(1)
	var nb := CP1252.encode(TEAM_NAME)
	w.put_u8(nb.size())
	w.put_bytes(nb)
	w.put_u8(1)
	w.put_i64(_created_fid)
	w.put_i64(State.my_coach_id)
	w.put_u8(0)
	w.put_u8(0)
	client.send_message(6021, w.raw(), 2)


func _launch_practice() -> void:
	var w := WireWriter.new()
	w.put_i32(TEAM_TEST_TYPE)
	w.put_u16(_preset_id)
	client.send_message(26330, w.raw(), 2)
	print("[smoke] practice launch sent (team %d, arena %d)" % [_preset_id, ARENA])


func _show_fight() -> void:
	State.net = client
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	fight_scene.turn_began.connect(_on_fight_turn)
	fight_scene.placement_began.connect(_on_placement)
	root.add_child(fight_scene)
	var t := 0.0
	while not (_area_fired and _boost_seen) and t < 70.0:
		await create_timer(0.5).timeout
		t += 0.5
	print("[smoke] SPECIAL fired=%s heal_boost=%s turns=%d" % [_area_fired, _boost_seen, _turns])
	client.send_message(8151, PackedByteArray(), 3)


func _on_placement() -> void:
	create_timer(0.5).timeout.connect(func():
		if fight_scene == null or finished:
			return
		for fid in State.fighters:
			if int(State.fighters[fid].get("coach", -1)) == State.my_coach_id:
				_our_wire = int(fid)
		fight_scene._selected = _our_wire
		var ok: bool = fight_scene.request_place_at(SPAWN)
		print("[smoke] place %d -> %s ok=%s" % [_our_wire, SPAWN, ok])
		create_timer(0.6).timeout.connect(func():
			if fight_scene != null and not finished:
				fight_scene.confirm_placement()))


func _on_fight_turn(fid: int, ours: bool) -> void:
	if finished or fight_scene == null or not ours:
		return
	_turns += 1
	await create_timer(0.6).timeout
	if finished or fight_scene == null:
		return
	var cur: Vector3i = fight_scene._actor_cells.get(fid, Vector3i.ZERO)
	print("[smoke] our turn %d at (%d,%d)" % [_turns, cur.x, cur.y])
	if Vector2i(cur.x, cur.y) != SPECIAL:
		if fight_scene.request_move_to(SPECIAL):
			create_timer(2.0).timeout.connect(func():
				if fight_scene != null and not finished:
					fight_scene.request_end_turn())
			return
	fight_scene.request_end_turn()


func _on_message(opcode: int, payload) -> void:
	var decoded := Codec.decode(opcode, WireReader.new(payload))
	if _sweep.feed(opcode, decoded):
		return
	match opcode:
		1024:
			if decoded.get("result") != 0:
				_finish(1, "auth refused")
		2048:
			var n := CP1252.encode("test")
			var w := WireWriter.new()
			w.put_u8(n.size())
			w.put_bytes(n)
			client.send_message(2049, w.raw(), 2)
		2052:
			State.my_coach_id = int(decoded.get("id", -1))
		4600:
			State.current_world = int(decoded.get("world_id", -1))
		4516:
			_sweep.start(ARENA)
		6000:
			if int(decoded.get("result", 1)) != 0:
				_finish(1, "fighter create refused %s" % decoded.get("result"))
				return
			_created_fid = int(decoded.get("fighter_id", -1))
			_save_preset()
		6030:
			for p in decoded.get("presets", []):
				if str(p.get("name", "")) == TEAM_NAME and _preset_id < 0:
					_preset_id = int(p.get("id", -1))
					_launch_practice()
		8000:
			State.fight_world = State.current_world
			State.fight_data = decoded
			State.index_fighters(decoded)
			_show_fight()
		8040:
			_combat_seen = true
		6200:
			var r := WireReader.new(payload)
			r.get_i32()
			r.get_i32()
			var entering := r.get_u8()
			r.get_i64()
			var tpl := r.get_i64()
			var who := r.get_i64()
			print("[smoke] 6200 entering=%d tpl=%d fighter=%d" % [entering, tpl, who])
			if entering == 1 and tpl == SPECIAL_TPL and who == _our_wire:
				_area_fired = true
		8120:
			if int(decoded.get("effect_id", -1)) == HEAL_BOOST \
					and int(decoded.get("target", -1)) == _our_wire:
				_boost_seen = true
				print("[smoke] 8120 heal boost on our fighter: %s" % decoded.get("value"))
		8300:
			_cleanup()


func _cleanup() -> void:
	var w := WireWriter.new()
	w.put_i64(_preset_id)
	w.put_i16(0)
	w.put_i16(0)
	client.send_message(6023, w.raw(), 2)
	var w2 := WireWriter.new()
	w2.put_i64(_created_fid)
	w2.put_i16(0)
	client.send_message(6003, w2.raw(), 2)
	await create_timer(0.5).timeout
	_finish(0 if (_area_fired and _boost_seen) else 1, "special smoke complete")


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[smoke] %s" % msg)
	quit(code)
