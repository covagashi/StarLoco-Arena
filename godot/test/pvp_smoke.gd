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
const Cards := preload("res://src/gamedata/cards.gd")

var _sess: Node
var _main
var _bot: ArenaClient
var _bot2: ArenaClient          # bot's relogin socket (reconnect test)
var _drop_done := false         # mid-fight disconnect already triggered
var _reconnect_seen := false    # bot2 got the resync after 26334
var _bot_coach := -1
var _bot_in_world := false
var _fight_seen := false
var _done := false
var _trade_seen := false
var _bot_ex := -1          # exchange id on the bot side
var _spec: ArenaClient
var _spec_coach := -1
var _spec_fight_seen := false
var _spec_world_back := false


func _init() -> void:
	await process_frame
	_sess = root.get_node("Session")
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	_sess.message.connect(_on_main_msg)
	_bot = ArenaClient.new()
	root.add_child(_bot)
	_bot.message_received.connect(_on_bot_msg)
	_spec = ArenaClient.new()
	root.add_child(_spec)
	_spec.message_received.connect(_on_spec_msg)
	_sess.connect_to("127.0.0.1", 5555)
	_bot.connect_to("127.0.0.1", 5555)
	_spec.connect_to("127.0.0.1", 5555)
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
			# in world — kick off the bot + spectator logins
			_login(_bot, "test2", "test123")
			_login(_spec, "test3", "test123")
		6028:
			print("[smoke] main 6028 — duo formed")
			_guild_phase()
		6030:
			var d := Codec.decode(op, WireReader.new(raw))
			for pr in d.get("presets", []):
				if pr.get("coaches", []).size() == 2:
					print("[smoke] main got duo preset '%s' type=%d ally=%d"
						% [pr.get("name", "?"), int(pr.type),
							int(pr.coaches[0])])
		5104:
			var d := Codec.decode(op, WireReader.new(raw))
			print("[smoke] main 5104 result=%d ex=%d other=%d" % [
				int(d.result), int(d.ex_id), int(d.other_id)])
			if int(d.result) == 3:
				# trade accepted — the pane opened; stage our first
				# tradable card via the real List2 row path, then ready.
				await create_timer(0.4).timeout
				var list2: ItemList = _main.get_node(
					"UI/ElementDlg/VBox/Scroll2/List2")
				if list2.item_count > 0:
					_main._exchange_add(0)
					print("[smoke] main staged %s"
						% Cards.name_of(int(list2.get_item_metadata(0))))
				await create_timer(0.4).timeout
				_main._on_element_act()   # "Ready" → 5109
				print("[smoke] main ready sent")
		5110:
			var d := Codec.decode(op, WireReader.new(raw))
			print("[smoke] main 5110 side=%d card=%s qty=%d" % [
				int(d.side), Cards.name_of(int(d.card)), int(d.qty)])
		5114:
			var d := Codec.decode(op, WireReader.new(raw))
			print("[smoke] main 5114 reason=%d — %s" % [
				int(d.reason),
				"SWAP COMMITTED" if int(d.reason) == 0 else "cancelled"])
			if int(d.reason) == 0:
				_trade_seen = true
				await create_timer(0.8).timeout
				print("[smoke] trade done — now the challenge")
				_main._challenge_target = _bot_coach
				_main._send_challenge()
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
			# the spectator queries coach 1's fight, then joins it
			var w := WireWriter.new()
			w.put_i64(State.my_coach_id)
			_spec.send_message(2260, w.raw(), 2)
			print("[smoke] spec queried spectate on coach %d"
				% State.my_coach_id)
			# the scene change is deferred — poll for the fight view, then
			# auto-ready its placement so combat can start.
			_drive_fight()
		2601:
			var d := Codec.decode(op, WireReader.new(raw))
			print("[smoke] member report %s — %d stats"
				% [d.name, d.stats.size()])
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


## Reconnect path: second socket for the same account, mid-fight. The server
## pushes the resume question (26333) during the login burst; answering
## 26334=1 replays the resync, from there the fight proceeds normally.
func _reconnect_bot() -> void:
	_bot2 = ArenaClient.new()
	root.add_child(_bot2)
	_bot2.message_received.connect(_on_bot2_msg)
	_bot2.connect_to("127.0.0.1", 5555)
	await create_timer(1.0).timeout
	_login(_bot2, "test2", "test123")


func _on_bot2_msg(op: int, raw: PackedByteArray) -> void:
	var p := WireReader.new(raw)
	match op:
		2048:
			_coach_create(_bot2, "test2")
		26333:
			print("[smoke] BOT2 26333 — resume-fight question, accept")
			var w := WireWriter.new()
			w.put_u8(1)
			_bot2.send_message(26334, w.raw(), 2)
		8000:
			print("[smoke] BOT2 8000 — resynced back into the fight")
			_reconnect_seen = true
		8010:
			_bot2.send_message(8011, PackedByteArray(), 3)
		8020:
			_bot2.send_message(8023, PackedByteArray(), 3)
		8030:
			_bot2.send_message(8031, PackedByteArray(), 3)
		8104:
			p.get_i32()
			p.get_i32()
			var w := WireWriter.new()
			w.put_i64(p.get_i64())
			_bot2.send_message(8105, w.raw(), 3)
		8300:
			print("[smoke] BOT2 8300 — fight over on the relogin socket")
			_bot2.send_message(26321, PackedByteArray(), 3)
		_:
			pass


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
				print("[smoke] bot in world — main invites it to a 2v2 duo")
				await create_timer(0.8).timeout
				# real path needs test2 in the friend list — inject the
				# row the server would have pushed
				State.friends.append(
					{"name": "test2", "id": _bot_coach, "online": true})
				_main._open_duo_dlg()
				_main.get_node("UI/DuoDlg/VBox/Name").text = "Duplico"
				_main._on_duo_create()
		6025:
			var d := Codec.decode(op, p)
			print("[smoke] bot got duo invite team='%s' from %s — join"
				% [d.get("team", "?"), d.get("inviter_name", "?")])
			var w := WireWriter.new()
			w.put_u8(1)
			w.put_str(String(d.get("team", "")), "u8")
			w.put_i64(int(d.get("inviter", 0)))
			w.put_i64(int(d.get("invited", 0)))
			w.put_i16(0)
			_bot.send_message(6026, w.raw(), 2)
		6028:
			print("[smoke] bot 6028 — duo formed, expect the duo preset")
		502:
			var d := Codec.decode(op, p)
			print("[smoke] bot got guild invite from %s to '%s' — join"
				% [d.inviter, d.guild])
			var w := WireWriter.new()
			w.put_u8(int(d.type))
			w.put_u8(1)
			w.put_str(String(d.inviter), "u8")
			w.put_str(String(d.guild), "u8")
			_bot.send_message(503, w.raw(), 8)
		504:
			var d := Codec.decode(op, p)
			print("[smoke] bot guild result=%d" % int(d.code))
		556:
			var d := Codec.decode(op, p)
			print("[smoke] bot guild gone (self=%s)"
				% (int(d.coach_id) == _bot_coach))
		5102:
			var d := Codec.decode(op, p)
			_bot_ex = int(d.ex_id)
			print("[smoke] bot got trade invite from %s — accepting"
				% d.inviter)
			var w := WireWriter.new()
			w.put_i64(_bot_ex)
			w.put_u8(1)
			_bot.send_message(5103, w.raw(), 3)
		5110:
			var d := Codec.decode(op, p)
			print("[smoke] bot 5110 side=%d card=%d qty=%d" % [
				int(d.side), int(d.card), int(d.qty)])
			# after seeing main's first stage, bot stages card 7 too
			if int(d.side) == 0:
				var w := WireWriter.new()
				w.put_i64(_bot_ex)
				w.put_i32(7)
				w.put_u16(1)
				_bot.send_message(5105, w.raw(), 3)
				await create_timer(0.3).timeout
				var w2 := WireWriter.new()
				w2.put_i64(_bot_ex)
				_bot.send_message(5109, w2.raw(), 3)
				print("[smoke] bot staged 7 + ready")
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
			if not _drop_done:
				_drop_done = true
				# drop this socket BEFORE the phase acks, then relogin —
				# the server must offer to resume (26333 → 26334).
				print("[smoke] bot drops the socket mid-fight — relogin")
				_bot.disconnect_from()
				_reconnect_bot()
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


## ---- guild phase: invite → stats → rank CRUD → promote/demote → kick ----
## Runs on the main client (guild leader); the bot auto-accepts the 502.
func _sel_member(name: String) -> bool:
	var list: ItemList = _main.get_node("UI/GuildDlg/VBox/Scroll/List")
	for i in list.item_count:
		if name in list.get_item_text(i):
			list.select(i)
			return true
	return false


func _guild_phase() -> void:
	await create_timer(0.5).timeout
	_main._open_guild()                    # 517 → fresh 510/552/512 pushes
	await create_timer(0.8).timeout
	_main.get_node("UI/GuildDlg/VBox/InviteRow/Name").text = "test2"
	_main._on_guild_invite()
	print("[smoke] guild invite sent (501) — bot should answer 503")
	await create_timer(1.2).timeout
	if _sel_member("test2"):
		_main._on_guild_stats()            # 2600 → 2601 report
		print("[smoke] member-stats sent (2600)")
		await create_timer(0.8).timeout
	# ranks editor: add "Oficial" with the invite right
	_main._on_guild_ranks_mode()
	_main.get_node("UI/GuildDlg/VBox/RankEdit/Name").text = "Oficial"
	_main.get_node("UI/GuildDlg/VBox/RankEdit/RInvite").button_pressed = true
	_main._on_guild_rank_apply()
	print("[smoke] rank-add sent (553)")
	await create_timer(1.0).timeout
	# modify that rank (555): rename + same rights
	var list: ItemList = _main.get_node("UI/GuildDlg/VBox/Scroll/List")
	for i in list.item_count:
		if "Oficial" in list.get_item_text(i):
			list.select(i)
	_main.get_node("UI/GuildDlg/VBox/RankEdit/Name").text = "Oficial Mayor"
	_main._on_guild_rank_apply()
	print("[smoke] rank-modify sent (555)")
	await create_timer(1.0).timeout
	_main._on_guild_ranks_mode()           # back to members
	if _sel_member("test2"):
		_main._on_guild_set_rank(-1)       # promote 10 → 2
		print("[smoke] promote sent (515)")
		await create_timer(0.8).timeout
	if _sel_member("test2"):
		_main._on_guild_set_rank(1)        # demote 2 → 10
		print("[smoke] demote sent (515)")
		await create_timer(0.8).timeout
	if _sel_member("test2"):
		_main._on_guild_kick()             # 505 [gid][member]
		print("[smoke] kick sent (505)")
		await create_timer(0.8).timeout
	# delete the custom rank (ranks mode Kick→557)
	_main._on_guild_ranks_mode()
	list = _main.get_node("UI/GuildDlg/VBox/Scroll/List")
	for i in list.item_count:
		if "Oficial" in list.get_item_text(i):
			list.select(i)
	_main._on_guild_kick()
	print("[smoke] rank-delete sent (557)")
	await create_timer(0.6).timeout
	_main._on_guild_ranks_mode()
	_main.get_node("UI/GuildDlg").hide()
	# continue to the exchange phase
	_main._invite_exchange_id(_bot_coach, "test2")


## ---- spectator client: test3 watches coach 1's fight read-only ----
func _on_spec_msg(op: int, raw: PackedByteArray) -> void:
	var p := WireReader.new(raw)
	match op:
		2048:
			_coach_create(_spec, "spec")
		2052:
			_spec_coach = int(p.get_i64())
			print("[smoke] spec coach id=%d" % _spec_coach)
		4516:
			# world enter — after spectate this is the return to overworld
			if _spec_fight_seen:
				_spec_world_back = true
				print("[smoke] spec back in overworld after the fight")
		2261:
			var yes := p.get_u8()
			print("[smoke] spec 2261 spectatable=%d" % yes)
			if yes == 1:
				var w := WireWriter.new()
				w.put_i64(State.my_coach_id)
				_spec.send_message(26331, w.raw(), 2)
				print("[smoke] spec joins the fight (26331)")
		8000:
			_spec_fight_seen = true
			print("[smoke] SPEC 8000 — fight replayed to the spectator")
		8300:
			print("[smoke] spec 8300 — acking result screen")
			_spec.send_message(26321, PackedByteArray(), 3)


func _finish(code: int, msg: String) -> void:
	if _done:
		return
	_done = true
	print("[smoke] %s (fight_seen=%s trade=%s spec=%s back=%s reconn=%s)" % [
		msg, _fight_seen, _trade_seen, _spec_fight_seen,
		_spec_world_back, _reconnect_seen])
	quit(code)
