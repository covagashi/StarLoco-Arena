# asset-import — retail .anm/.tgam → Godot-friendly PNG + JSON

Offline conversion of the retail client's proprietary animation format.
Requires the extracted client at `client/compiled/game/` (git-ignored —
extract `DofusArena-v2.70.zip`'s `game/` folder there). Python 3, stdlib only.

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
| `npc_dialogs.py` | Merge i18n 29/59/60/10/37/48/49 into `npcdialogs.json` |
| `card_names.py` | Merge card names into `cards.json` |
| `map_gfx.py` | Painted-map sprites/atlases → `godot/assets/mapgfx/` |
| `gui_extract.py <gui.jar> <i18n.jar> <out_dir>` | Retail GUI layer → `xml/` (theme + 180 dialog/component/template definitions), `images/` (TGA→PNG skin + icon art), `fonts/` (TTFs + .fnt/.tab metrics), `i18n_<lang>.json`. The XML files are the declarative spec for the `src/gui/` interpreter — tag vocabulary per `client/decompiled/core/ye_2.java`, theme-parser semantics per `core/DS.java` |
| `spell_sounds.py <spells.json> <data.jar> <sounds.jar> <out.json> <snd_dir> [anm_out.json] [spell_fx.json]` | Extract `Sound.playSound` ids + `invoke()` delays per spell script → `spell_sfx.json`; 6th arg → `anm_scripts.json`; 7th arg → `spell_fx.json` (`Particle.addParticleSystem` ids with `invoke()` timing, anchor `caster`/`target` from `startX`/`destX` locals); copies every referenced ogg |
| `xps_dump.py <sfx.jar> <xps_json_dir> <fx_png_dir> [xps_index.json]` | Decode `.xps` particle systems (alo_2 layout). Emits per-id JSON when the recursive parse succeeds (WIP — most files still fail EOF), always emits the header index (`textureId`, `durationMs`, blend modes), and exports `particles/<id>.tga` → PNG. Cross-check field names against wakfu-src `EmitterDefinition` / `ParticleModelAttributesRW`. |
| `anm_scr_patch.py <animations.jar> <anims_root> [set…]` | Backfill `meta.scr` into already-exported `meta.json`s — replays each action's frame walk to collect `pb_1` runScript parts without re-rendering frames |
| `test_anm.py` | Parse sweep + render checks (skips if jar absent) |

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
