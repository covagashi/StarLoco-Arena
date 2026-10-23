extends SceneTree

## Reel director, part 1 (S11): stage an AI-vs-AI fight and record it.
##
## Logs in as an admin coach, optionally pins the arena (/ARENA), launches an
## overworld challenge, places, and once combat starts hands its own fighters
## to the server AI (/AUTOPILOT on). Both sides then really fight; the
## ReplayRecorder writes the take to --out when the 8300 lands.
##
##   godot --headless --path godot -s tools/reel/record.gd -- \
##       [--out=user://reels] [--challenge=34] [--arena=N] [--login=test]
##       [--password=test123] [--coach=fightone] [--host=127.0.0.1:5555]
## Needs the local server; the account must be admin for the GM commands.
## Prints "[reel] saved <path>" and exits 0, or exits 1.

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const State := preload("res://src/state.gd")
const ReplayRecorder := preload("res://src/net/replay_recorder.gd")

var client: ArenaClient
var recorder: ReplayRecorder
var fight_scene: Node = null
var opts := {"out": "user://reels", "challenge": "34", "arena": "",
	"login": "test", "password": "test123", "coach": "fightone",
	"host": "127.0.0.1:5555"}
var _launched := false
var _autopilot := false
var _done := false


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			opts[a.substr(2, a.find("=") - 2)] = a.substr(a.find("=") + 1)
	client = ArenaClient.new()
	root.add_child(client)
	recorder = ReplayRecorder.new()
	recorder.dir = str(opts.out)
	recorder.settings_path = "user://reel_none.cfg"   # always record
	root.add_child(recorder)
	recorder.attach(client)
	recorder.saved.connect(func(p):
		print("[reel] saved %s" % ProjectSettings.globalize_path(p))
		_finish(0))
	client.connected.connect(_login)
	client.message_received.connect(_on_message)
	var hp: PackedStringArray = str(opts.host).split(":")
	if client.connect_to(hp[0], int(hp[1])) != OK:
		_finish(1, "connect failed")
		return
	create_timer(600.0).timeout.connect(_finish.bind(1, "timeout"))


func _login() -> void:
	var version := WireWriter.new()
	version.put_u8(0x02)
	version.put_u16(70)
	version.put_u8(5)
	version.put_bytes("72909".to_ascii_buffer())
	client.send_message(7, version.raw(), 0)
	var auth := WireWriter.new()
	var l := CP1252.encode(str(opts.login))
	var p := CP1252.encode(str(opts.password))
	auth.put_u8(l.size())
	auth.put_bytes(l)
	auth.put_u8(p.size())
	auth.put_bytes(p)
	client.send_message(1025, auth.raw(), 1)


func _chat(line: String) -> void:
	var b := line.to_ascii_buffer()
	var w := WireWriter.new()
	w.put_u16(b.size())
	w.put_bytes(b)
	client.send_message(3153, w.raw(), 3)


func _on_message(opcode: int, payload: PackedByteArray) -> void:
	match opcode:
		1024:
			if Codec.decode(opcode, WireReader.new(payload)).get("result") != 0:
				_finish(1, "auth refused")
		2048:
			var n := CP1252.encode(str(opts.coach))
			var w := WireWriter.new()
			w.put_u8(n.size())
			w.put_bytes(n)
			client.send_message(2049, w.raw(), 2)
		2052:
			var d := Codec.decode(opcode, WireReader.new(payload))
			State.my_coach_id = int(d.get("id", -1))
			State.my_coach_name = str(d.get("name", opts.coach))
		4600:
			State.current_world = int(Codec.decode(opcode, WireReader.new(payload)).get("world_id", -1))
		4516:
			if not _launched:
				_launched = true
				if str(opts.arena) != "":
					_chat("/ARENA %s" % opts.arena)
				var w := WireWriter.new()
				w.put_i32(int(opts.challenge))
				w.put_u16(99)
				client.send_message(26330, w.raw(), 2)
		8000:
			State.fight_world = State.current_world
			State.fight_data = Codec.decode(opcode, WireReader.new(payload))
			State.index_fighters(State.fight_data)
			State.net = client
			fight_scene = load("res://src/fight/fight_view.tscn").instantiate()
			fight_scene.placement_began.connect(func():
				create_timer(1.0).timeout.connect(func():
					if is_instance_valid(fight_scene):
						fight_scene.confirm_placement()))
			root.add_child(fight_scene)
		8040:
			if not _autopilot:
				_autopilot = true
				_chat("/AUTOPILOT on")
		26310:
			_finish(1, "challenge refused")


func _finish(code: int, msg := "") -> void:
	if _done:
		return
	_done = true
	if msg != "":
		print("[reel] %s" % msg)
	quit(code)
