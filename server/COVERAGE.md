# v2.70 server — Feature & Opcode Coverage Matrix

Single source of truth for what's **implemented**, **wire-audited** against the
real client decoder/encoder, and **tested** (unit / E2E). Keep this updated with
every change.

Legend:
- **Impl**: handler/serializer exists and is wired in.
- **Audit**: byte-for-byte verified against the decompiled client
  (`A`=audited & correct, `A*`=audited & a bug was fixed, `—`=not yet).
- **Unit** / **E2E**: covered by a Go test (`✓`) or not (`—`); `live` = verified
  against the real retail client.
- Dir: C2S (client→server, we decode) / S2C (server→client, we encode).

**Testing:** Go unit + scripted-wire E2E (`go test ./...`), plus an **autonomous
live-client loop** — see `docs/CLIENT-TESTING.md` and
`../client/control-agent/`. Every fixed bug is logged in `docs/BUGS.md`.

Audit legend cross-refs the commit that did/verified it.

---

## Connection & login

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 7 | ClientVersion | C2S | ✓ | A | — | ✓ (login) |
| 1025 | ClientAuthentication | C2S | ✓ | A | — | ✓ (login) |
| 1024 | ClientAuthResult | S2C | ✓ | A | — | ✓ |
| 1026 | WorldServerUnavailable | S2C | ✓ | A | — | — |
| 8 | InvalidClientVersion | S2C | ✓ | A | — | — |
| 107 | Ping request (asg_0) | C2S | ✓ | A | — | ✓ | client keepalive request; Godot sends per-arch {1,2} every 60s (ping_smoke) |
| 108 | Ping reply (abj_0) | S2C | ✓ | **A*** (was wrongly 107) | — | live ✓ (ping_smoke: flag+key echo, 29B) | credits client nW.sL() every 60s |

## Lifecycle (session / coach)

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 1 | Disconnect (`aqb`) | C2S | ✓ | A (empty) | — | — |
| 4517 | TutorialChangeInstance (`aae_2`) | C2S | ✓ (no-op) | A (empty, arch 3) | — | ✓ (Godot aog_1 gate) |
| 22003 | StatisticUpdate (`nq`) | C2S | ✓ (persist) | A (i16 id, i8 flag, i16 val) | ✓ | ✓ (229 live; 221 wired) |
| 22000 | AchievementUnlocked (`ade_0`) | S2C | ✓ (evaluated from types 800/801/802) | A (i16 achievementId) | ✓ | ✓ **live** |
| 22001 | StatisticRequest (`anp_0`) | C2S | ✓ | A (empty, arch 2) | ✓ | ✓ **live** |
| 22002 | StatisticData (`ls_0`) | S2C | ✓ (reply to 22001 ONLY) | A (i32 byteLen, then i16/i16 pairs) | ✓ | ✓ **live** |
| 27529 | DestroyCoach (`bl`) | C2S | ✓ (delete coach + data) | A (empty, arch 2) | ✓ (DeleteCoach) | wired (`/deletecoach CONFIRM`) |

## Coach creation & world entry

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 2048 | CoachCreationRequest | S2C | ✓ | A | — | ✓ |
| 2049 | CoachCreation | C2S | ✓ | **A*** (hair/skin swap fixed) | ✓ | ✓ |
| 2050 | CoachCreationResult | S2C | ✓ | A | — | ✓ |
| 2052 | CoachInformations | S2C | ✓ | **A*** (color order fixed) | ✓ | ✓ |
| 4600 | EnterInstance | S2C | ✓ | A | — | ✓ |
| 2400 | PlayerStatisticsReport | S2C | ✓ | **A*** (field ids fixed vs class) | ✓ | ✓ (implicit) |
| 2401 | PlayerStatistics (`uf_0`) | S2C | ✓ (login push) | A (u16 len + stat map) | ✓ | ✓ **live** — Godot "Coach" pane |

## World / actors / movement

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 4096 | ActorSpawn | S2C | ✓ | **A*** (16 missing bytes fixed) | ✓ | ✓ (AoI) |
| 4098 | ActorDespawn | S2C | ✓ | A | — | ✓ (AoI) |
| 4501 | CoachMovementRequest | C2S | ✓ | A | — | ✓ (AoI) |
| 4500 | ActorMovement | S2C | ✓ | A | — | ✓ (AoI) |
| 4510 | ActorTeleports (`xp_0`) | S2C | ✓ (`/tp` same-world) | A (i64 id, i32 x, i32 y, u16 z) | — | ✓ **live** (element AoI diff + zone triggers) |
| 200 | InteractiveElementSpawn (`rz_2`) | S2C | ✓ (streamed per chunk) | A | ✓ | ✓ (element AoI) |
| 206 | InteractiveElementDespawn (`acc_2`) | S2C | ✓ | A (i16 count, i64 ids) | ✓ | ✓ (element AoI) |
| 201 | InteractiveElementAction (`bd_2`) | C2S | ✓ | A | — | ✓ **live** (right-click; Zaap + graveyard) |

Elements are **streamed on the client's env-chunk grid** (Chebyshev chunk distance
≤ 2, chunks 18 cells), not bulk-sent per world: opcode 200 cannot carry the
element's type, so the client resolves it from a per-chunk registry it drops when
the chunk unloads. Bulk-sending silently discarded most of every island. See
BUGS.md B-108.

## Chat & social

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 3153 | UserVicinityContent | C2S | ✓ | A | — | ✓ (AoI chat) |
| 3152 | VicinityContent | S2C | ✓ | A | — | ✓ |
| 3155 | UserPrivateContent | C2S | ✓ | A | — | ✓ (whisper) |
| 3154 | PrivateContent | S2C | ✓ | A | — | ✓ (whisper) |
| 3151 | UserChannelContent | C2S | ✓ | A (acS: channel+msg) | — | ✓ (+Godot `/g`, channel `*`) |
| 3140 | ChannelContent | S2C | ✓ | A (xb_1: channel+sender+msg) | — | ✓ |
| 3159 | UserTradeContent (`/t`) | C2S | ✓ | A (afq_0, arch 3) | — | ✓ **live** |
| 3168 | TradeContent | S2C | ✓ | A (ayy — byte-identical to 3152) | — | ✓ **live** |
| 3199 | UserClanContent (`/c`) | C2S | ✓ validated | A (ak, arch 2: msg THEN i64 guildId) | ✓ | — |
| 509 | GuildCreate (`atM`, arch 3) | C2S | ✓ | A | ✓ | ✓ **live** |
| 501 | GuildInvite (`uq_2`) | C2S | ✓ | A | ✓ | ✓ |
| 503 | GuildInviteAnswer (`cg_0`) | C2S | ✓ | A | ✓ | ✓ |
| 517 | GuildGet (`auZ`) | C2S | ✓ | A | — | ✓ |
| 519 | GuildMembersGet (`add_2`) | C2S | ✓ | A | — | ✓ **live** |
| 502 | GuildInvitation (`auf_0`) | S2C | ✓ | A | ✓ | ✓ |
| 504 | GuildResult (`mD`) | S2C | ✓ | A | ✓ | ✓ **live** |
| 510 | GuildRecord (`arl_0`/`KI.b`) | S2C | ✓ | A | ✓ | ✓ **live** |
| 512 | GuildMembers (`kf_1` part 0) | S2C | ✓ | A | ✓ | ✓ **live** |
| 552 | GuildMembership (`kf_1` part 2) | S2C | ✓ | A | ✓ | ✓ **live** |
| 556 | GuildMemberGone (`h_0`) | S2C | ✓ | A | — | — |
| 558 | GuildCreatedFeed (`ahU`) | S2C | ✓ | A | — | — |
| 560 | GuildMemberFeed (`ry_1`) | S2C | ✓ | A | ✓ | — |
| 505 | GuildLeave/Kick (`nP`) | C2S | ✓ | A | — | ✓ |
| 511 | GuildDestroy (`awR`) | C2S | ✓ | A | — | ✓ |
| 515 | GuildSetRank (`abn_2`) | C2S | ✓ | A | — | — |
| 553 | GuildRankAdd (`abo_0`) | C2S | ✓ | A | ✓ | ✓ |
| 555 | GuildRankModify (`Nr`) | C2S | ✓ | A | ✓ | ✓ |
| 557 | GuildRankDelete (`Ko`) | C2S | ✓ | A | ✓ | ✓ |
| 2600 | GuildMemberStats (`mL`) | C2S | ✓ | A | — | — |
| 2601 | GuildMemberReport (`kq_2`) | S2C | ✓ | A | — | — |
| 5470 | DemonAffiliate (`Zu`, arch 3) | C2S | ✓ | A | ✓ | — |
| 5403 | DemonAffiliateResult (`mj_1`) | S2C | ✓ | A | ✓ | — |
| 3198 | ClanContent | S2C | ✓ | A (ano_1) | — | — |
| 3161 | UserGroupContent (`/p`) | C2S | ✓ | A (aux_, arch 3) | — | ✓ **live** |
| 3170 | GroupContent | S2C | ✓ | A (aik_1) | — | — |

**The channel pair 3151/3140 is vestigial in the RETAIL client**: it cannot
send 3151 (`ChannelContentCommand` is referenced by nothing in any shipped
jar), and a 3140 routes to pipe 3, which `du_1` never registers - so the
retail client nulls out and swallows it. The Godot client surfaces it as a
global `/g` chat on channel `*` (wire format identical to `acS`), so it is
exercised by e2e AND by the replacement client.

All four live pipes are served. **Trade** is global. **Group** resolves its
audience from the sender's own fight rather than the client-supplied coach id -
trusting that id would turn `/p` into an unfilterable DM channel - so it is
correct today and gains an audience when 2v2 lands. **Clan** re-validates the
client-supplied guild id against the sender's actual guild, which no coach has
yet, so it resolves to nobody until item 31.

Chat delivery is filtered by the recipient's ignore list and stripped of `<`/`>`
markup, and Trade carries the client's own 30 s cooldown. See BUGS.md B-104.
| 3129/33 | Add/Remove Friend | C2S | ✓ | A | — | ✓ |
| 3131/35 | Add/Remove Ignore | C2S | ✓ | A | — | ✓ |
| 3156 | FriendAdded | S2C | ✓ | **A*** (kz_1: name+note+i64+i16+sex+i16) | — | ✓ |
| 3160 | FriendRemoved | S2C | ✓ | **A*** (adw_1: name only) | — | ✓ |
| 3158 | IgnoreAdded | S2C | ✓ | **A*** (ft_0: name+note, no id) | — | ✓ |
| 3162 | IgnoreRemoved | S2C | ✓ | **A*** (ahm_0: name only) | — | ✓ |
| 3148 | NotificationFriendOnline | S2C | ✓ | A (dh_0: name+2str+i64+i16+sex+i64) | — | ✓ |
| 3150 | NotificationFriendOffline | S2C | ✓ | A (pv_0: name+note) | — | ✓ |
| 3164 | NotificationIgnoreOnline | S2C | ✓ | A (jH: name+i64) | — | ✓ |
| 3166 | NotificationIgnoreOffline | S2C | ✓ | A (jf_0: name only) | — | ✓ |
| 3144 | FriendList | S2C | ✓ | **A*** (nil-join desync fixed) | ✓ | — |
| 3146 | IgnoreList | S2C | ✓ | **A*** (nil-join desync fixed) | ✓ | — |
| 3204 | UserNotFound | S2C | ✓ | A | — | ✓ (whisper) |
| 15506 | MailCheckName | C2S | ✓ | A (u8 utf8 name) | — | ✓ (godot /mail gate) |
| 15507 | MailNameResult | S2C | ✓ | A (i64 coachId) | — | ✓ |

## Inventory & equipment

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 5200 | CoachInventoryUpdate | S2C | ✓ | A | — | ✓ |
| 5203 | CoachInventoryUpdateRequest | C2S | ✓ | A | — | ✓ |
| 5201 | CoachEquipmentUpdateRequest | C2S | ✓ | A | — | ✓ |

## Shop / economy (Card Master token purchase)

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 5300 | ShopOpen (yg) | C2S | ✓ | A (empty; opens Card Master) | — | ✓ |
| 5401 | ShopCatalog (NN) | S2C | ✓ | A ([i8 flag][i32 shopId]{i32 id,i16 qty}) | — | ✓ |
| 5450 | ShopBuy (mo_2) | C2S | ✓ | A ([i32 shopId][i16 N]{i32 cardId}) | ✓ | ✓ |
| 5403 | ShopResult (mj_1) | S2C | ✓ | A ([i8 res][i8 N]{i8 type,i32 amt}) | — | ✓ |
| 5400 | ShopBarter (aOo) | C2S | ✓ | A ([i32 exId][i16 N]{wanted}[i16 M]{given,qty}) | — | ✓ |
| 5490 | FusionRequest (ahg_0) | C2S | ✓ | A ([i32 count]{i32 cardId}) | — | ✓ |
| 5491 | FusionResult (agr_2) | S2C | ✓ | A ([i8 res][i32 obt][i32 notObt][i32 rec]) | — | ✓ |
| 4001 | WalletUpdate (tc_2) | S2C | ✓ | A ([i8 N]{i8 type,i32 amt} full sync) | — | ✓ |
| — | card tokenValue price map (gamedata) | — | ✓ | A (field 5, real-data verified) | ✓ | — |
| — | BuyCards/CreditCurrency (store) | — | ✓ | n/a | ✓✓ | ✓ |
| — | fight-win token faucet (+4001 push) | — | ✓ | n/a | ✓ | ✓ |
| — | ConsumeAndGrant (store, fusion) | — | ✓ | n/a | ✓ | ✓ |

Notes: currency is a multi-slot "token" wallet (byte type → i32); type 1 is the
primary shop token (845/907 real cards priced in it). Shop-open (5300) → catalog
(5401) sends every priced card (~845, one frame; no pagination exists in the
protocol). Faucets: new coaches get a starter balance, and winning a fight
credits a token reward with a live 4001 wallet push (both win paths: normal
kill-to-victory and give-up/forfeit, via checkFightEnd). Daily/other faucets are
TODO.

Card-for-card barter (5400): trade cards you own for a wanted card, no tokens.
Wire: [i32 exId][i16 N]{i32 wantedId}[i16 M]{i32 givenId, i16 qty}. Enforces the
client's own rule (aJd.canBuyCards): Σ(given.value × qty) ≥ wanted.value (and
wanted.value > 0). On success consumes the given cards + grants the wanted card
(ConsumeAndGrant), pushes 5200 and a success 5403; insufficient value or unowned
cards → 5403 result 1.

Fusion Lab (5490→5491): the original was recipe-based (~100 recipes, per the
2011 "Confrontation" release notes — fusion altars "create cards and pets"). The
recipe table is NOT in the decoded gamedata, so we implement a faithful
approximation: submitting ≥2 cards of one CardSet rolls the altar
(fusionSuccessPercent=60) → success grants a random other card of that set
(obtained); failure returns one input as leftovers (recovered); mixed-set/<2/
unowned → plain fail. Inputs are consumed atomically (ConsumeAndGrant) and a
fresh 5200 inventory is pushed. Deferred: 5400 card-for-card barter, 5470
Demon II affiliation.

## Ladder (1v1 leaderboard)

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 27500 | LadderRequest (dp_0) | C2S | ✓ | A ([i32 offset]) | — | ✓ |
| 27501 | LadderResponse (azd_0) | S2C | ✓ | A (paged window, field map vs vv_2) | — | ✓ |
| 27502 | LadderPageRequest (pc_1) | C2S | ✓ | A ([i16 board][i32 offset]) | — | ✓ |
| 27503 | LadderPage (ij_1) | S2C | ✓ | A ([i16 board][i32 off][i32 N]{name,tag,rating}) | — | ✓ |
| — | LadderPage/Rank/Count (store) | — | ✓ | n/a | ✓ | ✓ |

Notes: the 1v1 board is sorted by `Strength` desc (ties by name), paged in
windows of 20 by the client's scroll offset; only ranked coaches (strength > 0)
appear. Response header = [total][windowStart][windowEnd][myRank]; each row =
name + guild tag (empty until guilds) + rating + consecutive victories + total
victories/defeats (field map verified vs client vv_2/afl_1 case 27501). The
compact page (27502→27503, "find / center on my rank") returns board-typed
name+tag+rating rows (board 1 = 1v1; other boards → empty page). Deferred ladder
pieces: the other sub-boards (evolution/team/etc., 27504–27552).

## Card exchange (trading)

> **Live-verified against the retail client** (2026-08-15), driven by a synthetic
> second player. Observed in the real UI: the invitation dialog (5102) with the
> inviter's name, the trade window opening on 5104 result 3, a staked card
> appearing on 5110 and disappearing on 5112, and the "Proposition d'echange
> annulee" notice on 5114. Under the previous (2006) numbering none of those
> S2C messages could have reached the client at all - see BUGS.md B-093.

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 5101 | ExchangeInvite | C2S | V | A* | - | V |
| 5102 | ExchangeInvitationRequest | S2C | V | A* | - | V |
| 5103 | ExchangeAnswer | C2S | V | A* | - | V |
| 5104 | ExchangeConfirmation | S2C | V | A* | - | V |
| 5105 | ExchangeAddCard (ua_2) | C2S | V | A* | V | V |
| 5107 | ExchangeRemoveCard (wd_0) | C2S | V | A* | V | V |
| 5109 | ExchangeSetReady (ahJ) | C2S | V | A* | V | V |
| 5110 | ExchangeCardAdded (asH) | S2C | V | A* | V | V |
| 5111 | ExchangeCancel (any) | C2S | V | A* | V | V |
| 5112 | ExchangeCardRemoved (aaz_1) | S2C | V | A* | V | V |
| 5113 | ExchangeError (Or) | S2C | V | A* | V | - |
| 5114 | ExchangeEnd (aqX) | S2C | V | A* | V | V |
| 5116 | ExchangeUserReady (dl_0) | S2C | V | A* | V | V |
| — | transactional swap (dupe-safe) | — | ✓ | n/a | ✓✓✓✓ | ✓ |

## Fighters & teams

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 6001 | FighterCreate | C2S | ✓ | A (breed guard confirmed) | ✓ | ✓ |
| 6000 | FighterCreateResult | S2C | ✓ | A | — | ✓ |
| 6003 | FighterDelete | C2S | ✓ | A | — | ✓ |
| 6002 | FighterDeleteResult | S2C | ✓ | — | — | — |
| 6006 | FighterInformationList | S2C | ✓ | A (et_2 zv-before-ey) | ✓ | — |
| 6011 | UpdateFighterInventory | C2S | ✓ | A (bp_1: cards [i32]*, spells [i16 slot][i32]*) | ✓ | ✓ |
| 6010 | UpdatedFighterInventory | S2C | ✓ | A (nl_1: [i64 id][i8 res](+blobs)) | — | ✓ |
| 6013 | FighterAssignTeam | C2S | ✓ | A (qp_1: [i64 f][i16 src][i16 dst][i64 am], dst=-1 removes) | ✓ | — |
| 6021 | TeamPresetSave | C2S | ✓ | A | ✓ | ✓ |
| 6023 | TeamPresetDelete | C2S | ✓ | **A*** (i64 not u16 fixed) | — | ✓ (regression) |
| 6031 | TeamPresetListRequest | C2S | ✓ | A | — | ✓ (Godot graveyard open) |
| 6030 | TeamPresetList | S2C | ✓ | **A*** (member guard) | ✓ | — |

## Matchmaking

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 2301 | OpponentSearchRequest | C2S | ✓ | A | ✓ (matchmaker) | ✓ |
| 2303 | OpponentSearchCancel | C2S | ✓ | A (adj_0: empty) | — | ✓ |
| 2304 | OpponentSearchInProgress | S2C | ✓ | A (Hf: empty) | — | ✓ |
| 2306 | OpponentSearchCancelResult | S2C | ✓ | A (tj_2: [i8 result]) | — | ✓ |
| 2302 | OpponentSearchError | S2C | — | A (apa_0: [i8 error]) | — | — |
| 23110 | MatchFound | S2C | ✓ | **A*** (mode/fightType dup fixed) | — | ✓ |
| 23114 | MatchAccept | C2S | ✓ | A | — | ✓ |
| 2308 | MatchAcceptAlt | C2S | ✓ | A | — | — |
| 23116 | MatchConfirm | S2C | ✓ | — | — | — |
| 28609 | `bt_0` TournamentSearchCancel | C2S | ✓ | A (`[i64 tid][i64 coachId][i16 preset]`) | — | ✓ |
| 28610 | `de_0` TournamentSearchCancelResult | S2C | ✓ | A (`[i8 accepted]`) | — | ✓ |
| 28611 | `ly_1` TournamentSearchRequest | C2S | ✓ refuses | A (`[i64 tid][i64 coachId][i16 preset]`) | — | ✓ |
| 28612 | `DR` TournamentSearchResult | S2C | — | A (`[i64 tid][i16 preset][i8 accepted]`) | — | — |
| 28614 | `azj_0` TournamentFightStarting | S2C | — | A (`[i64 tid]`) | — | — |
| 28616 | `kw_1` TournamentSearchError | S2C | ✓ | A (`[i8 code][i8 subCode]`) | — | ✓ |
| 23101 | `bm_1` ClassicSearchCancel | C2S | ✓ | A (`[i64 coachId][i16 teamId]`) | — | ✓ **live** |
| 23102 | `ada_1` ClassicSearchCancelResult | S2C | ✓ | A (`[i8 accepted]`) | — | ✓ **live** |
| 23104 | `aLi` ClassicSearchResult | S2C | ✓ | A (`[i16 teamId][i8 accepted]`) | — | ✓ **live** |
| 23106 | `ads_2` ClassicFightStarting | S2C | ✓ | A (empty) | — | ✓ |
| 23108 | `M` ClassicSearchError | S2C | ✓ | A (`[i8 code]`) | — | — |
| 23001 | `abn_0` EvolutionSearchCancel | C2S | ✓ | A (`[i64 coachId][i16 preset]`) | — | ✓ |
| 23002 | `wf_2` EvolutionSearchCancelResult | S2C | ✓ | A (`[i8 accepted]`) | — | ✓ |
| 23003 | `ajw_0` EvolutionSearchRequest | C2S | ✓ | A (`[i64 coachId][i16 preset=99]`) | — | ✓ **live** |
| 23004 | `amh_0` EvolutionSearchResult | S2C | ✓ | A (`[i16 preset][i8 accepted]`) | — | ✓ **live** |
| 23006 | `azl_0` EvolutionFightStarting | S2C | ✓ | A (empty) | — | ✓ **live** |
| 23008 | `KL` EvolutionSearchError | S2C | ✓ | A (`[i8 code]`) | — | ✓ |
| 23009 | `aow_2` SphereBuy (Kanodo) | C2S | ✓ | A (`[i64 fighterId][i32 sphereId][i32 cardTemplateId]`) | — | ✓ **live** |
| 26330 | `alv_1` TeamTest / challenge launch | C2S | ✓ | A (`[i32 id][i16]`; b=99 bubble/breedmaster, b=teamId Tester, b=challenge.`Qu()` NPC-dialog défi — all three dispatch) | ✓ | ✓ (godot world_smoke: Baan group 48 défi → 8000) |

**There are THREE parallel copies of this handshake**, one per team-panel tab,
consumed by three near-identical client frames: `vu_1` (classic/Elite), `wp_0`
(evolution) and `ds_2` (tournament + Légendes). None of the three was served until
B-098/B-099/B-100: Evolution → COMBATTRE waited forever and **no evolution fight
was startable from the retail client at all**, while classic queued the coach but
showed no overlay — and since the Cancel button lives inside that overlay, no way
out of the queue.

Classic and evolution share one implementation (`searchFamily` in
`search_handshake.go`). Two asymmetries are load-bearing:

- The evolution `preset` is **not** a database team id — `sw_1.bMm = 99` is a
  synthetic pseudo-preset (peer of graveyard 10000, legend 9999) mapping to the
  coach's titular line-up. The classic i16 IS a real team id and may be -1.
- The **tournament family is not a clean twin**: its request/cancel/result carry a
  leading tournament id, and 28616 has a **second byte** (`subCode`, fed to
  `zN.M()` when code == 2). It therefore does not use `searchFamily`.

28611 is **refused** with code 1 rather than queued, because a tournament match is
a bracket fixture rather than a free pairing and the bracket layer is deferred —
pairing arbitrary searchers would silently pretend tournaments work. See BUGS.md
B-100.

Order is load-bearing — 23004 opens the client's "Searching…" overlay and only
23006/23002/23008(3,4,5) close it, so 23006 must precede CREATE_FIGHT. A 23004
carrying accepted=0 is a dead end (the panels close, nothing opens); refusals go
out as 23008. Verified live end to end: overlay → pair → fight → the evolution
result dialog.

## Fight lifecycle & combat

| Opcode | Msg | Dir | Impl | Audit | Unit | E2E |
|---|---|:---:|:---:|:---:|:---:|:---:|
| 8000 | CreateFight | S2C | ✓ | A (incl. gV grid tail, error byte) | ✓ | ✓ |
| 8010–8040 | phase start/end (presentation/placement/observation/action) | S2C | ✓ | A | — | ✓ |
| 8011/8023/8031 | ready-for-* | C2S | ✓ | A | — | ✓ |
| 8012/8024/8032 | ready-*-ack | S2C | ✓ | A | — | ✓ |
| 8021 | MoveToPlacementReq | C2S | ✓ | A | — | ✓ |
| 8022 | MoveToFreePlacement | S2C | ✓ | A | — | ✓ |
| 8100 | NewTableTurnBegin | S2C | ✓ | A | — | ✓ |
| 8104/8106 | FighterTurnBegin/End | S2C | ✓ | A | — | ✓ |
| 8105 | FighterEndTurnReq | C2S | ✓ | A | — | ✓ |
| 4503 | FighterMoveInFightReq | C2S | ✓ | A | — | ✓ |
| 4524 | FighterMoveInFight | S2C | ✓ | A | — | ✓ |
| 8107 | FighterCardUseRequest | C2S | ✓ | A (sg_2: i64 fid, i32 card, x, y, z) | — | ✓ (godot fight_smoke) |
| 8108 | FighterCardUse | S2C | ✓ | A | — | ✓ |
| 8109 | SpellCastRequest | C2S | ✓ | A | — | ✓ |
| 8110 | SpellCast | S2C | ✓ | A | — | ✓ |
| 8111/8112 | CloseCombatReq/CloseCombat | C2S+S2C | ✓ | A | — | ✓ (godot fallback path) |
| 4521 | FighterDirChangeReq | C2S | ✓ | A (i64 fid, u8 dir, arch 3) | — | ✓ (godot fight_smoke) |
| 4522 | FighterDirectionChange | S2C | ✓ | A | — | ✓ |
| 8120 | RunningEffect (AP/MP/HP/summons) | S2C | ✓ | A | ✓ | ✓ (blob parts 0-4; 3=displacement, 4=source spell; action 67/75/97 spawn a summon — Godot builds the fighter from type-300 + content.10; actions 37/38/39/58/59/64/153 displace actors — Godot moves/swaps/carries them; timed effects attach a buff chip — `dumpeffects` supplies the data-side duration) |
| 8121 | FightEffectTimer (buff attach) | S2C | ✓ | A | ✓ | ✓ (resync/spectator attach — never executes; Godot decodes `actionId + blob + fid + i16 expiry` into the same buff strip, rounds-left = expiry − own-turn counter) |
| 4520 | FighterDies | S2C | ✓ | A | — | ✓ (forfeit) |
| 8200 | ActionSequenceExecute | S2C | ✓ | A | — | ✓ |
| 8300 | EndFight | S2C | ✓ | A (2.70 strength-map counts) | ✓ | ✓ **live** (Godot decodes + renders the debrief panel) |
| 26321 | EndFightDone | C2S | ✓ | A | — | ✓ (godot pvp_smoke, spectator) |
| 8151 | GiveUpFight | C2S | ✓ | A | — | ✓ |
| 2260 | SpectateQuery | C2S | ✓ | A (i64 target) | — | ✓ (godot pvp_smoke, 3rd client) |
| 2261 | SpectateReply | S2C | ✓ | A (i8 0/1) | — | ✓ |
| 26331 | SpectateJoin | C2S | ✓ | A (i64 target, arch 2; resync replay) | — | ✓ |
| 26332 | SpectateTeardown | S2C | defined, unused | — | — | — (teardown goes through 8300+26321) |
| 26333 | ReconnectFightQuestion | S2C | ✓ | A (empty) | — | ✓ (godot pvp_smoke mid-fight drop) |
| 26334 | ReconnectFightAnswer | C2S | ✓ | A (u8 accept) | — | ✓ |
| 28649 | TournamentTreeReq | C2S | ✓ | A (i64 tid, i32 page, str32 name) | — | ✓ (godot world_smoke) |
| 28650 | TournamentTree | S2C | ✓ | A (i32 page, i32 n, slot/name pairs, i32 unread) | — | ✓ |

---

## Infrastructure coverage

| Area | Impl | Tested |
|---|:---:|:---:|
| Config (YAML + env) | ✓ | ✓ (5 tests) |
| Multi-DB store (sqlite/pg/mysql) | ✓ | ✓ (sqlite) |
| Docker (per-DB compose) | ✓ | build verified (no live run) |
| Account persistence | ✓ | ✓ |
| Coach persistence + reconnect | ✓ | ✓ (E2E) |
| Session kick / dup-login | ✓ | ✓ (E2E reconnect) |
| Async write queue + backpressure | ✓ | ✓ (E2E, race) |
| Graceful shutdown (no goroutine leak) | ✓ | ✓ |
| Actor-model fights (race-clean) | ✓ | ✓ (race) |
| Phase/turn timers (anti-deadlock) | ✓ | ✓ (2 tests) |
| AoI scoping + dynamic spawn/despawn | ✓ | ✓ (3 E2E) |
| gamedata (data.bdat cards/spells) | ✓ | ✓ (real-data tests) |
| Coach-stats race (Coach.Mu) | ✓ | ✓ (race, forfeit) |

---

## Known gaps / not-yet-done (honest)

**Wire-audit gaps** (impl exists, not yet byte-verified vs client):
- FighterCreate/Delete **result** messages (6000/6002).
- MatchConfirm (23116).

**Open-world feature gaps (build these before finishing the fight):**
The retail client uses many open-world (non-fight) opcodes the server does not
yet handle; unregistered opcodes are silently dropped (router.go), so each
missing feature manifests to the client as a *hang*. Prioritized:
- **Channel chat scoping** — 3151→3140 is implemented as a single GLOBAL
  audience (all online); the per-channel membership family (3128 flags, 3130/32
  join/leave, 3134/36/38 member ops, 3202 not-found) and guild/team-scoped
  routing are not modelled yet.
- **Shop extras** — Card Master token buy (5450), open/catalog (5300/5401),
  card-for-card barter (5400), the fight-win token faucet, and Fusion Lab
  (5490/5491) are done; still missing: 5470 Demon II affiliation, a real fusion
  recipe table (we approximate same-set fusion), and other faucets (daily login).
- **Inventory invariant**: BuyCards/ConsumeAndGrant assume one unequipped
  (pos=0) row per (coach, template). All server grant paths stack to preserve
  this; only raw test seeding can create duplicate rows.
- **5203 destructive/lock ops** — handler ignores its payload (uids are
  client-local, unresolvable); Godot sends an empty count as a refresh
  request on opening the gear pane and gets a `5200` re-push.
- Ladder: all 7 boards (27500–27514) are exercised by the Godot client;
  only secondary 275xx pages outside that family remain untouched.
- Events 17002/17003 (tournament calendar) are wired; 17004+ are not
  registered server-side. Tournaments (28601/28608/28611/28612/28648/
  28649/28650) are exercised end-to-end by the Godot client.
- Channel membership pushes (3128/3130/3132/3134/3136/3138/3202) are S2C
  only — the server never emits them, so the Godot client has nothing to
  consume yet.
- **2308 alt match accept** — duplicate accept path (matchId+mode+roster);
  the Godot client resolves matches through 23114/23116 instead.
- **22003 criteria** — Godot reports criterion 229 on first world entry
  (verified in coach_stats), 221 on breedmaster dialogs, and 219 via the
  record-1500 NPC dialog tree (verified live: Baan reply → coach_stats).
- 2052 CoachInformations / 4096 coach-actor sub-blobs are still empty (guild,
  inventory, appearance — the `0x80` tome blob is now populated, see B-106)
  BUT this is now known to be low-impact for stats: the
  coach panel's ladder stats come from the **2400 PlayerStatisticsReport** (which
  is sent + now field-correct), not the 2052 blob. The 2052/4096 `0x200` stat
  map only carries **Evolution-mode** stats (a game mode we don't track) and
  `0x100` tournament points / `dBe` team-victories — none modelled yet.
- Matchmaking-accept roster/mode/oppId are still decoded-and-discarded; the
  OpponentSearchError (2302) reply exists on the wire but is never emitted (no
  error condition maps to it yet).

**Fight feature gaps:**
- ~~Combat effect variety — only single-target HP-loss resolves; no areas, buffs,
  multi-target, non-damage effects, range/LoS/pathfinding validation.~~
  **Every clause of that is now false** and it stayed here long after it stopped
  being true: **502 of 533 effect rows resolve (94.2 %)** across 31 mechanic
  kinds, with areas, buffs, poison DoTs, target conditions, cast criteria,
  altitude line-of-sight and full range validation. The real remaining gap is
  **12 action ids / 31 rows** — see ROADMAP §8.5 for the itemised list.
- Bet stakes on a fight win (fights carry a bet field but it isn't wagered).
- In-fight movement (4503) is fully validated (rooted, MP budget, walkable, not
  destroyed, adjacency, occupancy, stop-on-contact). Placement (8021) is gated to
  the placement phase and to the fighter's own side's free start cells (B-075);
  before that it was a free mid-fight teleport to any coordinate.

**E2E gaps** (impl + audited, no end-to-end test yet):
- FighterInformationList (6006), TeamPresetList (6030) round-trips.
- Covered since: whisper (3155/3204), friends add/remove (3129/33/56/60),
  fighter create/delete (6001/6000/6003), team save/delete (6021/6023),
  ignore add/remove (3131/35/58/62), inventory request+equip (5203/5201/5200),
  exchange remove-card + cancel (5106/5108/5110/5111), in-fight movement
  (4503/4524), placement (8021/8022), social ack layouts (3156/58/60/62) +
  presence notifications (3148/3150/3164/3166), matchmaking cancel
  (2303/2304/2306), channel chat (3151/3140), fighter loadout equip
  (6011/6010, cards + slotted spells), shop token buy (5450→5403/5200) +
  wallet sync (4001) + insufficient-funds path, shop open→catalog
  (5300→5401), fight-win token faucet (+4001 reward push), Fusion Lab
  (5490→5491: success/failure-leftovers/mixed-set-fail), **card-for-card barter
  (5400: value-sufficient success / insufficient reject)**.

**Bugs fixed (recent passes):** (full log with root causes in `docs/BUGS.md`)
- **Ping keepalive** (found + verified via the LIVE client): the reply must be
  opcode **108** (`abj_0`), not 107 (`asg_0` is the C2S request only). The client
  credits its keepalive counter (`nW.sL()`) only on a 108; replying 107 made it
  log `Too high ping detected: reply number is low, 0 != 2` and reset every 60s.
  Fixed in `internal/handshake/ping.go`.
- `sendSocialAck` wrote a fixed `[name][i64 id]` for ALL four acks; the real
  client decoders differ per opcode (3156 kz_1 / 3158 ft_0 / 3160 adw_1 /
  3162 ahm_0) — would BufferUnderflow the retail client on 3156/3158. Fixed
  per-opcode + regression-tested (`TestSocialAckLayouts`).
- `sendMatchFound` wrote `mode` into both the mode AND fightType i16 fields;
  now writes `mode` then `subMode` (fightType).
- **Chat double-display**: all three chat handlers (vicinity 3152, channel 3140,
  private 3154) echoed the message back to the SENDER in addition to
  broadcasting. The client already shows its own outgoing line locally, so the
  echo made the sender see every message twice. Removed the self-echo (matches
  the reference server, which delivers only to others / the target). E2E tests
  now assert the sender gets no echo back.
- **Roster empty on panel reopen** (4 stacked root causes, byte-verified vs a
  live client capture):
  1. 6006 was pushed only at login → re-push after every fighter create (6001)
     and delete (6003).
  2. The panel-open request (6031) only returned teams → now returns BOTH the
     team list (6030) AND the roster (6006), like the reference server.
  3. **6006 leading i64 is a server TIMESTAMP (seconds), not the coach id.** The
     client computes each fighter's form as `(now - lead)/3600` hours (xi_0/awy
     callbacks → et_2.a); sending the coach id made that a huge hour count that
     zeroed form. The create result (6000) does NOT apply this fatigue, which is
     why fighters showed on first create but vanished on reopen. Now sends
     `time.Now().Unix()`.
  4. **The 6030 team list must lead with the special type=-4 "Evolution bench"
     team** holding all the coach's fighters. The client's first-open handler
     (ce_1 case 6030) does an unchecked `arrayList.get(0)`, and the normal
     handler (adi_2) scans for the type==-4 team to populate the fighter bench
     (xz_0.amc()). With no teams, count=0 crashed get(0) and the bench was never
     set → no fighters shown. Now `pushTeamPresetList` prepends the bench team.
  Unit tests lock the 6006 timestamp and the bench-team layout; E2E asserts the
  roster reflects create/delete and 6031 returns both lists.
- `buildPlayerStatisticsReport` (2400) put `Strength` in field 6 (an internal
  model value the client reads as `dN`, not a displayed stat) and never sent
  field 8 (consecutive losses, `dO`). Verified vs the decompiled
  `PlayerStatisticsReport` class: field ids are 1=playTime, 2=fightTime,
  3=fights, 4=won, 5=lost, 7=consecWins, 8=consecLosses. Fixed + a new
  `ConsecutiveLosses` coach field (tracked at fight end, persisted) +
  `TestPlayerStatisticsReportFields`.

## Testing

```powershell
go test ./...            # full suite
go test -race ./...      # race detector (all green; heavy combat E2E skipped under -race)
```

E2E suite: **70 top-level tests** (+ store/game unit tests). Added recently —
matchmaking cancel, channel chat, fighter loadout equip (6011/6010), the card
shop (open→catalog 5300→5401, wallet sync 4001, token buy 5450→5403/5200,
insufficient-funds, card-for-card barter 5400), the fight-win token faucet, the
Fusion Lab (5490→5491: success, failure-leftovers, mixed-set-fail), and the 1v1
ladder (27500→27501 window + own-rank; 27502→27503 compact page) — backed by
store unit tests
(`BuyCards`/`CreditCurrency`/`ConsumeAndGrant`/`SaveLoadout`), a game-package
`checkFightEnd` reward test, and real-data gamedata tests (token-price map +
`Priced()` catalog, 845/907 cards priced). All green under normal and -race
across repeated runs (3 heavy full-fight E2E tests — combat damage, in-fight
move, placement — skip under -race by design; the server logic itself is
race-clean).
