# ROADMAP — DofusArena 2.70

Feature-by-feature state of the **from-scratch Go server** (`server/`) that is
wire-compatible with the retail **DofusArena 2.70** client (Feb-2012, rev 72909),
plus the reverse-engineering tooling around it.

**Updated:** 2026-10-13 · **Released version:** 0.4.0 · **Branch:** `main-covaga`
(130 commits ahead of `v2.70`) · **Latest work:** the **Godot client** — lobby and
combat migrated to native controls, i18n es/en/fr (718 keys each), in-game bug
report (B-171, B-172), and placement facing fixed server-side (B-170). Current
tanda and its evidence: [`sprints/S01`](./sprints/S01-client-test-net.md)

This document answers two questions: *what actually works*, and *what is left*.
It is deliberately granular — "the fight system" is not one line item, it is
about forty. For the cold-start narrative see
[`server/docs/STATUS.md`](./server/docs/STATUS.md); for the opcode matrix see
[`server/COVERAGE.md`](./server/COVERAGE.md) and
[`server/docs/OPCODE-INVENTORY.md`](./server/docs/OPCODE-INVENTORY.md); for the
per-record data audit see
[`server/docs/DATA-COVERAGE.md`](./server/docs/DATA-COVERAGE.md).

---

## Legend

| Mark | Meaning |
|:---:|---|
| ✅ | **Done** — implemented, wire-audited against the decompiled client, and tested |
| 🟢 | **Done, unverified live** — implemented + unit-tested, never confirmed against the retail GUI |
| 🟡 | **Partial** — works, but a named part is approximated, hardcoded or hand-authored |
| 🔷 | **Data decoded, mechanic inert** — the record is parsed correctly; nothing consumes it yet |
| ⬜ | **Not started** |
| ⛔ | **Deliberately not implemented** — with a documented reason (usually: not recoverable from the client) |

**Scale reference.** 217 Go files + 292 test files · 1.077 test functions (151 of
them end-to-end over a real socket, in `test/e2e`; 619 in `internal/game`) · 82
C2S opcode handlers · 96 S2C frames emitted · 189 opcode constants · 9 of 24
populated client record types decoded. On the client side: 48 GDScript files /
21.072 lines in `godot/src`, 25 / 4.771 in `godot/test`.

---

## 1. At a glance

| System | State | One-line summary |
|---|:---:|---|
| Wire protocol & framing | ✅ | Both directions, cp1252 text, 82 C2S handlers / 96 S2C frames |
| Client data layer (`.bdat`) | 🟡 | 9 of 24 populated record types decoded; the big ones are byte-exact |
| Accounts, login, persistence | ✅ | 3 SQL drivers, bcrypt, reconnect, dup-login kick |
| Overworld (movement, AoI, elements) | 🟡 | Full AoI + a hand-transcribed interactive-element table |
| Chat & social | 🟡 | Vicinity/private/channel + friends/ignore; channels have no real scoping |
| Economy (shop, barter, fusion, trade, mail) | 🟡 | All flows work; fusion recipes are approximated |
| Fighters, teams, rosters | ✅ | Create/delete/equip/preset/assign, budget enforced from real data |
| **Fight system** | **🟡** | **Whole 1v1 loop is server-authoritative; 505/533 effect rows resolve; see §8 for the 40-item breakdown** |
| Progression / META layer | 🟡 | XP, morale, fatigue, wounds, death rolls — client-exact formulas |
| Evolution mode & graveyard | ✅ | State machine, capacities, resurrection gamble, persistent deaths |
| PvE challenges | 🟡 | 39/39 records decoded; win conditions + fight-start rules now enforced; opponent rosters are invented |
| Tournaments | 🟡 | Registration + calendar + list; no brackets, no matches |
| Ladder / ranking (7 tabs) | 🟡 | Only the 1v1 board carries data; six render as valid-but-empty |
| Sphere Board | ✅ | Types 900/901 decode byte-exactly; board/cursor/owned nodes served, buying (23009) validated server-side, and bought nodes apply their stats and spells in fight. Live-verified end to end |
| Achievements | ✅ | 332/5/13 decoded byte-exactly; tab opens (B-105), unlocks evaluated + announced, tome grow-only (B-106). 47 are structurally blocked on 2v2/tournaments; the rest need their statistic to start moving |
| Guilds / clans | ✅ | **Complete** (item 31), and never structurally blocked — the client's clan feature is fully wired; the server was writing an empty 0x20 blob, which every entry point gates on. Create/invite/accept, ranks + rights, kick/quit/destroy, clan chat, clan tag + clan ladder, demon affiliation, and clan islands on the retail rule (one island per demon, held by its top clan). Live-verified |
| 2v2 | ✅ | DONE (item 30). Duo formation via the 2VS2 tab (60xx), four-coach fights, per-owner AI/absence/rewards, post-fight for all four. Live-verified with four retail clients |
| Ops: config, releases, Docker, web portal | OK | Self-configuring, auto-released, full account + admin web portal |
| RE tooling (MCP harness, deobf lab) | 🟡 | Live-client driver works; deobfuscation is class+field only |
| **Godot client** (`godot/`) | 🟡 | Login → coach creation → native lobby → native combat, i18n es/en/fr, in-game bug report. Not covered by CI, and its asset-dependent tests can only run locally (assets are deliberately git-ignored) — see [`sprints/S01`](./sprints/S01-client-test-net.md) |

---

## 2. Foundation — protocol & transport ✅

| Item | State | Detail |
|---|:---:|---|
| C2S framing | ✅ | `[u16 len][u8 arch][u16 opcode][payload]`, arch 0/1/2/3, short-frame rejection |
| S2C framing | ✅ | `[u16 len][u16 opcode][payload]`, 64 KiB cap |
| Big-endian buffer helpers | 🟡 | `Reader` lacks `F32`/`U32`/`StringU16` (the `Writer` has them) |
| Text encoding | ✅ | **windows-1252 both directions** (B-068); JRE default charset confirmed at runtime |
| Opcode constants | ✅ | 187 `Op*` + 20 result/flag codes, each with the client class + wire layout inline |
| Router | ✅ | Unknown opcodes logged and dropped; the server never dies on an unknown frame |
| Async write queue + backpressure | ✅ | Race-tested |
| Graceful shutdown | ✅ | No goroutine leaks |
| Encryption | ⛔ | Game login is plaintext in 2.70; the RSA machinery belongs to an admin channel this client never uses |

**Coverage vs the client universe:** ~330 unique client opcodes. **82 handled**,
**96 emitted**, **8 defined-but-intentionally-dark** (each with a written reason —
e.g. 22002 `StatisticData` would wholesale-replace the coach's criteria), **172
with no server code** (mostly unidentified subsystems, admin channels and the
tournament live-match family).

**Known hazard, unguarded:** `Writer.StringU8` documents that several 2.70
decoders read its length as a *signed* byte, so a >127-byte string crashes the
client — but nothing enforces the limit.

---

## 3. Client data layer (`data.bdat` / `indexes.bdat`) 🟡

The project rule is **the client's data files are the single source of truth** —
no hardcoded values, no values ported from the v2.04b beta. Every v2.04b-inherited
value checked so far turned out wrong in 2.70.

### Decoded — 9 of 24 populated record types

| Type | Records | What | Fields | State |
|---:|---:|---|---|:---:|
| 100 | 907 | Coach cards | **26/26**, zero residual bytes across all 907 | ✅ |
| 101 | 138 | Card sets ("panoplies") | 2/2 | ✅ |
| 210 | 16 | Traps / special zones | 8/13 | 🟡 |
| 220 | 203 | Spells | **23/23** (2 decoded-not-evaluated) | ✅ |
| 230 | 51 | Per-round event cards | 4/4 | ✅ |
| 250 | 75 | Fighter equipment / weapons | 15/15 | ✅ |
| 300 | 53 | Summons | 17/17 | ✅ |
| 400 | 39 | PvE challenges | 17/17, 39/39 records exact | ✅ |
| 902 | 111 | Fighter conditions (wounds/blessings) | 5/5 | ✅ |
| — | — | Type 200 `Ht` effect rows (embedded in 6 types) | full | ✅ |
| — | — | `np_1` fight-ruleset elements | full | ✅ |
| — | 47 | Arenas from `maps/fight/*.jar` + `maps/tplg/*.jar` | — | ✅ |

### Not decoded — 15 populated types

| Type | Records | What | Why it matters |
|---:|---:|---|---|
| **901 / 900** | **17 527 / 15** | Sphere Board nodes + headers | ✅ decoded byte-exactly (item 29); the board graph stays client-side, the server serves the fighter's progress |
| 800/801/802 | 332/5/13 | Achievements + categories | **Decoded** (B-106) |
| 1500 | 148 | NPC dialog replies | **Client-side only** - the client loads these itself (`xs_0`); the server never needs them |
| 360 | 42 | Interactive-element rendering | We hand-author elements instead |
| 1100 | 30 | Fusion-laboratory definitions | ✅ decoded (B-089) — altars, not recipes |
| 1600 | 29 | Per-map metadata (music/background) | Cosmetic |
| 1000/1001 | 22/4 | Tournament definitions + level list | We hand-build 3 tournaments |
| 251 | 11 | Equipment pools from Sphere Board nodes | ✅ decoded (item 29); enforced - an evolution fighter may only wear what its bought nodes unlocked |
| 700 | 7 | Calendar events (7 subtypes) | We hand-build the calendar |
| 1400 | 2 | Pro League definitions | Served empty |
| 1 | 1 | Standard fight parameters (singleton) | Unknown impact |

### Decoded but with **no consumer** (🔷)

`CoachCard`: `RequiredLevel`, `FireworkType/Colour`, `IsUnique`, `ObtainableInDraw`,
`DropPercent`, `Rank`, `Parameters`, `FusionPower`, `FusionQuality`, `PetModelID`,
`ColourSlot/Index` · `Spell`: `MaxActive`, `TargetMasks` (202/203 spells),
`CooldownUnlockDelay` · `Summoning`: `DeadFlag`, `NoPositionalBonus`, `Radius` ·
`StaticEffect`: `AppCondition`, `UnappTriggers`, `Type`, `Label` ·
`Challenge`: `Fields[6]`, `TimeChallenge` · `Parameter`: everything except np_1
types 10/11/12/13/14 — the remaining rule families (budget, roster limits,
spell/equipment/class bans, prices, arena choice, event lists) and, inside type
14, victory subtypes 1/2/3 and the `victory_points` / `is_necessary` scalars.

### Open data issues

- **`gamedata` strings are still read as UTF-8.** Every field read today is ASCII
  (`"FIGHTER_CONDITION"`, `"FIGHTER_CARD_USE"`), so nothing is broken — but the
  first name or description field decoded will need `protocol.DecodeText`.
- `maps/env/*.jar` is not read; element layouts are hand-authored.
- i18n `.properties` are deliberately not read (strings are correctly client-side).

---

## 4. Accounts, sessions, persistence ✅

| Item | State | Detail |
|---|:---:|---|
| Auth (opcodes 7 / 1025 / 1024 / 8) | ✅ | Version gate emits `InvalidClientVersion`; client self-disconnects |
| Password hashing | ✅ | bcrypt at default cost |
| Coach creation (2048/2049/2050/2052) | ✅ | Hair/skin order + colour order both fixed vs the client |
| Duplicate login / session kick | ✅ | E2E-tested |
| Reconnect (coach + in-progress fight) | ✅ | 60 s grace, 26333/26334 resume question |
| Crash recovery | ✅ | `ResetConnectedFlags()` on startup |
| Ping keepalive (107 → **108**) | ✅ | Reply must be 108, not 107 — verified live |
| SQL drivers | ✅ | SQLite (WAL, pure-Go), PostgreSQL (pgx), MySQL/MariaDB |
| Transactions | ✅ | 13 explicit transaction sites, with rollback tests on the exchange path |
| **Schema migrations** | 🟡 | **GORM `AutoMigrate` only** — no version table, no down-migrations, no destructive-change path |

**15 persisted tables:** accounts, coaches, coach_cards, coach_friends,
coach_ignored, coach_currencies, coach_stats, fighters, fighter_spells,
fighter_objects, fighter_conditions, teams, team_fighters, mails, mail_cards.

**In-memory only (lost on restart):** live fights, matchmaking queue, direct
challenges, card exchanges, tournament registrations, AoI registry, spectator
lists.

**Persistence defects:**

1. ~~**`Coach.Standing` is never written to the DB**~~ — **fixed (B-077)**. It was
   dropped in three places: `CoachRepo.Save`'s field map, the 2052 descriptor and
   the 4096 actor record (both of the latter hardcoded `0` into an i32 that was
   already the right size, so no wire layout changed).
2. ~~**`TimeInFightSecs` / `TotalPlaySecs` are never incremented**~~ — **fixed**.
   Both were declared, written to the wire (the 2400 panel's dL/dM entries) and
   persisted by `CoachRepo.Save`, but incremented nowhere, so the panel showed 0
   forever — and so did the web portal's account page once it started showing them.
   Play time is stamped in `completeLogin` and banked in `Session.onClose`
   (before the replaced-session return, so a reconnect does not lose it); fight
   time is stamped in `FightManager.Create` and credited by `creditFightTime`,
   called from all three ways a fight can end and made idempotent with a CAS.
   Practice fights count for time (they are excluded from *competitive* records,
   but an hour of sparring is still an hour played). Verified live: a retail
   client session of 1m48s showed as `1m 48s` on the portal.
3. ~~**`CardLocked` is read in three places and set nowhere.**~~ — **resolved:
   the flag should never have existed.** 2.70 has no per-instance card flag — the
   card on the wire is `eb_1`'s four bytes (`NT()` == 4), the owned-card view
   model binds 28 property names and none is locked/cursed/linked, and no i18n
   string for a cursed card exists in any language. The real rules are
   per-TEMPLATE: `aPp` field 12 `tp()` (Bound) and field 13 `tq()`
   (Undestructible), both already parsed and already used for trading. The
   field, both constants and every `Flag: CardCursed` initialiser are gone;
   mail now gates on Bound alone, matching the client (an indestructible card
   may be posted). See BUGS.md B-094 — and B-093, the exchange-opcode fix
   this investigation uncovered.
---

## 5. Overworld 🟡

| Item | State | Detail |
|---|:---:|---|
| World entry (4600 + 4516 + 200) | ✅ | The three-frame sequence; 4516 is mandatory or movement stays locked |
| Coach movement (4501 → 4500) | ✅ | |
| Area-of-interest scoping | ✅ | Bilateral `known` sets, spawn/despawn on boundary crossing, configurable radius |
| Actor spawn/despawn (4096 / 4098) | ✅ | 16 missing bytes fixed during the audit |
| Interactive elements (201) | 🟡 | **139 elements across 15 kinds, hand-transcribed** from the env jars. Reproducible from `maps/env/*.jar` (verified 139/139 on instanceId + kind), but `alt` is not in them - see item 24 |
| Zaap network (4512) | 🟡 | 12 destinations **hand-mapped**; clan-island card unrouted (`TODO(clan)`); 6 unreleased placeholder cards deliberately unrouted |
| Fireworks (22095 → 22094) | ✅ | Echoed to launcher + nearby sessions |
| Direction change (4521 → 4522) | ✅ | Cosmetic only — 2.70 dropped directional damage |
| Intro cutscene / Lua scenario system | ⬜ | The client expects a scenario message the server does not implement |
| NPC dialog trees | ✅ | Client-side only — the client loads type 1500 itself; the server just spawns the NPC (item 27) |
| Zone triggers | ⬜ | env type 8 |

Element kinds spawned: DemonTotem 24, Zaap 21, CardMaster 13, Mailbox 12,
BreedMaster 12, DemonChallenge 11, ZoneTrigger 9, NPC 6, FusionLab 6, Graveyard 6,
Firework 5, TournamentTotem 2, Challenge 2, DemonI 1, DemonIII 1.

---

## 6. Chat, social & presence 🟡

| Item | State | Detail |
|---|:---:|---|
| Vicinity chat (3153 → 3152) | ✅ | AoI-scoped, no self-echo |
| Private message (3155 → 3154 / 3204) | ✅ | |
| Channel chat (3151 → 3140) | ⛔ | **Vestigial 2007 feature, unreachable in 2.70.** The client cannot SEND 3151 — `ChannelContentCommand` is referenced by nothing in any shipped jar — and a 3140 we send is dropped: it routes to pipe 3, which `du_1` never registers, so `ql_1.a` dereferences null and the frame loop swallows it. Kept as protocol preservation only |
| Channel membership family | ⛔ | **Dead code in 2.70** — all six handlers in `om_0` cast the message and `return false`. No C2S counterpart exists (not even in the 2007 reference), no UI, nothing gated. Sending them is unobservable |
| Trade chat (`/t`, 3159 → 3168) | ✅ | Global. Was dropped as an unhandled opcode while the client rendered the sender's own line locally, so it looked sent (B-103) |
| Clan chat (`/c`, 3199 → 3198) | 🟡 | Served and **validated** — the client-supplied guild id is re-checked against the sender's own. No coach has a guild yet (item 31), so it resolves to nobody; the client also self-gates and emits nothing without one |
| Group chat (`/p`, 3161 → 3170) | 🟡 | Served. The audience is resolved from the sender's own fight, **not** the client-supplied coach id — trusting that would make `/p` an unfilterable DM channel. It now HAS an audience: 2v2 is done (item 30), so an ally in the same fight receives it |
| Chat safety (ignore list, markup, rate limits) | ✅ | Ignore filtering on every pipe — private had **no client-side filter** and force-opens the chat window — plus `<`/`>` stripping and the client's own 30 s Trade cooldown (B-104) |
| Friends add/remove + list | ✅ | All four ack layouts differ per opcode and are individually verified |
| Ignore add/remove + list | ✅ | |
| Presence notifications | ✅ | 3148/3150/3164/3166 |
| GM commands | ✅ | `/HELP /WHERE /TP /WORLD /WHO /STRENGTH /FSTATE /ENDFIGHT /EVOFIGHT /SUDDENDEATH /MAPDESTRUCT` |
| Guild / team-scoped routing | ⬜ | Blocked on guilds existing |

**Open cosmetic bug:** the *client* mangles accented names it receives — proven
with two controlled experiments (every server-provided name gains exactly one
UTF-8→cp1252 hop, and pre-compensating makes it worse). Our encoding is correct
and must not be changed. The remaining work is locating the offending call in the
decompiled client.

---

## 7. Economy & items 🟡

| Item | State | Detail |
|---|:---:|---|
| Card inventory (5200 / 5203 / 5201) | 🟡 | Equip works (14 slots); **5203 card removal is unactionable** — its uids are client-generated, so the server cannot tell which card row they mean (see §13 item 14) |
| Multi-slot token wallet (4001) | ✅ | Byte type → i32, full sync push |
| Card Master shop (201 → 5401) | ✅ | Prices from real card data (845/907 cards priced); stock from the element's card list |
| Token purchase (5450 → 5403/5200) | ✅ | Transactional debit + grant |
| Card-for-card barter (5400) | ✅ | Enforces the client's own rule `Σ(given.value × qty) ≥ wanted.value` |
| Fusion Lab (5490 → 5491) | 🟡 | **There are no recipes.** Type 1100 is the 30 ALTARS (decoded). The target card comes from the request's last id and the slot count from the altar (B-089); only the success CURVE is still a flat roll |
| Card exchange / trading (5101–5112) | ✅ | Dupe-safe: staging resets both ready flags, commit re-validates every card, full rollback |
| Bound / undestructible enforcement | ✅ | 171 + 65 of the 907 cards cannot be traded |
| Mail (539, 15000–15007, 15506/15507) | ✅ | List, send, delete, attachments, capacity 20, 10 attachments, rune-safe truncation, online toast |
| System mails | ⬜ | Parsed, never generated |
| Faucets | 🟡 | Starter tokens (1000) + starter cards + fight-win reward (50) — **all three magnitudes are invented** |
| Daily login / other faucets | ⬜ | |
| Demon II affiliation (5470) | ⬜ | |

---

## 8. THE FIGHT SYSTEM 🟡

The whole single-coach-vs-single-coach loop is **server-authoritative**: the
client renders what the server decides. Each fight is a single goroutine actor
with a 64-slot mailbox, so no fight state is ever touched under a lock.

### 8.1 Fight lifecycle & phases ✅

| Item | State | Detail |
|---|:---:|---|
| 5 phases | ✅ | Presentation → Placement → Observation → Action → Ended |
| Phase transitions | ✅ | Idempotent compare-and-swap, so "both ready" and a clock firing cannot double-advance |
| Ready gates (8011/8023/8031 → 8012/8024/8032) | ✅ | Session-less teams pre-marked ready so solo/PvE fights advance |
| Phase clocks | ✅ | Presentation 20 s, placement 30 s, observation 10 s, turn 30 s, AI turn 1.2 s, disconnect grace 60 s |
| Per-fight turn clock | ✅ | Read from np_1 rule 10 as a **delta**, not a global (B-072) |
| Fight creation (8000) | ✅ | Presentation blob, grid tail, coach deck, special-cell list |
| Observation phase | 🟡 | Exists as a 10 s cue pair with **no mechanic between the cues** |
| Placement (8021 → 8022) | ✅ | Gated to the placement phase; the cell must be one of the fighter's own side's start cells and unoccupied (B-075). Altitude deliberately unvalidated, as on the movement path |

### 8.2 Turn order, timeline & the turn loop ✅

- **Initiative:** all fighters of both teams sorted by initiative descending,
  stable-sorted so ties keep team-A-before-team-B. The client plays exactly this
  order — its own comparator is a no-op. All 12 breed initiatives were corrected
  from the v2.04b figures (B-058).
- **Turn begin:** refill AP/MP → reset cast history → broadcast 8104 → fire
  turn-start effect areas → fire turn-start special cells → death check → arm the
  right clock (skip-turn / petrified / absent team / AI / human).
- **Turn end:** broadcast 8106 → revert one-turn special-cell buffs → advance to
  the next *living* fighter → on wrap into a new round: tick buffs, states,
  damage transfers, effect areas, poisons, draw the round event card, maybe
  advance sudden death.
- **Not a gap — investigated and closed.** This used to read "initiative buffs
  (actions 76/77) are tracked but never re-sort the timeline". Three independent
  checks say there is nothing to fix:
  **(a)** *no shipped spell uses action 76 or 77* — a dump of all 203 spells and
  533 effect rows returns zero, so nothing can change initiative mid-fight;
  **(b)** the client's timeline (`bg_1`) is an ordered list with insert / remove /
  advance and **no comparator, no sort and no initiative reference at all**;
  **(c)** there is no wire message that reorders it, so a server-side re-sort
  would silently desync the client's turn-order widget.
  Initiative from GEAR and conditions is applied pre-fight in
  `computeFighterStats` and *is* what `buildTimeline` sorts on, which is the only
  place 76/77 legitimately appear. Implementing a re-sort would be inventing a
  mechanic no data triggers.
- **Gap:** `refillFighter` restores MP on a rooted fighter (movement is still
  correctly blocked, but the client's MP gauge diverges).

### 8.3 Movement, tackle & pathfinding 🟡

| Item | State | Detail |
|---|:---:|---|
| In-fight movement (4503 → 4524) | ✅ | Origin-excluded step list, 1 MP/cell, Chebyshev adjacency (diagonals legal) |
| Move validation | ✅ | Rooted, MP budget, walkable, not destroyed, adjacency, not held by another fighter |
| Stop-on-contact | ✅ | Path truncated when entering an enemy's zone of control |
| **Tackle** (→ 4506) | 🟡 | Each adjacent enemy holder is evaded **independently, all must succeed**; failure ends the turn. Formula `dodge − block` clamped 0..100 — **the endpoints are client-verified, the curve between them is a server choice** |
| Block / dodge values | ✅ | From the breed table + summon templates + timed buffs, stored unclamped so reverts are exact |
| Altitude (z) validation | ⛔ | Deliberately unvalidated — (x,y) is the unit of movement, the client owns per-cell altitude |
| Pathfinding | 🟡 | **BFS flood fill, MP-bounded, 4-directional only.** Used by the AI only — so the AI moves strictly worse than a human client can |

### 8.4 Casting, close combat & weapon use 🟡

| Path | Opcodes | State | Detail |
|---|---|:---:|---|
| Spell cast | 8109 → 8110 | 🟡 | AP cost → target validity → cast criteria → frequency limits → fumble roll → crit roll → debit AP → resolve effects → flush → end check |
| Close combat ("corps-à-corps") | 8111 → 8112 | ✅ | Uniform 5 AP / 5 dmg (7 crit) of the breed's element, verified against the client's `xq` table. Weapon-independent, always available |
| Weapon / equipment use | 8107 → 8108 | ✅ | Ownership check, usable-while-carried flag, same targeting rules as spells (B-055) |
| Coach action-card play in fight | — | ⬜ | The deck IS castable: exposed as `"coachSpellInventory"` (a list of `yp_2`) and played with **8109**, the ordinary spell cast. But the blob resolves against the SPELL registry (`new ajO(je_1.Wa(), 8)`) while we emit card ids — see Tier 2 item 19 |

**Targeting validation:** walkable + not destroyed, Manhattan range window, Range
stat boost only when base `RangeMax > 1` and the spell is not
`RangeNotBoostable` (5 spells), `OnlyLine`, `NeedFreeCell`, `TestLoS`.

**Spell ownership** ✅ — `castSpellByFighter` requires the caster to own the
spell (B-075), closing the hole where a forged 8109 could fire any of the 203
spells from any fighter. Two legitimate sources: a coach fighter's equipped
`Fighter.Spells`, or a server-driven fighter's single `SummonSpellID`. The
second is not an edge case — PvE challenge demons carry a `domain.Fighter` for
breed and stats with an **empty** spell list, so a check against `Fighter.Spells`
alone would have muted every demon in the game.

### 8.5 Spell effect coverage — measured 🟡

Measured against the shipped data (`server/data-dist`, 203 spells / 533 effect rows):

| Metric | Value |
|---|---|
| Spells with **every** effect row modelled | **203 / 203 (100 %)** |
| **Effect rows resolved** | **533 / 533 (100 %)** |
| Fighter-card (weapon) effect rows resolved | **72 / 72 (100 %)** |
| Distinct mechanic kinds implemented | **38** (over ~143 mapped `mh_2` action ids) |

**The 31 modelled kinds:** flat elemental damage (direct + "par sort"), HP leech,
heal, %-of-max-HP damage, poison (a real per-round DoT with re-roll), damage
scaled by remaining AP, damage scaled by remaining MP, instant death, AP loss,
MP loss, AP steal, MP steal, AP gain, MP gain, teleport, swap, push, pull,
summon, state, buff, trap, dispel, visual-only, carry, throw, aura, zone MP loss,
line damage, damage transfer, remove-effect-by-id.

**Every action id in the shipped data is now resolved** (ROADMAP item 28). The
last nine were closed by reading the client rather than guessing from the French
labels, and only five of them turned out to be server work:

| Action | Client label | Resolution |
|---:|---|---|
| 140 | Diminution du cooldown d'un sort | **modelled** - rewrites the source spell's cooldown to now+params[0]; only ever shortens, and an infinite (63) cooldown collapses too |
| 84 | Reveler l'invisible | **modelled** - clears the server's own invisibility state; the client expires its `co_0` on receipt |
| 88 | Renvoi de sort | **modelled** - the next damaging spell is redirected to its caster, server-side (the client's `amv_1` redirects locally, so the server must agree) |
| 153 | Est repousse de sa cible | **modelled** - push with the roles swapped (`azw_0` is `na_2` using `bWl` for `bWm`); shares the shove core |
| 150 | Inverse les effets des cases bonus | **modelled, server-only** - the client's flag `yl_1.aDR` has zero readers, so the inversion can only live server-side |
| 68 | Tourne le regard vers la cellule ciblee | cosmetic -> `KindVisual` (turns the sprite, nothing else) |
| 170 | Aucun effet | cosmetic -> `KindVisual` (the null effect; exists to play an animation) |
| 171 | Devenir evanescent | cosmetic -> `KindVisual` (a blue material tint; the real numbers are actions 80 + 164) |
| 172 | Bouger vers la cible adverse la plus proche | **dead code** - calls `gn_0.Qf()`, an empty method with no override anywhere; the behaviour already lives in the server's summon AI |

Two of these (140, 153) were blocked on 8120 blob parts the server never sent -
see B-110.
**The "triggerée en zone" family is now complete** (was 165/166/169): the client's
`mh_2` table shows it as one shape with six members — `165` fire, `166` water,
`167` air, `168` earth (one `aez_1` class each), `169` AP (`MM`) and `177` MP
(`vn_1`). All six are the spell's own zone centred on the CASTER with the caster
excluded, so 169 reuses 177's body and 165–168 differ only by the element
`damageElement` returns, resolving through the ordinary elemental pipeline so
resistance, rebound and transfer apply. 167/168 have no shipped rows but cost
nothing to include, and omitting them would leave the identical silent hole if
data ever used them.

### 8.6 Damage model & combat statistics ✅

```
damage = base + caster.flatDmg[elem] − max(0, target.flatRes[elem])
       → × (1 + dmgPctAll + dmgPct[elem] − resPctAll − resPct[elem])
       → floored at 0, integer truncation
```
Neutral (element 0) bypasses the whole formula. Stats are stored **unclamped** and
bounded at read time, so a timed buff reverts exactly.

| Stat family | Action ids | State |
|---|---|:---:|
| Flat elemental resistance | 21–28 | ✅ |
| Elemental resistance % | 29–36 | ✅ |
| Flat elemental damage | 40–47 | ✅ |
| Elemental damage % | 48–55 | ✅ |
| All-element res % / dmg % | 80/81, 82/83 | ✅ |
| AP / MP loss resistance | 86/87 | ✅ |
| Damage rebound % | 89 | ✅ clamped 0–99, single hop, reduces what the victim takes |
| Heal power % | 78/79 | ✅ |
| Damage transfer | 129 | 🟡 direction/percentage are derived, not client-verified |
| Positional / flanking bonus | — | ⛔ 2.70 dropped directional damage |
| Armour / shield points | — | ⬜ |

**Critical hits & fumbles:** base rates are **0/0** — crit in 2.70 is entirely
earned (some spells grant +100, a guaranteed crit, which only works from a base of
0). Fumble is rolled first and precludes a crit; a fumble spends the AP, resolves
zero effects, and still counts against frequency limits. A crit does not multiply
damage — it selects the effect rows the data authored as critical.

### 8.7 Areas of effect ✅

| Shape | State |
|---|:---:|
| Point (1) | ✅ |
| Circle — Manhattan diamond (2) | ✅ |
| Cross (3) | ✅ all three arities the client accepts — 1, 2 or 4 arm lengths (`qv`) |
| Directional T (4) | ✅ orients by the cardinal step from source to centre |
| Ring / annulus (5) | ✅ |
| Square / rect (6) | ✅ |
| Inverted T (9) | ✅ |
| "All" (32767) | ✅ |
| Point-list (8) | ✅ explicit (dx,dy) offsets, rotated by the cast direction (`acg_0`) |

Shapes **7** and **10** exist in the client's `zg_1` table (`nd_1`, `aJF`) and are
not implemented — no shipped record uses either.

Friendly fire is authentic: an area lands on allies, enemies **and the caster**.
Expanded targets are re-filtered by each effect's own target conditions.

### 8.8 Target conditions & cast criteria ✅

- **Target conditions** — full port of the client's `aLc.a`. OR across the
  condition list, AND within one condition. Bits: caster, ally, enemy, human,
  summoned, effect-area, ally-except-caster, not-caster, **breed-is-zero (512) /
  breed-is-not-zero (1024)**, plus **14 positive and 14 negative breed bits**.
  Summons satisfy no positive breed bit. Only `CONDITION_IN_AOE` (bit 1) is a
  no-op.
  512/1024 test the target against `xq.axE` (breed id 0, the stat-less
  pseudo-breed) rather than a numbered slot, and were added in B-074 because the
  type-12 fight-start effects use 1024 to exclude summons — **an unimplemented
  condition bit is silently permissive**, so the buff would otherwise have landed
  on every summon. The file used to credit `aap.a`, which is a genuinely
  different validator (is/is-not pairs low down, count thresholds at 512+); that
  misattribution is what made B-073 believe a second evaluator was needed.
- **Cast criteria** — all 15 tokens implemented: `canSummon`,
  `can/cantCastWhenCarrying`, `cantCastWhenCarried`, `canCastWhenDying` (≤25 % HP),
  `canCastWhenInjured` (≤99 %), `canCastWhenDrunk`, the three Masqueraider mask
  gates (positive + negative), `canCastWhenCarryAlly/Ennemy`. Unknown tokens are
  permissive, matching the client.
- **Spell-level `TargetMasks`** ✅ (B-081) — decoded on 202/203 spells, but the
  client only APPLIES them when `EnforceTargetMasks` (field 19) is set, which is
  true for exactly 3: spell 468 (ally), spell 83 (ally **and** summoned), and
  spell 449 (`1<<62` = the target is a ground **effect area**). The first two are
  plain per-effect bits the existing evaluator already decides. The third is a
  targeting *mode* this server does not model, so a mask carrying any bit we
  cannot represent is skipped whole rather than half-enforced.

### 8.9 Cast frequency ✅

Per-fighter, per-spell: **cooldown** in table-turns (**63 = once per fight** —
this field was read from the wrong offset until B-059, which left 97 of 203 spells
with no cooldown at all, 28 of them once-per-fight), **max casts per turn**,
**max casts per target** (per-target counters cleared on the caster's own turn).
`ParentID` makes 5 spells share their parent's limits. `MaxActive` (max live
instances) is 🔷 decoded, not enforced — it needs a live-instance counter.

### 8.10 Line of sight 🟡

Altitude-based ray cast matching the client's algorithm: both endpoints raised by
an eye offset, the ray **oversampled 8× the Chebyshev step count**, per crossed
cell the ray's minimum altitude kept, terrain blocks iff `alt > rayMin` (grazing
equality is visible). Two tries: eye→eye, then eye→feet. Void is never blocking;
scenery always blocks.

**Deliberate limit:** implemented **terrain-only**. The client also blocks on
obstacle/creature occluders; we omit that, making our blocking a strict *subset* —
we can miss a block (an accepted anti-cheat gap) but never invent one. **Fighters
do not block line of sight.**

### 8.11 Fighter states ✅

12 states from 14 action ids. Applying a state **extends, never shortens**;
duration 63 is infinite; the source effect id is recorded so action 149 can strip
one specific state.

| State | Action(s) | What it enforces |
|---|---|---|
| Rooted | 65 | Cannot walk (also zeroes MP on apply). The only state that stops self-movement |
| Petrified | 96 | Turn is skipped |
| Stabilized | 94 | Blocks push (37) and pull (38) only |
| Anchored | 127 | Blocks being carried (58) only |
| Intransposable | 128 | Blocks swap (64) only |
| Invisible | 57 | AI ignores the fighter when picking targets |
| Immune | 95, 124 | Takes no damage; heals still land |
| Skip turn | 56, 111 | Next turn(s) passed, one charge consumed per skip |
| Drunk | 126 | Gate for `canCastWhenDrunk` |
| Mask: class / coward / berzerk | 173 / 174 / 175 | Gates for the Masqueraider cast criteria |

Note B-053: 127 and 128 used to be folded into root/stabilise, which froze the
whole arena on round 1 (event card 14 is 94+127+128). They are distinct now.

**Absent:** sleep/charm/confuse, states that modify damage taken/dealt, and
`statePetrified` does not zero AP/MP the way the client does.

### 8.12 Buffs, debuffs, poison & dispel 🟡

- **Three resolution classes:** *resource* buffs (HP/AP/MP/Range/Summons/
  crit/fumble/block/dodge — applied mechanically, `affectsMax` moves the ceiling),
  *combat-stat* buffs (the elemental and scalar families, reverted exactly by
  applying the negated delta), and *render-only* buffs (tracked with delta 0 so
  the buff count and targeted removal still match the client).
- **Duration:** read from the effect record, any slot ≥ 63 is infinite, ticked
  once per **table turn** (round-based, matching the client's own counter),
  reverted on expiry. The duration rides the wire so the client shows the icon
  and timer.
- **Poison (61)** is a real DoT: immediate first tick, then a fresh roll every
  round from the stored dice params, infinite-capable, stopped on death.
- **Dispel (62)** reverts and drops every *finite* buff (infinite enchantments
  survive) and clears states.
- **Remove-effect (149)** strips buffs, states and auras matched by source effect
  id, capped by a param — used by the Masqueraider mask-switch spells, which each
  bundle ~15 of these.

- **Stacking is CORRECT as-is — verified against the client.** A fighter carries
  **two registries with different semantics**, and the client is explicit about
  both. Buffs live in `gn_0.baO`, an `alf_1`, keyed by `xb_2.je()`; that key is
  assigned in `aka()` from `xb_2.ahT()`, a **monotonic counter**, because the
  pluggable key strategy `aes_2` has **no implementor anywhere in the client**
  (so `bWD` is permanently null). Two casts therefore can never collide, the
  registry's duplicate guard in `o()` never fires, and its only removal helpers
  are bulk **by source** (parent effect, fighter, spell, effect type) — there is
  no same-effect eviction to be found. So the client **stacks**, and our blind
  append matches it. Repeat-casting is bounded by **cast frequency** (cooldown /
  max-per-turn / max-per-target, all enforced) and by resource clamping, not by
  merging. Locked in by `TestBuffsStackAndExpireIndependently`, which
  mutation-fails against a merge. States are the *other* registry (`gn_0.baR`,
  an `aLM extends Kt`) and really are reference-counted — see the next bullet.

**Gaps:**
- ~~**Dispel deletes infinite states too**~~ — **fixed (B-077)**: permanent states
  now survive, as permanent buffs always did.
  The **general** fix is still open, and the client shows what it looks like:
  properties live in a **reference-counted** store (`Kt.g()` increments, `h()`
  decrements and removes at zero, `c()` reads the count), so a summon's innate
  root and a spell's root coexist as count 2 and removing one leaves the other.
  Our `States` map holds remaining TURNS, conflating "how long" with "how many
  sources", and `stateSrc` remembers only the LAST effect id to set each state.
  **Measured: not reachable in shipped content, so this stays deliberately
  unimplemented.** Overlap is certainly real — spell 419 applies five states at
  duration 63, and spells 147 and 170 each apply `rooted` twice in a single cast
  (170 with two different durations, 2 and 1). But the divergence is only
  *observable* if something removes one source of a multi-source state early,
  and the only mechanism that removes a state by source is action 149. Of the 50
  action-149 rows in the spell table, exactly **6** target a state effect id, and
  all six are the three Masqueraider mask spells stripping the other two masks —
  states whose source is unique in the whole game (173←9192, 174←9193, 175←9194),
  mutually exclusive by design and self-gated. Every other removal path is
  wholesale (dispel strips all finite states, death and fight-end clear
  everything) and so is indifferent to refcounting; natural expiry is correctly
  served by max(), since a state should last until its longest source ends.
  Implementing refcounting today would therefore be a behaviour-neutral refactor
  of the state model — pure risk. The assumption is pinned instead by
  `TestStatesTargetedBy149AreSingleSourced` (mutation-verified), which fails the
  moment a 149 targets a state with more than one source.
- Dispel does not touch poisons, damage-transfer links or auras.
- **Timed buff/debuff icons are not restored on reconnect or spectate** — the
  server keeps the buffs and they keep working; only the client-side icons are
  missing until they expire. CREATE_FIGHT has no slot for them: its two id lists
  are sphere-board nodes and persistent conditions (B-083), and the latter is
  now sent, so *wounds* do survive. Restoring timed buffs needs the per-effect
  message the client uses during normal play.

### 8.13 Static & special cells ✅

Trigger policy is **turn-start only** — per the manual, walking over a special
cell does nothing; the fighter must *start* its turn on it. Buffs last exactly one
turn and are reverted at turn end (the AP revert correctly drops the ceiling and
only clamps the current value, so a fighter that already spent the bonus AP is not
charged twice).

| Template | Tile | Effect | Scaled by the bonus-cell multiplier? |
|---:|---|---|:---:|
| 1002 | Killer | HP → 0, no save, no resist | no |
| 1003 | Trap | −10 HP | no (deliberate — it is a malus) |
| 1004 | Eagle Eye | +1 Range | yes |
| 1005 | Shield | +10 % all resistance | yes |
| 1006 | Panacea | +10 % heal power | yes |
| 1007 | Enthusiasm | +10 % damage dealt | yes |
| 1008 | Motivation | +1 AP (raises max too) | yes |
| 1009 | Healing Heart | +5 HP, only if below max | yes |

Cells are streamed to the client in 8000 (without that list the tiles are inert
decoration — B-048) and each firing broadcasts a tile animation plus the
characteristic-boost line. The **bonus-cell multiplier** (np_1 rule 13, up to ×10
on shipped challenges) is applied.

🟡 The magnitudes come from the game manual, not from client data.

### 8.14 Traps, glyphs & auras 🟡

Placed by action 66 (trap, from a type-210 template) and action 176 (aura).

- **Two trigger policies**, read from the template: **turn-start** (glyphs) and
  **walk-on** (classic traps). An aura always and only fires on turn-start, and
  never on its own caster.
- **Lifetime:** traps count down `maxExec` (≥63 or <0 = unlimited); auras age per
  round and die when their caster dies.
- Auras **follow the caster's live cell**.
- Firing replays the template's inner effects through the normal resolver, with a
  **re-entrancy guard** so a trap inside a trap cannot loop, and a slice snapshot
  so a self-removing area cannot corrupt iteration.
- Walk-on traps are checked **per movement step**, not just at the destination.

**Forced displacement arms traps** ✅ (B-076) — push, pull, teleport, swap (both
fighters) and throw all run the enter check. The client proves this is right:
`he_1.a(from…, to…, fighter)` is a pure position-change notification called by
**eight** effect classes, including `go` (teleport) and `aox_1` (swap, once per
swapped fighter). Carry is deliberately excluded — a carried fighter is stacked
on its carrier and holds no ground.

**The trigger enum, recovered in full** (B-076): **10000** turn-start ✅,
**10001** entered ✅, **10002** left ⬜, **10008** stayed-inside ⬜, plus **10003**
and **10006** ⬜ whose meanings are still unknown. Consequences worth knowing:
template 1016 `mauvaisOeil` fires only on 10003 and so **can never fire here**,
and templates 1017/1018/1019 ship with an **empty** trigger array.

**Not read from the template:** re-trigger policy (once per team / per target /
always), the two trigger bitmasks, the delayed re-trigger timer.

### 8.15 Displacement — carry/throw, push/pull, teleport, swap 🟡

| Mechanic | Actions | State | Detail |
|---|---|:---:|---|
| Carry | 58 | ✅ | Bidirectional links; refused if either party is already linked or the target is anchored. The carried fighter stacks on the carrier's cell, is dragged on every move, is **not independently targetable**, does not hold ground, and cannot tackle. Broken on death |
| Throw | 59 | 🟡 | Requires a walkable, unoccupied destination. **No landing damage** (matching the reference implementation) |
| Push / Pull | 37 / 38 | 🟢 | Blocked by *stabilized*. Direction quantised to 4 cardinals. Ray-traced cell by cell. **Cannot be shoved up a step taller than 2.** Collision damage = `cellsLeft × 6` into void/edge, `× 3` into a fighter — **and the blocking fighter takes the same damage**. Not live-verifiable (no practice spell pushes) |
| Teleport | 39 | ✅ | Moves the *caster* to the aimed cell |
| Swap / Transposition | 64 | ✅ | Blocked by *intransposable* |

Collision damage deliberately does not broadcast its own HP-loss line (the client
spawns its own display) — which means immunity, resistance, rebound and transfer
are all bypassed for collision damage specifically.

### 8.16 Summons & AI 🟡

**Summons** (actions 67 creature / 75 double / 97 mirror) ✅

- Stats from the type-300 template; requires a walkable, unoccupied cell.
- **Inserted into the timeline immediately after the summoner** (and after any
  summons it already owns), matching the client so both timelines stay in lock-step.
- **Innate properties applied at spawn** (B-060): of the 53 shipped creatures,
  **22 are rooted, 21 cannot be carried, 18 are stabilised, 15 intransposable**;
  29 carry a block % and 36 a dodge %, both feeding the tackle roll.
- **Summon cap** = `1 + NB_SUMMONS`, raised by action-74 buffs (stored unclamped
  so a summon-steal can drive the cap to 0) and enforced as a cast criterion.

**AI** 🟡 — four archetypes *derived* from the fighter's defining spell, because
there is no behaviour data anywhere in the game files. The archetype still comes
from that one spell, but **casting no longer does**: a fighter plays from a
**repertoire** (`aiRepertoire` = `SummonSpellID` then its `Fighter.Spells`,
deduped, both exactly what `fighterKnowsSpell` accepts) and re-picks the best
castable spell — affordable, off cooldown, within frequency limits and passing
the real targeting validator — before **every** cast, so it reacts to a kill or a
cooldown mid-turn. Challenge demons now ship a real loadout too
(`breedSpellRepertoire`: the breed's damaging AP-costing spells, strongest first,
capped at `maxFighterSpells`); measured, that is 1–7 per breed, typically 3–4,
where they used to have exactly one. A summoned creature has no `Fighter.Spells`,
so its repertoire is still a single spell and its behaviour is unchanged.

| Behaviour | Trigger | Turn plan |
|---|---|---|
| Blocker | no spell / no spell data | walk adjacent to nearest enemy, then hit it |
| Aggressive | damaging spell, MP < 4 | close into range, cast until dry |
| Kite | damaging spell with MP ≥ 4, or a debuff spell | close, cast, retreat |
| Self-buff | buff on a self-range spell | cast on self, then block |

Target selection: nearest by Manhattan distance → tie-break higher initiative →
tie-break real fighter over enemy summon (the manual's "summon intelligence"
rule). Invisible enemies are skipped. Movement scoring is fully deterministic
despite Go's random map order.

Positioning asks the **real validator** from each candidate cell
(`spellTargetValidFrom`), so "can I fire from there?" accounts for the Range-stat
extension, only-line, free-cell, line-of-sight and target masks. It previously
used a bare Manhattan window, which both walked closer than necessary and could
walk somewhere the cast was then refused, wasting the turn.

Every archetype except Kite then spends **leftover AP on close combat**
(`closeCombatAI`), after casting — a spell is almost always the better use of AP,
since close combat is a flat 5 AP for a flat 5 base damage. Kite is excluded on
purpose: its plan is to break contact. Before this, a fighter with no castable
spell did *nothing at all* — the blocker walked adjacent and stood there.

The AI also **never splashes its own team** (`aiWouldHitOwnTeam`): area effects
land on allies, enemies and the caster alike, and 15 damaging breed spells carry
an area shape - several the strongest their breed has, including one that hits
*every living fighter*. Picking by damage rather than by cost made those the
preferred choice, so the gate is what keeps the repertoire from being a
downgrade (B-085). Any friendly splash disqualifies the spell outright.

The AI also **never aims a support spell at an enemy** (`aiSpellHarmsEnemy`, a
whitelist of harmful effect kinds). That is not hypothetical: a real coach's team
becomes AI-driven the moment the coach drops mid-fight, carrying whatever the
player equipped, and only 3 shipped spells have an enforced ally-only mask — so
without the gate the AI would cheerfully heal the enemy it was attacking (B-084).

Its movement flood also **skips cells sudden death has destroyed** - players
were already guarded by `validateFightMove`, but the AI walks on paths from
`reachableCells`, which was not, so it could stop on one (instant death at the
next shrink) or walk THROUGH cells the client has flagged movement-blocked
(B-087).

The AI also **will not end a move on a Killer tile** (`aiCellIsSuicide`), which
kills whoever starts a turn on it. Watched live: a Xelor closing on the player's
team stepped onto one and was dead the next turn, because movement scoring only
measured distance. Passing OVER one is still allowed - it fires at turn start -
and the Trap tile is deliberately not avoided, since 10 HP is a cost to weigh
rather than certain death.

**What the AI cannot do:** heal or buff allies; summon; place traps; focus-fire
cooperatively; consider trap tiles; move diagonally. There are no difficulty tiers. Still the biggest
gameplay-quality lever left, but the two largest pieces — the single-spell limit
and never attacking — are now gone.

### 8.17 Map destruction / sudden death ✅

One of the most faithful parts of the codebase, and verified live.

- Driven by action **117** over the ordinary running-effect opcode (8120) — the
  sibling 8121 only *attaches* an effect and never executes one, which is why an
  earlier attempt did nothing (B-050).
- The **spiral walker reproduces the client's generator byte-for-byte** and is
  pinned by a unit test. The destroy order is the *reverse* of generation
  (outermost → centre) because the client prepends. The server sends only a
  cumulative count; both sides derive the identical cell list independently.
- **Pacing:** a step is cut every 12 walkable cells, so the collapse advances
  evenly regardless of how much void the outer band contains; steps that would
  remove no new walkable cell are skipped. The final step is always 299 cells
  (everything outside the 5×5 core).
- **Trigger turn 15 by default**, overridable per fight from np_1 rule 11 as a delta.
- **Kill rule:** a fighter dies only if standing on a cell removed by *that* step.
- Destroyed cells are **per-fight** (the arena value is shared and never mutated)
  and block movement, spell targeting, teleport and card targeting.
- Verified live on 2026-08-04: `/SUDDENDEATH` produced `step=1 r=104`, then
  `step=2 r=119 killed=2`; the client rendered the collapse and both fighters
  standing on removed cells died.

### 8.18 Per-round event cards ✅

The client only *displays* the drawn card, so the server applies the effects
itself. Deck is ids 1–27 (the 43+ range is PvE/creature-scoped and the 48–59 "god
set" would dominate), Fisher-Yates shuffled per fight, reshuffled on exhaustion.
**Round 1 always draws event 14 "Cloué au lit"** (actions 94+127+128), placed at
the deck top so it cannot recur in the cycle. Each effect is applied once per
living fighter with that fighter as both caster and target — self-casting is what
makes "+30 % damage" scale off each fighter's own stats — and every effect is
still gated by its own target conditions, which is how the 12 breed-god cards
restrict themselves.

Verified live: round 1 drew event 14 server-side and the client displayed **"Cloué
au lit"**, whose own effect text independently confirms the 94+127+128 mapping.

🟡 8000 sends an event count of 0, so the client gets no pre-declared event list.

### 8.19 Arenas ✅

All **47 shipped fight maps** decode from `maps/fight/*.jar` + `maps/tplg/*.jar`
(**46 of them playable** arenas in the registry; hardcoded to world 5 until
B-052). Three cell classes: floor, void (unwalkable,
LoS passes), scenery (unwalkable **and** blocks LoS). Per-arena start cells per
side (8 each), coach pedestal cells, special cells, camera centre. The exact grid
the server validates against is streamed to the client, so a genuine client path
always passes. A hand-decoded world-5 fallback keeps unit tests and bare checkouts
working.

🟡 Arena selection is uniform random — np_1 rule 29 ("choose the arena") is not
consumed.

### 8.20 Fight rulesets (np_1) 🟡

Per-fight (never package-global, deliberately — a rule set by one fight must not
leak into another). **5 of ~25 rule types are wired:**

| Type | Rule | State |
|---:|---|:---:|
| 10 | Per-fighter turn duration (**delta**) | ✅ |
| 11 | Sudden-death turn (**delta**) | ✅ |
| 12 | Cast an effect on all fighters at fight creation | ✅ 3 challenges, +40 % dodge for the fight, summons excluded by mask 1024 |
| 13 | Bonus-cell multiplier (absolute) | ✅ |
| **14** | **Victory conditions** (9 challenges) | ✅ subtype 4 ("reach turn N") wired; 1/2/3 decoded, unused by any shipped record |
| 1–9 | Budget, min/max fighters, spell & equipment allow/ban lists | catalogue only |
| 15–32 | Class limits/bans/prices, event lists, coach spell, max classes, **arena choice**, max league, hide opponent stats | catalogue only |
| 900–930 | **PARAMETERS**, not rules — every one is *"Paramètre de …"* | operand pool |
| 1000 | "Aucune limite sur ce combat" | ✅ |

Unknown rule types are inert, not fatal.

**"Catalogue only" is a resolution, not a gap.** `np_1` has two namespaces: 1–32
are rules, 900–930 are the typed OPERANDS they get composed with. A rule declares
how many it needs (`T()`); `np_1.b()` concatenates until it has them;
`je_2.a(np_1[])` applies the rule the moment it does; and `jk_1`
("coachCardFightParametersManager") pairs each bare rule with every compatible
parameter to build the picker entries (`WN`). The shipped data is exactly that
shape — 13 rule types with one instance and zero params each, against 31
parameter types whose 245 instances all carry values — so those rules are a menu
for composing a custom ruleset, and enforcing them as shipped would be enforcing
the menu. Everything that really applies arrives already parameterised, via the
challenge records. See Tier 1 item 9.

**Read `content.54.<type>` before implementing any rule** — it is the authoritative
semantics table and it is what proved 10/11 are deltas. It is a *display* table
though, and incomplete: no entry for 29, and 900–913 all render "Erreur dans
l'AGT". `ajr_2` says what a type IS; the i18n line says how to read its parameters.

**Victory conditions are arbitrated by us, not by the client.** The four `mp_2`
subclasses carry real one-line evaluators, so the *conditions* are recovered — but
`mv_1.b(mp_2)` is an **empty method**, the 3-arg evaluator has no call site
anywhere, `is_necessary`/`victory_points`/`affected_team` have no callers, and
`content.55` has no label for subtype 4. Retail decided these server-side. All
nine shipped conditions are subtype 4 with param 20 or 30 and `affected_team` 0,
held by challenge 14 and the "Défi du temps" set — survive to the turn and win.
`checkFightEnd` gained a decided-winner path so a fight can end with **both teams
standing**, and deliberately kills nobody to express that (evolution deaths key
off HP, so downing the loser would destroy fighters permanently).

### 8.21 End of fight ✅

| Item | State |
|---|:---:|
| Victory by elimination / forfeit (8151) | ✅ |
| Victory by ruleset condition (np_1 type 14) | ✅ ends the fight with both teams alive; nobody is killed to express it |
| Give-up, disconnect grace, both-absent teardown | ✅ |
| End-fight panel (8300) with 2.70 strength-map counts | ✅ |
| Ladder strength delta (±25) | 🟡 fixed delta, not full ELO |
| Token reward + live wallet push | ✅ |
| Challenge reward cards in the won-cards blob | ✅ |
| Per-fighter post-fight report (40-byte blob ×N) | ✅ |
| Evolution deaths persisted | ✅ the per-fighter death *chance* decides it (B-066); a KO is not a death (B-097) |
| **Card staking / bets** | ⬜ fights carry a bet field, nothing is wagered; the lost-cards blob is hardcoded empty |

### 8.22 Spectating & reconnect ✅

Spectate query (2260/2261) and join (26331) attach to the fight actor, remove the
spectator from the overworld, and replay the snapshot with the spectator flag.
Reconnect asks the resume question (26333/26334) and either re-attaches or
forfeits. 🟡 Timed buff icons are not restored in either path; persistent
conditions (wounds) now are (B-083).

### 8.23 Multi-fighter & 2v2

**Multiple fighters per team already works** — team building iterates the whole
roster, challenges field up to 4 opponents, and the timeline, end-check, AoE,
target conditions and post-fight reports are all N-fighter clean.

**2v2 / multi-coach is structurally blocked** (deferred by the maintainer):
`Teams` is a fixed array of 2, the ready gate hardcodes "2 coaches", each team
holds exactly one session, the fight index is one-coach-to-one-fight, and 8000
hardcodes a two-coach loop.

---

## 9. Progression & the META layer 🟡

Post-fight, per fighter, in this order — every formula transcribed from the
client's own code:

| Step | State | Detail |
|---|:---:|---|
| XP | ✅ | `base × (100 + morale) / 100`, +50 % if idle > 12 h. Morale *is* the bonus percentage |
| Gear & card-set XP modifiers | ✅ | % and flat, plus the fighter's own conditions |
| Reputation → XP conversion | ✅ | |
| Morale drift | ✅ | Including the damping toward its convergence point |
| Fatigue recovery + fight cost | ✅ | Keeps the client's integer division before the square root |
| **Wound roll** | ✅ | Upgrade on 3 light wounds / all 5 body parts / a d100 check; **3 serious wounds = permanent death** |
| **Death roll** | ✅ | injury % = totalXP/1000, death % = injury²/100 |
| Condition ageing | ✅ | Runs last so a wound taken this fight is not immediately aged |
| Banking + persistence | ✅ | 50 000 XP spend guard, morale/fatigue clamped, `LastFightAt` stamped |
| Gating | ✅ | Evolution fights always feed progression; practice and PvE challenges never do |

**Persistent conditions (wounds / blessings, type 902)** ✅ — 111 records decoded,
applied in-fight (last, after breed + equipment, with floors), applied to the
post-fight report, persisted, sent on the wire so wounds show on the portrait,
healed by consumables, and mutually exclusive per type (except the two types the
client exempts).

**Consumable coach cards (22099)** ✅ — 6 actions: heal light wounds, heal serious
wounds, change fatigue, change morale, permanent XP, apply a condition. The card
is consumed **only if something changed**, so a healing potion on a healthy
fighter is refused and kept. Resurrection is a separate gamble: the card is spent
whether or not the roll succeeds.

**Card-set bonuses** ✅ — 9 of the 13 action families are wired (XP, wound, death,
morale, fatigue, wound-cancel, reputation, resurrection, plus the "…for the
opponent" variants applied to the other team).

**The four "HONEST LIMIT" values** — deliberately named constants, each documented
as *not recoverable from the client* because the real server computed them and the
client only ever reads the result:

| Value | Current | Why it is ours |
|---|---|---|
| `baseXPPerFight` | 100 | The client receives `baseXp` pre-computed |
| Reputation per win / loss | 10 / 3 | Same — arrives pre-computed on the wire |
| "Roll d100 against each, death first" | — | The chances are client-exact; how they are *spent* is our reading |
| Condition expiry cadence | once per fight | No client code decrements the byte |

**Not implemented:**

- **Drop table (card-set actions 18–21)** ⛔ — the client exposes only the four
  modifiers, each a pure accessor the client never consumes. The pool and base
  rate are server-side and **not recoverable from the data**; building it means
  inventing the core mechanic. What *is* evidenced and could be assembled if the
  rule turns up: the draw pool is `ObtainableInDraw` weighted by `DropPercent`,
  filtered by `RequiredLevel`, paid out through the (already implemented)
  8300 won-cards blob.
- **Sphere Board** ✅ — implemented (item 29). Types 900/901 decode byte-exactly, the
  fighter's progress and owned nodes ride the fighter blob, purchases (23009) are
  re-derived server-side, and bought nodes apply their stats and spells in fight. The
  "emitted as empty lists on the wire" note this bullet used to carry was itself the
  bug B-118 fixed: those two lists are the sphere-unlocked spells and equipment pools,
  so sending them empty made a bought Spell node cease to exist on relog.
- **Achievements** ✅ — implemented. Types 800/801/802 decoded (332/5/13,
  byte-exact), the tab opens (B-105), and completion is evaluated generically and
  announced via 22000 (B-106). What remains is *statistic coverage*: the records
  reference 98 distinct counters and the server moves only a handful today, but
  each one lights its achievements up for free as the owning system starts
  counting it.
- **Coach standing persistence** ⚠️ — see §4.

---

## 10. Game modes & content 🟡

### PvE challenges 🟡

39/39 records decoded to zero residual bytes. Launch, victory recording
(idempotent criteria, first-clear-only rewards), the aggregate criterion when all
five minute demons are done, and reward cards in the end panel all work.

**Hand-built, and honestly labelled:** the **opponent rosters**. The client's
challenge table carries only presentation data (name, description, rewards, time
limit) — its loader discards everything else, so there is *no* opponent roster
anywhere in the client. Compositions were chosen to be legible (themed trios/pairs
per demon, the largest team for the gated boss). The challenge→criterion mapping
and the demon names were recovered by matching French label text; they exist
nowhere in the data files.

**Now enforced (B-074):** the nine victory conditions (np_1 type 14) — the seven
"Défi du temps" demons, their finale and challenge 14 are won by surviving to
turn 20/30 rather than by wiping the demon team — and the three type-12
fight-start effects (challenges 29/30/31: +40 % dodge for the whole fight, not
granted to summons).

**Still inert:** the `TimeChallenge` field, and six raw ints whose semantics are
explicitly unverified.

### Tournaments 🟡

Working: the calendar (17002/17003), the list (28601/28602), registration
(4607/28608) and an empty bracket (28649/28650). Three **standing** tournaments,
always open, referencing real client definition ids (chosen so registration always
completes — a fake id would crash the client).

Since done: types 1000/1001 are decoded (item 23), registrations are persisted
(B-101), and the opponent-search opcodes 28609/28611 are answered — refused
visibly with the client's own "impossible to start the search" rather than left
silent (B-100).

Missing: there is no bracket, no scheduled match, no prize table and no tournament
points. The rest of the **live-match layer** (scheduling, bracket progression,
rewards) is deferred — it needs many coaches and wall-clock scheduling.

### Ladder / ranking — 7 tabs 🟡

| Tab | Opcodes | State |
|---|---|:---:|
| 1 vs 1 | 27500/27501 | ✅ real data, paged in windows of 20, sorted by strength |
| Coach (reputation) | 27508/27509 | 🟡 valid but empty |
| 2 vs 2 | 27504/27505 | 🟡 valid but empty (no 2v2 teams) |
| Clan | 27502/27503 | 🟡 valid but empty (no guilds) |
| Tournoi | 27506/27507 | 🟡 valid but empty (no tournament points) |
| Ligue Pro | 27514/27515 | 🟡 valid but empty |
| Démon (+ drill-down) | 27512/27513, 27510/27511 | 🟡 the 24-demon roster with zeroed reputation |

All six empty boards are **well-formed** rather than stubbed — they render cleanly
instead of hanging the client.

### Evolution mode & graveyard ✅

States 0–5 (titular / bench / dead / graveyard / legendary / legendary-bench),
capacities enforced server-side to agree with the client's own refusals, one-way
graveyard exit via the resurrection gamble, and a persisted `Evolution` flag kept
**separate** from `State` (conflating them made every new evolution fighter come
back as classic — B-070).

### Matchmaking 🟡

FIFO queue keyed on mode. Search / cancel / accept, plus the "Combattre" ready-room
path that bypasses the accept handshake. **Rating band** ✅ (B-082): coaches pair
only within a strength gap that widens the longer either has waited
(`world.match_band` 300, `match_band_growth` 150/s, 0 disables). The widening is
what replaces a queue timeout — the requirement relaxes until somebody qualifies,
so a lone high-rated coach ends up matched instead of dropped. The numbers are
ours; matchmaking is invisible to the client. The accept message's roster, mode,
opponent id and bet are still decoded and discarded.

### Direct challenges 🟡

1v1 training challenge works end to end (invite, accept, decline, cancel,
withdraw, team-confirm). The **X-vs-X-with-allies variant (26313/26314) is not
implemented**.

---

## 11. Operations, packaging & distribution ✅

| Item | State | Detail |
|---|:---:|---|
| Self-writing config | ✅ | Fully commented template embedded and written on first run, race-safe, never overwrites operator edits |
| Config documentation guard | ✅ | A reflection test **fails CI if a `Config` field has no key in the template** |
| Env overrides | 🟡 | 14 keys; 3 fields have no override and that drift is unguarded |
| Game-data discovery | ✅ | Walks configured → exe-relative → cwd → per-OS install locations, and will combine halves found in *different* roots |
| Bundled server data | ✅ | `server/data-dist/` (~2.5 MB, records only) ships in git, every release archive and the Docker image — zero setup for fights |
| Web portal | OK | Full account site, no JS, no external assets, all embedded. Landing / public status / public ladder / sign-in / sign-up; account area showing every stored datum; admin console (search, deep view, create, delete, grant-admin, impersonate) + in-process pprof. HMAC sessions, CSRF, two rate limiters, script-free CSP. **TLS still left to a reverse proxy** |
| Update check | ✅ | One anonymous GET at startup, notify-only, silent on every failure, skipped on dev builds |
| CI | 🟡 | Build/vet/test on Linux **and** Windows, gofmt, `go mod tidy` check, 5-target cross-compile. **No `-race` job, no linter, no coverage, no vulnerability scan, no frontend build** |
| Releases | ✅ | Conventional Commits → release-please → GoReleaser, 5 targets + checksums, data + docs bundled |
| Docker | 🟡 | Multi-stage, non-root, 3 compose files (sqlite/postgres/mysql). **No image is published by CI**, no healthcheck |
| Deployment guides | 🟡 | Compose + env table. No systemd unit, no Kubernetes, no TLS/reverse-proxy example, no backup guidance |
| Load testing | ✅ | `cmd/loadtest` ramps N bots; ~2000 concurrent coaches on one instance (~170 MB) |

**Open, non-blocking:** Windows SmartScreen warns on the unsigned `.exe` (real fix
is a signing certificate or SignPath); no published Docker image.

---

## 12. RE tooling & documentation 🟡

| Item | State | Detail |
|---|:---:|---|
| Live-client MCP harness | ✅ | 12 MCP tools boot server + retail client with a Java agent injected, drive synthetic input on the GLCanvas, screenshot off-screen, read client model state by reflection, tail both logs, inject raw frames |
| Harness limits | 🟡 | Hard-coded paths, Windows-only, needs the 436 MB client tree, `/type` mangles non-ASCII before any protocol code runs, and **packet-injected fights render no HUD** (the client only arms it when *it* initiates) |
| Protocol analysis | ✅ | Framing spec, variable-length message layouts, the self-describing part-table container, `.bdat` byte format, 348-row opcode map |
| **Studio** (Wails desktop app) | 🟡 | **Read-only** by design (the 2.70 data layer has no encoder). 8 working views: data catalogs, jar/asset browsing, TGA decoding, map `.fmd` + topology parsing, composited map rendering with pan/zoom, bulk sprite export. 8 orphan nav strings inherited from the v2.04 tool. Excluded from Linux CI and from releases (needs CGO + GTK/WebKit) |
| **Deobfuscation lab** | 🟡 | Class layer done (4911 classes remapped, **472 semantically named**), field layer done (**892 fields**). **Open: method renaming, real package structure, full recompile.** Only 137 of the names are fact-backed; the rest are descriptive guesses |
| Game wiki | ✅ | 12 breeds × ~10 spells each, mechanics pages, rules pages |
| Bug log | ✅ | Every fix with symptom, root cause (naming the client class that proves it), and verification |

---

## 13. What's left — prioritised backlog

### Tier 0 — correctness & anti-cheat ✅ COMPLETE (B-075 … B-078)

1. ~~**Placement phase has no guard at all**~~ — **done (B-075)**. Gated to the
   placement phase, and the cell must be one of the fighter's own side's start
   cells and free.
2. ~~**Spell casts do not check spell ownership**~~ — **done (B-075)**. The
   caster must own the spell (`Fighter.Spells`) or be a server-driven fighter
   casting its `SummonSpellID` — the latter matters, because challenge demons
   carry an empty spell list and would otherwise have been muted.
3. ~~**Forced displacement does not trigger walk-on traps**~~ — **done (B-076)**.
   All five paths now run the enter check. It also recovered the full trigger
   enum: 10002 (left), 10008 (stayed inside), 10003 and 10006 remain
   unimplemented — see §8.14.
4. ~~**Dispel strips infinite states**~~ — **done (B-077)**. Permanent states now
   survive, matching the buff loop and `tickStates`. The general fix — the
   client reference-counts properties (`Kt.g`/`h`), so overlapping sources
   compose — is recorded in §8.12 as a follow-up.
5. ~~**`Coach.Standing` is never persisted or transmitted**~~ — **done (B-077)**.
   It was dropped in three places: `CoachRepo.Save`'s field map, the 2052
   descriptor and the 4096 actor record. No wire layout changed; both sites
   already wrote an i32 and simply wrote zero into it.
6. ~~Rooted fighters get their MP gauge refilled; petrified fighters do not have
   AP/MP zeroed~~ — **done (B-078)**. `effectiveAP`/`effectiveMP` mirror the
   client's `gn_0.d`. Not cosmetic: MP-scaled damage reads this value, so a
   rooted caster's spell now correctly deals nothing.
7. ~~`Writer.StringU8` does not enforce the 127-byte limit~~ — **done (B-078)**.
   It was a remote client-crash vector, not a style rule: chat echoes an
   attacker-supplied channel *name* through it.

**Tier 0 is complete.**

### Tier 1 — cheap concrete wins (**COMPLETE**: B-079…B-083 built; four resolved by evidence)

8. ~~**Zone-effect action ids 165 / 166 / 169**~~ — **done (B-079)**, plus 167 and
   168, which the roadmap had missed: `mh_2` shows the family is six members of
   one shape. Effect-row coverage 502→505 of 533 (94.2 %→94.7 %).
9. ~~**Enforce the remaining np_1 rules.**~~ — **resolved: there is nothing to
   enforce.** The operand question is answered, and the answer is that those
   entries are a **catalogue**, not rules.
   The client splits `np_1` into two namespaces, and the `ajr_2` enum names them:
   **1–32 are RULES** ("Modifie le budget", "Sort interdit", "Choisir une
   arène"), **900–930 are PARAMETERS** — every one literally *"Paramètre de …"*
   (de classe, d'id d'arène, de nombre de combattant, de temps…).
   A rule declares how many operands it needs (`np_1.T()`); a parameter carries a
   value and needs none (`aIE`, the only subclass with `sp()` true, and its type
   id is dynamic). `np_1.b(a,b)` **concatenates** a's params with b's until
   `rg().length >= T()`, and `je_2.a(np_1[])` walks the array accumulating
   exactly that way, applying a rule the moment it has enough operands. `jk_1` —
   which registers itself as **"coachCardFightParametersManager"** — pairs each
   under-parameterised rule with every compatible parameter to build the
   selectable combinations (`WN`, whose fields are `selected` / `description` /
   `activated` / `forbidden`: a picker UI).
   The shipped data matches exactly: **13 rule types, one instance each, zero
   params; 31 parameter types, 245 instances, every one carrying a value** — and
   the counts are self-evidently a catalogue (900 *classe* = 14 breeds, 901–912/
   929/930 *sort de \<breed\>* = 10 each because every breed has 10 spells, 927
   *id d'arène* = 27).
   So these were never configured rules and enforcing them as shipped would be
   enforcing a menu. Rules that actually apply arrive **already parameterised**,
   from the challenge records (types 10/12/13/14 — all wired). The work only
   becomes real if custom rulesets / tournaments are implemented, at which point
   the client's picker sends (rule + parameter) pairs. Pinned by
   `TestNp1RuleCatalogueShape`, which fails the moment a rule ships WITH
   operands.
10. ~~**np_1 type 14 victory conditions**~~ — **done (B-074)**. Subtype 4
    ("reach turn N") covers all 9 shipped conditions. Subtypes 1/2/3 remain
    decoded-but-unimplemented: no shipped record uses them, so there would be
    nothing to validate an implementation against.
11. [x] **Buff icons on reconnect/spectate** — **partly done (B-083), and the
    premise was half wrong.** The CREATE_FIGHT fighter blob's two id lists are
    *not* both buff channels: the first resolves through `akp_1`, the **sphere
    board** registry (`dq_1` → `contentLoader.sphereBoard`), and the client
    **re-applies** the matching node's effects — so writing buff ids there would
    apply unrelated sphere effects, not draw icons. It stays empty until the
    Sphere Board exists. The second list *is* the persistent conditions (type
    902) and is now sent, so wounds survive a reconnect or spectate. Timed spell
    buffs still have no slot in this message; restoring those needs the
    per-effect message the client uses during normal play.

    **Which message that is, is now settled — and the obvious choice is the wrong
    one.** 8120 (`amb_0`) is not a render channel: `of_1` case 8120 builds an
    `mv_0` and either `run()`s it immediately or queues it on the effect scheduler,
    so replaying a fighter's buffs through it on reconnect would **re-apply** every
    one of them — doubling stat changes client-side, exactly the way writing buff
    ids into the sphere-board list would have re-applied sphere nodes.

    The right channel is **8121** (`rq_2`, currently Inactive): case 8121 builds
    the effect, attaches it to the target's buff container (`zT.ajR().PJ().o(zT)`)
    and raises `"hasBuff"` — it attaches without executing. So the remaining work
    is to emit 8121 per active buff after CREATE_FIGHT on a reconnect or spectate
    join. The server already holds everything needed (`activeBuff`: actionID,
    effectID, resource, delta, turnsLeft, infinite, statBuff).

    **DONE.** `resyncBuffs` re-attaches every live buff from `sendFightResync`, so
    a reconnecting player or a joining spectator now sees the icons the fighters
    are actually carrying.

    ```
    8121 = [i32 mh_2 actionId][i16 blobLen][blob][i64 fighterId][i16 expiry][i8 flag]
    ```

    The blob is the **same six-part encoding as 8120** — factored out as
    `buildEffectBlob` so the two cannot drift — and the target rides inside it:
    `zT.ajR()` must resolve or the attach is skipped in silence.

    The trap was `akv_0`'s middle field. It is **not** a remaining turn count but an
    **absolute expiry mark** against that fighter's own timeline counter: `aGT`
    builds it as `alh_1.aAy() + duration` and reads what is left back as
    `expiry - aAy()`. Sending the remaining count — the obvious choice, and exactly
    what the server stores — would have made every restored buff read as already
    expired on any fighter that had taken a turn. Negative means infinite
    (`akv_0.isInfinite()` is `NC < 0`). `FightFighter.turnsTaken` mirrors `aAy()`,
    bumped in `beginTurn` where the client bumps its own.

    No removal message is needed: because the expiry is absolute, the **client ages
    the buff itself**. That also sidesteps 8122 (`zq_1`, `[i64 buffId][i64
    fighterId]`), which the server could not drive anyway — buff ids come from the
    client-local counter `ahT()`, so the server never sees them. Same shape as
    item 14's 5203 uids.
12. ~~**Buff stacking rules** — merge / refresh / cap instead of blind append.~~ —
    **withdrawn: the premise is false, and acting on it would have introduced a
    resource leak.** The client stacks. Buffs are filed in the per-fighter
    registry `alf_1` under `xb_2.je()`, assigned from the **monotonic counter**
    `ahT()` because the pluggable key strategy `aes_2` has no implementor in the
    client — so two casts can never collide, the duplicate guard never fires, and
    the only removal helpers are bulk by-source. Blind append is what the client
    expects. The abuse the item worried about is already bounded by **cast
    frequency** (cooldown / max-per-turn / max-per-target) and resource clamping;
    bonus-cell buffs cannot be farmed either, since they fire only at turn start
    and revert at turn end. Implementing the requested merge and running the new
    test showed the trap concretely: it tracks one buff after applying two
    deltas, permanently leaking the second one on revert. Locked in by
    `TestBuffsStackAndExpireIndependently` (mutation-verified). See §8.12 — the
    *states* store `Kt` genuinely is refcounted, and that gap remains open.
13. ~~**Initiative buffs should re-sort the timeline.**~~ — **withdrawn: the
    premise is false.** No shipped spell uses action 76/77 (0 of 533 effect
    rows), the client's timeline interface has no comparator or sort, and no
    wire message reorders it. See §8.2. Gear initiative already works.
14. ⛔ **5203 destructive/lock inventory ops** - **IMPOSSIBLE on this wire, not
    unbuilt. Verified end-to-end and now CI-enforced.** The premise was wrong
    twice, so the evidence is spelled out.

    **It is not "remove/lock".** `sj_1.yG` builds the frame from the cards that
    were in the client's reference set but are no longer in its current inventory
    view, and sends it right after the 5201 equipment layout. So it is a
    **removal notice** with no action discriminator anywhere in the payload -
    there is no lock, and `CardLocked` would never have had a writer.

    **Its uids cannot be resolved.** `eb_1.b(ByteBuffer)` reads only the i32
    reference-card id, and then does `this.aFL = uq_1.ahR()` UNCONDITIONALLY.
    `uq_1.ahR()` is a client-local monotonic counter (`bRK + (bRI & 0xFFFFFF)`,
    incrementing on every call). The server has never seen that number and
    cannot map it to a `CoachCard` row. A server-supplied uid would be discarded
    even if we added a field for it - and adding one would break the sacred wire
    regardless. There is no fallback route: `fh_0.encode()` writes
    `[i16 count][i64 uid x count]` and nothing else, so there is no template id
    to reconcile against. Acting on the frame would mean guessing which card to
    destroy, against an inventory that can hold several copies of the same
    reference card - the one case where guessing wrong is unrecoverable for the
    player.

    **Current handling is the correct end state, not a stopgap:** accept the
    frame, re-push the inventory, act destructively on nothing.

    `TestCardUIDsAreClientLocal` pins all of it against the decompiled client
    (uid assigned from the local counter, counter increments, 5203 carries only
    those uids). Each assertion was mutation-verified. If one ever fails, the
    wire changed or the reading was wrong and this item deserves a fresh look -
    do not adjust the test to make it pass.
15. ~~**AoE shape 8 (point-list)** and the asymmetric 2-/4-param crosses.~~ —
    **done (B-080)**. Shape 8 is directional (the client's symmetry flag `fi()`
    is false for it, as for the T shapes); the cross accepts 1/2/4 arm lengths
    and is *not* directional (`fi()` true). Only the 1-param cross and one
    shape-8 row occur in shipped data, so the cross work is forward safety —
    but it replaces an approximation that would have been silently wrong.
16. ~~**Matchmaking rating band + queue timeout.**~~ — **done (B-082)**. A band
    that widens with waiting (`world.match_band` / `match_band_growth`, 0
    disables). The widening *replaces* the timeout: relaxing the requirement
    ends the search in a match rather than in a give-up, which matters on a
    server with few players online.
17. [x] **Spell `TargetMasks`** — **done (B-081)**. **`MaxActive`** is
    decoded-not-enforced **on purpose**: the scope question that blocked it is
    answered, it needs no wire work, and it turns out it cannot change an outcome
    in the shipped data. 6 spells carry it (8, 15, 46, 141, 167, 173 — buff
    spells, not summons). The mechanism, from `sH` (the per-fighter cast-history
    tracker, `gn_0.baS`, reachable via `PN()`):
    - The counter is `sH.akV`, a map **keyed by spell id**, with `d()`
      incrementing, `e()` decrementing and deleting at zero, and `c()` doing the
      check — it rejects the cast once `count >= iT()` (record field 8).
    - **Scope is PER TARGET, not per caster.** `mv_1.a(caster, spell, target)`
      runs the cooldown / per-turn / per-target checks on the *caster's* `sH`
      (`sH2 = gn_02.PN()`) but calls the max-active check on `gn_03.PN().c()` —
      and `gn_03` is proven to be the target by the very next line, which passes
      it as the `aOf` of the per-target-cap check.
    - It **survives turn boundaries**: `sH.yB()` clears the per-turn buckets
      `akT`/`akU` and deliberately leaves `akV` alone.
    - **No server message is involved.** The decrement is driven by `amt_2`,
      which looks like a packet (it extends `yd_2`) but has `TI()` returning 0
      and *empty* `A(ByteBuffer)` / `c(ahh_0, ByteBuffer)` bodies, and appears in
      no opcode table: it is a purely client-local timeline event.
    So this is a pure server-side legality rule, and it is also **the real
    stacking cap** — the client never merges buffs (see §8.12), it refuses the
    cast once a target already carries `iT()` live copies.
    **Resolved: deliberately NOT enforced, because in the shipped data it cannot
    change an outcome.** The decay window is **one turn** — `mv_1` schedules the
    decrement with `arm_0.lQ(1)`, a literal, and the very next line schedules a
    different event with `arm_0.lQ(fv2.et())`, a spell-derived duration, so the
    literal is deliberate. A counter that resets every turn is exactly the
    granularity `CastMaxPerTarget` already has — and every shipped MaxActive
    spell is already capped at least as tightly by a limit we DO enforce: five of
    six have `CastMaxPerTarget == MaxActive` (15, 46, 141, 167, 173) and the
    sixth (spell 8) is a range-0 self-cast already limited to one cast per turn.
    Enforcing it would add a second, subtly different gate that changes no legal
    cast, while a wrong window would *reject* casts the client believes are
    legal. Pinned by `TestMaxActiveIsRedundantInShippedData`, which fails the
    moment a spell's MaxActive binds tighter than the limits we enforce.

### Tier 2 — real features

18. [x] **AI depth** - **CLOSED: correct, honest and competent.** What remains is
    how STRONG the AI should be, which is a balance dial rather than a defect -
    see the closing note at the end of this item. **Done:** multiple
    spells per fighter (a repertoire, re-picked before every cast), challenge
    demons carrying a real breed loadout (1 spell -> typically 3-4), positioning
    via the real targeting validator instead of a bare distance window,
    **close combat with leftover AP** (a spell-less fighter used to do nothing
    whatsoever), and two guards that the repertoire itself made necessary —
    never aiming a support spell at an enemy (B-084) and never splashing its own
    team with an area spell (B-085), one shared castability predicate so
    positioning and casting cannot disagree and freeze the fighter (B-086), and
    not walking onto Killer tiles. Since then: healing a dying ally, AP-efficient
    casting, killable-target selection, safer firing cells, and an explicit
    knowledge model. Never added (difficulty, not defects): summoning, placing
    traps, cooperative focus-fire, diagonal pathfinding, difficulty tiers.
    **Audit (no defect found).** The AI now has 18 tests covering the failure
    modes that actually bite: freezing when the only in-range spell is
    uncastable, friendly-fire splash, self-nuke, walking onto killer or
    destroyed cells, close combat with leftover AP, and multi-spell turns.
    `TestAINeverEndsTurnWithUsableAP` adds the general property - after the AI
    finishes, no spell in its repertoire may still be affordable AND castable -
    across five cost combinations chosen to leave awkward remainders. It passes,
    and a one-cast-per-turn mutant fails it, so it is not vacuous.

    **Fairness is now structural, not remembered.** `ai_knowledge.go` is the one
    place the AI is allowed to learn anything about the battlefield, and each
    function states what a human would see. Arena special cells are map features
    (known); effect areas placed by the fighter's OWN team are known; **enemy
    traps are not**. A server-side AI is reasoning over the same structs that
    hold every hidden thing, so omniscience is the DEFAULT and honesty is what
    needs enforcing - `TestAIDoesNotSeeEnemyTraps` asserts the AI treats an enemy
    trap as safe, which reads backwards until you remember that a human would
    walk into it too. A mutation making the AI see every trap is caught.

    **Targeting now plays like a person**: finish something if you can, else press
    whatever is closest to dying, else hit the nearest. Damage is estimated
    through the real elemental damage/resistance maths, so "can I finish this
    one" means something when resistances differ - and the AI stops firing into
    a resistance when a weaker element would do more. Deliberately shallow: one
    pass over living visible enemies, no lookahead, no movement search. That is
    both fast (tiny sets) and the depth a human actually plays at.

    **Spell targeting was already correct, and is now complete.** The AI could
    never aim a support spell at an enemy (`aiSpellCastableFrom` gates every
    candidate on `aiSpellHarmsEnemy`) and never splashes its own team with the
    harmful half of an area spell (`aiWouldHitOwnTeam`, strict: any friendly
    splash disqualifies). Both were already pinned by tests. What was missing was
    the other direction - because the attack path requires "harms an enemy",
    support spells were filtered out and never cast AT ALL, so the AI never
    healed a dying teammate. `aiSupportCast` fills that, ally-only, with the
    threshold and overheal cap that stop it topping up scratches.

    **Heals only, deliberately.** A heal's value is readable from the data: the
    effect rolls an amount and the useful part is bounded by the ally's missing
    HP, so "was that worth an action" is answerable. A buff's is not - nothing in
    the record says what +damage% for 3 turns is worth against spending the same
    AP attacking now. Buffs stay unused until there is a basis for valuing them
    rather than a guess.

    **On the target masks.** `TargetMasks` (field 22) is present on 202 of 203
    spells but `EnforceTargetMasks` (field 19) is set on only 3 - the retail
    client applies the cast-level check for those three alone. So the mask is
    good evidence of INTENT and cannot be used as a hard gate; the per-effect
    `Effect.Targets` mask is the enforceable one and already filters areas.

    **Tactics (closing pass).** Three things a person does without thinking, now
    done: AP is spent by damage-per-AP rather than raw damage (with 6 AP a
    2-AP/30 spell beats a 4-AP/40 one - 90 vs 70 over the turn) EXCEPT when a
    spell finishes the target, because a dead enemy stops attacking; the fighter
    prefers a firing cell that is not next to an enemy when one scores equally;
    and a known friendly trap makes a cell less attractive without ever making it
    unreachable, since a player steps on their own trap rather than refusing to
    move.

    That last distinction is the shape of the whole knowledge model: LETHAL
    hazards veto a cell, KNOWN-damaging ones only cost it points, and enemy traps
    do neither because the AI cannot see them.

    **A duplication worth remembering:** the spell ranking existed in two copies,
    one used to pick the TARGET and one to pick the CAST. The efficiency work
    landed in the first, so the AI valued targets by the new rule and still spent
    greedily. Reading the code missed it twice; a test measuring damage-per-turn
    caught it immediately. `chooseAISpell` now delegates to `bestSpellAgainst` so
    there is exactly one ranking.

    **Naming trap (documented in place):** `FightFighter.SummonSpellID` is the
    AI's SIGNATURE spell, not just a summon's. Challenge demons set it from
    `pickBreedSpell` precisely because a fighter with 0 there is classified a
    blocker and never casts at all - its `Fighter.Spells` are never reached.

    **What is left is the DIFFICULTY DIAL, not defects.** The three items this
    note used to list as outstanding - AP efficiency, target selection and
    positioning - are all done. What could still be added (deeper lookahead,
    coordinating focus-fire between several AI fighters, spending a turn
    repositioning for a better next turn) would make the AI HARDER TO BEAT,
    which is a balance choice for the operator rather than a bug to fix. The AI
    is now correct (never mis-targets), honest (cannot see enemy traps or its
    own future rolls) and competent (kills what it can reach, spends its AP
    well, heals a dying teammate, and does not stand next to people for no
    reason). That is the bar this item was opened to clear.
19. [x] **Coach action cards in fight** — **CLOSED: correct and complete as an
    empty deck.** The "no opcode" premise was wrong, and
    the id-namespace half is now FIXED (B-088).** The deck is exposed to the UI as
    the field **`"coachSpellInventory"`** (`Te.bMP`), a list of `yp_2`
    **castables**, and selecting a `yp_2` sends **8109 SpellCastRequestMessage**
    via `alx_2` carrying `yp_2.getId()`. So playing a coach card is an ordinary
    spell cast.
    The catch: both `aez_0` and `Te` build that container as
    `new ajO(je_1.Wa(), 8)`, and `je_1 extends azk`, whose `E(ByteBuffer)` reads
    an `i32` and resolves it against the castable map `apS` fills from the
    **spell** records (type 220) keyed by SPELL id. We emit **CoachCard template
    ids**, and only 65 of the 325 `HasUsableAction` cards share an id with a
    spell — the rest would be dropped with *"impossible d'ajouter l'item"*.
    We now emit spell ids only, filtered so an unresolvable id can never be sent
    and capped at the client's own capacity of 8; the deck is EMPTY today, which is
    the correct output because nothing grants a coach an action spell.
    Cards and spells are **separate registries** — `eh_2` loads type-100 records
    into `la_0.XJ()` as `xj`, `apS` loads type-220 into `je_1.Wa()` as `yp_2` —
    so a card id in that blob can only ever miss.
    **Closed: nothing populates it in this build.** `np_1` type 27 (*"Ajouter un
    sort de coach"*) appears on no card; `azk.h()`/`i()` (the breed-99/98 buckets)
    and `azk.aLO()` (a random draw of 3 from them) have **no callers at all**; and
    the card record carries no spell reference — its last field is the colour
    palette index. So the empty deck is complete and correct, not a stub. Also
    ruled out: `zd_2`
    (the Masqueraider mask picker — only the 5 parented spells 471/472/473→462,
    474/475→452), `aJt.Qx()` (a SUMMON's spells — `ta_0` says *"SummonedFighter"*),
    and `agp` (np_1 **type 12**, the fight-start effect, already implemented).
    See BUGS.md *"Coach action deck — nothing populates it in the 2.70 build"*
    for the full elimination trail.
20. [x] ~~**Card staking / bets** on a fight.~~ — **closed: vestigial in 2.70,**
    **nothing to implement.** The whole flow is absent from the shipped client.
    The only bet control, a `%randomFight.withBet%` checkbox in
    `randomFightCreationDialog.xml`, is **commented out with the reason in the
    file**: `<!--plus de pari-->`. The padlock UI the `desc.LockCard` /
    `desc.Unlock` / `desc.NotEnoughCards` strings belong to survives only as
    an orphaned theme skin (`checkboxCoachInventoryBigLock`) used by no dialog;
    those keys, and `fight.bet`, are referenced by **neither core.jar nor
    gui.jar** (verified by scanning the shipped jars' constant pools and every
    gui entry, not just the decompiled tree). None of the 134 C2S message classes
    carries a wager or a staked-card list.

    The **won**-cards half of END_FIGHT is emphatically not vestigial and is
    already implemented: 2.70 reuses it for challenge reward cards, and the
    client renders it. Only the `lostCards` slot is dead — it reaches the
    client's property store but no widget binds it, so `writeCardBlob(w, nil)`
    stays correct.

    This investigation is what turned up B-095 (the fight kind was in the wrong
    wire slot), which was a real bug hiding behind the "bet" field next to it.
21. [x] **Evolution per-fighter death chance** — DONE, but the premise was
    backwards. The chance was already modelled (B-066: `death%` =
    `(totalXp/1000)²/100`, plus the 3-serious-wounds escalation). What was
    actually wrong is that an **invented** `HP <= 0 → dead` override ran instead
    of it, killing every downed fighter and pre-empting the roll for exactly the
    fighters it mattered for. The client is unambiguous that a KO is not a
    permanent death — `fightEndAchievementDeathDescriptionFailed` ("pas de
    **mort définitive**") would be unreachable after a win otherwise. Fixed by
    deletion (B-097), which also uncovered a second bug behind it: the roster
    refresh was gated on a *downed* fighter existing, so a roll-death never
    reached the client until relog.

    **Verified live**, once B-098 made the mode reachable: a real evolution fight
    won by wiping the opposing team reported `killed=0`, and the client's own
    achievement panel said *"Hélas, vous n'avez pas occasionné de mort définitive
    chez les combattants adverses"* — the exact string quoted as evidence for the
    fix, shown in exactly the situation the old rule made impossible.
22. [x] **Fusion** — **built; the only thing still open is a number the client
    cannot tell us.** There is no recipe table; type 1100 is the ALTARS. Decoded
    (4/4 fields: power / quality / slots): 30 tiered altars. The mechanic is a
    power check against a **player-chosen target**, and the client's own panel
    gives the formula (kardsPower = Σ inputs' RequiredLevel − target's
    FusionPower). B-089 fixed the wire bug this exposed — the 5490 payload's
    LAST id is that target, which the server had been consuming as fuel — so the
    outcome is now the chosen card and a failed roll names it. The **altar** is
    resolved by position too — the six in-world altars are six tiers (lab ids 2-7,
    slots 2-5), which the client reads from each element's descriptor and we
    already carried as `worldElement.arg`. **Still open:** the success
    probability curve, which no client code reveals.
23. [x] **Tournament definitions + management** — DONE. Types 1000/1001 are
    decoded (22 definitions, field names taken from the client's own property
    strings: `qo()` = tournamentInscriptionCard, `aHi()` = tournamentRewards,
    `aHh()` = the team type branched on in `agz_1` against `aql_0`).

    The standing line-up is no longer a compiled-in Go table: it lives in
    `domain.Tournament` and is **edited from the web admin console** — create,
    edit, reorder, hide, delete — with a fresh database seeded with the three
    that used to be hard-coded, so nothing changes for an existing install.
    Changing the line-up no longer needs a rebuild.

    The dangerous part is guarded rather than documented: a definition id the
    client does not have NPEs it outright (`LS.Yf().gG(defId)` is
    dereferenced unguarded), and one with a non-zero inscription card can never
    complete registration here. Both are validated against the decoded
    catalogue on save, and the picker only offers definitions that satisfy them.

    Verified live: a tournament created in the browser reached a connected
    retail client (3 → 4), hiding one took it away again (→ 3), and the
    client logged no decode errors throughout.

    Registrations are now persisted and restored on boot (B-101) — they used to
    be process-lived, so every restart silently un-registered everybody. The
    opponent-search opcodes 28609/28611 are answered too, refusing visibly rather
    than going silent (B-100).

    Still deferred: brackets, scheduled fights and rewards — i.e. turning that
    refusal into a real fixture. See item 32.
24. [x] **Interactive elements from data** — DONE. The env jars were added to
    `data-dist` (maintainer decision, all 114), and the table is now
    **generated** from them by `cmd/genelements` into
    `internal/game/elements_data.go` instead of being transcribed by hand.

    Generated rather than read at runtime on purpose: the server keeps no startup
    dependency on map data for "what can the player click", the table stays
    reviewable in git, and every consumer keeps taking stable pointers into it.

    **It reproduced the hand table 139/139** on instance id, kind, cell, payload
    bytes, and the Card Master / Fusion altar descriptor arguments — and found a
    real bug doing it: world 28's Card Master had a **direction byte typed 03
    where the jar says 01**, which had been going onto the wire on every spawn.

    **The arrival altitude was the hard part, and two hypotheses were wrong before
    the right one.** The env element's own authored z is NOT it (that is the
    Zaap platform's height), and neither is the highest walkable tplg layer. It is
    the **LOWEST** walkable layer. Only one Zaap in retail data distinguishes them
    — world 25's, the login spawn, whose cell has floors at 8 and 30 — and the
    live client settled it: spawning at 30 rendered no coach at all. The earlier
    note claiming the hand-typed 8 was a transcription error was itself wrong; 8
    was right, and `elements_golden_test.go` now says so.

    Also fixed on the way: the topology reader silently dropped tile kinds 0 and 1
    (a size guard assumed type 0 "carries no per-cell data" — it carries a uniform
    altitude for all 324 cells — and type 1 was unhandled). They are most of the
    overworld. Added under an explicit `topoScope`, so **arena decoding is
    deliberately unchanged**: admitting those chunks widens an arena's bounding box
    without adding a playable cell, and arena bounds feed placement, movement
    clamping and sudden death.

    Still authored, and correctly so: which 11 of the 114 worlds to serve (110/113
    have env layers but no elements and would strand a player; 111/112 are
    staff-only), and the `zaapCardDest` routing.

    <details><summary>Superseded investigation notes</summary>

    Investigated before starting, which changed the shape of it:

    - **Type 360 is a sprite table, not the element table.** 42 fixed 19-byte
      records of `{id, type, gfx, colour, height, unused}`, loaded by `nh_2`
      ("Loading N interactive elements **views**"). Three of its five live fields
      are constant across all 42 rows, the sixth has no reader anywhere, and it
      carries **no instanceId, world, cell, descriptor or behaviour**. The server
      renders nothing, so it has zero server-side value. Now decoded anyway, with
      a real-data test that pins those constants so nobody re-chases it as the
      missing element table.
    - **Everything the server needs is in `maps/env/<world>.jar`** (`ru_2`/`aEG`:
      instanceId, env type, view ids, and the opcode-200 payload verbatim), with
      cell/descriptor inside that payload's part table.
    - **It is reproducible.** A structural scan of the 11 populated worlds'
      env jars matched today's hand table **139/139** on instanceId sets and
      **0/139** kind mismatches, with per-kind counts equal across all 15 types,
      and spot-checked payload blobs found byte-for-byte in the jars. So the
      correctness gate for this work already has a known answer.
    - **`alt` is the catch, and it is not in the env jars.** The env `RU` z is
      *decoration* height; the 4600 `alt` must be the tplg walkable ground, and
      **20 of 139 differ** — including the login-spawn Zaap (env 30 vs the correct
      8). Getting it from data means teaching the tplg reader about overworld
      worlds (today it only loads worlds that have an arena `.fmd`). A wrong `alt`
      silently freezes the coach, so this is the risky half.
    - **Policy stays hand-made regardless:** which of the 114 shipped env worlds
      to populate (we deliberately spawn 11; 110/113 have env but no elements and
      would strand a player), which Zaap is primary, and the `zaapCardDest`
      routing.

    The `data-dist` question that blocked this was answered: all 114 env jars are
    committed (+0.49 MB, taking the curated set to ~3 MB), with `DISCLAIMER.md` and
    `NOTICE` updated to say what they contain (ids, positions, descriptors - no
    sprites). CI needs them, because the gate tests read them.

    </details>
25. [x] **Channel scoping** — DONE, and the item as written was wrong twice over.
    Investigated before implementing:

    - **The membership family (3128/3130/3132/3134/3136/3138) is dead code.** All
      six handlers in the client's `om_0` cast the message and `return false`.
      There is no C2S counterpart — not even in the 2007 reference, where channel
      membership was always driven from outside the game client — no UI, and
      nothing gated on them. Implementing them is *provably* unobservable.
      **Closed as won't-do.**
    - **The premise that channel chat works and merely lacks scoping is false.**
      The client cannot send 3151 at all (`ChannelContentCommand` is referenced by
      nothing in any shipped jar), and the 3140 we send routes to pipe 3, which
      `du_1` never registers — so `ql_1.a` dereferences null and the line is
      swallowed by the frame loop's catch. Our `handleChannelMessage` has been
      talking to nobody. It stays as protocol preservation, correctly labelled.

    **What was actually broken, and is now fixed:** the client offers four chat
    pipes and we served two. `/t` **Trade** sent opcode 3159 and the server logged
    `unhandled opcode` and dropped it — while the client printed the player's own
    line locally, so it looked sent and silently never arrived (B-103). Trade is
    global, needs no subsystem that does not exist, and is now delivered.

    The other two are genuinely blocked, not skipped: `/c` **Clan** (3199) is
    guild-scoped and the client self-gates — with no guild it emits *no packet at
    all*, confirmed live — so it cannot even be exercised before item 31. `/p`
    **Group** (3161) targets the ally coach on your side of a live fight, read out
    of CREATE_FIGHT's coach list, so it needed 2v2 - which is now done (item 30).

    **All four live pipes are now served**, and the two that cannot yet reach an
    audience are served *correctly* rather than skipped: `/p` resolves its
    audience from the sender's own fight instead of the client-supplied coach id
    (trusting that id would turn it into an unfilterable DM channel that bypasses
    the ignore list), and `/c` re-validates the client-supplied guild id against
    the sender's actual guild. Both gain an audience the moment items 30/31 land,
    with no protocol work left.

    **Chat safety was added to match the client (B-104).** Reading the client's
    own limits first found a gap that is not just missing enforcement: private
    messages have **no ignore filter client-side** and force-open the chat window,
    so an ignored player could pop a victim's UI at will. Server-side filtering,
    `<`/`>` stripping (the renderer parses markup and escapes nothing), the
    client's 30 s Trade cooldown and its 5 s anti-repeat are all enforced now.

    Also identified in passing: 3159/3161/3168/3170/3198/3199 were all listed as
    "unidentified" in `OPCODE-INVENTORY.md` and now carry their layouts.
26. [x] **Achievements** — DONE. Types 800/801/802 decoded (332/5/13, byte-exact
    over every record), the tab opens (B-105), and unlocks are evaluated and
    announced via 22000 (B-106). Live-verified: entering the world announced two
    achievements with the client's own "Exploit débloqué" toast, and a restart +
    relog announced nothing again.

    Completion is **generic** — every statistic condition met and every listed
    card owned — so there is no per-achievement code, and there is **no reward**
    to grant (points are cosmetic; the record's one spare i32 has no consumer
    anywhere in the client). Unlocks matter as *keys*: zone triggers, challenge
    gating and the island Zaap dialog test them.

    The **tome** ("grimoire") is implemented properly rather than approximated: a
    grow-only table, folded in from the inventory at login and on every inventory
    push, and emitted in the 2052 descriptor's `0x80` blob (which had been
    hard-coded empty and mislabelled "betCards"). Selling a card therefore cannot
    revoke the achievements it completed, matching the client's own set, which
    never shrinks.

    **What is left is not an achievement task.** The 332 records reference 98
    distinct statistic ids (`or_0` documents each in French) and the server moves
    only a handful today — challenge completions, the narrative flags the client
    reports via 22003, and the Zaap seed. The rest are numbers owned by other
    systems ("damage dealt in one turn", "consecutive wins in evolution", "biggest
    Iop used for a won fight"), and each lights its achievements up for free the
    moment its owner starts counting it. Nothing further is needed *here*.

    Of those, **47 achievements (14%) are structurally unreachable** until two
    deferred systems exist, and no achievement-side work can change that:

    | Blocked by | Achievements | Statistic ids |
    |---|---|---|
    | ~~**2v2** (item 30)~~ - **unblocked**, item 30 is done | 22 | 146, 147, 148, 171 |
    | **Tournament match layer** (item 32) | 25 | 183, 187, 188, 189 |

    None of them are hidden, so they are visible-but-stuck in the client's list.
    The remaining 285 need only their statistic to start moving.
27. [x] **NPC dialog trees** — DONE, and the answer is that **the server owes
    nothing**. The premise ("type 1500 not decoded, needed for dialog trees") was
    wrong: type 1500 is loaded by the CLIENT from its own data, by its own
    content loader (`xs_0`, "contentLoader.dialogReply"), and the whole tree runs
    locally. Evidence:

    - `ao_2.a(fh_2,false)` — merely registering the dialog frame OPENS
      `npcTalkDialog`. There is no request and no reply.
    - The 17001/17002 it handles are **not wire opcodes**. They arrive as `wm_0`,
      which extends `sb_0` → `aed_2`, whose `encode()` returns `null`, so they can
      never be serialized — the same internal-event pattern as 22050/22051.
    - A reply can do exactly two things, per the `alj` enum:
      `cEY(1,"Lancer un défi")` → `th_0` sends **26330** (challenge start), and
      `cEZ(2,"Donne un exploit")` → `po_2` sends **22003** (a criterion). Both are
      implemented, and 22003 now also drives achievement evaluation (item 26).

    Also established: of the six NPCTalkers, **only one has a dialog tree at all** —
    `bob` (instance 143, world 85, dialog 228). The other five are decorative
    ghosts whose descriptor names dialog `-1`, so nothing could give them lines.

    Locked by tests that assert the NPCs are spawned in the right worlds and that
    exactly one carries a dialog id — the one thing that could silently kill the
    feature is the server no longer spawning the element. Live: the NPCs render
    and highlight as interactive. Opening the dialog window itself needs a real
    double-click, which the synthetic harness does not produce; it exercises no
    server code either way.

    Fixing the live check turned up a genuine defect, now fixed (B-107): the GM
    teleports left the coach on a cell with the wrong altitude, so the client
    refused to move it ("Invalid start cell for pathfind search").
28. ~~**The remaining unsupported effect action ids**~~ — **DONE**. Nine, not
    twelve (§8.5): five modelled (140 / 84 / 88 / 153 / 150), three cosmetic in
    the client and now `KindVisual` so they still animate (68 / 170 / 171), one
    dead client code (172 calls an empty method with no override). Effect rows
    resolved: **100 %**.

### Tier 3 — large systems

29. [x] **Sphere Board (Kanodo)** — **DONE, end to end, and live-verified.** The
    premise needed correcting: "17 542
    records" reads as an enormous wire job, but the board GRAPH is client-side
    data (`vj_2`/`dq_1` load types 900/901 out of the client's own files into
    `akp_1`), so the server never sends it. What the server owes is the fighter's
    PROGRESS, and the fighter blob already reserved room for it.
    Done: types 900 (15 boards) and 901 (17 527 nodes) decode byte-exactly —
    every record consumed to the byte, portal arrivals resolving to real cells,
    spell nodes resolving in the spell catalogue; the board's `cx`/`cy` identified
    as the ROOT sphere via `ks_2.Xm() = X(fs, ft)`; per-breed board selection,
    the stored 1-based cursor with root fallback and dangling-cell repair, the
    owned-node list, and schema v5 (`fighter_spheres` + cursor columns).
    Live on the retail client: the Kanodo opens on a real board, the fighter's
    head sits on the root, nodes select, and a node reports its own payload and
    price ("Bonus : +1% dégâts d'eau", "Coût : 218 xp").
    Also done: C2S **23009** (`aow_2`, arch 3) — the purchase. Every rule is
    re-derived server-side rather than trusted, because the client applies its own
    copy and simply tells us (there is no reply opcode and no rejection path, so a
    crafted 23009 would otherwise be a free talent tree): fighter ownership, the
    node being on THIS fighter''s board, the node having a payload, reachability,
    price (a re-bought node costs a TENTH), and a Barrier''s card being both
    accepted and actually held. Reachability mirrors `ajM.a` exactly — a route
    crosses EMPTY cells only, any payload node blocks it, dead ends block
    absolutely, and a portal reaches its arrival cell in one step.
    Live end-to-end: the confirm dialog ("dépenser 2 points d''expérience"), the
    purchase logged server-side, and 150 → 148 xp with the cursor moved,
    surviving a reconnect. Nodes the rule refuses are silently refused by the
    client too — the two agree.
    Also done: bought nodes now change the fighter. Their effect rows are `Ht`
    rows like every other passive, so they feed the same accumulator equipped
    cards and wounds use, applied after equipment and BEFORE conditions (growth
    of the fighter, then penalties on the finished article) - malus nodes
    included, since the board sells penalties on purpose. Sphere spells are
    merged into the fighter the fight is built from, so the cast validator and
    the AI repertoire both see them, on a COPY so nothing is written back.
    The evolution tail''s two "passive" lists turned out not to be passives at
    all (B-118): `ee_2` assigns them from the blob as `aRE = NI()` / `aRF = NJ()`
    and resolves them through the SPELL and EQUIPMENT-POOL tables, so they are
    the sphere-unlocked spells and type-251 pools. Sent empty, a Spell sphere
    bought in one session ceased to exist in the next.
    Also done: type **251** (equipment pools, `alf_2`) decodes, and the
    entitlement it exists for is enforced. An evolution fighter may wear only
    what its bought Item nodes unlocked; a classic "Elite" fighter is NOT
    restricted, because its picker is every card of the slot''s type
    (`aca_0.b`) while an evolution fighter''s is built from its unlocked pools
    (`ee_2` walking `aRF`). The client cannot offer an unearned card, so this
    only ever stops a crafted 6011 - which is a bare list of card ids.
    Also done: the ECONOMY is audited and locked. The board is the only thing
    that spends fighter experience and the post-fight report the only thing that
    grants it, and nothing checked the two met. Three invariants now do, against
    the shipped data-dist so they run in CI: the cheapest node REACHABLE from
    each board''s root is affordable on one fight (or a new fighter could never
    start), the dearest node (9 000) sits under the bank ceiling (50 000, else it
    could never be paid for), and a full board (~130 000 xp, strikingly uniform
    across all twelve) costs far more than the 40 000 that tops the level ladder -
    so the Kanodo is a series of choices, "apprendre a parcourir intelligemment",
    not a checklist.
    Live, the whole loop: the client shows "Esquive 61%" for a fighter that
    bought Esquive +1% after a full relog; that same fighter - which bought no
    Item node - is offered an entirely EMPTY equipment picker, exactly as the
    server''s rule says; and one won evolution fight moved it 148 -> 298 spendable
    xp while lifetime went 150 -> 300, the 2 it spent staying spent.
30. [x] **2v2 / multi-coach fights** — **DONE, live-verified end to end with four
    retail clients.** Every clause of the original description was wrong, which is
    worth keeping as a record of how far a plausible plan can sit from the data.
    The 2-team array must NOT become a slice: `aat_2` reads exactly two
    (`fight.team0` / `fight.team1`) and indexes `teArray[side]`. What varies is
    COACHES PER SIDE, and the wire always allowed it — the coach list is
    variable-length and independent of the team list, every fighter blob carries
    its owner's id, and `axw.a(team, side)` derives each coach's side from the
    team its fighters landed in.

    So `FightTeam.Coach/Session/Absent` became `Members []*FightMember`. The
    interesting part was not the rename but the places where "the team's coach"
    silently stood in for something per-coach: AI control (asking whether the SIDE
    had a session hands a human's fighters to the AI), absence (one coach dropping
    forfeited its ally), post-fight set bonuses (an ally's gear buffing fighters it
    does not own), stats, ladder, reward cards and the 8300 frames. Each is now
    per-owner — identical for 1v1, correct for 2v2.

    **Formation is the 60xx team family, not the 26313 XvsX of item 33.** The 2VS2
    tab creates a duo: teammate chosen from the FRIEND LIST, 6024 invite → 6025
    dialog → 6026 answer → 6027 refused / 6028 both open the picker. Every rule is
    re-derived server-side (the inviter is the sender, never the packet's id; an
    answer must name the coach that really invited it, or a stranger could be
    dragged into a duo). 26313 exists only as the `Test` Lua binding
    `XvsXInvitation` and has no UI — the two are unrelated.

    Three client rules had to be read rather than guessed, each found only after
    the previous was fixed:
    - a duo preset's coach list must hold BOTH coaches: `sw_1.afL()` is
      `bMK.size() == 2`, and the 2VS2 tab lists exactly the presets where it holds.
      `zK.cG()` APPENDS, so a hand-made team is `[self]` and a duo `[ally, self]`;
      `afG()` returns entry 0, the id 23103 sends back.
    - the preset TYPE must be one the client stamps (-6). Type 0 belongs to no
      bucket and skips the appearance bytes only -5/-6/-7 carry, so the row had
      nothing to draw and the tab stayed empty.
    - **each fighter entry's second i64 is the OWNING COACH, not a budget.**
      `cF(coachId)` keeps entries where `bMJ.du(id) == coachId`, and `afH()`
      requires every coach in the list to control one — which raises "Un des coachs
      ne contrôle aucun combattant". A 1v1 never noticed (afH only runs with >1
      coach); a 2v2 could never start. `cF()` reads the preset alone and never
      consults the roster, so no extra roster push is needed.

    23103 "Combattre" carries that ally id in its leading i64 — which we used to
    discard as "the team owner, trust the session". Both partners must press it
    before the pair queues once; `joinDuoPartner` merges the ally into the side and
    `pickArenaSeating(2)` picks from the 25 arenas that seat two coaches a side.
    On arenas: every .fmd stores SIX pedestal slots (28 of 47 populate all six, 24
    of those split 3/3 — the maps were always built for up to THREE coaches a
    side), and the 15 that populate none used to place a coach at the
    unpacked-zero sentinel, 2047 tiles off the map.

    Live: `2v2 side formed side=0 coaches=2 fighters=2` / `side=1 coaches=2
    fighters=2`, four fighters in the timeline (two red, two blue), pedestals both
    sides, turns cycling through all four coaches' fighters with `ai=false`. And
    the post-fight: `reports=4 standing=map[1:10 2:10 3:3 4:3]`, both winners +10
    standing / +1 win / +25 strength, both losers +3 / +1 loss, and every fighter
    that fought +208 xp and morale.

    The queue segregates duos from solo coaches. A duo must not face a lone coach -
    that side would field two coaches and two rosters, each with its own 6000-point
    budget, against one - and this is the CLIENT's distinction rather than a house
    rule: a preset's `zK.cB()` is 1 for an ordinary team and 2 for a duo, and the
    2VS2 tab lists only the latter. The matchmaker pairs only searchers with equal
    mode, so carrying it through is a single distinct tag.

    Nothing blocking is left.
31. [x] **Guilds / clans** — **DONE and live-verified**, including clan islands.
    The only unbuilt opcodes (513 rename, 551 icon) are deliberate exclusions with
    evidence, not backlog — see the end of this entry. The premise
    held: the client's clan feature is fully wired and reachable (handler `lh_1`
    registered on login, 13 C2S classes with production callers, the guild tab
    one click from the HUD). What blocked it was the server writing an empty
    0x20 blob, which is the ONLY thing besides 552 that sets `aPY()` — every
    entry point reads it, which is why `/c` had emitted nothing.
    Done: storage (guild/ranks/members, schema v2), the 0x20 membership blob,
    clan chat, and 509 create / 501 invite / 503 answer / 517 get / 519 members
    with 502/504/510/512/552/556/558/560. Live on the retail client: the success
    dialog, the CLAN tab showing the guild name, `chrono (chef)` with its rank
    badge, the leader-only management button, and the client's own
    "recruit 4 more" rule computing off the real member list.
    Also done: 505 kick/quit, 511 destroy, 553/555/557 rank CRUD, 515
    set-member-rank and 2600/2601 member stats - every privileged operation
    re-deriving the caller's rank instead of trusting the request, since the
    client hides each one from anyone without the right.
    Also done: the clan tag now fills the column reserved in the 1v1 board, and
    the clan ladder returns real rows (score = the sum of member ratings - a
    server choice, since the client renders the number without interpreting it).
    Also done, and it closes the feature: **clan islands, on the retail rule.**
    The client states it outright - *"Seul le clan le plus puissant au service de
    chaque Démon reçoit une île de clan"* - and the data agrees: **24 demon
    totems (ids 1-24) and exactly 24 islands (worlds 86-109)**, a 1:1. So an
    island is not chosen and not random: it belongs to a DEMON, and is held by
    that demon's top-ranked clan. A clan's only lever is which demon to serve.
    The island is therefore DERIVED, never stored - a clan that is overtaken
    loses it, which an allotted island could not express.
    Implemented with it: demon affiliation (**5470**, a card OFFERING with a
    split-quantity dialog, not a button; leader-only, one-way, answered on 5403)
    and the per-demon clan ladder (**27510/27511**), which had been replying with
    a well-formed empty window since it was written.
    The client cannot express a choice of island at all: card 859 sends only
    `[i32 cardTemplateId]`, so the destination is entirely server-side.
    Two server-side rates are ours, since the client only ever renders totals and
    fixes neither: a card is worth its own VALUE in reputation (rare gives more),
    and the clan-board score is the sum of member ratings. Both are stated in
    tests rather than buried.
    **Not implemented, deliberately:** 513 (rename) and 551 (icon) - reachable
    only from the client's `Test` Lua debug library, no UI, no assets.
32. [x] **Tournament live-match layer** — **DONE and live-verified end to end**,
    prizes included.

    The bracket is the client's own shape and not negotiable: `ah_1.getFieldValue`
    slices a 1-indexed binary heap by hard-coded slot range — 1 winner, 2-3 finale,
    4-7 semi, 8-15 quarter, 16-31 first round — so 16 entrants over 31 slots, and
    slot i is decided by the pair in 2i / 2i+1. Names in 28650 are **UTF-8**, not
    the cp1252 the rest of the protocol uses (B-068), and `IL.a` reads a trailing
    i32 unconditionally, so an empty tree still needs it or the client underflows
    instead of showing its own "unavailable".

    The match flow, read off `ds_2`: 28611 ready-up → 28612 (which opens the
    waiting dialog and MUST be sent, because the Tournois tab closes itself after
    28611) → 28614 *"Lancement du combat"*, which closes that dialog and therefore
    goes out BEFORE CREATE_FIGHT.

    **Reaching that UI was the hard part and none of it is server-visible.** The
    Tournois tab never requests the tournament list; only the calendar (20032) and
    the TOTEM (20070) do, and the totem is an interactive world element (`hb_0`),
    so the flow is entered from the map. 28630 then creates the notification that
    is the only way to SELECT a tournament (`agz_1` → `vk_1.ad(tid)`), and it must
    follow 28602 because `zN` resolves the tournament's NAME out of the registry
    28602 fills. Sent at world entry it throws inside the client and vanishes.

    Live: right-click the totem → `tournament list count=3` →
    `search period announced` → the tournament appears in the Tournois panel →
    select → Combattre → `tournament match paired a=Chrono b=ExBot` →
    `fight started arena=77`, both retail clients in placement.

    Pairing is per-FIXTURE, not per-tournament: a coach's opponent is the entrant
    in the sibling slot (`slot ^ 1`) and nobody else. Pairing any two ready
    entrants was safe — the bracket refuses a non-sibling result — but it sent two
    players into a match that advanced neither, which is worse than waiting.
    Results advance the winner to slot i, from the round it actually REACHED, and
    are persisted (schema 7) so a restart no longer resets every tournament to its
    first round.

    A short draw is won by **byes** (B-122). The client's tree is a fixed
    16-entrant heap, so without them a coach whose half was never seeded ran out
    of opponents and the winner slot was never filled — most tournaments simply
    never finished. "Unopposed" means the sibling's whole SUBTREE holds no
    entrant, not that the sibling slot is momentarily empty; the two readings
    agree on a finished round and disagree on a live one. Byes are derived, never
    stored, so they always match the current entrant list.

    **Prizes are paid** (B-123): `aub.aHi()` is the definition's reward card. It
    never crosses the wire — the client reads it from its own data.bdat — and the
    shipped GUI has no renderer for it, so nothing on either side would have
    revealed it was unpaid. Only definitions 11 (card 26) and 18 (card 544) name
    one. Note `aub.qo()` is the sibling field and is an entry FEE, not a second
    prize; that was already handled by excluding fee-charging definitions from
    the operator's list.

    Live end to end: `tournament match paired a=Chrono b=ExBot` → `fight started
    arena=74` → `bracket advanced winner=1 slot=1` (a bye — with two entrants the
    one match IS the final) → `prize awarded def=11 card=26`, with the card in
    `coach_cards` and only slot 8 persisted.

    An entrant with nobody left to play is now told so (**28648**, *"the other
    player was not searching while you were, so you are declared winner by
    forfeit"*). That message is the only server-side way to dismiss
    `tournamentsSearchStatusDialog`, so without it an unopposed coach sat in the
    waiting overlay for the rest of the session. It is gated on registration being
    CLOSED: byes are derived from the current entrant list, so an empty half of
    the draw while registration is open means only "nobody has entered there
    *yet*", and a lone early entrant would otherwise be handed the tournament and
    its prize the moment it pressed Combattre.

    **The 28xxx admin family is dead in the retail client and deliberately not
**Most of the 28xxx admin family is unreachable in the retail client and
    deliberately not implemented** — 28603/28605/28607/28633/28635 have message
    classes that can encode, but nothing anywhere constructs one. Their replies
    land solely in `ajp_0`, a **debug-console** handler whose output sink
    (`ajp_0.a(apk_0)`) is never installed, so even its logging is inert. A server
    handler could not be reached by any player action, could not be live-verified,
    and would make a privileged operation reachable by anyone who patches a client
    — so if they are ever added they must be gated on the account admin flag. The
    web console already covers the same capability. See
    `docs/OPCODE-INVENTORY.md` for the per-opcode reasons.

    **Correction: 28617/28618 are NOT part of that set**, and were wrongly filed
    with it. 28618 `ahd_0` = `[i64 tid]` makes the client ask *"Vous avez participé
    à un tournoi que vous n'avez pu terminer… Souhaitez vous que votre position
    soit reportée au prochain tournoi de même type ?"*, and answering yes sends
    28617 `afg_2` (`ajp_0`:152 → the `gs_2` dialog callback, answer 16). That is a
    player-facing carry-over feature, fully reachable — it only needs the SERVER to
    send 28618. **Genuine open work.** The mistake came from checking whether the
    client *constructs* 28617 and stopping there: it does, inside `ajp_0`, in
    response to a server message. "No constructor" proves unreachability; a
    constructor in a handler proves the opposite, and I read the first as the
    second.

    **28620** (the "Finale du tournoi X — A VS B" alert) is implemented: it needs
    no scheduler, because the final is simply the fixture whose winner takes the
    root. That test is *not* "the parent slot is 1" — with four entrants the pair
    at 8/9 decides slot 4 and the byes carry that winner home, so it is the final
    too. `Yq.a` reads both of its arrays **backwards**, so they are written in
    reverse; writing them naturally yields a valid frame announcing the finalists
    swapped.

    **28622 is dead** like the admin family: `ds_2`'s case body is empty, and the
    static list it decodes into (`uw_2.ahZ()`) is never read by anything.

    Tournaments now carry a real **opponent-search schedule**
    (`SearchPeriodStart` / `SearchPeriodMinutes`, schema 8), and **28644** sends
    entrants the countdown to it. The schedule is a single source of truth: the
    calendar's "phase" pair used to be invented as `now+1h..now+2h` on every
    request, so what the player was shown drifted each time the window was opened
    and corresponded to nothing. 28644 goes out only while the window is still
    ahead — `zN` renders `1 + (start-now)/60000` minutes, so a past start shows a
    negative countdown.

    A closed window is now **settled**: whoever was searching takes the fixture,
    whoever was not is declared forfeit (28648 both ways). That is what lets a
    tournament progress when the two halves of a fixture are never online
    together. Three rules make it fair rather than merely automatic — being in the
    ready set is not enough, the coach must actually be **present** (nothing clears
    that set on disconnect, so readying then logging off would otherwise win
    fixtures while absent); **neither** side searching decides nothing, because
    picking a winner would hand it to whoever was seeded lower; and a forfeit
    winner follows the **byes** above the fixture, so with a short draw a forfeit
    can be the tournament win and still pay out.

    Settlement runs lazily from the totem/list request rather than on a ticker: a
    tournament only needs to be current when somebody opens it, and the operation
    is idempotent by construction (it only fills empty parent slots), so no
    "already settled" flag is stored and no goroutine needs a lifecycle. The
    outcome does not depend on who triggered it.

    Still open: **28646** ("the period opens now, valid N minutes"), blocked on a
    specific hazard rather than effort — `zN` case 28646 adds its `td_0` **without**
    the duplicate guard case 28630 has, so emitting both for one tournament leaves
    two identical alert rows. 28630 would have to stop being the selection
    mechanism first.
33. [x] **X-vs-X challenge with allies** (26313/26314) — **CLOSED: dead in this
    build, and superseded.** Nothing to implement.

    26313 `aju_1` is `[i8 mode=14][i64 target][u8 n][i64 allyId × n]`, answered by
    26314 `ahV`. Its **only** builder is `awj_0`, which is the Lua binding
    `XvsXInvitation` in `adg_1` — a class whose own constructor is
    `super("Test")`, registered at `zh_1:152` alongside the other debug libraries.
    There is no UI anywhere that reaches it.

    It is also not the multi-coach feature it looks like: **item 30 (2v2) is built
    on the 60xx team family** (6024/6025/6026/6027/6028), which is what the 2VS2
    tab actually sends, and that is live-verified with four retail clients. The two
    are unrelated in both directions — 2v2 never touches 26313, and 26313 would not
    produce a 2v2.

    Same call, and same evidence shape, as the tournament admin family: the message
    class exists, the caller does not.
34. [x] **Versioned schema migrations** - DONE, though not by deleting
    `AutoMigrate`, and the reason is the three supported dialects. Hand-frozen
    `CREATE TABLE` SQL would exist three times and drift three ways, so the
    baseline is expressed through GORM's own migrator: portable, and identical to
    what every existing database was already built with. What is new is the
    mechanism around it - a `schema_migrations` table, ordered one-shot steps each
    in its own transaction, and `Store.SchemaVersion()`. A failed step records
    nothing and is retried next start. Step 1 is defined against the LIVE models,
    so a purely additive change still lands without a numbered migration; anything
    destructive, or anything that must be ordered against a data fix, now has a
    slot. Verified on the real dev database: adopted in place at version 1 with
    all 4 accounts and 13 fighters intact.
35. [x] **Web admin panel** — DONE. Ported from v2.04 onto the 2.70 store and
    restyled: HMAC-signed sessions, CSRF, a player account area showing every
    stored datum, an admin console (searchable account list, deep per-account
    view, create/delete/grant-admin, impersonation), a public status page and
    leaderboard, and in-process pprof behind the admin gate. See
    `server/docs/WEB-PORTAL.md`. TLS is still left to a reverse proxy — the
    server does not terminate it, but `web.secure_cookies` exists for when it
    sits behind one.

### Deliberately out of scope ⛔

- **The drop table** — the mechanic is not recoverable from the client; building
  it means inventing it. Documented in full in case evidence ever turns up.
- **Directional / positional damage** — 2.70 removed it.
- **Chasing the client's accent mangling** — proven to be client-side; our
  encoding is correct and must not be "fixed".
- **Emitting opcode 22002** — its handler wholesale-replaces the coach's criteria.
- The seven other intentionally-dark S2C opcodes, each with a written reason.

---

## 14. Documentation hygiene

Stale claims that will actively mislead the next person. **Struck-through rows are
fixed**; the list is kept rather than deleted so it stays auditable.

| Where | Said | Reality |
|---|---|---|
| ~~`server/COVERAGE.md` "Fight feature gaps"~~ | ~~"only single-target HP-loss resolves…"~~ | **Fixed 2026-08-10.** Every clause was false — 94.7 % of effect rows resolve |
| ~~`server/COVERAGE.md`~~ | ~~"E2E suite: 44 top-level tests"~~ | **Fixed** → 72 |
| ~~`server/COVERAGE.md`~~ | ~~lists `4321 EndFightDone`~~ | **Fixed** → 26321 |
| ~~`server/docs/DATA-COVERAGE.md`~~ | ~~"8 of 24 populated types decoded"; type 902 ❌~~ | **Fixed** → 9 of 24 |
| ~~`internal/game/fightrules.go`~~ | ~~bonus-cell multiplier "not consumed yet"~~ | **Fixed** |
| ~~`internal/game/target_conditions.go`~~ | ~~credits the validator to `aap.a`~~ | **Fixed (B-074)** — it ports `aLc.a`; the misattribution cost real time |
| ~~`internal/game/postfight.go`, `postfight_apply.go`~~ | ~~wound/death rolls "deliberately NOT run yet"~~ | **Fixed 2026-08-10** — they run (B-066) |
| ~~`internal/game/cardsets.go`~~ | ~~"resurrection is the only one this server implements"~~ | **Fixed 2026-08-10** — nine families, 14 call sites |
| ~~`internal/gamedata/effectkind.go`~~ | ~~poison "resolved as immediate damage for now"~~ | **Fixed 2026-08-10** — a real per-round DoT |
| ~~`internal/gamedata/effectkind.go`~~ | ~~stat buffs "not consumed by the current flat-damage combat model"~~ | **Fixed 2026-08-10** — they are; only initiative and a few exotic ids stay render-only |
| ~~`internal/game/elements.go`~~ | ~~6 element kinds "deliberately NOT spawned yet"~~ | **Fixed 2026-08-10** — all six are spawned (2/11/9/12/24/2); only cardUsingSwitch and NPCTalker are genuinely absent |
| ~~`internal/game/handlers_fight_combat.go`~~ | ~~"used until real spell gamedata is wired in"~~ | **Fixed 2026-08-10** — it is wired; these are the absent-data fallback |
| ~~`server/README.md`~~ | ~~lists `internal/net`; default addr `127.0.0.1`; an `--addr` flag~~ | **Fixed 2026-08-10** — no such package, default is `0.0.0.0:5555`, and the flags are `--config`/`--data`/`--version` |
| ~~`client/analysis/opcodes.md`~~ | ~~"little-endian"~~ | **Fixed 2026-08-10** → big-endian, as everything else and the code say |
| ~~`server/docs/STATUS.md` §7~~ | ~~"clicks reach AWT/Swing dialogs only, not the GLCanvas"~~ | **Fixed 2026-08-10** — `CLIENT-TESTING.md` retracts it, and coach creation was driven by canvas clicks the same day |

**None currently open.** New entries belong here the moment a claim is found false,
with the correction rather than a deletion — a struck row teaches; a removed row
just loses the lesson.
## 15. Invariants — do not break

- **`OPCODE-INVENTORY.md` H count must equal the `r.Register(protocol.` count in
  `internal/game`.** Currently **82 = 82**. Check after adding a handler.
- **Never send opcode 22002.** Criteria reach the client only via the 2052 blob.
- **The wire protocol is sacred.** The client cannot be changed; server output
  must match the decompiled reference byte for byte.
- **Data over v2.04b.** The 2.04b branch is a useful *unobfuscated structural*
  reference, but its values are beta-era and differ. Every one checked so far was
  wrong in 2.70.
- **Real-data tests skip, never fail, when `server/data` is absent.**
- `data/maps/` and `data/` must not move — tests read them by relative path.
- **`gofmt -l internal cmd test` must be EMPTY.** This used to read "do not fix
  pre-existing gofmt drift in `handlers_team.go`, `packets_test.go`,
  `summon_test.go`, `target_conditions.go`, `team_codec.go`" — that drift no
  longer exists (verified 2026-08-10 against a pristine checkout of `HEAD`: zero
  files listed). The old wording was actively harmful, because it trained the
  habit of filtering those names out of `gofmt -l`, which would hide real drift
  in them. Do not re-add the exemption; just keep the tree clean.

---

## 16. The method that keeps finding real bugs

For each client record type: read the deserializer for the exact field **order** →
find each obfuscated field's **getter** → grep the getter's **callers** for meaning
(no callers = dead in the client too, safe to skip) → then **dump the real
distribution** across all records. A mis-assigned field shows up instantly as an
implausible histogram — the spell cooldown was 97/203 populated on the correct
field versus 6 on the wrong one. Finish with a real-data canary test asserting the
population size, so a future field-order slip fails loudly instead of silently
zeroing a mechanic.

A corollary worth repeating: **verify a claim of absence against the code before
acting on it.** "Tackle is not implemented" headed the open-items list twice and
was wrong both times — tackle existed, it just used a hardcoded 67 % instead of
the real stats.

### What the B-074…B-083 run added to the method

**Verify the claim, not just its absence — including claims in THIS file.** Three
backlog items turned out to rest on false premises, and checking cost minutes
where implementing would have cost hours and shipped a wrong mechanic:

- *"Initiative buffs should re-sort the timeline"* — no shipped spell uses
  action 76/77 at all, the client's timeline interface has no comparator, and no
  message reorders it. **Withdrawn** rather than built.
- *"Fill the 8000 effects slot with buff icons"* — that slot is the **sphere
  board**, and the client re-applies the node's effects. Filling it as planned
  would have applied unrelated effects instead of drawing an icon.
- *"Asymmetric 2-/4-param crosses"* — no shipped record has one. Still
  implemented, because the client's own body was right there and the old code
  would have been silently *wrong* rather than absent, but scoped honestly as
  forward safety rather than sold as a fix.

**Dump the data distribution before scoping the work.** It repeatedly changed
what "the work" was: the zone-effect family was 6 members, not the 3 listed; the
enforced target masks were 3 of 202 carriers; the np_1 enforcement rules all ship
with EMPTY parameter arrays, which turns "enforce rule N" into "find where its
operand lives" — a different and much harder question.

**Mutation-test every new assertion.** Two tests in this run passed for the wrong
reason and would have entered the suite as decoration:

- the target-mask escape test used a mask that was permissive either way, so it
  passed with the feature removed;
- a matchmaker test probed the same queue repeatedly, and its own probes paired
  with each other rather than with the fixture.

Both were only exposed by deliberately breaking the code and demanding the test
notice. A test that cannot fail is worse than no test, because it looks like
coverage.

**A silent no-op is the failure mode to design against.** An unimplemented
effect action, an unhandled AoE shape and an unknown target-condition bit all
default to "do nothing" or "allow", which is invisible in play. That is why
167/168 were implemented despite having no shipped rows, and why a target mask
carrying a bit we cannot represent is skipped *whole* rather than half-enforced.
