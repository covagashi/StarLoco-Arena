extends SceneTree

## S11 replay smoke: play a real fight, record it, play the recording back
## and check the replay ends where the fight did.
##
## 1. Log in as `test`, launch challenge 34 (the 58th-minute demon), place,
##    pass our turns and surrender at table turn 7 — the AI plays its own
##    turns, so there is real damage and movement to compare.
## 2. A ReplayRecorder hooked to this client (as Session does) writes the
##    take to user://replays_smoke/ on the 8300.
## 3. That file goes through ReplayPlayer into a fresh fight_view at ×4,
##    with the transport bar, until its own 8300.
## 4. Live and replay must agree on every fighter's cell, damage taken and
##    death, the table turn, the winners, and the frames painted.
##   godot --headless --path godot -s test/replay_smoke.gd
## Needs the local server (127.0.0.1:5555); no seed: challenge 34 builds
## its own demon team, and `fightone` is the coach fight_smoke uses.

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")
const ReplayFile := preload("res://src/net/replay_file.gd")
const ReplayRecorder := preload("res://src/net/replay_recorder.gd")
const ReplayPlayer := preload("res://src/fight/replay_player.gd")

const DIR := "user://replays_smoke"
## Late enough for the demon to hit us: the comparison needs real damage.
const SURRENDER_ROUND := 7

var client: ArenaClient
var recorder: ReplayRecorder
var fight_scene: Node = null
var finished := false
var _challenged := false
var _surrendered := false
var _rounds := 0
var _live_ops := 0
var _replay_ops := 0
var _saved_path := ""
var _live := {}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for f in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR.path_join(f))
	client = ArenaClient.new()
	root.add_child(client)
	recorder = ReplayRecorder.new()
	recorder.dir = DIR
	recorder.settings_path = DIR.path_join("none.cfg")
	root.add_child(recorder)
	recorder.attach(client)
	recorder.saved.connect(func(p): _saved_path = p)
	client.connected.connect(_send_login)
	client.message_received.connect(_on_message)
	if client.connect_to("127.0.0.1", 5555) != OK:
		_finish(1, "connect failed")
		return
	create_timer(300.0).timeout.connect(_finish.bind(1, "timeout"))


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


func _on_message(opcode: int, payload: PackedByteArray) -> void:
	if finished:
		return
	if fight_scene != null and State.replay == null:
		_live_ops += 1
	match opcode:
		1024:
			if Codec.decode(opcode, WireReader.new(payload)).get("result") != 0:
				_finish(1, "auth refused")
		2048:
			var n := CP1252.encode("fightone")
			var w := WireWriter.new()
			w.put_u8(n.size())
			w.put_bytes(n)
			client.send_message(2049, w.raw(), 2)
		2052:
			State.my_coach_id = int(Codec.decode(opcode, WireReader.new(payload)).get("id", -1))
		4600:
			State.current_world = int(Codec.decode(opcode, WireReader.new(payload)).get("world_id", -1))
		4516:
			if not _challenged:
				_challenged = true
				var w := WireWriter.new()
				w.put_i32(34)
				w.put_u16(99)
				client.send_message(26330, w.raw(), 2)
		8000:
			_live_ops = 0
			State.fight_world = State.current_world
			State.fight_data = Codec.decode(opcode, WireReader.new(payload))
			State.index_fighters(State.fight_data)
			_open_live()
		8100:
			_rounds += 1
			if _rounds >= SURRENDER_ROUND and not _surrendered:
				_surrendered = true
				# let the round's AI turn land first
				create_timer(4.0).timeout.connect(func():
					client.send_message(8151, PackedByteArray(), 3))
		8300:
			create_timer(1.5).timeout.connect(_after_live)
		26310:
			_finish(1, "challenge refused")


func _open_live() -> void:
	State.net = client
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	fight_scene.placement_began.connect(func():
		create_timer(0.8).timeout.connect(func():
			if fight_scene != null and State.replay == null:
				fight_scene.confirm_placement()))
	fight_scene.turn_began.connect(func(_fid, ours):
		if ours and State.replay == null:
			create_timer(0.5).timeout.connect(func():
				if fight_scene != null and State.replay == null:
					fight_scene.request_end_turn()))
	root.add_child(fight_scene)


static func snapshot(fv: Node) -> Dictionary:
	var cells := {}
	for id in fv._actor_cells:
		cells[int(id)] = fv._actor_cells[id]
	var lost := {}
	for id in fv._hp_lost:
		lost[int(id)] = int(fv._hp_lost[id])
	var dead: Array = fv._dead.keys().map(func(k): return int(k))
	dead.sort()
	var winners: Array = State.fight_result.get("win_str", {}).keys()
	winners.sort()
	return {"cells": cells, "hp_lost": lost, "dead": dead,
		"table_turn": fv._table_turn, "over": fv._fight_over, "winners": winners}


func _after_live() -> void:
	if finished:
		return
	_live = snapshot(fight_scene)
	print("[replay] live: ops=%d %s" % [_live_ops, _live])
	if not _live.over:
		_finish(1, "FAIL live fight did not reach 8300")
		return
	if _saved_path == "":
		_finish(1, "FAIL the recorder saved nothing")
		return
	var replay := ReplayFile.read(_saved_path)
	var head: Dictionary = replay.get("header", {})
	print("[replay] saved %s frames=%d header=%s" % [_saved_path,
		replay.get("frames", []).size(), head])
	if not head.get("complete", false) or head.get("result") != "loss":
		_finish(1, "FAIL header: complete=%s result=%s (surrender = loss)" % [
			head.get("complete"), head.get("result")])
		return
	root.remove_child(fight_scene)
	fight_scene.queue_free()
	fight_scene = null
	State.fight_result = {}
	# playback, as the Replays panel does (no scene change under -s)
	var err := ReplayPlayer.play_data(self, replay, false)
	if err != "":
		_finish(1, "FAIL play: %s" % err)
		return
	var rc: Node = State.replay
	if State.net != rc or not State.spectating:
		_finish(1, "FAIL the replay did not take State.net / read-only")
		return
	rc.message_received.connect(func(_op, _raw): _replay_ops += 1)
	fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
	root.add_child(fight_scene)
	var bar: Node = fight_scene.get_node_or_null("UI/ReplayBar")
	if bar == null:
		_finish(1, "FAIL no replay bar")
		return
	rc.speed = 4.0
	var waited := 0.0
	while not fight_scene._fight_over and waited < 90.0:
		await create_timer(0.25).timeout
		waited += 0.25
	await create_timer(1.0).timeout
	var got := snapshot(fight_scene)
	print("[replay] replay: ops=%d after %.1fs real %s" % [_replay_ops, waited, got])
	var bad := []
	for k in _live:
		if str(_live[k]) != str(got[k]):
			bad.append("%s live=%s replay=%s" % [k, _live[k], got[k]])
	# the replay paints every recorded frame but the 8000 (main's, live too)
	if _replay_ops != int(head.frames) - 1:
		bad.append("frames emitted %d of %d" % [_replay_ops, int(head.frames) - 1])
	var hurt: bool = _live.hp_lost.values().any(func(v): return int(v) > 0)
	if not hurt:
		bad.append("nobody took damage — the comparison proves little")
	# leaving hands the live session back
	root.remove_child(fight_scene)
	fight_scene.queue_free()
	fight_scene = null
	if State.net != client or State.replay != null or Engine.time_scale != 1.0:
		bad.append("leaving the replay did not restore: net=%s replay=%s scale=%s" % [
			State.net == client, State.replay, Engine.time_scale])
	if not bad.is_empty():
		_finish(1, "FAIL replay differs:\n  " + "\n  ".join(bad))
		return
	_finish(0, "replay matches the live fight (%d frames, %d table turns)" % [
		int(head.frames), _live.table_turn])


func _finish(code: int, msg: String) -> void:
	if finished:
		return
	finished = true
	print("[replay] %s" % msg)
	quit(code)
