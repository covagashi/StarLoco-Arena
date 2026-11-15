# v2.70 server — Feature Status

Snapshot of what the from-scratch 2.70 server implements, as of the overnight
session. Verified against the **real retail client** through world entry +
movement; the features added afterwards are code-complete and unit-tested but
were **not run against the live client** (per instruction — no live server runs
overnight). Test them in the morning.

## Working end-to-end (confirmed with the real client earlier)

| Flow | Opcodes | Status |
|---|---|---|
| TCP connect + framing | — | ✅ |
| Client version handshake | 7 | ✅ |
| Ping / keepalive | 107 | ✅ (prevents "Too high ping" teardown) |
| Login (plaintext, no RSA) | 1025 → 1024 | ✅ |
| Coach creation screen | 2048 | ✅ |
| Coach creation submit | 2049 → 2050 | ✅ |
| Coach info | 2052 | ✅ (minimal coach) |
| Enter world / render lobby | 4600 | ✅ (worldId 85 = grassy intro island from the video, spawn in chunk 0_0 near Gostof/Baan; see docs/OVERWORLD-MAP.md) |
| GM `/WORLD` hop | 4600 | ✅ admin `/WORLD <id> [x y]` re-renders + syncs server position so movement works after hopping |
| Movement (walk) | 4501 → 4500 | ✅ echo + broadcast + persist |

## Added overnight (built + unit-tested, not yet live-tested)

| Feature | Opcodes | Status | Notes |
|---|---|---|---|
| **Persistence (SQLite)** | — | ✅ | Accounts (bcrypt) + coaches survive reconnect. No more re-creating the coach! Accounts auto-created on first login. |
| Existing-coach login | 2052 + lists + 2400 + 4600 | ✅ | `account.CoachID != nil` → full login; else creation prompt. |
| Vicinity chat | 3153 → 3152 | ✅ | Broadcast to all overworld coaches. |
| Private message / whisper | 3155 → 3154 | ✅ | Routed by name; UserNotFound(3204) fallback. |
| Friends add/remove | 3129 / 3133 | ✅ | Persisted; ack 3156/3160. |
| Ignore add/remove | 3131 / 3135 | ✅ | Persisted; ack 3158/3162. |
| Friend list | 3144 | ✅ | Populated from DB, with online flag. |
| Ignore list | 3146 | ✅ | Populated from DB. |
| Player statistics | 2400 | ✅ | 7 stat entries (play time, fights, W/L, strength, streak). |
| Coach cards inventory | 5200 / 5203 | ✅ | New coaches get 10 starter cards; inventory pushed at login. |
| Equip cards | 5201 | ✅ | 14 slots; equipment layout persisted. |
| Card exchange | 5101/5103/5111 | ⚠️ partial | Invite/accept/cancel flow works; **card transfer on completion deferred** (needs a re-validated tx to avoid dupes). |
| GM commands | (chat `/`) | ✅ | /HELP /WHERE /WHO /TP /STRENGTH — IsAdmin gated. |
| World presence | 4096 / 4098 | ✅ | ACTOR_SPAWN fan-out on join; despawn on leave. |
| Game data (`server/content`) | — | ✅ | 907 cards / 203 spells / 75 fighter cards / 53 summons and the other rules tables, the game's own since S40/S43, embedded. |
| **Fighter roster** | 6001/6003/6006 | ✅ | Create/delete/list with the et_2 codec; breed/name/spell validation; budget computed server-side; owner-scoped delete. |
| **Team presets** | 6021/6023/6030 | ✅ | Save/delete/list with the sw_1 codec; members scoped to owned fighters. |
| **Matchmaking** | 2301/23110/23114/2308 | ✅ | Opponent search → MatchFound → accept handshake; two coaches match + accept. |
| **Fight launch** | 26330/23103/26303 | ✅ live | TESTER (solo practice vs sparring), COMBATTRE (ready-room pairing), in-fight Prêt. |
| **Fight start** | 8000/8010–8104/4102 | ✅ live | CREATE_FIGHT blob + ACTOR_APPEAR render + full phase lifecycle → first turn. |
| **Combat** | 4503/8109/8120/4520/8300 | ✅ live | Move, spell cast w/ real spell data, breed+equipment-scaled HP/AP/MP, damage, death, END_FIGHT, stats. |

## Fight: what's done vs remaining

**Done + LIVE-VERIFIED against the retail 2.70 client:** the whole fight loop —
TESTER/COMBATTRE launch → EnterInstance(arena) → CREATE_FIGHT(8000) →
ACTOR_APPEAR(4102) → presentation → placement → observation → action →
NEW_TABLE_TURN(8100) → FIGHTER_TURN_BEGIN(8104) → move/cast → END_FIGHT(8300) →
result screen → back to lobby. Confirmed on-screen: real ice arena (world 5)
centred, both teams' fighters on the red/blue placement cells, coaches on their
flame pedestals, the top-left turn-order timeline strip, per-turn AP/MP/spell-bar
UI, and a damaging cast landing at the correct scale.

**8000 render — resolved:** the trailing `gV().f` fight-grid blob (`aoq_0.f`) +
the **ACTOR_APPEAR (4102)** message (which inserts the hidden fighter/coach
avatars into the iso render list) make the battlefield draw. EnterInstance x,y is
the arena centre (camera focus). Fighter/coach facing uses diagonal Direction8.

**Combat resolution — DONE + live-verified:**
- Fighter movement in fight (4503→4524) with MP spend (start-cell prefixed) and
  **server-side path validation** (`validateFightMove`): the move must start on
  the fighter's cell, step one adjacent cell at a time, stay on walkable arena
  cells (`arena.walkable`/`cellFlag`), fit within MP, and not enter another living
  fighter. Because the client pathfinds on the same grid the server streamed, a
  genuine path always passes — this rejects only forged moves (teleport, through
  void/obstacles, onto a fighter, no MP).
- Spell cast (8109→8110) using **real spell gamedata**: AP cost from the spell,
  and **data-accurate damage decoded from the spell's effect list** (the flat
  HP-loss/leech effects, action ids 1-5/6-10/130-134, `Spell.Damage()`) — NOT the
  spell's budget `value` field the old code wrongly used (e.g. Iop spell 4 now
  does its real 25, not 200). A utility spell (shield/buff/heal-only) has no
  flat-damage effect and correctly deals 0. AP debit (8120 id=91), HP-loss damage
  (8120 id=9, actual HP removed), flush (8200); 2.70 8120 layout (differs 2006).
  The 2.70 running-effect id map is transcribed in `gamedata/runningeffects.go`.
- **Spell targeting validation** (`spellTargetValid`, ported from the 2.04 server's
  `validateCast`): Manhattan range within `[RangeMin, RangeMax]` (RangeMax boostable
  by the caster's `Range` stat when >1), straight-line-only spells confined to the
  caster's row/column, and free-cell spells requiring an empty target. The spell
  range/flag fields were re-derived from raw bytes (range is at record fields 12/13,
  not 10/11; flags at 14/15/16 confirmed vs real data).
- **Spell line-of-sight** (`line_of_sight.go`): the 2.70 client's LoS is
  ALTITUDE-based (the `.dam` tile's visibility accessor `sl_1` exposes only a cell's
  altitude, unlike the 2.04 six-flag model), so it's reproducible from the arena's
  altitude topology we already have. Ported the client's ray test (`ahc_2.axq/axp`
  single-level reduction): both endpoints raised to eye height (+4 = ⌊0.8·6⌋), a
  ray sampled cell-by-cell, and an intermediate cell blocks iff its terrain rises
  above the ray's lowest altitude there (grazing = visible); tries eye→eye then
  eye→feet. Implemented TERRAIN-ONLY (skips the client's obstacle/creature
  occlusion), making our blocking a strict SUBSET of the client's — it can only
  ever miss a block, never reject a cast the client allowed. Live-checked geometry:
  a line over the arena's raised (9,7)=alt-10 cell is blocked; flat lines are clear.
- **Breed + equipment-scaled HP/AP/MP/init** (`breed.go` + `gamedata/fightercards.go`):
  a fighter's in-fight maxima = breed base (Feca 70, Iop 75, Sacrier 80, …; AP 6,
  MP 3) **plus** every equipped fighter-card's passive (FIGHTER_CARD_EQUIP)
  CharacBuff bonus, decoded from the type-250 records (action 11=HP, 13=AP,
  17=MP, 76=init). The client derives the exact same numbers from the equipped
  card ids the 8000 blob carries (it runs each card's equip effects on
  inventory-add), so server and client gauges stay in sync — previously HP was
  breed-base only, so a +40-HP card read 75 server-side but 115 on the client.
  The unknown-spell fallback damage is 15 (was 200, which one-shot 70-HP fighters).
- Death (4520) on HP→0; victory check; **END_FIGHT (8300)** with the 2.70
  two-strength-map-count layout; W/L stats persisted (skipped for practice).
- END_FIGHT_DONE (4321) → return to overworld. Give-up (8151) forfeit; disconnect
  teardown. AP/MP refill to each fighter's derived max (breed + card bonuses).
- **Practice-fight AI auto-pass:** the session-less sparring side auto-ends its
  turn on a short clock (`aiTurnClock` 1.2s) instead of dead-waiting the 30s
  human `turnClock`, so a TESTER fight flows without stalls.

**Remaining (combat depth):**
- Effect variety: damage is data-accurate, but still **single-target** and
  **damage-only** — heals (action 69, decoded via `Spell.IsHeal`), AP/MP
  steal (16/20/85/103), push/pull (37/38), buffs/debuffs and **areas/multi-target**
  are decoded-but-not-yet-resolved (need live client verification of the 8120
  wire for each). Move paths + full spell targeting (range/only-line/free-cell/
  line-of-sight) are validated (see above). LoS follow-ups: multi-level tiles
  (`ajc_2`/`ajj_2` with `aba` thickness + `aiT` transparency) and obstacle/creature
  occlusion (the client's `bE`) — both currently under-block (safe) on the flat
  single-level practice arena; and bit-exact supercover-DDA parity vs the client's
  `ahc_2` (the current sampler is a close single-level approximation).
- Non-stat card/equipment effects (damage %, resistances, range, crit — the
  other FIGHTER_CARD_EQUIP action ids) and coach-card passive bonuses on fighters.
- Active "action" cards played in-fight (max 3, once each) — FIGHTER_CARD_USE
  effects triggered on play.
- Bet/card stake transfer on win.
- Generalize arena loading (topology/.fmd parsed at runtime vs hardcoded world 5).
- **Card exchange transfer commit** (transactional, dupe-safe).
- Full coach serialization in 2052 (currently minimal).

### Scope note
A 1v1 fight is playable end-to-end **and confirmed live**: launch from the team
panel → place → move → cast a damaging spell (correct HP scale) → win/forfeit →
return to world. Depth (effect variety, stakes, card-HP) is the remaining combat
work. The 2006 server's full effect engine (~15 files) is the reference for
porting richer effects. **Note:** a fight must be launched via the real client
button (it registers the client-side fight handlers); the dev `/c2s` inject only
drives IN-fight messages.

## Run

```powershell
cd server
go build ./... ; go test ./...
go run ./cmd/seedaccount --login locos975 --password azerty --admin   # make your account admin
go run ./cmd/server                                                    # 127.0.0.1:5555
```

The game data is embedded (`server/content`). The DB file is
`arena.db` (git-ignored). Delete it to reset all accounts/coaches.

## Architecture

Layered, mirroring the proven 2006 server:
- `internal/protocol` — wire framing + big-endian read/write.
- `internal/handshake` — connection/coach/movement message codecs.
- `internal/domain` — GORM models.
- `internal/store` — SQLite + repositories.
- `internal/gamedata` — the game data tables, loaded from `server/content`.
- `internal/game` — router (opcode→handler map), Deps DI, session, world
  registry, exchange manager, `handlers_*.go` + `packets.go`.
- `cmd/server`, `cmd/seedaccount`.
