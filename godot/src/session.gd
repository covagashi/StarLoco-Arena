extends Node

## Autoload: owns the wire connection so it survives scene changes
## (main.gd → fight_view on FightCreation). Registers the client into
## `State.net`; scenes consume `State.net.message_received` + drain().

const ArenaClient := preload("res://src/net/arena_client.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const State := preload("res://src/state.gd")

signal message(opcode: int, payload: WireReader)
signal connected
signal disconnected

var client := ArenaClient.new()


func _ready() -> void:
	add_child(client)
	State.net = client
	client.message_received.connect(func(op, p): message.emit(op, p))
	client.connected.connect(func(): connected.emit())
	client.disconnected.connect(func(): disconnected.emit())


func connect_to(host: String, port: int) -> int:
	return client.connect_to(host, port)


func send(opcode: int, payload: PackedByteArray, arch: int = 0) -> void:
	client.send_message(opcode, payload, arch)


func is_online() -> bool:
	return client.is_online()
