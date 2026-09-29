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
| `src/anims/` | `AnmSprite` — frames from `tools/asset-import/anm_render.py --export`; alpha-scan foot pivot, `draw_on()` for merged z-order |
| `src/fight/fight_view.gd/.tscn` | Fight scene: painted map, spawn zones, placement clicks, turns, move/spell targeting, nameplates + damage floats |
| `src/world/world_view.gd` | Overworld island: painted map, coach actors (4096), click-to-move (4501), chat bubbles, coach hit-test for challenges, **interactive-element markers** (200/206) with click → `201` |
| `src/ui/chat_box.*` | Chat panel: vicinity/whisper/trade/group/clan + server announcements, `/command` emotes (4701→4700), `/friend` `/ignore` social ops (3129/3131/3133/3135), world bubbles |
| `src/gamedata/spells.gd` | Breed spell tables + names (from `assets/gamedata/spells.json`) |
| `src/gamedata/elements.gd` | Env element kinds/labels (`assets/gamedata/elements.json`) — the wire 200 carries position only; kind comes from this table |
| `src/gamedata/cards.gd` | Card names/prices/values (`assets/gamedata/cards.json`) — shop + barter UI |
| `src/main.gd/.tscn` | Login/lobby UI over the island view; roster `6006`, presets `6030`, create/delete `6001`/`6003`, loadout `6011`/`6010`, team presets `6021`/`6023`/`6013`, challenge `26300`-family, combattre `23103`/`23101`, Card Master shop `5401`/`5450`/`5400`/`5403`, Zaap `4512`, graveyard `22099`, fusion `5490`/`5491`, demon ladder `27510`/`27511`, tournaments `17002`/`17003` + `28601`/`28602`, fireworks `22095`/`22094`, wallet `4001`, inventory `5200`, friend/ignore lists `3144`/`3146` + acks/presence `3156`-`3166` |
| `assets/anims/` | Generated sprite frames — **git-ignored**; regenerate with `tools/asset-import/anm_render.py --export` |
| `assets/mapgfx/` | Painted-map sprites + atlases — **git-ignored**; regenerate with `tools/asset-import/map_gfx.py` |
| `assets/gamedata/` | Derived tables — **git-ignored**; regenerate with `server/cmd/dumpspells` + `tools/asset-import/spell_names.py`, `server/cmd/dumpelements`, `server/cmd/dumpcards` + `card_names.py` |

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
godot --path godot -s test/fight_shot.gd -- 10 /tmp/arena.png   # offline map shot
```

The smoke drives the whole lifecycle on loop: login `test/test123` →
challenge 34 (overworld practice vs the AI "Démon de la 58ème minute") →
`4600` arena id → `8000` fight decode (teams/breeds/spells) → `4102` actor
placements → phase gates (`8011`/`8023`/`8031` on arch 3) → `8040` combat →
turn loop (`8100` round, `8104` begin, `4503` move / `8109`/`8111` casts,
`8105` end-turn, `8120` effects decoded to floating damage + AP/MP spend) →
`8151` surrender → `8300` end → `26321` ack → `4600` back to overworld →
repeat.

`world_smoke` also exercises: vicinity/whisper/trade chat (local echo +
`3214`/`3204` replies), fighter create `6000` + loadout `6010`, team
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
`17003`/`28602`, and a fourth (card 208) to world 26's firework launcher
→ `22095` → `22094` echo.

`pvp_smoke` runs the full two-coach loop: a second socket logs in as
`test2`, the main client challenges it (`26301`→`26300` both ways →
`26305` accept → `26302` → both confirm teams `26303`), the fight
spawns on both sockets and runs to surrender.

Fighter sprites: breed+sex → `Players/-XYZ.anm` via the client's
`zh_1.cdN` table (`-(100+breed*10+sex)`); anm directions are diagonal-only
{0,1,2,5,6} with 3/4/7 as horizontal mirrors (`gw_2.ao`).

## Known limits / next steps

- Spell casting `8109`→`8110` is verified live when a fighter owns spells
  (the smoke's loadout saves them first); weapon `8111` is the fallback.
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
