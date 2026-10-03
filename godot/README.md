# godot/ — Godot 4 replacement client

A from-scratch DofusArena 2.70 client in GDScript (standard Godot 4.7 build —
no .NET), wire-compatible with the Go server in `server/` and the retail
protocol documented in `client/analysis/`.

## Run

```bash
godot --path godot                      # app: login form → island → fights
go run ./server/cmd/server              # serve on 127.0.0.1:5555
go run ./server/cmd/seedaccount --login test --password test123
```

## Layout

| Path | Role |
|---|---|
| `src/net/` | TCP framing (`[u16 len][u8 arch][u16 op][payload]`), cp1252, `WireReader/Writer`, schema `Codec` + `generated/` (from `tools/proto-gen`) |
| `src/net/arena_client.gd` | `ArenaClient` node — socket, frame reassembly, `pending` queue + `drain()` so packets arriving mid-scene-change aren't lost |
| `src/session.gd` | `Session` autoload — owns the persistent `ArenaClient`, registers it as `State.net` |
| `src/state.gd` | `State` static holder — worlds, `fight_data`, `fighters`, `roster` (6006), `presets` (6030), `breed_name` |
| `src/maps/` | `.fmd` arena parser, world `.tplg` topology, `map_gfx.gd` — retail painted-map renderer |
| `src/anims/` | `AnmSprite` — frames from `tools/asset-import/anm_render.py --export`; `xps_fx.gd` — spell `.xps` bursts (one `CPUParticles2D` per emitter with per-emitter `startSpawnTime`/`endSpawnTime` windows, + `xps_index.json` / `assets/fx/<textureId>.png`, approximate — see B-167) and `avw_0` ballistic tween projectiles (`spawn_projectile` + `arrived` for `tw#i+k` impact rows; `pick_id` resolves direction-keyed ids by caster Direction8); alpha-scan foot pivot, `draw_on()` for merged z-order, one-shot gestures (`play_once` + `hold_last` + `action_finished`), `meta.sfx` sound triggers (`Sons<id>` parts → `assets/sounds/<id>.ogg`, round-robin pool) and `meta.scr` script triggers (`pb_1` runScript parts → `scripts/anm/<id>.lua` resolved via `assets/gamedata/anm_scripts.json` — `playLocalSound` ids at their authored gain, `playLocalRandomSound` picked uniformly from its (id, gain) pairs, `stopOnAnimationChange` players killed on the next `load_action`; `playBark`/`playGroundSound` scripts resolve to nothing and are skipped). Player gestures live in `fighter_<file>` sets: retail splits them into skeletal tracks (`AnimSort_<breed>`, `AnimCombat`, `AnimCommunes`, `AnimEmotes*`) retargeted onto the body via label CRCs — `--composite <actor.anm>` bakes them (casts per spell, `AnimHit`/`AnimMort`, `AnimKO-Debut`→`Boucle`, `AnimTacle`, `AnimCarte`, `AnimMarche`/`Course`/`Saut`, emotes) |
| `src/fight/fight_view.gd/.tscn` | Fight scene: painted map, spawn zones, placement clicks, turns, move/spell targeting, nameplates + HP bars (max HP from the breed stat table / summon template — the wire only carries damage taken) + damage/stat/state floats (±AP/MP/HP, elemental res/dmg buffs, Rooted/Invisible/Petrified…, dispel clears the invisibility fade), cast-name floats with the 8110/8112/8108 critical flag ("critical! <spell>"), hover walk preview (dots along the BFS path + "N MP" cost label, red once it exceeds MP left), turn-clock countdown in the TopBar (30s server `turnClock`, red under 6s — also runs the 30s placement window), buff strip — a chip line under each nameplate fed by 8120 timed effects + 8121 resync attaches, counting down per table turn and stripping on dispel, turn timeline (8000 initiative order — team-tinted chips, acting fighter highlighted, dead dimmed, click centres the camera), mid-fight summons (8120 action 67/75/97 spawn the creature from the type-300 template — name via content.10, stats for the plate, timeline slot right after the caster, AI-driven so never ours to control), mid-fight displacement (8120 actions 37/38/39/58/59/64/153 — push/pull/teleport/swap/carry/throw, part-3 destination, carry links that follow the carrier and break on walk/death/throw, the cargo riding at carrier-offset and snapping back to its own cell when the link breaks, and the retail Porte pose family on carrier breeds (ee_2 `ls("Porte")` gesture-bank swap — Anim01Porte lift, AnimStatiquePorte/AnimMarchePorte while holding, Anim02/03Porte release by landing distance, AnimHitPorte/AnimTaclePorte/AnimPorte-Mort/AnimPorte-KO-* under hit/tackle/death), and the retail cast-range overlay (arming a spell/card/weapon tints Manhattan-range cells — bright where the server's full cast gate passes: walkable, only-line, altitude LoS, free-cell, target mask), special battlefield cells (`_fmd.specials` — lettered colour-coded diamond markers for templates 1002–1009: killer cell, trap, eagle eye, shield, panacea, enthusiasm, motivation, healing heart), 6200 area-action feedback (floats the tile's name over the fighter who entered), and placed effect areas (8120 action 66 trap/glyph on a cell + 176 caster aura — footprint tinted from the type-210 template, hidden while the caster is invisible per aew_1, one-shot traps drop after their inner-effect fire is attributed, auras track the caster's live cell and age per table turn), spell cast locks (dumpspells `lk`/`cd`/`mpt`/`mptt` — the client's own sH history: greyed buttons on cooldown/per-turn cap, overlay dims per-target-capped cells, fumbles count), and AoE cast preview (`zn` zones tint the aimed footprint while a spell/card is armed). Combat gestures: sprites resolve per-fighter (`look` → `npc_*`/`fighter_*` summon anms, breed/sex fighter file, coach fallback) — `AnimMarche` walks, `AnimHit` on damage, `AnimMort` held on death, casts try `AnimSort-<slugged French name>` → `AnimSort-Cast`/`AnimCast` (NPC summon anms carry rasterized gestures; player gestures come from the composited `fighter_<file>` bake — `AnimSort_<breed>`/`AnimCombat`/`AnimCommunes` skeletal tracks retargeted onto the body, falling back to idle only when the bake is absent), the fight-info chat channel mirrors retail's `fight.*` lines (spell cast / card use / close combat / tackled / death, with crit/miss markers), and a fighter's death chains `AnimMort` → or `AnimKO-Debut`→`AnimKO-Boucle` when the set lacks it. Round event cards (`8100` tail `f3` → type-230, named from `content.8`) collect in a top-right strip (retail's `fight.eventCards` binding, newest highlighted, max 4). The Lua script layer is also reproduced: casters face the aimed cell (`setMobileLookAt` → Direction8 snap — cast/card/weapon), crit/fumble zooms the camera onto the attacker↔target midpoint at 1.4× and restores (re_0), weapon cards (scripts 8000–8007, via `fightercards.json` `script`) and the unarmed `8111` punch play the per-family armed gesture `AnimStatique03(-Debut)-<fam>` composited from `animations/Players/Anim*.anm` banks onto every `fighter_*` set, the scripts' `Sound.playSound` events (`assets/gamedata/spell_sfx.json`, per `tools/asset-import/spell_sounds.py`) fire on the caster's sprite pool at their `invoke()` delays, and the 2 summon templates carrying a death `particle` id (type-300 field 17 — `.xps` unrendered) dissolve instead of greying
| `src/world/world_view.gd` | Overworld island: painted map, coach actors (4096), click-to-move (4501), chat bubbles, coach hit-test for challenges, **interactive-element markers** (200/206) with click → `201` |
| `src/ui/chat_box.*` | Chat panel: vicinity/whisper/trade/group/clan + server announcements, `/command` emotes (4701→4700), `/friend` `/ignore` social ops (3129/3131/3133/3135), world bubbles |
| `src/gamedata/spells.gd` | Breed spell tables + names (from `assets/gamedata/spells.json`) + script-driven cast sfx (`assets/gamedata/spell_sfx.json`) and particle fx (`assets/gamedata/spell_fx.json` — `Particle.addParticleSystem`/`addTweenParticleSystem` ids + `invoke()` delays incl. `time+k` arrival rows and direction-keyed ids, from `tools/asset-import/spell_sounds.py`'s Lua mini-evaluator) |
| `src/gamedata/elements.gd` | Env element kinds/labels (`assets/gamedata/elements.json`) — the wire 200 carries position only; kind comes from this table |
| `src/gamedata/cards.gd` | Card names/prices/values (`assets/gamedata/cards.json`) — shop + barter UI |
| `src/gamedata/kanodo.gd` | Sphere boards (`assets/gamedata/spheres.json`, from `server/cmd/dumpspheres`) — client-faithful `reachable()` mirror |
| `src/gamedata/effects.gd` | Timed/infinite effect records (`assets/gamedata/effects.json`, from `server/cmd/dumpeffects`) — `effectId → {a: action, d: turns, i: infinite, p: params}`; the wire never carries duration so the fight buff strip resolves it here, and `p[0]` tells dispel which buffs to strip |
| `src/gamedata/areas.gd` | Static-effect (type-210) trap/glyph templates (`assets/gamedata/areas.json`, same exporter) — `templateId → {t: TRAP/SPECIAL, s: shape, z: sizes, m: maxExec, w: walkOn, e: innerEffectIds}` + `footprint()`/`footprint_cells()` — the server `pointInArea` shapes ported in full (point/circle/cross/ring/square/T/inverted-T/point-list), also backing the armed-spell **AoE preview** (spell/card `zn` zones tint the cells a hover-cast would hit) |
| `src/gamedata/npcdialogs.gd` | NPC talker trees (`assets/gamedata/npcdialogs.json`, from `server/cmd/dumpnpcdialogs` + `tools/asset-import/npc_dialogs.py`) — record 1500 groups: speech (content.59) + reply rows (content.60), click runs `act` (`26330` défi with the challenge's own mode / `22003` criterion) then navigates `next` (0 closes) — client `ni_0`/`ao_2` model |
| `src/gamedata/scenarios.gd` | Kanojedo tutorial scripts (retail `scripts/scenario/<id>.lua` fired by kind-8 ZoneTriggers) — reduced to ordered content.29 monologue pages + optional `22003` criterion reports and a zaap follow-up page |
| `src/ui/kanodo_board.gd` | Kanodo board renderer — `_draw()` graph (~90×90 cells), cursor ring, owned fill, lit frontier |
| `src/main.gd/.tscn` | Login/lobby UI over the island view; roster `6006`, presets `6030`, create/delete `6001`/`6003`, loadout `6011`/`6010`, team presets `6021`/`6023`/`6013`, challenge `26300`-family, combattre `23103`/`23101`, Card Master shop `5401`/`5450`/`5400`/`5403`, Zaap `4512`, graveyard `22099`, fusion `5490`/`5491`, demon ladder `27510`/`27511`, tournaments `17002`/`17003` + `28601`/`28602` + register `4607`/`28608` + opponent search `28611`→`28612`/`28616`/`28648` + period `28630`, bracket `28649`→`28650` (entrants only) rendered into the pane's second list on row select, fireworks `22095`/`22094`, wallet `4001`, inventory `5200`, coach equipment `5201`/`5203` (14-slot pane, type→slot map), coach statistics `2401`/`2400` → `State.coach_stats` + "Coach" pane (fights, wins/losses, streaks, play time, win rate), achievement-unlock toasts (`22000` → bottom-centre card stack, hidden gated, name/pts from `npcdialogs.gd`), friend/ignore lists `3144`/`3146` + acks/presence `3156`-`3166`, guild create `509`/`504` + record/membership/roster `510`/`552`/`512` + tags `554` + feeds `558`/`560`, demon affiliation offering `5470`→`5403`, mailbox `15000`→`15001` + take `15006`/`15007` + delete `15004` + `/mail` compose `539`→`15003` + notice `15005`, player trade `/trade` `5101`→`5102`/`5104` + stage `5105`/`5110` + unstage `5107`/`5112` + ready `5109`/`5116` + cancel `5111` + end `5114` + error `5113`, Kanodo sphere board `23009` (evolution fighters only — optimistic buy, retail `awu_0`), 2v2 duo `6024` invite → `6025`/`6026` → `6028` + duo preset `type=-6` launched via `23103` with ally claim, spectate `/watch <coach>` `2260`→`2261` + join `26331` (fight resync replayed to the spectator socket) + teardown `26332` + read-only fight view, mid-fight reconnect `26333` question → `26334` answer → resync replay, quick-search "Search" `2301`→`2304` + cancel `2303`→`2306` + pending-match confirm `23110` → accept `23114` / decline → `23116`, evolution queue "Evo" `23003`→`23004` + cancel `23001`→`23002` + starting `23006` + refused `23008`, rankings window ("Ranks") — seven ladder tabs `27500`-`27514` → `27501`/`27503`/`27505`/`27507`/`27509`/`27513`/`27515` with windowed paging plus an Achievements tab (`22001`→`22002`): retail `qy_2` filtering (hidden / superseded / chain-locked rows dropped), done-first sorting, per-row ✓ or averaged progress %, points total, named criteria tail (content.37 names / content.49 descriptions / content.48 criterion labels from `npcdialogs.gd`), row select shows the description + per-condition progress, clan panel ("Clan") — member list `517` refresh, invite `501`→`502`/`503` (arch 8), member stats `2600`→`2601`, rank CRUD `553`/`555`/`557`, promote/demote `515`, leave/kick `505`, disband `511`, right-gated buttons, world elements — NPC talkers (kind 15, record-1500 trees via `npcdialogs.gd`: criterion-gated entry group, reply navigation, `26330` défi with the challenge's own `Qu()` mode, `22003` criterion rows), défi pickers (kind 3 `uk_0`), DemonChallenge accept/refuse bubbles (kind 7 `pn_0`, achievement-278 gate), paged demon monologues (kinds 6 `acn_0` / 9 `aac_2`, first-contact criterion 210, gates 275/276/277/284 evaluated client-side from type-800 data), zone triggers (kind 8 `oq` — cell-entry from walk steps and `4510` actor teleports, achievement-gated, once-per-session, queued scenarios rendered from `scenarios.gd`) |
| `assets/anims/` | Generated sprite frames — **git-ignored**; regenerate with `tools/asset-import/anm_render.py --export` (plain sets) and `--composite <actor.anm>` (fighter gestures: `animations/Players/AnimSort_<breed*10>.anm` + `AnimCombat`/`AnimCommunes`/`AnimEmotes<Male|Femele>.anm` + the weapon banks `Anim{Epee1,Dague1,Arc,Baguette,Marteau,Pelle,Poings}.anm` — the latter add `AnimStatique03(-Debut/-Boucle/-Fin)-<fam>` armed gestures over each `animations/Players/<file>.anm` → `fighter_<file>`) |
| `assets/sounds/` | Combat sfx (`<id>.ogg` from `contents/sounds.jar`) — **git-ignored**; extracted for the `Sons<id>` ids referenced by `meta.sfx`, the `Sound.playSound` ids in `spell_sfx.json`, and the `playLocalSound`/`playLocalRandomSound` ids in `anm_scripts.json` |
| `assets/mapgfx/` | Painted-map sprites + atlases — **git-ignored**; regenerate with `tools/asset-import/map_gfx.py` |
| `assets/fx/` | Particle textures (`<id>.png` from sfx.jar `particles/<id>.tga` via `tools/asset-import/xps_dump.py`) — **git-ignored** |
| `assets/gamedata/` | Derived tables — **git-ignored**; regenerate with `server/cmd/dumpspells` + `tools/asset-import/spell_names.py`, `server/cmd/dumpelements`, `server/cmd/dumpcards` + `card_names.py`, `server/cmd/dumpspheres`, `server/cmd/dumpnpcdialogs` + `tools/asset-import/npc_dialogs.py`, `server/cmd/dumpeffects`, `tools/asset-import/spell_sounds.py` (spell script sfx → `spell_sfx.json`, anm script sfx → `anm_scripts.json`, spell script particles → `spell_fx.json`), `tools/asset-import/xps_dump.py` (→ `xps_index.json` + optional per-id JSON under `xps/`) |

## Retail map art

`maps/gfx/<world>.jar` chunks decode through `elements.lib` → `gfx/<id>.tgam`
atlases (magic `MAGT`/`mAGT`, LE u16 w/h + BGRA rows padded to power-of-two).
`map_gfx.py` exports `assets/mapgfx/<world>.json` (sprite pos/uv/zkey) + PNG
atlases; `map_gfx.gd` draws them sorted by the retail render key
`(y+131071)<<32 | (x+131071)<<14 | intra`, with live actors merged into the
same stream (intra 8191) so props occlude them correctly. Missing art falls
back to the volumetric topology renderer.

## Verified live (test/*_smoke.gd, real server)

```bash
godot --path godot -s test/fight_smoke.gd      # graphical (screenshots)
godot --headless --path godot -s test/fight_smoke.gd
godot --path godot -s test/world_smoke.gd      # island + roster + chat + presets + emote + combattre
godot --path godot -s test/pvp_smoke.gd        # two-client challenge → real PvP fight
godot --headless --path godot -s test/summon_smoke.gd  # mid-fight summon: breed-2 fighter + spell 51 → real cast → 8120 spawn
godot --headless --path godot -s test/displace_smoke.gd # displacement: teleport 12 / push 67 / swap 135 → 8120 moves the sprites
godot --headless --path godot -s test/carry_smoke.gd  # carry/throw: breed-12 spells 126+132 → Porte anim family + ride/drop links
godot --headless --path godot -s test/ping_smoke.gd   # keepalive 107→108 (66s)
godot --path godot -s test/fight_shot.gd -- 10 /tmp/arena.png   # offline map shot
```

The smoke drives the whole lifecycle on loop: login `test/test123` →
challenge 34 (overworld practice vs the AI "Démon de la 58ème minute") →
`4600` arena id → `8000` fight decode (teams/breeds/spells) → `4102` actor
placements → phase gates (`8011`/`8023`/`8031` on arch 3) → `8040` combat →
turn loop (`8100` round, `8104` begin, `4503` move / `8109`/`8111` casts,
`8105` end-turn, `8120` effects decoded to floating damage + AP/MP spend) →
`8151` surrender → `8300` end (decoded — winner/loser strength maps, won
cards, per-fighter OW debrief — rendered as the result panel on re-entry,
and its morale/tiredness/xp/dead fields applied back onto the roster
entries like retail `adY.dz`) → `26321` ack → `4600` back to overworld →
repeat.

`world_smoke` also exercises: vicinity/whisper/trade chat (local echo +
`3214`/`3204` replies), the real mailbox (`15000`→`15001` list → `15006`
take → `15007`, `15004` delete, `/mail` compose → `539`→`15003` echo),
fighter create `6000` + loadout `6010`, team
preset save `6021` (or `6020` status 25 on a name clash) + assign `6013` +
delete `6023`, an emote round-trip `4701`→`4700`, the ranked queue
`23103`→`23104`→cancel `23101`→`23102`, **element AoI** (`200` spawn on
entry + walking to a Card Master's chunk → `201` → `5401` catalogue →
`5450` buy → `5403`), wallet `4001` + inventory `5200`, and the social
flow (`/friend` `3156`, `/ignore` `3158`, removes `3160`/`3162`, ghost
`3204`, `/friends` `/ignored` list echoes), and the element dialogs:
mailbox + graveyard + fusion altar panes on island 25, then a Zaap hop
(`4512` card 255) to world 37 — demon totem `27510`→`27511`, another hop
(card 254) to the demon islet for the challenge bubble (`26330` ready),
a third hop (card 256) to the tournament islet for `17002`/`28601` →
`17003`/`28602` + a real registration `4607`→`28608` (persisted in
`tournament_registrations`) + the "Find opponent" `28611`→`28612`
ready-up, and a fourth (card 208) to world 26's
firework launcher → `22095` → `22094` echo. It also creates a guild via
`/guild <name>` (`509`→`504` + `558` feed), and at the demon totem the
"Offer cards" basket sends `5470`→`5403` — verified in SQLite
(`guilds.demon_id`, `guild_demon_reputations`). The rankings window is
paged tab-by-tab: `27500`→`27501` (real 1v1 rows + my rank), `27508`→
`27509`, `27504`→`27505`, `27502`→`27503` (real guild rows), `27506`→
`27507`, `27514`→`27515`, and `27512`→`27513` demons 1-12 then 13-24 via
"More". The run ends with a GM `/world` tour of the NPC/demon elements:
world 37 Demon I (kind 9, paged monologue) + a DemonChallenge bubble
(kind 7), world 35 `/tp` cell tour over the kind-8 ZoneTriggers
(scenario 100's 11-page new-coach monologue + criterion `221`, the
Class Masters and Demon III teasers — queued so overlapping zones play
in order) followed by Demon III itself (kind 6 — first contact reports
criterion `210` via `22003`, then pages the intro), and world 85's Baan
(kind 15, record-1500 tree) whose défi reply launches `26330` with the
challenge's own mode → `8000` fight → surrender → `8300` → `26321`.

`pvp_smoke` runs the two-coach trade + fight loop: a second socket logs
in as `test2`, the main client trades with it first (`5101` invite → bot
`5102` → `5103` accept → `5104` 3 → both stage via `5105`/`5110` → both
ready `5109`/`5116` → `5114` commit — verified in `coach_cards`), then
challenges it (`26301`→`26300` both ways → `26305` accept → `26302` →
both confirm teams `26303`), the fight spawns on both sockets and runs
to surrender. A third socket (`test3`, coach auto-created on first
login) then spectates: `2260` query → `2261` → `26331` join → `8000`
resync → live `8300` → `26321` ack → back to overworld. Between the duo
and the trade the guild phase runs: `501` invite → bot `502` → `503`
accept → `504`/`510`/`552`/`512` pushes, `2600`→`2601` member report,
rank add `553` → modify `555` → promote/demote `515` → kick `505` (bot
`504`=402 + `556`) → rank delete `557`.

Fighter sprites: breed+sex → `Players/-XYZ.anm` via the client's
`zh_1.cdN` table (`-(100+breed*10+sex)`); anm directions are diagonal-only
{0,1,2,5,6} with 3/4/7 as horizontal mirrors (`gw_2.ao`).

## Known limits / next steps

- Spell casting `8109`→`8110` is verified live when a fighter owns spells
  (the smoke's loadout saves them first); weapon `8111` is the fallback.
- Equipment actives `8107`→`8108` (the fighter's weapon card) are verified
  live — `fight_smoke` fires card 1 at a seeded equipped fighter.
- Placement is click-a-spawn-cell (no drag preview like retail).
- Challenge/coach interactions need a second client — `pvp_smoke` brings
  its own bot.
- Most island Card-Master stock is **barter-only** (zero token price in
  retail data — the server refuses `5450` with code 2); the Exchange pane
  (`5400` card-for-card by summed value) covers it.
- Graveyard `22099` and fusion `5490`→`5491` verified end-to-end on the
  seeded test coach (a dead evolution fighter + resurrection card 305,
  and tradable same-set pairs); without the seed the smoke skips them.
- World 37 is an archipelago: its islets connect only via Zaap cards —
  matching retail (the tournament islet is teleport-access only).
- Headless runs can't screenshot (dummy driver); use a windowed run for
  `/tmp/fight_live.png`.
