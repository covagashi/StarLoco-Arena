extends Node

## Plays a replay back into fight_view (S11). It stands in for the live
## ArenaClient as State.net — same signal, drain(), scene_active and
## send_message() — so the fight view paints the recorded frames exactly as it
## painted them live, with no socket and no server.
##
## Frames come out on their recorded clock, with every wait capped at MAX_GAP:
## a live fight spends up to 30 s on a turn somebody is thinking. Speed and
## pause go through Engine.time_scale, so the animations, the tweens and the
## frame clock all keep the same pace (finish() puts it back to 1).
## The clock only starts once the fight scene consumes (scene_active), so the
## versus screen is not skipped while the scene loads.
##
## Nothing goes to a server. The one send that matters is the result screen's
## 26321 ack: the live server answers it with a 4600 back to the lobby, so
## this answers it with a synthetic one.

signal message_received(opcode: int, payload: PackedByteArray)
## Every frame has been emitted.
signal finished

const WireWriter := preload("res://src/net/wire_writer.gd")

const OP_ENTER_INSTANCE := 4600
const OP_END_FIGHT_DONE := 26321
## Longest wait between two frames at ×1, in ms.
const MAX_GAP := 1500
const SPEEDS := [1.0, 2.0, 4.0]

var header := {}
var frames: Array = []
var pending: Array = []
var scene_active := false
var paused := false:
	set(v):
		paused = v
		Engine.time_scale = 0.0 if v else speed
var speed := 1.0:
	set(v):
		speed = v
		if not paused:
			Engine.time_scale = v
## Index of the next frame to emit.
var cursor := 0
var _clock := 0.0      # replay ms elapsed (compressed timeline)
var _times := PackedInt32Array()
var _done := false


## `replay` is ReplayFile.read()'s {header, frames}. The first frame (the
## 8000) is the caller's: it builds State from it before the scene change.
func load_replay(replay: Dictionary) -> void:
	header = replay.get("header", {})
	frames = replay.get("frames", [])
	_times = compressed_times(frames, MAX_GAP)
	cursor = 0
	_clock = 0.0
	_done = false


## Recorded arrival times with every gap capped at `max_gap` ms.
static func compressed_times(list: Array, max_gap: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var prev := 0
	var acc := 0
	for i in list.size():
		var t := int(list[i].t)
		if i > 0:
			acc += clampi(t - prev, 0, max_gap)
		prev = t
		out.append(acc)
	return out


## Skip the frames already handled elsewhere (the opening 8000).
func skip(n: int) -> void:
	cursor = clampi(cursor + n, 0, frames.size())
	if cursor > 0:
		_clock = float(_times[cursor - 1])


func total_ms() -> int:
	return _times[-1] if _times.size() > 0 else 0


func elapsed_ms() -> int:
	return int(_clock)


func drain() -> Array:
	var out := pending
	pending = []
	return out


func is_online() -> bool:
	return true


func send_message(opcode: int, _payload: PackedByteArray, _arch: int = 3) -> void:
	if opcode == OP_END_FIGHT_DONE:
		# the live server's answer: back to a world that isn't the arena
		var w := WireWriter.new()
		w.put_f32(0.0)
		w.put_f32(0.0)
		w.put_i16(0)
		w.put_i16(-1)
		w.put_u8(0)
		_emit.call_deferred(OP_ENTER_INSTANCE, w.raw())


func send(_opcode: int, _values: Dictionary = {}) -> void:
	pass


func cycle_speed() -> float:
	var i := SPEEDS.find(speed)
	speed = SPEEDS[(i + 1) % SPEEDS.size()]
	return speed


## Advance the replay clock by `ms` and emit what falls due. Public so tests
## (and the reel renderer) can step it deterministically.
func advance(ms: float) -> void:
	if not scene_active or paused:
		return
	_clock += ms
	while cursor < frames.size() and _times[cursor] <= _clock:
		var fr: Dictionary = frames[cursor]
		cursor += 1
		_emit(int(fr.op), fr.raw)
	if cursor >= frames.size() and not _done:
		_done = true
		finished.emit()


func _process(delta: float) -> void:
	advance(delta * 1000.0)   # delta is already time-scaled


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _emit(op: int, raw: PackedByteArray) -> void:
	if not scene_active:
		pending.append({"op": op, "raw": raw})
	message_received.emit(op, raw)
