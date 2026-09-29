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

const Codec := preload("res://src/net/codec.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")
const Spells := preload("res://src/gamedata/spells.gd")

const OP_CLIENT_VERSION := 7
const OP_CLIENT_AUTH := 1025
const OP_INVALID_VERSION := 8
const OP_AUTH_RESULT := 1024
const OP_COACH_CREATE_REQ := 2048
const OP_COACH_CREATE := 2049
const OP_COACH_INFO := 2052
const OP_ENTER_INSTANCE := 4600
const OP_INSTANCE_READY := 4516
const OP_ACTOR_SPAWN := 4096
const OP_ACTOR_DESPAWN := 4098
const OP_ACTOR_MOVEMENT := 4500
const OP_FIGHT_CREATION := 8000
const OP_FIGHT_ERROR := 26310
const OP_PONG := 108
const OP_FIGHTER_LIST := 6006
const OP_TEAM_PRESETS := 6030
const OP_FIGHTER_CREATE := 6001
const OP_FIGHTER_CREATE_RESULT := 6000
const OP_FIGHTER_DELETE := 6003
const OP_FIGHTER_DELETE_RESULT := 6002
const OP_FIGHTER_LOADOUT := 6011
const OP_FIGHTER_LOADOUT_RESULT := 6010

@onready var host_edit: LineEdit = $UI/VBox/ConnRow/Host
@onready var port_edit: LineEdit = $UI/VBox/ConnRow/Port
@onready var connect_btn: Button = $UI/VBox/ConnRow/ConnectBtn
@onready var status_lbl: Label = $UI/VBox/ConnRow/Status
@onready var login_edit: LineEdit = $UI/VBox/AuthRow/Login
@onready var password_edit: LineEdit = $UI/VBox/AuthRow/Password
@onready var login_btn: Button = $UI/VBox/AuthRow/LoginBtn
@onready var log := $UI/Chat
@onready var world: Node2D = $World

var _my_pos := Vector3.ZERO   # last EnterInstance position


func _ready() -> void:
	Session.connected.connect(_on_connected)
	Session.disconnected.connect(_on_disconnected)
	Session.message.connect(_on_message)
	# Re-entering after a fight: replay anything that arrived mid-scene-change.
	for m in Session.client.drain():
		_on_message(m.op, m.raw)
	Session.client.scene_active = true
	connect_btn.pressed.connect(_on_connect_pressed)
	login_btn.pressed.connect(_on_login_pressed)
	$UI/VBox/AuthRow/PracticeBtn.pressed.connect(_on_practice_pressed)
	log.bubble.connect(world.chat_bubble)
	var breed_sel: OptionButton = $UI/CreateDlg/VBox/Breed
	for id in range(1, 13):
		breed_sel.add_item(State.BREED_NAMES[id], id)
	$UI/VBox/RosterBox/RosterBtns/NewBtn.pressed.connect(
		func(): $UI/CreateDlg.visible = true)
	$UI/CreateDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/CreateDlg.visible = false)
	$UI/CreateDlg/VBox/Btns/CreateBtn.pressed.connect(_on_create_fighter)
	$UI/VBox/RosterBox/RosterBtns/DelBtn.pressed.connect(_on_delete_fighter)
	$UI/VBox/RosterBox/Roster.item_selected.connect(
		func(_i):
			$UI/VBox/RosterBox/RosterBtns/DelBtn.disabled = false
			$UI/VBox/RosterBox/RosterBtns/LoadoutBtn.disabled = false)
	$UI/VBox/RosterBox/RosterBtns/LoadoutBtn.pressed.connect(_open_loadout)
	$UI/LoadoutDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/LoadoutDlg.visible = false)
	$UI/LoadoutDlg/VBox/Btns/SaveBtn.pressed.connect(_on_save_loadout)


func _exit_tree() -> void:
	# Fight transition: buffer until the next scene drains in its _ready.
	if Session.client != null:
		Session.client.scene_active = false


func _on_connect_pressed() -> void:
	if Session.is_online():
		Session.client.disconnect_from()
		return
	_log_line("connecting to %s:%s…" % [host_edit.text, port_edit.text])
	var err := Session.connect_to(host_edit.text, int(port_edit.text))
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
	Session.send(OP_CLIENT_VERSION, version.raw(), 0)

	var auth := WireWriter.new()
	var login := CP1252.encode(login_edit.text)
	var password := CP1252.encode(password_edit.text)
	auth.put_u8(login.size())
	auth.put_bytes(login)
	auth.put_u8(password.size())
	auth.put_bytes(password)
	Session.send(OP_CLIENT_AUTH, auth.raw(), 1)
	State.my_coach_name = login_edit.text.strip_edges()
	_log_line("sent version + auth for '%s'" % login_edit.text)


func _on_message(opcode: int, raw: PackedByteArray) -> void:
	var payload := WireReader.new(raw)
	if log.feed(opcode, payload):
		return  # chat family handled by the chat box
	match opcode:
		OP_INVALID_VERSION:
			_log_line("[color=red]server rejected client version — closing[/color]")
			Session.client.disconnect_from()
		OP_AUTH_RESULT:
			var code := payload.get_u8()
			if code == 0:
				_log_line("[color=green]auth OK[/color]")
			else:
				_log_line("[color=red]auth refused, code %d[/color]" % code)
		OP_COACH_CREATE_REQ:
			_send_coach_creation()
		OP_COACH_INFO:
			var d := Codec.decode(opcode, payload)
			State.my_coach_id = int(d.get("id", -1))
			_log_line("[color=green]coach info received — in lobby[/color]")
		OP_ENTER_INSTANCE:
			var d := Codec.decode(opcode, payload)
			State.current_world = int(d.get("world_id", -1))
			_my_pos = Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)),
				float(d.get("alt", 0)))
			_log_line("entering instance world=%d pos=(%s,%s)" % [
				State.current_world, d.get("x"), d.get("y")])
		OP_INSTANCE_READY:
			_log_line("[color=green]instance ready — in world[/color]")
			$UI/VBox/AuthRow/PracticeBtn.disabled = false
			world.show_world(State.current_world, _my_pos)
		OP_ACTOR_SPAWN:
			_spawn_world_actors(payload)
		OP_ACTOR_DESPAWN:
			var n := payload.get_i32()
			for i in n:
				world.actor_despawned(int(payload.get_i64()))
		OP_ACTOR_MOVEMENT:
			var aid := int(payload.get_i64())
			var path := []
			while payload.remaining() >= 10:
				path.append(Vector3i(int(payload.get_i32()),
					int(payload.get_i32()), int(payload.get_i16())))
			world.actor_moved(aid, path)
		OP_FIGHT_CREATION:
			State.fight_world = State.current_world
			State.fight_data = Codec.decode(opcode, payload)
			State.index_fighters(State.fight_data)
			_log_line("[color=green]fight created on arena %d — %d fighters[/color]"
				% [State.fight_world, State.fighters.size()])
			get_tree().change_scene_to_file("res://src/fight/fight_view.tscn")
		OP_FIGHTER_LIST:
			# Lobby roster (et_2 blobs) — fills the selectable fighter list.
			var d := Codec.decode(opcode, payload)
			State.roster = d.get("fighters", [])
			var roster_list: ItemList = $UI/VBox/RosterBox/Roster
			roster_list.clear()
			var names := []
			for f in State.roster:
				var label := "%s (%s)" % [f.get("name", "?"),
					State.BREED_NAMES.get(int(f.get("breed", 0)), "breed %d" % int(f.get("breed", 0)))]
				names.append(label)
				roster_list.add_item(label)
				roster_list.set_item_metadata(roster_list.item_count - 1, int(f.id))
			_log_line("roster: %s" % (", ".join(names) if names else "empty"))
		OP_TEAM_PRESETS:
			var d := Codec.decode(opcode, payload)
			State.presets = d.get("presets", [])
			var real := State.presets.filter(func(p): return int(p.type) != -4)
			_log_line("team presets: %d saved (%d shown incl. bench)" % [
				real.size(), State.presets.size()])
		OP_FIGHTER_CREATE_RESULT:
			var d := Codec.decode(opcode, payload)
			if int(d.result) == 0:
				_log_line("[color=green]fighter created: %s[/color]"
					% d.fighter.get("name", "?"))
				$UI/CreateDlg.visible = false
			else:
				_log_line("[color=red]fighter create refused, code %d[/color]"
					% int(d.result))
		OP_FIGHTER_DELETE_RESULT:
			var d := Codec.decode(opcode, payload)
			if int(d.result) == 0:
				_log_line("fighter %d deleted" % int(d.fighter_id))
			else:
				_log_line("[color=red]fighter delete refused, code %d[/color]"
					% int(d.result))
		OP_FIGHTER_LOADOUT_RESULT:
			# 6010: [i64 fid][u8 result][u16 spellsLen]{i32}[u16 cardsLen]{i32}
			var fid := int(payload.get_i64())
			var res := payload.get_u8()
			if res == 0:
				var spell_n := payload.get_u16()
				var spells := []
				for i in spell_n / 4:
					spells.append(int(payload.get_i32()))
				for f in State.roster:
					if int(f.get("id", -1)) == fid:
						f.spells = spells
				_log_line("[color=green]loadout saved — %d spells[/color]"
					% spells.size())
				$UI/LoadoutDlg.visible = false
			else:
				_log_line("[color=red]loadout refused, code %d[/color]" % res)
		OP_FIGHT_ERROR:
			_log_line("[color=red]fight creation refused[/color]")
		OP_PONG:
			pass  # keepalive reply
		_:
			_log_line("S2C opcode [b]%d[/b] — %d bytes" % [opcode, payload.remaining()])


## ActorSpawn inner body: [i32 count]{u8 type=1 coach: i64 id, str8 name,
## i32 x, i32 y, i16 z, u8 dir, u8 skin, u8 hair, u8 sex, i16 look, i32
## standing, u8 sit, i16 guild, i16 desc, u8 strPairs, i32 adminRight}
## (server writeCoachActor — aez_0.b flags 3179 source order)
func _spawn_world_actors(payload: WireReader) -> void:
	var d := Codec.decode(OP_ACTOR_SPAWN, payload)
	var body := WireReader.new(d.get("actors_raw", PackedByteArray()))
	var count := body.get_i32()
	for i in count:
		var atype := body.get_u8()
		if atype != 1:
			_log_line("[color=red]actor spawn: unknown type %d[/color]" % atype)
			return
		var id := int(body.get_i64())
		var cname := body.get_str("u8")
		var x := int(body.get_i32())
		var y := int(body.get_i32())
		var z := int(body.get_i16())
		body.get_u8()  # dir
		body.get_u8()  # skin
		body.get_u8()  # hair
		body.get_u8()  # sex
		body.get_u16() # look
		body.get_i32() # standing
		body.get_u8()  # sit
		body.get_u16() # guild blob len
		body.get_u16() # descriptor blob len
		body.get_u8()  # strength pairs
		body.get_i32() # admin right
		if id == State.my_coach_id:
			continue   # we already render ourselves from the 4600 position
		world.actor_spawned(id, cname, x, y, z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_ENTER and world.visible:
		log.grab_chat_focus()
		return
	if not world.visible:
		return
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var cell: Variant = world.screen_to_cell(world.get_global_mouse_position())
		if cell != null:
			world.click_to(cell)
	elif event is InputEventMouseMotion:
		world.set_hover(world.get_global_mouse_position())


func _on_practice_pressed() -> void:
	# TeamTest 26330 doubles as overworld challenge launch:
	# [i32 challengeId][i16 99] — 34 = "Démon de la 58ème minute" practice
	# demon. The server fields the opponent side; one client suffices.
	var w := WireWriter.new()
	w.put_i32(34)
	w.put_u16(99)
	Session.send(26330, w.raw(), 2)
	_log_line("practice challenge 34 sent — waiting for fight…")


## 6001 FighterCreate [u8 flag][i16 slot][u16 blobLen][et_2 blob] (arch 2).
## The roster list refresh arrives as a fresh 6006 push — no local mutation.
func _on_create_fighter() -> void:
	var dlg := $UI/CreateDlg/VBox
	var fname: String = dlg.get_node("Name").text.strip_edges()
	if fname.is_empty():
		_log_line("[color=red]fighter needs a name[/color]")
		return
	var blob: PackedByteArray = Overrides.encode_fighter_blob(
		dlg.get_node("Breed").get_selected_id(), fname,
		1 if dlg.get_node("Sex").button_pressed else 0)
	var w := WireWriter.new()
	w.put_u8(0)                       # flag: 0 = classic roster
	w.put_u16(0)                      # slot
	w.put_u16(blob.size())
	w.put_bytes(blob)
	Session.send(OP_FIGHTER_CREATE, w.raw(), 2)
	_log_line("fighter create sent: %s" % fname)


## 6003 FighterDelete [i64 fighterId][i16 slot] (arch 2).
func _on_delete_fighter() -> void:
	var roster_list: ItemList = $UI/VBox/RosterBox/Roster
	var sel := roster_list.get_selected_items()
	if sel.is_empty():
		return
	var fid: int = roster_list.get_item_metadata(sel[0])
	var w := WireWriter.new()
	w.put_i64(fid)
	w.put_u16(0)
	Session.send(OP_FIGHTER_DELETE, w.raw(), 2)
	_log_line("fighter delete sent: %d" % fid)


## Loadout editor — lists the fighter's breed-legal spells (from the exported
## gamedata table), checks the current loadout, saves via 6011.
var _loadout_fid := -1

func _open_loadout() -> void:
	var roster_list: ItemList = $UI/VBox/RosterBox/Roster
	var sel := roster_list.get_selected_items()
	if sel.is_empty():
		return
	_loadout_fid = roster_list.get_item_metadata(sel[0])
	var f: Variant = null
	for fr in State.roster:
		if int(fr.get("id", -1)) == _loadout_fid:
			f = fr
	if f == null:
		return
	var dlg := $UI/LoadoutDlg/VBox
	dlg.get_node("Title").text = "Loadout — %s" % f.get("name", "?")
	var box: VBoxContainer = dlg.get_node("Scroll/Spells")
	for c in box.get_children():
		c.queue_free()
	var owned := {}
	for s in f.get("spells", []):
		owned[int(s)] = true
	for s in Spells.for_breed(int(f.get("breed", 0))):
		var cb := CheckBox.new()
		cb.text = "%s — %d AP, %d-%d" % [s.name, s.ap, s.min, s.max]
		cb.set_meta("id", int(s.id))
		cb.button_pressed = owned.has(int(s.id))
		box.add_child(cb)
	$UI/LoadoutDlg.visible = true


## 6011 [i64 fid][i16 teamId][u16 len]{i32 spells}[u16 len]{i16 slot,i32 card}
func _on_save_loadout() -> void:
	if _loadout_fid < 0:
		return
	var picked := []
	for cb in $UI/LoadoutDlg/VBox/Scroll/Spells.get_children():
		if cb.button_pressed:
			picked.append(int(cb.get_meta("id")))
	if picked.size() > 6:
		_log_line("[color=red]max 6 spells[/color]")
		return
	# keep the fighter's existing card slots untouched
	var cards := []
	for f in State.roster:
		if int(f.get("id", -1)) == _loadout_fid:
			cards = f.get("cards", [])
	var w := WireWriter.new()
	w.put_i64(_loadout_fid)
	w.put_u16(0)                        # teamId — unused server-side
	w.put_u16(picked.size() * 4)
	for s in picked:
		w.put_i32(s)
	w.put_u16(cards.size() * 6)
	for c in cards:
		w.put_u16(int(c.slot))
		w.put_i32(int(c.id))
	Session.send(OP_FIGHTER_LOADOUT, w.raw(), 2)
	_log_line("loadout sent — %d spells" % picked.size())


func _send_coach_creation() -> void:
	var name := login_edit.text.strip_edges()
	var name_bytes := CP1252.encode(name.left(20))
	var w := WireWriter.new()
	w.put_u8(name_bytes.size())
	w.put_bytes(name_bytes)
	w.put_u8(1)  # skin
	w.put_u8(1)  # hair
	w.put_u8(0)  # sex
	Session.send(OP_COACH_CREATE, w.raw(), 2)
	_log_line("server asked coach creation — sent name '%s'" % name)


func _log_line(s: String) -> void:
	log.log_line(s)
