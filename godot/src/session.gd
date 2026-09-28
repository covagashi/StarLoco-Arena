extends Node

## Autoload: owns the wire connection so it survives scene changes
## (main.gd → fight_view on FightCreation). Scenes subscribe to
## `message` and filter by opcode; shared state lives in state.gd.

const ArenaClient := preload("res://src/net/arena_client.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")

signal message(opcode: int, payload: WireReader)
signal connected
signal disconnected

var client := ArenaClient.new()

## Messages received while a scene transition is in flight (e.g. ACTOR_APPEAR
## arriving before fight_view finishes _ready). Drained by the new scene.
var pending: Array = []


func _ready() -> void:
	add_child(client)
	client.message_received.connect(_relay)
	client.connected.connect(func(): connected.emit())
	client.disconnected.connect(func(): disconnected.emit())


func _relay(op: int, payload: WireReader) -> void:
	pending.append({"op": op, "raw": payload.buffer()})
	if pending.size() > 512:
		pending.pop_front()
	message.emit(op, payload)


## Take everything buffered since the last drain. Scene scripts call this in
## _ready before connecting `message`, so nothing is lost or doubled.
func drain() -> Array:
	var out := pending
	pending = []
	return out


func connect_to(host: String, port: int) -> int:
	return client.connect_to(host, port)


func send(opcode: int, payload: PackedByteArray, arch: int = 0) -> void:
	client.send_message(opcode, payload, arch)


func is_online() -> bool:
	return client.is_online()
