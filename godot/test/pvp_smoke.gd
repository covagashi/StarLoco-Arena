extends SceneTree

## Two-client PvP smoke: bot "test2" logs in on a second socket and
## auto-accepts a direct challenge; the main client drives the real UI
## path — click-challenge → 26301 → incoming 26300 → accept 26305 →
## both 26302 → team confirm 26303 → 8000 fight. Bot acks the fight
## phases (8011/8023/8031) and passes its turns (8105) so the bout
## actually runs.
##   godot --path godot -s test/pvp_smoke.gd

const ArenaClient := preload("res://src/net/arena_client.gd")
const Codec := preload("res://src/net/codec.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")

var _sess: Node
var _main
var _bot: ArenaClient
var _bot_coach := -1
var _bot_in_world := false
var _fight_seen := false
var _done := false


func _init() -> void:
	await process_frame
	_sess = root.get_node("Session")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_sess.message.connect(_on_main_msg)
	_bot = ArenaClient.new()
	root.add_child(_bot)
	_bot.message_received.connect(_on_bot_msg)
	_sess.connect_to("127.0.0.1", 5555)
	_bot.connect_to("127.0.0.1", 5555)
	await create_timer(0.5).timeout
	_login(_sess.client, "test", "test123")
	create_timer(60.0).timeout.connect(_finish.bind(1, "timeout"))


func _login(c: ArenaClient, name_: String, pass_: String) -> void:
	var v := WireWriter.new()
	v.put_u8(0x02)
	v.put_u16(70)
	v.put_u8(5)
	v.put_bytes("72909".to_ascii_buffer())
	c.send_message(7, v.raw(), 0)
	var a := WireWriter.new()
	var l := CP1252.encode(name_)
	var p := CP1252.encode(pass_)
	a.put_u8(l.size())
	a.put_bytes(l)
	a.put_u8(p.size())
	a.put_bytes(p)
	c.send_message(1025, a.raw(), 1)


func _coach_create(c: ArenaClient, name_: String) -> void:
	var n := CP1252.encode(name_)
	var w := WireWriter.new()
	w.put_u8(n.size())
	w.put_bytes(n)
	w.put_u8(1)
	w.put_u8(1)
	w.put_u8(0)
	c.send_message(2049, w.raw(), 2)


## ---- main client (drives the real main.tscn UI paths) ----
func _on_main_msg(op: int, raw: PackedByteArray) -> void:
	match op:
		2048:
			_coach_create(_sess.client, "test")
		4516:
			# in world — kick off the bot login, then challenge when it's up
			_login(_bot, "test2", "test123")
		26300:
			var p := WireReader.new(raw)
			var handle := int(p.get_i64())
			var outgoing := p.get_u8()
			p.get_u8()
			var who := ""
			for i in p.get_u8():
				who = p.get_str("i32")
			print("[smoke] 26300 invitation handle=%d outgoing=%d name=%s"
				% [handle, outgoing, who])
		26302:
			print("[smoke] 26302 accepted — confirm team via the dialog path")
			await create_timer(0.4).timeout
			_main._on_team_confirmed()   # sends 26303 with the dlg selection
		8000:
			print("[smoke] MAIN 8000 — challenge fight created")
			_fight_seen = true
			# the scene change is deferred — poll for the fight view, then
			# auto-ready its placement so combat can start.
			_drive_fight()
		8300:
			print("[smoke] MAIN 8300 — fight over")


## Once the fight view is the current scene, press Ready when placement
## opens and end our turns so the fight resolves quickly.
func _drive_fight() -> void:
	var fv = null
	for i in 100:
		await process_frame
		if current_scene != null and current_scene.has_signal("placement_began"):
			fv = current_scene
			break
	if fv == null:
		print("[smoke] WARN fight view never became current_scene")
		return
	# weakref: the view dies on scene change — capturing it raw errors.
	var ref: WeakRef = weakref(fv)
	fv.placement_began.connect(func():
		create_timer(0.5).timeout.connect(func():
			var s = ref.get_ref()
			if s != null:
				s.confirm_placement()
				print("[smoke] main placement ready")))
	fv.turn_began.connect(func(_fid, ours):
		if ours:
			create_timer(0.5).timeout.connect(func():
				var s = ref.get_ref()
				if s != null:
					s.request_end_turn()))
	# surrender after combat has been live a bit — a clean full loop
	await create_timer(20.0).timeout
	if ref.get_ref() != null and not _done:
		print("[smoke] main surrenders")
		_sess.client.send_message(8151, PackedByteArray(), 3)
	await create_timer(6.0).timeout
	_finish(0, "pvp challenge loop complete")


## ---- bot client: login, accept challenge, ack fight phases ----
func _on_bot_msg(op: int, raw: PackedByteArray) -> void:
	var p := WireReader.new(raw)
	match op:
		2048:
			_coach_create(_bot, "test2")
		2052:
			_bot_coach = int(p.get_i64())
			print("[smoke] bot coach id=%d" % _bot_coach)
		4516:
			if not _bot_in_world:
				_bot_in_world = true
				print("[smoke] bot in world — main challenges it")
				await create_timer(0.8).timeout
				_main._challenge_target = _bot_coach
				_main._send_challenge()
		26300:
			var handle := int(p.get_i64())
			var outgoing := p.get_u8()
			p.get_u8()
			var who := ""
			for i in p.get_u8():
				who = p.get_str("i32")
			if outgoing == 0:
				print("[smoke] bot got challenge from %s — accepting" % who)
				var w := WireWriter.new()
				w.put_i64(handle)
				w.put_u8(0)
				_bot.send_message(26305, w.raw(), 2)
		26302:
			var w := WireWriter.new()
			w.put_i64(_bot_coach)
			w.put_i16(-1)   # titular roster
			_bot.send_message(26303, w.raw(), 2)
			print("[smoke] bot confirmed team")
		8000:
			print("[smoke] BOT 8000 — same fight on the other socket")
		8010:
			_bot.send_message(8011, PackedByteArray(), 3)
		8020:
			_bot.send_message(8023, PackedByteArray(), 3)
		8030:
			_bot.send_message(8031, PackedByteArray(), 3)
		8104:
			# whoever's turn it is, ask to end it — the server ignores
			# end-turn for a fighter that isn't ours/not on turn.
			p.get_i32()
			p.get_i32()
			var w := WireWriter.new()
			w.put_i64(p.get_i64())
			_bot.send_message(8105, w.raw(), 3)
		8300:
			_bot.send_message(26321, PackedByteArray(), 3)
			print("[smoke] bot fight done")


func _finish(code: int, msg: String) -> void:
	if _done:
		return
	_done = true
	print("[smoke] %s (fight_seen=%s)" % [msg, _fight_seen])
	quit(code)
