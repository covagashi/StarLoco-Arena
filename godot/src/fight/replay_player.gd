extends RefCounted

## Starts and ends a replay (S11): swaps a ReplayClient in as State.net, builds
## the fight State from the recorded 8000 the way main.gd does live, opens
## fight_view, and puts everything back when the fight view leaves.
##
## The live session stays connected underneath: its frames keep buffering in
## Session.client.pending (main.gd drains them when the lobby comes back).

const ReplayFile := preload("res://src/net/replay_file.gd")
const ReplayClient := preload("res://src/net/replay_client.gd")
const Codec := preload("res://src/net/codec.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")

const OP_FIGHT_CREATION := 8000
const FIGHT_SCENE := "res://src/fight/fight_view.tscn"

## State the replay overwrites, restored by finish().
static var _saved := {}


## Load `path` and enter the fight view on it. Returns "" or an error key.
static func play(tree: SceneTree, path: String, open_scene := true) -> String:
	var replay := ReplayFile.read(path)
	return play_data(tree, replay, open_scene)


static func play_data(tree: SceneTree, replay: Dictionary, open_scene := true) -> String:
	var frames: Array = replay.get("frames", [])
	if frames.is_empty() or int(frames[0].op) != OP_FIGHT_CREATION:
		return "replay.err_file"
	if State.replay != null:
		finish()
	var head: Dictionary = replay.header
	_saved = {
		"net": State.net, "spectating": State.spectating,
		"fight_world": State.fight_world, "fight_data": State.fight_data,
		"fighters": State.fighters, "coach_ids": State.coach_ids,
		"fight_result": State.fight_result, "my_coach_id": State.my_coach_id,
		"my_coach_name": State.my_coach_name,
	}
	var rc := ReplayClient.new()
	rc.name = "ReplayClient"
	rc.load_replay(replay)
	rc.skip(1)
	tree.root.add_child(rc)
	State.replay = rc
	State.net = rc
	# read-only, as a spectator; the result title stays the recorder's
	State.spectating = true
	State.my_coach_id = int(head.get("coach_id", State.my_coach_id))
	State.my_coach_name = str(head.get("coach_name", State.my_coach_name))
	State.fight_world = int(head.get("world", -1))
	State.fight_data = Codec.decode(OP_FIGHT_CREATION, WireReader.new(frames[0].raw))
	State.index_fighters(State.fight_data)
	State.fight_result = {}
	if open_scene:
		tree.change_scene_to_file(FIGHT_SCENE)
	return ""


## Put the live session back. Called by fight_view when it leaves the tree.
static func finish() -> void:
	if State.replay == null:
		return
	var rc: Node = State.replay
	State.replay = null
	for k in _saved:
		match k:
			"net": State.net = _saved.net
			"spectating": State.spectating = _saved.spectating
			"fight_world": State.fight_world = _saved.fight_world
			"fight_data": State.fight_data = _saved.fight_data
			"fighters": State.fighters = _saved.fighters
			"coach_ids": State.coach_ids = _saved.coach_ids
			"fight_result": State.fight_result = _saved.fight_result
			"my_coach_id": State.my_coach_id = _saved.my_coach_id
			"my_coach_name": State.my_coach_name = _saved.my_coach_name
	_saved = {}
	Engine.time_scale = 1.0   # the ReplayClient's speed, now, not on its free
	if is_instance_valid(rc):
		rc.queue_free()
