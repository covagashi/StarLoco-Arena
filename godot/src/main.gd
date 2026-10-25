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

const ReplayPlayer := preload("res://src/fight/replay_player.gd")
const Codec := preload("res://src/net/codec.gd")
const Overrides := preload("res://src/net/codec_overrides.gd")
const WireReader := preload("res://src/net/wire_reader.gd")
const WireWriter := preload("res://src/net/wire_writer.gd")
const CP1252 := preload("res://src/net/cp1252.gd")
const State := preload("res://src/state.gd")
const DebugLog := preload("res://src/util/debug_log.gd")
const Spells := preload("res://src/gamedata/spells.gd")
const Elements := preload("res://src/gamedata/elements.gd")
const UiStyle := preload("res://src/ui/ui_style.gd")
const Features := preload("res://src/features.gd")
const Story := preload("res://src/gamedata/story.gd")
const FighterCards := preload("res://src/gamedata/fightercards.gd")
const Cards := preload("res://src/gamedata/cards.gd")
const Kanodo := preload("res://src/gamedata/kanodo.gd")
const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")
const TournamentDefs := preload("res://src/gamedata/tournament_defs.gd")
const Topology := preload("res://src/maps/topology.gd")
const Scenarios := preload("res://src/gamedata/scenarios.gd")
const BugReport := preload("res://src/ui/bug_report.gd")

const OP_CLIENT_VERSION := 7
const OP_CLIENT_AUTH := 1025
const OP_INVALID_VERSION := 8
const OP_AUTH_RESULT := 1024
## Godot-only extension pair — the retail client never uses these: 60000 asks
## for server runtime config, 60001 answers a key/value map (web_base_url).
const OP_CLIENT_CONFIG_REQ := 60000
const OP_CLIENT_CONFIG := 60001
const OP_GHOST_SAVE := 60010           # C2S [str name][u8 n]{[i64 fighter][u16 len][json]}
const OP_GHOST_RESULT := 60011         # S2C [u8 action][u8 code][i64 id]
const OP_GHOST_LIST_REQ := 60012       # C2S empty
const OP_GHOST_LIST := 60013           # S2C [u16 n]{i64 id, str name, str owner, u8 n, i32 elo, u8 mine}
const OP_GHOST_FIGHT := 60014          # C2S [i64 ghost][i64 replayOf]
const OP_GHOST_DELETE := 60015         # C2S [i64 ghost]
const OP_GHOST_LADDER_REQ := 60016     # C2S empty
const OP_STORY_REQUEST := 60020        # C2S empty (S21)
const OP_STORY := 60021                # S2C [u16 n]{i32 challengeId} — the campaign challenges won
const OP_FIGHTER_EQUIP_REQUEST := 60022  # C2S [i64 fighterId] (S22)
const OP_FIGHTER_EQUIP := 60023          # S2C [i64 fighterId][u16 n]{i32 cardId} — what it may wear
const OP_GHOST_LADDER := 60017         # S2C [i32 elo][i32 rank][i32 fights][i32 wins][u16 n]{str, i32×3, u8}
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
const OP_TOURN_SEARCH_START := 28611     # C2S [i64 tid][i64 me][i16 preset] arch 2
const OP_TOURN_OPENING := 28646          # [i64 tid][i64 durationMs] — period opens now
const OP_TOURN_UNFINISHED := 28618       # [i64 tid] — carry your place over?
const OP_TOURN_CARRY := 28617            # C2S [i64 tid] arch 2 — yes
const OP_TOURN_CREATE := 17010           # C2S player tournament (aFu) arch 3
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
const OP_FRIEND_REMOVE := 3133           # C2S [str8 name] (uk_1 event 21050 → aym_0)
const OP_FRIEND_ADD := 3129              # C2S [str8 name] (event 21051 → QZ)
const OP_IGNORE_REMOVE := 3135           # C2S [str8 name] (event 21052 → aer_0)
const OP_IGNORE_ADD := 3131              # C2S [str8 name] (event 21053 → MP)
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
const ELEM_SCENARIO := -2                # pseudo kind: tutorial monologue (zone trigger)
const OP_SPHERE_BUY := 23009             # C2S [i64 fighter][i32 sphere][i32 card]

var _login_name := ""       # the account last submitted (coach-creation default)
var _login_pass := ""
@onready var log := $UI/Chat

var _my_pos := Vector3.ZERO   # last EnterInstance position
var _challenge_handle := -1   # pending 26300 handle (-1 = none)
var _challenge_target := -1   # coach id we clicked "challenge" on
var _challenge_evo := 0       # evolution flag echoed back on accept
var _searching := false       # combattre queue state (23104 ack)
var _search_kind := 0         # 1=classic 2=quick 3=evolution 4=tournament (for cancel)
var _match := {}              # pending 23110 MatchFound row
var _shop_id := -1            # catalogue id echoed back on buy/barter
var _shop_cards := []         # [{id, qty}] of the open catalogue
var _barter_wanted := -1      # card id picked for exchange
var _gui: GuiLayer            # retail XULOR2 dialog layer
const NativeLobbyPanel := preload("res://src/ui/lobby_panel.gd")
var _lobby_screen
var _lobby_ready := false
## The saved screen/sound preferences go in once per run: main.tscn is
## reloaded after every fight, and re-applying the window mode would flicker.
static var _prefs_applied := false
var _login_screen             # baked-art login (PippopLogin via preload)
var _create_screen            # baked-art coach creation (PippopCoachCreation)
var _pending_login := ""      # login queued while connecting
var _pending_pass := ""       # password queued while connecting


## What the window says. project.godot keeps "StarLoco Arena" as the internal
## name, because it also names the user data folder (settings, replays).
const WINDOW_TITLE := "Pippop Arena"


func _ready() -> void:
	get_window().title = WINDOW_TITLE
	Session.connected.connect(_on_connected)
	Session.disconnected.connect(_on_disconnected)
	Session.message.connect(_on_message)
	# retail XULOR2 layer — logonDialog replaces the wire-test login row
	_gui = GuiLayer.new()
	for panel_name in preload("res://src/ui/lobby_panels.gd").TITLES:
		_gui.native_factories[panel_name] = _make_native_lobby_panel
	_gui.native_factories["cardMasterDialog"] = _make_card_master_panel
	_gui.native_factories["mailboxDialog"] = _make_mailbox_panel
	_gui.native_factories["fusionLabDialog"] = _make_fusion_panel
	_gui.native_factories["npcTalkDialog"] = _make_talk_panel
	_gui.native_factories["demonAffiliationDialog"] = _make_demon_panel
	_gui.native_factories["fireworkDialog"] = _make_firework_panel
	_gui.native_factories["fightReportDialog"] = _make_report_panel
	_gui.native_factories["exchangeDialog"] = _make_exchange_panel
	_gui.native_factories["askDialog"] = _make_ask_panel
	_gui.native_factories["coachLevelUpDialog"] = _make_level_up_panel
	_gui.native_factories["teamPickDialog"] = _make_team_pick_panel
	_gui.native_factories["kanodoDialog"] = _make_kanodo_panel
	_gui.native_factories["coachEquipDialog"] = _make_equip_panel
	add_child(_gui)
	if not _prefs_applied:
		_prefs_applied = true
		_apply_audio_prefs()
		_apply_vsync_pref()
		if _gui.gui.model.get_value("gamePreferences", "fullScreen") == true:
			_apply_fullscreen_pref()
		else:
			_on_apply_resolution([], null)   # no-op until one was picked
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
	_gui.on("inviteToGuild", _on_guild_invite_by_name)
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
	# dofusarena:* — the native Options panel (lobby_panels._options) writes
	# gamePreferences, these apply the side effects, and the GUI layer saves
	# them after every handler (user://gui_settings.cfg [prefs])
	_gui.on("setMusicMute", func(_a, _w): _apply_audio_prefs())
	_gui.on("setSaveReplay", func(_a, _w): pass)   # S11: saved; read per fight
	_gui.on("setMusicVolume", func(_a, _w): _apply_audio_prefs())
	_gui.on("setSoundsMute", func(_a, _w): _apply_audio_prefs())
	_gui.on("setSoundsVolume", func(_a, _w): _apply_audio_prefs())
	_gui.on("activateVSync", func(_a, _w): _apply_vsync_pref())
	_gui.on("setFullScreen", func(_a, _w): _apply_fullscreen_pref())
	_gui.on("applyResolution", _on_apply_resolution)
	_gui.on("destroyCoach", _on_destroy_coach)
	_gui.dialog_opened.connect(_on_gui_dialog_opened)
	$UI/Chat.visible = false
	if State.my_coach_id <= 0:
		_show_login_screen()
	else:
		_lobby_ready = Session.is_online() and State.current_world >= 0
		_mount_lobby_menubar({"name": State.my_coach_name})
	$UI/Chat.trade.connect(_invite_exchange)
	$UI/Chat.watch.connect(_watch_coach)
	# Re-entering after a fight: replay anything that arrived mid-scene-change
	# — LAST, once the GUI layer and the scene's own setup exist. Draining it
	# first ran the 4516 lobby entry with no _gui (B-178): the lobby re-entry
	# aborted, and with it the post-fight report.
	for m in Session.client.drain():
		_on_message(m.op, m.raw)
	Session.client.scene_active = true


func _exit_tree() -> void:
	# Fight transition: buffer until the next scene drains in its _ready.
	if Session.client != null:
		Session.client.scene_active = false


func _on_connected() -> void:
	_log_line("[color=green]%s[/color]" % I18n.t("net.connected"))
	if _pending_login != "":
		_send_auth(_pending_login, _pending_pass)
		_pending_login = ""


func _on_retail_logon(args: Array, _widget: GWidget) -> void:
	# dofusarena:logon(loginForm) — green button / Enter in a field
	var login := str(_gui.gui.model.get_value("account.name"))
	var password := str(_gui.gui.model.get_value("account.password"))
	if login.strip_edges() == "":
		return
	_login_name = login
	_login_pass = password
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
		_log_line(I18n.t("net.connecting", {"host": hp[0],
			"port": hp[1] if hp.size() > 1 else "5555"}))
	_gui._save_settings()


func _on_disconnected() -> void:
	_lobby_ready = false
	if is_instance_valid(_lobby_screen):
		_lobby_screen.set_actions_ready(false)
		_lobby_screen.show_bubble(I18n.t("net.disconnected"))
	_log_line("[color=red]%s[/color]" % I18n.t("net.disconnected"))
	if _login_screen != null and _pending_login != "":
		_login_screen.set_error(I18n.t("login.connect_failed"))
		_pending_login = ""


func _show_login_screen() -> void:
	Audio.play_music("")   # the retail starts its music on entering the world
	_login_screen = preload("res://src/ui/login_screen.gd").new()
	$UI.add_child(_login_screen)   # CanvasLayer — camera must not shift it
	_login_screen.submit.connect(_on_login_submit)
	var pm: Dictionary = _gui.gui.model.values.get("proxy", {})
	var hosts: Array = []
	for it in pm.get("list", []):
		hosts.append(str(it.get("text", it)) if it is Dictionary else str(it))
	if hosts.is_empty():
		hosts = ["140.238.172.196:3000", "127.0.0.1:5555"]
	_login_screen.set_proxies(hosts, str(pm.get("selected", hosts[0])))
	_login_screen.name_edit.text = str(
		_gui.gui.model.values.get("account.name", ""))
	if _gui.gui.model.values.get("account.remember", false):
		_login_screen.pass_edit.text = str(
			_gui.gui.model.values.get("account.password", ""))


func _on_login_submit(login: String, password: String, proxy: String) -> void:
	_gui.gui.model.values["account.name"] = login
	_gui.gui.model.values["account.password"] = password
	var pm: Dictionary = _gui.gui.model.values.get("proxy", {})
	pm["selected"] = proxy
	_login_name = login
	_login_pass = password
	if Session.is_online():
		_send_auth(login, password)
	else:
		_pending_login = login
		_pending_pass = password
		if proxy == "":
			proxy = "140.238.172.196:3000"
		var hp := proxy.split(":")
		Session.connect_to(hp[0], int(hp[1]) if hp.size() > 1 else 5555)
		_log_line(I18n.t("net.connecting", {"host": hp[0],
			"port": hp[1] if hp.size() > 1 else "5555"}))
	_gui._save_settings()


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
	DebugLog.add("sent version + auth for '%s'" % login_txt)


func _on_message(opcode: int, raw: PackedByteArray) -> void:
	var payload := WireReader.new(raw)
	if log.feed(opcode, payload):
		return  # chat family handled by the chat box
	match opcode:
		OP_INVALID_VERSION:
			_log_line("[color=red]%s[/color]" % I18n.t("net.version_refused"))
			Session.client.disconnect_from()
		OP_AUTH_RESULT:
			var code := payload.get_u8()
			if code == 0:
				_log_line("[color=green]%s[/color]" % I18n.t("net.auth_ok"))
			else:
				_log_line("[color=red]%s[/color]" % I18n.t(
					"net.auth_refused", {"code": code}))
				if _login_screen != null:
					_login_screen.set_error(I18n.t("login.bad_credentials"))
		OP_COACH_CREATE_REQ:
			_open_coach_creation()
		OP_COACH_CREATION_RESULT:
			# 2050: [u8 result] — 0 = created; success is followed by
			# COACH_INFO + ENTER_INSTANCE, failures only carry the code.
			var res := payload.get_u8()
			if res != 0:
				_log_line("[color=red]%s[/color]" % I18n.t(
					"net.coach_refused", {"code": res}))
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
				# two statements: GDScript evaluates the right side of
				# `d[a()] = b()` first, which swapped every id and value (S20B)
				var crit := cb.get_u16()
				State.criteria[crit] = cb.get_u16()
			if not State.guild.is_empty():
				DebugLog.add("guild: '%s' — rank %s, demon %d" % [
					State.guild.get("guild", "?"),
					State.guild.get("rank_name", "?"),
					int(State.guild.get("demon_id", 0))])
			_log_line("[color=green]%s[/color]" % I18n.t("net.in_lobby"))
			# Ask for the server's public web address (60000 → 60001): the
			# bug reporter POSTs to it, and a TCP link carries no http URL.
			State.net.send_message(OP_CLIENT_CONFIG_REQ, PackedByteArray(), 3)
			_gui.close("logonDialog")
			if _login_screen != null:
				_login_screen.queue_free()
				_login_screen = null
			if _create_screen != null:
				_create_screen.queue_free()
				_create_screen = null
			_mount_lobby_menubar(d)
		OP_ENTER_INSTANCE:
			var d := Codec.decode(opcode, payload)
			State.current_world = int(d.get("world_id", -1))
			State.elements = {}   # registry drops with the old world
			_coach_names = {}
			_my_pos = Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)),
				float(d.get("alt", 0)))
			DebugLog.add("entering instance world=%d pos=(%s,%s)" % [
				State.current_world, d.get("x"), d.get("y")])
		OP_INSTANCE_READY:
			_lobby_ready = true
			_log_line("[color=green]%s[/color]" % I18n.t("net.in_world"))
			_show_lobby_screen()
			# 28601 on arrival: our entries, the open search periods (28630)
			# and an unfinished tournament's carry-over question (28618)
			Session.send(OP_TOURN_LIST, PackedByteArray(), 2)
			# Post-fight re-entry: the debrief was decoded on 8300 — pop the
			# result panel now that the island is up.
			if not State.fight_result.is_empty():
				_show_fight_result()
			# aog_1: while achievement "coach created" (criterion 229) is unset,
			# retail acks the tutorial instance (4517) and reports criterion
			# 229 done (22003) on every entry until the server persists it.
			if not State.criteria.has(229):
				# S10: the first time ever — Adamai's intro (scenarios 0, 1);
				# "Cerrar" skips it, as retail's "Saltarse el tutorial"
				_queue_scenario(0)
				_scenario_queue.append(1)
				State.criteria[229] = 1
				State.net.send_message(OP_TUTORIAL_READY,
					PackedByteArray(), 3)
				var w := WireWriter.new()
				w.put_i16(229)
				w.put_u8(1)
				w.put_i16(1)
				State.net.send_message(OP_STAT_UPD, w.raw(), 2)
		OP_ACTOR_SPAWN:
			_read_coach_spawns(payload)
		OP_ACTOR_DESPAWN:
			var n := payload.get_i32()
			for i in n:
				var did := int(payload.get_i64())
				_coach_names.erase(did)
		OP_ACTOR_MOVEMENT:
			# Other coaches walking — [i64 id]{i32 x, i32 y, i16 z}+; the lobby
			# renders nobody, decoded only to document the wire.
			payload.get_i64()
			while payload.remaining() >= 10:
				payload.get_i32()
				payload.get_i32()
				payload.get_i16()
		OP_ACTOR_TELEPORTS:
			# 4510 — actor snapped to a cell (GM /tp, zaap arrival effects).
			Codec.decode(opcode, payload)
		OP_CLIENT_CONFIG:
			# [u8 n] n × {[u8 klen][key][u16 vlen][value]} — see the server's
			# handlers_clientconfig.go. Today carries web_base_url.
			var n := payload.get_u8() if payload.remaining() >= 1 else 0
			for i in n:
				var k := payload.get_str("u8", "utf8")
				var v := payload.get_str("u16", "utf8")
				if k == "web_base_url":
					State.web_base_url = _web_base_url(v)
			DebugLog.add("client config: web_base_url=%s" % State.web_base_url)
		OP_GHOST_LIST:
			var list := []
			for i in payload.get_u16():
				list.append({"id": payload.get_i64(), "name": payload.get_str("u8", "utf8"),
					"owner": payload.get_str("u8", "utf8"), "fighters": payload.get_u8(),
					"elo": payload.get_i32(), "mine": payload.get_u8() == 1})
			_gui.gui.model.set_value("ghosts", list, "list")
		OP_FIGHTER_EQUIP:
			var wfid := int(payload.get_i64())
			var wear: Array = []
			for i in payload.get_u16():
				wear.append(int(payload.get_i32()))
			_eq_wearable[wfid] = wear
			if wfid == _eq_fid:
				_push_fequip_model()
		OP_STORY:
			_story_won = []
			for i in payload.get_u16():
				_story_won.append(int(payload.get_i32()))
			_push_story_model()
		OP_GHOST_LADDER:
			var l := {"elo": payload.get_i32(), "rank": payload.get_i32(),
				"fights": payload.get_i32(), "wins": payload.get_i32(), "rows": []}
			for i in payload.get_u16():
				l.rows.append({"name": payload.get_str("u8", "utf8"), "elo": payload.get_i32(),
					"fights": payload.get_i32(), "wins": payload.get_i32(),
					"mine": payload.get_u8() == 1})
			_gui.gui.model.set_value("ghosts", l, "ladder")
		OP_GHOST_RESULT:
			var action := payload.get_u8()
			var code := payload.get_u8()
			var key := "ghost.ok.%d" % action if code == 0 else "ghost.err.%d" % code
			_gui.gui.model.set_value("ghosts", I18n.t(key), "status")
			if code != 0 and action == 2:
				_log_line("[color=red]%s[/color]" % I18n.t(key))
			if code == 0 and action != 2:
				Session.send(OP_GHOST_LIST_REQ, PackedByteArray(), 3)
		OP_FIGHT_CREATION:
			State.fight_world = State.current_world
			State.fight_data = Codec.decode(opcode, payload)
			State.index_fighters(State.fight_data)
			_log_line("[color=green]%s[/color]" % I18n.t("fight.created",
				{"n": State.fighters.size()}))
			# Buffer from NOW, not from _exit_tree: the scene change is
			# deferred, and the 4102/8010 the server sends right after the
			# 8000 usually arrive in the same read. They used to reach this
			# lobby, which drops them, so the fight view never showed the
			# versus nor sent its 8011 (S08).
			Session.client.scene_active = false
			get_tree().change_scene_to_file("res://src/fight/fight_view.tscn")
		OP_FIGHTER_LIST:
			# Lobby roster (et_2 blobs) — fills the selectable fighter list.
			var d := Codec.decode(opcode, payload)
			State.roster = d.get("fighters", [])
			_push_hub_model.call_deferred()
			# the Team panel lists them; the chat only says when there are none
			# (S07: it used to print the whole roster on every push)
			if State.roster.is_empty():
				_log_line(I18n.t("lobby.roster_empty"))
			_settle_revive()
			_push_team_model()
		OP_TEAM_PRESETS:
			var d := Codec.decode(opcode, payload)
			State.presets = d.get("presets", [])
			_push_hub_model.call_deferred()
		OP_FIGHTER_CREATE_RESULT:
			var d := Codec.decode(opcode, payload)
			if int(d.result) == 0:
				_log_line("[color=green]%s[/color]" % I18n.t("fighter.created",
					{"name": d.fighter.get("name", "?")}))
			else:
				_log_line("[color=red]%s[/color]" % I18n.t("fighter.err",
					{"code": int(d.result)}))
		OP_FIGHTER_DELETE_RESULT:
			var d := Codec.decode(opcode, payload)
			if int(d.result) == 0:
				_log_line(I18n.t("fighter.deleted", {"id": int(d.fighter_id)}))
			else:
				_log_line("[color=red]%s[/color]" % I18n.t("fighter.err",
					{"code": int(d.result)}))
		OP_FIGHTER_LOADOUT_RESULT:
			# 6010: [i64 fid][u8 result][u16 spellsLen]{i32}[u16 cardsLen]{i32}
			var fid := int(payload.get_i64())
			var res := payload.get_u8()
			if res == 0:
				var spell_n := payload.get_u16()
				var spells := []
				for i in spell_n / 4:
					spells.append(int(payload.get_i32()))
				# the stored cards come back too ([u16 slot][i32 card] each);
				# keeping only the spells made a reopened editor show the old
				# equipment, as if the save had failed (S20)
				var cards := []
				if payload.remaining() >= 2:
					var card_n := payload.get_u16()
					for i in card_n / 6:
						var slot := payload.get_u16()
						cards.append({"slot": slot, "id": int(payload.get_i32())})
				var fname := ""
				for f in State.roster:
					if int(f.get("id", -1)) == fid:
						f.spells = spells
						f.cards = cards
						fname = str(f.get("name", ""))
				_log_line("[color=green]%s[/color]" % I18n.t(
					"fighter.loadout_saved", {"n": spells.size()}))
				if fid == _eq_fid:
					_eq_save_state = "saved"
					_toast(I18n.t("fe.saved_toast", {"name": fname}))
					_push_fequip_model()
			else:
				_log_line("[color=red]%s[/color]" % I18n.t("fighter.err",
					{"code": res}))
				if fid == _eq_fid:
					_eq_save_state = "error"
					_toast(I18n.t("fe.save_err", {"code": res}))
					_push_fequip_model()
		OP_SEARCH_RESULT:
			# 23104 [i16 preset][u8 accepted] — the "Recherche en cours" ack
			payload.get_i16()
			if payload.get_u8() == 1:
				_searching = true
				_search_kind = 1
				_set_searching(true)
				_log_line(I18n.t("search.searching"))
		OP_SEARCH_CANCEL_RESULT:
			# 23102 [u8] — reply that closes the searching state
			payload.get_u8()
			_searching = false
			_search_kind = 0
			_set_searching(false)
			_log_line(I18n.t("search.cancelled"))
		OP_FIGHT_STARTING:
			# 23106 — paired, fight incoming (8000 follows)
			_searching = false
			_search_kind = 0
			_set_searching(false)
			_log_line("[color=green]%s[/color]" % I18n.t("search.found"))
		OP_SEARCH_ERROR:
			var code := payload.get_u8()
			if code >= 3:
				_searching = false
				_search_kind = 0
				_set_searching(false)
			DebugLog.add("classic search error %d" % code)
			_log_line("[color=red]%s[/color]" % _search_error_text(code))
		OP_QUICK_SEARCH_ACK:
			# 2304 empty — the random-fight search is live
			_searching = true
			_search_kind = 2
			_set_searching(true)
			_log_line(I18n.t("search.searching"))
		OP_QUICK_CANCEL_RES:
			# 2306 [u8 result] — quick-search cancelled (or was idempotent)
			payload.get_u8()
			_searching = false
			_search_kind = 0
			_set_searching(false)
			_log_line(I18n.t("search.cancelled"))
		OP_MATCH_FOUND:
			# 23110 — paired pending match; retail asks before the accept.
			var d := Codec.decode(opcode, payload)
			_match = d
			_ask("match", I18n.t("ask.match"),
				I18n.t("search.match_ask", {"name": str(d.get("opp_name", "?"))}), _answer_match)
		OP_MATCH_CONFIRM:
			# 23116 [i32 n] — 0 rows means our match fell through
			if payload.get_i32() == 0:
				_log_line("[i]%s[/i]" % I18n.t("search.fell_through"))
		OP_EVO_SEARCH_RES:
			# 23004 [i16 preset][u8 accepted]
			payload.get_i16()
			if payload.get_u8() == 1:
				_searching = true
				_search_kind = 3
				_set_searching(true)
				_log_line(I18n.t("search.searching_evo"))
		OP_EVO_CANCEL_RES:
			payload.get_i8()
			_searching = false
			_search_kind = 0
			_set_searching(false)
			_log_line(I18n.t("search.cancelled"))
		OP_EVO_STARTING:
			_searching = false
			_search_kind = 0
			_set_searching(false)
			_log_line("[color=green]%s[/color]" % I18n.t("search.found_evo"))
		OP_EVO_ERROR:
			var code := payload.get_i8()
			_searching = false
			_search_kind = 0
			_set_searching(false)
			DebugLog.add("evolution search error %d" % code)
			_log_line("[color=red]%s[/color]" % _search_error_text(code, true))
		OP_RECONNECT_Q:
			# 26333 — a dropped fight is still alive; resume it (26334).
			var w := WireWriter.new()
			w.put_u8(1)
			Session.send(OP_RECONNECT_A, w.raw(), 2)
			_log_line(I18n.t("fight.resuming"))
		OP_TOURN_TREE:
			# 28650 bracket — slot→name rows for the Calendar's tournament
			# (the reply carries no id: it answers the last 28649).
			var d := Codec.decode(opcode, payload)
			# heap slots: 1 winner, 2-3 final, 4-7 semis, 8-15 quarters,
			# 16-31 first round (ah_1)
			var slots := {}
			for sl in d.get("slots", {}):
				slots[int(sl)] = str(d.slots[sl])
			_tourn_bracket = {"tid": _tourn_tree_tid, "slots": slots}
			_refresh_calendar()
		OP_DUO_INVITATION:
			# 6025 [str8 team][str8 inviterName][i64 inviter][i64 invited]
			var team := payload.get_str("u8")
			var who := payload.get_str("u8")
			_duo_pending = {"team": team,
				"inviter": int(payload.get_i64()),
				"invited": int(payload.get_i64())}
			_ask("duo", I18n.t("ask.duo"), I18n.t("duo.invite_ask",
				{"name": who, "team": team}), _answer_duo)
		OP_DUO_REFUSED:
			_log_line("[color=red]%s[/color]" % I18n.t("duo.refused"))
		OP_DUO_ACCEPTED:
			_log_line("[color=green]%s[/color]" % I18n.t("duo.formed"))
		OP_DUO_GONE:
			_log_line("[i]%s[/i]" % I18n.t("duo.left"))
		OP_SPECTATE_REPLY:
			# 2261 [i8 1/0] — 1 = coach is in a live fight; join as viewer.
			if _watch_target >= 0 and payload.get_u8() == 1:
				var w := WireWriter.new()
				w.put_i64(_watch_target)
				Session.send(OP_SPECTATE_JOIN, w.raw(), 2)
				State.spectating = true
				_log_line(I18n.t("watch.joining"))
			else:
				_log_line("[i]%s[/i]" % I18n.t("watch.none"))
				_watch_target = -1
		OP_SPECTATE_DOWN:
			_log_line("[i]%s[/i]" % I18n.t("watch.closed"))
			State.spectating = false
		OP_LADDER_1V1, OP_LADDER_GUILD, OP_LADDER_2V2, OP_LADDER_TOURN, \
				OP_LADDER_COACH, OP_LADDER_DEMON, OP_LADDER_PRO:
			var ld := Codec.decode(opcode, payload)
			_ladder_data[opcode] = ld
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
			_log_line("[i]%s[/i]" % I18n.t("fight.over"))
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
				_log_line(I18n.t("challenge.sent", {"name": cname}))
			else:
				_ask("challenge", I18n.t("ask.challenge"), I18n.t("challenge.ask",
					{"name": cname}), _answer_challenge)
		OP_CHALLENGE_ACCEPTED:
			# 26302 [i64 handle][u8 evo] — both sides now pick a team (26303)
			payload.get_i64()
			_challenge_evo = payload.get_u8()
			_log_line("[color=green]%s[/color]" % I18n.t("challenge.accepted"))
			_open_team_pick()
		OP_CHALLENGE_CANCELLED:
			payload.get_i64()
			_challenge_handle = -1
			_ask_withdraw("challenge")
			_gui.close("teamPickDialog")
			_log_line("[i]%s[/i]" % I18n.t("challenge.cancelled"))
		OP_TEAM_PRESET_SAVED:
			# 6020 [u8 status] — only sent on failure (25 = name taken)
			var st := payload.get_u8()
			if st != 0:
				_log_line("[color=red]%s[/color]" % I18n.t("preset.err",
					{"code": st}))
		OP_TEAM_PRESET_DELETED:
			# 6022 [u8 status][i16 teamId on success]
			if payload.get_u8() == 0:
				var tid := int(payload.get_i16())
				State.presets = State.presets.filter(
					func(p): return int(p.id) != tid)
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
				# Zone triggers spawn AFTER the coach — re-check so a coach
				# already standing inside the zone still fires it.
				if e.get("kind") == 8:
					_check_zone_trigger(_my_cell())
		OP_ELEMENT_DESPAWN:
			var d := Codec.decode(opcode, payload)
			for id in d.get("ids", []):
				State.elements.erase(int(id))
		OP_WALLET:
			var d := Codec.decode(opcode, payload)
			for c in d.get("currencies", []):
				State.wallet[int(c.type)] = int(c.amount)
			if _gui.is_open("cardMasterDialog"):
				_push_cardmaster_model()
		OP_INVENTORY:
			var d := Codec.decode(opcode, payload)
			State.inventory = {}
			for c in d.get("cards", []):
				State.inventory[int(c.card_id)] = int(c.qty)
			# what the coach wears (section 1, full on every push — B-179)
			_equip_slots = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			for e in d.get("equipped", []):
				if int(e.slot) >= 0 and int(e.slot) < 14:
					_equip_slots[int(e.slot)] = int(e.card_id)
			_equip_draft = _equip_slots.duplicate()
			if _gui.is_open("coachEquipDialog"):
				_push_equip_model()
			if _gui.is_open("cardMasterDialog"):
				_push_cardmaster_model()
			if _gui.is_open("fusionLabDialog"):
				_push_fusion_model()
			if _gui.is_open("teamManagementDialog"):
				_push_team_model()
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
					_log_line("[color=green]%s[/color]" % I18n.t("demon.accepted"))
					# the first offering affiliates the clan; the server pushes no
					# guild record for it
					if int(State.guild.get("demon_id", 0)) == 0:
						State.guild["demon_id"] = _demon_id
					# the server consumes the cards but pushes no inventory (the
					# retail client drops them from its own view, handlers_demon)
					for cid in _demon_offered:
						var left := int(State.inventory.get(cid, 0)) - int(_demon_offered[cid])
						if left > 0:
							State.inventory[cid] = left
						else:
							State.inventory.erase(cid)
					_demon_staged = {}
					_demon_request_ladder()
				else:
					_log_line("[color=red]%s[/color]" % I18n.t("demon.failed"))
				_demon_status = {"ok": res == 0,
					"text": I18n.t("demon.accepted" if res == 0 else "demon.failed")}
				if _gui.is_open("demonAffiliationDialog"):
					_push_demon_model()
				if _gui.is_open("socialDialog") or _gui.is_open("guildDialog"):
					_push_social_model()
			else:
				for c in d.get("currencies", []):
					State.wallet[int(c.type)] = int(c.amount)
				var msg := I18n.t(["shop.done", "shop.tokens"][res] if res <= 1
					else "shop.refused", {"code": res})
				_log_line("[color=%s]%s[/color]" % ["green" if res == 0 else "red", msg])
				if _gui.is_open("cardMasterDialog"):
					if res == 0:
						_cm_given = {}
					_cm_status = {"text": msg, "ok": res == 0}
					_push_cardmaster_model()
		OP_FUSION_RESULT:
			var d := Codec.decode(opcode, payload)
			# One sentence for the chat and the native panel. The server
			# names the missed card AND the leftover on a failed roll; say
			# both, the leftover is what the player gets back.
			var got := int(d.get("obtained", 0))
			var missed := int(d.get("not_obtained", 0))
			var back := int(d.get("recovered", 0))
			var text := ""
			if int(d.get("result", 0)) != 0:
				text = I18n.t("fusion.refused")
			elif got > 0:
				text = I18n.t("fusion.got", {"name": Cards.name_of(got)})
			elif missed > 0:
				text = I18n.t("fusion.missed", {"name": Cards.name_of(missed)})
				if back > 0:
					text += " " + I18n.t("fusion.leftovers", {"name": Cards.name_of(back)})
			elif back > 0:
				text = I18n.t("fusion.leftovers", {"name": Cards.name_of(back)})
			else:
				text = I18n.t("fusion.failed")
			_log_line(("[color=green]%s[/color]" if got > 0 else "[color=red]%s[/color]") % text)
			_fusion_status = {"text": text, "ok": got > 0}
			# the tray is consumed either way — reset the lab
			_fusion_inputs = []
			_fusion_failed = int(d.get("obtained", 0)) <= 0 \
				and int(d.get("not_obtained", 0)) <= 0 \
				and int(d.get("recovered", 0)) <= 0
			if _gui.is_open("fusionLabDialog"):
				_push_fusion_model()
		OP_DEMON_LADDER_RES:
			var d := Codec.decode(opcode, payload)
			# the clans serving one demon, for the offering panel (S18)
			_demon_ladder = {"demon": int(d.get("demon", -1)), "rows": d.get("rows", [])}
			if _gui.is_open("demonAffiliationDialog"):
				_push_demon_model()
		OP_TOURN_CALENDAR, OP_TOURN_LIST_RES:
			var d := Codec.decode(opcode, payload)
			var rows: Array = d.get("events", d.get("tournaments", []))
			if opcode == OP_TOURN_CALENDAR:
				_calendar_events = rows
			else:
				# the list is the whole set of live editions: a finished one
				# drops out, and the coach's own status says whether it is
				# entered (-128 = not) — so a registration made in an earlier
				# session shows too (BACKLOG §1)
				_tourn_rows = {}
				for r0 in rows:
					var rt := int(r0.get("id", -1))
					_tourn_rows[rt] = r0
					if int(r0.get("status", -128)) != -128:
						_registered_tids[rt] = true
					else:
						_registered_tids.erase(rt)
				_push_tourn_search_model()
			if _gui.is_open("calendarDialog"):
				_push_calendar_model()
		OP_TOURN_REG_RES:
			var d := Codec.decode(opcode, payload)
			var tid := int(d.tournament_id)
			var msg := I18n.t("tourn.registered") if int(d.code) == 0 \
				else (I18n.t("tourn.full") if int(d.code) == 2
					else I18n.t("tourn.reg_refused", {"code": int(d.code)}))
			if int(d.code) == 0:
				_registered_tids[tid] = true
			_log_line(I18n.t("tourn.msg", {"tid": tid, "msg": msg}))
			_tourn_status = {"tid": tid, "text": msg, "ok": int(d.code) == 0}
			_refresh_calendar()
		OP_TOURN_SEARCH_PERIOD:
			var d := Codec.decode(opcode, payload)
			_search_open[int(d.tournament_id)] = int(d.open) != 0
			_refresh_calendar()
			_push_tourn_search_model()
			_log_line(I18n.t("tourn.search_state", {"tid": int(d.tournament_id),
				"state": I18n.t("tourn.open" if int(d.open) != 0
					else "tourn.closed")}))
		OP_TOURN_SEARCH_RES:
			var d := Codec.decode(opcode, payload)
			_log_line(I18n.t("tourn.msg", {"tid": int(d.tournament_id),
				"msg": I18n.t("tourn.search_wait") if int(d.accepted) != 0
					else I18n.t("tourn.search_refused")}))
			if int(d.accepted) != 0:
				_tourn_search_tid = int(d.tournament_id)
				# the lobby's "searching… cancel" bar, like the other lanes
				_searching = true
				_search_kind = 4
				_set_searching(true)
			else:
				_tourn_search_tid = -1
			_tourn_status = {"tid": int(d.tournament_id), "ok": int(d.accepted) != 0,
				"text": I18n.t("tourn.search_wait") if int(d.accepted) != 0
					else I18n.t("tourn.search_refused")}
			_refresh_calendar()
		OP_TOURN_CANCEL_RES:
			# 28610 [i8 accepted] — the search we cancelled is dead (also
			# sent by the server when a search period closes on us)
			_tourn_status = {"tid": _tourn_search_tid, "ok": true, "text": I18n.t("tourn.cancelled")}
			_tourn_search_tid = -1
			_end_tourn_search()
			_log_line(I18n.t("tourn.cancelled"))
			_refresh_calendar()
		OP_TOURN_SEARCH_ERR:
			var d := Codec.decode(opcode, payload)
			_tourn_status = {"tid": _tourn_search_pending, "ok": false, "text": I18n.t("tourn.err")}
			_tourn_search_tid = -1
			_end_tourn_search()
			DebugLog.add("tournament search error %d/%d" % [
				int(d.code), int(d.sub_code)])
			_log_line("[color=red]%s[/color]" % I18n.t("tourn.err"))
			_refresh_calendar()
		OP_TOURN_SEARCH_END:
			# 28648 — the period closed on an unplayed fixture: forfeit=0
			# means we won it by the other side's absence
			var d := Codec.decode(opcode, payload)
			_tourn_search_tid = -1
			_end_tourn_search()
			_search_open.erase(int(d.tournament_id))
			var msg := I18n.t("tourn.forfeit_lost" if int(d.forfeit) != 0
				else "tourn.forfeit_won", {"name": _tourn_name(int(d.tournament_id))})
			_toast(msg)
			_log_line(msg)
			_refresh_calendar()
			_push_tourn_search_model()
		28614:  # TournamentFightStarting [i64 tid] — bracket match launching
			var d := Codec.decode(opcode, payload)
			_tourn_search_tid = -1
			_end_tourn_search()
			_log_line("[color=green]%s[/color]" % I18n.t("tourn.starting",
				{"tid": int(d.tournament_id)}))
		28620:  # TournamentFinale (Yq) — [u8 status]1=add/2=remove; on add:
			# [i64 tid][i32 n][i64 coaches][i32 m][str32 names][str32 tname]
			# (both arrays written reversed — the retail reader Yq.a fills
			# them backwards, names[0] VS names[1] renders correct anyway).
			var st := payload.get_u8()
			var tid := int(payload.get_i64())
			if st == 1:
				var cn := payload.get_i32()
				var ids := []
				for i in cn:
					ids.insert(0, int(payload.get_i64()))   # reversed too
				var nn := payload.get_i32()
				var names := []
				for i in nn:
					# the wire order is reversed — prepend to land at the
					# same indices Yq.a fills (names[0] VS names[1])
					names.insert(0, payload.get_str("u32", "utf8"))
				var tname := payload.get_str("u32", "utf8")
				var line := I18n.t("tourn.finale", {"name": tname,
					"a": names[0] if names.size() > 0 else "?",
					"b": names[1] if names.size() > 1 else "?"})
				_toast(line)
				# retail's alert row asked "watch it?" (zN 28620): spectate the
				# first finalist's fight (2260 → 26331), as /watch does
				if not ids.is_empty() and not State.my_coach_id in ids:
					var who := int(ids[0])
					_ask("tournament", I18n.t("ask.tournament"),
						I18n.t("tourn.finale_watch", {"line": line}),
						func(yes: bool):
							if yes:
								_watch_target = who
								var w := WireWriter.new()
								w.put_i64(who)
								Session.send(OP_SPECTATE_QUERY, w.raw(), 2))
			else:
				pass  # remove — the toast already aged out
		28644:  # TournamentSearchUpcoming [i64 tid][i64 startUnixMs] — zN
			# alert-list row "search opens in N min" (1 + diff/60000).
			var tid2 := int(payload.get_i64())
			var start_ms := int(payload.get_i64())
			var mins := 1 + int((start_ms -
				int(Time.get_unix_time_from_system() * 1000)) / 60000)
			var line := I18n.t("tourn.opens_in", {"name": _tourn_name(tid2),
				"min": max(mins, 0)})
			_toast(line)
			_log_line(line)
		OP_TOURN_OPENING:
			# 28646 [i64 tid][i64 durationMs] — a search period starts now
			var tid3 := int(payload.get_i64())
			var left := int(payload.get_i64())
			_search_open[tid3] = true
			var line := I18n.t("tourn.period_open", {"name": _tourn_name(tid3),
				"min": maxi(1, int(left / 60000))})
			_toast(line)
			_log_line("[color=green]%s[/color]" % line)
			_refresh_calendar()
			_push_tourn_search_model()
		OP_TOURN_UNFINISHED:
			# 28618 [i64 tid] — the next edition of one we could not finish
			var tid4 := int(payload.get_i64())
			_ask("tournament", I18n.t("ask.tournament"),
				I18n.t("tourn.carry_ask", {"name": _tourn_name(tid4)}),
				func(yes: bool):
					if yes:
						var w := WireWriter.new()
						w.put_i64(tid4)
						Session.send(OP_TOURN_CARRY, w.raw(), 2))
		OP_GUILD_RESULT:
			var d := Codec.decode(opcode, payload)
			match int(d.code):
				403: _log_line("[color=green]%s[/color]" % I18n.t("guild.created"))
				404: _log_line("[color=green]%s[/color]" % I18n.t("guild.joined"))
				11: _log_line("[color=red]%s[/color]" % I18n.t("guild.name_taken"))
				20: _log_line("[color=red]%s[/color]" % I18n.t("guild.full"))
				35: _log_line("[color=red]%s[/color]" % I18n.t("guild.not_found"))
				40: _log_line("[color=red]%s[/color]" % I18n.t("guild.refused"))
				_: _log_line(I18n.t("guild.result", {"code": int(d.code)}))
		OP_GUILD_FEED:
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s[/i]" % I18n.t("guild.founded",
				{"coach": d.coach, "guild": d.guild}))
		OP_GUILD_INVITATION:
			# 502 [u8 type][str8 inviter][str8 guild] — ask before answering.
			var d := Codec.decode(opcode, payload)
			_guild_invite = {"type": int(d.type), "inviter": d.inviter,
				"guild": d.guild}
			_ask("guild", I18n.t("ask.guild"), I18n.t("guild.invite_ask",
				{"name": d.inviter, "guild": d.guild}), _answer_guild_invite)
		OP_GUILD_MEMBER_REPORT:
			var d := Codec.decode(opcode, payload)
			var lines := ["%s — %d stat(s):" % [d.name, d.stats.size()]]
			for s in d.stats:
				lines.append("  stat %d (type %d) = %s" % [
					int(s.id), int(s.type), str(s.value)])
			DebugLog.add("\n".join(lines))
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
			# The server announces an achievement only once its criteria
			# meet their thresholds, so they are at least that now. Counters
			# only the server moves (211 recruits, 198-200 the Demon III
			# chain) would otherwise stay stale until the next 2052, and the
			# client-side gates that read them (Demon III's offer) with them.
			var need := NpcDialogs.achievement_stats(aid)
			for sid in need:
				State.criteria[sid] = maxi(int(State.criteria.get(sid, 0)), int(need[sid]))
			if not bool(ainfo.get("hid", false)):
				var pts := int(ainfo.get("pts", 0))
				var aname := NpcDialogs.achievement_name(aid)
				_toast(I18n.t("ach.unlocked_toast", {"name": aname,
					"pts": " (+%d pts)" % pts if pts > 0 else ""}))
				_log_line("[color=yellow]%s[/color]" % I18n.t("ach.unlocked",
					{"name": aname}))
				# the tutorial scenario this achievement opens (S10)
				if Scenarios.ACHIEVEMENT_SCRIPTS.has(aid):
					_queue_scenario(int(Scenarios.ACHIEVEMENT_SCRIPTS[aid]))
		OP_STAT_DATA:
			# 22002 — reply to opening the achievements tab; the pairs also
			# refresh the local criterion map the pane evaluates against.
			var sd := Codec.decode(opcode, payload)
			for r0 in sd.get("rows", []):
				State.criteria[int(r0.get("crit", 0))] = int(r0.get("val", 0))
		OP_STATS_REPORT, OP_STATS_PUSH:
			# 2400/2401 — rs_2 stat map: the coach's lifetime numbers; the
			# "Coach" pane reads State.coach_stats.
			var sm := Codec.decode(opcode, payload)
			for s in sm.get("stats", []):
				State.coach_stats[int(s.id)] = s.value
			# refresh localCoach's statistics* fields for any open stats screen
			if _gui.is_open("coachStatisticsDialog"):
				_push_local_coach()
		510:  # GuildRecord — guild name/demon/rank table for our guild
			var d := Codec.decode(opcode, payload)
			State.guild["guild_id"] = int(d.guild_id)
			State.guild["guild"] = d.name
			State.guild["demon_id"] = int(d.demon_id)
			State.guild["ranks"] = d.ranks
			if _gui.is_open("guildManagementDialog"):
				_push_guild_mgmt_model()
		552:  # GuildMembership — my own rank/demon row (part 2)
			var d := Codec.decode(opcode, payload)
			for row in d.rows:
				State.guild.merge(row, true)
			if not State.guild.is_empty():
				DebugLog.add("guild membership: '%s' — %s (demon %d)" % [
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
			DebugLog.add("guild roster: %s" % ", ".join(names))
			if _gui.is_open("guildDialog") or _gui.is_open("socialDialog"):
				_push_social_model()
		554:  # GuildTags — clan tags for nearby coaches. Fed the world name
			# labels; the lobby keeps only the decode for the wire.
			Codec.decode(opcode, payload)
		556:  # GuildMemberGone — a coach left/was kicked
			var d := Codec.decode(opcode, payload)
			if int(d.coach_id) == State.my_coach_id:
				State.guild = {}
				_log_line("[i]%s[/i]" % I18n.t("guild.left"))
			else:
				_log_line("[i]%s[/i]" % I18n.t("guild.member_left",
					{"id": int(d.coach_id)}))
		560:  # GuildMemberFeed — "X joined / X was thrown out"
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s[/i]" % I18n.t(
				"guild.kicked" if int(d.removed) != 0 else "guild.member_joined",
				{"coach": d.coach}))
		OP_MAIL_LIST:
			var d := Codec.decode(opcode, payload)
			_mails = d.mails
			_mail_loading = false
			if _gui.is_open("mailboxDialog"):
				_push_mail_model()
		OP_MAIL_NAME_RES:
			var d := Codec.decode(opcode, payload)
			var cid := int(d.get("coach_id", 0))
			# -1 = checked and unknown; 0 stays "not checked yet"
			_gui.gui.model.set_value("mailbox.newMail.receiverId",
				cid if cid > 0 else -1)
			if cid <= 0 and not _gui.is_open("mailboxDialog"):
				_toast(I18n.t("chat.user_not_found_toast"))
		OP_MAIL_SEND_RES:
			var d := Codec.decode(opcode, payload)
			var res := int(d.result)
			var msg: String
			if res > 0:
				# (the server pushes the inventory without the attachments, 5200)
				msg = I18n.t("mail.sent", {"id": res, "to": d.mail.get("receiver", "?")})
			elif res == -2:
				msg = I18n.t("mail.refused")
			else:
				msg = I18n.t("mail.err", {"code": res})
			_log_line("[color=%s]%s[/color]" % ["green" if res > 0 else "red", msg])
			if _gui.is_open("mailboxDialog"):
				_mail_status = {"text": I18n.t("mb.sent_ok", {"to": d.mail.get("receiver", "?")})
					if res > 0 else msg, "ok": res > 0}
				if res > 0:
					_mail_mode = "list"
					_mail_loading = true
					Session.send(OP_MAILBOX_REQ, PackedByteArray(), 3)
				_push_mail_model()
		OP_MAIL_NOTICE:
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s[/i]" % I18n.t("mail.new", {"n": int(d.new_count)}))
		OP_MAIL_TAKEN:
			var d := Codec.decode(opcode, payload)
			for cid in d.cards:
				State.inventory[int(cid)] = int(
					State.inventory.get(int(cid), 0)) + 1
			if int(d.coach_id) == State.my_coach_id and not d.cards.is_empty():
				_log_line("[color=green]%s[/color]" % I18n.t("mail.collected",
					{"list": ", ".join(d.cards.map(
						func(c): return Cards.name_of(int(c))))}))
			# Drop the emptied mail from the open mailbox.
			for i in range(_mails.size() - 1, -1, -1):
				if int(_mails[i].get("id", -1)) == int(d.mail_id):
					_mails[i]["cards"] = []
			if _gui.is_open("mailboxDialog"):
				if not d.cards.is_empty():
					_mail_status = {"ok": true, "text": I18n.t("mail.collected",
						{"list": ", ".join(d.cards.map(
							func(c): return Cards.name_of(int(c))))})}
				var open: Variant = _gui.gui.model.get_value("mailbox.mail")
				if open is Dictionary and int(open.get("mailId", 0)) == int(d.mail_id):
					open["cards"] = []
					open["hasItems"] = false
				_push_mail_model()
		OP_EX_INVITATION:
			var d := Codec.decode(opcode, payload)
			_ex = {"id": int(d.ex_id), "my_side": 1,
				"other_name": d.inviter, "accepted": false,
				"staged": {0: {}, 1: {}}, "ready": {0: false, 1: false}}
			_ask("trade", I18n.t("ask.trade"), I18n.t("trade.ask",
				{"name": d.inviter}), _answer_exchange)
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
					_log_line(I18n.t("trade.invited"))
				2:
					_log_line("[color=red]%s[/color]" % I18n.t("trade.refused"))
					_ex = {}
					_gui.close("exchangeDialog")
				3:
					_ex["accepted"] = true
					_log_line("[color=green]%s[/color]" % I18n.t("trade.accepted"))
					_ex_status = ""
					_push_exchange_model()
					_gui.open("exchangeDialog")
		OP_EX_ADDED:
			var d := Codec.decode(opcode, payload)
			var side := int(d.side)
			_ex.staged[side][int(d.card)] = int(d.qty)
			_ex["ready"] = {0: false, 1: false}   # the server un-readies both
			_push_exchange_model()
		OP_EX_REMOVED:
			var d := Codec.decode(opcode, payload)
			_ex.staged[int(d.side)].erase(int(d.card))
			_ex["ready"] = {0: false, 1: false}
			_push_exchange_model()
		OP_EX_USER_READY:
			var d := Codec.decode(opcode, payload)
			_ex.ready[int(d.side)] = true
			_log_line(I18n.t("trade.you_ready") if int(d.side) == _ex.get("my_side", -1)
				else I18n.t("trade.ready", {"name": _ex.get("other_name", "?")}))
			_push_exchange_model()
		OP_EX_ERROR:
			var d := Codec.decode(opcode, payload)
			_ex_status = I18n.t("trade.err_unique" if int(d.code) == 1 else "trade.err_linked")
			_log_line("[color=red]%s[/color]" % _ex_status)
			_push_exchange_model()
		OP_EX_END:
			var d := Codec.decode(opcode, payload)
			_log_line(("[color=green]%s[/color]" % I18n.t("trade.done"))
				if int(d.reason) == 0 else "[i]%s[/i]" % I18n.t("trade.cancelled"))
			_ex = {}
			_gui.close("exchangeDialog")
		OP_FIREWORK_SHOW:
			# S18: no world to play it in — it bursts on the lobby sky, for
			# everyone the server sends it to (the launcher too).
			var d := Codec.decode(opcode, payload)
			_fw_shown += 1
			if is_instance_valid(_lobby_screen):
				var m := Cards.meta(int(d.get("card", 0)))
				var rgb: Array = m.get("fwColour", [255, 255, 255])
				var c := Color8(int(rgb[0]), int(rgb[1]), int(rgb[2])) if rgb.size() >= 3 else Color.WHITE
				_lobby_screen.firework(int(m.get("fwType", 0)), c)
			DebugLog.add("firework! %s" % Cards.name_of(int(d.get("card", 0))))
		OP_FRIEND_LIST:
			var d := Codec.decode(opcode, payload)
			State.friends = d.get("friends", [])
			if not State.friends.is_empty():
				_log_line(I18n.t("chat.friends_list", {"list": ", ".join(
					State.friends.map(func(f): return str(f.name)))}))
		OP_IGNORE_LIST:
			var d := Codec.decode(opcode, payload)
			State.ignored = d.get("names", [])
			if not State.ignored.is_empty():
				_log_line(I18n.t("chat.ignored_list",
					{"list": ", ".join(State.ignored)}))
		OP_FRIEND_ADDED:
			var d := Codec.decode(opcode, payload)
			State.friends.append({"name": d.name,
				"id": int(d.get("id", -1)), "online": true, "notify": 1})
			_log_line("[color=light_green]%s[/color]" % I18n.t("social.added",
				{"name": d.name}))
		OP_FRIEND_REMOVED:
			var d := Codec.decode(opcode, payload)
			State.friends = State.friends.filter(
				func(f): return f.name != d.name)
			_log_line(I18n.t("social.removed", {"name": d.name}))
		OP_IGNORE_ADDED:
			var d := Codec.decode(opcode, payload)
			State.ignored.append(d.name)
			_log_line("[i]%s[/i]" % I18n.t("social.ignored", {"name": d.name}))
		OP_IGNORE_REMOVED:
			var d := Codec.decode(opcode, payload)
			State.ignored.erase(d.name)
			_log_line(I18n.t("social.unignored", {"name": d.name}))
		OP_FRIEND_ONLINE:
			var d := Codec.decode(opcode, payload)
			for f in State.friends:
				if f.name == d.name:
					f.online = true
					f.id = int(d.get("id", -1))
			_log_line("[color=light_green]%s[/color]" % I18n.t("social.online",
				{"name": d.name}))
		OP_FRIEND_OFFLINE:
			var d := Codec.decode(opcode, payload)
			for f in State.friends:
				if f.name == d.name:
					f.online = false
			_log_line("[i]%s[/i]" % I18n.t("social.offline_name",
				{"name": d.name}))
		OP_IGNORE_ONLINE:
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s[/i]" % I18n.t("social.ignored_online",
				{"name": d.name}))
		OP_IGNORE_OFFLINE:
			var d := Codec.decode(opcode, payload)
			_log_line("[i]%s[/i]" % I18n.t("social.ignored_offline",
				{"name": d.name}))
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
			DebugLog.add("fight creation refused, code %d" % int(d.get("f1", -1)))
			_log_line("[color=red]%s[/color]" % I18n.t("fight.refused",
				{"code": int(d.get("f1", -1))}))
		OP_PONG:
			pass  # keepalive reply
		_:
			# Wire noise a player cannot act on — the bug-report log keeps it.
			DebugLog.add("S2C opcode %d — %d bytes" % [opcode, payload.remaining()])


## ActorSpawn inner body: [i32 count]{u8 type=1 coach: i64 id, str8 name,
## i32 x, i32 y, i16 z, u8 dir, u8 skin, u8 hair, u8 sex, i16 look, i32
## standing, u8 sit, i16 guild, i16 desc, u8 strPairs, i32 adminRight}
## (server writeCoachActor — aez_0.b flags 3179 source order)
func _read_coach_spawns(payload: WireReader) -> void:
	var d := Codec.decode(OP_ACTOR_SPAWN, payload)
	var body := WireReader.new(d.get("actors_raw", PackedByteArray()))
	var count := body.get_i32()
	for i in count:
		var atype := body.get_u8()
		if atype != 1:
			DebugLog.add("actor spawn: unknown type %d" % atype)
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
			continue   # our own coach is tracked from the 4600 position
		_coach_names[id] = cname


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed \
			and event.keycode == KEY_ENTER and State.my_coach_id >= 0:
		log.grab_chat_focus()


## Localized search refusal — retail codes (search_handshake.go):
## 1 cannot start (already fighting/queued), 2 bad team, 3 cancelled,
## 4 no opponent. Code 5 is silent.
func _search_error_text(code: int, evo := false) -> String:
	var key := ("evo.err." if evo else "search.err.") + str(code)
	var s := I18n.t(key)
	if s == key:
		s = I18n.t("evo.err.unknown" if evo else "search.err.unknown",
			{"code": code})
	return s


func _on_practice_pressed() -> void:
	# S10: a new coach has no fighters; the server would field an invented
	# one. Point at where to recruit instead.
	if State.roster.is_empty():
		_log_line("[color=red]%s[/color]" % I18n.t("fight.need_fighter"))
		_toast(I18n.t("fight.need_fighter"))
		return
	# TeamTest 26330 doubles as overworld challenge launch:
	# [i32 challengeId][i16 99] — 34 = "Démon de la 58ème minute" practice
	# demon. The server fields the opponent side; one client suffices.
	var w := WireWriter.new()
	w.put_i32(34)
	# 98, not 99: practice even though 34 is Historia's chapter 2 opener —
	# a training bout must never wound or kill a starter (S15)
	w.put_u16(98)
	Session.send(26330, w.raw(), 2)
	DebugLog.add("practice challenge 34 sent")
	_log_line(I18n.t("search.practice"))


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
	DebugLog.add("combattre sent — team %d%s" % [pid,
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
	# Preflight the same rule the server applies (handlers_evolution_search.go):
	# the evolution team is the TITULAR line-up — evolution fighters (type 2)
	# not on the bench (state 1/5). With an empty line-up the server answers
	# search error 2; tell the player what to do instead of a bare refusal.
	var titulars := 0
	for fr in State.roster:
		if int(fr.get("type", 2)) == 2 and int(fr.get("state", 0)) not in [1, 5]:
			titulars += 1
	if titulars == 0:
		DebugLog.add("evolution search blocked: no titular fighters")
		_log_line("[color=red]%s[/color]" % I18n.t("evo.err.need_fighter"))
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
		_log_line(I18n.t("search.accepted",
			{"name": str(_match.get("opp_name", "?"))}))
	else:
		Session.send(OP_QUICK_CANCEL, PackedByteArray(), 2)
	_match = {}


## S13: save the titular line-up as a ghost, with each fighter's rule set
## (GambitEditor.ruleset) keyed by fighter id.
func _ghost_save(ghost_name: String, rules: Dictionary, lineup: Array = []) -> void:
	var w := WireWriter.new()
	w.put_str(ghost_name, "u8", "utf8")
	w.put_u8(rules.size())
	for fid in rules:
		var json := JSON.stringify(rules[fid]).to_utf8_buffer()
		w.put_i64(int(fid))
		w.put_u16(json.size())
		w.put_bytes(json)
	# S22: the line-up itself — the Elite team picked on the Ranking card
	w.put_u8(lineup.size())
	for fid in lineup:
		w.put_i64(int(fid))
	Session.send(OP_GHOST_SAVE, w.raw(), 3)


## --- Spectate (2260/2261/26331) ------------------------------------------------
## /watch <name> queries whether that coach is in a live fight (2260); a 1
## reply auto-joins (26331) — the server replays the resync (4516 + 8000 with
## the spectator deck + actor appear + timeline), which the normal fight
## handlers already decode. 8300 → 26321 ack returns us to the overworld.
func _watch_coach(cname: String) -> void:
	var tid: int = _coach_id_by_name(cname)
	if tid < 0:
		_log_line("[color=red]%s[/color]" % I18n.t("watch.not_found", {"name": cname}))
		return
	_watch_target = tid
	var w := WireWriter.new()
	w.put_i64(tid)
	Session.send(OP_SPECTATE_QUERY, w.raw(), 2)


## Send the current tab's request at _ladder_start (arch 2).
func _ladder_request() -> void:
	var w := WireWriter.new()
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

## My rights mask (from the 552 membership row).
func _my_rights() -> int:
	return int(State.guild.get("rights", 0))


func _has_right(bit: int) -> bool:
	var r := _my_rights()
	return r & GUILD_RIGHT_LEADER != 0 or r & bit != 0


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
		4:
			_tourn_search(_tourn_search_tid)
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
	return _tm_preset_sel   # the Team panel's pick (selectTeamPreset)


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


## After 26302 both coaches confirm a team with 26303 [i64 self][i16 team]
## (S18: the native teamPickDialog, src/ui/team_pick_panel.gd). -1 = the
## titular line-up, which the server accepts on every team-carrying request.
func _open_team_pick() -> void:
	var presets: Array = [{"id": -1, "name": I18n.t("tp.titulars"), "n": -1}]
	for p in State.presets:
		if int(p.type) == -4:
			continue  # synthetic bench row
		presets.append({"id": int(p.id), "name": str(p.name), "n": p.fighters.size()})
	_gui.gui.model.set_value("teamPick", {"presets": presets,
		"evo": _challenge_evo != 0})
	_gui.open("teamPickDialog")


func _confirm_team(team_id: int) -> void:
	_gui.close("teamPickDialog")
	var w := WireWriter.new()
	w.put_i64(State.my_coach_id)
	w.put_i16(team_id)
	Session.send(OP_TEAM_CONFIRM, w.raw(), 2)
	_log_line(I18n.t("team.confirmed", {"id": team_id}))


## Closing the team picker backs out of the challenge (26307).
func _cancel_team_pick() -> void:
	_gui.close("teamPickDialog")
	if _challenge_handle >= 0:
		var w := WireWriter.new()
		w.put_i64(_challenge_handle)
		Session.send(OP_CHALLENGE_DECLINE, w.raw(), 2)
		_challenge_handle = -1


## Loadout editor — lists the fighter's breed-legal spells (from the exported
## gamedata table), checks the current loadout, saves via 6011.
var _loadout_fid := -1

## --- Coach statistics (2401 / 2400) ------------------------------------------
## The 2401 login push carries the coach's lifetime counters as an rs_2 stat
## map (server statistics.go — PlayerStatisticsReport field ids). Sparse: a
## stat the server never tracked simply isn't there and reads as 0.
const COACH_STAT_LABELS := {1: "stats.time_played", 2: "stats.time_fights",
	3: "stats.fights", 4: "stats.wins", 5: "stats.losses",
	7: "stats.win_streak", 8: "stats.loss_streak"}
const COACH_STAT_ORDER := [3, 4, 5, 7, 8, 1, 2]  # fights first, times last

## --- Coach equipment (5201) -------------------------------------------------
## 14 client slots; only the 12 wearable types map to one (server
## coachcard_slots.go — type -> 0-based position). The layout echoes nowhere:
## the client owns the state and re-sends all 14 slots on Wear.
const COACH_SLOT_FOR_TYPE := {2: 5, 3: 2, 4: 1, 5: 4, 6: 10, 7: 3,
	8: 8, 9: 6, 10: 11, 11: 0, 12: 7, 13: 9}
const COACH_SLOT_NAMES := {0: "slot.hat", 1: "slot.tattoo", 2: "slot.hair",
	3: "slot.epaulettes", 4: "slot.bracer", 5: "slot.breeches",
	6: "slot.pants", 7: "slot.staff", 8: "slot.cape", 9: "slot.pet",
	10: "slot.boots", 11: "slot.shirt"}

var _equip_slots: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   # worn (5200)
var _equip_draft: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   # being edited


## The native coach equipment (S18, src/ui/coach_equip_panel.gd), from the
## Inventory panel. 5203 asks for a fresh 5200, whose first section says what
## the coach wears (B-179).
func _open_equip() -> void:
	_equip_draft = _equip_slots.duplicate()
	_push_equip_model()
	_gui.open("coachEquipDialog")
	var w := WireWriter.new()
	w.put_u16(0)
	State.net.send_message(5203, w.raw(), 3)


func _push_equip_model() -> void:
	var slots: Array = []
	for i in 14:
		if not COACH_SLOT_NAMES.has(i):
			continue
		var cid := int(_equip_draft[i])
		slots.append({"slot": i, "label": I18n.t(COACH_SLOT_NAMES[i]),
			"card": cid, "name": Cards.name_of(cid) if cid != 0 else ""})
	# what can be worn: unequipped stacks plus what is worn now, minus the
	# draft's own picks
	var have := {}
	for cid in State.inventory:
		have[int(cid)] = int(State.inventory[cid])
	for cid in _equip_slots:
		if int(cid) != 0:
			have[int(cid)] = int(have.get(int(cid), 0)) + 1
	for cid in _equip_draft:
		if int(cid) != 0:
			have[int(cid)] = int(have.get(int(cid), 0)) - 1
	var owned: Array = []
	for cid in have:
		var t := int(Cards.meta(int(cid)).get("type", -1))
		if COACH_SLOT_FOR_TYPE.has(t) and int(have[cid]) > 0:
			owned.append({"id": int(cid), "name": Cards.name_of(int(cid)),
				"qty": int(have[cid]), "slot": int(COACH_SLOT_FOR_TYPE[t]),
				"slotName": I18n.t(COACH_SLOT_NAMES[int(COACH_SLOT_FOR_TYPE[t])])})
	owned.sort_custom(func(a, b): return a.slot < b.slot or (a.slot == b.slot and a.name < b.name))
	_gui.gui.model.set_value("coachEquip", {"slots": slots, "owned": owned,
		"dirty": _equip_draft != _equip_slots})


## 5201 [14 × i32 card] — the whole layout; the server answers with a 5200.
func _on_equip_wear() -> void:
	var w := WireWriter.new()
	for i in 14:
		w.put_i32(int(_equip_draft[i]))
	Session.send(OP_EQUIP_REQ, w.raw(), 3)
	DebugLog.add("equipment layout sent — %d card(s) worn" %
		(14 - _equip_draft.count(0)))


## 2048 COACH_CREATE_REQ → retail coachCreationDialog (sex/skin/hair/name +
## live paper-doll preview). localCoach is the model the XML binds to.
func _open_coach_creation() -> void:
	if _login_screen != null:
		_login_screen.queue_free()
		_login_screen = null
	_gui.gui.model.set_value("localCoach", {
		"sex": 0, "skin": 1, "hair": 1,
		"name": _login_name.strip_edges().left(20),
		"actorDescriptorLibrary": "coach_7000",
		"actorAnimation": "AnimStatique",
		"actorDirection": 3,
		"actorMaterial": Palettes.coach_tints(1, 1)})
	if not _gui.gui.model.changed.is_connected(_on_localcoach_changed):
		_gui.gui.model.changed.connect(_on_localcoach_changed)
	_create_screen = preload("res://src/ui/creation_screen.gd").new()
	$UI.add_child(_create_screen)
	_create_screen.bind_model(_gui.gui.model)
	_create_screen.dir_pressed.connect(
		func(d): _on_coach_dir([], null, d))
	_create_screen.random_pressed.connect(
		func(): _on_coach_random([], null))
	_create_screen.submit.connect(func(): _on_coach_create([], null))
	_create_screen.closed.connect(func():
		Session.client.disconnect_from())


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
	_gui.gui.model.set_value("localCoach",
		(int(lc.get("actorDirection", 3)) + d) & 7, "actorDirection")


func _on_coach_random(_args: Array, _w) -> void:
	var m = _gui.gui.model
	if not (m.get_value("localCoach") is Dictionary):
		return
	m.set_value("localCoach", randi() % 2, "sex")
	m.set_value("localCoach", randi() % Palettes.SKIN.size(), "skin")
	m.set_value("localCoach", randi() % Palettes.HAIR.size(), "hair")


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
	if _create_screen != null:
		_create_screen.queue_free()
		_create_screen = null
	_gui.close("coachCreationDialog")
	DebugLog.add("coach creation sent — '%s'" % name)


## --- fighter creation (teamManagement.editableFighter) --------------------
## The retail fighterCreationDialog binds a preview paper-doll to the model;
## setFighter* events just rewrite fields. On validate → 6001.
const _FV := preload("res://src/fight/fight_view.gd")


## Whether the create-fighter dialog was opened from the evolution tab —
## retail writes slot=99 + blob type 2 for evolution recruits, slot=teamId +
## blob type 1 for classic preset recruits (hu_2.java:16611).
var _create_fighter_evo := false


func _on_new_fighter_dialog(_args: Array, _w, evo := false, breed := 1) -> void:
	_create_fighter_evo = evo
	_gui.gui.model.set_value("teamManagement", {
		"breedId": breed, "sex": 0, "version": 2 if evo else 1,
		# no colour picker (S07): the breed's own colours
		"skin": Palettes.NO_TINT, "hair": Palettes.NO_TINT, "eye": Palettes.NO_TINT,
		"name": "",
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
	# the version radio also picks which roster the recruit lands in:
	# 2 = evolution (Wakfu-era), 1 = classic (Dofus-era)
	_create_fighter_evo = int(f.get("version", 1)) == 2
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
	DebugLog.add("fighter create sent: %s" % fname)


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
		{"fightersOnBench": bench, "fallen": _fallen_fighters(),
		"reviveCards": _revive_cards(), "reviveStatus": _revive_status,
		"benchFull": bench.size() >= BENCH_CAPACITY})
	_gui.gui.model.set_value("tomeManager",
		_all_card_sets(), "evolutionSets")
	_gui.gui.model.set_value("onlyTabEnabledId", -1)
	_push_team_classic_model()


## --- Fallen fighters (S18: the old graveyard, now part of the Team panel) ---
## Dead (2, still holding a team slot) and retired (3, out of the team)
## fighters, and the owned resurrection cards. 22099 [i64 fighter][i32 card]
## spends the card either way; on success the server moves the fighter
## (2 → titular, 3 → bench) and pushes 6006, on a failed roll it pushes only
## the inventory. The client gets no explicit verdict, so _revive_pending
## settles it from whichever push arrives.
const BENCH_CAPACITY := 7          # domain.BenchCapacity
const _REVIVE_CARD_TYPE := 24      # consumable resurrection cards
var _revive_status := {}           # {text, ok, fid} shown in the Team panel
var _revive_pending := {}          # {fid, name, card, cid, qty, seq} while awaiting
var _revive_seq := 0


func _fallen_fighters() -> Array:
	var out: Array = []
	for fr in State.roster:
		var st := int(fr.get("state", 0))
		if int(fr.get("type", 2)) == 2 and (st == 2 or st == 3):
			out.append(_evo_fighter_item(fr))
	return out


## Only real consumables: equipment cards also carry a resurrect % (a chance
## to come back during a fight) and must not be offered here.
func _revive_cards() -> Array:
	var out: Array = []
	for cid in State.inventory:
		var m := Cards.meta(int(cid))
		if int(m.get("type", 0)) == _REVIVE_CARD_TYPE \
				and int(m.get("resurrect", 0)) > 0 and int(State.inventory[cid]) > 0:
			out.append({"id": int(cid), "name": Cards.name_of(int(cid)),
				"qty": int(State.inventory[cid]),
				"pct": int(m.get("resurrect", 0))})
	out.sort_custom(func(a, b): return a.pct > b.pct or (a.pct == b.pct and a.id < b.id))
	return out


func _revive_fighter(fid: int, cid: int) -> void:
	var f: Variant = _fighter_by_id(fid)
	if f == null or not int(f.get("state", 0)) in [2, 3] \
			or int(State.inventory.get(cid, 0)) <= 0:
		return
	_revive_pending = {"fid": fid, "name": str(f.get("name", "?")),
		"card": Cards.name_of(cid), "cid": cid,
		"qty": int(State.inventory.get(cid, 0))}
	_revive_status = {"text": I18n.t("team.revive_sent",
		{"card": _revive_pending.card, "name": _revive_pending.name}), "ok": true,
		"fid": fid}
	var w := WireWriter.new()
	w.put_i64(fid)
	w.put_i32(cid)
	Session.send(OP_USE_ITEM, w.raw(), 3)
	_push_team_model()
	_revive_seq += 1
	_revive_pending["seq"] = _revive_seq
	var token := _revive_pending
	get_tree().create_timer(2.0).timeout.connect(func():
		if int(_revive_pending.get("seq", -1)) != int(token.seq):
			return
		_revive_pending = {}
		# no 6006: either the roll failed (card gone) or the server refused
		var spent := int(State.inventory.get(int(token.cid), 0)) < int(token.qty)
		_revive_status = {"text": I18n.t("team.revive_fail" if spent
			else "team.revive_refused", {"card": token.card, "name": token.name}),
			"ok": false, "fid": int(token.fid)}
		_push_team_model())


## 6006 after a 22099: the fighter is alive again if it left states 2/3.
func _settle_revive() -> void:
	if _revive_pending.is_empty():
		return
	var f: Variant = _fighter_by_id(int(_revive_pending.fid))
	if f == null or int(f.get("state", 0)) in [2, 3]:
		return
	_revive_status = {"text": I18n.t("team.revive_ok", {"name": _revive_pending.name,
		"where": I18n.t("team.starter" if int(f.get("state", 0)) == 0 else "team.bench")}),
		"ok": true, "fid": int(_revive_pending.fid)}
	_log_line("[color=green]%s[/color]" % _revive_status.text)
	_revive_pending = {}


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
		_log_line("[i]%s[/i]" % I18n.t("duo.pick"))
		return
	var wr := WireWriter.new()
	wr.put_str(tname.strip_edges(), "u8")
	wr.put_i64(State.my_coach_id)
	wr.put_i64(mate_id)
	Session.send(6024, wr.raw(), 2)
	_gui.close("team2vs2NameDialog")
	_log_line(I18n.t("duo.sent"))


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


## evolution:openCloseSphereBoard(fighter) — the Kanodo grid (native panel).
func _on_evo_sphere_board(args: Array, w: GWidget) -> void:
	var row: Variant = args[0] if args.size() > 0 \
		and args[0] is Dictionary else _row_item(w)
	if not (row is Dictionary):
		return
	_open_kanodo(int(row.get("id", row.get("fighterId", 0))))


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
const _EQ_PER_PAGE := 12

var _eq_fid := -1
var _eq_cards := {}          # slot int 0-4 -> card template id
var _eq_spells: Array = []   # spell ids currently equipped
var _eq_save_state := ""     # "" / "saving" / "saved" / "error" (S20: the panel says it)
var _eq_wearable := {}       # fighter id -> card ids it may wear (60023, S22)
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
	_eq_save_state = ""
	# ask what this fighter may wear: its spheres' cards (Historia) or all
	# (Elite) — the rule the server applies on save (S22)
	var req := WireWriter.new()
	req.put_i64(_eq_fid)
	Session.send(OP_FIGHTER_EQUIP_REQUEST, req.raw(), 2)
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
	return {"id": sid, "name": Spells.name_of(sid),   # UI language (S22: was the English export)
		"iconUrl": str(sid), "illustrationUrl": str(sid),
		"actionPoints": int(m.get("ap", 0)),
		"range": "%d-%d" % [int(m.get("min", 0)), int(m.get("max", 0))],
		"aoe": "", "aoeSize": 0, "cooldown": 0, "target": "",
		"description": "", "backgroundDescription": "",
		"value": int(m.get("value", 0)), "cardType": "spell"}


## Equipment slot item — the slot dndc binds itemIconUrl on top of the
## shared card fields.
func _equip_slot_item(cid: int, owned_only := true) -> Variant:
	if cid <= 0 or (owned_only and int(State.inventory.get(cid, 0)) <= 0):
		return null
	var it := _card_item(cid)
	it["itemIconUrl"] = str(cid)
	# a fighter card, not the coach card that shares its id (S22)
	it["name"] = FighterCards.label(cid)
	it["value"] = FighterCards.value_of(cid)
	it["fighter"] = true
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
	var dirty := _eq_is_dirty(f)
	if dirty and _eq_save_state != "saving":
		_eq_save_state = ""   # an edit after a save (or an error) starts over
	ef["dirty"] = dirty
	ef["saveState"] = _eq_save_state
	for s in _EQ_FIELDS.size():
		# what it wears is a fighter card, not an inventory one (S22)
		ef[_EQ_FIELDS[s]] = _equip_slot_item(int(_eq_cards.get(s, 0)), false)
	model.set_value("teamManagement", ef, "editableFighter")
	model.set_value("teamManagement", _eq_type,
		"selectedItemCardListType")
	# An Elite fighter may wear EVERY card of the slot's type (retail aca_0,
	# server entitledEquip): only the 6000 budget limits it. Offering just
	# the owned ones made the collection decide Elite teams (S22, no p2w).
	# A Historia fighter keeps its own cards (the server keeps what its
	# spheres unlocked).
	# The server's list (60023) when it has come; until then, every card for
	# an Elite fighter and none for a Historia one (its spheres decide).
	var elite := int(f.get("type", 2)) == 1
	var wearable: Array = _eq_wearable.get(_eq_fid, FighterCards.all_ids() if elite else [])
	var pool: Array = []
	for cid in wearable:
		if FighterCards.slot_type(int(cid)) == _eq_type + 1:
			var it: Variant = _equip_slot_item(int(cid), false)
			if it != null:
				pool.append(it)
	pool.sort_custom(func(a, b): return int(a.get("value", 0)) < int(b.get("value", 0)))
	var max_page := maxi(0, (pool.size() - 1) / _EQ_PER_PAGE)
	_eq_page = clampi(_eq_page, 0, max_page)
	model.set_value("teamManagement",
		pool.slice(_eq_page * _EQ_PER_PAGE,
			(_eq_page + 1) * _EQ_PER_PAGE), "selectedItemCardList")


## The draft differs from what the server last confirmed for this fighter.
func _eq_is_dirty(f: Dictionary) -> bool:
	var stored_spells: Array = []
	for sid in f.get("spells", []):
		stored_spells.append(int(sid))
	if stored_spells != _eq_spells.map(func(x): return int(x)):
		return true
	var stored := {}
	for c in f.get("cards", []):
		if int(c.get("id", 0)) != 0:
			stored[int(c.get("slot", 0))] = int(c.get("id", 0))
	var draft := {}
	for slot in _eq_cards:
		if int(_eq_cards[slot]) != 0:
			draft[int(slot)] = int(_eq_cards[slot])
	return stored != draft


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
	var t := FighterCards.slot_type(cid)   # the fighter slot, not the coach one (S22)
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
	if FighterCards.slot_type(cid) != slot + 1:
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
	_eq_save_state = "saving"
	_push_fequip_model()
	DebugLog.add("loadout saved: %d spells, %d items" % [
		_eq_spells.size(), _eq_cards.size()])
	_gui.gui.model.set_value("coachManagement", {"currentSet": ""})
	_gui.gui.model.set_value("tomeManager", false)


## --- lobby dialogs: model pushes on open + dofusarena.social:* ---------------

## Called by GuiLayer for every XULOR2 dialog that mounts — feed each
## screen's model from State before its first draw.
func _on_gui_dialog_opened(name: String) -> void:
	match name:
		"cityDialog":
			_push_city_model()
		"socialDialog":
			# the Clan tab lives here too: without this the member list stayed
			# empty (only the old debug pane asked for 512)
			_push_social_model()
			_request_guild_refresh()
		"guildDialog":
			_push_social_model()
			_request_guild_refresh()
		"guildManagementDialog":
			_push_guild_mgmt_model()
		"coachStatisticsDialog":
			_push_local_coach()
		"teamManagementDialog", "evolutionDialog":
			_push_team_model()
			# the Tournaments / Legends tabs list the editions we are in
			Session.send(OP_TOURN_LIST, PackedByteArray(), 2)
		"fighterEquipmentDialog":
			_push_fequip_model()
		"ladderInformationDialog":
			_request_all_ladders()
			_push_ladder_model()
		"cardBookDialog":
			_push_cardbook_model()
		"calendarDialog":
			# always: editions finish and repeat while the client is up
			Session.send(OP_TOURN_CAL, PackedByteArray(), 3)
			# 28601: registration state + the search-period pushes (28630)
			Session.send(OP_TOURN_LIST, PackedByteArray(), 2)
			_tourn_status = {}
			_tourn_bracket = {}
			_push_calendar_model()
		"achievementDialog":
			_ach_sel = {"type": -1, "sub": -1}
			_push_achievement_model()
		"optionsDialog":
			_push_options_model()
		"fusionLabDialog":
			if not _gui.native_factories.has("fusionLabDialog"):
				_push_cardbook_model()   # the XML include's inventory tab needs it
			_push_fusion_model()
		"mailboxDialog":
			if _mails.is_empty() and not _mail_loading:
				_mail_loading = true
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
			"id": int(fr.get("id", -1)),
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
	var demon := int(State.guild.get("demon_id", 0))
	model.set_value("guild", {
		"name": str(State.guild.get("guild", "")),
		"members": gm,
		"canManage": _has_right(GUILD_RIGHT_LEADER)
			if not State.guild.is_empty() else false,
		"guildInfos": "",
		# S18: the demon totem's job, in the clan tab
		"demon": demon,
		"demonName": _demon_name(demon) if demon > 0 else "",
		"canOffer": not State.guild.is_empty() \
			and int(State.guild.get("rank_level", 0)) == 1})
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
			"demonName": _demon_name(int(r.get("demon", 0))),
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
	var root: Control = _gui.dialogs.get("ladderInformationDialog")
	if root is NativeLobbyPanel:
		return root.tab
	if root is GWidget:
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


## useSpecialCard (retail aBC). Card 214 "Pacte" (type 21) opens clan
## creation, as in retail. Zaap cards (20) do nothing: the game has a lobby,
## not worlds to travel (owner, S05). Types 28 (title, 22093) and 30 (Dofus,
## 22097) are not wired yet.
func _on_use_special_card(_a: Array, w: GWidget) -> void:
	var card = w.item_value if w != null else null
	if not (card is Dictionary):
		card = _gui.gui.model.values.get(
			"coachManagement", {}).get("selectedCard")
	if not (card is Dictionary):
		return
	var cid := int(card.get("id", -1))
	if int(card.get("cardType", card.get("type", 0))) == 21 and cid == 214:
		_gui.open("guildCreationDialog")


func _step_set(args: Array, delta: int) -> void:
	if args.is_empty() or not (args[0] is GWidget):
		return
	var n: int = args[0].content_items.size()
	if n == 0:
		return
	args[0].selected_index = wrapi(
		args[0].selected_index + delta, 0, n)
	args[0].queue_redraw()


## changeInstance(card) — retail's double-click-a-zaap teleport. The game
## has a lobby, not worlds to travel (owner, S05): it only closes the dialog.
func _on_zaap_change_instance(_args: Array, _w: GWidget) -> void:
	_gui.close("zaapDialog")


## The islands whose services the lobby's City panel offers. The hall's
## worlds are gone (owner, S05: a lobby with PvE/PvP leagues, not worlds), so
## the panel lists them all at once and the server resolves each 201 in any
## world. 35/79/80/85 were discarded; the clan islands (86-109) only hold
## their clan's altar.
const LOBBY_WORLDS := [23, 24, 25, 26, 27, 28, 37]

## Env kinds whose instances all behave the same: one button for the kind.
## Zaaps (4) and zone triggers (8, walk-on) get none; the graveyard (10) is
## the Team panel's fallen section, the tournament totem (13) the Calendar and
## the demon totem (11) the clan tab + the Ranking's demon tab (S18).
const _CITY_ONE_PER_KIND := [2, 12]
const _CITY_HIDDEN := [4, 8, 10, 11, 13]
## Display order of the kinds in the City panel: shops and mail first.
const _CITY_ORDER := [1, 2, 14, 12, 3, 7, 6, 9, 5, 15, 11, 13]
## S10: the tutorial island's people, brought to the lobby (no worlds, S05):
## world 35's twelve class masters (kind 5) and the Demon III (kind 6), and
## Baan from world 85 (element 143). One "Aprendizaje" group, listed first.
const LEARNING_WORLD := 35
const LEARNING_KINDS := [5, 6]
const BAAN := {"world": 85, "id": 143}
const CITY_LEARNING := 100   # the group's pseudo-kind
const CITY_CHALLENGES := 101   # S22: challenges, demon challenges and Demon I together
const CITY_CHALLENGE_KINDS := [3, 6, 7, 9]


## Env record of an element from the coach's world or any lobby island.
func _env_element(id: int) -> Variant:
	var t: Variant = Elements.for_world(State.current_world).get(id)
	if t != null:
		return t
	for w in LOBBY_WORLDS + [LEARNING_WORLD, int(BAAN.world)]:
		t = Elements.for_world(w).get(id)
		if t != null:
			return t
	return null


## One button label per service: whatever names the element (an NPC or demon
## name, a Card Master's card set, an altar's tier), else the kind.
func _city_label(kind: int, e: Dictionary) -> String:
	var base := I18n.t("elem.%d" % kind)
	if base == "elem.%d" % kind:
		base = Elements.kind_name(kind)
	var f := str(e.get("desc", "")).split(";")
	match kind:
		1:   # "mode;cardListId[;nameId]" — the list id is a card set
			if f.size() > 2:
				var cm := NpcDialogs.npc_name(int(f[2]))
				if cm != "":
					return cm
			if f.size() > 1:
				var set_name := _set_name_for(int(f[1]))
				if set_name != "":
					return "%s · %s" % [base, set_name]
				# Lists 17 and 18 are no card set: both sell the server's priced
				# stock, the only cards tokens buy. One label merges them (S05).
				return I18n.t("city.token_shop")
		3, 5, 6, 7, 9, 15:   # first field is the speaker's name id
			var n := NpcDialogs.npc_name(int(f[0])) if f.size() > 0 else ""
			if n != "":
				return n
		11:   # demon id — named as everywhere else ("Demonio XVI")
			return _demon_name(int(f[0]))
		14:   # the altar's type-1100 lab: input slots and power
			var lab := Cards.lab(int(f[0]))
			if not lab.is_empty():
				return I18n.t("city.altar", {"n": int(lab.get("slots", 3)) - 1,
					"power": int(lab.get("power", 0))})
	return base


## Model for the native City panel (lobby_panels _city): the services of every
## lobby island from the client's own env table, merged — one button per
## distinct service (same kind and same label = same service).
func _push_city_model() -> void:
	var by_kind := {}
	var seen := {}
	for w in LOBBY_WORLDS:
		var table := Elements.for_world(w)
		var ids := table.keys()
		ids.sort()
		for id in ids:
			var e: Dictionary = table[id]
			var kind := int(e.type)
			if kind in _CITY_HIDDEN:
				continue
			if kind in _CITY_ONE_PER_KIND and by_kind.has(kind):
				continue
			var label := _city_label(kind, e)
			if seen.has("%d|%s" % [kind, label]):
				continue
			seen["%d|%s" % [kind, label]] = true
			if not by_kind.has(kind):
				by_kind[kind] = []
			by_kind[kind].append({"id": int(id), "label": label, "kind": kind})
	var groups: Array = []
	var learning: Array = []
	var lt := Elements.for_world(LEARNING_WORLD)
	var lids := lt.keys()
	lids.sort()
	for id in lids:
		var e: Dictionary = lt[id]
		if int(e.type) in LEARNING_KINDS:
			var row := {"id": int(id), "label": _city_label(int(e.type), e), "kind": int(e.type)}
			# S22: a face on each tile — the class master's class portrait,
			# the Demon III's challenge art
			var f := _desc_fields(str(e.get("desc", "")))
			if int(e.type) == 5 and f.size() > 3 and f[3] >= 1 and f[3] <= 12:
				row["portrait"] = "gui/images/breeds/fightTimeline/%d.png" % (int(f[3]) * 10)
			elif int(e.type) == 6:
				row["portrait"] = "gui/images/challenges/illustrations/29.png"
			learning.append(row)
	var baan: Variant = Elements.for_world(int(BAAN.world)).get(int(BAAN.id))
	if baan != null:
		learning.insert(0, {"id": int(BAAN.id), "label": _city_label(int(baan.type), baan),
			"kind": int(baan.type)})
	if not learning.is_empty():
		groups.append({"kind": CITY_LEARNING, "services": learning,
			"name": I18n.t("elem.learning"), "desc": I18n.t("city.desc.learning")})
	# S22: one "Retos" group for every challenge giver (they were three)
	var challenges: Array = []
	for kind in _CITY_ORDER:
		if not by_kind.has(kind):
			continue
		if kind in CITY_CHALLENGE_KINDS:
			challenges.append_array(by_kind[kind])
			continue
		var n := I18n.t("elem.%d" % kind)
		groups.append({"kind": kind, "services": by_kind[kind],
			"name": Elements.kind_name(kind) if n == "elem.%d" % kind else n,
			"desc": I18n.t("city.desc.%d" % kind) if I18n.has("city.desc.%d" % kind) else ""})
	if not challenges.is_empty():
		groups.append({"kind": CITY_CHALLENGES, "services": challenges,
			"name": I18n.t("elem.3"), "desc": I18n.t("city.desc.challenges")})
	_gui.gui.model.set_value("city", {"groups": groups})


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
		# The retail set name (content.25) when exported, else the shared
		# prefix of its cards' names.
		var real := Cards.card_set_name(sid)
		if real != "":
			_set_name_cache[sid] = real
			return real
		var cards: Array = []
		for cid in Cards.all_ids():
			if int(Cards.meta(int(cid)).get("set", 0)) == sid:
				cards.append(int(cid))
		_set_name_cache[sid] = _set_name(cards)
	return _set_name_cache[sid]


func _push_cardbook_model() -> void:
	var equip: Array = []
	var special: Array = []
	var all_cards: Array = []
	var owned := State.inventory.keys()
	owned.sort()
	for cid in owned:
		var t := int(Cards.meta(int(cid)).get("type", 0))
		var it := _card_item(int(cid))
		all_cards.append(it)
		match t:
			# 20 zaap teleports have no walkable world here — they fold into
			# the special-cards tab as collectibles
			20, 21, 22, 23:
				special.append(it)
			_:
				if t >= 1 and t <= 19 \
						and _equip_filter.get(t, true):
					equip.append(it)
	var model := _gui.gui.model
	_sync_equip_filter_model()
	# the inventory tabs all bind localCoach.<field>
	model.set_value("localCoach", equip, "filtredEquipmentCardInventory")
	model.set_value("localCoach", [], "zaapInventory")
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
		"zaapSets": []})


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
			if not _tourn_on_day(e, year, month, day_i):
				continue
			var tid := int(e.get("tid", -1))
			var row: Dictionary = _tourn_rows.get(tid, {})
			if row.is_empty():
				continue   # a finished edition: the list no longer carries it
			if not Features.LEGENDS and TournamentDefs.kind(_tourn_def(tid)) == TournamentDefs.LEGENDARY:
				continue   # Leyendas removed (owner, 2026-10-24)
			evs.append(_tourn_event_model(e, row))
		cells.append({"day": str(day_i), "events": evs,
			"hasMoreEventsToShow": evs.size() > 3, "style": ""})
	model.set_value("calendar", {
		"currentMonth": "%s %d" % [MONTH_NAMES[month - 1].capitalize(), year],
		"calendar": cells,
		"fullEventList": {"events": [], "style": ""},
		"eventFilter": {"showAllEvent": true,
			"tournamentEventFilter": true,
			"maintenanceEventFilter": true,
			"broadcastEventFilter": true},
		"bracket": _tourn_bracket, "status": _tourn_status,
		# the player tournament form needs the "Création de Tournoi" card
		"creationCards": int(State.inventory.get(807, 0)),
		"year": year, "month": month})
	model.set_value("itemOver", {})
	model.set_value("itemSelected", {})


## A tournament sits on the days its search periods start (S09: one per
## round); a calendar entry without periods falls back to its expiry day.
func _tourn_on_day(e: Dictionary, year: int, month: int, day: int) -> bool:
	var stamps: Array = []
	for ph in e.get("phases", []):
		stamps.append(int(ph[0]))
	if stamps.is_empty():
		stamps.append(int(e.get("runs_until", 0)))
	for ms in stamps:
		var d := Time.get_datetime_dict_from_unix_time(_local_s(int(ms) / 1000))
		if int(d.year) == year and int(d.month) == month and int(d.day) == day:
			return true
	return false


## Unix seconds shifted to local wall time, for get_datetime_dict_from_unix_time
## (which reads its argument as UTC).
func _local_s(unix_s: int) -> int:
	return unix_s + int(Time.get_time_zone_from_system().bias) * 60


func _local_hm(ms: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(_local_s(ms / 1000))
	return "%02d/%02d %02d:%02d" % [int(d.day), int(d.month), int(d.hour), int(d.minute)]


## One tournament for the Calendar's day detail (S09): what retail's
## calendarTournamentDetailsDialog showed — kind, schedule, entry, prize.
func _tourn_event_model(e: Dictionary, row: Dictionary) -> Dictionary:
	var tid := int(e.get("tid", -1))
	var def := int(row.get("def_id", 1))
	var periods: Array = []
	for ph in e.get("phases", []):
		var end_d := Time.get_datetime_dict_from_unix_time(_local_s(int(ph[1]) / 1000))
		periods.append("%s–%02d:%02d" % [_local_hm(int(ph[0])), int(end_d.hour), int(end_d.minute)])
	var reg: Array = e.get("registration", [])
	var entry := TournamentDefs.entry_card(def)
	var reward := TournamentDefs.reward_card(def)
	return {"title": str(e.get("name", "")),
		"typeIcon": "",
		"description": str(e.get("desc", "")),
		"registrationButton": true,
		"style": "", "id": tid,
		# native Calendar (S18): what the tournament totem did
		"registered": _registered_tids.has(tid),
		"regOpen": int(row.get("reg_open", 1)) != 0,
		"searchOpen": bool(_search_open.get(tid, false)),
		"searching": _tourn_search_tid == tid,
		# details (S09)
		"kind": TournamentDefs.kind(def),
		"rules": TournamentDefs.rules(def),
		"periods": periods,
		"regUntil": _local_hm(int(reg[0][1])) if not reg.is_empty() else "",
		"organizer": str(row.get("organizer", "")),
		"entryCard": entry,
		"entryName": Cards.name_of(entry) if entry != 0 else "",
		"entryOwned": int(State.inventory.get(entry, 0)) if entry != 0 else 0,
		"rewardName": Cards.name_of(reward) if reward != 0 else ""}


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
	# a ticketed definition costs one of its card (aug.registerTournament):
	# the panel asked first, the server takes it
	wr.put_i32(TournamentDefs.entry_card(_tourn_def(tid)))
	Session.send(OP_TOURN_REGISTER, wr.raw(), 2)


## --- Tournaments in the Calendar (S18: the tournament totem's job) -----------
## Register (4607, above), the bracket (28649 → 28650) and the opponent search
## (28611, cancelled with 28609) — the retail totem's actions, on the
## Calendar's event detail. Results land in calendar.status for that event.
var _tourn_rows := {}            # tid -> 28602 row (reg_open, status…)
var _tourn_bracket := {}         # {tid, rows:[{slot, name}]}
var _tourn_status := {}          # {tid, text, ok}
var _tourn_tree_tid := -1        # the tournament the last 28649 asked about
var _tourn_search_pending := -1  # the tournament the last 28611 was for


func _refresh_calendar() -> void:
	if _gui.is_open("calendarDialog"):
		_push_calendar_model()


## 28649 [i64 tid][i32 page][str32 name] — only an entrant gets the seats.
func _tourn_tree(tid: int) -> void:
	_tourn_tree_tid = tid
	var w := WireWriter.new()
	w.put_i64(tid)
	w.put_i32(0)
	w.put_str(State.my_coach_name, "i32")
	Session.send(OP_TOURN_TREE_REQ, w.raw(), 2)


## Opponent search → 28611 [i64 tid][i64 coach][i16 preset], arch 2, with
## the preset the definition's team kind sends (TournamentDefs: the picked
## team for classic, 99 / 10000 / 9999 otherwise); the same call cancels a
## live one with 28609.
func _tourn_search(tid: int) -> void:
	if tid < 0:
		return
	var w := WireWriter.new()
	w.put_i64(tid)
	w.put_i64(State.my_coach_id)
	w.put_i16(TournamentDefs.search_preset(_tourn_def(tid), _selected_preset_id()))
	_tourn_search_pending = tid
	if _tourn_search_tid == tid:
		Session.send(OP_TOURN_CANCEL, w.raw(), 2)
	else:
		Session.send(OP_TOURN_SEARCH_START, w.raw(), 2)


## The lobby's search bar goes down with a tournament search (28610, 28614,
## 28616, 28648).
func _end_tourn_search() -> void:
	if _search_kind == 4:
		_searching = false
		_search_kind = 0
		_set_searching(false)
	_push_tourn_search_model()


func _tourn_def(tid: int) -> int:
	return int(_tourn_rows.get(tid, {}).get("def_id", 1))


## The tournament's name, from the 28602 list (the 28618 / 28646 ids are
## always ones it carries), else its number.
func _tourn_name(tid: int) -> String:
	var row: Dictionary = _tourn_rows.get(tid, {})
	return str(row.get("name", "#%d" % tid))


## tournamentSearch model, for the Team panel's Tournaments and Legends tabs:
## the editions this coach is entered in, which tab each is searched from,
## and whether its search period is open now. Retail selected the tournament
## by clicking its alert row (agz_1); here the tab lists them.
func _push_tourn_search_model() -> void:
	if _gui == null:
		return
	var rows: Array = []
	for tid in _tourn_rows:
		if not _registered_tids.has(tid):
			continue
		var def := _tourn_def(tid)
		if not Features.LEGENDS and TournamentDefs.kind(def) == TournamentDefs.LEGENDARY:
			continue
		rows.append({"id": tid, "name": _tourn_name(tid),
			"tab": TournamentDefs.team_tab(def),
			"kind": TournamentDefs.kind(def),
			"open": bool(_search_open.get(tid, false)),
			"searching": _tourn_search_tid == tid})
	_gui.gui.model.set_value("tournamentSearch", {"rows": rows,
		"searching": _tourn_search_tid})
	_push_hub_model()


## The player tournament form (17010 aFu, S09): one or more daily search
## periods from the picked day and hour. The "Création de Tournoi" card is
## spent by the server; without it the server answers 25000 code 66.
func _tourn_create(f: Dictionary) -> void:
	var start := int(Time.get_unix_time_from_datetime_dict({
		"year": int(f.year), "month": int(f.month), "day": int(f.day),
		"hour": int(f.hour), "minute": 0, "second": 0}))
	# the form's time is local; unix_time_from_datetime_dict reads it as UTC
	start -= int(Time.get_time_zone_from_system().bias) * 60
	var length := int(f.minutes) * 60
	var w := WireWriter.new()
	w.put_i32(0)
	w.put_i16(0)                  # no custom fight rules
	var now_ms := int(Time.get_unix_time_from_system() * 1000)
	w.put_i64(now_ms)             # registration start
	w.put_i64(start * 1000)       # registration end
	var periods := clampi(int(f.periods), 1, 4)
	w.put_i64((start + (periods - 1) * 86400 + length) * 1000)  # event end
	w.put_u8(periods * 2)
	for i in periods:
		var s0 := start + i * 86400
		w.put_i64(s0 * 1000)
		w.put_i64((s0 + length) * 1000)
	w.put_str(str(f.name), "u8", "utf8")
	w.put_str(str(f.desc), "u16", "utf8")
	w.put_u8(1)                   # definition 1, classic 1v1 (the dialog's default)
	w.put_i64(0)                  # no repetition period
	w.put_i32(0)
	w.put_u8(0)                   # no pro leagues
	Session.send(OP_TOURN_CREATE, w.raw(), 3)
	_tourn_status = {"tid": -1, "ok": true, "text": I18n.t("tourn.created")}
	_log_line(I18n.t("tourn.created"))
	# the new row arrives with the next list
	Session.send(OP_TOURN_CAL, PackedByteArray(), 3)
	Session.send(OP_TOURN_LIST, PackedByteArray(), 2)


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
		# retail's icon (aea_1): min(points / 5, 5), the dimmed negative while
		# not done; under 5 points it would be 0, which has no file (S22)
		var grade := clampi(int(info.get("pts", 0)) / 5, 1, 5)
		items.append({"id": aid,
			"name": NpcDialogs.achievement_name(aid),
			"points": int(info.get("pts", 0)),
			"grade": int(info.get("cat", 0)),
			"iconUrl": "gui/images/achievement/icons/%d.png" % (grade if done else -grade),
			"keyIconUrl": "gui/images/achievement/key/%d.png" % grade,
			"done": done,
			# what it asks, done or not (it was only filled once done)
			"desc": _achievement_asks(aid, info),
			"completion": 100 if done else
				NpcDialogs.achievement_progress(
					aid, State.criteria, State.inventory),
			"descriptionDone": NpcDialogs.achievement_desc(aid)
				if done else "",
			"isSelected": false,
			"style": "done" if done else "", "subtypes": []})
	return items


## The data's description, or — when it has none — its conditions: each
## statistic with its target, each card it wants.
func _achievement_asks(aid: int, info: Dictionary) -> String:
	var d := NpcDialogs.achievement_desc(aid)
	if d.strip_edges() != "":
		return d
	var parts: Array = []
	for c in info.get("conds", []):
		if str(c.kind) == "card":
			parts.append(I18n.t("ach.needs_card", {"card": Cards.name_of(int(c.id))}))
		else:
			parts.append("%s: %d" % [NpcDialogs.criterion_name(int(c.id)), int(c.thr)])
	return "\n".join(parts)


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

## The native panel lists its own resolutions (lobby_panels
## _supported_resolutions); this only seeds the current one.
func _push_options_model() -> void:
	var model := _gui.gui.model
	var gp: Dictionary = model.values.get("gamePreferences", {})
	if str(gp.get("screenResolution", "")) == "":
		var ws := get_window().size
		gp["screenResolution"] = "%dx%d" % [ws.x, ws.y]
	model.set_value("gamePreferences", gp)


func _apply_audio_prefs() -> void:
	Audio.apply_prefs(_gui.gui.model.values.get("gamePreferences", {}))


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
	# the Options panel already asked (confirm_action, coach.destroy_confirm)
	Session.send(OP_DESTROY_COACH, PackedByteArray(), 2)


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


## inviteToGuild(name) — retail's uk_1 event 21054 becomes a 501 by NAME
## (qu_2 → uq_2): [u8 type 0][u8 mode 0][str8 name][i64 guildId], arch 8.
## The UI event ids 21050-21054 are not wire opcodes (B-180).
func _on_guild_invite_by_name(args: Array, _w: GWidget) -> void:
	var name := _social_arg_text(args[0]) if not args.is_empty() else ""
	var gid := int(State.guild.get("guild_id", 0))
	if name.is_empty() or gid <= 0:
		return
	var w := WireWriter.new()
	w.put_u8(0)
	w.put_u8(0)
	w.put_str(name, "u8")
	w.put_i64(gid)
	Session.send(OP_GUILD_INVITE, w.raw(), 8)


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
		_toast(I18n.t("guild.name_short"))
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
		var mine_out := int(m.get("sender_id", 0)) == State.my_coach_id
		var mine_in := int(m.get("receiver_id", 0)) == State.my_coach_id
		if mine_out:
			sent.append(_mail_row(m))
		if mine_in or not mine_out:
			recv.append(_mail_row(m))
	model.set_value("mailManager",
		{"receivedMails": recv, "sentMails": sent})
	if not (model.get_value("mailbox.mail") is Dictionary):
		model.set_value("mailbox.mail", {})
	# Native panel (S18): mode, status and the cards that can be attached.
	var draft: Variant = model.get_value("mailbox.newMail")
	var attached := {}
	if draft is Dictionary:
		for c in draft.get("cards", []):
			var cid := int(c.get("id", 0)) if c is Dictionary else int(c)
			attached[cid] = int(attached.get(cid, 0)) + 1
	var offer: Array = []
	for cid in State.inventory:
		var n := int(State.inventory[cid])
		if n > 0 and bool(Cards.meta(int(cid)).get("tradable", false)):
			offer.append({"id": int(cid), "name": Cards.name_of(int(cid)),
				"owned": n, "staged": int(attached.get(int(cid), 0))})
	offer.sort_custom(func(a, b): return a.name < b.name)
	model.set_value("mailbox.native", {"mode": _mail_mode,
		"loading": _mail_loading, "offer": offer,
		"status": str(_mail_status.get("text", "")),
		"statusOk": bool(_mail_status.get("ok", false))})


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
	_mail_delete(int(row.get("mailId", 0)))


func _mail_delete(mid: int) -> void:
	if mid <= 0:
		return
	var open: Variant = _gui.gui.model.get_value("mailbox.mail")
	if open is Dictionary and int(open.get("mailId", 0)) == mid:
		_gui.gui.model.set_value("mailbox.mail", {})
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


## Native mailbox (S18): open a letter by id, marking it read.
func _mail_open(mid: int) -> void:
	for m in _mails:
		if int(m.get("id", 0)) == mid:
			m["read"] = true
			_gui.gui.model.set_value("mailbox.mail", _mail_row(m))
			_mail_status = {}
			_push_mail_model()
			return


func _mail_compose(to: String) -> void:
	_gui.gui.model.set_value("mailbox.newMail", {
		"receiver": to, "receiverId": 0, "title": "",
		"message": "", "cards": []})
	_mail_mode = "compose"
	_mail_status = {}
	_push_mail_model()


func _mail_attach(cid: int) -> void:
	var nm: Variant = _gui.gui.model.get_value("mailbox.newMail")
	if not (nm is Dictionary):
		return
	var cards: Array = nm.get("cards", [])
	var have := cards.filter(func(c): return int(c.get("id", 0)) == cid).size()
	if cards.size() >= 10 or have >= int(State.inventory.get(cid, 0)):
		return
	cards.append({"id": cid, "name": Cards.name_of(cid)})
	nm["cards"] = cards
	_push_mail_model()


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
		if _gui.is_open("mailboxDialog"):
			_mail_status = {"text": I18n.t("mail.no_recipient"), "ok": false}
			_push_mail_model()
		else:
			_toast(I18n.t("mail.no_recipient"))
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
	w.put_i64(maxi(0, int(nm.get("receiverId", 0))))   # the server resolves the name
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
## Keep the way the player turned the coach in the lobby (« »): rebuilding
## the model used to put it back to 3 (S20).
func _local_coach_dir() -> int:
	if _gui != null:
		var cur: Variant = _gui.gui.model.get_value("localCoach")
		if cur is Dictionary and cur.has("actorDirection"):
			return int(cur.actorDirection) & 7
	return 3


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
		"actorDirection": _local_coach_dir(),
		"actorMaterial": Palettes.coach_tints(
			int(look.get("skin", 0)), int(look.get("hair", 0))),
		"standing": State.coach_standing,
		"standingForProgressBar": _standing_bar(),
		"standingNeededForNextLevel": State.standing_for_level(
			State.coach_level(State.coach_standing) + 1),
		"strenght": 0,
		"strengthForProgressBar": 0,
		"strengthNeededForNextLevel": 0,
		"tournamentToken": State.coach_tournament_points,
		"level": State.coach_level(State.coach_standing),
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


## The retail's standingForProgressBar (sj_1): the share of the current
## level still to go, 100 → 0 — its bar fills from the right.
func _standing_bar() -> int:
	var lvl := State.coach_level(State.coach_standing)
	var lo := State.standing_for_level(lvl)
	var hi := State.standing_for_level(lvl + 1)
	if hi <= lo:
		return 0
	return 100 - roundi(float(State.coach_standing - lo) / float(hi - lo) * 100.0)


## menuBarDialog binds (equipedEmotes + name today; more land as screens port).
func _mount_lobby_menubar(d: Dictionary) -> void:
	State.my_coach_name = str(d.get("name", State.my_coach_name))
	Audio.play_music("island")
	$UI/Chat.visible = true
	_push_local_coach()
	_gui.gui.model.set_value("showToolsInMenuBar", 0)
	_gui.gui.model.set_value("menuBar", {
		"coachInventoryButton": true, "socialButton": true})
	_show_lobby_screen()


func _log_line(s: String) -> void:
	log.log_line(s)


## Bottom-centre toast — retail's achievementDialog style: a small card that
## stacks upward and fades out after a few seconds.
func _toast(text: String) -> void:
	# its own CanvasLayer above the dialogs (layer 10): under $UI a toast was
	# hidden by whatever window had triggered it (S20)
	var box := $Toasts/ToastBox
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PAPER, UiStyle.RIM_HI, 2, 12))
	var lab := Label.new()
	lab.text = text
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", UiStyle.INK)
	card.add_child(lab)
	box.add_child(card)
	# remove_child first: queue_free alone keeps the node counted until the
	# frame ends, so a 4th toast within 4 s spun this loop forever (S08)
	while box.get_child_count() > 3:
		var old := box.get_child(0)
		box.remove_child(old)
		old.queue_free()
	# bound to the card, so a toast dropped early takes its fade with it
	var tw := card.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(card, "modulate:a", 0.0, 0.6)
	tw.tween_callback(card.queue_free)


## --- Interactive elements (200/201/206) -------------------------------------
## Click on a world marker → INTERACTIVE_ELEMENT_ACTION 201 [i64 id][i16 ordinal]
## (arch 3). The server only answers for kinds with server-side follow-up
## (Card Master pushes the 5401 catalogue); the rest open client-local dialogs.
var _elem_id := -1            # element last used (201)
var _elem_kind := -1          # env type of that element
var _demon_id := -1           # demon of the totem being offered to
var _awaiting_offer := false  # a 5470 basket is in flight → next 5403 is its ack
var _search_open := {}        # tournament id -> opponent-search period open
var _registered_tids := {}    # tournament ids this coach is registered in
var _mails := []              # decoded mail records for the open mailbox
var _mail_mode := "list"      # native mailbox: "list" or "compose"
var _mail_status := {}        # its last result line: {text, ok}
var _mail_loading := false    # a 15000 is out, the list has not landed
var _ex := {}                 # active exchange {id, my_side, other_name,
                              # staged:{0:{card:qty},1:{}}, ready:{0,1}}
var _kanodo_fid := -1         # fighter id of the open Kanodo board
var _kanodo_pick := {}        # sphere node selected on the board
var _duo_pending := {}        # incoming 6025 {team, inviter, invited}
var _watch_target := -1       # coach id asked in the pending 2260
var _npc := {}                # open NPC dialog {name, replies}
var _fired_triggers := {}     # zone-trigger element ids already run this session
var _scenario_queue := []     # pending tutorial monologues (overlapping zones)
const BAAN_TUTORIAL := 46      # "Tutorial de Baan" (challenge, mode 9)
var _baan_lesson_done := false # his lesson plays once per session

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
var _guild_invite := {}         # pending 502 {type, inviter, guild}


var _coach_names := {}   # coach id -> display name (from 4096 spawns)


## Element registry lookup — same shape the hall's element_info returned,
## fed from State.elements (the raw 200/206 wire dicts).
func _element_info(id: int) -> Dictionary:
	var e: Dictionary = State.elements.get(id, {})
	if e.is_empty():
		# Out of the server's AoI or on another island: the lobby's City panel
		# reaches every island's services, so fall back to the client's own
		# env table — same id, kind and descriptor, no wire payload.
		var t: Variant = _env_element(id)
		if t != null:
			e = {"x": t.x, "y": t.y, "z": t.z, "kind": int(t.type),
				"desc": str(t.desc)}
	return {"pos": Vector3i(int(e.get("x", 0)), int(e.get("y", 0)),
			int(e.get("z", 0))),
		"kind": int(e.get("kind", -1)), "desc": str(e.get("desc", "")),
		"cells": e.get("cells", [])}


## Coach display name -> id, over the 4096 spawn registry.
func _coach_id_by_name(cname: String) -> int:
	for id in _coach_names:
		if String(_coach_names[id]).to_lower() == cname.to_lower():
			return int(id)
	return -1


## Current coach cell without the hall — the last EnterInstance position
## (no walking in the lobby; used only for zone-trigger checks at spawn).
func _my_cell() -> Vector2i:
	return Vector2i(int(_my_pos.x), int(_my_pos.y))


## Zone triggers (kind 8) covering a cell — over State.elements.
func _zone_triggers_at(cell: Vector2i) -> Array:
	var out := []
	for id in State.elements:
		var e: Dictionary = State.elements[id]
		if int(e.get("kind", -1)) != 8:
			continue
		if Vector2i(int(e.get("x", 0)), int(e.get("y", 0))) == cell \
				or e.get("cells", []).has(cell):
			out.append(int(id))
	return out


## CanvasLayer shell; the existing XML layer remains above it.
func _show_lobby_screen() -> void:
	if not is_instance_valid(_lobby_screen):
		_lobby_screen = preload("res://src/ui/lobby_screen.gd").new()
		_lobby_screen.name = "LobbyScreen"
		$UI.add_child(_lobby_screen)
		$UI.move_child(_lobby_screen, 0)
		_lobby_screen.bind_model(_gui.gui.model, $UI/Chat)
		_lobby_screen.dialog_requested.connect(func(n): _gui.toggle(n))
		_lobby_screen.action_requested.connect(_on_lobby_action)
		_lobby_screen.team_picked.connect(func(pid):
			_tm_preset_sel = pid
			_push_hub_model())
		log.bubble.connect(func(id, text):
			if id == State.my_coach_id:
				_lobby_screen.show_bubble(text))
	_lobby_screen.set_actions_ready(_lobby_ready)
	_push_hub_model()
	$UI/Chat.show()


func _make_native_lobby_panel(panel_name: String) -> Control:
	var panel := preload("res://src/ui/lobby_panels.gd").new()
	panel.panel_name = panel_name
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


## S18: the native Card Master replaces the retail cardMasterDialog XML.
func _make_card_master_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/card_master_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_mailbox_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/mailbox_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_fusion_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/fusion_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_equip_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/coach_equip_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_kanodo_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/kanodo_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_team_pick_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/team_pick_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_level_up_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/level_up_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_ask_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/ask_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_exchange_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/exchange_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_report_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/report_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_firework_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/firework_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_demon_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/demon_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


func _make_talk_panel(_panel_name: String) -> Control:
	var panel := preload("res://src/ui/talk_panel.gd").new()
	panel.model = _gui.gui.model
	panel.requested.connect(_on_native_lobby_action)
	return panel


## Native controls reuse existing handlers with the same item-event context.
func _on_native_lobby_action(event: String, args: Array, item: Variant, index: int) -> void:
	match event:
		"nativeOpen":
			_gui.open(str(args[0]))
			return
		"nativeStoryPlay":
			_story_play(int(args[0]))
			return
		"nativeStory":
			_gui.close("teamManagementDialog")
			_open_story()
			return
		"nativeLadderTab":
			_ladder_tab = int(args[0])
			_ladder_start = 0
			_ladder_request()
			return
		"nativeDisconnect":
			Session.client.disconnect_from()
			State.my_coach_id = -1
			State.current_world = -1
			get_tree().change_scene_to_file("res://src/main.tscn")
			return
		"openBugReport":
			_open_bug_report()
			return
		"nativePlayReplay":
			var err := ReplayPlayer.play(get_tree(), str(args[0]))
			if err != "":
				_log_line("[color=red]%s[/color]" % I18n.t(err))
			return
		"nativeGhostList":
			Session.send(OP_GHOST_LIST_REQ, PackedByteArray(), 3)
			return
		"nativeGhostLadder":
			Session.send(OP_GHOST_LADDER_REQ, PackedByteArray(), 3)
			return
		"nativeGhostSave":
			_ghost_save(str(args[0]), args[1], args[2] if args.size() > 2 else [])
			return
		"nativeGhostFight":
			var w := WireWriter.new()
			w.put_i64(int(args[0]))
			w.put_i64(0)
			Session.send(OP_GHOST_FIGHT, w.raw(), 3)
			return
		"nativeGhostDelete":
			var w := WireWriter.new()
			w.put_i64(int(args[0]))
			Session.send(OP_GHOST_DELETE, w.raw(), 3)
			return
		"nativeWatch":
			if str(args[0]) != "":
				_watch_coach(str(args[0]))
			return
		"nativeUseElement":
			_use_element(int(args[0]))
			return
		"nativeDemonOpen":
			_open_demon_native()
			return
		"nativeDemonPick":
			if int(State.guild.get("demon_id", 0)) == 0:
				_demon_id = int(args[0])
				_demon_status = {}
				_push_demon_model()
				_demon_request_ladder()
			return
		"nativeDemonAdd":
			_demon_status = {}
			_demon_stage(int(args[0]))
			return
		"nativeDemonRemove":
			var cid := int(args[0])
			if int(_demon_staged.get(cid, 0)) <= 1:
				_demon_staged.erase(cid)
			else:
				_demon_staged[cid] = int(_demon_staged[cid]) - 1
			_push_demon_model()
			return
		"nativeDemonOffer":
			_on_demon_affiliate([], null)
			return
		"nativeFwAdd":
			var cid := int(args[0])
			for sl in _fw_slots:
				if int(sl.cid) == 0:
					sl["cid"] = cid
					sl["delay"] = 0
					break
			_push_firework_model()
			return
		"nativeFwRemove":
			var i := int(args[0])
			if i >= 0 and i < _fw_slots.size():
				_fw_slots.remove_at(i)
				_fw_slots.append({"cid": 0, "delay": 0})
			_push_firework_model()
			return
		"nativeFwDelay":
			var i := int(args[0])
			if i >= 0 and i < _fw_slots.size():
				_fw_slots[i]["delay"] = maxi(0, int(args[1]))
			_push_firework_model()
			return
		"nativeFwLaunch":
			_on_fw_launch([], null)
			return
		"nativeExAdd":
			_ex_add_one(int(args[0]))
			return
		"nativeExRemove":
			if not _ex.is_empty():
				var wr := WireWriter.new()
				wr.put_i64(int(_ex.id))
				wr.put_i32(int(args[0]))
				wr.put_u16(1)
				Session.send(OP_EX_REMOVE, wr.raw(), 3)
			return
		"nativeExReady":
			if not _ex.is_empty() and not bool(_ex.get("ready", {}).get(int(_ex.get("my_side", 0)), false)):
				_on_ex_ready([], null)
			return
		"nativeExCancel":
			_on_ex_close([], null)
			return
		"nativeTournTree":
			_tourn_tree(int(args[0]))
			return
		"nativeTournSearch":
			_tourn_search(int(args[0]))
			return
		"nativeTournCreate":
			_tourn_create(args[0])
			return
		"nativeEquipOpen":
			_open_equip()
			return
		"nativeEquipPut":
			var cid := int(args[0])
			var slot: int = COACH_SLOT_FOR_TYPE.get(int(Cards.meta(cid).get("type", -1)), -1)
			if slot >= 0:
				_equip_draft[slot] = cid
			_push_equip_model()
			return
		"nativeEquipTake":
			var slot := int(args[0])
			if slot >= 0 and slot < 14:
				_equip_draft[slot] = 0
			_push_equip_model()
			return
		"nativeEquipReset":
			_equip_draft = _equip_slots.duplicate()
			_push_equip_model()
			return
		"nativeEquipWear":
			_on_equip_wear()
			return
		"nativeKanodo":
			_open_kanodo(int(args[0]))
			return
		"nativeKanodoPick":
			_on_sphere_pick(args[0], bool(args[1]))
			return
		"nativeKanodoBuy":
			_on_sphere_buy()
			return
		"nativeTeamPick":
			_confirm_team(int(args[0]))
			return
		"nativeTeamPickCancel":
			_cancel_team_pick()
			return
		"nativeAsk":
			_ask_answer(bool(args[0]))
			return
		"nativeTalk":
			_talk_choice(int(args[0]))
			return
		"nativeRevive":
			_revive_fighter(int(args[0]), int(args[1]))
			return
		"nativeCmSelect":
			_cm_selected = int(args[0])
			_cm_given = {}
			_cm_status = {}
			_push_cardmaster_model()
			return
		"nativeCmStage":
			_cm_status = {}
			_cm_stage(int(args[0]))
			return
		"nativeCmUnstage":
			_cm_unstage(int(args[0]))
			return
		"nativeCmClear":
			_cm_given = {}
			_cm_status = {}
			_push_cardmaster_model()
			return
		"nativeCmBuy":
			_cm_buy_tokens()
			return
		"nativeCmBarter":
			_on_cm_buy([], null)
			return
		"nativeMailRead":
			_mail_open(int(args[0]))
			return
		"nativeMailDelete":
			_mail_status = {}
			_mail_delete(int(args[0]))
			return
		"nativeMailTake":
			_mail_status = {}
			_on_mail_take([], null)
			return
		"nativeMailCompose":
			_mail_compose(str(args[0]))
			return
		"nativeMailCancel":
			_mail_mode = "list"
			_mail_status = {}
			_push_mail_model()
			return
		"nativeMailCheck":
			_gui.gui.model.set_value("mailbox.newMail.receiver", str(args[0]).strip_edges())
			_gui.gui.model.set_value("mailbox.newMail.receiverId", 0)
			_on_mail_test_name([], null)
			return
		"nativeMailAttach":
			_mail_attach(int(args[0]))
			return
		"nativeMailDetach":
			var cards: Array = _gui.gui.model.get_value("mailbox.newMail", "cards")
			if cards is Array and int(args[0]) < cards.size():
				cards.remove_at(int(args[0]))
			_push_mail_model()
			return
		"nativeMailSend":
			var nm: Variant = _gui.gui.model.get_value("mailbox.newMail")
			if nm is Dictionary:
				nm["receiver"] = str(args[0]).strip_edges()
				nm["title"] = str(args[1])
				nm["message"] = str(args[2])
			_mail_status = {}
			_on_mail_send([], null)
			return
		"nativeFusTarget":
			_fusion_target = int(args[0])
			_fusion_failed = false
			_fusion_status = {}
			_push_fusion_model()
			return
		"nativeFusStage":
			_fusion_status = {}
			_fusion_stage_native(int(args[0]))
			return
		"nativeFusUnstage":
			_fusion_inputs.erase(int(args[0]))   # one copy
			_fusion_failed = false
			_push_fusion_model()
			return
		"nativeFusClear":
			_fusion_inputs = []
			_fusion_failed = false
			_fusion_status = {}
			_push_fusion_model()
			return
		"nativeFusRequest":
			_on_fusion_request([], null)
			return
	var context := GWidget.new()
	context.item_value = item
	context.selected_index = index
	_gui._on_event("dofusarena", event, args, context)
	context.free()


## Resolve the announced portal address for HTTP: a wildcard bind host
## ("0.0.0.0"/"::") only means "wherever the game socket reached", so the
## connected game host replaces it. Returns "" when nothing was announced.
func _web_base_url(announced: String) -> String:
	var u := announced.strip_edges().trim_suffix("/")
	if u == "":
		return ""
	var host := ""
	if Session.client != null:
		host = Session.client.last_host
	if host == "":
		return u
	for wild in ["0.0.0.0", "[::]", "::"]:
		if u.contains("://" + wild + ":") or u.ends_with("://" + wild):
			return u.replace(wild, host)
	return u


func _open_bug_report() -> void:
	var d := BugReport.new(State.web_base_url)
	# Capture the arena before the modal covers it.
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		d.set_screenshot(img.save_jpg_to_buffer(0.85))
	add_child(d)
	d.popup_centered()


## The lobby's matchmaking state (S18; was the debug row's Cancel button).
func _set_searching(on: bool) -> void:
	if is_instance_valid(_lobby_screen):
		_lobby_screen.set_searching(on)


## --- Historia (S21): the campaign panel ---------------------------------
var _story_won: Array = []          # campaign challenge ids won (60021)
var _story_intro_seen := {}         # challenge id -> its demon intro played


func _open_story() -> void:
	_push_story_model()
	Session.send(OP_STORY_REQUEST, PackedByteArray(), 2)
	_gui.open("storyDialog")


func _push_story_model() -> void:
	if _gui == null:
		return
	var titulars := 0
	for fr in State.roster:
		if int(fr.get("type", 2)) == 2 and int(fr.get("state", 0)) == 0:
			titulars += 1
	_gui.gui.model.set_value("story", {"won": _story_won.duplicate(), "titulars": titulars})


## Jugar on a Historia challenge: its demon's intro the first time (as in the
## lobby), Nilo's lessons before his (in _launch_challenge), then the fight.
func _story_play(chal: int) -> void:
	_gui.close("storyDialog")
	var task := int(Story.INTROS.get(chal, 0))
	if task != 0 and not _story_intro_seen.has(chal):
		_story_intro_seen[chal] = true
		var intro: Dictionary = Scenarios.script(task)
		if not intro.get("pages", []).is_empty():
			_talk_pages(NpcDialogs.challenge_name(chal), intro.pages, func(): _launch_challenge(chal, 99))
			return
	_launch_challenge(chal, 99)


## The hub cards' live lines (S20B): how many Story starters, the Elite
## teams with the one Ranking will field, and the tournament this coach can
## search now. Pushed whenever the roster, the presets or the tournament
## state change.
func _push_hub_model() -> void:
	if _gui == null:
		return
	var titulars := 0
	var bench := 0
	for fr in State.roster:
		if int(fr.get("type", 2)) != 2:
			continue
		match int(fr.get("state", 0)):
			0: titulars += 1
			1: bench += 1
	var teams: Array = []
	for p in State.presets:
		if int(p.get("type", 0)) in [-5, -6, -7]:
			continue   # 2v2 presets (Features.DUO)
		if int(p.get("id", 0)) <= 0:
			continue   # the roster's pseudo-preset, not a team to pick
		teams.append({"id": int(p.get("id", 0)), "name": str(p.get("name", ""))})
	# Ranking fields the Team panel's pick; with none, the first Elite team
	if not teams.any(func(t): return int(t.id) == _tm_preset_sel) and not teams.is_empty():
		_tm_preset_sel = int(teams[0].id)
	var tourn := {"registered": 0, "label": "", "search_tid": -1}
	var first_name := ""
	for tid in _tourn_rows:
		if not _registered_tids.has(tid):
			continue
		var def := _tourn_def(tid)
		if not Features.LEGENDS and TournamentDefs.kind(def) == TournamentDefs.LEGENDARY:
			continue
		tourn.registered += 1
		if first_name == "":
			first_name = _tourn_name(tid)
		if bool(_search_open.get(tid, false)) and int(tourn.search_tid) < 0:
			tourn.search_tid = int(tid)
			tourn.label = I18n.t("hub.tourn.open", {"name": _tourn_name(tid)})
	if str(tourn.label) == "" and first_name != "":
		tourn.label = I18n.t("hub.tourn.shut", {"name": first_name})
	_push_story_model()
	_gui.gui.model.set_value("hub", {
		"story": {"titulars": titulars, "bench": bench},
		"ranked": {"teams": teams, "selected": _tm_preset_sel},
		"tourn": tourn})


func _on_lobby_action(action: String) -> void:
	match action:
		"cancel_search": _on_cancel_search()
		"practice": _on_practice_pressed()
		"fight": _on_fight_pressed()
		"quick": _on_quick_search()
		"evo": _on_evo_search()
		# S20B hub cards
		"story": _open_story()
		"ghost":
			if _searching:
				_on_cancel_search()
			_gui.open("ghostDialog")
		"team_story", "team_elite":
			_gui.gui.model.set_value("gamePreferences",
				0 if action == "team_story" else 1, "lastSelectedGameModeId")
			_gui.open("teamManagementDialog")
		"tourn_search":
			var hub: Variant = _gui.gui.model.get_value("hub")
			if hub is Dictionary:
				_tourn_search(int(hub.get("tourn", {}).get("search_tid", -1)))
		"duo":
			# S18: the native 2v2 team panel, with the online friends to pick
			_push_social_model()
			_gui.open("team2vs2NameDialog")
		"team": _gui.toggle("teamManagementDialog")


func _use_element(id: int) -> void:
	var e: Dictionary = _element_info(id)
	var kind := int(e.get("kind", -1))
	var w := WireWriter.new()
	w.put_i64(id)
	w.put_i16(0)   # action ordinal — first action of the element's list
	Session.send(OP_ELEMENT_ACTION, w.raw(), 3)
	var label := Elements.kind_name(kind)
	_elem_id = id
	_elem_kind = kind
	match kind:
		1:   # Card Master — server pushes the 5401 catalogue
			_log_line(I18n.t("shop.opening", {"label": label}))
		4:   # Zaap — no worlds to travel in the lobby (owner, S05)
			pass
		2:   # Mailbox — the server answers 15000 with the full list (15001)
			_mail_mode = "list"
			_mail_status = {}
			_mail_loading = true
			Session.send(OP_MAILBOX_REQ, PackedByteArray(), 3)
			_gui.open("mailboxDialog")
		10:  # Graveyard — its fighters live in the Team panel now (S18)
			_open_fallen()
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
		5:   # Breed Master — recruit text; "Aceptar" runs 26330 too.
			# zs_1 also reports criterion 221 ("talked to a breedmaster") on
			# every dialog open — a counter stat, value=1 each time.
			_open_breed_master(e)
			_report_criterion(221)
		11:  # Demon totem
			# S18: no totem to visit — the demon ladder is the Ranking's
			# Demonios tab, and the offering lives in the clan panel.
			_gui.open("ladderInformationDialog")
		13:  # Tournament totem — its tournaments live in the Calendar (S18)
			_gui.open("calendarDialog")
		12:  # Firework launcher — pick a card → 22095 → 22094 echo
			_open_firework(e)
		15:  # NPC talker — client-side dialog tree (record 1500)
			_open_npc(e)
		_:   # anything else has no screen of its own
			DebugLog.add("element %d (kind %d): nothing to open" % [id, kind])


## --- Invitations (S18: native askDialog, src/ui/ask_panel.gd) ---------------
## Incoming challenge / match / clan / duo / trade prompts. One at a time;
## the rest wait in _asks. Each answers through its own Callable(bool).
var _asks: Array = []   # [{kind, title, text, answer}]


func _ask(kind: String, title: String, text: String, answer: Callable) -> void:
	_asks.append({"kind": kind, "title": title, "text": text, "answer": answer})
	if _asks.size() == 1:
		_ask_show()


func _ask_show() -> void:
	if _asks.is_empty():
		_gui.close("askDialog")
		return
	_gui.gui.model.set_value("ask", {"title": _asks[0].title, "text": _asks[0].text})
	if not _gui.is_open("askDialog"):
		_gui.open("askDialog")


func _ask_answer(accepted: bool) -> void:
	if _asks.is_empty():
		return
	var a: Dictionary = _asks.pop_front()
	_gui.close("askDialog")
	(a.answer as Callable).call(accepted)
	_ask_show()


## The other side withdrew (e.g. 26304): drop its prompt unanswered.
func _ask_withdraw(kind: String) -> void:
	var was_first: bool = not _asks.is_empty() and _asks[0].kind == kind
	_asks = _asks.filter(func(a): return a.kind != kind)
	if was_first:
		_gui.close("askDialog")
		_ask_show()


## --- Conversations (S18: native npcTalkDialog, src/ui/talk_panel.gd) ---------
## Every talking element (challenge 3, breed master 5, Demon III 6, demon
## challenge 7, Demon I 9, NPC 15) and the tutorial monologues reduce to one
## shape: who speaks, what they say, and a row of choices. _talk_show pushes
## that as the `talk` model; the panel answers "nativeTalk" [index] and the
## choice's Callable runs here, so the wire stays in main.gd.

var _talk_actions: Array = []   # Callables, index-aligned with talk.choices
var _talk_seen := {}            # element id -> true once its intro scenario ran


## choices: [{label, kind, do}] — kind "reply" / "challenge" go in the list,
## "primary" / "secondary" in the action row.
## Who is talking, as a face for the talk window (S23): {"anim": set dir,
## "action": …} for the retail portraits (tools/asset-import/portraits.sh),
## {"image": path} for a class portrait or a challenge's art. Each opener
## sets it; closing the window clears it.
var _talk_face := {}
const FACE_NILO := {"anim": "anims/portrait_nilo", "action": "1_AnimStatique", "who": "talk.who.nilo"}
const FACE_ALDEBRAN := {"anim": "anims/portrait_aldebran", "action": "1_AnimParle", "who": "talk.who.aldebran"}
const FACE_DEMON1 := {"anim": "anims/portrait_demon1", "action": "0_AnimStatique", "who": "talk.who.demon1"}
const FACE_DEMON3 := {"image": "gui/images/challenges/illustrations/29.png", "who": "talk.who.demon3"}


func _talk_show(speaker: String, text: String, choices: Array, page := 0, pages := 0) -> void:
	_talk_actions = []
	var rows: Array = []
	for c in choices:
		_talk_actions.append(c.do)
		rows.append({"label": str(c.label), "kind": str(c.kind)})
	_gui.gui.model.set_value("talk", {"name": speaker, "text": _talk_bbcode(text),
		"choices": rows, "page": page, "pages": pages, "face": _talk_face})
	if not _gui.is_open("npcTalkDialog"):
		_gui.open("npcTalkDialog")


func _talk_choice(i: int) -> void:
	if i >= 0 and i < _talk_actions.size():
		(_talk_actions[i] as Callable).call()


func _talk_close() -> void:
	_talk_face = {}
	_gui.close("npcTalkDialog")
	_npc = {}


## Retail texts carry literal "\n" and a few HTML tags; RichTextLabel speaks
## BBCode.
static func _talk_bbcode(text: String) -> String:
	var t := text.replace("\\n", "\n").replace("[", "[lb]")
	for tag in ["b", "i", "u"]:
		t = t.replace("<%s>" % tag, "[%s]" % tag).replace("</%s>" % tag, "[/%s]" % tag)
	var strip := RegEx.create_from_string("<[^>]*>")
	return strip.sub(t, "", true).strip_edges()


func _close_choice(key := "btn.close") -> Dictionary:
	return {"label": I18n.t(key), "kind": "secondary", "do": _talk_close}


## A challenge offer: 26330 [i32 challengeId][i16 mode] — 99 for every picker
## accept (cj_0's bM is hardcoded 99 for env 3/6/7), the record's Qu() for an
## NPC reply action.
func _challenge_choice(chal: int, mode := 99, label := "") -> Dictionary:
	return {"label": label if label != "" else NpcDialogs.challenge_name(chal),
		"kind": "challenge" if label == "" else "primary",
		"do": func(): _launch_challenge(chal, mode)}


func _launch_challenge(chal: int, mode: int) -> void:
	if chal <= 0:
		return
	if chal == BAAN_TUTORIAL and not _baan_lesson_done:
		# S10: Baan's two lessons (scenarios 200, 201) before his fight
		_baan_lesson_done = true
		_talk_close()
		_talk_face = FACE_NILO
		var sc := Scenarios.script(200)
		var pages: Array = sc.get("pages", []) + Scenarios.script(201).get("pages", [])
		_talk_pages(I18n.t("talk.baan"), pages, func(): _launch_challenge(chal, mode))
		return
	var w := WireWriter.new()
	w.put_i32(chal)
	w.put_u16(mode)
	Session.send(OP_TEAM_TEST, w.raw(), 2)
	_log_line(I18n.t("challenge.accepted_id", {"id": chal}))
	_talk_close()


## Paged monologue: "Siguiente" until the last page, then `done`.
func _talk_pages(speaker: String, pages: Array, done: Callable) -> void:
	_npc = {"speaker": speaker, "pages": pages, "page": 0, "done": done}
	_talk_page()


func _talk_page() -> void:
	var pages: Array = _npc.get("pages", [])
	var page := int(_npc.get("page", 0))
	if page >= pages.size():
		(_npc.get("done", _talk_close) as Callable).call()
		return
	var last := page == pages.size() - 1
	_talk_show(str(_npc.get("speaker", "")), NpcDialogs.npc_name(int(pages[page])), [
		{"label": I18n.t("btn.ok" if last else "btn.next"), "kind": "primary",
			"do": func():
				_npc["page"] = int(_npc.get("page", 0)) + 1
				_talk_page()},
		_close_choice()], page + 1, pages.size())


## NPC talker (kind 15): desc = "nameId;criterionId;defaultGroup;altGroup;
## style" (client ni_0). The whole tree is client-side — opening sends nothing;
## reply actions are the only wire traffic (26330 challenge / 22003 criterion).
## altGroup is picked when criterionId != -1 and its value is > 0.
func _open_npc(e: Dictionary) -> void:
	_talk_face = FACE_NILO   # S23: the only kind-15 talker is Nilo (Baan)
	var fields := str(e.get("desc", "")).split(";")
	var name_id := int(fields[0]) if fields.size() > 0 else -1
	var crit := int(fields[1]) if fields.size() > 1 else -1
	var def_group := int(fields[2]) if fields.size() > 2 else -1
	var alt_group := int(fields[3]) if fields.size() > 3 else def_group
	_npc = {"name": NpcDialogs.npc_name(name_id), "replies": []}
	var group := def_group
	if crit != -1 and int(State.criteria.get(crit, 0)) > 0:
		group = alt_group
	_npc_node(group)


## One dialog node: speech (content.59) + reply rows (content.60 labels).
func _npc_node(group_id: int) -> void:
	var g := NpcDialogs.group(group_id)
	if g.is_empty():
		_talk_close()
		return
	var replies: Array = g.get("replies", [])
	_npc["replies"] = replies
	var choices: Array = []
	for i in replies.size():
		choices.append({"label": str(replies[i].get("label", "…")), "kind": "reply",
			"do": _npc_reply.bind(i)})
	if choices.is_empty():
		choices.append(_close_choice())
	_talk_show(str(_npc.get("name", "")), str(g.get("text", "")), choices)


## Reply click = client ao_2 case 17001: run the action, then navigate to the
## reply's `next` group (0 = close the dialog).
func _npc_reply(i: int) -> void:
	var replies: Array = _npc.get("replies", [])
	if i < 0 or i >= replies.size():
		return
	var r: Dictionary = replies[i]
	match int(r.get("act", 0)):
		1: # Lancer un défi — 26330 [i32 challengeId][i16 challenge.Qu()]
			# through _launch_challenge, so Baan's lesson plays first (S10)
			var chal := int(r.get("params", [0])[0])
			_launch_challenge(chal, NpcDialogs.challenge_mode(chal))
			return
		2: # Donne un exploit — 22003 {i16 criterionId, u8 1, i16 1}
			var crit := int(r.get("params", [0])[0])
			_report_criterion(crit)
	var next := int(r.get("next", 0))
	if next != 0:
		_npc_node(next)
	else:
		_talk_close()


## 22003 {i16 criterionId, u8 1, i16 1}, plus the local shadow same-session
## gates read.
func _report_criterion(crit: int) -> void:
	var w := WireWriter.new()
	w.put_i16(crit)
	w.put_u8(1)
	w.put_i16(1)
	State.net.send_message(OP_STAT_UPD, w.raw(), 2)
	State.criteria[crit] = 1


## uk_0 Challenge (kind 3): desc "nameId;speechId;challengeId;…" — one choice
## per challenge (cj_0's picker), each launching 26330 {id, 99}.
func _open_challenge_picker(e: Dictionary) -> void:
	_talk_face = FACE_DEMON3 if str(e.get("desc", "")).begins_with("144") else {}
	var fields := _desc_fields(str(e.get("desc", "")))
	var choices: Array = []
	for c in fields.slice(2):
		choices.append(_challenge_choice(int(c)))
	choices.append(_close_choice())
	_talk_show(NpcDialogs.npc_name(fields[0]) if fields.size() > 0 else "",
		NpcDialogs.npc_name(fields[1]) if fields.size() > 1 else "", choices)


## pn_0 DemonChallenge (kind 7): desc "nameId;scenarioId;challengeId;
## acceptText[;refuseText]". scenarioId != 0 plays that intro monologue the
## first time (retail Lua scenario, then runInteractiveElementSpecialAction)
## and offers the challenge after it, and directly from then on. With
## scenarioId == 0 the offer is gated on achievement 278 ("all four
## minute-demon challenges"); otherwise the refuse text and "OK".
func _open_demon_challenge(e: Dictionary) -> void:
	_talk_face = {}
	var fields := _desc_fields(str(e.get("desc", "")))
	var speaker := NpcDialogs.npc_name(fields[0]) if fields.size() > 0 else ""
	var task := int(fields[1]) if fields.size() > 1 else 0
	var intro: Dictionary = Scenarios.script(task) if task != 0 else {}
	var id := _elem_id
	if not intro.is_empty() and not _talk_seen.has(id):
		_talk_seen[id] = true
		_talk_pages(speaker, intro.get("pages", []), func(): _demon_offer(fields, speaker))
	else:
		_demon_offer(fields, speaker)


func _demon_offer(fields: Array, speaker: String) -> void:
	var task := int(fields[1]) if fields.size() > 1 else 0
	var chal := int(fields[2]) if fields.size() > 2 else -1
	var accept_txt := int(fields[3]) if fields.size() > 3 else -1
	var refuse_txt := int(fields[4]) if fields.size() > 4 else -1
	if task != 0 or _ach_done(278):
		_talk_show(speaker, NpcDialogs.npc_name(accept_txt), [
			_challenge_choice(chal, 99, I18n.t("btn.accept")),
			_close_choice("btn.refuse")])
	else:
		_talk_show(speaker, NpcDialogs.npc_name(refuse_txt), [_close_choice("btn.ok")])


## aac_2 Demon I (kind 9): desc "nameId;t0;t1;t2;alt0;alt1" — a paged
## monologue. Achievement 277 (all minute-demon challenges) picks the alt
## two-page set.
func _open_demon1(e: Dictionary) -> void:
	_talk_face = FACE_DEMON1
	var fields := _desc_fields(str(e.get("desc", "")))
	var pages := fields.slice(4) if _ach_done(277) else fields.slice(1, 4)
	_talk_pages(NpcDialogs.npc_name(fields[0]), pages, _talk_close)


## acn_0 Demon III (kind 6): desc "nameId;t0..t5;challengeId×3". First contact
## (achievement 275 pending) reports criterion 210 then pages t0→t2; the tail
## picks t3 (needs 3 recruits, ach 276), t5 (evo challenges done, ach 284) or
## t4 + the challenges.
func _open_demon3(e: Dictionary) -> void:
	_talk_face = FACE_DEMON3
	var fields := _desc_fields(str(e.get("desc", "")))
	var speaker := NpcDialogs.npc_name(fields[0])
	var texts := fields.slice(1, 7)
	if not _ach_done(275):
		_report_criterion(210)   # achievement 275's gate reads it
		_talk_pages(speaker, texts.slice(0, 3), _talk_close)
	elif not _ach_done(276):
		_talk_show(speaker, NpcDialogs.npc_name(texts[3]), [_close_choice()])
	elif _ach_done(284):
		_talk_show(speaker, NpcDialogs.npc_name(texts[5]), [_close_choice()])
	else:
		var choices: Array = []
		for c in fields.slice(7):
			# 30 opens with achievement 280, 31 with 281 (challengeDialog
			# hides them by afz_0.achievementLinkedCompleted; the server
			# refuses them too)
			var gate := int(DEMON3_GATES.get(int(c), 0))
			if gate == 0 or _ach_done(gate):
				choices.append(_challenge_choice(int(c)))
		choices.append(_close_choice())
		_talk_show(speaker, NpcDialogs.npc_name(texts[4]), choices)


## The Demon III chain's order (type 400 QB).
const DEMON3_GATES := {30: 280, 31: 281}


## zs_1 Breed Master (kind 5): desc "nameId;textId;textId;breed;challengeId".
## Accept → 26330 {challengeId, 99}.
func _open_breed_master(e: Dictionary) -> void:
	var bf := _desc_fields(str(e.get("desc", "")))
	_talk_face = {"image": "gui/images/breeds/fightTimeline/%d.png" % (int(bf[3]) * 10)} \
		if bf.size() > 3 and bf[3] >= 1 and bf[3] <= 12 else {}
	var fields := _desc_fields(str(e.get("desc", "")))
	var chal := int(fields[4]) if fields.size() > 4 else -1
	var choices: Array = []
	if chal > 0:
		choices.append(_challenge_choice(chal, 99, I18n.t("btn.accept")))
	# "Reclutar un guerrero" (zs_1 → fighterCreationTutorialDialog): the
	# fighter creation with this master's class picked (S10)
	var breed := int(fields[3]) if fields.size() > 3 else 0
	if breed >= 1 and breed <= 12:
		choices.append({"label": I18n.t("talk.recruit"), "kind": "primary",
			"do": func():
				_talk_close()
				# a recruit joins Historia (S21: the campaign fields its starters)
				_on_new_fighter_dialog([], null, true, breed)})
	choices.append(_close_choice("btn.refuse"))
	_talk_show(NpcDialogs.npc_name(fields[0]) if fields.size() > 0 else "",
		NpcDialogs.npc_name(fields[1]) if fields.size() > 1 else "", choices)


## Achievement check against the coach's live criteria + tome (aau_1.a).
func _ach_done(id: int) -> bool:
	return NpcDialogs.achievement_done(id, State.criteria, State.inventory)


## Zone triggers (kind 8, client `oq`): desc "script;requireAch;blockAch".
## Fires once per element per session when the coach walks into its zone —
## the required achievement must be done, the blocking one NOT. The script is
## a client-side Lua scenario (anr_0) — the tutorial monologues.
func _check_zone_trigger(cell: Vector2i) -> void:
	for id in _zone_triggers_at(cell):
		if _fired_triggers.has(id):
			continue
		var e: Dictionary = _element_info(id)
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
		if _elem_kind == ELEM_SCENARIO and _gui.is_open("npcTalkDialog"):
			_scenario_queue.append(script)
		else:
			_run_scenario(script)


## Play a scenario as a paged monologue (the retail BubbleText content is
## intact; the actor walk-in / widget-particle choreography is not
## reproduced). `ach` criteria go out as 22003 like Context.updateAch.
func _run_scenario(id: int) -> void:
	var s := Scenarios.script(id)
	if s.is_empty():
		return
	var ach := int(s.get("ach", 0))
	if ach > 0:
		_report_criterion(ach)
	_elem_kind = ELEM_SCENARIO
	var speaker := str(s.get("speaker", ""))
	_talk_face = {"adamai": FACE_ALDEBRAN, "baan": FACE_NILO}.get(speaker, {})
	_talk_pages(I18n.t("talk." + speaker) if speaker != "" else I18n.t("talk.tutorial"),
		s.get("pages", []), func():
		_talk_close()
		if not _scenario_queue.is_empty():
			_run_scenario(_scenario_queue.pop_front()))
	DebugLog.add("tutorial scenario %d fired" % id)


## Play a scenario now, or after the monologue on screen (one at a time, like
## the retail Lua VM's event loop).
func _queue_scenario(id: int) -> void:
	if _gui.is_open("npcTalkDialog"):
		_scenario_queue.append(id)
	else:
		_run_scenario(id)


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
## Dialog folded into one native panel (S18, src/ui/report_panel.gd): the
## outcome, winner/loser coaches with their new ladder strength, each of our
## fighters' OW report (banked XP, morale/tiredness drift, wounds) and the
## cards won. fight_view decoded the 8300 before acking; we push the
## `fightReport` model once the lobby is back.
func _show_fight_result() -> void:
	var r: Dictionary = State.fight_result
	State.fight_result = {}
	if r.is_empty():
		return
	# 8300 carries the standing won; the absolute value only comes with the
	# login 2052, so keep it here. Crossing a level pops the retail
	# coachLevelUpDialog once the report is closed (WE.java).
	var level_before := State.coach_level(State.coach_standing)
	State.coach_standing += int(r.get("standing", 0))
	var level_now := State.coach_level(State.coach_standing)
	_push_local_coach()
	var me := int(State.my_coach_id)
	var in_win: bool = r.get("win_str", {}).has(me)
	var in_lose: bool = r.get("lose_str", {}).has(me)
	var outcome := "over"
	if int(r.get("flee", 0)) != 0:
		outcome = "abandoned"
	elif in_win:
		outcome = "victory"
	elif in_lose:
		outcome = "defeat"
	var summary := []
	if int(r.get("standing", 0)) != 0:
		summary.append(I18n.t("debrief.standing", {"n": "%+d" % int(r.standing)}))
	if int(r.get("killed", 0)) > 0 or int(r.get("injured", 0)) > 0:
		summary.append(I18n.t("debrief.casualties", {"killed": int(r.killed),
			"injured": int(r.injured)}))
	var coaches: Array = []
	for side in [["winners", "win_str", true], ["losers", "lose_str", false]]:
		for c in r.get(side[0], []):
			var cid := int(c.id)
			var str_new: Variant = r.get(side[1], {}).get(cid)
			coaches.append({"name": _coach_result_name(cid),
				"side": I18n.t("rp.winner") if side[2] else I18n.t("rp.loser"),
				"strength": str(int(str_new)) if str_new != null else "—",
				"me": cid == me})
	var fighters: Array = []
	for rep in r.get("reports", []):
		# Retail applies the OW report to the roster fighter (adY.dz) — keep
		# the lobby panel's morale/tiredness/xp current without a 6006 re-push.
		for f in State.roster:
			if int(f.get("id", -1)) == int(rep.fighter):
				f.morale = int(rep.get("morale", f.get("morale", 0)))
				f.tiredness = int(rep.get("tiredness", f.get("tiredness", 0)))
				f.xp = int(f.get("xp", 0)) + int(rep.get("xp_final", 0))
				if rep.get("dead", false):
					f.state = 2   # dead — the Team panel's Fallen section
		var xp := "%+d" % int(rep.get("xp_final", 0))
		if int(rep.get("morale_bonus", 0)) != 0:
			xp += " " + I18n.t("debrief.morale_bonus", {"n": "%+d" % int(rep.morale_bonus)})
		fighters.append({"name": _fighter_result_name(int(rep.fighter)), "xp": xp,
			"morale": "%d (%+d)" % [int(rep.get("morale", 0)), int(rep.get("morale_delta", 0))],
			"tired": "%d (%+d)" % [int(rep.get("tiredness", 0)), int(rep.get("tiredness_delta", 0))],
			"state": I18n.t("rp.dead") if rep.get("dead", false)
				else (I18n.t("rp.wounded") if int(rep.get("wound", 0)) != 0 else I18n.t("rp.fine"))})
	var counts := {}
	for cid in r.get("won_cards", []):
		counts[cid] = int(counts.get(cid, 0)) + 1
	var cards: Array = []
	for cid in counts:
		cards.append({"id": int(cid), "name": Cards.name_of(int(cid)), "qty": int(counts[cid])})
	_gui.gui.model.set_value("fightReport", {"outcome": outcome,
		"summary": summary, "coaches": coaches, "fighters": fighters,
		"cards": cards})
	var report := _gui.open("fightReportDialog")
	if level_now > level_before and report != null:
		_gui.gui.model.set_value("levelUp", {"level": level_now})
		report.closed.connect(func(): _gui.open("coachLevelUpDialog"), CONNECT_ONE_SHOT)


## The retail graveyard element: the fallen fighters are a section of the
## Team panel's evolution tab, not a place (owner, S18). Retail sends 6031 on
## team-panel open — the server re-pushes the roster (6006) + presets (6030).
func _open_fallen() -> void:
	Session.send(6031, PackedByteArray(), 2)
	_gui.gui.model.set_value("gamePreferences", 0, "lastSelectedGameModeId")
	_push_team_model()
	_gui.open("teamManagementDialog")


## Fusion altar: multi-select inventory cards as inputs (≥2 of one set), pick
## the target from List2 (every template in the inputs' set), Fuse → 5490.
## --- fusionLabDialog ---------------------------------------------------------
## fusionTrade: localCardExchange = input tray (padded to slotCount),
## fusionCard/resultCard = the boost card being made, labPower = altar power,
## kardsPower = Σ inputs.reqLevel − target.fusPower (client recipe math).

var _fusion_lab := {}          # altar record {power, quality, slots}
var _fusion_inputs: Array = [] # card ids fed in (a card twice = two copies)
var _fusion_target := -1       # boost card id being made
var _fusion_failed := false
var _fusion_status := {}       # last 5491 for the native panel: {text, ok}


func _open_fusion_lab(e: Dictionary) -> void:
	_fusion_inputs = []
	_fusion_target = -1
	_fusion_failed = false
	_fusion_status = {}
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
	# --- native panel (S18): the whole recipe, the server's own rules ---------
	# power   = Σ inputs' level + altar power + Σ inputs' boost power ≥ target's
	# quality = altar quality + Σ inputs' boost quality ≥ target's, and it is
	#           the success die (roll < quality out of 100)
	# value   = the target may be worth at most 3× what is given
	var lab_power := int(_fusion_lab.get("power", 0))
	var lab_quality := int(_fusion_lab.get("quality", 0))
	var have_power := lab_power
	var have_quality := lab_quality
	var given_value := 0
	var counts := {}
	for cid in _fusion_inputs:
		var m := Cards.meta(int(cid))
		have_power += int(m.get("reqLevel", 0)) + int(m.get("fusPower", 0))
		have_quality += int(m.get("fusQuality", 0))
		given_value += int(m.get("value", 0))
		counts[int(cid)] = int(counts.get(int(cid), 0)) + 1
	var tm := Cards.meta(_fusion_target) if _fusion_target > 0 else {}
	var need_power := int(tm.get("fusPower", 0))
	var need_quality := int(tm.get("fusQuality", 0))
	var reason := ""
	if _fusion_target <= 0:
		reason = "fus.pick_target"
	elif _fusion_inputs.size() < 2:
		reason = "fus.need_two"
	elif have_power < need_power:
		reason = "fus.short_power"
	elif have_quality < need_quality:
		reason = "fus.short_quality"
	elif int(tm.get("value", 0)) > given_value * 3:
		reason = "fus.too_valuable"
	var targets: Array = []
	for tid in Cards.all_ids():
		var m := Cards.meta(int(tid))
		if int(m.get("fusPower", 0)) > 0 or int(m.get("fusQuality", 0)) > 0:
			targets.append({"id": int(tid), "name": Cards.name_of(int(tid)),
				"value": int(m.get("value", 0)), "fusPower": int(m.get("fusPower", 0)),
				"fusQuality": int(m.get("fusQuality", 0)),
				"owned": int(State.inventory.get(int(tid), 0))})
	targets.sort_custom(func(a, b): return a.value < b.value \
		or (a.value == b.value and a.id < b.id))
	# What can go on the altar: tradable cards you own (the server refuses
	# bound and undestructible ones), the most valuable first.
	var fuel: Array = []
	for cid in State.inventory:
		var n := int(State.inventory[cid])
		var m := Cards.meta(int(cid))
		if n <= 0 or not bool(m.get("tradable", false)):
			continue
		fuel.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"value": int(m.get("value", 0)), "owned": n,
			"staged": int(counts.get(int(cid), 0)),
			"reqLevel": int(m.get("reqLevel", 0)),
			"fusPower": int(m.get("fusPower", 0)),
			"fusQuality": int(m.get("fusQuality", 0))})
	fuel.sort_custom(func(a, b): return a.value > b.value \
		or (a.value == b.value and a.id < b.id))
	var inputs: Array = []
	for cid in counts:
		inputs.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"count": int(counts[cid])})
	model.set_value("fusionTrade", {
		"localCardExchange": tray,
		"fusionCard": target,
		"resultCard": target,
		"fusionFailed": _fusion_failed,
		"labPower": lab_power,
		"kardsPower": maxi(0, kp),
		"slotCount": slots,
		"canFusion": reason == "",
		"help": "",
		"lab": {"power": lab_power, "quality": lab_quality, "slots": slots},
		"targets": targets, "targetId": _fusion_target,
		"fuel": fuel, "inputs": inputs, "inputCount": _fusion_inputs.size(),
		"power": {"have": have_power, "need": need_power},
		"quality": {"have": have_quality, "need": need_quality},
		"chance": clampi(have_quality, 0, 100),
		"givenValue": given_value,
		"reason": reason,
		"status": str(_fusion_status.get("text", "")),
		"statusOk": bool(_fusion_status.get("ok", false))})


## Native "give a card": one more copy of `cid` on the altar, while you own
## more and the altar has room. The same card twice is two copies (the
## server tallies duplicates when it consumes them).
func _fusion_stage_native(cid: int) -> void:
	var slots := maxi(1, int(_fusion_lab.get("slots", 3)) - 1)
	var staged := _fusion_inputs.count(cid)
	if cid <= 0 or staged >= int(State.inventory.get(cid, 0)) \
			or _fusion_inputs.size() >= slots \
			or not bool(Cards.meta(cid).get("tradable", false)):
		return
	_fusion_inputs.append(cid)
	_fusion_failed = false
	_push_fusion_model()


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
	DebugLog.add("fusion sent: %d cards → %s" % [_fusion_inputs.size(),
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
var _cm_status := {}      # last 5403 for the native panel: {text, ok}


## The retail dialog opens on the catalog reply (5401), like the mailbox.
## The retail fields stay for the XML layout; the native panel (S18) reads
## catalog/offer/staged/wallet/status.
func _push_cardmaster_model() -> void:
	var model := _gui.gui.model
	var catalog: Array = []
	var native: Array = []
	var set_id := 0
	for c in _shop_cards:
		var cid := int(c.id)
		var it := _card_item(cid)
		it["shopQty"] = int(c.qty)
		catalog.append(it)
		var m := Cards.meta(cid)
		if set_id == 0:
			set_id = int(m.get("set", 0))
		var price: Array = []
		for t in m.get("price", {}):
			if int(m.price[t]) > 0:
				price.append({"type": int(t), "amount": int(m.price[t])})
		var owned := int(State.inventory.get(cid, 0))
		var unique_owned := bool(m.get("unique", false)) and owned > 0
		native.append({"id": cid, "name": Cards.name_of(cid),
			"value": int(m.get("value", 0)), "owned": owned, "price": price,
			"uniqueOwned": unique_owned,
			"canBuyTokens": not price.is_empty() and _affordable(cid)
				and not unique_owned})
	var staged: Array = []
	var staged_rows: Array = []
	var sum := 0
	for cid in _cm_given:
		for i in int(_cm_given[cid]):
			staged.append(_card_item(int(cid)))
		staged_rows.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"count": int(_cm_given[cid])})
		sum += Cards.value_of(int(cid)) * int(_cm_given[cid])
	while staged.size() < 4:
		staged.append(null)
	# What the coach can put on the table: tradable cards they own, the most
	# valuable first so a few clicks cover the price.
	var offer: Array = []
	for cid in State.inventory:
		var n := int(State.inventory[cid])
		if n <= 0 or int(cid) == _cm_selected \
				or not bool(Cards.meta(int(cid)).get("tradable", false)):
			continue
		offer.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"value": Cards.value_of(int(cid)), "owned": n,
			"staged": int(_cm_given.get(cid, 0))})
	offer.sort_custom(func(a, b): return a.value > b.value \
		or (a.value == b.value and a.id < b.id))
	var wallet: Array = []
	for t in State.wallet:
		wallet.append({"type": int(t), "amount": int(State.wallet[t])})
	var wanted_val := Cards.value_of(_cm_selected) if _cm_selected > 0 else 0
	model.set_value("cardMasterTrade", {
		"cardMasterCardExchange": catalog,
		"localCardExchange": staged,
		"cardMasterCardsPrice": wanted_val,
		"localCardsPrice": sum,
		"canBuyCards": _cm_selected > 0 and sum >= wanted_val and sum > 0,
		"selectedCard": _card_item(_cm_selected)
			if _cm_selected > 0 else null,
		"setName": _set_name_for(set_id),
		"catalog": native, "selectedId": _cm_selected,
		"offer": offer, "staged": staged_rows,
		"offered": sum, "wanted": wanted_val, "wallet": wallet,
		"status": str(_cm_status.get("text", "")),
		"statusOk": bool(_cm_status.get("ok", false))})
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
	if row is Dictionary:
		_cm_unstage(int(row.get("id", 0)))


func _cm_unstage(cid: int) -> void:
	if cid <= 0:
		return
	var cur := int(_cm_given.get(cid, 0))
	if cur <= 1:
		_cm_given.erase(cid)
	else:
		_cm_given[cid] = cur - 1
	_push_cardmaster_model()


## Native Card Master "Comprar": 5450 for the chosen card, one copy.
func _cm_buy_tokens() -> void:
	if _cm_selected <= 0 or not _priced(_cm_selected):
		return
	var w := WireWriter.new()
	w.put_i32(_shop_id)
	w.put_u16(1)
	w.put_i32(_cm_selected)
	Session.send(OP_SHOP_BUY, w.raw(), 3)
	_cm_status = {}
	DebugLog.add("buy 5450 sent: %s" % Cards.name_of(_cm_selected))


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
	DebugLog.add("barter sent: %d kinds → %s" % [_cm_given.size(),
		Cards.name_of(_cm_selected)])


## --- demonAffiliationDialog (5470 card offering) ------------------------------
## Same barter shape as the card master: stage cards in localCardExchange,
## each card's `value` becomes demon reputation server-side. Only the guild
## LEADER can affiliate and only while the guild serves no demon yet.

var _demon_staged := {}     # cid -> staged count
var _demon_status := {}     # {text, ok} — the last offering, for the panel
var _fw_shown := 0          # 22094s drawn on the lobby sky (for the smoke)
var _demon_ladder := {}     # last 27511: {demon, rows}
var _demon_offered := {}    # cid -> count in the 5470 awaiting its 5403


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
	# --- native panel (S18, src/ui/demon_panel.gd) ---------------------------
	var owned: Array = []
	for cid in State.inventory:
		var m := Cards.meta(int(cid))
		if not bool(m.get("tradable", false)) or int(State.inventory[cid]) <= 0:
			continue
		owned.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"qty": int(State.inventory[cid]) - int(_demon_staged.get(cid, 0)),
			"value": int(m.get("value", 0))})
	owned.sort_custom(func(a, b): return a.value > b.value or (a.value == b.value and a.id < b.id))
	var basket: Array = []
	for cid in _demon_staged:
		basket.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"qty": int(_demon_staged[cid]), "value": Cards.value_of(int(cid))})
	var ladder: Array = []
	if int(_demon_ladder.get("demon", -1)) == _demon_id:
		for r0 in _demon_ladder.get("rows", []):
			ladder.append({"name": str(r0.get("name", "?")),
				"points": int(r0.get("quarterly", 0))})
	var demons: Array = []
	for did in _lobby_demons():
		demons.append({"id": did, "name": _demon_name(did)})
	_gui.gui.model.set_value("demonNative", {
		"demon": _demon_id, "demonName": _demon_name(_demon_id),
		"canChoose": int(State.guild.get("demon_id", 0)) == 0,
		"demons": demons, "owned": owned, "basket": basket, "total": sum,
		"ladder": ladder, "status": _demon_status,
		"pending": _awaiting_offer})


## The demons a clan can serve: the lobby's demon totems (kind 11, desc =
## demon id).
func _lobby_demons() -> Array:
	var out: Array = []
	for w in LOBBY_WORLDS:
		for id in Elements.for_world(w):
			var e: Dictionary = Elements.for_world(w)[id]
			if int(e.type) != 11:
				continue
			var did := int(_desc_fields(str(e.get("desc", "")))[0])
			if did > 0 and not did in out:
				out.append(did)
	out.sort()
	return out


## Retail names demons by Roman numeral (afg_1.kn): demon 16 is "XVI".
func _demon_name(id: int) -> String:
	if id < 1 or id > 3999:
		return I18n.t("demon.name", {"n": str(id)})
	var vals := [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
	var syms := ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
	var n := id
	var out := ""
	for i in vals.size():
		while n >= vals[i]:
			out += syms[i]
			n -= vals[i]
	return I18n.t("demon.name", {"n": out})


## 27510 [i16 demon][i16 flag][i32 startRank] → 27511: the clans serving it.
func _demon_request_ladder() -> void:
	if _demon_id <= 0:
		return
	var w := WireWriter.new()
	w.put_i16(_demon_id)
	w.put_i16(0)
	w.put_i32(0)
	Session.send(OP_DEMON_LADDER, w.raw(), 2)


## Opened from the clan tab: the clan's demon, or the first one to choose.
func _open_demon_native() -> void:
	var cur := int(State.guild.get("demon_id", 0))
	var demons := _lobby_demons()
	_demon_id = cur if cur > 0 else (int(demons[0]) if not demons.is_empty() else -1)
	_demon_staged = {}
	_demon_status = {}
	_push_demon_model()
	_demon_request_ladder()
	_gui.open("demonAffiliationDialog")


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
	_demon_offered = _demon_staged.duplicate()
	_demon_status = {"ok": true, "text": I18n.t("demon.sent")}
	Session.send(OP_DEMON_OFFER, wr.raw(), 3)
	_push_demon_model()
	DebugLog.add("demon %d offering sent: %d card(s)" % [_demon_id, total])


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
	# --- native panel (S18, src/ui/exchange_panel.gd) ------------------------
	var staged_mine: Dictionary = _ex.get("staged", {}).get(mine, {})
	var owned: Array = []
	for cid in State.inventory:
		if not bool(Cards.meta(int(cid)).get("tradable", false)):
			continue
		var left := int(State.inventory[cid]) - int(staged_mine.get(cid, 0))
		if left > 0:
			owned.append({"id": int(cid), "name": Cards.name_of(int(cid)), "qty": left,
				"value": Cards.value_of(int(cid))})
	owned.sort_custom(func(a, b): return a.name < b.name)
	model.set_value("exchangeNative", {
		"other": str(_ex.get("other_name", "?")),
		"accepted": bool(_ex.get("accepted", false)),
		"owned": owned, "mine": _ex_rows(mine), "theirs": _ex_rows(other),
		"myValue": _ex_staged_value(mine), "theirValue": _ex_staged_value(other),
		"myReady": bool(_ex.get("ready", {}).get(mine, false)),
		"theirReady": bool(_ex.get("ready", {}).get(other, false)),
		"full": staged_mine.size() >= EX_MAX_STAGED, "status": _ex_status})


## One side's staged cards as table rows.
func _ex_rows(side: int) -> Array:
	var out: Array = []
	var st: Dictionary = _ex.get("staged", {}).get(side, {})
	for cid in st:
		out.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"qty": int(st[cid]), "value": Cards.value_of(int(cid)) * int(st[cid])})
	return out


const EX_MAX_STAGED := 5     # server maxStagedPerSide, the client's 5 slots
var _ex_status := ""         # last refusal (5113), shown in the panel


## One more of card `cid` on my side: 5105 carries the TOTAL quantity (the
## server replaces the staged entry).
func _ex_add_one(cid: int) -> void:
	if _ex.is_empty() or not _ex.get("accepted", false):
		return
	var mine := int(_ex.get("my_side", 0))
	var cur := int(_ex.get("staged", {}).get(mine, {}).get(cid, 0))
	if cur + 1 > int(State.inventory.get(cid, 0)):
		return
	_ex_status = ""
	var wr := WireWriter.new()
	wr.put_i64(int(_ex.id))
	wr.put_i32(cid)
	wr.put_u16(cur + 1)
	Session.send(OP_EX_ADD, wr.raw(), 3)


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


## --- Kanodo (sphere board) --------------------------------------------------
## Roster → Kanodo opens the board of the selected EVOLUTION fighter (type 2 —
## classic fighters carry no sphere tail on the wire). Buying is optimistic
## like retail: 23009 is fire-and-forget; the server validates reachability,
## XP and barrier cards and persists silently. We mirror the same rules for
## what can be clicked (lit frontier = server's Reachable flood).
var _kanodo_lines: Array = []   # the picked sphere's details (panel text)
var _kanodo_can_buy := false
var _kanodo_status := ""

func _open_kanodo(fid: int) -> void:
	var f: Variant = _fighter_by_id(fid)
	if f == null or int(f.get("type", 1)) != 2:
		_log_line("[i]%s[/i]" % I18n.t("kanodo.evo_only"))
		return
	_kanodo_fid = int(f.id)
	_kanodo_pick = {}
	_kanodo_lines = []
	_kanodo_can_buy = false
	_kanodo_status = ""
	_refresh_kanodo()
	_gui.open("kanodoDialog")


func _fighter_by_id(fid: int) -> Variant:
	for fr in State.roster:
		if int(fr.get("id", -1)) == fid:
			return fr
	return null


## The `kanodo` model the native panel (src/ui/kanodo_panel.gd) draws.
func _refresh_kanodo() -> void:
	var f: Variant = _fighter_by_id(_kanodo_fid)
	if f == null:
		_gui.close("kanodoDialog")
		return
	var board := int(f.get("board", 0))
	if board == 0:
		board = Kanodo.board_id_for_breed(int(f.get("breed", 0)))
	var cursor := Vector2i(int(f.get("sphere_x", 0)),
		int(f.get("sphere_y", 0)))
	if cursor == Vector2i.ZERO:
		var root: Array = Kanodo.boards.get(board, {}).get("root", [0, 0])
		cursor = Vector2i(int(root[0]), int(root[1]))
	_gui.gui.model.set_value("kanodo", {"fid": _kanodo_fid,
		"name": str(f.get("name", "?")), "xp": int(f.get("xp", 0)),
		"total": int(f.get("total_xp", 0)), "board": board,
		"owned": f.get("spheres", []), "cursor": [cursor.x, cursor.y],
		"lines": _kanodo_lines, "canBuy": _kanodo_can_buy,
		"status": _kanodo_status})


func _on_sphere_pick(n: Dictionary, reachable: bool) -> void:
	_kanodo_pick = n
	_kanodo_status = ""
	var kind := String(n.get("kind", "empty"))
	var lines := [I18n.t("kanodo.node", {"id": int(n.id), "x": int(n.x),
		"y": int(n.y), "kind": I18n.t("kanodo.kind." + kind)})]
	if int(n.get("spell", 0)) != 0:
		lines.append("→ %s" % Spells.name_of(int(n.spell)))
	if int(n.get("pool", 0)) != 0:
		lines.append(I18n.t("kanodo.pool", {"id": int(n.pool)}))
	if n.get("barrier", []).size() > 0:
		var names := []
		for c in n.barrier:
			names.append(Cards.name_of(int(c)))
		lines.append(I18n.t("kanodo.barrier",
			{"list": ", ".join(names)}))
	if n.get("fx", []).size() > 0:
		lines.append(I18n.t("kanodo.fx", {"fx": str(n.fx)}))
	lines.append(I18n.t("kanodo.cost", {"xp": int(n.get("xp", 0))}))
	if not reachable:
		lines.append(I18n.t("kanodo.unreachable"))
	_kanodo_lines = lines
	_kanodo_can_buy = reachable
	_refresh_kanodo()


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
			_kanodo_status = I18n.t("kanodo.no_card")
			_refresh_kanodo()
			return
	var cost := int(_kanodo_pick.get("xp", 0))
	if f.spheres.has(int(_kanodo_pick.id)):
		cost /= 10   # re-purchase discount (afb_1 case 16926)
	if int(f.get("xp", 0)) < cost:
		_kanodo_status = I18n.t("kanodo.no_xp")
		_refresh_kanodo()
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
	_kanodo_status = I18n.t("kanodo.bought", {"id": int(_kanodo_pick.id), "cost": cost})
	_log_line(_kanodo_status)
	_kanodo_pick = {}
	_kanodo_lines = []
	_kanodo_can_buy = false
	_refresh_kanodo()


## --- Player exchange (5101-5116) --------------------------------------------
## /trade <name> invites; 5102 asks the target; 5104 accepted opens the pane.
## List (top) = the trade table ("You:/Name:" rows — click own row to unstage,
## 5107); List2 (bottom) = own tradable inventory — click rows to stage (5105
## qty 1). Act = ready toggle (5109), Alt = cancel (5111). Both-ready commits
## server-side and ends with 5114.
func _invite_exchange(cname: String) -> void:
	var tid: int = _coach_id_by_name(cname)
	if tid < 0:
		_log_line("[color=red]%s[/color]" % I18n.t("watch.not_found", {"name": cname}))
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
	_open_firework_retail()


func _open_firework_retail() -> bool:
	_fw_elem = _elem_id
	_fw_reset()
	_push_firework_model()
	return _gui.open("fireworkDialog") != null


func _push_firework_model() -> void:
	if _fw_slots.is_empty():
		_fw_reset()
	var model := _gui.gui.model
	# --- native launcher (S18, src/ui/firework_panel.gd) ---------------------
	var used := {}
	var slots_n: Array = []
	for i in _fw_slots.size():
		var cid := int(_fw_slots[i].get("cid", 0))
		if cid > 0:
			used[cid] = int(used.get(cid, 0)) + 1
			slots_n.append({"i": i, "id": cid, "name": Cards.name_of(cid),
				"delay": int(_fw_slots[i].get("delay", 0))})
	var owned: Array = []
	for cid in State.inventory:
		var meta := Cards.meta(int(cid))
		if int(meta.get("type", 0)) != 25:
			continue
		owned.append({"id": int(cid), "name": Cards.name_of(int(cid)),
			"qty": int(State.inventory[cid]) - int(used.get(cid, 0)),
			"kind": int(meta.get("fwType", 0))})
	owned.sort_custom(func(a, b): return a.id < b.id)
	model.set_value("fireworkNative", {"owned": owned, "slots": slots_n,
		"max": _fw_slots.size()})
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
	var e: Dictionary = _element_info(_fw_elem)
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


## --- Card Master shop --------------------------------------------------------
## 5401 catalogue → list of cards w/ names+prices. Buy sends 5450
## [i32 shopId][i16 n]{i32 cardId}; Exchange opens the barter pane (5400).
func _open_shop(d: Dictionary) -> void:
	_shop_id = int(d.get("shop_id", -1))
	_shop_cards = d.get("cards", [])
	_cm_given = {}
	_cm_status = {}
	# the native panel shows the first card's detail straight away
	_cm_selected = int(_shop_cards[0].id) if not _shop_cards.is_empty() else -1
	# the native Card Master (S18) is the only shop UI
	_gui.open("cardMasterDialog")
	_push_cardmaster_model()


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

