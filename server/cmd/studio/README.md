> **2026-10-25 — partly dead.** This was `tools/README.md`, moved here in
> sprint S32 when `tools/` was removed. Everything below that reads the
> retail client's `.jar`s (jar browser, sprites, `.sba` player, map art) stopped
> working when `client/` was deleted; the data tables over `server/data-dist/`
> still work. Paths like `go-server/` are from an older layout (today:
> `server/`).

# DofusArena2-06 Data & Asset Studio (`tools/`)

A cross-platform (Linux / macOS / Windows) desktop GUI for **browsing, visualizing,
editing, and exporting** every DofusArena2-06 data file and client asset: maps,
breeds/classes, spells, cards, items, summonings, static effects, events — plus the
sprite/animation/GUI/particle/audio assets shipped inside the client `.jar`s.

> **Status:** ✅ **All 8 phases (0–7) implemented and tested against the real
> data/assets.** The app is a Wails desktop binary; its Go backend lives in
> `go-server/cmd/studio` (inside the server module so it reuses the proven
> parsers) and its web frontend under `go-server/cmd/studio/frontend`. This file
> documents what was built and how to run it.

## How to run / build

```powershell
# One-time: install the Wails CLI (needs Go + Node) and add GOPATH\bin to PATH
go install github.com/wailsapp/wails/v2/cmd/wails@latest
$env:PATH += ";$(go env GOPATH)\bin"

# From go-server/cmd/studio:
wails dev      # hot-reload dev mode
wails build    # produce a native binary in build/bin/dofusarena-studio(.exe)

# Backend tests (parsers, decoders, encoders, export pipeline):
#   run from go-server/
go test ./cmd/studio/...
```

The app auto-detects the repo's `data/` and `client-compiled/` folders; override
them from the Overview page.

### What shipped per phase
| Phase | Delivered | Verified against real data |
|-------|-----------|----------------------------|
| 0 | Wails shell, dark theme, nav, path auto-detect | app builds on all 3 OS targets |
| 1 | Spells/Cards/Summonings/StaticEffects/Events tables + effects drawer | 138 spells, 181+127 cards, 10/10/27 others |
| 2 | Jar browser (zip), PNG/text preview, extract | 9 jars, gui.jar 1060 entries |
| 3 | TGA→PNG decoder + lazy sprite gallery | 508 gfx sprites decode |
| 4 | Isometric map viewer, overlays, hover inspector | 15 maps; map 2 = 972 cells |
| 5 | Byte-exact `.dat` encoders + safe export + spell editor | all 5 `.dat` round-trip byte-exact |
| 6 | `.sba` format reverse-engineered + full tag-body decoder + **Canvas animation player** + fighter dress-up | 30 real `.sba` fully decoded; player + compositor tested end-to-end |
| 7 | Byte-exact `.amw` encoder + special-cell editor + jar repack | 39 `.amw` chunks round-trip byte-exact |

> The `.sba` **animation player** is now implemented: the decoder recovers every
> tag body (bitmaps→straight-alpha RGBA, matrices, color transforms, movie-clip
> timelines, bitmap sequences), a compositor flattens a symbol's timeline into
> drawable frames, and the frontend plays them on a `<canvas>` (play/pause/
> scrub/loop, symbol picker, pan/zoom) — including **multi-layer fighter
> dress-up** (base + equipment `.sba` layers composited via `ComposeFighter`).
> A full free-form `.amw` **geometry editor** remains the one documented
> follow-on. See §7 below for the Phase 6 implementation notes.

---

## 1. Is it feasible? — Yes.

The single most important fact that makes this project low-risk:

> **We already have byte-exact, reverse-engineered parsers for every data file in
> Go**, living in `go-server/internal/gamedata/parser/`. They were validated
> byte-for-byte against the real client files (see
> `go-server/docs/04-game-data-format.md`). The GUI does **not** need to
> re-derive any binary format — it reuses this proven code.

That drives the recommended architecture:

- **Backend:** Go — import the existing `internal/gamedata` + `internal/gamedata/parser`
  packages directly. No format re-implementation, no drift between server and tool.
- **Shell:** [**Wails v2**](https://wails.io) — bundles the Go backend with a web
  frontend into a single small native binary per OS. True native windows, native
  file dialogs, no bundled browser (uses the OS WebView: WebView2 / WKWebView /
  WebKitGTK). This is how we get "very sexy + multiplatform" cheaply.
- **Frontend:** a web UI (Svelte or React + Vite + Tailwind). Canvas/WebGL for the
  isometric map & sprite rendering.

```
┌────────────────────────────────────────────────────────────┐
│  Wails desktop app  (one binary: .exe / .app / ELF)         │
│                                                             │
│  ┌───────────────┐   Wails IPC   ┌────────────────────────┐ │
│  │  Web frontend │ ◀───────────▶ │  Go backend            │ │
│  │  (Svelte/React│               │  ├ gamedata parsers     │ │
│  │   Canvas/WebGL│               │  ├ .jar (zip) reader    │ │
│  │   Tailwind)   │               │  ├ .tga / .sba decoders │ │
│  └───────────────┘               │  └ .dat/.amw ENCODERS   │ │
│                                  └────────────────────────┘ │
└────────────────────────────────────────────────────────────┘
        reads ▲                         writes ▼
  data/  •  client-compiled/game/contents/*.jar
```

### Fallback / alternative stacks (recorded, not chosen)
- **Go + local web server** (open in browser): same backend, less "native" feel.
  Good as a debug fallback if a WebView platform misbehaves.
- **Tauri (Rust)** / **Electron** / **Flutter**: all would force us to
  re-implement the binary parsers away from Go — rejected for that reason.

---

## 2. What data exists (the inventory the tool must cover)

### 2.1 Game-data files — `data/` (big-endian `.dat`, little-endian Alea)
All already parsed in `go-server/internal/gamedata/parser/`:

| File | Parser | Contents | Notes |
|------|--------|----------|-------|
| `cards.dat` | `cards.go` | Coach cards, Fighter cards, effects | 3 sections in one file |
| `spells.dat` | `spells.go` | Spells + effects | range/AP/LOS/breed/script |
| `events.dat` | `events.go` | Events + effects | |
| `summoning.dat` | `summoning.go` | Summons (HP/AP/MP/gfx/spell) | |
| `staticEffects.dat` | `staticeffects.go` | Static effect areas | traps/glyphs/special cells |
| `elements.ade` | `elements_ade.go` | Element definition catalog | walk/height/LOS/move flags |
| `maps/<id>/*.amw` | `amw.go` + `map_altitude.go` | Per-region cell/element chunks | 15 fight maps (2–16) |
| `breeds.dat`, `items.dat` | — | **empty/vestigial** in this build | classes come from elsewhere |

> **Breeds/classes note:** `breeds.dat` and `items.dat` are empty in this build.
> "Class" data (the 12 Dofus breeds + their spell lists) will need to be sourced
> from spells' `BreedID`, the `.lua` scripts in `data.jar`, and/or i18n — a
> discovery task flagged in the roadmap below.

### 2.2 Client assets — `client-compiled/game/contents/*.jar` (ZIP archives)

| Jar | Count | Formats | What it is |
|-----|-------|---------|------------|
| `gui.jar` | 1091 | **`.png` ×995**, `.xml` ×59, `.TTF` ×3 | UI sprites, layouts, fonts — **standard PNG, easy win** |
| `gfx.jar` | 511 | **`.tga` ×508** | Ground/tile/decoration sprites (Targa — simple decode) |
| `animations.jar` | 76 | **`.sba` ×73** | Sprite Byte Animation (custom format) |
| `equipments.jar` | 366 | **`.sba` ×359** | Coach/fighter equipment animations |
| `sfx.jar` | 316 | `.aps` ×265, `.cg` ×36 | Particle systems + shaders |
| `sounds.jar` / `musics.jar` / `sounds*.jar` | — | audio | SFX / music |
| `data.jar` | 1135 | `.amw`, `.lua` ×170, `.dat`, `.xml`, `.ade` | Master copy of data + Lua scripts |
| `i18n.jar` | — | localization | strings for names/descriptions |

Format difficulty ranking for rendering: **PNG (trivial) → TGA (easy) → SBA
sprite-animation (hard, custom) → APS particles (hard) → CG shaders (very hard)**.

---

## 3. Roadmap — easiest → hardest

Each phase is independently shippable. Difficulty is **T-shirt sized**
(XS / S / M / L / XL). "Reuse" = leans on existing Go parsers.

### Phase 0 — Project skeleton  ·  **XS**
- `tools/studio/` Wails app scaffold (`wails init`), Go module that imports
  `github.com/dofusarena/go-server/internal/gamedata`.
- Config: point at a `data/` dir and a `client-compiled/` dir (auto-detect the
  siblings; allow override via native folder picker).
- Dark, "sexy" base theme (Tailwind), left nav (Maps / Spells / Cards / Items /
  Summons / Static Effects / Events / Assets), main content pane, status bar.
- **Deliverable:** app launches on all 3 OSes, shows an empty shell + detected paths.

### Phase 1 — Read-only data browsers (tables)  ·  **S**  ·  *reuse*
The fast, high-value win. Expose each `Repository`/`Store` over Wails IPC as JSON;
render sortable/filterable/searchable tables + a detail panel.
- **1a Spells** — id, AP cost, range min/max, LOS, breed, script, effects list.
- **1b Cards** — coach cards & fighter cards, with attached effects.
- **1c Summonings** — HP/AP/MP/gfx/spell.
- **1d Static Effects** — area shape/params/triggers/effects.
- **1e Events** — effects.
- Cross-links: click a spell's `BreedID` → filter; click an effect `ScriptID`.
- **Deliverable:** every `.dat`-backed record browsable & searchable.

### Phase 2 — Raw asset browser (jar explorer)  ·  **S**
- Go opens the `.jar`s as ZIP archives (stdlib `archive/zip`), builds a virtual
  file tree across all jars, with search/filter by name & extension.
- **PNG preview** (from `gui.jar`) — works immediately, no decoding.
- Extract-to-disk (single file or bulk) with native save dialog.
- Font (`.TTF`) preview, XML/Lua/text syntax-highlighted viewer.
- **Deliverable:** browse & extract every client asset; view all PNGs/text.

### Phase 3 — TGA sprite viewer  ·  **M**
- Go-side TGA decoder (or `golang.org/x/image`) → serve as PNG to the frontend.
- Gallery grid of `gfx.jar` (508 tiles) + `gfx/<id>.tga` lookup by ID.
- Link map elements → their gfx id so a tile shows its actual sprite.
- **Deliverable:** visual catalog of all ground/decoration sprites.

### Phase 4 — Static isometric map viewer  ·  **L**  ·  *reuse*
The centerpiece "wow" feature (non-animated first).
- Load a map via `gamedata.MapStore.Get(id)` (all `.amw` chunks + `elements.ade`).
- Render the isometric grid on Canvas/WebGL using the **known projection**
  (`px=(x-y)*43`, `py=-(x+y)*21.5`) and the resolved altitude/z-order from
  `map_altitude.go` (`ResolveCellSurfaces`).
- Composite the real tile sprites (Phase 3) per cell/level, respecting piling &
  `LevelUnpiled` z-order.
- **Overlays** (toggleable): walkability heatmap, altitudes, line-of-sight
  blockers, fight-start cells (team A/B), coach-start cells, special/trap cells
  (`specialcells.json`).
- Hover a cell → inspector (x, y, z, walkable, elements, flags).
- **Deliverable:** pixel-plausible static render of all 15 fight maps with
  gameplay overlays — doubles as a design/debug tool for the server.

### Phase 5 — Data editing + export of `.dat` files  ·  **L**
Introduces **write** support. This is the first "export to client" milestone.
- Build **encoders** mirroring each parser (the inverse of `spells.go`, `cards.go`,
  …). Guarantee round-trip: `parse(encode(parse(f))) == parse(f)` and, where the
  original is canonical, `encode(parse(f)) == f` byte-for-byte.
- Editable forms for spells / cards / summonings / static effects / events with
  validation (ranges, enum values, referential integrity).
- Dirty-tracking, diff-vs-original view, undo/redo.
- **Export targets:**
  1. loose file into `data/` (server/tool reads it),
  2. **repack into `data.jar`** so the *client* loads it (Phase 7 machinery).
- **Deliverable:** edit a spell's AP cost in the GUI → export → server & client
  both see the change.

### Phase 6 — `.sba` sprite-animation decoder + player  ·  **XL**
The hardest asset format; animations for fighters/coaches/equipment.
- Reverse-engineer `.sba` (Sprite Byte Animation) the same disciplined way the
  map formats were done: **extract compiled `.class` from `core.jar`, disassemble
  with `javap -c`**, verify byte-exact against real `.sba` files. (See the
  Phase-K methodology in `docs/04-game-data-format.md` §4.9.1.)
- Frame/timeline model → WebGL animation player (play/pause/scrub/loop, per-
  direction, palette/teint support).
- Preview coaches & fighters with their equipment layers composited.
- **Deliverable:** play any in-game animation; preview a fighter fully dressed.
- *Risk:* format is undocumented; timebox the RE spike before committing the UI.

> **Implemented.** Backend: `cmd/studio/sba/` gained a faithful `InputBitStream`
> port (`bitreader.go`), full tag-body decoding (`model.go`), bitmap-pixel
> extraction (`bitmap.go`: outer-zlib → `AlphaBitmapData` raw RGBA, auto
> un-premultiplied), and a timeline compositor (`frames.go`). The App exposes
> `GetAnimationPlayback` and `ComposeFighter`. Frontend: `animations.ts` is now a
> `<canvas>` player (play/pause/scrub/loop, fps/zoom, drag-pan, symbol picker,
> structure/debug toggle) with equipment layering. **Key RE correction:** the
> `.sba` tag codes are the format's own namespace (1 ShowFrame, 2 DefineBitmap,
> 3 DefineBitmapSequence, 4 DefineMovieClip, 5 PlaceObject, 6 RemoveObject,
> 7 ActionFlag), *not* SWF codes — the earlier structure-only inspector used the
> wrong constants. Verified against all 30 real `animations.jar`/`equipments.jar`
> files. Current limitation: the canvas honors the alpha multiplier; full RGB
> mult/add color-transform tinting is a small follow-up.

### Phase 7 — Full round-trip: `.amw` map editor + jar repack  ·  **XL**
The most powerful, most complex capability.
- **`.amw` + `specialcells.json` encoders** (inverse of `amw.go`) — byte-exact
  round-trip proven against all 15 maps first.
- **Map editor:** paint/erase tiles & elements, place fight-start / coach-start /
  bonus / special cells, edit per-cell levels & altitudes, live overlays reused
  from Phase 4, live walkability re-resolve.
- **Jar repacker:** rewrite `data.jar` (and, for assets, the relevant jar) with
  edited entries, preserving `META-INF/MANIFEST.MF`, ordering, and (if required)
  signing. Always **back up** the original jar; write to a staging copy and swap.
- **Export pipeline:** one action to push edited data+maps into
  `client-compiled/game/contents/*.jar` **and** the server's `data/` dir, with a
  pre-flight validation + backup + rollback.
- **Deliverable:** design a new fight map in the GUI, export, launch the real
  client, and play on it.

### Phase 8+ — Polish & stretch goals  ·  varies
- **Classes/breeds view** once breed data is sourced (Lua/i18n discovery task).
- **i18n integration:** show real localized names/descriptions on every record.
- **Particle (`.aps`) preview**, audio (`.aps`/sound) playback.
- **Diff two data sets** (e.g. compare `spells.dat` vs `Copie de spells.dat`).
- **Search everything** (global command palette across data + assets).
- **Live server hookup:** read the running server's loaded state via its ops API.
- CI: cross-compile signed release binaries for Windows/macOS/Linux.

---

## 4. Difficulty summary (the "easiest → hardest" ladder)

| # | Phase | Size | Writes? | Key risk |
|---|-------|------|---------|----------|
| 0 | Skeleton | XS | – | none |
| 1 | Data browsers | S | no | none (reuse) |
| 2 | Jar/asset explorer + PNG | S | no | none |
| 3 | TGA sprite viewer | M | no | TGA variants |
| 4 | Static iso map viewer | L | no | z-order/compositing fidelity |
| 5 | Data editing + `.dat` export | L | **yes** | byte-exact encoders |
| 6 | `.sba` animation player | XL | no | undocumented format (RE spike) |
| 7 | `.amw` map editor + jar repack | XL | **yes** | round-trip + client acceptance |
| 8+| Polish / classes / particles | var | some | data discovery |

**Recommended first slice to prove the whole idea:** Phases 0 → 1 → 2 → 4
(skeleton, data tables, asset browser, static map view). That already delivers a
genuinely useful, sexy, multi-platform inspector with zero write-risk, and every
piece after it (editing/export/animation) builds on that foundation.

---

## 5. Guardrails / non-negotiables

- **Never mutate originals in place.** All exports back up the target jar/file and
  write via a staging copy + atomic swap, with rollback.
- **Round-trip tests gate every encoder** before it's allowed to touch client files.
- **Reuse the server's parser package** — do not fork the binary-format logic; a
  single source of truth prevents server/tool drift.
- **Read-only by default;** editing is an explicit mode.

---

## 6. Suggested layout

```
tools/
  README.md            ← this file
  studio/              ← the Wails app (created in Phase 0)
    go.mod             ← requires ../../go-server (replace directive)
    main.go            ← Wails bootstrap
    app.go             ← IPC-exposed backend methods
    internal/
      assets/          ← jar (zip) reader, TGA/SBA/PNG decoders
      encode/          ← .dat/.amw encoders (Phase 5/7) + round-trip tests
      export/          ← backup + jar repack + rollback pipeline
    frontend/          ← Svelte/React + Vite + Tailwind
      src/
        views/         ← Spells, Cards, Maps, Assets, ...
        render/        ← iso map canvas/WebGL, sprite/animation player
```
