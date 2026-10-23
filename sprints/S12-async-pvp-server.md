# S12 — Async PvP, fase 3: ghosts en el servidor

**Planificado:** 2026-10-16 · **Detallado y abierto:** 2026-10-23 · **Hito:** M4 — Async PvP · **Tamaño:** M · **Estado:** 🟢 cerrado (2026-10-23)

## Objetivo

La fase 3 de [`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md). Las fases 1–2 (combate
contra la IA con semilla fija y el motor de gambits) están hechas (`8220cac4`).

## Punto de partida (auditoría del 2026-10-23)

- **La semilla existe.** Cada combate la recibe en `FightManager.Create`
  (`fightseed.go`; `SetSeed` antes de la primera tirada). No se guarda en
  ningún sitio ni viaja.
- **Gambits.** Hay un motor completo: tipos, `parseGambitRules` estricto,
  evaluación en `runAITurn` antes del arquetipo. Pero las reglas solo llegan
  por `setGambitRulesJSON`, que **solo usan los tests**: no hay
  almacenamiento ni opcode.
- **La aleatoriedad que queda fuera de la semilla** (`BACKLOG.md` §4):
  - `pickArenaSeating` usa el `rand` global.
  - Los drops tienen su propio RNG.
  - El cansancio depende del reloj.
  Solo la arena cambia el combate; drops y cansancio llegan después del 8300.
- **El camino más cercano** es `startPvEChallenge`: el equipo propio contra
  un equipo sin sesión (`buildChallengeTeam`), con `startFightWithTeams`.
- **Desde S11:**
  - Un luchador de jugador jugado por la IA lanza sus hechizos.
  - `/AUTOPILOT` deja a la IA jugar el lado del retador. Así un combate
    contra un ghost se puede repetir sin manos humanas.

## Decisiones (delegadas: "toma usando heurística"; el dueño dijo "continúa", 2026-10-23)

| Decisión | Tomada | Por qué |
|---|---|---|
| Qué guarda un ghost | una **foto congelada** de la alineación titular: los `domain.Fighter` con hechizos (ya filtrados por legalidad y esferas), cartas y condiciones; más las reglas por luchador | si el dueño cambia luego su equipo, el ghost no cambia: es una grabación |
| Ids en combate | coach sintético `1<<31 + 2`; los ids de los luchadores van en su propio rango (base + 2³⁶ + ghost·16) y el `ID` de la foto se pone a 0 | así nada después del combate (XP, heridas, drops) escribe en los luchadores reales del dueño; `isSyntheticCoach` lo cubre |
| Opcodes | 60010 guardar, 60011 resultado, 60012 pedir lista, 60013 lista, 60014 combatir (o repetir un combate guardado) | patrón ≥60000 de `BACKLOG.md` §3; el cliente retail nunca los manda |
| Quién los usa | solo admin (resultado "no permitido" para el resto) | el esbozo lo pedía; S13 lo abre |
| Ghosts por coach | 3; el cuarto se rechaza | sin tope, cualquiera llena la tabla |
| Combate contra un ghost | de práctica: sin escalera, sin recompensas de desafío | escalera y recompensas son S14 |
| Reproducibilidad | cada combate contra un ghost guarda semilla, arena, ganador, rondas y un hash del registro de decisiones (`ghost_fights`); 60014 con el id de un combate guardado lo repite con su semilla y su arena | es el criterio de cierre; la arena sale de la semilla, no del `rand` global |
| Drops y cansancio | se quedan fuera de la semilla | ocurren después del 8300; no cambian el combate |

## A. Servidor

- [x] Tablas `ghost_teams` y `ghost_fights` (migraciones 13 y 14, en la base
      y en el baseline), con sus repos.
- [x] Guardar (60010): foto de la alineación titular más reglas JSON
      opcionales por luchador, validadas con `parseGambitRules`.
- [x] Lista (60012 → 60013).
- [x] Combatir (60014): equipo ghost sin sesión con las reglas puestas,
      arena elegida con la semilla, combate de práctica. Al terminar,
      escribe en `ghost_fights`.
- [x] Repetir (60014 con id de combate): misma semilla y misma arena.
- [x] Pruebas: unidad (foto, ids, reglas, tope, permisos) y e2e (crear un
      ghost, combatir con `/AUTOPILOT` y repetir con la misma semilla: el
      mismo ganador, las mismas rondas y el mismo hash).

## Criterio de cierre

Un admin crea un ghost por protocolo, otro coach combate contra él, y el
combate es reproducible con su semilla.

## Resultado

- **Servidor:**
  - `domain/ghost.go` y `store/ghosts.go`, migraciones 13–14.
  - `game/ghost.go`: foto, equipo ghost sintético, arena por semilla,
    60010–60014 y `recordGhostFight` en `checkFightEnd`.
  - `startFightWithTeamsSeeded`.
- **Pruebas:**
  - Unidad, `ghost_test.go`: foto congelada y sin ids, equipo sintético con
    reglas, rechazos, arena estable por semilla, hash.
  - e2e `TestGhostFightReplaysWithItsSeed`: crear, listar, combatir IA
    contra IA y repetir. Ganador, rondas, arena y hash **iguales**. Pasada
    tres veces con semillas distintas (16, 20 y 23 rondas).
  - Unidad, migraciones y e2e del ghost también en **Postgres 16 y MariaDB
    11**, con contenedores podman locales.
- **Encontrado:**
  - **GORM y `default:`.** Con `default:-1` en `WinnerTeam`, un 0 (gana el
    retador) se guardaba como -1: GORM toma el valor cero como "sin
    valor". Quitado.
  - **El reloj de la IA en e2e.** A 1,2 s por turno, un combate IA contra
    IA hacía que la prueba durara 3 min. `SetAITurnClockForTest(200 ms)` en
    el `TestMain` de e2e: la suite entera pasa de 38 a 30 s.
- `OPCODE-INVENTORY.md`: filas 60010–60014 y recuentos.
