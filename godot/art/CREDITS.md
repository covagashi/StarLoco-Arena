# Where the art comes from (S34)

Every source under `godot/art/`, who made it and under what terms.
`tools/art/check.py` fails the build if a tracked folder or a font is
missing here. What the tools build (`out/` folders) is not in git: it is
regenerated with `python3 tools/art/build.py` (see AGENTS.md).

Licence of the client's art: like the rest of `godot/`, © Daviaan, all
rights reserved (see the repository README); the tools that make it are
third-party and keep their own licences, listed at the end.

## Sources in this repository

| Folder | What | Made by | Notes |
|---|---|---|---|
| `arena1/`, `arena2/`, `arena5/`, `arena6/`, `arena7/`, `arena8/`, `arena9/`, `arena10/`, `arena11/`, `arena12/` | Arena kits (arenas 3 and 4 reuse them): kiln models (`kit.kx.js`), loom textures (`*.tx.js`), the editor's piece list (`kit.json`) | Written for this project (S36), from the owner's notes on each piece | Shapes were modelled looking at the retail pieces they replace (`gfx` in `kit.json`), never copied from them. `arena1/glyphs.py` draws Baybayin glyphs with the Noto font below. `arena1/paint/` and `arena1/vex/` are S36 trials, not built. |
| `common/` | Shared kiln shapes the kits include | Written for this project | |
| `characters/` | `figures.json` (how each 3D figure is built), `joints/` (the bone fixes reviewed in S35b), `meshy_map.json` (which Meshy figure is which class), `fighter1.tx.js` (the S35 pilot's cloth) | Written for this project | The figures' meshes and textures come from the owner's Meshy files below. |
| `equipment/` | The fighters' equipment pieces (S35c): kiln models of the hats, weapons, capes, pets and dofus (`kit.kx.js` and its includes), and `pieces.json` (which card shows which piece) | Written for this project | Own designs; the retail card illustrations only gave the idea. |
| `layouts/` | Where each piece sits in arenas 1–12 | The owner in the map editor, from drafts of mine (S36) | |
| `shapes/` | Each arena's walkable cells (the fight grid) | Frozen in S43 from the retail map data the server already plays (cell numbers only, no art) | Leaves with the retail data (S40–S43). |
| `fonts/` | `NotoSansTagalog-Regular.ttf` | The Noto Project Authors | SIL Open Font License 1.1, `fonts/OFL.txt`. Used only to draw glyph textures. |
| `ao.json`, `blender.json`, `biomes.json` | Build settings | Written for this project | |

## Sources outside the repository

| What | Where | Made by | Notes |
|---|---|---|---|
| The 35 Meshy figures (24 fighters, 2 coaches, 8 summons): `<folder>/<folder>.glb` | Homelab art repository `pippop-arena-assets` (`//debian/codigo/pippop-arena-assets`); local copy `~/codigo/capturas/s35/meshy` (`PIPPOP_MESHY`) | The owner: reference images in Flow, meshes and textures generated with Meshy (S35b) | Kept out of git because of their size (5–30 MB each; no Git LFS, AGENTS.md). Made on the owner's paid Meshy Pro plan as private assets (owner, 2026-11-11): they belong to the owner and are cleared for commercial use. (Meshy's free-tier assets are public under CC BY 4.0; none of ours are.) |
| Summon 8010 (the crystal) | none: `tools/blender/characters/crystal_8010.py` models it | Written for this project | |

## Tools (their licences, not the art's)

| Tool | Licence | Used for |
|---|---|---|
| kiln (uilianks/kiln) | MIT | Arena models, equipment pieces |
| loom (uilianks/loom) | MIT | Textures |
| Blender 5.2 | GPL (the program; what it outputs is ours) | Curved pieces, AO, rigging and animation |
| Meshy | Commercial service, owner's Pro plan (private assets) | Figure meshes |

## Still retail (leaving)

What the client still reads from the converted retail files under
`godot/assets/` (git-ignored, never redistributed): sprites of anything
without a 3D figure, interface pieces, spell effects, sounds and music.
Each leaves with its sprint: effects S37, cards and icons S38, sound S39,
the rest S43.
