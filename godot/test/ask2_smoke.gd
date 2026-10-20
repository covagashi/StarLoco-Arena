extends "res://test/ask_smoke.gd"

## S18: the two invitation prompts ask_smoke.gd cannot reach as `test`.
##
##   godot --path godot -s test/ask2_smoke.gd -- --as=test2 [--shot-dir=D]
##
## The main client is `test2` (no clan); the bot is `test`, leader of clan 2.
## 1. Match found: both send a quick search (2301); the pairing (23110)
##    shows "Combate encontrado"; Aceptar sends 23114 and the bot accepts its
##    side too: the fight starts (8000) and test2 surrenders it (8151).
## 2. Clan: the bot invites test2 (501); "Invitación a un clan"; Aceptar
##    (504) makes test2 a member — the server pushes the clan record. The bot
##    then expels test2 (505), as test2 started.

const LEADER_GUILD := 2
const WireReader := preload("res://src/net/wire_reader.gd")


func _bot_name() -> String:
	return "test"


var _bot_raw := {}   # last raw payload per opcode the bot received


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	_bot = ArenaClient.new()
	root.add_child(_bot)
	_bot.message_received.connect(func(op, raw):
		_bot_seen[op] = int(_bot_seen.get(op, 0)) + 1
		_bot_raw[op] = raw)
	_bot.connected.connect(func(): _bot_login())
	_bot.connect_to("127.0.0.1", 5555)
	var in_world: bool = await _wait(func(): return _bot_seen.has(4516), 10.0)
	_record(0, "bot", in_world and _as == "test2", "main is %s, the bot is test" % _as)
	if not in_world or _as != "test2":
		i18n.set_locale(_lang_before)
		return
	await _match()
	await create_timer(1.0).timeout
	await _guild()
	i18n.set_locale(_lang_before)


func _match() -> void:
	var q := WireWriter.new()
	q.put_i16(1)
	q.put_i16(0)
	q.put_i32(0)
	_seen.clear()
	_bot_send(2301, q.raw())
	await create_timer(0.3).timeout
	_main._on_quick_search()
	var paired: bool = await _wait(func(): return _seen.has(23110) and _main._gui.is_open("askDialog"), 6.0)
	await create_timer(0.4).timeout
	var a: Dictionary = _ask()
	_record(0, "match", paired and str(a.get("title", "")) == "Combate encontrado" and "test" in str(a.get("text", "")),
		"23110 → '%s': '%s'" % [a.get("title", ""), a.get("text", "")])
	await _shot("ask-match")
	if not paired:
		return
	_seen.clear()
	_main._gui.dialogs.get("askDialog").find_child("Accept", true, false).pressed.emit()
	await create_timer(0.4).timeout
	# the bot accepts its side too, with its own roster (23114)
	var m: Dictionary = Codec.decode(23110, WireReader.new(_bot_raw.get(23110, PackedByteArray())))
	var roster: Dictionary = Codec.decode(6006, WireReader.new(_bot_raw.get(6006, PackedByteArray())))
	var ids: Array = roster.get("fighters", []).map(func(f): return int(f.get("id", 0)))
	var w := WireWriter.new()
	w.put_i64(int(m.get("match", 0)))
	w.put_i64(int(m.get("opp", 0)))
	w.put_i16(int(m.get("mode", 0)))
	w.put_i16(int(m.get("fight_type", 0)))
	w.put_i32(ids.size())
	for i in range(ids.size() - 1, -1, -1):
		w.put_i64(int(ids[i]))
	w.put_u8(1)
	_bot_send(23114, w.raw())
	var fought: bool = await _wait(func(): return _seen.has(8000), 6.0)
	_record(0, "match accept", not _main._gui.is_open("askDialog") and fought,
		"Aceptar (23114) + the bot's 23114 → both accepted → 8000, the fight starts")
	await create_timer(1.0).timeout
	_sess.send(8151, PackedByteArray(), 3)   # end it: surrender
	await _wait(func(): return _seen.has(8300), 6.0)
	await create_timer(1.0).timeout


func _guild() -> void:
	var inv := WireWriter.new()
	inv.put_u8(0)
	inv.put_u8(1)
	inv.put_i64(State.my_coach_id)
	inv.put_i64(LEADER_GUILD)
	_seen.clear()
	_bot.send_message(501, inv.raw(), 8)
	var asked: bool = await _wait(func(): return _seen.has(502) and _main._gui.is_open("askDialog"), 4.0)
	await create_timer(0.4).timeout
	var a: Dictionary = _ask()
	_record(0, "guild", asked and str(a.get("title", "")) == "Invitación a un clan" and "test" in str(a.get("text", "")),
		"502 → '%s': '%s'" % [a.get("title", ""), a.get("text", "")])
	await _shot("ask-guild")
	if not asked:
		return
	_seen.clear()
	_main._gui.dialogs.get("askDialog").find_child("Accept", true, false).pressed.emit()
	var joined: bool = await _wait(func(): return str(State.guild.get("guild", "")) != "", 4.0)
	_record(0, "guild accept", joined, "Aceptar → test2 is in '%s'" % State.guild.get("guild", ""))
	# restore: the leader expels test2
	var kick := WireWriter.new()
	kick.put_i64(LEADER_GUILD)
	kick.put_i64(State.my_coach_id)
	_bot.send_message(505, kick.raw(), 8)
	await create_timer(1.5).timeout
