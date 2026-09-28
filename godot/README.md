# godot/ — Godot 4 replacement client

A from-scratch DofusArena 2.70 client in GDScript (standard Godot 4.7 build —
no .NET), wire-compatible with the Go server in `server/` and the retail
protocol documented in `client/analysis/`.

## Run

```bash
godot --path godot                      # app: login form → lobby → fights
go run ./server/cmd/server              # serve on 127.0.0.1:5555
go run ./server/cmd/seedaccount --login test --password test123
```

## Layout

| Path | Role |
|---|---|
| `src/net/` | TCP framing (`[u16 len][u8 arch][u16 op][payload]`), cp1252, `WireReader/Writer`, schema `Codec` + `generated/` (from `tools/proto-gen`) |
| `src/net/arena_client.gd` | `ArenaClient` node — socket, frame reassembly, `pending` queue + `drain()` so packets arriving mid-scene-change aren't lost |
| `src/session.gd` | `Session` autoload — owns the persistent `ArenaClient`, registers it as `State.net` |
| `src/state.gd` | `State` static holder — `current_world`, `fight_world`, `fight_data`, `fighters`, `coach_ids`, `my_coach_id`, `net` |
| `src/maps/` | `.fmd` arena parser + world `.tplg` topology (little-endian chunks) |
| `src/anims/` | `AnmSprite` — plays frames exported by `tools/asset-import/anm_render.py --export` (`meta.json` + PNGs) |
| `src/fight/fight_view.gd/.tscn` | Iso fight view: cells, spawn zones, actors, phases, turns |
| `src/main.gd/.tscn` | Login/lobby UI |
| `assets/anims/` | Generated sprite frames — **git-ignored**; regenerate with `tools/asset-import/anm_render.py --export` |

## Verified live (test/fight_smoke.gd, real server)

```
godot --path godot -s test/fight_smoke.gd      # graphical (screenshot)
godot --headless --path godot -s test/fight_smoke.gd
```

The smoke drives the whole lifecycle on loop: login `test/test123` →
challenge 34 (overworld practice vs the AI "Démon de la 58ème minute") →
`4600` arena id → `8000` fight decode (teams/breeds) → `4102` actor
placements → phase gates (auto-ready `8011`/`8023`/`8031` on arch 3) →
`8040` combat → turn loop (`8100` round, `8104` begin — ours auto-passed
with `8105`, `4524` moves) → `8151` surrender → `8300` end → `26321` ack →
`4600` back to overworld → repeat.

Fighter sprites: breed+sex → `Players/-XYZ.anm` via the client's
`zh_1.cdN` table (`-(100+breed*10+sex)`); anm directions are diagonal-only
{0,1,2,5,6} with 3/4/7 as horizontal mirrors (`gw_2.ao`).

## Known limits / next steps

- Turns auto-pass — no interactive move/spell UI yet.
- `8120` effect payloads are received but not decoded (damage/HP display).
- Placement phase auto-accepts seed positions (no drag UI).
- Overworld is still the plain lobby UI — no `.dam` map rendering yet.
- Headless runs can't screenshot (dummy driver); use a windowed run for
  `/tmp/fight_live.png`.
