extends Node

## Records the fight this client takes part in — or watches — into a replay
## (S11, replay_file.gd). Hooked to the live ArenaClient by the Session
## autoload: it sees every S2C frame, starts on FightCreation (8000), stops on
## EndFight (8300) or a dropped connection, and writes user://replays/.
##
## Retail's "save replays" option (gamePreferences.saveReplays, Options →
## Fight) turns it off; it defaults to on, as in the retail.

const ReplayFile := preload("res://src/net/replay_file.gd")
const Codec := preload("res://src/net/codec.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

const OP_FIGHT_CREATION := 8000
const OP_END_FIGHT := 8300

## Chat that isn't the fight's own: whispers, channels, trade, group, guild,
## "user not found" and the 3206-3216 notices. A replay is meant to be shown
## around; the vicinity chat (3152) and server notices stay.
const PRIVATE_OPS := [3154, 3140, 3168, 3170, 3198, 3204, 3206, 3210, 3212,
	3214, 3216]

## Emitted with the file path once a replay is written.
signal saved(path: String)

var dir := ReplayFile.DIR
var keep := ReplayFile.KEEP
## Settings file the GUI layer saves gamePreferences into; tests point it
## elsewhere.
var settings_path := "user://gui_settings.cfg"

var _frames: Array = []
var _start_ms := 0
var _start_unix := 0
var _header := {}
var recording := false


func attach(client: Node) -> void:
	client.message_received.connect(on_frame)
	client.disconnected.connect(stop.bind(false))


func enabled() -> bool:
	var c := ConfigFile.new()
	if c.load(settings_path) != OK:
		return true
	return bool(c.get_value("prefs", "saveReplays", true))


func on_frame(opcode: int, raw: PackedByteArray) -> void:
	if opcode == OP_FIGHT_CREATION:
		# a second 8000 without an 8300 (a resumed fight) restarts the take
		if recording:
			stop(false)
		if not enabled():
			return
		_begin(raw)
	if not recording:
		return
	if opcode in PRIVATE_OPS:
		return
	_frames.append({"t": Time.get_ticks_msec() - _start_ms, "op": opcode,
		"raw": raw.duplicate()})
	if opcode == OP_END_FIGHT:
		var res: Dictionary = Codec.decode(opcode, WireReader.new(raw))
		_header["winners"] = res.get("win_str", {}).keys()
		_header["result"] = "none" if _header.spectating \
			else ("win" if res.get("win_str", {}).has(int(_header.coach_id)) else "loss")
		stop(true)


func _begin(raw: PackedByteArray) -> void:
	recording = true
	_frames = []
	_start_ms = Time.get_ticks_msec()
	_start_unix = int(Time.get_unix_time_from_system())
	var d: Dictionary = Codec.decode(OP_FIGHT_CREATION, WireReader.new(raw)) \
		if raw.size() > 0 else {}
	var sides := _sides(d)
	_header = {
		"version": ReplayFile.VERSION,
		"recorded_at": _start_unix,
		"coach_id": State.my_coach_id,
		"coach_name": State.my_coach_name,
		"spectating": State.spectating,
		# 8000 follows the fight's own 4600, so this is the arena
		"world": State.current_world,
		"fight_type": int(d.get("fight_type", 0)),
		"fight_id": int(d.get("fight_id", 0)),
		"left": sides[0],
		"right": sides[1],
		"result": "none",
		"complete": false,
	}


## [left names, right names]: our side first, else team order.
func _sides(d: Dictionary) -> Array:
	var coach_names := {}
	for c in d.get("coaches", []):
		coach_names[int(c.id)] = str(c.name)
	var teams: Array = d.get("teams", [])
	var by_team := []
	var mine := -1
	for i in teams.size():
		var names := []
		for f in teams[i].get("fighters", []):
			var cid := int(f.get("coach", -1))
			if cid == State.my_coach_id and not State.spectating:
				mine = i
			var n: String = coach_names.get(cid, "")
			if n != "" and n not in names:
				names.append(n)
		if names.is_empty():
			names.append(str(teams[i].get("name", "?")))
		by_team.append(" & ".join(names))
	while by_team.size() < 2:
		by_team.append("?")
	if mine == 1:
		return [by_team[1], by_team[0]]
	return [by_team[0], by_team[1]]


## Write what was recorded. `complete` = the fight reached its 8300.
func stop(complete: bool) -> void:
	if not recording:
		return
	recording = false
	if _frames.size() < 2:
		_frames = []
		return
	_header["complete"] = complete
	_header["duration_ms"] = int(_frames[-1].t)
	_header["frames"] = _frames.size()
	var path := dir.path_join(ReplayFile.file_name(_start_unix,
		str(_header.left), str(_header.right)))
	if FileAccess.file_exists(path):
		path = path.get_basename() + "_%d.%s" % [_start_ms, ReplayFile.EXT]
	var err := ReplayFile.write(path, _header, _frames)
	_frames = []
	if err != OK:
		push_warning("replay: write failed (%d) %s" % [err, path])
		return
	ReplayFile.prune(dir, keep)
	saved.emit(path)
