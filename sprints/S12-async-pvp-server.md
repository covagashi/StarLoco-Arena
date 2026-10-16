# S12 — Async PvP, fase 3: ghosts en el servidor

**Planificado:** 2026-10-16 · **Hito:** M4 — Async PvP · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

La fase 3 de [`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md). Las fases 1–2 (combate
contra la IA con semilla fija y el motor de gambits) están hechas (`8220cac4`).

## Tareas candidatas

- [ ] Tabla `ghost_teams` (migración de esquema) y los opcodes propios
      60010–60014 (patrón ≥60000 de `BACKLOG.md` §3).
- [ ] Visible solo para admin al principio.
- [ ] Guardar el id de arena junto a la semilla (hoy el reparto de arena, los
      drops y el cansancio usan aleatoriedad global o el reloj: `BACKLOG.md` §4).
- [ ] e2e: crear un ghost, combatir contra él y repetir el mismo resultado con la
      misma semilla.

## Criterio de cierre

Un admin crea un ghost por protocolo, otro coach combate contra él, y el
combate es reproducible con su semilla.
