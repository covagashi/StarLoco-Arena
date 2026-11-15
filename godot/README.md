# godot/ — Godot 4 replacement client

A from-scratch client in GDScript (standard Godot 4.7 build — no .NET),
wire-compatible with the Go server in `server/`. Players see it as
**Pippop Arena**.

## Run

```bash
godot --path godot                      # app: login form → island → fights
go run ./server/cmd/server              # serve on 127.0.0.1:5555
go run ./server/cmd/seedaccount --login test --password test123
```

## Layout

| Path | Role |
|---|---|
| `src/net/` | TCP framing (`[u16 len][u8 arch][u16 op][payload]`), cp1252, `WireReader/Writer`, schema `Codec` + `generated/` (generated once by the removed `tools/proto-gen`; edit by hand) |
| `src/net/arena_client.gd` | `ArenaClient` node — socket, frame reassembly, `pending` queue + `drain()` so packets arriving mid-scene-change aren't lost |
| `src/session.gd` | `Session` autoload — owns the persistent `ArenaClient`, registers it as `State.net` |
| `src/audio/audio.gd` | `Audio` autoload — the Music and SFX buses, the two volumes (`gamePreferences` music*/ambianceSounds*, applied at startup and from Options) and the music track: `island` in the lobby, `fight` in combat, cross-faded across the scene change (sprints/S06) |
| `src/state.gd` | `State` static holder — worlds, `fight_data`, `fighters`, `roster` (6006), `presets` (6030), `breed_name` |
| `src/maps/` | `arena_layout.gd` — the arenas' own shapes (`art/shapes/`, `server/internal/gamedata/arenas/`) and kits |
| `src/anims/` | `fighter3d.gd` + `figure.gd` — our 3D fighters, coaches and summons (S35), toon shaders |
| `src/fight/fight_view.gd/.tscn` | Fight scene: the arena in 3D, placement, turns, move/spell targeting with range and AoE previews, nameplates, HP bars and floats, buff strip, timeline, summons, displacement, traps and auras, cast locks, round event cards, the S37 effect library |
| `src/world/world_view.gd` | Overworld island: painted map, coach actors (4096), click-to-move (4501), chat bubbles, coach hit-test for challenges, **interactive-element markers** (200/206) with click → `201` |
| `src/ui/chat_box.*` | Chat panel: vicinity/whisper/trade/group/clan + server announcements, `/command` emotes (4701→4700), `/friend` `/ignore` social ops (3129/3131/3133/3135), world bubbles |
| `src/fx/vfx.gd` | S37 effect library: 9 shapes × 5 elements drawn in code (CPUParticles2D + `_draw` rings), one recipe per spell; sheet via `tools/fx/vfx_sheet.sh` |
| `src/gamedata/spells.gd` | Breed spell tables (`assets/content/spells.json`); names are ours (`OwnText`); each spell's `fx` effect recipe (S37) |
| `src/gamedata/elements.gd` | Element kinds/labels (`assets/content/elements.json`) — the wire 200 carries position only; kind comes from this table |
| `src/gamedata/cards.gd` | Card prices/values (`assets/content/cards.json`) — shop + barter UI |
| `src/gamedata/kanodo.gd` | Sphere boards (`assets/content/spheres.json`) — client-faithful `reachable()` mirror |
| `src/gamedata/effects.gd` | Timed/infinite effect records (`assets/content/effects.json`) — `effectId → {a: action, d: turns, i: infinite, p: params}`; the wire never carries duration so the fight buff strip resolves it here, and `p[0]` tells dispel which buffs to strip |
| `src/gamedata/areas.gd` | Static-effect (type-210) trap/glyph templates (`assets/content/areas.json`) — `templateId → {t: TRAP/SPECIAL, s: shape, z: sizes, m: maxExec, w: walkOn, e: innerEffectIds}` + `footprint()`/`footprint_cells()` — the server `pointInArea` shapes ported in full (point/circle/cross/ring/square/T/inverted-T/point-list), also backing the armed-spell **AoE preview** (spell/card `zn` zones tint the cells a hover-cast would hit) |
| `src/gamedata/npcdialogs.gd` | NPC dialog trees (`assets/content/npcdialogs.json`): reply rows run `act` (`26330` défi with the challenge's own mode / `22003` criterion) then navigate `next` (0 closes); texts are ours (`OwnText`) |
| `src/gamedata/scenarios.gd` | Kanojedo tutorial scripts (retail `scripts/scenario/<id>.lua` fired by kind-8 ZoneTriggers) — reduced to ordered content.29 monologue pages + optional `22003` criterion reports and a zaap follow-up page |
| `src/ui/kanodo_board.gd` | Kanodo board renderer — `_draw()` graph (~90×90 cells), cursor ring, owned fill, lit frontier |
| `src/main.gd/.tscn` | Login/lobby UI over the island view; roster `6006`, presets `6030`, create/delete `6001`/`6003`, loadout `6011`/`6010`, team presets `6021`/`6023`/`6013`, challenge `26300`-family, combattre `23103`/`23101`, Card Master shop `5401`/`5450`/`5400`/`5403`, Zaap `4512`, graveyard `22099`, fusion `5490`/`5491`, demon ladder `27510`/`27511`, tournaments `17002`/`17003` + `28601`/`28602` + register `4607`/`28608` + opponent search `28611`→`28612`/`28616`/`28648` + period `28630`, bracket `28649`→`28650` (entrants only) rendered into the pane's second list on row select, fireworks `22095`/`22094`, wallet `4001`, inventory `5200`, coach equipment `5201`/`5203` (14-slot pane, type→slot map), coach statistics `2401`/`2400` → `State.coach_stats` + "Coach" pane (fights, wins/losses, streaks, play time, win rate), achievement-unlock toasts (`22000` → bottom-centre card stack, hidden gated, name/pts from `npcdialogs.gd`), friend/ignore lists `3144`/`3146` + acks/presence `3156`-`3166`, guild create `509`/`504` + record/membership/roster `510`/`552`/`512` + tags `554` + feeds `558`/`560`, demon affiliation offering `5470`→`5403`, mailbox `15000`→`15001` + take `15006`/`15007` + delete `15004` + `/mail` compose `539`→`15003` + notice `15005`, player trade `/trade` `5101`→`5102`/`5104` + stage `5105`/`5110` + unstage `5107`/`5112` + ready `5109`/`5116` + cancel `5111` + end `5114` + error `5113`, Kanodo sphere board `23009` (evolution fighters only — optimistic buy, retail `awu_0`), 2v2 duo `6024` invite → `6025`/`6026` → `6028` + duo preset `type=-6` launched via `23103` with ally claim, spectate `/watch <coach>` `2260`→`2261` + join `26331` (fight resync replayed to the spectator socket) + teardown `26332` + read-only fight view, mid-fight reconnect `26333` question → `26334` answer → resync replay, quick-search "Search" `2301`→`2304` + cancel `2303`→`2306` + pending-match confirm `23110` → accept `23114` / decline → `23116`, evolution queue "Evo" `23003`→`23004` + cancel `23001`→`23002` + starting `23006` + refused `23008`, rankings window ("Ranks") — seven ladder tabs `27500`-`27514` → `27501`/`27503`/`27505`/`27507`/`27509`/`27513`/`27515` with windowed paging plus an Achievements tab (`22001`→`22002`): retail `qy_2` filtering (hidden / superseded / chain-locked rows dropped), done-first sorting, per-row ✓ or averaged progress %, points total, named criteria tail (content.37 names / content.49 descriptions / content.48 criterion labels from `npcdialogs.gd`), row select shows the description + per-condition progress, clan panel ("Clan") — member list `517` refresh, invite `501`→`502`/`503` (arch 8), member stats `2600`→`2601`, rank CRUD `553`/`555`/`557`, promote/demote `515`, leave/kick `505`, disband `511`, right-gated buttons, world elements — NPC talkers (kind 15, record-1500 trees via `npcdialogs.gd`: criterion-gated entry group, reply navigation, `26330` défi with the challenge's own `Qu()` mode, `22003` criterion rows), défi pickers (kind 3 `uk_0`), DemonChallenge accept/refuse bubbles (kind 7 `pn_0`, achievement-278 gate), paged demon monologues (kinds 6 `acn_0` / 9 `aac_2`, first-contact criterion 210, gates 275/276/277/284 evaluated client-side from type-800 data), zone triggers (kind 8 `oq` — cell-entry from walk steps and `4510` actor teleports, achievement-gated, once-per-session, queued scenarios rendered from `scenarios.gd`) |

## Assets

`assets/` holds only our own `ui/`, `i18n/`, `audio/` and `content/` (the
tables `server/cmd/exportclient` builds from `server/content`; rerun it after
a content change, `TestClientDataUpToDate` fails until you do). Since S43 the
client reads nothing from the retail client; `run_tests.sh` guards it.

## Verified live (test/*_smoke.gd, real server)

```bash
godot --path godot -s test/fight_smoke.gd      # graphical (screenshots)
godot --headless --path godot -s test/fight_smoke.gd
godot --headless --path godot -s test/world_smoke.gd   # S05 audit: every hall service via the lobby City panel
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

`world_smoke` is the S05 service audit (rewritten 2026-10-17; the old hall
walk died with the deprecated hall). It logs in, presses the lobby's
**City** menu button and presses every service button the panel lists, then
checks the evidence each one leaves: Card Master `201`→`5401` +
`cardMasterDialog`, mailbox `15000`→`15001` + `mailboxDialog`, graveyard /
challenge / demon panes, fusion and firework dialogs, demon totem
`27510`→`27511`, tournament totem `17002`→`17003` (+ `28601`→`28602`). The
panel merges the services of every island and the coach never travels (the
game has a lobby, not worlds): the server resolves each `201` in any world.
One `[audit]` line per service; exit 0 only if all pass (57 checks).
`--shot-dir=D` (under `xvfb-run`) saves the lobby, the City panel and a Card
Master.

What the old hall smoke also drove — chat, fighter creation and loadout,
presets, the ranked queues, social and guild commands, mail compose and
take, tournament registration and bracket (`28649`), the rankings tabs,
the NPC défi fight (`26330` → `8000`) — is **not** re-covered by it; see
`sprints/S05-lobby-services.md`.

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
