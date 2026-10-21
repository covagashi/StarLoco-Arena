extends RefCounted
## SmokeSweep — clears what an interrupted smoke left on the test account
## (S08). The fighter smokes create "zz*" fighters and presets and delete them
## at the end, so a run that is cut short leaves them behind; at 100 fighters
## the server refuses to create one (code 20, "pool full") and every later
## run fails. Cleaning at the START makes each run independent of the last.
##
## Usage: on 4516, sweep.start(); feed every message to sweep.feed() and skip
## it when that returns true; `done` runs once the leftovers are deleted.

const WireWriter := preload("res://src/net/wire_writer.gd")
const PREFIX := "zz"

var _client
var _done: Callable
var _active := false
var _fighters: Array = []


func _init(client, done: Callable) -> void:
	_client = client
	_done = done


## 6031 answers with the roster (6006) then the presets (6030).
func start() -> void:
	_active = true
	_client.send_message(6031, PackedByteArray(), 2)


func feed(opcode: int, decoded: Dictionary) -> bool:
	if not _active:
		return false
	match opcode:
		6006:
			_fighters = []
			for f in decoded.get("fighters", []):
				if str(f.get("name", "")).begins_with(PREFIX):
					_fighters.append(int(f.get("id", -1)))
			return true
		6030:
			_active = false
			var presets := 0
			for p in decoded.get("presets", []):
				if str(p.get("name", "")).begins_with(PREFIX):
					var w := WireWriter.new()   # presets first: they hold the fighters
					w.put_i64(int(p.get("id", -1)))
					w.put_i16(0)
					w.put_i16(0)
					_client.send_message(6023, w.raw(), 2)
					presets += 1
			for fid in _fighters:
				var w2 := WireWriter.new()
				w2.put_i64(fid)
				w2.put_i16(0)
				_client.send_message(6003, w2.raw(), 2)
			print("[smoke] sweep: %d leftover preset(s), %d fighter(s) deleted"
				% [presets, _fighters.size()])
			_done.call()
			return true
	return false
