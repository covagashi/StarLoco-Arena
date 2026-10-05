# deprecated_hall

The free-roaming overworld island ("the hall") — `world/world_view.gd` —
is preserved here, **out of the active client**. The live flow is now
login → lobby + menus; the walkable map may return later.

Not shared, moved intact:
- `world/world_view.gd` — island view: volumetric topology fallback,
  MapGfx painter + dynamic actors, click-to-move (4501), coach spawns
  (4096/4099/4500/4510), chat bubbles, interactive-element markers,
  zone triggers, wheel zoom.

**Stayed in `src/`** because the fight view and creation screen still
need them (they are NOT deprecated):
- `src/maps/topology.gd`, `src/maps/map_gfx.gd` — also used by
  `fight/fight_view.gd` for arena rendering
- `src/anims/anm_sprite.gd` — paper-doll renderer shared by fighters,
  coaches and the creation preview

`.gdignore` keeps Godot from compiling this tree. To revive the hall,
move `world/` back under `src/`, restore the `World` node in
`src/main.tscn`, and re-point the guarded call sites in `src/main.gd`
(search for `world != null`).
