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
const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const Topology := preload("res://src/maps/topology.gd")
const Scenarios := preload("res://src/gamedata/scenarios.gd")

const OP_CLIENT_VERSION := 7
const OP_CLIENT_AUTH := 1025
const OP_INVALID_VERSION := 8
const OP_AUTH_RESULT := 1024
const OP_COACH_CREATE_REQ := 2048
const OP_COACH_CREATE := 2049
const OP_COACH_CREATION_RESULT := 2050
const OP_COACH_INFO := 2052
const OP_ENTER_INSTANCE := 4600
const OP_INSTANCE_READY := 4516
const OP_ACTOR_SPAWN := 4096
const OP_ACTOR_DESPAWN := 4098
const OP_ACTOR_MOVEMENT := 4500
const OP_ACTOR_TELEPORTS := 4510         # S2C [i64 id][i32 x][i32 y][i16 z]
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
const OP_DUO_REQUEST := 6024             # C2S [str8 team][i64 me][i64 mate]
const OP_DUO_INVITATION := 6025          # S2C [str8 team][str8 who][i64][i64]
const OP_DUO_ANSWER := 6026              # C2S [i8 ok][str8 team][i64][i64][i16]
const OP_DUO_REFUSED := 6027             # S2C empty
const OP_DUO_ACCEPTED := 6028            # S2C empty — duo formed
const OP_DUO_GONE := 6029                # S2C partner left
const OP_SPECTATE_QUERY := 2260          # C2S [i64 coach] — spectatable?
const OP_SPECTATE_REPLY := 2261          # S2C [i8 0/1]
const OP_SPECTATE_JOIN := 26331          # C2S [i64 coach] arch 2
const OP_SPECTATE_DOWN := 26332          # S2C empty — teardown
const OP_LADDER_1V1_REQ := 27500         # C2S [i32 start] arch 2
const OP_LADDER_1V1 := 27501
const OP_LADDER_GUILD_REQ := 27502       # C2S [i16 board][i32 start]
const OP_LADDER_GUILD := 27503
const OP_LADDER_2V2_REQ := 27504         # C2S [i32 start]
const OP_LADDER_2V2 := 27505
const OP_LADDER_TOURN_REQ := 27506       # C2S [i32x3][u8 m][u8 t][u16 y]
const OP_LADDER_TOURN := 27507
const OP_LADDER_COACH_REQ := 27508       # C2S [i32 start]
const OP_LADDER_COACH := 27509
const OP_LADDER_DEMON_REQ := 27512       # C2S [i16 flag][i32 start]
const OP_LADDER_DEMON := 27513
const OP_LADDER_PRO_REQ := 27514         # C2S [i32 start][i32 lg][i32 pg]
const OP_LADDER_PRO := 27515
const OP_END_FIGHT := 8300               # S2C result screen — needs 26321 ack
const OP_END_FIGHT_DONE := 26321         # C2S empty — returns coach to overworld
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
const OP_EQUIP_REQ := 5201               # C2S 14×i32 coach equip layout, arch 3
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
const OP_DESTROY_COACH := 27529          # C2S empty (arch 2) — delete coach
const OP_GUILD_CREATE := 509             # C2S [u8 type][str8 name] arch 3
const OP_GUILD_RESULT := 504             # [i8 type][i32 code]
const OP_GUILD_FEED := 558               # [str8 coach][str8 guild]
const OP_GUILD_INVITE := 501             # C2S [u8 type][u8 mode][str8|i64][i64 gid] arch 8
const OP_GUILD_INVITATION := 502         # S2C [u8 type][str8 i][str8 g]
const OP_GUILD_INV_ANSWER := 503         # C2S [u8 type][u8 yes][str8 i][str8 g] arch 8
const OP_GUILD_LEAVE := 505              # C2S [i64 gid][i64 member] arch 8 — self=leave
const OP_GUILD_DESTROY := 511            # C2S [i64 gid] arch 2
const OP_GUILD_SET_RANK := 515           # C2S [i64 gid][i64 member][u16 lvl] arch 8
const OP_GUILD_GET := 517                # C2S [i64 player] arch 2 — refresh own guild
const OP_GUILD_MEMBERS := 519            # C2S [i64 guild] arch 2 — 512 roster re-push
const OP_GUILD_RANK_ADD := 553           # C2S [i64 gid][i32 rights][str8 name] arch 2
const OP_GUILD_RANK_MOD := 555           # C2S [i64 gid][i32 rights][u16 lvl x2][str8 name] arch 2
const OP_GUILD_RANK_DEL := 557           # C2S [i64 gid][u16 lvl] arch 2
const OP_GUILD_MEMBER_STATS := 2600      # C2S [i64 member] arch 2
const OP_GUILD_MEMBER_REPORT := 2601     # S2C [i64][str16 name][u16 len][stats]
const OP_QUICK_SEARCH := 2301            # C2S [i16 1][i16 type][i32 0] arch 2
const OP_QUICK_SEARCH_ACK := 2304        # S2C empty — search live
const OP_QUICK_CANCEL := 2303            # C2S empty arch 2
const OP_QUICK_CANCEL_RES := 2306        # S2C [u8 result]
const OP_MATCH_FOUND := 23110            # S2C — codec_overrides
const OP_MATCH_ACCEPT := 23114           # C2S [i64 m][i64 opp][i16][i16][i32 n][i64xn][u8]
const OP_MATCH_CONFIRM := 23116          # S2C [i32 n] — 0 = fell through
const OP_EVO_CANCEL := 23001             # C2S [i64 me][i16 99] arch 2
const OP_EVO_CANCEL_RES := 23002         # S2C [i8 accepted]
const OP_EVO_SEARCH := 23003             # C2S [i64 me][i16 99] arch 2
const OP_EVO_SEARCH_RES := 23004         # S2C [i16 preset][u8 accepted]
const OP_EVO_STARTING := 23006           # S2C empty — fight incoming
const OP_EVO_ERROR := 23008              # S2C [i8 code]
const OP_RECONNECT_Q := 26333            # S2C empty — resume fight?
const OP_RECONNECT_A := 26334            # C2S [u8 accept] arch 2
const OP_TOURN_TREE_REQ := 28649         # C2S [i64 tid][i32 page][str32 name]
const OP_TOURN_TREE := 28650             # S2C — codec_overrides
const OP_TOURN_CANCEL := 28609           # C2S [i64 tid][i64 me][i16 preset] arch 2
const OP_TOURN_CANCEL_RES := 28610       # S2C [i8 accepted]
const OP_FIGHTER_SET_STATE := 23000      # C2S [i64 fid][u8 legendary] arch 2
const OP_STAT_REQ := 22001               # C2S empty arch 2 — open criteria tab
const OP_STAT_DATA := 22002              # S2C — codec_overrides stat_data
const OP_STAT_UPD := 22003               # C2S [i16 id][u8 flag][i16 val] arch 2
const OP_STATS_REPORT := 2400            # S2C rs_2 stat map — coach report
const OP_STATS_PUSH := 2401              # S2C uf_0 stat map — login push
const OP_TUTORIAL_READY := 4517          # C2S empty arch 3 — aog_1 first-entry ack
const OP_RESET_POS := 4514               # C2S empty arch 3 — /resetPosition
const OP_DEMON_OFFER := 5470             # C2S [i16 demon][i16 n]{i32,i16 qty}
const OP_FRIEND_REMOVE := 21050          # C2S [str8 name] (uk_1.removeFromFriendList)
const OP_FRIEND_ADD := 21051             # C2S [str8 name]
const OP_IGNORE_REMOVE := 21052          # C2S [str8 name]
const OP_IGNORE_ADD := 21053             # C2S [str8 name]
const OP_GUILD_INVITE_BY_NAME := 21054   # C2S [str8 name]
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
const OP_MAIL_SEND := 539                # C2S full mail record arch 3
const OP_MAIL_SEND_RES := 15003          # S2C [i64 result][mail record]
const OP_MAIL_CHECK := 15506             # C2S [str8 name] — recipient check
const OP_MAIL_NAME_RES := 15507          # S2C [i64 coachId] — 0 = unknown
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
const ELEM_SCENARIO := -2                # pseudo kind: tutorial monologue (zone trigger)
const ELEM_RESULT := -3                  # pseudo kind: post-fight debrief (8300)
const ELEM_COACH := -4                   # pseudo kind: coach statistics (2401)
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
var _search_kind := 0         # 1=classic 2=quick 3=evolution (for cancel)
var _match := {}              # pending 23110 MatchFound row
var _shop_id := -1            # catalogue id echoed back on buy/barter
var _shop_cards := []         # [{id, qty}] of the open catalogue
var _barter_wanted := -1      # card id picked for exchange
var _gui: GuiLayer            # retail XULOR2 dialog layer
var _pending_login := ""      # login queued while connecting
var _pending_pass := ""       # password queued while connecting


func _ready() -> void:
	Session.connected.connect(_on_connected)
	Session.disconnected.connect(_on_disconnected)
	Session.message.connect(_on_message)
	# Re-entering after a fight: replay anything that arrived mid-scene-change.
	for m in Session.client.drain():
		_on_message(m.op, m.raw)
	Session.client.scene_active = true
	# retail XULOR2 layer — logonDialog replaces the wire-test login row
	_gui = GuiLayer.new()
	add_child(_gui)
	_gui.on("logon", _on_retail_logon)
	_gui.on("validateLoginForm", _on_retail_logon)
	_gui.on("createCoach", _on_coach_create)
	_gui.on("validateCoachCreationForm", _on_coach_create)
	_gui.on("createRandomCoach", _on_coach_random)
	_gui.on("setPreviousCoachDirection", _on_coach_dir.bind(-1))
	_gui.on("setNextCoachDirection", _on_coach_dir.bind(1))
	_gui.on("disconnect", func(_a, _w): Session.client.disconnect_from())
	# teamManagement / evolution namespace → the lobby fight screens
	_gui.on("launchEvolutionFight", func(_a, _w): _on_evo_search())
	_gui.on("launchTeamTest", func(_a, _w): _on_practice_pressed())
	_gui.on("createNewEvolutionFighter",
		func(a, w): _on_new_fighter_dialog(a, w, true))
	_gui.on("deleteFighter", _on_gui_delete_fighter)
	# dofusarena.evolution:* — teamManagementEvolution roster component
	_gui.on("selectFighter", _on_evo_select_fighter)
	_gui.on("changeFighterStatus", _on_evo_fighter_status)
	_gui.on("becomeALegend", _on_evo_become_legend)
	_gui.on("createNewFighter",
		func(a, w): _on_new_fighter_dialog(a, w, false))
	_gui.on("selectTeamPreset", _on_tm_select_preset)
	_gui.on("onFighterDropped", _on_tm_fighter_dropped)
	_gui.on("onFighterDroppedXvsX", _on_tm_fighter_dropped)
	_gui.on("deleteEditableTeamPreset", _on_tm_delete_preset)
	_gui.on("saveTeam", _on_tm_save_team)
	_gui.on("selectEditableFighter", _on_tm_select_editable_fighter)
	_gui.on("showHidePrebuildTeams", _on_tm_prebuild_toggle)
	_gui.on("addNewTeam", func(a, w): _on_tm_add_team(a, w, -6))
	_gui.on("addNewTournamentTeam",
		func(a, w): _on_tm_add_team(a, w, -5))
	_gui.on("addNewTeamXvsX", _on_tm_add_team_xvsx)
	_gui.on("selectTeamBackgroundColorIndex",
		func(a, w): _on_tm_pick_color(a, w,
			"selectedTeamBackground", "color"))
	_gui.on("selectTeamIconColorIndex",
		func(a, w): _on_tm_pick_color(a, w,
			"selectedTeamIcon", "color"))
	_gui.on("selectTeamBackground",
		func(a, w): _on_tm_pick_color(a, w,
			"selectedTeamBackground", "id"))
	_gui.on("selectTeamIcon",
		func(a, w): _on_tm_pick_color(a, w, "selectedTeamIcon", "id"))
	_gui.on("setClassicReadyForFight",
		func(_a, _w): _on_fight_pressed())
	_gui.on("launchLegendTest",
		func(_a, _w): _on_practice_pressed())
	# retail surfaces without a backing lane yet — tournaments, team-file
	# restore, and the hover popups the engine already owns.
	for m in ["validateTeamNameForm", "loadTeam", "selectTournament",
			"loadProfile", "deleteProfile", "setPlayerIndex",
			"setTournamentReadyForFight",
			"setLegendTournamentReadyForFight",
			"showFighterInfos", "hideFighterInfos"]:
		_gui.on(m, func(_a, _w): pass)
	_gui.on("openCloseSphereBoard", _on_evo_sphere_board)
	_gui.on("selectConsumableSet", _on_evo_select_set)
	_gui.on("goBackToList", _on_evo_back_to_list)
	_gui.on("selectCard", _on_evo_card_infos)
	_gui.on("showCoachCardInfosEvolution", _on_evo_card_infos)
	_gui.on("hideCoachCardInfosEvolution", func(_a, _w): pass)
	_gui.on("showPopup", func(_a, _w): pass)
	_gui.on("hidePopup", func(_a, _w): pass)
	_gui.on("editFighter", _on_eq_edit_fighter)
	# dofusarena.teamManagement:* — fighterEquipmentDialog loadout editor
	_gui.on("changeItemCardType", _on_eq_change_type)
	_gui.on("increaseList", func(a, w): _on_eq_page(a, w, 1))
	_gui.on("decreaseList", func(a, w): _on_eq_page(a, w, -1))
	_gui.on("addEquipment", _on_eq_add_equipment)
	_gui.on("removeEquipment", _on_eq_remove_equipment)
	_gui.on("addSpell", _on_eq_add_spell)
	_gui.on("removeSpell", _on_eq_remove_spell)
	_gui.on("dragEquipment", _on_eq_drag_equipment)
	_gui.on("dropEquipment", _on_eq_drop_equipment)
	_gui.on("dropSpell", _on_eq_drop_spell)
	_gui.on("validateEquipmentDrop", func(_a, _w): pass)
	_gui.on("validateSpellDrop", func(_a, _w): pass)
	_gui.on("showEquipmentInfos", _on_eq_show_infos)
	_gui.on("showSpellInfos", _on_eq_show_infos)
	_gui.on("showHelp", _on_eq_show_help)
	_gui.on("saveEditableFighter", _on_eq_save)
	_gui.on("closeFighterEditionDialog",
		func(_a, _w): _gui.close("fighterEquipmentDialog"))
	_gui.on("createFighter", _on_gui_create_fighter)
	_gui.on("closeFighterCreationDialog",
		func(_a, _w): _gui.close("fighterCreationDialog"))
	_gui.on("setFighterBreedId", _on_fighter_set.bind("breedId"))
	_gui.on("setFighterSkinColorIndex", _on_fighter_set.bind("skin"))
	_gui.on("setFighterHairColorIndex", _on_fighter_set.bind("hair"))
	_gui.on("setFighterEyeColorIndex", _on_fighter_set.bind("eye"))
	_gui.on("setFighterVersion", _on_fighter_version)
	_gui.on("setFighterSex", _on_fighter_set.bind("sex"))
	_gui.on("hideMouseImage", func(_a, _w): pass)
	_gui.on("changeTeamTab", _on_tm_change_tab)
	_gui.on("addRemoveFighterFromEditableTeamPreset",
		_on_tm_add_remove_fighter)
	_gui.on("openCloseUnlockedColors", func(_a, _w): pass)
	# dofusarena.social:* — friend/ignore/guild tab actions
	_gui.on("addToFriendList", _on_social_add.bind(OP_FRIEND_ADD))
	_gui.on("addToIgnoreList", _on_social_add.bind(OP_IGNORE_ADD))
	_gui.on("removeFromFriendList", _on_social_remove.bind(OP_FRIEND_REMOVE))
	_gui.on("removeFromIgnoreList", _on_social_remove.bind(OP_IGNORE_REMOVE))
	_gui.on("inviteToGuild", _on_social_add.bind(OP_GUILD_INVITE_BY_NAME))
	_gui.on("switchSocialTab", func(_a, _w): pass)
	_gui.on("quitGuild", _on_gui_quit_guild)
	_gui.on("destroyGuild", _on_gui_destroy_guild)
	# dofusarena.guild:* — creation + management + member stats
	_gui.on("openCloseGuildManagement",
		func(_a, _w): _gui.toggle("guildManagementDialog"))
	_gui.on("createGuild", _on_guild_create)
	_gui.on("validateGuildCreationForm", func(_a, _w): pass)
	_gui.on("showRanks", func(_a, _w): pass)   # hover popup owns itself
	_gui.on("selectRank", _on_guild_select_rank)
	_gui.on("addRankToGuild", _on_guild_add_rank)
	_gui.on("removeRankToGuild", _on_guild_remove_rank)
	_gui.on("modifyRank", _on_guild_modify_rank)
	# the checkbox bindings already write guildSelectedRank.can* back
	for m in ["setCanInvite", "setCanRemove", "setCanPromote",
			"setCanDepromote"]:
		_gui.on(m, func(_a, _w): pass)
	_gui.on("getMemberStats", _on_guild_member_stats)
	_gui.on("promote", _on_guild_stats_promote.bind(-1))
	_gui.on("depromote", _on_guild_stats_promote.bind(1))
	_gui.on("removeGuildMember", _on_guild_stats_kick)
	_gui.on("closeMemberStatsDialog",
		func(_a, _w): _gui.close("guildCoachStatsDialog"))
	# dofusarena.mail:* — inbox/sentbox + compose dialog
	_gui.on("tabItemChange", func(_a, _w): pass)
	_gui.on("readMail", _on_mail_read)
	_gui.on("deleteMail", _on_mail_delete)
	_gui.on("getItemFromMail", _on_mail_take)
	_gui.on("newMail", _on_mail_new)
	_gui.on("reply", _on_mail_reply)
	_gui.on("sendMail", _on_mail_send)
	_gui.on("testName", _on_mail_test_name)
	_gui.on("closeNewMailDialog",
		func(_a, _w): _gui.close("newMailDialog"))
	_gui.on("validateNewMailForm", func(_a, _w): pass)
	_gui.on("toggleInventory", func(_a, _w): pass)
	_gui.on("addItemToMail", func(_a, _w): pass)   # dndc staging — later
	_gui.on("removeItemFromMail", func(_a, _w): pass)
	# dofusarena:*LadderInformationDialog — paging of the retail ladder tabs
	_gui.on("forwardTenLadderInformationDialog",
		func(_a, _w): _ladder_gui_page(10))
	_gui.on("forwardOneHundredLadderInformationDialog",
		func(_a, _w): _ladder_gui_page(100))
	_gui.on("backwardTenLadderInformationDialog",
		func(_a, _w): _ladder_gui_page(-10))
	_gui.on("backwardOneHundredLadderInformationDialog",
		func(_a, _w): _ladder_gui_page(-100))
	_gui.on("firstPlayerLadderInformationDialog",
		func(_a, _w): _ladder_gui_first())
	_gui.on("lastPlayerLadderInformationDialog",
		func(_a, _w): _ladder_gui_last())
	_gui.on("coachSearchLadderInformationDialog",
		func(_a, _w): _ladder_gui_mine())
	# dofusarena.coachManagement:* — zaap tome navigation + teleport
	_gui.on("goToSet", _on_zaap_go_to_set)
	_gui.on("goToSetList", _on_cardbook_tab)
	_gui.on("changeInstance", _on_zaap_change_instance)
	_gui.on("equipSet", func(_a, _w): pass)
	# dofusarena.coachManagement:* — card book / coach inventory
	_gui.on("showCoachCardInfos", _on_card_hover)
	_gui.on("showCoachCardInfosInTome", _on_card_hover)
	_gui.on("showSpellCardInTome", _on_card_hover)
	_gui.on("hideCoachCardInfos", _on_card_unhover)
	_gui.on("hideCoachEquipmentInfos", _on_card_unhover)
	_gui.on("showCoachEquipmentInfos", _on_card_hover)
	_gui.on("goToFightList", _on_cardbook_tab)
	_gui.on("selectEquipmentTypeFilter", _on_equip_type_filter)
	_gui.on("selectAllEquipmentTypeFilter", _on_equip_filter_all)
	_gui.on("useSpecialCard", _on_use_special_card)
	_gui.on("equip", _on_maybe_fusion_add)
	# dofusarena.fusionLaboratory:* + cardMaster:* — shared drag names,
	# dispatched on whichever trade dialog is open
	_gui.on("removeCard", _on_shared_remove_card)
	_gui.on("removeFusionCard", _on_fusion_remove_target)
	_gui.on("fusionRequest", _on_fusion_request)
	_gui.on("dragCard", func(_a, _w): pass)
	_gui.on("dropCard", _on_shared_drop_card)
	_gui.on("dragFusionCard", func(_a, _w): pass)
	_gui.on("dropFusionCard", _on_fusion_drop_target)
	_gui.on("selectCardToBuy", _on_cm_select_card)
	_gui.on("chooseAnotherCard", _on_cm_choose_another)
	_gui.on("buyCards", _on_cm_buy)
	_gui.on("affiliateToDemon", _on_demon_affiliate)
	# dofusarena.firework:* — launcher slots + per-slot delays
	_gui.on("dropFirework", _on_fw_drop)
	_gui.on("removeFirework", _on_fw_remove)
	_gui.on("setDelay", _on_fw_delay)
	_gui.on("validateFireworkDrop", func(_a, _w): pass)
	_gui.on("launchFirework", _on_fw_launch)
	_gui.on("closeFireworkDialog",
		func(_a, _w): _gui.close("fireworkDialog"))
	# dofusarena:zoom* — miniMap navigator controls
	_gui.on("zoomIn", func(a, w): _on_map_zoom(a, w, 0.25))
	_gui.on("zoomOut", func(a, w): _on_map_zoom(a, w, -0.25))
	_gui.on("setMapZoom", _on_map_zoom_slider)
	_gui.on("closeCardMasterDialog",
		func(_a, _w): _gui.close("cardMasterDialog"))
	# dofusarena.exchange:* — player trade pane (5105-5116)
	_gui.on("setReadyForExchange", _on_ex_ready)
	_gui.on("closeCoachExchangeDialog", _on_ex_close)
	_gui.on("addCardToTome", func(_a, _w): pass)
	_gui.on("selectCostFilter", func(_a, _w): pass)
	_gui.on("selectSetFilter", func(_a, _w): pass)
	_gui.on("selectPetTypeFilter", func(_a, _w): pass)
	_gui.on("changeFightTab", func(_a, _w): pass)
	_gui.on("changeTomeTab", func(_a, _w): pass)
	_gui.on("showBreedDetails", func(_a, _w): pass)
	_gui.on("showSummonDetails", func(_a, _w): pass)
	_gui.on("backToBreedList", func(_a, _w): pass)
	_gui.on("showEffectDetails", func(_a, _w): pass)
	_gui.on("hideEffectDetails", func(_a, _w): pass)
	_gui.on("selectNextSet", func(a, _w): _step_set(a, 1))
	_gui.on("selectPreviousSet", func(a, _w): _step_set(a, -1))
	# dofusarena.calendar:* — month paging + day events + registration
	_gui.on("showNextMonth", _on_calendar_month.bind(1))
	_gui.on("showPreviousMonth", _on_calendar_month.bind(-1))
	_gui.on("showFullEventList", _on_calendar_day_events)
	_gui.on("highlightEvent", _on_calendar_highlight)
	_gui.on("unhighlightEvent", func(_a, _w): pass)
	_gui.on("registerTournament", _on_calendar_register)
	_gui.on("selectAllEventTypeFilter", func(_a, _w): pass)
	_gui.on("openTournamentDetailsDialog", func(_a, _w): pass)
	_gui.on("openTournamentDetailsDialogInFullList", func(_a, _w): pass)
	# dofusarena.achievement:* — type/subtype filters
	_gui.on("selectAchievementType", _on_ach_select_type)
	_gui.on("selectAchievementSubtype", _on_ach_select_subtype)
	_gui.on("selectAchievement", func(_a, _w): pass)
	# dofusarena:* — options dialog; the widget binds already wrote
	# gamePreferences, handlers just apply side-effects
	_gui.on("setInverseMouseControl", func(_a, _w): pass)
	_gui.on("setShowFighterMoveRange", func(_a, _w): pass)
	_gui.on("setSaveReplay", func(_a, _w): pass)
	_gui.on("setMaskWorld", func(_a, _w): pass)
	_gui.on("setGridActivated", func(_a, _w): pass)
	_gui.on("setMusicMute", func(_a, _w): _apply_audio_prefs())
	_gui.on("setMusicVolume", func(_a, _w): _apply_audio_prefs())
	_gui.on("setSoundsMute", func(_a, _w): _apply_audio_prefs())
	_gui.on("setSoundsVolume", func(_a, _w): _apply_audio_prefs())
	_gui.on("activateParticles", func(_a, _w): pass)
	_gui.on("activateVSync", func(_a, _w): _apply_vsync_pref())
	_gui.on("activateShaders", func(_a, _w): pass)
	_gui.on("setFullScreen", func(_a, _w): _apply_fullscreen_pref())
	_gui.on("applyResolution", _on_apply_resolution)
	_gui.on("destroyCoach", _on_destroy_coach)
	_gui.dialog_opened.connect(_on_gui_dialog_opened)
	$UI/VBox.visible = false
	if State.my_coach_id <= 0:
		_gui.open("logonDialog")
	else:
		_mount_lobby_menubar({"name": State.my_coach_name})
		$UI/VBox.visible = true
	connect_btn.pressed.connect(_on_connect_pressed)
	login_btn.pressed.connect(_on_login_pressed)
	$UI/VBox/AuthRow/PracticeBtn.pressed.connect(_on_practice_pressed)
	$UI/VBox/AuthRow/FightBtn.pressed.connect(_on_fight_pressed)
	$UI/VBox/AuthRow/SearchBtn.pressed.connect(_on_quick_search)
	$UI/VBox/AuthRow/EvoBtn.pressed.connect(_on_evo_search)
	$UI/MatchAskDlg.confirmed.connect(_answer_match.bind(true))
	$UI/MatchAskDlg.canceled.connect(_answer_match.bind(false))
	$UI/VBox/AuthRow/DuoBtn.pressed.connect(_open_duo_dlg)
	$UI/VBox/AuthRow/RanksBtn.pressed.connect(_open_ladder)
	$UI/LadderDlg/VBox/Tabs.item_selected.connect(_on_ladder_tab)
	$UI/LadderDlg/VBox/Scroll/List.item_selected.connect(_on_ladder_sel)
	$UI/LadderDlg/VBox/Btns/MoreBtn.pressed.connect(_on_ladder_more)
	$UI/LadderDlg/VBox/Btns/CloseBtn.pressed.connect(
		func(): $UI/LadderDlg.hide())
	var tabs: OptionButton = $UI/LadderDlg/VBox/Tabs
	for t in LADDER_TABS:
		tabs.add_item(t.label)
	$UI/VBox/AuthRow/ClanBtn.pressed.connect(_open_guild)
	$UI/GuildDlg/VBox/InviteRow/InviteBtn.pressed.connect(_on_guild_invite)
	$UI/GuildDlg/VBox/Btns/StatsBtn.pressed.connect(_on_guild_stats)
	$UI/GuildDlg/VBox/Btns/KickBtn.pressed.connect(_on_guild_kick)
	$UI/GuildDlg/VBox/Btns/PromoteBtn.pressed.connect(
		_on_guild_set_rank.bind(-1))
	$UI/GuildDlg/VBox/Btns/DemoteBtn.pressed.connect(
		_on_guild_set_rank.bind(1))
	$UI/GuildDlg/VBox/Btns/RanksBtn.pressed.connect(_on_guild_ranks_mode)
	$UI/GuildDlg/VBox/RankEdit/ApplyBtn.pressed.connect(
		_on_guild_rank_apply)
	$UI/GuildDlg/VBox/Btns/LeaveBtn.pressed.connect(_on_guild_leave)
	$UI/GuildDlg/VBox/Btns/DisbandBtn.pressed.connect(_on_guild_disband)
	$UI/GuildDlg/VBox/Btns/CloseBtn.pressed.connect(
		func(): $UI/GuildDlg.hide())
	$UI/GuildAskDlg.confirmed.connect(_answer_guild_invite.bind(true))
	$UI/GuildAskDlg.canceled.connect(_answer_guild_invite.bind(false))
	$UI/VBox/AuthRow/GearBtn.pressed.connect(_open_equip)
	$UI/VBox/AuthRow/CoachBtn.pressed.connect(_open_coach_stats)
	$UI/EquipDlg/VBox/Btns/WearBtn.pressed.connect(_on_equip_wear)
	$UI/EquipDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/EquipDlg.hide())
	$UI/EquipDlg/VBox/Slots.item_selected.connect(_on_equip_slot_sel)
	$UI/EquipDlg/VBox/Cards.item_selected.connect(_on_equip_card_sel)
	$UI/DuoDlg/VBox/Btns/CreateBtn.pressed.connect(_on_duo_create)
	$UI/DuoDlg/VBox/Btns/CancelBtn.pressed.connect(
		func(): $UI/DuoDlg.visible = false)
	$UI/DuoAskDlg.confirmed.connect(_answer_duo.bind(true))
	$UI/DuoAskDlg.canceled.connect(_answer_duo.bind(false))
	$UI/VBox/AuthRow/CancelSearchBtn.pressed.connect(_on_cancel_search)
	log.bubble.connect(world.chat_bubble)
	log.emote.connect(world.emote)
	world.cell_entered.connect(_check_zone_trigger)
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
	$UI/Chat.watch.connect(_watch_coach)
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
			$UI/VBox/RosterBox/RosterBtns/KanodoBtn.disabled = false
			$UI/VBox/RosterBox/RosterBtns/BenchBtn.disabled = false)
	$UI/VBox/RosterBox/RosterBtns/LoadoutBtn.pressed.connect(_open_loadout)
	$UI/VBox/RosterBox/RosterBtns/KanodoBtn.pressed.connect(_open_kanodo)
	$UI/VBox/RosterBox/RosterBtns/BenchBtn.pressed.connect(_on_bench_fighter)
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
	if _pending_login != "":
		_send_auth(_pending_login, _pending_pass)
		_pending_login = ""


func _on_retail_logon(args: Array, _widget: GWidget) -> void:
	# dofusarena:logon(loginForm) — green button / Enter in a field
	var login := str(_gui.gui.model.get_value("account.name"))
	var password := str(_gui.gui.model.get_value("account.password"))
	if login.strip_edges() == "":
		return
	login_edit.text = login
	password_edit.text = password
	if Session.is_online():
		_send_auth(login, password)
	else:
		_pending_login = login
		_pending_pass = password
		var proxy := str(_gui.gui.model.get_value("proxy", "selected"))
		if proxy == "":
			proxy = "140.238.172.196:3000"
		var hp := proxy.split(":")
		Session.connect_to(hp[0], int(hp[1]) if hp.size() > 1 else 5555)
		_log_line("connecting to %s…" % proxy)
	_gui._save_settings()


func _on_disconnected() -> void:
	status_lbl.text = "offline"
	login_btn.disabled = true
	connect_btn.text = "Connect"
	_log_line("[color=red]disconnected[/color]")


func _on_login_pressed() -> void:
	_send_auth(login_edit.text, password_edit.text)


func _send_auth(login_txt: String, pass_txt: String) -> void:
	var version := WireWriter.new()
	version.put_u8(0x02)          # marker, ignored by the server
	version.put_u16(70)           # the only field it validates
	version.put_u8(5)
	version.put_bytes("72909".to_ascii_buffer())
	Session.send(OP_CLIENT_VERSION, version.raw(), 0)

	var auth := WireWriter.new()
	var login := CP1252.encode(login_txt)
	var password := CP1252.encode(pass_txt)
	auth.put_u8(login.size())
	auth.put_bytes(login)
	auth.put_u8(password.size())
	auth.put_bytes(password)
	Session.send(OP_CLIENT_AUTH, auth.raw(), 1)
	State.my_coach_name = login_txt.strip_edges()
	_log_line("sent version + auth for '%s'" % login_txt)


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
			_open_coach_creation()
		OP_COACH_CREATION_RESULT:
			# 2050: [u8 result] — 0 = created; success is followed by
			# COACH_INFO + ENTER_INSTANCE, failures only carry the code.
			var res := payload.get_u8()
			if res != 0:
				_log_line("[color=red]coach create refused, code %d[/color]"
					% res)
		OP_COACH_INFO:
			var d := Codec.decode(opcode, payload)
			State.my_coach_id = int(d.get("id", -1))
			State.my_coach_name = str(d.get("name", State.my_coach_name))
			State.my_coach_look = {"skin": int(d.get("skin", 0)),
				"hair": int(d.get("hair", 0)), "sex": int(d.get("sex", 0))}
			State.coach_standing = int(d.get("standing", 0))
			State.coach_tournament_points = int(
				d.get("tournament_points", 0))
			State.guild = d.get("guild", {})
			# criteria_blob = raw {u16 id, u16 value} pairs — the field's u16
			# length prefix already served as buildCriteriaBlob's byteLen.
			var cb := WireReader.new(d.get("criteria_blob", PackedByteArray()))
			State.criteria = {}
			while cb.remaining() >= 4:
				State.criteria[cb.get_u16()] = cb.get_u16()
			if not State.guild.is_empty():
				_log_line("guild: '%s' — rank %s, demon %d" % [
					State.guild.get("guild", "?"),
					State.guild.get("rank_name", "?"),
					int(State.guild.get("demon_id", 0))])
			_log_line("[color=green]coach info received — in lobby[/color]")
			_gui.close("logonDialog")
			_mount_lobby_menubar(d)
			$UI/VBox.visible = true
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
			$UI/VBox/AuthRow/DuoBtn.disabled = false
			$UI/VBox/AuthRow/RanksBtn.disabled = false
			$UI/VBox/AuthRow/ClanBtn.disabled = false
			$UI/VBox/AuthRow/GearBtn.disabled = false
			$UI/VBox/AuthRow/CoachBtn.disabled = false
			$UI/VBox/AuthRow/SearchBtn.disabled = false
			$UI/VBox/AuthRow/EvoBtn.disabled = false
			world.show_world(State.current_world, _my_pos)
			# Post-fight re-entry: the debrief was decoded on 8300 — pop the
			# result panel now that the island is up.
			if not State.fight_result.is_empty():
				_show_fight_result()
			# aog_1: while achievement "coach created" (criterion 229) is unset,
			# retail acks the tutorial instance (4517) and reports criterion
			# 229 done (22003) on every entry until the server persists it.
			if not State.criteria.has(229):
				State.criteria[229] = 1
				State.net.send_message(OP_TUTORIAL_READY,
					PackedByteArray(), 3)
				var w := WireWriter.new()
				w.put_i16(229)
				w.put_u8(1)
				w.put_i16(1)
				State.net.send_message(OP_STAT_UPD, w.raw(), 2)
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
		OP_ACTOR_TELEPORTS:
			# 4510 — actor snapped to a cell (GM /tp, zaap arrival effects).
			var tp := Codec.decode(opcode, payload)
			world.actor_teleported(
				int(tp.f0), int(tp.f1), int(tp.f2), int(tp.f3))
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
				# state: 0 titular, 1 bench, 2 dead, 3 graveyard, 4/5 legendary
				var st := int(f.get("state", 0))
				var tag: String = {1: " [bench]", 2: " [dead]",
					3: " [graveyard]", 4: " [legendary]",
					5: " [legendary bench]"}.get(st, "")
				var label := "%s (%s)%s" % [f.get("name", "?"),
					State.BREED_NAMES.get(int(f.get("breed", 0)), "breed %d" % int(f.get("breed", 0))), tag]
				names.append(label)
				roster_list.add_item(label)
				roster_list.set_item_metadata(roster_list.item_count - 1, int(f.id))
			_log_line("roster: %s" % (", ".join(names) if names else "empty"))
			_push_team_model()
			if _elem_kind == 10 and $UI/ElementDlg.visible:
				_fill_graveyard()
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
				_search_kind = 1
				$UI/VBox/AuthRow/CancelSearchBtn.visible = true
				_log_line("searching for an opponent…")
		OP_SEARCH_CANCEL_RESULT:
			# 23102 [u8] — reply that closes the searching state
			payload.get_u8()
			_searching = false
			_search_kind = 0
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("search cancelled")
		OP_FIGHT_STARTING:
			# 23106 — paired, fight incoming (8000 follows)
			_searching = false
			_search_kind = 0
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("[color=green]opponent found — fight starting![/color]")
		OP_SEARCH_ERROR:
			var code := payload.get_u8()
			if code >= 3:
				_searching = false
				_search_kind = 0
				$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("[color=red]search error %d[/color]" % code)
		OP_QUICK_SEARCH_ACK:
			# 2304 empty — the random-fight search is live
			_searching = true
			_search_kind = 2
			$UI/VBox/AuthRow/CancelSearchBtn.visible = true
			_log_line("searching for an opponent…")
		OP_QUICK_CANCEL_RES:
			# 2306 [u8 result] — quick-search cancelled (or was idempotent)
			payload.get_u8()
			_searching = false
			_search_kind = 0
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("search cancelled")
		OP_MATCH_FOUND:
			# 23110 — paired pending match; retail asks before the accept.
			var d := Codec.decode(opcode, payload)
			_match = d
			$UI/MatchAskDlg.dialog_text = \
				"Fight against %s?" % str(d.get("opp_name", "?"))
			$UI/MatchAskDlg.popup_centered()
		OP_MATCH_CONFIRM:
			# 23116 [i32 n] — 0 rows means our match fell through
			if payload.get_i32() == 0:
				_log_line("[i]the match fell through[/i]")
		OP_EVO_SEARCH_RES:
			# 23004 [i16 preset][u8 accepted]
			payload.get_i16()
			if payload.get_u8() == 1:
				_searching = true
				_search_kind = 3
				$UI/VBox/AuthRow/CancelSearchBtn.visible = true
				_log_line("searching an evolution opponent…")
		OP_EVO_CANCEL_RES:
			payload.get_i8()
			_searching = false
			_search_kind = 0
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("search cancelled")
		OP_EVO_STARTING:
			_searching = false
			_search_kind = 0
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("[color=green]evolution fight starting![/color]")
		OP_EVO_ERROR:
			var code := payload.get_i8()
			_searching = false
			_search_kind = 0
			$UI/VBox/AuthRow/CancelSearchBtn.visible = false
			_log_line("[color=red]evolution search refused (%d)[/color]"
				% code)
		OP_RECONNECT_Q:
			# 26333 — a dropped fight is still alive; resume it (26334).
			var w := WireWriter.new()
			w.put_u8(1)
			Session.send(OP_RECONNECT_A, w.raw(), 2)
			_log_line("resuming the dropped fight…")
		OP_TOURN_TREE:
			# 28650 bracket — render slot→name into the pane's second list.
			var d := Codec.decode(opcode, payload)
			if $UI/ElementDlg.visible and _elem_kind == 13:
				var l2: ItemList = $UI/ElementDlg/VBox/Scroll2/List2
				$UI/ElementDlg/VBox/Scroll2.visible = true
				l2.clear()
				var slots: Array = d.get("slots", {}).keys()
				slots.sort()
				for s in slots:
					l2.add_item("slot %d — %s" % [
						int(s), str(d.slots[s])])
		OP_DUO_INVITATION:
			# 6025 [str8 team][str8 inviterName][i64 inviter][i64 invited]
			var team := payload.get_str("u8")
			var who := payload.get_str("u8")
			_duo_pending = {"team": team,
				"inviter": int(payload.get_i64()),
				"invited": int(payload.get_i64())}
			$UI/DuoAskDlg.dialog_text = \
				"%s invites you to 2v2 team '%s'." % [who, team]
			$UI/DuoAskDlg.popup_centered()
		OP_DUO_REFUSED:
			_log_line("[color=red]2v2 refused or unavailable[/color]")
		OP_DUO_ACCEPTED:
			_log_line("[color=green]2v2 team formed — both press "
				+ "Combattre[/color]")
		OP_DUO_GONE:
			_log_line("[i]your 2v2 partner left[/i]")
		OP_SPECTATE_REPLY:
			# 2261 [i8 1/0] — 1 = coach is in a live fight; join as viewer.
			if _watch_target >= 0 and payload.get_u8() == 1:
				var w := WireWriter.new()
				w.put_i64(_watch_target)
				Session.send(OP_SPECTATE_JOIN, w.raw(), 2)
				State.spectating = true
				_log_line("joining the fight as spectator…")
			else:
				_log_line("[i]that coach is not fighting[/i]")
				_watch_target = -1
		OP_SPECTATE_DOWN:
			_log_line("[i]spectator view closed[/i]")
			State.spectating = false
		OP_LADDER_1V1, OP_LADDER_GUILD, OP_LADDER_2V2, OP_LADDER_TOURN, \
				OP_LADDER_COACH, OP_LADDER_DEMON, OP_LADDER_PRO:
			var ld := Codec.decode(opcode, payload)
			_ladder_data[opcode] = ld
			_fill_ladder(ld, opcode)
			if _gui.is_open("ladderInformationDialog"):
				_push_ladder_model()
		OP_END_FIGHT:
			# A result screen arriving on the lobby scene means the user backed
			# out of the fight view mid-fight — ack it (26321) so the server
			# detaches the spectator link and returns the coach to overworld.
			State.fight_result = Codec.decode(opcode, payload)
			State.spectating = false
			State.fight_world = -1
			State.fighters = {}
			Session.send(OP_END_FIGHT_DONE, PackedByteArray(), 3)
			_log_line("[i]fight over — back to the island[/i]")
			_show_fight_result()
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
				# Zone triggers spawn AFTER the coach — re-check so a coach
				# already standing inside the zone still fires it.
				if e.get("kind") == 8:
					_check_zone_trigger(world.my_cell())
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
			if $UI/EquipDlg.visible:
				_fill_equip()
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
			# the tray is consumed either way — reset the lab
			_fusion_inputs = []
			_fusion_failed = int(d.get("obtained", 0)) <= 0 \
				and int(d.get("not_obtained", 0)) <= 0 \
				and int(d.get("recovered", 0)) <= 0
			if _gui.is_open("fusionLabDialog"):
				_push_fusion_model()
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
			if opcode == OP_TOURN_CALENDAR:
				_calendar_events = rows
				if _gui.is_open("calendarDialog"):
					_push_calendar_model()
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
			if int(d.accepted) != 0:
				_tourn_search_tid = int(d.tournament_id)
			else:
				_tourn_search_tid = -1
		OP_TOURN_CANCEL_RES:
			# 28610 [i8 accepted] — the search we cancelled is dead
			_tourn_search_tid = -1
			_log_line("tournament search cancelled")
		OP_TOURN_SEARCH_ERR:
			var d := Codec.decode(opcode, payload)
			_tourn_search_tid = -1
			_log_line("[color=red]tournament search error %d/%d[/color]" % [
				int(d.code), int(d.sub_code)])
		OP_TOURN_SEARCH_END:
			var d := Codec.decode(opcode, payload)
			_tourn_search_tid = -1
			_log_line("tournament %d search ended%s" % [int(d.tournament_id),
				" — winner by forfeit" if int(d.forfeit) != 0 else ""])
		28614:  # TournamentFightStarting [i64 tid] — bracket match launching
			var d := Codec.decode(opcode, payload)
			_tourn_search_tid = -1
			_log_line("tournament %d: fight starting!" % int(d.f0))
		28620:  # TournamentFinale (Yq) — [u8 status]1=add/2=remove; on add:
			# [i64 tid][i32 n][i64 coaches][i32 m][str32 names][str32 tname]
			# (both arrays written reversed — the retail reader Yq.a fills
			# them backwards, names[0] VS names[1] renders correct anyway).
			var st := payload.get_u8()
			var tid := int(payload.get_i64())
			if st == 1:
				var cn := payload.get_i32()
				for i in cn:
					payload.get_i64()
				var nn := payload.get_i32()
				var names := []
				for i in nn:
					# the wire order is reversed — prepend to land at the
					# same indices Yq.a fills (names[0] VS names[1])
					names.insert(0, payload.get_str("u32", "utf8"))
				var tname := payload.get_str("u32", "utf8")
				_toast("Finale du tournoi %s — %s VS %s" % [
					tname, names[0] if names.size() > 0 else "?",
					names[1] if names.size() > 1 else "?"])
			else:
				pass  # remove — the toast already aged out
		28644:  # TournamentSearchUpcoming [i64 tid][i64 startUnixMs] — zN
			# alert-list row "search opens in N min" (1 + diff/60000).
			var tid2 := int(payload.get_i64())
			var start_ms := int(payload.get_i64())
			var mins := 1 + int((start_ms -
				int(Time.get_unix_time_from_system() * 1000)) / 60000)
			_log_line("tournament %d: opponent search opens in %d min" % [
				tid2, max(mins, 0)])
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
		OP_GUILD_INVITATION:
			# 502 [u8 type][str8 inviter][str8 guild] — ask before answering.
			var d := Codec.decode(opcode, payload)
			_guild_invite = {"type": int(d.type), "inviter": d.inviter,
				"guild": d.guild}
			$UI/GuildAskDlg.dialog_text = \
				"%s invites you to join '%s'" % [d.inviter, d.guild]
			$UI/GuildAskDlg.popup_centered()
		OP_GUILD_MEMBER_REPORT:
			var d := Codec.decode(opcode, payload)
			var lines := ["%s — %d stat(s):" % [d.name, d.stats.size()]]
			for s in d.stats:
				lines.append("  stat %d (type %d) = %s" % [
					int(s.id), int(s.type), str(s.value)])
			_log_line("\n".join(lines))
			# retail raises the stats dialog on the reply
			if not _guild_stats_member.is_empty():
				_gui.open("guildCoachStatsDialog")
				_push_guild_member_stats(d)
		22000:
			# AchievementUnlocked — retail zN raises the achievementDialog
			# toast, gated on !isHidden() (the server already skips hidden
			# ones, but the client-side gate is part of the contract).
			var aid := int(payload.get_i16())
			var ainfo := NpcDialogs.achievement_info(aid)
			if not bool(ainfo.get("hid", false)):
				var pts := int(ainfo.get("pts", 0))
				var aname := NpcDialogs.achievement_name(aid)
				_toast("Achievement unlocked — %s%s" % [aname,
					" (+%d pts)" % pts if pts > 0 else ""])
				_log_line("[color=yellow]achievement unlocked: %s[/color]"
					% aname)
		OP_STAT_DATA:
			# 22002 — reply to opening the achievements tab; the pairs also
			# refresh the local criterion map the pane evaluates against.
			var sd := Codec.decode(opcode, payload)
			for r0 in sd.get("rows", []):
				State.criteria[int(r0.get("crit", 0))] = int(r0.get("val", 0))
			_fill_ladder(sd, opcode)
		OP_STATS_REPORT, OP_STATS_PUSH:
			# 2400/2401 — rs_2 stat map: the coach's lifetime numbers; the
			# "Coach" pane reads State.coach_stats.
			var sm := Codec.decode(opcode, payload)
			for s in sm.get("stats", []):
				State.coach_stats[int(s.id)] = s.value
			if _elem_kind == ELEM_COACH and $UI/ElementDlg.visible:
				_fill_coach_stats()
			# refresh localCoach's statistics* fields for any open stats screen
			if _gui.is_open("coachStatisticsDialog"):
				_push_local_coach()
		510:  # GuildRecord — guild name/demon/rank table for our guild
			var d := Codec.decode(opcode, payload)
			State.guild["guild_id"] = int(d.guild_id)
			State.guild["guild"] = d.name
			State.guild["demon_id"] = int(d.demon_id)
			State.guild["ranks"] = d.ranks
			_fill_guild()
			if _gui.is_open("guildManagementDialog"):
				_push_guild_mgmt_model()
		552:  # GuildMembership — my own rank/demon row (part 2)
			var d := Codec.decode(opcode, payload)
			for row in d.rows:
				State.guild.merge(row, true)
			if not State.guild.is_empty():
				_log_line("guild membership: '%s' — %s (demon %d)" % [
					State.guild.get("guild", "?"),
					State.guild.get("rank_name", "?"),
					int(State.guild.get("demon_id", 0))])
			if _gui.is_open("guildDialog") or _gui.is_open("socialDialog"):
				_push_social_model()
		512:  # GuildMembers — the roster (part 0 rows)
			var d := Codec.decode(opcode, payload)
			State.guild["members"] = d.rows
			var names := []
			for m in d.rows:
				names.append("%s%s" % [m.get("name", "?"),
					"*" if m.get("online", false) else ""])
			_log_line("guild roster: %s" % ", ".join(names))
			_fill_guild()
			if _gui.is_open("guildDialog") or _gui.is_open("socialDialog"):
				_push_social_model()
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
			_fill_guild()
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
			# the retail client opens the dialog when the list lands
			if _elem_kind == 2 or _gui.is_open("mailboxDialog") or \
					_gui.is_open("newMailDialog"):
				_gui.open("mailboxDialog")
				_push_mail_model()
		OP_MAIL_NAME_RES:
			var d := Codec.decode(opcode, payload)
			var cid := int(d.get("coach_id", 0))
			_gui.gui.model.set_value("mailbox.newMail.receiverId", cid)
			if cid <= 0:
				_toast("No such coach")
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
					if _gui.open("exchangeDialog") == null:
						_open_exchange()
					_push_exchange_model()
		OP_EX_ADDED:
			var d := Codec.decode(opcode, payload)
			var side := int(d.side)
			_ex.staged[side][int(d.card)] = int(d.qty)
			_refresh_exchange()
			_push_exchange_model()
		OP_EX_REMOVED:
			var d := Codec.decode(opcode, payload)
			_ex.staged[int(d.side)].erase(int(d.card))
			_refresh_exchange()
			_push_exchange_model()
		OP_EX_USER_READY:
			var d := Codec.decode(opcode, payload)
			_ex.ready[int(d.side)] = true
			var who: String = "You" if int(d.side) == _ex.get("my_side", -1) \
				else _ex.get("other_name", "?")
			_log_line("%s %s ready" % [who,
				"are" if int(d.side) == _ex.get("my_side", -1) else "is"])
			_refresh_exchange()
			_push_exchange_model()
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
			_gui.close("exchangeDialog")
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
		_:
			pass
	# friend/ignore/guild pushes — keep the social dialog's model fresh
	if opcode in [OP_FRIEND_LIST, OP_IGNORE_LIST, OP_FRIEND_ADDED,
			OP_FRIEND_REMOVED, OP_IGNORE_ADDED, OP_IGNORE_REMOVED,
			OP_FRIEND_ONLINE, OP_FRIEND_OFFLINE, 512] \
			and _gui.is_open("socialDialog"):
		_push_social_model()
	match opcode:
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
		var look := {"dir": int(body.get_u8()),
			"skin": int(body.get_u8()), "hair": int(body.get_u8()),
			"sex": int(body.get_u8())}
		body.get_u16() # look flags (equipment variant bits — unused)
		body.get_i32() # standing
		body.get_u8()  # sit — opcode 4601 would toggle it; AnimAssis lives
		               # in coach_700x but the sit pose needs the retail
		               # bench-anchor — read, kept
		body.get_u16() # guild blob len
		body.get_u16() # descriptor blob len
		body.get_u8()  # strength pairs
		body.get_i32() # admin right
		if id == State.my_coach_id:
			continue   # we already render ourselves from the 4600 position
		world.actor_spawned(id, cname, x, y, z, look)


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
	# The first i64 is the CLAIMED partner for duo presets (coaches[0] =
	# ally, per the 6030 coach list order); solo sends the own coach id.
	var partner := State.my_coach_id
	# the retail classic tab's selection wins over the debug dropdown
	var pid := _tm_preset_sel if _tm_preset_sel > 0 \
		else _selected_preset_id()
	for p in State.presets:
		if int(p.id) == pid and p.get("coaches", []).size() >= 1:
			partner = int(p.coaches[0])
	var w := WireWriter.new()
	w.put_i64(partner)
	w.put_i16(pid)
	Session.send(OP_COMBATTRE, w.raw(), 2)
	_log_line("combattre sent — team %d%s" % [pid,
		" (2v2 with ally %d)" % partner if partner != State.my_coach_id
		else ""])


## --- Random matchmaking (2301) + evolution queue (23003) --------------------
## Two more search lanes next to the classic Combattre: the quick-search
## button opens a random-fight queue (2301), the Evo button queues the
## evolution team (23003, pseudo-preset 99). Cancels differ per lane.
func _on_quick_search() -> void:
	if _searching:
		return
	# 2301 [i16 1][i16 teamType][i32 0] — retail's "random fight" request;
	# mode 1, subMode = the selected preset's type (0 classic, -6 duo).
	var sub_mode := 0
	var pid := _selected_preset_id()
	for p in State.presets:
		if int(p.id) == pid:
			sub_mode = int(p.get("type", 0))
	var w := WireWriter.new()
	w.put_i16(1)
	w.put_i16(sub_mode)
	w.put_i32(0)
	Session.send(OP_QUICK_SEARCH, w.raw(), 2)


func _on_evo_search() -> void:
	if _searching:
		return
	# 23003 [i64 coachId][i16 99] — 99 is the evolution pseudo-preset.
	var w := WireWriter.new()
	w.put_i64(State.my_coach_id)
	w.put_i16(99)
	Session.send(OP_EVO_SEARCH, w.raw(), 2)


## 23110 landed and the user answered the confirmation dialog.
## Accept → 23114 [i64 match][i64 opp][i16 mode][i16 type][i32 n][i64 x n][u8 1]
## with our own roster ids reversed (the server consumes, retail echoes them).
## Decline → 2303 frees the pending search.
func _answer_match(yes: bool) -> void:
	if _match.is_empty():
		return
	if yes:
		var w := WireWriter.new()
		w.put_i64(int(_match.get("match", 0)))
		w.put_i64(int(_match.get("opp", 0)))
		w.put_i16(int(_match.get("mode", 0)))
		w.put_i16(int(_match.get("fight_type", 0)))
		var ids := State.roster.map(func(f): return int(f.get("id", 0)))
		w.put_i32(ids.size())
		for i in range(ids.size() - 1, -1, -1):
			w.put_i64(int(ids[i]))
		w.put_u8(1)
		Session.send(OP_MATCH_ACCEPT, w.raw(), 2)
		_log_line("accepted match vs %s" % str(_match.get("opp_name", "?")))
	else:
		Session.send(OP_QUICK_CANCEL, PackedByteArray(), 2)
	_match = {}


## Roster bench/titular toggle — 23000 [i64 fid][u8 legendary]. The server
## flips the state itself (titular↔bench, dead→graveyard, leg↔leg-bench) and
## pushes a fresh 6006; the flag mirrors what retail sends for legendaries.
func _on_bench_fighter() -> void:
	var roster_list: ItemList = $UI/VBox/RosterBox/Roster
	var sel := roster_list.get_selected_items()
	if sel.is_empty():
		return
	var fid := int(roster_list.get_item_metadata(sel[0]))
	var f: Variant = _fighter_by_id(fid)
	if f == null:
		return
	var st := int(f.get("state", 0))
	if st == 3:   # graveyard — only a resurrection item brings it back
		return
	var w := WireWriter.new()
	w.put_i64(fid)
	w.put_u8(1 if st >= 4 else 0)
	Session.send(OP_FIGHTER_SET_STATE, w.raw(), 2)
	_log_line("state toggle sent for %s" % str(f.get("name", "?")))


## --- Spectate (2260/2261/26331) ------------------------------------------------
## /watch <name> queries whether that coach is in a live fight (2260); a 1
## reply auto-joins (26331) — the server replays the resync (4516 + 8000 with
## the spectator deck + actor appear + timeline), which the normal fight
## handlers already decode. 8300 → 26321 ack returns us to the overworld.
func _watch_coach(cname: String) -> void:
	var tid: int = world.coach_id_by_name(cname)
	if tid < 0:
		_log_line("[color=red]no coach '%s' nearby[/color]" % cname)
		return
	_watch_target = tid
	var w := WireWriter.new()
	w.put_i64(tid)
	Session.send(OP_SPECTATE_QUERY, w.raw(), 2)


## --- Ranking window (27500-27515) ---------------------------------------------
## "Ranks" opens the seven-tab board (retail ladderInformationDialog). Each
## tab is a windowed request (start offset, server page 20 / demons 12); the
## reply fills the list and "More" pulls the next window.
func _open_ladder() -> void:
	$UI/LadderDlg.show()
	_ladder_start = 0
	_ladder_request()


func _on_ladder_tab(idx: int) -> void:
	_ladder_tab = idx
	_ladder_start = 0
	_ladder_request()


func _on_ladder_more() -> void:
	_ladder_request()


## Send the current tab's request at _ladder_start (arch 2).
func _ladder_request() -> void:
	var w := WireWriter.new()
	if _ladder_start == 0:
		# fresh window (open / tab switch) — drop the previous tab's rows;
		# "More" requests append instead.
		$UI/LadderDlg/VBox/Scroll/List.clear()
	match int(LADDER_TABS[_ladder_tab].op):
		OP_LADDER_GUILD_REQ:
			w.put_i16(1)                     # board id — must be 1
			w.put_i32(_ladder_start)
		OP_LADDER_TOURN_REQ:
			w.put_i32(0)                     # month window start
			w.put_i32(0)                     # trimester window start
			w.put_i32(0)                     # year window start
			w.put_u8(int(_ladder_tourn.m))
			w.put_u8(int(_ladder_tourn.t))
			w.put_i16(int(_ladder_tourn.y))
		OP_LADDER_DEMON_REQ:
			w.put_i16(1)                     # flag — 1 populates the list
			w.put_i32(_ladder_start)
		OP_LADDER_PRO_REQ:
			w.put_i32(_ladder_start)
			w.put_i32(1)                     # league id (1 = Arena Ligue Pro)
			w.put_i32(20)                    # page size
		OP_STAT_REQ:
			pass                           # 22001 is an empty ask
		_:
			w.put_i32(_ladder_start)
	Session.send(int(LADDER_TABS[_ladder_tab].op), w.raw(), 2)


func _fill_ladder(d: Dictionary, opcode: int) -> void:
	# window advance: the reply's `end` is the next start (demons: start+n)
	match opcode:
		OP_LADDER_DEMON:
			_ladder_start = int(d.get("start", 0)) \
				+ d.get("rows", []).size()
		OP_LADDER_GUILD:
			_ladder_start = int(d.get("start", 0)) \
				+ d.get("rows", []).size()
		_:
			_ladder_start = int(d.get("end", _ladder_start))
	if not $UI/LadderDlg.visible:
		return
	var list: ItemList = $UI/LadderDlg/VBox/Scroll/List
	var hint: Label = $UI/LadderDlg/VBox/Hint
	var more: Button = $UI/LadderDlg/VBox/Btns/MoreBtn
	match opcode:
		OP_STAT_DATA:
			_fill_achievements(list, hint, more)
		OP_LADDER_1V1:
			for r0 in d.get("rows", []):
				var g := str(r0.get("guild", ""))
				list.add_item("%s%s — rating %d · %dW/%dL · streak %d" % [
					str(r0.get("name", "?")),
					" [%s]" % g if g != "" else "",
					int(r0.get("rating", 0)), int(r0.get("wins", 0)),
					int(r0.get("losses", 0)), int(r0.get("streak", 0))])
			hint.text = "%d ranked — your rank: %s" % [
				int(d.get("total", 0)),
				str(d.get("my_rank")) if int(d.get("my_rank", 0)) > 0
					else "unranked"]
			more.disabled = int(d.get("end", 0)) >= int(d.get("total", 0))
		OP_LADDER_GUILD:
			for r0 in d.get("rows", []):
				list.add_item("%s (leader %s) — %d pts" % [
					str(r0.get("guild", "?")), str(r0.get("leader", "?")),
					int(r0.get("score", 0))])
			hint.text = "%d clan(s)" % d.get("rows", []).size()
			more.disabled = d.get("rows", []).size() < 20
		OP_LADDER_2V2:
			for r0 in d.get("rows", []):
				list.add_item("%s — %s [%s] rating %d · %dW/%dL" % [
					str(r0.get("team", "?")), str(r0.get("coaches", "?")),
					str(r0.get("guild", "")), int(r0.get("rating", 0)),
					int(r0.get("wins", 0)), int(r0.get("losses", 0))])
			hint.text = "%d teams" % int(d.get("total", 0))
			more.disabled = int(d.get("end", 0)) >= int(d.get("total", 0))
		OP_LADDER_TOURN:
			_ladder_tourn = {"m": int(d.get("month", 0)),
				"t": int(d.get("trimester", 0)),
				"y": int(d.get("year", 0))}
			var wins: Array = d.get("windows", [])
			var labels := ["month", "trimester", "year"]
			var pts: Array = d.get("my_points", [0, 0, 0])
			for i in wins.size():
				list.add_item("— %s —" % labels[i])
				for r0 in wins[i].get("rows", []):
					list.add_item("%s — %d pts" % [
						str(r0.get("name", "?")),
						int(r0.get("points", 0))])
			hint.text = "your points — month %d · trimester %d · year %d" % [
				int(pts[0]), int(pts[1]), int(pts[2])]
			more.disabled = true
		OP_LADDER_COACH:
			for r0 in d.get("rows", []):
				list.add_item("%s — %d rep · %dW/%dL · demon %d" % [
					str(r0.get("coach", "?")), int(r0.get("rep", 0)),
					int(r0.get("wins", 0)), int(r0.get("losses", 0)),
					int(r0.get("demon", 0))])
			hint.text = "%d coaches" % int(d.get("total", 0))
			more.disabled = int(d.get("end", 0)) >= int(d.get("total", 0))
		OP_LADDER_DEMON:
			for r0 in d.get("rows", []):
				list.add_item("Demon %d — %s · %d rep" % [
					int(r0.get("demon", 0)),
					str(r0.get("guild", "")) if str(r0.get("guild", "")) \
						!= "" else "unaffiliated",
					int(r0.get("rep", 0))])
			hint.text = "24 demons"
			more.disabled = d.get("rows", []).size() < 12
		OP_LADDER_PRO:
			for r0 in d.get("rows", []):
				list.add_item("%s [%s] — rating %d" % [
					str(r0.get("name", "?")), str(r0.get("guild", "")),
					int(r0.get("rating", 0))])
			hint.text = "league %d — your rank %s" % [
				int(d.get("league", 0)),
				str(d.get("my_rank")) if int(d.get("my_rank", 0)) > 0
					else "unranked"]
			more.disabled = int(d.get("end", 0)) >= int(d.get("total", 0))


## Achievements tab — the retail achievementsDialog: named rows sorted
## done-first (qy_2), each showing ✓ or its averaged progress %, then a tail
## of named raw criteria. Selecting a row puts its description and
## per-condition progress in the hint line.
func _fill_achievements(list: ItemList, hint: Label, more: Button) -> void:
	var rows := NpcDialogs.achievement_rows(State.criteria, State.inventory)
	var earned := 0
	for r0 in rows:
		var aid := int(r0.id)
		var pts := int(NpcDialogs.achievement_info(aid).get("pts", 0))
		if r0.done:
			earned += pts
			list.add_item("✓ %s — %d pts" % [
				NpcDialogs.achievement_name(aid), pts])
		else:
			list.add_item("%s — %d%%" % [NpcDialogs.achievement_name(aid),
				NpcDialogs.achievement_progress(
					aid, State.criteria, State.inventory)])
		list.set_item_metadata(list.item_count - 1, {"ach": aid})
	var cids := State.criteria.keys()
	cids.sort()
	for cid in cids:
		list.add_item("%s = %d" % [
			NpcDialogs.criterion_name(int(cid)), int(State.criteria[cid])])
		list.set_item_metadata(list.item_count - 1, {"crit": int(cid)})
	hint.text = "%d achievements · %d pts earned · %d criteria" % [
		rows.size(), earned, State.criteria.size()]
	more.disabled = true


func _on_ladder_sel(idx: int) -> void:
	var list: ItemList = $UI/LadderDlg/VBox/Scroll/List
	var m: Variant = list.get_item_metadata(idx)
	if typeof(m) != TYPE_DICTIONARY or not m.has("ach"):
		return
	var aid := int(m.ach)
	var info := NpcDialogs.achievement_info(aid)
	var conds := []
	for c in info.get("conds", []):
		if c.kind == "stat":
			conds.append("%s %d/%d" % [
				NpcDialogs.criterion_name(int(c.id)),
				mini(int(State.criteria.get(int(c.id), 0)), int(c.thr)),
				int(c.thr)])
		else:
			conds.append("%s %s" % [Cards.name_of(int(c.id)),
				"✓" if int(State.inventory.get(int(c.id), 0)) > 0 else "—"])
	var desc := NpcDialogs.achievement_desc(aid)
	$UI/LadderDlg/VBox/Hint.text = "%s — %d pts%s%s" % [
		NpcDialogs.achievement_name(aid), int(info.get("pts", 0)),
		"\n" + desc if desc != "" else "",
		"\n" + " · ".join(conds) if not conds.is_empty() else ""]


## --- Clan panel (501-557, 2600/2601) ------------------------------------------
## "Clan" opens the guild dialog: members view (invite/stats/kick/rank ops)
## and a ranks editor (add/modify/delete, right-gated like retail — the
## server re-derives every right server-side anyway). Membership-changing
## opcodes (501/503/505/515) go on arch 8; admin ops (511/517/553/555/557/
## 2600) on arch 2 — mirrors the retail `a((byte)N)` table.
const GUILD_RIGHT_LEADER := 1
const GUILD_RIGHT_INVITE := 2
const GUILD_RIGHT_REMOVE := 4
const GUILD_RIGHT_PROMOTE := 8
const GUILD_RIGHT_DEMOTE := 16

func _open_guild() -> void:
	$UI/GuildDlg.show()
	_guild_ranks_mode = false
	_guild_mode_ui()
	_fill_guild()
	if not State.guild.is_empty():
		var w := WireWriter.new()
		w.put_i64(State.my_coach_id)
		Session.send(OP_GUILD_GET, w.raw(), 2)
		w = WireWriter.new()
		w.put_i64(int(State.guild.get("guild_id", 0)))
		Session.send(OP_GUILD_MEMBERS, w.raw(), 2)


## My rights mask (from the 552 membership row).
func _my_rights() -> int:
	return int(State.guild.get("rights", 0))


func _has_right(bit: int) -> bool:
	var r := _my_rights()
	return r & GUILD_RIGHT_LEADER != 0 or r & bit != 0


## Selected member row in members mode (the list stores the member dict
## itself as item metadata).
func _guild_sel_member() -> Variant:
	if _guild_ranks_mode:
		return null
	var list: ItemList = $UI/GuildDlg/VBox/Scroll/List
	var sel := list.get_selected_items()
	if sel.is_empty():
		return null
	return list.get_item_metadata(sel[0])


func _fill_guild() -> void:
	if not $UI/GuildDlg.visible:
		return
	var title: Label = $UI/GuildDlg/VBox/Title
	var hint: Label = $UI/GuildDlg/VBox/Hint
	var list: ItemList = $UI/GuildDlg/VBox/Scroll/List
	list.clear()
	if State.guild.is_empty():
		title.text = "Clan"
		hint.text = "no clan — found one with /guild <name>"
		return
	title.text = "Clan — %s" % str(State.guild.get("guild", "?"))
	hint.text = "you: %s · demon %d · %d member(s)" % [
		str(State.guild.get("rank_name", "?")),
		int(State.guild.get("demon_id", 0)),
		State.guild.get("members", []).size()]
	if _guild_ranks_mode:
		for rk in State.guild.get("ranks", []):
			list.add_item("rank %d — %s (rights %d)" % [
				int(rk.get("level", 0)), str(rk.get("name", "?")),
				int(rk.get("rights", 0))])
	else:
		for m in State.guild.get("members", []):
			if int(m.get("part", -1)) != 0:
				continue
			list.add_item("%s — %s%s" % [
				str(m.get("name", "?")), str(m.get("rank_name", "?")),
				" · online" if m.get("online", false) else ""])
			list.set_item_metadata(list.item_count - 1, m)


## Swap member/rank button enablement for the current mode + rights.
func _guild_mode_ui() -> void:
	var edit: HBoxContainer = $UI/GuildDlg/VBox/RankEdit
	var invite: HBoxContainer = $UI/GuildDlg/VBox/InviteRow
	var btns := $UI/GuildDlg/VBox/Btns
	edit.visible = _guild_ranks_mode
	invite.visible = not _guild_ranks_mode
	btns.get_node("StatsBtn").visible = not _guild_ranks_mode
	btns.get_node("PromoteBtn").visible = not _guild_ranks_mode
	btns.get_node("DemoteBtn").visible = not _guild_ranks_mode
	var kick: Button = btns.get_node("KickBtn")
	kick.text = "Delete" if _guild_ranks_mode else "Kick"
	var ranks: Button = btns.get_node("RanksBtn")
	ranks.text = "Members" if _guild_ranks_mode else "Ranks"
	# right-gating mirrors retail's hidden entries (server rechecks anyway)
	var in_guild := not State.guild.is_empty()
	$UI/GuildDlg/VBox/InviteRow/InviteBtn.disabled = \
		not in_guild or not _has_right(GUILD_RIGHT_INVITE)
	btns.get_node("LeaveBtn").disabled = not in_guild
	btns.get_node("DisbandBtn").disabled = \
		not _has_right(GUILD_RIGHT_LEADER)


func _on_guild_invite() -> void:
	var edit: LineEdit = $UI/GuildDlg/VBox/InviteRow/Name
	var cname := edit.text.strip_edges()
	if cname.is_empty():
		return
	var tid: int = world.coach_id_by_name(cname)
	if tid < 0:
		_log_line("[color=red]no coach '%s' nearby[/color]" % cname)
		return
	var w := WireWriter.new()
	w.put_u8(0)                                  # guild type (clan)
	w.put_u8(1)                                  # mode 1 = by coach id
	w.put_i64(tid)
	w.put_i64(int(State.guild.get("guild_id", 0)))
	Session.send(OP_GUILD_INVITE, w.raw(), 8)
	edit.clear()


func _on_guild_stats() -> void:
	var m: Variant = _guild_sel_member()
	if m == null:
		return
	var w := WireWriter.new()
	w.put_i64(int(m.get("coach_id", 0)))
	Session.send(OP_GUILD_MEMBER_STATS, w.raw(), 2)


func _on_guild_kick() -> void:
	if _guild_ranks_mode:
		# delete the selected rank
		var list: ItemList = $UI/GuildDlg/VBox/Scroll/List
		var sel := list.get_selected_items()
		var ranks: Array = State.guild.get("ranks", [])
		if sel.is_empty() or sel[0] >= ranks.size():
			return
		var w := WireWriter.new()
		w.put_i64(int(State.guild.get("guild_id", 0)))
		w.put_i16(int(ranks[sel[0]].get("level", 0)))
		Session.send(OP_GUILD_RANK_DEL, w.raw(), 2)
		return
	var m: Variant = _guild_sel_member()
	if m == null:
		return
	var w := WireWriter.new()
	w.put_i64(int(State.guild.get("guild_id", 0)))
	w.put_i64(int(m.get("coach_id", 0)))
	Session.send(OP_GUILD_LEAVE, w.raw(), 8)


## delta -1 = promote (smaller level number), +1 = demote. Picks the
## nearest EXISTING rank in that direction — levels are sparse (leader 1,
## members join at 10, customs land in between).
func _on_guild_set_rank(delta: int) -> void:
	var m: Variant = _guild_sel_member()
	if m == null:
		return
	var cur: int = int(m.get("rank_level", 0))
	var want := -1
	for rk in State.guild.get("ranks", []):
		var lvl: int = int(rk.get("level", 0))
		if delta < 0 and lvl < cur and (want < 0 or lvl > want):
			want = lvl    # promote → highest level below current
		elif delta > 0 and lvl > cur and (want < 0 or lvl < want):
			want = lvl    # demote → lowest level above current
	if want < 0:
		_log_line("[i]no rank to %s to[/i]" % [
			"promote" if delta < 0 else "demote"])
		return
	var w := WireWriter.new()
	w.put_i64(int(State.guild.get("guild_id", 0)))
	w.put_i64(int(m.get("coach_id", 0)))
	w.put_i16(want)
	Session.send(OP_GUILD_SET_RANK, w.raw(), 8)


func _on_guild_leave() -> void:
	if State.guild.is_empty():
		return
	var w := WireWriter.new()
	w.put_i64(int(State.guild.get("guild_id", 0)))
	w.put_i64(State.my_coach_id)               # self = leave
	Session.send(OP_GUILD_LEAVE, w.raw(), 8)


func _on_guild_disband() -> void:
	var w := WireWriter.new()
	w.put_i64(int(State.guild.get("guild_id", 0)))
	Session.send(OP_GUILD_DESTROY, w.raw(), 2)


func _on_guild_ranks_mode() -> void:
	_guild_ranks_mode = not _guild_ranks_mode
	_guild_mode_ui()
	_fill_guild()
	if _guild_ranks_mode:
		# seed the editor with the selected rank if any
		var list: ItemList = $UI/GuildDlg/VBox/Scroll/List
		var sel := list.get_selected_items()
		var ranks: Array = State.guild.get("ranks", [])
		if not sel.is_empty() and sel[0] < ranks.size():
			_fill_rank_edit(ranks[sel[0]])


func _fill_rank_edit(rk: Dictionary) -> void:
	var edit := $UI/GuildDlg/VBox/RankEdit
	edit.get_node("Name").text = str(rk.get("name", ""))
	var r := int(rk.get("rights", 0))
	edit.get_node("RInvite").button_pressed = r & GUILD_RIGHT_INVITE != 0
	edit.get_node("RKick").button_pressed = r & GUILD_RIGHT_REMOVE != 0
	edit.get_node("RPromote").button_pressed = r & GUILD_RIGHT_PROMOTE != 0
	edit.get_node("RDemote").button_pressed = r & GUILD_RIGHT_DEMOTE != 0


## Apply = modify the selected rank (555) or add a new one (553).
func _on_guild_rank_apply() -> void:
	var edit := $UI/GuildDlg/VBox/RankEdit
	var name := str(edit.get_node("Name").text).strip_edges()
	if name.is_empty():
		return
	var rights := 0
	if edit.get_node("RInvite").button_pressed: rights |= GUILD_RIGHT_INVITE
	if edit.get_node("RKick").button_pressed: rights |= GUILD_RIGHT_REMOVE
	if edit.get_node("RPromote").button_pressed: rights |= GUILD_RIGHT_PROMOTE
	if edit.get_node("RDemote").button_pressed: rights |= GUILD_RIGHT_DEMOTE
	var w := WireWriter.new()
	w.put_i64(int(State.guild.get("guild_id", 0)))
	w.put_i32(rights)
	var list: ItemList = $UI/GuildDlg/VBox/Scroll/List
	var sel := list.get_selected_items()
	var ranks: Array = State.guild.get("ranks", [])
	var nb: PackedByteArray = name.to_utf8_buffer()
	if not sel.is_empty() and sel[0] < ranks.size():
		# modify: [i32 rights][u16 lvl][u16 lvl][str8 name]
		var lvl: int = int(ranks[sel[0]].get("level", 0))
		w.put_i16(lvl)
		w.put_i16(lvl)
		w.put_u8(nb.size())
		w.put_bytes(nb)
		Session.send(OP_GUILD_RANK_MOD, w.raw(), 2)
	else:
		w.put_u8(nb.size())
		w.put_bytes(nb)
		Session.send(OP_GUILD_RANK_ADD, w.raw(), 2)


## Answer the pending 502 clan invitation (503, arch 8).
func _answer_guild_invite(accepted: bool) -> void:
	if _guild_invite.is_empty():
		return
	var w := WireWriter.new()
	w.put_u8(int(_guild_invite.get("type", 0)))
	w.put_u8(1 if accepted else 0)
	for k in ["inviter", "guild"]:
		var nb: PackedByteArray = str(_guild_invite[k]).to_utf8_buffer()
		w.put_u8(nb.size())
		w.put_bytes(nb)
	Session.send(OP_GUILD_INV_ANSWER, w.raw(), 8)
	_guild_invite = {}


## --- 2v2 duo (6024-6029) ------------------------------------------------------
## "2v2…" opens the invite dialog (team name + friend pick, retail's
## team2vs2NameDialog): 6024 [str8 team][i64 me][i64 mate]. The invited side
## gets 6025 → DuoAskDlg → 6026. On 6028 both clients own a -6 duo preset
## (pushed via 6030) whose coaches[0] is the ally — Combattre then sends it
## as the claimed partner in 23103's first i64.
func _open_duo_dlg() -> void:
	var opt: OptionButton = $UI/DuoDlg/VBox/Friend
	opt.clear()
	for fr in State.friends:
		var fid := int(fr.get("id", -1))
		if fid <= 0:
			continue   # offline/friendless rows carry id -1
		opt.add_item(fr.get("name", "?"))
		opt.set_item_metadata(opt.item_count - 1, fid)
	if opt.item_count == 0:
		_log_line("[i]no friends — /friend &lt;name&gt; first[/i]")
		return
	opt.select(0)
	$UI/DuoDlg.visible = true


func _on_duo_create() -> void:
	var opt: OptionButton = $UI/DuoDlg/VBox/Friend
	if opt.selected < 0:
		return
	var tname: String = $UI/DuoDlg/VBox/Name.text.strip_edges()
	if tname.is_empty():
		tname = "duo"
	var w := WireWriter.new()
	w.put_str(tname, "u8")
	w.put_i64(State.my_coach_id)
	w.put_i64(int(opt.get_item_metadata(opt.selected)))
	Session.send(OP_DUO_REQUEST, w.raw(), 2)
	$UI/DuoDlg.visible = false
	_log_line("2v2 invitation sent")


func _answer_duo(accept: bool) -> void:
	if _duo_pending.is_empty():
		return
	var w := WireWriter.new()
	w.put_u8(1 if accept else 0)
	w.put_str(String(_duo_pending.team), "u8")
	w.put_i64(int(_duo_pending.inviter))
	w.put_i64(int(_duo_pending.invited))
	w.put_i16(0 if accept else 2)   # reason 2 = refused/busy (client's own)
	Session.send(OP_DUO_ANSWER, w.raw(), 2)
	_duo_pending = {}


## 23101 [i64 coachId][i16 teamId] — the classic overlay's Cancel.
func _on_cancel_search() -> void:
	# Cancel the kind of search actually running: classic ready-up (23101),
	# the random quick-search (2303, empty) or the evolution queue (23001).
	match _search_kind:
		2:
			Session.send(OP_QUICK_CANCEL, PackedByteArray(), 2)
		3:
			var w := WireWriter.new()
			w.put_i64(State.my_coach_id)
			w.put_i16(99)                # evolution pseudo-preset
			Session.send(OP_EVO_CANCEL, w.raw(), 2)
		_:
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
	w.put_u8(0)                       # flag: 0 = UI create (1 = file restore)
	# slot = target preset id (-1 → titular pool), per hu_2.java:16611
	w.put_i16(_selected_preset_id())
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


## --- Coach statistics (2401 / 2400) ------------------------------------------
## The 2401 login push carries the coach's lifetime counters as an rs_2 stat
## map (server statistics.go — PlayerStatisticsReport field ids). Sparse: a
## stat the server never tracked simply isn't there and reads as 0.
const COACH_STAT_LABELS := {1: "time played", 2: "time in fights",
	3: "fights", 4: "wins", 5: "losses", 7: "win streak", 8: "loss streak"}
const COACH_STAT_ORDER := [3, 4, 5, 7, 8, 1, 2]  # fights first, times last

func _open_coach_stats() -> void:
	_element_text("Coach — %s" % State.my_coach_name,
		"lifetime statistics:")
	_elem_kind = ELEM_COACH
	_fill_coach_stats()


func _fill_coach_stats() -> void:
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.clear()
	for id in COACH_STAT_ORDER:
		var v := int(State.coach_stats.get(id, 0))
		var text := _fmt_secs(v) if id in [1, 2] else str(v)
		list.add_item("%s: %s" % [COACH_STAT_LABELS[id], text])
	var fights := int(State.coach_stats.get(3, 0))
	if fights > 0:
		$UI/ElementDlg/VBox/Hint.text = "win rate: %d%%" % [
			int(State.coach_stats.get(4, 0)) * 100 / fights]


static func _fmt_secs(secs: int) -> String:
	var h := secs / 3600
	var m := (secs % 3600) / 60
	return "%dh %02dm" % [h, m] if h > 0 else "%dm %02ds" % [m, secs % 60]


## --- Coach equipment (5201) -------------------------------------------------
## 14 client slots; only the 12 wearable types map to one (server
## coachcard_slots.go — type -> 0-based position). The layout echoes nowhere:
## the client owns the state and re-sends all 14 slots on Wear.
const COACH_SLOT_FOR_TYPE := {2: 5, 3: 2, 4: 1, 5: 4, 6: 10, 7: 3,
	8: 8, 9: 6, 10: 11, 11: 0, 12: 7, 13: 9}
const COACH_SLOT_NAMES := {0: "Chapeau", 1: "Tatouages", 2: "Coiffure",
	3: "Epaulette", 4: "Brassard", 5: "Culotte", 6: "Pantalon",
	7: "Baton", 8: "Cape", 9: "Familier", 10: "Bottes", 11: "Chemise"}

var _equip_slots: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]


func _open_equip() -> void:
	$UI/EquipDlg.visible = true
	_fill_equip()
	# 5203 asks for a fresh 5200 push (the uid list is client-local and
	# unresolvable server-side — an empty count is a pure refresh request).
	var w := WireWriter.new()
	w.put_u16(0)
	State.net.send_message(5203, w.raw(), 3)


func _fill_equip() -> void:
	var slots: ItemList = $UI/EquipDlg/VBox/Slots
	var cards: ItemList = $UI/EquipDlg/VBox/Cards
	slots.clear()
	for i in 14:
		var label: String = COACH_SLOT_NAMES.get(i, "slot %d" % i)
		var cid := int(_equip_slots[i])
		slots.add_item("%d %s — %s" % [i, label,
			Cards.name_of(cid) if cid != 0 else "(empty)"])
		slots.set_item_disabled(i, not COACH_SLOT_NAMES.has(i))
	cards.clear()
	var owned := []
	for cid in State.inventory:
		var t := int(Cards.meta(int(cid)).get("type", -1))
		if COACH_SLOT_FOR_TYPE.has(t) and int(cid) not in _equip_slots:
			owned.append(int(cid))
	owned.sort()
	for cid in owned:
		var idx := cards.add_item("%s  (x%d)" % [
			Cards.name_of(cid), int(State.inventory[cid])])
		cards.set_item_metadata(idx, cid)


func _on_equip_card_sel(idx: int) -> void:
	var cards: ItemList = $UI/EquipDlg/VBox/Cards
	var cid := int(cards.get_item_metadata(idx))
	var slot: int = COACH_SLOT_FOR_TYPE.get(
		int(Cards.meta(cid).get("type", -1)), -1)
	if slot >= 0:
		_equip_slots[slot] = cid
		_fill_equip()


func _on_equip_slot_sel(idx: int) -> void:
	if _equip_slots[idx] != 0:
		_equip_slots[idx] = 0
		_fill_equip()


func _on_equip_wear() -> void:
	var w := WireWriter.new()
	for i in 14:
		w.put_i32(int(_equip_slots[i]))
	Session.send(OP_EQUIP_REQ, w.raw(), 3)
	_log_line("equipment layout sent — %d card(s) worn" %
		(14 - _equip_slots.count(0)))


## 2048 COACH_CREATE_REQ → retail coachCreationDialog (sex/skin/hair/name +
## live paper-doll preview). localCoach is the model the XML binds to.
func _open_coach_creation() -> void:
	_gui.gui.model.set_value("localCoach", {
		"sex": 0, "skin": 1, "hair": 1,
		"name": login_edit.text.strip_edges().left(20),
		"actorDescriptorLibrary": "coach_7000",
		"actorAnimation": "AnimStatique",
		"actorDirection": 3,
		"actorMaterial": Palettes.coach_tints(1, 1)})
	_gui.open("coachCreationDialog")
	if not _gui.gui.model.changed.is_connected(_on_localcoach_changed):
		_gui.gui.model.changed.connect(_on_localcoach_changed)


## localCoach.sex/hair/skin drive the preview's paper-doll set + channel tints
func _on_localcoach_changed(n: String, field: String, _v) -> void:
	if n != "localCoach" or not field in ["sex", "hair", "skin"]:
		return
	var lc = _gui.gui.model.get_value("localCoach")
	if not (lc is Dictionary):
		return
	lc["actorDescriptorLibrary"] = "coach_700%d" % int(lc.get("sex", 0))
	lc["actorMaterial"] = Palettes.coach_tints(
		int(lc.get("skin", 0)), int(lc.get("hair", 0)))
	_gui.gui.model.set_value("localCoach", lc)


func _on_coach_dir(_args: Array, _w, d: int) -> void:
	var lc = _gui.gui.model.get_value("localCoach")
	if not (lc is Dictionary):
		return
	lc["actorDirection"] = (int(lc.get("actorDirection", 3)) + d) & 7
	_gui.gui.model.set_value("localCoach", lc)


func _on_coach_random(_args: Array, _w) -> void:
	var lc = _gui.gui.model.get_value("localCoach")
	if not (lc is Dictionary):
		return
	lc["sex"] = randi() % 2
	lc["skin"] = randi() % Palettes.SKIN.size()
	lc["hair"] = randi() % Palettes.HAIR.size()
	_gui.gui.model.set_value("localCoach", lc)


func _on_coach_create(_args: Array, _w) -> void:
	var lc = _gui.gui.model.get_value("localCoach")
	if not (lc is Dictionary):
		return
	var name := str(lc.get("name", "")).strip_edges()
	if name == "":
		return
	var name_bytes := CP1252.encode(name.left(20))
	var w := WireWriter.new()
	w.put_u8(name_bytes.size())
	w.put_bytes(name_bytes)
	w.put_u8(int(lc.get("skin", 0)) & 0xFF)
	w.put_u8(int(lc.get("hair", 0)) & 0xFF)
	w.put_u8(int(lc.get("sex", 0)) & 0xFF)
	Session.send(OP_COACH_CREATE, w.raw(), 2)
	_gui.close("coachCreationDialog")
	_log_line("coach creation sent — '%s'" % name)


## --- fighter creation (teamManagement.editableFighter) --------------------
## The retail fighterCreationDialog binds a preview paper-doll to the model;
## setFighter* events just rewrite fields. On validate → 6001.
const _FV := preload("res://src/fight/fight_view.gd")


## Whether the create-fighter dialog was opened from the evolution tab —
## retail writes slot=99 + blob type 2 for evolution recruits, slot=teamId +
## blob type 1 for classic preset recruits (hu_2.java:16611).
var _create_fighter_evo := false


func _on_new_fighter_dialog(_args: Array, _w, evo := false) -> void:
	_create_fighter_evo = evo
	_gui.gui.model.set_value("teamManagement", {
		"breedId": 1, "sex": 0, "version": 1,
		"skin": 0, "hair": 0, "eye": 0, "name": "",
		"actorAnimation": "AnimStatique", "actorDirection": 3},
		"editableFighter")
	_refresh_editable_fighter()
	_gui.open("fighterCreationDialog")


func _refresh_editable_fighter() -> void:
	var f = _gui.gui.model.get_value("teamManagement", "editableFighter")
	if not (f is Dictionary):
		return
	var breed := clampi(int(f.get("breedId", 1)), 1, 12)
	var sex := clampi(int(f.get("sex", 0)), 0, 1)
	f["actorDescriptorLibrary"] = "fighter_%s" % \
		_FV.FIGHTER_FILES[(breed - 1) * 2 + sex]
	f["actorMaterial"] = Palettes.fighter_tints(
		int(f.get("skin", 0)), int(f.get("hair", 0)), int(f.get("eye", 0)))
	_gui.gui.model.set_value("teamManagement", f, "editableFighter")


## setFighterBreedId(fighter,N) / setFighterSkinColorIndex(N,fighter) —
## the arg order differs per event; take the numeric arg either way.
func _on_fighter_set(args: Array, _w, field: String) -> void:
	var f = _gui.gui.model.get_value("teamManagement", "editableFighter")
	if not (f is Dictionary):
		return
	var v := -1
	for a in args:
		if a is int or a is float:
			v = int(a)
	if field == "breedId" and v < 0:
		v = int(args[1]) if args.size() > 1 else 1
	if v < 0:
		return
	f[field] = v
	if field == "breedId" or field == "sex":
		_refresh_editable_fighter()
	else:
		f["actorMaterial"] = Palettes.fighter_tints(
			int(f.get("skin", 0)), int(f.get("hair", 0)),
			int(f.get("eye", 0)))
		_gui.gui.model.set_value("teamManagement", f, "editableFighter")


func _on_fighter_version(args: Array, _w) -> void:
	var f = _gui.gui.model.get_value("teamManagement", "editableFighter")
	if not (f is Dictionary):
		return
	for a in args:
		if a is int or a is float:
			f["version"] = int(a)
	_gui.gui.model.set_value("teamManagement", f, "editableFighter")


func _on_gui_create_fighter(_args: Array, _w) -> void:
	var f = _gui.gui.model.get_value("teamManagement", "editableFighter")
	if not (f is Dictionary):
		return
	var fname := str(f.get("name", "")).strip_edges()
	if fname == "":
		return
	var blob: PackedByteArray = Overrides.encode_fighter_blob(
		int(f.get("breedId", 1)), fname, int(f.get("sex", 0)), [],
		[int(f.get("hair", 0)), int(f.get("skin", 0)),
			int(f.get("eye", 0))],
		2 if _create_fighter_evo else 1)
	# slot: 99 for evolution recruits, the preset's team id for classic
	# (hu_2.java:16611 — 0 was our placeholder, the server needs the team).
	var slot := 99
	if not _create_fighter_evo:
		slot = _tm_preset_sel if _tm_preset_sel > 0 \
			else _selected_preset_id()
	var w := WireWriter.new()
	w.put_u8(0)
	w.put_i16(slot)
	w.put_u16(blob.size())
	w.put_bytes(blob)
	Session.send(OP_FIGHTER_CREATE, w.raw(), 2)
	_gui.close("fighterCreationDialog")
	_log_line("fighter create sent: %s" % fname)


func _on_gui_delete_fighter(args: Array, _w) -> void:
	# deleteFighter(fighter) — fighter = the row's <data id> item
	if args.is_empty() or not (args[0] is Dictionary):
		return
	var w := WireWriter.new()
	w.put_i64(int(args[0].get("id", args[0].get("fighterId", 0))))
	w.put_u16(0)
	Session.send(OP_FIGHTER_DELETE, w.raw(), 2)


## Roster → the XULOR2 model the evolution tab's fighter cards bind.
## state 1/5 → bench lists; the editableTeamPreset.fighters bean is
## per-tab (evolution titulars vs the classic recruit pool) like retail.
func _push_team_model() -> void:
	var bench: Array = []
	for fr in State.roster:
		var item := _evo_fighter_item(fr)
		if int(fr.get("state", 0)) == 1:
			bench.append(item)
	_gui.gui.model.set_value("teamManagement",
		{"fighters": _tm_classic_pool() if _tm_tab() in [1, 2, 3]
			else _tm_evo_playing()}, "editableTeamPreset")
	_gui.gui.model.set_value("evolutionTeam",
		{"fightersOnBench": bench})
	_gui.gui.model.set_value("tomeManager",
		_all_card_sets(), "evolutionSets")
	_gui.gui.model.set_value("onlyTabEnabledId", -1)
	_push_team_classic_model()


## Active teamManagement tab — persisted like retail's
## gamePreferences.lastSelectedGameModeId (0 evolution, 1 elite, 2 2v2,
## 3 tournament, 4 legends).
func _tm_tab() -> int:
	var v: Variant = _gui.gui.model.get_value("gamePreferences",
		"lastSelectedGameModeId")
	return int(v) if v is int or v is float else 0


## Classic tabs' fighter pool — every type-1 roster fighter flagged with
## `teamMember` when it already belongs to the selected preset (the
## newFighterList renderer reads it for the add/remove button).
func _tm_classic_pool() -> Array:
	var pool: Array = []
	for fr in State.roster:
		if int(fr.get("type", 2)) != 1:
			continue
		var it := _evo_fighter_item(fr)
		it["teamMember"] = _tm_preset_has(int(it.get("id", 0)))
		pool.append(it)
	return pool


func _tm_preset_has(fid: int) -> bool:
	for p in State.presets:
		if int(p.get("id", -1)) != _tm_preset_sel:
			continue
		for pf in p.get("fighters", []):
			if int(pf.get("id", 0)) == fid:
				return true
	return false


func _tm_evo_playing() -> Array:
	var playing: Array = []
	for fr in State.roster:
		if int(fr.get("type", 2)) == 2 and int(fr.get("state", 0)) != 1 \
				and int(fr.get("state", 0)) != 5:
			playing.append(_evo_fighter_item(fr))
	while playing.size() < 6:
		playing.append(null)
	return playing


## changeTeamTab(teamManagementTabbedContainer) — repush the shared
## editableTeamPreset fields for the newly shown tab and persist the
## index like retail's lastSelectedGameModeId.
func _on_tm_change_tab(args: Array, w: GWidget) -> void:
	var idx := -1
	var src: GWidget = w
	for a in args:
		if a is GWidget:
			src = a
	if src != null:
		idx = src.selected_index
	if idx < 0:
		return
	_gui.gui.model.set_value("gamePreferences",
		idx, "lastSelectedGameModeId")
	var ev: Variant = _gui.gui.model.get_value("teamManagement",
		"editableTeamPreset")
	var ef: Dictionary = ev if ev is Dictionary else {}
	ef["fighters"] = _tm_classic_pool() if idx in [1, 2, 3] \
		else _tm_evo_playing()
	_gui.gui.model.set_value("teamManagement", ef, "editableTeamPreset")


## addRemoveFighterFromEditableTeamPreset(fighter) — the recruit pool's
## add/remove button; same 6013 wire as the drag-drop path.
func _on_tm_add_remove_fighter(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	var fid := int(row.get("id", row.get("fighterId", 0)))
	if fid <= 0 or _tm_preset_sel <= 0:
		return
	var out := bool(row.get("teamMember", false))
	var wr := WireWriter.new()
	wr.put_i64(fid)
	wr.put_i16(_tm_preset_sel if out else -1)
	wr.put_i16(-1 if out else _tm_preset_sel)
	wr.put_i64(State.my_coach_id)
	Session.send(OP_FIGHTER_ASSIGN, wr.raw(), 2)


## Classic tab — preset rows under teamManager + the selected preset as
## editableTeamPreset.selectedFighters. Legendary evolution fighters feed
## the Legends tab's editableTeamPreset.legendaryFighters /
## evolutionTeam.legendary* lists.
var _tm_preset_sel := -1


func _push_team_classic_model() -> void:
	var model := _gui.gui.model
	var legends: Array = []
	var legends_bench: Array = []
	for fr in State.roster:
		var st := int(fr.get("state", 0))
		var it := _evo_fighter_item(fr)
		if st == 4:
			legends.append(it)
		elif st == 5:
			legends_bench.append(it)
	model.set_value("teamManagement", legends,
		"editableTeamPreset.legendaryFighters")
	model.set_value("evolutionTeam", legends_bench,
		"legendaryFightersOnBench")
	model.set_value("evolutionTeam", _preset_strength(legends),
		"legendaryValue")
	var rows: Array = []
	var rows2: Array = []
	for p in State.presets:
		var fid_list: Array = []
		for pf in p.get("fighters", []):
			var f: Variant = _fighter_by_id(int(pf.get("id", 0)))
			if f != null:
				fid_list.append(_evo_fighter_item(f))
		var row := {"id": int(p.get("id", 0)),
			"teamId": int(p.get("id", 0)),
			"name": str(p.get("name", "")),
			"isEditable": true,
			"background": "", "icon": "",
			"backgroundColor": "", "iconColor": "",
			"strength": _preset_strength(fid_list),
			"level": fid_list.size(),
			"fighters": fid_list,
			"selectedFighters": fid_list,
			"consecutiveVictories": 0, "totalVictories": 0,
			"totalDefeats": 0, "isBestTeam": false}
		if int(p.get("type", 0)) in [-5, -6, -7]:
			row["coachs"] = p.get("coaches", [])
			rows2.append(row)
		else:
			rows.append(row)
	model.set_value("teamManagement", {
		"teamPreset1vs1List": rows,
		"teamPreset2vs2List": rows2,
		"tournamentsList": [], "teamsIconsList": _team_icons(),
		"teamsBackgroundsList": _team_icons()}, "teamManager")
	var gpv: Variant = model.get_value("gamePreferences")
	var gp: Dictionary = gpv if gpv is Dictionary else {}
	gp["showPrebuildTeam"] = true
	model.set_value("gamePreferences", gp)
	# selected preset → editableTeamPreset (classic fields — the evolution
	# tab's editableTeamPreset.fighters is untouched; classic members live
	# under selectedFighters like retail).
	var sel: Variant = null
	for r in rows + rows2:
		if int(r.get("id", -1)) == _tm_preset_sel:
			sel = r
	var efv: Variant = model.get_value("teamManagement",
		"editableTeamPreset")
	var ef: Dictionary = efv if efv is Dictionary else {}
	if sel != null:
		ef["name"] = sel.get("name", "")
		ef["value"] = sel.get("strength", 0)
		ef["selectedFighters"] = sel.get("selectedFighters", [])
	model.set_value("teamManagement", ef, "editableTeamPreset")


func _preset_strength(list: Array) -> int:
	var s := 0
	for f in list:
		if f is Dictionary:
			s += int(f.get("budget", 0))
	return s


## teamNameDialog's icon/background pickers — the retail list is a fixed
## icon sheet; expose the 12 slots the XML enumerates.
func _team_icons() -> Array:
	var out: Array = []
	for i in 12:
		out.append({"id": i, "textureUrl": "", "color": "1,1,1"})
	return out


## selectTeamPreset — the clicked row becomes editableTeamPreset.
func _on_tm_select_preset(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	_tm_preset_sel = int(row.get("id", row.get("teamId", -1)))
	_push_team_classic_model()


## onFighterDropped/onFighterDroppedXvsX — a roster fighter dropped onto a
## preset slot → 6013 [i64 fid][i16 src][i16 dst][i64 coach]. Dropping a
## preset member back onto the roster pool sends dst = -1.
func _on_tm_fighter_dropped(_a: Array, w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	var payload: Variant = dnd.get("item")
	if not (payload is Dictionary):
		return
	var fid := int(payload.get("id", payload.get("fighterId", 0)))
	if fid <= 0:
		return
	# destination: the preset this drop targeted (row's team id), else the
	# roster pool (-1) when the drop landed outside a preset list.
	var dst := _tm_preset_sel
	var row: Variant = _row_item(w)
	if row is Dictionary and row.has("teamId"):
		dst = int(row.get("teamId", dst))
	elif row is Dictionary and row.has("id") and not row.has("fighterId"):
		dst = int(row.get("id", dst))
	if dst <= 0:
		return
	var src := -1
	for p in State.presets:
		for pf in p.get("fighters", []):
			if int(pf.get("id", 0)) == fid:
				src = int(p.get("id", -1))
	var wr := WireWriter.new()
	wr.put_i64(fid)
	wr.put_i16(src)
	wr.put_i16(dst)
	wr.put_i64(State.my_coach_id)
	Session.send(OP_FIGHTER_ASSIGN, wr.raw(), 2)


## deleteEditableTeamPreset(team) → 6023 [i64 team][i16 gm][i16 fa].
func _on_tm_delete_preset(args: Array, w: GWidget) -> void:
	var team_id := _tm_preset_sel
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if row is Dictionary:
		team_id = int(row.get("teamId", row.get("id", team_id)))
	if team_id <= 0:
		return
	var wr := WireWriter.new()
	wr.put_i64(team_id)
	wr.put_i16(0)
	wr.put_i16(0)
	Session.send(OP_TEAM_PRESET_DELETE, wr.raw(), 2)
	if _tm_preset_sel == team_id:
		_tm_preset_sel = -1


## saveTeam — persist editableTeamPreset's members back under its own id
## (6021 sw_1 blob; same layout the debug saver writes). saveTeam(team)
## carries the preset row in the elite/tournament tabs.
func _on_tm_save_team(args: Array, w: GWidget) -> void:
	var team_id := _tm_preset_sel
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if row is Dictionary:
		team_id = int(row.get("teamId", row.get("id", team_id)))
	if team_id <= 0:
		return
	var preset: Variant = null
	for p in State.presets:
		if int(p.get("id", -1)) == team_id:
			preset = p
	if preset == null:
		return
	var wr := WireWriter.new()
	wr.put_i16(int(preset.get("type", 0)))
	wr.put_i16(team_id)
	wr.put_i16(int(preset.get("game_mode", 1)))
	var nb := CP1252.encode(str(preset.get("name", "")))
	wr.put_u8(nb.size())
	wr.put_bytes(nb)
	var members: Array = preset.get("fighters", [])
	wr.put_u8(members.size())
	for pf in members:
		wr.put_i64(int(pf.get("id", 0)))
		wr.put_i64(int(pf.get("owner", State.my_coach_id)))
	wr.put_u8(0)
	wr.put_u8(0)
	Session.send(OP_TEAM_PRESET_SAVE, wr.raw(), 2)


## addNewTeam/addNewTournamentTeam — the name dialog's form → 6021 (aqH:
## raw sw_1 blob). Retail types: -6 elite (teamNameDialog), -5 tournament
## (newTeamTournamentDialog); both carry the 4 appearance bytes picked via
## selectedTeamIcon/selectedTeamBackground (hu_2.java:16632/16660).
func _on_tm_add_team(_args: Array, _w: GWidget, preset_type: int) -> void:
	var model := _gui.gui.model
	var tname := str(model.get_value("teamManagement", "teamName"))
	if tname.strip_edges() == "":
		return
	var wr := WireWriter.new()
	wr.put_i16(preset_type)
	wr.put_i16(0)
	wr.put_i16(1)
	var nb := CP1252.encode(tname.strip_edges())
	wr.put_u8(nb.size())
	wr.put_bytes(nb)
	if preset_type in [-5, -6, -7]:
		var icon := _asv(model.get_value("selectedTeamIcon"))
		var bg := _asv(model.get_value("selectedTeamBackground"))
		wr.put_u8(icon[0] & 0xFF)
		wr.put_u8(icon[1] & 0xFF)
		wr.put_u8(bg[0] & 0xFF)
		wr.put_u8(bg[1] & 0xFF)
	wr.put_u8(0)   # fighters — created empty
	wr.put_u8(0)   # coaches
	wr.put_u8(0)   # trailing pad
	Session.send(OP_TEAM_PRESET_SAVE, wr.raw(), 2)
	for d in ["teamNameDialog", "team2vs2NameDialog",
			"newTeamTournamentDialog"]:
		_gui.close(d)


## asV pair — {id, color} dict → [index, colorIndex] like retail's
## asV(lV, aFS). The icon pickers store plain ints; tolerate both.
func _asv(v: Variant) -> Array:
	if v is Dictionary:
		return [int(v.get("id", 0)), int(v.get("color", 0))]
	if v is int or v is float:
		return [int(v), 0]
	return [0, 0]


## addNewTeamXvsX — 2v2 teams are created by INVITING a teammate, not by
## saving a solo preset: 6024 [str8 name][i64 inviter][i64 invited]
## (hu_2.java:16636 → ir_0). The invited coach comes from
## teamManagement.teammateName (friend-list picker).
func _on_tm_add_team_xvsx(_args: Array, _w: GWidget) -> void:
	var model := _gui.gui.model
	var tname := str(model.get_value("teamManagement", "teamName"))
	if tname.strip_edges() == "":
		return
	var mate: Variant = model.get_value("teamManagement", "teammateName")
	var mate_id := -1
	if mate is Dictionary:
		mate_id = int(mate.get("id", mate.get("coach_id", -1)))
	elif mate is int or mate is float:
		mate_id = int(mate)
	else:
		var mname := str(mate)
		for fr in State.friends:
			if str(fr.get("name", "")) == mname:
				mate_id = int(fr.get("id", fr.get("coach_id", -1)))
	if mate_id <= 0:
		_log_line("[i]pick a teammate for the 2v2 team first[/i]")
		return
	var wr := WireWriter.new()
	wr.put_str(tname.strip_edges(), "u8")
	wr.put_i64(State.my_coach_id)
	wr.put_i64(mate_id)
	Session.send(6024, wr.raw(), 2)
	_gui.close("team2vs2NameDialog")


## selectTeam{Icon,Background} set the asV index; the *ColorIndex events set
## its color — `field` is the model key, `part` the asV component.
func _on_tm_pick_color(args: Array, w: GWidget, field: String,
		part: String) -> void:
	var idx := 0
	if part == "id":
		var row: Variant = _row_item(w)
		if row is Dictionary:
			idx = int(row.get("id", row.get("index", 0)))
	for a in args:
		if a is int or a is float:
			idx = int(a)
		elif a is Dictionary:
			idx = int(a.get("id", idx))
	var cur: Variant = _gui.gui.model.get_value(field)
	var d: Dictionary = cur if cur is Dictionary else {}
	d[part] = idx
	_gui.gui.model.set_value(field, d)


## showHidePrebuildTeams — the preferences checkbox → model flag.
func _on_tm_prebuild_toggle(_a: Array, _w: GWidget) -> void:
	var gpv: Variant = _gui.gui.model.get_value("gamePreferences")
	var gp: Dictionary = gpv if gpv is Dictionary else {}
	gp["showPrebuildTeam"] = not bool(gp.get("showPrebuildTeam", true))
	_gui.gui.model.set_value("gamePreferences", gp)


## selectEditableFighter — preset-member row → editableFighter preview.
func _on_tm_select_editable_fighter(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if row is Dictionary:
		_gui.gui.model.set_value("teamManagement",
			row, "editableFighter")


## The fighter-card item the evolution rows bind — raw roster dict merged
## with the display fields the renderers read (level, morale, paper-doll…).
func _evo_fighter_item(fr: Dictionary) -> Dictionary:
	var breed := clampi(int(fr.get("breed", 1)), 1, 12)
	var sex := clampi(int(fr.get("sex", 0)), 0, 1)
	var item := {
		"id": int(fr.get("id", 0)),
		"fighterId": int(fr.get("id", 0)),
		"name": str(fr.get("name", "")),
		"breedId": breed, "sex": sex,
		"state": int(fr.get("state", 0)),
		"level": int(fr.get("xp", 0)),
		"isHeavy": int(fr.get("tiredness", 0)) >= 80,
		"moraleForProgressBar": int(fr.get("morale", 0)),
		"moraleForTooltip": str(fr.get("morale", 0)),
		"tirednessForProgressBar": int(fr.get("tiredness", 0)),
		"tirednessForTooltip": str(fr.get("tiredness", 0)),
		"tirednessIsDangerous": int(fr.get("tiredness", 0)) >= 80,
		"teamLeague": int(fr.get("board", 0)),
		"maxHealthPoints": 0, "maxActionPoints": 6,
		"maxMovePoints": 3, "initiativePoints": 0,
		"description": "", "conditions": fr.get("conditions", []),
		"torsoInjury": [], "otherInjury": [], "legInjury": [],
		"headInjury": [], "armInjury": [],
		"iconUrl": str(breed * 10),
		"illustrationUrl": str(breed * 10),
		"typeIconUrl": "",
		"actorDescriptorLibrary": "fighter_%s" % \
			_FV.FIGHTER_FILES[(breed - 1) * 2 + sex],
		"actorAnimation": "AnimStatique",
		"actorDirection": 3,
		"actorMaterial": Palettes.fighter_tints(
			int(fr.get("skin", 0)), int(fr.get("hair", 0)),
			int(fr.get("eye", 0)))}
	item.merge(fr, true)
	item["actorDescriptorLibrary"] = "fighter_%s" % \
		_FV.FIGHTER_FILES[(breed - 1) * 2 + sex]
	item["actorMaterial"] = Palettes.fighter_tints(
		int(fr.get("skin", 0)), int(fr.get("hair", 0)),
		int(fr.get("eye", 0)))
	item["state"] = int(fr.get("state", 0))
	return item


## evolution:selectFighter — row becomes the details panel's fighter.
func _on_evo_select_fighter(args: Array, w: GWidget) -> void:
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if not (row is Dictionary):
		return
	_gui.gui.model.set_value("evolutionTeam",
		row, "selectedFighter")


## evolution:changeFighterStatus — the per-row swap button AND the dndc drop
## between the team/bench lists both land here → 23000 state toggle.
func _on_evo_fighter_status(_args: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	if not (row is Dictionary):
		row = dnd.get("item")
	if not (row is Dictionary):
		return
	var fid := int(row.get("id", row.get("fighterId", 0)))
	if fid <= 0:
		return
	var f: Variant = _fighter_by_id(fid)
	if f == null or int(f.get("state", 0)) == 3:
		return
	# 23000 [i64 fid][u8 promote] — retail Jc: flag 0 = titular/bench toggle
	# (both the evolution pair 1↔3 and the legend pair 4↔5); flag 1 is
	# becomeALegend only (event 23068).
	var wr := WireWriter.new()
	wr.put_i64(fid)
	wr.put_u8(0)
	Session.send(OP_FIGHTER_SET_STATE, wr.raw(), 2)


## evolution:becomeALegend — promote the clicked evolution fighter into the
## Legends team → 23000 flag 1 (retail event 23068).
func _on_evo_become_legend(args: Array, w: GWidget) -> void:
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if not (row is Dictionary):
		return
	var fid := int(row.get("id", row.get("fighterId", 0)))
	if fid <= 0:
		return
	var wr := WireWriter.new()
	wr.put_i64(fid)
	wr.put_u8(1)
	Session.send(OP_FIGHTER_SET_STATE, wr.raw(), 2)


## evolution:openCloseSphereBoard(fighter) — the Kanodo grid. The retail
## sphereBoard widget isn't implemented yet; open the existing board panel.
func _on_evo_sphere_board(args: Array, w: GWidget) -> void:
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if not (row is Dictionary):
		return
	var f: Variant = _fighter_by_id(
		int(row.get("id", row.get("fighterId", 0))))
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


## evolution:selectConsumableSet(setList,setDescription) — pick a tome set →
## coachManagement.currentSet {name, description, collectionForEvolution}.
func _on_evo_select_set(args: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if row is Dictionary:
		var coll: Array = []
		for c in row.get("collection", []):
			if c is Dictionary \
					and int(State.inventory.get(int(c.get("id", 0)), 0)) > 0:
				coll.append(c)
		_gui.gui.model.set_value("coachManagement",
			{"name": str(row.get("name", "")),
				"description": str(row.get("description", "")),
				"collectionForEvolution": coll}, "currentSet")
	if args.size() >= 2:
		if args[0] is GWidget: args[0].visible = false
		if args[1] is GWidget: args[1].visible = true


## evolution:goBackToList(setList,setDescription) — back to the summary.
func _on_evo_back_to_list(args: Array, _w: GWidget) -> void:
	if args.size() >= 2:
		if args[0] is GWidget: args[0].visible = true
		if args[1] is GWidget: args[1].visible = false


## evolution:selectCard / showCoachCardInfosEvolution — hover/click a set
## card → coachManagement.selectedCard preview.
func _on_evo_card_infos(_args: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if row is Dictionary:
		_gui.gui.model.set_value("coachManagement",
			row, "selectedCard")


## --- fighterEquipmentDialog (6011 loadout editor) ----------------------------
## editableFighter = working copy of the fighter being dressed: equipment
## slots {0..4 → card}, spells list, breedSpells offer. Save → 6011.
const _EQ_FIELDS := ["weaponEquipment", "petEquipment", "cloakEquipment",
	"hatEquipment", "dofusEquipment"]
const _EQ_PER_PAGE := 8

var _eq_fid := -1
var _eq_cards := {}          # slot int 0-4 -> card template id
var _eq_spells: Array = []   # spell ids currently equipped
var _eq_type := 0            # selectedItemCardListType (slot filter)
var _eq_page := 0


## evolution:editFighter(fighter) → open the equipment editor on that row.
func _on_eq_edit_fighter(args: Array, w: GWidget) -> void:
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if not (row is Dictionary):
		return
	var f: Variant = _fighter_by_id(
		int(row.get("id", row.get("fighterId", 0))))
	if f == null:
		return
	_eq_fid = int(f.id)
	_eq_cards = {}
	for c in f.get("cards", []):
		_eq_cards[int(c.get("slot", 0))] = int(c.get("id", 0))
	_eq_spells = []
	for s in f.get("spells", []):
		_eq_spells.append(int(s))
	_eq_type = 0
	_eq_page = 0
	_push_fequip_model()
	_gui.open("fighterEquipmentDialog")


## Spell-id → the item shape spellFighterCard binds (icons live in
## spells/icons/<id>.png; ap/min/max come from the exported table).
func _spell_item(sid: int) -> Dictionary:
	var m := Spells.meta(sid)
	return {"id": sid, "name": str(m.get("name", "Spell %d" % sid)),
		"iconUrl": str(sid), "illustrationUrl": str(sid),
		"actionPoints": int(m.get("ap", 0)),
		"range": "%d-%d" % [int(m.get("min", 0)), int(m.get("max", 0))],
		"aoe": "", "aoeSize": 0, "cooldown": 0, "target": "",
		"description": "", "backgroundDescription": "",
		"value": int(m.get("value", 0)), "cardType": "spell"}


## Equipment slot item — the slot dndc binds itemIconUrl on top of the
## shared card fields.
func _equip_slot_item(cid: int) -> Variant:
	if cid <= 0 or int(State.inventory.get(cid, 0)) <= 0:
		return null
	var it := _card_item(cid)
	it["itemIconUrl"] = str(cid)
	return it


func _push_fequip_model() -> void:
	var f: Variant = _fighter_by_id(_eq_fid)
	if f == null:
		return
	var model := _gui.gui.model
	var breed := clampi(int(f.get("breed", 1)), 1, 12)
	var sex := clampi(int(f.get("sex", 0)), 0, 1)
	var spells: Array = []
	for sid in _eq_spells:
		spells.append(_spell_item(sid))
	while spells.size() < 7:
		spells.append(null)
	var offers: Array = []
	for s in Spells.for_breed(breed):
		var it := _spell_item(int(s.id))
		it["equipped"] = _eq_spells.has(int(s.id))
		offers.append(it)
	var ef := {"id": _eq_fid, "fighterId": _eq_fid,
		"name": str(f.get("name", "")), "breedId": breed, "sex": sex,
		"maxHealthPoints": 0, "maxActionPoints": 6, "maxMovePoints": 3,
		"initiativePoints": 0, "criticalHitBonus": 0, "rangeBonus": 0,
		"healBonus": 0, "damagesRebound": 0, "dodgePercent": 0,
		"tacklePercent": 0,
		"resEarthPercent": 0, "resFirePercent": 0, "resWaterPercent": 0,
		"resWindPercent": 0,
		"dmgEarthPercent": 0, "dmgFirePercent": 0, "dmgWaterPercent": 0,
		"dmgWindPercent": 0,
		"value": int(f.get("budget", 0)),
		"actorDescriptorLibrary": "fighter_%s" % \
			_FV.FIGHTER_FILES[(breed - 1) * 2 + sex],
		"actorMaterial": Palettes.fighter_tints(
			int(f.get("skin", 0)), int(f.get("hair", 0)),
			int(f.get("eye", 0))),
		"spells": spells, "breedSpells": offers}
	for s in _EQ_FIELDS.size():
		ef[_EQ_FIELDS[s]] = _equip_slot_item(int(_eq_cards.get(s, 0)))
	model.set_value("teamManagement", ef, "editableFighter")
	model.set_value("teamManagement", _eq_type,
		"selectedItemCardListType")
	var pool: Array = []
	for cid in State.inventory:
		if int(Cards.meta(int(cid)).get("type", 0)) == _eq_type + 1 \
				and int(State.inventory[cid]) > 0:
			pool.append(_equip_slot_item(int(cid)))
	var max_page := maxi(0, (pool.size() - 1) / _EQ_PER_PAGE)
	_eq_page = clampi(_eq_page, 0, max_page)
	model.set_value("teamManagement",
		pool.slice(_eq_page * _EQ_PER_PAGE,
			(_eq_page + 1) * _EQ_PER_PAGE), "selectedItemCardList")


## changeItemCardType(N) — pick which slot's card pool the strip lists.
func _on_eq_change_type(args: Array, _w: GWidget) -> void:
	for a in args:
		if a is int or a is float:
			_eq_type = clampi(int(a), 0, 4)
	_eq_page = 0
	_push_fequip_model()


## increaseList/decreaseList(itemList) — page the equipment strip.
func _on_eq_page(_a: Array, _w: GWidget, delta: int) -> void:
	_eq_page += delta
	_push_fequip_model()


## addEquipment(fighter) — double-click a strip card → its type's slot.
func _on_eq_add_equipment(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	var cid := int(row.get("id", 0))
	var t := int(Cards.meta(cid).get("type", 0))
	if t >= 1 and t <= 5:
		_eq_cards[t - 1] = cid
		_push_fequip_model()


## removeEquipment(fighter,N) — double-click the equipped slot → unequip.
func _on_eq_remove_equipment(args: Array, w: GWidget) -> void:
	var slot := -1
	for a in args:
		if a is int or a is float:
			slot = int(a)
	if slot < 0:
		var row: Variant = _row_item(w)
		if row is Dictionary:
			for s in _EQ_FIELDS.size():
				if _eq_cards.get(s, -1) == int(row.get("id", -2)):
					slot = s
	if slot >= 0:
		_eq_cards.erase(slot)
		_push_fequip_model()


## addSpell/removeSpell — double-click a breed-spell row ↔ equipped row.
func _on_eq_add_spell(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	var sid := int(row.get("id", 0))
	if sid > 0 and not _eq_spells.has(sid) and _eq_spells.size() < 6:
		_eq_spells.append(sid)
		_push_fequip_model()


func _on_eq_remove_spell(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if row is Dictionary:
		_eq_spells.erase(int(row.get("id", 0)))
		_push_fequip_model()


## dragEquipment(fighter,N) fires at drag start — remember the source slot
## so a drop elsewhere unequips it (the payload is the slot's own item).
func _on_eq_drag_equipment(args: Array, _w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	for a in args:
		if a is int or a is float:
			dnd["from_slot"] = int(a)


## dropEquipment(fighter,N) — a strip card (or another slot's item) onto
## slot N; the card's record type must match (type = slot+1, vi_1 order).
func _on_eq_drop_equipment(args: Array, _w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	var payload: Variant = dnd.get("item")
	if not (payload is Dictionary):
		return
	var slot := -1
	for a in args:
		if a is int or a is float:
			slot = int(a)
	var cid := int(payload.get("id", 0))
	if slot < 0 or cid <= 0:
		return
	if int(Cards.meta(cid).get("type", 0)) != slot + 1:
		return
	if dnd.has("from_slot"):
		_eq_cards.erase(int(dnd["from_slot"]))
	_eq_cards[slot] = cid
	_push_fequip_model()


## dropSpell(fighter) — a breed-spell row dragged onto the equipped list.
func _on_eq_drop_spell(_a: Array, _w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	var payload: Variant = dnd.get("item")
	if payload is Dictionary and str(payload.get("cardType", "")) == "spell":
		var sid := int(payload.get("id", 0))
		if sid > 0 and not _eq_spells.has(sid) and _eq_spells.size() < 6:
			_eq_spells.append(sid)
			_push_fequip_model()


## showEquipmentInfos/showSpellInfos — hover → selectedCard preview.
func _on_eq_show_infos(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if row is Dictionary:
		_gui.gui.model.set_value("teamManagement",
			row, "selectedCard")


## showHelp(key) — the spell-card stat labels' rollover help.
func _on_eq_show_help(args: Array, _w: GWidget) -> void:
	if args.is_empty():
		return
	var model := _gui.gui.model
	model.set_value("teamManagement",
		_gui.gui.loader.i18n_str(str(args[0])), "help")
	model.set_value("teamManagement", str(args[0]), "helpIcon")


## saveEditableFighter(fighter) → 6011 [i64 fid][i16 team][u16 spellLen]
## {i32 spells}[u16 cardLen]{i16 slot,i32 card} — same layout as the
## debug editor (spells blob first, equipment positions after).
func _on_eq_save(_a: Array, _w: GWidget) -> void:
	if _eq_fid < 0:
		return
	var wr := WireWriter.new()
	wr.put_i64(_eq_fid)
	wr.put_u16(0)
	wr.put_u16(_eq_spells.size() * 4)
	for s in _eq_spells:
		wr.put_i32(int(s))
	wr.put_u16(_eq_cards.size() * 6)
	for s in _eq_cards.keys():
		wr.put_u16(int(s))
		wr.put_i32(int(_eq_cards[s]))
	Session.send(OP_FIGHTER_LOADOUT, wr.raw(), 2)
	_log_line("loadout saved: %d spells, %d items" % [
		_eq_spells.size(), _eq_cards.size()])
	_gui.gui.model.set_value("coachManagement", {"currentSet": ""})
	_gui.gui.model.set_value("tomeManager", false)


## --- lobby dialogs: model pushes on open + dofusarena.social:* ---------------

## Called by GuiLayer for every XULOR2 dialog that mounts — feed each
## screen's model from State before its first draw.
func _on_gui_dialog_opened(name: String) -> void:
	match name:
		"socialDialog":
			_push_social_model()
		"guildDialog":
			_push_social_model()
			_request_guild_refresh()
		"guildManagementDialog":
			_push_guild_mgmt_model()
		"coachStatisticsDialog":
			_push_local_coach()
		"teamManagementDialog", "evolutionDialog":
			_push_team_model()
		"fighterEquipmentDialog":
			_push_fequip_model()
		"ladderInformationDialog":
			_request_all_ladders()
			_push_ladder_model()
		"zaapDialog":
			_push_zaap_model()
		"cardBookDialog":
			_push_cardbook_model()
		"calendarDialog":
			if _calendar_events.is_empty():
				Session.send(OP_TOURN_CAL, PackedByteArray(), 3)
			_push_calendar_model()
		"achievementDialog":
			_ach_sel = {"type": -1, "sub": -1}
			_push_achievement_model()
		"optionsDialog":
			_push_options_model()
		"fusionLabDialog":
			_push_cardbook_model()   # the include's inventory tab needs it
			_push_fusion_model()
		"mailboxDialog":
			if _mails.is_empty():
				Session.send(OP_MAILBOX_REQ, PackedByteArray(), 3)
			_push_mail_model()
		"newMailDialog":
			_push_cardbook_model()
		"demonAffiliationDialog":
			_push_cardbook_model()
			_push_demon_model()
		"fireworkDialog":
			_push_cardbook_model()
			_push_firework_model()
		"mapDialog", "miniMapDialog":
			_push_map_model()
		"exchangeDialog", "cardMasterDialog":
			_push_cardbook_model()   # embedded inventory include
			if name == "exchangeDialog":
				_push_exchange_model()


## friends.list / ignore.list / guild.{members,name} for the social tabs.
func _push_social_model() -> void:
	var model := _gui.gui.model
	var fl: Array = []
	for fr in State.friends:
		fl.append({"name": str(fr.get("name", "")),
			"online": bool(fr.get("online", false)),
			"notify": int(fr.get("notify", 0)),
			"connected": bool(fr.get("online", false))})
	model.set_value("friends", {"list": fl})
	var il: Array = []
	for nm in State.ignored:
		il.append({"name": str(nm)})
	model.set_value("ignore", {"list": il})
	var gm: Array = []
	for m in State.guild.get("members", []):
		var it := {"name": str(m.get("name", "")),
			"connected": bool(m.get("online", false)),
			"rankIconUrl": "", "guildInfos": ""}
		it.merge(m, true)   # coach_id/rank_level ride for stats & kick
		gm.append(it)
	model.set_value("guild", {
		"name": str(State.guild.get("guild", "")),
		"members": gm,
		"canManage": _has_right(GUILD_RIGHT_LEADER)
			if not State.guild.is_empty() else false,
		"guildInfos": ""})
	model.set_value("guildMaster",
		_has_right(GUILD_RIGHT_LEADER) if not State.guild.is_empty() else false)
	# guildInviter gates the invite-send panel — the INVITE right
	model.set_value("guildInviter",
		_has_right(GUILD_RIGHT_INVITE) if not State.guild.is_empty() else false)


## --- ladderInformationDialog -------------------------------------------------
## ladderManager holds one list per tab; rows come from the last reply
## cached per request opcode in _ladder_data.

var _ladder_data := {}    # request opcode -> last decoded ladder reply


func _ladder_items(rows: Array, fields: Array, vals: Callable) -> Array:
	var out: Array = []
	var i := 0
	for r in rows:
		var it := {"position": i + 1, "style": ""}
		var v: Dictionary = vals.call(r)
		for f in fields:
			it[f] = v.get(f, 0 if f in ["level", "rating", "reputation",
				"strength", "points", "quarterlyReputationPoints",
				"totalVictories", "totalDefeats",
				"consecutiveVictories"] else "")
		out.append(it)
		i += 1
	return out


func _push_ladder_model() -> void:
	var lm := {}
	var d: Dictionary = _ladder_data.get(OP_LADDER_1V1, {})
	lm["list1vs1"] = _ladder_items(d.get("rows", []),
		["coachName", "guildName", "level", "rankIconUrl", "rankName",
		 "totalVictories", "totalDefeats", "consecutiveVictories"],
		func(r): return {
			"coachName": str(r.get("name", "")),
			"guildName": str(r.get("guild", "")),
			"totalVictories": int(r.get("wins", 0)),
			"totalDefeats": int(r.get("losses", 0)),
			"consecutiveVictories": int(r.get("streak", 0))})
	d = _ladder_data.get(OP_LADDER_COACH, {})
	lm["listReputation"] = _ladder_items(d.get("rows", []),
		["creatorCoachName", "demonName", "guildName", "reputation",
		 "totalVictories", "totalDefeats"],
		func(r): return {
			"creatorCoachName": str(r.get("coach", "")),
			"demonName": str(r.get("demon", "")),
			"reputation": int(r.get("rep", 0)),
			"totalVictories": int(r.get("wins", 0)),
			"totalDefeats": int(r.get("losses", 0))})
	d = _ladder_data.get(OP_LADDER_2V2, {})
	lm["list2vs2"] = _ladder_items(d.get("rows", []),
		["teamName", "coachName", "guildName", "level", "rankIconUrl",
		 "rankName", "totalVictories", "totalDefeats",
		 "consecutiveVictories"],
		func(r): return {
			"teamName": str(r.get("team", "")),
			"coachName": str(r.get("coaches", "")),
			"guildName": str(r.get("guild", "")),
			"totalVictories": int(r.get("wins", 0)),
			"totalDefeats": int(r.get("losses", 0))})
	d = _ladder_data.get(OP_LADDER_GUILD, {})
	lm["listGuild"] = _ladder_items(d.get("rows", []),
		["name", "bossName", "strength"],
		func(r): return {
			"name": str(r.get("guild", "")),
			"bossName": str(r.get("leader", "")),
			"strength": int(r.get("score", 0))})
	d = _ladder_data.get(OP_LADDER_TOURN, {})
	var wins: Array = d.get("windows", [])
	var wnames := ["Month", "Trimester", "Year"]
	for i in wnames.size():
		var rows: Array = wins[i].get("rows", []) if i < wins.size() else []
		lm["listTournamentInThe%s" % wnames[i]] = \
			_ladder_items(rows, ["name", "points"],
				func(r): return {"name": str(r.get("name", "")),
					"points": int(r.get("points", 0))})
	d = _ladder_data.get(OP_LADDER_PRO, {})
	lm["listGlickoRating"] = _ladder_items(d.get("rows", []),
		["coachName", "guildName", "rating"],
		func(r): return {
			"coachName": str(r.get("name", "")),
			"guildName": str(r.get("guild", "")),
			"rating": int(r.get("rating", 0))})
	lm["proLeagueDefinitionName"] = "Arena Ligue Pro"
	d = _ladder_data.get(OP_LADDER_DEMON, {})
	lm["listDemon"] = _ladder_items(d.get("rows", []),
		["demonName", "guildName", "quarterlyReputationPoints"],
		func(r): return {
			"demonName": "Demon %d" % int(r.get("demon", 0)),
			"guildName": str(r.get("guild", "")),
			"quarterlyReputationPoints": int(r.get("rep", 0))})
	_gui.gui.model.set_value("ladderManager", lm)
	# search/paging button visibility flags the tabs bind to
	for n in ["ladderPlayerSearchButtonVisible",
			"ladderReputationSearchButtonVisible",
			"ladder2vs2BestTeamSearchButtonVisible",
			"ladderGlickoRatingSearchButtonVisible"]:
		_gui.gui.model.set_value(n, true)


## The retail ladder tab order matches LADDER_TABS[0..6]; read the live
## selection off the dialog's tabbedContainer widget.
func _ladder_gui_tab() -> int:
	var root: GWidget = _gui.dialogs.get("ladderInformationDialog")
	if root != null:
		var tc := _find_kind(root, "tabbedContainer")
		if tc != null:
			return clampi(int(tc.selected_index), 0, 6)
	return _ladder_tab


func _find_kind(w: GWidget, k: String) -> GWidget:
	if w.kind == k:
		return w
	for ch in w.get_children():
		if ch is GWidget:
			var r := _find_kind(ch, k)
			if r != null:
				return r
	return null


func _ladder_gui_page(delta: int) -> void:
	_ladder_tab = _ladder_gui_tab()
	var board: Dictionary = _ladder_data.get(
		int(LADDER_TABS[_ladder_tab].op), {})
	var cur := int(board.get("start", 0))
	var total := int(board.get("total", 0))
	_ladder_start = maxi(0, cur + delta)
	if total > 0:
		_ladder_start = mini(_ladder_start, total - 1)
	_ladder_request()


func _ladder_gui_first() -> void:
	_ladder_tab = _ladder_gui_tab()
	_ladder_start = 0
	_ladder_request()


func _ladder_gui_last() -> void:
	_ladder_tab = _ladder_gui_tab()
	var board: Dictionary = _ladder_data.get(
		int(LADDER_TABS[_ladder_tab].op), {})
	var total := int(board.get("total", 0))
	_ladder_start = maxi(0, total - int(LADDER_TABS[_ladder_tab].page))
	_ladder_request()


func _ladder_gui_mine() -> void:
	_ladder_tab = _ladder_gui_tab()
	var board: Dictionary = _ladder_data.get(
		int(LADDER_TABS[_ladder_tab].op), {})
	_ladder_start = maxi(0, int(board.get("my_rank", 0)) - 1)
	_ladder_request()


## On open, fetch every board the dialog can show — replies land in
## _ladder_data and refresh ladderManager as they arrive.
func _request_all_ladders() -> void:
	var saved_tab := _ladder_tab
	var saved_start := _ladder_start
	for i in 7:
		_ladder_tab = i
		_ladder_start = 0
		_ladder_request()
	_ladder_tab = saved_tab
	_ladder_start = saved_start


## --- zaapDialog --------------------------------------------------------------
## tomeManager.zaapSets = the special card sets (those holding type-20
## zaap cards); each set's `collection` feeds the card grid.

func _push_zaap_model() -> void:
	var sets := {}     # set id -> {cards, owned}
	for cid in Cards.all_ids():
		var m := Cards.meta(int(cid))
		var sid := int(m.get("set", 0))
		if sid <= 0:
			continue
		var has_zaap := int(m.get("type", 0)) == 20
		if not sets.has(sid):
			sets[sid] = {"cards": [], "owned": 0, "zaap": false}
		sets[sid]["cards"].append(int(cid))
		sets[sid]["zaap"] = sets[sid]["zaap"] or has_zaap
		if int(State.inventory.get(int(cid), 0)) > 0:
			sets[sid]["owned"] += 1
	var zs: Array = []
	for sid in sets:
		var sd: Dictionary = sets[sid]
		if not sd["zaap"]:
			continue
		var coll: Array = []
		for cid in sd["cards"]:
			var qty := int(State.inventory.get(cid, 0))
			coll.append({
				"id": cid, "name": Cards.name_of(cid),
				"illustrationUrl": str(cid),
				"tomeStyle": "" if qty > 0 else "BackZaapCoachCard",
				"globalQuantity": qty,
				"isInTome": qty > 0, "quantity": qty})
		coll.sort_custom(func(a, b): return int(a.id) < int(b.id))
		zs.append({
			"name": _set_name(sd["cards"]),
			"size": sd["cards"].size(),
			"completion": sd["owned"],
			"description": "",
			"collection": coll,
			"illustrationUrl": str(sd["cards"][0]),
			"isInTome": int(sd["owned"]) == sd["cards"].size(),
			"tomeStyle": ""})
	zs.sort_custom(func(a, b): return str(a.name) < str(b.name))
	_gui.gui.model.set_value("tomeManager", {"zaapSets": zs})


## Card-set display name — longest shared prefix of its cards (family
## names like "Weerdtrot" / "Zatrox"), else the first card's name.
func _set_name(cards: Array) -> String:
	if cards.is_empty():
		return ""
	var prefix: String = Cards.name_of(int(cards[0]))
	for c in cards:
		var n := Cards.name_of(int(c))
		var i := 0
		while i < prefix.length() and i < n.length() and prefix[i] == n[i]:
			i += 1
		prefix = prefix.left(i)
	prefix = prefix.strip_edges()
	if prefix.length() < 3:
		var words := Cards.name_of(int(cards[0])).split(" ")
		prefix = " ".join(words.slice(0, maxi(1, words.size() - 1)))
	return prefix


## goToSet(specialList,specialSetDetails,4) — open the set detail pane:
## the clicked row's item is the set dict → coachManagement.currentSet.
func _on_zaap_go_to_set(args: Array, w: GWidget) -> void:
	if w != null and w.item_value is Dictionary:
		_gui.gui.model.set_value("coachManagement",
			w.item_value, "currentSet")
	if args.size() >= 2:
		if args[0] is GWidget:
			args[0].visible = false
		if args[1] is GWidget:
			args[1].visible = true


## goToSetList has two call shapes sharing one method name:
##   goToSetList(specialList,specialSetDetails) — zaap: show list, hide details
##   goToSetList(inventoryTab,N[,list,details]) — inventory: select tab N
func _on_cardbook_tab(args: Array, _w: GWidget) -> void:
	if args.size() < 2 or not (args[0] is GWidget):
		return
	if args[1] is GWidget:
		args[0].visible = true
		args[1].visible = false
		return
	args[0].selected_index = int(args[1])
	args[0].queue_redraw()
	if args.size() >= 4:
		if args[2] is GWidget:
			args[2].visible = true
		if args[3] is GWidget:
			args[3].visible = false


## selectEquipmentTypeFilter(coach,N) — checkbox toggles type N in/out of
## the equipment filter; coachManagement.inventoryCardTypeFilter holds the
## per-type checkbox state, we keep the active mask alongside it.
var _equip_filter := {}   # card type -> bool shown (default all)


func _on_equip_type_filter(args: Array, _w: GWidget) -> void:
	if args.size() < 2:
		return
	var t := int(args[1])
	_equip_filter[t] = not _equip_filter.get(t, true)
	_sync_equip_filter_model()
	_push_cardbook_model()


func _on_equip_filter_all(_a: Array, _w: GWidget) -> void:
	# all-on (the default) -> all-off; otherwise back to all-on
	var all_on := true
	for t in range(1, 20):
		if not _equip_filter.get(t, true):
			all_on = false
	for t in range(1, 20):
		_equip_filter[t] = not all_on
	_sync_equip_filter_model()
	_push_cardbook_model()


const _FILTER_FIELDS := {7: "shoulderpadFilter", 11: "beltFilter",
	4: "bootsFilter", 3: "hatFilter", 5: "cloakFilter", 10: "amuletFilter",
	2: "ringFilter", 6: "weaponFilter", 13: "offhandFilter",
	8: "petFilter", 12: "dofusFilter", 9: "setFilter"}


func _sync_equip_filter_model() -> void:
	var f := {}
	for t in _FILTER_FIELDS:
		f[_FILTER_FIELDS[t]] = _equip_filter.get(t, true)
	_gui.gui.model.set_value("coachManagement", f,
		"inventoryCardTypeFilter")


func _on_card_hover(_a: Array, w: GWidget) -> void:
	if w != null and w.item_value is Dictionary:
		_gui.gui.model.set_value("coachManagement",
			w.item_value, "selectedCard")


func _on_card_unhover(_a: Array, _w: GWidget) -> void:
	_gui.gui.model.set_value("coachManagement", null, "selectedCard")


## useSpecialCard — zaap-type (20) cards teleport via the shared zaap
## path; the 21-23 special actions (rename, firework…) are UI events we
## don't support yet, so non-zaap cards no-op here.
func _on_use_special_card(_a: Array, w: GWidget) -> void:
	var card = w.item_value if w != null else null
	if not (card is Dictionary):
		card = _gui.gui.model.values.get(
			"coachManagement", {}).get("selectedCard")
	if card is Dictionary \
			and int(card.get("cardType", card.get("type", 0))) == 20:
		_on_zaap_change_instance(_a, w)


func _step_set(args: Array, delta: int) -> void:
	if args.is_empty() or not (args[0] is GWidget):
		return
	var n: int = args[0].content_items.size()
	if n == 0:
		return
	args[0].selected_index = wrapi(
		args[0].selected_index + delta, 0, n)
	args[0].queue_redraw()


## changeInstance(card) — double-click a zaap card teleports (retail
## sends its own opcode; ours is OP_ZAAP [i32 cardTemplateId]). The
## cardBook's detail-panel button passes the hovered selectedCard.
func _on_zaap_change_instance(_args: Array, w: GWidget) -> void:
	var card = w.item_value if w != null else null
	if not (card is Dictionary):
		card = _gui.gui.model.values.get(
			"coachManagement", {}).get("selectedCard")
	if not (card is Dictionary):
		return
	var cid := int(card.get("id", 0))
	if cid <= 0 or int(Cards.meta(cid).get("type", 0)) != 20:
		return
	if int(State.inventory.get(cid, 0)) <= 0:
		return
	var wr := WireWriter.new()
	wr.put_i32(cid)
	Session.send(OP_ZAAP, wr.raw(), 3)
	_gui.close("zaapDialog")


## --- cardBookDialog (coach inventory) ----------------------------------------
## Inventory tabs bind coachManagement.*Inventory lists; the summary tab
## binds tomeManager's five set-category lists.

func _card_item(cid: int) -> Dictionary:
	var m := Cards.meta(cid)
	var qty := int(State.inventory.get(cid, 0))
	return {"id": cid, "name": Cards.name_of(cid),
		"iconUrl": str(cid), "illustrationUrl": str(cid),
		"quantity": qty, "globalQuantity": qty,
		"cardType": int(m.get("type", 0)),
		"description": "", "coachCardEffects": [],
		"showEvolutionBonus": false,
		"value": int(m.get("value", 0)),
		"requiredLevel": "", "typeIconUrl": "",
		"cardSetName": _set_name_for(int(m.get("set", 0))),
		"rarity": Color(1.0, 0.6, 0.1) if bool(m.get("unique", false))
			else Color(1, 1, 1),
		"tomeStyle": "" if qty > 0 else "BackZaapCoachCard",
		"isInTome": qty > 0}


## set id -> shared-name prefix (memoized; _all_card_sets builds once)
var _set_name_cache := {}


func _set_name_for(sid: int) -> String:
	if sid <= 0:
		return ""
	if not _set_name_cache.has(sid):
		var cards: Array = []
		for cid in Cards.all_ids():
			if int(Cards.meta(int(cid)).get("set", 0)) == sid:
				cards.append(int(cid))
		_set_name_cache[sid] = _set_name(cards)
	return _set_name_cache[sid]


func _push_cardbook_model() -> void:
	var equip: Array = []
	var zaap: Array = []
	var special: Array = []
	var all_cards: Array = []
	var owned := State.inventory.keys()
	owned.sort()
	for cid in owned:
		var t := int(Cards.meta(int(cid)).get("type", 0))
		var it := _card_item(int(cid))
		all_cards.append(it)
		match t:
			20:
				zaap.append(it)
			21, 22, 23:
				special.append(it)
			_:
				if t >= 1 and t <= 19 \
						and _equip_filter.get(t, true):
					equip.append(it)
	var model := _gui.gui.model
	_sync_equip_filter_model()
	# the inventory tabs all bind localCoach.<field>
	model.set_value("localCoach", equip, "filtredEquipmentCardInventory")
	model.set_value("localCoach", zaap, "zaapInventory")
	model.set_value("localCoach", special, "specialCardInventory")
	model.set_value("localCoach", all_cards, "filtredCardInventory")
	model.set_value("localCoach", all_cards, "cardInventory")
	model.set_value("localCoach", [], "filtredSetCardInventory")
	model.set_value("localCoach", _all_card_sets(), "cardSets")
	model.set_value("localCoach", [], "cardCostFilterList")
	model.set_value("localCoach", "", "selectedCostFilter")
	model.set_value("isEvolutionMode", false)
	model.set_value("tome", {"actionCards": [], "currentBreed": "",
		"currentBreedDescription": "",
		"currentBreedHelpDescription": ""})
	# tome summary: five categories — classify by content until the
	# retail set-kind metadata is decoded
	var cheap: Array = []
	var expensive: Array = []
	var spec: Array = []
	var fight: Array = []
	var evo: Array = []
	for sd in _all_card_sets():
		var items: Array = sd["collection"]
		var has_special := false
		var all_fight := items.size() > 0
		var total_v := 0
		for c in items:
			var t := int(Cards.meta(int(c.id)).get("type", 0))
			if t in [20, 21, 22, 23]:
				has_special = true
			if t < 24:
				all_fight = false
			total_v += int(Cards.meta(int(c.id)).get("value", 0))
		if has_special:
			spec.append(sd)
		elif all_fight:
			fight.append(sd)
		elif items.size() > 0 and total_v / items.size() < 10000:
			cheap.append(sd)
		else:
			expensive.append(sd)
	model.set_value("tomeManager", {"cheapSets": cheap,
		"expensiveSets": expensive, "specialSets": spec,
		"fightSets": fight, "evolutionSets": evo,
		"zaapSets": spec})


## Every card set in cards.json (for the tome + set-tab pickers).
func _all_card_sets() -> Array:
	var groups := {}
	for cid in Cards.all_ids():
		var m := Cards.meta(int(cid))
		var sid := int(m.get("set", 0))
		if sid <= 0:
			continue
		if not groups.has(sid):
			groups[sid] = []
		groups[sid].append(int(cid))
	var out: Array = []
	for sid in groups:
		var cards: Array = groups[sid]
		cards.sort()
		var coll: Array = []
		var owned := 0
		for cid in cards:
			coll.append(_card_item(cid))
			if int(State.inventory.get(cid, 0)) > 0:
				owned += 1
		out.append({"name": _set_name(cards), "size": cards.size(),
			"completion": owned, "description": "", "collection": coll,
			"illustrationUrl": str(cards[0]),
			"isInTome": owned == cards.size(), "tomeStyle": ""})
	out.sort_custom(func(a, b): return str(a.name) < str(b.name))
	return out


## --- calendarDialog ------------------------------------------------------------

var _calendar_events: Array = []   # decoded 17003 rows
var _calendar_month_off := 0       # showNext/PreviousMonth offset

const MONTH_NAMES := ["january", "february", "march", "april", "may",
	"june", "july", "august", "september", "october", "november",
	"december"]


func _days_in_month(year: int, month: int) -> int:
	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31
		4, 6, 9, 11:
			return 30
		_:
			return 29 if (year % 4 == 0 and (year % 100 != 0
				or year % 400 == 0)) else 28


func _push_calendar_model() -> void:
	var model := _gui.gui.model
	var base := Time.get_datetime_dict_from_system()
	var year := int(base.year)
	var month := int(base.month) + _calendar_month_off
	while month > 12:
		month -= 12
		year += 1
	while month < 1:
		month += 12
		year -= 1
	var dim := _days_in_month(year, month)
	var first := Time.get_datetime_dict_from_unix_time(
		Time.get_unix_time_from_datetime_dict(
			{"year": year, "month": month, "day": 1}))
	# Monday-first grid: leading empty cells before day 1
	var off := (int(first.weekday) + 6) % 7
	var cells: Array = []
	for i in off:
		cells.append({"day": "", "events": [], "style": "",
			"hasMoreEventsToShow": false})
	for day_i in range(1, dim + 1):
		var evs: Array = []
		for e in _calendar_events:
			var ed := Time.get_datetime_dict_from_unix_time(
				int(e.get("runs_until", 0)) / 1000)
			if int(ed.year) == year and int(ed.month) == month \
					and int(ed.day) == day_i:
				evs.append({"title": str(e.get("name", "")),
					"typeIcon": "",
					"description": str(e.get("desc", "")),
					"registrationButton": true,
					"style": "", "id": int(e.get("tid", -1))})
		cells.append({"day": str(day_i), "events": evs,
			"hasMoreEventsToShow": evs.size() > 3, "style": ""})
	model.set_value("calendar", {
		"currentMonth": "%s %d" % [MONTH_NAMES[month - 1].capitalize(), year],
		"calendar": cells,
		"fullEventList": {"events": [], "style": ""},
		"eventFilter": {"showAllEvent": true,
			"tournamentEventFilter": true,
			"maintenanceEventFilter": true,
			"broadcastEventFilter": true}})
	model.set_value("itemOver", {})
	model.set_value("itemSelected", {})


func _on_calendar_month(_a: Array, _w: GWidget, delta: int) -> void:
	_calendar_month_off += delta
	_push_calendar_model()


## showFullEventList(eventListContainer,eventDescription,eventList,
## calendarDay) — fill the shared day-detail list with the clicked day's
## events; args[3] resolves the row's <data id="calendarDay">.
func _on_calendar_day_events(args: Array, _w: GWidget) -> void:
	var day_cell = args[3] if args.size() > 3 else null
	if not (day_cell is Dictionary):
		return
	_gui.gui.model.set_value("calendar",
		{"events": day_cell.get("events", []), "style": ""},
		"fullEventList")


func _on_calendar_highlight(a: Array, w: GWidget) -> void:
	var ev = a[0] if not a.is_empty() else \
		(w.item_value if w != null else null)
	if ev is Dictionary:
		_gui.gui.model.set_value("itemOver", ev)
		_gui.gui.model.set_value("itemSelected", ev)


func _on_calendar_register(args: Array, w: GWidget) -> void:
	var ev = args[0] if not args.is_empty() else \
		(w.item_value if w != null else null)
	if not (ev is Dictionary):
		return
	var tid := int(ev.get("id", -1))
	if tid < 0:
		return
	var wr := WireWriter.new()
	wr.put_i64(tid)
	wr.put_i64(State.my_coach_id)
	wr.put_i16(-1)
	wr.put_i32(0)
	Session.send(OP_TOURN_REGISTER, wr.raw(), 2)


## --- achievementDialog --------------------------------------------------------
## achievementManager: types/subtypes tabs group the NpcDialogs rows by
## cat/sub; selecting one filters achievementsList.

var _ach_sel := {"type": -1, "sub": -1}


func _achievement_items() -> Array:
	var rows := NpcDialogs.achievement_rows(State.criteria, State.inventory)
	var items: Array = []
	for r0 in rows:
		var aid := int(r0.id)
		var info := NpcDialogs.achievement_info(aid)
		if _ach_sel["type"] >= 0 \
				and int(info.get("cat", 0)) != _ach_sel["type"]:
			continue
		if _ach_sel["sub"] >= 0 \
				and int(info.get("sub", 0)) != _ach_sel["sub"]:
			continue
		var done := bool(r0.done)
		items.append({"id": aid,
			"name": NpcDialogs.achievement_name(aid),
			"points": int(info.get("pts", 0)),
			"grade": int(info.get("cat", 0)),
			"iconUrl": "", "keyIconUrl": "",
			"completion": 100 if done else
				NpcDialogs.achievement_progress(
					aid, State.criteria, State.inventory),
			"descriptionDone": NpcDialogs.achievement_desc(aid)
				if done else "",
			"isSelected": false,
			"style": "done" if done else "", "subtypes": []})
	return items


func _push_achievement_model() -> void:
	var rows := NpcDialogs.achievement_rows(State.criteria, State.inventory)
	var total := 0
	var types := {}
	for r0 in rows:
		var info := NpcDialogs.achievement_info(int(r0.id))
		if bool(r0.done):
			total += int(info.get("pts", 0))
		var cat := int(info.get("cat", 0))
		if not types.has(cat):
			types[cat] = {}
		types[cat][int(info.get("sub", 0))] = true
	var tl: Array = []
	var cats := types.keys()
	cats.sort()
	for cat in cats:
		var subs: Array = []
		for s in types[cat]:
			subs.append({"name": "Type %d" % s, "sub": s,
				"cat": cat,
				"isSelected": s == _ach_sel["sub"]})
		subs.sort_custom(func(a, b): return int(a.sub) < int(b.sub))
		tl.append({"name": "Type %d" % cat, "cat": cat,
			"isSelected": cat == _ach_sel["type"], "subtypes": subs})
	_gui.gui.model.set_value("achievementManager", {
		"achievementsList": _achievement_items(),
		"achievementTypesList": tl,
		"achievementsTotalPoints": total})
	var sel = null
	for t in tl:
		if t["isSelected"]:
			sel = t
	if sel == null and not tl.is_empty():
		sel = tl[0]
	_gui.gui.model.set_value("selectedAchievementType", sel)


func _on_ach_select_type(_a: Array, w: GWidget) -> void:
	if w == null or not (w.item_value is Dictionary):
		return
	_ach_sel["type"] = int(w.item_value.get("cat", -1))
	_ach_sel["sub"] = -1
	_push_achievement_model()


func _on_ach_select_subtype(_a: Array, w: GWidget) -> void:
	if w == null or not (w.item_value is Dictionary):
		return
	_ach_sel["type"] = int(w.item_value.get("cat", _ach_sel["type"]))
	_ach_sel["sub"] = int(w.item_value.get("sub", -1))
	_push_achievement_model()


## --- optionsDialog ------------------------------------------------------------

func _push_options_model() -> void:
	var model := _gui.gui.model
	var gp: Dictionary = model.values.get("gamePreferences", {})
	var res_list: Array = []
	for r in ["800x600", "1024x768", "1280x832", "1280x1024", "1440x900",
			"1600x1200", "1920x1080", "1920x1200"]:
		res_list.append({"text": r, "value": r})
	gp["screenResolutions"] = res_list
	if str(gp.get("screenResolution", "")) == "":
		var ws := get_window().size
		gp["screenResolution"] = "%dx%d" % [ws.x, ws.y]
	model.set_value("gamePreferences", gp)


func _apply_audio_prefs() -> void:
	var gp: Dictionary = _gui.gui.model.values.get("gamePreferences", {})
	var mv := 0.0 if bool(gp.get("musicMute", false)) \
		else float(gp.get("musicVolume", 0.5))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music")
		if AudioServer.get_bus_index("Music") >= 0 else 0,
		linear_to_db(maxf(mv, 0.0001)))


func _apply_vsync_pref() -> void:
	var gp: Dictionary = _gui.gui.model.values.get("gamePreferences", {})
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED
		if bool(gp.get("vsyncActivated", true))
		else DisplayServer.VSYNC_DISABLED)


func _apply_fullscreen_pref() -> void:
	var gp: Dictionary = _gui.gui.model.values.get("gamePreferences", {})
	get_window().mode = Window.MODE_FULLSCREEN \
		if bool(gp.get("fullScreen", false)) else Window.MODE_WINDOWED


func _on_apply_resolution(args: Array, _w: GWidget) -> void:
	var gp: Dictionary = _gui.gui.model.values.get("gamePreferences", {})
	var spec: String = str(gp.get("screenResolution", ""))
	# the form's combobox may hold a picked-but-unapplied value
	if args.size() > 0 and args[0] is GWidget:
		var combo: GWidget = _find_combo(args[0])
		if combo != null and str(combo.content_value) != "":
			spec = str(combo.content_value)
	var p := spec.split("x")
	if p.size() != 2:
		return
	get_window().size = Vector2i(int(p[0]), int(p[1]))


func _find_combo(w: GWidget) -> GWidget:
	if w.kind == "comboboxplus" or w.kind == "comboBox":
		return w
	for ch in w.get_children():
		if ch is GWidget:
			var r := _find_combo(ch)
			if r != null:
				return r
	return null


func _on_destroy_coach(_a: Array, _w: GWidget) -> void:
	if not State.fight_data.is_empty():
		return  # retail: cantDestroyCoachDuringFight
	var d := ConfirmationDialog.new()
	d.dialog_text = "Destroy your coach? This cannot be undone."
	d.confirmed.connect(func():
		Session.send(OP_DESTROY_COACH, PackedByteArray(), 2))
	add_child(d)
	d.popup_centered()


## Event args are either the textEditor widget (editor) or a row's
## <data id> value (friend dict / ignore name).
func _social_arg_text(v: Variant) -> String:
	if v is GWidget:
		return v.text.strip_edges()
	if v is Dictionary:
		return str(v.get("name", v.get("text", ""))).strip_edges()
	return str(v).strip_edges()


func _on_social_add(args: Array, _w: GWidget, opcode: int) -> void:
	var s := _social_arg_text(args[0]) if not args.is_empty() else ""
	if s.is_empty():
		return
	var w := WireWriter.new()
	w.put_str(s, "u8")
	Session.send(opcode, w.raw(), 2)


func _on_social_remove(args: Array, w: GWidget, opcode: int) -> void:
	_on_social_add(args, w, opcode)


func _on_gui_quit_guild(_a: Array, _w: GWidget) -> void:
	var gid := int(State.guild.get("guild_id", 0))
	if gid <= 0:
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	w.put_i64(State.my_coach_id)   # member = self → leave
	Session.send(OP_GUILD_LEAVE, w.raw(), 8)


func _on_gui_destroy_guild(_a: Array, _w: GWidget) -> void:
	var gid := int(State.guild.get("guild_id", 0))
	if gid <= 0:
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	Session.send(OP_GUILD_DESTROY, w.raw(), 2)


## --- dofusarena.guild:* — creation / management / member stats -------------

var _guild_stats_member := {}   # member dict the stats dialog is showing


## guildDialog wants fresh data each open — same 517/519 pair the debug
## panel sends in _open_guild.
func _request_guild_refresh() -> void:
	if State.guild.is_empty():
		return
	var w := WireWriter.new()
	w.put_i64(State.my_coach_id)
	Session.send(OP_GUILD_GET, w.raw(), 2)
	w = WireWriter.new()
	w.put_i64(int(State.guild.get("guild_id", 0)))
	Session.send(OP_GUILD_MEMBERS, w.raw(), 2)


## createGuild(guildCreationForm) — aia_0.createGuild reads the
## guildCreationName property, requires >= 5 chars, sends
## atM(509)=[u8 type=kG.Fi=2][str8 name] and closes.
func _on_guild_create(_a: Array, _w: GWidget) -> void:
	var name := str(_gui.gui.model.get_value("guildCreationName")) \
		.strip_edges()
	if name.length() < 5:
		_toast("Guild name must be at least 5 characters")
		return
	var w := WireWriter.new()
	w.put_u8(2)                              # kG.Fi — the clan guild type
	w.put_str(name, "u8")
	Session.send(OP_GUILD_CREATE, w.raw(), 3)
	_gui.close("guildCreationDialog")


## guild.editableRanks — ranks with the right bits split into the can*
## flags the management checkboxes bind.
func _rank_item(rk: Dictionary) -> Dictionary:
	var r := int(rk.get("rights", 0))
	return {"name": str(rk.get("name", "")),
		"rankLevel": int(rk.get("level", 0)),
		"rankIconUrl": "", "rights": r,
		"canInvite": r & GUILD_RIGHT_INVITE != 0,
		"canRemove": r & GUILD_RIGHT_REMOVE != 0,
		"canPromote": r & GUILD_RIGHT_PROMOTE != 0,
		"canDepromote": r & GUILD_RIGHT_DEMOTE != 0}


func _push_guild_mgmt_model() -> void:
	var model := _gui.gui.model
	var ranks: Array = []
	for rk in State.guild.get("ranks", []):
		ranks.append(_rank_item(rk))
	model.set_value("guild", ranks, "guild.editableRanks")
	model.set_value("guildSelectedRank",
		ranks[0] if not ranks.is_empty() else {})


## selectRank(rankNameEditor) — item click seeds the editor + checkboxes
## through the guildSelectedRank binding.
func _on_guild_select_rank(_a: Array, w: GWidget) -> void:
	if w.item_value is Dictionary:
		_gui.gui.model.set_value("guildSelectedRank",
			w.item_value.duplicate())


func _selected_rank_rights() -> int:
	var sr: Variant = _gui.gui.model.get_value("guildSelectedRank")
	var r := 0
	if sr is Dictionary:
		if sr.get("canInvite", false): r |= GUILD_RIGHT_INVITE
		if sr.get("canRemove", false): r |= GUILD_RIGHT_REMOVE
		if sr.get("canPromote", false): r |= GUILD_RIGHT_PROMOTE
		if sr.get("canDepromote", false): r |= GUILD_RIGHT_DEMOTE
	return r


## addRankToGuild — 553 [i64 gid][i32 rights][str8 name] arch 2; retail
## adds the typed name with the toggled rights.
func _on_guild_add_rank(_a: Array, _w: GWidget) -> void:
	var gid := int(State.guild.get("guild_id", 0))
	var name := str(_gui.gui.model.get_value(
		"guildSelectedRank", "name")).strip_edges()
	if gid <= 0 or name.is_empty():
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	w.put_i32(_selected_rank_rights())
	w.put_str(name, "u8")
	Session.send(OP_GUILD_RANK_ADD, w.raw(), 2)


func _on_guild_remove_rank(_a: Array, _w: GWidget) -> void:
	var gid := int(State.guild.get("guild_id", 0))
	var sr: Variant = _gui.gui.model.get_value("guildSelectedRank")
	var lvl := int(sr.get("rankLevel", 0)) if sr is Dictionary else 0
	if gid <= 0 or lvl <= 0:
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	w.put_i16(lvl)
	Session.send(OP_GUILD_RANK_DEL, w.raw(), 2)


## modifyRank — 555 [i64 gid][i32 rights][u16 lvl][u16 lvl][str8 name]
## (both shorts carry the same level — aia_0.modifyRank).
func _on_guild_modify_rank(_a: Array, _w: GWidget) -> void:
	var gid := int(State.guild.get("guild_id", 0))
	var sr: Variant = _gui.gui.model.get_value("guildSelectedRank")
	if gid <= 0 or not (sr is Dictionary):
		return
	var name := str(sr.get("name", "")).strip_edges()
	var lvl := int(sr.get("rankLevel", 0))
	if name.is_empty() or lvl <= 0:
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	w.put_i32(_selected_rank_rights())
	w.put_i16(lvl)
	w.put_i16(lvl)
	w.put_str(name, "u8")
	Session.send(OP_GUILD_RANK_MOD, w.raw(), 2)


## getMemberStats — row click on the roster; 2600 fetches the member's
## PlayerStatisticsReport, 2601 fills guildCoachStatsDialog.
func _on_guild_member_stats(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	_guild_stats_member = row
	var wr := WireWriter.new()
	wr.put_i64(int(_guild_stats_member.get("coach_id", 0)))
	Session.send(OP_GUILD_MEMBER_STATS, wr.raw(), 2)


func _push_guild_member_stats(d: Dictionary) -> void:
	var stats := {}
	for s in d.get("stats", []):
		stats[int(s.id)] = s.value
	var model := _gui.gui.model
	model.set_value("guildCoachStats", {
		"name": str(d.get("name", "")),
		"level": int(_guild_stats_member.get("level", 0)),
		"actorDescriptorLibrary": "coach_7000",
		"rankIconUrl": "", "guildRankIconUrl": "",
		"statisticsTotalPlayTime": int(stats.get(1, 0)),
		"statisticsTotalFightsTime": int(stats.get(2, 0)),
		"statisticsTotalFights": int(stats.get(3, 0)),
		"statisticsTotalFightsWon": int(stats.get(4, 0)),
		"statisticsTotalFightsLost": int(stats.get(5, 0)),
		"statisticsConsecutiveWins": int(stats.get(7, 0))})
	var rl := int(_guild_stats_member.get("rank_level", 0))
	model.set_value("guildCanPromote",
		_has_right(GUILD_RIGHT_PROMOTE) and rl > 2)
	model.set_value("guildCanDepromote",
		_has_right(GUILD_RIGHT_DEMOTE) and rl >= 1)
	model.set_value("guildExcluder",
		_has_right(GUILD_RIGHT_REMOVE) and rl != 1)


## promote/depromote on the stats screen act on the member it shows —
## same sparse-rank pick as _on_guild_set_rank.
func _on_guild_stats_promote(_a: Array, _w: GWidget, delta: int) -> void:
	if _guild_stats_member.is_empty():
		return
	var gid := int(State.guild.get("guild_id", 0))
	var cur := int(_guild_stats_member.get("rank_level", 0))
	var want := -1
	for rk in State.guild.get("ranks", []):
		var lvl := int(rk.get("level", 0))
		if delta < 0 and lvl < cur and (want < 0 or lvl > want):
			want = lvl
		elif delta > 0 and lvl > cur and (want < 0 or lvl < want):
			want = lvl
	if gid <= 0 or want < 0:
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	w.put_i64(int(_guild_stats_member.get("coach_id", 0)))
	w.put_i16(want)
	Session.send(OP_GUILD_SET_RANK, w.raw(), 8)


func _on_guild_stats_kick(_a: Array, _w: GWidget) -> void:
	var gid := int(State.guild.get("guild_id", 0))
	var mid := int(_guild_stats_member.get("coach_id", 0))
	if gid <= 0 or mid <= 0:
		return
	var w := WireWriter.new()
	w.put_i64(gid)
	w.put_i64(mid)
	Session.send(OP_GUILD_LEAVE, w.raw(), 8)


## --- dofusarena.mail:* — inbox / sentbox / compose --------------------------

func _mail_date(ms: int) -> String:
	if ms <= 0:
		return ""
	var d := Time.get_datetime_dict_from_unix_time(ms / 1000)
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year,
		d.hour, d.minute]


func _mail_row(m: Dictionary) -> Dictionary:
	var cards: Array = []
	for cid in m.get("cards", []):
		var it := _card_item(int(cid))
		cards.append(it)
	return {"mailId": int(m.get("id", 0)),
		"sender": str(m.get("sender", "")),
		"receiver": str(m.get("receiver", "")),
		"title": str(m.get("title", "")),
		"date": _mail_date(int(m.get("date_ms", 0))),
		"read": bool(m.get("read", false)),
		"hasItems": not m.get("cards", []).is_empty(),
		"style": "",
		"message": str(m.get("body", "")),
		"cards": cards}


## mailManager.{receivedMails,sentMails} + mailbox.mail (the selected
## letter) + mailbox.newMail (the compose draft).
func _push_mail_model() -> void:
	var model := _gui.gui.model
	var recv: Array = []
	var sent: Array = []
	for m in _mails:
		if int(m.get("sender_id", 0)) == State.my_coach_id:
			sent.append(_mail_row(m))
		else:
			recv.append(_mail_row(m))
	model.set_value("mailManager",
		{"receivedMails": recv, "sentMails": sent})
	if not (model.get_value("mailbox.mail") is Dictionary):
		model.set_value("mailbox.mail",
			recv[0] if not recv.is_empty() else {})


## the clicked widget can be a child of the materialized row — the item
## dict only lives on the renderer root.
func _row_item(w: GWidget) -> Variant:
	var n: Node = w
	while n != null:
		if n is GWidget and n.item_value != null:
			return n.item_value
		n = n.get_parent()
	return null


func _on_mail_read(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	row["read"] = true
	for m in _mails:
		if int(m.get("id", 0)) == int(row.get("mailId", 0)):
			m["read"] = true
	_gui.gui.model.set_value("mailbox.mail", row)


## deleteMail(mail) — the row dict carries mailId; the button inside a
## sent-box row deletes that copy server-side too (15004).
func _on_mail_delete(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary) or int(row.get("mailId", 0)) <= 0:
		row = _gui.gui.model.get_value("mailbox.mail")
	if not (row is Dictionary):
		return
	var mid := int(row.get("mailId", 0))
	if mid <= 0:
		return
	var wr := WireWriter.new()
	wr.put_u8(1)
	wr.put_i64(mid)
	Session.send(OP_MAIL_DELETE, wr.raw(), 3)
	for i in range(_mails.size() - 1, -1, -1):
		if int(_mails[i].get("id", -1)) == mid:
			_mails.remove_at(i)
	_push_mail_model()


func _on_mail_take(_a: Array, _w: GWidget) -> void:
	var row: Variant = _gui.gui.model.get_value("mailbox.mail")
	if not (row is Dictionary):
		return
	var mid := int(row.get("mailId", 0))
	if mid <= 0 or row.get("cards", []).is_empty():
		return
	var w := WireWriter.new()
	w.put_i64(mid)
	w.put_u8(0)
	Session.send(OP_MAIL_TAKE, w.raw(), 3)


func _on_mail_new(_a: Array, _w: GWidget) -> void:
	_gui.gui.model.set_value("mailbox.newMail", {
		"receiver": "", "receiverId": 0, "title": "",
		"message": "", "cards": []})
	_push_cardbook_model()   # compose binds localCoach.cardInventory
	_gui.open("newMailDialog")


## reply — seed the draft with the selected letter's sender.
func _on_mail_reply(_a: Array, _w: GWidget) -> void:
	var row: Variant = _gui.gui.model.get_value("mailbox.mail")
	var to := str(row.get("sender", "")) if row is Dictionary else ""
	_gui.gui.model.set_value("mailbox.newMail", {
		"receiver": to, "receiverId": 0, "title": "",
		"message": "", "cards": []})
	_push_cardbook_model()
	_gui.open("newMailDialog")


## testName(newMailForm) — resolves the typed receiver name into
## mailbox.newMail.receiverId through 15506/15507.
func _on_mail_test_name(_a: Array, _w: GWidget) -> void:
	var name := str(_gui.gui.model.get_value(
		"mailbox.newMail", "receiver")).strip_edges()
	if name.is_empty():
		return
	var w := WireWriter.new()
	w.put_str(name, "u8")
	Session.send(OP_MAIL_CHECK, w.raw(), 2)


## sendMail(newMailForm) — the full mail record, arch 3: the same record
## shape the server decodes (id=0, session-derived sender fields).
func _on_mail_send(_a: Array, _w: GWidget) -> void:
	var nm: Variant = _gui.gui.model.get_value("mailbox.newMail")
	if not (nm is Dictionary):
		return
	var receiver := str(nm.get("receiver", "")).strip_edges()
	var title := str(nm.get("title", ""))
	var message := str(nm.get("message", ""))
	if receiver.is_empty():
		_toast("Mail needs a recipient")
		return
	var extra := WireWriter.new()
	var tb := title.to_utf8_buffer()
	extra.put_u16(1); extra.put_i32(tb.size()); extra.put_bytes(tb)
	var bb := message.to_utf8_buffer()
	extra.put_u16(2); extra.put_i32(bb.size()); extra.put_bytes(bb)
	var cards: Array = nm.get("cards", [])
	if not cards.is_empty():
		extra.put_u16(3)
		extra.put_u16(cards.size())
		for c in cards:
			extra.put_i32(int(c.get("id", 0)) if c is Dictionary else int(c))
	var w := WireWriter.new()
	w.put_i64(0)                                   # mail id — server assigns
	w.put_i64(State.my_coach_id)
	w.put_str(State.my_coach_name, "u8")
	w.put_i32(0)                                   # senderGame
	w.put_i64(int(nm.get("receiverId", 0)))
	w.put_str(receiver, "u8")
	var eb := extra.raw()
	w.put_i32(eb.size())
	w.put_bytes(eb)
	w.put_i64(int(Time.get_unix_time_from_system() * 1000.0))
	w.put_u8(0); w.put_u8(0); w.put_u8(0); w.put_i32(0)
	Session.send(OP_MAIL_SEND, w.raw(), 3)
	_gui.close("newMailDialog")


## localCoach model — shared by menuBarDialog / coachStatisticsDialog /
## coachCreationDialog. Stats come from the 2400/2401 rs_2 stat map.
func _local_coach_model() -> Dictionary:
	var cs: Dictionary = State.coach_stats
	var look: Dictionary = State.my_coach_look
	return {
		"name": State.my_coach_name,
		"sex": int(look.get("sex", 0)),
		"skin": int(look.get("skin", 0)),
		"hair": int(look.get("hair", 0)),
		"equipedEmotes": [],
		"actorDescriptorLibrary": "coach_700%d" % int(look.get("sex", 0)),
		"actorAnimation": "AnimStatique",
		"actorDirection": 3,
		"actorMaterial": Palettes.coach_tints(
			int(look.get("skin", 0)), int(look.get("hair", 0))),
		"standing": State.coach_standing,
		"standingForProgressBar": State.coach_standing,
		"standingNeededForNextLevel": 0,
		"strenght": 0,
		"strengthForProgressBar": 0,
		"strengthNeededForNextLevel": 0,
		"tournamentToken": State.coach_tournament_points,
		"level": 0,
		"rankIconUrl": "", "guildRankIconUrl": "",
		"statisticsTotalPlayTime": int(cs.get(1, 0)),
		"statisticsTotalFightsTime": int(cs.get(2, 0)),
		"statisticsTotalFights": int(cs.get(3, 0)),
		"statisticsTotalFightsWon": int(cs.get(4, 0)),
		"statisticsTotalFightsLost": int(cs.get(5, 0)),
		"statisticsConsecutiveWins": int(cs.get(7, 0)),
		"statisticsConsecutiveEvolutionWins": 0,
		"statisticsTotalFightsEvolution": 0,
		"statisticsTotalFightsEvolutionWon": 0,
		"statisticsTotalFightsEvolutionLost": 0,
		"statisticsTournamentPoints": State.coach_tournament_points,
	}


func _push_local_coach() -> void:
	_gui.gui.model.set_value("localCoach", _local_coach_model())


## menuBarDialog binds (equipedEmotes + name today; more land as screens port).
func _mount_lobby_menubar(d: Dictionary) -> void:
	State.my_coach_name = str(d.get("name", State.my_coach_name))
	_push_local_coach()
	_gui.gui.model.set_value("showToolsInMenuBar", 0)
	_gui.gui.model.set_value("menuBar", {
		"coachInventoryButton": true, "socialButton": true})
	if not _gui.is_open("menuBarDialog"):
		_gui.open("menuBarDialog")


func _log_line(s: String) -> void:
	log.log_line(s)


## Bottom-centre toast — retail's achievementDialog style: a small card that
## stacks upward and fades out after a few seconds.
func _toast(text: String) -> void:
	var box := $UI/ToastBox
	var card := PanelContainer.new()
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 12)
	card.add_child(lab)
	box.add_child(card)
	while box.get_child_count() > 3:
		box.get_child(0).queue_free()
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)


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
var _duo_pending := {}        # incoming 6025 {team, inviter, invited}
var _watch_target := -1       # coach id asked in the pending 2260
var _npc := {}                # open NPC dialog {name, replies}
var _fired_triggers := {}     # zone-trigger element ids already run this session
var _scenario_queue := []     # pending tutorial monologues (overlapping zones)
var _pending_zaap_page := 0   # scenario 108 follow-up: show once the Zaap opens

## Ranking window tabs (retail ladderInformationDialog order): the request
## opcode and a payload builder; replies land in _on_message below.
const LADDER_TABS := [
	{"label": "1 vs 1", "op": OP_LADDER_1V1_REQ, "page": 20},
	{"label": "Coach", "op": OP_LADDER_COACH_REQ, "page": 20},
	{"label": "2 vs 2", "op": OP_LADDER_2V2_REQ, "page": 20},
	{"label": "Clan", "op": OP_LADDER_GUILD_REQ, "page": 20},
	{"label": "Tournoi", "op": OP_LADDER_TOURN_REQ, "page": 20},
	{"label": "Ligue Pro", "op": OP_LADDER_PRO_REQ, "page": 20},
	{"label": "Démon", "op": OP_LADDER_DEMON_REQ, "page": 12},
	{"label": "Achievements", "op": OP_STAT_REQ, "page": 0},
]
var _tourn_search_tid := -1  # tournament whose opponent-search is live
var _ladder_tab := 0          # current LADDER_TABS index
var _ladder_start := 0        # window start of the next request
var _ladder_tourn := {"m": 0, "t": 0, "y": 0}  # echoed tournament period
var _guild_ranks_mode := false  # GuildDlg list shows ranks instead of members
var _guild_invite := {}         # pending 502 {type, inviter, guild}


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
		14:  # Fusion altar — retail lab: fuel tray + boost target → 5490
			_open_fusion_lab(e)
		3:   # Challenge (uk_0) — name;textId;challengeIds… → picker → cj_0 26330
			_open_challenge_picker(e)
		7:   # Demon challenge (pn_0) — gated on achievement 278
			_open_demon_challenge(e)
		6:   # Demon III (acn_0) — paged talk → criterion 210 → challenge picker
			_open_demon3(e)
		9:   # Demon I (aac_2) — paged monologue gated on achievement 277
			_open_demon1(e)
		5:   # Breed Master — recruit text; the "test" button runs 26330 too.
			# zs_1 also reports criterion 221 ("talked to a breedmaster") on
			# every dialog open — a counter stat, value=1 each time.
			_open_challenge_bubble(e)
			w = WireWriter.new()
			w.put_i16(221)
			w.put_u8(1)
			w.put_i16(1)
			State.net.send_message(OP_STAT_UPD, w.raw(), 2)
		11:  # Demon totem — ladder page requested with 27510, shown on 27511
			_open_demon_totem(e)
		13:  # Tournament totem — calendar (17002) + list (28601)
			_open_tournament_totem()
		12:  # Firework launcher — pick a card → 22095 → 22094 echo
			_open_firework(e)
		15:  # NPC talker — client-side dialog tree (record 1500)
			_open_npc(e)
		_:   # Demons (6/9) — local text bubble
			_element_text(label, "…")


## NPC talker (kind 15): desc = "nameId;criterionId;defaultGroup;altGroup;
## style" (client ni_0). The whole tree is client-side — opening sends nothing;
## reply actions are the only wire traffic (26330 challenge / 22003 criterion).
## altGroup is picked when criterionId != -1 and its value is > 0.
func _open_npc(e: Dictionary) -> void:
	var fields := str(e.get("desc", "")).split(";")
	var name_id := int(fields[0]) if fields.size() > 0 else -1
	var crit := int(fields[1]) if fields.size() > 1 else -1
	var def_group := int(fields[2]) if fields.size() > 2 else -1
	var alt_group := int(fields[3]) if fields.size() > 3 else def_group
	_npc = {
		"name": NpcDialogs.npc_name(name_id),
		"replies": [],
	}
	var group := def_group
	if crit != -1 and int(State.criteria.get(crit, 0)) > 0:
		group = alt_group
	_npc_node(group)


## Show one dialog node: speech (content.59) + reply rows (content.60 labels).
func _npc_node(group_id: int) -> void:
	var g := NpcDialogs.group(group_id)
	if g.is_empty():
		$UI/ElementDlg.visible = false
		return
	var replies: Array = g.get("replies", [])
	_npc["replies"] = replies
	_element_text(str(_npc.get("name", "NPC")), str(g.get("text", "")))
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	for i in replies.size():
		list.add_item(str(replies[i].get("label", "…")))
		list.set_item_metadata(i, i)
	if not list.item_selected.is_connected(_on_npc_reply):
		list.item_selected.connect(_on_npc_reply)
	_elem_close_btn()


## Reply click = client ao_2 case 17001: run the action, then navigate to the
## reply's `next` group (0 = close the dialog). For kinds 3/6 the list rows
## are the défi picker — a click accepts the challenge (cj_0 → 26330 {id, 99}).
func _on_npc_reply(i: int) -> void:
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	if _elem_kind == 3 or _elem_kind == 6:
		var chal := int(list.get_item_metadata(i))
		if chal > 0:
			var w := WireWriter.new()
			w.put_i32(chal)
			w.put_u16(99)
			Session.send(OP_TEAM_TEST, w.raw(), 2)
			_log_line("challenge %d accepted" % chal)
		$UI/ElementDlg.visible = false
		return
	if _elem_kind != 15:
		return
	var replies: Array = _npc.get("replies", [])
	if i < 0 or i >= replies.size():
		return
	var r: Dictionary = replies[i]
	match int(r.get("act", 0)):
		1: # Lancer un défi — 26330 [i32 challengeId][i16 challenge.Qu()]
			var chal := int(r.get("params", [0])[0])
			var w := WireWriter.new()
			w.put_i32(chal)
			w.put_u16(NpcDialogs.challenge_mode(chal))
			Session.send(OP_TEAM_TEST, w.raw(), 2)
		2: # Donne un exploit — 22003 {i16 criterionId, u8 1, i16 1}
			var crit := int(r.get("params", [0])[0])
			var w := WireWriter.new()
			w.put_i16(crit)
			w.put_u8(1)
			w.put_i16(1)
			State.net.send_message(OP_STAT_UPD, w.raw(), 2)
			State.criteria[crit] = 1   # local shadow for same-session gates
	var next := int(r.get("next", 0))
	if next != 0:
		_npc_node(next)
	else:
		$UI/ElementDlg.visible = false


## Fill the ElementDlg list with one row per challenge (content.30 names);
## clicking a row sends 26330 [i32 challengeId][i16 99] — the wire shape every
## picker accept produces (cj_0's bM is hardcoded 99 for env 3/6/7 elements).
func _npc_fill_challenges(chals: Array) -> void:
	_npc["chals"] = chals
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.clear()
	for c in chals:
		list.add_item(NpcDialogs.challenge_name(int(c)))
		list.set_item_metadata(list.item_count - 1, int(c))
	if not list.item_selected.is_connected(_on_npc_reply):
		list.item_selected.connect(_on_npc_reply)


## uk_0 Challenge (kind 3): desc "nameId;speechId;challengeId;…" — accept shows
## the challenge picker (cj_0); each row launches 26330 {id, 99}.
func _open_challenge_picker(e: Dictionary) -> void:
	var fields := _desc_fields(str(e.get("desc", "")))
	_npc = {}
	_element_text(
		NpcDialogs.npc_name(fields[0]) if fields.size() > 0 else "Challenge",
		NpcDialogs.npc_name(fields[1]) if fields.size() > 1 else "")
	_npc_fill_challenges(fields.slice(2))
	_elem_close_btn()


## Show AltBtn as a plain "Close" — _on_element_alt's fallthrough hides the
## dialog for every kind that has no specific alt action.
func _elem_close_btn() -> void:
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Close"
	alt.visible = true


## pn_0 DemonChallenge (kind 7): desc "nameId;taskId;challengeId;acceptText;
## refuseText". taskId != 0 drives a client-side scenario we don't run — we go
## straight to the challenge offer. taskId == 0 gates the accept bubble on
## achievement 278 ("all four minute-demon challenges"): refuse text otherwise.
func _open_demon_challenge(e: Dictionary) -> void:
	var fields := _desc_fields(str(e.get("desc", "")))
	var task := int(fields[1]) if fields.size() > 1 else 0
	var chal := int(fields[2]) if fields.size() > 2 else -1
	var accept_txt := int(fields[3]) if fields.size() > 3 else -1
	var refuse_txt := int(fields[4]) if fields.size() > 4 else -1
	_npc = {}
	_element_text(NpcDialogs.npc_name(fields[0]),
		NpcDialogs.npc_name(
			accept_txt if task != 0 or _ach_done(278) else refuse_txt))
	var alt: Button = $UI/ElementDlg/VBox/Btns/AltBtn
	alt.text = "Refuse"
	alt.visible = true
	if task != 0 or _ach_done(278):
		var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
		act.text = "Accept"
		act.visible = true
		act.disabled = chal < 0
		_npc["chal"] = chal


## aac_2 Demon I (kind 9): desc "nameId;t0;t1;t2;alt0;alt1" — a paged
## monologue. Achievement 277 (all minute-demon challenges) picks the alt
## two-page set; the "Next" button advances, last page closes.
func _open_demon1(e: Dictionary) -> void:
	var fields := _desc_fields(str(e.get("desc", "")))
	var pages := fields.slice(4) if _ach_done(277) else fields.slice(1, 4)
	_npc = {"pages": pages, "page": 0, "chals": []}
	_npc_page_show(NpcDialogs.npc_name(fields[0]))


## acn_0 Demon III (kind 6): desc "nameId;t0..t5;challengeId×3". First contact
## (achievement 275 pending) reports criterion 210 then pages t0→t2; the tail
## picks t3 (needs 3 recruits, ach 276), t5 (evo challenges done, ach 284) or
## t4 + the challenge picker.
func _open_demon3(e: Dictionary) -> void:
	var fields := _desc_fields(str(e.get("desc", "")))
	var texts := fields.slice(1, 7)
	var chals := fields.slice(7)
	_npc = {"chals": chals}
	if not _ach_done(275):
		var w := WireWriter.new()
		w.put_i16(210)
		w.put_u8(1)
		w.put_i16(1)
		State.net.send_message(OP_STAT_UPD, w.raw(), 2)
		State.criteria[210] = 1   # local shadow — achievement 275's gate reads it
		_npc["pages"] = texts.slice(0, 3)
		_npc["page"] = 0
		_npc["chals"] = []
		_npc_page_show(NpcDialogs.npc_name(fields[0]))
	elif not _ach_done(276):
		_element_text(NpcDialogs.npc_name(fields[0]),
			NpcDialogs.npc_name(texts[3]))
	elif _ach_done(284):
		_element_text(NpcDialogs.npc_name(fields[0]),
			NpcDialogs.npc_name(texts[5]))
	else:
		_element_text(NpcDialogs.npc_name(fields[0]),
			NpcDialogs.npc_name(texts[4]))
		_npc_fill_challenges(chals)
	_elem_close_btn()


## Show one monologue page; ActBtn = Next / OK.
func _npc_page_show(title: String) -> void:
	var pages: Array = _npc.get("pages", [])
	var page := int(_npc.get("page", 0))
	var last := page >= pages.size() - 1
	_element_text(title, NpcDialogs.npc_name(int(pages[page]))
		if pages.size() > page else "")
	var act: Button = $UI/ElementDlg/VBox/Btns/ActBtn
	act.text = "OK" if last else "Next"
	act.visible = true
	act.disabled = false
	_elem_close_btn()


## ActBtn on kinds 6/9 advances the monologue; at the last page it either
## closes (no challenges) or reveals the défi picker.
func _npc_page_next() -> void:
	_npc["page"] = int(_npc.get("page", 0)) + 1
	var pages: Array = _npc.get("pages", [])
	if int(_npc.page) < pages.size():
		_npc_page_show($UI/ElementDlg/VBox/Title.text)
		return
	var chals: Array = _npc.get("chals", [])
	if chals.is_empty():
		$UI/ElementDlg.visible = false
		# Queued zone-trigger scenarios run one monologue at a time.
		if _elem_kind == ELEM_SCENARIO and not _scenario_queue.is_empty():
			_run_scenario(_scenario_queue.pop_front())
	else:
		_npc_fill_challenges(chals)
		$UI/ElementDlg/VBox/Btns/ActBtn.visible = false


## Achievement check against the coach's live criteria + tome (aau_1.a).
func _ach_done(id: int) -> bool:
	return NpcDialogs.achievement_done(id, State.criteria, State.inventory)


## Zone triggers (kind 8, client `oq`): desc "script;requireAch;blockAch".
## Fires once per element per session when the coach walks into its zone —
## the required achievement must be done, the blocking one NOT. The script is
## a client-side Lua scenario (anr_0) — the tutorial monologues.
func _check_zone_trigger(cell: Vector2i) -> void:
	for id in world.zone_triggers_at(cell):
		if _fired_triggers.has(id):
			continue
		var e: Dictionary = world.element_info(id)
		var fields := _desc_fields(str(e.get("desc", "")))
		var script := int(fields[0]) if fields.size() > 0 else -1
		var req := int(fields[1]) if fields.size() > 1 else 0
		var block := int(fields[2]) if fields.size() > 2 else 0
		if req > 0 and not _ach_done(req):
			continue
		if block > 0 and _ach_done(block):
			continue
		_fired_triggers[id] = true
		_elem_id = id
		# Overlapping zones queue their scenarios like the retail Lua VM's
		# event loop — one monologue at a time.
		if _elem_kind == ELEM_SCENARIO and $UI/ElementDlg.visible:
			_scenario_queue.append(script)
		else:
			_run_scenario(script)


## Play a scenario as a paged floating monologue (the retail BubbleText
## content is intact; the actor walk-in / widget-particle choreography is
## not reproduced). `ach` criteria go out as 22003 like Context.updateAch.
func _run_scenario(id: int) -> void:
	var s := Scenarios.script(id)
	if s.is_empty():
		return
	var ach := int(s.get("ach", 0))
	if ach > 0:
		var w := WireWriter.new()
		w.put_i16(ach)
		w.put_u8(1)
		w.put_i16(1)
		State.net.send_message(OP_STAT_UPD, w.raw(), 2)
		State.criteria[ach] = 1   # local shadow for same-session gates
	_pending_zaap_page = int(s.get("zaap", 0))
	_npc = {"pages": s.get("pages", []), "page": 0, "chals": []}
	_elem_kind = ELEM_SCENARIO
	_npc_page_show("Tutorial")
	_log_line("tutorial scenario %d fired" % id)


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


## Coach display name for the result panel — own coach, then the fight blob's
## coach list (State.coach_ids), then a bare id fallback.
func _coach_result_name(id: int) -> String:
	if id == State.my_coach_id:
		return State.my_coach_name
	var c: Dictionary = State.coach_ids.get(id, {})
	return str(c.get("name", "coach %d" % id))


## Report rows name ROSTER ids — resolve against the lobby roster; fall back
## to the fight-time fighter index (wire ids — rarely matches, kept anyway).
func _fighter_result_name(fid: int) -> String:
	for f in State.roster:
		if int(f.get("id", -1)) == fid:
			return str(f.get("name", "fighter %d" % fid))
	return str(State.fighters.get(fid, {}).get("name", "fighter %d" % fid))


## Post-fight debrief — the client's fightResultDialog + fightResultEvolution-
## Dialog folded into one read-only panel: winner/loser coaches with their new
## ladder strength, cards won, then each of our fighters' OW report (banked
## XP, morale/tiredness drift, wounds). fight_view decoded the 8300 before
## acking; we pop the panel once the island view is back.
func _show_fight_result() -> void:
	var r: Dictionary = State.fight_result
	State.fight_result = {}
	if r.is_empty():
		return
	var me := int(State.my_coach_id)
	var in_win: bool = r.get("win_str", {}).has(me)
	var in_lose: bool = r.get("lose_str", {}).has(me)
	var title := "Fight over"
	if int(r.get("flee", 0)) != 0:
		title = "Fight over — abandoned"
	elif in_win:
		title = "Victory!"
	elif in_lose:
		title = "Defeat"
	var hints := []
	if in_win:
		hints.append("strength → %d" % int(r.win_str[me]))
	elif in_lose:
		hints.append("strength → %d" % int(r.lose_str[me]))
	if int(r.get("standing", 0)) != 0:
		hints.append("standing %+d" % int(r.standing))
	if int(r.get("killed", 0)) > 0 or int(r.get("injured", 0)) > 0:
		hints.append("killed %d / injured %d" % [
			int(r.killed), int(r.injured)])
	_element_text(title, "   ".join(hints))
	_elem_kind = ELEM_RESULT
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	for c in r.get("winners", []):
		var cid := int(c.id)
		var str_new: Variant = r.get("win_str", {}).get(cid)
		list.add_item("★ %s%s" % [_coach_result_name(cid),
			"  → str %d" % int(str_new) if str_new != null else ""])
	for c in r.get("losers", []):
		var cid := int(c.id)
		var str_new: Variant = r.get("lose_str", {}).get(cid)
		list.add_item("   %s%s" % [_coach_result_name(cid),
			"  → str %d" % int(str_new) if str_new != null else ""])
	for rep in r.get("reports", []):
		# Retail applies the OW report to the roster fighter (adY.dz) — keep
		# the lobby panel's morale/tiredness/xp current without a 6006 re-push.
		for f in State.roster:
			if int(f.get("id", -1)) == int(rep.fighter):
				f.morale = int(rep.get("morale", f.get("morale", 0)))
				f.tiredness = int(rep.get("tiredness", f.get("tiredness", 0)))
				f.xp = int(f.get("xp", 0)) + int(rep.get("xp_final", 0))
				if rep.get("dead", false):
					f.state = 2   # dead — the graveyard list picks it up
		var parts := [_fighter_result_name(int(rep.fighter))]
		if int(rep.get("xp_final", 0)) != 0:
			var xp := "%+d XP" % int(rep.xp_final)
			if int(rep.get("morale_bonus", 0)) != 0:
				xp += " (morale %+d%%)" % int(rep.morale_bonus)
			parts.append(xp)
		if int(rep.get("morale_delta", 0)) != 0:
			parts.append("morale %+d → %d" % [
				int(rep.morale_delta), int(rep.get("morale", 0))])
		if int(rep.get("tiredness_delta", 0)) != 0:
			parts.append("tired %+d → %d" % [
				int(rep.tiredness_delta), int(rep.get("tiredness", 0))])
		if rep.get("dead", false):
			parts.append("dead")
		elif int(rep.get("wound", 0)) != 0:
			parts.append("wounded")
		list.add_item(", ".join(parts))
	var won_cards: Array = r.get("won_cards", [])
	if not won_cards.is_empty():
		list.add_item("— cards won —")
		var counts := {}
		for cid in won_cards:
			counts[cid] = int(counts.get(cid, 0)) + 1
		for cid in counts:
			list.add_item("%s ×%d" % [Cards.name_of(int(cid)), int(counts[cid])])


## Graveyard: dead (2) / interred (3) fighters from the roster, plus the owned
## resurrection cards (type with a resurrect% action). Pick a fighter, Act =
## 22099 [i64 fighterId][i32 cardId] spending the first owned revive card.
func _open_graveyard() -> void:
	# Retail sends 6031 on graveyard AND team-panel open — the server
	# re-pushes the roster (6006) + presets (6030) so the list is fresh.
	Session.send(6031, PackedByteArray(), 2)
	_element_text("Graveyard", "Dead fighters:")
	_fill_graveyard()


func _fill_graveyard() -> void:
	var list: ItemList = $UI/ElementDlg/VBox/Scroll/List
	list.clear()
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
## --- fusionLabDialog ---------------------------------------------------------
## fusionTrade: localCardExchange = input tray (padded to slotCount),
## fusionCard/resultCard = the boost card being made, labPower = altar power,
## kardsPower = Σ inputs.reqLevel − target.fusPower (client recipe math).

var _fusion_lab := {}          # altar record {power, quality, slots}
var _fusion_inputs: Array = [] # card ids fed in
var _fusion_target := -1       # boost card id being made
var _fusion_failed := false


func _open_fusion_lab(e: Dictionary) -> void:
	_fusion_inputs = []
	_fusion_target = -1
	_fusion_failed = false
	# the altar element's desc arg is its type-1100 lab id
	var lab := Cards.lab(int(str(e.get("desc", "0"))))
	_fusion_lab = lab if not lab.is_empty() else Cards.lab_default()
	_gui.open("fusionLabDialog")


func _push_fusion_model() -> void:
	var model := _gui.gui.model
	var slots := maxi(1, int(_fusion_lab.get("slots", 3)) - 1)
	var tray: Array = []
	for cid in _fusion_inputs:
		tray.append(_card_item(int(cid)))
	while tray.size() < slots:
		tray.append(null)
	var target = _card_item(_fusion_target) if _fusion_target > 0 else null
	var kp := -int(Cards.meta(_fusion_target).get("fusPower", 0)) \
		if _fusion_target > 0 else 0
	for cid in _fusion_inputs:
		kp += int(Cards.meta(int(cid)).get("reqLevel", 0))
	model.set_value("fusionTrade", {
		"localCardExchange": tray,
		"fusionCard": target,
		"resultCard": target,
		"fusionFailed": _fusion_failed,
		"labPower": int(_fusion_lab.get("power", 0)),
		"kardsPower": maxi(0, kp),
		"slotCount": slots,
		"canFusion": _fusion_inputs.size() >= 2 and _fusion_target > 0,
		"help": ""})


## Double-click a tray row → hand the card back to the inventory.
## (method name shared with cardMaster — only act while the lab is open)
func _on_fusion_remove_input(_a: Array, w: GWidget) -> void:
	if not _gui.is_open("fusionLabDialog"):
		return
	if w == null or not (w.item_value is Dictionary):
		return
	var cid := int(w.item_value.get("id", 0))
	_fusion_inputs.erase(cid)
	_fusion_failed = false
	_push_fusion_model()


## Double-click the target card → clear it.
func _on_fusion_remove_target(_a: Array, _w: GWidget) -> void:
	if not _gui.is_open("fusionLabDialog"):
		return
	_fusion_target = -1
	_fusion_failed = false
	_push_fusion_model()


## equip(coach) double-click on an inventory row — while the lab is open it
## stages the card: boost cards (fusPower/fusQuality) become the target,
## everything else becomes fuel. Stands in for retail drag&drop.
func _on_maybe_fusion_add(_a: Array, w: GWidget) -> void:
	if not _gui.is_open("fusionLabDialog"):
		return
	var card = w.item_value if w != null else null
	if not (card is Dictionary):
		return
	var cid := int(card.get("id", 0))
	if cid <= 0 or int(State.inventory.get(cid, 0)) <= 0:
		return
	var m := Cards.meta(cid)
	var slots := maxi(1, int(_fusion_lab.get("slots", 3)) - 1)
	if int(m.get("fusPower", 0)) > 0 or int(m.get("fusQuality", 0)) > 0:
		_fusion_target = cid
	elif _fusion_inputs.size() < slots and not _fusion_inputs.has(cid):
		_fusion_inputs.append(cid)
	_fusion_failed = false
	_push_fusion_model()


## fusionRequest(...) → 5490 [i32 n]{i32 ids}: inputs then target LAST —
## the client writes the array reversed so the server reads the target last.
func _on_fusion_request(_a: Array, _w: GWidget) -> void:
	if _fusion_inputs.size() < 2 or _fusion_target <= 0:
		return
	var wr := WireWriter.new()
	wr.put_i32(_fusion_inputs.size() + 1)
	for cid in _fusion_inputs:
		wr.put_i32(int(cid))
	wr.put_i32(_fusion_target)
	Session.send(OP_FUSION_REQ, wr.raw(), 3)
	_log_line("fusion sent: %d cards → %s" % [_fusion_inputs.size(),
		Cards.name_of(_fusion_target)])


## Shared removeCard — the method name lives on both the fusion tray and
## the card-master exchange list.
func _on_shared_remove_card(a: Array, w: GWidget) -> void:
	if _gui.is_open("cardMasterDialog"):
		_on_cm_remove(a, w)
	elif _gui.is_open("exchangeDialog"):
		_on_ex_remove(a, w)
	elif _gui.is_open("demonAffiliationDialog"):
		_on_demon_remove(a, w)
	else:
		_on_fusion_remove_input(a, w)


## Shared dropCard — route the drag payload by open dialog. The fusion
## tray slots and the barter slots both accept inventory cards.
func _on_shared_drop_card(_a: Array, w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	var payload: Variant = dnd.get("item")
	if not (payload is Dictionary):
		return
	var cid := int(payload.get("id", 0))
	if cid <= 0 or int(State.inventory.get(cid, 0)) <= 0:
		return
	if _gui.is_open("cardMasterDialog"):
		_cm_stage(cid)
	elif _gui.is_open("exchangeDialog"):
		_ex_stage(cid, w)
	elif _gui.is_open("demonAffiliationDialog"):
		_demon_stage(cid)
	elif _gui.is_open("fusionLabDialog"):
		_fusion_stage(cid, w)


## drop on a tray slot: boost cards land on the target, others on the
## fuel slots (same rule as the double-click stage).
func _fusion_stage(cid: int, _w: GWidget) -> void:
	var m := Cards.meta(cid)
	var slots := maxi(1, int(_fusion_lab.get("slots", 3)) - 1)
	if int(m.get("fusPower", 0)) > 0 or int(m.get("fusQuality", 0)) > 0:
		_fusion_target = cid
	elif _fusion_inputs.size() < slots and not _fusion_inputs.has(cid):
		_fusion_inputs.append(cid)
	_fusion_failed = false
	_push_fusion_model()


## dropFusionCard — drop onto the fusion-target slot itself.
func _on_fusion_drop_target(_a: Array, _w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	var payload: Variant = dnd.get("item")
	if not (payload is Dictionary) or not _gui.is_open("fusionLabDialog"):
		return
	var cid := int(payload.get("id", 0))
	if cid <= 0:
		return
	_fusion_target = cid
	_fusion_failed = false
	_push_fusion_model()


## --- cardMasterDialog (5401 catalog / 5450 buy / 5400 barter) -----------------

var _cm_given := {}       # cid -> staged count for the barter
var _cm_selected := -1    # catalog card being bought


## The retail dialog opens on the catalog reply (5401), like the mailbox.
func _push_cardmaster_model() -> void:
	var model := _gui.gui.model
	var catalog: Array = []
	for c in _shop_cards:
		var it := _card_item(int(c.id))
		it["shopQty"] = int(c.qty)
		catalog.append(it)
	var staged: Array = []
	var sum := 0
	for cid in _cm_given:
		for i in int(_cm_given[cid]):
			staged.append(_card_item(int(cid)))
		sum += Cards.value_of(int(cid)) * int(_cm_given[cid])
	while staged.size() < 4:
		staged.append(null)
	var wanted_val := Cards.value_of(_cm_selected) if _cm_selected > 0 else 0
	model.set_value("cardMasterTrade", {
		"cardMasterCardExchange": catalog,
		"localCardExchange": staged,
		"cardMasterCardsPrice": wanted_val,
		"localCardsPrice": sum,
		"canBuyCards": _cm_selected > 0 and sum >= wanted_val and sum > 0,
		"selectedCard": _card_item(_cm_selected)
			if _cm_selected > 0 else null})
	model.set_value("exchange.cardTrade", _shop_id, "exchangeId")


## selectCardToBuy(selectCardContainer, buyCardContainer) — the two
## container widget args toggle; the row item becomes selectedCard.
func _on_cm_select_card(a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if row is Dictionary:
		_cm_selected = int(row.get("id", -1))
	if a.size() >= 2:
		if a[0] is GWidget: a[0].visible = false
		if a[1] is GWidget: a[1].visible = true
	_push_cardmaster_model()


## chooseAnotherCard — back to the catalog.
func _on_cm_choose_another(a: Array, _w: GWidget) -> void:
	if a.size() >= 2:
		if a[0] is GWidget: a[0].visible = true
		if a[1] is GWidget: a[1].visible = false
	_cm_selected = -1
	_push_cardmaster_model()


## stage a dragged inventory card into the barter offer.
func _cm_stage(cid: int) -> void:
	var owned := int(State.inventory.get(cid, 0))
	var cur := int(_cm_given.get(cid, 0))
	if cur >= owned:
		return
	_cm_given[cid] = cur + 1
	_push_cardmaster_model()


## removeCard on the exchange list — unstage one of the row's cards.
func _on_cm_remove(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	var cid := int(row.get("id", 0))
	if cid <= 0:
		return
	var cur := int(_cm_given.get(cid, 0))
	if cur <= 1:
		_cm_given.erase(cid)
	else:
		_cm_given[cid] = cur - 1
	_push_cardmaster_model()


## buyCards → 5400 [i32 exId][i16 nW]{i32 wanted}[i16 nG]{i32,u16}.
func _on_cm_buy(_a: Array, _w: GWidget) -> void:
	if _cm_selected <= 0 or _cm_given.is_empty():
		return
	var wr := WireWriter.new()
	wr.put_i32(_shop_id)
	wr.put_i16(1)
	wr.put_i32(_cm_selected)
	wr.put_i16(_cm_given.size())
	for cid in _cm_given:
		wr.put_i32(int(cid))
		wr.put_u16(int(_cm_given[cid]))
	Session.send(OP_SHOP_BARTER, wr.raw(), 3)
	_log_line("barter sent: %d kinds → %s" % [_cm_given.size(),
		Cards.name_of(_cm_selected)])


## --- demonAffiliationDialog (5470 card offering) ------------------------------
## Same barter shape as the card master: stage cards in localCardExchange,
## each card's `value` becomes demon reputation server-side. Only the guild
## LEADER can affiliate and only while the guild serves no demon yet.

var _demon_staged := {}     # cid -> staged count


func _open_demon_offer_dialog() -> bool:
	_demon_staged = {}
	_push_demon_model()
	return _gui.open("demonAffiliationDialog") != null


func _push_demon_model() -> void:
	var staged: Array = []
	var sum := 0
	for cid in _demon_staged:
		for i in int(_demon_staged[cid]):
			staged.append(_card_item(int(cid)))
		sum += Cards.value_of(int(cid)) * int(_demon_staged[cid])
	while staged.size() < 4:
		staged.append(null)
	_gui.gui.model.set_value("demonAffiliationTrade", {
		"localCardExchange": staged,
		"localCardsPrice": sum,
		"affiliationPrice": 0,
		"canBuyCards": not _demon_staged.is_empty()})
	_gui.gui.model.set_value("exchange.cardTrade", _demon_id,
		"exchangeId")


func _demon_stage(cid: int) -> void:
	var owned := int(State.inventory.get(cid, 0))
	var cur := int(_demon_staged.get(cid, 0))
	if cur >= owned:
		return
	_demon_staged[cid] = cur + 1
	_push_demon_model()


func _on_demon_remove(_a: Array, w: GWidget) -> void:
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	var cid := int(row.get("id", 0))
	var cur := int(_demon_staged.get(cid, 0))
	if cur <= 1:
		_demon_staged.erase(cid)
	else:
		_demon_staged[cid] = cur - 1
	_push_demon_model()


## affiliateToDemon → 5470 [u16 demon][u16 n]{i32 card, u16 qty}. Retail
## sends every staged instance as its own (card,1) pair.
func _on_demon_affiliate(_a: Array, _w: GWidget) -> void:
	if _demon_staged.is_empty() or _demon_id < 0:
		return
	var wr := WireWriter.new()
	var total := 0
	for cid in _demon_staged:
		total += int(_demon_staged[cid])
	wr.put_i16(_demon_id)
	wr.put_i16(total)
	for cid in _demon_staged:
		for i in int(_demon_staged[cid]):
			wr.put_i32(int(cid))
			wr.put_i16(1)
	_awaiting_offer = true
	Session.send(OP_DEMON_OFFER, wr.raw(), 3)
	_gui.close("demonAffiliationDialog")
	$UI/ElementDlg.visible = false
	_log_line("demon %d offering sent: %d card(s)" % [_demon_id, total])


## --- exchangeDialog (player trade, 5101-5116) ---------------------------------

func _ex_staged_items(side: int) -> Array:
	var out: Array = []
	var staged: Dictionary = _ex.get("staged", {}).get(side, {})
	for cid in staged:
		var it := _card_item(int(cid))
		it["quantity"] = int(staged[cid])
		out.append(it)
	while out.size() < 4:
		out.append(null)
	return out


func _ex_staged_value(side: int) -> int:
	var sum := 0
	var staged: Dictionary = _ex.get("staged", {}).get(side, {})
	for cid in staged:
		sum += Cards.value_of(int(cid)) * int(staged[cid])
	return sum


func _push_exchange_model() -> void:
	if _ex.is_empty():
		return
	var model := _gui.gui.model
	var mine := int(_ex.get("my_side", 0))
	var other := 1 - mine
	var look: Dictionary = State.my_coach_look
	model.set_value("localCoach", "coach_700%d" % int(look.get("sex", 0)),
		"actorDescriptorLibrary")
	model.set_value("exchange.remoteCoach", {
		"name": str(_ex.get("other_name", "?")),
		"actorDescriptorLibrary": "coach_7000"})
	model.set_value("exchange.cardTrade", {
		"exchangeId": int(_ex.get("id", 0)),
		"localCardExchange": _ex_staged_items(mine),
		"remoteCardExchange": _ex_staged_items(other),
		"localCardsValue": _ex_staged_value(mine),
		"remoteCardsValue": _ex_staged_value(other),
		"localUserReady": bool(_ex.get("ready", {}).get(mine, false)),
		"remoteUserReady": bool(_ex.get("ready", {}).get(other, false)),
		"readyButtonEnabled": bool(_ex.get("accepted", false))
			and not bool(_ex.get("ready", {}).get(mine, false))})


## setReadyForExchange → 5109 ready toggle.
func _on_ex_ready(_a: Array, _w: GWidget) -> void:
	if _ex.is_empty():
		return
	var w := WireWriter.new()
	w.put_i64(int(_ex.id))
	Session.send(OP_EX_READY, w.raw(), 3)


## closeCoachExchangeDialog → 5111 cancels the trade.
func _on_ex_close(_a: Array, _w: GWidget) -> void:
	if not _ex.is_empty():
		var w := WireWriter.new()
		w.put_i64(int(_ex.id))
		Session.send(OP_EX_CANCEL, w.raw(), 3)
	_gui.close("exchangeDialog")


## removeCard on my side of the trade → 5107 unstage.
func _on_ex_remove(_a: Array, w: GWidget) -> void:
	if _ex.is_empty():
		return
	var row: Variant = _row_item(w)
	if not (row is Dictionary):
		return
	var cid := int(row.get("id", 0))
	if cid <= 0:
		return
	var wr := WireWriter.new()
	wr.put_i64(int(_ex.id))
	wr.put_i32(cid)
	wr.put_u16(1)
	Session.send(OP_EX_REMOVE, wr.raw(), 3)


## drop on my tray → 5105 stage one of the dragged card.
func _ex_stage(cid: int, _w: GWidget) -> void:
	if _ex.is_empty() or not _ex.get("accepted", false):
		return
	var wr := WireWriter.new()
	wr.put_i64(int(_ex.id))
	wr.put_i32(cid)
	wr.put_u16(1)
	Session.send(OP_EX_ADD, wr.raw(), 3)


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
	alt.text = "Cancel search" if _tourn_search_tid == tid else "Find opponent"
	alt.visible = _registered_tids.has(tid) \
		and (_search_open.get(tid, false) or _tourn_search_tid == tid)
	# Entrants get the bracket straight away (retail opens the tree with the
	# tournament): 28649 → 28650 fills the second list with slot→name rows.
	if _registered_tids.has(tid):
		var w := WireWriter.new()
		w.put_i64(tid)
		w.put_i32(0)
		w.put_str(State.my_coach_name, "i32")
		Session.send(OP_TOURN_TREE_REQ, w.raw(), 2)


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


## --- mapDialog / miniMapDialog ------------------------------------------------
## map.xml is static except the map background (containerMap<id> theme style)
## and the coach pin; miniMapDialog is a live mapNavigator of the same data.
## Coach/element world coords → map px: iso-project the fmd cells, fit the
## projected bounds into the 1024×512 retail map image, apply that same
## transform to each pin.

const _MAP_SIZE := Vector2(1024, 512)


func _push_map_model() -> void:
	var model := _gui.gui.model
	var w := State.current_world
	model.set_value("currentInstanceId", "Map%d" % w)
	var mm := {"mapId": "map%d" % w,
		"mapSize": "%d,%d" % [int(_MAP_SIZE.x), int(_MAP_SIZE.y)],
		"name": "Island %d" % w,
		"eliteBonus": "", "evolutionBonus": "",
		"zoom": 1.0, "xCenter": 222, "yCenter": 9}
	var topo := Topology.load_world(w, Topology.SCOPE_WORLD)
	var cells: Dictionary = topo.get("cells", {})
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for pos in cells:
		if not cells[pos].get("ground", false):
			continue
		var p := Vector2((pos.x - pos.y) * 43.0, (pos.x + pos.y) * 21.5)
		mn = mn.min(p)
		mx = mx.max(p)
	if mn.x >= mx.x:
		model.set_value("miniMap", mm)
		return
	var span := mx - mn
	var s := minf(_MAP_SIZE.x / maxf(span.x + 86.0, 1.0),
		_MAP_SIZE.y / maxf(span.y + 43.0, 1.0))
	var to_px := func(wx: float, wy: float) -> Vector2:
		var p := Vector2((wx - wy) * 43.0, (wx + wy) * 21.5)
		return (p - mn) * s + (_MAP_SIZE - span * s) / 2.0
	var cp: Vector2 = to_px.call(_my_pos.x, _my_pos.y)
	mm["miniMapX"] = cp.x
	mm["miniMapY"] = cp.y
	var points: Array = []
	for id in State.elements:
		var e: Dictionary = State.elements[id]
		var ep: Vector2 = to_px.call(float(e.get("x", 0)), float(e.get("y", 0)))
		points.append({"x": ep.x, "y": ep.y,
			"color": _map_pin_color(int(e.get("type", 0)))})
	points.append({"x": cp.x, "y": cp.y,
		"color": Color(1, 0.85, 0.2), "me": true})
	mm["points"] = points
	model.set_value("miniMap", mm)


## Element-kind → pin color on the minimap (same palette the world markers
## use, mapped through the env-type table's own numbering).
func _map_pin_color(t: int) -> Color:
	match t:
		2: return Color(0.7, 0.7, 0.75)      # mailbox
		4: return Color(0.35, 0.7, 1.0)      # zaap
		6, 9, 11: return Color(0.8, 0.4, 1.0)  # demons
		12: return Color(1.0, 0.65, 0.2)     # firework
		13: return Color(0.95, 0.55, 0.95)   # tournament totem
		14: return Color(0.4, 0.9, 0.85)     # fusion altar
		_: return Color(0.6, 0.9, 0.6)


## dofusarena:zoomIn / zoomOut / setMapZoom — miniMap.zoom drives the
## navigator's zoomScale bind.
func _on_map_zoom(_a: Array, _w: GWidget, delta: float) -> void:
	var model := _gui.gui.model
	var mmv: Variant = model.get_value("miniMap")
	var mm: Dictionary = mmv if mmv is Dictionary else {"zoom": 1.0}
	var z: float = clampf(float(mm.get("zoom", 1.0)) + delta, 0.5, 4.0)
	mm["zoom"] = z
	model.set_value("miniMap", mm)
	model.set_value("zoomScale", z)


func _on_map_zoom_slider(_a: Array, w: GWidget) -> void:
	var model := _gui.gui.model
	var mmv: Variant = model.get_value("miniMap")
	var mm: Dictionary = mmv if mmv is Dictionary else {}
	mm["zoom"] = float(w.content_value) * 3.5 + 0.5
	model.set_value("miniMap", mm)
	model.set_value("zoomScale", mm["zoom"])


## --- fireworkDialog (22095 launch) --------------------------------------------
## 8 launcher slots {card, delay}; the tome panel lists the sets that hold
## type-25 (fairywork/fountain) cards. launchFirework schedules each staged
## card on its own delay and sends one 22095 per launch — the server echoes
## 22094 for everyone near the element.

var _fw_slots := []          # index 0..7 → {"cid": int, "delay": int}
var _fw_elem := -1


func _fw_reset() -> void:
	_fw_slots = []
	for i in 8:
		_fw_slots.append({"cid": 0, "delay": 0})


func _open_firework(_e: Dictionary) -> void:
	if not _open_firework_retail():
		_open_firework_debug()
		return


func _open_firework_retail() -> bool:
	_fw_elem = _elem_id
	_fw_reset()
	_push_firework_model()
	return _gui.open("fireworkDialog") != null


func _push_firework_model() -> void:
	if _fw_slots.is_empty():
		_fw_reset()
	var model := _gui.gui.model
	var sets: Array = []
	for sd in _all_card_sets():
		for c in sd.get("collection", []):
			if c is Dictionary \
					and int(Cards.meta(int(c.get("id", 0))).get("type", 0)) == 25:
				sets.append(sd)
				break
	model.set_value("tomeManager", sets, "fireworkSets")
	var slots := {}
	for i in _fw_slots.size():
		var cid := int(_fw_slots[i].get("cid", 0))
		slots["firework%d" % (i + 1)] = {
			"card": _card_item(cid) if cid > 0 else null,
			"delay": int(_fw_slots[i].get("delay", 0))}
	model.set_value("fireworkLauncher", slots)


## dropFirework(N) — a tome/inventory card lands on launcher slot N.
func _on_fw_drop(args: Array, _w: GWidget) -> void:
	var dnd: Dictionary = _gui.gui.model.values.get("dnd", {})
	var payload: Variant = dnd.get("item")
	if not (payload is Dictionary):
		return
	var cid := int(payload.get("id", 0))
	if cid <= 0 or int(State.inventory.get(cid, 0)) <= 0:
		return
	for a in args:
		if a is int or a is float:
			var i := clampi(int(a), 0, _fw_slots.size() - 1)
			_fw_slots[i]["cid"] = cid
	_push_firework_model()


## removeFirework(N) — the slot's own card is dragged out → clear the slot.
func _on_fw_remove(args: Array, _w: GWidget) -> void:
	for a in args:
		if a is int or a is float:
			var i := clampi(int(a), 0, _fw_slots.size() - 1)
			_fw_slots[i]["cid"] = 0
	_push_firework_model()


## setDelay(N, delayN) — the per-slot textEditor, arg2 = the editor widget.
func _on_fw_delay(args: Array, _w: GWidget) -> void:
	var slot := -1
	var editor: GWidget = null
	for a in args:
		if a is int or a is float:
			if slot < 0:
				slot = int(a)
		elif a is GWidget:
			editor = a
	if slot < 0 or slot >= _fw_slots.size() or editor == null:
		return
	_fw_slots[slot]["delay"] = maxi(0, int(editor.text))


## launchFirework — schedule each staged card; delay is in deciseconds
## (maxChars=3 on the field). One 22095 per launch, element pos/id on wire.
func _on_fw_launch(_a: Array, _w: GWidget) -> void:
	var e: Dictionary = world.element_info(_fw_elem)
	var pos: Vector3i = e.get("pos", Vector3i.ZERO)
	var delay_acc := 0.0
	var sent := 0
	for s in _fw_slots:
		var cid := int(s.get("cid", 0))
		if cid <= 0:
			continue
		delay_acc += int(s.get("delay", 0)) * 0.1
		_launch_firework_at(cid, pos, delay_acc)
		sent += 1
	if sent > 0:
		_gui.close("fireworkDialog")


func _launch_firework_at(cid: int, pos: Vector3i, delay_s: float) -> void:
	var w := WireWriter.new()
	w.put_i32(cid)
	w.put_i32(pos.x)
	w.put_i32(pos.y)
	w.put_i64(_fw_elem)
	var send := func() -> void:
		Session.send(OP_FIREWORK, w.raw(), 3)
	if delay_s <= 0.0 or not is_inside_tree():
		send.call()
	else:
		get_tree().create_timer(delay_s).timeout.connect(send,
			CONNECT_ONE_SHOT)


func _open_firework_debug() -> void:
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
		5, 7:  # breedmaster/demon challenge accepted → 26330 {id, 99}
			var chal := int(_npc.get("chal", _bubble_challenge))
			if chal < 0:
				return
			var w := WireWriter.new()
			w.put_i32(chal)
			w.put_u16(99)
			Session.send(OP_TEAM_TEST, w.raw(), 2)
			$UI/ElementDlg.visible = false
			_log_line("challenge %d accepted" % chal)
		6, 9, ELEM_SCENARIO:  # monologue — Next advances, last closes/pickers
			_npc_page_next()
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
		var tid := int(list.get_item_metadata(sel[0]))
		w.put_i64(tid)
		w.put_i64(State.my_coach_id)
		w.put_i16(99)
		if _tourn_search_tid == tid:
			# The same button cancels a live search (retail toggles it).
			Session.send(OP_TOURN_CANCEL, w.raw(), 2)
			_log_line("tournament search cancel sent (tid %d)" % tid)
		else:
			Session.send(28611, w.raw(), 2)
			_log_line("tournament search sent (tid %d)" % tid)
		return
	if _elem_kind == 11 and not _elem_offer:
		# "Offer cards" — the retail demonAffiliationDialog barter; debug
		# multi-pick stays as the fallback when the GUI layer is off.
		if _open_demon_offer_dialog():
			return
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
	# Closing a queued-up scenario monologue starts the next one.
	if _elem_kind == ELEM_SCENARIO and not _scenario_queue.is_empty():
		_run_scenario(_scenario_queue.pop_front())


## Zaap dialog: reuse the shop panel in "teleport" mode — the stocked list is
## our own type-20 cards (Zaap destinations); clicking one sends 4512.
var _zaap_mode := false

func _open_zaap() -> void:
	# retail zaapDialog — the tome of special sets; debug list as fallback
	if _gui.open("zaapDialog") != null:
		if _pending_zaap_page > 0:
			var page := _pending_zaap_page
			_pending_zaap_page = 0
			_npc = {"pages": [page], "page": 0, "chals": []}
			_elem_kind = ELEM_SCENARIO
			_npc_page_show("Tutorial")
		return
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
	# Scenario 108's useZaap step: once the Zaap dialog is open the tutorial
	# shows one more floating page explaining the teleport click.
	if _pending_zaap_page > 0:
		var page := _pending_zaap_page
		_pending_zaap_page = 0
		_npc = {"pages": [page], "page": 0, "chals": []}
		_elem_kind = ELEM_SCENARIO
		_npc_page_show("Tutorial")


## --- Card Master shop --------------------------------------------------------
## 5401 catalogue → list of cards w/ names+prices. Buy sends 5450
## [i32 shopId][i16 n]{i32 cardId}; Exchange opens the barter pane (5400).
func _open_shop(d: Dictionary) -> void:
	_zaap_mode = false
	_shop_id = int(d.get("shop_id", -1))
	_shop_cards = d.get("cards", [])
	_cm_given = {}
	_cm_selected = -1
	# the retail card-master dialog is the primary UI; the debug pane
	# stays hidden unless the XML fails to load
	if _gui.open("cardMasterDialog") != null:
		_push_cardmaster_model()
		return
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
