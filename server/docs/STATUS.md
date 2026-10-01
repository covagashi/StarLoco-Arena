# STATUS — read this first

Single entry point for picking the 2.70 server back up cold. Everything else is
detail; this is state.

**Updated:** 2026-09-02

> **Security:** a full hostile-client audit plus a client-enforced-rule sweep and
> **fully remediated** (`BUGS.md` B-145 … B-160). That included two remote
> full-server crashes reachable in three packets, four unbounded card-minting
> paths, a team-preset IDOR, client-authored spell loadouts, and the absence of
> any connection cap, timeout or login throttle on the game socket.
>
> [`SECURITY.md`](./SECURITY.md) is the reference: threat model, the structural
> properties that keep the surface small, the per-item fix table, and the three
> findings deliberately **not** changed (spectating any fight is retail
> behaviour, the fighter budget is only warned about by the client, and
> hand-driving your own summon yields no advantage).
>
> **Before exposing an instance publicly**, set `limits.auto_register: false` and
> `limits.first_account_is_admin: false` in `config.yaml`. Both default to true
> to preserve local workflows, and the second is a race an attacker wins simply
> by connecting before you do.

---

## 1. What this project is doing right now

Making the from-scratch Go server wire-compatible with the **retail 2.70 client**, driven
by bugs found in live play. Current theme: **the client's data files are the single source
of truth** — no hardcoded values, no values ported from v2.04b (a beta whose numbers were
re-tuned). Every v2.04b-inherited value checked so far has turned out wrong in 2.70.

**Tiers 0, 1 and 2 are COMPLETE** (see `ROADMAP.md`). Tier 3 is where work is now, and
most of it is done too: **29 Sphere Board**, **31 guilds/clans**, **34 schema migrations**
and **35 web admin panel** have all landed. What is left in Tier 3 is almost entirely the
maintainer's own deferrals. **30 (2v2) is now DONE too** — live-verified with four retail
clients. **32 (tournament match layer)** is now DONE: brackets, per-fixture pairing,
byes, persistence (schema 7) and prizes have all landed and the whole flow is
live-verified (see below). What remains in Tier 3 is **33 (X-vs-X allies)**, which turned out
to be unrelated to 2v2: its 26313 exists only as the client's `Test` Lua binding
`XvsXInvitation`, with no UI anywhere. Ask before starting it.

**Item 32 is now DONE, live-verified end to end** with two retail clients:
`tournament match paired a=Chrono b=ExBot` → `fight started arena=74` →
`tournament bracket advanced winner=1 slot=1` → `tournament prize awarded def=11 card=26`,
with the card really in `coach_cards` and only slot 8 persisted (4/2/1 are derived byes).

Getting there produced one real bug and one non-bug, which is the useful part. The blocker
— "the Tournois roster is empty" — looked like a single problem and was two. The first was
a genuine server bug (**B-124**): the client discards the roster and presets on every
ENTER_INSTANCE, so a plain `/WORLD`, and every Zaap trip, emptied the team panel until
relog. The second was not a bug at all: the panel's budget still read 6600, so the team was
loaded and only the portraits were missing — switching tab away and back repaints them.

Two lessons worth keeping: the suspect written down here previously (`agz_1` →
`onlyTabEnabledId`) was wrong on both counts, and a controlled bisect (teleport with no
totem) found in one step what re-reading the client had not. And when driving the client,
**switch tabs once after opening the team panel** before trusting what the roster shows.

**Opcode coverage, and what is actually left.** 331 rows: 104 C2S handled, 122 S2C emitted,
5 inactive, 100 unimplemented. 16 of those 100 are **unreachable from the retail client**
and are recorded as deliberate non-work, with the evidence, in
[`docs/OPCODE-INVENTORY.md`](./OPCODE-INVENTORY.md) — 10 C2S whose message class is never
constructed, and 6 S2C with no live consumer. The other ~84 are real gaps; that file now
names the consuming client class for each, groups them by feature family, and gives a
suggested order. Start there rather than from the raw table.
A recurring result worth knowing before picking up an item: **five Tier 1 entries were
resolved by evidence rather than code** — initiative re-sort, 5203 destructive ops, buff
stacking, the np_1 operand hunt and `MaxActive` — because the premise was false or the gap
was unreachable in shipped data. Two of them would have introduced bugs if built as
written. Tier 2 and 3 repeated it: the coach action deck is empty because *nothing in this
build populates it*, card staking is vestigial (`<!--plus de pari-->`), NPC dialog trees
run entirely client-side, and item 29's "17 542 records" was never the size of the job
because the board graph is client-side data. **Check the premise against the client before
implementing** (§9).

## 2. Where to look

| Doc | What it answers |
|---|---|
| **this file** | What is done / in flight / next |
| `DATA-COVERAGE.md` | Which client records we read, field by field, and what is still unread |
| `BUGS.md` | Every fix: symptom, root cause (with the client class that proves it), verification |
| `OPCODE-INVENTORY.md` | Every opcode and its handler |
| `CLIENT-TESTING.md` | Live-client harness, and the e2e flakiness diagnosis |
| `CLIENT-UI-MAP.md` / `OVERWORLD-MAP.md` | Canvas click targets, world layout |

## 3. Recently completed (newest first)

| # | What |
|---|---|
| GODOT | **Spell `.xps` particle FX** (B-167): `spell_sounds.py` → `spell_fx.json` (100 spells — `[[t_ms, xpsId, anchor]]`). `xps_dump.py` decodes **364/364** `0x5001` sfx.jar systems to `assets/gamedata/xps/<id>.json` + `xps_index.json`, exports **253/275** TGA→`assets/fx/<id>.png` (`81.xps` is a legacy `XPS` zlib blob — skipped). Decoder tracks `alo_2` (compact header when `dstBlend==0`, 22-float bitmap models, DirectionFollower tag-6 has no leveled bit). `xps_fx.gd` drives CPUParticles2D from the first emitter JSON when present (approximate — affector curves still skipped). `fight_view` `_cast_fx` on `8110`. Verified: `test_xps.py` 364/364, `fight_smoke` + `carry_smoke` green |
| GODOT | **Animation-frame script audio** (B-166): `.anm` `pb_1` runScript parts (83 files, 1,657 parts — `AnimSort_*`, `AnimCombat`, `AnimEmotes`, weapon banks, `npc_2000`) now export as `meta.scr {frameIdx: [scriptIds]}` in both `anm_render.py` paths; `spell_sounds.py` resolves `scripts/anm/<id>.lua` boilerplate into `anm_scripts.json` (409 scripts → `{s:[[soundId,gain]…], stop}` — `playLocalSound` singles + `playLocalRandomSound` uniform `(id,gain)` sets; `playBark`/`playGroundSound` skipped, retail tables unshipped). `AnmSprite` fires them per-frame through the sfx pool at authored gain, honours `stopOnAnimationChange`; `anm_scr_patch.py` backfilled 3,144 metas in place. Verified: `fight_smoke` green, tackle/hit/KO/cast/emote/weapon-draw triggers all mapped |
| GODOT | **Lua-driven cast fidelity**: spell/card/weapon plays now reproduce the script layer — casters snap their facing to the aimed cell (every script leads with `setMobileLookAt`, agv_0.D Direction8 snap), crit/fumble punches the camera to the attacker↔target midpoint at 1.4× and restores (re_0), and `dumpspells`' new `script` id + `tools/asset-import/spell_sounds.py` extract `Sound.playSound` ids with their `invoke()` delays into `spell_sfx.json` (88 spells, 76 ids, 75 oggs) which `AnmSprite.play_sound` pools per caster. Weapon cards (scripts 800x) play the per-family armed gesture `AnimStatique03(-Debut)-<fam>` — 219 fists (also the unarmed 8111), 110 sword, 112 dagger, 117 bow, 108 wand, 114 hammer, 111 shovel — composited from `animations/Players/Anim*.anm` banks onto every `fighter_*` set (`dumpfightercards` exports the card's `script` field so the client maps card→family). Summons carrying a death-particle id (type-300 field 17 → `npcdialogs.json` `particle`; only templates 52/53) dissolve instead of greying. Also B-165: opcode 2050 had no handler |
| GODOT | **Cast limits + AoE preview**: `dumpspells`/`dumpfightercards` now export the client's `sH` cast-frequency budget per spell/card (`lk` LimitKeyID, `cd` EffectiveCooldown — 63=once per fight, `mpt`/`mptt` per-turn/per-target caps; 61 spells carry limits) and the effect `zn` zones (deduped `[shape,size]` — 18 spells, 8 cards). fight_view records every `8110` (fumbles count — server storeCasts after the roll), resets per-turn counters on the fighter's own `8104`, greys locked spell buttons live, dims per-target-capped cells in the range overlay, and tints the aimed footprint while hovering a castable cell — `areas.gd` gained the full `pointInArea` port incl. directional T/inverted-T/point-list (`cardinalStep` source→aim axis). Verified: T/Tinv/point-list footprints match the server math; fabricated 8110 locks spell 32 (cd=5) until table_turn+5 |
| GODOT | **Placed effect areas** (traps/glyphs/auras): `8120` action 66 places a trap/glyph on the cast cell and 176 a caster-followed aura — both carry the type-210 template id in `value`, so `dumpeffects` now also exports `areas.json` (shape/size/maxExec/walkOn/innerEffectIds) and `areas.gd` ports the server `pointInArea` footprints (point/circle/cross/ring/square). Retail visibility is honoured — the area renders only while its caster sprite is visible (aew_1 `aoy` hides hidden casters' traps). There is no removal broadcast: finite areas count fires by attributing inner-effect 8120s (same caster, victim inside footprint) and drop at `maxExec`, auras age per table turn and die with their caster. Verified in `fight_smoke` with fabricated 8120s — r2 diamond = 13 cells, one-shot trap erased on fire, unlimited glyph persists |
| GODOT | **Special battlefield cells**: `_fmd.specials` tiles now render as lettered colour-coded diamond markers (templates 1002–1009 — killer cell, trap, eagle eye, shield, panacea, enthusiasm, motivation, healing heart), and `6200` EffectAreaAction floats the tile's name over the fighter who entered. Arena 59 carries 10 of them — verified live in `fight_smoke` with zero draw errors |
| GODOT | **Combat gestures**: `AnmSprite` gained one-shot playback (`once`/`hold_last`/`action_finished`/`play_once`) and fight_view resolves the anim set per fighter — summon `look` (type-300) → `npc_*`/`fighter_*`, players via the breed/sex fighter file, coach fallback. Triggers: `AnimMarche` while walking (engages even when facing is unchanged; sets without it glide rather than swapping to the coach), `AnimHit` on damage, `AnimMort` held on death, 8110 → `AnimSort-<slugged FR name>` → `AnimSort-Cast`/`AnimCast` (spell_names.py exports `nfr` for the slug; NPC summon anms carry rasterized gestures — player `AnimSort_*` files are skeletal tracks that render empty standalone, so player casts keep the idle frame). Also: `load_action` no longer blanks the sprite on a missing asset, and cache-hit reloads restore `playing`. Verified live — `fight_smoke`/`summon_smoke` green, Tofu spawns on its real `npc_8006` set |
| GODOT | **Tackle + acting-fighter HUD**: `4506` FIGHTER_TACKLED floats "tackled!" on the held fighter (no 4524 follows a failed evasion — the server force-ends the turn), and the spell-bar AP/MP label now tracks whoever's 8104 is running (breed stats for players, type-300 ap/mp for summons) like retail, not just our own fighter |
| GODOT | **Turn clock**: the TopBar shows a live countdown per fighter turn (and for the 30s placement window) — the server's `turnClock` is 30s (`internal/game/fight.go`), reset on every 8104 and cleared on 8106/8028/8300, red under 6s |
| GODOT | **Buff strip + 8121**: every fighter now carries a chip line under its nameplate — timed/infinite `8120` effects attach by resolving `gen_effect` through the new `dumpeffects` export (306 rows; duration is data-side, never on the wire), `8121` resync attaches decode `actionId + blob + fid + i16 expiry` into rounds-left = expiry − own-turn counter (the client's `expiry - aAy()`), one `8100` ages all finite chips by a table turn like `tickBuffs`, dispel strips by `params[0]`, death clears. Verified live in `fight_smoke` with fabricated 8121 frames |
| GODOT | **Walk preview + crit floats**: hovering a free cell on our turn dots the BFS path (the same `_find_path` a click sends, so preview == request) and floats the "N MP" cost — green inside budget, red past it. The 8110/8112/8108 casts now read the critical byte and float "critical! \<name>" / "critical hit!" in gold, and spell floats show the resolved name instead of the raw id |
| GODOT | **Effect floats**: the `8120` running effect now surfaces stat/state changes — resource gains/drains/steals (±AP/MP/RG/INI/HEAL/SUM), elemental res & dmg buffs (the fire/earth/water/air ± pair scheme), crit/fumble/block/dodge, on-hit damage boosts, and the state family (Rooted/Petrified/Invisible…) as pale labels; invisibility also fades the sprite alpha and dispel restores it. Drains/gains on the acting fighter sync the AP/MP readout too |
| GODOT | **Cast-range overlay** (retail "zone de portée"): arming a spell/card/weapon tints every Manhattan-range cell, bright where the full cast gate passes — walkable, only-line, the client's `ahc_2` altitude LoS ported verbatim, free-cell occupancy and the enforced target mask (`aLc` bits incl. breed banks; unevaluable bits stay permissive like `spellTargetMaskAllows`). `dumpspells`/`dumpfightercards` now export the gates (`los`/`line`/`free`/`noboost`/`mask`). Verified live: spell 51 (los+free, 1-1) lights exactly the free adjacent cells |
| GODOT | **Displacement effects**: `8120` part-3 (`displacementPart` — dest x/y/z + collided fighter) is decoded and the seven displacement actions now move actors live — push 37 / pull 38 / self-push 153 take the part-3 cell, teleport 39 moves the caster to the part-0 cell, swap 64 exchanges both live cells, carry 58 parks the target on the carrier (it then rides along via `_carried_by`, broken by walking, another displacement or death), throw 59 lands it. Live-verified by `displace_smoke.gd` (teleport 12, push 67, swap 135). Also fixed the summon-render crash: `AnmSprite.load_action` cleared `_frames` **before** checking the asset existed, so `_face_step` retrying the missing `fighter_7000` set on a `breed=-1` summon blanked it and `draw_on` indexed an empty array every frame — a failed load now keeps the previous animation and `draw_on` guards empty frames |
| GODOT | **Achievements pane**: the old "Stats" tab (`22001`→`22002`) rendered raw `criterion N = V`; now it reproduces the retail achievements list — `qy_2` visibility rules (hidden, superseded, chain-locked dropped), done-first sort, per-row ✓ or averaged progress %, named criteria tail, and a detail line with description + per-condition progress. `dumpnpcdialogs` exports the full type-800 record (`prev`/`super`/`cat`/`sub`/`pts`/`hid`); `npc_dialogs.py` merges i18n 37/49/48. Also B-163: the LadderDlg list never cleared between tabs |
| B-162 | `/TP` moved the coach but never refreshed the **element** AoI — `teleportWithinWorld` called `ApplyMove` (actors) but not `refreshWorldElements`, so a teleport landed somewhere its client had no elements spawned (kind-8 zone triggers included). One-line fix; the Godot client also grew a real 4510 handler (snap + camera + `cell_entered`) so zone-trigger scenarios fire on teleports too |
| B-161 | A refused fight launch (illegal roster — e.g. 3 same-breed titulars) **disconnected the coach** instead of answering 26310: `rosterError` propagated out of every fight-start handler into `serve`, which drops the session. Fixed at all six call sites via `refuseFightError`; `titularRoster` also picks a breed-legal lineup now, since the server chooses it for challenges. Regression tests pin both halves |
| ITEM 36 | **Bug reports from the client's own dialog** - the retail client has a working "Rapport de bug" (menu bar -> `menuBarSendBug` -> `openBugReportDialog`, event 16427) that POSTs multipart/form-data to `<bugReportURL><lang>/bug-report` and requires a reply whose first line is exactly `OK`. That endpoint now exists, stores the report + screenshot, and the admin console lists/views/resolves them. **Live-verified with the retail client**: a real submission produced `bug report received id=1 title="Arche du Zaap sous la plateforme" screenshot=true`, the client logged no error (so it accepted our `OK`), and the 68 KB screenshot renders in the console. Screenshots go to disk, never the database - MySQL's default BLOB is 64 KB and anything in the database lands in every backup |
| B-127 | The website's own Home link and logo were dead ends once signed in (`/` redirected to /account). Also removed every "point your client at host:port" line - the download is pre-configured |
| DEPLOY | **First real production deployment** (Debian 13 / Docker / PostgreSQL 16, behind a Cloudflare Tunnel so the portal needs no inbound port). Two bugs only a non-SQLite, proxied deployment can expose: B-125 and B-126. Both were invisible to a fully green suite, e2e included |
| B-126 | The portal's per-visitor sign-up/sign-in limits became ONE server-wide bucket behind a reverse proxy; `web.trusted_proxies` (empty by default) makes X-Forwarded-For believable only from proxies you list |
| B-125 | **Coach creation disconnected every player on postgres** - `COLLATE NOCASE` is SQLite-only. Guarded now by a test that scans string literals for SQLite-only SQL, so the suite catches the next one without needing a postgres to run against |
| ITEM 32 | **Tournament match layer**: totem right-click -> 28601/28602 -> 28630 -> the tournament appears in the Tournois tab -> select -> Combattre -> `tournament match paired a=Chrono b=ExBot` -> `fight started arena=77`, both retail clients in Phase de placement. Bracket (28649/28650) served; results advance up the heap, persist (schema 7), pair per-fixture, bye an unopposed coach (B-122) and pay the definition's prize (B-123). Live-verified end to end: paired -> fight -> `bracket advanced slot=1` (a bye) -> `prize awarded def=11 card=26`, card present in coach_cards || ITEM 30 | **2v2 DONE** - four retail clients, two duos, one fight: `2v2 side formed side=0 coaches=2 fighters=2` / `side=1 coaches=2 fighters=2`, and post-fight `reports=4 standing=map[1:10 2:10 3:3 4:3]`. Formation is the 60xx team family (2VS2 tab -> friend list -> 6024/6025/6026/6028), NOT item 33's 26313 |
| B-121 | Presence reached only friends with `notify` on - a toast preference used as a subscription, so a 2v2 invite worked or failed purely on who logged in first |
| B-120 | The friend list sent coach id **0** for everyone (adP is the coach id AND the presence flag; adO is notify) |
| DOCS | `OPCODE-INVENTORY.md` had rotted badly and is now **machine-checked** (`opcode_inventory_test.go`): 20 implemented opcodes were still marked `-` "gap", 3 handlers had no row, and **5106/5108 were marked handled but do not exist in the client at all** (no class returns them). Also settled: 5109/5111 are **C2S**, not S2C ÔÇö their base `so_0` throws *"ne peut ├¬tre d├®cod├®"*, i.e. send-only || DOCS | `OPCODE-INVENTORY.md` had rotted badly and is now **machine-checked** (`opcode_inventory_test.go`): 20 implemented opcodes were still marked `-` "gap", 3 handlers had no row, and **5106/5108 were marked handled but do not exist in the client at all** (no class returns them). Also settled: 5109/5111 are **C2S**, not S2C — their base `so_0` throws *"ne peut être décodé"*, i.e. send-only |
| ITEM 29 | **Sphere Board (Kanodo) complete**: types 900/901 byte-exact, board/cursor/owned nodes served, 23009 purchases fully re-derived server-side, node effects and sphere spells applied in fight, type 251 equipment entitlement enforced, and the XP economy audited against the post-fight grant |
| B-118 | The evolution tail's two "passive" lists are not passives — `ee_2` resolves them through the SPELL and EQUIPMENT-POOL tables, so sending them empty made a bought Spell sphere cease to exist on relog |
| B-117 | Worlds 86–109 (the clan islands) served no interactive elements, so their Zaaps dead-ended; fixed by regenerating `elements_data.go` with those worlds in `policyWorlds` |
| B-116 | Card 859 (island access) was never granted; now granted **and revoked** at login as island ownership changes |
| B-115 | `TestPhaseClockForceAdvances` polled for a 20 ms transient; phases are chained, so it now waits for `PhaseAction` |
| B-114 | Clan islands require an **active** clan (5 members, from `guild.notEnoughGuildMembersToBeActive`); `DemonLadder` and `IslandOf` now share one subquery so they cannot disagree |
| ITEM 31 | **Guilds/clans complete**: storage, the 0x20 membership blob (the one thing besides 552 that sets `aPY()`), clan chat, full rank/member CRUD, the clan ladder, demon affiliation (5470) and **clan islands** — derived from "top clan serving each demon", never stored, because 24 demon totems map 1:1 onto 24 island worlds |
| ITEM 26 | **Achievements**: 332/5/13 records decoded, tab opens, unlocks announced via 22000, the "grimoire" folded in from inventory. 47 remain structurally unreachable until 2v2 and the tournament match layer exist |
| ITEM 24 | **Interactive elements generated from the env jars** (`cmd/genelements`) — reproduced the hand table 139/139 and found a real bug doing it (world 28's Card Master had direction `03` where the jar says `01`) |
| ITEM 25 | **Channel scoping**: `/t` Trade was being dropped with `unhandled opcode` while the client printed it locally (B-103); chat safety added to match the client's own limits (B-104) |
| LIVE | Full 5v4 driven to completion: by round 7 the AI had killed two player fighters and taken ZERO damage (no friendly fire, no Killer-tile suicide), fight ended cleanly, client log error-free |
| B-089 | Fusion consumed the player's CHOSEN card as fuel (5490's last id is the target) + type 1100 decoded: there is no recipe table |
| B-088 | The 8000 coach-deck blob carried CARD ids in a SPELL-id field (65 of 325 usable cards collide with a real spell) |
| B-087 | The AI walked THROUGH and onto sudden-death cells (players were guarded, the AI's own flood was not) |
| B-086 | The AI FROZE (positioning and casting disagreed about castability); also stopped walking onto Killer tiles |
| B-085 | The AI would NUKE ITS OWN TEAM with area spells (15 damaging breed spells are AoE; one hits every living fighter) |
| B-084 | The AI would HEAL the enemy it was attacking (a real coach's team goes AI-driven on disconnect, carrying arbitrary spells) |
| AI | Fighters play from a spell REPERTOIRE (was one fixed spell); demons carry a real breed loadout; close combat with leftover AP (a spell-less fighter did nothing at all); positioning uses the real targeting validator |
| LIVE | B-083 verified in the retail client: a real fight rendered every fighter, event card 14 drew, the end-of-fight panel and its won-cards row rendered, log error-free |
| RE | Buff stacking + the state-refcount gap both MEASURED and closed as correct-as-is; `MaxActive` scope answered (per TARGET, client-local, no wire) |
| B-083 | Fighter conditions (wounds) now in CREATE_FIGHT; the other id list is the SPHERE BOARD, not buffs |
| B-082 | Matchmaking rating band that widens with waiting (configurable; 0 disables) |
| B-081 | Spell-level target masks now enforced (3 spells); MaxActive documented as scope-blocked |
| B-080 | AoE shape 8 (point-list, directional) implemented; the cross now honours all three arities the client accepts |
| B-079 | The "triggerée en zone" effect family completed (165-168 elemental, 169 AP; 177 already done). Effect-row coverage 94.2%→94.7% |
| B-078 | **Tier 0 complete.** Effective AP/MP derived like the client's `gn_0.d`; `StringU8` enforces the 127-byte limit (a remote client-crash vector) |
| B-077 | Dispel no longer strips summons' innate states; `Coach.Standing` persisted and put on the wire (2052 + 4096) |
| B-076 | Forced displacement (push/pull/teleport/swap/throw) now arms traps; the full type-210 trigger enum recovered from `he_1.a` |
| B-075 | Two anti-cheat holes closed: 8021 placement was a free teleport to any cell at any time; spell casts never checked the caster owned the spell |
| B-074 | np_1 types 12 + 14 wired: fight-start effects and victory conditions now drive fights (12 of 39 challenges); target-condition bits 512/1024 added |
| DIST | Shipping pipeline: automated releases, self-writing config, web sign-up, update notice (§10) |
| B-073 | Challenges 39/39: inline unlength-prefixed effects now parsed exactly |
| B-072 | Turn clock + sudden-death turn now per-fight, from data (were hardcoded globals) |
| B-071 | Decoded `np_1`: coach cards 26/26 (zero residual x907), challenges 36/39 |
| B-070 | Evolution fighters could not be created (et_2 type byte was decoded and dropped) |
| B-069 | Challenge reward cards now reported in 8300; won/lost blob order corrected |
| B-068 | Wire text is windows-1252, not UTF-8 (both directions) |
| B-067 | Consumable coach cards: card effect arrays kept; 325 usable cards now work |
| B-066 | Coach META slice 2: type-902 conditions, the wound roller and the death roll |
| B-065 | Coach META slice 1: XP / morale / fatigue / reputation + the 8300 debrief record |
| B-064 | e2e combat flake: tests assumed "client A == side 0" (side 0 = first searcher) |
| B-063 | Tackle now uses real block/dodge (was a flat 67%); actions 147/148 wired |
| B-062 | Card sets ("panoplies") decoded; resurrection bonus wired |
| B-061 | Bound/undestructible cards can no longer be traded; coach card 8→18 fields |
| B-060 | Summon innate properties applied (22/53 creatures are rooted) |
| B-059 | Spell cooldown was read from the wrong field — 97/203 spells had none |
| B-058 | All 12 breed initiatives + base value were the 2.04b figures |
| B-057 | Cra's close-combat element was water, should be air |
| B-055/56 | Weapon attacks (8107) apply effects; fighter budget used the wrong card table |
| B-053/54 | Per-round event cards; actions 127/128 were mis-mapped onto root/stabilise |
| B-052 | All 47 fight maps (was hardcoded to world 5) |

## 4. Open items

Ordered by value. Item 1 is the biggest unlock; item 2 is the cheapest concrete win.

> Note: "tackle/dodge not implemented" used to head this list and was WRONG twice over —
> tackle existed, it just used a hardcoded 67% instead of the real stats (B-063). Verify a
> claim of absence against the code before acting on it.

1. **The drop table** (AI 18-21) — the last inert corner of the META layer.
   **Deliberately not implemented.** The client exposes only the four MODIFIERS
   (`avh_0`/`yt_0`/`aqm_0`/`akl` — drop bonus, drop chance, min/max level of dropped
   items); each is a pure accessor whose `a(et_2)` does nothing, i.e. the client never
   consumes them. The pool and the base rate are server-side and are **not recoverable
   from the data**, so building this means inventing the core mechanic — the same class
   of unknown as `baseXPPerFight`, but for a whole system rather than one constant.
   What IS evidenced and could be assembled if the rule ever turns up: the draw pool is
   `CoachCard.ObtainableInDraw` weighted by `DropPercent`, filtered by
   `RequiredLevel`; the payout channel is the 8300 won-cards blob (done, B-069); and
   the i18n says pets "augmentent les drops dans tous les modes de jeu, simulant un
   niveau de plus pour le joueur", which is AI 20/21 in prose.
2. **The CLIENT mangles accented names it receives** (B-068 residual). Proven with two
   controlled experiments: every server-provided name gains exactly one UTF-8→cp1252
   hop, and no input can undo it — pre-compensating makes it worse. Our encoding is
   correct and must NOT be changed to chase this. The open work is to locate the
   offending call in the decompiled client. Cosmetic; message bodies are unaffected.
3. **`gamedata` string fields are still read as UTF-8.** The `.bdat` text the client
   ships is almost certainly cp1252 too. Every field we currently read is ASCII
   (`"FIGHTER_CONDITION"`, `"FIGHTER_CARD_USE"`), so nothing is broken today — but the
   moment a name or description field is decoded it will need `protocol.DecodeText`.
4. **Enforce the remaining `np_1` rules.** Turn duration, sudden death and the
   bonus-cell multiplier are wired (B-072); fight-start effects (12) and victory
   conditions (14) are wired (B-074). Still inert: budget (incl. type 1000 "no limit"),
   roster limits, banned/allowed spells and equipment, class limits and prices, arena
   choice, event-list choice. **Read `content.54.<type>` before implementing any rule**
   — it is the authoritative semantics table, and it is what revealed that the timing
   rules are deltas rather than absolutes.
   ✅ **RESOLVED — there is nothing to enforce; they are a CATALOGUE.** `np_1` has two
   namespaces and the `ajr_2` enum names them: **1–32 are rules**, **900–930 are
   PARAMETERS** (every one literally *"Paramètre de …"* — de classe, d'id d'arène, de
   nombre de combattant, de temps). A rule declares how many operands it needs
   (`np_1.T()`); a parameter carries a value and needs none (`aIE`, the only subclass
   with `sp()` true). `np_1.b()` **concatenates** params until `rg().length >= T()`,
   `je_2.a(np_1[])` applies the rule the moment it has enough, and `jk_1` — registered
   as **"coachCardFightParametersManager"** — pairs each bare rule with every compatible
   parameter to build the picker entries (`WN`: `selected`/`description`/`activated`/
   `forbidden`). The data matches exactly: 13 rule types × 1 instance × 0 params, vs 31
   parameter types × 245 instances **all** carrying values, with catalogue-shaped counts
   (14 classes, 10 spells per breed, 27 arenas). So enforcing them as shipped would be
   enforcing a menu. Real rules arrive already parameterised via challenge records
   (10/12/13/14 — all wired). This only becomes work if custom rulesets/tournaments are
   built. Pinned by `TestNp1RuleCatalogueShape`.
5. **`MaxActive`** — decoded, not enforced. `TargetMasks` is **done** (B-081, 3 spells;
   a mask carrying a bit we cannot represent is skipped whole rather than guessed).
   For `MaxActive` the SCOPE question that blocked it is now answered and it needs **no
   wire work**: the counter is `sH.akV` on the per-fighter cast-history tracker, keyed
   by spell id, checked **on the TARGET** (`mv_1` runs cooldown/per-turn against the
   caster's `sH` but calls the max-active check on `gn_03`, which the next line proves
   is the target), surviving turn boundaries (`yB()` clears the per-turn buckets and
   leaves `akV`), and decremented by `amt_2` — which looks like a packet but has
   `TI()==0`, empty serialization bodies and no opcode, i.e. a client-local timeline
   event. It is also **the real stacking cap**: the client never merges buffs, it
   refuses the cast once the target carries `iT()` live copies.
   ✅ **RESOLVED — deliberately not enforced.** The decay window is **one turn**
   (`arm_0.lQ(1)`, a literal; the very next line uses `arm_0.lQ(fv2.et())`, a
   spell-derived duration, so the literal is deliberate), which is exactly the
   granularity `CastMaxPerTarget` already has. And every shipped MaxActive spell is
   already capped at least as tightly by a limit we DO enforce: five of six have
   `CastMaxPerTarget == MaxActive` (15, 46, 141, 167, 173), and the sixth (spell 8) is a
   range-0 self-cast already limited to one cast per turn. Enforcing it would add a
   second, subtly different gate that changes no legal cast, while a wrong window would
   *reject* casts the client believes are legal. Pinned by
   `TestMaxActiveIsRedundantInShippedData`.
6. **Tournaments** — types 1000/1001 decoded (22 definitions + the level
   list), and the line-up is now **editable from the web admin console** rather than
   compiled in: `domain.Tournament` rows, seeded on a fresh database with the three
   that used to be a Go table, served to the client from the database on every
   calendar/list request. Saving is validated against the decoded catalogue — an
   unknown definition id NPEs the retail client, so an admin cannot save one.
   Verified live: created a tournament in the browser and watched a connected retail
   client go 3 → 4 → 3 as it was added and hidden, with no decode errors.
   Registrations are persisted and restored on boot (B-101) — they used to vanish
   on every restart. The opponent-search opcodes 28609/28611 are answered as well,
   refusing visibly instead of leaving the client on a silent screen (B-100).
   Still deferred by the user: brackets, scheduling and rewards, i.e. turning that
   refusal into a real fixture.
7. ~~**Sphere Board**~~ — **DONE** (item 29). The "largest unimplemented system, 17 542
   records" framing was the misleading part: the board graph is client-side data, so the
   record count was never the size of the server's job.
8. ~~**2v2 / multi-coach fights**~~ — **DONE** (item 30), live-verified with four retail
   clients: duo formation through the 2VS2 tab (the 60xx team family, not item 33's
   26313), four-coach fights, and post-fight for all four
   (`reports=4 standing=map[1:10 2:10 3:3 4:3]`). This also gave `/p` group chat a real
   audience and unblocked 22 of the 47 stranded achievements.
   **The lesson is worth more than the feature**: every clause of the roadmap's
   description was wrong, and three separate client rules (`afL`, the preset type, and
   the fighter entry's second i64 being the OWNING COACH) each surfaced only after the
   previous one was fixed. Read the client's validation path *before* writing code.
9. **Tournament live-match layer** (brackets, scheduling, prizes) — deferred by the
   maintainer; blocks the other 25 stranded achievements.
10. **Fusion success probability** — genuinely unknown; no client code reveals the curve.
    Everything else about fusion is implemented (item 22).
11. **Server-invented constants** - now **configurable** under `rules:` in config.yaml
    (`base_xp_per_fight`, `standing_win`, `standing_loss`,
    `max_social_list_entries`; 0 means "use the default"). They and the
    reputation-per-card rate and the clan-board score are all **ours** — the client
    receives them pre-computed and so cannot arbitrate them. They are anchored by tests
    (a wrong value now fails loudly) but they are not retail-exact, and no test here can
    make them so. Do not let a green suite imply otherwise.
8. ~~**e2e residual flake**~~ — **fixed** (B-064): the tests assumed "client A == side 0",
   but side 0 is whoever reaches the matchmaker queue first, and the harness fires both
   searches without a happens-before. Full suite now passes repeatedly under load.

## 5. Awaiting the user

Nothing. The two items that used to sit here were **verified live in the retail client**
on 2026-08-04 (see `CLIENT-TESTING.md` for the driver — a solo "Tester" fight needs no
second player, and the client HUD renders fully once *the client* starts the fight):

- **Round event card renders.** Round 1 drew **event 14** server-side and the client
  displayed the card **"Cloué au lit"**. Its own effect text — *"Stabilise la cible
  (impossible à pousser ou attirer), non portable, rend intransposable"* — is an
  independent confirmation of B-053's mapping: actions **94 + 127 + 128**, and notably
  **no** movement block, exactly as decoded.
- **Sudden death.** `/SUDDENDEATH` shrank the arena (`step=1 r=104`, then
  `step=2 r=119 killed=2`); the client rendered the collapse and both fighters standing
  on removed cells died (*"Tanko perd 70 PdV / Tanko est mort"*), ending the fight.
- Bonus: the end-of-fight panel showed coach Loov at **Niveau 13 (1500)**, which matches
  the client's own `strengthToLevel`: `1 + round((1500-1000)/2000*49) = 13`.

## 6. Invariants — do not break

- **`OPCODE-INVENTORY.md` must agree with the code.** This used to say "H count must
  equal the `r.Register` count — currently 82 = 82", to be checked by hand. It was not
  checked, and it drifted to **82 vs 105**: twenty implemented opcodes still marked `-`
  ("anything marked `-` is a gap", says the document's own header), three handlers with
  no row, and two rows — 5106/5108 — claiming coverage of opcodes **the client does not
  have**. It is now enforced by `internal/game/opcode_inventory_test.go` in both
  directions, plus the S2C side, so it cannot rot again. Currently **H = 105**,
  **E = 115**. A hand-counted invariant is not an invariant.
- **Never send opcode 22002 *spontaneously*.** It is legitimate — and implemented — as
  the **reply to 22001**; `handleStatisticRequest` is its only emitter. The old wording
  here was a flat "never send 22002", which is now false and would invite someone to
  "fix" correct code. What must never happen is an unsolicited 22002: the client's
  permanently-registered tutorial handler `asA` would pop the tutorial-guide dialog.
  Criteria otherwise reach the client via the 2052 `0x200` blob.
- **`gofmt -l internal cmd test` must be EMPTY.** (This used to name five files as
  having untouchable pre-existing drift. Verified 2026-08-10 against a pristine
  `HEAD` checkout: there is none, in those five or anywhere else. The old wording
  trained people to filter those names out of `gofmt -l`, which would mask real
  drift — do not re-add it.)
- **Data over v2.04b.** v2.04b is a useful *unobfuscated reference* for structure (its
  `Breed.java` is the twin of 2.70's `xq`), but its VALUES are beta-era and differ.
- `data/maps/` and `data/` must not move — tests read them by relative path.

## 7. Known limits of my own verification

- **Fights started by packet injection do not arm the client's fight HUD.** The
  injected fight itself is correct (the client loads the arena and logs no errors); what
  is missing is local UI state the client only enters when *it* initiates. So drive the
  real UI instead — `CLIENT-TESTING.md` records the exact solo-fight recipe (team emblem
  → **TESTER** → **PRÊT**), which needs one account and no second player and renders the
  full HUD.
- ~~Clicks reach AWT/Swing dialogs only, not the GLCanvas.~~ **False** — retracted in
  `CLIENT-TESTING.md` and confirmed again on 2026-08-10, when coach creation was driven
  entirely by canvas clicks. `ControlAgent` targets the GLCanvas deliberately.
- **Verified live on 2026-08-11** (see §11 for the session): the CREATE_FIGHT change
  that added the conditions list (B-083) deserializes correctly — a real client-driven
  fight rendered every fighter, which is exactly what a wrong byte would have broken.
  Also re-confirmed: round 1 draws event card 14, the end-of-fight panel renders with
  the won-cards blob, and the client log stays error-free start to finish.
- **B-074 is server-verified, not visually verified.** The victory-condition chain is
  proven over a real socket (`test/e2e/victory_condition_test.go` drives a real
  challenge fight to the condition and asserts END_FIGHT names the coach; the server
  log shows `victory condition met ... round=2 winner=0` → `fight ended winnerTeam=0`),
  and every assertion is mutation-checked. What is NOT confirmed in the retail GUI is
  how the client renders the end-of-fight panel when **the losing team is still
  alive** — a state the elimination path never produces. Judged low risk: the 8300
  payload shape is unchanged by B-074 (only the winner id differs, a field that
  already varies) and that panel is live-verified for elimination wins. Confirming it
  needs a coach with fighters plus ~20 rounds of a "Défi du temps" in the GUI; worth
  folding into the next live session rather than doing standalone.
- The e2e harness builds `game.Deps` with **nil** `Cards`, `Spells`, `FighterCards`,
  `Summonings`, `CardSets`, `Events`, `FightMaps`. Most data-layer work is therefore
  provably inert in e2e — check this before blaming a gameplay change for a red suite. A
  *varying* failing test is machine load; a *consistent* one is a regression.

## 8. Test account + dev tooling

- Account **locos975 / azerty**, coach **Chrono (id 1)**. Fighter states: 0 titular,
  1 bench, 2 dead, 3 graveyard.
- The dev database has been rebuilt since this section was first written, so the old
  entry here (coach *Loov* id 3, fighters 22–29, and a warning that fighter 22's loadout
  had been modified to carry weapon 85) no longer describes anything that exists.
  Verified 2026-08-21 against `arena.db`:
  - **8 coaches**: 1 Chrono, 2 ExBot, 3 Sparrer, 4 Peer, 5–8 Recrue1–4. The four
    *Recrue* coaches exist to make the clan **active** — an island needs 5 members.
  - **13 fighters** (ids 1–13): Test, Brute, Tanko, Duo, Trio, Quatro, Cinco, **Sexto**,
    Spar1–3, Elito, Tourno. Sexto is the sphere test subject — it owns node 23802, sits
    at cursor (15, 76), and its `xp` is deliberately below its `total_xp` because it has
    spent some.
  - **1 guild**: "Les Bouftous".
- Reading the dev DB directly is often faster than driving the GUI for a number: a
  throwaway `cmd/` program using `store.Open("arena.db")` reads it fine while the server
  is running (SQLite WAL). Delete it afterwards — do not leave probe commands in `cmd/`.
- Dev endpoints (loopback, DEV builds only):
  - `curl "http://127.0.0.1:5599/c2s?opcode=&arch=&hex="` — inject a client packet
  - `curl "http://127.0.0.1:5599/fight"` — live fight dump
  - `curl --get --data-urlencode "cmds=..." "http://127.0.0.1:5599/script"` — drive a
    fight synchronously: `goto <wire> [ai] | move | cast | castself | usecard | cc | end |
    dump | wait`. **URL-encode `;`** or Go's query parser eats everything after it.
- GM chat: opcode **3151** arch 3, payload `012A` + `[u8 len]` + utf8.
  `/HELP /WHERE /TP /WORLD /WHO /STRENGTH /FSTATE /ENDFIGHT /EVOFIGHT /SUDDENDEATH
  /MAPDESTRUCT`.
- Build/test from `server/`: `go build ./... && go vet ./... && go test ./...`,
  e2e `go test ./test/e2e/`.

## 9. Method that keeps finding real bugs

For each client record type: read the deserializer `a(ByteBuffer,int,short)` for the exact
field **order** → find each obfuscated field's **getter** → grep the getter's **callers**
for meaning (no callers = dead in the client too, safe to skip) → then **dump the real
distribution** across all records. A mis-assigned field shows up instantly as an
implausible histogram (spell cooldown: 97/203 on field 10 vs 6 on field 8). Finish with a
real-data canary test asserting the population size, so a future field-order slip fails
loudly instead of silently zeroing a mechanic.

**The counterpart, which now pays just as often: check a backlog item's PREMISE against
the client before implementing it.** Four items in a row turned out to rest on false
premises (initiative re-sort, 5203 destructive ops, buff stacking, the state-refcount
gap), and two of them would have introduced bugs if implemented as written — the
requested buff "merge" applies both deltas but tracks one, leaking the second on every
revert. The reliable shape of that check is: find the client structure that owns the
behaviour, read how it is KEYED, and grep for whether the discriminating code path exists
at all. A strategy interface with no implementor (`aes_2`), an effect list keyed by a
monotonic counter, a message class with empty serialization bodies (`amt_2`) — each of
those settles a design question outright. When the answer is "the gap is real but not
reachable in shipped content", write the **guard test** that pins the data property
instead of writing the feature.

## 10. Distribution — the server as a product

Added 2026-08-05. The server is now something a non-technical person downloads and runs;
it no longer assumes a Go toolchain or a terminal-literate operator.

**Release pipeline** (`.github/workflows/`, `.goreleaser.yaml`)

- `ci.yml` — build/vet/test on Linux **and** Windows for every push/PR, plus `gofmt`, a
  `go mod tidy` check, and a cross-compile of `cmd/server` for all five release targets so
  a portability break is caught on the commit that causes it, not at release time.
- `release.yml` — `release-please` maintains a release PR from Conventional Commits;
  merging it tags + creates the GitHub release, then **GoReleaser** attaches
  Windows/Linux/macOS archives (amd64 + arm64, except Windows) and `checksums.txt`.
- **Do not split GoReleaser into its own `on: push: tags` workflow.** Tags pushed with the
  built-in `GITHUB_TOKEN` do not trigger workflow runs, so it would never fire and every
  release would ship empty. It must stay a dependent job in the same run.
- `cmd/studio` is excluded from releases and from Linux CI (Wails needs CGO + GTK/WebKit);
  the shipped binary is `CGO_ENABLED=0`, which is why one Linux runner can build everything.

**First-run behaviour** (`internal/config`)

- `config.template.yaml` is embedded and written to `config.yaml` on first start —
  every setting documented inline, unused ones commented out. This file is the only
  documentation most operators will read.
- `config_template_test.go` reflects over `Config` and **fails if a field has no key in the
  template**. Add a config field ⇒ document it, or CI breaks. Deliberate.
- Template and console output are **ASCII-only**: em-dashes rendered as mojibake in the
  Windows console (cp850). Keep it that way.
- Defaults changed for end users: `addr` `127.0.0.1` → **`0.0.0.0`** (friends can connect),
  `log_level` `debug` → **`info`** (quiet console).

**Game-data discovery** (`internal/gamedata/locate.go`) — added after the first
release, then revised days later (see the dated entry below — this paragraph
describes the discovery mechanism only, not the current bundling policy).

- The client stores the two halves in **different** directories:
  `game/contents/bdata/` (data.bdat + indexes.bdat) and `game/contents/maps/`
  (fight/ + tplg/). The old instruction "copy contents/bdata to data/" was therefore
  **wrong** — it silently produced a server with cards but **zero arenas**.
- `Resolve(root)` accepts any of: a merged `data/` dir, the client's `contents/`,
  its `game/`, or the install root holding `DofusArena.exe`. `Discover(configured)`
  walks the configured path, then exe-relative, cwd-relative (incl. the committed
  `server/data-dist/` and the source-checkout `client/compiled/game`), then the usual
  per-OS install locations — and will combine halves found in **different** roots
  (e.g. records in `data/`, arenas still in the client).
- `--data` flag overrides `data_dir` for one run.
- The failure message (now rare — see below) names which half is missing, how to fix
  it, and where it looked. `Location.Complete()` distinguishes "no data" from "half".

**2026-08-05, later the same day — reversed the "never bundle" call above.** The
maintainer (StarLoco) explicitly decided the small server-data subset (records only,
~2.5 MB — `data.bdat`, `indexes.bdat`, `maps/`) should ship in the box: it is now
committed at `server/data-dist/` (a deliberate exception alongside the still-gitignored
`server/data/` scratch dir — see `AGENTS.md` constraint 4) and copied into every release
archive and the Docker image, landing next to the binary at `data/`. `Discover`'s
existing candidate list already checked a cwd-relative `data`, so this needed **zero
gamedata code changes** beyond adding `data-dist` itself as a fallback candidate (so a
source checkout behaves the same as a downloaded release). The 436 MB retail client
remains fully excluded, unbundled, unchanged. `DISCLAIMER.md`, `NOTICE`, `LICENSE`,
`AGENTS.md`, `CONTRIBUTING.md`, `CLAUDE.md`, the root `README.md`, `.gitignore`,
`.gitattributes` and the Dockerfile were all updated in the same pass so no doc is left
claiming this data is excluded when it no longer is. Verified with the real
`goreleaser` snapshot output: extracted a bare zip with nothing else present, ran it
with zero flags — 907 cards / 203 spells / 47 arenas, no setup. Archives also renamed
`dofusarena-server_*` → `arena-server_*` in the same change.

**2026-08-05, later still — the retail client itself, by link, not by commit.**
The maintainer supplied a personal Mega mirror of the full retail client and asked
for it on the web portal, the README and the release notes. Implemented as
`web.client_download_url` (`internal/config`, default = the mirror link, blank
hides it, overridable per-fork). **⚠️ REVERSED — see the compliance-pass entry
below. The link is gone and the default is empty; do not restore it.**

**2026-08-31 — compliance pass on the repo and arenareborn.com.** The maintainer
asked for maximum defensibility at minimum risk, accepting residual risk. What
changed, in order of how much exposure it removed:

1. **The client mirror is gone from everything this project controls.**
   `defaultClientDownloadURL` is now `""` and `config.template.yaml` matches
   (the template is written verbatim on first run and *overrides* the Go
   default, so blanking only one would have changed nothing for new installs).
   The URL is out of `.goreleaser.yaml`'s footer and out of `README.md`. The
   config field survives, so an operator with a lawful copy can opt in under
   their own name. Pinned by `TestNoClientDownloadLinkByDefault`.
   The reason this mattered more than it looks: the link was the *default*, so
   every operator who ran a release republished it from their own portal
   without choosing to — the project's one unambiguous exposure, spread onto
   strangers. `AGENTS.md` constraint 5 was rewritten to say so.
2. **Three legal pages** — `/legal`, `/privacy`, `/terms` — public, crawlable,
   in all four languages, listed in `publicPages` so they reach the sitemap.
   Non-affiliation, what is and is not distributed, non-commercial status, and
   a takedown route that does not require a lawyer. New `web.contact_email`
   feeds the address; blank renders an explanation rather than a dead
   `mailto:`.
3. **Self-service account deletion** (`/account/delete`) — GDPR art. 17. Reuses
   `store.AccountRepo.DeleteAccount`, so the player path and the admin path can
   never diverge in what they erase. Two confirmations (password + typing the
   account name), blocked while impersonating and while the account is
   connected, and it clears the session afterwards.
4. **Non-affiliation notice in the footer of every page**, linking `/legal`.
5. **`serverName()` now falls back to "Arena Reborn", not "DofusArena"** —
   describing the game is referential use, adopting the mark as the site's own
   identity is not.

Two documentation errors found and fixed while doing this, both of which had
been trusted: this file claimed the README carried the mirror link in three
places ("top callout, comparison table, Step 2") when there was exactly **one**
raw URL, at `README.md:125`; and `DISCLAIMER.md`/`NOTICE` still described a
three-way committed / linked / neither split that no longer had a middle term.

**Still open, deliberately, and needing a maintainer decision:**

- **`server/data-dist/`** — 344 files, 2.96 MB of Ankama records, committed and
  in every release. "No art, audio or executable code" mitigates but does not
  answer it. Bring-your-own via `Discover()` is the defensible alternative and
  costs the zero-setup property. Not changed without an explicit call.
- **`client/decompiled/`** — EU Software Directive art. 6 protects decompiling
  *for interoperability*; it is weaker cover for publishing the output. Moving
  it to a private repo would cost nothing operationally. `client/analysis/`
  (our own notes) is unaffected either way.
- **`static/arena-bg*`** (6 files, ~645 KB) is game-world art and is the
  background of every page on the public site. Flagged; the maintainer chose to
  keep it.

**Web portal** (`internal/web`) — a full account site, no JS, no external assets, all
embedded in the binary. See [`WEB-PORTAL.md`](./WEB-PORTAL.md) for the page list, the
security model and the theme.

Public: landing, `/status` (totals only, no names), `/ladder`, sign in/up. Signed in:
`/account` shows every datum the server holds about you, plus a password change. Admin:
dashboard, searchable account list, per-account deep view, create/delete/grant-admin,
impersonation, and a monitoring page serving this process's own pprof profiles.

**The first account created becomes admin** (a release archive has no `seedaccount`, so
there must be some path to a GM); nothing else ever grants it implicitly — see B-090,
where logging in used to. Rate-limited per IP (separately for sign-up and sign-in),
same-origin checked, CSRF-tokened, HMAC-signed sessions, bcrypt via the existing store.
Port ladder: 80 → 8080 → 8090 → 3000 → 5000 → any free port, so it always starts even
unprivileged.

**Update check** (`internal/update`) — one anonymous GET of GitHub's `/releases/latest` at
startup; prints a notice if newer. Never downloads or installs. Silent on every failure
(offline servers must not be nagged). Skipped entirely on unstamped `dev` builds.

Open follow-ups, none blocking:

1. **Windows SmartScreen** warns on the unsigned `.exe`. Real fix is a code-signing
   certificate (paid) or [SignPath](https://signpath.org/) (free for OSS). Documented as a
   click-through in `docs/QUICKSTART.md` for now.
2. **No Docker image is published** on release. The `Dockerfile` still builds locally; only
   the binaries are automated.
3. **First release must be cut manually-ish**: `.release-please-manifest.json` starts at
   `0.0.0`, so the first `feat:` commit produces `v0.1.0`.

### e2e suite runtime

The wire suite runs **parallel** (`t.Parallel()` on every test) and takes ~15-20s, down from
~140s. Each test already had its own store, its own TCP port and its own server, so they were
independent in everything except two package-level globals in `internal/game`:

- `turnClock` - every test set it to the same 12s, so it is set ONCE in `TestMain` rather than
  per test. A per-test override is a data race the moment anything runs in parallel.
- `fusionRand` - the fusion tests seed it to *different* values on purpose (one to force a
  success, one a failure), so **`fusion_test.go` is deliberately NOT parallel** and says so at
  the top of the file. Sequential tests complete before the parallel phase resumes, which is
  what keeps that safe.

Verified with `-race` (clean) and six consecutive runs (no failures) before landing, because
the previous flakiness episode (B-126..B-129) came from tests that passed once.

The `-timeout 25m` in CI stays. It was a mitigation for a slow suite and is now enormous
headroom; removing it would only buy a worse failure mode on a loaded runner.