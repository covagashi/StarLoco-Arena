# asset-import — retail .anm/.tgam → Godot-friendly PNG + JSON

Offline conversion of the retail client's proprietary animation format.
Requires the extracted client at `client/compiled/game/` (git-ignored —
extract `DofusArena-v2.70.zip`'s `game/` folder there). Python 3, stdlib only.

## make_assets.sh — the whole tree in one command

`tools/make_assets.sh` runs every tool below in the right order, so neither a
player nor a developer needs to know them. Its inputs are the player's own
retail client and the committed `server/data-dist/`; nothing it writes is
redistributed.

```bash
tools/make_assets.sh <retail_game_dir> <out_assets_dir> [--only a,b] [--skip a,b]
                     [--sets p,q] [--jobs N] [--resume]
tools/make_assets.sh client/compiled/game godot/assets
```

`<retail_game_dir>` is the client's `game/` folder (or its `contents/`). A
missing jar stops the run before anything is written, naming the jar and the
stage that needs it. Needs `python3` (+ Pillow for `gui`) and Go (`gamedata`).

| Stage | Makes | With | Time* |
|---|---|---|---|
| `gamedata` | `gamedata/*.json` (spells, cards, cardsets, fusionlabs, elements, spheres, npcdialogs, effects, areas, fightercards, spell_sfx, anm_scripts, spell_fx) | `server/cmd/dump*` over `server/data-dist` + `spell_names.py`, `card_names.py`, `npc_dialogs.py`, `spell_sounds.py` | 2 s (+ the first `go build`) |
| `fx` | `fx/<id>.png`, `gamedata/xps/`, `gamedata/xps_index.json` | `xps_dump.py` | 7 s |
| `gui` | `gui/` | `gui_extract.py` | 10 s |
| `musics` | `musics/*.ogg` | `musics.py` | <1 s |
| `mapgfx` | `mapgfx/<world>.json` + `tex/` for every world in `maps/gfx/` | `map_gfx.py` | 30 s |
| `anims` | `anims/<set>/` — 71 sets | `anm_render.py --export/--composite`, `portraits.sh` | ~40 min (a fighter set ~90 s, `portraits` 2.5 min, the rest seconds) |
| `sounds` | `sounds/<id>.ogg` for every id the tables and the anim sets name | `sounds.py` | 1 s |

\* on the dev box (ROG Ally, one job). The `anims` sets and how each is made:

| Set | Run |
|---|---|
| `animsort_<b>` (b = 10…130) | `--export` of `Players/AnimSort_<b>.anm`, actions matching `AnimSort` |
| `coach_700{0,1}` | `--export` of `Players/700<s>.anm` (`AnimStatique`) + `AnimCommunes.anm --composite` onto it |
| `coach_805` | `--export` of `equipments/coachs/805.anm` — the old coach stand-in, nothing loads it now |
| `fighter_<f>` (24: breeds 1–12 × sex) | `--export` of `Players/<f>.anm` (`AnimStatique`) + `--composite` onto it of `AnimCommunes`, `AnimCombat`, `AnimSort_<breed×10>`, `AnimEmotes<Male\|Femele>` (in that order: the last two share a `LienClip` part), and each weapon bank `Anim{Epee1,Dague1,Arc,Baguette,Marteau,Pelle,Poings}` (`AnimStatique03`); breed 2 also gets `AnimSort_120`'s carry poses (`Porte`) |
| `npc_<id>` | `--export` of `NPCs/<id>.anm` — every positive type-300 summon look (`npc_2000`: only its `_Anim` gestures) |
| `portraits` → `portrait_*` | `portraits.sh` |

Options: `--only`/`--skip` pick stages; `--sets 'fighter_-110,npc_*'` limits
`anims` to the sets matching those shell patterns; `--jobs N` renders N sets
at once (one Python process each); `--resume` keeps sets an earlier run
finished. Each set renders into a hidden `.<set>.part` folder and replaces the
old one only when it is complete, so re-running is safe at any point. Logs
(one per stage and per set) and the resume stamps go to
`<out>/.make_assets/`.

Rebuilding the dev tree from scratch gives the same files as the hand-made
one, with these known differences (checked 2026-10-24): PNGs re-encode
(identical pixels, different bytes); `gui/i18n_*.json` now read the jar as
UTF-8, fixing ~420 strings the old tree had as mojibake; old sets lose the
`flipy` marker `anm_flip.py` left; channel masks (`f*_m.png`) come from
the renderer, which follows the texture's alpha, instead of
`anm_mask_patch.py`'s backfill, which marked whole quad rectangles (skin
bled over eyes and clothes) and, in the fighter sets, was often not the size
of its colour frame; and the six summon-look
fighter sets (`-1100 -120 -130 -140 -170 -190`) no longer carry the ~395
loose body-part folders (`0_Arme`, `2_BrasPeau`…) an early full export left
in them — the client never asks for those.

## Formats

- **`.anm`** (`contents/animations.jar`): Ankama animation containers —
  texture table (`.tgam` names) + atlas regions (UV rects) + actions
  (per-frame transform lists) + labels. Transform `fL` ids resolve through a
  scene graph: label → root action by CRC, nested action by id, or drawable
  region. Layout reconstructed from `client/decompiled/` (`bs_2`, `ju_2`,
  `xc_2`, `aca`, `gw_2`, `pq_0`, `aek_0`).
- **`.tgam`**: `MAGT` + width/height + RGBA8 pixels (rows padded to the next
  power of two) + collision mask. Same decoder as `server/cmd/studio/tgam.go`.

## Tools

| Tool | Purpose |
|---|---|
| `anm_dump.py <animations.jar>` | Parse & scan every `.anm` (573/573 pass) |
| `anm_render.py <jar> <entry> [action] [frame]` | Render one frame to `/tmp/*.png` |
| `anm_render.py <jar> <entry> --export <dir>` | Export all frames of every named action (color PNG + `f*_m.png` channel mask per frame when the action carries tint channels) |
| `anm_render.py <jar> <entry> --composite <actor.anm>` | Bake skeletal gesture tracks (`AnimSort_*`, `AnimCombat`, weapon banks `Anim*.anm`…) over a body set |
| `anm_flip.py <anims_root> [set…]` | One-time migration: flip exported frames vertically + adjust `meta.oy` (the emitter used gw_2's Y-up vertex math verbatim — GL flips at display, our PNGs do not, so every pre-fix export was upside-down) |
| `anm_mask_patch.py <jar> <anims_root> [set…]` | Backfill `f*_m.png` channel-coverage masks into already-exported sets (geometry-only replay — no texture sampling) |
| `spell_names.py` | Merge FR spell names into `spells.json` (`nfr` slug → `AnimSort-<name>` casts) |
| `npc_dialogs.py` | Merge i18n 29/59/60/10/37/48/49 into `npcdialogs.json` (English tables plus `locales.es` / `locales.fr`) |
| `card_names.py` | Merge card names into `cards.json` |
| `map_gfx.py <world> <out_dir>` | Painted-map sprites/atlases of one world → `godot/assets/mapgfx/` (reads `client/compiled/game/contents`, or `$ARENA_CONTENTS`) |
| `gui_extract.py <gui.jar> <i18n.jar> <out_dir>` | Retail GUI layer → `xml/` (theme + 180 dialog/component/template definitions), `images/` (TGA→PNG skin + icon art), `fonts/` (TTFs + .fnt/.tab metrics), `i18n_<lang>.json`. The XML files are the declarative spec for the `src/gui/` interpreter — tag vocabulary per `client/decompiled/core/ye_2.java`, theme-parser semantics per `core/DS.java` |
| `spell_sounds.py <spells.json> <data.jar> <sounds.jar> <out.json> <snd_dir> [anm_out.json] [spell_fx.json]` | Extract `Sound.playSound` ids + `invoke()` delays per spell script → `spell_sfx.json`; 6th arg → `anm_scripts.json`; 7th arg → `spell_fx.json` (`Particle.addParticleSystem` ids with `invoke()` timing, anchor `caster`/`target` from `startX`/`destX` locals); copies every referenced ogg |
| `xps_dump.py <sfx.jar> <xps_json_dir> <fx_png_dir> [xps_index.json]` | Decode `.xps` particle systems (alo_2 layout). Emits per-id JSON when the recursive parse succeeds (WIP — most files still fail EOF), always emits the header index (`textureId`, `durationMs`, blend modes), and exports `particles/<id>.tga` → PNG. Cross-check field names against wakfu-src `EmitterDefinition` / `ParticleModelAttributesRW`. |
| `anm_scr_patch.py <animations.jar> <anims_root> [set…]` | Backfill `meta.scr` into already-exported `meta.json`s — replays each action's frame walk to collect `pb_1` runScript parts without re-rendering frames |
| `portraits.sh [assets_root]` | (`$ANIMATIONS_JAR` picks another client's jar) The faces of the NPCs who talk (S23) → `anims/portrait_<who>/`: `bob_interface` (Nilo), `demon1`, the gostofos, and Aldebrán's map actor (gfx 2500; his own 2008 GUI `.anm` is a layout the parser does not read). Keeps only the actions `talk_panel.gd` plays |
| `sounds.py <sounds.jar> <assets_dir> [animations.jar]` | Every sfx id the client can ask for → `sounds/<id>.ogg`: `spell_sfx.json` + `anm_scripts.json` ids and the anim sets' `meta.sfx`; without an anims tree, the `Sons<id>` anm names |
| `musics.py <musics.jar> <out_dir>` | The three music tracks (`loading`, `island`, `fight`) → `godot/assets/musics/*.ogg`, read raw by `src/audio/audio.gd` |
| `test_anm.py` | Parse sweep + render checks (skips if jar absent) |
| `test_npc_dialogs.py` | `npc_dialogs.py`'s port of the client text formatter (`are_0.format`, with the retail class's own test cases) and of the event-card description (`asf_0.a`); needs nothing git-ignored |

## Export layout

```
<out>/<action_name>/f000.png …      per-frame sprites (tight bounds)
<out>/<action_name>/meta.json       {anm, action, fps, frames:[{png,w,h,ox,oy}],
                                     sfx?: {frameIdx: [Sons<id> soundIds]},
                                     scr?: {frameIdx: [runScript ids]}}
```

`ox`/`oy` is the frame's top-left offset in scene space — keep it as the
sprite offset in Godot so frames of different sizes stay pivot-registered.

## Example

```bash
python3 tools/asset-import/anm_render.py \
  client/compiled/game/contents/animations.jar \
  animations/NPCs/2001.anm --export /tmp/npc2001
```

## Verified

- Parser: all 573 `.anm` in `animations.jar` (two frame encodings:
  RLE `repeat` field + flat variant used by `animations/gui/`).
- Renderer: affine quads + color mul/add chains reproduce `gw_2` output;
  NPC 2001 (treant) `1_AnimHit` renders a correct 24-frame sequence,
  coach `805.anm` renders a correct dark-bird sprite.
- Tint channels (`ju_2.CZ&0x3F`): 1=skin, 2=hair, 8=pupil; propagated
  through composite retargets (costume channels 6/7/9 stay authored) and
  emitted as `f*_m.png` masks (R/G/B coverage) for runtime recoloring —
  `AnmSprite.tints` + `gamedata/palettes.gd` (apH/agl_0/tn_0 tables,
  ×1.25 like retail `aaV`).
- Paper-doll coaches: `Players/700{0,1}.anm` bodies + `AnimCommunes.anm`
  gestures → `coach_700{0,1}` sets (the old `coach_805` stand-in was an
  NPC bird).
- Known gaps: frame-part effects (particles) are parsed but not rendered;
  sound triggers (`Sons*` → `meta.sfx`) and script hooks (`pb_1` runScript →
  `meta.scr` → `anm_scripts.json`) ARE exported; external `.anmx`
  composition tables unused.

## References

- `client/decompiled/` — obfuscated 2.70 source (ground truth, byte-exact).
- `hussein-aitlahcen/wakfu-src` (GitHub) — **unobfuscated** Wakfu client on
  the same Ankama Java engine: `framework/graphics/engine/Anm2/*` maps 1:1
  onto our classes (`AnmShape{,R,T,A,M,CR,CT,CRT,RTAM…}` = transform types,
  `AnmActionTypes` = frame parts 1-10, `AnmTransformDataTable` = `aek_0`
  color/skin table with `CUSTOM_COLOR_{SKIN,HAIR,CLOTHES,…}` recoloring).
  Useful for naming and for the still-undecoded formats (`.dam` overworld
  maps, `.xps` particle systems under `particleSystem/`).
- `WakBox/WakfuBDataReader` — reference for the shared `.dat` record format.
- Note: Dofus **1.x/2.x** tools (PyDofus, ArakneSwf, d2i/d2p/dlm/swl) do NOT
  apply — DofusArena uses the Java engine; there are no `.swf` files.
