extends "res://test/world_smoke.gd"

## S18: the native invitation prompt (askDialog), live, in Spanish.
##
##   godot --path godot -s test/ask_smoke.gd [-- --shot-dir=D]
##
## A bot (`test2`, second socket) proposes a trade AND challenges the main
## client (`test`) at once. The prompts queue: the trade one shows first —
## "Aceptar" opens the native trade window (5103 → 5104 result 3), which we
## cancel; then the challenge one — "Rechazar" sends 26307 and the bot sees
## its challenge cancelled (26304). A third prompt (another trade) is closed
## with Cerrar, which refuses it (5103 with 0). Last, a duo invitation is
## refused (6026 → the bot gets 6027). No Godot dialog on the way.

const ArenaClient := preload("res://src/net/arena_client.gd")
const BOT_COACH := 2   # test2's coach id in server/arena.db

var _bot: ArenaClient
var _bot_coach := -1
var _bot_seen := {}
var _lang_before := ""


func _audit() -> void:
	var i18n = root.get_node("I18n")
	_lang_before = i18n.lang
	i18n.set_locale("es")
	_bot = ArenaClient.new()
	root.add_child(_bot)
	_bot.message_received.connect(func(op, _raw): _bot_seen[op] = int(_bot_seen.get(op, 0)) + 1)
	_bot.connected.connect(func(): _bot_login())
	_bot.connect_to("127.0.0.1", 5555)
	var in_world: bool = await _wait(func(): return _bot_seen.has(4516), 10.0)
	_record(0, "bot", in_world, "test2 logged in on a second socket")
	if not in_world:
		i18n.set_locale(_lang_before)
		return
	# both invitations at once: trade, then challenge
	_seen.clear()
	_bot_send(5101, _i64(State.my_coach_id))
	await create_timer(0.3).timeout
	var ch := WireWriter.new()
	ch.put_i64(State.my_coach_id)
	ch.put_u8(0)
	_bot_send(26301, ch.raw())
	await _wait(func(): return _seen.has(5102) and _seen.has(26300), 4.0)
	await create_timer(0.5).timeout
	var panel = _main._gui.dialogs.get("askDialog")
	var a: Dictionary = _ask()
	_record(0, "queue", panel != null and _main._asks.size() == 2 and str(a.get("title", "")) == "Propuesta de intercambio"
		and not _godot_dialog_open(), "2 prompts queued, showing '%s': '%s'" % [a.get("title", ""), a.get("text", "")])
	await _shot("ask-trade")
	if panel == null:
		i18n.set_locale(_lang_before)
		return
	panel.find_child("Accept", true, false).pressed.emit()
	var opened: bool = await _wait(func(): return _main._gui.is_open("exchangeDialog"), 3.0)
	await create_timer(0.4).timeout
	a = _ask()
	_record(0, "accept", opened and _main._gui.is_open("askDialog") and str(a.get("title", "")) == "Te desafían",
		"Aceptar → 5104 → trade window; next prompt '%s'" % a.get("title", ""))
	# the trade window is behind/over it — cancel the trade from the window
	var ex = _main._gui.dialogs.get("exchangeDialog")
	if ex != null:
		ex.find_child("Cancel", true, false).pressed.emit()
	await _wait(func(): return not _main._gui.is_open("exchangeDialog"), 3.0)
	_bot_seen.erase(26304)
	panel = _main._gui.dialogs.get("askDialog")
	panel.find_child("Refuse", true, false).pressed.emit()
	var declined: bool = await _wait(func(): return _bot_seen.has(26304), 3.0)
	_record(0, "refuse", declined and not _main._gui.is_open("askDialog") and _main._asks.is_empty(),
		"Rechazar → 26307 → the bot gets 26304; no prompt left")
	# close-as-refuse
	_seen.clear()
	_bot_seen.erase(5104)
	_bot_send(5101, _i64(State.my_coach_id))
	await _wait(func(): return _main._gui.is_open("askDialog"), 3.0)
	await create_timer(0.3).timeout
	_main._gui.dialogs.get("askDialog").close_button.pressed.emit()
	var refused: bool = await _wait(func(): return _bot_seen.has(5104), 3.0)
	_record(0, "close", refused and not _main._gui.is_open("askDialog") and not _main._gui.is_open("exchangeDialog"),
		"Cerrar refuses the trade (the bot hears back, no trade window)")
	# a duo invitation: 6024 [str8 team][i64 inviter][i64 mate] → 6025 here
	_seen.clear()
	_bot_seen.erase(6027)
	var duo := WireWriter.new()
	duo.put_str("Pareja", "u8")
	duo.put_i64(BOT_COACH)
	duo.put_i64(State.my_coach_id)
	_bot_send(6024, duo.raw())
	await _wait(func(): return _main._gui.is_open("askDialog"), 3.0)
	await create_timer(0.3).timeout
	var t: String = str(_ask().get("title", ""))
	var q: String = str(_ask().get("text", ""))
	_main._gui.dialogs.get("askDialog").find_child("Refuse", true, false).pressed.emit()
	var duo_refused: bool = await _wait(func(): return _bot_seen.has(6027), 3.0)
	_record(0, "duo", t == "Invitación a dúo" and "Pareja" in q and duo_refused,
		"'%s': '%s' → Rechazar → 6026 → the bot gets 6027" % [t, q])
	i18n.set_locale(_lang_before)


func _ask() -> Dictionary:
	var a: Variant = _main._gui.gui.model.get_value("ask")
	return a if a is Dictionary else {}


func _godot_dialog_open() -> bool:
	for c in _main.get_node("UI").get_children():
		if c is ConfirmationDialog and c.visible:
			return true
	return false


func _i64(v: int) -> PackedByteArray:
	var w := WireWriter.new()
	w.put_i64(v)
	return w.raw()


func _bot_send(op: int, raw: PackedByteArray) -> void:
	_bot.send_message(op, raw, 3 if op == 5101 else 2)


func _bot_login() -> void:
	var v := WireWriter.new()
	v.put_u8(0x02)
	v.put_u16(70)
	v.put_u8(5)
	v.put_bytes("72909".to_ascii_buffer())
	_bot.send_message(7, v.raw(), 0)
	var a := WireWriter.new()
	var l := CP1252.encode("test2")
	var p := CP1252.encode("test123")
	a.put_u8(l.size())
	a.put_bytes(l)
	a.put_u8(p.size())
	a.put_bytes(p)
	_bot.send_message(1025, a.raw(), 1)
	await _wait(func(): return _bot_seen.has(2048), 5.0)
	var n := CP1252.encode("test2")
	var w := WireWriter.new()
	w.put_u8(n.size())
	w.put_bytes(n)
	w.put_u8(1)
	w.put_u8(1)
	w.put_u8(0)
	_bot.send_message(2049, w.raw(), 2)
