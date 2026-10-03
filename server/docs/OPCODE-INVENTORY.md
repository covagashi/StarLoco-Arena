# DofusArena 2.70 — Opcode Inventory (server coverage vs client universe)

Complete, opcode-by-opcode map of **what the Go server handles / emits** versus the
**full set of opcodes the retail 2.70 client knows**. Use this to plan feature work:
anything marked `-` is a gap (the client may send it and the server silently drops it,
or the client expects it and the server never sends it).

## Sources & method

| Source | What it gives |
|---|---|
| `client/analysis/opcode_map.csv` (348 rows) | The authoritative client universe: every opcode + obfuscated class + real class (where known) + direction |
| `server/internal/protocol/opcodes.go` | Every opcode the server names as a constant |
| `internal/game/deps.go` → `RegisterAll` (18 `register*Handlers` groups) | Every **C2S handler** the server registers (`r.Register`) |
| `internal/game/*.go` `protocol.EncodeS2C(...)` + `internal/handshake/*.go` encoders | Every **S2C frame** the server actually builds and sends |
| `internal/game/router.go:40` | Unknown C2S opcodes are logged `unhandled opcode` and dropped (server keeps running) |

Framing (see `internal/protocol/frame.go`):
- **C2S** `[u16 len][u8 arch][u16 opcode][payload]` — client → server (has arch byte)
- **S2C** `[u16 len][u16 opcode][payload]` — server → client

> Connection / world-entry S2C frames (auth result, coach info, enter-instance, ping
> reply, actor movement) are built in the **`internal/handshake`** package, not the
> `game` package — that is why a grep of `internal/game` alone misses them.

**Correction: the `apk_0` developer console is LIVE.** An earlier note in this file reasoned
that the tournament admin replies are inert because their sink is never installed. That is
true of **`ajp_0`** specifically (nothing ever calls `ajp_0.a(apk_0)`), but it is NOT true of
`apk_0` itself: `mu_2`, the `contentLoader.console` startup loader registered in `zh_1`,
subscribes `ao_0.aU()` and `ajc_0` to it. So anything routed through `apk_0.aDz().log(...)` -
opcodes 102 and 105 - really is displayed. "Console" is not a synonym for "dead"; check the
subscriber list for the specific object, not the family.

**Correction: 2401 is not Java-serialized.** This file previously said emitting the statistics
report meant "matching their serializer byte-for-byte", and I repeated that as a days-of-work
estimate. It is wrong. `arq_0.aEv().aa()` reads a model id off the front, looks the model up in
a registry, and hands it the buffer; `rs_2.u()` then parses an ordinary typed key-value map:

```
[i16 modelId][i64 ownerId][i16 count]
  count x { [i16 statId][i8 type][value] }      type: 1=i32(4B) 2=i64(8B) 3=float32(4B)
```

Nothing about that is harder than any other frame in this file. The phrase "serialized object"
in the decompiled source described a MODEL LOOKUP, not JVM serialization, and I took it at face
value because it sat next to a `PlayerStatisticsReport` type name. Estimating from a type name
instead of the parser cost a day of avoidance.

### Negative results - things that look like missing opcodes but are not

These cost real time to establish. They are recorded so nobody re-derives them.

**Chat flood detection has no S2C frame.** The client shows
*"Flood detecte : message deja envoye."* from `jd_0` case 10 - a purely **client-side**
check (`jd_0.c(text, System.currentTimeMillis())`) on the chat input box, which refuses to
send and prints the warning locally. The sibling string `error.chat.floodDetected.time`
(`aon_0.edG`) is **declared and never referenced anywhere in the client**. `om_0` has no
flood case at all.

Consequence: the server's own repeat guard (`chat.allowRepeat`) is a second line of defence
against a *modified* client, and it is correct for it to drop silently - there is no retail
frame to report it with. Do not invent one, and do not reuse 3212/3216 for it. This is the
one place in chat where a silent server-side drop is right; everywhere else the silence was
a bug (see B-133, and the 3206/3210/3214 fixes).

**`error.chat.floodDetected.time`, `memberNotFound` and the flood pair are string-only.**
Their presence in `texts_fr.properties` proves nothing about reachability - the i18n bundle
is shared across Ankama titles and carries strings this client never displays. Always
confirm a string is actually fetched by a `getString(...)` call site before treating it as
evidence of a feature.

**Emote table.** The ten emotes are hardcoded in the client enum `up_0` as
(id, animation, chat command): 57 `/clap`, 59 `/read`, 60 `/declare`, 62 `/angry`,
63 `/music`, 65 `/show`, 66 `/laugh`, 67 `/fear`, 68 `/cry`, 69 `/no`. The ids are
**non-contiguous and the gaps are real** - 58, 61 and 64 are not emotes. Because the
whole table is knowable, the server relays its own name rather than the client's
string, so a modified client cannot push an arbitrary animation name to other players.

**Correction: the tournament admin family is unreachable for a DIFFERENT reason than
first recorded.** An earlier version of this file leaned on "`ajp_0`'s sink is
never installed" as the reason. That statement is narrowly true - nothing calls
`ajp_0.a(apk_0)`, so ajp_0 has no debug-console sink - but it does NOT make ajp_0 inert:
`ajp_0.azc()` is separately registered as a live message handler
(`apN.aDK().a(ajp_0.azc())` in `aog_1` and `by_2`, removed again in `aog_1`). Two different
registrations, one of which I had generalised from the other.

The decisive fact is simpler and stronger: the five C2S classes (`ayQ`, `bi_2`, `ago_0`,
`kx_2`, `aeC`) are **constructed nowhere in the client**, so retail cannot send them.

The difference matters. "Dead handler" would mean the server may send the replies freely and
nothing happens. "Live handler, unsendable request" means the replies WOULD be processed if
we sent them unsolicited - they are orphaned, not dead. Anything added here must still be
gated on the account admin flag.

This is the second claim of this shape corrected in one pass (see the `apk_0` note below).
Both were "the sink is missing" arguments made without listing the subscribers/registrations.
Prefer the argument that rests on a constructor search: it is cheap, decisive, and does not
depend on tracing a registration path through startup code.

## Status legend

| Mark | Meaning |
|---|---|
| **H** | C2S **handled** — a handler is registered in `RegisterAll` |
| **E** | S2C **emitted** — the server builds & sends this frame |
| **I** | **Inactive** — the server *defines* the opcode constant but never registers/sends it |
| **-** | **Not implemented** — the client knows it; the server has no code for it |

## Summary counts

| Bucket | Count |
|---|---|
| Client opcodes total (unique, from CSV) | ~330 |
| **C2S handled (H)** | **107** |
| **S2C emitted (E)** | **118** |
| **S2C defined-but-inactive (I)** | **8** |
| Client opcodes with **no server code (-)** | 172 (mostly unidentified subsystems) |

Counts are rows of the master table below (340 rows). Opcode **107** is a single
`both | H+E` row and counts once on each side. Re-derive after any change — the
handled count must equal the number of `r.Register` calls in `internal/game`:

```powershell
$t = Get-Content docs\OPCODE-INVENTORY.md
$both = ($t|sls '^\| \d+ \| both \| H\+E \|').Count
"H={0} E={1} I={2} -={3}" -f (($t|sls '^\| \d+ \| C2S \| H \|').Count + $both),
  (($t|sls '^\| \d+ \| S2C \| E \|').Count + $both),
  ($t|sls '^\| \d+ \| \w+ \| I \|').Count, ($t|sls '^\| \d+ \| \w+ \| - \|').Count
(sls -Path internal\game\*.go -Pattern 'r\.Register\(protocol\.').Count  # must equal H
```

---

## Master table — every opcode, ordered by number

Notes column gives the server handler/builder or the reason it is a gap. "obf" = the
obfuscated client class from the CSV; real class name is used when the CSV knows it.

### 1 – 999 — handshake, reconnection-ticket, properties, part-tables

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 1 | C2S | H | DisconnectionNotificationMessage (aqb) | `handleDisconnect`. (CSV also lists LoginMessage `ll_2` on op 1; real login is 1025.) |
| 2 | both | - | ReconnectionTicketMessage (apg_1 / tI) | Admin/proxy reconnect-ticket channel; unused by our flow |
| 3 | C2S | - | ReconnectionTicketRequest (`po_1`) | `[i8]`, constructed in `ajz_1` so retail can send it. Connection-stage; our session flow never needs a reconnection ticket because we do not hand the client off between servers |
| 4 | S2C | - | ReconnectionTicketResult (`nu_2`) | `[i8 bool]`, 1 byte. The answer to 3; same reason |
| 6 | S2C | - | (`asu`) | `[i8]` -> `qd_0.w(b)`. Connection-stage message consumed by `alz_2`, the handler for the pre-game **auth/connection** protocol (frames built by the `fp_0` factory, dispatched to the `qd_0` state machine). Our handshake takes a different, working path through `internal/handshake`; these are alternate branches of it |
| 7 | C2S | H | ClientVersionMessage (na) | `handleClientVersion` |
| 8 | S2C | E | InvalidClientVersion (oq_1) | `EncodeInvalidClientVersion` � `handleClientVersion` sends `[u8 major][u16 minor]` on a version mismatch; the client shows a modal and self-disconnects |
| 9 | S2C | - | (`avT`) | `[i8][i8]`, exactly 2 bytes. Same `fp_0`/`alz_2` connection stage as 6 |
| 10 | C2S | - | PropertyListQuery (`ms_0`) | Payload is a single hardcoded `0` byte. Constructed in `gy_2`. Part of a client-side **"property" config subsystem** (10/11/12) we do not model |
| 11 | C2S | - | PropertyItem (`afy_2`) | `[name][typed value]` - the encoder switches on a type tag to pick the value width. Constructed in `akX`. Same property subsystem |
| 12 | C2S | - | PropertyQuery (`pn_2`) | `[u8 len][name]`. Constructed in `ad_0`. Same property subsystem - a get-by-name |
| 20 | C2S | - | (`rx_0`) | `[i32][packed array]`. Built only as `new rx_0(null)` in `afl_2` and read back in `aop_0` - it round-trips locally rather than being a server request |
| 100 | S2C | - | (`es_0`) | `[i8][i16][i16][i32]`, 9 bytes. `alz_2` case 100: if the first i16 is **-1** it calls `qd_0.vP()`, otherwise `qd_0.a(s, s2, l2)` - a connection-stage status/dispatch with a sentinel. Same subsystem as 6/9 |
| 101 | C2S | - | (`aFC`) | `[i16 len][text]`. **Constructed nowhere** in the client, so the retail client cannot send it |
| 102 | S2C | - | (`ja_0`) | `[i8 level][i16 len][text]`. `alz_2` switches on the level and calls `apk_0.aDz().trace/log/...` - the client's **developer console**. NOT inert: `mu_2` (the `contentLoader.console` startup loader, registered in `zh_1`) subscribes `ao_0.aU()` and `ajc_0` to it, so the text is really displayed. Unimplemented because it is a developer affordance (server prints into the client console), not gameplay |
| 103 | S2C | - | (`dm_0` / `qr_2`) | **Two classes both return 103**, both decode via a shared `n(ByteBuffer)`, and neither is constructed outside the factory - so which one 103 resolves to depends on factory registration order. Ambiguous by construction; do not send it without settling that first |
| 105 | S2C | - | (`Ve`) | `[i8 level]` + an i32 when level==3. Same developer-console sink as 102 |
| 106 | S2C | - | (`lo`) | `[i8][raw remainder]` - the tail is kept as an unparsed ByteBuffer, so the payload shape is defined by whatever reads it downstream. Connection stage (`fp_0`) |
| 107 | both | H+E | Ping (asg_0) | `handlePing` → `handshake.EncodePingReply` |
| 108 | S2C | - | (`abj_0`) | `[i8][i32][i64][i64]...`, min 29 bytes. Connection stage (`fp_0`). Note `pl_2` case 108 calls `nW.sL()` - so a frame in this family is also consumed by the ladder handler |
| 200 | S2C | E | InteractiveElementSpawn | generated table (`cmd/genelements`); Zaaps, Card Masters, Fusion altars, NPCs, totems |
| 201 | C2S | H | InteractiveElementAction (bd_2) | `handleInteractiveElementAction` � **every** element click |
| 202 | S2C | - | (`tt_2`) | `[i64][i16 len]...` via a shared `G(ByteBuffer)` reader. Connection stage (`fp_0`) |
| 204 | S2C | - | (`il_0`) | `[i16 n]{[i64][i64][i16 len][blob]}` - a batch of id/id/blob triples. Connection stage (`fp_0`) |
| 206 | S2C | E | InteractiveElementDespawn (acc_2) |  |
| 501 | C2S | H | GuildInvite (uq_2) | `handleGuildInvite` |
| 502 | S2C | E | GuildInvitation (auf_0) | sent to the invitee |
| 503 | C2S | H | GuildInviteAnswer (cg_0) | `handleGuildInviteAnswer` - accept/refuse an invitation |
| 504 | S2C | E | GuildResult (mD) | create/join result code |
| 505 | C2S | H | GuildLeave / Kick (nP) | `handleGuildLeave` - one opcode for both; kicking re-derives the caller's rank |
| 509 | C2S | H | GuildCreate (atM), arch 3 | `handleGuildCreate` - live-verified |
| 510 | S2C | E | GuildRecord (arl_0) | the guild sheet |
| 511 | C2S | H | GuildDestroy (awR) | `handleGuildDestroy` - leader only, rank re-derived server-side |
| 512 | S2C | E | GuildMembers | the clan member list (item 31) |
| 513 | C2S | - | (`wt_1`) | `[i64][u8 len][cp1252 text]` (guild RENAME). **Test-Lua-only**: `asW` is a `uc_1` action in the `adg_1` debug console - the same deliberate non-work class as 17004/17006/17008 |
| 515 | C2S | H | GuildSetRank (abn_2) | `handleGuildSetRank` - leader-only, validated server-side |
| 517 | C2S | H | GuildGet (auZ) | `handleGuildGet` |
| 519 | C2S | H | GuildMembersGet (add_2) | `handleGuildMembers` - live-verified |
| 539 | C2S | H | MailSend (F) | `handleMailSend` � full mail record |
| 551 | C2S | - | (`mx_1`) | `[i64][i16][i32][i32]` (guild ICON). **Test-Lua-only**: `Ad` is a `uc_1` action in the `adg_1` debug console - same class as 513 |
| 552 | S2C | E | GuildMembership | the 0x20 membership blob (item 31) |
| 553 | C2S | H | GuildRankAdd (abo_0) | `handleGuildRankAdd` |
| 554 | S2C | E | GuildTags part-table (`kf_1`) | `[i32 n]` then n x `[i32 len][ca_0 part 1 = ut_2 tag]` - the clan-tag table `lh_1` merges onto every coach in `bd_1.Is()`. Pushed at login by `pushGuildTags` (all clanned coaches) and broadcast by `broadcastGuildTag` on create/join so labels update live; clears go through 556, which leave/kick/destroy now broadcast to every session |
| 555 | C2S | H | GuildRankModify (Nr) | `handleGuildRankModify` |
| 556 | S2C | E | GuildMemberGone (h_0) | kick / quit notice |
| 557 | C2S | H | GuildRankDelete (Ko) | `handleGuildRankDelete` |
| 558 | S2C | E | GuildCreatedFeed (ahU) |  |
| 560 | S2C | E | GuildMemberFeed (ry_1) |  |

### 1024 – 2601 — auth, coach creation, spectate query, matchmaking, stats

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 1024 | S2C | E | ResultMessage / AuthResult (Uk) | `handshake.EncodeAuthResult` |
| 1025 | C2S | H | ClientAuthenticationMessage (bu_1) | `handleAuthentication` |
| 1026 | S2C | E | WorldServerUnavailable | `messages.go` |
| 2048 | S2C | E | CoachCreationRequestMessage (amz_0) | `handshake.EncodeCoachCreationRequest` |
| 2049 | C2S | H | CoachCreationMessage (alq_0) | `handleCoachCreation` |
| 2050 | S2C | E | CoachCreationResultMessage (az_0) | `handshake.EncodeCoachCreationResult` |
| 2052 | S2C | E | CoachInformationsMessage (aoh_2) | `buildCoachInformation` → `EncodeCoachInformations`. Its **0x200 stat-pairs blob is the ONLY safe way criteria reach the client**; `byteLen` must be exactly 4×pairs or the coach fails to materialise |
| 2070 | S2C | E | ServerMessage (nj) | `[i32 len][cp1252 message]` - a server-wide announcement. `om_0` shows it at severity 5 AND force-maximises the chat panel + force-opens chatDialog, so it interrupts deliberately: operational notices only. Sent by the admin `/ANNOUNCE` command |
| 2260 | C2S | H | (py_0) | `handleSpectateQuery` (is coach in a spectatable fight?) |
| 2261 | S2C | E | (wv_2) | spectate reply |
| 2300 | S2C | I | OpponentFoundMessage (bk_1) | Defined; superseded by 23110 MatchFound |
| 2301 | C2S | H | OpponentSearchRequestMessage (agp_1) | `handleOpponentSearch` |
| 2302 | S2C | I | OpponentSearchError (apa_0) | **intentionally inactive** � the client has NO handler for the 2300-series replies (vestigial; we use 23110). Sending it is dropped, and an empty payload would crash its decoder |
| 2303 | C2S | H | OpponentSearchCancelMessage (adj_0) | `handleOpponentSearchCancel` |
| 2304 | S2C | E | OpponentSearchInProgressMessage (Hf) | matchmaking "searching…" |
| 2306 | S2C | E | OpponentSearchCancelResultMessage (tj_2) | |
| 2307 | S2C | - | (`bx_1`) | The **bet-carrying variant** of match-found ("opponentSearchConfirmation.request" dialog): its answer is 2308 (`Pg`), which we already handle via `handleMatchAcceptAlt`. We always announce with the 23110 variant instead, so the question never goes out - the alternate dialog is supported by the wire we already serve |
| 2308 | C2S | H | (Pg) | `handleMatchAcceptAlt` |
| 2309 | S2C | - | (`cJ`) | `[i8 bool]` - the result frame **for the 2307 variant** (`avn_0.close()` + "resultIsNo" toast). Ours is the 23110 variant, whose result is 23112 |
| 2400 | S2C | E | PlayerStatisticsReportMessage (pl_1) | `buildPlayerStatisticsReport` |
| 2401 | S2C | E | PlayerStatisticsReport (`uf_0`) | `[i16 blobLen][i16 modelId][i64 ownerId][i16 n]` then n x `{[i16 statId][i8 type][value]}`; type from `dr_2`: 1=i32, 2=i64, 3=float32. **Not** Java-serialized. Stat ids are exact, from the unobfuscated `PlayerStatisticsReport` getters: 1 playTime(i64), 2 fightTime(i64), 3 fights, 4 won, 5 lost, 6 unknown, 7 consecWins, 8 consecLosses. **modelId=1 verified live** - 0/2/3 are each refused by name. Sent on login; the map is sparse (untracked stats omitted, not zeroed) (B-141) |
| 2411 | S2C | - | (`HJ`) | **Per-preset ladder record**, decoded fully: `[i32 n]` then n x `{i16 presetListId, i16 teamId (sw_1.cB), i16 strength (afA/bMF), i32 totalVictories (afB), i32 totalDefeats (afC), i32 consecWins (afD)}` - `add_0` writes them onto the `zK` presets in `bs_0.IF()` and refires teamManagement.teamPreset*List. **Read BACKWARDS** (`for j = n-1`), the Yq/28620 trap. Deliberate non-work for now: stats are coach-global in our model - a per-preset record needs a per-preset stats model, and filling the fields with coach numbers would lie in the UI |
| 2600 | C2S | H | GuildMemberStats (mL) | `handleGuildMemberStats` |
| 2601 | S2C | E | GuildMemberReport (mL family) | reply to 2600 |

### 3128 – 3216 — chat & social

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 3128 | S2C | - | ChannelFlags (`by_1`) | **No-op consumer**: `om_0` case 3128 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3129 | C2S | H | AddFriendMessage (QZ) | `handleAddFriend` |
| 3130 | S2C | - | ChannelJoin (`cz_0`) | **No-op consumer**: `om_0` case 3130 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3131 | C2S | H | AddIgnoreMessage (MP) | `handleAddIgnore` |
| 3132 | S2C | - | ChannelLeave (`Bs`) | **No-op consumer**: `om_0` case 3132 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3133 | C2S | H | RemoveFriendMessage (aym_0) | `handleRemoveFriend` |
| 3134 | S2C | - | ChannelMemberFlags (`Uy`) | **No-op consumer**: `om_0` case 3134 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3135 | C2S | H | RemoveIgnoreMessage (aer_0) | `handleRemoveIgnore` |
| 3136 | S2C | - | ChannelMemberKick (`ato_0`) | **No-op consumer**: `om_0` case 3136 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3138 | S2C | - | ChannelMembers (`ax_2`) | **No-op consumer**: `om_0` case 3138 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3140 | S2C | E | ChannelContentMessage (xb_1) | channel chat broadcast |
| 3142 | S2C | - | ChatUserFlags (`wh_0`) | **No-op consumer**: `om_0` case 3142 is a cast and `return false` - the client does nothing with it. Not a feature gap; sending it would change nothing on screen. (The row previously read *"channel mgmt not modelled"*, which wrongly implied missing work.) |
| 3144 | S2C | E | FriendListMessage (aaf_1) | `buildFriendList` (login) |
| 3146 | S2C | E | IgnoreListMessage (abh_0) | `buildIgnoreList` (login) |
| 3148 | S2C | E | NotificationFriendOnlineMessage (dh_0) | presence push |
| 3150 | S2C | E | NotificationFriendOfflineMessage (pv_0) | presence push |
| 3151 | C2S | H | UserChannelContentMessage (acS) | `handleChannelMessage` |
| 3152 | S2C | E | VicinityContentMessage (ck_0) | vicinity chat broadcast |
| 3153 | C2S | H | UserVicinityContentMessage (bb_0) | `handleVicinityMessage` (also carries `/GM` commands) |
| 3154 | S2C | E | PrivateContentMessage (ais_2) | private message delivery |
| 3155 | C2S | H | UserPrivateContentMessage (Xk) | `handlePrivateMessageRecv` |
| 3156 | S2C | E | FriendAddedMessage (kz_1) | `sendSocialAck` |
| 3158 | S2C | E | IgnoreAddedMessage (ft_0) | `sendSocialAck` |
| 3159 | C2S | H | `afq_0` | **Trade chat send** (`/t`), arch 3: `[u16 len][msg]`. Global. 30 s cooldown + 5 s anti-repeat, both the client's own limits (B-104) |
| 3160 | S2C | E | FriendRemovedMessage (adw_1) | `sendSocialAck` |
| 3161 | C2S | H | `aux_` | **Group chat send** (`/p`), arch 3: `[i64 allyCoachId][u16 len][msg]`. Served, but has no audience until 2v2 (item 30): the audience is resolved from the sender's own fight, never from the client-supplied coach id, which would otherwise be an unfilterable DM bypassing the ignore list |
| 3162 | S2C | E | IgnoreRemovedMessage (ahm_0) | `sendSocialAck` |
| 3164 | S2C | E | NotificationIgnoreOnlineMessage (jH) | presence push |
| 3166 | S2C | E | NotificationIgnoreOfflineMessage (jf_0) | presence push |
| 3168 | S2C | E | `ayy` | **Trade chat recv**. Byte-identical to 3152 |
| 3170 | S2C | E | `aik_1` | **Group chat recv**. Byte-identical to 3152; no audience until 2v2 (item 30) |
| 3198 | S2C | E | `ano_1` | **Clan chat recv**. Byte-identical to 3152; live since item 31 |
| 3199 | C2S | H | `ak` | **Clan chat send** (`/c`), arch 2: `[u16 len][msg][i64 guildId]`. The client SELF-GATES on having a guild - with none it emits no packet at all - which is why this looked dead before item 31. Now live: the supplied guild id is re-validated against the sender's actual guild |
| 3202 | S2C | I | ChannelNotFound (qv_0) | **unreachable** - it answers 3151, which the retail client cannot send (`ChannelContentCommand` is referenced by nothing). Vestigial with the rest of the channel family |
| 3204 | S2C | E | UserNotFoundMessage (ve_1) | emitted on PM to unknown name |
| 3206 | S2C | E | MalformedCommand (`amd_1`) | EMPTY payload. Sent for a bare `/` and for an **unrecognised slash-command** - the latter replaced an invented English string (B-140). Renders translated: *"Ungultiger Befehl"* in the German client, verified live |
| 3208 | S2C | - | MemberNotFoundMessage (ez_2) | error class, unused |
| 3210 | S2C | E | NotEnoughPrivilegesMessage (`lx_0`) | EMPTY payload. Sent when a non-admin issues a `/` command; replaces an invented, untranslated English string |
| 3212 | S2C | I | NotYetImplementedMessage (`adm_0`) | EMPTY payload; constant + the `sendChatError` helper exist, no call site yet. Shows *"error.chat.notYetImplemented"* |
| 3214 | S2C | E | TargetIsYourselfMessage (as_0) | EMPTY payload - `om_0` ignores the body and shows *"error.chat.targetIsYourself"*. Sent when a coach whispers ITSELF; before this the whisper was relayed straight back and the player saw no explanation. Emitted via `sendChatError` |
| 3216 | S2C | E | OperationNotPermited (`avs`) | EMPTY payload. The i18n string names the real trigger: *"Ta liste d'amis ou de personnes ignorees est peut-etre **pleine**"* - it is the **social-list-full** refusal, NOT a generic permission error. Sent when a friend/ignore add would exceed `maxSocialListEntries` (B-133) |

### 4000 – 4902 — wallet, actors, overworld & fight movement, direction

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 4000 | S2C | - | (`tg_1`) | `[i32 value]` -> `sj_1.nu(value)` on the local coach. The setter body is not resolvable from the obfuscated source, so the FIELD is unknown even though the wire is trivial. Do not guess - a wrong write here silently corrupts local coach state |
| 4001 | S2C | E | WalletUpdate (tc_2) | `buildWalletUpdate` (token balance) |
| 4096 | S2C | E | ActorSpawnMessage (xe_2) | `buildActorSpawn` (AoI seed) |
| 4098 | S2C | E | ActorDespawnMessage (th_1) | despawn fan-out |
| 4102 | S2C | E | ActorAppearMessage (aEV) | `buildActorAppearForFight` |
| 4104 | S2C | - | ActorDisapear (`aya_0`) | `[i16 n]{i64 actorId}` -> `qg_2`. A batched actor removal. **Redundant**: we already despawn via 4098, which the client handles equally well. Nothing is missing from the player's view - this is a second way to say the same thing |
| 4106 | S2C | - | ActorReposition (`aqb_0`) | `[i16 n]{[i64 actorId][i32 x][i32 y][i16 z]}` -> `qg_2` (clears its list first). The **batched** form of 4510 - teleport several actors without a walk animation. **Blocked by the same precondition as 4510**: AoI membership is seeded in `EnterAoI` and not maintained on movement, and a repositioned actor the receiver has not spawned is exactly the case that NPEs a retail handler (see B-136) |
| 4309 | S2C | - | FightInvitationError (`n`) | EMPTY payload and **no consumer anywhere** - only the `gz_1` factory names it. Inert: emitting it would tell the player nothing. The fight-setup refusals that DO reach the player go through other frames |
| 4311 | S2C | - | FightCreationCancel (`aff_2`) | EMPTY payload, **no consumer anywhere**. Inert, exactly like 4309 |
| 4500 | S2C | E | ActorMovementMessage (avf_0) | `handshake.EncodeActorMovement` |
| 4501 | C2S | H | CoachActorMovementRequestMessage (aLY) | `handleMovement` |
| 4503 | C2S | H | FighterActorMovementRequestMessage (md_1) | `handleFighterMoveInFight` |
| 4506 | S2C | E | FighterTackledMessage (acg) | tackle interrupt |
| 4510 | S2C | E | ActorTeleports (`xp_0`) | `[i64 actorId][i32 x][i32 y][i16 z]`, exactly 18 bytes (the client length-checks it). Moves an actor with no walk animation; for the local player it also recentres the camera. Used for **same-world** teleports (`/TP`), paired with `ApplyMove` so every observer's AoI is maintained incrementally instead of by a full instance re-enter (B-142). Cross-world still uses 4600 |
| 4512 | C2S | H | ZaapTeleport (Gs) | `handleZaapTeleport` � `[i32 cardTemplateId]` |
| 4514 | C2S | H | ResetPosition (`aII`) | EMPTY. The console command **`/resetPosition`** (`yl_0.getName()`); the client also special-cases the literal text in `jd_0` case 10 so it skips the local flood guard. Player-facing unstick - moves the coach to its CURRENT world's primary Zaap via the enter path (B-135) |
| 4516 | S2C | E | InstanceReady (yu_1) | **mandatory after every 4600** � else movement stays locked |
| 4517 | C2S | H | (aae_2) | `handleTutorialChangeInstance` (instance-ready ack) |
| 4518 | C2S | - | (`Ab`) | EMPTY. Console command **`/ignoreEventsMessages`** (`sr_1`). The client also locally despawns every other actor. Note it sends the frame **twice** (`b(new Ab())` then a second instance) - a client bug, so expect duplicates. Not implemented: we have no event-message stream to mute |
| 4519 | C2S | - | (`aOx`) | EMPTY. Console command **`/acceptEventsMessages`** (`yl`), the counterpart to 4518, and likewise **sent twice**. Not implemented for the same reason |
| 4520 | S2C | E | FighterDiesMessage (cd_2) | death event |
| 4521 | C2S | H | FighterActorDirectionChangeRequestMessage (lr_2) | `handleFighterDirectionChange` — relays facing; reply 4522 |
| 4522 | S2C | E | FighterChangeDirectionMessage (u_0) | `buildFighterDirectionChange` — cosmetic facing broadcast |
| 4523 | C2S | - | (`anv_0`) | EMPTY. Console command **`/skipTutorial`** (`bv_0`). Not implemented: there is no tutorial to skip |
| 4524 | S2C | E | FighterMoveMessage (yr_1) | in-fight move broadcast |
| 4600 | S2C | E | EnterInstanceMessage (aec_2) | `handshake.EncodeEnterInstance` (world/arena stream) |
| 4601 | S2C | E | SitStand (`afV`) | `[i16 n]{i64 sitting}[i16 n]{i64 standing}` -> `AnimAssis-Debut` / `AnimAssis-Fin`, nudging each actor's facing. **Server-driven only**: the client has no sit UI and forwards `/sit` to the server like any other slash-line (verified live). Paired with the actor blob's `dBg` byte, which covers a coach that was ALREADY seated when you arrived. Sent by `/sit` and `/stand`; walking stands you up (B-139) |
| 4607 | C2S | H | TournamentRegister (aik_0) | `handleTournamentRegister` - join a tournament (arch 3); reply 28608 |
| 4700 | S2C | E | EmotePlayed (`azt_0`) | `[i64 actorId][u8 nameLen][animName]`. `no_2` case 4700 resolves the actor, nudges its facing, then `mT.aY(name)` plays the animation. Broadcast to the emoter's AoI **including the emoter** - the client never plays its own emote locally |
| 4701 | C2S | H | EmotePlay (`JY`) | `[u8 nameLen][animName][i32 emoteId]`, sent by `avv_0.playEmote`. The name is the client's locally-resolved string and is **ignored** by the server, which relays its own canonical name for the id |
| 4800 | S2C | - | RunScript (`yd`) | `[i32 scriptId][i32 n]{i64 args}` -> `anr_0.aXN().a(scriptId, 0, args, false)` (the client logs *"execution du script"*), guarded by a lookup so an unknown script is ignored. Drives client-side scripted sequences. Not implemented: the script ids live in client content we do not model |
| 4900 | S2C | - | (`xk_0`) | `[i32 apt][i32 apu][i64 id][i64 packedPos][i32 qc_0]` (header from `ue_0.o`). `of_1` builds an `avJ` and pushes it onto the `vr_0.aiM()` replay/telemetry queue, then flushes. `packedPos` unpacks via `wi_2.dd/de/df` into (x,y,z). Not implemented: the queue is a **client-side recorder** (the handler also prints a `418\|` trace line); nothing in the visible UI reads it, so sending it changes nothing a player can see |
| 4901 | S2C | - | (`xy_2`) | `[i32 apt][i32 apu][i64 id]`. Same `vr_0.aiM()` recorder queue as 4900, via `ol_2`. Not implemented for the same reason |
| 4902 | S2C | E | FighterOuch (`aiz_0`) | `[i32][i32][i64 fighterId]` - the two header i32s come from `ue_0.o` and the handler never reads them, so they are sent as 0. Pops the **"ouch !"** bubble over the fighter. Sent when a fighter **loses HP to a CRITICAL cast** (B-138). The frame names ONE fighter, so it can only mean the one that was hit - never the attacker |

### 5000 – 5491 — exchange, inventory/equipment, shop, fusion

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 5000 | S2C | - | NoInstanceServerAvailableMessage (CU) | error class, unused |
| 5101 | C2S | H | ItemExchangeInvitationRequestMessage (fw_1) | `handleExchangeInvite` |
| 5102 | S2C | E | ItemExchangeInvitationMessage (uo_1) | invitation push |
| 5103 | C2S | H | ItemExchangeInvitationAnswerMessage (tw_0) | `handleExchangeAnswer` |
| 5104 | S2C | E | ItemExchangeInvitationConfirmationMessage (Ul) | confirmation push |
| 5105 | C2S | H | ExchangeAddCard (ua_2) | `handleExchangeAddCard` - `[i64 exId][i32 refCardId][i16 qty]` from base `pv_2` |
| 5107 | C2S | H | ExchangeRemoveCard (wd_0) | `handleExchangeRemoveCard` - same `pv_2` base as 5105, hence the pair |
| 5109 | C2S | H | ExchangeSetReady (ahJ) | `handleExchangeSetReady` - `[i64 exId]` toggle. Its base `so_0` throws "ne peut etre decode", i.e. send-only, which is what proves the direction is C2S |
| 5110 | S2C | E | ExchangeCardAdded (asH) | `[i64 exId][i8 userIdx][i32 refCardId][i16 qty]` |
| 5111 | C2S | H | ExchangeCancel (any) | `handleExchangeCancel` - `[i64 exId]`; same `so_0` base as 5109 |
| 5112 | S2C | E | ExchangeCardRemoved (aaz_1) | same shape as 5110 |
| 5113 | S2C | E | ExchangeError (Or) | `sendExchangeError` |
| 5114 | S2C | E | ExchangeEnd (aqX) | `[i8 reason][i64 exId]` (0=success, 1=cancel) |
| 5116 | S2C | E | ExchangeUserReady (dl_0) | `[i64 exId][i8 userIdx]` |
| 5200 | S2C | E | CoachInventoryUpdateMessage (air_2) | `pushInventory` (card inventory) |
| 5201 | C2S | H | CoachEquipmentUpdateRequestMessage (aEl) | `handleEquipmentRequest` |
| 5202 | S2C | I | CoachEquipmentUpdate (yz_2) | **intentionally inactive** � a coach's overworld avatar is hair/skin/sex (already sent correct at ActorSpawn); "equipment" is cards/deck (gameplay), delivered per-fight via 8000. Broadcasting it re-skins nothing visible |
| 5203 | C2S | H | CoachInventoryUpdateRequest (`fh_0`) | `[i16 n]{i64 uid}` - **client-local uids only, no template id**. `handleInventoryRequest` deliberately takes no destructive action. Server-assigned card identity is **impossible in this protocol**, proven twice: (1) `eb_1.b(ByteBuffer)` reads only the i32 reference-card id and then unconditionally overwrites the uid with `uq_1.ahR()`, the client-local counter, so a uid we sent would be discarded even if the wire had a field for it; (2) 5203 echoes only those uids, with no template id to reconcile against. The server receives numbers it has never seen |
| 5204 | C2S | H | AddToTome (`ajm_2`) | `[i32 templateId]`. The card context-menu "inscribe in grimoire" action (`ST.b(8)`; also `by_0` for a fixed 112): the client marks `isInTome` locally and expects no reply. Not uid-blocked like 5203 - the id is the *template* (all client lookups use `Math.abs(wy_2.jf())`). `handleAddToTome` verifies ownership and grow-only-inserts into the tome so an inscribed card survives being traded away |
| 5300 | C2S | H | ShopOpen (yg) | `handleShopOpen` � **no-op**: 5300 is the client debug console, not the shop; the Card Master opens via 201 |
| 5301 | ? | - | (`axZ`) | **Stub**: both `a(byte[])` and `encode()` are empty (`return true` / `EMPTY_BYTE_ARRAY`) - it carries no data in either direction. Instantiated only by the decode factory, never by client code, so nothing ever sends it |
| 5400 | C2S | H | ShopBarter (aOo) | `handleShopBarter` |
| 5401 | S2C | E | ShopCatalog (NN) | `buildShopCatalog` |
| 5403 | S2C | E | ShopResult (mj_1) | purchase result + new balance |
| 5450 | C2S | H | ShopBuy (mo_2) | `handleShopBuy` (token purchase) |
| 5470 | C2S | H | DemonAffiliate (Zu), arch 3 | `handleDemonAffiliate` - a card OFFERING with a split-quantity dialog, leader-only and one-way; answered on 5403 |
| 5490 | C2S | H | FusionRequest (ahg_0) | `handleFusionRequest` |
| 5491 | S2C | E | FusionResult (agr_2) | fusion outcome |

### 6000 – 6200 — fighters & team presets

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 6000 | S2C | E | CreationFighterInformationMessage (aiy_2) | fighter-create result |
| 6001 | C2S | H | CreateFighterInformationRequestMessage (aNb) | `handleFighterCreate` |
| 6002 | S2C | E | DeletionFighterInformationMessage (DQ) | fighter-delete result |
| 6003 | C2S | H | DeleteFighterInformationRequestMessage (ot_2) | `handleFighterDelete` |
| 6006 | S2C | E | FighterInformationListMessage (jt_2) | `pushFighterList` (roster) |
| 6010 | S2C | E | UpdatedFighterInformationInventoryMessage (nl_1) | loadout update result |
| 6011 | C2S | H | UpdateFighterInventoryRequestMessage (bp_1) | `handleFighterInventoryUpdate` |
| 6013 | C2S | H | (qp_1) | `handleFighterAssignTeam` (drag fighter to team slot) |
| 6014 | S2C | E | FighterAssignedTeam (aoi) | `[i8 status]` + on success `[i64 fighterId][i16 srcTeam][i16 dstTeam][i64 mb][i64 aCG]` - the ack for **6013** `OpFighterAssignTeam`, emitted by `sendFighterAssignedTeam` after a successful assign/remove. The fields are the request echoed + the effective id aCG: `dx_2` unlinks the fighter from preset **srcTeam** (`at(aCE).l(K)` — `sw_1.bMJ` is the preset's fighter→coach map and `l()`=`dv`=remove), re-keys the entity when K≠aCG, then files `aCG` under coach `mb` (= the request's `am`) in the **currently open preset** (`II().j(aCG,mb)` — `j`=`bMJ.l`=put). `aCF` (dstTeam) is decoded but never read. We never re-id: `aCG=fid` on assigns, **`aCG=-1` on removals** — the sentinel `sw_1.j` refuses (logs, no put), which is how a pure remove avoids re-adding itself |
| 6020 | S2C | E | TeamPresetSaved (aic_0) | `[i8 status]`; the full preset follows ONLY when status==0 (`aic_0` reads nothing after a non-zero status, so an error frame is exactly one byte). **25** = `error.teamManagement.teamNameExist`, any other non-zero = the generic save error. We send 25 to refuse a duplicate preset name (B-131); the success payload is still carried by the 6030 list re-send |
| 6021 | C2S | H | SaveTeamPresetRequestMessage (aqH) | `handleTeamPresetSave` |
| 6022 | S2C | E | TeamPresetDeleted (agH) | `[i8 status]` + `[i16 teamId]` **only when status==0** (`agH` reads the id inside `if (aV == 0)`). Required, not cosmetic: 6030 merges by preset id and `bs_0.IF().IG()` purges only DUO presets, so without this a deleted preset stays on screen until relog (B-130) |
| 6023 | C2S | H | DeleteTeamPresetRequestMessage (aad_1) | `handleTeamPresetDelete` |
| 6024 | C2S | H | TeamUpRequest (ir_0), arch 2 | `handleTeamUpRequest` - **2v2 team formation**. `[u8 teamName][i64 inviterId][i64 invitedId]`. Sent by the team panel (hu_2 case 16636) after `team2vs2NameDialog`; the teammate is picked from the coach's own FRIEND LIST (case 16635). The inviter id is IGNORED server-side in favour of the sender |
| 6025 | S2C | E | TeamUpInvitation (dy_2) | `[u8 teamName][u8 inviterName][i64 inviterId][i64 invitedId]` - pops *"[name] te propose de faire equipe avec lui/elle"* (ug_1 case 6025) |
| 6026 | C2S | H | TeamUpAnswer (abB), arch 2 | `handleTeamUpAnswer` - `[i8 accept][u8 teamName][i64 inviterId][i64 invitedId][i16 reason]`. The client auto-refuses with reason=2 when already teamed or the inviter is ignored |
| 6027 | S2C | E | TeamUpRefused (lk_0) | empty - *"Le coach a refuse la creation, ou est indisponible."* |
| 6028 | S2C | E | TeamUpAccepted (ahh_2) | empty - BOTH clients open the fighter picker (`hu_2.li()`) |
| 6029 | S2C | E | TeamUpCoachGone (OJ) | `[i8 status]` - `dx_2` shows *"error.teamManagement.coachDisconnected"* whatever the value, so the opcode IS the message. Sent when one half of a 2v2 pair disconnects (B-132) |
| 6030 | S2C | E | TeamPresetListMessage (ar_0) | `pushTeamPresetList` |
| 6031 | C2S | H | TeamPresetListRequestMessage (ys_1) | `handleTeamPresetListRequest` |
| 6032 | S2C | - | CoachConditions (gd_0) | `[u8 count]{[i16 conditionId][u8 grade]}` stored on the local coach (`sj_1.uk` via `kh()`). The values are **type-902 condition ids**: `bf_1.df().g(id)` resolves each to an `aiz_2` definition and `aic_1` strips the curable ones (`ayT()`) on a probability roll - the same wound/blessing layer we already model per FIGHTER. **Not implemented because the server has no coach-level condition model**, so this is a feature (decide what gives a coach a condition, and when it clears) rather than a wire gap. The decode is settled; the game design is not |
| 6200 | S2C | E | EffectAreaActionMessage (jD) | `buildEffectAreaAction` — plays a special cell's tile animation (B-048) |

### 8000 – 8400 — fight lifecycle & combat actions

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 8000 | S2C | E | FightCreationMessage (aat_2) | `buildCreateFight` (presentation blob) |
| 8010 | S2C | E | StartPresentationMessage (akx_1) | phase cue |
| 8011 | C2S | H | TeamMateSetReadyForPlacementRequestMessage (au_2) | `handleReadyForPlacement` |
| 8012 | S2C | E | TeamMateSetReadyForPlacementMessage (aio_0) | ready ack |
| 8018 | S2C | E | EndPresentationMessage (akl_1) | phase cue |
| 8020 | S2C | E | StartPlacementMessage (ut) | phase cue |
| 8021 | C2S | H | MoveToFreePlacementRequestMessage (adn_0) | `handleMoveToPlacement` |
| 8022 | S2C | E | MoveToFreePlacementMessage (lk_2) | placement move broadcast |
| 8023 | C2S | H | TeamMateSetReadyForObservationRequestMessage (auq_0) | `handleReadyForObservation` |
| 8024 | S2C | E | TeamMateSetReadyForObservationMessage (dw_1) | ready ack |
| 8028 | S2C | E | EndPlacementMessage (aaw_0) | phase cue |
| 8030 | S2C | E | StartObservationMessage (agp_2) | phase cue |
| 8031 | C2S | H | TeamMateSetReadyForActionRequestMessage (nS) | `handleReadyForAction` |
| 8032 | S2C | E | TeamMateSetReadyForActionMessage (aMC) | ready ack |
| 8038 | S2C | E | EndObservationMessage (aPo) | phase cue |
| 8040 | S2C | E | StartActionMessage (tt_0) | phase cue |
| 8100 | S2C | E | NewTableTurnBeginMessage (jg_1) | new round; the i32 tail is the round's EVENT CARD id (0 = none). Display-only client-side — the server draws it and applies its effects (see events.go, BUGS B-054) |
| 8104 | S2C | E | FighterTurnBeginMessage (kw_2) | turn begin |
| 8105 | C2S | H | FighterEndTurnRequestMessage (rC) | `handleFighterEndTurn` |
| 8106 | S2C | E | FighterTurnEndMessage (TJ) | turn end |
| 8107 | C2S | H | FighterCardUseRequestMessage (sg_2) | `handleFighterCardUse` → `useFighterCard`: a fighter using its EQUIPMENT's active ability (the weapon attack) at a target cell. Sent by the client's `abt_1` mode carrying a `ve_0` (fighter equipment, NOT a coach card). Distinct from 8109 spell cast (B-047) and 8111 close combat; resolves the card's `FIGHTER_CARD_USE` effects (B-055) |
| 8108 | S2C | E | FighterCardUseMessage (arn_0) | `buildFighterCardUse` — card-play broadcast |
| 8109 | C2S | H | SpellCastRequestMessage (mc_2) | `handleSpellCast` — **the real spell cast**; was unhandled (B-047) |
| 8110 | S2C | E | SpellCastMessage (axn_0) | spell-cast result |
| 8111 | C2S | H | CloseCombatRequestMessage (aso_0) | `handleCloseCombat` — "corps-à-corps", the UNARMED punch. Sent by the client's `agd_1` mode with only the fighter + target cell (no card id), so it is weapon-INDEPENDENT and always available. Uniform 5 AP / 5 dmg (7 crit) of the breed's element, verified against the client's `xq` table (`DO`/`DP`/`DQ`). Attacking with a weapon is 8107 instead |
| 8112 | S2C | E | CloseCombatMessage (aAD) | close-combat result |
| 8120 | S2C | E | RunningEffectActionMessage (amb_0) | damage/heal/effect chat lines |
| 8121 | S2C | E | AttachScriptedEffect (rq_2) | `[i32 actionId][i16 blobLen][blob][i64 fighterId][i16 expiry][i8 flag]`. **Attaches** an effect as a buff — it never executes one, which is exactly why the buff resync uses it and not 8120 (`of_1` case 8120 *runs* the effect, so replaying buffs through that would double every one). `expiry` is an ABSOLUTE mark against the fighter's own turn counter (`aGT` builds `aAy() + duration`, reads back `expiry - aAy()`); negative = infinite. Executing (incl. **117 MapDestruction**) goes via 8120 (B-050) |
| 8122 | S2C | - | DetachBuff (zq_1) | `[i64 buffId][i64 fighterId]` - the removal counterpart to 8121: `of_1` does `ee_2.PJ().dL(buffId)` and raises `"hasBuff"`. **Unusable, now proven**: `alf_1` keys buffs by `je()`→`aFL`, and `xb_2.aka()` assigns `aFL = bWD != null ? bWD.n() : ahT()` — the `aes_2` provider `bWD` is never installed anywhere in the client (`xb_2.a(aes_2)` has no caller), so every buff id is the client-local counter `bWC++`. 8121's `rq_2` carries no id field either, so the wire cannot address a buff instance. Same wall as item 14's 5203 uids — deliberate non-work |
| 8151 | C2S | H | GiveUpFightRequestMessage (as_1) | `handleGiveUp` (forfeit) |
| 8200 | S2C | E | FightActionSequenceExecute (ayj_0) | action flush barrier |
| 8250 | S2C | - | (`wc_2`) | `[i64 coachId][i8 flag]`. `aez_0.nw(1)` when true, `nw(2)` when false; if the id is the local coach and the flag is false it shows **"cheat.turnDuration.decreased"**. This is a **turn-duration penalty** toggle. Not implemented: the wire is settled but nothing in the client says what earns the penalty - that is an anti-cheat policy decision, not a protocol gap |
| 8300 | S2C | E | EndFightMessage (YP) | fight result screen |
| 8400 | S2C | - | (`aBZ`) | EMPTY payload, `a(byte[])` is `return true`, and **no consumer anywhere** - only the `gz_1` factory references it. Inert, exactly like 27552 |

### 15000 – 17010 — unidentified subsystems

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 15000 | C2S | H | MailListRequest (ajs_0) | `handleMailListRequest` — mailbox open |
| 15001 | S2C | E | MailList (ayV) | `buildMailList` — **this reply is what opens the dialog** |
| 15003 | S2C | E | MailSendResult (Eh) | reply to 539; `-2` = recipient's box full |
| 15004 | C2S | H | MailDelete (ads_0) | `handleMailDelete` |
| 15005 | S2C | E | MailNewNotice (wt_2) | "you have new mail" toast |
| 15006 | C2S | H | MailTakeCards (akk_1) | `handleMailTakeCards` |
| 15007 | S2C | E | MailCardsTaken (cb) | attachment payout |
| 15506 | C2S | H | MailCheckName (rr_1) | `handleMailCheckName` — recipient validation |
| 15507 | S2C | E | MailNameResult (afj_2) | `0` = no such coach |
| 17002 | C2S | H | TournamentCalReq (yq_1) | `handleTournamentCalendarRequest` (TournamentTotem) |
| 17003 | S2C | E | TournamentCalendar (awa_0) | `buildTournamentCalendar` — standing tournaments as typeId=4 qr_0 events |
| 17004 | C2S | - | (`fu_2`) | `[i64 1]` - **Test-Lua-only**: `acL` is a `uc_1` console action (the `adg_1` debug console), not gameplay. Same deliberate non-work class as 513/551 |
| 17005 | S2C | - | (`aef_1`) | `[i32 typeId]` followed by a **polymorphic** payload: the client resolves `tb_0.zl().dD(typeId)` to an `iz_0` and lets IT read the rest. Consumed by **`zN`** (line 58), so this 17xxx block is tournament-adjacent rather than an unknown subsystem. Not implemented: the payload shape depends on a type registry we do not model |
| 17006 | C2S | - | (`agh_2`) | `[i64 5][iz_0 event]` - **Test-Lua-only** (`alc_2` console action): sends a hardcoded `wk_1` TEST event. Same class as 513/551 |
| 17008 | C2S | - | (`ald_2`) | `[u8 n]{iz_0 events}` - **Test-Lua-only** (`avb_0` console action): pushes hardcoded `jF`/`qr_0`/`nc_0`/`ayo` TEST events. Same class as 513/551 |
| 17010 | C2S | - | (`aFu`) | **Player-created calendar tournaments** (`oz_1` case 20072): gated on card 807 (owned or inscribed in tome, `bW(-807)`), sends name+description+round schedule; the client locally shows "tournamentCreated" and expects no ack. Deliberate non-work for now: ours are admin-curated `domain.Tournament` rows against the 22-record type-1000 catalogue, and a defId-less custom event could never satisfy the client's unguarded definition deref at registration time - a real model gap, not a codec |

### 22000 – 23116 — statistics / achievements, fight-setup & matchmaking

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 22000 | S2C | E | AchievementUnlocked | the client's own "Exploit debloque" toast (B-106) |
| 22001 | C2S | H | StatisticRequest (anp_0) | `handleStatisticRequest` - the only legitimate trigger for 22002 |
| 22002 | S2C | E | StatisticData | **reply-only**: emitted solely from `handleStatisticRequest` (22001). Never send it spontaneously - the permanently-registered tutorial handler `asA` would pop the tutorial-guide dialog |
| 22003 | C2S | H | StatisticUpdate (nq) | `handleStatisticUpdate` � the client self-reports criteria 210/218/221/229/39 here; echoed back via 2052 |
| 22004 | C2S | - | (`axH`) | `[i64 coachId]` - **abuse-report support frame**: the `chat.reportIncorrectBehaviour` context action (`gy_1`/`qq_2`) sends AddIgnore(3131) + this. Deliberate non-work: moderation/report pipeline does not exist server-side |
| 22092 | S2C | - | (`axA`) | `[i64 actorId][i16 flag]` -> `aez_0.cm()`: the flag rendered as `<text 56/57>` in the actor hover tooltip (`bu_2`, only when !=0). The same field already rides inside the coach spawn blob's own decode (`aez_0` line ~474). Deliberate non-work: no server-side source for the flag exists - pushing it would be inventing a status policy |
| 22093 | C2S | - | (`Tx`) | `[i32]` - **cross-game card transfer** (`agn_0` case 16443). Deliberate non-work: there is no other Ankama game to transfer to |
| 22094 | S2C | E | FireworkShow (la_1) | echoed to launcher + `SessionsNear` |
| 22095 | C2S | H | FireworkLaunch (axf_0) | `handleFireworkLaunch` |
| 22097 | C2S | - | (`OB`) | `[i32]` - **cross-game card transfer** (`agn_0` case 16442): the client locally toasts `coachInventory.otherGameCardSent`. Deliberate non-work: account-link transfer to another Ankama game cannot exist here |
| 22099 | C2S | H | FighterUseItemOn (bw) | `handleFighterUseItemOn` — resurrection: gated on the card carrying a real resurrection effect (action 13), rolls its decoded % (rand 1..100 <= pct), consumes the card either way, revives only on success |
| 23000 | C2S | H | FighterSetState (Jc) | `handleFighterSetState` � titular/bench/graveyard/legendary |
| 23001 | C2S | H | EvolutionSearchCancel (abn_0) | `handleEvolutionSearchCancel` |
| 23002 | S2C | E | EvolutionSearchCancelResult (wf_2) | `[i8 accepted]` - closes `evolutionSearchStatusDialog` |
| 23003 | C2S | H | EvolutionSearchRequest (ajw_0) | `handleEvolutionSearchRequest` |
| 23004 | S2C | E | EvolutionSearchResult (amh_0) | `[i16 preset][i8 accepted]` - opens the search overlay |
| 23006 | S2C | E | EvolutionFightStarting (azl_0) | empty - *"Lancement du combat"*, closes the overlay before CREATE_FIGHT |
| 23008 | S2C | E | EvolutionSearchError (KL) | `[i8 code]` - 1 impossibleToStartOpponentsSearch, 2 badTeam, 3 ... |
| 23009 | C2S | H | SphereBuy / Kanodo (aow_2), arch 3 | `handleSphereBuy` - `[i64 fighterId][i32 sphereId][i32 cardTemplateId]`. No reply and no rejection path, so every rule is re-derived server-side |
| 23101 | C2S | H | ClassicSearchCancel (bm_1) | `handleClassicSearchCancel` |
| 23102 | S2C | E | ClassicSearchCancelResult (ada_1) | `[i8 accepted]` - closes `classicSearchStatusDialog` |
| 23103 | C2S | H | (atj_0) | `handleClassicReadyForFight` ("Combattre" ready-up) |
| 23104 | S2C | E | ClassicSearchResult (aLi) | `[i16 teamId][i8 accepted]` - opens the search overlay |
| 23106 | S2C | E | ClassicFightStarting (ads_2) | empty - *"Lancement du combat"*, closes the overlay before CREATE_FIGHT |
| 23108 | S2C | E | ClassicSearchError (M) | `[i8 code]` - same code table as 23008 |
| 23110 | S2C | E | (tb_2) | `MatchFound` ("do you accept?") |
| 23112 | S2C | E | MatchResult (`aku_1`) | `[i8 ok]` - the result frame paired with 23110: `avn_0.close()` + "resultIsNo" toast on 0. `sendMatchCancelled` emits it to the still-waiting coach when the other side declines |
| 23114 | C2S | H | (acz_2) | `handleMatchAccept` |
| 23116 | C2S | - | (`aex_0`) | `[i32 N][i64×N reversed]` team-confirm roster, sent by `aox_0` on dialog answer 4 (`hu_2`). **C2S-only**: `gz_1` has no 23116 case, so nothing we emit here can be decoded (the old `sendMatchCancelled` emitted exactly that - silently dropped; now uses 23112). Inbound is the roster the client confirms after a match; our match starts on dual-accept without needing it |

### 25000 – 26334 — challenge, spectate, reconnect, fight-done, team-test

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 25000 | S2C | E | ErrorNotice (`az`) | `[i8 code]` -> `zN.M(code)`: the bare localized-error toaster (same ~25-entry code table as 26310, minus its frame cleanup). Emitted for the clan-island Zaap refusal (`FightErrNoIsland`=72 -> "error.guild.noIsland") |
| 26300 | S2C | E | (wu_2) | `ChallengeInvitation` (both sides) |
| 26301 | C2S | H | (hk_1) | `handleChallengeInvite` |
| 26302 | S2C | E | (pu_1) | `ChallengeAccepted` (open team panel) |
| 26303 | C2S | H | (bl_1) | `handleFightReadyConfirm` (in-fight "Prêt" **and** challenge team-confirm) |
| 26304 | S2C | E | (gz_0) | `ChallengeCancelled` |
| 26305 | C2S | H | (vT) | `handleChallengeAccept` |
| 26307 | C2S | H | (mz_0) | `handleChallengeDecline` (decline / cancel / withdraw) |
| 26310 | S2C | E | FightCreationError (nx_1) | `sendFightCreationError` — refuses the challenge sentinel (`errorCode 34`) |
| 26312 | S2C | - | (axr_0) | Challenge setup-abort reason — **deferred** |
| 26313 | C2S | - | (aju_1) | **X-vs-X challenge with allies — deferred** |
| 26314 | S2C | - | (ahV) | **X-vs-X challenge with allies — deferred** |
| 26321 | C2S | H | (nv_0) | `handleEndFightDone` (ack result screen) |
| 26330 | C2S | H | TeamTest / ChallengeLaunch (alv_1) | `handleTeamTest` — **dual meaning**, told apart by field 2: `[i32 fightType][i16 teamId]` = "Tester" solo practice; `[i32 challengeId][i16 99]` (arch **2**) = overworld challenge → `startChallengeFight` |
| 26331 | C2S | H | (x_0) | `handleSpectateJoin` |
| 26332 | S2C | I | (azb_0) | Defined; spectator teardown done via 8300 END_FIGHT instead |
| 26333 | S2C | E | (uz_0) | `ReconnectFightQuestion` ("resume your fight?") |
| 26334 | C2S | H | (aiw_1) | `handleReconnectFightAnswer` |

### 27500 – 28650 — ladder + two large unidentified paired families

| Op | Dir | St | Client class | Notes |
|---|---|---|---|---|
| 27500 | C2S | H | LadderRequest (dp_0) | `handleLadderRequest` — **1v1** board `[i32 windowStart]` |
| 27501 | S2C | E | LadderResponse (azd_0) | `buildLadderResponse` — 1v1 window; rows = end-start; u8 searchBtn |
| 27502 | C2S | H | GuildLadderRequest (pc_1) | `handleGuildLadderRequest` — **guild/clan** board `[i16 board][i32 start]` |
| 27503 | S2C | E | GuildLadder (ij_1) | `buildGuildLadder` — `[i16 1][i32 start][i32 N]{clan,leader,score}`; empty until guilds exist |
| 27504 | C2S | H | Ladder2v2Request (vg_1) | `handleLadder2v2Request` — **2v2** board `[i32 start]` |
| 27505 | S2C | E | Ladder2v2Response (aka_0) | `build2v2Ladder` — 2v2 window; icon list; **i32** searchBtn; empty until 2v2 teams exist |
| 27506 | C2S | H | TournamentLadderRequest (qk_2) | `handleTournamentLadderRequest` — the **"Tournoi"** tab (was mislabelled "seasonal", B-046) |
| 27507 | S2C | E | TournamentLadder (uj_0) | `buildTournamentLadder` — tournament points; 3 windows (month/trimester/year), empty |
| 27508 | C2S | H | CoachReputationRequest (aa_2) | `handleCoachReputationRequest` � ranking window "Coach" tab |
| 27509 | S2C | E | CoachReputation (jw_0) | `buildCoachReputation` � derived-count window; empty (reputation not modelled) |
| 27510 | C2S | H | DemonLadderRequest (aid_1) | `handleDemonLadderRequest` (DemonTotem) |
| 27511 | S2C | E | DemonLadder (anc_0) | `buildDemonLadder` — per-demon drill-down; **20-byte empty stub**; statusFlag must be 1, trailing i64 affiliation is per-message |
| 27512 | C2S | H | DemonListRequest (ow_2) | `handleDemonListRequest` � ranking window "D�mon" tab |
| 27513 | S2C | E | DemonList (xn_2) | `buildDemonList` � the 24-demon roster (12/page), reputation 0 |
| 27514 | C2S | H | ProLeagueLadderRequest (ck_2) | `handleProLeagueLadderRequest` — the real **"Ligue Pro"** tab (B-046) |
| 27515 | S2C | E | ProLeagueLadder (amu_0) | `buildProLeagueLadder` — well-formed empty; total bounds the client's clear loop |
| 27525 | C2S | X | (`zz_0`) | `[u8 len][appearance][i8][i8][i8][i16 len][blob]` - the **same field layout as 27526**, and `zz_0` also carries the static avatar-render helper the 27526 handler calls. This is the C2S half of Ankama's internal avatar pipeline. **Never implement** (see 27528) |
| 27526 | S2C | X | (`jg_2`) | `[u8 n][appearance][i8][i8][i8][i16 n][blob][i64 coachId]`. Builds an `aez_0` coach from the payload, renders its avatar offscreen, replies **27527** (`gc_0`) with a hash-match flag, and stashes the PNG. **Never implement** - see 27528 |
| 27527 | C2S | X | (`gc_0`) | `[i64 coachId][blob hash][i8 match]` - the client's reply to **27526**, reporting whether the avatar it rendered matches the hash the server sent. Part of Ankama's internal avatar-upload pipeline; a normal server never sends 27526, so this never arrives. **Never implement** (see 27528) |
| 27528 | S2C | X | (`eq_1`) | `[i8 len][blob]`. Opens a TLS socket to **`ws.ankama.lan:443`** and `POST /ankama/Accounts_Game/UploadAvatar` with the PNG rendered by 27526, tagged with the account id and `universe=5`. **Never implement**: this is Ankama's *internal* avatar-generation pipeline (they drove real clients to render account avatars into their account service). `ws.ankama.lan` does not resolve outside Ankama's LAN, so on any other server it can only produce a stack trace and leak the account id. The success branch in the client is literally empty |
| 27529 | C2S | H | (bl) | `handleDestroyCoach` ("Détruire le coach") |
| 27551 | C2S | - | (`aib_1`) | EMPTY payload (`and_2`, a `ja_1` dialog answer 8): sets `zN.aY(false)` - the flag gating LOCAL achievement toasts - then sends this as the "notifications off" preference ack. Deliberate non-work: it flips a client-local display flag; nothing server-side changes and no reply is read |
| 27552 | S2C | - | (`amk_0`) | EMPTY payload and `a(byte[])` is `return true` - no fields at all. Registered in the `gz_1` factory but **referenced by no handler anywhere**, so decoding it is where it ends. Inert |
| 28601 | C2S | H | TournamentListReq (wa_2) | `handleTournamentListRequest` — **28xxx is the tournament subsystem** |
| 28602 | S2C | E | TournamentList (ng_2) | `buildTournamentList` — registerable tournaments, per-coach status |
| 28603 | C2S | - | TournamentAdmin? (`ayQ`) | **unsendable by retail**: the class is constructed NOWHERE in the client (verified case-sensitively). Tournament admin family - see the note above the legend |
| 28604 | S2C | - | (`auE`) | Reply in the tournament admin family. Its handler `ajp_0` **is** registered, so the client would process this if sent - it is orphaned, not dead. Unimplemented because it answers 28603, which the client cannot send |
| 28605 | C2S | - | TournamentAdmin? (`bi_2`) | **unsendable by retail**: the class is constructed NOWHERE in the client (verified case-sensitively). Tournament admin family - see the note above the legend |
| 28606 | S2C | - | (`aik`) | As 28604; answers 28605 |
| 28607 | C2S | - | TournamentAdmin? (`ago_0`) | **unsendable by retail**: the class is constructed NOWHERE in the client (verified case-sensitively). Tournament admin family - see the note above the legend |
| 28608 | S2C | E | TournamentRegisterReply (dy_0) | reply to 4607: [i64 tid][i8 err] (0=accepted) |
| 28609 | C2S | H | TournamentSearchCancel (bt_0) | `handleTournamentSearchCancel` - refuses visibly rather than going silent (B-100) |
| 28610 | S2C | E | TournamentSearchCancelResult |  |
| 28611 | C2S | H | TournamentSearchRequest (ly_1) | `handleTournamentSearchRequest` - `[i64 tid][i64 coachId][i16 preset]`. Only an ENTRANT may ready up; pairing is scoped to the one tournament |
| 28612 | S2C | E | TournamentSearchResult (DR) | `[i64 tid][i16 preset][i8 accepted]` - opens the client's waiting dialog (`tournamentsSearchStatusDialog`). Must be sent, or the team panel closes leaving no overlay |
| 28614 | S2C | E | TournamentFightStarting (azj_0) | `[i64 tid]` - *"Lancement du combat"*. Closes the waiting dialog, so it goes out BEFORE CREATE_FIGHT |
| 28616 | S2C | E | TournamentSearchError |  |
| 28617 | C2S | - | TournamentCarryStanding (afg_2) | `[i64 tid]` - the player answering YES to 28618's *"report my position to the next tournament of the same type?"* dialog (`ajp_0`:152 -> `gs_2`, answer 16). Reachable and player-facing but **blocked, not dead**: the whole flow is gated on 28618, which only makes sense once tournaments actually END - the live-match layer (opponent search, scheduled fights, bracket progression) is the documented deferral in tournaments.go. Implementing the ack alone would fabricate a carry rule with no unfinished tournaments to carry from |
| 28618 | S2C | - | TournamentUnfinished (ahd_0) | `[i64 tid]` - *"Vous avez participe a un tournoi que vous n'avez pu terminer"* + the carry-over question. The SERVER must send this to start the flow; answering it sends 28617. **Blocked on the same live-match deferral as 28617**: no tournament ever reaches "ended while you were registered" today, so there is nothing honest to report |
| 28620 | S2C | E | TournamentFinale (Yq) | ADD `[i8 1][i64 id][i32 n]{i64 coachId}[i32 n]{[i32 len][utf8]}[i32 len][utf8 tournamentName]`, REMOVE `[i8 2][i64 id]`. The "Finale du tournoi X - A VS B" alert. **`Yq.a` reads BOTH arrays backwards**, so they are written in reverse or the finalists are announced swapped |
| 28622 | S2C | - | (`uw_2`) | Consumer `ds_2` case 28622 is `bl2 = false; break;` - it assigns a local flag and returns. **No-op**: sending it changes nothing. (This is the row that scores "substantive" in the mechanical empty-body sweep precisely because of that assignment - see the sweep's stated limitation) |
| 28630 | S2C | E | TournamentSearchPeriod (dg_0) | `[i64 tid][i8 open]` - opens/closes a tournament's opponent-search period. Creates the client's tournament NOTIFICATION (`zN` builds a `td_0`), and clicking that is the ONLY way to select a tournament (`agz_1` -> `vk_1.ad(tid)`). Without it `hu_2` refuses Combattre with `error.noTournamentSelected` forever |
| 28633 | C2S | - | TournamentAdmin? (`kx_2`) | **unsendable by retail**: the class is constructed NOWHERE in the client (verified case-sensitively). Tournament admin family - see the note above the legend |
| 28634 | S2C | - | (`acn_2`) | As 28604; answers 28633 |
| 28635 | C2S | - | TournamentAdmin? (`aeC`) | **unsendable by retail**: the class is constructed NOWHERE in the client (verified case-sensitively). Tournament admin family - see the note above the legend |
| 28636 | S2C | - | (`aig_1`) | As 28604; answers 28635 |
| 28644 | S2C | E | TournamentSearchUpcoming (aaj_0) | `[i64 tid][i64 startEpochMillis]` - the countdown to a tournament's next opponent-search period. `zN` shows `1 + (start-now)/60000` minutes, so a start in the PAST renders a negative count; sent only while the window is still ahead |
| 28646 | S2C | - | (`aNq`) | `zN` case 28646 adds its `td_0` WITHOUT the duplicate guard that case 28630 has. **Blocked, not unwritten**: 28630 must stop being the tournament-selection mechanism before this can be sent, or the client accumulates duplicate entries |
| 28648 | S2C | E | TournamentSearchEnded (df_1) | `[i64 tid][i8 forfeit]` - closes an opponent-search period. forfeit=0 is *"the other player was not searching while you were, so you are declared winner by forfeit"*; forfeit=1 is the same sentence reversed. The ONLY server-side way to dismiss `tournamentsSearchStatusDialog` (`zN` case 28648), so an unopposed coach that never gets this waits in it forever |
| 28649 | C2S | H | TournamentTreeReq (alf_0) | `handleTournamentTreeRequest` - `[i64 tournamentId][i32 page][i32 len][utf8 highlightName]`. The page is driven by the tree dialog's paging buttons (20069) and the name by its search box (20068) |
| 28650 | S2C | E | TournamentTree (IL) | `encodeTournamentTree` - `[i32 page][i32 n]{[i32 slot][i32 len][utf8 name]}[i32 unread]`. A 1-indexed binary heap: 1 winner, 2-3 finale, 4-7 semi, 8-15 quarter, 16-31 first round (`ah_1.getFieldValue`). Names are **UTF-8**, not cp1252. Upper rounds stay empty until a match layer decides them |

---



### Where to start (highest value first)

Coverage today (counted from the table 2026-10-05): **345 rows - 109 C2S
handled, 150 S2C emitted, 6 inactive, 4 never-implement, 76 unimplemented**. Of the remainder, **every row now carries its evidence** - unreachable constructors, inert consumers, Test-Lua-only console actions, client-local identifiers, Ankama-internal pipelines, missing game models - rather than a bare "unknown". The pass produced these real changes:

1. ~~Chat errors (`om_0`, 3206/3210/3216)~~ - **all four already emitted** (3206
   malformed `/` cmd, 3210 non-admin `/`, 3214 self-whisper, 3216 social-list-full),
   plus 3204 for unknown names. Only 3212 (`notYetImplemented`) still has no call
   site, marked `I` deliberately.
2. ~~8122 buff detach (`of_1`)~~ - **checked, unusable**: the buff id IS the
   client-local `ahT()` counter (`bWC++`; the `aes_2` provider `bWD` has no caller
   anywhere), and 8121 carries no id field, so the wire cannot name a buff.
   Recorded on the 8122 row as deliberate non-work.
3. ~~Search-flow siblings~~ - **already implemented**; the rows were stale (see below).
4. ~~Team presets (`dx_2`, 6014/6020/6022/6029/6032)~~ - **done/resolved**. 6020/6022/6029
   were already emitted; **6014 is now sent** on every applied assign/remove (echo of the
   request + `aCG=fid`, or `aCG=-1` for pure removes), and **6032 is a feature, not a wire
   gap** — nothing grants coach-level conditions, so there is nothing to report (see its row).
5. ~~Guild replies (`lh_1`, 512/552/554)~~ - **all emitted**: 554 was already wired
   (`pushGuildTags` at login, `broadcastGuildTag` on membership changes, 556 clears);
   it now has a regression test.
6. **23112 MatchResult - new emission + a real bug fix.** `sendMatchCancelled` used to
   emit **23116**, which `gz_1` never registers - the retail decoder dropped it silently.
   It now emits 23112 `[i8 0]` (`avn_0.close()` + "resultIsNo" toast for the
   still-waiting coach).
7. **25000 ErrorNotice - new emission.** The bare `zN.M(code)` error toaster (26310's
   code table minus frame cleanup). First call site: the clan-island Zaap refuses with
   `error.guild.noIsland` (72) instead of silently dropping.
8. **5204 AddToTome - new handler.** The card context-menu "inscribe in grimoire"
   (`ST.b(8)`; `[i32 templateId]` - not uid-blocked like 5203): ownership-checked,
   grow-only `SyncTome` insert; the client expects no reply.
9. ~~Reachable C2S (`4514/4518/4519/4523/4701/5204/17004-17010/22004/22093/22097/
   27525/27527/27551/28617`)~~ - **fully resolved**: 4514/4701 were already handled;
   4518/4519/4523 are console commands with no counterpart stream; 17004/17006/17008
   are `adg_1` Test-Lua actions sending hardcoded TEST events; 17010 needs a
   custom-tournament model that cannot satisfy the client's unguarded defId deref;
   22004 is abuse-report support (no moderation pipeline); 22093/22097 are
   cross-game card transfer (no other game exists); 27525/27527 are the
   Ankama-internal avatar pipeline (X); 27551 flips a client-local toast flag;
   28617 is blocked behind 28618, which needs tournaments that actually END.
10. ~~S2C family sweep~~ - 2411's wire is now fully decoded (per-preset ladder record;
    needs a per-preset stats model to fill honestly); 22092 is a hover-tooltip
    status flag with no server-side source; the 4900/4901 pair feeds a client-side
    recorder queue nothing visible reads. All rows carry the evidence.

The low system opcodes (100-204) and single-consumer one-offs stay `-` for real
reasons too (connection-stage alternates our handshake does not take, the
unresolvable `tg_1` setter at 4000, `RunScript` ids living in client content we
do not model). Guessing there is how the 8120-vs-8121 mistake happened.



> **Blind spot in the invariant test - now CLOSED.**
> `TestOpcodeInventoryMarksEveryEmittedFrame` scans `EncodeS2C` call sites for a
> LITERAL opcode, so a helper taking the opcode as a variable - like
> `sendChatError(opcode uint16)` - was invisible to it. 3214 was emitted while
> still marked `-` and the suite stayed green.
>
> `TestVariableOpcodeHelpersAreInventoried` covers that case. It DISCOVERS the
> helpers rather than listing them - any method taking `opcode uint16` whose body
> reaches `EncodeS2C` - then resolves the `protocol.Op*` constant at each call site
> and requires the row to be marked `E`. Adding a new helper cannot silently
> reopen the hole.
>
> Two details it has to be correct about, both learned by getting them wrong:
> taking an opcode is NOT the same as sending one (`Router.Register(opcode
> uint16, ...)` matches the signature and emits nothing), and it FAILS rather
> than passes when discovery finds nothing, so a rename cannot turn it into a
> no-op.


> **The `-` status was unreliable for anything sent INDIRECTLY, and 10 rows were wrong.**
> `TestOpcodeInventoryMarksEveryEmittedFrame` scans `EncodeS2C` sites for a literal opcode,
> so it never saw opcodes passed as a parameter (`sendChatError`) or held in a struct field
> (`searchFamily{result: ...}`). Both classic and evolution search handshakes
> (23002/23004/23006/23008, 23102/23104/23106/23108) and two guild replies (512, 552) had
> been implemented for a long time and still read as "not implemented" - which inflated the
> backlog and put finished work at the top of the start list above.
>
> `TestNoUnimplementedRowIsActuallyWired` now fails if a row marked `-` or `I` has its
> protocol constant referenced anywhere in `internal/game`. It proves the row needs
> re-checking rather than proving a frame is sent, which is the right failure mode for a
> document people plan from. It matches on a word boundary: the first version reported
> `OpCoachEquipmentUpdate` as used because `OpCoachEquipmentUpdateRequest` contains it.

### Why each unimplemented C2S is unimplemented

A C2S opcode we do not serve is a message the client can SEND and we silently drop,
so each one needs a reason on the record rather than a family label. Every entry
below was checked the same way: search the decompiled client CASE-SENSITIVELY for
`new <class>(`. A message class with no constructor cannot be sent by the retail
client whatever its opcode implies.

**'DEAD in retail' does not mean Ankama never used it.** These are real messages and
were presumably driven by an internal build or admin tool. It means only that no
code path in the SHIPPED 2.70 client constructs one, so a server handler could not
be reached by a player, and could not be live-verified the way everything else here
is. Implementing one would also make a privileged operation reachable by anyone who
patches a client, so if any are ever added they must be gated on the account admin
flag.

| Opcode | Class | Status | Reason |
|---|---|---|---|
| 101 | `aFC` | dead | DEAD - no constructor anywhere in the client. |
| 513 | `wt_1` | dead | DEAD in retail - guild RENAME, reachable only from the client Test Lua debug library. No UI, no assets (ROADMAP item 31). |
| 551 | `mx_1` | dead | DEAD in retail - guild ICON, same Test-Lua-only path as 513. |
| 4514 | `aII` | DONE | `/resetPosition` console command (player-facing unstick) - `handleResetPosition` teleports to the current world's primary Zaap (B-135). |
| 4518 | `Ab` | reachable | `/ignoreEventsMessages` console command; client also despawns every other actor locally and sends the frame twice (its own bug). Deliberate non-work - we have no event-message stream to mute. |
| 4519 | `aOx` | reachable | `/acceptEventsMessages` console command, counterpart to 4518 (also sent twice). Deliberate non-work, same reason. |
| 4523 | `anv_0` | reachable | `/skipTutorial` console command. Deliberate non-work - there is no tutorial to skip. |
| 4701 | `JY` | DONE | Emote play - `handleEmote` relays to the AoI as 4700 including the sender (the client never plays its own emote locally). |
| 5204 | `ajm_2` | DONE | "Inscribe in grimoire" - `[i32 templateId]` (not a uid). `handleAddToTome` ownership-checks then `SyncTome`s it. |
| 17004 | `fu_2` | reachable | Test-Lua-only (`acL` console action) - `[i64 1]`. Deliberate non-work, same class as 513/551. |
| 17006 | `agh_2` | reachable | Test-Lua-only (`alc_2` console action) - hardcoded TEST calendar event. Deliberate non-work. |
| 17008 | `ald_2` | reachable | Test-Lua-only (`avb_0` console action) - hardcoded TEST events. Deliberate non-work. |
| 17010 | `aFu` | reachable | Player-created calendar tournaments (card 807 gate, `oz_1` 20072). Real model gap - custom events have no type-1000 defId, and registration derefs it unguarded. Documented deliberate non-work, not a codec. |
| 22004 | `axH` | reachable | Abuse-report support (`[i64 coachId]`, sent with AddIgnore by `chat.reportIncorrectBehaviour`). Deliberate non-work - no moderation pipeline. |
| 22093 | `Tx` | reachable | Cross-game card transfer (`agn_0` 16443). Deliberate non-work - no other Ankama game exists. |
| 22097 | `OB` | reachable | Cross-game card transfer (`agn_0` 16442, `otherGameCardSent` toast). Deliberate non-work - same reason. |
| 26313 | `aju_1` | dead | DEAD in retail - X-vs-X invite. Only builder is awj_0, the Lua binding XvsXInvitation in the Test library (adg_1, super("Test")). No UI. Superseded by the 60xx 2v2 family (ROADMAP item 33). |
| 27525 | `zz_0` | reachable | LIVE - built in po_0, the production world-element action handler. |
| 27527 | `gc_0` | reachable | LIVE - built in `sL`, the 27526 render callback. **Ankama-internal avatar pipeline, not ladder.** |
| 27551 | `aib_1` | reachable | Notification-preference ack (`and_2` dialog answer): flips the client-local achievement-toast flag `zN.aY(false)`. Deliberate non-work - nothing server-side to do. |
| 28603 | `ayQ` | dead | DEAD in retail - tournament CREATE. No `new ayQ()` anywhere; its reply 28604 is handled only by ajp_0, whose output sink (ajp_0.a(apk_0)) is never installed. The web admin console covers this capability instead. |
| 28605 | `bi_2` | dead | DEAD in retail - no constructor anywhere. Same family as 28603. |
| 28607 | `ago_0` | dead | DEAD in retail - no constructor anywhere. Same family as 28603. |
| 28617 | `afg_2` | reachable | REACHABLE and player-facing, but blocked behind 28618 - which only makes sense once tournaments END (live-match layer is the documented deferral). Implementing the ack alone would fabricate the carry rule. |
| 28633 | `kx_2` | dead | DEAD in retail - no constructor; same ajp_0-only reply path as 28603. |
| 28635 | `aeC` | dead | DEAD in retail - no constructor; same ajp_0-only reply path as 28603. |

**28617/28618 - a correction.** These were previously filed with the dead admin
family and that was wrong. 28618 `ahd_0` = `[i64 tid]` makes the client show
*"Vous avez participe a un tournoi que vous n'avez pu terminer : <name>. Souhaitez
vous que votre position soit reportee au prochain tournoi de meme type ?"*, and
answering yes sends 28617 `afg_2` = `[i64 tid]` (`ajp_0` line 152 -> the `gs_2`
dialog callback, which fires on answer 16). It is a player-facing 'carry my standing
into the next tournament of the same type' flow, fully reachable - it just needs the
SERVER to send 28618 first. Genuine open work, not dead code.

The 16 marked *reachable* above have a real constructor in a production class and are
genuine gaps; the caller is named so the next person starts from evidence rather
than a grep. Their semantics are not yet established and that is stated rather than
guessed.



### Why each unimplemented S2C is unimplemented

Same evidence test as the C2S table, inverted: an S2C we never send is only a gap if
something in the client would CONSUME it. Each opcode below was searched for as
`case <opcode>:` across the decompiled client, excluding `gz_1` (the opcode->class
factory, which mentions every opcode and proves nothing). The handler class is named so
the next person starts from the consumer rather than from a grep.

**Send nothing here - there is no consumer.**

| Opcode | Consumer | Why not |
|---|---|---|
| 3208 | *none* | No `case 3208` anywhere. The client would drop it. |
| 28604 | `ajp_0` | Tournament-create reply. `ajp_0` is the debug console whose output sink (`ajp_0.a(apk_0)`) is never installed, so the reply is inert even if sent. |
| 28606 | `ajp_0` | Same: live handler, unsendable request (28605). |
| 28634 | `ajp_0` | Same: live handler, unsendable request (28633). |
| 28636 | `ajp_0` | Same: live handler, unsendable request (28635). |
| 5000 | `rl_2` | `case` present, body is a cast and a return - no side effect. Found by the mechanical sweep, not by eye. |
| 3128 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 3130 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 3132 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 3134 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 3136 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 3138 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 3142 | `om_0` | `case` present, body is a cast and a return - no side effect. |
| 28622 | `ds_2` | Has a `case`, but the body is empty (`bl2 = false; break;`) and the static list it decodes into is only reachable via `uw_2.ahZ()`, which nothing calls. A case label is not a consumer. |


**The empty-body check is now mechanical, and it should have been from the start.** Every
unimplemented S2C had its `case` body extracted and scored: lines that are only a cast, a
`return`, a `break` or a brace do not count. Result over the 74:

- **10 have a no-op consumer** - 3128/3130/3132/3134/3136/3138/3142 (`om_0`), 3208 (no
  handler at all), 5000 (`rl_2`), and 28622 (`ds_2`).
- **4 more are unreachable in practice** - 28604/28606/28634/28636 have real bodies and a LIVE handler (`ajp_0.azc()` is registered), but they answer requests the client cannot construct, so nothing triggers them. Formerly described here as writing
  only through `ajp_0.cE()`, whose sink is never installed.
- **60 are genuinely consumed** and are the real backlog.

The sweep caught 5000, which I had filed under "misc, single consumer" purely because it
had a handler. It also shows the check's limit: **28622 scores as substantive** because its
body assigns a local flag (`bl2 = false;`) before breaking, which has no effect. So the
score is a filter, not a verdict - it narrows what to read, and the body still has to be
read. That is the honest version of the rule I kept restating and not applying.

**Real gaps, grouped by the client class that consumes them.** Each group is a coherent
chunk of work: one handler class, one feature area.

| Family | Consumer | Opcodes | Notes |
|---|---|---|---|
| Social / friends | `om_0` | ~~2070~~, ~~3206~~, ~~3210~~, 3212, ~~3214~~, ~~3216~~ | **CORRECTED** - this was listed as 13 opcodes. On reading the case bodies, **3128/3130/3132/3134/3136/3138/3142 are decode-and-discard**: each casts the message and `return false`, exactly the empty-body trap this document warns about, so sending them does nothing. 2070/3206/3210/3214/3216 all emit today (announce, malformed command, rights, self-whisper, list-full); only 3212 stays silent deliberately. |
| Fight | `of_1` | 4900, 4901, ~~4902~~, ~~8122~~, 8250 | `of_1` is the in-fight handler (8120/8121 live here). **4902 DONE** (ouch bubble). **8122 resolved**: proven unusable - buff ids are the client-local `bWC++` counter, the wire cannot address an instance (deliberate non-work). 4900/4901 feed a client-side recorder queue nothing visible reads. 8250 is the turn-duration penalty toggle - needs an anti-cheat policy, not a codec. |
| Team presets / fighters | `dx_2` | ~~6014~~, 6032 | **6020, 6022, 6029 DONE** (B-131/B-130/B-132); **6014 DONE** - `sendFighterAssignedTeam` acks applied assigns/removes (echo + `aCG`, -1 sentinel on pure removes; the feared re-key branch is a no-op because we never re-id). **6032** stays a feature gap - no coach-condition source exists. **6020** `aic_0` - on status 0, REPLACES the preset in the list (remove + re-add a copy): an update-ack carrying the new preset. **6022** `agH` - on status 0, closes `fighterEquipmentDialog` and clears `teamManagement.selectedCard`: the ack that dismisses the loadout editor. **6029** `OJ` - shows *"error.teamManagement.coachDisconnected"*. **6032** `gd_0` - applies `kh()` to the local coach. Before implementing 6022, check whether the 6012 reply we already send after 6011 (`sendFighterInventoryResult`) is what dismisses the dialog - if it is, 6022 belongs to the team-management editor rather than the inventory path, and the two must not both fire. |
| Challenge / duel | `ft_1` | ~~23112~~, 2307, 2309, 4309, 26312, 26314 | **23112 DONE** - `sendMatchCancelled` now emits it (was a 23116 the client cannot decode). 2307/2309 are the bet-carrying variant pair - we announce via 23110; the 2308 answer is already handled. 26312/26314 are the X-vs-X pair; 26313's C2S half is Test-Lua-only (item 33), so confirm reachability before building these. |
| Guild / clan | `lh_1` | ~~554~~ | **554 DONE** - clan-tag table pushed at login (`pushGuildTags`), broadcast on join/create (`broadcastGuildTag`), cleared via the now-broadcast 556s. 513 rename / 551 icon are Test-Lua-only. |
| Ladder | `pl_2`, `pq_1` | ~~27526~~, ~~27528~~, 27552 | **27526/27528 resolved**: the Ankama-internal avatar-upload pipeline (27528 literally POSTs to `ws.ankama.lan`) - never-implement. 27552 is decode-factory-only, inert. 108 also lands in `pl_2`. Sub-boards beyond the 1v1/clan ones we serve. |
| Overworld / instance | `no_2` | ~~4601~~, ~~4700~~, 22092 | **4601/4700 DONE** (sit-stand, emotes). 22092 is the hover-tooltip status flag - settled wire, no source for the flag exists (deliberate non-work). 4510 reaches `no_2` and `qg_2`. |
| Overworld (misc) | `qg_2` | 4104, 4106, ~~4510~~ | **4510 DONE** (teleports). 4104 redundant with 4098; 4106 blocked by the same spawn-precondition as 4510. |
| Tournament notifications | `zN` | 17005, ~~25000~~, 28646 | **25000 DONE** - it's the bare `zN.M(code)` error toaster (26310's code table minus frame cleanup); now emitted for the clan-island Zaap refusal. **28646** ("search period opens now, N minutes") is blocked on a known hazard, not effort: `zN` case 28646 adds its `td_0` WITHOUT the duplicate guard case 28630 has, so emitting both for one tournament leaves two identical alert rows. 28630 must stop being the selection mechanism first. |
| Tournament (player) | `ajp_0` | 28618 | **NOT dead** but **blocked**: it raises a real dialog whose answer sends 28617 - and it only fires for "ended while you were registered" tournaments, which requires the deferred live-match layer to ever produce an ending. |
| System / connection | `fp_0`, `alz_2`, `tu_1` | 100, 102, 103, 105, 106, 108, 202, 204 | Low opcodes; 202/204 sit beside INTERACTIVE_ELEMENT_SPAWN (200) so are likely the element family. Semantics not established. |
| Misc, single consumer | `add_0` / `pe_2` / `aog_1` / `WE` / `do_2` | ~~2401~~, 2411 / 4000 / 4800 / 8400 / 4311 | 2401 done (B-141); 2411's wire is fully decoded (per-preset ladder record) but needs a per-preset stats model to fill honestly. 4000's target setter is unresolvable - do not guess. |

**How to pick one up.** Open the consumer class, find `case <opcode>:`, and read what it
does with the decoded message - that gives both the wire layout (from the message class
it casts to) and the UI effect. Two traps this document exists to prevent: a `case` with
an empty body is not a consumer (28622), and a message class with no `new` anywhere
cannot be sent by the retail client at all (the C2S table). Grep CASE-SENSITIVELY - the
obfuscated names differ only by case and a default PowerShell `Select-String` will lie.


## Focused views (for planning)

### C2S handled — 73, by feature

- **Connection/lifecycle (8):** 7, 107, 1025, 2049, 1, 4517, 22003, 27529
- **Overworld (3):** 4501, **201** (every element click), **4512** (Zaap)
- **Chat (3):** 3153, 3155, 3151
- **Social (4):** 3129, 3133, 3131, 3135
- **Inventory/equipment (2):** 5203, 5201
- **Economy (4):** 5300 (no-op), 5450, 5400, 5490
- **Mail (6):** 15000, 15004, 15006, 15506, **539**, + notice/result on the S2C side
- **Totems (5):** **27510** (demon ladder), **17002** / **28601** (tournament calendar/list), **4607** (tournament register), **28649** (tournament bracket)
- **Card exchange (6):** 5101, 5103, 5105, 5106, 5107, 5108
- **Fighters/teams (9):** 6001, 6003, 6011, 6013, 6021, 6023, 6031, **23000** (evolution state), **22099** (resurrection)
- **Fireworks (1):** **22095**
- **Matchmaking (4):** 2301, 2303, 23114, 2308
- **Ladder (2):** 27500, 27502
- **Fight setup (3):** 26330, 23103, 26303
- **In-fight (10):** 8011, 8021, 8023, 8031, 8105, 4503, 8107, 8111, 8151, 26321
- **Resume/spectate/challenge (6):** 26334, 2260, 26331, 26301, 26305, 26307

### S2C defined but inactive — 8 (all resolved: implemented or intentionally dark)

After the correctness sweep, every one of these is a deliberate decision, not a
loose end. Only opcode 8 became active; the rest are inactive for a documented,
evidence-based reason (a malformed frame or a fake trigger would be worse than
silence).

| Op | Name | Verdict |
|---|---|---|
| 8 | InvalidClientVersion | **now active** — `handleClientVersion` sends it on a version mismatch; the client self-disconnects. e2e-verified |
| 22002 | StatisticData | **never emit** — its handler opens the tutorial dialog *and* wholesale-replaces the coach's criteria. Criteria go out in 2052's 0x200 blob instead |
| 1026 | WorldServerUnavailable | **no honest trigger** — a login-time "game server unreachable" popup; in a monolithic server the world is reachable once the client connected |
| 2302 | OpponentSearchError | **dead client-side** — the client has no handler for the 2300-series replies (we use 23110); an empty payload would crash its decoder |
| 3202 | ChannelNotFound | **no trigger** - it answers 3151, which the retail client cannot send at all; the whole channel family is vestigial 2007 code (see ROADMAP item 25) |
| 5202 | CoachEquipmentUpdate | **no visible effect** — the overworld avatar (hair/skin/sex) is already correct at spawn; equipment is cards/deck, delivered per-fight via 8000 |
| 2300 | OpponentFound | superseded by 23110 — leave as-is |
| 26332 | SpectateTeardown | handled via 8300 — leave as-is |

### Known, identified gaps worth prioritising

1. **2v2 / multi-coach fights** — team-building/placement/timeline for >1 fighter per side (the last item of the original fight audit).
2. **4521 / 4522 direction-change** — small, self-contained; removes a live `unhandled opcode` during fights.
3. **26313 / 26314 (+ 26310 / 26312) X-vs-X challenge** — finishes the direct-challenge feature deferred in B-040.
4. **Inactive S2C set** above — small robustness fixes.

### Large unknowns — need a decomp pass before scoping

These are whole subsystems the server has zero code for. Identify them (client obf class →
behaviour) before deciding whether the retail client needs them:

- **27504–27552** (paired C2S/S2C) — the leaderboard family, now fully identified for the ranking window. It has **SEVEN** tabs, all wired: **1 vs 1** 27500/27501, **Coach** 27508/27509, **2 vs 2** 27504/27505, **Clan** 27502/27503, **Tournoi** 27506/27507, **Ligue Pro** 27514/27515, **Démon** 27512/27513 (+ the per-demon drill-down 27510/27511). Corrected in B-046: 27506/27507 is the *Tournoi* tab (not "seasonal"), and *Ligue Pro* is the separate 27514/27515 pair that previously had no handler. Remaining 275xx opcodes are dark.
- **28601–28650** (paired C2S/S2C, ~40 opcodes) — the tournament subsystem, now live
  end to end: **28601/28602 list**, **17002/17003 calendar**, **4607/28608
  registration**, **28630 search period**, **28609/28611 cancel/ready**,
  **28612/28614 accept + fight start**, **28648 search ended**, **28649/28650
  bracket**.

  The remainder splits in two, and the split is the point:

  **Dead in the retail client — do not implement.** 28603 (`ayQ` create), 28605
  (`bi_2`), 28607 (`ago_0`), 28633 (`kx_2`), 28635 (`aeC`) are the
  tournament ADMIN family. Each message class exists and can encode, but **nothing
  in the client ever constructs one**: `new ayQ()`, `new bi_2()`, `new kx_2()`,
`new aeC()` and `new ago_0()` appear nowhere. (**28617 is NOT one of these** - it is
  inside `gs_2`, which is `ajp_0`'s own inner class. (Grep case-sensitively here:
  `ayQ` and `aeC` collide with unrelated *methods* `TradeContentCommand.ayQ()` and
  `ry_2.aeC()`, which makes them look used.)

  Their replies — 28604, 28606, 28618, 28634, 28636 — are handled only by `ajp_0`,
  a **debug-console** command handler (`apk_0` is the client's console:
  `HelpCommand`, `NavigateToParentCommandSetCommand`). It reports via `ajp_0.cE()`,
  which writes to a sink installed by `ajp_0.a(apk_0)` — and nothing calls that
  either, so the sink stays null and even the printing is inert. A server
  implementation of this family could never be reached by the retail client.

  **28622 is dead too**, for a different reason: `ds_2` does have a case for it, but
  the body is empty (`bl2 = false; break;`), and the static list it decodes into is
  only reachable through `uw_2.ahZ()`, which nothing calls. A `case` label is not
  evidence of a consumer.

  **Live and still open.** 28644 (`aaj_0`, `[i64 tid][i64 nextSearchEpochMillis]`,
  the "next search period is at T" countdown) and 28646 (`aNq`,
  `[i64 tid][i64 durationMillis]`, "search period opens now, valid N minutes") are
  genuinely rendered by `zN`. Both need wall-clock search-period scheduling, which
  the server does not have — `domain.Tournament` carries no schedule columns.

  One hazard for whoever builds it: `zN` case 28646 adds its `td_0` notification
  **without** the duplicate guard that case 28630 has, so emitting both for the same
  tournament leaves two identical rows in the alert list.
- **15xxx — solved: this is the mailbox** (15000/15001 list, 15003 send result, 15004 delete, 15005 notice, 15006/15007 attachments, 15506/15507 name lookup, plus C2S 539 send). Fully implemented.
- **17xxx — solved: the tournament calendar** (17002/17003, now serving real standing-tournament events). 17004/17006/17008 are Test-Lua-only console actions sending hardcoded TEST events; 17010 is player-created tournaments, gated on card 807 - a real model gap (custom events have no type-1000 defId to satisfy the client's unguarded deref).
- **22xxx (minus 22003)** — statistics/achievements beyond the single counter we handle. **22094/22095 (fireworks) and 22099 (resurrection card) are now implemented.**
- **23xxx (minus 23103/23110/23112/23114)** — remaining fight-setup / matchmaking variants. **23000 is not fight-setup at all** — it is the evolution-mode fighter state change (titular/bench/graveyard/legendary), now handled.
- **10/11/12 Property\*** — client config/property push; check whether login blocks without it.
- **2/3/4 ReconnectionTicket\*** — proxy reconnect channel; check whether this client ever uses it.

## How to refresh this document

1. Client universe: `client/analysis/opcode_map.csv`.
2. Handled C2S: `rg "r\.Register\(" server/internal/game` (or Grep) → 72 rows across the `register*Handlers` groups in `deps.go`.
3. Emitted S2C: `rg "EncodeS2C\(protocol\.Op" server/internal` **plus** the `internal/handshake` encoders (auth 1024, coach-create 2048/2050, coach-info 2052, enter-instance 4600, ping 107, actor-move 4500).
4. Defined constants: `internal/protocol/opcodes.go`. A constant that is neither registered nor sent is **Inactive (I)**.
