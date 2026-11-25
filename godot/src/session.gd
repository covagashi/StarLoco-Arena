extends Node

## Autoload: owns the wire connection so it survives scene changes
## (main.gd → fight_view on FightCreation). Registers the client into
## `State.net`; scenes consume `State.net.message_received` + drain().

const ArenaClient := preload("res://src/net/arena_client.gd")
const ReplayRecorder := preload("res://src/net/replay_recorder.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const State := preload("res://src/state.gd")

signal message(opcode: int, payload: PackedByteArray)
signal connected
signal disconnected

var client := ArenaClient.new()
## Saves every fight this client plays or watches (S11).
var recorder := ReplayRecorder.new()


func _ready() -> void:
	add_child(client)
	add_child(recorder)
	recorder.attach(client)
	State.net = client
	client.message_received.connect(func(op, p): message.emit(op, p))
	client.connected.connect(func(): connected.emit())
	client.disconnected.connect(_on_lost)


## S53: a socket that drops after login says so on every screen
## (src/ui/lost_connection.gd); before login the screens handle it.
func _on_lost() -> void:
	disconnected.emit()
	if State.my_coach_id > 0 and not get_tree().root.has_node("LostConnection"):
		var lost: CanvasLayer = load("res://src/ui/lost_connection.gd").new()
		lost.name = "LostConnection"
		get_tree().root.add_child.call_deferred(lost)


func connect_to(host: String, port: int) -> int:
	return client.connect_to(host, port)


func send(opcode: int, payload: PackedByteArray, arch: int = 0) -> void:
	client.send_message(opcode, payload, arch)


func is_online() -> bool:
	return client.is_online()
