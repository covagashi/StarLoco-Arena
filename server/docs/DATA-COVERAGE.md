# Client data coverage — state of the art

> Picking the project up cold? Start at [`STATUS.md`](./STATUS.md).

**The rule: the client's data files are the single source of truth.** The 2.70 server
must derive every game value by *reading the client's own files*, never by hardcoding a
number or by porting one from v2.04b. When the client's data is updated, the server must
pick the change up with no code change. This document records exactly how far we are
from that, so the gap is visible instead of implicit.

Last audited: 2026-08-03, against the shipped
`compiled/game/contents/bdata/{data.bdat,indexes.bdat}` (19 781 records, 24 types) and
`compiled/game/contents/maps/`.

**Why this matters (measured, not hypothetical).** Every value we ever hardcoded or
inherited from v2.04b has eventually turned out to be wrong in 2.70: all 12 breed
initiatives, the breed base value (400 vs 600), Cra's close-combat element, base
crit/fumble (5/1 vs 0/0), and the spell cooldown field — which left **97 of 203 spells,
28 of them once-per-fight, with no cooldown at all**. See BUGS.md B-055…B-059.

---

## 1. Where the data lives

| Source | What | Read by |
|---|---|---|
| `bdata/indexes.bdat` | `[i32 type][utf name][utf value][i64 pos]` per record | `gamedata.Open` |
| `bdata/data.bdat` | one zlib stream per record: `[i32 id][i16 ver][i32 len][payload]` | `gamedata.Store.ReadRecord` |
| `maps/fight/*.jar` | `.fmd` start points + special cells (47 arenas) | `gamedata.LoadFightMaps` |
| `maps/tplg/*.jar` | per-map topology tiles | `gamedata.LoadFightMaps` |
| `maps/env/*.jar` | interactive elements | ✅ **read** (`gamedata/envmaps.go`: `ru_2`/`aEG` + the `do_1` part table). Committed to `data-dist` (all 114). `cmd/genelements` turns them into `game/elements_data.go`; reproduced the old hand table 139/139 and found a wrong direction byte (B-102) |
| `i18n/texts_*.properties` | all display strings, keyed `content.<table>.<id>` | **not read** — the server sends ids and the client resolves them (correct: strings are client-side) |

Record types are the `atr_0` enum. A record class is the `lJ` subclass whose `cq()`
returns that id; a loader is the `hR` implementation that turns records into runtime
objects.

---

## 2. Record-type coverage

**19 of 24 populated types are decoded.** Legend: ✅ decoded · ⚠️ partially used · ❌ not read.

The 4 still unread are all deliberate, not backlog: **1** is a singleton of standard
fight parameters we override per-ruleset anyway, **700** is superseded by the real
tournament records (1000/1001), **1400** Pro League is served empty because the mode
does not exist in this build, and **1600** is per-map music/background refs — client
rendering, which the server does none of. **1500** is client-only by design (§NPC
dialog trees).

| Type | Records | Client record → runtime | What it is | Status | Our decoder |
|---|---:|---|---|---|---|
| 1 | 1 | `aet_1` → — | Standard fight parameters (singleton) | ❌ | — |
| **100** | 907 | `aPp` → `xj` | **Coach cards** | ✅ 18/26 | `cards.go` |
| **101** | 138 | `yp_0` → `fe_1` | **Card sets ("panoplies")** | ✅ 2/2 | `cardsets.go` |
| **210** | 16 | `rf_2` → `er_1` | **Traps / special zones** | ✅ partial | `effectareas.go` |
| **220** | 203 | `co_1` → `yp_2` | **Spells** | ✅ 23/23 | `spells.go` |
| **230** | 51 | `ama_1` → `tO` | **Per-round event cards** | ✅ full | `events.go` |
| **250** | 75 | `uh_0` → `ve_0` | **Fighter equipment / weapons** | ✅ good | `fightercards.go` |
| 251 | 11 | `alf_2` → — | Equipment pools granted by Sphere Board nodes | ✅ 3/3 | `equipmentpools.go` |
| **300** | 53 | `jz_2` → `aJt` | **Summons** | ✅ 17/17 | `summonings.go` |
| 360 | 42 | `rb_0` → `yn_2` | Element sprite **views** (gfx/colour/height) — decoded; no consumer and none expected, the server renders nothing | ✅ | `elementviews.go` |
| **400** | 39 | `GE` → `afz_0` | **PvE challenges** | ✅ partial | `challenges.go` |
| 700 | 7 | `fw_2` → `iz_0`* | Calendar events (7 subtypes) | ❌ | hand-built in `tournaments.go` |
| 800 | 332 | `ru_1` → `aau_1` | Achievements (+ thresholds, required cards) | ✅ | `achievements.go` |
| 801 | 5 | `fw_0` → `ajk_1` | Achievement categories | ✅ | `achievements.go` |
| 802 | 13 | `wr_0` → `li_2` | Achievement subcategories | ✅ | `achievements.go` |
| 900 | 15 | `bg_0` → `Ei` | Sphere Board headers (per breed/season) | ✅ | `spheres.go` |
| 901 | **17 527** | `aeI` → `ayr_0` | Sphere Board nodes (xp cost, spell, cards) | ✅ byte-exact | `spheres.go` |
| 902 | 111 | `ahm_1` → `aiz_2` | **Fighter conditions** — the persistent wound/blessing layer | ✅ | `conditions.go` |
| 1000 | 22 | `aub` → — | Tournament definitions (rules, rewards, prizes) | ✅ 12/12 | `LoadTournaments` |
| 1001 | 4 | `ek_2` → — | Tournament level list | ✅ 1/1 | `Tournaments.Levels()` |
| 1100 | 30 | `ajd_0` → `abe_1` | Fusion-laboratory definitions | ✅ 4/4 | `LoadFusionLabs` |
| 1400 | 2 | `cb_2` → `atk_0` | Pro League definitions | ❌ | served empty |
| 1500 | 148 | `atF` → `ana_2` | NPC dialog replies | **n/a** | client-only (`xs_0`) |
| 1600 | 29 | `mw_0` → — | Per-map metadata (music/background refs) | ❌ | — |

Declared in `atr_0` but **absent from this store** (9): 110, 231, 232, 500, 600, 1101,
1102, 1200, 1300. Type **200** (`Ht`, the effect row) is never a standalone record — it is
embedded in 100/210/220/230/250/902 and is decoded by `effects.go`.

### Type 1000/1001 - Tournaments (`aub` / `ek_2`) - complete

Type 1000, from `aub`'s `a(ByteBuffer,int,short)` and its writer `cr()`:

    [i16 id][u8][u8][u8 teamType][i32][i32]
    [u8 n] np_1 x n                              // the tournament's fight ruleset
    [i16][i32 inscriptionCard][i32 rewardCard][u8 flag]
    5 x ( [u8 n] x { [u8 key][i32 value] } )     // five prize maps

22 definitions (ids 1, 4-24). Type 1001 is a single `u8` per record; the four
records read `[1 2 5 3]`.

Names come from the client's own property strings (`qr_0`): `qo()` is
**"tournamentInscriptionCard"** - `aug.registerTournament` looks that card up in
the player's inventory to let them enter - and `aHi()` is
**"tournamentRewards"**. `aHh()` is the team type, branched on in `agz_1`
against `aql_0`: 1 classique 1v1, 2 evolution, 3 cimetiere, 4 legendaire.

Five fields have NO consumer in the client (`aHe`, `aHf`, `aHg`, `aHj`,
`aHk`, the last being the prize maps). That is expected rather than suspicious -
the client reads only what it displays and the rest is server-side configuration -
so they are decoded and kept by position rather than skipped.

**Cross-checks that make the decode trustworthy:** every `teamType` lands inside
`aql_0`'s 0-4; every non-zero inscription/reward card id resolves to a real
card (16, 808, 26, 544); and the three hand-built standing tournaments turn out
to reference defIDs whose decoded team types match their names - defID 17, our
"Tournoi du Cimetiere", really is teamType 3 (cimetiere).

### Type 1100 - Fusion labs (`ajd_0`) - 4 of 4 fields, complete

12 bytes: `[i64 id][i16 power][u8 quality][u8 slotsPlusOne]`, from `ajd_0`'s own
`a(ByteBuffer,int,short)` and confirmed against its writer `cr()`.

30 records, ids 2-31, and the values are a clean tiered table - power runs
1/5/10/15/20...120/150, quality 1/2/5/8/10...45/50, and the rendered slot count
(`azi() - 1`) is 2-5. Power and quality rise together, which is what makes a
field-order slip obvious: any other reading produces noise.

**These four numbers ARE the fusion mechanic.** The client's fusion panel
(`ajt_1`) exposes exactly:

| property | value |
|---|---|
| `slotCount` | `lab.azi() - 1` |
| `labPower` | `lab.tz()` |
| `kardsPower` | Σ inputs' `RequiredLevel` - target's `FusionPower` |
| `quality` | `lab.tA()` |
| `canFusion` | inputs >= 2 |

So fusion is a power-threshold mechanic against a **player-chosen target card**,
not a recipe lookup. There is no recipe table anywhere in the client:
`contentLoader.recipe` is a declared i18n key with no loader and no record type.

### Type 101 — Card sets (`yp_0`) — 2 of 2 fields ✅ complete
`[i32 setId][u8 n + akw_0 effects]`. Membership runs the other way, from each coach
card's `CardSet` field. Each effect carries its own **threshold** (`akw_0.aAm()`, the
entry's trailing byte): it applies once the coach has that many of the set's cards
equipped. 138 sets, 88 effects, thresholds 2..10.

The effects are `AI`-enum coach META bonuses, and they are **all wired now** —
resurrection (10), XP (28), fatigue (9), morale (9), reputation (6), death chance
(5) and wound-cancellation (4) — through the post-fight meta pass (B-066) and its
`sessionSetBonus`/`opposingSetBonus` lookups. An earlier revision of this
document called everything but resurrection "decoded and **inert**"; that has not
been true since B-066, and the death-chance five (AI 7/8, the *Sacrifice /
Défense / Meurtre / Fair-play* cards) only started to matter in practice with
B-097, which stopped an invented `HP <= 0 → dead` rule from pre-empting the roll
they modify.

### Biggest gaps, by impact

**All five entries that used to sit here are now closed.** Kept struck through rather
than deleted, because each one's *correction* is the useful part — three of them were
mis-described here before they were built, and re-reading the client is what fixed them.

1. ~~**902 fighter conditions (111 records)**~~ — done. `[i16 id][i8 grade][i16 type][u8 n
   + gfx refs][effects]`. **Correction, and it is why this took two attempts:** an earlier
   revision of this document called these "the authoritative definitions of every in-fight
   state, the real source for `game/states.go`". That was wrong. They are a *separate,
   persistent* layer: conditions are applied by **coach cards** (effect `AI.aHK` =
   *"Applique une condition"*, resolved by `vm_2`), surfaced as the fighter's `conditions`
   field, and named by `content.40.*` — 116 names such as *Blessure légère jambe*, *Ange
   gardien*, *Champion*, *Fatigué*. They are the **wound / blessing / morale layer**
   carried between fights, not the mh_2 in-fight state actions that `states.go` maps.
   Conditions of the same `type` are mutually exclusive (`vm_2` replaces same-type, except
   types 21 and 70). Now modelled: wounds accrue, persist between fights, ride the
   CREATE_FIGHT blob so they survive a reconnect (item 11), and apply *after* equipment
   and spheres — growth of the fighter first, then penalties on the finished article.
2. ~~**901/900 Sphere Board (17 542 records)**~~ — done (item 29). The premise here was
   the misleading part: "17 542 records" reads as an enormous wire job, but the board
   graph is **client-side** data. What the server owed was the fighter's progress, the
   purchase rules re-derived server-side, and the effects of bought nodes.
3. ~~**1000 tournaments (22)**~~ — done (item 23). Definitions are decoded and the
   line-up is edited from the web console instead of compiled in. The *match* layer
   (brackets, scheduling, prizes) is deferred — item 32, not a decode gap.
4. ~~**101 card sets (138)**~~ — done (B-062); the bonuses are meta, not combat.
5. ~~**800/801/802 achievements (350)**~~ — done (item 26). What remains is *statistic
   coverage*, not decoding: 98 counters are referenced and the server moves a handful,
   each lighting its achievements up for free as its owning system starts counting.

**What is actually left is no longer a data-decoding problem.** The remaining holes are
the two deferred systems (2v2 → item 30, tournament matches → item 32, which between them
strand 47 achievements), the fusion success curve (no client code reveals it), and the
handful of **server-invented constants** that the client receives pre-computed and so
cannot arbitrate — `baseXPPerFight`, `standingForResult`, the reputation-per-card rate and
the clan-board score. Those are stated in tests rather than buried, but they are ours, and
no amount of testing here can make them retail-exact.

---

## 3. Field coverage for the types we DO decode

Field numbers are the record's binary order. "consumer" = who reads it in the client.

### Type 220 - Spells (`co_1`) - 23 of 23 fields decoded (2 not yet evaluated)
| # | field | our name | status |
|---|---|---|---|
| 1,2,3 | id, breedId, value | `ID/BreedID/Value` | ✅ |
| 4 | target id | — | ⬜ dead in client too (never read for logic) |
| 5 | animation script id | `ScriptID` | ✅ (client-render only) |
| 6 | AP cost | `AP` | ✅ |
| 7 | per-target cap | `CastMaxPerTarget` | ✅ |
| 8 | **max live instances** | `MaxActive` | ✅ decoded, ❌ **not enforced** |
| 9 | per-turn cap | `CastMaxPerTurn` | ✅ |
| 10 | **cooldown (63 = once/fight)** | `Cooldown` | ✅ **fixed — was read from field 8** |
| 11 | deferred unlock delay | `CooldownUnlockDelay` | ✅ decoded, not needed server-side |
| 12,13 | range bounds | `RangeMin/Max` | ✅ (stored max-then-min; normalised) |
| 14,15,16 | LoS / only-line / free-cell | `TestLoS/OnlyLine/NeedFreeCell` | ✅ |
| 17 | description toggle | — | ⬜ client display only |
| 18 | **range not boostable** | `RangeNotBoostable` | ✅ **newly decoded + enforced** (5 spells) |
| 19 | run target-validity check | — | ⬜ we always apply target conditions |
| 19 | enforce target masks | `EnforceTargetMasks` | ✅ decoded (true on only 3 spells) |
| 20 | criterion tokens | `Criterion` | ✅ |
| 21 | effects | `Effects` | ✅ |
| 22 | spell-level target masks | `TargetMasks` | ✅ decoded (202/203 spells), ❌ not yet evaluated |
| 23 | parent spell id | `ParentID` | ✅ **decoded + enforced** — `LimitKeyID()` shares all cast limits with the parent (5 spells) |

Type 220 is now **23 of 23 fields decoded**. Two are decoded but not yet acted on:
`TargetMasks` needs the client's fuller `aLc` evaluator (it extends the per-effect
condition bits with state-based ones — bit 49 intransposable, 50 stabilised, 51
cannot-be-carried, 56 rooted, 57 petrified), and it is only *enforced* by the client on 3
spells, so the payoff is small; `MaxActive` needs a live-instance counter.

### Type 250 — Fighter equipment (`uh_0`) — 15 of 15 fields
All decoded. Flags 9–13 were unidentified until this audit and are now enforced:
only-line, line-of-sight, free-cell, usable-while-dead, usable-while-carried. Field 7 is
a client animation script id (**not** a crit rate, an earlier hypothesis — now dead).

### Type 230 — Event cards (`ama_1`) — 4 of 4 fields ✅ complete
Field 2 is dead in the client too (no callers).

### Type 100 - Coach cards (`aPp`) - 26 of 26 fields (zero residual x907; B-071)
Was 8 of 26 (and `Rank` was permanently 0). Now decoded in one pass through field 18:
id, type, set, value, price map, required level, firework type + colour, `isUnique`,
obtainable-in-draw + drop %, **bound**, **undestructible**, has-usable-action, the effect
array (incl. the resurrection scan) and rank. The two tradability flags are now enforced
in exchanges (B-061).

**Fields 19-26 are now read too (B-071),** so this record is **26 of 26** and every one
of the 907 shipped records is consumed to **zero residual bytes** — the strongest check
available that the layout is right. They are: the `np_1[]` gameplay parameters (19), two
i16 the client hands to its runtime card object and never reads again (20-21), the
fusion laboratory's `labPower` and `quality` (22-23), the pet model id (24, which
`aez_0.aQv()` uses to spawn one visual per owned pet), and a colouring card's slot and
palette index (25-26, named by the unobfuscated `setFighterColorIndex`: slot 0 hair /
1 skin / 2 eyes).

Cross-check worth keeping: exactly **7** cards carry a pet model id, and the client
ships exactly **7** pet descriptions (`content.24.71/75/80/88/92/99/103`).

### Type 300 — Summons (`jz_2`) — 17 of 17 fields ✅ complete
Was 7 of 17. The tail is now decoded, and the four innate displacement properties are
**applied at spawn** (B-060): 22 of the 53 shipped creatures are rooted, 21 cannot be
carried, 18 are stabilised and 15 intransposable — none of which we honoured.
`Block`/`Dodge` (29 and 36 creatures) are decoded AND applied — they feed the tackle roll
(B-063). `DeadFlag` is dead
in the client too; `NoPositionalBonus` is inert because 2.70 dropped directional damage.

### Type 400 - Challenges (`GE`) - 17 of 17 fields (39/39 records exact; B-071, B-073)
Decoded: id, six raw ints, reward cards, time-challenge. Of the rest, most have **no
callers in the client either**; the meaningful unread ones are the linked achievement id,
the XP reward and the XP cap.

### Type 210 — Traps / special zones (`rf_2`) — 8 of 13 fields
Decoded: id, type string, AoE shape+params, max triggers, effects. **Not read**: the
re-trigger policy (once per team / per target / always), the two trigger bitmasks, and
the delayed re-trigger timer.

**The trigger enum, recovered in full (B-076).** The client turns `appTriggers` /
`unappTriggers` into two `BitSet`s keyed by trigger id (`aeb_0`), and fires them from
`he_1.a(fromX,fromY,fromZ, toX,toY,toZ, fighter)`, which partitions the live areas by
whether they contain the FROM cell and the TO cell:

| id | fires when | server |
|---:|---|---|
| 10000 | the fighter STARTS its turn on the footprint | ✅ |
| 10001 | **entered** — in TO, not in FROM | ✅ (walk **and**, since B-076, every forced displacement) |
| 10002 | **left** — in FROM, not in TO | ⬜ |
| 10003 | unknown — the ONLY trigger on template 1016 `mauvaisOeil`, which therefore **never fires here** | ⬜ |
| 10006 | unknown — templates 2 and 1015 | ⬜ |
| 10008 | **stayed inside** — in TO and in FROM | ⬜ |

`he_1.a` is a pure position-change notification and **eight** effect classes call it,
including `go` (teleport) and `aox_1` (swap, once per swapped fighter) — which is the
evidence that forced displacement triggers areas, not just walking.

Shipped trigger sets across the 16 templates: the 8 `SPECIAL` tiles are all `[10000]`;
traps 1 and 1020 are `[10001]`; template 2 is `[10008 10000 10006 10001]` with
`unapp=[10002]`; 1015 is `[10000 10001 10008 10006]`; 1016 is `[10003]`; and **1017,
1018, 1019 carry an EMPTY trigger array**, so nothing fires them at all.

---

## 4. Values still hardcoded that SHOULD come from data

| Value | Where | Correct source |
|---|---|---|
| Breed HP/AP/MP/init/element/value | `game/breed.go` | client enum `xq` — **compiled into the client, not in .bdat**; hardcoded of necessity, now pinned to `xq` by tests |
| Close-combat 5 AP / 5 dmg / 7 crit | `game/breed.go` | same (`xq.DO/DP/DQ`) |
| Fighter states (`stateByAction`) | `game/states.go` | NOT type 902 - that is the persistent condition layer (B-066). These map `mh_2` action ids and are compiled into the client. |
| Tournaments | `game/tournaments.go` | **type 1000/1001** |
| Interactive elements | `game/elements_data.go` (generated by `cmd/genelements`) | `maps/env/*.jar` + `maps/tplg` (arrival altitude = the **lowest** walkable layer). **NOT type 360** - that is only sprites |
| Zaap destinations | `game/zaap.go` | `maps/env` descriptors |

`xq` is a Java enum inside `core.jar`, not a data record, so it cannot be read at runtime;
hardcoding is unavoidable there. The mitigation is the test suite: `breed.go`'s table is
pinned field-for-field to `xq`, so drift is caught rather than silent.

---

## 5. Recommended order of work

A pattern was visible here and it turned out to be the right call: **the remaining gaps
were mostly MECHANICS, not data.** Card sets made it explicit — 78 of its 88 effects were
decoded and inert because XP, morale, fatigue, drops and wounds did not exist server-side.
Decoding more records was never going to change that; building the owning systems did.

**This list is now fully worked through** — kept for the ordering rationale, which held.

1. ~~**The coach META layer, slice 2**~~ (wounds / death / drops) — done, and it was
   indeed the biggest unlock per unit of work: it activated the ~78 set effects, most
   coach-card effects and the type-902 condition layer at once. *Drops are the deliberate
   exception* — the pool and base rate are not recoverable from the client, so building
   them means inventing the mechanic (see "out of scope").
2. ~~**`np_1[]` element layout**~~ — DONE (B-071). Was: one unknown that unblocks 8 coach-card fields *and*
   parts of the challenge and tournament records. Decode it once, gain three records.
3. ~~**Spell `TargetMasks` + `MaxActive`**~~ — TargetMasks implemented (B-081); MaxActive
   **deliberately not enforced**, which is a result rather than a skip: its window is one
   turn, and every shipped MaxActive spell is already capped at least as tightly by a
   limit we do enforce, so it cannot change an outcome. Pinned by a test that fails the
   moment that stops being true.
4. ~~**Type 1000/1001 tournaments**~~ — done (item 23); definitions decoded, line-up
   editable from the web console.
5. ~~**Types 900/901 Sphere Board**~~ — done (item 29). The "largest unimplemented
   system" framing was the misleading part: the graph is client-side, so the record count
   never was the size of the job.

## 5b. The `np_1` fight-ruleset types (`ajr_2`)

Decoded in B-071; types 10/11/13 wired in B-072. The low block is a fight-ruleset
system — the mechanism a challenge or tournament uses to customise a match:

| type | meaning | note |
|---|---|---|
| 1-3 | budget, min/max fighters | |
| 4-9 | spell/equipment allow + ban lists (incl. "ban everything") | |
| **10** | **per-fighter turn duration (ms) — a DELTA** | ✅ wired (B-072); only challenge 46 uses it: +3 600 000 ms |
| **11** | **sudden-death turn — a DELTA (±turns)** | ✅ wired (B-072); unused by challenges, expected tournament-side |
| **12** | **cast an effect on all fighters at fight creation** | ✅ wired (B-074); 3 challenges (29/30/31), each +40% dodge for the whole fight, target mask 1024 = real breeds only |
| 13 | multiply bonus-cell effects (absolute) | ✅ wired (B-072); 5 challenges (x2, x2, x5, x10) |
| **14** | **victory condition** | ✅ wired (B-074); the ONE type with its own layout (`wi_0` + `mp_2`); 9 challenges, all subtype 4 |
| 15-25 | class limits, class bans, fighter/spell/equipment prices | |
| 26, 32 | event list, sudden-death event list | |
| 27 | add a coach spell | |
| 28 | max distinct classes | |
| 29 | choose the arena | no `content.54.29` label — the enum is the only evidence |
| 30 | max league | |
| 31 | hide opponent statistics | |
| 900 | class parameter | params = breed id; 14 coach cards |
| 901-912, 929, 930 | per-breed spell parameters — Féca…Pandawa **plus 929 Roublard / 930 Zobal** | params = spell id; ~10 coach cards each |
| 913, 924 | low / high budget parameter | |
| 914-923 | per-equipment-kind parameters (sword, dagger, wand, bow, hammer, shovel, hat, cape, pet, dofus) | |
| 925-928 | turn / time (ms) / arena id / fighter count parameters | |
| 1000 | `Aucune limite sur ce combat` (no params) | named, not enforced; challenge 12 |

`content.54.<type>` is the authoritative semantics table and **must be read before
implementing a rule** — it is what proved 10/11 are deltas. Note it is a *display*
table and is incomplete: there is no entry for 29, and 900-913 all render as
"Erreur dans l'AGT". The `ajr_2` enum is the authority on what a type IS; the i18n
line is the authority on how its parameters are meant to be read.

### The type-14 victory-condition subtypes (`qk_1`)

Each is one concrete `mp_2` subclass whose one-line body is the semantics:

| subtype | label | client body | state |
|---:|---|---|---|
| 1 | Posséder une position | `cy_1`: a living fighter of the team is on cell (p0,p1) | decoded, not implemented — unused by shipped data |
| 2 | Posséder un nombre de points de victoire | `fp_1`: `team.amt() >= p0` | decoded, not implemented — unused |
| 3 | Tuer des combattants d'une classe | `ct_1`: ≥ p1 (default 1) enemies of breed p0 are dead | decoded, not implemented — unused |
| **4** | **Atteindre un tour donné** | `ajm_0`: `fight.ZB().JI() > p0` | ✅ **all 9 shipped conditions**; wired (B-074) |
| 1000 | Aucune condition sur ce combat | — | — |

The nine shipped conditions are identical: subtype 4, one param (20 or 30),
`is_necessary`=true, `victory_points`=0, `affected_team`=0. Their holders are
challenge 14 and the "Défi du temps" set — *time* challenges. **The client never
evaluates any of this**: `mv_1.b(mp_2)` is an empty method, the 3-arg evaluator has
no call site, `rh()`/`ri()`/`rj()` have no callers, and `content.55` stops at entry
1 so a type-4 condition cannot even be displayed. Retail arbitrated these
server-side; the condition is recovered, the arbitration is ours (see B-074).

## 6. Change log

| Date | Change |
|---|---|
| 2026-08-19 | `cmd/dumpcards` now also exports each card's `resurrect` percent (action 13) so the Godot client's graveyard dialog can pick a resurrection card from inventory without hardcoding ids; `tools/asset-import/card_names.py` passes the field through into `godot/assets/gamedata/cards.json`. |
| 2026-08-19 | Established that record type **1500** (NPC dialog replies) is **client-only** and needs no server decode: the client loads it with its own content loader (`xs_0`, "contentLoader.dialogReply") and runs the whole tree locally — `ao_2` opens `npcTalkDialog` on frame registration, and its 17001/17002 are non-encodable internal events (`wm_0` → `sb_0` → `aed_2.encode()` returns null). A reply's only wire effects are 26330 and 22003, both already implemented. Marked n/a rather than missing. |
| 2026-08-19 | Decoded record types **800/801/802** (achievements + categories/subcategories, 332/5/13) with byte-exact consumption over every record, and wired generic completion evaluation + the 22000 unlock push (B-106). Established that there is **no reward**: points are cosmetic and the type-800 record's spare `i32` (`ru_1.bJg`) has no consumer anywhere in the client, so it is decoded and given no behaviour. Also corrected 22002's blanket "do not emit" to "reply-only", which is what had left the tab unopenable (B-105). |
| 2026-08-18 | Corrected the card-set effect status: the `AI` META bonuses are all wired (since B-066), not "inert bar resurrection". The death-chance five (AI 7/8) only became observable with B-097, which removed an invented `HP <= 0 → dead` rule that pre-empted the roll they modify. No decode change. |
| 2026-08-18 | Read `maps/env/*.jar` (`ru_2`/`aEG` + the big-endian `do_1` part table) and generated the overworld element table from it, retiring the hand transcription; reproduced it 139/139 and found a wrong direction byte (B-102). Added tplg tile kinds **0** (uniform) and **1** (4-bit), which a size guard and a missing case had been dropping - most of the overworld - scoped so arena decoding is unchanged. Arrival altitude established as the **lowest** walkable layer, not the element's authored z nor the highest layer. |
| 2026-08-18 | Decoded record type **360** (42 element sprite views, 5/5 fields) — and established it is **not** the interactive-element table: no instanceId, world, cell or behaviour, three of five live fields constant across all 42 records, one field with no reader in the client. ROADMAP item 24 restated: placements live in `maps/env/*.jar` (+ `tplg` for altitude), and the item is blocked on a `data-dist` maintainer decision rather than on code. Element count corrected 132 → 139. |
| 2026-08-10 | Recovered the full type-210 trigger enum from `he_1.a` / `aeb_0` and wired forced displacement into the enter trigger (B-076). 10002/10003/10006/10008 documented but still unimplemented; template 1016 can never fire here, and 1017/1018/1019 ship with empty trigger arrays. |
| 2026-08-10 | Wired np_1 types 12 and 14 (B-074): fight-start effects and victory conditions now drive fights instead of being carried inert. Added target-condition bits 512/1024 (breed-is-zero), corrected the validator's provenance from `aap.a` to `aLc.a`, renamed the `mp_2` scalars to the client's own SQL column names, and documented the `qk_1` subtypes and the 913-930 parameter block. |
| 2026-08-05 | Inline unlength-prefixed Ht effects parsed exactly; challenges now 39/39 with zero residual (B-073). |
| 2026-08-04 | np_1 rule 13 (bonus-cell multiplier) applied to the beneficial tiles; timing rules 10/11 corrected to DELTAS per content.54.* (B-072). |
| 2026-08-04 | Wired np_1 rule types 10/11: the turn clock and sudden-death turn are per-fight and read from data instead of hardcoded package globals (B-072). |
| 2026-08-04 | Decoded the `np_1` element (B-071): coach cards now 26/26 fields with zero residual across all 907 records; challenges 36/39 exact; the ajr_2 type enum documented as a fight-ruleset system. |
| 2026-08-04 | Evolution fighters can be created: the et_2 type byte is honoured via a persisted Fighter.Evolution flag, separate from State (B-070). |
| 2026-08-04 | Challenge reward cards reported on the end-of-fight panel; the won/lost card-blob order corrected (B-069). |
| 2026-08-04 | Wire text encoding corrected to windows-1252 in both directions; the length prefix now counts encoded bytes (B-068). |
| 2026-08-04 | Coach cards keep their full akw_0 effect array; the 325 usable cards (healing, rest, morale, XP, blessings) now work via 22099 (B-067). |
| 2026-08-04 | Coach META slice 2: type 902 decoded (111 records, 5/5 fields), conditions persisted + on the wire, the wound roller (bf_1.b) and the death roll (adl_0.atd) ported (B-066). |
| 2026-08-04 | Coach META slice 1: the 8300 per-fighter post-fight report (adl_0/OW) now exists; XP, morale, fatigue and coach reputation applied with the client's own formulas (B-065). |
| 2026-08-03 | e2e combat tests made side-agnostic; the "client A == side 0" assumption was the long-standing flake (B-064). |
| 2026-08-03 | Tackle wired to the real block/dodge characteristics — breed table args 13/14, actions 120-123, summon template fields; actions 147/148 (crit/fumble malus) applied (B-063). |
| 2026-08-03 | First audit. Fixed the spell cooldown field (B-059); decoded the summon tail 7→17 fields and applied innate properties (B-060); decoded coach cards 8→18 fields and enforced tradability (B-061); completed the spell record 19→23 fields with parent-spell limit sharing; decoded card sets and wired the resurrection bonus (B-062); corrected this document's wrong claim about type 902. Types decoded: 7 → 8. |
| 2026-12-17 | `cmd/dumpspheres` exports the Kanodo catalogue (types 900/901: 15 boards, 17527 nodes, kind classified with the client's `aKZ` rules) for the Godot client's board pane. |
| 2026-12-17 | `cmd/dumpnpcdialogs` exports the NPC-dialog reply table (type 1500 `atF`, 148 rows → 61 groups; challenge-launch modes pre-resolved from type 400 `Fields[1]`) and `tools/asset-import/npc_dialogs.py` merges i18n tables 29/59/60 into the Godot client's `npcdialogs.json`. Verified live: `/world 85` → Baan dialog → criterion 219 + défi 26330→8000. |
| 2026-12-17 | `dumpnpcdialogs` also exports the **type-800 achievement table** (332 rows → `{stats: {statId: threshold}, cards: [id]}`) so the Godot client can evaluate the demon-element gates locally exactly like `aau_1.a`/`sj_1.c` (every stat at threshold AND every required card in the tome). The demon env kinds are now wired end-to-end and verified live in `world_smoke`'s `/world` tour: kind 9 Demon I paged monologue, kind 7 DemonChallenge accept/refuse bubble (achievement-278 gate), kind 6 Demon III first-contact criterion `210` + intro pages, kind 3 challenge picker rows → `26330 {id, 99}`. |
| 2026-12-17 | **Zone triggers (env kind 8, retail `oq`)** wired end-to-end: the element-200 blob's `cells` array is now decoded and kept, `cell_entered` runs the `oq` gates (required achievement done, blocking one open, once per session), and the Lua scenarios under `scripts/scenario/<id>` — which all reduce to ordered `BubbleText` pages (content.29 ids) plus an optional `Context.updateAchievement` — are carried in `godot/src/gamedata/scenarios.gd` and played as a paged dialog with a queue for overlapping zones. Same-world `/tp` (4510, `xp_0`) is now handled client-side (snap, camera recentre, `cell_entered`); `teleportWithinWorld` learned to refresh the element AoI so the trigger cells actually spawn (B-162). Verified live: 4 triggers fired on world 35 incl. the 11-page new-coach tutorial (scenario 100) and criteria 219/221 persisted. |
| 2026-09-30 | `dumpnpcdialogs`' type-800 export gained the presentation fields the Godot achievements pane needs (`prev`/`super` chain, `cat`/`sub`, `pts`, `hid`) and `npc_dialogs.py` merges i18n **37** (names, 332) / **49** (descriptions, 173) / **48** (criterion labels, 99). The Godot "Achievements" tab reproduces `qy_2`'s list semantics — hidden/superseded/chain-locked rows dropped, done-first sort, averaged per-condition progress — verified live: 112 rows, `✓ Encounters of the 3rd kind — 5 pts` on top with a named-conditions detail line. |
| 2026-09-30 | `dumpnpcdialogs` now exports the **type-300 summon templates** (`jz_2`, 53 rows → `{hp, ap, mp, look}`) and `npc_dialogs.py` merges i18n **10** (summon names — `aJt.getName`). The Godot fight view builds mid-fight summons from them: an `8120` running effect with action 67/75/97 carries only the template id in `value` and the new fighter wire id in `target`, so the fighter dict, nameplate ("Gobball (Humo)" — template name + summoner, `adT.setName`), timeline slot and team are all resolved locally (`hy_1`/`gn_0.d`). Verified live by `summon_smoke`: a real spell-51 cast spawns "Tofu (…)", chip lands right after the caster, the summon turn reads not-ours (server AI), preset+fighter cleanup via 6023/6003. |
| 2026-09-30 | `dumpspells`/`spell_names.py` now carry the **cast gates** per spell (`los`=TestLoS, `line`=OnlyLine, `free`=NeedFreeCell, `noboost`=RangeNotBoostable, and `mask`=TargetMasks when EnforceTargetMasks — 107 LoS / 12 line / 17 free / 1 mask of 120 breed-legal), and `dumpfightercards` exports the same three `mv_1` gates per card ability. The Godot fight view uses them for the retail "zone de portée": arming a spell/card/weapon tints every cell in Manhattan range, bright where the full cast gate (walkable + range + line + `ahc_2` altitude LoS, ported verbatim + free-cell/mask occupancy) passes, dim where blocked. Verified live in `fight_smoke`: spell 51 (los+free, range 1-1) lights exactly the 3 free adjacent cells. |
| 2026-09-30 | New `cmd/dumpeffects` exports every **timed/infinite type-200 effect** embedded in spells + fighter cards (306 rows → `{a: actionId, d: table-turns, i: infinite, p: params}`) into `godot/assets/gamedata/effects.json`. The wire never carries a duration — the client's `ZT.jt` resolves it from the effect record — so the Godot buff strip attaches on `8120` by looking `gen_effect` up here, counts down per table turn (`tickBuffs` ages on 8100, `buffExpiryMark` is an absolute mark on the fighter's own turn counter for `8121` resync attaches), and strips by `params[0]` on dispel (server `removeEffectByID`). Verified live in `fight_smoke`: fabricated 8121 attach → `+3 AP·1` + `Invisible·∞` chips, one 8100 ages the finite chip out. |
| 2026-09-30 | `dumpeffects` also exports the **type-210 static-effect templates** (`rf_2`, 16 rows → `{t: TRAP/SPECIAL, l: label, s: areaShape, z: sizes, m: maxExec, w: firesOnWalkOn, e: innerEffectIds}`) into `godot/assets/gamedata/areas.json`. The `8120` area-creation broadcast (action 66 cell trap / 176 caster aura) carries only the template id in `value`, so the Godot fight view resolves footprint/maxExec/inner effects here — same division of labour as retail's own `rf_2` catalog. `areas.gd` ports `pointInArea` (point, Manhattan circle, cross, ring, square); trap removal has no wire event, so finite areas count fires by attributing inner-effect `8120`s (same caster + victim inside the footprint) and drop at `maxExec`, while auras re-centre on the caster's live cell and age one step per `8100`. Verified in `fight_smoke` with fabricated 8120s (r2 = 13 cells, one-shot erased on fire, unlimited persisted). |
| 2026-09-30 | `dumpspells`/`dumpfightercards` now carry the **cast-frequency limits** (`lk` = LimitKeyID — variants share the parent's budget, `cd` = EffectiveCooldown = max of fields 10/11 with 63 = once per fight, `mpt`/`mptt` = per-turn/per-target caps; 61 of 120 breed-legal spells) and the **effect zone footprints** (`zn` = deduped `[areaShape, areaSize…]` rows — 18 spells, 8 cards). The Godot fight view keeps its own `sH` history: every `8110` records the cast (fumbles count — `storeCast` runs after the roll), the fighter's own `8104` clears per-turn counters (`onNewTurn`), locked spells grey on the bar live, and an armed spell/card tints the aimed footprint via `areas.gd`'s full `pointInArea` port (point, Manhattan circle, cross, ring, square, directional T/T-inv and point-list rotated by `cardinalStep` source→aim). |
| 2026-10-01 | `dumpfightercards`/`dumpspells`/`dumpnpcdialogs` now export the **Lua script ids** behind casts and card uses — fighter-card field 7 (`uh_0.eA`, decoded and stored as `ScriptID`), the spell field-5 `script` (already decoded, now on the JSON), and type-300 field 17 `particle` (`jz_2.oz`, a FreeParticleSystem id on death — nonzero on only 2/53 summons, templates 52/53). The Godot fight view uses the weapon scripts 8000–8007 to play the per-family armed gesture `AnimStatique03(-Debut)-<fam>` composited from `animations/Players/Anim{Epee1,Dague1,Arc,Baguette,Marteau,Pelle,Poings}.anm` onto every `fighter_*` set, and `tools/asset-import/spell_sounds.py` extracts the scripts' `Sound.playSound` calls (+`invoke()` delays) into `spell_sfx.json` — 88 spells, 76 distinct sound ids — played on the caster's `AnmSprite` pool with the gesture. |
| 2026-10-02 | **Spell `.xps` FX channel** (B-167): `spell_sounds.py` → `spell_fx.json` (100 spells). `xps_dump.py` + `test_xps.py`: **364/364** retail `0x5001` particle systems → `godot/assets/gamedata/xps/*.json` + `xps_index.json`; **253/275** textures → `godot/assets/fx/*.png` (`81.xps` legacy `XPS` wrapper excluded). Godot `xps_fx.gd` reads first-emitter spawn/model fields when JSON exists. |
| 2026-10-03 | `spell_sounds.py`'s particle pass is now a **scoped Lua mini-evaluator** instead of a regex scan → `spell_fx.json` grows to **116 spells** (all 107 spell-bound particle scripts covered — 7 lost to un-`invoke()`d `displayEffect()` entry points, 9+ to `invoke (` spacing / variable ids). Rows: `[t_ms, xpsId, "caster"|"target"]` bursts; `[t, xpsId|"dir-map", "tw", angleDeg, coef]` for `addTweenParticleSystem` (retail `avw_0` ballistics — `v0=√(g·d/sin2θ)`, `ms=2·v0·sinθ/g·1000/coef`); `["tw#i+k", id, anchor]` fires `k` ms after tween `i` lands (`invoke(time+k, …)`). Variable ids become `{"1":…,"3":…,"5":…,"7":…,"_"}` direction maps resolved per call site by `xps_fx.gd`'s `pick_id`. `fight_view._cast_fx` spawns tweens, queues arrival rows, and picks dir ids by the caster's Direction8. The 6 fighter-card scripts (8001–8007) emit no particles → 8108 needs no FX gating. Verified: `test_xps.py` 364/364, `fight_smoke`/`carry_smoke` green headless; retail ballistic duration reproduced to ~0.3ms (0.654s on a 5-cell shot). |
| 2026-10-02 | The **anm-frame `runScript` audio channel** (B-166) is now exported: 83 `.anm` files carry 1,657 `pb_1` parts that run `scripts/anm/<id>.lua` on frame enter (`anm_dump.py` parses them as `script`; `anm_render.py` collects `scr_hits` in both flat and composite paths → `meta.scr {frameIdx: [scriptIds]}`; `anm_scr_patch.py` backfilled 3,144 exported metas without re-rendering). `spell_sounds.py`'s new `scripts/anm/*.lua` pass emits `anm_scripts.json` — 409 scripts resolved to `{s: [[soundId, gain]…], stop}`: `playLocalSound`'s `soundFileId`/`gain`/`stopOnAnimationChange` locals, and `playLocalRandomSound`'s literal `(id, gain)` pairs picked uniformly per `agO.c`. 20 scripts skip (18 `playBark` npc-voice, 4 `playGroundSound` footsteps — tables not shipped); `playCount` and `rollOffPreset` unsupported (never used / no positional audio in the pool). `AnmSprite` fires them per-frame at authored gain, stops `stop`-flagged streams on action change. |
| 2026-10-03 | **`xps_fx.gd` visual-parity pass**: each decoded system now builds **one `CPUParticles2D` per emitter** (retail stacks 1–14 layers — 154/182 spell-referenced systems are multi-emitter, e.g. `10110` staggers 6 emitters across 0.6–3.0s), honouring per-emitter `startSpawnTime`/`endSpawnTime` via `_schedule_emit` timers and `spawnFrequency`→continuous-stream `amount` (projectile trails hold `flying` until `arrived`). The three hottest affectors run the real `ua_0` update math: `LinearForceEx` (208/208 corpus uses `geocentric` → iso-projected `gravity`), `FrictionalForce` (→ `damping`), `ColorFader` (`TimeCondition` windows → simulated exponential-chase `color_ramp`). Emitter `offset*` now projects through the same iso+z (`aNA()=10`) transform. `Rebound` (`arx_0` — dvel = R90(offset)·restitution·dt, an orbital curl on 29 spell-referenced systems) approximated by `tangential_accel`. The **keyframed affector layer** (fixed 0.03s tick inside `TimeCondition` windows — `ua_02.b(0.03f, …)` in `Emitter.b`) is ported: `Deformer` (`ir_1` — scaleX/Y += p0/p1, rot += p2 per tick; ~160 spell-referenced systems incl. the Cra arrows) → piecewise-linear `scale_amount_curve` + `angular_velocity`, and `LinearForce` (`af_0` — attract toward a point along an axis mask; every authored target is the origin) → `radial_accel` (10335's swirl+inward-pull = the retail vortex combo). Still unported: `DirectionFollower` (15 systems — velocity-aligned billboards, no CPUParticles2D analogue), sub-emitters (7 decoded systems — `1013120`/`1013130`/`1013321`/`30000` family — none spell-referenced), lights (a single corpus entry). Verified: `test_xps.py` 364/364, `fight_smoke`/`carry_smoke`/`displace_smoke` green (0 script errors). |
