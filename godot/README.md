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
| `src/world/world_view.gd` | Overworld island: painted map, coach actors (4096), click-to-move (4501) |
| `src/main.gd/.tscn` | Login/lobby UI over the island view; decodes roster `6006` and presets `6030` |
| `assets/anims/` | Generated sprite frames — **git-ignored**; regenerate with `tools/asset-import/anm_render.py --export` |
| `assets/mapgfx/` | Painted-map sprites + atlases — **git-ignored**; regenerate with `tools/asset-import/map_gfx.py` |

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
godot --path godot -s test/world_smoke.gd      # island + roster decode
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

Fighter sprites: breed+sex → `Players/-XYZ.anm` via the client's
`zh_1.cdN` table (`-(100+breed*10+sex)`); anm directions are diagonal-only
{0,1,2,5,6} with 3/4/7 as horizontal mirrors (`gw_2.ao`).

## Known limits / next steps

- The test fighter owns no spells, so live casting exercises `8111`
  (weapon/close-combat); `8109` shares the wire path and is decoded (`8110`).
- Placement is click-a-spawn-cell (no drag preview like retail).
- Roster/presets decode is wired (`6006`/`6030`) but the UI is a text label.
- Headless runs can't screenshot (dummy driver); use a windowed run for
  `/tmp/fight_live.png`.
