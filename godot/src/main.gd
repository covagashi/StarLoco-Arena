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
const Elements := preload("res://src/gamedata/elements.gd")
const Cards := preload("res://src/gamedata/cards.gd")
const Kanodo := preload("res://src/gamedata/kanodo.gd")

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
const OP_FIGHTER_ASSIGN := 6013          # [i64 fid][i16 src][i16 dst][i64 am]
const OP_TEAM_PRESET_SAVE := 6021        # [sw_1 blob][u8 pad]
const OP_TEAM_PRESET_SAVED := 6020       # [u8 status] — 0 ok / 25 name taken
const OP_TEAM_PRESET_DELETE := 6023      # [i64 team][i16 gm][i16 fa]
const OP_TEAM_PRESET_DELETED := 6022     # [u8 status][i16 teamId on ok]
const OP_COMBATTRE := 23103              # [i64 coachId][i16 teamId] ready-up
const OP_SEARCH_RESULT := 23104          # [i16 preset][u8 accepted]
const OP_SEARCH_CANCEL := 23101          # [i64 coachId][i16 teamId]
const OP_SEARCH_CANCEL_RESULT := 23102   # [u8 accepted]
const OP_FIGHT_STARTING := 23106         # empty — "Lancement du combat"
const OP_SEARCH_ERROR := 23108           # [u8 code]
const OP_CHALLENGE_INVITE := 26301       # [i64 target][u8 evo]
const OP_CHALLENGE_INVITATION := 26300   # [i64 handle][u8 out][u8 evo][u8 n]{str32}
const OP_CHALLENGE_ACCEPT := 26305       # [i64 handle][u8 evo]
const OP_CHALLENGE_ACCEPTED := 26302     # [i64 handle][u8 evo] → both confirm
const OP_CHALLENGE_DECLINE := 26307      # [i64 handle] decline/cancel
const OP_CHALLENGE_CANCELLED := 26304    # [i64 handle]
const OP_TEAM_CONFIRM := 26303           # [i64 coachId][i16 teamId]
const OP_ELEMENT_SPAWN := 200            # [i16 n]{i64 id, u16 len, part-table}
const OP_ELEMENT_DESPAWN := 206          # [i16 n]{i64 id}
const OP_ELEMENT_ACTION := 201           # C2S [i64 id][i16 actionOrdinal]
const OP_WALLET := 4001                  # [u8 n]{u8 ctype, i32 amount}
const OP_INVENTORY := 5200               # 4 sections — codec_overrides
const OP_SHOP_CATALOG := 5401            # [u8 mode][i32 shopId]{i32, u16}…
const OP_SHOP_RESULT := 5403             # [u8 result][u8 n]{u8, i32}
const OP_SHOP_BUY := 5450                # C2S [i32 shopId][i16 n]{i32 cardId}
const OP_SHOP_BARTER := 5400             # C2S [i32 shop][i16 n]{i32}[i16 m]{i32,u16}
const OP_ZAAP := 4512                    # C2S [i32 cardTemplateId]
const OP_TEAM_TEST := 26330              # C2S [i32 challengeOrType][i16 99|team]
const OP_FUSION_REQ := 5490              # C2S [i32 n]{i32 ids… target last}
const OP_FUSION_RESULT := 5491           # [u8 res][i32 got][i32 miss][i32 back]
const OP_USE_ITEM := 22099               # C2S [i64 fighterId][i32 cardId]
const OP_FIREWORK := 22095               # C2S [i32 card][i32 x][i32 y][i64 el]
const OP_FIREWORK_SHOW := 22094          # [i32 card][i32 x][i32 y][i32 z][i64 el]
const OP_DEMON_LADDER := 27510           # C2S [i16 demonId][i16 flag][i32 start]
const OP_DEMON_LADDER_RES := 27511       # ladder rows — codec_overrides
const OP_TOURN_CAL := 17002              # C2S empty
const OP_TOURN_CALENDAR := 17003         # calendar events — codec_overrides
const OP_TOURN_LIST := 28601             # C2S empty
const OP_TOURN_LIST_RES := 28602         # tournament rows — codec_overrides
const OP_TOURN_REGISTER := 4607          # C2S [i64 t][i64 coach][i16 -1][i32 0]
const OP_TOURN_REG_RES := 28608          # [i64 tid][i8 code]
const OP_TOURN_SEARCH_PERIOD := 28630    # [i64 tid][i8 open]
const OP_TOURN_SEARCH_RES := 28612       # [i64 tid][i16 preset][i8 accepted]
const OP_TOURN_SEARCH_ERR := 28616       # [i8 code][i8 sub]
const OP_TOURN_SEARCH_END := 28648       # [i64 tid][i8 forfeit]
const OP_GUILD_CREATE := 509             # C2S [u8 type][str8 name] arch 3
const OP_GUILD_RESULT := 504             # [i8 type][i32 code]
const OP_GUILD_FEED := 558               # [str8 coach][str8 guild]
const OP_DEMON_OFFER := 5470             # C2S [i16 demon][i16 n]{i32,i16 qty}
const OP_FRIEND_LIST := 3144             # [u8 n]{u16 len, friend blob}
const OP_IGNORE_LIST := 3146             # [u8 n]{str8 name}
const OP_FRIEND_ADDED := 3156            # [u8 name][u8 note][i64 id]…
const OP_IGNORE_ADDED := 3158            # [u8 name][u8 note]
const OP_FRIEND_REMOVED := 3160          # [u8 name]
const OP_IGNORE_REMOVED := 3162          # [u8 name]
const OP_FRIEND_ONLINE := 3148           # [u8 name]…[i64 id]…
const OP_FRIEND_OFFLINE := 3150          # [u8 name][u8 note]
const OP_IGNORE_ONLINE := 3164           # [u8 name][i64 id]
const OP_IGNORE_OFFLINE := 3166          # [u8 name]
const OP_MAILBOX_REQ := 15000            # C2S empty — opens the mailbox dialog
const OP_MAIL_LIST := 15001              # S2C [i16 n]{mail record}
const OP_MAIL_SEND_RES := 15003          # S2C [i64 result][mail record]
const OP_MAIL_DELETE := 15004            # C2S [u8 n]{i64 ids}
const OP_MAIL_NOTICE := 15005            # S2C [u8 newCount]
const OP_MAIL_TAKE := 15006              # C2S [i64 mailId][u8 pad]
const OP_MAIL_TAKEN := 15007             # S2C [i64 mail][i64 coach][u8 n]{i32}
const OP_EX_INVITE := 5101               # C2S [i64 targetCoachId]
const OP_EX_INVITATION := 5102           # S2C [i64 ex][i64 inviter][str8]
const OP_EX_ANSWER := 5103               # C2S [i64 ex][u8 accept]
const OP_EX_CONFIRM := 5104              # S2C [i8 result][i64 ex][i64 other]
const OP_EX_ADD := 5105                  # C2S [i64 ex][i32 card][u16 qty]
const OP_EX_REMOVE := 5107               # C2S same shape as 5105
const OP_EX_READY := 5109                # C2S [i64 ex] ready toggle
const OP_EX_CANCEL := 5111               # C2S [i64 ex]
const OP_EX_ADDED := 5110                # S2C [i64 ex][u8 side][i32 card][u16]
const OP_EX_REMOVED := 5112              # S2C same shape as 5110
const OP_EX_ERROR := 5113                # S2C [u8 code][i64 ex]
const OP_EX_END := 5114                  # S2C [u8 reason][i64 ex]
const OP_EX_USER_READY := 5116           # S2C [i64 ex][u8 side]
const ELEM_EXCHANGE := 100               # pseudo kind: ElementDlg in trade mode
const OP_SPHERE_BUY := 23009             # C2S [i64 fighter][i32 sphere][i32 card]

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
var _challenge_handle := -1   # pending 26300 handle (-1 = none)
var _challenge_target := -1   # coach id we clicked "challenge" on
var _challenge_evo := 0       # evolution flag echoed back on accept
var _searching := false       # combattre queue state (23104 ack)
var _shop_id := -1            # catalogue id echoed back on buy/barter
var _shop_cards := []         # [{id, qty}] of the open catalogue
var _barter_wanted := -1      # card id picked for exchange


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
	$UI/VBox/AuthRow/FightBtn.pressed.connect(_on_fight_pressed)
	$UI/VBox/AuthRow/CancelSearchBtn.pressed.connect(_on_cancel_search)
	log.bubble.connect(world.chat_bubble)
	log.emote.connect(world.emote)
	$UI/VBox/TeamRow/AssignBtn.pressed.connect(func(): _on_assign(true))
	$UI/VBox/TeamRow/UnassignBtn.pressed.connect(func(): _on_assign(false))
	$UI/VBox/TeamRow/SaveTeamBtn.pressed.connect(_open_save_team)
	$UI/VBox/TeamRow/DelTeamBtn.pressed.connect(_on_del_team)
	$UI/SaveTeamDlg/VBox/Btns/SaveBtn.pressed.connect(_on_save_team)
	$UI/SaveTeamDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/SaveTeamDlg.visible = false)
	$UI/ChallengeAskDlg.confirmed.connect(_send_challenge)
	$UI/ChallengeDlg.confirmed.connect(_answer_challenge.bind(true))
	$UI/ChallengeDlg.canceled.connect(_answer_challenge.bind(false))
	$UI/ExchangeAskDlg.confirmed.connect(_answer_exchange.bind(true))
	$UI/ExchangeAskDlg.canceled.connect(_answer_exchange.bind(false))
	$UI/Chat.trade.connect(_invite_exchange)
	$UI/TeamPickDlg/VBox/Btns/GoBtn.pressed.connect(_on_team_confirmed)
	$UI/TeamPickDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/TeamPickDlg.visible = false)
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
			$UI/VBox/RosterBox/RosterBtns/LoadoutBtn.disabled = false
			$UI/VBox/RosterBox/RosterBtns/KanodoBtn.disabled = false)
	$UI/VBox/RosterBox/RosterBtns/LoadoutBtn.pressed.connect(_open_loadout)
	$UI/VBox/RosterBox/RosterBtns/KanodoBtn.pressed.connect(_open_kanodo)
	$UI/KanodoDlg/VBox/Btns/CloseBtn.pressed.connect(
		func(): $UI/KanodoDlg.visible = false)
	$UI/KanodoDlg/VBox/Btns/BuyBtn.pressed.connect(_on_sphere_buy)
	$UI/KanodoDlg/VBox/Scroll/Board.sphere_clicked.connect(_on_sphere_pick)
	$UI/LoadoutDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/LoadoutDlg.visible = false)
	$UI/LoadoutDlg/VBox/Btns/SaveBtn.pressed.connect(_on_save_loadout)
	$UI/ShopDlg/VBox/Btns/CloseBtn.pressed.connect(
		func(): $UI/ShopDlg.visible = false)
	$UI/ShopDlg/VBox/Btns/BuyBtn.pressed.connect(_on_shop_buy)
	$UI/ShopDlg/VBox/Btns/TradeBtn.pressed.connect(_open_barter)
	$UI/ShopDlg/VBox/Scroll/Cards.item_selected.connect(_on_shop_pick)
	$UI/BarterDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/BarterDlg.visible = false)
	$UI/BarterDlg/VBox/Btns/TradeBtn.pressed.connect(_on_barter_trade)
	$UI/ElementDlg/VBox/Btns/CloseBtn.pressed.connect(
		func(): $UI/ElementDlg.visible = false)
	$UI/ElementDlg/VBox/Btns/ActBtn.pressed.connect(_on_element_act)
	$UI/ElementDlg/VBox/Btns/AltBtn.pressed.connect(_on_element_alt)
	$UI/ElementDlg/VBox/Scroll/List.multi_selected.connect(
		func(_i, _s): _on_fusion_inputs())
	$UI/ElementDlg/VBox/Scroll2/List2.item_selected.connect(
		func(_i): _on_fusion_inputs())


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
			State.guild = d.get("guild", {})
			if not State.guild.is_empty():
				_log_line("guild: '%s' — rank %s, demon %d" % [
					State.guild.get("guild", "?"),
					State.guild.get("rank_name", "?"),
					int(State.guild.get("demon_id", 0))])
			_log_line("[color=green]coach info received — in lobby[/color]")
		OP_ENTER_INSTANCE:
			var d := Codec.decode(opcode, payload)
			State.current_world = int(d.get("world_id", -1))
			State.elements = {}   # registry drops with the old world
			_my_pos = Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)),
				float(d.get("alt", 0)))
			_log_line("entering instance world=%d pos=(%s,%s)" % [
				State.current_world, d.get("x"), d.get("y")])
		OP_INSTANCE_READY:
			_log_line("[color=green]instance ready — in world[/color]")
			$UI/VBox/AuthRow/PracticeBtn.disabled = false
			$UI/VBox/AuthRow/FightBtn.disabled = false
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
			_refresh_presets()
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
		OP_SEARCH_RESULT:
			# 23104 [i16 preset][u8 accepted] — the "Recherche en cours" ack
			payload.get_i16()
			if payload.get_u8() == 1:
				_searching = true
				$UI/VBox/AuthRow/CancelSearchBtn.visible = true
				_log_line("searching for an opponent…")
		OP_SEARCH_CANCEL_RESULT:
			# 23102 [u8] — reply that closes the searching state
			payload.get_u8()
			_searching = false
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("search cancelled")
		OP_FIGHT_STARTING:
			# 23106 — paired, fight incoming (8000 follows)
			_searching = false
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("[color=green]opponent found — fight starting![/color]")
		OP_SEARCH_ERROR:
			var code := payload.get_u8()
			if code >= 3:
				_searching = false
				$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("[color=red]search error %d[/color]" % code)
		OP_CHALLENGE_INVITATION:
			# 26300 [i64 handle][u8 outgoing][u8 evo][u8 n]{[i32 len][name]}
			_challenge_handle = int(payload.get_i64())
			var outgoing := payload.get_u8()
			_challenge_evo = payload.get_u8()
			var cname := ""
			for i in payload.get_u8():
				cname = payload.get_str("i32")
			if outgoing:
				_log_line("challenge sent — waiting for %s…" % cname)
			else:
				$UI/ChallengeDlg.dialog_text = \
					"%s challenges you to a training fight — accept?" % cname
				$UI/ChallengeDlg.popup_centered()
		OP_CHALLENGE_ACCEPTED:
			# 26302 [i64 handle][u8 evo] — both sides now pick a team (26303)
			payload.get_i64()
			_challenge_evo = payload.get_u8()
			_log_line("[color=green]challenge accepted — pick your team[/color]")
			_open_team_pick()
		OP_CHALLENGE_CANCELLED:
			payload.get_i64()
			_challenge_handle = -1
			$UI/ChallengeDlg.hide()
			$UI/TeamPickDlg.visible = false
			_log_line("[i]challenge cancelled[/i]")
		OP_TEAM_PRESET_SAVED:
			# 6020 [u8 status] — only sent on failure (25 = name taken)
			var st := payload.get_u8()
			if st != 0:
				_log_line("[color=red]preset save refused, code %d[/color]" % st)
		OP_TEAM_PRESET_DELETED:
			# 6022 [u8 status][i16 teamId on success]
			if payload.get_u8() == 0:
				var tid := int(payload.get_i16())
				State.presets = State.presets.filter(
					func(p): return int(p.id) != tid)
				_refresh_presets()
		OP_ELEMENT_SPAWN:
			# 200 — world interactives entering the AoI: zaaps, card masters…
			var d := Codec.decode(opcode, payload)
			var table := Elements.for_world(State.current_world)
			for e in d.get("elements", []):
				var id := int(e.id)
				var info: Variant = table.get(id)
				e["kind"] = int(info.type) if info != null else -1
				if e.get("desc", "") == "" and info != null:
					e.desc = info.desc
				State.elements[id] = e
				world.element_spawned(e)
		OP_ELEMENT_DESPAWN:
			var d := Codec.decode(opcode, payload)
			for id in d.get("ids", []):
				State.elements.erase(int(id))
			world.element_despawned(d.get("ids", []))
		OP_WALLET:
			var d := Codec.decode(opcode, payload)
			for c in d.get("currencies", []):
				State.wallet[int(c.type)] = int(c.amount)
			_refresh_wallet_label()
		OP_INVENTORY:
			var d := Codec.decode(opcode, payload)
			State.inventory = {}
			for c in d.get("cards", []):
				State.inventory[int(c.card_id)] = int(c.qty)
			_log_line("inventory: %d card stack(s)" % State.inventory.size())
		OP_SHOP_CATALOG:
			var d := Codec.decode(opcode, payload)
			_open_shop(d)
		OP_SHOP_RESULT:
			var d := Codec.decode(opcode, payload)
			var res := int(d.result)
			if _awaiting_offer:
				# 5403 doubles as the demon-affiliation ack (server sends an
				# empty detail list) — label it as the offering result.
				_awaiting_offer = false
				if res == 0:
					_log_line("[color=green]demon accepted the offering[/color]")
				else:
					_log_line("[color=red]demon offering failed "
						+ "(guild leader + unaffiliated required)[/color]")
			else:
				for c in d.get("currencies", []):
					State.wallet[int(c.type)] = int(c.amount)
				_refresh_wallet_label()
				match res:
					0: _log_line("[color=green]shop: deal done[/color]")
					1: _log_line("[color=red]shop: not enough tokens[/color]")
					_: _log_line("[color=red]shop: refused (code %d)[/color]"
						% res)
		OP_FUSION_RESULT:
			var d := Codec.decode(opcode, payload)
			if int(d.get("result", 0)) != 0:
				_log_line("[color=red]fusion: request refused[/color]")
			elif int(d.get("obtained", 0)) > 0:
				_log_line("[color=green]fusion: got %s![/color]"
					% Cards.name_of(int(d.obtained)))
			elif int(d.get("not_obtained", 0)) > 0:
				_log_line("[color=red]fusion: missed %s[/color]"
					% Cards.name_of(int(d.not_obtained)))
			elif int(d.get("recovered", 0)) > 0:
				_log_line("fusion: leftovers returned (%s)"
					% Cards.name_of(int(d.recovered)))
			else:
				_log_line("[color=red]fusion failed — cards consumed[/color]")
		OP_DEMON_LADDER_RES:
			var d := Codec.decode(opcode, payload)
			if $UI/ElementDlg.visible and _elem_kind == 11:
				var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
				list.clear()
				for r0 in d.get("rows", []):
					list.add_item("%s  — %d pts" % [
						str(r0.get("name", "?")), int(r0.get("quarterly", 0))])
				$UI/ElementDlg/VBox/Hint.text = \
					"demon %d — %d clan(s), your affiliation: %d" % [
						int(d.get("demon", -1)), d.get("rows", []).size(),
						int(d.get("affiliation", 0))]
			else:
				_log_line("demon ladder: %d row(s)" % d.get("rows", []).size())
		OP_TOURN_CALENDAR, OP_TOURN_LIST_RES:
			var d := Codec.decode(opcode, payload)
			var rows: Array = d.get("events", d.get("tournaments", []))
			if $UI/ElementDlg.visible and _elem_kind == 13:
				var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
				for r0 in rows:
					var tid := int(r0.get("id", r0.get("tid", -1)))
					var label := str(r0.get("name", "?"))
					if r0.get("reg_open", 1) == 0:
						label += "  (closed)"
					list.add_item(label)
					list.set_item_metadata(list.item_count - 1, tid)
				$UI/ElementDlg/VBox/Hint.text = "%d tournament(s)" % [
					$UI/ElementDlg/VBox/Scroll/List.item_count]
				var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
				act.text = "Register"
				act.visible = true
				act.disabled = true
			else:
				_log_line("tournaments: %d" % rows.size())
		OP_TOURN_REG_RES:
			var d := Codec.decode(opcode, payload)
			var tid := int(d.tournament_id)
			var msg := "registration accepted" if int(d.code) == 0 \
				else ("tournament full" if int(d.code) == 2
					else "registration refused (%d)" % int(d.code))
			if int(d.code) == 0:
				_registered_tids[tid] = true
			_log_line("tournament %d: %s" % [tid, msg])
			if $UI/ElementDlg.visible and _elem_kind == 13:
				$UI/ElementDlg/VBox/Hint.text = msg
		OP_TOURN_SEARCH_PERIOD:
			var d := Codec.decode(opcode, payload)
			_search_open[int(d.tournament_id)] = int(d.open) != 0
			_log_line("tournament %d opponent search %s" % [
				int(d.tournament_id),
				"OPEN" if int(d.open) != 0 else "closed"])
		OP_TOURN_SEARCH_RES:
			var d := Codec.decode(opcode, payload)
			_log_line("tournament %d search %s" % [int(d.tournament_id),
				"accepted — waiting for opponents"
				if int(d.accepted) != 0 else "refused"])
		OP_TOURN_SEARCH_ERR:
			var d := Codec.decode(opcode, payload)
			_log_line("[color=red]tournament search error %d/%d[/color]" % [
				int(d.code), int(d.sub_code)])
		OP_TOURN_SEARCH_END:
			var d := Codec.decode(opcode, payload)
			_log_line("tournament %d search ended%s" % [int(d.tournament_id),
				" — winner by forfeit" if int(d.forfeit) != 0 else ""])
		28614:  # TournamentFightStarting [i64 tid] — bracket match launching
			var d := Codec.decode(opcode, payload)
			_log_line("tournament %d: fight starting!" % int(d.f0))
		OP_GUILD_RESULT:
			var d := Codec.decode(opcode, payload)
			match int(d.code):
				403: _log_line("[color=green]guild created[/color]")
				404: _log_line("[color=green]joined the guild[/color]")
				11: _log_line("[color=red]guild name invalid or taken[/color]")
				20: _log_line("[color=red]guild is full[/color]")
				35: _log_line("[color=red]guild: coach not found[/color]")
				40: _log_line("[color=red]guild invite refused[/color]")
				_: _log_line("guild result %d" % int(d.code))
		OP_GUILD_FEED:
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s founded the guild '%s'[/i]" % [d.coach, d.guild])
		510:  # GuildRecord — guild name/demon/rank table for our guild
			var d := Codec.decode(opcode, payload)
			State.guild["guild_id"] = int(d.guild_id)
			State.guild["guild"] = d.name
			State.guild["demon_id"] = int(d.demon_id)
			State.guild["ranks"] = d.ranks
		552:  # GuildMembership — my own rank/demon row (part 2)
			var d := Codec.decode(opcode, payload)
			for row in d.rows:
				State.guild.merge(row, true)
			if not State.guild.is_empty():
				_log_line("guild membership: '%s' — %s (demon %d)" % [
					State.guild.get("guild", "?"),
					State.guild.get("rank_name", "?"),
					int(State.guild.get("demon_id", 0))])
		512:  # GuildMembers — the roster (part 0 rows)
			var d := Codec.decode(opcode, payload)
			State.guild["members"] = d.rows
			var names := []
			for m in d.rows:
				names.append("%s%s" % [m.get("name", "?"),
					"*" if m.get("online", false) else ""])
			_log_line("guild roster: %s" % ", ".join(names))
		554:  # GuildTags — clan tags for nearby coaches (name labels)
			var d := Codec.decode(opcode, payload)
			for row in d.rows:
				if world.has_method("set_coach_guild"):
					world.set_coach_guild(int(row.coach_id), row.guild)
		556:  # GuildMemberGone — a coach left/was kicked
			var d := Codec.decode(opcode, payload)
			if int(d.coach_id) == State.my_coach_id:
				State.guild = {}
				_log_line("[i]you are no longer in a guild[/i]")
			else:
				_log_line("[i]coach %d left the guild[/i]" % int(d.coach_id))
		560:  # GuildMemberFeed — "X joined / X was thrown out"
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s %s[/i]" % [d.coach,
				"was kicked out of the guild" if int(d.removed) != 0
				else "joined the guild"])
		OP_MAIL_LIST:
			var d := Codec.decode(opcode, payload)
			_mails = d.mails
			if $UI/ElementDlg.visible and _elem_kind == 2:
				_fill_mails()
			_log_line("mailbox: %d letter(s)" % _mails.size())
		OP_MAIL_SEND_RES:
			var d := Codec.decode(opcode, payload)
			var res := int(d.result)
			if res > 0:
				_log_line("[color=green]mail %d sent to %s[/color]" % [
					res, d.mail.get("receiver", "?")])
			elif res == -2:
				_log_line("[color=red]mail refused: mailbox full or "
					+ "unknown recipient[/color]")
			else:
				_log_line("[color=red]mail send failed (%d)[/color]" % res)
		OP_MAIL_NOTICE:
			var d := Codec.decode(opcode, payload)
			_log_line("[i]you have %d new letter(s)[/i]" % int(d.new_count))
		OP_MAIL_TAKEN:
			var d := Codec.decode(opcode, payload)
			for cid in d.cards:
				State.inventory[int(cid)] = int(
					State.inventory.get(int(cid), 0)) + 1
			if int(d.coach_id) == State.my_coach_id and not d.cards.is_empty():
				_log_line("[color=green]collected: %s[/color]" % ", ".join(
					d.cards.map(func(c): return Cards.name_of(int(c)))))
			# Drop the emptied mail from the open mailbox.
			for i in range(_mails.size() - 1, -1, -1):
				if int(_mails[i].get("id", -1)) == int(d.mail_id):
					_mails[i]["cards"] = []
			if $UI/ElementDlg.visible and _elem_kind == 2:
				_fill_mails()
		OP_EX_INVITATION:
			var d := Codec.decode(opcode, payload)
			_ex = {"id": int(d.ex_id), "my_side": 1,
				"other_name": d.inviter, "accepted": false,
				"staged": {0: {}, 1: {}}, "ready": {0: false, 1: false}}
			$UI/ExchangeAskDlg.dialog_text = \
				"%s wants to trade with you." % d.inviter
			$UI/ExchangeAskDlg.popup_centered()
		OP_EX_CONFIRM:
			var d := Codec.decode(opcode, payload)
			match int(d.result):
				0:  # pending — we invited; keep the id, wait for the answer
					if _ex.is_empty():
						_ex = {"my_side": 0, "other_name": "?"}
					_ex.id = int(d.ex_id)
					_ex["staged"] = {0: {}, 1: {}}
					_ex["ready"] = {0: false, 1: false}
					_ex["accepted"] = false
					_log_line("trade invitation sent…")
				2:
					_log_line("[color=red]trade refused[/color]")
					_ex = {}
					if _elem_kind == ELEM_EXCHANGE:
						$UI/ElementDlg.visible = false
				3:
					_ex["accepted"] = true
					_log_line("[color=green]trade accepted[/color]")
					_open_exchange()
		OP_EX_ADDED:
			var d := Codec.decode(opcode, payload)
			var side := int(d.side)
			_ex.staged[side][int(d.card)] = int(d.qty)
			_refresh_exchange()
		OP_EX_REMOVED:
			var d := Codec.decode(opcode, payload)
			_ex.staged[int(d.side)].erase(int(d.card))
			_refresh_exchange()
		OP_EX_USER_READY:
			var d := Codec.decode(opcode, payload)
			_ex.ready[int(d.side)] = true
			var who: String = "You" if int(d.side) == _ex.get("my_side", -1) \
				else _ex.get("other_name", "?")
			_log_line("%s %s ready" % [who,
				"are" if int(d.side) == _ex.get("my_side", -1) else "is"])
			_refresh_exchange()
		OP_EX_ERROR:
			var d := Codec.decode(opcode, payload)
			_log_line("[color=red]trade error: %s[/color]" % (
				"they already own that unique card" if int(d.code) == 1
				else "card is linked / undestructible"))
		OP_EX_END:
			var d := Codec.decode(opcode, payload)
			_log_line("[color=green]trade complete[/color]"
				if int(d.reason) == 0 else "[i]trade cancelled[/i]")
			_ex = {}
			if _elem_kind == ELEM_EXCHANGE:
				$UI/ElementDlg.visible = false
		OP_FIREWORK_SHOW:
			var d := Codec.decode(opcode, payload)
			_log_line("firework! %s at (%d,%d)" % [
				Cards.name_of(int(d.get("card", 0))),
				int(d.get("x", 0)), int(d.get("y", 0))])
		OP_FRIEND_LIST:
			var d := Codec.decode(opcode, payload)
			State.friends = d.get("friends", [])
			if not State.friends.is_empty():
				_log_line("friends: %s" % ", ".join(
					State.friends.map(func(f): return str(f.name))))
		OP_IGNORE_LIST:
			var d := Codec.decode(opcode, payload)
			State.ignored = d.get("names", [])
			if not State.ignored.is_empty():
				_log_line("ignored: %s" % ", ".join(State.ignored))
		OP_FRIEND_ADDED:
			var d := Codec.decode(opcode, payload)
			State.friends.append({"name": d.name,
				"id": int(d.get("id", -1)), "online": true, "notify": 1})
			_log_line("[color=light_green]%s added to friends[/color]" % d.name)
		OP_FRIEND_REMOVED:
			var d := Codec.decode(opcode, payload)
			State.friends = State.friends.filter(
				func(f): return f.name != d.name)
			_log_line("%s removed from friends" % d.name)
		OP_IGNORE_ADDED:
			var d := Codec.decode(opcode, payload)
			State.ignored.append(d.name)
			_log_line("[i]%s ignored[/i]" % d.name)
		OP_IGNORE_REMOVED:
			var d := Codec.decode(opcode, payload)
			State.ignored.erase(d.name)
			_log_line("%s un-ignored" % d.name)
		OP_FRIEND_ONLINE:
			var d := Codec.decode(opcode, payload)
			for f in State.friends:
				if f.name == d.name:
					f.online = true
					f.id = int(d.get("id", -1))
			_log_line("[color=light_green]%s is online[/color]" % d.name)
		OP_FRIEND_OFFLINE:
			var d := Codec.decode(opcode, payload)
			for f in State.friends:
				if f.name == d.name:
					f.online = false
			_log_line("[i]%s went offline[/i]" % d.name)
		OP_IGNORE_ONLINE:
			var d := Codec.decode(opcode, payload)
			_log_line("[i](ignored) %s is online[/i]" % d.name)
		OP_IGNORE_OFFLINE:
			var d := Codec.decode(opcode, payload)
			_log_line("[i](ignored) %s went offline[/i]" % d.name)
		OP_FIGHT_ERROR:
			var d := Codec.decode(opcode, payload)
			_log_line("[color=red]fight refused (code %d)[/color]"
				% int(d.get("f1", -1)))
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
		var mpos := world.get_global_mouse_position()
		var who: int = world.actor_at(mpos)
		if who >= 0:
			_challenge_target = who
			$UI/ChallengeAskDlg.dialog_text = \
				"Challenge %s to a training fight?" % world.actor_name(who)
			$UI/ChallengeAskDlg.popup_centered()
			return
		var elem: int = world.element_at(mpos)
		if elem >= 0:
			_use_element(elem)
			return
		var cell: Variant = world.screen_to_cell(mpos)
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


## --- Combattre: ranked search queue -------------------------------------
## 23103 [i64 allyCoach][i16 teamId] — pairs with the next coach that
## readies up; server replies 23104 (searching) then 23106 + 8000 on pair.
func _on_fight_pressed() -> void:
	if _searching:
		return
	var w := WireWriter.new()
	w.put_i64(State.my_coach_id)
	w.put_i16(_selected_preset_id())
	Session.send(OP_COMBATTRE, w.raw(), 2)
	_log_line("combattre sent — team %d" % _selected_preset_id())


## 23101 [i64 coachId][i16 teamId] — the classic overlay's Cancel.
func _on_cancel_search() -> void:
	var w := WireWriter.new()
	w.put_i64(State.my_coach_id)
	w.put_i16(_selected_preset_id())
	Session.send(OP_SEARCH_CANCEL, w.raw(), 2)


## Preset id of the TeamRow selection, or -1 (server falls back to the
## titular roster — tolerated on every team-carrying request).
func _selected_preset_id() -> int:
	var sel: int = $UI/VBox/TeamRow/Preset.selected
	if sel <= 0:
		return -1
	return $UI/VBox/TeamRow/Preset.get_item_id(sel)


func _refresh_presets() -> void:
	for opt_path in ["UI/VBox/TeamRow/Preset", "UI/TeamPickDlg/VBox/Pick"]:
		var opt: OptionButton = get_node(opt_path)
		# keep the user's selection across server re-pushes (6030 lands after
		# every roster/team mutation)
		var keep := -1
		if opt.selected > 0:
			keep = opt.get_item_id(opt.selected)
		opt.clear()
		opt.add_item("(titular roster)", -1)
		for p in State.presets:
			if int(p.type) == -4:
				continue  # synthetic bench row
			opt.add_item("%s (%d fighters)" % [p.name, p.fighters.size()],
				int(p.id))
		for i in opt.item_count:
			if opt.get_item_id(i) == keep:
				opt.select(i)
				break


## --- Direct challenge (training fight between two coaches) --------------
## 26301 [i64 target][u8 evo] → both sides get 26300; target accepts with
## 26305, either side declines/cancels with 26307; on 26302 both send 26303.
func _send_challenge() -> void:
	if _challenge_target < 0:
		return
	var w := WireWriter.new()
	w.put_i64(_challenge_target)
	w.put_u8(0)   # evolution flag — classic training fight
	Session.send(OP_CHALLENGE_INVITE, w.raw(), 2)


func _answer_challenge(accept: bool) -> void:
	if _challenge_handle < 0:
		return
	var w := WireWriter.new()
	w.put_i64(_challenge_handle)
	if accept:
		w.put_u8(_challenge_evo)  # 26305 echoes the invite's flag; 26307 is bare
	Session.send(OP_CHALLENGE_ACCEPT if accept
		else OP_CHALLENGE_DECLINE, w.raw(), 2)
	if not accept:
		_challenge_handle = -1


## After 26302 both coaches confirm a team with 26303 [i64 self][i16 team].
func _open_team_pick() -> void:
	$UI/TeamPickDlg.visible = true


func _on_team_confirmed() -> void:
	$UI/TeamPickDlg.visible = false
	var pick: OptionButton = $UI/TeamPickDlg/VBox/Pick
	var team_id := -1
	if pick.selected > 0:
		team_id = pick.get_item_id(pick.selected)
	var w := WireWriter.new()
	w.put_i64(State.my_coach_id)
	w.put_i16(team_id)
	Session.send(OP_TEAM_CONFIRM, w.raw(), 2)
	_log_line("team confirmed (%d) — waiting for opponent…" % team_id)


## --- Team presets ----------------------------------------------------------
## 6013 [i64 fid][i16 srcTeam][i16 dstTeam][i64 am] — drag-drop wire form.
func _on_assign(add: bool) -> void:
	var roster_list: ItemList = $UI/VBox/RosterBox/Roster
	var sel := roster_list.get_selected_items()
	var team_id := _selected_preset_id()
	if sel.is_empty() or team_id <= 0:
		_log_line("[i]select a roster fighter and a preset first[/i]")
		return
	var fid: int = roster_list.get_item_metadata(sel[0])
	var w := WireWriter.new()
	w.put_i64(fid)
	w.put_i16(-1 if add else team_id)   # src: pool (-1) when adding
	w.put_i16(team_id if add else -1)   # dst: pool (-1) when removing
	w.put_i64(State.my_coach_id)
	Session.send(OP_FIGHTER_ASSIGN, w.raw(), 2)
	_log_line("assign %s sent (fid %d %s team %d)" % [
		"6013", fid, "→" if add else "←", team_id])


## 6023 [i64 teamId][i16 gm][i16 fa] — delete the selected preset.
func _on_del_team() -> void:
	var team_id := _selected_preset_id()
	if team_id <= 0:
		return
	var w := WireWriter.new()
	w.put_i64(team_id)
	w.put_i16(0)
	w.put_i16(0)
	Session.send(OP_TEAM_PRESET_DELETE, w.raw(), 2)


func _open_save_team() -> void:
	var box: VBoxContainer = $UI/SaveTeamDlg/VBox/Scroll/Fighters
	for c in box.get_children():
		c.queue_free()
	for f in State.roster:
		var cb := CheckBox.new()
		cb.text = "%s (%s)" % [f.get("name", "?"),
			State.BREED_NAMES.get(int(f.get("breed", 0)), "?")]
		cb.set_meta("id", int(f.get("id", 0)))
		cb.button_pressed = true
		box.add_child(cb)
	$UI/SaveTeamDlg.visible = true


## 6021 — sw_1 blob [i16 type=0][i16 teamId=0][i16 gameMode=1][str8 name]
## [u8 n]{i64 fighter, i64 ownerCoach}[u8 0 coaches] + trailing u8 pad.
func _on_save_team() -> void:
	var tname: String = $UI/SaveTeamDlg/VBox/Name.text.strip_edges()
	if tname.is_empty():
		_log_line("[color=red]team needs a name[/color]")
		return
	var w := WireWriter.new()
	w.put_i16(0)
	w.put_i16(0)
	w.put_i16(1)
	var nb := CP1252.encode(tname)
	w.put_u8(nb.size())
	w.put_bytes(nb)
	var members := []
	for cb in $UI/SaveTeamDlg/VBox/Scroll/Fighters.get_children():
		if cb.button_pressed:
			members.append(int(cb.get_meta("id")))
	w.put_u8(members.size())
	for fid in members:
		w.put_i64(fid)
		w.put_i64(State.my_coach_id)
	w.put_u8(0)   # coach list — solo preset
	w.put_u8(0)   # trailing pad byte
	Session.send(OP_TEAM_PRESET_SAVE, w.raw(), 2)
	$UI/SaveTeamDlg.visible = false
	_log_line("team preset '%s' sent (%d fighters)" % [tname, members.size()])


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


## --- Interactive elements (200/201/206) -------------------------------------
## Click on a world marker → INTERACTIVE_ELEMENT_ACTION 201 [i64 id][i16 ordinal]
## (arch 3). The server only answers for kinds with server-side follow-up
## (Card Master pushes the 5401 catalogue); the rest open client-local dialogs.
var _elem_id := -1            # element the ElementDlg is showing
var _elem_kind := -1          # env type of that element
var _elem_offer := false      # kind-11 dialog switched to card-offer mode
var _demon_id := -1           # demon of the totem being offered to
var _awaiting_offer := false  # a 5470 basket is in flight → next 5403 is its ack
var _search_open := {}        # tournament id -> opponent-search period open
var _registered_tids := {}    # tournament ids this coach is registered in
var _mails := []              # decoded mail records for the open mailbox
var _ex := {}                 # active exchange {id, my_side, other_name,
                              # staged:{0:{card:qty},1:{}}, ready:{0,1}}
var _kanodo_fid := -1         # fighter id of the open Kanodo board
var _kanodo_pick := {}        # sphere node selected on the board


func _use_element(id: int) -> void:
	var e: Dictionary = world.element_info(id)
	var kind := int(e.get("kind", -1))
	var w := WireWriter.new()
	w.put_i64(id)
	w.put_i16(0)   # action ordinal — first action of the element's list
	Session.send(OP_ELEMENT_ACTION, w.raw(), 3)
	var label := Elements.kind_name(kind)
	_elem_id = id
	_elem_kind = kind
	_elem_offer = false
	match kind:
		1:   # Card Master — server pushes the 5401 catalogue
			_log_line("%s — opening shop…" % label)
		4:   # Zaap — local dialog of owned Zaap cards (type 20) → 4512
			_open_zaap()
		2:   # Mailbox — the server answers 15000 with the full list (15001)
			_element_text("Mailbox", "Loading letters…")
			Session.send(OP_MAILBOX_REQ, PackedByteArray(), 3)
		10:  # Graveyard — dead/interred fighters + resurrection cards
			_open_graveyard()
		14:  # Fusion altar — feed same-set cards at a target → 5490
			_open_fusion()
		3, 7: # Challenge / Demon challenge — accept bubble → 26330
			_open_challenge_bubble(e)
		5:   # Breed Master — recruit text; the "test" button runs 26330 too
			_open_challenge_bubble(e)
		11:  # Demon totem — ladder page requested with 27510, shown on 27511
			_open_demon_totem(e)
		13:  # Tournament totem — calendar (17002) + list (28601)
			_open_tournament_totem()
		12:  # Firework launcher — pick a card → 22095 → 22094 echo
			_open_firework(e)
		_:   # Demons (6/9), NPC talkers (15) — local text bubble
			_element_text(label, "…")


## Generic element dialog: title + hint + a list + two optional action
## buttons. _elem_kind decides what ActBtn/AltBtn do.
func _element_text(title: String, hint: String) -> void:
	$UI/ElementDlg/VBox/Title.text = title
	$UI/ElementDlg/VBox/Hint.text = hint
	_elem_offer = false
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.clear()
	list.select_mode = ItemList.SELECT_SINGLE
	$UI/ElementDlg/VBox/Scroll2.visible = false
	$UI/ElementDlg/VBox/Btns/ActBtn.visible = false
	$UI/ElementDlg/VBox/Btns/AltBtn.visible = false
	$UI/ElementDlg.visible = true


## desc is the element's ";" descriptor — decode the numeric fields.
func _desc_fields(desc: String) -> Array:
	var out := []
	for f in desc.split(";"):
		out.append(int(f) if f.is_valid_int() else -1)
	return out


## Graveyard: dead (2) / interred (3) fighters from the roster, plus the owned
## resurrection cards (type with a resurrect% action). Pick a fighter, Act =
## 22099 [i64 fighterId][i32 cardId] spending the first owned revive card.
func _open_graveyard() -> void:
	_element_text("Graveyard", "Dead fighters:")
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	var dead := 0
	for f in State.roster:
		var st := int(f.get("state", 0))
		if st == 2 or st == 3:
			dead += 1
			list.add_item("%s  (breed %d, %s)" % [
				f.get("name", "?"), int(f.get("breed", 0)),
				"interred" if st == 3 else "dead"])
			list.set_item_metadata(list.item_count - 1, int(f.get("id", -1)))
	if dead == 0:
		$UI/ElementDlg/VBox/Hint.text = "No dead fighters."
		return
	var revive := -1
	for cid in State.inventory:
		if int(Cards.meta(int(cid)).get("resurrect", 0)) > 0:
			revive = int(cid)
			break
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	if revive < 0:
		$UI/ElementDlg/VBox/Hint.text += "  (no resurrection card owned)"
	else:
		act.text = "Resurrect (%s)" % Cards.name_of(revive)
		act.disabled = true
		act.visible = true
		list.item_selected.connect(
			func(_i): act.disabled = false, CONNECT_ONE_SHOT)


## Fusion altar: multi-select inventory cards as inputs (≥2 of one set), pick
## the target from List2 (every template in the inputs' set), Fuse → 5490.
func _open_fusion() -> void:
	_element_text("Fusion altar", "")
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.select_mode = ItemList.SELECT_MULTI
	for cid in State.inventory:
		var m := Cards.meta(int(cid))
		if not m.get("tradable", false):
			continue
		list.add_item("%s  ×%d" % [
			Cards.name_of(int(cid)), int(State.inventory[cid])])
		list.set_item_metadata(list.item_count - 1, int(cid))
	$UI/ElementDlg/VBox/Scroll2.visible = true
	$UI/ElementDlg/VBox/Btns/ActBtn.visible = true
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.text = "Fuse"
	act.disabled = true
	_on_fusion_inputs()


## Recompute the fusion target list + button state from the input selection.
func _on_fusion_inputs() -> void:
	if _elem_kind != 14:
		return
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	var list2: ItemList = $UI/ElementDlg/VBox/Scroll2/List2
	var inputs := []
	var set_id := -1
	var mixed := false
	for idx in list.get_selected_items():
		var cid := int(list.get_item_metadata(idx))
		inputs.append(cid)
		var s := int(Cards.meta(cid).get("set", 0))
		if set_id == -1:
			set_id = s
		elif s != set_id:
			mixed = true
	list2.clear()
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.disabled = true
	if inputs.size() < 2:
		$UI/ElementDlg/VBox/Hint.text = "Pick 2+ cards of one set to feed…"
		return
	if mixed or set_id <= 0:
		$UI/ElementDlg/VBox/Hint.text = "Inputs must share a card set."
		return
	# Every template of the set is a legal target (need not be owned).
	for cid in Cards.all_ids():
		if int(Cards.meta(cid).get("set", 0)) == set_id:
			list2.add_item("%s  (value %d)" % [
				Cards.name_of(cid), Cards.value_of(cid)])
			list2.set_item_metadata(list2.item_count - 1, cid)
	$UI/ElementDlg/VBox/Hint.text = "Now pick the card to fuse toward…"


## Challenge bubble (env 3/7 desc idx2 = challengeId; breed master idx4):
## Accept → 26330 [i32 challengeId][i16 99] (arch 2 — challengeAcceptBreed).
var _bubble_challenge := -1

func _open_challenge_bubble(e: Dictionary) -> void:
	var fields := _desc_fields(str(e.get("desc", "")))
	# Demon challenge & plain challenge carry it at index 2; the Breed Master
	# layout is name;txt;txt;breed;challenge → index 4.
	_bubble_challenge = int(fields[4]) if _elem_kind == 5 \
		and fields.size() > 4 else (int(fields[2]) if fields.size() > 2 else -1)
	var title := Elements.kind_name(_elem_kind)
	if _elem_kind == 5:
		title = "Breed Master — test fight"
	_element_text(title, "Challenge #%d — accept?"
		% _bubble_challenge)
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.text = "Accept"
	act.visible = true
	act.disabled = _bubble_challenge < 0
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Refuse"
	alt.visible = true


## Demon totem → 27510 [i16 demon][i16 flag][i32 startRank]; desc = demon id.
## The dialog fills in when 27511 lands (handled in _on_message).
func _open_demon_totem(e: Dictionary) -> void:
	var fields := _desc_fields(str(e.get("desc", "")))
	var demon := int(fields[0]) if fields.size() > 0 else -1
	_demon_id = demon
	var hint := "Requesting ladder…"
	if int(State.guild.get("demon_id", 0)) != 0:
		hint += " — guild already serves demon %d" % \
			int(State.guild.get("demon_id"))
	_element_text("Demon totem %d" % demon, hint)
	# Retail gates the affiliate control on rank 1 AND demon_id == 0
	# (pq_1.java:56 guildCanAffiliate) — mirror it on the Alt button.
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Offer cards"
	alt.visible = int(State.guild.get("rank_level", 0)) == 1 \
		and int(State.guild.get("demon_id", 0)) == 0
	var w := WireWriter.new()
	w.put_i16(demon)
	w.put_i16(0)
	w.put_i32(0)
	Session.send(OP_DEMON_LADDER, w.raw(), 2)


## Tournament totem → 17002 (calendar) + 28601 (list), both empty, arch 3/2.
func _open_tournament_totem() -> void:
	_element_text("Tournament totem", "Requesting tournaments…")
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	if not list.item_selected.is_connected(_on_tournament_sel):
		list.item_selected.connect(_on_tournament_sel)
	Session.send(OP_TOURN_CAL, PackedByteArray(), 3)
	Session.send(OP_TOURN_LIST, PackedByteArray(), 2)


func _on_tournament_sel(i: int) -> void:
	# The List's item_selected is shared across element dialogs — ignore
	# selections that aren't this totem's rows (stale callback, empty list).
	if _elem_kind != 13:
		return
	$UI/ElementDlg/VBox/Btns/ActBtn.disabled = false
	# "Find opponent" (retail "Combattre") only makes sense for a
	# tournament we're in AND whose search window is open (28630).
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	var tid := int(list.get_item_metadata(i))
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Find opponent"
	alt.visible = _registered_tids.has(tid) \
		and _search_open.get(tid, false)


## Mailbox pane — filled when MAIL_LIST (15001) lands: sender + title per
## row, body preview in the hint, "Take cards" armed by attachments and
## "Delete" always available.
func _fill_mails() -> void:
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.clear()
	for i in _mails.size():
		var m: Dictionary = _mails[i]
		var title: String = m.get("title", "")
		var label := "%s: %s" % [m.get("sender", "?"),
			title if title != "" else "(no subject)"]
		if not m.get("cards", []).is_empty():
			label += "  [%d card(s)]" % m.cards.size()
		if not m.get("read", true):
			label = "* " + label
		list.add_item(label)
		list.set_item_metadata(i, i)
	$UI/ElementDlg/VBox/Hint.text = "%d letter(s) — select to read" % _mails.size()
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.text = "Take cards"
	act.visible = true
	act.disabled = true
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Delete"
	alt.visible = true
	alt.disabled = true
	if not list.item_selected.is_connected(_on_mail_sel):
		list.item_selected.connect(_on_mail_sel)


## --- Kanodo (sphere board) --------------------------------------------------
## Roster → Kanodo opens the board of the selected EVOLUTION fighter (type 2 —
## classic fighters carry no sphere tail on the wire). Buying is optimistic
## like retail: 23009 is fire-and-forget; the server validates reachability,
## XP and barrier cards and persists silently. We mirror the same rules for
## what can be clicked (lit frontier = server's Reachable flood).
const KIND_LABEL := {
	"spell": "new spell", "bonus": "bonus", "malus": "malus (a sacrifice)",
	"summon": "summon mastery", "barrier": "barrier — needs a card",
	"teleport": "portal", "item": "equipment set", "deadend": "dead end",
	"empty": "path",
}

func _open_kanodo() -> void:
	var roster_list: ItemList = $UI/VBox/RosterBox/Roster
	var sel := roster_list.get_selected_items()
	if sel.is_empty():
		return
	var f: Variant = _fighter_by_id(
		roster_list.get_item_metadata(sel[0]))
	if f == null or int(f.get("type", 1)) != 2:
		_log_line("[i]Kanodo is for evolution fighters only[/i]")
		return
	_kanodo_fid = int(f.id)
	_kanodo_pick = {}
	$UI/KanodoDlg/VBox/Title.text = "Kanodo — %s" % f.get("name", "?")
	$UI/KanodoDlg/VBox/Hint.text = "Click a lit sphere."
	$UI/KanodoDlg/VBox/Btns/BuyBtn.disabled = true
	_refresh_kanodo()
	$UI/KanodoDlg.visible = true


func _fighter_by_id(fid: int) -> Variant:
	for fr in State.roster:
		if int(fr.get("id", -1)) == fid:
			return fr
	return null


func _refresh_kanodo() -> void:
	var f: Variant = _fighter_by_id(_kanodo_fid)
	if f == null:
		$UI/KanodoDlg.visible = false
		return
	var board := int(f.get("board", 0))
	if board == 0:
		board = Kanodo.board_id_for_breed(int(f.get("breed", 0)))
	var cursor := Vector2i(int(f.get("sphere_x", 0)),
		int(f.get("sphere_y", 0)))
	if cursor == Vector2i.ZERO:
		var root: Array = Kanodo.boards.get(board, {}).get("root", [0, 0])
		cursor = Vector2i(int(root[0]), int(root[1]))
	$UI/KanodoDlg/VBox/XP.text = "xp %d / %d total" % [
		int(f.get("xp", 0)), int(f.get("total_xp", 0))]
	$UI/KanodoDlg/VBox/Scroll/Board.set_state(board,
		f.get("spheres", []), cursor)


func _on_sphere_pick(n: Dictionary) -> void:
	_kanodo_pick = n
	var kind := String(n.get("kind", "empty"))
	var lines := ["sphere %d  (%d,%d) — %s" % [
		int(n.id), int(n.x), int(n.y), KIND_LABEL.get(kind, kind)]]
	if int(n.get("spell", 0)) != 0:
		lines.append("→ %s" % Spells.name_of(int(n.spell)))
	if int(n.get("pool", 0)) != 0:
		lines.append("→ equipment set %d" % int(n.pool))
	if n.get("barrier", []).size() > 0:
		var names := []
		for c in n.barrier:
			names.append(Cards.name_of(int(c)))
		lines.append("needs one of: %s" % ", ".join(names))
	if n.get("fx", []).size() > 0:
		lines.append("effect %s" % str(n.fx))
	lines.append("cost %d xp" % int(n.get("xp", 0)))
	$UI/KanodoDlg/VBox/Hint.text = "\n".join(lines)
	var board := $UI/KanodoDlg/VBox/Scroll/Board
	$UI/KanodoDlg/VBox/Btns/BuyBtn.disabled = \
		not board._lit.has(int(n.id)) or not Kanodo.has_payload(n)


func _on_sphere_buy() -> void:
	var f: Variant = _fighter_by_id(_kanodo_fid)
	if f == null or _kanodo_pick.is_empty():
		return
	var card := 0
	if String(_kanodo_pick.get("kind", "")) == "barrier":
		for c in _kanodo_pick.get("barrier", []):
			if int(State.inventory.get(int(c), 0)) > 0:
				card = int(c)
				break
		if card == 0:
			$UI/KanodoDlg/VBox/Hint.text += \
				"\n[color=red]no accepted card in inventory[/color]"
			return
	var cost := int(_kanodo_pick.get("xp", 0))
	if f.spheres.has(int(_kanodo_pick.id)):
		cost /= 10   # re-purchase discount (afb_1 case 16926)
	if int(f.get("xp", 0)) < cost:
		$UI/KanodoDlg/VBox/Hint.text += "\n[color=red]not enough xp[/color]"
		return
	var w := WireWriter.new()
	w.put_i64(_kanodo_fid)
	w.put_i32(int(_kanodo_pick.id))
	w.put_i32(card)
	Session.send(OP_SPHERE_BUY, w.raw(), 3)
	# optimistic apply (retail awu_0): cursor walks onto the node
	f.sphere_x = int(_kanodo_pick.x)
	f.sphere_y = int(_kanodo_pick.y)
	if not f.spheres.has(int(_kanodo_pick.id)):
		f.spheres.append(int(_kanodo_pick.id))
	f.xp = int(f.xp) - cost
	_log_line("Kanodo: sphere %d bought (-%d xp)" % [
		int(_kanodo_pick.id), cost])
	_refresh_kanodo()


func _on_mail_sel(i: int) -> void:
	# Stale selections from other element dialogs would index into the
	# (usually empty) _mails — guard on the open pane being the mailbox.
	if _elem_kind != 2 or i >= _mails.size():
		return
	var m: Dictionary = _mails[i]
	var body: String = m.get("body", "")
	$UI/ElementDlg/VBox/Hint.text = body if body != "" else "(empty letter)"
	$UI/ElementDlg/VBox/Btns/ActBtn.disabled = m.get("cards", []).is_empty()
	$UI/ElementDlg/VBox/Btns/AltBtn.disabled = false


## --- Player exchange (5101-5116) --------------------------------------------
## /trade <name> invites; 5102 asks the target; 5104 accepted opens the pane.
## List (top) = the trade table ("You:/Name:" rows — click own row to unstage,
## 5107); List2 (bottom) = own tradable inventory — click rows to stage (5105
## qty 1). Act = ready toggle (5109), Alt = cancel (5111). Both-ready commits
## server-side and ends with 5114.
func _invite_exchange(cname: String) -> void:
	var tid: int = world.coach_id_by_name(cname)
	if tid < 0:
		_log_line("[color=red]no coach '%s' nearby[/color]" % cname)
		return
	_invite_exchange_id(tid, cname)


func _invite_exchange_id(tid: int, cname := "") -> void:
	_ex = {"my_side": 0, "other_name": cname, "accepted": false}
	var w := WireWriter.new()
	w.put_i64(tid)
	Session.send(OP_EX_INVITE, w.raw(), 3)


func _answer_exchange(accept: bool) -> void:
	if _ex.is_empty():
		return
	var w := WireWriter.new()
	w.put_i64(int(_ex.id))
	w.put_u8(1 if accept else 0)
	Session.send(OP_EX_ANSWER, w.raw(), 3)
	if not accept:
		_ex = {}


func _open_exchange() -> void:
	_elem_kind = ELEM_EXCHANGE
	_element_text("Exchange — %s" % _ex.get("other_name", "?"),
		"Click your cards below to stage them.")
	_elem_kind = ELEM_EXCHANGE   # _element_text does not reset the kind
	var list2: ItemList = $UI/ElementDlg/VBox/Scroll2/List2
	list2.clear()
	list2.select_mode = ItemList.SELECT_SINGLE
	for cid in State.inventory:
		if not Cards.meta(int(cid)).get("tradable", false):
			continue
		list2.add_item("%s  ×%d" % [
			Cards.name_of(int(cid)), int(State.inventory[cid])])
		list2.set_item_metadata(list2.item_count - 1, int(cid))
	$UI/ElementDlg/VBox/Scroll2.visible = true
	if not list2.item_selected.is_connected(_exchange_add):
		list2.item_selected.connect(_exchange_add)
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	if not list.item_selected.is_connected(_exchange_unstage_row):
		list.item_selected.connect(_exchange_unstage_row)
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.text = "Ready"
	act.visible = true
	act.disabled = false
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Cancel trade"
	alt.visible = true
	alt.disabled = false
	_refresh_exchange()


func _exchange_add(i: int) -> void:
	if _elem_kind != ELEM_EXCHANGE or _ex.is_empty() \
			or not _ex.get("accepted", false):
		return
	var list2: ItemList = $UI/ElementDlg/VBox/Scroll2/List2
	var w := WireWriter.new()
	w.put_i64(int(_ex.id))
	w.put_i32(int(list2.get_item_metadata(i)))
	w.put_u16(1)
	Session.send(OP_EX_ADD, w.raw(), 3)


func _exchange_unstage_row(i: int) -> void:
	if _elem_kind != ELEM_EXCHANGE or _ex.is_empty():
		return
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	var meta: Variant = list.get_item_metadata(i)
	if typeof(meta) != TYPE_DICTIONARY \
			or int(meta.get("side", -1)) != int(_ex.my_side):
		return   # only own staged rows come off the table
	var w := WireWriter.new()
	w.put_i64(int(_ex.id))
	w.put_i32(int(meta.card))
	w.put_u16(1)
	Session.send(OP_EX_REMOVE, w.raw(), 3)


func _refresh_exchange() -> void:
	if _elem_kind != ELEM_EXCHANGE or not $UI/ElementDlg.visible:
		return
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.clear()
	for side in [int(_ex.get("my_side", 0)),
			1 - int(_ex.get("my_side", 0))]:
		var who: String = "You" if side == int(_ex.my_side) \
			else _ex.get("other_name", "?")
		for card in _ex.staged[side]:
			list.add_item("%s: %s ×%d" % [
				who, Cards.name_of(int(card)), int(_ex.staged[side][card])])
			list.set_item_metadata(list.item_count - 1,
				{"side": side, "card": int(card)})
	var me_r: bool = _ex.ready.get(int(_ex.my_side), false)
	var them_r: bool = _ex.ready.get(1 - int(_ex.my_side), false)
	$UI/ElementDlg/VBox/Hint.text = "ready: you %s / %s %s" % [
		"✓" if me_r else "·", _ex.get("other_name", "?"),
		"✓" if them_r else "·"]


## Firework launcher — pick any owned card; launch → 22095 [i32 card][i32 x]
## [i32 y][i64 elementId]; the server echoes 22094 for everyone nearby.
func _open_firework(e: Dictionary) -> void:
	_element_text("Fireworks", "Pick a card to launch:")
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	for cid in State.inventory:
		list.add_item("%s  ×%d" % [
			Cards.name_of(int(cid)), int(State.inventory[cid])])
		list.set_item_metadata(list.item_count - 1, int(cid))
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.text = "Launch"
	act.visible = true
	act.disabled = true
	list.item_selected.connect(
		func(_i): act.disabled = false, CONNECT_ONE_SHOT)


## ElementDlg primary button — dispatched on the element kind being shown.
func _on_element_act() -> void:
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	match _elem_kind:
		10:  # graveyard resurrect
			var sel := list.get_selected_items()
			if sel.is_empty():
				return
			var revive := -1
			for cid in State.inventory:
				if int(Cards.meta(int(cid)).get("resurrect", 0)) > 0:
					revive = int(cid)
					break
			if revive < 0:
				return
			var w := WireWriter.new()
			w.put_i64(int(list.get_item_metadata(sel[0])))
			w.put_i32(revive)
			Session.send(OP_USE_ITEM, w.raw(), 3)
			$UI/ElementDlg.visible = false
			_log_line("resurrect card used: %s" % Cards.name_of(revive))
		14:  # fusion — inputs + the List2 target LAST (server reads it so)
			var inputs := []
			for idx in list.get_selected_items():
				inputs.append(int(list.get_item_metadata(idx)))
			var list2: ItemList = $UI/ElementDlg/VBox/Scroll2/List2
			var sel2 := list2.get_selected_items()
			if inputs.size() < 2 or sel2.is_empty():
				return
			var w := WireWriter.new()
			w.put_i32(inputs.size() + 1)
			for cid in inputs:
				w.put_i32(cid)
			w.put_i32(int(list2.get_item_metadata(sel2[0])))
			Session.send(OP_FUSION_REQ, w.raw(), 3)
			$UI/ElementDlg.visible = false
			_log_line("fusion sent: %d cards → %s" % [inputs.size(),
				Cards.name_of(int(list2.get_item_metadata(sel2[0])))])
		3, 7, 5:  # challenge accepted
			var w := WireWriter.new()
			w.put_i32(_bubble_challenge)
			w.put_u16(99)
			Session.send(OP_TEAM_TEST, w.raw(), 2)
			$UI/ElementDlg.visible = false
			_log_line("challenge %d accepted" % _bubble_challenge)
		13:  # tournament register → 4607 [tid][coach][preset=-1][card=0]
			var sel := list.get_selected_items()
			if sel.is_empty():
				return
			var w := WireWriter.new()
			w.put_i64(int(list.get_item_metadata(sel[0])))
			w.put_i64(State.my_coach_id)
			w.put_i16(-1)
			w.put_i32(0)
			Session.send(OP_TOURN_REGISTER, w.raw(), 3)
			_log_line("tournament register sent (tid %d)"
				% int(list.get_item_metadata(sel[0])))
		11:  # demon offering — only meaningful in offer mode
			if not _elem_offer:
				return
			var offers := []
			for idx in list.get_selected_items():
				offers.append(int(list.get_item_metadata(idx)))
			if offers.is_empty() or _demon_id < 0:
				return
			var w := WireWriter.new()
			w.put_i16(_demon_id)
			w.put_i16(offers.size())
			for cid in offers:
				w.put_i32(cid)
				w.put_i16(1)
			_awaiting_offer = true
			Session.send(OP_DEMON_OFFER, w.raw(), 3)
			$UI/ElementDlg.visible = false
			_log_line("demon %d offering sent: %d card(s)" % [
				_demon_id, offers.size()])
		ELEM_EXCHANGE:  # "Ready" toggle → 5109
			var w := WireWriter.new()
			w.put_i64(int(_ex.id))
			Session.send(OP_EX_READY, w.raw(), 3)
		2:   # mailbox "Take cards" → 15006 [i64 id][u8 pad]
			var sel := list.get_selected_items()
			if sel.is_empty():
				return
			var m: Dictionary = _mails[int(list.get_item_metadata(sel[0]))]
			if m.get("cards", []).is_empty():
				return
			var w := WireWriter.new()
			w.put_i64(int(m.id))
			w.put_u8(0)
			Session.send(OP_MAIL_TAKE, w.raw(), 3)
			_log_line("collecting %d card(s) from mail %d…" % [
				m.cards.size(), int(m.id)])
		12:  # firework
			var sel := list.get_selected_items()
			if sel.is_empty():
				return
			var e: Dictionary = world.element_info(_elem_id)
			var pos: Vector3i = e.get("pos", Vector3i.ZERO)
			var w := WireWriter.new()
			w.put_i32(int(list.get_item_metadata(sel[0])))
			w.put_i32(pos.x)
			w.put_i32(pos.y)
			w.put_i64(_elem_id)
			Session.send(OP_FIREWORK, w.raw(), 3)
			$UI/ElementDlg.visible = false


func _on_element_alt() -> void:
	if _elem_kind == ELEM_EXCHANGE:
		# "Cancel trade" → 5111; the server broadcasts 5114 reason 1.
		var w := WireWriter.new()
		w.put_i64(int(_ex.id))
		Session.send(OP_EX_CANCEL, w.raw(), 3)
		return
	if _elem_kind == 2:
		# "Delete" → 15004 [u8 n]{i64 ids} — the client drops the row at
		# once; the server answers nothing.
		var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
		var sel := list.get_selected_items()
		if sel.is_empty():
			return
		var idx := int(list.get_item_metadata(sel[0]))
		var m: Dictionary = _mails[idx]
		var w := WireWriter.new()
		w.put_u8(1)
		w.put_i64(int(m.id))
		Session.send(OP_MAIL_DELETE, w.raw(), 3)
		_mails.remove_at(idx)
		_fill_mails()
		_log_line("mail %d deleted" % int(m.id))
		return
	if _elem_kind == 13:
		# Opponent search → 28611 [i64 tid][i64 coach][i16 preset], arch 2.
		# Retail sends pseudo-preset 99 from the Tournois tab's Combattre.
		var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
		var sel := list.get_selected_items()
		if sel.is_empty():
			return
		var w := WireWriter.new()
		w.put_i64(int(list.get_item_metadata(sel[0])))
		w.put_i64(State.my_coach_id)
		w.put_i16(99)
		Session.send(28611, w.raw(), 2)
		_log_line("tournament search sent (tid %d)"
			% int(list.get_item_metadata(sel[0])))
		return
	if _elem_kind == 11 and not _elem_offer:
		# "Offer cards" — the affiliate basket: multi-pick tradable cards,
		# Act sends 5470 [demon][n]{id, qty=1}. Guild leaders only per server.
		_elem_offer = true
		var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
		list.clear()
		list.select_mode = ItemList.SELECT_MULTI
		for cid in State.inventory:
			if not Cards.meta(int(cid)).get("tradable", false):
				continue
			list.add_item("%s  ×%d" % [
				Cards.name_of(int(cid)), int(State.inventory[cid])])
			list.set_item_metadata(list.item_count - 1, int(cid))
		$UI/ElementDlg/VBox/Title.text = "Demon %d — offering" % _demon_id
		$UI/ElementDlg/VBox/Hint.text = \
			"Pick cards to give (reputation = their value):"
		var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
		act.text = "Offer"
		act.visible = true
		act.disabled = false
		return
	$UI/ElementDlg.visible = false


## Zaap dialog: reuse the shop panel in "teleport" mode — the stocked list is
## our own type-20 cards (Zaap destinations); clicking one sends 4512.
var _zaap_mode := false

func _open_zaap() -> void:
	var list: ItemList = $UI/ShopDlg/VBox/Scroll/Cards
	list.clear()
	var owned := []
	for cid in State.inventory:
		if int(Cards.meta(int(cid)).get("type", 0)) == 20:
			owned.append(int(cid))
	owned.sort()
	_zaap_mode = true
	_shop_cards = []
	for cid in owned:
		list.add_item("%s  ×%d" % [Cards.name_of(cid), State.inventory[cid]])
		list.set_item_metadata(list.item_count - 1, cid)
	$UI/ShopDlg/VBox/Title.text = "Zaap"
	$UI/ShopDlg/VBox/Hint.text = "Pick a destination."
	$UI/ShopDlg/VBox/Btns/BuyBtn.text = "Teleport"
	$UI/ShopDlg/VBox/Btns/TradeBtn.visible = false
	$UI/ShopDlg.visible = true
	_on_shop_pick(-1)


## --- Card Master shop --------------------------------------------------------
## 5401 catalogue → list of cards w/ names+prices. Buy sends 5450
## [i32 shopId][i16 n]{i32 cardId}; Exchange opens the barter pane (5400).
func _open_shop(d: Dictionary) -> void:
	_zaap_mode = false
	_shop_id = int(d.get("shop_id", -1))
	_shop_cards = d.get("cards", [])
	var list: ItemList = $UI/ShopDlg/VBox/Scroll/Cards
	list.clear()
	for c in _shop_cards:
		var cid := int(c.id)
		var price := Cards.price_text(cid)
		var line := "%s  ×%d" % [Cards.name_of(cid), int(c.qty)]
		line += "  (%s)" % price if price != "" else "  (barter only)"
		list.add_item(line)
		list.set_item_metadata(list.item_count - 1, cid)
	$UI/ShopDlg/VBox/Title.text = "Card Master"
	$UI/ShopDlg/VBox/Hint.text = "Click a card — buy with tokens, or exchange yours."
	$UI/ShopDlg/VBox/Btns/BuyBtn.text = "Buy (tokens)"
	$UI/ShopDlg/VBox/Btns/TradeBtn.visible = true
	_refresh_wallet_label()
	$UI/ShopDlg.visible = true
	_on_shop_pick(-1)


func _on_shop_pick(_idx: int) -> void:
	var list: ItemList = $UI/ShopDlg/VBox/Scroll/Cards
	var sel := list.get_selected_items()
	var has := not sel.is_empty()
	$UI/ShopDlg/VBox/Btns/BuyBtn.disabled = not has
	$UI/ShopDlg/VBox/Btns/TradeBtn.disabled = not has and not _zaap_mode
	if _zaap_mode:
		$UI/ShopDlg/VBox/Btns/BuyBtn.text = "Teleport"
	elif has:
		var cid := int(list.get_item_metadata(sel[0]))
		$UI/ShopDlg/VBox/Btns/BuyBtn.disabled = \
			not _priced(cid) or not _affordable(cid)


func _priced(cid: int) -> bool:
	for t in Cards.meta(cid).get("price", {}):
		if int(Cards.meta(cid).price[t]) > 0:
			return true
	return false


func _affordable(cid: int) -> bool:
	for t in Cards.meta(cid).get("price", {}):
		var amt := int(Cards.meta(cid).price[t])
		if amt > 0 and int(State.wallet.get(int(t), 0)) < amt:
			return false
	return true


func _on_shop_buy() -> void:
	var list: ItemList = $UI/ShopDlg/VBox/Scroll/Cards
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	var cid := int(list.get_item_metadata(sel[0]))
	if _zaap_mode:
		var w := WireWriter.new()
		w.put_i32(cid)
		Session.send(OP_ZAAP, w.raw(), 3)
		$UI/ShopDlg.visible = false
		_log_line("zaap: %s" % Cards.name_of(cid))
		return
	var w := WireWriter.new()
	w.put_i32(_shop_id)
	w.put_u16(1)
	w.put_i32(cid)
	Session.send(OP_SHOP_BUY, w.raw(), 3)
	_log_line("buy 5450 sent: %s" % Cards.name_of(cid))


## Barter: offer owned tradable cards whose summed value ≥ wanted card's.
func _open_barter() -> void:
	var list: ItemList = $UI/ShopDlg/VBox/Scroll/Cards
	var sel := list.get_selected_items()
	if sel.is_empty():
		return
	_barter_wanted = int(list.get_item_metadata(sel[0]))
	var wanted_value := Cards.value_of(_barter_wanted)
	$UI/BarterDlg/VBox/Wanted.text = "wanted: %s (value %d)" % [
		Cards.name_of(_barter_wanted), wanted_value]
	var box: VBoxContainer = $UI/BarterDlg/VBox/Scroll/Mine
	for c in box.get_children():
		c.queue_free()
	for cid in State.inventory:
		var meta := Cards.meta(int(cid))
		if not meta.get("tradable", false):
			continue
		for i in mini(int(State.inventory[cid]), 9):
			var cb := CheckBox.new()
			cb.text = "%s (value %d)" % [Cards.name_of(int(cid)),
				Cards.value_of(int(cid))]
			cb.set_meta("id", int(cid))
			cb.toggled.connect(func(_on): _update_barter_sum())
			box.add_child(cb)
	$UI/BarterDlg.visible = true
	_update_barter_sum()


func _update_barter_sum() -> void:
	var total := 0
	for cb in $UI/BarterDlg/VBox/Scroll/Mine.get_children():
		if cb.button_pressed:
			total += Cards.value_of(int(cb.get_meta("id")))
	$UI/BarterDlg/VBox/Sum.text = "offered value: %d / %d" % [
		total, Cards.value_of(_barter_wanted)]
	$UI/BarterDlg/VBox/Btns/TradeBtn.disabled = \
		total < Cards.value_of(_barter_wanted) or total <= 0


## 5400 [i32 shopId][i16 nWanted]{i32 cardId}[i16 nGiven]{i32 cardId, u16 qty}
func _on_barter_trade() -> void:
	var given := {}
	for cb in $UI/BarterDlg/VBox/Scroll/Mine.get_children():
		if cb.button_pressed:
			var cid := int(cb.get_meta("id"))
			given[cid] = int(given.get(cid, 0)) + 1
	var w := WireWriter.new()
	w.put_i32(_shop_id)
	w.put_u16(1)
	w.put_i32(_barter_wanted)
	w.put_u16(given.size())
	for cid in given:
		w.put_i32(cid)
		w.put_u16(given[cid])
	Session.send(OP_SHOP_BARTER, w.raw(), 3)
	$UI/BarterDlg.visible = false
	_log_line("barter 5400 sent: %d cards for %s" % [
		given.values().reduce(func(a, b): return a + b, 0),
		Cards.name_of(_barter_wanted)])


func _refresh_wallet_label() -> void:
	var parts := []
	for t in State.wallet:
		parts.append("%d t%d" % [int(State.wallet[t]), int(t)])
	var node: Label = $UI/ShopDlg/VBox/Wallet
	node.text = "wallet: %s" % (", ".join(parts) if parts else "—")
