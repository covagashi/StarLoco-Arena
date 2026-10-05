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

`.gdignore` keeps Godot from compiling this tree.

## To revive the hall

The live `main.gd` no longer carries the hooks — restoring it means:

1. Move `world/` back under `src/`, add the `World` node (`world_view.gd`)
   to `src/main.tscn`, and `@onready var world := $World`.
2. In `_ready`: `log.bubble.connect(world.chat_bubble)`,
   `log.emote.connect(world.emote)`,
   `world.cell_entered.connect(_check_zone_trigger)`.
3. `OP_INSTANCE_READY`: `world.show_world(State.current_world, _my_pos)`
   (instead of/alongside `_show_lobby_screen()`).
4. `OP_ACTOR_SPAWN`: `world.actor_spawned(id, name, x, y, z, look)` —
   `_read_coach_spawns` already decodes every field.
5. `OP_ACTOR_DESPAWN/MOVEMENT/TELEPORTS`: `actor_despawned(did)` /
   `actor_moved(aid, path)` / `actor_teleported(f0..f3)` — the decodes
   are still in place.
6. `OP_ELEMENT_SPAWN/DESPAWN`: `world.element_spawned(e)` /
   `element_despawned(ids)` — `State.elements` is still maintained.
7. `_unhandled_input`: wheel zoom (`world.zoom_by`), actor/element pick
   (`actor_at`/`element_at`), `screen_to_cell` → `click_to`, and
   `set_hover` on mouse motion.
8. Guild tags (554): `world.set_coach_guild(coach_id, guild)` if name
   labels should tint by guild.
