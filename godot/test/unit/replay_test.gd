extends RefCounted
## S11 replays: the file format round-trips (header + frames, a truncated
## tail keeps the whole frames), the recorder starts on 8000, drops private
## chat, stops on 8300 or a disconnect and honours saveReplays, the replay
## client caps dead time and answers the result ack with a 4600, and the
## folder keeps only the newest KEEP.

const ReplayFile := preload("res://src/net/replay_file.gd")
const ReplayRecorder := preload("res://src/net/replay_recorder.gd")
const ReplayClient := preload("res://src/net/replay_client.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const State := preload("res://src/state.gd")

const DIR := "user://test_replays"


func run(t) -> void:
	t.suite("replay")
	_clean()
	_file(t)
	_truncated(t)
	_recorder(t)
	_client(t)
	_prune(t)
	_clean()


func _file(t) -> void:
	var path := DIR.path_join("a.slr")
	var frames := [
		{"t": 0, "op": 8000, "raw": PackedByteArray([1, 2, 3])},
		{"t": 70000, "op": 4102, "raw": PackedByteArray()},
		{"t": 70001, "op": 8300, "raw": PackedByteArray([255, 0, 128])},
	]
	t.eq(ReplayFile.write(path, {"recorded_at": 5, "left": "Á b"}, frames), OK, "write")
	var r := ReplayFile.read(path)
	t.eq(r.get("header", {}).get("left", ""), "Á b", "header utf8 survives")
	t.eq(r.get("frames", []).size(), 3, "three frames back")
	if r.get("frames", []).size() == 3:
		t.eq(int(r.frames[1].t), 70000, "time > u16 survives")
		t.eq(int(r.frames[2].op), 8300, "opcode survives")
		t.eq(r.frames[2].raw, PackedByteArray([255, 0, 128]), "payload bytes survive")
		t.eq(r.frames[1].raw.size(), 0, "empty payload survives")
	t.eq(ReplayFile.read_header(path).get("recorded_at", 0), 5, "header-only read")
	t.eq(ReplayFile.file_name(0, "Lo ov", "Spar/ring"), "7001010000_Loov_VS_Sparring.slr",
		"retail-style name, unsafe chars dropped")


## A crash mid-write leaves a short tail: the whole frames still read.
func _truncated(t) -> void:
	var path := DIR.path_join("cut.slr")
	var f := FileAccess.open_compressed(path, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	f.big_endian = true
	f.store_buffer("SLRP".to_ascii_buffer())
	f.store_8(1)
	var head := JSON.stringify({"x": 1}).to_utf8_buffer()
	f.store_32(head.size())
	f.store_buffer(head)
	f.store_32(10); f.store_16(8000); f.store_32(2); f.store_buffer(PackedByteArray([7, 7]))
	f.store_32(20); f.store_16(4102); f.store_32(50); f.store_buffer(PackedByteArray([1]))
	f.close()
	var r := ReplayFile.read(path)
	t.eq(r.get("frames", []).size(), 1, "truncated tail: the whole frame only")
	t.eq(ReplayFile.read(DIR.path_join("missing.slr")), {}, "missing file → {}")


func _fight_creation() -> PackedByteArray:
	# just enough of an 8000 for the codec: the recorder only reads names
	return PackedByteArray()


func _recorder(t) -> void:
	var rec := ReplayRecorder.new()
	rec.dir = DIR.path_join("rec")
	rec.settings_path = DIR.path_join("prefs.cfg")
	var saved := []
	rec.saved.connect(func(p): saved.append(p))
	State.my_coach_id = 7
	State.spectating = false
	rec.on_frame(4600, PackedByteArray([1]))
	t.ok(not rec.recording, "nothing before 8000")
	rec.on_frame(8000, _fight_creation())
	t.ok(rec.recording, "8000 starts the take")
	rec.on_frame(3154, PackedByteArray([9]))     # a whisper
	rec.on_frame(3152, PackedByteArray([1]))     # fight chat
	rec.on_frame(8300, _end_fight(7))
	t.ok(not rec.recording, "8300 stops it")
	t.eq(saved.size(), 1, "one replay saved")
	if saved.size() == 1:
		var r := ReplayFile.read(saved[0])
		var ops: Array = r.frames.map(func(fr): return int(fr.op))
		t.eq(ops, [8000, 3152, 8300], "whisper dropped, fight chat kept")
		t.eq(r.header.get("result"), "win", "our coach in win_str → win")
		t.ok(bool(r.header.get("complete")), "complete")
	# a dropped connection keeps the partial fight
	rec.on_frame(8000, _fight_creation())
	rec.on_frame(4102, PackedByteArray([1]))
	rec.stop(false)
	t.eq(saved.size(), 2, "disconnect saves the partial fight")
	if saved.size() == 2:
		var h := ReplayFile.read_header(saved[1])
		t.ok(not bool(h.get("complete", true)), "partial is marked incomplete")
		t.eq(h.get("result"), "none", "no result without 8300")
	# saveReplays off
	var c := ConfigFile.new()
	c.set_value("prefs", "saveReplays", false)
	c.save(rec.settings_path)
	rec.on_frame(8000, _fight_creation())
	t.ok(not rec.recording, "saveReplays=false records nothing")
	rec.free()
	State.my_coach_id = -1


func _end_fight(winner: int) -> PackedByteArray:
	var w := WireWriter.new()
	w.put_i32(1); w.put_i32(-1); w.put_u8(0)
	w.put_i32(1); w.put_i64(winner); w.put_i32(10)
	w.put_i32(0)
	w.put_u8(0); w.put_u8(0)
	w.put_u16(1); w.put_u8(0)
	w.put_u16(1); w.put_u8(0)
	w.put_u8(0)
	w.put_u8(0); w.put_u8(0); w.put_i32(0)
	return w.raw()


func _client(t) -> void:
	var frames := [
		{"t": 0, "op": 8000, "raw": PackedByteArray()},
		{"t": 100, "op": 1, "raw": PackedByteArray()},
		{"t": 30100, "op": 2, "raw": PackedByteArray()},   # 30 s thinking
		{"t": 30200, "op": 3, "raw": PackedByteArray()},
	]
	t.eq(ReplayClient.compressed_times(frames, 1500), PackedInt32Array([0, 100, 1600, 1700]),
		"waits capped at MAX_GAP")
	var rc := ReplayClient.new()
	rc.load_replay({"header": {}, "frames": frames})
	rc.skip(1)
	var got := []
	rc.message_received.connect(func(op, _raw): got.append(op))
	rc.advance(5000)
	t.eq(got, [], "clock waits for the scene")
	rc.scene_active = true
	rc.advance(100)
	t.eq(got, [1], "frame due at 100 ms")
	rc.advance(1499)
	t.eq(got, [1], "not yet at 1599 ms")
	rc.advance(1)
	t.eq(got, [1, 2], "the capped frame at 1600 ms")
	rc.paused = true
	rc.advance(10000)
	t.eq(got, [1, 2], "paused holds")
	rc.paused = false
	t.eq(Engine.time_scale, 1.0, "unpause restores the time scale")
	rc.advance(100)
	t.eq(got, [1, 2, 3], "last frame")
	t.eq(rc.total_ms(), 1700, "total length")
	rc.cycle_speed()
	t.eq(Engine.time_scale, 2.0, "×2 speeds the engine")
	rc.speed = 1.0
	# the result-screen ack gets the lobby 4600 back (deferred)
	rc.send_message(26321, PackedByteArray())
	rc._emit(4600, PackedByteArray())   # what the deferred call does
	t.eq(got[-1], 4600, "26321 → synthetic 4600")
	rc.free()
	Engine.time_scale = 1.0


func _prune(t) -> void:
	var d := DIR.path_join("prune")
	for i in 5:
		ReplayFile.write(d.path_join("%d.slr" % i), {"recorded_at": i}, [])
	ReplayFile.prune(d, 3)
	var left: Array = ReplayFile.list(d).map(func(r): return int(r.header.recorded_at))
	t.eq(left, [4, 3, 2], "prune keeps the newest")


func _clean() -> void:
	_rm(ProjectSettings.globalize_path(DIR))


func _rm(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for sub in d.get_directories():
		_rm(path.path_join(sub))
	for f in d.get_files():
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
