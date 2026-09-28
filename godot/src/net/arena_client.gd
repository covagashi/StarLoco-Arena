extends Node

## TCP session + frame layer for the DofusArena 2.70 wire protocol.
##
## S2C frames arrive as [u16 totalLen][u16 opcode][payload]; TCP is a stream,
## so partial frames accumulate in _recv_buf until totalLen bytes are present.
## Emits one `message_received` per complete frame with the stripped payload.

const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const Codec := preload("res://src/net/codec.gd")
const Opcodes := preload("res://src/net/generated/opcodes.gd")

signal connected
signal disconnected
signal message_received(opcode: int, payload: WireReader)

const HEADER_LEN := 4

var _peer := StreamPeerTCP.new()
var _recv_buf := PackedByteArray()
var _connected := false
var _established := false


func connect_to(host: String, port: int) -> Error:
	_recv_buf.clear()
	_established = false
	var err := _peer.connect_to_host(host, port)
	if err != OK:
		return err
	_connected = true
	return OK


func disconnect_from() -> void:
	_peer.disconnect_from_host()
	_connected = false


func is_online() -> bool:
	return _connected and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED


func send_message(opcode: int, payload: PackedByteArray, arch_target: int = 3) -> void:
	_peer.put_data(WireWriter.frame(opcode, payload, arch_target))


## Encodes + sends a schema-driven C2S message. Arch comes from the generated
## ARCH table; -1 (conditional) falls back to payload[0] — the 107 ping echo —
## or 3, the dominant in-game channel.
func send(opcode: int, values: Dictionary = {}) -> void:
	var payload := Codec.encode_payload(opcode, values)
	var arch: int = Opcodes.ARCH.get(opcode, 3)
	if arch < 0:
		arch = payload[0] if payload.size() > 0 else 3
	send_message(opcode, payload, arch)


func _process(_delta: float) -> void:
	if not _connected:
		return
	_peer.poll()
	var status := _peer.get_status()
	if status == StreamPeerTCP.STATUS_CONNECTED:
		if not _established:
			_established = true
			connected.emit()
		var avail := _peer.get_available_bytes()
		if avail > 0:
			var res := _peer.get_data(avail)
			if res[0] == OK:
				_recv_buf.append_array(res[1])
			_drain_frames()
	elif status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR:
		_connected = false
		disconnected.emit()


func _drain_frames() -> void:
	while _recv_buf.size() >= HEADER_LEN:
		var total := (_recv_buf[0] << 8) | _recv_buf[1]
		if total < HEADER_LEN or _recv_buf.size() < total:
			return  # corrupt header, or full frame not yet arrived
		var opcode := (_recv_buf[2] << 8) | _recv_buf[3]
		var payload := _recv_buf.slice(HEADER_LEN, total)
		_recv_buf = _recv_buf.slice(total)
		message_received.emit(opcode, WireReader.new(payload))
