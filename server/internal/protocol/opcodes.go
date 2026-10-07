package protocol

// Wire opcodes used during the connection/login handshake and early world
// entry. Full opcode inventory lives in client/analysis/opcode_map.csv.
const (
	// Lifecycle (client -> server)
	OpDisconnect             = 1     // C2S: empty — DisconnectionNotificationMessage (graceful quit)
	OpTutorialChangeInstance = 4517  // C2S: empty (arch 3) — tutorial/instance-ready ack
	OpDestroyCoach           = 27529 // C2S: empty (arch 2) — "Détruire le coach" (delete coach)
	OpStatisticUpdate        = 22003 // C2S (arch 2): [i16 statId][i8 flag][i16 value] achievement/stat counter
	// OpStatisticRequest is sent (empty) when the achievement tab is opened. The
	// reply (OpStatisticData) is what actually OPENS the tab client-side - handler
	// A pops "achievementDialog" from its 22002 case - so leaving this unanswered
	// makes the achievements button do nothing at all.
	OpStatisticRequest = 22001 // C2S anp_0 (arch 2): empty - "send me my criteria"

	// Connection / auth (client -> server unless noted)
	OpClientVersion        = 7    // C2S: [u8 0x02][u16 ver=70][u8 len][ascii build]
	OpPing                 = 107  // both ways: latency/clock-sync handshake
	OpClientAuthentication = 1025 // C2S: [u8 loginLen][login][u8 passLen][pass] (plaintext)

	// Server -> client
	OpClientAuthResult       = 1024 // S2C: [u8 resultCode]
	OpWorldServerUnavailable = 1026 // S2C: empty
	OpInvalidClientVersion   = 8    // S2C: required version bytes

	// Coach creation / world entry
	OpCoachCreationRequest = 2048 // S2C: empty — shows coach-creation screen
	OpCoachCreation        = 2049 // C2S: [u8 nameLen][name][u8 skin][u8 hair][u8 sex]
	OpCoachCreationResult  = 2050 // S2C: [u8 resultCode]
	OpCoachInformations    = 2052 // S2C: serialized LocalCoach (existing coach -> lobby)
	OpEnterInstance        = 4600 // S2C: [f32 x][f32 y][i16 alt][i16 mapId][u8 dynamic] — renders world/lobby

	// Movement (overworld)
	OpActorMovement        = 4500 // S2C: [i64 actorId] + n×[i32 x][i32 y][i16 z]
	OpCoachMovementRequest = 4501 // C2S: n×[i32 x][i32 y][i16 z] (no count; from length)

	// Actors
	OpActorSpawn   = 4096 // S2C: (zlib-wrappable) [i32 count] + per actor
	OpActorDespawn = 4098 // S2C: [i32 count] + i64 ids
	OpActorAppear  = 4102 // S2C: [u8 count]{i64 id,i32 x,i32 y,i16 z,u8 dir} — inserts a fight actor into the render list + shows it (aEV/qg_2.g)

	// Interactive elements (overworld NPCs, Zaaps, Cardmasters) + Zaap teleport.
	// Elements are defined in each world's env layer, but the client CLEARS them
	// on ENTER_INSTANCE (4600); the server must (re)spawn the ones to show via 200
	// (by env instanceId). See internal/game/zaap.go + docs/OVERWORLD-MAP.md.
	OpInteractiveElementSpawn  = 200 // S2C rz_2: [i16 count]{[i64 instanceId][i16 len][partTableBlob]}
	OpInteractiveElementAction = 201 // C2S bd_2: [i64 instanceId][i16 actionOrdinal] — element click
	// OpInteractiveElementDespawn removes elements the client can no longer
	// resolve, i.e. whose env chunk has scrolled out of range. Pairs with 200; see
	// game.refreshWorldElements for why elements must be streamed, not bulk-sent.
	OpInteractiveElementDespawn = 206  // S2C acc_2: [i16 count]{[i64 instanceId]}
	OpZaapTeleport              = 4512 // C2S Gs: [i32 cardTemplateId] — use a Zaap card; server replies EnterInstance(4600)
	// OpInstanceReady MUST be sent after every overworld EnterInstance(4600).
	// A Zaap request (4512) sets a movement lock client-side (auv_0) and this is
	// the ONLY thing that clears it — there is no timeout, so omitting it leaves
	// the coach permanently unable to walk. It also fires the client's
	// walked-onto-element triggers. See game.Session.sendEnterOverworld.
	OpInstanceReady = 4516 // S2C yu_1: empty — instance ready / movement unlock
	// OpAchievementUnlocked announces one unlock. Unlike OpStatisticData below,
	// this IS safe to push unsolicited: its handler zN is registered permanently
	// at login and only raises a toast. A hidden achievement is a no-op — zN gates
	// its whole body on !isHidden().
	OpAchievementUnlocked = 22000 // S2C ade_0: [i16 achievementId]

	// OpStatisticData is the criteria snapshot. NEVER send it unsolicited: the
	// permanently-registered tutorial handler (asA, added at login by by_2) pops
	// the tutorial-guide dialog on receipt. It is safe, and required, ONLY as the
	// reply to OpStatisticRequest below - opening the achievement tab registers
	// handler A, and the client dispatches frames newest-handler-first
	// (fh_2: qe.add(0,...), loop breaks on the first handler returning false), so
	// A consumes the frame and asA never sees it. Unsolicited criteria changes go
	// through the 2052 coach descriptor instead.
	OpStatisticData = 22002 // S2C ls_0: [i32 byteLen]{[i16 crit][i16 val]}

	// Statistics
	OpPlayerStatisticsReport = 2400 // S2C: [u16 blobLen][stats field-map blob]

	// Inventory / equipment
	OpCoachInventoryUpdate        = 5200 // S2C: 4 sections (addEquip, removeShort, updInv, ints)
	OpCoachEquipmentUpdateRequest = 5201 // C2S: 14×i32 slot references
	OpCoachInventoryUpdateRequest = 5203 // C2S: [u16 count]+i64 uids — cards REMOVED from the inventory (client fh_0/sj_1.yG); the uids are client-local (eb_1 assigns uq_1.ahR()), so they cannot be resolved server-side
	OpAddToTome                   = 5204 // C2S ajm_2: [i32 templateId] — the card context-menu "inscribe in grimoire"; the client marks isInTome locally, no reply expected
	OpCoachEquipmentUpdate        = 5202 // S2C: broadcast equipment change

	// Shop / economy (Card Master token purchase + wallet)
	OpWalletUpdate  = 4001 // S2C: [i8 count]{i8 currencyType, i32 amount} full wallet sync
	OpShopOpen      = 5300 // C2S: (empty) open Card Master / request catalog
	OpShopCatalog   = 5401 // S2C: [i8 flag][i32 shopId]{i32 cardId, i16 qty} offering
	OpShopBuy       = 5450 // C2S: [i32 shopId][i16 N]{i32 cardId} buy with tokens
	OpShopResult    = 5403 // S2C: [i8 result][i8 count]{i8 currencyType, i32 amount} new balance
	OpShopBarter    = 5400 // C2S: [i32 exId][i16 N]{i32 wantedId}[i16 M]{i32 givenId,i16 qty}
	OpFusionRequest = 5490 // C2S: [i32 count]{i32 cardId} (ids reversed) fuse cards
	OpFusionResult  = 5491 // S2C: [i8 result][i32 obtained][i32 notObtained][i32 recovered]

	// Card exchange / trading
	OpExchangeInvite            = 5101 // C2S: [i64 targetId]
	OpExchangeInvitationRequest = 5102 // S2C: [i64 exId][i64 inviterId][u8 len][name]
	OpExchangeAnswer            = 5103 // C2S: [i64 exId][i8 accept]
	OpExchangeConfirmation      = 5104 // S2C: [i8 result][i64 exId][i64 otherId]
	// The exchange block is NOT contiguous in 2.70 — it was renumbered from the
	// 2006-era layout, and the old numbering (5105..5112 in order) would have the
	// server sending 5109/5111, which are C2S in this build and absent from the
	// client's decode factory (gz_1) entirely. Each entry below names the client
	// class that proves it.
	OpExchangeAddCard     = 5105 // C2S ua_2/pv_2: [i64 exId][i32 refCardId][i16 qty]
	OpExchangeRemoveCard  = 5107 // C2S wd_0/pv_2: same shape as 5105
	OpExchangeSetReady    = 5109 // C2S ahJ:       [i64 exId] (toggle)
	OpExchangeCardAdded   = 5110 // S2C asH:       [i64 exId][i8 userIdx][i32 refCardId][i16 qty]
	OpExchangeCancel      = 5111 // C2S any:       [i64 exId]
	OpExchangeCardRemoved = 5112 // S2C aaz_1:    same shape as 5110
	// OpExchangeError is new in 2.70: the client shows a specific message for
	// code 1 ("that unique card is already there") and the linked-card refusal
	// for anything else. See pg_1 case 5113.
	OpExchangeError     = 5113 // S2C Or:   [i8 code][i64 exId]
	OpExchangeEnd       = 5114 // S2C aqX:  [i8 reason][i64 exId] (0=success,1=cancel)
	OpExchangeUserReady = 5116 // S2C dl_0: [i64 exId][i8 userIdx]

	// Exchange end reasons
	ExchangeEndSuccess = 0
	ExchangeEndCancel  = 1

	// Card object on the wire: [i32 refCardId][i64 uid][i8 flags]
	CardFlagLocked = 1
	CardFlagCursed = 2

	// Fighters / teams
	OpFighterCreate           = 6001 // C2S: [u8 flag][i16 slot][i16 len][et_2 blob]
	OpFighterCreateResult     = 6000 // S2C: [u8 result](+coachId,fighterId,blob,flag,slot)
	OpFighterDelete           = 6003 // C2S: [i64 fighterId][i16 slot]
	OpFighterDeleteResult     = 6002 // S2C: [u8 result][i64 fighterId][i64 secondaryId]
	OpFighterInformationList  = 6006 // S2C: [i64 leadId][u8 count]{i64 id,u16 len,blob}
	OpUpdateFighterInventory  = 6011 // C2S: [i64 fighterId][i16 teamId][i16 len][cards][i16 len][spells]
	OpUpdatedFighterInventory = 6010 // S2C: [i64 fighterId][i8 result](+[i16 len][cards][i16 len][spells])
	OpFighterAssignTeam       = 6013 // C2S: [i64 fighterId][i16 srcTeam][i16 dstTeam][i64 am] — qp_1 drag/assign; dst=-1 removes
	// OpFighterAssignedTeam acks 6013: [i8 status], and on status 0 the request
	// echoed verbatim — [i64 fighterId][i16 srcTeam][i16 dstTeam][i64 am] — plus a
	// trailing [i64 effectiveFighterId] (`aoi.cKH`/`aCG`). `dx_2` case 6014 then
	// removes the fighter from preset srcTeam (`at(aCE).l(K)` — bMJ is the preset's
	// fighter->coach map and l() = dv = remove), re-keys the entity when K!=aCG,
	// and files `aCG` under coach `am` in the CURRENTLY OPEN preset
	// (`IF().II().j(aCG, mb)`). aCF is decoded but never read: the destination is
	// the open preset, not a wire field. aCG=-1 makes `sw_1.j` skip the re-add —
	// the "pure removal" sentinel, since `j` refuses -1 with an error log and no
	// put. We never re-id fighters, so aCG = fid on assigns and -1 on removes.
	OpFighterAssignedTeam = 6014 // S2C aoi
	// OpTeamPresetSaved is the reply to 6021: [i8 status], and on status 0 the
	// full saved preset follows. `aic_0` reads NOTHING after a non-zero status, so
	// an error frame is exactly one byte.
	//
	// Status 25 is the client's own "this name is taken" case
	// ("error.teamManagement.teamNameExist"); any other non-zero shows the generic
	// "error.teamManagement.teamPresetSave".
	// OpTeamUpCoachGone tells the surviving member of a 2v2 pair that its partner
	// dropped: [i8 status], and `dx_2` shows "error.teamManagement.coachDisconnected"
	// regardless of the value - the opcode is the message.
	OpTeamUpCoachGone = 6029 // S2C OJ
	OpTeamPresetSaved = 6020 // S2C aic_0
	OpTeamPresetSave  = 6021 // C2S: [sw_1 blob][u8 pad]
	// OpTeamPresetDeleted acknowledges a delete: [i8 status] and, when status==0,
	// [i16 teamId] (agH reads the id ONLY on success).
	//
	// Required, not cosmetic. Re-sending the preset list (6030) does NOT remove a
	// deleted preset: `dx_2` case 6030 calls `bs_0.IF().IG()`, which purges only
	// the presets where `afK()` is false (`bMK.size() > 1`, i.e. the DUO ones) and
	// keeps the normal ones, then merges the payload into a map keyed by preset
	// id. A deleted preset is absent from that payload, so nothing ever removes
	// it and it stays on screen until the player relogs. 6022 is what calls
	// `bs_0.IF().as(id)`.
	OpTeamPresetDeleted     = 6022 // S2C agH
	OpTeamPresetDelete      = 6023 // C2S: [i16 teamId]
	OpTeamPresetListRequest = 6031 // C2S: (empty) request team presets
	// --- 2v2 team formation (60xx) -------------------------------------------
	// The production path, reachable from the team panel: "Creer une equipe 2VS2"
	// (hu_2 case 16636) opens team2vs2NameDialog, the teammate is picked from the
	// coach's own FRIEND LIST (case 16635), and the named pair is sent as 6024.
	// Not to be confused with the 26313 XvsX request, which exists only as the
	// `Test` Lua binding XvsXInvitation and has no UI.
	OpTeamUpRequest    = 6024 // C2S ir_0 (arch 2): [u8 len][teamName][i64 inviterCoachId][i64 invitedCoachId]
	OpTeamUpInvitation = 6025 // S2C dy_2: [u8 len][teamName][u8 len][inviterName][i64 inviterCoachId][i64 invitedCoachId]
	OpTeamUpAnswer     = 6026 // C2S abB (arch 2): [i8 accept][u8 len][teamName][i64 inviterCoachId][i64 invitedCoachId][i16 reason]
	OpTeamUpRefused    = 6027 // S2C lk_0: empty - "Le coach a refuse la creation, ou est indisponible."
	OpTeamUpAccepted   = 6028 // S2C ahh_2: empty - both clients open the fighter picker (hu_2.li())
	OpTeamPresetList   = 6030 // S2C: [u8 presetCount]{sw_1}[u8 coachCount]{...}

	// Fight lifecycle
	OpCreateFight            = 8000 // S2C: the fight-presentation blob
	OpStartPresentation      = 8010 // S2C: empty
	OpReadyForPlacementAck   = 8012 // S2C: [i64 coachId]
	OpEndPresentation        = 8018 // S2C: empty
	OpStartPlacement         = 8020 // S2C: empty
	OpMoveToFreePlacement    = 8022 // S2C: [i64 fighterId][i32 x][i32 y][i16 z]
	OpReadyForObservationAck = 8024 // S2C: [i64 coachId]
	OpEndPlacement           = 8028 // S2C: empty
	OpStartObservation       = 8030 // S2C: empty
	OpReadyForActionAck      = 8032 // S2C: [i64 coachId]
	OpEndObservation         = 8038 // S2C: empty
	OpStartAction            = 8040 // S2C: empty
	OpNewTableTurnBegin      = 8100 // S2C: [i32 uid][i32 -1][i8 turn][i32 eventId]
	OpFighterTurnBegin       = 8104 // S2C: [i32 uid][i32 -1][i64 fighterId]
	OpFighterTurnEnd         = 8106 // S2C: [i32 uid][i32 -1][i64 fighterId]

	// Combat actions
	OpFighterMoveInFightReq = 4503 // C2S: [i64 fighterId] + path {i32 x,i32 y,i16 z}
	OpFighterMoveInFight    = 4524 // S2C: [i32 uid][i32 -1][i64 fighterId] + path
	OpFighterDirChangeReq   = 4521 // C2S lr_2 (arch 3): [i64 fighterId][u8 dir] — visual facing (qc_0), cosmetic
	OpFighterChangeDir      = 4522 // S2C u_0: [i32 uid][i32 -1][i64 fighterId][u8 dir]
	// Spell cast and in-fight CARD use are two DISTINCT actions with byte-identical
	// 22-byte requests (arch 3), which is how they were previously conflated (B-047):
	// the client's alx_2 holds a spell (yp_2) and sends 8109; abt_1 holds a card
	// (ve_0) and sends 8107. Their replies share one layout too.
	OpSpellCastRequest      = 8109 // C2S mc_2: [i64 fighterId][i32 spellId][i32 x][i32 y][i16 z]
	OpFighterCardUseRequest = 8107 // C2S sg_2: [i64 fighterId][i32 cardId][i32 x][i32 y][i16 z]
	OpFighterCardUse        = 8108 // S2C arn_0: header+[i64 user][i32 cardId][i8 miss](+crit+target); cardId resolved via the client card registry
	OpSpellCast             = 8110 // S2C: header+[i64 caster][i32 spell][i8 miss](+crit+target)
	OpCloseCombatRequest    = 8111 // C2S: [i64 fighterId][i32 x][i32 y][i16 z] (client aso_0, weapon attack)
	OpCloseCombat           = 8112 // S2C: header+[i64 attacker][i8 miss](+crit+target) (aAD, 17/28B)
	OpRunningEffect         = 8120 // S2C: header+[i8 now][i8 trig][i32 Nx][i32 effId][i16 len][blob]
	OpActionSequenceExecute = 8200 // S2C: empty (flush barrier)
	OpEffectAreaAction      = 6200 // S2C jD: header+[i8 entering][i64 areaInstanceId][i64 templateId][i64 fighterId] — plays a special cell / glyph animation
	// 8121 rq_2 ATTACHES a scripted effect to a fighter as a persistent buff
	// (of_1 adds it to the target's effect list and flags "hasBuff"); it never
	// EXECUTES one. Running an effect — including MapDestruction (mh_2 action 117,
	// sudden death) — goes through OpRunningEffect (8120) instead, whose handler
	// instantiates it and calls run(). Defined for the record; not emitted.
	OpRunScriptedEffect = 8121  // S2C rq_2: [i32 mh_2 actionId][i16 blobLen][blob][i64][i16][i8]
	OpFighterDies       = 4520  // S2C: [i32 uid][i32 -1][i64 fighterId]
	OpFighterTackled    = 4506  // S2C: [i32 uid][i32 -1][i64 tackledId][i64 tacklerId] (acg, 24B)
	OpEndFight          = 8300  // S2C: header+[i8 flee]+result
	OpEndFightDone      = 26321 // C2S: empty (ack result screen) (client nv_0, NOT 4321)

	// Mid-fight reconnect / resume. On reconnect the server pushes the empty
	// QUESTION (26333, client uz_0) while the coach is in the lobby; the client
	// shows a Yes/No "reconnectionInFightQuestion" dialog (pq_1) and replies with
	// the ANSWER (26334, client aiw_1) = 1 accept / 0 decline. On accept the server
	// replays the fight-presentation sequence (see sendFightResync).
	OpReconnectFightQuestion = 26333 // S2C: empty — "resume your fight?"
	OpReconnectFightAnswer   = 26334 // C2S (arch 2): [i8 accept] — 1=resume, 0=decline

	// Spectator. The client queries whether a coach is in a spectatable fight
	// (2260 py_0 → 2261 wv_2), and if so offers "enterSpectatorMode" which sends
	// the join (26331 x_0). 26332 (azb_0) tells a spectator's client to tear down
	// its local fight view.
	OpSpectateQuery    = 2260  // C2S: [i64 coachId] — is this coach in a spectatable fight?
	OpSpectateReply    = 2261  // S2C: [i8 spectatable]
	OpSpectateJoin     = 26331 // C2S (arch 2): [i64 coachId] — attach as a spectator to that coach's fight
	OpSpectateTeardown = 26332 // S2C: empty — local fight-view teardown

	// Direct challenge ("Proposer un entraînement" / training fight): coach A
	// directly challenges coach B. The handle carried on the wire (invitation /
	// accepted / cancelled) is the CHALLENGER's coach id; after B accepts, both
	// coaches confirm a team with OpFightReadyConfirm (26303) and the fight starts.
	OpChallengeInvite     = 26301 // C2S (arch 2): [i64 targetCoachId][i8 evoFlag] (hk_1)
	OpChallengeInvitation = 26300 // S2C: [i64 handle][i8 outgoing][i8 evo][i8 nNames]{[i32 len][name]} (wu_2)
	OpChallengeAccept     = 26305 // C2S (arch 2): [i64 handle][i8 evoFlag] (vT)
	OpChallengeAccepted   = 26302 // S2C: [i64 handle][i8 evo] (pu_1) — both open the team panel
	OpChallengeDecline    = 26307 // C2S (arch 2): [i64 handle] (mz_0) — decline / cancel / withdraw
	OpChallengeCancelled  = 26304 // S2C: [i64 handle] (gz_0) — the other side backed out
	// OpFightCreationError tells the client a fight could not be started and pops
	// its pending fight-setup states (do_2 / wg_2 / B). Without it, accepting an
	// overworld challenge leaves those states dangling with no feedback.
	OpFightCreationError = 26310 // S2C nx_1: [i64 fightId][i8 errorCode]

	// Fight-creation error codes carried by OpFightCreationError (client zN.M).
	FightErrUnableToCreate = 34 // "Impossible de créer le combat !"
	FightErrInternal       = 38
	FightErrNoInstance     = 39
	FightErrCancelled      = 40
	// The retail SERVER re-validated the roster rules the client also checks
	// locally, and the client still renders every one of these codes in the same
	// switch as 34/38/39/40 above (zN.java:214-322). Implementing them therefore
	// RESTORES retail behaviour rather than diverging from it - which is the
	// opposite of what this project previously assumed about the team budget.
	FightErrInvalidFightersCount = 45 // "Le nombre de combattants est invalide"
	FightErrInvalidTeamBudget    = 46 // "error.fight.creation.invalidTeamBudget"
	FightErrTooManySameBreed     = 63 // "tooMuchSameBreedFighters"
	FightErrMatchfinderOccuring  = 69 // "Action impossible pendant une recherche de combat."
	FightErrNoIsland             = 72 // "error.guild.noIsland" — the clan-island Zaap when the clan holds none
	FightErrMinEvolutionBudget   = 78 // "invalidMinimalEvolutionTeamBudget"

	// OpErrorNotice is the BARE zN.M() code toaster (25000, client `az`): [i8
	// code]. 26310 wraps the same code table in frame cleanup; 25000 is for
	// refusals outside the fight-creation handshake where no pending state needs
	// popping (e.g. the clan-island Zaap refusal).
	OpErrorNotice = 25000 // S2C az: [i8 errorCode] -> zN.M(code) toast

	// Fireworks (the overworld "cardUsingSwitch" element, env type 12).
	OpFireworkShow   = 22094 // S2C la_1: [i32 cardId][i32 x][i32 y][i32 z][i64 elementId]
	OpFireworkLaunch = 22095 // C2S axf_0: [i32 cardId][i32 x][i32 y][i64 elementId]

	// Mailbox (the overworld mailbox element, env type 2). The client opens the
	// mailbox dialog ONLY when it receives OpMailList — replying to OpMailListRequest
	// is mandatory, an empty list is fine. See internal/game/handlers_mail.go.
	OpMailListRequest = 15000 // C2S ajs_0 (arch 3): empty — "open my mailbox"
	OpMailList        = 15001 // S2C ayV: [i16 count]{mail record} — opens the dialog
	OpMailSendResult  = 15003 // S2C Eh: [i64 result][mail record] (>0 ok, -2 full)
	OpMailDelete      = 15004 // C2S ads_0 (arch 3): [u8 count][i64 mailId]×count
	OpMailNewNotice   = 15005 // S2C wt_2: [u8 newMailCount] — "you have new mail" toast
	OpMailTakeCards   = 15006 // C2S akk_1 (arch 3): [i64 mailId](+1 pad byte)
	OpMailCardsTaken  = 15007 // S2C cb: [i64 mailId][i64 coachId][u8 n]{i32 cardId}
	OpMailSend        = 539   // C2S F (arch 3): a full mail record
	OpMailCheckName   = 15506 // C2S rr_1 (arch 2): [u8 len][utf8 coachName]
	OpMailNameResult  = 15507 // S2C afj_2: [i64 coachId] — 0 = no such coach

	// Mail send results carried by OpMailSendResult.
	MailSendOK   = 1  // any value > 0 = accepted
	MailSendFull = -2 // recipient's mailbox is full

	// Demon totems (env type 11) and tournament totems (env type 13). Clicking
	// either opens NOTHING by itself — the dialog is opened purely by the server's
	// reply, so without these the totems are inert.
	OpDemonLadderRequest = 27510 // C2S aid_1 (arch 2): [i16 demonId][i16 flag][i32 startRank] — per-demon drill-down
	OpDemonLadder        = 27511 // S2C anc_0: [i16 demonId][i16 flag][i32 start][i32 N]{guild,i64,i64,i64}[i64 affil]
	OpTournamentCalReq   = 17002 // C2S yq_1 (arch 3): empty
	OpTournamentCalendar = 17003 // S2C awa_0: [i16 count]{[i32 typeId=4][qr_0 tournament event]}
	OpTournamentListReq  = 28601 // C2S wa_2 (arch 2): empty
	OpTournamentList     = 28602 // S2C ng_2: [i32 count]{[i64 tid][u8 search][i8 status][i16 defId][u8 regOpen][i32 fp+i32[]][3×str32][u8 kind]}
	// Tournament registration + bracket. Registration is on the game/calendar arch
	// (3), not the tournament arch (2). The bracket reply IL(28650) is an empty tree
	// here (no live match graph): the client shows "tree unavailable" and closes.
	OpTournamentRegister      = 4607  // C2S aik_0 (arch 3): [i64 tid][i64 coachId][i16 teamPreset][i32 cardId]
	OpTournamentRegisterReply = 28608 // S2C dy_0: [i64 tid][i8 errorCode] (0=accepted, 2=full, else refused)
	// Tournament opponent search — the third member of the "ready up and look for
	// an opponent" pattern (client frame ds_2, twin of vu_1 / wp_0). It is NOT a
	// clean twin: the request, cancel and result all carry a tournament id, and
	// the error has a SECOND byte (kw_1.pa(), fed to zN.M() when code == 2).
	// Sent by the Tournois tab AND by Légendes (which passes preset 9999).
	OpTournamentSearchCancel       = 28609 // C2S bt_0 (arch 2): [i64 tid][i64 coachId][i16 preset]
	OpTournamentSearchCancelResult = 28610 // S2C de_0: [i8 accepted]
	OpTournamentSearchRequest      = 28611 // C2S ly_1 (arch 2): [i64 tid][i64 coachId][i16 preset]
	OpTournamentSearchResult       = 28612 // S2C DR: [i64 tid][i16 preset][i8 accepted]
	OpTournamentFightStarting      = 28614 // S2C azj_0: [i64 tid]
	OpTournamentSearchError        = 28616 // S2C kw_1: [i8 code][i8 subCode]
	// OpTournamentSearchPeriod opens or closes a tournament's opponent-search
	// period. It is what puts the tournament NOTIFICATION in the client's alert
	// list (zN case 28630 builds a `td_0`), and clicking that notification is the
	// only thing that selects a tournament (agz_1 sets `vk_1.ad(tid)`), which the
	// Tournois tab's "Combattre" requires - `hu_2` refuses with
	// "error.noTournamentSelected" while `vk_1.fx() == 0`.
	//
	// So without this message the tournament UI is unreachable no matter how
	// valid the team is: there is no other way to select one.
	OpTournamentSearchPeriod = 28630 // S2C dg_0: [i64 tid][i8 open]

	// OpTournamentSearchEnded closes an opponent-search period for a fixture the
	// recipient is in, and says how it was settled: [i64 tid][i8 forfeit].
	//
	// forfeit=0 is "tournamentWinner" - "the other player was not searching for
	// an opponent while you were, so you are declared winner by forfeit for this
	// match". forfeit=1 is "tournamentForfeit" - the same sentence pointed the
	// other way.
	//
	// It is also the only thing that closes the client's waiting overlay from the
	// server side: `zN` case 28648 dismisses `tournamentsSearchStatusDialog` on
	// the winner branch. Without it a coach who readies up and is never paired
	// sits in that dialog for the rest of the session.
	// OpTournamentFinale announces (or withdraws) a tournament FINAL, as the
	// standing "Finale du tournoi X — A VS B" entry in the client's alert list.
	//
	//	ADD    : [i8 1][i64 id][i32 n]{i64 coachId}[i32 n]{[i32 len][utf8 name]}[i32 len][utf8 tournamentName]
	//	REMOVE : [i8 2][i64 id]
	//
	// WIRE TRAP: `Yq.a` reads BOTH arrays backwards (`for (n = len-1; 0 <= n; --n)`),
	// so the first element on the wire lands at index n-1. `zN` prints
	// `names[0] VS names[1]`, so the pair must be written in REVERSE order or the
	// two finalists appear the wrong way round.
	OpTournamentFinale = 28620 // S2C Yq

	// OpTournamentSearchUpcoming tells an entrant when the next opponent-search
	// period begins: [i64 tid][i64 startEpochMillis].
	//
	// `zN` turns it into a countdown entry (`apd`) showing the remaining minutes,
	// computed as 1 + (start - now)/60000 - so a start in the PAST yields a
	// negative, nonsensical count. Only send it while the period is still ahead.
	OpTournamentSearchUpcoming = 28644 // S2C aaj_0

	OpTournamentSearchEnded = 28648 // S2C df_1: [i64 tid][i8 forfeit]

	OpTournamentTreeReq = 28649 // C2S alf_0 (arch 2): [i64 tid][i32 round][i32 nameLen][name]
	OpTournamentTree    = 28650 // S2C IL: [i32 treeSize][i32 count]{[i32 id][i32 nameLen][name]}[i32 bib]

	// Evolution mode / graveyard. The client applies both of these OPTIMISTICALLY
	// and consumes no reply, so the server must reproduce the same state machine
	// and persist it; refreshed state reaches the client via 6006.
	OpFighterSetState  = 23000 // C2S Jc (arch 2): [i64 fighterId][u8 legendaryToggle]
	OpFighterUseItemOn = 22099 // C2S bw (arch 3): [i64 fighterId][i32 cardTemplateId]

	// Running-effect ids (2.70 client mh_2 / RunningEffectConstants). The client
	// looks the id up via mh_2.cr(); an unknown id makes case-8120 drop the
	// packet ("runningEffect inconnu"). Damage should instead be keyed to the
	// spell effect's own ActionID (1-5 direct / 130-134 "par sort"); this is only
	// the neutral fallback for a damage source with no spell effect.
	RunEffectHPLoss = 1  // mh_2 id 1 "Perte de point de vie" (neutral direct HP loss)
	RunEffectAPUse  = 91 // mh_2 id 91 "Utilisation de PA": SILENT AP debit (no chat) for action costs
	RunEffectMPUse  = 92 // mh_2 id 92 "Utilisation de PM": SILENT MP debit (no chat) for movement

	// Fight C2S
	OpReadyForPlacement   = 8011 // C2S: empty
	OpMoveToPlacementReq  = 8021 // C2S: [i64 fighterId][i32 x][i32 y][i16 z]
	OpReadyForObservation = 8023 // C2S: empty
	OpReadyForAction      = 8031 // C2S: empty
	OpFighterEndTurnReq   = 8105 // C2S: [i64 fighterId]
	OpGiveUpFight         = 8151 // C2S: empty

	// Fight creation (team-management panel buttons -> launch a fight)
	OpTeamTest             = 26330 // C2S (arch 2): [i32 fightType=12][i16 teamId] — alv_1, "Tester" (solo practice)
	OpClassicReadyForFight = 23103 // C2S (arch 2): [i64 coachId][i16 teamId] — atj_0, "Combattre" (ready-up + pair)
	OpFightReadyConfirm    = 26303 // C2S (arch 2): [i64 coachId][i16 teamId] — bl_1, in-fight "Prêt" team confirm

	// Matchmaking
	OpOpponentSearchRequest      = 2301  // C2S: [i16 mode][i16 sub][i32 N][i64×N ids]
	OpOpponentFound              = 2300  // S2C: opponent-found (opcode-only)
	OpOpponentSearchError        = 2302  // S2C: [i8 error]
	OpOpponentSearchCancel       = 2303  // C2S: empty
	OpOpponentSearchInProgress   = 2304  // S2C: empty
	OpOpponentSearchCancelResult = 2306  // S2C: [i8 result]
	OpMatchAcceptAlt             = 2308  // C2S: [i64 id][i16 mode][i32 N][ids][i8 accept]
	OpMatchFound                 = 23110 // S2C: match-found "do you accept?"
	OpMatchResult                = 23112 // S2C aku_1: [i8 ok] — closes the avn_0 dialog; 0 toasts "resultIsNo" to the still-waiting side
	OpMatchAccept                = 23114 // C2S: [i64 id][i64 opp][i16][i16][ids][i8 accept]
	OpMatchConfirm               = 23116 // C2S aex_0 only: [i32 N][i64×N reversed] team-confirm roster — gz_1 has no 23116 case, the client cannot decode it

	// Classic opponent search (23100 block) — the CLASSIC tab's "Combattre".
	// 23103 is the request; the rest is the same handshake as the evolution block
	// below, handled by the client's vu_1 frame. Unlike the evolution preset, the
	// i16 here IS a real team id (and may be -1 for "no preset selected").
	OpClassicSearchCancel       = 23101 // C2S (arch 2): [i64 coachId][i16 teamId] — bm_1
	OpClassicSearchCancelResult = 23102 // S2C: [i8 accepted] — ada_1
	OpClassicSearchResult       = 23104 // S2C: [i16 teamId][i8 accepted] — aLi
	OpClassicFightStarting      = 23106 // S2C: empty — ads_2, "Lancement du combat"
	OpClassicSearchError        = 23108 // S2C: [i8 code] — M

	// Evolution opponent search (23000 block) — the EVOLUTION tab's "Combattre".
	// Byte-identical twins of the classic 23101/23102/23103/23104/23106/23108
	// family, and the client frames mirror each other exactly (wp_0 vs vu_1).
	//
	// The handshake the client waits for, in order:
	//
	//	C2S 23003            -> S2C 23004 {preset, 1}   opens the "Searching…" overlay
	//	   (opponent found)  -> S2C 23006 {}            closes it, then CREATE_FIGHT (8000)
	//	   (cancelled)       -> S2C 23002 {1}
	//	   (failed)          -> S2C 23008 {code}
	//
	// The client pushes its FIGHT frame (do_2) BEFORE sending 23003, so 8000 is
	// already routable when the server answers. Nothing here is optional: an
	// accepted 23004 with no following 23006 leaves the overlay up forever.
	OpEvolutionSearchCancel       = 23001 // C2S (arch 2): [i64 coachId][i16 preset] — abn_0
	OpEvolutionSearchCancelResult = 23002 // S2C: [i8 accepted] — wf_2
	OpEvolutionSearchRequest      = 23003 // C2S (arch 2): [i64 coachId][i16 preset=99] — ajw_0
	OpEvolutionSearchResult       = 23004 // S2C: [i16 preset][i8 accepted] — amh_0
	OpEvolutionFightStarting      = 23006 // S2C: empty — azl_0, "Lancement du combat"
	// OpSphereBuy has NO reply: the client applies the purchase to its own copy of
	// the fighter and then tells us (awu_0), so this is the authority on what is
	// persisted rather than a request the player can see refused.
	OpSphereBuy            = 23009 // C2S aow_2 (arch 3): [i64 fighterId][i32 sphereId][i32 cardTemplateId], card = the Barrier sacrifice or 0
	OpEvolutionSearchError = 23008 // S2C: [i8 code] — KL

	// Ladder — the ranking window has SEVEN tabs, one opcode pair each (client
	// afl_1, dialog ladderInformationDialog.xml). All C2S arch 2; strings are
	// [i32 len][utf8]; no length field is bounds-checked. Row loops index a
	// PRE-SIZED client list (list.get(n)), so an oversized row/total count throws
	// IndexOutOfBounds — empty boards must send zero counts, not just zero rows.
	OpLadderRequest      = 27500 // C2S dp_0: [i32 windowStart] — "1 vs 1" tab
	OpLadderResponse     = 27501 // S2C azd_0: 1v1 window (rows = end-start; trailing u8 searchBtn)
	OpGuildLadderRequest = 27502 // C2S pc_1: [i16 board][i32 windowStart] — "Clan" tab
	OpGuildLadder        = 27503 // S2C ij_1: [i16 board=1][i32 start][i32 N]{guild,leader,i32 score}
	OpLadder2v2Request   = 27504 // C2S vg_1: [i32 windowStart] — "2 vs 2" tab
	OpLadder2v2Response  = 27505 // S2C aka_0: 2v2 window (icon list; rows = end-start; trailing i32 searchBtn)
	// "Tournoi" tab (ladderInformation.tournamentType1Tab) — tournament POINTS,
	// three windows in ONE message: month, then trimester, then year.
	OpTournamentLadderRequest = 27506 // C2S qk_2: [i32 monthStart][i32 trimStart][i32 yearStart][i8 month][i8 trim][i16 year]
	OpTournamentLadder        = 27507 // S2C uj_0: [i8 m][i8 t][i16 y][i32 ptsM][i32 ptsT][i32 ptsY] + 3×{[i32 total][i32 start][i32 end][i32 myRank] rows{[i32 len][name][i32 pts]} [i8 search]}
	// Two reputation tabs (client afl_1):
	OpCoachReputationRequest = 27508 // C2S aa_2: [i32 startRank] — "Coach" reputation tab
	OpCoachReputation        = 27509 // S2C jw_0: derived-count window; trailing u8 searchBtn
	OpDemonListRequest       = 27512 // C2S ow_2: [i16 flag][i32 startIndex] — "Démon" tab (24-demon list)
	OpDemonList              = 27513 // S2C xn_2: [i16 flag][i32 start][i32 N]{i16 demonId, i64 repPts, guild}
	// "Ligue Pro" tab (ladderInformation.glickoRatingTab) — the pro-league board.
	OpProLeagueLadderRequest = 27514 // C2S ck_2: [i32 windowStart][i32 leagueId][i32 pageSize]
	OpProLeagueLadder        = 27515 // S2C amu_0: [i32 total][i32 start][i32 end][i32 myRank][i32 leagueId] rows{[i32 len][name][i32 len][guild][i16 rating]} [i8 search]

	// Chat
	OpVicinityContentMessage     = 3152 // S2C: sender name + i64 id + message
	OpUserVicinityContentMessage = 3153 // C2S: [u16 len]message
	OpPrivateContentMessage      = 3154 // S2C: sender name + i64 id + message
	OpUserPrivateContentMessage  = 3155 // C2S: [u8 len]target [u8 len]message
	OpChannelContentMessage      = 3140 // S2C: [u8 len]channel [u8 len]sender [u8 len]message
	OpUserChannelContentMessage  = 3151 // C2S: [u8 len]channel [u8 len]message

	// The other three chat pipes the client actually offers, alongside General
	// (/s) and Private. Their S2C shape is byte-identical to VicinityContent
	// (3152), so they share its builder — only the opcode differs.
	//
	//	/t Trade  — GLOBAL, and the only one of the three that works today.
	//	/p Group  — the ally coach on your side of a live fight, so it needs 2v2.
	//	/c Clan   — guild-scoped; the client will not even SEND it without a guild.
	OpUserTradeContentMessage = 3159 // C2S (arch 3): [u16 len][message] — afq_0
	// OpServerMessage is a server-wide announcement: [i32 len][message] in cp1252
	// (`nj` decodes with the JVM default charset, and StringU32 already encodes
	// that way).
	//
	// `om_0` case 2070 shows it in chat at severity 5 AND force-maximises the chat
	// panel plus force-opens chatDialog - it interrupts the player deliberately, so
	// it is for operational notices ("server restarting"), not chatter.
	OpServerMessage = 2070 // S2C nj
	// Chat error signals. All five carry an EMPTY payload: `om_0` ignores the
	// decoded message entirely and shows a fixed string from its own i18n table,
	// so the opcode IS the message. Without them the client shows nothing at all
	// when the server refuses a chat action.
	// Emotes. The client sends the emote it wants to play (4701) and the server
	// relays it to everyone nearby as 4700, INCLUDING the sender: `playEmote`
	// only sets the actor's facing locally, the animation itself is driven purely
	// by the 4700 handler (`no_2` case 4700 -> `mT.aY(name)`). Without the echo
	// the player who emoted sees nothing.
	// OpResetPosition is the console command `/resetPosition` (client class `yl_0`,
	// empty payload). It is the player's own unstick: no admin rights, no
	// arguments. Note the client special-cases the literal text in `jd_0` case 10
	// so it bypasses the local flood guard.
	OpResetPosition = 4514 // C2S aII: EMPTY
	// OpFighterOuch pops the "ouch !" bubble over a fighter (of_1 case 4902).
	// [i32][i32][i64 fighterId] - the two header i32s come from ue_0.o and are
	// NOT read by the handler, which uses only the fighter id.
	// OpSitStand toggles the sit state of coaches already on screen:
	// [i16 n]{i64 sitting}[i16 n]{i64 standing}. Server-driven only - the
	// client has no sit UI and never requests it.
	// OpPlayerStatistics carries the coach's lifetime statistics report:
	// [i16 blobLen][blob], blob = [i16 modelId][i64 ownerId][i16 n] then n x
	// {[i16 statId][i8 type][value]} with type 1=i32, 2=i64, 3=float32.
	// Stat ids come from the UNOBFUSCATED PlayerStatisticsReport getters.
	OpPlayerStatistics = 2401 // S2C uf_0
	// OpActorTeleports moves an actor with no walk animation:
	// [i64 actorId][i32 x][i32 y][i16 z], exactly 18 bytes (the client
	// length-checks it). For the local player the client also recentres the
	// camera. Only safe for actors the receiver has SPAWNED - see ViewersOf.
	OpActorTeleports = 4510 // S2C xp_0
	OpSitStand       = 4601 // S2C afV

	OpFighterOuch             = 4902 // S2C aiz_0
	OpEmotePlay               = 4701 // C2S JY:     [u8 nameLen][name][i32 emoteId]
	OpEmotePlayed             = 4700 // S2C azt_0:  [i64 actorId][u8 nameLen][name]
	OpChatErrMalformedCommand = 3206 // S2C amd_1: "error.chat.malformedCommand"
	OpChatErrNotEnoughRights  = 3210 // S2C lx_0:  "error.chat.notEnoughPrivileges"
	OpChatErrNotImplemented   = 3212 // S2C adm_0: "error.chat.notYetImplemented"
	OpChatErrTargetIsYourself = 3214 // S2C as_0:  "error.chat.targetIsYourself"
	OpChatErrNotPermitted     = 3216 // S2C avs:   "error.chat.operationNotPermited"

	OpTradeContentMessage     = 3168 // S2C: [u8 len]sender [i64 id] [u16 len]message — ayy
	OpUserGroupContentMessage = 3161 // C2S (arch 3): [i64 targetCoachId][u16 len][message] — aux_
	OpGroupContentMessage     = 3170 // S2C: same shape as 3168 — aik_1
	OpUserClanContentMessage  = 3199 // C2S (arch 2): [u16 len][message][i64 guildId] — ak
	OpClanContentMessage      = 3198 // S2C: same shape as 3168 — ano_1
	OpChannelNotFound         = 3202 // S2C: [u8 len]channel
	OpUserNotFound            = 3204 // S2C: [u8 len]name

	// Social lists
	OpFriendList    = 3144 // S2C: [u8 count] + per friend {i16 len, blob}
	OpIgnoreList    = 3146 // S2C: [i8 count] + per ignore {u8 len, name}
	OpAddFriend     = 3129 // C2S: [u8 len]name
	OpAddIgnore     = 3131 // C2S: [u8 len]name
	OpRemoveFriend  = 3133 // C2S: [u8 len]name (or i64 id)
	OpRemoveIgnore  = 3135 // C2S
	OpFriendAdded   = 3156 // S2C
	OpFriendRemoved = 3160 // S2C
	OpIgnoreAdded   = 3158 // S2C
	OpIgnoreRemoved = 3162 // S2C

	// Presence notifications (pushed when a friend/ignored coach logs in/out).
	// Layouts verified vs the 2.70 client decoders dh_0/pv_0/jH/jf_0.
	OpFriendOnline  = 3148 // S2C: [u8 name][u8 s2][u8 s3][i64 id][i16][i8 sex][i64]
	OpFriendOffline = 3150 // S2C: [u8 name][u8 note]
	OpIgnoreOnline  = 3164 // S2C: [u8 name][i64 id]
	OpIgnoreOffline = 3166 // S2C: [u8 name]

	// Godot-client extensions — the retail client neither sends 60000 nor
	// understands 60001, so these never appear on a retail session. The reply
	// is a key/value map ({u8 n} n×{u8 keyLen,key,u16 valueLen,value}) so new
	// runtime settings need no new opcode. Registered in the router so the
	// request isn't "unhandled opcode" noise.
	OpClientConfigRequest = 60000 // C2S (Godot only): empty
	OpClientConfig        = 60001 // S2C (Godot only): key/value map; key "web_base_url"
)

// Auth result codes carried by OpClientAuthResult (1024).
const (
	AuthOK             = 0
	AuthInvalidLogin   = 2
	AuthAlreadyOnline  = 3
	AuthSaveInProgress = 4
	AuthClosedBeta     = 127
)

// Client version advertised in the OpClientVersion handshake. The client sends
// major=2, minor=70; the server must accept these or the client shows
// logon.invalidClientVersion.
const (
	VersionMajor = 2
	VersionMinor = 70
)

// --- Guilds ("clans"). The client's own family: 13 C2S classes, 10 S2C.
// Strings on ALL of these are UTF-8 (aey_0), not the cp1252 used for coach and
// fighter names.
const (
	OpGuildCreate          = 509  // C2S atM  (arch 3): [u8 type][u8 len][name]
	OpGuildInvite          = 501  // C2S uq_2: [u8 type][u8 mode] then (mode 0) [u8 len][coachName] | (mode 1) [i64 coachId], then [i64 guildId]
	OpGuildInviteAnswer    = 503  // C2S cg_0: [u8 type][u8 accepted][u8 len][inviterName][u8 len][guildName]
	OpGuildGet             = 517  // C2S auZ:  [i64 playerId]
	OpGuildMembersGet      = 519  // C2S add_2:[i64 guildId]
	OpGuildLeave           = 505  // C2S nP:    [i64 guildId][i64 memberId] - quit (self) or kick
	OpGuildDestroy         = 511  // C2S awR:   [i64 guildId]
	OpGuildSetRank         = 515  // C2S abn_2: [i64 guildId][i64 memberId][i16 newRankLevel]
	OpGuildRankAdd         = 553  // C2S abo_0: [i64 guildId][i32 rights][u8 len][name]
	OpGuildRankModify      = 555  // C2S Nr:    [i64 guildId][i32 rights][i16 level][i16 level][u8 len][name] - both shorts carry the SAME level (aia_0.modifyRank sets each from aRe())
	OpGuildRankDelete      = 557  // C2S Ko:    [i64 guildId][i16 level]
	OpGuildMemberStats     = 2600 // C2S mL:   [i64 memberId]
	OpDemonAffiliate       = 5470 // C2S Zu (arch 3): [i16 demonId][i16 count] count x {[i32 cardId][i16 qty]} - a card OFFERING, not a button
	OpDemonAffiliateResult = 5403 // S2C mj_1: [u8 result(0=ok)][u8 n] n x {[u8 kind][i32 value]}
	OpGuildMemberReport    = 2601 // S2C kq_2: [i64 coachId][u16 len][name][u16 len][PlayerStatisticsReport]

	OpGuildInvitation  = 502 // S2C auf_0: [u8 type][u8 len][inviterName][u8 len][guildName]
	OpGuildResult      = 504 // S2C mD:    [u8 type][i32 resultCode]
	OpGuildRecord      = 510 // S2C arl_0: [u16 len][guild record -> KI.b]
	OpGuildMembers     = 512 // S2C kf_1(512): [i32 N] N x {[i32 len][ca_0 part 0]}
	OpGuildMembership  = 552 // S2C kf_1(552): [i32 1] {[i32 len][ca_0 part 2]} - MY membership
	OpGuildTags        = 554 // S2C kf_1(554): [i32 N] N x {[i32 len][ca_0 part 1]} - other players' tags
	OpGuildMemberGone  = 556 // S2C h_0:   [i64 playerId]
	OpGuildCreatedFeed = 558 // S2C ahU:   [u8 len][coachName][u8 len][guildName]
	OpGuildMemberFeed  = 560 // S2C ry_1:  [u8 len][coachName][u8 removed]
)

// Guild result codes carried by OpGuildResult (client lh_1.java:44-90).
const (
	GuildResultLeft          = 400
	GuildResultDestroyed     = 401
	GuildResultKicked        = 402
	GuildResultCreated       = 403
	GuildResultJoined        = 404
	GuildResultBadName       = 11
	GuildResultFull          = 20
	GuildResultUserNotFound  = 35
	GuildResultInviteRefused = 40
)
