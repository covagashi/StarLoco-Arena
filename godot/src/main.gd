extends Control

## M0 wire-test harness: connect → ClientVersion → ClientAuthentication →
## coach create/info → login burst → EnterInstance. Exchange verified against
## server/internal/testclient/flows.go and test/e2e/login_test.go.
##
## Wire facts (server/protocol/frame.go, handshake/messages.go):
##   C2S [u16 len][u8 arch][u16 op][payload]   S2C [u16 len][u16 op][payload]
##   7   ClientVersion   arch 0  [u8 0x02][u16 70][u8 len][ascii build]
##   1025 ClientAuth     arch 1  [u8 len][login][u8 len][pass]  (PLAINTEXT — the
##                     RSA channel is a separate admin path, unused here)
##   1024 AuthResult     [u8 code]  0=ok, 2=refused
##   2048 CoachCreateReq (empty) → reply 2049 arch 2 [u8 len][name][u8 skin][u8 hair][u8 sex]
##   2052 CoachInfos     login burst begins; 4600 EnterInstance; 4516 Ready
##   8   InvalidVersion  [u8 2][u16 70] — server keeps socket open; we close it.

const ArenaClient := preload("res://src/net/arena_client.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")

const OP_CLIENT_VERSION := 7
const OP_CLIENT_AUTH := 1025
const OP_INVALID_VERSION := 8
const OP_AUTH_RESULT := 1024
const OP_COACH_CREATE_REQ := 2048
const OP_COACH_CREATE := 2049
const OP_COACH_INFO := 2052
const OP_ENTER_INSTANCE := 4600
const OP_INSTANCE_READY := 4516
const OP_PONG := 108

var client := ArenaClient.new()

@onready var host_edit: LineEdit = $VBox/ConnRow/Host
@onready var port_edit: LineEdit = $VBox/ConnRow/Port
@onready var connect_btn: Button = $VBox/ConnRow/ConnectBtn
@onready var status_lbl: Label = $VBox/ConnRow/Status
@onready var login_edit: LineEdit = $VBox/AuthRow/Login
@onready var password_edit: LineEdit = $VBox/AuthRow/Password
@onready var login_btn: Button = $VBox/AuthRow/LoginBtn
@onready var log: RichTextLabel = $VBox/Log


func _ready() -> void:
	add_child(client)
	client.connected.connect(_on_connected)
	client.disconnected.connect(_on_disconnected)
	client.message_received.connect(_on_message)
	connect_btn.pressed.connect(_on_connect_pressed)
	login_btn.pressed.connect(_on_login_pressed)


func _on_connect_pressed() -> void:
	if client.is_online():
		client.disconnect_from()
		return
	_log_line("connecting to %s:%s…" % [host_edit.text, port_edit.text])
	var err := client.connect_to(host_edit.text, int(port_edit.text))
	if err != OK:
		_log_line("[color=red]connect failed: %s[/color]" % error_string(err))


func _on_connected() -> void:
	status_lbl.text = "connected"
	login_btn.disabled = false
	connect_btn.text = "Disconnect"
	_log_line("[color=green]connected[/color]")


func _on_disconnected() -> void:
	status_lbl.text = "offline"
	login_btn.disabled = true
	connect_btn.text = "Connect"
	_log_line("[color=red]disconnected[/color]")


func _on_login_pressed() -> void:
	var version := WireWriter.new()
	version.put_u8(0x02)          # marker, ignored by the server
	version.put_u16(70)           # the only field it validates
	version.put_u8(5)
	version.put_bytes("72909".to_ascii_buffer())
	client.send_message(OP_CLIENT_VERSION, version.raw(), 0)

	var auth := WireWriter.new()
	var login := CP1252.encode(login_edit.text)
	var password := CP1252.encode(password_edit.text)
	auth.put_u8(login.size())
	auth.put_bytes(login)
	auth.put_u8(password.size())
	auth.put_bytes(password)
	client.send_message(OP_CLIENT_AUTH, auth.raw(), 1)
	_log_line("sent version + auth for '%s'" % login_edit.text)


func _on_message(opcode: int, payload: WireReader) -> void:
	match opcode:
		OP_INVALID_VERSION:
			_log_line("[color=red]server rejected client version — closing[/color]")
			client.disconnect_from()
		OP_AUTH_RESULT:
			var code := payload.get_u8()
			if code == 0:
				_log_line("[color=green]auth OK[/color]")
			else:
				_log_line("[color=red]auth refused, code %d[/color]" % code)
		OP_COACH_CREATE_REQ:
			_send_coach_creation()
		OP_COACH_INFO:
			_log_line("[color=green]coach info received — in lobby[/color]")
		OP_ENTER_INSTANCE:
			_log_line("entering instance…")
		OP_INSTANCE_READY:
			_log_line("[color=green]instance ready — in world[/color]")
		OP_PONG:
			pass  # keepalive reply
		_:
			_log_line("S2C opcode [b]%d[/b] — %d bytes" % [opcode, payload.remaining()])


func _send_coach_creation() -> void:
	var name := login_edit.text.strip_edges()
	var name_bytes := CP1252.encode(name.left(20))
	var w := WireWriter.new()
	w.put_u8(name_bytes.size())
	w.put_bytes(name_bytes)
	w.put_u8(1)  # skin
	w.put_u8(1)  # hair
	w.put_u8(0)  # sex
	client.send_message(OP_COACH_CREATE, w.raw(), 2)
	_log_line("server asked coach creation — sent name '%s'" % name)


func _log_line(s: String) -> void:
	log.append_text(s + "\n")
