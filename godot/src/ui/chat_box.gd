extends VBoxContainer

## ChatBox — reusable chat panel: channel filter tabs + scrollback + input
## with retail-style channel prefixes (/s vicinity, /t trade, /w name whisper,
## /p group, /c clan; anything else starting with '/' is forwarded verbatim for
## the server's GM-command handler). Emitted wire ops:
##   C2S 3153 vicinity arch3 [u16 msg]      S2C 3152 [u8 name][i64 id][u16 msg]
##   C2S 3155 private  arch4 [u8 tgt][u8 m] S2C 3154 [u8 name][i64 id][u8 msg]
##   C2S 3159 trade    arch3 [u16 msg]      S2C 3168 same as 3152
##   C2S 3161 group    arch3 [i64 id][u16]  S2C 3170 same as 3152
##   C2S 3199 clan     arch2 [u16 msg][i64] S2C 3198 same as 3152
##   C2S 3151 channel  arch4 [u8 ch][u8 m]  S2C 3140 [u8 ch][u8 snd][u8 msg]
##   S2C 2070 server announcement [u32 msg]
##   S2C 3206/3210/3212/3214/3216 chat errors (empty payloads)
## Own outgoing lines are echoed locally — the server never sends them back.
##
## The tab row filters the scrollback by channel — a line is stored once and
## re-rendered when the filter changes, so switching tabs loses nothing.

const WireWriter := preload("res://src/net/wire_writer.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")

signal bubble(actor_id: int, text: String)   # hooked to lobby bubbles

const COLORS := {
	"say": "white",
	"trade": "orange",
	"whisper": "medium_purple",
	"group": "light_green",
	"clan": "cyan",
	"channel": "light_blue",
	"server": "red",
	"system": "khaki",
	"me": "khaki",
	"error": "tomato",
}
const CHAT_ERROR_KEYS := {
	3206: "chat.err.malformed",
	3210: "chat.err.privileges",
	3212: "chat.err.not_implemented",
	3214: "chat.err.self",
	3216: "chat.err.not_permitted",
}

## Filter tabs, in display order: every stored line maps its kind to one.
## "channel" (named channels such as the global "*") shares the trade tab —
## it is the same kind of opt-in broadcast pipe.
const TABS := ["all", "say", "trade", "group", "clan", "whisper", "system"]
const KIND_TAB := {
	"say": "say", "me": "say", "channel": "trade", "trade": "trade",
	"group": "group", "clan": "clan", "whisper": "whisper",
	"server": "system", "system": "system", "error": "system",
}
const MAX_LINES := 300

@onready var _display: RichTextLabel = $Display
@onready var _input: LineEdit = $Row/Input

var _tab := "all"
var _tab_btns := {}
var _lines: Array = []          # [{kind, text}] — pre-formatted bbcode


func _ready() -> void:
	var tabs := HBoxContainer.new()
	tabs.name = "Tabs"
	tabs.add_theme_constant_override("separation", 2)
	for t in TABS:
		var b := Button.new()
		b.toggle_mode = true
		b.text = I18n.t("chat.tab." + t)
		b.add_theme_font_size_override("font_size", 11)
		b.custom_minimum_size = Vector2(0, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.button_pressed = t == _tab
		b.pressed.connect(func(): _set_tab(t))
		tabs.add_child(b)
		_tab_btns[t] = b
	add_child(tabs)
	move_child(tabs, 0)
	_input.text_submitted.connect(_on_submit)
	$Row/SendBtn.pressed.connect(func(): _on_submit(_input.text))
	_input.placeholder_text = I18n.t("chat.placeholder")
	$Row/SendBtn.text = I18n.t("chat.send")
	I18n.locale_changed.connect(func(_l): _retranslate())


func _set_tab(t: String) -> void:
	_tab = t
	for k in _tab_btns:
		_tab_btns[k].button_pressed = k == t
	_render()


func _retranslate() -> void:
	_input.placeholder_text = I18n.t("chat.placeholder")
	$Row/SendBtn.text = I18n.t("chat.send")
	for t in _tab_btns:
		_tab_btns[t].text = I18n.t("chat.tab." + t)


## Retail emote table (server handlers_emote.go — up_0 in the client).
## command -> [emoteId, animName]
const EMOTES := {
	"clap": [57, "AnimEmote-Applaudir"],
	"applaudir": [57, "AnimEmote-Applaudir"],
	"read": [59, "AnimEmote-Lire-Debut"],
	"lire": [59, "AnimEmote-Lire-Debut"],
	"declare": [60, "AnimEmote-Declaration"],
	"angry": [62, "AnimEmote-Colere"],
	"colere": [62, "AnimEmote-Colere"],
	"music": [63, "AnimEmote-Guitare-Debut"],
	"guitare": [63, "AnimEmote-Guitare-Debut"],
	"show": [65, "AnimEmote-Pointer"],
	"point": [65, "AnimEmote-Pointer"],
	"laugh": [66, "AnimEmote-Rire"],
	"rire": [66, "AnimEmote-Rire"],
	"fear": [67, "AnimEmote-Effraye"],
	"effraye": [67, "AnimEmote-Effraye"],
	"cry": [68, "AnimEmote-Defaite"],
	"defaite": [68, "AnimEmote-Defaite"],
	"no": [69, "AnimEmote-Non"],
	"non": [69, "AnimEmote-Non"],
}

const OP_EMOTE_PLAY := 4701
const OP_EMOTE_PLAYED := 4700

## Social list commands — C2S [u8 len][name], arch 4 (server handlers_social).
const SOCIAL_OPS := {
	"friend": 3129, "ami": 3129, "unfriend": 3133, "enemie": 3133,
	"ignore": 3131, "unignore": 3135,
}
signal emote(actor_id: int, anim: String)
signal trade(coach_name: String)
signal watch(coach_name: String)

var _pending_mails := []  # FIFO of {frame, to} — 15506 replies arrive in order


## Feed one S2C chat opcode. Returns true if the opcode was a chat message.
func feed(opcode: int, payload: WireReader) -> bool:
	match opcode:
		3152:  # VicinityContent
			var sname := payload.get_str("u8")
			var sid := int(payload.get_i64())
			var msg := payload.get_str("u16")
			_line("say", "%s: %s" % [sname, msg])
			bubble.emit(sid, msg)
		3154:  # PrivateContent — u8 body length (not u16!)
			var sname := payload.get_str("u8")
			payload.get_i64()
			var msg := payload.get_str("u8")
			_line("whisper", "[i]%s[/i] %s" % [
				I18n.t("chat.whisper_in", {"name": sname}), msg])
		3140:  # ChannelContent
			var chan := payload.get_str("u8")
			var sname := payload.get_str("u8")
			var msg := payload.get_str("u8")
			_line("channel", "[%s] %s: %s" % [chan, sname, msg])
		3168:  # TradeContent
			var sname := payload.get_str("u8")
			payload.get_i64()
			var msg := payload.get_str("u16")
			_line("trade", "[%s] %s: %s" % [I18n.t("chat.chan.trade"), sname, msg])
		3170:  # GroupContent
			var sname := payload.get_str("u8")
			payload.get_i64()
			var msg := payload.get_str("u16")
			_line("group", "[%s] %s: %s" % [I18n.t("chat.chan.group"), sname, msg])
		3198:  # ClanContent
			var sname := payload.get_str("u8")
			payload.get_i64()
			var msg := payload.get_str("u16")
			_line("clan", "[%s] %s: %s" % [I18n.t("chat.chan.clan"), sname, msg])
		3204:  # UserNotFound — [u8 name]
			var who := payload.get_str("u8")
			_line("error", "[i]%s[/i]" % I18n.t("chat.user_not_found", {"name": who}))
		2070:  # ServerMessage — i32 length, JVM-charset body
			var msg := payload.get_str("i32")
			_line("server", "[b]%s[/b] %s" % [I18n.t("chat.server"), msg])
		3206, 3210, 3212, 3214, 3216:
			_line("error", "[i]%s[/i]" % I18n.t(
				CHAT_ERROR_KEYS.get(opcode, "chat.err.malformed")))
		OP_EMOTE_PLAYED:  # [i64 actor][u8 anim] — relay to the world view
			var aid := int(payload.get_i64())
			var anim := payload.get_str("u8")
			emote.emit(aid, anim)
		15507:  # MailNameResult — [i64 coachId], 0 = no such coach
			var rid := int(payload.get_i64())
			var pm: Dictionary = _pending_mails.pop_front() \
				if not _pending_mails.is_empty() else {}
			if rid != 0 and not pm.is_empty():
				Session.send(539, pm.frame, 3)
			elif not pm.is_empty():
				_line("error", "[i]%s[/i]" % I18n.t(
					"chat.user_not_found", {"name": pm.to}))
		_:
			return false
	return true


func _on_submit(text: String) -> void:
	text = text.strip_edges()
	_input.clear()
	if text.is_empty() or Session.client == null:
		return
	_input.release_focus()

	# Slash commands: emotes, social lists, then channel prefixes.
	if text.begins_with("/"):
		var sp := text.find(" ")
		var cmd := text.substr(1, sp - 1 if sp > 0 else -1).to_lower()
		var rest := text.substr(sp + 1).strip_edges() if sp > 0 else ""
		if EMOTES.has(cmd):
			# Emote — C2S 4701 [u8 name][i32 id], arch 3; the server relays its
			# canonical anim name back via 4700, so no local echo is needed.
			var ew := WireWriter.new()
			var aname: String = EMOTES[cmd][1]
			ew.put_u8(aname.length())
			ew.put_bytes(aname.to_ascii_buffer())
			ew.put_i32(EMOTES[cmd][0])
			Session.send(OP_EMOTE_PLAY, ew.raw(), 3)
			return
		if SOCIAL_OPS.has(cmd):
			if rest.is_empty():
				_line("error", "[i]%s[/i]" % I18n.t("chat.usage.friend"))
				return
			var sw := WireWriter.new()
			var nb := CP1252.encode(rest)
			sw.put_u8(nb.size())
			sw.put_bytes(nb)
			Session.send(SOCIAL_OPS[cmd], sw.raw(), 4)
			return
		if cmd == "friends":
			if State.friends.is_empty():
				_line("server", "[i]%s[/i]" % I18n.t("chat.no_friends"))
			else:
				_line("server", I18n.t("chat.friends_list", {"list": ", ".join(
					State.friends.map(func(f): return "%s%s" % [f.name,
						"" if f.get("online", false)
						else " (%s)" % I18n.t("social.offline")]))}))
			return
		if cmd == "ignored":
			_line("server", I18n.t("chat.ignored_list", {"list": (
				", ".join(State.ignored) if not State.ignored.is_empty()
				else I18n.t("chat.none"))}))
			return
		if cmd == "mail":
			# Compose a letter — C2S 539 mail record (arch 3):
			# /mail <name> <title>|<body>. The whole family is UTF-8.
			var sp2 := rest.find(" ")
			var pipe := rest.find("|")
			if sp2 <= 0 or pipe < 0:
				_line("error", "[i]%s[/i]" % I18n.t("chat.usage.mail"))
				return
			var target := rest.substr(0, sp2)
			var title := rest.substr(sp2 + 1, pipe - sp2 - 1).strip_edges()
			var body := rest.substr(pipe + 1).strip_edges()
			var ew := WireWriter.new()
			var tb := title.to_utf8_buffer()
			ew.put_u16(1); ew.put_i32(tb.size()); ew.put_bytes(tb)
			var bb := body.to_utf8_buffer()
			ew.put_u16(2); ew.put_i32(bb.size()); ew.put_bytes(bb)
			var extra := ew.raw()
			var mw := WireWriter.new()
			mw.put_i64(0)                    # mail id — server assigns
			mw.put_i64(State.my_coach_id)
			var snb := State.my_coach_name.to_utf8_buffer()
			mw.put_u8(snb.size()); mw.put_bytes(snb)
			mw.put_i32(2)                    # senderGame — client sends 2
			mw.put_i64(0)                    # receiver id — resolved by name
			var rnb := target.to_utf8_buffer()
			mw.put_u8(rnb.size()); mw.put_bytes(rnb)
			mw.put_i32(extra.size()); mw.put_bytes(extra)
			mw.put_i64(0); mw.put_u8(0); mw.put_u8(0); mw.put_u8(0)
			mw.put_i32(0)
			# Retail validates the recipient first: 15506 [u8 len][utf8 name]
			# (arch 2) → 15507 [i64 coachId]; 0 refuses the send.
			_pending_mails.append({"frame": mw.raw(), "to": target})
			var ck := WireWriter.new()
			var cnb := target.to_utf8_buffer()
			ck.put_u8(cnb.size()); ck.put_bytes(cnb)
			Session.send(15506, ck.raw(), 2)
			return
		if cmd == "watch":
			# Spectate — resolve name → coach id, then 2260/26331.
			if rest.is_empty():
				_line("error", "[i]%s[/i]" % I18n.t("chat.usage.watch"))
				return
			watch.emit(rest)
			return
		if cmd == "trade":
			# Player exchange invite — the pane resolves name → coach id.
			if rest.is_empty():
				_line("error", "[i]%s[/i]" % I18n.t("chat.usage.trade"))
				return
			trade.emit(rest)
			return
		if cmd == "reset":
			# /resetPosition — 4514 empty (arch 3); the server teleports the
			# coach back to its spawn point (retail console command).
			Session.send(4514, PackedByteArray(), 3)
			return
		if cmd == "deletecoach":
			# 27529 (bl) — delete the whole coach; retail's confirm button
			# (jv_2) sends it then disconnects the session. Two-step: ask
			# for /deletecoach CONFIRM to keep it deliberate.
			if rest != "CONFIRM":
				_line("error", "[i]%s[/i]" % I18n.t("chat.deletecoach"))
				return
			_line("server", "[b]%s[/b]" % I18n.t("chat.deletecoach"))
			Session.send(27529, PackedByteArray(), 2)
			Session.client.disconnect_from()
			return
		if cmd == "guild":
			# Guild creation — C2S 509 [u8 type][u8 len][name], arch 3.
			# The 504 result + 510/552/512 state pushes + 558 feed answer it.
			if rest.is_empty():
				_line("error", "[i]%s[/i]" % I18n.t("chat.usage.guild"))
				return
			var gw := WireWriter.new()
			var nb := CP1252.encode(rest)
			gw.put_u8(0)
			gw.put_u8(nb.size())
			gw.put_bytes(nb)
			Session.send(509, gw.raw(), 3)
			return

	# Channel prefixes → dedicated pipes; unknown '/x' goes verbatim to the
	# server's GM-command handler on the vicinity op.
	var op := 3153
	var arch := 3
	var w := WireWriter.new()
	var body := text
	var label := "say"
	var priv_target := ""

	if text.begins_with("/w "):
		var rest := text.substr(3).strip_edges()
		var sp := rest.find(" ")
		if sp <= 0:
			_line("error", "[i]%s[/i]" % I18n.t("chat.usage.w"))
			return
		priv_target = rest.substr(0, sp)
		body = rest.substr(sp + 1).strip_edges()
		op = 3155
		arch = 4
		label = "whisper"
	elif text.begins_with("/t "):
		body = text.substr(3)
		op = 3159
		label = "trade"
	elif text.begins_with("/p "):
		body = text.substr(3)
		op = 3161
		label = "group"
	elif text.begins_with("/c "):
		body = text.substr(3)
		op = 3199
		arch = 2
		label = "clan"
	elif text.begins_with("/g "):
		# 3151 = the named-channel pipe; "*" is the global channel the
		# server fans out to every online coach (test channel_test.go).
		body = text.substr(3)
		op = 3151
		arch = 4
		label = "channel"
	elif text.begins_with("/s "):
		body = text.substr(3)

	match op:
		3151:
			w.put_u8(1)
			w.put_bytes("*".to_ascii_buffer())
			w.put_u8(CP1252.encode(body).size())
			w.put_bytes(CP1252.encode(body))
		3153, 3159:
			w.put_u16(CP1252.encode(body).size())
			w.put_bytes(CP1252.encode(body))
		3155:
			w.put_u8(CP1252.encode(priv_target).size())
			w.put_bytes(CP1252.encode(priv_target))
			w.put_u8(CP1252.encode(body).size())
			w.put_bytes(CP1252.encode(body))
		3161:
			w.put_i64(0)   # ally coach id — filled when group fights exist
			w.put_u16(CP1252.encode(body).size())
			w.put_bytes(CP1252.encode(body))
		3199:
			w.put_u16(CP1252.encode(body).size())
			w.put_bytes(CP1252.encode(body))
			w.put_i64(0)   # guild id — client has none yet

	Session.send(op, w.raw(), arch)

	# Local echo: the server never sends our own lines back.
	var me := State.my_coach_name
	match label:
		"say":
			_line("me", "%s: %s" % [me, body])
			bubble.emit(State.my_coach_id, body)
		"whisper":
			_line("whisper", "[i]%s[/i] %s" % [
				I18n.t("chat.whisper_out", {"name": priv_target}), body])
		"channel":
			_line("channel", "[*] %s: %s" % [me, body])
		_:
			_line(label, "%s: %s" % [me, body])


func _line(kind: String, s: String) -> void:
	_lines.append({"kind": kind, "text": "[color=%s]%s[/color]" % [
		COLORS.get(kind, "white"), s]})
	if _lines.size() > MAX_LINES:
		_lines.remove_at(0)
	if _tab == "all" or KIND_TAB.get(kind, "say") == _tab:
		_display.append_text(_lines.back().text + "\n")


func _render() -> void:
	_display.clear()
	for l in _lines:
		if _tab == "all" or KIND_TAB.get(l.kind, "say") == _tab:
			_display.append_text(l.text + "\n")


func log_line(s: String) -> void:
	_line("system", s)


func grab_chat_focus() -> void:
	_input.grab_focus()
