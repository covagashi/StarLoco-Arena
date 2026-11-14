extends Node

## TCP session + frame layer for the DofusArena 2.70 wire protocol.
##
## S2C frames arrive as [u16 totalLen][u16 opcode][payload]; TCP is a stream,
## so partial frames accumulate in _recv_buf until totalLen bytes are present.
## Emits one `message_received` per complete frame with the stripped payload.
##
## S44: in the browser (no TCP there) the same bytes ride a WebSocket — the
## server's ws_addr, wss:// behind its TLS proxy; each binary message is a run
## of the stream, so the frame layer above is the same. A host given as a full
## URL ("wss://…/") is used as is; otherwise the web build opens
## ws://host:port. `--ws-url=<url>` on the command line forces WebSocket on
## desktop too (the smokes try the web transport that way).

const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const Codec := preload("res://src/net/codec.gd")
const Opcodes := preload("res://src/net/generated/opcodes.gd")

signal connected
signal disconnected
signal message_received(opcode: int, payload: PackedByteArray)

const HEADER_LEN := 4

var _peer := StreamPeerTCP.new()
var _ws: WebSocketPeer = null   # S44: the browser's transport, when in use
var _recv_buf := PackedByteArray()
var _connected := false
var _established := false

## Host of the current connection — used to resolve wildcard web_base_url
## announcements ("http://0.0.0.0:8080" is only meaningful for same-host play).
var last_host := ""

## Messages received while no scene consumes them (e.g. ACTOR_APPEAR racing
## a scene change) buffer here; the entering scene drains them in _ready.
## While scene_active is set, messages are emit-only — otherwise every new
## scene would replay the whole session backlog.
var pending: Array = []
var scene_active := false

## Keepalive: the server drops a silent socket at idle_timeout (300s default).
## Retail's pl_2 keepalive fires one 107 per arch in {1,2} every 60s
## (nW.PX, kl_0) — flag field = the arch it's sent on.
const PING_INTERVAL := 60.0
const PING_ARCHES := [1, 2]
var _ping_clock := 0.0


## Take everything buffered since the last drain.
func drain() -> Array:
	var out := pending
	pending = []
	return out


func connect_to(host: String, port: int) -> Error:
	_recv_buf.clear()
	_established = false
	last_host = host
	var url := _ws_url(host, port)
	if url != "":
		_ws = WebSocketPeer.new()
		_ws.inbound_buffer_size = 1 << 20
		_ws.outbound_buffer_size = 1 << 20
		var werr := _ws.connect_to_url(url)
		if werr != OK:
			_ws = null
			return werr
		if "://" in host:
			last_host = host.get_slice("://", 1).get_slice("/", 0).get_slice(":", 0)
		_connected = true
		return OK
	_ws = null
	var err := _peer.connect_to_host(host, port)
	if err != OK:
		return err
	_connected = true
	return OK


## The WebSocket URL to use, or "" for TCP: a host that is already a URL; the
## web build's ws://host:port; or the --ws-url override.
static func _ws_url(host: String, port: int) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ws-url="):
			return a.trim_prefix("--ws-url=")
	if host.begins_with("ws://") or host.begins_with("wss://"):
		return host
	if OS.has_feature("web"):
		return "ws://%s:%d/" % [host, port]
	return ""


func disconnect_from() -> void:
	if _ws != null:
		_ws.close()
	else:
		_peer.disconnect_from_host()
	_connected = false


func is_online() -> bool:
	if _ws != null:
		return _connected and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN
	return _connected and _peer.get_status() == StreamPeerTCP.STATUS_CONNECTED


func send_message(opcode: int, payload: PackedByteArray, arch_target: int = 3) -> void:
	var frame := WireWriter.frame(opcode, payload, arch_target)
	if _ws != null:
		_ws.send(frame, WebSocketPeer.WRITE_MODE_BINARY)
	else:
		_peer.put_data(frame)


## Encodes + sends a schema-driven C2S message. Arch comes from the generated
## ARCH table; -1 (conditional) falls back to payload[0] — the 107 ping echo —
## or 3, the dominant in-game channel.
func send(opcode: int, values: Dictionary = {}) -> void:
	var payload := Codec.encode_payload(opcode, values)
	var arch: int = Opcodes.ARCH.get(opcode, 3)
	if arch < 0:
		arch = payload[0] if payload.size() > 0 else 3
	send_message(opcode, payload, arch)


func _process(delta: float) -> void:
	if not _connected:
		return
	var up := false
	var down := false
	if _ws != null:
		_ws.poll()
		var st := _ws.get_ready_state()
		up = st == WebSocketPeer.STATE_OPEN
		down = st == WebSocketPeer.STATE_CLOSED
	else:
		_peer.poll()
		var status := _peer.get_status()
		up = status == StreamPeerTCP.STATUS_CONNECTED
		down = status == StreamPeerTCP.STATUS_NONE or status == StreamPeerTCP.STATUS_ERROR
	if up:
		if not _established:
			_established = true
			connected.emit()
		_ping_clock += delta
		if _ping_clock >= PING_INTERVAL:
			_ping_clock = 0.0
			for arch in PING_ARCHES:
				var w := WireWriter.new()
				w.put_u8(arch)        # flag = the arch it rides on
				w.put_i32(0)          # key
				w.put_i64(Time.get_ticks_usec() * 1000)
				send_message(107, w.raw(), arch)
		if _ws != null:
			while _ws.get_available_packet_count() > 0:
				_recv_buf.append_array(_ws.get_packet())
			_drain_frames()
		else:
			var avail := _peer.get_available_bytes()
			if avail > 0:
				var res := _peer.get_data(avail)
				if res[0] == OK:
					_recv_buf.append_array(res[1])
				_drain_frames()
	elif down:
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
		if not scene_active:
			pending.append({"op": opcode, "raw": payload})
			if pending.size() > 512:
				pending.pop_front()
		message_received.emit(opcode, payload)
