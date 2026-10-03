# Bug log — DofusArena 2.70 server

A running record of protocol/behaviour bugs found while making the from-scratch
Go server wire-compatible with the retail 2.70 client. For humans **and** the AI:
each entry has the symptom, the root cause (with the client class that proves
it), the fix, and how it was verified.

**Verification legend:** `unit` (Go unit test) · `e2e` (scripted wire client) ·
`live` (real retail client via the control agent) · `audit` (byte-compared vs
decompiled client, no runtime).

---

### B-168 · Match-decline notice emitted on an opcode the client cannot decode

- **Symptom:** when one coach declined a match, the still-waiting opponent's
  "do you accept?" dialog stayed open forever — the cancel frame never reached
  its handler.
- **Root cause:** `sendMatchCancelled` emitted **23116**, but `aex_0` (the
  23116 class) is `so_0`+`encode()`-only and `gz_1` has no 23116 case — it is a
  **C2S-only** message (the client's post-match roster confirm, built by
  `aox_0`). The retail decoder dropped our frame silently.
- **Fix:** the decline now emits **23112** `MatchResult` (`aku_1: [i8 ok]`), the
  result frame paired with our 23110 announce: `ft_1` case 23112 does
  `avn_0.close()` + toasts `opponentSearchConfirmation.resultIsNo`. (2309 is the
  same frame for the *other* match-found variant, 2307.)
- **Verified:** `audit` (`gz_1`/`aex_0`/`aku_1`/`ft_1`) + unit
  (`TestAddToTome…`, `TestZaapClanIslandRefusalToasts25000` cover the two
  sibling emissions from the same pass).

### B-167 · Godot: spell cast `.xps` particle FX missing

- **Symptom (Godot):** spell casts showed gesture + script sfx but no
  projectile/burst particles — retail runs `Particle.addParticleSystem`
  from `data.jar` scripts (161/197 scripts reference an `.xps` id).
- **Root cause:** the sfx.jar `.xps` binaries (365 systems, textures in
  `particles/<id>.tga`) were never decoded or wired; the fight view had
  no spawn hook on `8110`/`8108`.
- **Fix:** `spell_sounds.py` → `spell_fx.json`; `xps_dump.py` → full
  emitter-tree JSON for **364/364** retail `0x5001` systems (+ `81.xps`
  legacy `XPS` zlib wrapper, skipped); TGA→PNG; `xps_fx.gd` builds one
  `CPUParticles2D` per emitter from `assets/gamedata/xps/<id>.json`
  (154/182 spell-referenced systems stack 2–14 layers);
  `_cast_fx` on `8110` in `fight_view.gd`. Decoder follows `alo_2` /
  `bk_0` / `gg_0` (22-float bitmap models, compact header when
  `dstBlend==0`, DirectionFollower tag-6 has no leveled bit).
- **Fix (2026-10-03):** the regex pass missed whole code paths —
  direct `displayEffect()` calls (7 spells), `invoke (` with a space,
  `addTweenParticleSystem` variable ids, direction-keyed picks
  (`if startMobileDirection == N`, `APS_*` tables), `time`-relative
  invokes — and scraped commented-out code (3 false rows). Replaced by a
  scoped mini-evaluator → **116 spells** (was 100), incl. the Cra arrow
  family (`10905`–`10945`: dir-keyed projectile ids, `delai_trajSprite`
  constants) and Xelor's Aiguille volley (8 needles, impact bound to the
  main needle). `addTweenParticleSystem` now flies retail's `avw_0`
  arc in `xps_fx.gd` (`spawn_projectile` + `arrived` → `tw#i+k` rows);
  `pick_id` resolves `{dir:id}` maps by caster Direction8.
- **Fix (2026-10-03, paridad):** the three hot affectors now run their
  real `ua_0` update math in `xps_fx.gd` — `LinearForceEx` (`lv`: vel +=
  F·33·dt → iso-projected accel), `FrictionalForce` (`nt`: vel·= 1−(33−
  f)·dt → damping), `ColorFader` (`oo_0`: c += (t−c)·speed·dt inside
  TimeCondition windows → simulated lifetime `color_ramp`). All
  emitters now spawn (not just the first), each under its own
  `startSpawnTime`/`endSpawnTime` window (`_schedule_emit` timers;
  projectile trails hold `flying` until `arrived`). `Rebound` (`arx_0`
  dvel = R90(offset)·restitution·dt — an orbital curl, not a bounce) is
  approximated by `tangential_accel` (29 spell-referenced systems).
  The keyframed layer (fixed 0.03s tick inside `TimeCondition`
  windows) is ported too: `Deformer` (`ir_1` — scaleX/Y += p0/p1,
  rot += p2 per tick, ~160 systems) → piecewise `scale_amount_curve`
  + `angular_velocity`, and `LinearForce` (`af_0` — pull toward a
  point; every authored target is the origin) → `radial_accel`.
  `DirectionFollower` (`aie_1` — billboards track screen velocity;
  its emitters are motionless, the visible motion is the parent
  system's) is approximated on projectiles by rotating the streak
  body to the instantaneous screen velocity (arc-following).
  Still out: sub-emitters (7 decoded systems, none spell-referenced)
  and lights (a single corpus entry).
- **Verify:** `fight_smoke` + `carry_smoke` green (headless, 0 script
  errors). Live cast FX visible when `spell_fx.json`, `xps_index.json`,
  and the texture png exist for the spell's xps id — the `assets/fx`
  pngs need a `.godot` import pass (`godot --headless --import` once
  after regenerating) or `load()` skips them silently.

### B-166 · Godot: anm-frame `runScript` audio channel missing entirely

- **Symptom (Godot):** fight gestures played silent — cast whooshes,
  tackle/hit/KO grunts, weapon-draw sweeps, emote stingers — even though
  the oggs existed in `sounds.jar`.
- **Root cause:** `spell_sounds.py` only covered the *spell-script* API
  `Sound.playSound`. The louder retail channel is separate: 83 `.anm`
  files carry `pb_1` **runScript** frame parts (1,657 parts) that run
  `scripts/anm/<id>.lua` on frame enter — 388 `Sound.playLocalSound`,
  21 `playLocalRandomSound`, 18 `playBark`, 4 `playGroundSound` calls.
  `anm_render.py` parsed the parts but never recorded them, so no
  metadata reached the client.
- **Fix:** `anm_render.py` now collects `scr_hits` (script id → first
  logical frame, same rule as `Sons*`) in both the flat and composite
  renderers and emits `meta.scr` `{frameIdx: [scriptIds]}`;
  `spell_sounds.py` gained a `scripts/anm/*.lua` pass emitting
  `anm_scripts.json` `{scriptId: {s: [[soundId, gain]…], stop}}` —
  `playLocalRandomSound`'s arg list is literal `(id, gain)` pairs picked
  **uniformly** (`agO.c` uses `ej_0.n`, the second number is gain not a
  weight). `AnmSprite` resolves the table lazily, plays picks through
  the same pool with `volume_db = linear_to_db(gain/100)`, and kills
  `stopOnAnimationChange` streams on the next `load_action` (retail
  registers the stream handle and stops it on anim swap). Skipped and
  documented: `playBark` (npc voice table, 18 scripts — no matching
  oggs shipped), `playGroundSound` (ground-material footsteps, 4
  scripts), `playCount` (never used — all calls 4-arg), and
  `rollOffPreset` (positional attenuation — the pool is non-positional).
  `anm_scr_patch.py` backfills `meta.scr` into existing exports without
  re-rendering: 3,144 metas patched.
- **Verified:** `audit` — patched metas carry retail script ids (e.g.
  `1_AnimTacle` frame 0 → 1990000005/1990000006 → whoosh 1100000001-3
  @35 + hit 1100000004 @60); `fight_smoke` green; headless AnmSprite
  check resolves the table and no-ops cleanly on bark ids.

### B-165 · Godot: opcode 2050 (coach-creation result) had no handler

- **Symptom (Godot):** a refused coach creation (e.g. a taken name) was
  silent — the server answers `2050` with the result code and only sends
  `2052`/`4600` on success, so the client waited forever.
- **Root cause:** the dispatch table covered `2048` (creation request)
  and `2052` (coach info) but `2050` fell through unresolved; only the
  generated opcode constant existed.
- **Fix:** `main.gd` now handles `OP_COACH_CREATION_RESULT` — logs the
  refusal code; success still flows through `2052` + `4600` unchanged.
- **Verified:** audit (the handler is a one-byte read + log; the success
  path is exercised by every smoke's login).

### B-164 · titularRoster caps by arena seats, not the six-fighter team rule

- **Symptom (Godot smoke):** every `26330` défi launch answered `26310`
  "illegal roster: too many fighters" once the coach's titular list
  reached 8 fighters (rewards had grown it past the team cap).
- **Root cause:** `titularRoster(coachID, max)` caps picks at `max`, which
  callers set to `len(fightArena.team0)` — arena start cells, often ≥8.
  With 8 titular fighters the roster passed `validateRoster`'s
  `maxTeamMembers` (=6) check and the launch refused. Affected every
  server-picked lineup: `startPvEChallenge`, `/FIGHT` GM, totem duels.
- **Fix:** `titularRoster` now clamps `max` to `maxTeamMembers` before
  reading the store — the same "the server picks a legal lineup" rule
  that already enforced `maxSameBreedPerTeam` there.
- **Verified:** `live` Godot `fight_smoke` — challenge 34 launches with
  the 8-fighter titular roster again (capped to 6), fight completes.
  (`internal/game/handlers_fightcreation.go`)

### B-163 · Godot: the LadderDlg list never cleared between tabs

- **Symptom (Godot):** switching tabs in the "Ranks" window stacked rows —
  e.g. the Coach ladder rendered appended under leftover 1v1 rows, and the
  criteria tab could repeat its rows on reopen.
- **Root cause:** `_fill_ladder` only ever *appended*; neither
  `_open_ladder`, `_on_ladder_tab` nor the dispatch cleared the ItemList.
  Windowed "More" requests are supposed to append, so the fill itself can't
  blanket-clear.
- **Fix:** `_ladder_request` clears the list when `_ladder_start == 0`
  (fresh open / tab switch); `More` requests keep appending.
- **Verified:** live `world_smoke` — the Achievements tab fills 112 clean
  rows after the other tabs.

### B-162 · `/TP` moved the coach but never its element AoI — zone triggers silently absent

- **Symptom (Godot smoke):** after `/tp 179 194` the client correctly snapped
  to the cell, but `zone_triggers_at` found nothing — the kind-8 element
  sitting exactly there never existed in the client's registry, even though it
  was inside the env-chunk radius.
- **Root cause:** `teleportWithinWorld` calls `World.ApplyMove`, which only
  diffs the *actor* AoI. Interactive elements live in a separate per-session
  registry (`spawnedElements`) kept in step by `refreshWorldElements` — wired
  into `EnterAoI` and `handleCoachMove`, but never into the teleport path. The
  coach landed surrounded by elements its client was never told about; the
  stale set still claimed whatever surrounded the previous cell.
- **Fix:** `teleportWithinWorld` now calls
  `s.refreshWorldElements(s.currentWorld, x, y)` right after `ApplyMove` — the
  same call the walk path makes — so a 4510 lands with the correct 200/206
  element diff.
- **Verified:** live Godot smoke: `tp (179,194)` now receives a 200 spawn for
  element 60 (`cells=[(179,193)..(179,196)]`, desc `100;0;275`) and its
  scenario fires — `triggers=[60]`, 11-page tutorial monologue, criterion 221
  persisted. (`internal/game/teleport.go`.)
- **Client-side companions (Godot):** `main.gd` had no 4510 handler at all —
  added `OP_ACTOR_TELEPORTS` decode + `WorldView.actor_teleported` (snap
  position, drop walk state, recentre camera, emit `cell_entered`). Also fixed
  `cell_entered` emitting `Vector3i` into a `Vector2i` slot on both the world
  load and walk-step paths.

### B-161 · Illegal roster on fight launch disconnected the coach

- **Symptom (Godot smoke):** `26330` (Tester / overworld challenge) closed the
  connection with no reply once the coach's roster held three fighters of one
  breed — an easy state to reach in a dev database.
- **Root cause:** `buildFightTeamFor` refuses an illegal roster with
  `rosterError`, which carries a retail `26310` error code — but every call site
  (`handleTeamTest`, `startPvEChallenge`, `startChallengeFight`, matchmaker
  `startFight`, totem duels, the GM fight command) propagated it. `serve` drops
  the session on any handler error, so a *gameplay* refusal became a disconnect;
  in the two-session paths it would have dropped BOTH coaches.
- **Fix:** `refuseFightError` converts a `rosterError` into
  FIGHT_CREATION_ERROR (26310) on every waiting session; other errors still
  propagate. Also `titularRoster` now enforces `maxSameBreedPerTeam` while
  picking — for challenge launches the server picks the lineup, so it picks a
  legal one instead of choosing a roster it then refuses.
- **Verified:** `unit` (`TestTeamTestIllegalRosterAnswers26310`,
  `TestTitularRosterCapsSameBreed`) + live Godot smoke: `26330` now yields
  `8000` (two capped Iops fielded) instead of a disconnect.
  (`internal/game/handlers_fightcreation.go`, `handlers_challenge.go`,
  `handlers_fight.go`, `handlers_totems.go`, `handlers_gm.go`.)

### B-160 - SECURITY (second pass): the remaining Medium and Low findings

Closed in one sweep; see `SECURITY.md` for the per-item table. The ones worth
knowing about:

- **Equipping moved the whole stack.** `Pos` lives on the stack ROW, so equipping
  one of five copies set `Pos` on all five: they vanished from `pushInventory`
  (which filters `Pos == 0`), became untradeable, unfusable and unmailable, and
  counted as ONE for set bonuses. It was also how duplicate `pos = 0` rows
  accumulated, since `BuyCards` only stacks onto a `pos = 0` row. Equipping now
  splits one unit off and merges it back on unequip.
- **`consumeCard` was a lost-update.** No transaction, no guard on the value it
  read, discarded errors - it returned `true` even when nothing was written. Now
  a single conditional `UPDATE ... quantity = quantity - 1 WHERE quantity > 0`.
- **Fusion had no value ceiling.** Both of the client's gates are no-ops for ~900
  of 907 cards, so two commons became a set's best card at a flat 60%.
- **A dead fighter kept acting.** 8109/8111/4503 had no `HP > 0` check (8107 and
  4521 did), and death is only acted on at turn start.
- **Self-trade locked a coach out of trading**, and the same shape aimed at a
  stranger locked *them* out.
- **`Coach.Inventory`/`Wallet` were written from other goroutines** without
  `Coach.Mu` - an unsynchronised slice-header write, i.e. undefined behaviour
  rather than a stale read.

**Verified.** unit + e2e, `-race` clean across `internal/game` (91s), `test/e2e`
(27s) and `internal/store` (58s). Stack split/merge and the name rejections are
mutation-verified.

**Note.** The overworld displacement cap broke three AoI tests that were using
4501 as a teleport - exactly the primitive being removed. The helper now walks in
hops. Worth recording because the first hop size (80 per axis) is 113 cells
diagonally, over the 100-cell Euclidean cap, so every hop was refused and the AoI
assertions failed for a reason unrelated to AoI.

---

### B-159 - SECURITY: spell loadouts were client-authored (6011)

**Symptom.** Any fighter could cast any spell in the game, persistently.

**Cause.** `castSpellByFighter` gates casting on `fighterKnowsSpell`, which reads
the spell list the CLIENT writes through 6011. `decodeLoadoutSpells` accepted up
to 6 arbitrary ids with no legality check, and `SaveLoadout` validated only WHOSE
fighter it was, never WHAT spells - so the mitigation combat believes it has was
anchored on attacker-controlled data. The same handler already validated CARDS
(`canonicalEquipSlots` + `entitledEquip`); spells were passed straight through,
and `fighter.go` carried a comment admitting the gap.

**Fix.** `spell_legality.go` filters client-authored lists to the fighter's own
breed. Measured rather than assumed: of 203 spells, breeds 1..14 own 10-13 each;
pseudo-breed 0 (44 spells) is monster/summon material - id 428 is range 1-30
value 250 - and pseudo-breed 99 (14) is boss utility. Legitimate extras are added
SERVER-side after the filter (sphere unlocks, summons, challenge demons), so
nothing legitimate reaches a spell list through the client.

**Verified.** unit + e2e. The e2e tests were necessary: mutations bypassing the
filter at BOTH call sites survived the entire unit suite.

---

### B-158 - SECURITY: no connection limits, timeouts or login throttle

**Symptom.** A few dozen sockets could saturate every core; 10k idle connections
were free.

**Cause.** The accept loop took every connection unconditionally - no global cap,
no per-IP cap, no read deadline, nothing to evict a socket that connected and
never spoke. Each connection costs two goroutines, ~12 KB of buffers and a
256-slot queue that can hold up to 16 MB. Opcode 1025 runs bcrypt synchronously
on the session goroutine (~50-100 ms), so unthrottled logins were the cheapest
full-server DoS, and password guessing had no limit either.

**Fix.** A `limits:` config block (global + per-IP caps, handshake and idle read
deadlines, per-IP login throttle), all 0-means-default / negative-means-disabled.
Auto-registration and first-account-becomes-admin became opt-out switches - the
latter is a race an attacker wins on a fresh public instance, and every GM verb
is gated on that flag. 1025 also gained an already-authenticated guard: it could
be replayed forever, leaking a Sessions key and a world-registry entry per
attempt, and `Registry.byID` is iterated under a global mutex on every movement
packet.

**Note.** I first phrased the flags positively, so a zero-value `Limits` meant
"auto-registration OFF" and every e2e login was refused. They are negative flags
now, and a test pins that the zero value is inert.

---

### B-157 - SECURITY: empty and unusable names accepted for fighters, teams, guilds

**Symptom.** A fighter could be created with an empty name; guild names were
case-sensitively unique.

**Cause.** `sanitizeFighterName` returned `"Noob"` for empty input, which accepted
the input and disguised it - and hid that a client was sending something the
retail client never sends (`acx_2` and the fighter form both refuse locally).
`GuildRepo.Create` compared names with `Where("name = ?")` while `CoachRepo` used
`LOWER(name) = LOWER(?)`, so `Elite`/`elite`/`ELITE` were distinct guilds - direct
impersonation, and the name is broadcast to every online session on creation.
Guild rank names had no validation at all.

**Fix.** 6001 and 6021 reject; guild names and rank names go through
`sanitizeDisplayName`; guild uniqueness is case-insensitive.

`validateFighterName` uses a WHITELIST rather than "strip and keep the rest",
because stripping accepted `<b></b>` as a fighter named `b/b` - harmless, but
plainly not something a player typed, and it means the set of storable names is
defined by whatever the stripper misses instead of by a rule someone chose.
Sanitisation still runs FIRST, so `Ad<U+00AD>min` normalises to `Admin` and is
judged as `Admin` would be, rather than being stored as a distinct row that
renders identically.

**Verified.** unit + e2e (opcode 6001 with empty/blank/markup/invisible names
creates no fighter; a legitimate name still does). Mutation-verified.

---
### B-152 - SECURITY: repeatable tournament reward cards (28611)

**Symptom.** A tournament winner could mint its reward card without limit.

**Cause.** `awardTournamentPrize` had no already-paid record. Its reachable
caller, `handleTournamentSearchRequest` (28611), re-derives "unopposed in this
tournament" purely from persisted bracket state - registration closed and the
root slot held by this coach - so it stays true indefinitely and each packet
granted another copy. `IsRegistered` is never cleared on winning either.

**Fix.** `TournamentRepo.ClaimTournamentPrize` makes payment idempotent, with the
guard in the UPDATE's WHERE clause so two concurrent claims cannot both match.
Deliberately a pay-once LEDGER, not an eligibility check: my first version
refused when no registration row existed, which broke three existing prize tests.
That was the useful signal - requiring registration adds a second rule about WHO
may be paid, and unregistration happens elsewhere in the lifecycle, so a
legitimate winner could have been silently denied.

**Verified.** unit (store: repeat claims, per-coach/per-tournament isolation) +
unit (game: `awardTournamentPrize` five times grants once). Mutation-verified.

---

### B-151 - SECURITY: unpriced cards were purchasable for free (5450)

**Symptom.** Most of the card catalogue could be minted at no cost.

**Cause.** `handleShopBuy` derived cost solely from the template's `Price` map,
and `BuyCards` skips entries with `amount <= 0`. A card whose price map is empty
or all-zero therefore cost nothing. Live against shipped data: of 907 cards, 62
sit in a card set with NO price and 702 more carry an all-zero price - 764
templates, 64 per packet. `shopID` is unvalidated, so the attacker picks whichever
set holds the card it wants and never approaches a Card Master.

Confirmed these are not-for-sale rather than free by reading the records: card 51
has `price map[1:0]` with `value 36200`; card 449 `price map[1:0]` with `value
17234`. A zero entry means "no price in this currency".

**Fix.** `cardIsPurchasable` in `handleShopBuy` rejects any card with no strictly
positive price. The shop CATALOGUE is deliberately unchanged - I briefly filtered
it too and broke `TestCardMasterStockIsItsCardSet`, which documents an unpriced
in-set card as "still stocked". What retail displayed is a parity question with no
client evidence; what the server hands over is not.

**Verified.** unit (`cardIsPurchasable` table, plus
`TestStockedIsNotTheSameAsPurchasable` recording the asymmetry).
**Gap, honestly recorded:** no test drives opcode 5450 end-to-end with an
unpriced card id, so removing the guard from the handler does NOT fail the suite.
Follow-up.

---

### B-150 - SECURITY: the client could clear the server's anti-replay flags (22003)

**Symptom.** PvE challenge reward cards could be farmed indefinitely.

**Cause.** The server records "challenge N already cleared" as stat id
`2000 + N` in the same `coach_stats` table opcode 22003 lets the client write, and
`UpsertStat` OVERWRITES rather than maxes. Beat a challenge, send 22003 with
`statID = 2000+N, value = 0`, re-run it, get paid again.

The namespace was documented as un-collidable because 2000 exceeds the client's
`MaxCriterionID` (1007). That only held for OUTPUT - `buildCriteriaBlob` drops ids
above 1007 - and said nothing about input. `su.StatID` is a full `int16`.

**Fix.** Writes restricted to the client's own criterion range, which the client
never exceeds, so no legitimate flow changes. A test asserts the two id spaces
cannot overlap, so raising `MaxCriterionID` past 2000 fails loudly.

**Verified.** e2e (real 22003 frame: bookkeeping id rejected, criterion 213 still
accepted) + unit (namespace separation). Mutation-verified.

---

### B-149 - SECURITY: duplicate logins leaked coach state into every subsystem

**Symptom.** Re-logging in while queued left a ghost that other players were
matched against; the second session was also invisible to the whole world.

**Cause.** Two halves.
`onClose` returned EARLY for a session displaced by a newer login, skipping its
entire teardown - deterministic, not a race, because `handleAuthentication` calls
`Sessions.Swap` BEFORE `old.kick()`, so `Sessions.Remove` always reports false
there. The matchmaker kept a searcher holding a dead socket, and challenges,
exchanges and 2v2 pairings kept their counterparties waiting on someone gone.
Separately, `World.Add` refuses a coach already present, so the NEW session lost
permanently: full login sequence, but no AoI, and every world-scoped delivery
routed to the dead socket.

**Fix.** `releaseSubsystems()` extracted and run on BOTH paths.
`Registry.TakeOver` re-points the existing entry at the new session, preserving
position and AoI known-set so nobody sees a spurious despawn/respawn.
`Registry.RemoveIfSession` stops a closing session tearing down an entry a newer
login already owns.

**Verified.** e2e (`TestReplacedSessionReleasesItsChallenge`: two sockets, live
challenge, second login) + unit. The e2e test uses the CHALLENGE rather than the
matchmaker queue on purpose - the matchmaker's own ghost purge would have masked
the queue case, so the queue is not proof the release runs.

---

### B-148 - SECURITY: 6021 team-preset IDOR and roster duplication

**Symptom.** Any client could overwrite and take ownership of another coach's team
preset, and could field a roster of duplicated fighters.

**Cause.** `TeamRepo.Upsert`'s doc comment claimed it was "scoped to the owning
coach"; the code had no `coach_id` predicate at all. The team id arrives on the
wire, and `gorm.Save` with a non-zero PK issues `UPDATE teams SET * WHERE id = ?`,
so naming a victim's id deleted their members and rewrote `coach_id`, `name`,
`game_mode`, appearance and `ally_coach_id` (destroying their 2v2 pairing). Team
ids are small sequential integers.

Separately, member building checked ownership but nothing else. The fighter count
is a `u8`, so the same owned fighter could be sent 255 times. Beyond an unfair
roster this corrupts the fight: `WireID = base + fighterID*16 + side*8 + i`
collides with another fighter's space past `i=16`, and placement does
`cells[i%len(cells)]`, stacking fighters on one cell.

**Fix.** `Upsert` requires the row to already belong to the caller, and a miss is
indistinguishable from a nonexistent id so it cannot enumerate other coaches'
ids. `presetMembers` applies the same rules the drag-and-drop path already
enforced via `canPlaceFighter` - 6 members, no duplicates, 2 per breed - with the
two limits promoted to named constants so the paths cannot drift again.

Refusals are silent by design: retail validates rosters LOCALLY (`hu_2` shows
`error.teamManagement.fightersCountExploded` itself and never sends), so no
"invalid preset" status exists on the wire. Same precedent as chat flood.

**Verified.** e2e (steal attempt leaves the victim's team owned and named as
before; 20 copies of one fighter save as 1; 8 fighters over 4 breeds cap at 6; 5
of one breed cap at 2). Mutation-verified.
**Note:** the dedup test alone was insufficient - with 20 copies of ONE fighter,
dedup leaves a single member and the size cap is never reached, so a mutation
disabling it survived. The cap tests use distinct fighters for that reason.

---

### B-147 - SECURITY: channel chat was unsanitized and unthrottled (3140)

**Symptom.** One client could inject markup into every online player's chat, and
spam a global broadcast with no limit.

**Cause.** `buildChannelMessage` was the only chat builder that sanitized
nothing, while vicinity, trade, clan, group and private all did - and it is the
widest pipe of the set. All three fields are attacker-chosen: the channel KEY and
body come straight off the wire, and the sender name is only as trustworthy as
coach-name validation. The client renderer (`rw_2.bJ`) parses `<b>`, `<c>`,
`<text color=...>` and `<image pixmap=...>` in the body AND the sender name with
no escaping (B-104); the input widget's `restrict="[.*&[^<>]]"` is client-side
only. The pipe also had no throttle at all.

**Fix.** All three fields through `sanitizeChatText`; `allowRepeat` shared with
its siblings.

**Verified.** unit. Two corrections worth keeping: `maxChannelField` is defence in
depth and NOT the live protection (`Writer.StringU8` already truncates at 127, and
its comment records being hardened for this exact case), and my first length test
checked for a NEGATIVE prefix - wrong, since `byte(len(s))` wraps modulo 256, so a
300-byte field yields 44: positive but describing fewer bytes than follow. The
test now asserts the three fields consume the payload EXACTLY, and fires when both
clamps are removed.

---

### B-146 - SECURITY: empty and impersonating coach names accepted (2049)

**Symptom.** A coach could be created with an empty name, with markup, or with a
name that renders identically to another player's.

**Cause.** `CoachRepo.Create` applied only `strings.TrimSpace`, so a
whitespace-only name collapsed to `""` and stored fine - NOT NULL is satisfied by
the empty string and the uniqueness count is 0. (`sendGuildMembers` already had to
skip blank member names, which was this leaking through.) Also accepted: markup,
C0 controls including newlines, and U+00AD SOFT HYPHEN, which is not
`unicode.IsSpace` so it survived TrimSpace and renders as nothing - `Ad<AD>min` is
a distinct row displaying as `Admin`.

2049 could also be replayed indefinitely: it checked only that the account was
authenticated, so a loop minted unlimited coaches, each re-pointing the account
and each collecting starter cards and wallet.

**Fix.** `validateCoachName`, built from the CLIENT's own rule
(`aBC.validateCoachCreationForm`: `length <= 20` against
`([\p{L}]|[\p{L}][-]){2,}\p{L}`). The server rule is a deliberate SUPERSET that
also allows digits: being stricter than the client would reject names a
legitimate client can produce, while being looser only risks accepting one retail
would not have made, and digits enable none of the attacks. `clientCoachNameRE` is
kept alongside for strict parity, with a test pinning that we are never stricter.
The client's error string `error.coachCreation.invalidName` reads "Nom de coach
invalide ou deja utilise", so result code 11 already covers "invalid" and no
server prose was invented. One coach per account now enforced.
`sanitizeFighterName` also fixed: it cut at 16 BYTES, splitting runes and
persisting invalid UTF-8, and stripped no markup.

**Verified.** e2e (six hostile names via the real 2049 frame; replay refused) +
unit. Mutation-verified.
**Note:** the replay guard first tested `s.Account.CoachID`, which
`CoachRepo.Create` updates in the DATABASE but not in memory - it read correctly
and never fired. Only the e2e test caught it. And my first mutation check reported
CAUGHT because the mutant did not COMPILE; rewritten to compile it reported
MISSED, revealing nothing exercised 2049 with hostile input at all.

---

### B-145 - SECURITY: no panic containment; two remote full-server crashes

**Symptom.** Three packets from a throwaway account killed the entire server
process - every logged-in player and every fight in progress - and it was
re-armable at will.

**Cause.** There was no `recover()` anywhere in production code, and Go
terminates the whole process on an unrecovered panic in ANY goroutine. Two
reachable nil dereferences:

1. **Matchmaker.** Queue for a fight (2301), then destroy your own coach (27529).
   `handleDestroyCoach` set `Session.Coach = nil` without cleaning the matchmaker,
   and `onClose`'s cleanup is gated on `s.Coach != nil` so disconnecting did not
   clean it either. The next honest player to search dereferenced the ghost at
   `matchmaker.go:115`.
2. **ChallengeManager.** Same shape: invite someone, destroy your coach, and the
   victim's accept/decline - or any third party's logout touching that challenge -
   dereferenced `c.challenger.Coach.ID`.

**Fix.** Coach ids now resolve through `searcherCoachID` / `sessionCoachID`, which
report absence instead of dereferencing; the matchmaker purges ghosts on the
Search path so the queue self-heals. `handleDestroyCoach` releases every subsystem
before nilling the coach. Containment added independently:
`Session.dispatchSafely` (drops that one session, logs opcode + stack) and
`Fight.runEvent` (keeps the fight running - one bad event must not void a match
players are minutes into).

**Verified.** unit, with the panic reproduced BEFORE the fix. Every guard is
mutation-verified.
**Note:** two of these tests were initially vacuous. The `ConfirmTeam` subtest
never accepted the challenge, so it returned early and never reached the guarded
line; and I only ever nil'd the CHALLENGER's coach, leaving the mirror deref on
`c.target` untested. Both mutations survived until the fixtures were fixed.

---
### B-137 - re-entering the SAME world duplicated interactive elements - FIXED by B-142

**Status: FIXED**, as a side effect of B-142 rather than by the guard I was contemplating.
The duplication only happened because a same-world teleport re-entered the instance at all.
Now that `/TP` on the current world uses 4510 instead, there is no second element push to be
rejected - verified live: the `Impossible d'ajouter un elements interactif` error no longer
appears after a same-world teleport.

Worth noting the guard I was going to write ("skip the element push when the world is
unchanged") would have worked, but it would have left the re-enter in place along with its
roster/preset churn, and carried the first-enter trap described below. Removing the re-enter
was the better fix and it was not visible until the AoI work made it possible.

**Symptom.** Any code path that calls `sendEnterOverworld` for the world the coach is ALREADY
on makes the client log:

```
ERROR Impossible d'ajouter un elements interactif d'ID=37 au manager ajX@... qui le contient deja.
```

(37 is world 25's Zaap.) Reproduced by firing `/resetPosition` via the dev `/c2s` endpoint
with the coach already on world 25.

**Why it matters beyond the log line.** `elements.go` carries the comment *"the client clears
its element manager on each 4600, so they must be re-sent per world"*. That is evidently NOT
true for a same-world re-enter, so the premise the element re-push rests on is wrong in at
least one case. Whether the element ends up in a broken state or the client just refuses the
duplicate is not yet established - the error is raised by the manager, and the add is rejected.

**Scope - this is not new.** It affects every same-world `sendEnterOverworld` caller:
  - `/TP` (`gmTeleport`) explicitly stays on the current world
  - `/resetPosition` (B-135), which inherited the behaviour
  - Zaap travel only when the destination island is the current one

**Experiment run - what the client actually does.** Re-entered world 25 while already on it
and read the manager's own words: *"...au manager ajX@172290f **qui le contient deja**"*. The
manager still HOLDS element 37 and REJECTS the duplicate add. So:

  - the client does **not** clear its element manager on a same-world 4600 (contradicting the
    `elements.go` comment), and
  - the original element survives - the re-push is redundant rather than destructive.

That makes the error **noisy but benign**: nothing is lost, the second copy is simply refused.
It is a real defect only in that it hides genuine element errors in the log.

**Why it is STILL not fixed.** The obvious change - skip the re-push when `world ==
s.currentWorld` - has a trap: on the FIRST enter into a world, `currentWorld` may already have
been set to that world by the caller, in which case the guard would skip the push that
actually matters and leave the island with no interactive elements at all. Distinguishing
"first enter" from "re-enter" is the real work here, and it is not a one-line change. The
symptom being benign is what makes deferring it defensible.

**How it was found.** Only by reading the retail client's log after driving a real teleport.
No server-side test would show this: the server's behaviour is correct in isolation, and the
client accepts the frame - it just rejects the duplicate element.

## Open / suspected

### `generic effet inconnu : 0` — the frames that genuinely have no effect record (documented, won't fix)

Part 0's third field is the **generic effect id**, which the client resolves into
the effect RECORD (`yi_1.f` → `gR().iK(n2)`). It is the shipped `Ht.effect_id`,
i.e. exactly our `gamedata.Effect.EffectID`, and `0` is the data format's "no
record" sentinel — so the lookup can never succeed and the client logs it.

A null record is not what it first looks like. Every read of it is null-guarded,
so nothing crashes and the damage numbers are right (the value is applied
verbatim). What breaks is PERSISTENCE: `akF()`, `akD()` and `isInfinite()` all
read the record, so with none the effect is never added to the target's buff
container and `jt()` is a no-op. **Any effect meant to LAST cannot last if it
carries generic id 0.** Every remaining site is instantaneous, so the cost today
is a log line — but it is a live trap for whoever gives one of them a duration.

Fixed where a real id was in scope: the zone AP/MP drain (`applyZoneResourceLoss`
had `ef` right there) and the damage rebound (`ef.EffectID` is now threaded
through `applyDamageRebound` / `dealReboundDamage`).

**Deliberately left at 0**: the AP/MP debit frames, close combat, the walk cost,
the special-cell boosts and fallback damage. These are server-invented actions
with no shipped `Ht` row — there is none with action 91/92 — so the only way to
silence the log would be to attach a FOREIGN record, and if that record carried a
finite `effect_duration` it would turn every AP debit into a timed buff that calls
`jt()`, re-creating B-113. A log line is the cheaper bug.

### Coach action deck — nothing populates it in the 2.70 build (investigation CLOSED)

The wrong-namespace half is fixed (B-088). The remaining question was what should
populate `coachActionDeckSpellIDs`. Answer: **nothing does, in this build** — so
the empty deck is the complete and correct behaviour, not a stub awaiting work.

Every mechanism that could grant a coach an action spell was followed to ground:

- **`np_1` type 27**, literally *"Ajouter un sort de coach"* — appears on **no**
  shipped coach card. The 13 rule types that do appear are catalogue entries with
  no operands.
- **`azk.h()` / `azk.i()`**, which bucket castables by breed 99 / 98 (`xq` is the
  breed enum: `axT(98)`, `axU(99)`), and **`azk.aLO()`**, which would draw up to 3
  at random from the breed-99 bucket — **none of the three has a single caller**,
  so the buckets are never filled and the draw never runs.
- **The coach card record** carries no spell reference. It is decoded to the end;
  its last field `tE()` is the colour PALETTE index (the client builds
  `"fighterColor" + tE()`), not a link to anything castable.
- **`zd_2`** is the Masqueraider mask picker (only the 5 parented spells
  471/472/473→462, 474/475→452), and **`aJt.Qx()`** is a SUMMON's spell list
  (`ta_0`'s own error string says *"SummonedFighter"*).

The client-side feature is fully built — the deck is exposed as
`"coachSpellInventory"` and played with **8109**, the ordinary spell cast — but
2.70 ships no data to fill it. If a source is ever found or invented, the only
change needed is the candidate list in `coachActionDeckSpellIDs`; the filter, cap
and wire format are already right, and the cast handler would then also need to
accept a deck spell the FIGHTER does not know (`fighterKnowsSpell`), since it
belongs to the coach.

- **The coach META layer is only PARTLY built.** Slice 1 — XP, morale, fatigue and
  coach reputation — landed in B-065. Still missing: the wound roll, the death roll
  and the drop table, so ~30 of the 78 card-set effects remain inert.
- **Fighter conditions (type 902) are unmodelled** — wounds never accrue between fights.
  Fully decodable (0 unknown fields); needs the roller `bf_1.b` ported.
- ~~**Most `np_1` rule types are decoded but not ENFORCED.**~~ — **resolved: they are a
  CATALOGUE, not rules.** Types 1–32 are rules, 900–930 are the typed OPERANDS
  (`ajr_2` names every one *"Paramètre de …"*), and `np_1.b()` concatenates a rule with
  following entries until it has `T()` of them. The 13 rule types on coach cards each
  appear once with zero params — a menu for composing a custom ruleset, which `jk_1`
  ("coachCardFightParametersManager") pairs with parameters to build the picker. Rules
  that really apply arrive already parameterised via the challenge records (10/12/13/14,
  all wired). Pinned by `TestNp1RuleCatalogueShape`.
  **Consult `content.54.<type>` for a rule's exact semantics before implementing one** —
  it is the authoritative label table, and it is what revealed the timing rules are
  deltas rather than absolutes.
- ~~**Spell `TargetMasks` / `MaxActive` decoded but not evaluated.**~~ — `TargetMasks` is
  enforced (B-081, 3 spells). `MaxActive` is deliberately NOT enforced: its decay window
  is one turn (`arm_0.lQ(1)`, a literal), which is the granularity `CastMaxPerTarget`
  already has, and all 6 spells are already bound at least as tightly by an enforced
  limit. Pinned by `TestMaxActiveIsRedundantInShippedData`.
- **[RESOLVED — kept for the reasoning trail] The end-of-fight dialog.** It now
  renders: see B-098, which found the actual cause (the evolution mode that
  produces it could not be started at all, because 23003 went unanswered), and
  B-096, verified live by the same run. The investigation below is left in place
  because the *method* mistake it records is the reusable lesson.

  The earlier "it never appears" claim was wrong. It rested on fights started by
  injecting CREATE_FIGHT at a client that had not asked for one. Capturing the
  client's own log (see the tooling note below) showed what really happened:

  ```
  WARN [DEFAUT DE CONCEPTION] Message (aAt) non traite, de type 8000, ...
  WARN [DEFAUT DE CONCEPTION] Message (YP)  non traite, de type 8300, ...
  ```

  **CREATE_FIGHT itself was never handled.** `WE` — the only handler for 8300 — is
  registered in exactly one place, `adu_0` line 244, i.e. by the fight object the
  client builds *when it processes 8000*. A client that never entered fight mode has
  no 8300 handler, so the absent dialog was an artefact of the test method, not a
  server fault. The screenshots agree: they show arena scenery with no fighters, no
  timeline and no fight HUD — the map had loaded from ENTER_INSTANCE and nothing more.

  What was still needed was a fight the client STARTS ITSELF, then watching for the
  result screen. Doing that produced the real answer twice over: the "Tester"
  button gave a genuine client-initiated fight that ran and ended cleanly but
  carries no reports (practice and challenge fights skip progression by design),
  and Evolution → COMBATTRE, the mode that DOES produce the dialog, turned out to
  be unreachable — B-098.

  *Confirmed live in passing:* the client's **calendar** renders the three standing
  tournaments from the database across the month, so the 17003 path works end to end
  in the real UI.

  Eliminated so far, each by reading the client and matching the server against it:
  the 8300 payload decodes (`YP.a` read field-by-field against our writer, including
  the two-i32 action header `ue_0.o` and the `len >= 9` guard); the fight kind now
  reaches `aKl()` (B-095); the per-fighter reports are now resolvable in the
  recipient's roster (B-096); and the coach ids in the winner/loser lists match the
  ones `writeFightCoachBlock` registers, so `bv.ef(id)` can find them.

  Next suspects inside `y_0.run()`, which is where the dialog is pushed:
  the `fight.team0` / `fight.team1` properties it reads into `teArray` and then
  dereferences unconditionally (`teArray[0].hM(...)`) — if either is unset the
  method throws just before `apN.aDK().a(ajo_1.azb())` — and `bC`'s `OW` blob
  length, since `new OW(bytes)` may itself be strict about the 40-byte record.

---

## Fixed

### B-142 - same-world teleports re-entered the whole instance

**Symptom (invisible to the player, expensive everywhere else).** Every `/TP` within a world
sent a full ENTER_INSTANCE. That made the client discard and re-fetch its fighter roster and
team presets (B-124), re-push interactive elements it already held (B-137), and left other
players' area-of-interest sets to be corrected by a full re-seed rather than incrementally.

**Root cause.** `Registry.UpdatePosition` only records coordinates - it does no AoI work - so
the re-enter was the only thing keeping observers consistent.

**Fix.** `teleportWithinWorld` uses **4510** (`ActorTeleports`), the frame retail has for
exactly this: move an actor with no walk animation, recentring the camera for the local
player. It reuses `ApplyMove`, which is agnostic about HOW the coach reached the new cell and
already computes the enter/leave diff - so a teleport is now an ordinary AoI update.
Cross-world teleports still use ENTER_INSTANCE: a different island genuinely is a different
map.

**Ordering is load-bearing.** A session that only just gained sight must receive ActorSpawn
BEFORE the 4510 naming the coach. The retail handler resolves the actor id and dereferences
the result with no null check, so the reverse order is a NullPointerException in someone
else's client - the same hazard as B-136. `TestTeleportSpawnsBeforeTelling` asserts the ORDER,
not merely that both frames arrive, and a mutation that inverts it is caught.

**Live-verified**: `/TP 45 -15` moved the coach, the camera followed, the server answered
`tp -> (45,-15,4)` with the altitude resolved from topology, and the duplicate-element error
that B-137 recorded no longer appears.

5 mutations caught: self not told (camera stays behind), viewers not told, coach not stood up,
z written as i32 (the frame must be exactly 18 bytes or the client drops it silently), and
teleport-before-spawn.

### B-141 - the statistics panel was never populated (2401)

**Shipped after correcting my own cost estimate**, which had kept this closed. I had recorded
2401 as "a Java-serialized object - matching their serializer byte-for-byte", and repeated that
as a days-of-work figure. Opening the parser took ten minutes and showed an ordinary typed map:

```
[i16 blobLen][i16 modelId][i64 ownerId][i16 count]
  count x { [i16 statId][i8 type][value] }     type: 1=i32(4B) 2=i64(8B) 3=float32(4B)
```

"Serialized" in the decompiled source described a MODEL LOOKUP (`arq_0.aa` reads a model id,
finds the model, hands it the buffer). I estimated from a type name instead of the code that
reads the bytes.

**The stat ids are exact, not inferred.** `PlayerStatisticsReport` is the one UNOBFUSCATED
class in the client, and its getters read the ids literally - `dJ() { return this.V((short)4); }`
is fights-won = 4. Full set: 1 playTime(i64), 2 fightTime(i64), 3 fights, 4 won, 5 lost,
6 unknown (`dN`, no bound UI property), 7 consecutive wins, 8 consecutive losses.

**modelId = 1 was verified against a live client, not guessed.** `arq_0.aa` refuses an unknown
model by name, so the value is directly testable: injected 0, 2 and 3 were each refused
("le modele n'est pas reconnu : modelId=N") while 1 was accepted silently. A full five-entry
report at modelId 1 then decoded with no error, and now arrives on login the same way.

**The map is sparse on purpose.** Play time and total fight time are not measured by this
server; sending 0 would be indistinguishable from "you have played zero seconds", so they are
omitted and the client reads its own default. A test asserts they stay out.

**A tautological test, caught by mutation.** The first version compared the encoded modelId
against `statsReportModelID` - the same constant it came from - so changing the constant
changed both sides and the mutation survived. It now compares against the literal 1, with the
live experiment recorded next to it as the way to re-derive it. That is the field where being
wrong costs the ENTIRE report rather than one number. 5 mutations caught after the fix.

### B-140 - unknown slash-commands answered with invented English

**Symptom.** Mistyping a command produced *"unknown command: ZZZZNOTACOMMAND"* - a string this
server made up, in English, shown verbatim inside a German client.

**Fix.** Reply with **3206** (`error.chat.malformedCommand`), which retail already has and
which was already wired for the bare-`/` case. Live-verified: the German client now renders
*"Ungultiger Befehl"*.

The verb still goes to the server log. An admin who mistypes `/ANNONCE` wants to know which
word failed, and the client frame carries no payload to tell them - so the information moves
to where it is useful rather than being deleted.

**Same class as two earlier fixes**, and worth stating as a rule: 3210 replaced an invented
English permission error, 3214 replaced a self-whisper echo. Any time this server authors
player-facing prose, it is almost certainly re-inventing a frame the client already has
translated into every language it ships with. The remaining `gmFeedback` strings (usage lines,
command results) are admin-only and have no retail equivalent, so they stay.

Tests: `TestUnknownCommandUsesTranslatedFrame` and `TestUnknownCommandSendsNoInventedText` -
the second asserts no server-authored English is sent at all, since a frame AND a text line
would be worse than either alone. 1 mutation caught.

### Live validation of B-139 (sitting)

`/sit` typed in the retail client produces no error reply (it previously answered *"unknown
command: SIT"*) and the 4601 is CONSUMED - no `[DEFAUT DE CONCEPTION] ... non traite` warning,
which is how the client reports a frame no active screen handled (see the 6029 note in B-132).

The sit animation itself could not be judged: this client instance cannot load
`animations.jar` (`AnimCommunes.anm` FileNotFoundException), so no player sprite renders at
all. Wire and handler are confirmed; the visual is not, and that is an environment limit
rather than an open question about the code.

### B-139 - sitting implemented (/sit, /stand, stand-on-move)

**Decided by StarLoco after a live experiment.** The open question was whether the client
sits a coach on its own. It does not: typing `/sit` forwards it to the server exactly like
any other slash-line - the retail client showed no local reaction and our own handler replied
*"unknown command: SIT"*, identical to a control `/zzzznotacommand`. So a coach can ONLY ever
appear seated because the server said so.

**Two mechanisms, both required.**
  - The actor blob's `dBg` byte (flag 0x40), read on spawn: `no_2.g` plays `AnimAssis-Debut`
    when an actor arrives with it set. This covers *"was already sitting when you got there"*.
    We previously wrote a hardcoded 0 here.
  - **4601**, which toggles it for coaches already on screen. This covers *"sat down while you
    were watching"*.

**Behaviour.** `/sit` and `/stand` are available to every player - they are handled BEFORE the
admin gate, via an explicit allow list so no admin verb can slip through that door. Walking
stands the coach up: without it a coach would slide across the ground in a sitting pose on
every client that has it spawned. Sitting while already seated emits nothing, or the client
would visibly re-seat itself on each repeat.

Addressed by AoI membership (`ViewersOf`), not proximity - 4601 makes the client resolve each
id against its spawned actors, and an unknown id is the case that NPEs a retail handler
(B-136).

**A mutation that escaped first time.** Swapping the sitting/standing lists still produces a
well-formed 4601 - it just stands the coach up instead of seating it. The original wire test
called `buildSitStand` directly, so it could not see the swap, and the broadcast test only
asserted that *a* frame arrived. Both tests now assert WHICH list the id is in, from both
sides. 4 mutations caught after the fix.

### B-138 - fighters never reacted to critical hits

**Not a bug so much as an absent feature, implemented to an explicit product decision.**

The client can pop an "ouch !" speech bubble over a fighter (4902, `of_1` -> a 25-second
`interactiveBubbleDialog`). Nothing in the client says WHEN, so the trigger is server policy.

**Decision (StarLoco): a fighter says ouch when it takes a CRITICAL hit - the fighter that
RECEIVES the damage, not the attacker.**

The wire agrees with that reading on its own: 4902 carries a single fighter id, so it cannot
express "attacker hit target" even if we wanted it to. Whatever it names is the fighter the
bubble appears over.

**Implementation.** Both halves of the rule are enforced: the cast must be critical AND the
fighter must actually lose HP. A critical debuff, a miss, or a fully absorbed hit produces no
bubble; ordinary damage produces none either.

Rather than thread a "was crit" flag through every effect handler - which would still miss
damage applied indirectly via rebound, transfer or collision - the fight snapshots HP before a
critical cast and compares after. That catches every path damage can arrive by and cannot
drift out of sync with the damage code, which is the failure mode a threaded flag invites.

Hooked at all three places a crit is rolled: spell cast, close combat, and fighter-card use.

Tests: `TestOuchOnlyForFightersThatLostHP` (a bystander at full HP must stay silent),
`TestOuchNotSentForZeroDamageCrit`, `TestOuchNotSentForHealing` (the comparison is strictly
"lost HP", not "changed HP"). 3 mutations caught, including the healing-direction one.

### B-136 - emotes could crash a nearby player's message handler (found live)

**Symptom.** None in unit or e2e tests - all four emote tests passed. Found only by injecting
4700 into the retail client and reading its log.

**What the client does.** `no_2` case 4700 resolves the actor with `bd_1.Is().bb(id)` and
dereferences the result **with no null check**. An id the client has not spawned throws
NullPointerException and the whole message is dropped:

```
ERROR Exception levee lors du traitement d'un message : azT  NO.a(SourceFile:193)
java.lang.NullPointerException
WARN  Message (azT) non traite, de type 4700
```

(4510 by contrast logs *"Impossible de teleporter le personnage ... car il n'existe pas"* -
so the politeness is per-handler, not a client-wide guarantee.)

**The bug.** `handleEmote` broadcast with `World.SessionsNear` - raw proximity. AoI membership
is seeded in `EnterAoI` and is **not** maintained as coaches move, so "standing nearby" and
"has this coach spawned" are different sets. A neighbour in the first set but not the second
would take the NPE.

**Fix.** New `Registry.ViewersOf(coachID)` returns sessions whose AoI known-set contains the
coach (the same predicate `LeaveAoI` uses, without mutating). `handleEmote` uses it.

**The rule this establishes.** Any frame that makes the client look an actor up by id must be
addressed by AoI membership, not proximity. Proximity is only safe for frames that carry
everything they need - vicinity chat is text, which is why it has been correct all along.

Tests: `TestEmoteNotSentToCoachesWhoCannotSeeIt` puts a coach in proximity but NOT in the
known-set - the exact divergence - and asserts both fixture conditions so it cannot pass for
the wrong reason. Reverting to `SessionsNear` fails the suite.

**Process note.** This is the first bug this session that unit and e2e tests could not have
found, and it took ~6 tool calls against the live client to surface. AGENTS.md is right that
a live run is the final step, not a formality.

### B-135 - /resetPosition did nothing (players could not unstick themselves)

**Symptom.** The client's `/resetPosition` console command (4514) had no handler, so a player
wedged in geometry had no recourse but to ask an admin for a `/TP`.

**Fix.** `handleResetPosition` moves the coach to its current world's primary Zaap through
`sendEnterOverworld` - the same path Zaap travel already uses. A teleporter is by definition
somewhere the coach can walk out of, which is exactly what an unstick needs. Refused during
a fight so it cannot double as an escape hatch.

**Why not ActorTeleports (4510), which is the "right" frame.** 4510 moves an actor with no
walk animation in 18 bytes, and would be much cheaper than a full instance re-enter. It is
blocked on something structural: our overworld AoI membership is only ever computed in
`EnterAoI` (instance enter, fight exit) - `Registry.UpdatePosition` merely records
coordinates. A 4510 teleport would therefore move the coach visually while leaving every
AoI known-set stale, making it visible to players it is nowhere near and invisible to those
it landed among. Recorded on the 4510 row as a precondition rather than a to-do.

**A mutation that survived, and why it is not a test gap.** Removing the explicit
`s.Coach.Pos* = ...` assignment changes nothing observable, because
`Registry.UpdatePosition` mutates the *same* `*domain.Coach` the session holds - the registry
stores the pointer, not a copy. The assignment is only load-bearing when the coach is absent
from the registry. Genuinely equivalent under any fixture where the coach is online, so it
is documented rather than papered over with a contrived test.

**A mutation that did not survive, after a fix.** "Fall back to the start world" initially
passed, because the first test put the coach on the start world - both branches were
identical. `TestResetPositionStaysOnCurrentWorld` uses world 26 and asserts the two zaaps
differ before trusting the result. Without it, a start-world fallback would have looked
correct for everyone on world 25 while silently evicting everyone else.

Tests: `TestResetPositionMovesCoachToAZaap`, `TestResetPositionRefusedInFight` (with a
fixture check that a fight is really registered), `TestResetPositionStaysOnCurrentWorld`.

### B-134 - emotes did nothing

**Symptom.** Using an emote had no effect: no animation for the player, nothing for anyone
watching. The feature was simply absent - 4701 had no handler and 4700 was never sent.

**Fix.** `handleEmote` (4701) relays the emote to the sender's AoI as 4700.

**Two things that are easy to get wrong here.**

*The sender must be echoed.* `avv_0.playEmote` only updates the actor's facing direction
locally and then sends 4701 - the animation itself is played exclusively by the 4700 handler
(`no_2` -> `mT.aY(name)`). Excluding the sender the way vicinity chat correctly does would
have left the emoting player as the only person who saw nothing. The mutation test for this
is the one that matters: the neighbour path can look perfect while the feature is useless.

*The client's animation name is not trustworthy.* 4701 carries both an emote id and the
animation name the client resolved. The table is hardcoded in the client enum `up_0`, so the
server knows it too and relays its OWN name for the id. Otherwise a modified client could
make every nearby client attempt an arbitrary animation string.

Ids are non-contiguous (57, 59, 60, 62, 63, 65-69); the gaps are real and unknown ids are
dropped rather than relayed.

Tests: `TestEmoteRelaysToNeighboursAndSelf` (with a fixture check that the two coaches are
genuinely within AoI), `TestEmoteUsesServerTableNotClientString`, `TestEmoteUnknownIdDropped`.
4 mutations caught, including "sender not echoed" and "trust the client string".

### B-133 - the friend and ignore lists had no upper bound

**Symptom.** A client could add friends or ignores without limit; nothing server-side ever
refused. Unbounded growth per coach, and every one of those rows is loaded at login.

**Root cause.** `socialEdit` went straight to `FirstOrCreate` with no count check.

**Fix.** `socialListFull` counts the coach's existing edges and refuses past
`maxSocialListEntries`, replying **3216** (`avs`).

**Why 3216 is the right frame, and what I had wrong first.** I originally planned 3216 for
"clan chat with no guild", reading its name (`OperationNotPermited`) as a generic permission
error. The i18n string says otherwise: *"Operation non permise.\nTa liste d'amis ou de
personnes ignorees est peut-etre **pleine**."* It is specifically the social-list-full
refusal. Reading the displayed STRING rather than the class name is what caught it - the
same check that has now corrected three opcodes this project (28617, 6029, 3216).

**On the constant.** `maxSocialListEntries = 100` is **server policy, not client-derived**.
The 2.70 client carries no max-friends constant - only the error to show when the server
refuses - so retail enforced this server-side, but the value it used is not recoverable.
Recorded alongside the other server-invented constants rather than presented as retail
behaviour.

Tests: `TestSocialListCapRefusesWithNotPermitted` (both lists), which asserts the list is
genuinely full before testing the refusal, and that re-adding an EXISTING entry stays a
no-op instead of erroring at the boundary; `TestSocialCapBelowLimitAllows` guards the other
direction. 3 mutations caught: cap never trips, duplicate counted as new, `>` for `>=`.

### B-132 - a 2v2 partner could disconnect without the other half being told

**Symptom.** During 2v2 team formation, if one member dropped, the other was left in the
fighter picker waiting for a coach who was already gone. The pairing also stayed bound
server-side, so the survivor could not form a new one.

**Root cause.** `Session.onClose` notifies every other counterparty it has - the matchmaking
opponent, a pending direct challenge, an in-progress exchange - but the 2v2 team-up was
simply absent from that list.

**Fix.** `Deps.releaseTeamUpAndNotify` breaks the pairing and sends **6029** (`OJ`) to the
survivor. One byte: `dx_2` shows *"error.teamManagement.coachDisconnected"* regardless of
the value, so the opcode is the message.

Extracted as a method rather than written inline, because `onClose` cannot be driven from a
unit test - it dereferences `s.Account`, which a synthetic session does not have. Testing
the helper directly also keeps the teardown readable.

**Fully validated with TWO real clients.** Chrono invited ExBot, ExBot accepted, then ExBot's
client was killed. The server logged `2v2 partner gone leaver=2 notified=1` and Chrono's client
displayed a modal reading *"Anderung abgebrochen: euer Mitspieler hat sich soeben ausgeloggt!"*
- `error.teamManagement.coachDisconnected`, translated, with an OK button. End to end, exactly
the scenario this fix exists for.

That also resolved the caveat below rather than contradicting it. Forming a duo OPENS the 2v2
team panel automatically, so the frame IS active precisely when a partner can drop - which is
why the earlier injection (no duo, panel closed) went unconsumed while the real sequence works.
The bound claim was correct and the bound turns out never to bite in practice.

**Earlier refinement (validated by injecting 6029).** The retail client decodes 6029 into
`OJ` but only CONSUMES it while the team-management frame is active. Injected while the
player was standing in the overworld, the client logged:

```
WARN [DEFAUT DE CONCEPTION] Message (OJ) non traite, de type 6029, les frames ont toutes retourne true
```

i.e. every registered frame declined it and the message was dropped with no effect.

That is not a defect in this fix - the scenario 6029 exists for is precisely "the survivor is
sitting in the fighter picker", where the frame IS active. But it bounds the claim: a partner
who drops while the survivor has the team panel CLOSED is not notified, because the client
has nowhere to put the message. There is no retail frame that would tell them either, so this
is a client limitation rather than something the server can route around. Worth knowing before
anyone reports "I didn't get told" and it gets chased as a server bug.
Tests: `TestPartnerDisconnectNotifiesTheOtherHalf`, which asserts the pairing is bound
BEFORE acting (otherwise it would pass whether or not the notification happened) and that
the survivor is unpaired afterwards. 2 mutations caught: never notifying, never releasing.

### B-131 - a duplicate team-preset name saved silently

**Symptom.** Saving a preset under a name the coach already used succeeded, leaving two
presets listed identically in the team panel with no way to tell them apart.

**Root cause.** The save handler upserted whatever it decoded. Retail refuses this: `dx_2`
case 6020 has a dedicated status **25** mapped to *"error.teamManagement.teamNameExist"*,
separate from the generic *"error.teamManagement.teamPresetSave"* it shows for any other
non-zero status. We never sent 6020 at all, so neither error could ever appear.

**Fix.** Refuse the save and reply 6020 with status 25 when another preset of the same coach
already has that name (case-insensitive; renaming a preset to its own current name is not a
clash). The error frame is exactly ONE byte - `aic_0` reads the preset only inside
`if (aV == 0)`, so appending anything would leave unread bytes on a message the client
considers complete.

Tests: `TestDuplicateTeamNameIsRefused` (status, frame length, and that nothing was written)
and `TestDistinctTeamNameStillSaves`. 4 mutations caught, including a wrong status code and
an over-long error frame.

**Test-harness note.** Building a valid 6021 payload requires the 2v2 tail: after the
fighter list there is a `[u8 coachCount]` + entries block, and omitting the count even when
empty makes `decodeTeamPreset` fail as a truncated payload - the handler returns the error
and the connection drops, which surfaces in a test as a bare `EOF`.

### B-130 - a deleted team preset stayed on screen until relog

**Symptom.** Deleting a team preset removed it from the database, and it kept appearing in
the client's team list for the rest of the session.

**Root cause.** The handler deleted the row and re-sent the whole preset list (6030),
assuming the client would rebuild from it. It does not. `dx_2` case 6030 calls
`bs_0.IF().IG()`, which is not a clear: it removes only the presets where `afK()` is false
(`bMK.size() > 1`, i.e. the DUO ones) and KEEPS the normal ones, then merges the payload
into a map keyed by preset id. A deleted preset is simply absent from that payload, so
nothing ever removes it.

**Fix.** Send **6022** (`agH`) after a successful delete: `[i8 status]` plus `[i16 teamId]`
only when status is 0, because `agH` reads the id inside `if (aV == 0)`. That is what calls
`bs_0.IF().as(id)` client-side.

**Found by reading, not by testing.** The delete path had tests and they passed - they
asserted the row was gone from the store, which was true and beside the point. What exposed
it was working through the `dx_2` family opcode by opcode and asking what each reply
actually does to the client's state.

Tests: `TestDeletedTeamPresetIsAcknowledged`, mutation-checked against never acking, acking
the wrong id, and a non-zero status (which makes the client read no id at all).

### B-129 - the e2e suite sits too close to go test's 10m default on CI

**Symptom.** `test/e2e` intermittently hit `panic: test timed out after 10m0s` on
`ubuntu-latest`, with `TestPlacementRejectsIllegalCellsAndPhases` reported as the running
test. It failed the release job twice, so **v0.5.0 was tagged and published with no
binaries** - GoReleaser runs the suite and never got to build.

**Not what it looked like.** The obvious readings were both wrong. It is not CPU
starvation: under `docker --cpus=2`, matching the runner, that test passes in 17s. It is
not an infinite hang either - one full CI run completed it in 6m49s. What actually happens
is that CI runs **every package concurrently** (`go test $all_pkgs`), so the e2e fights -
which drive real sockets and real clocks - contend with the rest of the suite and the
package total lands close enough to 10m that ordinary variance decides the outcome.

Two greens in between were misleading and worth flagging: docs-only and changelog-only
commits finished in ~3m because Go served **cached** test results, so they proved nothing
about the flake.

**Mitigation, not a fix.** `-timeout 25m` on every CI and release `go test` invocation.
That stops variance from failing releases; it does not make the suite faster, and if a real
deadlock is ever introduced it now takes 25m to surface instead of 10m. The underlying
work - the e2e suite is slow because it waits on wall-clock fight phases - is still open.

### B-126 - two e2e tests raced the fight phase, red on Linux CI only

**Symptom.** After 132 commits went out, CI failed on `ubuntu-latest` while `windows-latest`
passed. `TestPlacementMove` and `TestPlacementRejectsIllegalCellsAndPhases` reported
*"no MoveToFreePlacement (8022) for a legal placement of our own fighter"*, burning 82s and
242s, and the e2e package then blew its 10-minute timeout.

**Root cause.** `readyGate` sends the two READY frames and drains for a fixed 250ms; the
advance to PLACEMENT happens on the fight actor afterwards. An 8021 sent straight after can
therefore arrive while the fight is still in PRESENTATION, where the placement guard
(87831bb) correctly refuses it. The guard was right; the tests were racing it. On Windows
the fixed drain happened to be long enough; on a 2-core runner it was not.

**Diagnosis worth keeping.** "Linux CI is slower" was the obvious reading and it was wrong.
Timing the suite under `docker golang:1.26` showed every other e2e test within noise of
Windows - `TestLoginToWorld` 0.15s vs 0.09s, `TestFullFightToVictory` 1.91s vs 1.80s - and
only the placement tests blown out at 14.6s vs 2.1s. That ruled out the environment and
pointed at two specific tests. Reproducing on the failing platform locally is what made it
diagnosable at all.

**Fix.** `enterPlacement` waits for **8020 StartPlacement**, which `advanceToPlacement`
broadcasts, so the tests synchronise on the event instead of on a guess. Faster too:
`TestPlacementMove` on Linux went 14.60s -> 1.28s.

### B-127 - a 3s harness timeout flaked on a loaded CI runner

**Symptom.** `TestChatMarkupIsStrippedOnTheWire` failed on Windows CI with
*"create coach: read tcp 127.0.0.1:...: i/o timeout"* - a test unrelated to any recent work,
passing locally and on the two previous runs.

**Root cause.** `testclient.defaultTimeout` was 3s for every harness wait, shared by 192
call sites. Fine on a developer machine; not on a contended runner, where the e2e package
took 198s against 131s locally. Any of those call sites could have been the one to lose.

**Fix.** Raised to 10s. This is a ceiling on FAILURE, not a delay on success - `WaitFor`
returns the moment the frame arrives, and the Windows suite measures 129s before and after.
Checked first that nothing asserts on the timeout EXPIRING: the tests that assert a frame is
absent pass their own short timeout explicitly.

Raised the shared default rather than special-casing the one test that happened to flake,
since that would have left the same trap for the next person.

### B-127 - the website's own Home link was a dead end once you signed in

**Symptom.** After signing in, neither the "Home" nav link nor the header logo
worked: both went straight back to /account, so the landing page could not be
reached again without signing out.

**Root cause.** `handleIndex` redirected any request carrying a session to
/account, commented "a signed-in visitor wants their account, not the marketing
page". True the moment you sign in - and the login handler already redirects
there itself - but wrong as a rule for `/`, which is exactly what the site's own
logo and Home link point at.

**Fix.** `/` renders the landing page for everybody; its call to action becomes
"My account" when signed in. `TestSignedInVisitorSkipsLanding` asserted the old
behaviour and is now `TestSignedInVisitorCanStillReachLanding`, joined by
`TestSigningInLandsOnTheAccountPage` so the behaviour the redirect was really
for stays pinned.

**Also removed in the same pass:** every "point your client at `<host>:<port>`"
line (landing page, account page, /status, footer). The download ships already
configured for this server, so printing an address only invited people to
mistype one. `TestPublicPagesDoNotAskPlayersForAnAddress` keeps it gone.

### B-126 - the sign-up and sign-in limits became ONE server-wide bucket behind a proxy

**Symptom.** On a server whose portal sits behind a reverse proxy (here nginx-less:
Cloudflare Tunnel -> the portal), the eleventh account created in any hour was refused
for **everybody**, and likewise the twenty-first sign-in attempt in fifteen minutes. The
limits are meant to be per visitor; they had become global. Found while deploying, before
launch, rather than by a room full of players failing to register.

**Root cause.** `clientIP` keys both limiters on `r.RemoteAddr` and deliberately ignores
`X-Forwarded-For` - correctly, for a directly-reachable portal, since anyone could
otherwise forge the header and mint a fresh allowance per request. But behind a proxy
every visitor arrives as the proxy, so `newLimiter(10, time.Hour)` and
`newLimiter(20, 15*time.Minute)` collapse onto a single key.

This cannot be dodged by configuration: with Cloudflare in front, the real client address
only ever exists in a header, so the portal is either told or blind.

**Fix.** `web.trusted_proxies` (IPs or CIDRs), **empty by default** so no existing
deployment changes behaviour. When - and only when - a request genuinely arrives from a
listed peer, the client is taken as the right-most `X-Forwarded-For` entry that is not
itself a trusted proxy; hops to its right were appended by infrastructure we control,
everything to its left is caller-supplied and ignored. A malformed hop stops the walk
rather than being skipped over, so a forged entry cannot be reached past a bad one.
Unparseable config is rejected at startup, because a typo would silently reinstate the
shared bucket this exists to fix.

Tests: `TestClientIPTrustsOnlyConfiguredProxies` (unit, 7 cases - including that an
untrusted peer cannot forge an address, that a trusted proxy IS believed, chain
resolution, and CIDR form) and `TestParseTrustedProxiesRejectsGarbage`. Verified live:
the production server logs `web: trusting forwarded client addresses from reverse
proxies proxies=[...]` at startup.

### B-125 - coach creation disconnected the player outright on postgres

**Symptom.** On a PostgreSQL server, confirming a new coach's name dropped the connection
instantly, every time. Nobody could get past character creation; SQLite was unaffected,
so it did not reproduce in development at all. Server log:

```
dispatch error opcode=2049 err="ERROR: collation \"nocase\" for encoding \"UTF8\"
does not exist (SQLSTATE 42704)"
```

**Root cause.** `CoachRepo.GetByName` and `CoachRepo.Create` both filtered with
`name = ? COLLATE NOCASE`. `NOCASE` is a **SQLite-only** collation - postgres has no such
thing and errors rather than ignoring it. Creation runs its case-insensitive uniqueness
check first, so it threw before the coach row was ever written (the transaction rolled
back cleanly, which is why no half-made coaches were left behind).

The knowledge was already in the codebase and simply never reached this file:
`account_admin.go` carries the comment *"LOWER() on both sides rather than COLLATE
NOCASE: the latter is SQLite-only and this has to work on postgres and mysql too."*

**Why the suite did not catch it.** The store tests run on SQLite, where the statement is
perfectly valid. The full suite - including e2e - passed green while coach creation was
broken for every postgres and mysql operator, which is exactly who
`deploy/docker-compose.postgres.yml` invites. A green suite here does **not** prove the
server works on the database it will be deployed on.

**Fix.** `LOWER(name) = LOWER(?)` at both sites. Plus a guard that does not depend on
which database the tests use: `TestNoSQLiteOnlySQLInStringLiterals` parses the store
package and fails if SQLite-only SQL (`COLLATE NOCASE`, `AUTOINCREMENT`,
`INSERT OR REPLACE`, `IFNULL(`, `strftime(`, ...) appears in a **string literal** -
comments are exempt, so entries like this one can still name the constructs. The
`PRAGMA`s in `store.go` are untouched: they are already guarded by `if isSQLite`.

Tests: `unit` (the guard, mutation-checked - planting the bug back fails on both lines
with file/line, removing it passes) and `live` - a real retail client created a coach
against the production postgres server after the fix.

### B-124 - the team panel emptied after any teleport, Zaap trip or GM /WORLD

**Symptom.** After arriving anywhere - a Zaap, a GM `/TP` or `/WORLD` - the team panel
showed six empty "Recruter" slots and a budget of 0, exactly as if the team had been
deleted. Relogging brought it back. Found while trying to start a tournament fight: the
roster was present right after login and gone after a single `/WORLD`.

**Root cause.** The client throws away the fighter roster and the saved team presets on
**every** ENTER_INSTANCE (4600), the same way it clears its element manager, and never
asks for them again. `sendEnterOverworld` re-sent the elements (which
`resetSpawnedElements` and its comment already document) but not the roster or the
presets - those were pushed only once, during login.

So every path through `sendEnterOverworld` was affected: Zaap travel, `/TP`, `/WORLD`,
and returning from a fight. The post-fight case was accidentally covered, because the
end-of-fight code pushes a fresh roster of its own for other reasons.

**Fix.** `sendEnterOverworld` re-pushes both, with the same reasoning as the element
reset: the client discards them on every 4600, so they must go out on every entry rather
than only on a world change. Failures are logged, not returned - arriving with a stale
team panel beats failing a teleport half-way through, after the client has already been
told to render the destination.

Tests: `TestRosterSurvivesAWorldChange` (e2e, drives a real `/WORLD` over a socket and
requires both 6006 and the preset list to follow). Verified live: roster intact after a
teleport that emptied it before the fix.

**The second cause turned out NOT to be a bug.** After the totem visit the panel still
looked empty with this fix in place, but the giveaway was the budget: it read 6600, not 0,
so the team was loaded and only the portraits were missing. Switching tab away and back
(Evolution → Tournois) repaints them, and the tournament fight then runs normally.

So that half is a client-side repaint quirk with no server involvement, and needs no fix -
only a note for anyone driving the client: **after opening the team panel, switch tabs
once before trusting what the roster shows.** The earlier guess that `agz_1` →
`onlyTabEnabledId` cleared the roster was wrong twice over - wrong for the teleport (that
was this bug) and wrong for the totem (nothing was cleared at all).

### B-125 - an unopposed tournament entrant waited in the overlay forever

**Symptom.** A coach that readied up for a tournament fixture nobody could ever contest -
the common case once byes exist, since a short draw leaves whole halves empty - sat in
`tournamentsSearchStatusDialog` for the rest of the session. Cancel was the only way out,
and it gave up a tournament the coach had in fact already won.

**Root cause.** `handleTournamentSearchRequest` queued every accepted entrant and waited
for a pairing. Nothing ever closes that overlay from the server side except **28648**
(`df_1`), which was unimplemented: `zN` case 28648 dismisses the dialog on its winner
branch, and there is no timeout.

**Fix.** Send 28648 with forfeit=0 - the client's *"the other player was not searching for
an opponent while you were, so you are declared winner by forfeit"* - and award the prize,
when the byes have already carried the coach to the root.

**The gate is the subtle part.** This is allowed only once registration is CLOSED. Byes
are derived from the current entrant list, so while registration is open an empty half of
the draw means only "nobody has entered there *yet*"; a lone early entrant would otherwise
be handed the tournament, and its prize, the instant it pressed Combattre. Retail ties
forfeits to a search *period* closing for the same reason.

That error was caught by an existing test (`TestTournamentReadyAcceptsAndWaits`) going red
on the first attempt, which is what it was written for.

Tests: `TestUnopposedTournamentEntrantIsDeclaredWinner` (closed, alone -> 28648 forfeit=0),
`TestLoneEntrantWaitsWhileRegistrationIsOpen` (open, alone -> no 28648) and
`TestClosedTournamentWithAnOpponentStillWaits` (closed, opponent seeded -> no 28648). The
last exists because with a single entrant "the bracket says I won" and "always true" are
indistinguishable - the mutation survived until a two-entrant case was added.

### B-122 - an under-filled tournament could never be won

**Symptom.** A tournament with fewer than 16 entrants stalled: every entrant played
until it ran out of opponents and the winner slot was never filled, so the tournament
never ended and its prize (B-123) was never paid. With four entrants the survivor
stopped at slot 4. Since a 16-entrant tournament is the exception rather than the rule,
this meant most tournaments simply never finished.

**Root cause.** The client's bracket is a fixed 16-entrant binary heap
(`ah_1.getFieldValue` hard-codes the slot ranges), and the server seeds only the
entrants it has. `RecordMatchResult` advances the winner of slots 2i/2i+1, so a coach
whose sibling slot was never seeded had no fixture to play and simply stopped. There
were no **byes**.

**Fix.** `applyByes` walks unopposed coaches up the tree, deepest-first so a bye
cascades through several rounds in one pass.

The load-bearing detail is what "unopposed" means. It is NOT "the sibling slot is empty
right now" - that walks a coach straight past an opponent who has not finished its own
match yet. It is "the sibling's entire **subtree** holds no entrant", i.e. nobody can
ever arrive there, which is decidable from the seeding alone and therefore gives the
same answer no matter when it is asked.

Byes are **derived**, never stored, so they always agree with the current entrant list:
a coach byed because its half of the draw was empty stops being byed the moment somebody
registers there, with no stored slot left behind to contradict the seeding.
`RecordMatchResult` consequently returns the slot the winner *ends up* in rather than
the parent of the pair, so a final decided by a bye still reads as a tournament win.

Tests: `TestShortDrawIsWonByBye`, `TestByeIsNotGivenWhileAnOpponentIsStillComing`, and
`TestFirstRoundRange`. That last one exists because behaviour tests provably *cannot*
catch an off-by-one in the subtree range: seeding fills the first round contiguously, so
a subtree contains an entrant exactly when its first leaf does, and a range that drops
its last leaf still answers correctly everywhere. The masking disappears the moment
seeding gains a gap, so the helper's contract is pinned on its own.

### B-123 - a tournament prize defined in the client data was never paid

**Symptom.** A tournament built on definition 11 or 18 defines a prize card, and
winning it granted nothing.

**Root cause.** The prize is `aub.aHi()`, bound to the GUI field `tournamentRewards`
and read by the client **straight out of its own data.bdat** - it is never sent over
the wire, so nothing on the wire could reveal the discrepancy.

**Correction to the original write-up.** This was first recorded as "the client
*advertises* a prize the server never paid", and that overstated it. `qr_0` does expose
the reward (`new wy_2(aub.aHi())`), and `tournamentsOfTheDay.xml` /
`tournamentListDialog.xml` do bind it into the "Récompenses" list - but the
`<itemRenderer>` there has only an `<isNull/>` branch drawing an empty
`CardRewardBackground`, with no renderer for an actual card. Checked live with a
tournament switched to definition 11: the strip stays empty whether or not a prize
exists. So the shipped GUI never displays it, and the panel is dead in the same way
B-046 found the ladder's reward panel to be.

That does not change the fix - the data defines a prize for that tournament and a win
should pay it, and the player does see the card arrive in their inventory - but the
justification is "the data defines it", not "the player was shown it".

Only 2 of the 22 shipped definitions name a prize (11 → card 26, a rank-5 card worth
14350; 18 → card 544). Both are free to enter, so both pass the web console's
"no entry ticket" filter and can be picked by an operator.

**Fix.** `Deps.awardTournamentPrize`, called from `advanceTournamentBracket` when the
winner reaches `bracketWinnerSlot`, grants the definition's `RewardCard` and pushes a
fresh inventory. Guarded like the challenge rewards against a definition naming a card
the game does not ship.

Note the sibling field `aub.qo()` = `tournamentInscriptionCard` is an entry **fee**,
not a reward: `aug.registerTournament` refuses to send the registration unless the coach
holds that card. That rule was already handled, by excluding fee-charging definitions
from the operator's list.

Tests: `tournament_prize_test.go` (granted; the definition's own card, not a fixed one;
nothing when no prize is advertised - including with no card catalogue loaded, where the
`RewardCard == 0` check is the only guard; and only at the winner slot, not per round).

**Live-verified, end to end.** Two retail clients, a tournament switched to definition 11:

```
tournament match paired  tournament=2600002 a=Chrono b=ExBot
fight started            id=1 arena=74
tournament bracket advanced  tournament=2600002 winner=1 slot=1
tournament prize awarded     coach=1 tournament=2600002 def=11 card=26
```

and `coach_cards` really holds template 26 qty 1 afterwards. The registration also
survived a full server restart (`tournament registrations restored count=2`, re-announced
on the next totem visit).

Two things worth reading off that trace. `slot=1` from a single match is B-122's byes
working: with two entrants seeded at 16/17 the one match IS the final, and the winner
rides the empty half of the draw to the root. And only `slot=8` is persisted - slots 4, 2
and 1 are derived on read, which is the "byes are derived, never stored" rule holding in
practice rather than only in the unit tests.

### B-121 - presence notifications reached only friends with "notify" on

**Symptom.** A 2v2 invitation succeeded or failed depending on **who logged in first**.
Sparrer → Peer was refused with *"Le coach a refusé la création, ou est indisponible."*
while Peer → Sparrer worked, with identical data. Found by driving four clients at once.

**Root cause.** `CoachRepo.WatchersAsFriend` filtered on `notify = true`, treating a TOAST
preference as a subscription. The client makes the distinction explicit (`om_0` case 3148):

    axa_03.ai(true);
    axa_03.c(dh_02.no());                 // presence AND the friend's coach id
    if (axa_03.aJM()) { ...show "X vient de se connecter"... }

The presence/id repair is unconditional; the flag gates only the message — and the client
already holds that flag, because we send it in the friend list (`adO`, see B-120). So the
filter did far more than silence a toast: a friend with notify off never learned the other
had come online, and never received its **coach id**.

That id is the whole problem. Per B-120 the friend LIST only carries an id for coaches who
were already online when it was built (offline friends are `-1`, which is the client's own
presence test). So the only way to learn a *later* arrival's id is the 3148 we were
suppressing — and the 2v2 teammate picker sends `axa_0.getId()` as the invited coach.
Whoever logged in first held its partner at `-1` and invited nobody.

**Fix.** The query no longer filters on `notify`; the client decides whether to print.

**Verified:** `unit` (`TestWatchersAsFriendIgnoresNotifyFlag`, mutation-checked: restoring
the filter fails it) + `live` (four clients, both invitation directions now work).

Two test-quality notes, both mistakes made while writing it:
- the first fixture contained **no notify=false row at all**. `Notify: false` is the
  struct's zero value and the column is `gorm:"default:true"`, so GORM omitted the field
  and the database wrote `true`. The rows are now written through a map, and the test
  asserts the fixture really holds one notify=false row before relying on it.
- the first mutation run reported MISSED because the anchor matched the **test file**
  (alphabetically ahead of `repos.go`) rather than the repository. A mutation that edits
  the test instead of the code proves nothing — verify which file changed.

**Not a bug, retracted:** the "Evolution TESTER starts a PvE challenge" report was wrong.
26330's second field really is 99 for a challenge accept (`cj_0`, `pn_0`, `zs_1` all send
`fH(challengeId), bM(99)`); the team panel sends the real preset id and the Légendes tab
sends the 9999 pseudo-preset, which already falls back to the coach's own fighters. The
original observation was a mis-click on a challenge bubble, diagnosed without reading the
client's senders.

### B-120 - every friend had coach id 0 and read as permanently online

**Symptom.** Creating a 2v2 team always failed with *"Le coach a refusé la création, ou
est indisponible."* even though the chosen teammate was online, unignored, not fighting
and not already paired. Found by driving two retail clients at once: ExBot picked Chrono
from its friend list, pressed CRÉER, and the server refused.

**Root cause.** Not in the 2v2 code at all - in the **friend list (3144)**, which had been
wrong since it was written. `buildFriendList` labelled its last two fields
`[i8 online][i64 lastSeen]` and wrote the presence flag into the first and a constant `0`
into the second. The client's `om_0` case 3144 says otherwise:

    new axa_0(qm.adM, qm.name, qm.adP != -1L, qm.adP, qm.adO)

- **`adP` is the friend's COACH ID**, and it doubles as presence: `-1` means offline.
- **`adO` is the per-friend NOTIFY toggle** (`axa_0.aJM()` gates the "X vient de se
  connecter" toast), not presence.

So every friend arrived with **id 0**, and because `0 != -1`, every friend also read as
**online** regardless of the flag we sent. The id is not cosmetic: the 2v2 teammate picker
hands `axa_0.getId()` straight back as the invited coach in 6024, so the server received
`invited = 0` and refused - correctly, for the wrong reason. `coach_friends.Notify` had
existed in the schema all along with nothing writing it to the wire.

**Fix.** `adO` carries `CoachFriend.Notify`; `adP` carries the coach id when online and
`-1` when offline. An offline friend deliberately has no usable id, which is the client's
own rule.

**Verified:** `unit` (`TestFriendListCarriesCoachIdAndNotify`) + `live`. Live, with two
retail clients running simultaneously: ExBot created team "LesDeux" naming Chrono, the
server logged `2v2 invitation from=ExBot to=Chrono team=LesDeux`, Chrono's client rendered
*"ExBot te propose de faire équipe avec lui/elle."*, accepting produced
`2v2 team formed team=LesDeux inviter=2 invited=1`, and **both** clients opened the 2VS2
fighter picker on 6028.

3 mutations caught - but only after fixing the test. The first version used
online+notify-on and offline+notify-off, which **correlated the two fields being
separated**, so swapping one for the other passed. Decorrelating them (online+notify-OFF,
offline+notify-ON) made the mutation fail as it should. A test whose data correlates the
fields it is distinguishing proves nothing.

### B-119 - OPCODE-INVENTORY.md claimed coverage of two opcodes the client does not have, and called twenty implemented ones "gaps"

**Symptom.** No runtime symptom — which is exactly why it went unnoticed for so long.
This is a defect in the document the project uses to *decide what to build next*, and its
own header says "anything marked `-` is a gap". `STATUS.md` declared the guarding
invariant as "the H count must equal the `r.Register(protocol.` count — currently
82 = 82", to be checked by hand after adding a handler. Nobody did. It had drifted to
**82 vs 105**.

**Root cause.** Three separate failures, all from the same cause (a hand-maintained
cross-reference with no test):

1. **Twenty implemented opcodes were still marked `-`** — the whole guild family
   (501/509/511/517/519/553/555/557/2600), the sphere buy (23009), demon affiliation
   (5470), the evolution and tournament searches, and the S2C halves of guilds, exchange
   and achievements. Anyone planning from this document would have re-implemented work
   that was already done.
2. **Three registered handlers had no row at all** (503, 505, 515).
3. **Two rows described opcodes that do not exist.** 5106 and 5108 were marked `H`, with
   the note *"not in client CSV, server-defined from exchange RE"*. They are not
   server-defined; they are **not real**. No class in the decompiled client returns
   either id (`getId()` sweep over the whole `core` tree), and the server registers no
   handler for them. They appear to have been invented to fill a gap created by failure 4.

4. **The exchange family's directions were wrong.** The rows claimed 5109/5111 were S2C
   with the parenthetical *"CSV mislabels C2S; it is S2C"*. The CSV was right and the
   note was wrong. `ahJ` (5109) and `any` (5111) both extend **`so_0`**, whose decode
   method throws *"ne peut être décodé"* — a send-only message, i.e. C2S by construction.
   The pairing is settled the same way: `ua_2` (5105) and `wd_0` (5107) both extend
   **`pv_2`**, which serialises `[i64 exId][i32 cardId][i16 qty]` — the add/remove pair —
   while 5109/5111 write a bare `[i64 exId]` — the ready/cancel pair. The CSV's
   human-readable *names* for this family are shifted by one slot; its *directions* and
   its handler grouping are correct. The Go constants in `opcodes.go` already matched the
   client exactly, so no code was wrong — only the document.

**Fix.** Corrected all of the above, and then made the invariant machine-checked instead
of hand-counted: `internal/game/opcode_inventory_test.go` reads the router's real handler
map (a zero `Deps` is enough — registration only takes function references) and asserts
every registered opcode is marked `H`; asserts the reverse, that no row claims an `H` we
do not serve (the direction that hides dropped packets behind documented coverage); and
scans the `EncodeS2C` call sites in `game` + `handshake` for the S2C side. It fails if the
table format ever changes such that it would parse zero rows, so it cannot pass
vacuously. Counts are now **H = 105**, **E = 115**.

**Verified:** `unit` (`TestOpcodeInventoryMarksEveryRegisteredHandler`,
`TestOpcodeInventoryClaimsNoHandlerWeDoNotHave`, `TestOpcodeInventoryMarksEveryEmittedFrame`)
+ `audit` (the `getId()` sweep proving 5106/5108 do not exist, and the `so_0`/`pv_2`
inheritance proving the exchange directions). 4 mutations caught: a real handler demoted
to `-`, a phantom `H` row, an emitted frame demoted to `-`, and the table format
destroyed.

**Lesson recorded in `STATUS.md`:** *a hand-counted invariant is not an invariant.* The
project already had the right pattern for this in `internal/config/config_template_test.go`,
which fails when a config field has no key in the shipped template; the opcode inventory
simply never got the same treatment.

### B-118 - the evolution tail's two "passive" lists are the Sphere Board's spells and equipment pools

**Symptom.** A Spell sphere bought in one session stopped existing in the next: the
fighter could cast it until it logged out, and then could not.

**Root cause.** The last two lists of the evolution tail were being written as
empty and documented as "passives, not modelled yet". They are not passives.
`ee_2` fills its own three lists straight from the blob -
`aRD = et_2.NE()` (the bought nodes), `aRE = et_2.NI()` and `aRF = et_2.NJ()` -
and then resolves `aRE` through the SPELL table (`je_1.Wa().el`) and `aRF` through
the equipment-pool table (`aca_0.aOq().F`, record type 251). They are the spells
and equipment pools a fighter's bought Sphere Board nodes unlocked.

The client adds each one locally at the instant of purchase (`ee_2.a`) and never
re-derives them, which is exactly why the bug survived a session: everything
worked until the fighter was next loaded from the wire.

**Fix.** Both lists are derived from the fighter's bought nodes and sent. The
node's effect ROWS are a separate matter - nothing carries a fighter's
characteristics on the wire, because the server is authoritative in a fight - so
those are re-derived at fight time through the same passive accumulator equipped
cards and wounds already use, after equipment and before conditions.

**Verified.** `live` (a fighter that bought "Esquive +1%" still shows Esquive 61%
after a full relog, and a fight starts clean with it) + `unit` (13 mutations,
including one that proved the fight path itself was untested and another that
caught the merged spell slice aliasing the persisted fighter).

### B-117 - the 24 clan islands served no elements, so no one could land on one

**Symptom.** With the island held, the card granted (B-116) and the destination
resolving correctly, a live teleport still went nowhere: `zaap use: destination
zaap missing card=859 world=88 instance=146`.

**Root cause.** `worldElements` had no entry for worlds 86-109 at all, so
`zaapAt(88, 146)` could not resolve and the handler refused. The table is
GENERATED by `cmd/genelements` from the client's env jars, and its `policyWorlds`
list deliberately omitted the islands as "unreachable content" - which was true
when it was written and stopped being true when clans landed.

**Fix.** Added worlds 86-109 to `policyWorlds` and regenerated. Two things this
surfaced that a hand-written table would have got wrong:

- every clan island also carries a **Fusion altar** of its own (6 -> 30 across the
  server), content that was simply not being served;
- the island Zaaps use orientation byte `03`, not the `01` of the world-23 Zaaps,
  so a payload synthesised from a "uniform" template would have been subtly wrong
  on almost all of them.

**Verified.** `live` (Chrono teleports to world 88, arrives at (48,77) alt 0, the
Zaap renders and the client registers element 146 at that cell), plus `unit`:
`TestEveryClanIslandHasAReachableZaap` walks the same `zaapAt` path the handler
does, `TestClanIslandZaapsMatchTheDocumentedTable` checks the served cells against
`docs/OVERWORLD-MAP.md`, and `TestClanIslandZaapAltitudesMatchTheTopology` checks
every island's arrival altitude against the shipped tplg - a wrong altitude does
not error, it silently leaves the coach unable to walk. 6 mutations caught.

### B-115 - `TestPhaseClockForceAdvances` was flaky: it polled for a 20ms transient

**Symptom.** The full `internal/game` package run failed intermittently with
`phase never reached Placement (stuck at Observation)`. It passed every time in
isolation, on the clean tree as well as the working one, so it was not caused by
the change being made when it appeared.

**Root cause.** A race in the test, not in the fight. The message is the tell: the
phase was already *past* the one being waited for. `waitPhase` polls `f.Phase()`
every 5ms while the test shortens every clock to 20ms, so each intermediate phase
exists for about four polls - and under the load of the whole package the polling
goroutine need not be scheduled inside that window at all. The test was asserting
on states too short-lived to observe reliably.

**Fix.** Wait only for the final phase (`PhaseAction`, 2s budget). Nothing is
lost: the phases are chained, each transition arming the next one's clock, so
arriving at Action is only possible by having passed through Placement and
Observation. Verified by mutation - breaking either intermediate `armClock`, or
refusing the first transition, still fails the test. 6/6 clean full-package runs
after the fix.

**Verified.** `unit` (mutation x3, stress x6).

### B-114 - a one-member clan could hold an island against the whole server

**Symptom.** A single coach could found a clan, offer a demon a handful of cards
and take that demon's island permanently - no one else could ever displace them
without out-giving them, and 23 of the 24 islands stayed unreachable.

**Root cause.** The activity rule was never implemented, because the client
mentions it exactly once and enforces nothing. Opening the CLAN tab below five
members pops `guild.notEnoughGuildMembersToBeActive` - *"Votre clan ne comporte
pas assez de membres pour etre actif. Recrutez encore [#1] personne{[>1]?s:} !"* -
computed as `5 - memberCount` in `uk_1.java:52`. That is the whole of the client's
involvement: a warning label. What "actif" *does* is the server's to decide, and
the only reading that gives the warning meaning is that an inactive clan does not
compete.

**Fix.** `GuildActiveMinMembers = 5`, applied as a subquery shared by
`DemonLadder` and (through it) `IslandOf`, so the ladder and the island allocation
cannot disagree - an inactive clan ranking first while the island went to the clan
below it would show a leader who does not hold the prize. Because the rule rides
in through the ladder, a clan that drops below the threshold loses its island the
moment the member leaves, with nothing having to watch for the departure. The
island Zaap card follows automatically (B-116).

**Verified.** `unit` (mutation x5: threshold, filter, HAVING, both packages).

### B-116 - the clan-island Zaap card was never granted to anybody

**Symptom.** The clan-island destination logic was unreachable. No coach could
ever teleport to a clan island, and no test noticed, because both halves were
individually correct.

**Root cause.** Card 859 is not in `starterZaapCards` and nothing else granted it,
while `handleZaapUse` gates every destination on `coachOwnsCard`. The gate could
therefore never pass.

**Fix.** Reconciled at login next to the existing starter-card grant: granted when
the coach's clan holds an island, and revoked when it does not. Revoked as well as
granted because an island changes hands - a card left behind would list a
destination in the Zaap dialog that silently does nothing when clicked. Being done
at login makes it idempotent and self-healing for clans that gained or lost an
island while a member was offline.

**Verified.** `unit` (mutation x5).

### B-111 - the fighter equipment slot is the item's TYPE, not a free index

The client's fighter item inventory is a fixed 5-slot `ArrayInventory` (`en_1`,
`ee_2.java:139`) and the position is **not** an index: each piece is built with
`vi_1.ap((byte)uh_0.getType())` (`eh_2.java:81`), so a fighter card's record
`Type` IS its slot type - weapon 1, pet 2, cloak 3, hat 4, dofus 5, at positions
0-4 - and `ne_2.a` refuses any item whose position is not its type's.

Two independent gates with two different messages, which is what made the first
attempt look complete when it was not: clamping the range removed every
`position en dehors des limites` and left 30 `impossible d'ajouter l'item`
behind. The ABSENCE of the first message beside the second was the clue.

Fixed at the source of truth rather than at each writer. `FighterRepo` takes an
injected `EquipSlotOf` (the store must not import game data) and normalises on
BOTH read paths, so every consumer - roster blob, fight blob, stat computation -
sees the same storable set the client will accept. The repair is read-only: the
rows on disk are untouched, and with no card table loaded the fighter comes back
exactly as stored, so a data-less dev server does not silently empty every
loadout.

Live: `impossible d'ajouter l'item` 40 -> 30 -> **0**. A full login-plus-fight run
now logs zero protocol errors.

**What the fighters were actually wearing before.** Worth spelling out, because
it is worse than "some equipment was dropped". The dev roster stored ten cards at
sequential slots 0-9; matched against each card's own type slot:

    stored order [122 95 125 121 103 129 102 156 158 128]  slots 0..9
    card type    [  5  2   4   5   3   3   3   3   2   4]
    canonical    [  4  1   3   4   2   2   2   2   1   3]  <- required position
    accepted?    [  n  Y   n   n   n   n   n   n   n   n]

Exactly ONE item - the pet, which happened to be stored at its own slot - was
ever accepted. The client had been rendering these fighters with a single piece
of gear while the server computed their stats from all ten. After the fix they
wear four (pet, cloak, hat, dofus; they own no weapon) and visibly change
appearance in the team panel.

**A/B'd, because the team-budget readout moved.** Disabling the injection put it
back to 5750/6000, so the change is definitely mine. It is not a regression: the
client computes that total from the equipment it is actually holding, so a roster
whose gear was being thrown away silently read as cheap. Now that the gear
arrives, this account's team reads 10000/6000 - over the cap the game's own help
text states ("ne jamais depasser 6000 points de budget"). That is **pre-existing
invalid data made visible**, not new breakage: those loadouts could never have
been assembled through the retail UI, which only ever offers five type-bound
slots. Practice fights still start and run clean.

**Provenance, narrowed and then closed off.** The ten rows are all genuine fighter
cards, so they are not the B-112 transposition; and `decodeLoadoutCards` has been
capped at 6 since the first commit, so 6011 cannot have written ten either. That
leaves exactly one writer: `buildFighter`, the fighter-CREATE path, which deduped
on the incoming slot and stopped there - no cap, no type check, the sender's
position taken on trust.

What sent such a blob is still unknown and may never be known (an older build, a
tool, a hand-made row). Rather than keep guessing, the hole itself is now shut:
`buildFighter` runs the same canonicalisation as the loadout path, and when no
card table is loaded it falls back to the type-independent clamp (one item per
position, positions inside the inventory) instead of passing the list through. A
data-less dev server can no longer persist a loadout the client would refuse.

Repairing or rebuilding the existing dev roster is still the maintainer's call -
the read-path normalisation already hides those rows from the client.

### B-113 - Nx was inverted, and round-card effects landed where the client cannot take them

Both halves of the original B-111 report, both fixed and measured live.

**Nx is turns ELAPSED.** `ZT.jt(int n2)` computes
`remaining = <the effect RECORD's effect_duration> - n2` (`ZT.java:135`), so the
duration comes from the DATA (resolved through part 0's generic effect id) and Nx
only offsets it - `ZT.akB()` is literally `jt(0)`. The server passed the full
duration, giving `remaining = duration - duration = 0`: every buff, state, aura,
damage-transfer and timed visual arrived already expired. The parameter is now
`elapsedTurns` and every fresh application sends 0.

**Round-card effects ran with no current fighter.** `jt()` anchors the expiry on
whose turn it is (`cn_0.JG()` -> `aGT.dh()`), and the client clears that anchor on
`NEW_TABLE_TURN`, restoring it only on the next `FIGHTER_TURN_BEGIN`. Anything
timed sent in between throws `IllegalStateException: currentFighter() sans
hasCurrentFighter()`. The action is caught (`akb_2.java:127-136`) and dropped,
which is worse than losing the buff: it stays registered on the fighter but is
never executed and can never expire.

The first diagnosis ("the equipment buffs applied at setup") was wrong - no
equipment buff is ever broadcast; equipment is folded into the fighter's maxima at
build time. It was `applyRoundEvent`, which meant it recurred EVERY round, not
just at fight start. `beginTableTurn` now only draws and announces the card;
`applyTableTurnEffects` resolves it, after `beginTurn`.

Measured on the live client, same practice fight before and after:

    currentFighter() sans hasCurrentFighter : ~200 -> 0
    [_FL_] ACTION FAILURE                   : ~200 -> 0
    generic effet inconnu                   :    n -> 0
    position en dehors des limites          :   40 -> 0

with the round card's effects still applied, so the reorder cost a frame and
nothing else.
### B-112 - 6011's two loadout blobs were swapped, so fighters had no spells

Found while fixing B-111's inventory overflow. `bp_1.encode()` writes
`Oh().cd()` and then `Oi().cd()`, and on a fighter those are `Oh() -> ajv_2 aTs`,
the 6-slot SPELL inventory serialised as a flat `[i32 spellId]` list, and
`Oi() -> en_1 aTr`, the 5-slot EQUIPMENT inventory serialised as
`[i16 slot][i32 cardId]` pairs (`gn_0.java:513,517`, `ee_2.java:137,139`).

The 6011 handler read them the other way round. Nothing ever failed to parse,
because a flat list and a slotted list happen to appear in exactly that order -
so the shapes lined up and only the MEANINGS were transposed: any spell the
player equipped would have been persisted as equipment, and any equipment as
spells.

**Correction to the first write-up of this entry.** I originally claimed this was
"why every fighter came out of the loadout screen with `spells=0 objects=<n>` and
could not cast anything". That does not hold, and the arithmetic says so:

- the old `decodeLoadoutCards` read blob 1 FLAT and assigned `Slot = len(out)`,
  so it would have stored whatever was in the SPELL blob - spell ids;
- the ids actually on those fighters (`122 95 125 121 103 ...`) are all genuine
  FIGHTER CARDS (types 2-5), not spells;
- and reading the slotted blob as flat would misalign every read
  (`[i16 pos][i32 id]` taken as `i32` yields `pos<<16|id_hi`, i.e. garbage),
  which is not what is stored either.

So the 10-object rosters did **not** come from this bug, and the dev account's
`spells=0` is simply "no spell was ever equipped" - its spell pool is empty. The
swap was real, and is proven from `bp_1.encode()` plus the fighter CREATE path
disagreeing with the update path, but the symptom I hung on it was somebody
else's. Provenance of those rows is still open (see B-111).

The fighter CREATE path (`fighter_codec.go`) always read the order correctly, so
the two paths had been contradicting each other.

Both decoders and both encoders were the wrong shape as a consequence
(`decodeLoadoutCards` was flat and invented sequential slots because it was
really parsing the slotless spell blob). All four are corrected, along with the
caps, which were also applied to the opposite inventory: spells 6 (`ajv_2`),
equipment 5 (`en_1`).

The two e2e tests that covered this had encoded the bug as a requirement - they
built a flat blob, called it "cards", and asserted the server stored it as cards,
which it dutifully did. Rewritten against the client's byte order. This is the
second time a green test has pinned the wrong behaviour (see
`TestWorldElementsSpawnedOnEntry`); the lesson repeats - a test written from the
same misreading as the code cannot catch it, only the client can.

Verified: unit (blob order, round-trip, caps, slot filtering), rewritten e2e,
5 mutations, and live - the client's inventory rejections during login went to 0.

**Live proof from the client's own bytes.** Opening a fighter's loadout and
pressing VALIDER makes the client send a real 6011. For a fighter holding four
equipment pieces and no spells the server now logs

    fighter loadout updated  fighter=3 cards=4 spells=0 budget=2200

Under the old read the SAME frame would have produced `cards=0 spells=4`, since
the empty flat spell blob became the cards and the four slotted items became the
spells. The two counts landing on the correct side is the discriminating result,
and it needed no fixture - the client supplied the bytes.

The budget is a second, independent check: the client's own loadout header showed
2200 before VALIDER was pressed, and the server recomputed 2200 from the same four
cards. Server and client now derive the same fighter value from the same
equipment.
### B-110 - every push/pull NPE'd the client, and no buff icon could ever appear: the 8120 blob was missing two parts

Two independent live bugs with one root cause: `buildRunningEffect` only ever
wrote blob parts 0/1/2. The client's running effects expose **six** (`xb_2.Kl`),
and two of the others are not optional.

**Part 3 (`aaa_0`/`hk_0`, 18B) - the displacement destination.** Push (37), pull
(38) and "est repoussé de sa cible" (153) move the fighter to the cell in this
part, verbatim (`na_2.java:57` `m(bzW)`). The client would normally compute that
cell itself in `aaH()`, but `aaH()` is only reachable from `a(xb_2)`, and the wire
path never calls it: `mv_0.ax():205` calls `Nu.akd()`, which clears `bWv`, which
makes `akf()` false, which is the gate on `a(xb_2)` at `xb_2.java:774`. The guard
that might have saved it (`rM`, `na_2.java:47`) is only cleared inside that same
uncalled method, so it stays `true` and execution falls straight through to
`this.bzW.equals(ry2)` on a null. **Proven live** by injecting the same push frame
twice through the dev endpoint:

    without part 3 -> Exception levée lors du traitement d'un message : amB
                      java.lang.NullPointerException
                      [DEFAUT DE CONCEPTION] Message (amB) non traité, de type 8120
    with part 3    -> (nothing)

So the client did not merely mis-animate the shove, it **threw and dropped the
whole effect**. 10 shipped rows are affected (7 push, 3 pull) - "Coup Sournois",
"Peur", "Flèche de Recul", "Attirance", "Vent Attirant", "Attirance Légère".

**Part 4 (`jf_2`, 12B) - the source spell**, `[i32 sourceType][i64 sourceId]`,
type 13 = Spell. This is the only way the client learns which spell produced an
effect, and its buff bar *requires* it: both providers walk the fighter's running
effects and `continue` on `mi() == null || mi().iP() != 13` (`ee_2.java:562` and
`:594`). Without it **no buff icon can ever appear on any fighter**, no matter how
correctly the buff is applied, ticked and reverted server-side. It is also
mandatory for action 140, which dereferences the source spell unconditionally.

Fix: `buildRunningEffect` takes optional parts and sorts them by index (the
decoder sizes each part from the *next* directory offset, so ascending order is
load-bearing). `applyPushPull` attaches the destination plus the blocking
fighter's id; the timed-effect call sites (buff, state, visual, damage transfer)
attach the source spell, which `resolveSpellEffects` records in `f.sourceSpellID`
around each cast - saved and restored, so a nested effect cannot inherit a stale
id, and non-spell effects (poison, special cells, traps) correctly send no part 4
at all.

Verified: unit (part layouts, ordering, omission-when-zero), call-site tests that
capture the actual broadcast frames (destination matches the server's own
`victim.Pos`, blocker id present/absent), and the live A/B above. Every assertion
mutation-checked, including by re-introducing the original bug.

### B-109 - interactive objects could not be used: one was drawn off its cell, and the rest was operator error

Chasing "the element highlights but nothing happens" to the end. Two separate
findings, and only one of them is a server bug.

**The server bug: an element drawn away from its cell.** The env blob is AUTHORING
data and its z is the sprite's decoration height, not the cell's walkable ground -
world 25's Zaap carries **30** where its cell's ground is **8**. The view is drawn
at that z, and the client's pick is CELL-based (`wp_2` -> `bd(cellX, cellY)`), so
the element rendered nowhere near the cell you can click. Measured A/B on the live
client: with the authored z the Zaap is **invisible and unusable**; with the ground
altitude it renders beside the coach and a right-click reaches the server. Exactly
**1 of 139** payloads needs this, but for that one the element simply was not there.

That rewrite has to locate the RU part by parsing the part table
(`u8 count, count x {u8 id, i32 offset}`, part data at `offset+1`), because its
position is payload-dependent: 138 payloads put it at byte 14 and one - world 23's
card master, instance 5 - puts it at 20. The first version of this fix assumed a
fixed 14 and would have written into the middle of that element's data.

**The rest was me holding it wrong.** The action is on **mouse button 3**, not
button 1. `wp_2` picks the button by option: `if (clW) { move=1; action=3 } else
{ move=3; action=1 }`, and in this client's state left-click is MOVE - which is why
every left-click walked the coach and nothing else. The game's own help text says so
outright: *"Apres avoir fait un clic droit sur un zaap, double clic sur la kard
representant ta destination !"*. Right-clicking a Zaap opens its dialog, and
double-clicking a destination card teleports:

```
element action  element=37  kind=zaap       action=0  coach=Chrono
zaap teleport   coach=Chrono card=202 world=23 zaap=35 cell="[-57 0]" alt=2
element action  element=103 kind=graveyard  action=0  coach=Chrono
```

**A theory I had to throw away.** An interim version of this fix also cleared bit
256 of the approach mask, because `do_1.gh()` reads it as "inert" and `do_1.a(coach)`
- the "can this coach use it" test - then returns false wherever the coach stands.
That test has **no caller anywhere in the client**; it is dead code. An A/B with the
mask left exactly as shipped (`0xFFFF`, `inert=true`) produced the element action
just the same, so the strip was removed rather than kept "just in case": mutating
authentic retail data for a dead code path is not a trade worth making. A test pins
the mask as untouched so the theory cannot quietly return.

**The 22 elements with no approach direction are not broken either.** Since the mask
does not gate the click, `mask & 0x00FF == 0` costs them nothing - the 12 card
masters, 1 challenge and 9 zone triggers behave like every other element. That
earlier claim is withdrawn.

**Verified** `unit` for the part-table parse (both offsets present, so the
fixed-offset shortcut fails loudly), the z rewrite touching only its two bytes, the
mask being left alone, no mutation of the shared table, and junk-tolerance; `live`
for the Zaap and the graveyard both producing element actions, and a full Zaap
teleport.
### B-108 - most of every island's interactive elements were silently thrown away

On the island every player starts on, the mailbox, the graveyard, the fusion lab
and both card masters were **not there at all** — five of world 25's six elements.
The client rejected each one at login:

```
ERROR Aucune définition trouvée pour l'instance d'élement interactif 103
ERROR Impossible de spawner l'élément interactif instanceId=103
```

**Cause.** Opcode 200 carries only `[instanceId][payload]` — it cannot tell the
client what an element *is*. `do_1.a()` resolves the TYPE through
`me_2.qR().eP(instanceId)`, a registry the CLIENT fills from its own env data, and
that registry is **per-chunk and transient**: `OH.d(ru_2)` registers a chunk's
element definitions as it streams in, `OH.e(ru_2)` unregisters them when it
unloads. An element whose chunk is not currently loaded therefore cannot be
resolved at all. We sent every element of a world in one frame at world entry, so
everything outside the spawn chunk was dropped — permanently, because nothing ever
re-sent it.

**The radius was measured, not guessed.** With the coach parked at three different
cells, every element at Chebyshev chunk distance ≤ 2 resolved and every element at
≥ 3 failed: 14 observations, no exceptions, and the boundary itself observed (the
graveyard resolves at exactly 2, a card master fails at exactly 3). Chunks are 18
cells, so the client keeps a 5×5 chunk neighbourhood. The controlled version of the
experiment is the convincing one: standing on the graveyard's cell, the graveyard
resolves and the *Zaap* starts failing instead — the two swap.

**Fix.** Elements are now streamed like actors: `refreshWorldElements` sends 200
for those coming into range and 206 for those leaving, as a delta against what the
session has already spawned, on world entry **and after every move**. Running it on
movement is what makes it robust — an element missed at the edge of the range is
picked up by walking closer.

Two details worth keeping:

- **`chunkOf` must floor-divide.** Go's `/` truncates toward zero, so cell −1 would
  share a chunk with +1, and several islands place elements at negative cells
  (world 25's fusion lab is at (−45,−25), a card master at (−58,33)).
- **The spawned set resets on world change**, because the client drops its element
  registry with the old world; without that we would believe elements were still
  spawned and never re-send them.

**This is not a corrupted client.** Nothing was wrong with the client or its data.

**Verified live:** login now produces **zero** rejections (it produced five), and
approaching the graveyard streams it and the mailbox in, with the crypt rendering
and highlighting where before it did not exist client-side.

**The old test asserted the bug.** `TestWorldElementsSpawnedOnEntry` required
world 25's entry frame to contain the Zaap, both card masters *and* the fusion
altar — and passed for months while the client was discarding four of them,
because it only ever checked what the server put on the wire. It now asserts the
opposite (far elements must be withheld) plus a companion that they stream in on
approach. Unit tests cover the chunk maths including the negative-coordinate trap,
and carry the 14 live measurements as a table so widening the radius "to be safe"
fails loudly — widening it is not safe, it silently drops elements again.

### B-107 - GM teleport froze the coach: "Invalid start cell for pathfind search"

`/WORLD <id> x y` and `/TP x y` placed the coach on a cell it could not stand on,
and the client then refused to move it at all:

```
INFO (SourceFile:418) - Invalid start cell for pathfind search : doesn't exist.
```

The client seeds its overworld pathfinder with the coach's cell **and altitude**
and needs a walkable layer at exactly that altitude. Neither command supplied one:

- `/WORLD` defaults `(x, y, alt)` to the destination's primary Zaap, which is
  correct — but when the caller passes an explicit `x y` it overrode only the
  coordinates and kept the **Zaap's** altitude. Worse, for a world with no
  registered Zaap the altitude fell through to `s.Coach.PosZ`, i.e. the altitude
  of the world the coach was **leaving**. Hopping to world 7 from the start island
  gave `alt=8`, from world 19 gave `alt=0`, for the same destination cell.
- `/TP` had the same flaw for the same reason.

Both now resolve the destination cell's real ground altitude — the lowest walkable
tplg layer, which is what the client's own arrival logic uses (B-102) — via a
lazily-loaded, cached `WorldTopology`. Lazy because only an admin issuing these
two commands ever needs it; loading all ~113 world topologies at startup would be
pure waste. An explicit `/TP x y z` still overrides.

The same cell that used to give `alt=8` now resolves to `alt=-11`, and the coach
walks. **Live-verified**: the pathfind error is gone entirely and click-to-move
works after a hop.

This is dev tooling, not a player-facing path (players arrive by Zaap, which
already carried a known-good altitude) — but it silently blocked live verification
in any world without a Zaap, which is the project's main validation tool.

### B-106 - achievements were never evaluated, so nothing ever unlocked

With the tab open (B-105) the client rendered progress correctly — it computes
percentages itself — but no achievement could ever *complete*, because the server
had no idea what an achievement was. Types 800/801/802 were undecoded and opcode
22000 was never sent.

Decoding them turned out to be the whole job, because **completion is entirely
generic**: an achievement is done when every statistic condition is met and every
listed card is in the coach's tome (`aau_1.a`). There is no per-achievement logic
anywhere in the client, so there is none here either.

All 332 shipped records decode with **byte-exact consumption** (no short read, no
overrun), which is the test that matters: the server unlocks *from* these records,
so a silent mis-parse would unlock the wrong things.

Three findings worth keeping:

- **There is no reward.** Points ("PE") are cosmetic — summed for a header total
  and to pick a row icon tier, nothing else. The record's one remaining `i32`
  (`ru_1.bJg`) is parsed, copied into the runtime object, and then read by **no
  client code at all**. It is decoded here and deliberately given no behaviour.
  Unlocks matter only as *keys*: zone triggers, challenge gating and the island
  Zaap dialog test "does this coach have achievement N".
- **Completion is not stored, only the announcement is.** Whether an achievement
  is done is recomputed from the criteria every time, exactly as the client does
  it. The table exists purely so the 22000 toast fires once per coach — without
  it a player would be re-toasted on every evaluation, including every login.
- **22000 is safe to push unsolicited**, unlike its sibling 22002: its handler
  `zN` is registered permanently at login and only raises a toast. A *hidden*
  achievement is a client-side no-op (`zN` gates its whole body on
  `!isHidden()`), so those are recorded silently and never sent.

**Verified** `unit` for the decoder (byte-exact over all 332 records, catalogue
shape, and the `>=` / clamped-percentage rules) and `e2e` for the engine over real
sockets: announced on crossing the threshold, not before, exactly once, still not
repeated after a relog, hidden ones silent, card-gated ones still locked.
Mutation-checked three ways — announcing repeatedly, announcing hidden ones, and
ignoring card conditions each fail with the specific diagnostic.

**Live-verified** end to end: entering the world announced achievements 362 and
456, the client showed *"Exploit débloqué : Le démon de la 52ème minute vous donne
une rune"* with its description — the same achievement its own tab had computed as
100%, so two independent implementations agree — and a full restart + relog
announced nothing again.

**Follow-up, now also fixed:** the tome was initially approximated by
currently-owned card templates, which would have let a sale silently revoke the
achievements a card had completed. It is now a grow-only table of its own, folded
in from the inventory at login and on every inventory push — `pushInventory` is
the single path every visible grant takes (shop, fusion, fight winnings,
challenge rewards, exchange, mail), so hooking it there cannot be out-of-date the
next time a grant site is added. The tome is also emitted in the 2052 descriptor's
`0x80` blob, which had been hard-coded empty and mislabelled "betCards": without
it the client computes card-gated progress from an empty set and shows 0% on rows
the server considers complete.

That fix needed a better test than the one it started with. The first version
asserted on the database, which a mutation that made *evaluation* read the live
inventory sailed straight through — the row was still there, nothing looked at
it. The test now asserts behaviour: a second achievement gated on the same card
plus a criterion must still unlock after the card is sold, which is only possible
if evaluation consults the tome. That mutation now fails.

### B-105 - the achievements tab could not be opened at all

Clicking the "Exploits" button did nothing. Not "opened empty" — nothing.

The reason is that the client does not open the dialog itself. `yh.a()` only
registers handler `A` and sends opcode 22001:

```java
apN.aDK().a(A.U());                 // register the achievement handler
add_1.aOG().l("dofusarena.achievement", qJ.class);
anp_0 anp_02 = new anp_0();          // 22001, empty
apN.aDK().vJ().b(anp_02);
```

and it is `A`'s **22002 handler** that pops the window:

```java
case 22002: {
    apN.aDK().Ln().b(ls_02.qI());
    ...
    add_1.aOG().a("achievementDialog", oh_2.bq("achievementDialog"), (short)10000);
```

22001 was not registered server-side, so the reply never came and the button was
inert.

**Why this was not obvious:** `OpStatisticData` (22002) carried a blanket
`DO NOT EMIT` warning, because the tutorial handler `asA` pops the tutorial-guide
dialog on receipt, and `asA` is registered permanently at login (`by_2`). That
warning was over-broad, and following it literally is what left 22001 unanswered.

The client dispatches **newest-handler-first** and stops at the first handler that
consumes:

```java
// fh_2 registration:  this.qe.add(0, atG2);
for (int j = 0; j < n2; ++j) { bl2 = atG2.a(pr_02); if (bl2) continue; break; }
```

`A` is registered when the tab opens, so it sits at index 0 and returns `false`,
and `asA` never sees the frame. The correct rule is therefore not "never emit" but
**"never emit unsolicited; always emit in reply to 22001"** — the request itself is
the proof that `A` is registered. Confirmed live: the tab opens and no tutorial
dialog appears.

**A second hazard found while fixing it.** 22002 must carry the coach's COMPLETE
criteria set, never a delta: `A` does `Ln().b(ls_0.qI())` and `aez_0.b` *replaces*
the map rather than merging, so anything omitted is erased from the running
client. Omitting the always-seeded Zaap criterion (219) would silently re-lock the
island Zaap until the next login — i.e. a player could lose access simply by
opening the achievements tab. Both encodings now derive from one
`normalizeCriteria`, so the login descriptor and the tab snapshot cannot disagree;
only the length-prefix width differs (i32 here, i16 in the 2052 descriptor blob).

**Verified** `unit` that the two encodings carry identical pairs, and `e2e` that
the reply arrives, reflects criteria earned since login, and is a full snapshot.
Mutation-checked three ways — dropping the registration, omitting the Zaap
criterion, and using an i16 length prefix each fail with the specific diagnostic.
**Live-verified**: the tab renders 10 PE with real per-achievement percentages
(100 / 50 / 25 / 0 %), so the server's criteria genuinely drive the client's
completion maths.

### B-104 - chat had no server-side safety at all, and one client-side gap was exploitable

Finishing the chat pipes meant deciding what a *modified* client may do, since
every limit the retail client applies is trivially removed from it. Reading them
out of the client first turned up one gap that is not merely missing enforcement
but an actual harassment vector.

**1. Ignored players could still whisper — and pop your UI.** The client filters
General, Trade, Clan and Group by sender name, but `om_0` case 3154 (private) has
**no ignore check at all**, and receiving a whisper additionally force-maximises
the chat panel and force-opens `chatDialog`:

```java
case 3154: {
    ais_2 ais_22 = (ais_2)pr_02;
    ...
    if (!azs_0.aLV().getBooleanProperty("chat.isMaximize")) {
        azs_0.aLV().g("chat.isMaximize", true);          // force-maximise
    }
    if (!add_1.aOG().kR("chatDialog")) {
        add_1.aOG().a("chatDialog", ...);                // force-open
    }
```

So an ignored player could reopen a victim's chat window at will, and there was no
client-side backstop to rely on. The server now filters every chat path by the
recipient's ignore list, and answers the sender `UserNotFound` — the same thing
they already see for an offline target, so being ignored is not disclosed.

**That fix needed a second one to work at all:** ignore edges were written to the
database but never mirrored into the in-memory coach, which is loaded once at
login. An ignore therefore did not take effect until the player relogged.

**2. Chat was a markup-injection channel.** The renderer treats both the message
body and the sender name as markup and escapes nothing (`rw_2.bJ`), with `<b>`,
`<c>`, `<text color=…>` and `<image pixmap=…>` all live. The only thing stopping
players today is the input widget's `restrict="[.*&[^<>]]"`, i.e. a client-side
filter. `<` and `>` are now stripped on relay, matching what the client's own
input filter does rather than inventing an escaping scheme.

**3. No rate limiting.** Mirrored from the client:

| Limit | Client | Server |
|---|---|---|
| Trade cooldown | `TradeContentCommand.czB` = 30 000 ms, strict `<`, singleton never reset | same, per coach |
| Anti-repeat | `jd_0`: last 10 lines, 5 s each, only for lines ≥ 6 chars | same window, but keyed on the **trimmed body** |

The anti-repeat is deliberately *stricter* than the client's, which hashes the raw
input line — so a trailing space, or switching pipe prefix, slips the same text
straight through. Keying on the body closes that.

**4. Wire bounds.** Bodies are capped at 32767 (the u16 pipes are read with a
SIGNED `getShort`, so more arrives negative and the client drops the message with
`NegativeArraySizeException`), names at 255, private bodies at 255 (u8), all cut
on a rune boundary so a truncation cannot render as mojibake.

**Verified** `unit` for the gates and the sanitiser (including the strict 30 s
comparison and rune-boundary truncation) and `e2e` over real sockets for the parts
a helper test cannot prove: an ignored whisper dropped, an ignored trade line
dropped while an uninvolved third player still receives it, an ignored general
line dropped, markup stripped on the wire, and the cooldown enforced.
Mutation-checked twice — removing the whisper ignore check, and removing the
in-memory mirror of the ignore edge, each fail with the specific diagnostic.

### B-103 - Trade chat was dropped, and it looked like it had been sent

The client offers four chat pipes — General (`/s`), Private, Trade (`/t`) and
Clan (`/c`) — plus Group (`/p`). We served two. Typing in Trade produced:

```
level=INFO msg="unhandled opcode" opcode=3159 arch=3 len=17
```

and nothing else. The failure was invisible to the player because **the client
renders its own outgoing line locally**: the chat panel showed
`(Commerce) Chrono : selling a dofus` in the Trade colour, so the message looked
delivered and simply never arrived for anyone.

**Fix.** `3159` (C2S, arch 3, `[u16 len][msg]`) is handled and fanned out as
`3168` to every other online overworld coach — Trade is global by design. The S2C
form is byte-identical to VicinityContent (3152), the client's `ayy` being a
field-for-field copy of `ck_0`, so it is the same builder with a different opcode.
A leading `/` is still treated as a GM command: the pipe is only which tab the
text was typed into.

**The other two pipes are blocked, not skipped**, and the distinction is worth
recording because both look implementable from the server side alone:

- `/c` **Clan** (3199 → 3198) is guild-scoped, and `GuildContentCommand`
  self-gates on the coach having a `ca_0` — **with no guild the client emits no
  packet at all**, confirmed live. Implementing it before guilds exist would mean
  handling a message that cannot arrive.
- `/p` **Group** (3161 → 3170) targets the ally coach on your side of a live
  fight, read out of CREATE_FIGHT's coach list (`aat_2`). In a 1v1-only server
  there is no ally, so the target id is 0 or stale. It needs 2v2.

**Verified** `live` — the retail client typed `/t vends épée à 10 kamas`, the
server logged `trade chat from=Chrono`, and a second connected player received
`3168 TRADE from Chrono` with the text. Also `e2e` — delivery, no self-echo,
whitespace-only lines dropped, and an accented body round-tripping (the u16 length
counts *encoded* cp1252 bytes, so raw UTF-8 would both mangle the text and
desynchronise the length). Mutation-checked: emitting the vicinity opcode instead
of 3168 fails the delivery test.

**Found alongside, and NOT fixed because there is nothing to fix:** the channel
family this work was originally aimed at is vestigial. The client cannot send
3151, and a 3140 we send routes to pipe 3 — which `du_1` never registers — so
`ql_1.a` dereferences null and the frame loop swallows it. `handleChannelMessage`
has been broadcasting to an audience that discards every line. Recorded in
ROADMAP item 25 rather than "fixed", since the correct action is to stop claiming
it works.

### B-102 - a hand-typed direction byte was wrong on the wire for one Card Master

Found by generating the overworld element table from the client's own env layers
and diffing it against the hand transcription it replaced (ROADMAP item 24). 138 of
139 payloads matched byte for byte. The one that did not:

```
 env jar  ...001a0001010101000000000004303b313500
 hand     ...001a0001010103000000000004303b313500
                       ^^ direction
```

World 28's Card Master (instance 16): the RU part's **direction** byte was typed
`03` where `maps/env/28.jar` says `01`. The payload is copied onto the wire verbatim
in INTERACTIVE_ELEMENT_SPAWN, so every client that entered Magmara was told that
element faced the wrong way. Confirmed against the raw jar bytes before changing
anything (the jar contains the `01` form and not the `03` form).

Cosmetic in effect, but it is the exact class of error the generator exists to
remove, and it was invisible to every test that only checked the table's shape.

**Verified** `unit` — `TestGeneratedTableMatchesTheHandTranscription` compares the
generated table against the transcription on kind, cell, payload, arg/mode and Zaap
altitude, and `TestCommittedTableIsStillWhatTheDataSays` re-derives from the jars.
Mutation-checked: swapping the Card Master descriptor's two fields in the generator
fails the golden comparison with the specific ids.

**A second suspected error was NOT one, and that matters more.** The same diff
flagged world 25's Zaap altitude (hand: 8, element's authored z: 30) and a first
pass "corrected" it to 30. The live client refuted it immediately: at 30 the coach
does not render at all, while 8 is where it has always correctly appeared. The
cell has two stacked walkable floors, 8 and 30, and the arrival altitude is the
**lowest** — not the element's own z, and not the highest layer, which were the two
plausible rules. The hand value was right, the generator was wrong, and the
altitude rule is now derived correctly for all 21 Zaaps. Recorded because the
tempting reading — "the data disagrees with the table, so the table is wrong" — was
the wrong one exactly once, and it was the case that could freeze a player.

### B-101 - every restart silently un-registered everyone from every tournament

`TournamentManager` held registrations in a plain `map[uint]map[int64]bool` and
nothing else. A player signed up, the server bounced, and their entry was gone —
no message, no trace, and the client happily showed the "S'inscrire" button again
as though they had never registered. The web console had to apologise for it in
the UI.

**Fix.** A `tournament_registrations` table keyed by `(coach_id,
tournament_wire_id)` with a unique index, written through on register/unregister
and loaded into the same in-memory cache at boot. The manager takes the store as a
small interface and is nil-tolerant, so unit tests and any store-less dev run
behave exactly as before. `Unregister` is new (nothing called it, but persisting
only half the transition would have been a trap for whoever adds withdrawal).

Keyed by the **wire** id, not the row id, because that is what the client sends in
4607 and what everything else is keyed by. That is only safe because
`Tournament.WireID()` derives from the row id and is stable across restarts — and
it is why `TournamentRepo.Delete` now purges a tournament's registrations: they
have no foreign key, so they would otherwise survive as orphans and then be
inherited by whatever row later reused that id. The domain field is named
`TournamentWireID` rather than `TID` to keep the two id spaces from being confused.

**A fake store hid a real bug, and the real-DB test caught it.** The manager tests
run against an in-process fake, which passed immediately. The store test against a
temp database failed with `no such column: tid` — gorm maps a field named `TID` to
`t_id`, so every query was wrong. The manager had been tested against itself; only
the repo test touched actual SQL. Same lesson as the exchange block (B-093), which
is why both layers now have their own tests.

**Verified** `unit` (write-through, load-back across a simulated restart,
idempotent register, persisted unregister, nil-store fallback) + `store` (real
round-trip, idempotency against the unique index, and delete-purges-registrations).
Mutation-checked: dropping the write-through, and dropping the purge in `Delete`,
each fail their own test.

**Verified** `live`: registered for "Tournoi 1v1 Classique" from the retail
client's calendar (`tournament register tid=2600001 code=0`), restarted the
server — `tournament registrations restored count=1` — and re-opened the same
tournament, where the client now reads **"Vous êtes inscrit au premier tour"**
instead of offering the register button.

### B-100 - the TOURNAMENT "Combattre" was also unanswered; refused visibly

The third and last member of the pattern (client frame `ds_2`, twin of `vu_1` /
`wp_0`). Its C2S pair — **28611** `ly_1` search and **28609** `bt_0` cancel — was
unserved, so the Tournois tab's "Combattre" went silent exactly like B-098/B-099.
28611 is sent by **two** tabs: Tournois (with a real team id) and **Légendes**
(with the legend pseudo-preset 9999).

**It is NOT a clean twin, and assuming it was would have shipped a broken frame.**
The request, cancel and result all carry a leading tournament id, 28614 carries one
too, and **28616 has a SECOND byte**: when `code == 2` the client ignores the usual
message table and calls `zN.M(subCode)`. A one-byte error — the shape the other two
families use — is a short frame and a decode failure.

**This REFUSES rather than queues, deliberately.** For the other two families
accepting the search is truthful: two coaches really can pair and fight. A
tournament match is not a free pairing — it is a specific bracket fixture between
two registered entrants, and this server has no bracket/match layer (28649 is
answered with an empty tree, and the live-match layer is deliberately deferred).
Pairing arbitrary searchers would invent semantics and produce fights that advance
nothing, i.e. silently pretend tournaments work. So the answer is the client's own
`matchfinder.impossibleToStartOpponentsSearch` (code 1), which shows a message and
leaves no overlay behind, and 28609 is answered so the Cancel path works.

When the bracket layer lands this becomes: verify the coach is an entrant of `tid`,
accept with 28612, pair by fixture, then 28614 followed by CREATE_FIGHT.

**Verified** `e2e` — refusal with an exactly-2-byte payload and code 1, the same
for the Légendes preset 9999, and the cancel reply. Mutation-checked: shortening
28616 to one byte (i.e. treating it as a clean twin) fails the test.

**NOT verified live**, stated plainly: reaching 28611 from the UI needs a team, a
saved preset AND a selected tournament, and the client cannot even say so —
clicking "Combattre" with no tournament selected renders the literal
`!error.noTournamentSelected!`, because `hu_2:814` asks for
`error.noTournamentSelected` while all four `texts_*.properties` define it as
`tournaments.noTournamentSelected`. That is a **retail client defect**, not ours;
recorded in `client/analysis/PROTOCOL-messages.md` along with the full three-family
table.

### B-099 - the CLASSIC "Combattre" had the same silent-queue defect, plus a double-queue bug

Found by asking, after B-098, whether the classic twin had the same gap. It did.

**Symptom.** 23103 was served — the coach really did enter the queue and really did
get a fight when someone else readied — but **none of the replies were sent**. So
while waiting the player saw nothing at all: no "Recherche en cours" overlay, and
because the Cancel button lives *inside* that overlay
(`avl_0.cancelSearch` is registered by the 23104 handler), **no way to leave the
queue**. Clicking "Combattre" again just queued them a second time.

**A stale comment had covered this up.** The handler documented itself as "the
coach waits (the client shows `waitingForOpponentCoach`) until an opponent
readies". That string exists, but it belongs to the fight-INVITATION flow
(`B:96,125,154`, `aqr_0:25`) and is never used on the 23103 path. Checking it was
what exposed the bug — the premise-check habit paying off on our own prose rather
than on the roadmap's.

**Root cause.** `vu_1` (classic) is character-for-character `wp_0` (evolution)
with one string changed, `classicSearchStatusDialog` for
`evolutionSearchStatusDialog` — same four cases, same branches, same teardown
rules. The whole family was simply unimplemented:

| classic | evolution | dir | payload |
|---|---|---|---|
| 23101 `bm_1` | 23001 | C2S | `[i64 coachId][i16 teamId]` cancel |
| 23102 `ada_1` | 23002 | S2C | `[i8 accepted]` |
| 23103 `atj_0` | 23003 | C2S | `[i64 coachId][i16 teamId]` search |
| 23104 `aLi` | 23004 | S2C | `[i16 teamId][i8 accepted]` |
| 23106 `ads_2` | 23006 | S2C | *(empty)* |
| 23108 `M` | 23008 | S2C | `[i8 code]` |

**Fix.** The handshake now lives in one place (`search_handshake.go`,
`searchFamily`) and both tabs share it, so the traps only had to be written once
and the twin relationship is explicit. 23103 accepts with 23104, announces 23106
to both sides on pairing, and 23101 is handled and answered with 23102. A
`CancelSearch` before enqueueing makes a double click idempotent.

One deliberate asymmetry: the evolution preset is the synthetic 99 and is refused
if it is anything else, but the classic i16 is a **real team id and may be -1**
("no preset selected", `hu_2:969-973`), arriving as 65535 and resolving to no
roster. That is tolerated — `buildFightTeamFor` falls back to the coach's own
fighters, which is this path's long-standing behaviour and not something to
tighten while fixing an overlay.

**Verified** `live` — Elite tab → COMBATTRE showed **"Recherche en cours……"** with
its Cancel button (`combattre: waiting for opponent team=1`), and clicking
**Annuler** closed it and logged `combattre: search cancelled`. That button was
unreachable before this fix.

Also `e2e` — accept + cancel (including the -1 preset passing through), pairing
with 23106 ahead of CREATE_FIGHT, and a double-click guard that pairs a third
coach against a stale duplicate entry if the dedupe is removed. All three
mutation-checked: dropping the 23104 send, the 23106 send, or the dedupe each
fails its own test with the specific diagnostic.

### B-098 - the EVOLUTION tab's "Combattre" was unanswered, so the mode was unreachable

**Symptom.** Team panel → Evolution → **COMBATTRE** did nothing at all. The client
passed its own checks, sent one message and waited forever on a silent screen:

```
level=INFO msg="unhandled opcode" opcode=23003 arch=2 len=10
```

**Every evolution fight this server had ever run was created by the test
harness.** The mode the whole progression system exists for — XP, morale,
fatigue, wounds, permanent death, the graveyard — had never once been reachable
from the retail client.

**What the client is asking for.** `ajw_0` (23003, C2S, arch 2) is
`{i64 coachId, i16 preset}`, and it is the byte-identical twin of the classic
`atj_0` (23103) this server already served. Its whole family mirrors the classic
one, frame for frame (`wp_0` vs `vu_1`):

| evolution | classic | dir | payload | role |
|---|---|---|---|---|
| 23001 `abn_0` | 23101 | C2S | `{i64 coachId, i16 preset}` | cancel the search |
| 23002 `wf_2` | 23102 | S2C | `{i8 accepted}` | reply to the cancel |
| 23003 `ajw_0` | 23103 | C2S | `{i64 coachId, i16 preset}` | start the search |
| 23004 `amh_0` | 23104 | S2C | `{i16 preset, i8 accepted}` | reply to the search |
| 23006 `azl_0` | 23106 | S2C | *(empty)* | "Lancement du combat" |
| 23008 `KL` | 23108 | S2C | `{i8 code}` | search error |

**The 99 is not a mode** — an earlier revision of this entry said it was, and that
was wrong. `sw_1.bMm = 99` is a synthetic **team preset id** meaning "the
evolution team", a peer of graveyard (`10000`) and legend (`9999`); the object
carrying it (`xz_0`, bound to the Lua property `evolutionTeam`) sets it in its own
constructor, and the tournament path sends `xz_0.amc().tI()` rather than a
literal. The client's own minimum-budget rule is gated on it —
`hu_2:1073`, `xz_02.afr() && getValue() < 5000`, where `afr()` is `tI() == 99`.
It is therefore **not a database team id** and must map to the coach's TITULAR
line-up; looking it up in the teams table would miss, or worse, hit an unrelated
coach's real team.

**The handshake is not optional, and the order is load-bearing:**

```
C2S 23003            ->  S2C 23004 {preset, 1}   opens the "Searching…" overlay
   (opponent found)  ->  S2C 23006 {}            closes it, then CREATE_FIGHT
   (cancelled)       ->  S2C 23002 {1}
   (failed)          ->  S2C 23008 {code}
```

Two traps found by reading `wp_0`:

- **`23004` with accepted=0 is a dead end.** The client pops the team panels
  either way, but only opens the overlay when the flag is true — a refusal that
  way leaves the player on a bare screen with no message. A refusal must be
  `23008`, not a rejected search.
- **`23008` codes 1 and 2 show their message but leave the overlay up**; only
  3, 4 and 5 tear it down. So codes 1/2 are safe only *before* an accepted
  23004.

**Fix.** `handlers_evolution_search.go`: 23003 validates the preset, refuses an
empty line-up with 23008/2, accepts with 23004, and enqueues in the existing
matchmaker under a dedicated mode so evolution searchers only ever pair with each
other. On pairing both sides get 23006 and then the fight — created with
`evolution=true`, so it feeds progression. 23001 cancels and answers 23002.
Because `WE` re-sends 23003 unprompted at end-of-fight, a stale queue entry is
dropped first so a coach cannot pair with itself.

**Verified** `live` — the payoff run, with a synthetic second coach
(`internal/testclient`) to pair against:

1. COMBATTRE → the retail client showed **"Recherche en cours……"** with its
   Cancel button (the `evolutionSearchStatusDialog` overlay) — 23004 working.
2. The partner searched → server logged
   `evolution search: paired -> starting fight a=Chrono b=Sparrer` and
   `fight started practice=false evolution=true challenge=0`, the overlay closed
   and **a real evolution fight rendered in the retail client**.
3. Ending it opened the **`fightResultEvolutionDialog`** — see B-096/B-097 below,
   which this finally verified end to end.

Also `e2e` — `evolution_search_test.go`: accept-and-wait, cancel, empty-team
refusal, pairing, and that the produced fight actually banks XP (i.e. is not a
practice fight). The pairing test asserts 23006 arrives **before** CREATE_FIGHT
by inspecting the frames `WaitFor` saw ahead of it; deleting the 23006 send fails
it on both clients.

> Note on that ordering: it is structural, not delicate. CREATE_FIGHT is emitted
> from the fight goroutine (`startFightWithTeams` → `f.Post`), so anything sent
> synchronously from the handler necessarily precedes it. Reordering the two
> statements in the handler is therefore *not* observable and the test cannot
> catch it — what it does catch is the send being dropped or moved into the fight
> actor, which is the change that would actually break the client.

### B-097 - being knocked out in an evolution fight killed the fighter for good

**Symptom.** Every fighter that finished an evolution fight at 0 HP was written
to the database as permanently dead (state 2) - on the winning side too. The
modelled per-fighter death *chance* (B-066) therefore almost never decided
anything, because it was skipped for exactly the fighters most likely to be
affected.

**Root cause.** Two independent passes, neither of them derived from the client:

```go
// postfight_apply.go - the meta pass, per fighter
if f.Evolution && ff.HP <= 0 {
    rep.dead = true                       // skips the roll entirely
    fr.State = domain.FighterStateDead
} else if d.Conditions != nil { ... }     // the client-exact roll lives here

// handlers_fight_combat.go - a SECOND unconditional sweep, after the first
for _, ff := range t.Fighters {
    if ff.HP > 0 { continue }
    d.Store.Fighters.SetState(ff.Fighter.ID, domain.FighterStateDead)
}
```

The comment on the first (*"a fighter the FIGHT already killed... cannot be hurt
twice"*) reads like a derivation but is invented: nothing in the client links
HP to permanent death. B-043 introduced it honestly as a placeholder
(*"minimal-correct"*), and it then outlived the mechanic that replaced it.

**What the client actually says.** Permanent death is a per-fighter probability
computed from that fighter's own lifetime XP (`adl_0.atd()`:
`death% = (totalXp/1000)²/100`), with no HP input anywhere:

- `fightEndAchievementDeathDescriptionFailed` - *"vous n'avez pas occasionné de
  **mort définitive** chez les combattants adverses"*. You down the enemy team to
  win, so this string could never appear after a win if downing killed. The
  client also keeps the two words apart: `fight.die` (*"[#1] est mort"*) is the
  in-fight KO; *"mort définitive"* is the permanent one.
- `content.29.301` - *"et un **grand nombre de blessures** peut provoquer la
  mort"*: death is the end of an injury/fatigue chain built up over many fights.
- `bf_1.b` kills only when an upgrade roll lands on a fighter already holding 3
  serious wounds - cumulative, never HP-driven.
- Opcode 4520 `FighterDiesMessage` (`cd_2`) carries a bare fighter id and no
  permanence flag, and **no client code links `HP == 0` to `isDead()`/state 2**.

**Fix.** Delete the override; every fielded fighter takes the same roll. The
second sweep no longer decides or persists anything either - `runPostFightMeta`
already banks the result through `SaveProgress`, which writes `state` - so it is
now `announceDeaths`, whose only job is the 6006 roster refresh.

That rename fixed a **second bug hiding inside the first**: being the code that
pushed the roster, it gated the push on *a downed fighter existing*. A fighter
killed by the roll alone (i.e. every death that will now actually happen) never
triggered a refresh and stayed alive on the player's screen until relog. The
push is now keyed off who the roll killed.

`deathIsRolledNotDealt` in `postfight_apply.go` carries the evidence, including
the honest limit: `adl_0.atd()` and `bf_1.b` have no callers in the client (they
are server logic shipped inside `core.jar`), so we cannot prove whether retail
gated the *roll* on participation. What the evidence settles is that a KO does
not replace the roll with certain death.

**Verified** `unit` - `TestDownedFighterIsNotKilled` (a downed rookie survives,
death% being 0 at TotalXP 0) and `TestVeteranDiesFromTheRoll` (a fighter at 100%
death chance dies *while standing at full HP* - the dead one is the untouched
fighter and the survivor is the one who hit the floor, which is the whole point).
`TestDeathIsReportedForTheRosterPush` covers the push keying. All three were
mutation-tested: reinstating the old `HP <= 0` branch fails them with the exact
diagnostics quoted above.

**Verified** `live` (once B-098 made evolution mode reachable) - a real evolution
fight in the retail client, won by wiping the opposing team. Server:
`post-fight meta reports=9 killed=0 injured=0`. The result dialog's achievement
panel read, in the client's own words:

> **IMPITOYABLE** — *Hélas, vous n'avez pas occasionné de mort définitive chez les
> combattants adverses.*

That is the exact string quoted as evidence above, displayed after downing every
enemy — which is precisely the outcome the old rule made impossible, and the
clearest possible confirmation that a KO is not a permanent death.

### B-096 - END_FIGHT's per-fighter reports were keyed in the wrong id space

The post-fight debriefs in 8300 are keyed by an id the client resolves against
its **own roster**, and it does so without a nil check:

```java
// y_0.run(), after every other end-of-fight update
object22 = this.bC.eJ();
for (int j = 0; j < object22.length; ++j) {
    adY.atu().dz((long)object22[j]).a((OW)this.bC.t((long)object22[j]));
}
apN.aDK().a(ajo_1.azb());   // <- the line that opens the result dialog
```

`adY` is filled from the fighter list, which sends the raw database fighter id
(`buildFighterList` → `w.I64(int64(fighters[i].ID))`). The server was keying the
reports by the **fight wire id** instead — `FighterWireIDBase + fr.ID*16 + …`,
a value around 1.1e12 that is not in the roster at all. `dz()` returns null, the
`.a(...)` throws, and `run()` dies **before** the line that opens the dialog.

There is a second instance of the same mistake in the same place: the reports
were built once and sent to *both* coaches, so even with the right id space each
client received the opponent's fighters, which are equally unresolvable in its
roster.

Fixed by keying reports with the roster id and tagging each with its owning
coach, then narrowing per recipient (`reportsFor`). Spectators get none — they
have no roster to resolve against.

*Verified:* unit (the id is a roster id and specifically not in the wire-id
space; the scoping helper). Both of those passed against the broken code, since
they only exercise the builder — so the real guard is an e2e that runs a ranked
fight with **real roster fighters** (progression skips placeholder fighters with
id 0, and `fightFeedsProgression` excludes practice and challenge bouts, which
is why the obvious existing tests carry no reports at all) and checks the ids in
the actual frame against each recipient's roster. Mutation-checked: reverting to
wire ids, and dropping the per-coach scoping, each fail it with the specific id
named.

**Verified** `live` (after B-098 made evolution mode reachable at all): a real
evolution fight between two coaches ended with `post-fight meta reports=9` — 6
for one side, 3 for the other — and the retail client **opened the
`fightResultEvolutionDialog`** with a per-fighter XP breakdown for its own six
and nothing for the opponent's. That is the first time this dialog has been seen,
and it is what the wrong id space and the unscoped send would each have thrown
before reaching.

*Historical note:* this entry used to end "this did not, on its own, make the
result dialog appear — see the open item". That open item was itself wrong (the
earlier evidence came from injected fights the client never entered), and the
dialog was in fact unreachable for a completely different reason: B-098.

### B-095 - CREATE_FIGHT's fight kind was written into a byte the client never reads

Every decision the retail client makes about *what sort of fight this is* — which
result dialog to open, whether to read a coach's evolution level instead of its
strength, whether to look up challenge metadata — comes from one value, and the
server was putting it somewhere else.

`aat_2.ac` reads the 8000 header as:

| slot | lands in | read back as |
|---|---|---|
| i32 | `mv_1.cAq` | **`aKl()`** — the fight kind |
| i64 | `adu_0.cmF` | **`asy()`** — the challenge id |
| i8 | `mv_1.byp` | `ZC()` — **no reader anywhere in the client** |
| i64 | `mv_1.byv` | turn-display budget, `Math.max(31000, byv)` ms |
| i32 | `axw.aW` | fight instance id |

The server wrote a constant `1` into the i32, `0` into the first i64, the kind
(5 or 6) into the **unread** i8, and the challenge id into the turn-clock slot.
So `aKl()` was always 1 and `asy()` always 0, which means:

- `WE` case 8300 could never take `aKl() == 5`, so the challenge reward/XP panel
  was unreachable, and `dC(0)` would have returned null even if it had;
- `aKl() == 6` was never true, so the evolution result path and its
  Death/Injury achievement rows were unreachable;
- `aat_2` lines 194/214 never took the evolution branch, so an evolution fight's
  coach block was read as *strength* instead of the evolution level;
- `aKl() == 3`, the tournament path, was equally unreachable.

The semantics had actually been worked out correctly before — the old comment
named `WE case 8300 -> adu_02.aKl() == 5` — but the value was written to the
wrong field, and `aKl()` is the i32, not the byte that looks like a kind.

Fixed by deriving the kind once (`Fight.wireKind()`: evolution 6 > challenge 5 >
normal 1) into the i32, putting the challenge id in the first i64, leaving the
unread byte at zero, and sending the real turn clock in the slot that wants a
duration. `Fight.FightType` and `Fight.Bet` are gone with it: the first was a
constant 1 that only fed the wrong slot, and the second was never set by
anything (betting is vestigial in 2.70 — see the note below).

*Verified:* unit (`TestCreateFightKindLandsInTheSlotTheClientReads` decodes the
header exactly as `aat_2.ac` does and asserts each value's slot;
`TestCreateFightLeavesTheUnreadByteZero` stops the kind being put back into the
i8). Mutation-checked by restoring the whole original mapping, which fails five
assertions naming the specific slots.

**Not yet visually confirmed, and now known to be blocked by something else:** a
live challenge fight and a live evolution fight were both driven to a settled
result against the retail client, and **neither opened any end-of-fight dialog**
— not the challenge panel, not the evolution debrief, not the ordinary result
screen. Since the ordinary screen is also missing, the dialog is failing for a
reason upstream of the fight kind. This fix is necessary for those panels but is
evidently not sufficient; the missing result dialog is a separate open item.

### B-094 - `CardLocked` was read in three places and set nowhere

The last of the three persistence defects, and the answer turned out to be that
the question was wrong: nothing sets the flag because **2.70 has no per-instance
card flag at all**.

`CoachCard.Flag` carried two bits, `CardLocked` (1) and `CardCursed` (2). The
locked bit gated trading, mailing and the commit-time exchange invariant, and
was never written by anything. The cursed bit was written to every card the
server ever created and was never read.

Neither exists in the client:

- the card object on the wire is `eb_1`'s four bytes — one i32 reference id,
  `NT()` returns 4 — with no flag byte anywhere;
- the owned-card view model `wy_2.ce` lists 28 bindable property names and none
  of them is locked, cursed, linked or tradable;
- the only `isLocked()` in the client is `mi_2.isLocked()`, a local
  drag-and-drop lock on an inventory container that never touches the network;
- there is no "cursed" concept for cards in the i18n tables in any language —
  the only *maudit* strings are spell descriptions.

The real rules are **per-template**, in the `aPp` card record: field 12 `tp()`
(**Bound** — "on ne peut échanger/envoyer une kard liée") and field 13 `tq()`
(**Undestructible** — blocks destroy, sell, fuse and give-to-demon). The server
already parsed both into `gamedata.CoachCard` and already used them for trading
via `cardIsTradable`; only mail and the store were still consulting the dead
bit.

Fixed by deleting the flag outright — the field, both constants, every
`Flag: CardCursed` initialiser, and the portal's "Flags" column, which had been
rendering "Cursed" against every card a player owned. Mail now gates on
`cardIsBound`, which matches the client exactly: mail checks `tp()` **alone**, so
an indestructible card may be posted even though it cannot be destroyed or sold.
Using the broader tradability check there would have quietly refused a card the
retail client sends happily.

The `flag` column itself stays in existing databases — `AutoMigrate` never drops
— but nothing reads or writes it, and inserts fall back to its default.

*Verified:* unit (`cardIsBound` truth table, including that Undestructible is
NOT bound), e2e (`TestMailRefusesBoundCardsButAllowsUndestructible` posts all
three kinds and checks what actually left the sender's inventory).
Mutation-checked both ways: dropping the gate lets a Bound card through, and
substituting `cardIsTradable` wrongly refuses the Undestructible one.

### B-093 - The whole card-exchange block was on 2006 opcode numbering

Trading could never have worked with the retail client. The exchange messages
were implemented as a contiguous run, 5105–5112 in order, which is the 2006
layout. 2.70 renumbered the block, and the mapping is not contiguous:

| Ours (2006) | 2.70 | Client class | Direction |
|---|---|---|---|
| 5105 add card | **5105** | `ua_2` | C2S |
| 5106 remove card | **5107** | `wd_0` | C2S |
| 5107 set ready | **5109** | `ahJ` | C2S |
| 5108 cancel | **5111** | `any` | C2S |
| 5109 card added | **5110** | `asH` | S2C |
| 5110 card removed | **5112** | `aaz_1` | S2C |
| 5111 end | **5114** | `aqX` | S2C |
| 5112 user ready | **5116** | `dl_0` | S2C |
| — | **5113** | `Or` | S2C (new: refusal notice) |

Two of the opcodes the server *broadcast* — 5109 and 5111 — are **client-sent**
messages in 2.70 (`extends so_0`, `encode()` only) and have no case in the
client's decode factory `gz_1`, so the client could not have instantiated them.
Meanwhile the client's real remove-card (5107) would have arrived at the
server's set-ready handler.

The card payload was wrong too. The server wrote the 2006 shape
`[i32 refCardId][i64 uid][i8 flags]`, but 2.70's card object is `eb_1`'s four
bytes and nothing else (`NT()` returns 4, `b()` reads a single `getInt()`), so
`asH` reads `[i64 exId][i8 userIdx][i32 refCardId][i16 qty]` — 15 bytes against
the 24 being sent. There is **no per-instance uid on the wire at all**: the
client generates its own locally in `eb_1.b` via `uq_1.ahR()`. Cards are
therefore identified by **template id**, and the server now resolves them as
`(coach, template, pos = 0)`, which is how the rest of the codebase already
treats inventory (`ConsumeAndGrant`).

**Why it was not caught:** `COVERAGE.md` recorded all twelve opcodes as
*audited & correct*, and the end-to-end tests passed — because
`internal/testclient` had the same 2006 numbers hard-coded. The server was only
ever tested against itself. Both are fixed, and `TestExchangeOpcodesMatchTheClient`
now pins every opcode and direction to the client class that implements it, so a
server message can never again land on an opcode the client only sends.

Also added: **5113**, the refusal notice, which 2.70 has and the server did not.
It is now sent when the server refuses a stake — for a non-tradable card, and
for a unique card the receiver already owns (`ky_2.a` returns 2 in that case, so
the client would have rejected the incoming card and desynced its inventory
against a trade the server had already committed).

*Verified:* unit (opcode/direction table, byte-exact payload shapes for
5110/5112/5113/5114/5116), e2e (the exchange flow now runs over the corrected
numbering). Mutation-checked: restoring the 2006 numbering and re-adding the
uid+flags bytes each fail a named test.

**Live-verified end to end** against the retail client, using a synthetic second
player built on `internal/testclient` (it logs in over the real socket, places
itself beside the target coach so the client can resolve the inviter actor, and
grants itself a card the shipped data says is tradable). Observed in the real
UI:

| Message | What the client did |
|---|---|
| 5102 invitation | showed *"ExBot t'invite à participer à un échange."* |
| 5103 answer → 5104 result 3 | **opened the trade window** with both panels |
| 5105 add card (i32 template) | server staged it |
| 5110 card added, 15-byte payload | **the card appeared in the trade panel** |
| 5107 remove card | server unstaged it |
| 5112 card removed | **the card disappeared** |
| 5113 | sent when a non-tradable card was staked |
| 5114 | showed *"Proposition d'échange annulée"* |

That last row is the clearest demonstration of the bug: the server used to send
the end notice as **5111**, which this client implements as a *client-sent*
message, so it was discarded in silence. The same is true of card-added, which
went out as 5109.

The result codes were confirmed at the same time: `ug_1`'s 5104 switch opens the
trade window on **3** (`nk.c()` → `sd()`) and shows the cancelled-invitation
notice on 1 and 2, which is what the server already sent.

*Not covered:* clicking **Oui** in the invitation dialog through the test
harness produced a refusal rather than an accept, so the accept was injected
instead. That is unexplained and is a harness question (click placement) rather
than a protocol one — an injected `accept = 1` is read correctly by the server,
and `tw_0.encode` writes `[i64 exId][i8 accept]`, exactly the order the handler
reads.

### B-092 - The two play-time statistics were never incremented

`Coach.TimeInFightSecs` and `Coach.TotalPlaySecs` were fully wired *except* for
the part that counts: declared on the model, written to the wire as the 2400
statistics panel's `dL`/`dM` entries, persisted by `CoachRepo.Save`, even
asserted in a packet test with fixture values — and incremented in no code path
at all. Both showed 0 for every player forever.

It went unnoticed because nothing displayed them prominently. Building the web
portal's account page, which shows "Time in fight" and "Time played" as their
own rows, made it obvious.

Fixed in two halves:

- **Play time** is stamped on the session in `completeLogin` and banked by
  `Session.creditPlayTime`, called at the top of `onClose` — deliberately
  *before* the replaced-session early return, since a kicked session's time was
  really played. It only mutates the in-memory coach; the incoming session owns
  the struct and saves it later, carrying the total with it.
- **Fight time** is stamped in `FightManager.Create` (the one chokepoint every
  fight passes through) and credited by `Deps.creditFightTime`, called from all
  three ways a fight can conclude — declared winner, forfeit, and teardown with
  no winner — and made idempotent with a CAS rather than trusting a single
  call site that a future path might bypass.

Practice fights count toward time. They are excluded from wins, losses and
ladder movement because those are competitive records; time spent is not.

*Verified:* unit (arithmetic, idempotence, sub-second and zero-timestamp
guards), e2e (`TestPlayTimeIsPersistedOnDisconnect` over a real socket, plus an
assertion added to the existing full-fight `TestChallengeVictoryConditionEndsFight`
so the victory path is covered), and live — a 1m48s retail-client session showed
as `1m 48s` on the portal, having previously always read `0s`.

### B-090 - Every player who logged in became a server administrator

`handleAuthentication` auto-created unknown logins with `admin=true` **and**
promoted every existing non-admin account to admin on each successful login:

```go
} else if !acc.IsAdmin {
    // Dev/preservation server: promote existing accounts so GM commands
    // work without a manual reseed.
    if err := s.deps.Store.Accounts.SetAdmin(acc.ID, true); err == nil {
```

That was a deliberate convenience, and while `is_admin` only gated chat GM
commands on a LAN server it was merely generous. It stopped being harmless the
moment the web portal hung **account deletion, admin granting and
impersonation** off the same flag: every player who had ever logged in would
have arrived at the site already holding the keys to everyone else's account.

Fixed by making the flag mean something: only the **first** account on a fresh
server is created as admin (matching what the web portal already did for web
sign-ups), and logging in never changes the flag. Admin is granted afterwards by
`seedaccount --admin` or the console's own grant button.

**Operator note:** accounts already promoted by the old code keep `is_admin` in
an existing database — the fix stops the bleeding, it does not rewrite history.
`SELECT id, name, is_admin FROM accounts WHERE is_admin = 1;` shows who has it,
and the console's *Revoke admin* button removes it.

*Verified:* unit (`TestLoginDoesNotGrantAdmin`, `TestFirstAccountBecomesAdmin`).

### B-089 - Fusion consumed the player's CHOSEN card as fuel

The 5490 request is `[i32 count]{i32 cardId}` and the handler read every id as
an input. The LAST one is the target.

The client builds the array as the input list with the chosen card inserted at
index 0 (`add.java`: `jg_02.v(0, ajt_16.azv())`) and `ahg_0.encode()` then
writes it REVERSED, so the chosen card lands last on the wire. `azv()` is
`cCr`, which the fusion panel exposes as the property **"fusionCard"** - the
card the player is trying to MAKE.

So the server was fusing the player's target away as fuel and then handing back a
RANDOM card from the set, ignoring their choice entirely.

**Fix.** The last id is parsed as the target and the outcome IS that card. It is
still constrained to the inputs' CardSet - a player-supplied target with no
constraint would let anyone name the best card in the game and fuse two commons
into it. The altar's slot count now bounds the input count too
(`"slotCount" = lab.azi() - 1`, from the newly decoded type 1100).

Failure now also reports the target as **notObtained**, which is what makes the
client show *"fusionRecipeFailed"* naming the card that was missed instead of a
bare *"fusionFailed"* (`cp_0`, case 5491).

**The target's own COST is enforced**, straight out of the client's formula:
`kardsPower` = Σ inputs' `RequiredLevel` − target's `FusionPower` must not go
negative, and the altar's quality must reach the target's `FusionQuality`. Only
7 cards in the game carry those (all type 27, set 149: power 5/15/30/50, quality
5/15/30) - for the other 900 both are 0 and the checks are no-ops, which is
exactly why they are safe to add. A refused fusion consumes nothing and names the
target as `notObtained`.

**Still approximated:** the success probability CURVE. The panel shows "labPower"
beside "kardsPower" (Σ inputs' `RequiredLevel` − target's `FusionPower`) and
"quality", but the server owns the roll and no client code reveals the curve. A
hard `kardsPower >= labPower` gate would be WRONG: 543 of the 907 cards have
`RequiredLevel` 0, so most fusions would become impossible. Left as a flat
chance, documented, rather than guessed.

**The altar is chosen by POSITION.** The six in-world altars are six different
TIERS of the type-1100 table (ids 2-7: power 1/10/20/30/5/15, slots 2/3/4/5/2/3),
so which one you use decides how many cards may be fed in. The client resolves it
that way - `xx_2`, the fusion-altar element, parses its own descriptor as a
single parameter, the lab-definition id, and looks it up with `CN.by(id)` - and
our element table already carried that value as `worldElement.arg` (2,6,4,3,7,5
for the six altars). The handler now picks the nearest fusion altar in the coach's
world instead of a fixed default. Nearest wins rather than requiring adjacency: a
legitimate client is always standing at the altar it opened, and a hard distance
gate would risk refusing real fusions over a stale coordinate.

**Verified:** `e2e` - the three fusion tests now send the real 3-id layout and
assert the chosen target is what comes back, and that a failed roll names it.
Both mutation-checked: reading the id from the wrong end yields `obtained 700,
want the chosen target 702`, and dropping the notObtained report is caught too.
`unit` - TestFusionLabPickedByPosition, mutation-checked against the fixed-default
behaviour.

### B-088 - The 8000 coach-deck blob carried the wrong ID NAMESPACE

`writeCoachCardBlob` emitted the coach's equipped cards as bare i32 **CoachCard
template ids**. That field is a list of **SPELL** ids.

**Proof, end to end in the client.** The coach deserialises the blob with

    public void L(byte[] byArray) {          // aez_0.L, and Te.L identically
        this.bMQ = new ajO(je_1.Wa(), 8);
        this.bMQ.b(byArray);
    }

`je_1 extends azk`, whose `E(ByteBuffer)` reads an i32 and resolves it in its
castable map. That map is filled ONLY by `apS` - its line 55 is the sole
registration - which iterates the SPELL records (`co_1`, type 220) and registers
one `yp_2` per spell under the spell id. Cards are a different registry
altogether: `eh_2` loads type-100 records into `la_0.XJ()` as `xj`. There is no
second source that could rescue a card id.

**It was wrong in both directions.** An id that misses is dropped and the client
logs *"impossible d'ajouter l'item"*. An id that HITS is worse: it renders an
unrelated spell as a castable action card. Measured: 65 of the 325 cards with
`HasUsableAction` collide with a real spell id.

**Fix.** `writeCoachActionDeck` replaces it and emits spell ids only.
`filterCoachDeckSpellIDs` drops anything the client could not resolve, de-dupes,
and caps at the client's own capacity of 8 (`new ajO(je_1.Wa(), 8)`), so the
wrong-namespace bug cannot be reintroduced by accident.

**The deck is empty today, and that is the correct output, not a stub.** Nothing
in the shipped data grants a coach an action spell - see the Open entry "Which
spell ids belong in the coach action deck" for what is still missing and the
leads for finding it. Filling in that one source is the only remaining change;
everything downstream of it is already correct.

**Verified:** `unit` - TestCoachActionDeckNeverEmitsCardIDs (equipped cards whose
ids deliberately COLLIDE with real spells still produce an empty blob) and
TestFilterCoachDeckSpellIDs (unknown ids dropped, duplicates collapsed, capped at
8); both mutation-checked, the first against the old card-id behaviour.
`live` - a real fight still creates cleanly, placement phase renders, client log
error-free.

### B-087 - The AI walked through and onto sudden-death cells

Found by auditing the movement flood after the Killer-tile fix, on the theory
that if one lethal-cell class was unmodelled another might be. It was.

There are TWO movement paths and only one was guarded. A human's move goes
through `validateFightMove`, which rejects any path touching a cell sudden death
has removed. The AI calls `applyFighterMove` DIRECTLY on a path from
`reachableCells`, which checked `walkable` and occupancy but not `cellDestroyed` -
so the AI got a move no player could make.

Two consequences, and the second is the serious one:

- it could END its move on a destroyed cell, and `shrinkArena` kills whoever
  stands on one outright (HP to 0, no save, no resist);
- it could PATH THROUGH destroyed cells, which the client has flagged
  movement-blocked (`asF.bV`) - i.e. the server animating a walk the client
  believes is impossible.

**Fix.** `reachableCells` now skips destroyed cells, which is the shared source
for every AI movement behaviour and for the `/script` move command, and brings it
in line with what `validateFightMove` already enforced for players.

**Verified:** `unit` - TestPathfindAvoidsDestroyedCells asserts the cell is gone
as a destination AND that nothing routes through it, plus the end-to-end case
that the AI does not land on one. Mutation-checked: without the guard the flood
offers the destroyed cell and three separate paths route straight over it.

### B-086 - The AI froze: positioning and casting disagreed about what was castable

**Third self-inflicted bug from the repertoire work, found by watching a live
5v4 stall for eight rounds** - every demon on full AP and full MP, doing nothing
at all.

`moveIntoSpellRange` asked "could I cast anything from there?" using harm,
affordability and the targeting validator. `chooseAISpell` asked the same
question PLUS cooldown, cast-frequency limits and friendly fire. A spell that
passed the first and failed the second froze the fighter: it would not move,
believing it could already fire, and then would not cast.

**The live case was exact.** The Cra's spell 3 reaches 5-8 cells and its nearest
enemy stood at distance 8, so "it could fire". Its best spell (18, d38) was on
its 1-turn cooldown and everything else was range 2-5, so nothing was actually
castable - and it stood still, every turn.

**Fix.** `aiSpellCastableFrom` is now THE predicate, used by `chooseAISpell`
(from the caster's own cell) and `aiCanFireFrom` (from each candidate cell), so a
plan and the action that follows it cannot disagree. `aiFiringGap` also skips a
spell on cooldown or out of casts, so the AI does not walk toward one it could
not cast even from the perfect spot. `areaFighters` gained an explicit-origin
variant so the friendly-fire question can be asked about a cell not yet moved to.

Same class as making positioning consult the real targeting validator - and a
reminder that fixing that for RANGE only was half the job.

**Verified:** `live` - re-running the same challenge, all four demons now spend
their MP closing in (mp=0/3) where before they sat at mp=3/3 for eight rounds.
`unit` - TestAIDoesNotFreezeWhenTheOnlyInRangeSpellIsUncastable, mutation-checked
against the weaker positioning predicate.

Also in this pass: the AI **will not end a move on a Killer tile**
(`aiCellIsSuicide`). Watched live in the same fight - a Xelor closing on the
player's team stepped onto one and was dead at the start of its next turn,
because movement scoring only measured distance. Passing OVER one is still
allowed, since it fires at turn start; the Trap tile is deliberately not avoided,
as 10 HP is a cost to weigh rather than certain death, and refusing to path near
it would distort movement more than the damage is worth.
(`unit` - TestAIWillNotWalkOntoAKillerCell, mutation-checked.)

### B-085 - The AI would nuke its own team with area spells

**Self-inflicted, same review pass as B-084.** Friendly fire here is real and
authentic - `areaFighters` lands an area effect on allies, enemies and the caster
alike, and you are meant to position to spare your team. The AI had no idea it
existed, which did not matter while it cast one fixed spell chosen by CHEAPEST AP
(`pickBreedSpell`). Giving it a repertoire changed the selection to
HARDEST-HITTING, which systematically favours the area spells.

**Measured:** 15 of the damaging breed spells carry an area shape, and several
are the strongest their breed has - the Cra's best (spell 18, d38, affordable at
exactly 6 AP) is a size-3 T, and Iop spell 9 is shape 32767, i.e. *every living
fighter*, which damages the caster's whole team and the caster itself. Both were
in the live repertoires observed in the retail client.

**Fix.** `aiWouldHitOwnTeam` runs each candidate's HARMFUL effects through the
real `areaFighters` from the caster's actual cell (so the directional shapes
resolve exactly) and disqualifies the spell if any living same-team fighter,
including the caster, falls in the zone. `aiSpellHarmsEnemy` was split so
`aiEffectHarms` can ask the question per effect - a buff or heal riding along in
the same spell is not friendly fire.

The policy is deliberately strict: any friendly splash disqualifies the spell
rather than weighing ally damage against enemy damage. That is predictable and
cheap to reason about; the cost is declining a cast a human might judge worth it.

**Verified:** `unit` - TestAIAvoidsFriendlyFire (ally in the blast forces the
weaker single-target spell; ally moved clear or dead restores the AoE) and
TestAIWillNotNukeItself (a 32767 area is never cast, and no AP is spent trying).
Both mutation-checked by removing the gate, which reproduces the bug.

### B-084 - The AI would heal the enemy it was attacking

**Self-inflicted, caught by reviewing my own change before moving on.** Giving
the AI a spell repertoire (it previously cast one fixed spell) opened a hole:
`chooseAISpell` aims at the nearest OPPONENT and ranked purely by damage, so any
spell in the fighter's loadout became a candidate - including a heal or a buff.

**Why it was reachable, and not just theoretical.** Challenge demons are safe by
construction (`breedSpellRepertoire` filters to damaging spells), but they are
not the only AI-driven fighters. When a coach drops mid-fight,
`coachLeftFightOnActor` nils that team's session, and `isAIControlled` then hands
their fighters to the AI - carrying whatever spells the PLAYER equipped. The
targeting validator does not save us either: only 3 shipped spells carry an
enforced ally-only target mask (B-081), so a heal aimed at an enemy passes
validation and lands as a heal.

**Fix.** `aiSpellHarmsEnemy` gates every candidate in `chooseAISpell`,
`aiCanFireFrom` and `aiFiringGap`, so the AI neither casts nor walks into
position for a spell that would help its target. It is a deliberate WHITELIST of
harmful effect kinds (damage, leech, %HP, poison, AP/MP-scaled, instant death,
zone/line damage, AP/MP loss and steal, states, push/pull): an effect kind we do
not model reads as "not known to harm", so a new or unsupported effect is never
fired at an enemy on a guess.

**Verified:** `unit` - TestAINeverAimsSupportSpellsAtEnemies, mutation-checked by
removing the guard, which reproduces the bug exactly (the AI picks the heal and
spends all 6 AP on the enemy).

### B-083 - Fighter conditions were missing from CREATE_FIGHT (and the "effects" slot is not what the roadmap thought)

The fighter blob in CREATE_FIGHT ends with two id lists, and both were sent
empty. The roadmap filed this as "buff icons on reconnect/spectate - fill the
8000 effects/conditions slots". **The effects half of that is wrong**, and
filling it as planned would have caused a real bug rather than a missing icon.

**The effects list is the SPHERE BOARD.** `gn_0.b` reads
`[i16 count][i32 x count]` into a `jg_0` and hands it to
`gn_0.a(jg_0, vy_1, ib_2)`, which resolves each id through `akp_1` and then
**re-applies every effect of the object it finds**. `akp_1` is filled by
`dq_1`, whose `getName()` is `contentLoader.sphereBoard` - it is the
sphere-board node registry (types 900/901, 17 542 records, the largest
unimplemented system). Writing buff ids there would not draw an icon; the client
would look them up among sphere nodes and apply whatever shared the id. The slot
stays empty, now with that written next to it so the next person does not repeat
the assumption.

**The conditions list is real and is now filled.** It is
`[i16 count][i16 x count]`, read into `gn_0.uk` - the same container the
roster blob's evolution tail already fills through `et_2.uk` - and drawn on the
fighter's portrait. Sending it in CREATE_FIGHT is what keeps an injured fighter
looking injured after a reconnect or to a spectator, since both rebuild the fight
from that message. The client adds each id at a fixed level of 1
(`vy_1.b(id, (byte)1)`), so the remaining-fights counter has no slot here; it
travels in the roster blob, which does have a duration byte.

The count is capped at 255 for the same reason the roster writer caps it: a
corrupt row must not wrap the length and desynchronise the rest of the blob.

**Verification.** A fighter with two conditions puts both ids on the wire in
order; a fighter with none still produces a well-formed blob; and the existing
byte-exact layout test still passes, since the empty case is the same two bytes
as before. Mutation-checked by restoring the hardcoded empty list.

**Still open:** in-fight BUFF icons (the timed spell buffs) have no slot in this
message at all - the two lists here are sphere nodes and persistent conditions.
Restoring those on reconnect would need whatever per-effect message the client
uses during normal play, which is a separate piece of RE.

---

### B-082 - Matchmaking paired anyone with anyone

The queue took the first waiting coach in the same mode, so a 3000-strength
coach was matched against a 1000 instantly. There was no rating band and no
queue timeout.

Coaches are now paired only while their ladder-strength gap fits inside a band
that WIDENS with waiting - 300 points to start, +150 for each second either side
has been queued, both configurable (`world.match_band` /
`world.match_band_growth`, 0 disables the check entirely).

**The widening is why there is no separate queue timeout.** A fixed band on a
server with a handful of players online is a deadlock: the lone high-rated coach
waits forever and a timeout would only turn that into a failed search. Relaxing
the requirement instead means the search always terminates in a match rather than
in a giving-up. With the defaults, two coaches 1500 points apart meet after about
8 seconds, and two similarly-rated ones still pair instantly - fairness must not
add latency to the common case.

The band grows with the LONGER of the two waits, not the shorter: waiting earns
a wider net, and using the shorter wait would let a freshly-queued coach veto a
match for someone who had been waiting for minutes.

**These numbers are ours.** The client has no say in matchmaking - it sends a
search and is told about a match - so nothing here is recoverable from retail
data, exactly like the post-fight constants already flagged as honest limits.
Said so at the definition rather than leaving it to be assumed.

Default for existing embedders is unchanged: `NewMatchmaker` starts with the
band disabled and only `cmd/server` applies the configured values, so the e2e
harness (which builds Deps directly) pairs instantly as before.

**A flawed test caught itself.** The first version probed the same matchmaker
repeatedly as the clock advanced - but a failed Search ENQUEUES its searcher, so
the second and third probes paired with each other instead of with the waiting
coach, and the assertion failed for a reason that had nothing to do with the
band. Each probe now runs against a fresh queue. A second bug in the same test
was plain arithmetic: 11 x 150 is 1650, not 1800, so the "should now pair" case
was asserted one second too early. Both were mistakes in the test, and both were
worth fixing rather than loosening.

**Verification.** The exact boundary either side of the qualifying second,
instant pairing for close ratings, band 0 pairing anyone, the longer-wait rule,
and the pre-existing mode filter still refusing cross-mode pairs.
Mutation-checked by dropping the band check and by taking the shorter wait.

---

### B-081 - Spell-level target masks were decoded and never evaluated

`TargetMasks` (field 22) are CAST-level target conditions, distinct from the
per-effect conditions that filter an area's expanded targets. 202 of the 203
shipped spells carry one, but the client only APPLIES the check when the spell's
`EnforceTargetMasks` flag (field 19, `eF()`) is set - and exactly three
spells set it:

| spell | mask | meaning |
|---:|---|---|
| 468 | `4` (bit 2) | the target must be an **ally** |
| 83 | `36` (bits 2+5) | an ally **and** summoned - an allied summon |
| 449 | `1<<62` | the target must be a ground **effect area** |

The first two are plain per-effect condition bits, so the existing evaluator
decides them with no new machinery. The third is not: bit 62 lives in
`aLc.n(ack_1)`, which asks whether the target is a live trap/glyph rather than
a fighter - a targeting MODE this server does not model, since casts here aim at
a cell or the fighter standing on it, never at a ground area.

**A mask carrying any bit this evaluator cannot represent is skipped whole.**
Judging spell 449 with the fighter evaluator would reject every cast of it,
which is a worse outcome than not enforcing a rule at all, and half-enforcing a
mixed mask is not the rule either.

**The mutation test caught a worthless assertion here.** The first version of
the "unrepresentable bit" test used spell 449's own mask, and it passed with the
escape hatch REMOVED - because `targetConditionPasses` already ignores bits it
does not know, so a pure-unknown mask is permissive either way. The test proved
nothing. The case that actually exercises the escape is a MIXED mask (one
decidable bit plus one that is not), where partial enforcement and skipping
diverge; the test now asserts on that and fails when the escape is disabled.

**MaxActive is deliberately still not enforced.** Six spells carry it (8, 15,
46, 141, 167, 173 - buff spells, not summons: poison, AP boosts, all-element
damage%). The field's SCOPE is the unknown - whether the cap counts live
instances per caster, per target, or across the whole fight - and the client
side of it is a runtime counter that `apS` passes into `yp_2` rather than
anything readable from the record. Implementing a cap against a guessed scope
would change which casts are legal, so it stays decoded and documented.

**Verification.** Ally-only and ally+summoned masks (accepting the right target
and refusing the wrong one), the `EnforceTargetMasks` flag acting as the gate,
the mixed-mask escape, and a real-data canary pinning the three enforced spells
and their exact masks so a future data set that enforces more of them fails
loudly. Mutation-checked by removing the enforcement call and by disabling the
escape.

---

### B-080 - AoE shape 8 was unimplemented and the cross ignored two of its three arities

**Shape 8 (`acg_0`, "forme a base de points")** fell through to a single cell.
It is an explicit list of `(dx,dy)` offsets from the centre: `acg_0.a(int[])`
rejects an odd-length array outright and reads consecutive pairs, and its
parameter labels name them x1,y1,x2,y2... ("Liste de N points").

It is **directional**, which is the part worth getting right. The client's shapes
carry a symmetry flag `fi()` - true for the circle and the point, which look
the same whichever way you face, and FALSE for the T, the inverted T and this
one. The authored offsets sit in a fixed reference frame, which the labels state
outright: "prendre l'axe sud-est pour construire". So the list is rotated by the
caster->centre cardinal step exactly as the T shapes rotate their stem, and a
caster standing on the centre degrades to the centre cell, the same degradation
the T shapes already use. Malformed (odd-length) lists degrade rather than throw
the way `acg_0` does - this is attacker-reachable data.

One shipped row uses it: spell 469's action-125 effect, size `[0 0 -1 0]`.

**The cross (shape 3, `qv`)** applied `size[0]` to all four arms with a note
calling the other forms a rare approximation. `qv.a(int[])` in fact accepts
exactly 1, 2 or 4 lengths and rejects anything else, and the arm-to-axis mapping
is legible from the cell list it builds and confirmed by its own debug name
`"cross-h"+aeD+"b"+aeF+"-g"+aeG+"d"+aeE`:

    aeD = haut   -> (+n, 0)      1 param : all four arms alike
    aeF = bas    -> (-n, 0)      2 params: face-a-soi (+-x), then cote (+-y)
    aeG = gauche -> (0, -n)      4 params: haut, bas, gauche, droite
    aeE = droite -> (0, +n)

The cross is NOT directional (`qv.fi()` returns true), so the arms stay on the
grid axes - our existing non-directional handling was right about that much.

**Scope, honestly.** A dump of every shape/size combination across the spell AND
static-effect tables shows shape 3 carries exactly one size in every shipped row,
so the 2-/4-param work is forward safety rather than a live fix. It still beats
the status quo: the old code would have produced a WRONG footprint for those
forms rather than an obviously missing one. Shapes 7 and 10 exist in the client's
`zg_1` table and remain unimplemented - nothing ships them either.

**Verification.** Arity tables for all three cross forms with per-axis inside and
outside cases; an exhaustive equivalence test over r=0..3 and dx,dy=-4..4 proving
the 1-param form - the only one any record uses - behaves exactly as the old
implementation; and shape-8 coverage of the identity rotation, a quarter turn,
the zero-direction degradation and a malformed list. Mutation-checked by
unrouting shape 8 and by dropping the 4-param cross branch.

---

### B-079 - The "triggeree en zone" effect family was 1 of 6 implemented

Action 177 ("Perte de points de mouvement triggeree en zone") was implemented and
its five siblings were logged as unresolved no-ops. The client's `mh_2` table
shows they are ONE shape with six members:

| id | class | label |
|---:|---|---|
| 165 | `aez_1(fv_1.bam)` | Perte de points de vie **feu** triggeree en zone |
| 166 | `aez_1(fv_1.ban)` | ... **eau** |
| 167 | `aez_1(fv_1.bao)` | ... **air** |
| 168 | `aez_1(fv_1.bap)` | ... **terre** |
| 169 | `MM()`            | Perte de points d'**action** triggeree en zone |
| 177 | `vn_1()`          | Perte de points de **mouvement** triggeree en zone |

All six are the spell's own zone centred on the CASTER with the caster excluded,
so 169 is literally 177's body with AP substituted for MP (both now share
`applyZoneResourceLoss`), and 165-168 differ only by the element
`damageElement` returns.

The roadmap listed 165/166/169 - the three with shipped rows - and missed 167 and
168 entirely. They have no rows today, but they are the same class with a
different element constant, so including them costs nothing and omitting them
would leave the identical silent hole the moment data used them. An unimplemented
action id is a silent no-op, which is the failure mode worth designing against.

The elemental variants resolve through the ordinary pipeline
(`computeElementalDamage` -> `applyDamageRebound` -> `applyHPDelta`) rather
than subtracting HP, so resistance, rebound and damage transfer all apply, and
the magnitude is rolled PER VICTIM to match every other multi-target path here.

**Effect-row coverage: 502/533 -> 505/533 (94.2 % -> 94.7 %).** Remaining
unresolved: 9 action ids over 28 rows, down from 12 over 31.

**Verification.** Zone AP loss (drains in-zone enemies, spares out-of-zone ones
and the caster, does not touch MP), its clamp at 0, all four elemental variants
(footprint + the element `damageElement` returns), and a resistance case
proving it goes through the damage pipeline. Mutation-checked by unmapping 169
and by removing 165 from the fire branch.

---

### B-078 - Effective AP/MP were never derived, and StringU8 could crash every client

The last two Tier 0 items.

**1. Rooted/petrified fighters reported and SPENT resources they do not have.**
The client has two characteristic getters: `gn_0.c` returns the raw stored
value, `gn_0.d` returns the EFFECTIVE one, and `d` zeroes it:

    d(Lr.bqz /*MP*/): 0 if the fighter has avx_0.dew (petrified) OR dex (rooted)
    d(Lr.bqy /*AP*/): 0 if the fighter has avx_0.dew (petrified)

This server had no equivalent, which is not merely a cosmetic gauge issue as the
roadmap assumed. "Dommages par PM possede" scales off exactly this value, so in
the retail client a ROOTED caster's MP-scaled spell deals **nothing**, while we
were reading the raw MP and hitting at full strength.

`effectiveAP`/`effectiveMP` now mirror `gn_0.d` and are used by the
scaled-damage effect and by the AP/MP deltas in CREATE_FIGHT (so a resume or
spectate rebuilds the same gauges the client would derive). They are DERIVED,
not stored - refillFighter deliberately still refills the raw value, exactly as
the client keeps the raw characteristic, so a root that ends restores mobility
with nothing to restore. Rooted deliberately does not zero AP: a rooted fighter
can still cast.

**2. `Writer.StringU8` documented a 127-byte limit and enforced nothing.**
Several 2.70 decoders read that prefix as a SIGNED byte, so 128 bytes present a
length of -128 and crash the client's reader. That made it a **remote
client-crash vector**, not a style rule: the channel-chat path clamps the
message it echoes, but NOT the channel NAME, and both come straight off the
wire - so one client could crash every other client that received the message.

The writer now truncates. Enforcing it at the single choke point makes every
call site safe by construction, and the limit is applied to the ENCODED bytes
because that is what the prefix counts (the wire charset is cp1252, single-byte,
so cutting bytes cannot split a character). The existing call-site clamps are
left in place as belt and braces.

**Verification.** A table over 0/1/126/127/128/255/1000 bytes asserting the
prefix never exceeds 127 and never reads negative when signed, plus an
accented-text case proving the limit counts cp1252 bytes rather than the Go
string's UTF-8 length. For the getters: a state table (rooted zeroes MP only,
petrified zeroes both, unrelated states change nothing, raw values never
mutated) and a behavioural test that a rooted caster's MP-scaled spell deals
zero while an unrooted one deals damage. Both mutation-checked.

---

### B-077 - Dispel stripped summons of what they ARE, and Standing was thrown away

Two more Tier 0 items, unrelated except that both are one-line omissions with
outsized consequences.

**1. Dispel cleared the whole state map.** The buff half of applyDispel always
kept permanent entries ("dispel leaves permanent enchantments"); the state half
deleted every key unconditionally. Summon innate properties are applied at spawn
as INFINITE states - of the 53 shipped creatures **22 are rooted, 21 anchored,
18 stabilised, 15 intransposable** - so a single dispel made a stationary summon
mobile, or a carry-proof one carryable, for the rest of the fight. Those are not
enchantments to undo; they are what the creature IS.

Infinite states (>= infiniteStateTurns) now survive, which also makes dispel
agree with `tickStates`, which has always refused to age them, and with the
buff loop beside it.

**The client's model is richer, and is the eventual general fix.** Fighter
properties (rooted/anchored/intransposable/...) live in a REFERENCE-COUNTED
store: `Kt.g()` increments, `Kt.h()` decrements and removes at zero,
`c()` reads the count and `b()` is "count != 0" - and `gn_0` really does
read the count (`this.c(avx_0.deu) != 0`). So a summon's innate root and a
spell's root coexist as count 2, and removing either leaves the other. This
server's `States` map holds remaining TURNS, conflating "how long" with "how
many sources" - the same shortcut behind the buff-stacking gap. Keeping infinite
states is correct for every case the shipped data produces; counting sources
would additionally fix overlapping FINITE ones. Recorded rather than attempted,
because it touches skip-turn charges, ageing and removal-by-source-id.

**2. `Coach.Standing` was computed, then thrown away three different ways.**
Standing is the coach's EVOLUTION experience - a different axis from Strength,
the ladder rating - and the client derives the evolution LEVEL from it and pops
its level-up dialog when it changes. The post-fight META already computed and
applied it (`t.Coach.Standing += standing`, with the level transition logged),
but:

- `CoachRepo.Save`'s field map omitted the column, so every point died on
  relog. The column existed and was migrated; it was simply never written.
- The 2052 coach descriptor hardcoded `w.I32(0)`, so the coach's OWN level
  read as 1 however much it had earned.
- The 4096 actor-spawn record hardcoded `w.I32(0)` too, so every other coach
  visible in the world also rendered as level 1.

All three now carry the real value. **No wire layout changed** - both sites
already wrote an i32 in the right place, they just wrote a zero into it - so
this is a value fix, not a protocol change.

**Verification.** Store round-trip through Save/Get; byte-offset assertions on
both wire records; dispel tests covering a summon's four innate properties, an
infinite state on an ordinary fighter (a Masqueraider mask), and that a genuine
finite enchantment is still stripped. All five mutation-checked: reverting each
of the three Standing sites, and restoring the blanket state clear, each fail
the tests that claim to cover them.

---

### B-076 - Forced displacement walked straight past every trap

checkEffectAreasMove had exactly ONE caller - the voluntary walk path - so push,
pull, teleport, swap and throw all repositioned fighters with no trap check at
all. Shoving an enemy onto a glyph is a core tactic of this game, and its
absence also made every trap trivially avoidable: any displacement crossed them
for free.

**The client settles it, and gives the full trigger model.** `he_1.a(fromX,
fromY, fromZ, toX, toY, toZ, fighter)` partitions the live areas by whether
they contain the FROM cell and the TO cell:

| fires | when | meaning |
|---:|---|---|
| **10001** | in TO, not in FROM | **entered** the area |
| **10008** | in TO and in FROM | **stayed inside** it |
| **10002** | in FROM, not in TO | **left** it |

It is a pure position-change notification - nothing in it cares HOW the fighter
moved - and **eight distinct effect classes call it**, including `go`
(teleport, the class our applyTeleport comment already cited) and `aox_1`
(swap, the class our applySwap comment already cited, which calls it ONCE PER
SWAPPED FIGHTER).

The fix was correspondingly small, because checkEffectAreasMove already
implements the 10001 half of that partition exactly - `contains(arrival) &&
!contains(start)` - and its own doc comment already claimed it was "called per
step by applyFighterMove (and any server-driven reposition)". The repositions
were simply never wired. Teleport, swap (both fighters), push/pull and throw now
call it. Carry is deliberately excluded: a carried fighter is stacked on its
carrier and explicitly holds no ground in this server's model.

The push path checks HP after collision damage, so a fighter the impact already
killed does not also spring the trap it landed on.

**Trigger ids this server still ignores** (dumped from all 16 shipped type-210
templates): **10008** stayed-inside, **10002** left, **10003** (the ONLY trigger
on template 1016 "mauvaisOeil", so that trap can never fire here), and **10006**
(templates 2 and 1015). Three templates - 1017, 1018, 1019 - carry an EMPTY
trigger array and so fire from nothing. Their meanings are now recorded in
DATA-COVERAGE rather than left as a blank.

**A latent panic fell out of this.** The new "a shove springs a lethal trap"
test was the first trap test able to reach endFight - previously only a
voluntary walk could spring a trap, and the walker was never the last enemy in
those fixtures. endFight dereferences `deps.Log` unguarded, so a fixture
without a logger panicked the fight actor. Production always sets Log, so this
was reachable only from tests; the fixture now provides one rather than papering
over it with nil checks that would hide the next fixture mistake.

**Verification.** One test per displacement path (teleport, swap for both
fighters, push, throw), each mutation-checked independently by removing that one
hook. Plus the half of the partition that is easy to get wrong: a fighter shoved
from one cell to another INSIDE the same area has not entered it, so nothing
fires - that is the client's 10008 case, which this server does not implement,
and the wrong reading would have re-fired the walk-on effect.

---

### B-075 - Two anti-cheat holes: placement was a free teleport, casts skipped spell ownership

Both were Tier 0 items on the roadmap. Both were exploitable by a forged packet
from an otherwise ordinary client session.

**1. MoveToPlacementReq (8021) had no phase guard and no cell validation.** The
handler checked only that the fighter belonged to the requesting coach, then
assigned the coordinates verbatim. So the placement opcode worked at ANY time,
including mid-fight, which made it a free teleport: no MP cost, ignoring
rooting, tackle, walk-on traps and line of sight. It also accepted any
coordinate at all - off-map, into scenery or void, onto a cell sudden death had
destroyed, onto the ENEMY's starting area, or onto a cell another fighter
already occupied. That last one silently stacks two fighters on one cell and
corrupts targeting, tackle and LoS for the rest of the fight.

Now gated to PhasePlacement, and the cell must be one of the fighter's OWN
side's start cells - the same set the server seeded the team from, and the only
set the client ever offers - and free. The phase is read on the fight ACTOR
rather than in the handler, because the phase can advance while the message sits
in the mailbox. Altitude stays unvalidated, matching the movement path: (x,y) is
the unit of placement and the client owns per-cell z.

**2. castSpellByFighter never checked that the caster knows the spell.** It
resolved the id straight out of the 203-entry table, so a forged 8109 could fire
any spell in the game from any fighter. The equipment path (8107) has always
checked ownership via fighterHasEquipped; this closes the same hole on the spell
path, in the same place and style (deep, not in the handler - castSpellByFighter
already re-checks isCurrentTurn even though the handler did, and that
defence-in-depth is deliberate).

The check has to accept TWO sources, and getting this wrong would have been
worse than the hole. A real coach fighter casts what it has equipped
(Fighter.Spells, preloaded by the store on both fighter-load paths). But a
SERVER-DRIVEN fighter casts its single SummonSpellID - and that covers not only
summoned creatures but every AI opponent in PvE: challenge demons are built with
a domain.Fighter for breed and stats and an EMPTY spell list, their one spell
living in SummonSpellID. A naive "must be in Fighter.Spells" check would have
muted every demon in the game and broken all 39 challenges.

**Two e2e tests were codifying the defects.**

- TestPlacementMove drove the fight to the ACTION phase and placed from there,
  onto the arbitrary cell (2,9), with a comment stating outright that "the
  placement handler has no phase guard". Rewritten to place during placement,
  onto a legal start cell, plus a new TestPlacementRejectsIllegalCellsAndPhases
  covering off-map, outside-any-start-area, scenery, the enemy's start cell, and
  8021 after the phase has passed.
- TestCombatSpellDamage cast spell id 0 from the synthesized "Champion"
  placeholder - the fallback fighter the server invents when a coach has none -
  which owns nothing. It now creates real fighters that own the spell they cast,
  which is what a real client does.

Fixing them exposed that the combat e2e fixtures never created fighters at all:
every one of those fights ran on the placeholder. buildFighterBlob now takes
spell ids, and matchIntoFight lets a test prepare its coaches and stop before
any phase gate.

**Verification.** Unit tests cover both legitimate spell sources and the demon
case explicitly; e2e covers legal placement, four illegal cells, wrong-phase
placement, and a forged cast that must neither damage nor spend AP. Every
assertion mutation-checked: removing the phase gate, removing the cell
validation and removing the ownership check each fail the tests that claim to
cover them. The e2e suite was run three times end to end for flakiness, since a
shared helper used by nine tests changed.

---

### B-074 - np_1 rule types 12 and 14 were decoded but nothing consumed them
B-071/B-073 decoded every 
p_1 element, including the three type-12 fight-start
effects and the nine type-14 victory conditions. Both were then carried, inert:
12 of the 39 shipped challenges were playing by rules the server had read and
ignored. The "Defi du temps" ("time challenge") demons in particular had NO win
condition at all - the only way to finish one was to eliminate the whole demon
team, which is not what the challenge asks for.

**Type 14 - alternative victory conditions.** Read content.55 first, as the
method demands, and it stops at entry 1: the client cannot even DISPLAY a type-4
condition. It goes further than that. wi_0.a(mv_1) hands the decoded condition
to the fight via mv_1.b(mp_2), and **mv_1.b is an empty method**; the
three-argument evaluator (mv_1, yg_0, yg_0) has **no call site anywhere in the
client**; and h()/i()/j() (is_necessary, victory_points, affected_team)
have no callers either. Retail arbitrated victory conditions entirely
server-side and the client kept the machinery as dead reference.

What IS recoverable is the CONDITION, because each of the four mp_2 subclasses
is a one-line body. qk_1 names them and jm_0 - the only subtype the shipped
data uses - is simply:

`java
return mv_12.ZB().JI() > this.JI[0];
`

JI() returns NC, incremented in cn_0.dm() on each timeline wrap: the same
table-turn counter this server calls 	ableTurn. So subtype 4 is "the round
counter passed N", strictly greater.

Three independent things agree on the reading, which is what makes it safe:
qk_1 labels subtype 4 **"Atteindre un tour donne"**; the nine holders are
challenge 14 plus **"Defi du temps : Poison / Violence / Pont mortel / Kawotte /
Lac / Quai des brumes / Altruisme"** and its finale - literally *time*
challenges; and the parameter is 20 or 30 turns. Survive to the turn and you
win. None of them touches sudden death, so the default collapse at turn 15 still
lands first and the last 5-15 rounds are fought on a shrinking arena. That is
the mechanic, not an accident.

**The arbitration is ours and is labelled as such.** ffected_team is the only
field that could name a winner, it is 0 on all nine, and the client never reads
it; we read it as the team index it is named for. This server builds a PvE
challenge with the coach as team 0, so the shipped value makes the coach win by
surviving. ictory_points (all 0) and is_necessary (all true) would matter
only for scoring several partial conditions, so they are carried and
deliberately unused rather than guessed at. Subtypes 1/2/3 are documented from
their client bodies but NOT implemented - no shipped record uses them, so there
would be nothing to validate against.

checkFightEnd gained an explicit decided-winner path, because a fight can now
end with **both teams still standing** and a survivor count cannot express that.
Nobody is killed to make the result work: downing the loser would have been the
easy shortcut and would have silently destroyed evolution fighters, whose deaths
are driven by HP rather than by the result.

**Type 12 - fight-start effects.** Applied through the same path round event
cards already use (pplyRoundEvent): each fighter is both caster and target so
a percentage scales off its own stats, and every effect is still gated by its own
target conditions.

That last part turned out to be the real work. The three effects carry target
mask **1024**, and B-073 recorded that as needing "the client's aLc evaluator, a
separate open item". That was over-cautious - 	arget_conditions.go already IS
a port of Lc.a; it was simply missing bits 512/1024, which are one line each:

`java
(0x200 & c) != 0 && (!(t instanceof gn_0) || t.NY().lV() != xq.axE.lV())  -> reject
(0x400 & c) != 0 && (!(t instanceof gn_0) || t.NY().lV() == xq.axE.lV())  -> reject
`

xq.axE is breed id **0**, the stat-less pseudo-breed listed between xD(-1)
and the 14 real breeds. So 512 = "is a creature", 1024 = "is a real player-breed
fighter". **An unimplemented condition bit is silently permissive**, so without
them the +40% dodge would also have landed on every summon - the mask is there
precisely to stop that.

While confirming which class our validator ports: the file credited **ap.a**,
but ap is a genuinely different validator (its low bits are is/is-not pairs
and its 512+ bits are count thresholds). Our port matches Lc.a bit for bit.
The wrong attribution is what sent B-073 looking for a second evaluator that did
not need to exist; corrected.

**Verification.** Two real-data canaries assert the shipped shape (9 conditions,
all subtype 4, param 20 or 30, (true, 0, 0); 3 start effects, action 122,
params [40], targets [1024]) so a future field-order slip fails loudly instead of
silently disabling the mechanic. Behavioural tests cover the strictly-greater
boundary, a fight ending with both teams alive, the winner coming from
ffected_team rather than a hardcoded side, an unknown team being skipped, and
fights without conditions being untouched. Each was mutation-checked: > to
>= and dropping the ffected_team read each fail multiple tests, and
removing the 1024 check reproduces the summon-buff bug.

**Not done, deliberately:** subtypes 1/2/3, ictory_points scoring, and the
np_1 rules that still have no consumer (budget, roster limits, spell/equipment
and class bans, prices, arena choice, event lists).

---

### B-073 · Challenges 29/30/31 stopped short on an inline, unlength-prefixed effect
B-071 left three challenge records deliberately unfinished: each carries an `np_1`
type-12 parameter ("Lance un effet sur tous les combattants à la création du combat")
whose trailing `Ht` effect is **inline with no length prefix**. Every other effect on
this format is length-prefixed — `decodeEffectList` slices the blob first — so the
existing decoder could stop reading early with no consequence. An inline effect can
only be passed by parsing it **exactly**: a byte too few or too many desynchronises
every field after it.

**The fix was one field short of free.** `decodeEffectBlob` already read through field
19 (the i64 target masks); the full `Ht` record is just **two trailing flag bytes**
longer (`beL`/`beM`, getters `Tj`/`Tk`, which the client hands straight to its runtime
effect constructor and whose meaning is not established). Reading those two makes the
decoder self-delimiting, so it was split into `decodeEffectCursor` (consumes a
caller-owned cursor exactly) with `decodeEffectBlob` as a thin wrapper. Nothing about
the length-prefixed path changes.

**All 39 challenge records now decode to zero residual bytes** (was 36).

**The decoded values are the real evidence this is byte-exact.** All three effects come
out as:

```
container "FIGHT_PARAMETER"   action 122   params [40]   duration [63 0]
```

Every one of those is independently meaningful: `FIGHT_PARAMETER` is a container type
we had not seen, and it is exactly what a rule applied at fight creation should say;
action **122** is the dodge-GAIN action from the same `mh_2` table as the tackle stats
(B-063); `[63 0]` is the same infinite-duration marker the `FIGHTER_CONDITION` rows
use. A misaligned read does not land on four coherent values at once. So challenges
29/30/31 each grant **+40% dodge to every fighter for the whole fight**.

**The guard test did its job.** `TestChallengeTailReal` pinned those three ids with a
message saying "an inline-Ht parser must have landed; move it out of the blocked set" —
and that is exactly how the change announced itself, failing loudly on all three the
moment the parser worked. The blocked set is gone and the decoded effect values are now
asserted in its place.

**Still NOT applied.** The effect is decoded and carried, not executed: rule type 12
would need the fight-start application path, and its target mask (`[1024]`) needs the
client's `aLc` evaluator, which is a separate open item. Half-wiring it against a mask
I cannot evaluate would be worse than leaving it inert and documented.

**Verified:** `unit` — 39/39 challenges consumed exactly; the three inline effects
asserted field by field; a synthetic well-formed inline effect consumed to the byte
(a sentinel placed immediately after it must still read back, which is the assertion
that actually proves exactness); and a truncated inline effect failing the decode
rather than returning junk.

### B-072 · The turn clock and sudden-death turn were hardcoded — and package-global
Two fight rules the data actually specifies were invented constants in this server:
`turnClock = 30s` and `suddenDeathTurn = 15`. Both are `np_1` rule types (10 and 11,
decoded in B-071), so the data was there to read as soon as the element layout was.

**The second half of the bug is worse than the first.** Both were **package-level**,
so a fight that changed either would have changed it for *every other fight in the
process*. Nothing set them at runtime yet, so it had never fired — but wiring the
ruleset without noticing would have introduced a genuine cross-fight leak on the very
first challenge that customises a turn.

**Fix.** A per-`Fight` `Rules` struct resolved from the fight's parameter list at
creation, with `turnClockFor()` / `suddenDeathTurnFor()` accessors that fall back to
the package defaults. The existing test hooks keep working because the defaults are
what `defaultFightRules()` reads.

**THE TIMING RULES ARE DELTAS — my first version of this got that wrong.** I initially
applied both as absolute values. The client's own label table settles it:

```
content.54.10 = "[£1] secondes en {[+1]?plus:moins} pour jouer chaque combattant"
content.54.11 = "La mort subite a lieu [£1] tours plus {[+1]?tard:tôt}"
```

"N seconds **more/less**", "sudden death happens N turns **later/earlier**". The
`{[+1]?…:…}` construct selects wording from the SIGN, which only makes sense for a
signed offset. `suddendeath.go` had even recorded it already — "tournament rule cards
shift it by ±5/±10 turns" — and I did not read my own comment carefully enough the
first time. `content.54.*` is the authoritative per-rule semantics table and should be
consulted before implementing any further rule.

So challenge 46 ("Tuto de Baan") does not set a one-hour turn; it **adds** an hour to
the default. For a tutorial that must not time out on a player who is reading, the
effect is the same, which is exactly why the error would have been easy to miss.

**What the shipped data uses.** Of the 39 challenges, exactly **one** carries a
turn-duration rule (challenge 46). **No** challenge sets a sudden-death delta — that is
presumably tournament-side, and the mechanism is now in place for when those are
decoded. **Five** carry a bonus-cell multiplier (×2, ×2, ×5, ×10), now applied. Type
1000 ("Pas de limite de budget", used by challenge 12) is named but not enforced.

**Robustness choices:** a delta that would drive the value non-positive is IGNORED, not
applied — a zero-length turn clock would end every turn instantly, and a sudden-death
turn of 0 would shrink the arena from turn one. A multiplier of 0 or absent behaves as
×1, never ×0, which would silently disable every bonus cell.

**The multiplier covers the BENEFICIAL tiles only** — the five stat buffs and the
healing heart. The killer cell has no magnitude to scale, and the trap is a *piège*, a
malus: scaling it ×10 under a rule the client advertises as a *bonus* would be a
perverse reading of "il bénéficie de ses effets… lui apporter des PA, de la
résistance". Including the healing heart is a judgement call, flagged as such in the
code — nothing in the data distinguishes it either way.

**Verified:** `unit` — deltas in both directions (a negative one shortening the clock
and moving sudden death earlier); over-large negative deltas being ignored rather than
producing a zero clock; the multiplier being absolute while the timings are relative;
an unimplemented rule type inert rather than fatal; per-fight isolation (a customised
and a normal fight side by side, plus a zero-valued `Fight` still playable); and the
multiplier applied at ×2/×5/×10 with ×0 and "no rules" both behaving as ×1.

### B-071 · The `np_1` element layout — the last decode blocker on three records
`np_1` was the one unknown standing between us and the tail of the coach-card
record (fields 19-26), the tail of the challenge record, and parts of the
tournament tables. Its layout turned out to be plainly readable in
`np_1.k(ByteBuffer)`, cross-checkable against both its writer `cd()` and its size
function `nj()`:

```
[i32 type][i32 id][i32 parentId][u8 n][i32 × n params][i16 effectVersion]
  if effectVersion != 0: [i32 effectId][Ht blob, inline, NO length prefix]
```

**Two traps, both different from every other effect list in this format:** the
trailing effect is written **version first, then id** (the reverse of
`decodeEffectList`'s `[id][ver][len]`), and it has **no length prefix**.

**And `np_1` is polymorphic.** Exactly one of its 30-odd subclasses overrides the
read: type **14, "Condition de victoire"** (`wi_0`), which has no param array and
no effect, just `[i32 id][i32 parentId][mp_2 blob]`. Decoding it generically reads
the `mp_2`'s leading `i16` as a param count and desynchronises everything after —
which is precisely what happened to challenges 14 and 37..44, whose "effect
version" came out as the nonsense value 1024. That 1024 is the tell: it is an
`mp_2` type field being read one field too early.

**What the type enum turns out to be.** `ajr_2` names all 32 low types, and they
are a **fight-ruleset system**: budget, min/max fighters, banned or allowed
spells and equipment, class limits and prices, arena choice, event-list choice —
and notably **type 10 "modifies each fighter's turn duration in milliseconds"**
and **type 11 "modifies the sudden-death start turn"**, both of which this server
currently hardcodes. The 900+ block is per-breed spell parameters. Recorded in
`DATA-COVERAGE.md`; nothing is wired to it yet.

**Results.**
- Coach cards: **26/26 fields**, and all **907 records consume to exactly zero
  residual bytes**. A format that ends precisely where the decoder stops, 907
  times out of 907, is the strongest evidence a layout is right.
- Challenges: **36 of 39** records exact. The other three (29/30/31) each carry a
  type-12 parameter ("Lance un effet sur tous les combattants à la création du
  combat") whose inline `Ht` cannot be skipped without a full effect parser;
  `decodeParameters` stops there deliberately rather than desynchronise, and the
  test pins those three by id so the day someone writes that parser, it fails and
  tells them to move them out of the blocked set.

**An independent cross-check fell out of it:** exactly **7 cards** carry a pet
model id, and the client ships exactly **7 pet descriptions**
(`content.24.71/75/80/88/92/99/103`, "Ce familier Augmente les drops dans tous les
modes de jeu"). Two unrelated sources agreeing on 7 is worth more than either
alone.

Field names came from the few unobfuscated fragments in the jar: the fusion
laboratory's Xulor field names give `tz` = **labPower** and `tA` = **quality**,
and the method `setFighterColorIndex` gives `tD` = colour slot (0 hair / 1 skin /
2 eyes) and `tE` = palette index. `tB` is the pet model id — `aez_0.aQv()` spawns
one visual instance per owned pet from it. `tw`/`tx` are handed to the runtime
card object and never read again: dead in the client, decoded here only so the
record round-trips.

**Verified:** `unit` — zero-residual over all 907 coach cards and 36/39
challenges; the element decoded against the client's own size functions
(`np_1.nj()` and `wi_0.nj() = 12 + mp_2.nj()`); the inline-effect guard; and the
victory-condition case built from the exact byte pattern (type `1024`) that used
to be misread.

### B-070 · You could not create an evolution fighter at all
Recruiting from the **Évolution** tab produced a CLASSIC fighter. The evolution roster
could therefore only ever contain fighters that got there some other way, its
substitutes bench was permanently empty, and the tab refused to start a match.

The client says which roster it means, in the `type` byte of the `et_2` blob it sends
with FIGHTER_CREATE (1 = classic, 2 = evolution). We decoded it —
`fb.Type = typ` — and then **never read it again**: the same "decoded but dead"
pattern behind most of this session's bugs. `buildFighter` never set `State`, so every
fighter defaulted to `FighterStateTitular`, `IsEvolution()` answered false, and the
fighter was serialized back as type 1 with no evolution tail.

**Fix.** A persisted `Fighter.Evolution` flag, set from the blob's type byte.

**It is deliberately separate from `State`,** and that distinction is the actual bug
underneath the bug. `IsEvolution()` used to be `State != Titular`, which conflates two
different things: the client buckets an evolution roster as **line-up = state 0 *or*
2**, bench = 1, graveyard = 3 (`xz_0`). So state 0 means "in the line-up", *not* "not
an evolution fighter" — and any correct implementation of recruitment was impossible
while the two were the same field. `IsEvolution()` now returns the flag, falling back
to the old state test so rows written before the column existed (benched, dead or
interred fighters, which could only have got there through evolution play) keep
working.

**Verified:** `unit` — a type-2 blob yields `Evolution=true` and a type-1 blob false,
both starting in the line-up; the legacy fallback across all four non-titular states;
and that the flag reaches the wire (type byte 2 *and* a longer blob, because the tail
is what files the fighter into the client's roster). `live` — a fighter recruited on
the Évolution tab came back `evolution=true state=0`, appeared in the roster with its
fatigue/morale bars and a 600/6000 budget, and the tab then started a real fight.

### B-069 · Challenge rewards were granted but never shown, and the card blobs were documented backwards
Two problems in the same three lines of END_FIGHT.

**1. The won-cards blob was hardcoded empty.** `awardChallengeRewards` grants the
cards and pushes the inventory, but 8300 reported none — so the results panel's
**"Cartes gagnées"** section was blank on the very fight that paid out. The player got
the cards and was told nothing.

**2. The two blobs were commented in the wrong order.** Our source said
`// lost cards blob` first, `// won cards blob` second. Traced through the client, it
is the other way round:

```java
YP.c(blob, bl2)   ->  arrayList = bl2 ? this.by : this.bz
   first blob is read with bl2 = false   ->  bz
   second blob is read with bl2 = true   ->  by
ajo_1:  bz -> "fight.wonCards"      by -> "fight.lostCards"
```

So the **first blob is WON**. Both were zero, so nothing was broken *yet* — but the
next person to fill them in from those comments would have shown players their
winnings in the "Cartes perdues" column, and the packet would have looked perfectly
well-formed while doing it. Wrong comments on a byte-oriented protocol are latent
bugs; this one is now pinned by a test rather than a comment.

**Format** (`YP.c`): `[u16 blobLen][u8 groupCount]{[u8 n]{[i32 cardId]}}`. An empty
list writes a zero *length*, not an empty group — the client only parses the blob when
the length is > 0. The granted list is expanded by quantity, because the panel shows
one icon per copy won rather than one per distinct template.

**Verified:** `unit` — the blob is decoded back field by field from a real
`buildEndFightFull` frame, asserting the WON list is the FIRST one (the test fails
loudly with "won cards must go first" if the order is ever flipped back), and that an
empty fight writes two zero lengths. `live` — challenge 11 paid out card 186 on a first
clear and the retail client parsed the enlarged frame with an empty `output.log`.

**Visually confirmed** (after B-070 made the Évolution tab usable): challenge 12 paid
out cards 183/188/192 on a first clear and the results panel rendered **three card
images under "Cartes gagnées"**, where it had always been blank.

### B-068 · Every string on the wire was the wrong charset
The server wrote and read UTF-8. The client does neither. Both of its string paths
name **no charset at all**:

```java
read:   this.setName(new String(byArray));      // aez_0.V, gn_0, sw_1, ta_0, axD…
write:  byte[] byArray = this.bY.getBytes();    // acS, aey_0, afy_2…
```

Both take the JVM **platform default**, and the shipped client runs on the bundled
**Java 1.6**, whose default is the OS code page — UTF-8 only became Java's default in
18. Confirmed at runtime against the live client rather than assumed:

```
Charset.defaultCharset().name()  ->  windows-1252
```

**Two bugs, and the second is the worse one.**
1. *Outbound*: every accented literal we send was mangled. Spotted live — the
   challenge opponent "Défi" rendered on the end-of-fight panel as `DÃƒÆ'Ã‚Â©fi`.
2. *Inbound*: an accented name or chat line **from the player** is not valid UTF-8
   (`é` is the lone byte `0xE9`), so it decoded to replacement characters — and then
   got **persisted** that way. Corrupting stored data is worse than rendering it
   wrong, and nothing was watching for it.

**Fix.** A single `EncodeText`/`DecodeText` pair in `internal/protocol` (cp1252 via
`x/text/encoding/charmap`, already in the module graph), used by every string helper
on both the reader and the writer. Three call sites were hand-rolling
`I32(len(s)) + Raw([]byte(s))` and bypassing the helpers entirely — chat, ladder and
matchmaking — so they were fixed to delegate; chat is exactly where players type
accents. `internal/testclient` encodes the same way, so the e2e suite now sends what a
retail client sends.

**The subtle part is the length prefix.** It counts **encoded** bytes. "Défi" is 4
runes, 5 bytes in UTF-8 and 4 in cp1252 — so the old code wrote a prefix that
disagreed with its own payload for any non-ASCII string, desyncing every field after
it in the frame. There is a test dedicated to that (a sentinel byte after the string
must still be readable).

A rune cp1252 cannot represent is written as `?`, matching Java's own encoder, so the
byte count stays honest.

**Verified:** `unit` — the exact cp1252 bytes for "Défi"/"Démon"/"Maître d'élevage"
(and `€`, which is what makes this cp1252 rather than latin-1), round trips for 11
accented strings, the byte-accurate length prefix at all three widths, the
unmappable-rune fallback, and that decoding never fails for any of the 256 byte
values. `live` — an accented chat message now round-trips client → server → client and
renders correctly as **"Café"**.

**Residual — and my first write-up of this claimed more than it should have.** I wrote
that the end-of-fight panel was fixed "because it is fed by the same encoder". It is
not, and the truth is more interesting: **the client itself mangles server-provided
NAMES, and no server-side encoding can prevent it.**

Established with two controlled experiments (the coach renamed in the DB, the frame
bytes dumped from a unit test, the result read off the screen):

| stored name | bytes we send (correct cp1252) | client renders |
|---|---|---|
| `Loové` (`E9`) | `05 4C 6F 6F 76 E9` | `LoovÃ©` |
| `LoovÃ©` (`C3 A9`) | `06 4C 6F 6F 76 C3 A9` | `LoovÃƒÂ©` |

Each input gains **exactly one extra UTF-8→cp1252 hop**. That rules out a workaround:
to display `é` the client would have to receive a string whose mangle *is* `é`, i.e.
byte `E9` decoded as UTF-8 — which is not valid UTF-8. Pre-compensating makes it
strictly worse, as the second row shows. The fight panel shows the damage twice
(`Défi` → `DÃƒÂ©fi`) because the name passes through the mechanism twice: once onto
the coach object, once into the results-panel property.

Message BODIES are unaffected — an accented chat message renders correctly — so this
is specific to the name path, not to our encoder.

**Conclusion: the server is right and stays as it is.** Our writers emit correct
cp1252 on every path (`writeFightCoachBlock`, `buildVicinityMessage`,
`EncodeCoachInformations` all dump `…76 E9`). The remaining defect is in a client we
cannot change. What I did **not** do is locate the exact client code performing the
extra hop — the evidence is behavioural, not a decompiled line — so the open item is
"find the mangling call in the client", not "fix the encoding".

### B-067 · 325 usable coach cards did nothing, because the decoder threw their effects away
The card decoder walked the `akw_0` effect array (field 15) only to sniff out the
resurrection percentage and **discarded every other effect**. So of the 907 coach
cards, the **325 flagged usable** — every healing potion, rest balm, morale boost and
blessing — were inert: dropping one on a living fighter hit a handler that only knew
how to resurrect the dead and returned silently.

That made the wound layer from B-066 a **one-way ratchet**: a roster could accumulate
injuries forever with no way to repair them.

**Fix.** Keep the whole effect list on the card (decoded with the shared `decodeAkw`,
the same one card sets and conditions use) and derive `ResurrectPercent` from it, then
extend `FIGHTER_USE_ITEM` (22099) so a card dropped on a LIVING fighter applies its
consumable actions. Each is transcribed from the client class that implements it —
note every one has two methods, a passive `a(et_2)` that only annotates the post-fight
report and a consumable path that mutates the fighter for real:

| AI | usable cards | what the consumable path does | client |
|---|---:|---|---|
| 11 | 30 | heal LIGHT wounds, per-wound roll at x% | `aic_1.c` |
| 5 | 30 | heal SERIOUS wounds, per-wound roll at x% | `ze_1.c` |
| 16 | 8 | `fatigue = clamp(fatigue + x, 0, 100)` | `cm_1.c` |
| 9 | 8 | `morale = clamp(morale + x, 0, 100)` | `cc_1.e` |
| 2 | 4 | permanent XP, capped at 50 000 | `adl_2.c` |
| 15 | **165** | apply condition `[id, duration]` | `vm_2.c` |

The AI-15 duration is used **as-is**: the passive path adds +1 so an equipped card's
condition survives the fight it was applied in, which is meaningless for a card used
out of combat.

**Design choice: a card that changes nothing is NOT consumed.** Unlike the resurrection
gamble — where the card is spent on a failed roll because the roll *is* the point — a
healing potion dropped on an unwounded fighter is refused and kept. A mis-drop should
not destroy an expensive card.

**Why keeping the whole array mattered, concretely.** The live check healed a fighter
carrying `[1 4 7 9]` (2 light + 2 serious) and the result was `[17 20]`, which looked
wrong until the cards were dumped:

```
card 320  AI 15 [17 5]  +  AI 11 [100]      "heal all light wounds, and gain condition 17 for 5 fights"
card 340  AI 15 [20 5]  +  AI  5 [100]      "heal all serious wounds, and gain condition 20 for 5 fights"
```

These potions do **two** things each. A decoder that kept one action per card — as this
one did for resurrection — would have silently dropped half of every such card's
behaviour, with nothing to indicate it.

**Verified:** `unit` — healing by severity (a light potion must not clear a serious
wound), the no-op refusal, fatigue/morale clamping, the XP cap, AI-15 duration and its
exclusion rule, the usable-flag gate, and cross-coach ownership. `real-data` — a canary
pinning 907 cards / 325 usable and the per-action counts (4/30/8/30/4/165/8), that every
usable AI-15 effect carries both params, and that the resurrection percentages still
decode after the refactor. `live` — the real 22099 opcode healed all four wounds off a
fighter and applied both potions' 5-fight buffs.

### B-066 · Fights left no mark: the wound / condition layer did not exist
Type 902 — 111 records — was undecoded, `domain.Fighter` had no conditions, and the
evolution tail shipped a hardcoded `conditionCount = 0`. A fighter could fight forever
and come out untouched: no wounds, no permanent death from injury, and ~30 card-set
effects with nowhere to apply.

**What a condition is.** A persistent status carried BETWEEN fights: the wound layer,
the blessings a coach card grants, and the curses. Decoded from `ahm_1`:

```
[i16 id][i8 grade][i16 type][u8 n]{n × akw_0}[i32 m]{m × Ht}
```

`grade` is the default duration in FIGHTS (-1 = permanent, which every wound is), and
`type` is a mutual-exclusion class. The record needed **no new primitives** — `akw_0`
is the same structure card sets use and `Ht` the same one spells use, so both existing
decoders were reused verbatim. **Field coverage 5/5, zero unknowns.**

Every record carries **either** meta effects **or** in-fight effects, never both
(54/57, asserted in the canary) — which is what lets the apply path route a condition
by inspecting a single list.

**The wound table**, and note where it lands:

| wound | light | serious |
|---|---|---|
| leg | −20% **dodge** (action 123) | −1 MP (18) |
| arm | −20% **block** (action 121) | −1 AP (14) |
| head | −10% XP (meta AI 1) | −20% XP (meta AI 1) |
| torso | −5% resistance (81) | −20% resistance (81) |
| other | −10 initiative (77) | −1 morale (meta AI 9) |

Actions **121/123 are the block/dodge-down actions wired in B-063**, so the wound layer
plugs straight into the tackle model: a leg wound makes you easier to pin, an arm wound
makes you worse at pinning. Card equip effects and condition effects now resolve through
one shared `applyPassiveEffect`, because they are the same kind of thing — an always-on
`Ht` row.

**Apply rules** (`vm_2.a`), all three easy to get backwards:
- **One per type, FIRST wins** — an existing wound on a body part blocks a new one; the
  newcomer is dropped, not swapped in.
- **Type 21 is exempt** and stacks without limit.
- **Type 70 is refused** on this path (it is reached only via the Sphere Board hook).

**The wound roller** (`bf_1.b` — which has *zero callers in the client*, i.e. it is
server logic that happens to ship inside `core.jar`, so it could be reproduced rather
than invented):
1. A wound on a body part — light **or** serious, via a deliberate switch fall-through —
   excludes that part from the draw.
2. Upgrade if 3+ light wounds, or all 5 parts wounded, or a d100 under
   `lightHeld² × 10` (10 / 40 / 90% at 1 / 2 / 3 light wounds).
3. Upgrade while already holding **3 serious wounds → the fighter dies for good**.
4. Otherwise upgrade in place: remove a light wound, add the serious one of that part.
5. Else add a light wound on an unwounded part.

**Injury and death chances** (`adl_0.atd` + `ate`): `injury% = totalXp / 1000`, then
`death% = injury²/100`, then fatigue amplifies the injury chance. The shape is worth
reading twice — **a veteran is far more fragile than a rookie** (10 000 XP → 10% / 1%;
50 000 XP → 50% / 25%), and a rookie's zero chances auto-set the cancel flags that spare
it entirely.

**Two shipped-client quirks reproduced deliberately, not fixed:**
1. The draw pool is built from body parts **1..4 only**, so the roller can never inflict
   a light "other" wound. Diverging would change our wound distribution away from retail.
2. When every drawable part is already wounded the client calls `nextInt(0)` and
   **throws**. A fight actor must not panic, so we report "no injury" instead — the only
   safe reading. Covered by `TestWoundRollNeverPanics`.

**Honest limit:** nothing in the client decrements the duration byte, so the per-fight
countdown is a server choice. The evidence for it is `vm_2.a` adding +1 to a card-applied
duration "so it survives this fight", which only makes sense if the tick happens once per
fight at the end. We expire AFTER the wound roll, so a wound taken this fight is not
immediately aged.

**Verified:** `unit` — the 111-record canary (population, the meta/fight split, all 10
wounds' ids/types/payloads, the light↔serious symmetry), the apply rules, expiry, the
three roller outcomes, the two no-panic states, healing by severity, and wounds actually
changing AP/MP/block/dodge through the same path cards use. `live` — ~120 real evolution
fights: light wounds appeared, upgraded into serious wounds, **two fighters died**, and
the retail client rendered it — the wound count as skull icons (3 and 4, matching the
server's `conds=3`/`conds=4`), dead fighters as **RIP gravestones**, plus the fatigue
("Zzz") and morale bars — with an empty `output.log` throughout.

### B-065 · No fighter ever gained XP: the post-fight report was never sent
END_FIGHT (8300) carries a **per-fighter debrief record** — the client's `adl_0`,
read back as `OW` — and the server sent a count of **zero**, forever. Consequences:
the evolution debrief panel (`fightResultEvolutionDialog`, which binds all 13 of its
exposed fields) had nothing to render, and no fighter gained XP, morale or fatigue
from playing. Coach reputation was likewise hardcoded to 0, so
`standing += amW()` in `WE.java` always added nothing and the level-up dialog could
never fire.

The byte was also **mislabelled in our own source** as "object stats count", which is
probably why it stayed at zero: `YP.a()` lines 90-97 read it as
`[u8 n]{[i64 fighterId][i16 len][OW blob]}` → `cbF.a(fighterId, new OW(bytes))`.

**Why this was worth doing first:** it is the single shared blocker for two whole
subsystems. 78 already-decoded card-set effects and the entire type-902 condition
layer are inert *only* because there is no report for them to modify.

**Implemented (slice 1 — XP, morale, fatigue, reputation).** Every formula is
transcribed verbatim from the shipped client, because `core.jar` contains the
*shared* client/server code — the real server's arithmetic is literally in the jar:

| Rule | Source | Behaviour |
|---|---|---|
| XP | `adl_0.a(base, hours, morale)` | `base * (100+morale)/100`, then `+50%` if idle **> 12 h**. The morale value **is** the bonus percentage. |
| Fatigue recovery | `et_2.a(fatigue, hours)` | `(sqrt(f) - sqrt(h-1))²` — accelerating: 100 → 0 takes 101 h, 25 → 0 takes 26 h. |
| Fatigue cost | `adl_0.a(t, h, true)` | `+rand(25)` per fight, capped at 100; at the cap the fighter is **exhausted**. |
| Morale drift | `adl_0.dg` | Damped by distance from the extreme — a win moves by `(100-morale)/50`, a loss by `morale/50`, so morale converges instead of pinning. |
| Fighter level | `nr_0.cs` + `PP` | 1..6 at 860 / 4 000 / 10 000 / 20 000 / 40 000 XP. |
| Coach evolution level | `aet_0.nJ` / `nr_0.ct` | `max(1, min(sqrt(standing/10), 50))`, inverse `n²*10`. |
| XP cap | `et_2.ft` | Gains refused once spendable XP reaches 50 000. |

**Two numbers are NOT client-derived and are flagged as such in the code**:
`baseXPPerFight` and `standingForResult`. Both arrive on the wire pre-computed
(`cnr`, `YP.cbG`), so the real server's formula for them is not in the jar.
Everything they flow *through* is exact; only the seeds are ours, and they are single
named constants so they can be replaced the moment evidence appears.

**Design note — the guard is on EVOLUTION, not on "not practice".** A GM/solo
evolution fight is flagged practice as well, so testing `Practice` alone would skip
exactly the mode the whole debrief exists for. `fightFeedsProgression` therefore
returns true for any evolution fight, and false for plain practice and for
challenges (the client is explicit: *"tu n'auras pas de fatigue ni de blessure ou de
mort dans un défi du temps"*).

**Also:** 8300 is now sent **per coach** rather than broadcast, because
`standingWon` is a single scalar — one shared frame would credit the loser with the
winner's reputation. Spectators get a neutral copy.

**Verified:** `unit` — the 40-byte layout asserted byte-for-byte against
`adl_0.cd()` (including the signed `moraleDelta`), the XP formula across 7 cases
(incl. "exactly 12 h does not qualify"), recovery monotonicity, morale convergence at
both extremes, the level tables round-tripped for every level 2..50, and the XP cap /
clamping guards. `live` — a real fight logged `post-fight meta reports=7 killed=0
injured=0 standing=map[3:10]`, the retail client parsed the enlarged 8300 with **no**
`output.log` error, and the result screen still renders correctly.

**Not yet visually confirmed:** the evolution debrief *panel* itself. It only opens
when the client **exits its own fight state** (`ajo_1.a`, gated on fight kind 6), and
reaching a true evolution fight through the UI needs a second player — the Évolution
tab's "Tester" button starts a *challenge* (challenge=12), not an evolution fight.

### B-064 · The e2e combat flake was a wrong assumption, not a timing problem
`TestCombatSpellDamage` failed roughly 1 run in 4 on a loaded machine with `no SPELL_CAST
(8110)`. Two earlier "fixes" (a 30s→6s turn clock, and a collect loop that swallowed
`FIGHTER_TURN_BEGIN`) were real improvements but **did not touch the cause**, and the
failure kept coming back. Both were guesses at timing.

**Method that actually found it.** Reproduce on demand instead of waiting for luck: pin
23 of 24 cores with busy loops, and the failure goes from ~1-in-4 to **4-in-4**. Then log
each refusal branch server-side rather than reason about them. The first instrumented run
was decisive:

```
DIAGCAST dropped in handler casterID=1099511627776 nilCaster=false
    coachMismatch=true notCurrentTurn=false currentWire=1099511627776 turnIndex=0
```

`notCurrentTurn=false` — the turn was fine all along. **`coachMismatch=true`**: the test
was casting with a fighter belonging to the *other* coach, and `handleSpellCast` dropped it
silently (correctly).

**Cause.** The tests identified their own fighters with `isTeamAFighter()`, i.e. "team A is
side 0". But side 0 is simply **whoever reached the matchmaker queue first** —
`Matchmaker.Search` pairs the new searcher with the one already queued, and
`handleFight` builds `buildFightTeam(pm.a, 0)` / `buildFightTeam(pm.b, 1)`. The harness
fires A's and B's `Search` back-to-back with no happens-before, so under load **B can win
the race and A becomes side 1**. Every assumption then inverts: the loop casts with B's
fighter (dropped) and skips its own, burning all four attempts — exactly the observed
"cast, skip, cast, skip" pattern.

The server was right at every step; three tests were wrong (`TestCombatSpellDamage`,
`TestFightMove`, `TestPlacementMove` all shared the helper).

**Fix — make the tests side-agnostic rather than force the race.** An action for a fighter
you do not own is a silent server-side no-op, so a test can simply *try*:
- cast/move on **every** turn offered, using that fighter's own side-appropriate cells
  (`enemyStartCell`, `oneStepFromStart`);
- `TestPlacementMove` probes for ownership — the 8022 echo only comes back for a fighter
  the requesting coach owns, so the echo **is** the proof;
- the final assertion became "damage did not land on the **caster's** side" (`fighterSide`,
  computed from the wire id) instead of "not on team A";
- `isTeamAFighter` is deleted so the assumption cannot come back.

Also kept: B now **ends its own turns** instead of letting them expire, so rotation no
longer depends on the turn clock; the clock could therefore go 6s→**12s**, which removes
the *other* latent race (acting inside your own turn on a slow machine).

**Verified:** under the same 23/24-core load that gave 4/4 failures, the three combat tests
now pass **6/6**; the full e2e suite passes repeatedly under half-machine load (~70-82s,
barely above its idle 77s).

### B-063 · Tackle used a flat 67% instead of the fighters' real block/dodge
Tackle (zone of control) *was* implemented — this document and `STATUS.md` both wrongly
listed it as missing — but it rolled a **hardcoded 67%** evasion for every fighter against
every holder, with a comment admitting "the per-side Evasion modifier is not modelled yet
(no fighter evasion stat)". The stats existed all along; nothing read them.

**The characteristics.** `Lr.brd` = block %, `Lr.bre` = dodge %, both fed by:
- the breed table (`xq` args 13/14 → `DT()`/`DU()`),
- card/spell actions **120/121** (block ±) and **122/123** (dodge ±),
- a summon's own type-300 template (29 creatures carry a block %, 36 a dodge %).

The shipped breed values are strikingly coherent — **dodge is 100 for every breed**, and
block tracks class identity: **Feca 60, Iop and Pandawa 40, Sram and Sacrier 20, everyone
else 0**. The client's help text confirms the dodge base independently: *"Tous les
personnages ont, de base, 100% en esquive"* — an external check that argument 14 is
identified correctly.

**The rule**, from the same help text: *"Ce sont tes chances d'esquive qui donneront ton
pourcentage de chance de ne pas être bloqué. Avoir 100% en esquive te garantis de toujours
esquiver les personnages qui ont 0% de chance de blocage… Chaque fois que ton combattant
quittera le corps à corps d'un adversaire, celui-ci pourra tenter de le bloquer, pour lui
faire perdre son tour."*

**Fix.** `tackleEvasionChance = clamp(mover.Dodge - holder.Block, 0, 100)`, rolled once per
adjacent holder. Block/Dodge now flow from breed → equipped-card actions 120-123 →
in-fight buffs (new `BuffBlock`/`BuffDodge`) → summon templates, and are stored unclamped
so a timed debuff reverts exactly.

**Honest limit:** the client's `TackleAction` is a cosmetic animation in both 2.70 and
2.04b, so the arithmetic is server-side and *not* recoverable from the client. The
**anchor** is verified (100 dodge vs 0 block always escapes; higher block is worse); the
**curve between the endpoints is a server choice**. Subtraction is the simplest shape
satisfying the anchor. This is flagged in `tackle.go` so nobody later mistakes it for a
client-derived formula.

**Also dropped: the "4+ adjacent enemies = movement impossible" cap.** It came from the
2.04b manual and directly contradicts the 2.70 guarantee above — four adjacent Cras would
pin a fighter the client promises free passage to. Being surrounded is punishing on its
own: four Fecas give 0.4⁴ ≈ 2.6%.

**Two more mappings corrected while here:** actions **147/148** (crit-rate / fumble-rate
*malus*) were classified as generic buffs and never applied; they now feed CritRate and
FumbleRate. Action 120 is consequently no longer "render-only" — `TestBuffLifecycle`'s
render-only case moved to action 155 (damage/resistance bluff).

**Verified:** `unit` — the formula and its bounds across 8 cases; 100-dodge-vs-0-block
escaping 200/200 times even when surrounded on all four sides; ~40% escape vs one Feca and
~16% vs two (independent rolls); breed block/dodge pinned to the client table with the
"a Feca must block better than a Cra" sanity check.

### B-062 · Card-set bonuses ("panoplies") did not exist
Record type 101 — 138 sets, referenced by all 907 coach cards through their `CardSet`
field — was never read, so wearing a matching set granted nothing.

**The rule, from the client** (`sj_1`'s aggregated-bonus builder, not from the UI):

```
count = the coach's EQUIPPED cards of this set
for each set effect:  if effect.Threshold <= count  ->  it applies
several sources of the same action id are SUMMED
```

The threshold is `akw_0.aAm()`, the trailing byte of each effect entry. Note that
`fe_1`'s `halfSetEffects` / `fullSetEffects` split (`threshold < size` vs `== size`) is
**only how the UI groups them** — the engine rule is the per-effect threshold and nothing
else. Real thresholds range 2..10.

**What set effects are.** They use the client's `AI` enum, i.e. the coach META layer:
XP % and flat (28 effects), fatigue (9), morale (9), reputation (6), death chance (5),
wound cancellation (4), drops — and **resurrection chance (10)**.

**Scope, deliberately limited.** Of those meta systems this server implements exactly one:
resurrection. So that is the only one wired up — `setBonusFor(aiActionResurrect)` is added
to the card's own chance (capped at 100) in the graveyard revive path. The other bonuses
are decoded and inert, waiting for their mechanics, rather than half-built against
consumers that do not exist. `docs/DATA-COVERAGE.md` lists them.

**Verified:** `unit` — the threshold rule across 0/1/2/4/5 equipped cards; summing across
two different sets; unequipped cards (Pos 0) not counting; a different action id not
mixed in; no catalogue staying inert rather than panicking. Real data: every set a card
points at exists, all 88 effects have a plausible threshold (1..20) and AI action (1..21)
and carry params, and at least one set grants resurrection. `live` — the server logs
`cardSets=138`.

### B-061 · Bound / undestructible cards could be traded
`exchangeMoveCard` validated only the per-instance state — the player's own lock flag
and "is it equipped". It never looked at the card TEMPLATE, so the two flags that make a
card non-tradable were ignored: **171 of the 907 shipped cards are `Bound`** ("linked" to
their owner) and **65 are `Undestructible`**.

The client refuses both itself (`error.exchange.linkedCard` /
`coachInventory.undestructibleCard`), which is exactly why the server has to as well — a
client-side rule is not a rule. A forged 5105 could stake a bound card and trade it away.

**Fix.** `Deps.cardIsTradable` checks the template's `Bound`/`Undestructible`, called
before a card is staged. Unknown templates and an absent catalog stay permissive, so a
server running without data files behaves as it did rather than blocking all trade.

**Fixing it required decoding the record properly.** The coach-card decoder read only the
first 5 fields and left `Rank` permanently 0, with a comment deferring the rest. It now
decodes through field 18 in one pass: required level, firework type + colour, isUnique,
obtainable-in-draw + drop %, **bound**, **undestructible**, has-usable-action, the effect
array (which the resurrection scan already walked) and rank. Fields 19-26 remain unread
behind an `np_1[]` array whose element layout is not yet known — recorded in
`docs/DATA-COVERAGE.md` rather than silently skipped.

**Verified:** `unit` — tradability across plain/bound/undestructible/unknown templates and
with no catalog at all; real-data canaries on the newly-decoded fields (implausible
level/rank/drop-% ranges fail, and a zero `ranked` count fails, so a field-order slip is
caught); the pre-existing resurrection test still passes, which independently confirms
the record stays aligned through field 15.

### B-060 · Summons ignored their innate properties — every creature could be shoved
The type-300 summon record was decoded only as far as field 6 (id/HP/AP/MP/spells/gfx);
the whole tail was skipped as "not needed server-side". It very much was.

Fields 7–12 are the properties a creature is **born with** — the client's `adT`/`ta_0`
stamp them onto the fighter at spawn, which is how a wall, a doll or a Xelor dial is
immovable:

| field | getter | client property | effect |
|---|---|---|---|
| 7 | `op()` | `avx_0.deA` | cannot be carried (blocks Carry 58) |
| 8 | `oq()` | `avx_0.deB` | intransposable (blocks swap 64) |
| 9 | `or()` | `avx_0.dev` | stabilised (blocks Push 37 / Pull 38) |
| 10 | `os()` | `avx_0.dex` | rooted — MP reads as 0, cannot walk |
| 11 | `ov()` | `avx_0.deD` | set by the client, never tested by it |
| 12 | `oy()` | `avx_0.deF` | disables positional damage bonus (inert: 2.70 dropped it) |

Measured on the 53 shipped creatures: **22 rooted, 21 cannot-be-carried, 18 stabilised,
15 intransposable**. We honoured none, so any summon in the game could be pushed, pulled,
swapped or picked up.

**Fix.** The record is now decoded in full (17/17 fields), and
`applySummonInnateProperties` grants the four displacement properties as permanent states
at spawn, so the existing enforcement covers them with no new rules. Fields 13/14
(**block %** on 29 creatures, **dodge %** on 36) are decoded but deliberately inert —
tackle/dodge is unimplemented server-wide, and that is a mechanic gap, not a summon one.

**Verified:** `unit` — real-data canaries on the flag populations and on block/dodge
plausibility (a field-order slip collapses them to zero and fails); and a game-side test
that a wall creature gets all four properties, keeps them across a round tick, actually
resists a push and a carry, and that a flagless creature is left fully mobile.

### B-059 · Spell COOLDOWNS were read from the wrong field — 97 spells had none
The spell record has four distinct cast-limit bytes and we had the cooldown on the wrong
one. Each maps to a different bucket of the client's cast-history tracker `sH`, which is
what fixes their meanings:

| field | getter | client bucket | meaning |
|---|---|---|---|
| 7 | `iS()` | `akU`, keyed `spellId<<32\|targetId` | max casts per target, per turn |
| 8 | `iT()` | `akV`, counted up/down | max **live instances** at once |
| 9 | `iU()` | `akT`, reset each turn | max casts per turn |
| 10 | `iV()` | `akS`, stores `turn + value` | **cooldown in table turns; 63 = once per fight** |

We read the cooldown from **field 8**. Measured against the shipped table: field 10 is
non-zero on **97 of 203 spells, 28 of them 63 (once per fight)**, while field 8 is
non-zero on just 6. So nearly half the spell book had **no cooldown enforced at all** —
including every once-per-fight spell, which could be cast every single turn — and the 6
max-active spells were instead wrongly rate-limited.

**Also newly decoded from the same record:**
- **Field 18 `eD()` = range NOT boostable** (5 spells): the caster's Range characteristic
  must not extend these. The client's gate is
  `if (!(maxRange <= 1 || boost >= 0 && eD())) maxRange += boost`, so the flag suppresses
  only a *positive* boost — `spellTargetValid` now mirrors that exactly.
- Field 11 `et()` (deferred unlock delay) is decoded for completeness.

**Still unread on this record:** field 22 (spell-level target bitmasks — we honour only
the per-effect ones) and field 23 (parent spell id — the client shares cooldowns and caps
with the parent). Both are logged in `docs/DATA-COVERAGE.md`.

**Verified:** `unit` — a real-data test asserts cooldowns are common (≥50 spells), that
once-per-fight spells exist, and that the max-active cap is rarer than the cooldown, so a
future field swap fails loudly.

### B-058 · Every breed's INITIATIVE (and base value) was the 2.04b figure — turn order was wrong
The breed table's initiative column, and the per-breed base value, were the **2006**
numbers. Initiative decides the fight timeline, so turn order in every fight was built
on the wrong data.

**How it was pinned.** 2.70's breed table is the obfuscated enum `xq`, but v2.04b ships
the **unobfuscated twin of the same table** (`Breed.java`) and the two line up argument
for argument, which fixes every position beyond doubt:

|  | id | HP | AP | MP | **init** | crit | fumble | **value** | element | ccAP | ccDmg | ccCrit |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 2.04b `FECA` | 1 | 70 | 6 | 3 | **50** | 5 | 1 | **400** | WATER | 5 | 5 | 7 |
| 2.70 `axF` | 1 | 70 | 6 | 3 | **20** | 0 | 0 | **600** | `ban` | 5 | 5 | 7 |

The client reaches them as `ok()`=HP, `ol()`=AP, `om()`=MP, `DK()`=initiative — and
`DK()` is what seeds characteristic `Lr.bqA`, the one `ee_2` renders as
`initiativePoints`. That chain is what proves the 5th argument is initiative.

**2.70 re-tuned three things, and all three were wrong here:**
- **Initiative — all 12 values changed.** 2.70's are unique per breed (Feca 20,
  Osamodas 40, Enutrof 60, Sram 50, Xelor 80, Ecaflip 70, Eniripsa 0, Iop 10, Cra 75,
  Sadida 30, Sacrier 90, Pandawa 100), so the timeline is fully determined with no ties;
  the 2.04b values we carried had many duplicates.
- **Base value 400 → 600**, so every fighter's budget was 200 short (compounding B-056).
- **Cra's close-combat element** (already fixed as B-057 — and this is where it came
  from: 2.04b's `CRA` really is `WATER`).

**Verified:** `unit` — the whole table is pinned to the client's values, including a
check that no two breeds share an initiative.

**Still open — base crit/fumble.** In the same positions where 2.04b holds `5, 1`, the
2.70 client holds **`0, 0`** for every breed, and those feed `xq.DL()`/`DM()` →
`Lr.bqU`/`bqV`, which `ee_2` renders as `criticalHitBonus`/`criticalMissMalus`. Read
literally, 2.70 gives fighters no innate crit or fumble and expects equipment to supply
it. `baseCritRate`/`baseFumbleRate` are deliberately left at 5/1: zeroing them silently
removes crits from every fight, and the fighter-card record has an unidentified i32
(`uh_0.eA`) that is a plausible per-weapon crit rate. That field needs identifying first.

### B-057 · Cra's close-combat element was water, not air
`breedTable`'s per-breed close-combat element put **Cra** in water. The client's own
breed table (enum `xq`, whose 9th ctor arg is an `fv_1` element) splits the 12 breeds
cleanly **3/3/3/3**:

| element | breeds |
|---|---|
| fire (`fv_1.bam`) | Xelor, Eniripsa, Pandawa |
| water (`fv_1.ban`) | Feca, Enutrof, Ecaflip |
| air (`fv_1.bao`) | **Sram, Cra, Sacrier** |
| earth (`fv_1.bap`) | Osamodas, Iop, Sadida |

Ours made water a 4-breed group and air a 2-breed one, so every Cra punch was resolved
against the target's **water** resistance instead of air — wrong damage on every
close-combat hit by a Cra.

**Also verified while there** (no change needed): the close-combat constants really are
uniform across breeds — every `xq` entry carries the same 5/5/7, exposed as
`DO()`/`DP()`/`DQ()`, and the client renders "Corps à corps (N AP)" from `DO()`. HP/AP/MP
match the client for all 12 breeds.

**Still unverified:** `Init` is *not* from this table (the client's 5th ctor arg spans
0..100 and matches no plausible initiative spread), so our initiative values — which
decide turn order — remain unconfirmed against the 2.70 client. Flagged in the code.

**Verified:** `unit` — the element groups are pinned to the client's 3/3/3/3 split, and
base HP/AP/MP to its table.

### B-056 · Fighter equipment was valued from the COACH-card table
`computeFighterBudget`/`computeLoadoutBudget` summed a fighter's equipment value out
of `Deps.Cards` — the **coach**-card table (type 100). A fighter's objects are
**fighter** cards (type 250, client `ve_0`). The two id spaces overlap almost
completely with entirely unrelated prices, so the lookup silently succeeded and
returned nonsense.

Measured across the shipped tables: of the 75 fighter cards, **66 got a different
value and not one matched** (9 ids are absent from the coach table). Card 85 — a
weapon worth 200 — was valued at **18200**; card 97 (50) at **46000**. Since the
budget is clamped to int16, a fighter with two pieces of gear saturated at 32767,
making team-budget limits meaningless.

**Fix.** Both functions now read `Deps.FighterCards`. **Verified:** `unit` — a card id
present in BOTH tables with different values must be valued from the fighter table.

### B-055 · Using a fighter's equipment (8107) applied no effects at all
Playing a fighter's gear in a fight was acknowledged and animated but did **nothing**:
no AP was spent, no damage dealt. The handler broadcast FIGHTER_CARD_USE (8108) and
stopped.

**Root cause — a misread that had been carried in a comment.** The code claimed card
effects "use the client's own action enum (`AI.aHI`), a different table from spell
effect ids", making it a separate subsystem. That is wrong on both counts:

- `AI` is the **COACH**-card meta enum — XP bonus, wounds, morale, fatigue, drops,
  reputation, resurrection chance. It has nothing to do with in-fight equipment.
- 8107 is sent by the client's `abt_1` targeting mode carrying a **`ve_0`**, which is
  fighter EQUIPMENT (its icons come from `fighterEquipmentIconsPath`; its `cardType`
  is "weapon"/"equipment"). Its effects are ordinary `xj_0` effects — the *same*
  structure spells use, which the existing resolver already handles.

So this is the **weapon attack**, and it needed no new effect machinery. (It is also
distinct from CLOSE_COMBAT 8111, which is the breed's fixed unarmed strike.)

**Data.** A fighter card (type 250, `uh_0`) carries two effect lists split by
container type, exactly as the client splits them in `jb_2.a`:
`FIGHTER_CARD_EQUIP` (passive) and `FIGHTER_CARD_USE` (the active ability). A card is
playable iff it has the latter (`jb_2.isUsable`) — **23 of the 75 shipped cards**, all
weapons: an AP cost, a range band, and elemental damage in a normal and a critical
variant.

Two decode traps, both caught by the data rather than assumed:
- **The container type is space-padded** to a fixed width (`"FIGHTER_CARD_USE  "`).
  Matching it untrimmed found ZERO use-effects while the same-length
  `"FIGHTER_CARD_EQUIP"` happened to work — a silent, one-sided failure.
  `decodeEffectBlob` now trims, as the client does.
- **The record stores range MAX before MIN.** Three independent signals agree: the
  client renders the band as `AA()-Az()` (ascending only this way), a max of 0 is what
  makes a card self-target-only (`ve_0`'s "cast.targetCaster"), and the reverse
  reading yields min > max on every ranged weapon shipped.

**Fix.** `FighterCard` now decodes `APCost`, `RangeMin`/`RangeMax` and `UseEffects`
(+`Usable()`); `useFighterCard` (`fightercard_use.go`) mirrors `castSpellByFighter` —
validate, roll fumble/crit, broadcast 8108 with the real flags, debit AP, resolve the
crit/normal effect subset, flush, check for fight end. Ownership is now checked
against the FIGHTER's own objects (it was checking the coach's inventory, the wrong
collection entirely).

**Deliberately not enforced:** the record's six flag bytes (line-of-sight / only-line
/ free-cell / carry gates). Their individual positions are unverified against the
client's targeting code, and guessing wrong would silently reject legitimate attacks —
worse than being permissive toward a forged packet, which the cell/range/AP checks
already bound.

**Verified:** `unit` — a played weapon deals damage and costs its AP; unowned gear,
passive-only gear, out-of-range targets (both too far and inside the minimum), out-of-
turn use and insufficient AP are all refused with no side effects; a crit resolves the
IsCritical subset (higher damage) and a fumble spends AP but deals nothing; the Range
stat extends a ranged weapon but never a melee one. Real data: 23/75 cards usable,
every one with `min <= max`, a plausible AP cost and an action on every effect; card 85
is 4 AP range 1-1 with both variants; card 37 decodes as range 2-5 (the max-before-min
canary). `live` — 8107 now reaches the resolver and correctly refuses the test
fighter's passive-only card 149, logging why.

**Live-verified end-to-end** (follow-up pass). Two `/script` commands were added to
drive this — `usecard <wire> <card> <x> <y>` and `cc <wire> <x> <y>` — then weapon 85
was equipped on a real fighter through the REAL protocol path (6011
UpdateFighterInventory), a Tester fight was started, the sparring AI was allowed to
walk into contact, and the weapon was played:

- `used=true ap 6->2/6` — the card's own 4 AP is charged.
- Target HP **70 → 55** on the first hit, then exactly **10 per hit** over the next
  four (55 → 15). Card 85 ships `params=[10]` normal / `[15]` critical, so the 15 was a
  genuine 5%-crit roll and the crit subset is being selected correctly.
- The loadout save logged `budget=600` = 400 base + card 85's **fighter-card** value of
  200, which also confirms B-056 live (the old coach-table lookup would have scored
  18200 and saturated the int16 clamp).

### B-054 · The per-round EVENT CARD was never implemented
Every round of every fight sent `NEW_TABLE_TURN_BEGIN` (8100) with `eventId 0` and
applied nothing, so the card that is supposed to be drawn at the start of each table
turn — and to affect BOTH teams for that round — simply did not exist.

**Root cause / provenance.** The mechanic is server-authoritative. 8100 is
`[i32 uid][i32 -1][i8 turn][i32 eventId]`; the client's `jg_1` reads the id and
resolves it via `cw_1.eO().w(id)` into a `tO` ("ClientEvent") **purely to display the
card** (name from i18n table 8, art from `eventsIllustrationsPath`). Nothing in the
client applies the effects — the server draws the card AND applies it. Our
`buildNewTableTurn` hard-coded `I32(0)`.

The cards live in `data.bdat` **type 230** (client record `ama_1`, loaded by `aGl`):
`[i32 id][i16 unused][u8 descriptionFlag]` + the standard embedded effect list. 51
records ship.

**Which cards are drawable.** The data is not one pool, and the deciding evidence is
the 2006 client: its `events.dat` holds **exactly ids 1..27**. So 1..27 is the base
deck — the 12 breed-god cards (each restricted to its own breed by the effect's breed
target condition) plus 15 neutral arena cards — and everything from 43 up was added
later for PvE: the creature cards (43..47, 67) and the "Démon des Minutes 3"
boosts/debuffs (61..66) carry creature-scoped target masks, and 48..59 are a second,
far stronger god set (+3 AP, +100% resist, arena-wide invisibility) that would
dominate a fight if it came up every few rounds. Only 1..27 are dealt.

**Fix.**
- `gamedata/events.go` — decodes type 230 into `Event{ID, Effects, DescriptionFlag}`
  with `LoadEvents`/`Get`/`IDs`/`Len`; wired as `Deps.Events` in `main.go`.
- `game/events.go` — a per-fight shuffled deck of ids 1..27 dealt one card per round
  and reshuffled once exhausted (every card appears once per cycle), shuffled with the
  fight's own RNG so a seeded fight is reproducible. `beginTableTurn` broadcasts
  8100 with the real id FIRST (the client must instantiate the card before the effect
  actions arrive) and only then applies it. Reconnect resends the round's CURRENT card
  rather than drawing a new one.
- **Application model:** each effect is applied once per living fighter with that
  fighter as BOTH caster and target. Self-casting is what makes it work — an event has
  no caster, and the per-fighter handlers read the caster's own characteristics (a
  "+30% damage" card must scale off each fighter's own stats). Events deliberately
  bypass cell-area resolution: a round card has no aimed cell, and the shipped data is
  inconsistent anyway (most effects are `areaShape=32767` "all", but event 7 ships
  `areaShape=1`). Each effect is still gated by its own target conditions, which is how
  "Dieu Iop" buffs only Iops. Summons are NOT blanket-excluded — the data targets them
  explicitly where intended (the Osamodas card buffs summons via IS_SUMMONED), so the
  conditions decide.
- **The opening round is fixed:** round 1 always draws event 14 ("Cloué au lit").
  Implemented by moving that card to the top of the freshly-shuffled deck, so it is
  still dealt exactly once per cycle and cannot repeat on round 2.

**Target conditions gained a negative breed bank.** The live draw of event 8 ("Dieu
Enutrof") exposed it: one effect buffs Enutrofs, the other buffs everyone *else*, and
the second is expressed as bit 34. Per the client's evaluator (`aap.a`), bit **16+k**
means "breed IS k+1" and bit **32+k** means "breed is NOT k+1", each bit checked
independently. `target_conditions.go` previously masked only bits 16..27 and compared
the whole masked value at once, so a "not an Enutrof" effect landed on the Enutrof too.
2.70 also widened the bank from 12 breeds to 14 slots.

**Verified:** `unit` — decoder against the real table (51 cards; every base-deck id
present; each record's inner id matches its key, the canary for a mis-aligned header;
event 14 is exactly 94+127+128 with a one-round duration; event 1 carries the Iop breed
bit; the two non-"all" effects are both on event 7); deck behaviour (inert with no data,
first draw is card 14 for 50 different seeds, every card dealt once per cycle with no
early repeat of the opening card, twice over two cycles, never a non-base card in 200
draws, deterministic under seed); effects reach BOTH teams; a breed card buffs only its
breed; the negative-breed card buffs each side exactly once. `live` — server logs
`eventCards=51`, and two separate fights both drew `turn=1 eventCard=14` then a random
card (8, then 3) on turn 2, with the fight dump showing both fighters carrying the
opening card's three states.

**Not verified:** that the client visually renders the drawn card — an injected fight
builds no client-side match object, so nothing renders in the harness. The id is on the
wire and the client's own resolver is a pure display lookup.

### B-053 · Actions 127/128 were mis-mapped onto root/stabilise — the opening card froze the arena
`states.go` folded action **127** ("S'enraciner") into `stateRooted` and **128**
("Rendre intransposable") into `stateStabilized`. Both were wrong, and 127 was wrong in
a way that mattered: it zeroed the target's MP and blocked its movement outright.

**Root cause.** Each state action maps to a distinct client FIGHTER PROPERTY (enum
`avx_0`), and the client shows exactly what each one forbids:

| action | class | property | what it actually blocks |
|---|---|---|---|
| 65 "Immobilisé" | `rc_0` | `dex` (ROOTED) | sets MP (`Lr.bqz`) to 0 → **cannot walk** |
| 96 "Pétrifié" | `asy` | `dew` | AP **and** MP read as 0 → cannot act |
| 94 "Stabilisation" | `cw_2` | `dev` | **only** Push (37 `na_2`) / Pull (38 `sa_2`) |
| 127 "S'enraciner" | `fj_1` | `deA` | **only** Carry (58 `Jk`) |
| 128 "Rendre intransposable" | `ky_1` | `deB` | **only** swap position (64 `aox_1`) |

`mv_1` gates each displacement effect on its own property, and `gn_0` zeroes the MP
characteristic for `dew`/`dex` only. So 127 and 128 never stop a fighter walking — they
stop it being *moved by someone else*.

This surfaced through the round-card work: event 14, the card the opening round always
draws, is exactly 94 + 127 + 128. Under the old mapping it rooted and MP-zeroed every
fighter, freezing the whole arena on round 1 instead of simply making everyone immune to
being pushed, pulled, carried or swapped.

**Fix.** Split into five distinct states (`stateRooted`, `statePetrified`,
`stateStabilized`, `stateAnchored`, `stateIntransposable`); `applyPushPull` keeps
checking stabilised, `applySwap` now checks intransposable (it was checking stabilised),
and `applyCarry` now checks anchored (it checked nothing).

**Verified:** `unit` — each action maps to its own state; a stabilised fighter resists a
push but can still be swapped and keeps its MP; an anchored fighter cannot be carried but
still walks and keeps its MP; an intransposable fighter resists a swap but can still be
pushed; and the opening card leaves everyone able to walk while granting all three
immunities. `live` — the in-fight dump shows both fighters at round 1 with
`[anchor:1 intransp:1 stab:1]` and **MP 3/3**.

### B-052 · Only ONE fight map existed — all 47 arenas are now supported
Every fight was played on world 5, because the arena was a single hand-decoded
package-level value (`practiceArena`): its topology, scenery, start cells, coach
pedestals and special cells were transcribed into Go by hand. Any fight on another
map would have been validated against world 5's geometry.

**Fix — the server now reads the client's own map files.** `maps/fight` and
`maps/tplg` were copied into `data/maps` (~1.2 MB; the same duplication already used
for `data.bdat`), and `gamedata.LoadFightMaps` decodes them:

* **`.fmd`** (client `Om.b`, little-endian): 6 packed coach slots, a packed
  `(team0<<8)|team1` count, both teams' start cells, then the special cells as
  `{i32 packedPos, i32 templateId}`. A packed position is
  `x=(v>>>20 &0xFFF)-2047, y=(v>>>8 &0xFFF)-2047, z=(v&0xFF)-127`.
* **topology tiles**: a 7-byte header `[u8 type][i16 chunkX][i16 chunkY][i16 wp]`
  then one of three per-cell layouts — type **2** `ajg_2` (a 16-entry altitude
  palette, a 4-entry ground palette and 18×18 cell bytes), type **3** `aji_2` (one
  packed i16 per cell, `ground` read from the SIGN-EXTENDED short so a negative value
  means no floor), and type **5** `ajj_2` (a sorted list of packed ints, several
  LAYERS per cell). Types 0/1/6 carry no floor data. A cell has no floor when its
  ground entry is −1; combined with the altitude sentinel that separates true void
  from solid scenery.

Two decisions were driven by evidence rather than guesswork:
* **Layer choice.** A type-5 cell can stack several layers (a platform over a pit).
  Taking the first layer put start cells at the wrong height on 6 maps; taking the
  HIGHEST floor layer matched every arena. Each `.fmd` records the exact z the client
  expects for each start cell, so those 47 maps' start points are the oracle.
* **Map 42's content quirk.** Two of its special cells sit on cells the topology
  gives no floor, so they could never be stood on and never fire. They are dropped as
  unreachable (`UnreachableSpecials`) rather than papered over.

**Refactor.** `arena` is now one flat cell grid (`floor` / `scenery` / `void`) with a
bounding box, so a map need not start at (0,0); `Fight` carries its own `*arena` and
every rule reads `f.Arena()` — movement, spell targeting, line of sight, pathfinding,
summons, carry, effect areas, the streamed fight grid, ACTOR_APPEAR, EnterInstance and
sudden death. `pickArena` rotates over the whole set, so fights are spread across all
47 maps. The hand-decoded world 5 is kept as the fallback (folded into the same cell
grid by `init`), so a checkout without map files — and the entire unit suite — still
works unchanged.

**Verified:** `unit` — the decoder must reproduce the hand-decoded world 5 EXACTLY
(start cells, all 22 scenery cells, the 9 specials with template ids, the 151/22/151
floor/scenery/void split, pedestals on scenery); all 47 arenas load with every start
cell and special on real floor at the altitude the `.fmd` records; every arena's
streamed grid classifies each cell as exactly one of floor/scenery/void; two fights on
different arenas stay isolated and collapse toward their own centres; an arena-less
Fight still falls back to world 5; and sudden death terminates leaving a core on
**every** arena. `live` — the server logs `fight maps loaded arenas=47`; three
successive fights started on three different maps (start cells (6,2,0) / (15,8,0) /
(14,10,-1), none of them world 5's), and the client rendered the arena correctly.

### B-051 · Every private message and GM reply rendered EMPTY
Noticed while testing GM commands: each reply appeared in the chat as
`de Server :` with **no text**. It affected every whisper too, so the private
channel was effectively mute.

**Root cause:** PrivateContent (3154) writes its body with a **u16** length, but
the client's `ais_2` decoder reads it as a single BYTE
(`new byte[byteBuffer.get() & 0xFF]`). For any message shorter than 256 bytes the
first byte of our u16 is the ZERO high byte, so the client read a length of 0 and
rendered an empty line — silently, with no decode error.

Subtle detail that made this easy to miss: the otherwise byte-identical **vicinity**
message (3152, `ck_0`) really does use a `short` for its body length, so
`buildVicinityMessage` was correct and only the private variant was wrong. The two
had been written from one template.

**Fix**: `buildPrivateMessage` now writes `[u8 nameLen][name][i64 senderId]
[u8 msgLen][message]`. Because a byte prefix caps the body at 255, an over-long
message is truncated on a **rune boundary** (the client decodes the body as UTF-8, so
cutting mid-character would render mojibake).

**Verified:** `live` — `/WHERE` and `/HELP` now print their text in the client's chat
(`de Server : pos=(40,-20,8)` and the full command list), where both were blank
before.

### B-050 · Sudden death ("Mort Subite") — the arena never collapsed
Reported from live play: *"after X turns (normally 15) the fight map starts to get
shrinked"*, followed by *"29 turns and nothing triggered by the client — it must be
server side that sends something"*. Correct on both counts: the rule exists in 2.70,
the client never self-triggers it, and our server sent nothing.

**The rule is real and configurable.** The client's i18n states the default outright
— *"Pourquoi attendre **15 tours** avant que les équipes se rencontrent"*
(`content.42.16`) — and tournament rule cards shift it: *"retarde/avance de 5/10
tours la mort subite"* (cards 788/789/790/793), with presets pinning it to turn 2
(`content.53.16`) or 10 (`content.53.19`). Hence `suddenDeathTurn` is a var.

**The mechanism.** `mh_2.java:114` binds action id **117** ("Destruction de terrain")
to class `mw_2`, whose own error string names it **MapDestruction**. The server runs
it with **8121** (`rq_2`):

```
[i32 mh_2 actionId = 117][i16 blobLen][blob][i64][i16][i8]
```

`of_1` case 8121 resolves the class from the action id, instantiates the `ZT`
animation and feeds it the blob. The blob is the same Ankama part-serialisation as a
running effect; part 0 (`yi_1`, 34 B) is
`[i64 caster][i64 target][i32 genericEffectId][i32 x][i32 y][i16 z][i32 r]`, where
**x/y/z is the spiral centre** and **r is a progressive destroy counter**.
`mw_2` then walks a square spiral outward from that centre and per cell calls
`asF.bV`, which sets the cell's movement-block bit *and* hides its graphics, then
kills every entity standing on a destroyed cell — matching the reported rules
exactly (fighters and summons die instantly; nobody can move onto a removed cell).

**Two client details that shaped the design.** `xb_2.bWv` defaults to **true**, so
`akf()` is true and the client takes the *instant* branch: it calls the param init
`mw_2.a(xb_2)` (which dereferences the effect behind `genericEffectId` — so that id
MUST resolve or the client NPEs) and destroys `Ny² − Nz²` cells in one go, ignoring
`r`. And `mw_2.aI()` is true, so the effect **requires a resolvable target fighter**.

**First attempt was wrong — it killed everyone.** I initially made the collapse a
single shot that destroyed everything outside a 5×5 core (the client's defaults).
Both teams start at y=15/16 and y=2/3, far outside that core, so *every* fighter died
the instant it fired. Reported as: *"the /suddendeath is just killing all fighters.
After 15 turns, all fighters die as well."* The mechanic is **progressive**: the arena
shrinks ring by ring so fighters can retreat, and a fighter dies **only** if the cell
under it is the one being removed.

**Fix** (`suddendeath.go`): from `suddenDeathTurn` onward, each new table turn removes
**one ring** (Chebyshev distance from the arena centre), counting inward from the
outermost until only `suddenDeathCoreRing = 2` — a 5×5 core — remains. `shrinkRing`
kills only the fighters whose own ring is the one removed; being outside the eventual
core is not lethal by itself, you simply cannot walk back out. Destroyed cells live on
the Fight (never on the shared `practiceArena` value) and are refused by
`validateFightMove`, `spellTargetValid` and `applyTeleport`.

The surviving core is chosen to match the client exactly: its spared area is the first
`Nz²`=25 cells of the spiral, which is precisely Chebyshev ≤ 2. So server and client
agree on the FINAL geometry even though the ramp is currently server-only.

**Wrong opcode — the second mistake.** I first drove the client with **8121**
(`rq_2`) and nothing rendered. 8121 only **attaches** an effect to a fighter as a
persistent buff (`of_1` does `zT.ajR().PJ().o(zT)` and flags `"hasBuff"`); it never
executes one. Executing goes through the ordinary **RUNNING_EFFECT (8120)** — the
same message damage and heals use — whose handler looks the effect up by the mh_2
action id in the `runningEffectId` field and calls `run()`.

That single change also dissolved the two blockers I had wrongly concluded were
fatal:
1. I thought the geometry was unobtainable because no shipped effect carries action
   117 and none has 2 parameters. Irrelevant: `mv_0` (the 8120 executor) calls
   `akd()` on the effect, clearing the "instant" flag, and the **progressive branch
   never reads the parameters** — `Ny/Nz` simply keep their field defaults 18/5.
2. I thought progressive mode was unreachable because `bWv` defaults to true and is
   reset to true on release. True on the 8121 path; on the 8120 path `mv_0` clears it.

So the server drives the whole collapse through **`r`**, the last field of
running-effect part 0: the client destroys the first `r` cells of its spiral list
(ordered outermost → centre). `buildRunningEffect` already writes `r` as its `value`
argument, so no new builder was needed.

**Schedule.** `suddenDeathSchedule` walks the destruction order and cuts a step every
time another `suddenDeathFloorCellsPerTurn` (12) **walkable** cells have been passed,
ending exactly on `Ny²−Nz²` = 299 — the client's own core. Counting *floor* rather
than raw spiral cells is what keeps the pace even: the arena's outer band is mostly
void, so a fixed step in `r` eats nothing for several turns and then takes a huge
bite. Measured on world 5 the arena goes 151 → 139 → 127 → … → 16 floor cells, one
bite per turn across turns 15–26.

**Animation.** The effect is sent with `mustExecNow=false`, which QUEUES it on the
client's action sequence (the 8200 flush plays it) rather than running it the instant
the frame lands — the same way damage and heals are sent, and what lets the client
animate the collapse instead of snapping the cells out of existence.

**GM aids:** `/SUDDENDEATH` applies one shrink step immediately; call it repeatedly to
watch the arena close in. **`/MAPDESTRUCT [r [x y]]`** sends ONLY the client
animation (8120, action 117) and changes nothing server-side — no cells removed, no
fighter harmed — purely to see what the client renders; `r` is the destroy count
(299 = everything outside the 5×5 core). Caveat: the client kills entities on the
cells it removes, so it can show deaths the server does not have; end the fight
afterwards rather than playing on.

**Verified:** `unit` — 9 tests, including two direct regressions for the reported bug:
a fighter on a removed cell dies while one on a surviving cell lives, and a fighter
survives the first step and dies only on the step that takes its OWN cell (both
discover the per-step cell sets empirically rather than assuming them). Plus: the
spiral matches a hand-trace of `in_0`; the destroy order is outermost-first with the
centre last and no repeats; the schedule rises monotonically and lands exactly on
`Ny²−Nz²`; the first step does not flatten the map; it does not start early; it halts
with the core intact; and removed cells are refused by move validation while
surviving neighbours stay reachable.

**Not live-confirmed:** the on-screen collapse. The harness cannot verify it — fights
started by packet injection never build a client-side match object, so that client
processes no fight frames at all (fighters do not even render). Needs a check in a
normally-started fight.

### B-049 · Special cells fired at the END of the turn and granted nothing visible
Reported: *"the special effect cells are animated at the end of the turn, it should be
at the beginning, and the fighter should get the effect."* Both symptoms, one cause
each — the mechanic itself (B-048) was correctly hooked into `beginTurn`.

1. **Late animation.** The client queues fight frames and only plays them when an
   `ACTION_SEQUENCE_EXECUTE` (8200) barrier arrives. The special-cell path broadcast
   its 6200 animation and effects but never flushed, so everything sat in the queue
   until the next flush later in the turn. Now flushed via `defer`, so every exit path
   (killer / trap / heal / buff) closes its sequence exactly once.
2. **Invisible buff.** The buff tiles changed `AP`/`Range`/`Stats` server-side and
   broadcast **nothing**, so the player saw no effect land. Each tile now emits its
   characteristic-boost running effect using the client's own action ids (AP 13,
   Range 72, Heal 78, Res% 80, Dmg% 82 — v2.04b `charcRunningEffectID` parity).

### B-048 · Arena had no obstacles and no special cells (two reported fight bugs)
Reported from live play: *"the special cell actions aren't working"* and *"with the
Iop's Bond I can jump into a cell that shouldn't be possible (the ice spike)"*.

Both came from the **same gap: our arena model was a bare altitude grid.** It knew
which cells were void, and nothing else — no obstacles, no special tiles.

**1 · Obstacles.** `cellFlag` returned `0xFC00` ("open, obstacle-free floor") for
*every* non-void cell, so the map's scenery — ice spikes, trees, the coach pedestals
— was advertised to the client as plain floor, and `walkable()` agreed. Decoded the
real data from `maps/tplg/5.jar!0_0`: each cell's ground-palette entry `cCJ == -1`
means "no walkable ground", giving **22 obstacle cells** for world 5 (independently
confirmed: all six `.fmd` coach pedestals sit on them — coaches stand *on* the
scenery). RE'd the client's `aoq_0` cell word: bits 0-5 topology layer, **bit 7**
not-a-valid-arena-cell, **bit 8** blocks LoS, **bit 9** blocks movement, bits 10-15
dynamic obstacle id. Scenery must be **`0xFFFF`** — *not* `0xFE00`/`0xFD00`, which
leave bit 7 clear so the client still draws a walkable tile on top of the spike.

`spellTargetValid` also never checked walkability at all: `NeedFreeCell` only tested
for **fighters**, so any spell could be aimed at a void cell or an obstacle — and for
a displacement spell (Bond) the caster then *landed* there. `applyTeleport` did check
`walkable()`, which is why this needed the data fix and not just a guard. Server-side
LoS was terrain-altitude-only and would have stayed more permissive than the client
(whose bit-8 test now blocks on these cells), so obstacles report an impassable
pseudo-altitude and block rays too.

**2 · Special cells.** The 8000 blob carries a `[i8 specialCellCount]` section and we
wrote **0**, so the client never instantiated a live EffectArea per tile and every
special cell was inert decoration (the *art* comes from the client's own `.fmd`,
which is why they looked present). Decoded `fight/5.jar!5.fmd`: after the coach slots
and the two team start lists it stores `[u8 count]` + N × `{i32 packedPos, i32
templateId}` — **9 special cells** for world 5. The wire tuple is
`[i64 templateId][i64 instanceId][i32 x][i32 y][i16 z]`, placed after the rule-id
list and before the `i16 mapInstanceId`. Template ids index the client's
`staticEffect` table (SPECIAL **1002-1009**, TRAP **1/2/1015-1020** — all present in
this build).

Ported the mechanic from the v2.04b reference (`internal/combat/specialcells.go`),
including its template→behaviour table: 1002 Killer · 1003 Trap · 1004 EagleEye ·
1005 Shield · 1006 Panacea · 1007 Enthusiasm · 1008 Motivation · 1009 HealingHeart.
Per the manual (§5.0.4) a tile fires **only when a fighter STARTS its turn on it**
("no use to walk on or to fly over"), and the bonus lasts that turn. World 5 carries
4× EagleEye, 2× Shield, 2× Motivation, 1× Panacea — no Killer/Trap, as befits a
practice arena. Motivation raises **both** `AP` and `MaxAP` (bumping only the current
value is silently clamped back, so the tile would do nothing), and the revert drops
the ceiling while leaving already-spent AP alone so a fighter isn't charged twice.
The tile animation is **6200** `EFFECT_AREA_ACTION`, which must reference the
**instance id** (not the template id); it is purely cosmetic — the client's
`EffectArea.execute` is empty, so it can never double-apply the effect.

**Verified:** `unit` — 6 new tests (all 22 obstacles unwalkable + `0xFFFF` + LoS-
blocking and *not* void; all 9 special cells on walkable floor with z matching the
topology altitude and 1-based instance ids; the template table; buff apply/revert for
motivation/eagle-eye/shield/panacea; "plain cell grants nothing"; spent-AP not
double-charged). Three EXISTING tests failed on the new data and were **correct to
fail** — they encoded the old wrong map: a "valid 3-step" path routed straight
through the obstacle at (7,13), an only-line cast targeted the **void** cell (4,15),
and a LoS precondition asserted a raw altitude for what is actually an obstacle.
Fixed the fixtures and added explicit coverage that targeting a void cell or a
scenery obstacle is refused. `live` — the retail client accepted the new 8000 with
all 9 tiles and logged **no** "Impossible de trouver la cellule spéciale", i.e. every
template id resolved in its registry, with no new client errors.

**Not yet live-confirmed:** that a tile actually *fires* in-client. The client
currently builds no match object from our 8000 at all (`apN.aDK().aDL()` is null —
tracked separately), so the parse may not even reach the section; and no fighter
starts within MP range of a tile, so triggering one needs a multi-round setup. The
mechanic is unit-proven but should be re-checked once the match-construction issue is
resolved.

**Open, deliberately not changed:** `validateFightMove` refuses to move a **rooted**
fighter. v2.04b's `turns.go` does the same ("a ROOTED or PETRIFIED fighter cannot move
under its own power") and also blocks displacement, but live feedback says 2.70's root
should only prevent push/pull/teleport. The two disagree, so this was left alone
pending a decompiled-client check rather than changed on a guess.

### B-047 · Spell cast (8109) was unhandled; card use (8107) cast an arbitrary spell
Reported from live play: *"I couldn't cast spell or card in fight."*

**Root cause — two distinct actions were conflated.** Spell casting and in-fight
action-card play send **byte-identical** 22-byte requests (`[i64 fighterId][i32 id]
[i32 x][i32 y][i16 z]`, arch 3), which is how they came to be treated as one:

| | class | request | reply |
|---|---|---|---|
| **Spell cast** | `alx_2` holds a spell (`yp_2`) | **8109** `mc_2` | 8110 `axn_0` |
| **Card use** | `abt_1` holds a card (`ve_0`) | **8107** `sg_2` | 8108 `arn_0` |

The server registered **only 8107** and ran the *spell* handler on it, so:
- **Spells (8109) hit no handler at all** → casting did nothing.
- **Card use (8107)** was fed into `castSpellByFighter` with the **card id used as a
  spell id**. The id spaces overlap, so playing a card could cast an unrelated spell —
  actively wrong, not merely inert.

Its own doc comment said `handleSpellCast (8109 …)` while it was registered on
`OpSpellCastRequest = 8107`, and the inventory even named 8107
`FighterCardUseRequestMessage` while asserting it was "the real spell-cast request"
and marking 8109 **"DORMANT"**. The RE was right and the wiring was wrong.

**Why no test caught it:** `internal/testclient` also sent spells on **8107** — the
harness was written to match the *server's* assumption instead of the decompiled
client, so the entire e2e combat suite passed against the wrong opcode. A harness
that mirrors the implementation cannot falsify it; it must be pinned to the client.

**Fix**: `OpSpellCastRequest = 8109` (registered to `handleSpellCast`, logic
unchanged); new `OpFighterCardUseRequest = 8107` → `handleFighterCardUse`, which
validates owner/alive/turn, requires the card to be in the coach's **equipped deck**
(the same set `writeCoachCardBlob` streams in the 8000 blob, so a client cannot play
a card it does not own), and broadcasts **8108** via `buildFighterCardUse`. The
testclient now sends 8109 for `CastSpell` and gains `UseCard` for 8107.

**Scope limit:** per-card *effects* are not resolved. Card effects use the client's
own action enum (`AI.aHI`, e.g. action 13 = resurrect), a different table from spell
effect ids, so mapping them is a separate subsystem. The play is validated,
acknowledged and animated, but applies no effect yet.

**Verified:** `unit` (full `internal/game` suite green on the corrected constants);
`e2e` (`TestCombatSpellDamage` now casts on **8109** and still resolves damage
end-to-end — the same test previously passed on 8107 and proved nothing about the
retail client); `live` (injected 8109 in a running fight: **no `unhandled opcode`**,
handler reached; previously 8109 had no handler at all).

### B-046 · Ranking window has SEVEN tabs — "Tournoi" was blank and "Ligue Pro" unhandled
Audit triggered by the question "is the tournament work actually finished?". It was
not: the tournament feature has a **second surface** that was never served.

**Two mislabels, one missing board.** `ladderInformationDialog.xml` defines **seven**
tabs, not six:

| tab | i18n key | C2S → S2C | was |
|---|---|---|---|
| 1 vs 1 | `coachType1Tab` | 27500 → 27501 | served |
| Coach | `coachReputationType1Tab` | 27508 → 27509 | served (empty) |
| 2 vs 2 | `coachType2Tab` | 27504 → 27505 | served (empty) |
| Clan | `guildType1Tab` | 27502 → 27503 | served (empty) |
| **Tournoi** | **`tournamentType1Tab`** | **27506 → 27507** | **blank — no reply sent** |
| **Ligue Pro** | **`glickoRatingTab`** | **27514 → 27515** | **no handler at all** |
| Démon | `demonReputationType1Tab` | 27512 → 27513 | served |

B-041 had labelled **27506/27507** the *"seasonal (Ligue Pro)"* board and made it
deliberately silent ("complex, 3 sub-lists"). In fact it is the **Tournoi** tab — a
tournament-**points** board — and the genuine *Ligue Pro* tab is the untouched
**27514/27515** pair. B-041's live note "the Ligue Pro tab renders correctly" was
actually the *Tournoi* tab drawing its static headers with no rows.

**Fix**: `handleTournamentLadderRequest` (27506) now replies with a real **27507**:
`[i8 month][i8 trimester][i16 year][i32 ptsM][i32 ptsT][i32 ptsY]` followed by
**three** windows (month, trimester, year), each
`[i32 total][i32 start][i32 end][i32 myRank] rows{[i32 len][name][i32 points]} [i8 search]`.
`handleProLeagueLadderRequest` (27514) replies with **27515**
`[i32 total][i32 start][i32 end][i32 myRank][i32 leagueId] rows{…} [i8 search]`, echoing
the league id (it drives the client's league-name lookup, i18n group 58, which falls
back safely if absent). Both are legitimately **empty**: no tournament match has ever
been played (the live-match layer is deferred, B-044) so no tournament points exist,
and there is no pro league.

**Crash trap:** every `afl_1` row loop indexes a **pre-sized** client list via
`list.get(n)`, and 27515 additionally *clears* slots from `end-start` up to **total**.
So an empty board must send **zero counts**, not merely zero rows — a non-zero `total`
with no rows walks off the end of that list and throws.

**Verified:** `unit` (`TestTournamentLadderEmptyIsWellFormed` locks the exact 67-byte
form, all-zero counts, `end==start` per window and the echoed selectors;
`TestProLeagueLadderEmptyIsWellFormed` locks the 21-byte form and the echoed league
id, both replaying the client's decode cursor to assert full consumption); `e2e`
(`TestLadderAllBoardsRenderCleanly` extended — the old assertion that 27507 is *never*
sent was itself the bug's fingerprint and is now inverted into a real shape check).

**Not a bug — the empty "Récompenses" panel.** The same audit checked why the
tournament window's rewards column is blank. It is **client-side dead UI**, nothing
server-owed: `qr_0.tournamentRewards` resolves `aub.aHi()` (a single reward Kard id
from local `data.bdat` type-1000) against the local card registry, and **no packet
contributes any reward data**. Both XML instances of that list
(`tournamentsOfTheDay.xml`, `tournamentListDialog.xml`) declare only an `<isNull/>`
item renderer, so the widget can *only* ever paint the empty slot art — choosing a
definition with a non-zero reward (e.g. defId 11 or 18) would still render nothing.
The neighbouring `tournamentTokenReward` binding is likewise unimplemented by `qr_0`
and always resolves to null. Documented so nobody hunts a server-side cause.

### B-045 · In-fight facing change (4521) was dropped — "unhandled opcode" on every turn
The client sends **4521 `FighterActorDirectionChangeRequestMessage`** (`lr_2`) every
time a fighter turns during a fight. The server had no handler, so each one logged
`unhandled opcode 4521` and the fighter's new facing never reached the other client
or the spectators — everyone but the acting player kept seeing the old facing.

This was masked by a **wrong premise in B-037 K**, which asserted 2.70 had "no
direction-change opcode (no 4521 equivalent)". The opcode map (`opcode_map.csv`)
disproves it: 4521 is C2S high-priority and **4522 `FighterChangeDirectionMessage`**
(`u_0`) is its S2C pair. What 2.70 actually dropped is *directional damage*, not
facing itself.

**Fix**: `handleFighterDirectionChange` (4521) validates and relays;
`buildFighterDirectionChange` emits **4522** `[i32 uid][i32 -1][i64 fighterId][u8 dir]`
(the `ue_0` action header + payload, 17 bytes). Facing is stored on
`FightFighter.Orientation` (a `qc_0` index) via `Fight.applyDirectionChange`, which
enforces that a coach may turn only its **own, living** fighter and only on **that
fighter's turn**. It is a free action: no AP/MP/position change, and a rejected
request is a silent no-op (cosmetic only — it must never desync a turn). Relaying the
client's direction byte verbatim is crash-safe for peers because `qc_0.hf()` maps any
out-of-range byte to `NONE` rather than returning null.

**Verified:** `unit` (`TestFighterDirectionChangeWire` locks the exact 17-byte 4522
layout incl. the `-1` triggeringId; `TestFighterDirectionChangeValidation` covers the
happy path, re-facing, a spoofing coach, an out-of-turn fighter, an unknown wire id
and a dead fighter); `live` — two stages:
1. **Wart removal, A/B controlled:** injecting 4521 logged **nothing**, while a
   control inject of **4523** (a genuinely unregistered C2S opcode) logged
   `unhandled opcode … opcode=4523` in the same session. The 4521 wart is gone.
2. **Real fight:** `/EVOFIGHT` (7 titular fighters) driven to the action phase, then
   a facing request injected for **all 7** wire ids at once. The server logged
   exactly **1 `fight facing`** (the fighter whose turn it actually was — …8145,
   which had advanced from …8128 since the previous log read, so the gate was
   evaluated against live turn state) and **6 `fight facing ignored … currentTurn=false`**.
   **Zero client exceptions**, i.e. the retail client decoded the 17-byte 4522.

A diagnosability gap found during that live run: the handler was originally silent on
success, so a broadcast could not be confirmed from the log (the sibling move handler
logs its rejects). It now logs both outcomes — which is what made the 1-vs-6 result
above provable. The name field is nil-guarded (`ff.Fighter` is nil for summons, cf.
`breed.go`); the unit tests call `applyDirectionChange` directly and would not have
caught that deref.

### B-044 · Tournament totem opened an empty window (subsystem now live)
The tournament totem answered `17002`/`28601` with empty `17003`/`28602` stubs, so
the "Tournois du jour" window opened blank — the single biggest untouched block. The
blocker was a belief that populating it would crash the client: the calendar entry
(`17003 awa_0`) is keyed by a content `typeId` that must resolve to a registered
prototype, and each list row (`28602 ng_2`) carries a `tournamentDefinitionId` the
client's list/detail/register paths dereference **unguarded** (`aug.registerTournament`
→ `LS.Yf().gG(defId).qo()`), so a wrong id NPEs.

**Root of the un-blocking:** a parse of the retail `data.bdat` settled a dispute — it
holds **22 real tournament definitions** (type-1000 `aub`, ids {1,4..24}), and the
calendar content id **4** decodes as a tournament (`qr_0`). 20 of the 22 have
`referenceCardId == 0` (joinable with no card). Earlier "the table is empty" readings
were a mis-parse (enum ordinal vs `getId()`, or treating `data.bdat` as one zlib
stream instead of per-record members).

**Fix** (`tournaments.go`, `handlers_totems.go`): serve a fixed set of **standing
tournaments**, each referencing a real no-card definition (defIds 1/4/17, wire kind 1
"private" so registration completes without the search/bracket flows). `17003` emits
`typeId=4` `qr_0` events; `28602` emits registerable rows; `4607` registration is
accepted (`28608 err 0`) and tracked in-memory (`TournamentManager`), reflected back
as the row's `coachStatus`; `28649` bracket requests get an empty `28650` tree.

**Two crash traps, both handled:** (1) `qr_0` reads registration-period pair **[0]**
unguarded → every event carries ≥1 pair; (2) the "of-the-day" filter (`vk_1.Cd` →
`de_2.a`) reads the two event instants **inverted** vs their field names — the
"startDate" slot (OV) is the *runs-until* bound (must be ≥ now/end-of-today) and
"extraDate" (bOF) is the *already-started* bound (must be ≤ now). My first dates had
these backwards, so the events decoded fine but were silently filtered out of the
list (empty panel, no exception); swapping them made all three appear.

**Verified:** `unit` (5: exact-consume calendar/list decode, registration status,
manager idempotency, and a guard that every standing defId is a real no-card id) +
`e2e` (4: list/calendar shape, register→accepted→re-list-registered, empty tree);
`live` — the retail totem window listed all three tournaments with real names,
per-defId illustrations, schedules and registration periods, and clicking the real
**S'inscrire** button sent a genuine `4607` (server `tid=2600002 code=0`) → *"Inscription
au tournoi acceptée"* → the row flipped to the green ✓, with **zero client exceptions**.
The live-match layer (opponent search, scheduled fights, brackets, rewards) is
deferred — it needs many coaches and wall-clock scheduling.

### B-043 · Fight deaths persist into the graveyard (evolution mode)
The graveyard could only be filled with the `/FSTATE` GM workaround — a fighter
that died in a fight came back fine, so the evolution/graveyard system never filled
from real play. Root: the server had the evolution *state* machine (states 0–5,
23000 burial, 22099 resurrection) but no fight ever wrote a death.

RE'd the rule: only the **evolution** fight mode is lethal (client `adu_0.aKl() ==
6`); ranked, "Tester" practice and PvE-challenge fights never persist deaths. It
is **server-authoritative** — the client sends no death report at end-of-fight
(only 26321 ack / 23003 requeue), and applies fighter state solely from a **6006**
roster push (`dx_2` case 6006 → `awy.b` → `ee_2.f`, state byte included). Downed
fighters land in state **2 (dead)**, not 3 (graveyard); 2→3 stays the player's
burial (23000).

**Fix**: `Fight.Evolution` flag (8000 kind byte **6**, `WE` case 8300); on
`checkFightEnd`, `persistEvolutionDeaths` sets every fighter that fell to 0 HP —
on either side — to state 2 (`FighterRepo.SetState`) and pushes 6006 to its online
coach. Only real persisted fighters count: synthetic opponents (sparring/challenge,
DB id 0, `isSyntheticCoach`) are skipped. The rule is minimal-correct "all downed
die"; the retail per-fighter death *chance* (effect-7 cards) is not modelled.
XP/tiredness/morale (the 8300 `OW` block) is a separate subsystem, deferred. The
direct-challenge evo flag now sets `Fight.Evolution`; **`/EVOFIGHT`** (GM) starts a
solo evolution practice fight so the chain is reachable without a second coach.

**Verified:** `unit` (`evolution_death_test.go`: a downed real fighter → dead(2)
even on the winning side, a survivor untouched, a NON-evolution fight persists
nothing, and synthetic fighters are never written / no phantom rows); `live`
(`/EVOFIGHT` with Loov's 7 titular fighters → `/ENDFIGHT lose` → server logs
`evolution fight deaths [...7 names]`, the DB shows all 7 at state 2 while the
un-fielded bench fighter stays state 1, and **zero client exceptions** on the
kind-6 CREATE_FIGHT + 6006 push).

### B-042 · Correctness sweep (inactive opcodes + resurrection odds)
A pass over long-standing small gaps. Research turned several "TODO" opcodes into
*decided* ones — sometimes the correct outcome is to do nothing, and documenting
why closes the gap.

- **8 InvalidClientVersion — now active.** `handleClientVersion` sends
  `[u8 major][u16 minor]` (the expected version) on a mismatch; the client
  (`oq_1`/`apN.r`) shows a modal and self-disconnects, so no server-side close is
  needed (which also dodges a write-queue/close race). `e2e`
  (`version_test.go`: a version-69 client gets opcode 8 with 2.70; the accept path
  is covered by every other login).
- **Resurrection is now a gamble (22099).** Previously always succeeded. The
  dropped card must carry a real resurrection effect (client effect **action 13**,
  `AI.aHI`) — the same gate the client applies via `akw_0.c`'s `aaF()` — and its
  `param[0]` is the success %. Roll `rand(1..100) <= pct` (mirrors `nz_1`): consume
  the card either way, revive only on success, refuse (no consume) a card with no
  resurrection effect. Required decoding the CoachCard (`aPp`) **effect array**
  (field 15): ground-truthed against `aPp.a()` — note floatParams uses an **i32**
  count, not the i8 DATA-FORMAT.md §6 implied, which would misalign the array.
  `gamedata.CoachCard.ResurrectPercent` decodes it (verified: 305/316/317/318=100,
  51=12, 53=10, 35=5, 137=1). `unit` (`cards_resurrect_test.go` real-data decode;
  `resurrection_test.go` roll boundaries/rate + handler revive/refuse/fail-consume
  against a real store).
- **1026 / 2302 / 3202 / 5202 — intentionally left inactive**, each for a
  documented, evidence-based reason (see OPCODE-INVENTORY): 1026 has no honest
  trigger in a monolithic server; 2302's whole 2300-series has no client handler
  (an empty payload would crash the client's decoder); 3202 can't fire because the
  server accepts every channel; 5202 would re-skin nothing (the overworld avatar is
  hair/skin/sex, already correct at spawn; the deck is delivered per-fight via
  8000). Fusion was found to already validate same-set inputs and roll a 60%
  success — the only unmodelled part is per-altar power levels (a reasonable
  single-altar approximation, not a bug).

### B-041 · Ladder / leaderboard panel (six boards)
The ranking window opened but every tab was blank. Root cause was two-fold. (1)
The panel is **six independent boards**, each its own opcode pair (client
controller `afl_1`): **1v1** `27500 dp_0 → 27501 azd_0`, **guild/clan**
`27502 pc_1 → 27503 ij_1`, **2v2** `27504 vg_1 → 27505 aka_0`, **seasonal
("Ligue Pro")** `27506 qk_2 → 27507 uj_0`. Only the first two opcode *numbers*
were handled, and **27502 was mislabeled as a 1v1 "compact page"** — it is the
guild board, whose rows are `clanName + leaderName + score` and whose reply the
client (`ij_1`, `if cB()==1`) **discards unless the echoed board id is 1**. 2v2
and seasonal were unhandled, so those tabs never populated. (2) The 1v1 reply's
row loop is `for j < (windowEnd − windowStart)` with **no bounds check**, so
`windowEnd` must equal `windowStart + len(rows)` exactly or the client reads past
the buffer → decode exception → blank list.

**Fix** (`handlers_ladder.go`): reclassified 27502/27503 as the guild board
(well-formed empty until guilds exist, board id pinned to 1); added 27504/27505
(2v2) and 27506 (seasonal); made `windowEnd = windowStart + len(rows)` structural
so no caller can desync it. Guild/2v2 return well-formed **empty** windows (no
guild/2v2 subsystems); the seasonal reply (`uj_0`, three monthly/quarterly/yearly
sub-lists) is **deliberately never sent** — its tab renders empty cleanly and the
other boards are independent, whereas a malformed 27507 would throw. The 1v1
board shows ranked coaches (`strength > 0`, seeded to 1000 on first ranked fight),
each row carrying rating/streak/wins/losses; the client derives rank number and
level/rank icon itself, and `myRank` (field 4) drives the self-highlight.

The remaining two tabs — **Coach** `27508 aa_2 → 27509 jw_0` and **Démon**
`27512 ow_2 → 27513 xn_2` — are the reputation family (demon/guild reputation, not
modelled). The Coach tab returns a well-formed empty reputation window; the Démon
tab lists the **24 overworld demons** (ids 1–24, 12/page) with 0 reputation and no
guild — real structure, honestly zeroed, rather than blank. The per-demon
drill-down (`27510 → 27511`, a DemonTotem or a Démon-row click) stays an empty
window; its "page" field was really the **statusFlag** (=1), so the earlier stub
was already byte-correct — just relabelled, with the 3-i64-per-row shape documented.

**Verified:** `unit` (`handlers_ladder_test.go`: a cursor replays the client's
exact per-board decode loop and asserts it consumes the whole payload — the
over/under-read that blanks the panel — plus board-id-1 and the u8-vs-i32 trailing
flags); `e2e` (`ladder_test.go`: a rated coach appears on the 1v1 board with its
stats and `myRank=1`; guild/2v2 come back well-formed empty; seasonal stays
silent); `live` (Loov set to strength 1500 → **1v1 tab shows N=1, Niveau
13(1500), Loov** — level 13 = the client's `1 + round((1500−1000)/2000·49)`; the
**2 vs 2**, **Clan** and **Ligue Pro** tabs each render with their own correct
headers and an empty list, **zero client decode exceptions**).

> **Correction (see B-046):** this entry called the panel "six boards" and labelled
> **27506/27507** the *seasonal / "Ligue Pro"* board, left deliberately silent. Both
> claims were wrong. `ladderInformationDialog.xml` has **SEVEN** tabs: 27506/27507 is
> the **"Tournoi"** tab (`ladderInformation.tournamentType1Tab`), and the real
> **"Ligue Pro"** tab (`ladderInformation.glickoRatingTab`) is a separate pair,
> **27514/27515**, which had no handler at all. The "Ligue Pro renders correctly"
> observation above was really the *Tournoi* tab rendering its static headers with no
> data. Both are served as of B-046.

### B-040 · Direct challenges ("Proposer un entraînement" / training fight)
One coach directly challenges another (instead of random matchmaking). RE'd the
26300-family flow; the wire handle throughout is the CHALLENGER's coach id.
Handshake:
- **26301** `hk_1` `[i64 targetCoachId][i8 evo]` — A challenges B →
  **handleChallengeInvite** (new `handlers_challenge.go`): a silent no-op if the
  target is offline/self or either coach is already fighting or in another
  challenge; else registers a `challenge` and pushes **26300** `wu_2`
  `[i64 handle][i8 outgoing][i8 evo][i8 nNames]{[i32 len][name]}` to B (incoming,
  name=challenger) and to A (outgoing "waiting", name=target).
- **26305** `vT` — B accepts → **handleChallengeAccept**: only the TARGET can
  accept; pushes **26302** `pu_1` `[i64 handle][i8 evo]` to both (they open the
  team panel).
- **26307** `mz_0` — B declines OR A cancels → **handleChallengeDecline**: drops
  the challenge and tells the other side **26304** `gz_0` `[i64 handle]`.
- **26303** `bl_1` `[i64 coachId][i16 teamId]` — team confirm. `handleFightReadyConfirm`
  now branches: a coach already IN a fight → the in-fight "Prêt"
  (ready-for-placement, unchanged); a coach in an ACCEPTED challenge → record its
  team, and once BOTH confirm, `startChallengeFight` builds both teams and calls
  the normal `startFightWithTeams` (non-practice) → the standard `8000` fight.

State lives in a new **`ChallengeManager`** (`challenge.go`, mirrors the
Matchmaker): thread-safe `Create`/`Accept`/`ConfirmTeam`/`Remove`, both coaches
mapped to the one challenge, at most one challenge per coach. `Deps.Challenges`
wired in `cmd/server` + both test harnesses. A disconnect cancels a pending
challenge and notifies the other coach (26304, in `session.go onClose`). Opcodes
`OpChallengeInvite/Invitation/Accept/Accepted/Decline/Cancelled` added.

Scope: only the **1v1 training** path (evolution flag carried through verbatim);
the X-vs-X-with-allies variant (26313/26314) and the setup-abort reason codes
(26310/26312) are not implemented.

`unit` (`TestChallengeManager`: create/one-per-coach/target-only-accept/
double-accept/both-confirm-starts/remove/other/evolution). `e2e`
(`test/e2e/challenge_test.go`, the two-coach path the single GUI client can't
drive): **TestDirectChallenge** — A→B, B & A get 26300 with correct
incoming/outgoing flags + handle, B accepts, both get 26302, both confirm 26303,
both receive CREATE_FIGHT(8000); **TestDirectChallengeDecline** — decline → 26304
to A, no fight.

### B-039 · Spectators (watch an ongoing fight)
Read-only spectating, reusing the B-038 `sendFightResync` snapshot path. Client
flow (RE'd earlier): the client asks whether a coach is in a spectatable fight
(**2260** `py_0` `[i64 coachId]` → **2261** `wv_2` `[i8 spectatable]`), and if so
offers "enterSpectatorMode" which sends the join (**26331** `x_0` `[i64 coachId]`).
- **handleSpectateQuery** (new `handlers_spectate.go`): replies 2261 = 1 iff
  `Fights.ByCoach(id)` is a live (non-ended) fight, else 0. Reads phase off the
  atomic (no actor hop).
- **handleSpectateJoin**: for a caller not already in/​watching a fight, binds the
  session as a spectator and, on the fight actor, adds it to the new `Fight.spectators`
  list, removes it from the overworld (SetInFight + despawn), and replays the fight
  via `sendFightResync(sess, f, spectator=true)` — the same snapshot as a resume but
  with the CREATE_FIGHT **spectator flag** set and an empty action deck (a spectator
  can't cast).
- **broadcast** now also reaches `f.spectators`, so a spectator sees every
  move/cast/turn frame and the final END_FIGHT(8300).
- A spectator **cannot act**: it owns no fighter and is not in `Fights.ByCoach`, so
  every fight-command handler no-ops for it.
- **Lifecycle**: `Session.spectating` links a viewer to its fight (touched only by
  that session's own goroutine — the actor owns the reciprocal slice, so no race).
  On fight end the spectator receives END_FIGHT and is returned to the overworld by
  the existing `handleEndFightDone` (now also clears `spectating`); on disconnect
  `onClose` posts `removeSpectator`.
- Opcodes `OpSpectateQuery=2260` / `OpSpectateReply=2261` / `OpSpectateJoin=26331` /
  `OpSpectateTeardown=26332` (26332 defined, not yet emitted). `buildCreateFight`
  gained a `spectator bool` param (byte-identical except the flag).

`unit` (`TestCreateFightEncodes`: the spectator blob differs from the player blob by
exactly one byte). `e2e` (`test/e2e/spectate_test.go` `TestSpectateFight`, the
three-client path the single GUI client can't drive): a 3rd client queries
2260→2261=1 for a fighter and =0 for a non-fighter, joins 26331, receives
CREATE_FIGHT(8000)+FIGHTER_TURN_BEGIN(8104), and receives END_FIGHT(8300) when a
player gives up.

Same documented limitation as resume: active buff/debuff icons aren't restored in
the snapshot (server keeps the buffs working). 26332 local-teardown isn't used —
spectators end via the normal END_FIGHT + overworld return.

### B-038 · Mid-fight RESUME (reconnect back into an ongoing fight)
Completes the B-034 reconnect seam: a coach who dropped mid-fight can now rejoin
and keep playing instead of being forfeited on return. RE'd the client flow —
resume is **server-pushed**: on reconnect the server pushes the empty QUESTION
**26333** (`uz_0`) while the coach is in the lobby; the client shows a Yes/No
`reconnectionInFightQuestion` dialog and replies **26334** (`aiw_1`, `[i8 accept]`
1=resume / 0=decline).
- **enterWorld** (`handlers_connection.go`): a returning coach whose team is still
  `Absent` in a live fight is now offered resume (push 26333) instead of being
  force-forfeited. The 60 s reconnect grace keeps running, so a coach who never
  answers still forfeits.
- **handleReconnectFightAnswer** (new `handlers_reconnect.go`, registered in
  `RegisterAll`): on **accept** it re-attaches the session to its `FightTeam`
  (clears `Absent`, restores `Session`, `stopGrace()`), re-marks the coach in-fight
  (SetInFight + despawn from the lobby), and replays the fight; on **decline** it
  `forfeitCoach`s.
- **sendFightResync**: replays the fresh-start sequence to the one returning
  session, sourced from CURRENT state — EnterInstance(4600, dynamic arena) →
  CreateFight(8000) → ActorAppear(4102, current cells) → FIGHTER_DIES for the
  fallen → the phase cues fast-forwarded to the live phase (8010→…→8040) → the
  current NewTableTurn(8100) + FighterTurnBegin(8104).
- **writeCombatFighterBlob** now emits the live `hpLost/mpUsed/apUsed` deltas
  (`max − current`) instead of hardcoded 0 — byte-identical at a fresh start (all
  full) but carrying real damage/spend on a resync.
- Opcodes `OpReconnectFightQuestion=26333` / `OpReconnectFightAnswer=26334` added.
- **LIMITATION** (documented): active buff/debuff icons are not restored (the
  CREATE_FIGHT effects/conditions slots are still sent empty) — the buffs keep
  working server-side, only their client icons are missing until they expire.

`e2e` (`test/e2e/reconnect_test.go`, the two-coach path the single GUI/practice
client can't drive): **TestReconnectResumeFight** — A drops, reconnects, is pushed
26333, accepts with 26334(1), receives CREATE_FIGHT(8000)+FIGHTER_TURN_BEGIN(8104),
and the fight keeps going (opponent gets no END_FIGHT); **TestReconnectDeclineForfeits**
— decline (26334=0) → opponent END_FIGHT. The old `TestDisconnectGraceThenForfeit`
was updated to `TestDisconnectGraceHoldsFightForResume` (return now offers resume,
not an instant forfeit).

Also fixed a **pre-existing** e2e bug found en route: `TestFullFightToVictory`
waited for END_FIGHT before the winner's WalletUpdate(4001), but the reward is
broadcast BEFORE END_FIGHT (`awardFightWin` precedes `buildEndFight`), so the
END_FIGHT wait consumed the 4001 and the reward wait timed out — reordered the
test to the wire order.

### B-037 · Scaled-damage element (audit item J) + hit-location deferral (K)
- **J · AP/MP-scaled damage is now ELEMENTAL.** The effect ids whose damage
  scales by the caster's current AP/MP (`151`/`152` neutral, `156`/`157` fire,
  `158`/`159` air, `160`/`161` water, `162`/`163` earth — the client tooltip's
  "par PA/PM possédé") were dealt as **raw neutral** HP loss, bypassing the
  target's resistances. `applyScaledDamage` now routes the scaled value
  (`perPoint × current AP|MP`) through `computeElementalDamage` with the effect's
  element (`damageElement` extended with the scaled ids) and the rebound step,
  exactly like a normal elemental hit. `unit` (`TestScaledDamageElement`: id→
  element map; AP-neutral 18; AP-fire 12 −50% res → 6; MP-earth 12 −flat 2 → 10;
  scaled hit feeds rebound). No practice spell casts a scaled effect, so it rides
  the damage path already live-verified in B-036 (client renders the value
  verbatim under the effect's own action id).
- **K · Hit-location / facing directional damage — deliberately NOT implemented.**
  The v2.04b engine has directional damage (`hitLocationBonus`: back +30% / side
  +15% / front +0%, gated on the effect's `affectedByLocalisation` flag). 2.70
  **dropped it**: the effect record still carries field 7 `affectedByLocalisation`
  (documented as unmodeled in `gamedata/effects.go`), and the 2.70 client i18n has
  zero front/side/back damage tooltips. Implementing it would fabricate a mechanic
  the client neither drives nor renders, so it is an intentional gap (same posture
  as the flat AP/MP-resist "no dodge roll" decision and the inert STATE_APPLY
  registry).

  > **Correction (see B-045):** this entry originally justified the gap partly by
  > claiming the server "has no facing infrastructure … no direction-change opcode
  > (no 4521 equivalent)". **That premise was wrong** — 2.70 *does* have
  > `4521 FighterActorDirectionChangeRequestMessage` / `4522
  > FighterChangeDirectionMessage`, and the client sends 4521 during fights. Facing
  > is now tracked and broadcast (B-045). The **conclusion is unchanged**: facing is
  > purely cosmetic and never feeds the damage formula, because the *damage* half of
  > the mechanic (the `hitLocationBonus` table and its tooltips) really is absent
  > from 2.70.

### B-036 · Damage-formula stat batch (audit items F/G/H/I)
Four more fight-system gaps, each ported from the proven v2.04b damage engine and
folded into the existing `combatStats` profile (new SCALAR characteristics fed by
the same buff/card machinery as the elemental stats — `Stats.apply` +
track/revert + `summary()`):
- **F · AP/MP-loss resistance (esquive PA/PM, actions 86/87).** New scalar stats
  `resAPLoss`/`resMPLoss` reduce every AP/MP drain by the reference flat-percent
  model `removed = v − trunc(v*resist/100)` (floor 0, negative resist amplifies,
  clamp to [-100,100]) — NOT a probability dodge. A plain LOSS (16/20) resists the
  full roll then caps at the current resource; a STEAL (85/103) caps at the current
  resource first, then resists, and the caster gains the resisted amount (mirrors
  v2.04b CharacLeech). `unit` (7-case formula pin + loss/steal/immune/negative/
  buff-revert scenarios).
- **G · Damage rebound (action 89, "Renvoie les dégâts").** New scalar stat
  `dmgRebound` (0-99) reflects a share of every mitigated elemental hit back to the
  attacker: `rebound = final*pct/100`, subtracted from the victim's damage and
  dealt straight to the attacker as neutral HP loss (single hop, no re-rebound, no
  transfer), guarded by `caster != victim`. Hooked into the single-target damage
  path (`applyDamageEffect`) and close-combat. Unlike the v2.04b reference — which
  leaves the caster's loss un-broadcast (a documented gap) — the reflected HP IS
  broadcast, matching the 2.70 damage-transfer (129) convention so the attacker's
  gauge stays in sync. `unit` (50% reflect, no-stat, self-hit guard, 99% clamp +
  lethal-to-attacker, buff feed).
- **H · Push/pull collision parity.** The collided-into fighter now takes the same
  collision damage on a PULL as on a push (v2.04b `applyPushPull` damages the
  obstacle regardless of direction); coefficients already matched (6/cell into
  void, 3/cell into a fighter). `unit` (pull into a blocker: both take 9).
- **I · Heal power (actions 78 up / 79 down).** New scalar stat `healPct` scales
  every heal the caster casts: `healed = base*(100+healPct)/100` (integer trunc,
  clamp [-100,100]) — a port of v2.04b `ComputeHeal`. `unit` (+50%/-50%/0% +
  buff apply/revert).

Plumbing: `combatStats` gained the four scalar fields + a `scalarStatOps` map;
`combatStats.apply` and the new `isStatBuff` predicate (used by `applyBuff` and
`computeFighterStats`) now cover elemental AND scalar buffs; the `activeBuff`
`elemental` flag was renamed `statBuff` (it reverts both). `summary()` (the
`/fight` dump) now prints `resLoss`/`rebound`/`heal`. **LIVE** (practice, /script):
a normal cast still lands damage through the refactored universal path (rebound a
no-op at rate 0) — Poolcheck spell 4 → Tanko −15 HP; the buff→`combatStats`→
`summary()` pipeline the scalar stats ride works end-to-end — a Feca armor cast
showed `stats[…Res…]` +25% all-element resist that visibly reduced a follow-up hit
(15→7); a self-buff raised MaxHP 75→100 with `allRes10%/allDmg15%`; zero client
decode errors throughout. (No practice spell carries a scalar action 86/87/89/78/
79, so the scalar mechanics themselves are unit-only, like the batch-A–E tackle/
rebound cases.)

### B-035 · Combat-mechanics + ladder batch (audit items A/B/C/D/E + P2)
Six gaps from the fight-system audit, each ported from the proven v2.04b reference
(or RE'd from the client) and verified:
- **A · Spell cast-frequency limits.** The spell record's fields 7/8/9 (decoded and
  discarded) are now stored: `CastMaxPerTarget` / `MinCastInterval` / `CastMaxPerTurn`
  (field 7 is the loader's misnamed "maxPerPlayer" but is semantically per-target).
  A per-fighter `spellCastHistory` (port of `SpellCastHistory.java`) enforces them in
  `castSpellByFighter` and resets per-turn counters in `beginTurn`. Closes the
  "recast a once-per-turn nuke/summon unlimited times" exploit. `unit` + `live`
  (Iop spell 8, perTurn=1: 2nd cast blocked, AP unchanged; re-castable next turn).
- **B · Poison / DoT scheduler.** Poison (61) now tracks an `activePoison` per
  victim (caster/params/turnsLeft) and re-rolls + re-applies it at each new table
  turn (`tickPoisons`), after the immediate first tick — a port of
  `ActiveEffectPoisonTick`. Real data confirms multi-turn poisons (Sadida 173 =
  3-turn, 455/458 infinite). `unit` + `live` (spell 193 = 5 dmg/round × duration).
- **C · Tackle / lock (zone-of-control).** `tackle.go` (port of v2.04b): leaving a
  cell orthogonally adjacent to a living enemy requires an evasion roll (67% each,
  ALL must pass; 4+ adjacent = impossible) — a fail forfeits the move and ends the
  turn, broadcasting `FIGHTER_TACKLED 4506` (`acg`, 24-byte format decompile-
  verified); and a walk stops on contact (`truncatePathOnEnemyContact`). Wired into
  `handleFighterMoveInFight`. `unit` (adjacency, truncate, 67% distribution, 4+/0).
- **D · Critical hits & fumbles.** Effect field 11 `IsCritical` is now decoded;
  fighters carry `CritRate/FumbleRate` (breed base 5/1 + card/buff actions 70/71,
  now mechanical). Each cast rolls fumble then crit (`rng+1 <= rate`): a fumble
  spends AP but applies nothing, a crit runs the spell's `isCritical` effect subset
  (`selectEffectsForCrit`); the crit/fumble flag rides the existing `buildSpellCast`
  bytes. `unit` (crit→15 / normal→10 / fumble→no-effect) + `live` (crit-rate buff
  spell 14 raised Poolcheck 5→35 via the correct normal subset).
- **E · Close-combat (weapon attack).** New opcode **8111** `CloseCombatRequest`
  (`aso_0`) → `handleCloseCombat`: an adjacent-enemy melee costing `closeCombatAP`
  (5) for the breed's close-combat element damage (`closeCombatDamages` 5 /
  `closeCombatCritDamages` 7 on a crit), replying **8112** `CloseCombat` (`aAD`,
  17/28-byte format decompile-verified). Per-breed close-combat elements added to
  the breed table. `unit` + `live` (injected 8111 → Poolcheck −5 AP, Sparring −5
  earth HP, no client error).
- **P2 · Ranked ladder now moves.** `checkFightEnd` applies
  `domain.ApplyFightStrength` (±25, seed unranked→1000, clamp [1000,3000] — a port
  of the client's `DofusArenaConstants` ladder model) to each real coach and
  populates the 8300 `YP` **strength maps** (`bA`/`bB` = `{i64 coachId, i32
  strength}`, previously sent empty) so the results screen shows the new Level/Rank.
  `unit` + `e2e` (`test/e2e/fightladder_test.go`: two real coaches, one gives up →
  winner Strength 1025 / loser 1000 persisted).

### B-034 · Mid-fight disconnect — grace period + forfeit (reconnect-ready)
A coach dropping its connection mid-fight used to call `endFight`, which just
tore the fight down and teleported everyone to the overworld — the surviving
opponent got **no victory** (no `END_FIGHT 8300`, no win/loss stat, no reward),
despite `endFight`'s comment claiming it "declared the remaining coach winner".
- **RE finding (why not just insta-forfeit):** the 2.70 client — unlike 2.04b —
  **supports reconnecting to a live fight** (S2C `26333` pops
  `reconnectionInFightQuestion`, C2S `26334` answers; it also spectates via `2261`
  + `26331`). The client's model is *keep the fight alive, turn-pass the absent
  coach, offer reconnect, and only finish with the normal 8300*. There is no
  dedicated "player left" packet. So an instant end fights the client's design.
- **Fix (grace period + forfeit, reconnect-ready):** a disconnect now routes
  through `coachLeftFight` (was `endFight`). A **practice** fight (synthetic
  opponent) still tears down. A **real** fight is KEPT ALIVE: the leaver's team is
  flagged `Absent` + its `Session` detached, its in-progress turn is passed at once,
  and its turns thereafter auto-pass (a new `beginTurn` case — the fighters are NOT
  AI-played, since the coach may return). An **independent grace timer**
  (`disconnectGraceClock`, its own generation so a turn-clock never cancels it)
  forfeits the absent coach if it doesn't return; the opponent can also just win by
  killing the idle fighters. If **both** sides are absent the fight tears down.
  Forfeit is unified in `forfeitCoach` (kills the coach's whole team incl. summons →
  `checkFightEnd`), now shared by the give-up button, the grace timeout and the
  return path. A returning coach (relogin, `enterWorld`) forfeits the abandoned
  fight so it resolves and the coach is freed — the **reconnect-ready seam** where a
  later full RESUME (the `26333`/`26334` + `EnterInstance 4600 dynamic` →
  `ActorSpawn 4096` replay) would instead re-attach and resync.
- **Verified:** `unit` (`internal/game/disconnect_test.go`: fight survives a single
  drop + team flagged absent + the leaver's turn is passed + grace/return forfeit
  hands the opponent the win with stats; both-absent tears down; practice tears
  down) · `e2e` (`test/e2e/disconnect_test.go` — TWO real coaches matchmade into a
  real fight over the wire; dropping one coach's TCP socket yields NO instant
  `END_FIGHT` (grace holds it open), and the coach returning to the world forfeits
  so the opponent receives `END_FIGHT 8300` — the win the old insta-teardown never
  delivered; stable ×3) · `live` (a normal practice turn still casts fine — the new
  `beginTurn` case doesn't disturb play — and a client drop from a practice fight
  logs a clean `fight ended (teardown)`, no panic). Only the FULL mid-fight RESUME
  (26333/26334 re-attach + `ActorSpawn 4096` resync) remains unverified; the
  forfeit victory path is now wire-proven. (The single-client GUI/MCP harness can't
  drive a two-coach disconnect — no second real coach in a practice fight and no
  close-client-without-killing-the-server control — which is why the e2e wire
  harness is the right tool here.)
- Also corrected two stale comments the audit flagged: `resolveMatchAccept` (real
  matchmade fights ARE created via `startFight`) and `endFight` (it declares no
  winner; the disconnect victory path is `coachLeftFight`).

### B-033 · Action 149 "Retire un effet" — targeted effect removal (closes the B-032 nuance)
The remaining B-032 nuance — on a mask *switch* the displaced mask's self-aura and
stat malus lingered — is now fully resolved by implementing the general
targeted-removal mechanic the client uses, effect **action 149** (handler `dw_0`).
- **Client spec (RE'd from `dw_0.java`):** 149 iterates the target's running-effects
  and removes every one whose **source effectId** (`bWj.ST()`, field 1 — NOT
  actionId/parentId/spellId) equals `params[0]`; `params[1]` caps the count
  (default −1 = all), `params[2]` is an optional gate. Removal is delegated to each
  effect's ordinary unapply (`aky()`→`aK()`) — i.e. **identical to an early
  expiry**: the state bit is cleared, the buff's characteristic reverted, the aura
  area destroyed. It is a fully general mechanic (mask spells are just its heaviest
  user).
- **Server implementation:** every applied buff/state/aura now carries its **source
  effectId** — `activeBuff.effectID` (+ an `infinite` flag), `FightFighter.stateSrc`
  (a `state→effectId` map, stamped in `applyState`), and `effectArea.effectID`.
  `KindRemoveEffect` (149) → `applyRemoveEffect` → `removeEffectByID(ff, effectId,
  limit)` strips matching buffs (via the new shared `revertBuff`), states, and
  self-placed auras, and broadcasts the 149 so the client's `dw_0` drops the same
  effects. **Infinite buffs are now TRACKED** (flagged `infinite`, skipped by
  `tickBuffs`/`applyDispel`) instead of fire-and-forget — required so a mask's
  permanent (`dur=[63,0]`) malus can be reverted by 149. This **replaces the B-032
  ad-hoc mask-state exclusivity**: masks are now made mutually exclusive purely by
  the shipped data (each switch spell bundles ~15 action-149 removes), so the whole
  displaced mask — state, malus AND aura — is stripped, not just the state.
- **Data (enumerated from `data.bdat`):** each mask = distinct effectId per
  component — Class state `9192`/malus `9213`(102 MP−)/aura `9260`(176 tmpl1017),
  Coward state `9193`/malus `9215`(73 range−)/aura `9261`(1018), Berzerk state
  `9194`/malus `9217`(81 res%−)/aura `9262`(1019). Spell 471 (→Berzerk) removes the
  Class+Coward components (`9192,9213,9260,9193,…`), etc. Only 5 shipped spells use
  149 (15 Ecaflip, 444 Rogue, 471/472/473 masks) — all handled generically.
- **Verified:** `unit` (`TestRemoveEffectByID`: a Class bundle — state + infinite MP
  malus + aura — each stripped and reverted by its effectId, and the infinite malus
  is NOT aged by a normal tick; rewritten `TestMaskStates`; `TestBuffLifecycle`
  updated for infinite-tracking) · `live` (cast Class 473 → `[maskCls]`, MP 3→2,
  aura 1017; switch to Berzerk 471 → `[maskBzk]` ONLY, **MP reverted 2→3**, aura
  **1017 gone**, only 1019; switch to Coward 472 → `[maskCow]` ONLY, **Berzerk
  `allRes-25%` reverted**, aura **1019 gone**, only 1018; zero client decode errors
  across all 17-per-switch removal broadcasts). Nothing lingers on a mask switch —
  the carry/aura/mask exotic-effect line is now complete with no deferrals.

### B-032 · NB_SUMMONS + Masqueraider masks (closes the B-031 deferrals)
The three items B-031 consciously left behind, now resolved with client-RE +
real-data evidence (v2.04b cross-checked where it existed):
- **NB_SUMMONS characteristic (action 74) — now mechanical.** `criteria.go`'s
  `canSummon` was `livingSummons < 1 + nbSummons()` with `nbSummons()` hardcoded 0,
  so the cap was stuck at one. The client (`ahG.java`) reads characteristic
  `Lr.bqW` = **id 26**, and effect **action 74** ("Augmente le nombre d'invocs",
  `mh_2.java:83`, bound to `Lr.bqW`) raises it — exactly as the v2.04b reference
  applies it (`74 → NbSummons`). Wired: new `BuffSummons` `BuffResource` +
  `resourceBuff[74]`, a `FightFighter.NbSummons` field, an `applyResourceDelta`
  case, and `nbSummons()` reads the field. **Two subtleties the shipped data
  forced:** (1) action 74 is **param-signed** — spells 55/79/450 (Osamodas/Sadida/
  Rogue) carry `params=[1] dur=[63,0]` (a permanent +1 slot) while spell 476
  (Masqueraider) carries `params=[-1] dur=[1,0]` (a 1-turn summon-*steal*); since
  `Roll()` returns a positive magnitude, the buff uses `signedFirstParam` so the
  steal subtracts. (2) NB_SUMMONS is stored **unclamped** (the client charac is
  bounded by Integer.MIN/MAX): a steal can push the effective cap (1+NB_SUMMONS)
  to 0, and clamping-at-write would break apply/revert symmetry (a steal on a base
  summoner would leak a summon back on expiry). Infinite (+1) buffs apply
  permanently (untracked); finite (−1) steals are tracked and reverted.
- **Masqueraider masks (actions 173/174/175) — now settable.** The three mask
  states (`stateMaskClass/Coward/Berzerk`) had no setter, so their
  `canCastWhenMask*` criteria were dead. The client grants them via three distinct
  effect ids — **173 Class / 174 Coward / 175 Berzerk** (`mh_2.java:168-170`,
  handlers `acl_2`/`Ew`/`akp_2` → states `avx_0.deH/deI/deJ`), shipped on spells
  **473/472/471** (`dur=[63,0]` infinite). Wired into `effectkind.go` (`KindState`)
  and `stateByAction`. Masks are **mutually exclusive**: `applyState` strips the
  other two when one is donned (the client does this via the grant spell's bundled
  removes + each spell's `cannotCastWhenMask<self>` self-gate). NB: they belong to
  breed 14 (Masqueraider), **not** the Sram (breed 4) — B-031's "Sram masks" note
  was a misnomer.
- **akw_0 coach-card criteria — deliberately NOT implemented (verdict, not a
  punt).** Deep RE (`akw_0.java` + 20 subclasses, `AI.java:6-26`, `aap.java`)
  proves it is a post-fight **reward/roster meta** system: every subclass modifies
  XP / drops / injuries / death-chance / morale / fatigue / resurrection /
  reputation / "apply a persistent condition", and **none** touch live combat
  (HP/AP/MP/cells/spells). It has **no protocol dependency** — the client reads
  full card definitions (criteria included) from its own local `data.bdat`; the
  server transmits only ownership (template ids/quantities/equip slots), which it
  already does. Both servers run fights correctly with it unparsed; v2.04b ignored
  it entirely. The current parser (`cards.go`) reads type-100 fields 1–5 and stops
  — correct and safe. (If the reward *economy* is ever wanted, the work is scoped
  in memory: parse fields #15/#19, port the 20 subclass effects + `aap` mask
  predicate + `adl_0` fold + `operator`=set-tier logic + the `aiz_2` condition
  system.)
- **Verified:** `unit` (`TestNbSummonsBuff`: infinite +1 persists through a tick,
  param-signed −1 steal reverts symmetrically; `TestMaskStates`: set → criteria →
  exclusive switch → infinite no-age) · `live` (real spell 55 lifted Poolcheck's
  cap 1→2, second Gobball then summoned on a fresh 6-AP turn; mask spell 473 set
  `[maskClass]`, its re-cast was blocked by `cannotCastWhenMaskClass`, spell 471
  switched to `[maskBzk:63]` stripping Class; zero client decode errors throughout,
  incl. the masks' bundled resistance malus + self-auras).
- **Remaining nuance (documented, not hand-waved):** on a mask *switch* the
  displaced mask's self-aura (`template 1017/1019`) and stat malus linger, because
  the real client removes them via the grant spell's bundled **action-149** "Retire
  un effet" entries. Faithfully modelling that needs a general targeted-effect-
  removal mechanic (per-effect-id tracking on buffs/states/areas) — a separate
  subsystem, breed-14-only, absent from the practice flow. The core mask STATE +
  criteria gating (the actual B-031 gap) is complete; the state is always
  single-masked, so criteria are always correct.

### B-031 · Spell cast-criteria + carried-fighter occupancy (completes B-030)
- **Full criterion parsing (`criteria.go`):** the spell's field-20 `criterion`
  string (previously discarded) is now decoded and enforced. It is a
  `;`-separated list of case-insensitive named tokens combined with implicit AND
  (empty = no gate, unknown = permissive) — NOT an operator grammar — ported from
  the client's CriteriaCompiler (ahp_1). All 15 tokens implemented, reading only
  caster state: `canSummon` (living summons < 1+NB_SUMMONS), `can/cantCastWhen
  Carrying`, `cantCastWhenCarried`, `canCastWhenDying`/`Injured` (HP ≤ 25%/99%),
  `canCastWhenDrunk`, `can/cannotCastWhenMask{Class,Berzerk,Coward}`,
  `canCastWhenCarryAlly`/`Ennemy`. Enforced in `castSpellByFighter` before AP is
  spent — this SUPERSEDES the B-030 hardcoded carry check (which wrongly blocked a
  carried fighter from casting ANY spell; the real data marks only 4 spells with
  `cantCastWhenCarried`). Real data uses all 15 token families (57 spells;
  `cantCastWhenCarrying`×24, `canSummon`×18). Drunk (126) moved from a render-only
  KindVisual to a tracked KindState so `canCastWhenDrunk` can read it; the three
  Sram mask states are tracked-but-unset (their `canCastWhenMask*` spells stay
  gated off — faithful, as no effect grants a mask yet).
- **Carried-fighter occupancy:** `cellHeldByOther` and `cellOccupied` now skip a
  carried fighter — it is held on its carrier's cell and is not an independent
  board obstacle (the carrier already holds the cell).
- **Verified:** `unit` (TestCastCriteria, rewritten TestCarryCastGating with real
  criterion tokens) · `live` (drunk spell 407 → `[drunk:63]` state rendered, no
  decode error; summon spell 110 cast twice → the SECOND was blocked by `canSummon`
  at the 1-summon limit — fired=false, timeline unchanged, cell adjacent + AP
  available). This closes the carry/aura work with nothing left behind.

### B-030 · Carry/aura fidelity polish — cast gating, untargetability, aura target conditions
- **Cast-while-carried gating** (`castSpellByFighter`): a carried fighter cannot
  cast at all; a carry spell (a KindCarry effect) needs an empty grip; a throw
  spell (KindThrow) needs to be carrying someone — mirrors the client's
  cantCastWhenCarried / can(t)CastWhenCarrying criteria, rejected before AP spend.
- **Carried-fighter untargetability** (`fighterAtCell`): a carried fighter, which
  shares its carrier's cell, is skipped by the single-target selector, so a cast
  on that cell resolves onto the carrier (the front fighter) — the carried one is
  protected. (Area effects still catch it; only single-target is redirected.)
- **Aura target conditions** (`fireEffectArea`): an aura ticks everyone in its
  radius, so its inner effects now respect their target-condition mask (an
  enemies-only debuff aura skips allies). A trap still fires unconditionally on
  whoever stepped on it (unchanged, preserving B-025).
- **Verified:** `unit` (TestCarryCastGating, TestCarriedUntargetable,
  TestAuraTargetFilter). Logic-only — no new wire message — building on the
  live-verified carry/aura paths (B-029).

### B-029 · Hard exotic batch — carry/throw, aura, line/zone damage, damage-transfer
- **Carry/throw (58 "Porter" / 59 "Jeter"):** direct port of the v2.04b resolver
  (`carry.go`). Bidirectional `CarriedFighter`/`CarriedByFighter` links; carry
  stacks the target on the caster's cell, moving the carrier drags the passenger,
  throw drops it at the target cell (no landing damage from the carry itself);
  a carried fighter dismounts when it walks, and death breaks the links.
- **Aura (176 "Pose une aura"):** a caster-FOLLOWED effect area — `effectArea`
  gained `follow`/`turnsLeft`; its centre tracks the caster's live cell, it fires
  on turn-start for fighters in radius (reusing `checkEffectAreasTurnStart`, but
  never on its own caster), lives for its duration and dies with the caster.
- **Zone MP-loss (177):** `applyZoneMPLoss` drains `params[0]` MP from every
  fighter in the spell's zone centred on the CASTER (caster excluded).
- **Line damage (178-181):** `applyLineDamage` hits every fighter in the
  axis-aligned bounding box spanned by caster↔target (both excluded), each via the
  real elemental formula, no flanking bonus. `damageElement` extended (178 fire /
  179 water / 180 air / 181 earth).
- **Damage transfer (129):** no v2.04b reference — a derived link (`damageTransfer`
  on the fighter) hooked in `applyHPDelta`: a % of the bearer's incoming damage is
  redirected to the caster (one hop, no re-check). Direction/percentage may need
  live refinement.
- **Verified:** `unit` (TestCarryThrow, TestLineDamage, TestZoneMPLoss,
  TestDamageTransfer, TestAura) · `live` (Pandawa spell 126 carried Tanko onto
  Poolcheck → walking dragged him → spell 127 threw him to (10,15); spell 468
  line-fire hit Tanko in the box for 10, sparing the off-row Sparring; spell 463
  placed 3 caster-followed auras — all with no client decode error). 129 has no
  castable spell in the shipped data (unit-only).

### B-028 · Exotic-effect batch — skip-turn, dispel, client-visual effects
- **Scope:** a batch of small deferred effects, resolved from their exact mh_2
  labels (decompiled `mh_2.java`):
  - **Skip-turn (56 "Fin de tour" / 111 "Passe son tour"):** a new `stateSkipTurn`
    — `beginTurn` passes the fighter's turn and consumes one skip (it is spent per
    skipped turn, not aged per round by `tickStates`).
  - **Dispel (62 "Désenvoûtement"):** `applyDispel` reverts every tracked buff
    (resource + elemental stat) and clears every timed state on the target.
  - **Client-visual effects (60/98 look change, 126 "Devenir ivre" drunk, 139
    "Redirection des dégâts (purement visuel)"):** new `KindVisual` — broadcast the
    running-effect so the client renders/animates it, with no server mechanic.
- **Classifier:** `KindDispel` + `KindVisual` added; 56/111 added to `KindState`.
- **Verified:** `unit` (TestSkipTurnState, TestDispel) · `live` (Tanko buffed via
  spell 32 → `[stab:5] stats[fRes0/25% aRes0/25%]`, then dispel spell 40 cleared
  ALL of it; drunk spell 407 rendered with no decode error). Skip-turn has no
  castable spell in the shipped data (trap/monster-only), so it is unit-only.
- **Still deferred:** carry/throw (58/59), aura (176), damage-transfer (129) and
  the zone-triggered MP/HP-loss variants (177/178) — they need real
  positioning/link/follow-caster models, not a render-only path.

### B-027 · Damage formula — elemental resistances + damage bonuses (buffs made mechanical)
- **Symptom:** combat dealt FLAT damage — the whole family of resistance/damage
  buffs (mh_2 21-55, 80-83) rendered on the client but did nothing, so every
  fight with a resist/damage buff was mis-scored, and the gap grew as more buff
  spells were used. This was the last big deferred piece of B-020.
- **Model (`combat_stats.go`, ported from the proven v2.04b `damage.go`):** a
  `combatStats` per fighter (per-element flat + % damage, per-element flat + %
  resist, all-element damage %/resist %). Populated from equipped-card passive
  effects at fight build (`computeFighterStats`; the breed contributes none) and
  mutated by in-fight buffs. Values stored unclamped so a timed buff reverts by
  exact subtraction; the Dofus bounds (flat resist ≥ 0, percents ±100) apply at
  read time.
- **Formula (`computeElementalDamage`):** `value = base + casterFlatDmg[e] −
  max(0,targetFlatRes[e])`, then a single percent modifier `casterDmg%(e+all) −
  targetRes%(e+all)` applied LAST, floored at 0. **Neutral/physical (and poison)
  bypass everything** (raw value) — verified against the v2.04b PHYSICAL
  short-circuit. Element from the action id: 1/130 neutral, 2/131 fire, 3/132
  earth, 4/133 water, 5/134 air (leech 6-10 same). `applyDamageEffect` now runs
  it; `applyBuff` applies the elemental stat buffs mechanically + reverts on
  expiry. The `/fight` dump shows a fighter's `stats[…]`.
- **Verified:** `unit` (TestDamageElement, TestElementalStatOpsApplyRevert,
  TestComputeElementalDamage — flat-before-percent, floor-at-0, clamps, neutral
  bypass; TestDamageWithResistBuff; TestBuffLifecycle updated) · `live` (Tanko
  spell 32 → dump showed `stats[fRes0/25% aRes0/25%]`; then ONE fire circle hit
  both Poolcheck (0 fire res, took **19**) and Tanko (25% fire res, took **14** =
  19×0.75 floored) — exact 25 % reduction, no client desync).

### B-026 · AoE geometry — the real zone size (decoder off-by-one) + Manhattan circle
- **Symptom:** every circle/cross/ring/T spell collapsed to a single cell (the
  fighter on the aimed cell, or NOBODY when that cell was empty). B-022 blamed
  "radius baked into the shape ordinal"; that was wrong.
- **Root cause 1 — decoder off-by-one.** The client's `Ht` effect record has SIX
  `int[]` arrays after `params`, then one `int64[]`: triggersBefore, triggersAfter,
  endTriggers, a **vestigial** array (`Tf`/`beH`, never populated → always empty),
  **areaSize** (`Tg`/`beI`, DB column `effect_area_size`), duration; then targets.
  `effects.go` read areaSize from the **4th** array (the empty vestigial one)
  instead of the **5th**, so every real zone arrived size-less and
  `areaFighters` hit its point-fallback. Fixed by reading the 5th array (duration
  and targets were already correct, so it is a safe one-line swap). Confirmed on
  real data (`TestSpellAreaSizeReal`): circle(2)=23, cross(3)=5, ring(5)=10,
  T-inv(9)=8 effects now carry a size; point(1) and all(32767) carry none.
- **Root cause 2 — Euclidean circle.** A Dofus "circle" is a **Manhattan diamond**
  (`|dx|+|dy| ≤ r`, client `nw_0`), not a Euclidean disk — they diverge at r≥3.
  `area.go` used `dx²+dy² ≤ r²`. Fixed, and the real shapes were added: ring (5,
  diamond annulus), square (6), and inverted-T (9, directional). T/inverted-T
  orient the stem along the caster→target cardinal step (client `sp_2`/`arG`).
- **Verified:** `unit` (TestSpellAreaSizeReal on real data; TestPointInArea now
  asserts the diamond-vs-Euclidean divergence at r3, plus ring + inverted-T) ·
  `live` (circle-r2 spell 128 cast at (8,15) between two fighters dist-1 apart →
  BOTH took 19 fire damage, the far fighter untouched, no client decode error;
  pre-fix the same cast on the empty centre cell would have hit no one).

### B-025 · Traps / glyphs — persistent ground-effect areas (action 66)
- **Scope:** the "Pose un piège" effect (mh_2 action 66, client handler `ds_1` /
  SetEffectArea) — recognised but skipped before. A spell effect with action 66
  places a persistent area on the battlefield that replays a template's inner
  effects on whichever fighter triggers it.
- **Data:** action 66's `params[0]` is a **type-210 StaticEffect** template id.
  New loader `gamedata/effectareas.go` decodes all 16 shipped templates (8 TRAP +
  8 SPECIAL) — id/type/label/areaShape/maxExec/appCondition + the trigger id
  arrays + the embedded inner-effect list (exact `rf_2` layout, string=`[i32]`,
  arrays=`[i32 count]`, BitSet stored as a plain id array). Validated against the
  known records (id=1 point trap, id=2 circle r2).
- **Runtime (`game/effectarea.go`):** `applySetEffectArea` places an `effectArea`
  (unique id, footprint, caster, `maxExec`) at the cast cell and broadcasts the
  action-66 RUNNING_EFFECT (no target fighter → target mirrors the caster, like
  teleport; the client reads the template id from the VALUE field). Triggering is
  server-authoritative: `checkEffectAreasMove` (hooked per step into
  `applyFighterMove`) fires a **walk-on** trap (trigger id 10001) when a fighter
  enters the footprint; `checkEffectAreasTurnStart` (hooked into `beginTurn`)
  fires a **turn-start** glyph/special (id 10000). Firing replays the template's
  inner effects through the normal resolver (each broadcasting its own
  RUNNING_EFFECT, so the client renders the trap's damage/state with no bespoke
  message), then decrements a finite `maxExec` and self-removes when exhausted
  (`>=63`/`<0` = unlimited). `KindTrap` added to the classifier; the dev `/fight`
  dump lists live areas.
- **Verified:** `unit` (loader real-data TestLoadStaticEffectsReal — 16 templates;
  TestApplySetEffectAreaPlacesTrap, TestTrapTriggersOnWalkOnAndExhausts,
  TestTrapWalkOnViaApplyFighterMove, TestTrapUnlimitedNotRemoved) · `live` (Sram
  spell 153 placed two circle-r2 traps at (8,13) with no client decode error;
  Tanko walked in → `[invis:3]` applied (walk-on 10001); Poolcheck standing in it
  at turn-start → `[invis:2]` (turn-start 10000); both areas persisted, unlimited).

### B-024 · Deep-combat test harness — the `/script` fight-scenario runner
- **Problem:** deep combat testing against the retail client was hand-driven raw
  `/c2s` opcode injection in a PowerShell poll-act loop, which fought the 30s turn
  clock and let short (1-turn) buffs/states expire between slow MCP tool calls — a
  scenario spanning several fighters' turns within ONE round could not be
  expressed reliably.
- **Fix:** a DEV-only `/script` endpoint (`game/debug_script.go`) that runs a whole
  fight scenario IN-PROCESS on the fight actor in milliseconds. `Fight.callSync`
  posts a closure to the fight mailbox and blocks for its result (a synchronous
  "call an actor" over the fire-and-forget `Post`), so each step touches fight
  state race-free. Commands (`;`-separated): `goto <wire> [ai]` (advance turns,
  skipping or AI-playing intermediates), `move`, `cast`, `castself`, `end`,
  `dump`, `wait`. `DebugDump` was refactored to a reusable `Fight.writeSnapshot`
  (now also prints `round=`); added `FightManager.Only()/Get(id)`.
- **Verified:** `live` — a single call did `goto Tanko → castself 34 (immune+stab)
  → goto Poolcheck (auto-skip the Sparring AI) → move (BFS) → cast damage at the
  immune Tanko`, and Tanko's HP stayed 70/70 (immunity blocked it); a second call
  confirmed the 1-turn state ticked away a round later; used throughout B-025.

### B-023 · Status states — root / petrify / stabilise / invisibility / immunity
- **Scope:** the state-effect family (mh_2 65/127 root, 96 petrify, 94/128
  stabilise/intransposable, 57 invisibility, 95/124 immunity) — recognised but
  skipped before. They now apply, render, tick down and are ENFORCED server-side.
- **Wire:** a state is an ordinary running effect (the standard 3-part blob,
  value 0, `Nx` = duration) whose action id selects the client handler that
  renders + tracks it — same shape as a buff (already proven). The server mirrors
  it with a per-fighter remaining-turn count (`states.go`, ticked each new round
  alongside buffs) and enforces the rule the client cannot on a server-driven
  (summon/AI) fighter.
- **Enforcement:** rooted (65/127) → `validateFightMove` + the AI movement reject
  the move (and MP is zeroed to match the client's rc_0); petrified (96) →
  `beginTurn` passes the turn on the short clock; stabilised (94/128) →
  `applyPushPull`/`applySwap` no-op on the target; invisible (57) → the AI's
  `nearestOpponent`/`minEnemyDistance` skip it; immune (95/124) → `applyHPDelta`
  blocks damage (a heal still lands). `KindState` added to the classifier; the dev
  `/fight` dump now prints a fighter's states (e.g. `[immune:1 stab:1]`).
- **Verified:** `unit` (TestClassifyState, TestApplyStateAndEnforcement,
  TestPetrifiedSkipAndTickStates) · `live` (Tanko spell 34 → `[immune:1 stab:1]`
  applied + client-rendered with no decode error; then Poolcheck cast a 25-damage
  spell 4 on the immune Tanko — it paid AP and animated but Tanko's HP stayed 45,
  the immunity blocking the damage).

### B-022 · Area-of-effect + target conditions — area spells hit the right fighters
- **Scope:** effects only ever touched the single fighter on the target cell.
  Area spells (circle/cross/T and the `32767` "Target: All" sentinel) now hit
  every fighter in the zone, and the per-effect **target-condition** mask decides
  who each expanded target legitimately affects.
- **Why it was subtle (2.70 data specifics):** an area spell's `AreaSize` field
  (16) is EMPTY in the 2.70 data (the geometric radius is baked into the shape
  ordinal — a later RE), so the common non-point area is `AreaShape 32767`
  ("all"), used by SELF-BUFFS: e.g. Iop spell 7 is `32767` with `Targets=[2]`
  (IS_CASTER). Naively expanding `32767` to "all living fighters" would have
  wrongly buffed the enemy team (a desync bug). The fix decodes the effect
  record's `targets` (field 19, i64[]) and ports the client's
  `FightTargetValidator` (`target_conditions.go`: IS_CASTER/ALLY/ENEMY/HUMAN/
  SUMMONED + breed bits; valid if ANY condition passes, a condition passing iff
  ALL its bits hold; empty = permissive).
- **Design:** AoE is server-authoritative — `area.go` `areaFighters` expands the
  aimed cell (point hit-test ported from v2.04b: circle = Euclidean r², cross =
  row/col arms, T = directional beam+bar, empty = all living) and the resolver
  applies the effect once per hit fighter (each broadcasting its own 8120 — no
  new wire). A single-target (point) effect is NOT re-filtered (the client
  already validated the aimed cell); only the SERVER-EXPANDED area/all targets are
  filtered by the target conditions. `resolveEffect` now dispatches
  positioning/summon single-target and loops `areaFighters` → `applyPerTargetEffect`
  for every cell-targeting kind.
- **Superseded:** the original note here claimed the geometric zone SIZE was
  "baked into the shape ordinal" (empty `AreaSize`), leaving circle/cross to fall
  back to point. That was WRONG — it was a decoder off-by-one; see **B-026**,
  which reads the real `AreaSize` and gives circle/cross/ring/T their true radius.
- **Verified:** `unit` (TestPointInArea, TestAreaFighters, TestAreaTargetConditions,
  TestResolveEffectAreaDamage) · `live` (spell 7 self-buff → Poolcheck MaxHP
  75→135 while ally Tanko + enemy Sparring stayed 70, proving the IS_CASTER filter;
  spell 9 hit-all → all three fighters took 5 in one cast; client rendered both
  with no decode error).

### B-021 · Summons + AI — summoned creatures spawn, render and are played by a built-in AI
- **Scope:** the summon effect family (67 "Invoque une créature", 75 "double", 97
  "mirror") plus the AI that plays any fighter no client controls (a summon AND
  the sparring opponent, which previously just idled until its turn clock).
- **Client wire (RE of `hy_1`/`api_0`/`mv_0`/`jz_2` + memory #180):** there is NO
  add-fighter message — the client CREATES the summon itself from an 8120
  RUNNING_EFFECT whose action id is 67/75/97. `hy_1.execute` builds the fighter
  via `gn_0.d(nv, cell, templateId)`, where **nv (the new fighter id) is read from
  part-2** (the `api_0` codec, same i64 wire as a normal target ref) and the
  **template id is read from part-0's VALUE field** (`yi_1.f` sets `r` = value —
  so no client compute path is needed, which is essential because the client's
  `adu_0.al()` id-allocator throws in a real fight). So a summon is just the
  standard `buildRunningEffect` with `value=templateId, targetWireID=nv`. The
  client then inserts the fighter into team + timeline + renders the avatar via
  the same `qg_2.g` path as ACTOR_APPEAR — no separate 4102.
- **Server:** `internal/gamedata/summonings.go` decodes the type-300 `jz_2`
  template (`id, HP, AP, MP, [i8]i32 spellIds, i32 look`; 53 templates load).
  `internal/game/summon.go` `applySummon` allocates a summon wire id in a
  collision-free namespace, builds the `FightFighter` from the template (Father =
  caster, SummonSpellID = template's first spell), inserts it into the team +
  the turn timeline right after the caster (matching the client so both timelines
  stay in lock-step), and broadcasts the 8120. `KindSummon` added to the effect
  classifier.
- **AI (`internal/game/ai.go` + `pathfind.go`, ported from the v2.04b
  `summon_ai.go`):** `reachableCells` is a 4-directional BFS movement flood
  (bounded by MP, blocked by fighters). `runAITurn` — armed from `beginTurn` on
  the short AI clock instead of a bare force-pass — derives the archetype from the
  fighter's spell (no spell → blocker; damage → aggressive/kite; debuff → kite;
  self-buff → self-buff), then closes to spell range (or adjacency), casts until
  dry, optionally retreats, and ends its turn. The move/cast internals were
  factored out of the handlers (`applyFighterMove`, `castSpellByFighter`) so the
  AI drives them exactly like a player.
- **Verified:** `unit` (TestApplySummon{,FallbackStatsAndBlockedCell},
  TestReachableCells, TestNearestOpponent, TestMoveTowardNearestOpponent,
  TestClassifyAIBlocker, TestRunAITurnBlockerEndsTurn, TestLoadSummoningsReal) ·
  `live` (injected Osamodas summon spell 110 → a Gobball creature (template 1,
  20 HP) spawned at the target cell, client rendered it + grew the timeline to 4
  with no decode error; on its turn the summon AI-walked toward the enemy; and the
  sparring dummy — a spell-less blocker — now advances on the players each turn
  instead of idling).

### B-020 · Spell effects: full effect system (positioning, buffs, damage variants) — completes B-017
- **Scope:** B-017 resolved only damage/heal/AP-MP; push/pull/teleport, buffs and
  the damage variants were deferred. This wires the whole set the 203 shipped
  spells use (98 distinct mh_2 action ids), classified once in
  `gamedata/effectkind.go` (`EffectKind`) and dispatched in
  `game/spell_effects.go`. Now handled: damage (direct 1-5 / "par sort" 130-134)
  with the real **dice roll** (`Effect.Roll`: 1-param fixed, 3-param
  `[count,faces,mod]` — the old params[0]-only under-reported dice damage), HP
  **leech** (6-10, heals the caster), **heal** (69), **%HP** (125), **poison**
  (61, first tick), AP/MP **loss** (16/20) / **steal** (85/103) / **gain** (15/19),
  **instant death** (63), **teleport** (39, caster→cell), **swap** (64),
  **push/pull** (37/38, faithful ray-trace port of the client's `na_2`/`sa_2` +
  the v2.04b collision formula: `cellsBlocked × (void?6:3)`), and timed
  **characteristic buffs** (CharacBuff/Gain/Debuff/Loss) — resource buffs
  (AP/MP/HP/Range) modelled + reverted on expiry, pure-stat buffs rendered.
- **Key wire facts (RE of `mv_0.ax`/`xb_2`/`yi_1`/`mh_2`, cross-checked vs the
  v2.04b resolver):** (1) the client renders `RunningEffect.getValue()`
  **verbatim** and never re-rolls on receive (`disableValueComputation`), so the
  server value is authoritative. (2) A buff's **duration rides in the 8120 `Nx`
  field** (`Nu.jt(Nx)`), NOT the blob — `buildRunningEffect` gained a
  `durationTurns` arg; instant effects pass 0. (3) The effect record's field 18
  (`duration`, ≥63 = infinite) and 16 (`areaSize`) are now decoded
  (`gamedata/effects.go`, six consecutive i32[] after params per the client's `Ht`
  deserializer). (4) A per-fight RNG (`Fight.rng`) rolls dice; buffs tick down at
  each new table turn (`tickBuffs`).
- **Deferred at the time (now mostly DONE):** summon (B-021), trap/glyph (B-025),
  states — invisibility/root/stabilise/petrify/immunity (B-023), AoE expansion
  (B-022/B-026), and the resist/damage-% damage formula (B-027) are all since
  implemented. Still deferred: aura (176), carry/throw (58/59), dispel (62),
  look-change, damage-transfer (129/139), drunk (126) — documented KindUnsupported
  no-ops (the cast animates; the exotic effect is a safe no-op).
- **Verified:** `unit` (TestEffectKindClassification, TestEffectRoll,
  TestDurationTurns, TestBuffResource, TestResolveEffect{,HPVariants,Positioning},
  TestBuffLifecycle, TestCardinalStep) · `live` (Poolcheck spell 7 → HP **75→135**
  from the infinite HP-boost buff, client orb rendered 135; spell 6 → **teleport**
  (7,15)→(5,15) rendered; Tanko spell 32 self resist-buff rendered with no decode
  error; AP debited correctly throughout).

### B-019 · Fighter movement rejected — the client's 4503 path EXCLUDES the origin cell
- **Symptom (live):** clicking a destination in a fight never moved the fighter
  ("nothing happens"); neither left- nor right-click worked. The server received
  the move but silently dropped it.
- **Root cause:** two things. (1) The retail client's move request (`md_1` built
  from the `arh_0` pathfinder, opcode 4503) sends the path as the STEP cells
  ONLY, EXCLUDING the fighter's current (origin) cell — verified live: a fighter
  at (7,15) sent `path[0]=(8,15)`. `validateFightMove` required `path[0]==origin`
  and rejected every move (the old e2e test hid this by sending an origin-included
  path — self-consistent but wrong). (2) A move is a RIGHT-click: `S.java` sends
  only when `ado.aqY()==n2`, `n2 = adc_0.clW("inverseMouseControl") ? 1 : 3`,
  default false → **button 3**; left-click only shows the path preview.
- **Fix:** `handlers_fight_combat.go` — `validateFightMove` now treats `path[0]`
  as the first STEP (must be adjacent to the fighter's cell), each subsequent step
  adjacent, MP cost = `len(path)`; the FIGHTER_MOVE (4524) broadcast PREPENDS the
  origin (`[origin, step1, …, dest]`) so the client's `HB`/`abm_2` walk animation
  starts at the fighter. Control-agent `/click` gained a `button` param so the
  harness can right-click. e2e testclient updated to send the origin-excluded path.
- **Verified:** `unit` (TestValidateFightMove origin-excluded cases) · `e2e`
  (TestFighterMoveInFight) · `live` (right-click via agent: Tanko (9,15)→(9,14),
  MP 3→2, animated; inject: Poolcheck (7,15)→(8,15)).

### B-018 · Spell casts never took effect; give-up never teleported back
- **Symptom (live):** a spell animated but dealt no damage / no "perd X PV"; the
  end-of-fight popup showed but never returned to the overworld.
- **Root cause:** (1) the client sends the spell-cast request as **8107** (`sg_2`),
  not 8109, and the results-ack as **26321** (`nv_0`), not 4321 — both were
  "unhandled opcode". (2) The RUNNING_EFFECT (8120) blob is Ankama's
  part-serialized "BinarSerial" (`amb_0`/`aJj.ad`/`ajl_2`), NOT a flat struct:
  `[i8 numParts]` + directory `{[i8 idx][i32 off]}` + parts; an HP-loss needs
  parts 0 (`yi_1`, 34B `[i64 caster][i64 target][i32 genericId][x][y][z][value]`),
  1 (`Yk`, caster) and 2 (`yl_2`, target). The old flat blob's first byte read as
  `numParts=0`, so the client parsed nothing and dropped the effect.
- **Fix:** `protocol/opcodes.go` (8107, 26321, mh_2 running-effect ids),
  `fight_combat_packets.go` (`buildRunningEffect` + `writeBinarSerial`).
- **Verified:** `e2e` (TestCombatSpellDamage) · `live` (cast spell 4 → target HP
  70→45 rendered; give-up → close popup → teleported to overworld).

### B-017 · Spell effects: only flat damage was resolved
- **Symptom:** utility spells (heal, AP/MP drain/steal) did nothing.
- **Fix:** `spell_effects.go` — `resolveSpellEffects` iterates a spell's effects
  and resolves flat damage (1-10 / 130-134), heal (69), AP/MP loss (16/20) and
  AP/MP steal (85/103), each broadcasting its own 8120 keyed to the effect's
  ActionID; `handleSpellCast` refactored to use it (unknown spell → neutral
  fallback). Push/pull/teleport (37/38/39), AoE, buffs and DoT are recognised but
  deferred (need the client push/area handlers + duration model).
- **Verified:** `unit` (TestResolveEffect) · `live` (damage).

### B-016 · Team membership never persists — fighters revert to the pool on reopen
- **Symptom (live+db):** building a team (Recruter a fighter into a slot, or drag
  a pool fighter into a slot) showed the fighter in the slot, but the
  `team_fighters` table stayed empty and the fighter was back in the pool after a
  reconnect. Only teams seeded directly in the DB ever rendered members. This is
  the B-015 follow-up ("adding a pool fighter to a team is drag-drop, not yet
  driven/verified").
- **Root cause:** the client assigns/removes a team member with the `qp_1` packet
  = **opcode 6013**, body `[i64 fighterId][i16 srcTeam][i16 dstTeam][i64 am]`
  (sent by `acx_2.onFighterDropped` / `onFighterRemoved`; `dstTeam=-1` removes,
  `srcTeam=-1` is the pool). The server registered **no handler for 6013**, so
  every assignment was silently dropped. Red herrings ruled out along the way:
  `saveTeam`/`loadTeam` map to client-internal `20127`/`20126` and export/import a
  **local file** (`%saveTeam%` renders "Exporter équipe" → "Fichier sauvegardé");
  there is no server "save team" button. `selectTeamPreset` is client-internal
  `16617`. The create packet `6001` carries a slot but **no team id**, so
  create-into-slot cannot be assigned server-side — the retail persistence path
  is drag pool→slot (6013).
- **Fix:** `internal/game/handlers_team.go` — new `handleFighterAssignTeam`
  registered for `protocol.OpFighterAssignTeam` (6013): validates coach ownership
  (IDOR guard), unlinks the fighter from `srcTeam`, links it into `dstTeam` under
  the client's caps (≤6 fighters, ≤2 of the same breed), persists via new
  `TeamRepo.AddMember`/`RemoveMember`, then re-pushes the roster (6006) and team
  list (6030) so the pool/slots reconcile.
- **Verified:** `unit` (`TestFighterAssignTeamPersists` — pool→team add, 2-per-
  breed cap, removal, IDOR reject, survives a store reload) · `audit` (payload
  byte-matches `qp_1.encode`; frame `[i16 len][i8 2][i16 op][body]` matches the
  already-correct `aad_1`/`ot_2`). `live` drag not demonstrable — the client's GL
  fighter-card drag does not respond to synthetic drag events (tooling gap), and
  create-into-slot emits no 6013.

### B-014 · Ping keepalive desync — client logs "reply number is low" every 60s
- **Symptom (live):** client `output.log` logged `Too high ping detected:
  Server reply number is low, 0 != 2` every 60 s, plus `Pas de connexion
  disponible pour envoyer le message`.
- **Root cause:** the keepalive uses **two** opcodes. `107` (`asg_0`, C2S only)
  is the client's ping request; `108` (`abj_0`, S2C only, 29 bytes) is the
  server's ack. The client (`pl_2` case 108) credits its counter `nW.sL()` only
  on a **108**. `nW` sends 2 pings (flags 1 & 2) per 60 s and expects 2 replies;
  our server replied with **107**, so the counter never advanced → reset + error.
- **Fix:** `internal/handshake/ping.go` — `EncodePingReply` now emits opcode
  **108** (`PingReplyOpcode`). Body was already correct.
- **Verified:** `live` — ran the real client 75 s past a keepalive cycle, zero
  errors (was every 60 s).

### B-015 · Fighters never appear in the Elite team pool (empty roster)
- **Symptom (live):** created fighters were in the client model
  (`adY.atu() size=4`) but the Elite team panel showed an empty
  available-fighters pool — you could never build a team.
- **Root cause:** the B-013 fix prepended a `type=-4` "bench" team to the 6030
  team list **containing all the coach's fighters**. But `type=-4` is the
  Evolution-mode graveyard, and the client's fighter-pool filter (`U`/`Z`)
  **excludes any fighter that is a member of ANY team in the 6030**. So listing
  the fighters in the -4 team made the pool render empty. (Verified in the
  decompiled client: `Z.a` excludes fighters in `bs_0.IF().IH()` or on the
  `xz_0` bench.)
- **Fix:** the `type=-4` team must be **empty** — it exists only so the client's
  Evolution first-open handler (`ce_1` case 6030) can safely do an unchecked
  `arrayList.get(0)`. Fighters flow purely via 6006 (type=1) into `adY.atu()`,
  and since they're in no team and not on the bench they appear in the pool.
  (`internal/game/team_codec.go` `benchTeamPreset()` now writes 0 members.)
- **Verified:** `live` — the agent's `/roster` now reports `pool=4 fighterList=4`
  (was 0), and a created fighter renders in a team slot. `e2e`/`unit` green.
- **Notes for follow-up:** the team-create opcode is **6021** and works
  (`members=0` is correct for a newly-created empty team). Adding an existing pool
  fighter to a team is a drag-drop that sends **6013** — now handled (see B-016).
  Evolution fighters are `type=2` on the wire but our encoder always writes
  `type=1` — Evolution-mode round-trip is a separate open item.

### B-013 · Fighter roster empty after create / panel reopen
- **Symptom (live):** Evolution "Recruter" → create → popup closes, no fighter
  shown; and reopening any team-management tab showed an empty roster.
- **Root cause (four stacked):**
  1. `6006` (FighterInformationList) was pushed only at login.
  2. The panel-open request `6031` returned only teams, not the roster.
  3. **The `6006` leading i64 is a server TIMESTAMP (seconds), not the coach
     id** — the client computes each fighter's form as `(now - lead)/3600` hours
     (`xi_0`/`awy` → `et_2.a`); the coach id made that huge → form zeroed. The
     `6000` create result doesn't apply this fatigue, which is why fighters
     showed on first create but vanished on reopen.
  4. **The `6030` team list must lead with a special `type=-4` "Evolution bench"
     team** holding all fighters — the client's first-open handler (`ce_1` case
     6030) does an unchecked `arrayList.get(0)` and the normal handler (`adi_2`)
     scans for the `type==-4` team to fill the bench.
- **Fix:** re-push `6006` after create/delete; `6031` now returns `6030`+`6006`;
  `buildFighterList` sends `time.Now().Unix()`; `pushTeamPresetList` prepends the
  `type=-4` bench team. (`internal/game/handlers_fighter.go`, `handlers_team.go`,
  `team_codec.go`.)
- **Verified:** `unit` + `e2e`; `live` verification pending a create-flow drive.

### B-012 · Chat messages shown twice to the sender
- **Symptom (live):** every vicinity/channel/private message the player sent
  appeared twice in their own chat.
- **Root cause:** all three chat handlers echoed the frame back to the sender in
  addition to broadcasting. The client already renders its own outgoing line
  locally, so the echo duplicated it.
- **Fix:** removed the self-echo — vicinity → `SessionsNear` (excludes sender),
  channel → `SessionsWithout(coachID)`, whisper → target only. Matches the
  reference server. (`internal/game/handlers_chat.go`.)
- **Verified:** `e2e` (asserts sender receives no echo).

### B-011 · PlayerStatisticsReport (2400) wrong field ids
- **Root cause:** put `Strength` in field 6 (an internal model value `dN`, not a
  displayed stat) and never sent field 8 (consecutive losses `dO`). Verified vs
  the decompiled `PlayerStatisticsReport` class: 1=playTime, 2=fightTime,
  3=fights, 4=won, 5=lost, 7=consecWins, 8=consecLosses.
- **Fix:** emit fields 1,2,3,4,5,7,8; added `Coach.ConsecutiveLosses`.
- **Verified:** `unit` (`TestPlayerStatisticsReportFields`).

---

## Earlier fixes (pre-live-harness, audit/e2e verified)

| ID | Area | Root cause | Where |
|---|---|---|---|
| B-010 | Social acks | `sendSocialAck` wrote a fixed `[name][i64]` for all 4 acks; real layouts differ per opcode (3156 kz_1 / 3158 ft_0 / 3160 adw_1 / 3162 ahm_0) — would BufferUnderflow the client on 3156/3158 | `handlers_social.go` |
| B-009 | Matchmaking | `sendMatchFound` wrote `mode` into both the mode AND fightType i16 fields | `handlers_matchmaking.go` |
| B-008 | ActorSpawn 4096 | coach record missing 16 trailing bytes at flags 3179 → client BufferUnderflow | `packets.go` |
| B-007 | Coach look | client reads SKIN then HAIR (not hair-then-skin); swap in 2049 decode + 2052/8000/4096 encoders | multiple |
| B-006 | TeamPresetDelete 6023 | read as u16, real id is i64 → silent no-op | `handlers_fighter.go` |
| B-005 | FriendList/IgnoreList | nil-join count desync | `packets.go` |
| B-004 | CREATE_FIGHT 8000 | two-stage decode; leading error byte required; `et_2` reads `zv`(sex) before `ey` | `fight_packets.go` |
| B-003 | Overworld culling | 100% server-side; must spawn/despawn (4096/4098) across AoI; a 4500 move for an un-spawned actor is dropped | `world.go` |
| B-002 | Exchange completion | 5111 reason byte is FIRST (0=success/1=cancel) | `handlers_exchange.go` |
| B-001 | Login | plaintext (not RSA); wire is big-endian `[u16 len][u8 arch][u16 op]` C2S / `[u16 len][u16 op]` S2C | `protocol/` |

---

## How bugs get found now

1. **Live client via the control agent** (`client/control-agent/`) — drive
   the retail client, screenshot panels, read its `output.log` for
   errors/exceptions, and read client-side model state via `/eval`. This class
   of bug (silent wrong-state, decode crashes, protocol desyncs) is invisible on
   the wire alone — see B-012, B-013, B-014.
2. **Byte audit** vs the decompiled client in
   `E:\Projets\DofusArena2-06\client\decompiled\core` — for exact wire layouts.
3. **e2e / unit** regression tests lock every fix.
