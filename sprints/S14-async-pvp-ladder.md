# S14 — Async PvP, fase 5: relleno, ladder y recompensas

**Planificado:** 2026-10-16 · **Detallado, abierto y cerrado:** 2026-10-23 · **Hito:** M4 — Async PvP · **Tamaño:** M · **Estado:** 🟢 cerrado (las dos decisiones abiertas, tomadas el 2026-10-25 → S25)

## Objetivo

La fase 5 de [`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md): que el modo funcione
aunque haya pocos jugadores conectados, que es justo el caso de un revival.

## Decisiones previas (dueño)

- ¿Qué se gana al vencer a un ghost? Por defecto, nada en cartas: solo ladder.
- ¿El Elo de un ghost decae con el tiempo?

## Decisiones del dueño (2026-10-25)

- **Recompensa:** temporadas. Al final de cada una, los del top ganan
  **pesetas**, una moneda para comprar cosméticos. Ganar a un ghost sigue
  sin dar cartas.
- **Decaimiento:** no hay decaimiento continuo. Al empezar cada temporada se
  hace un **reinicio suave** que acerca a todos a la media.

Las dos piden temporadas en el servidor → [S25](./S25-temporadas.md).

## Decisiones (delegadas: "continúa", 2026-10-23)

| Decisión | Tomada | Por qué |
|---|---|---|
| Recompensa por ganar a un ghost | **ninguna en cartas**: solo la clasificación | el valor por defecto del README; el combate es de práctica, así que no pasa por desafíos ni drops. **Sigue abierta para el dueño** |
| ¿El Elo decae? | **no** | sin datos de uso no hay a qué ajustar un decaimiento. **Sigue abierta para el dueño** |
| Ghosts de relleno | **12, generados por el servidor** en la primera petición de ghosts (dueño 0, "La arena" en el cliente): dos o tres razas distintas con sus hechizos y dos reglas (alejarse por debajo del 25 %, rematar con el hechizo firma por debajo del 40 %), Elo fijo de 700 a 1360 | `data-dist/` solo lo toca el dueño (AGENTS.md, restricción 4); generarlos en código es determinista y no publica datos nuevos |
| Rating del jugador | tabla propia `ghost_ratings` (Elo, combates, victorias), aparte de la Strength del 1 contra 1 | `ASYNC-PVP.md`: las dos escaleras no se mezclan; tampoco se toca el struct `Coach`, que comparten sesión y combate |
| Fórmula | Elo con K = 32. Contra el ghost de un jugador se mueven los dos ratings; contra uno de relleno, solo el del retador y con K/2. Mínimo de 100. Las repeticiones no puntúan | los de relleno anclan la escala; con K/2 farmearlos rinde poco |
| Emparejamiento | 60014 con id 0: el ghost de un jugador más cercano dentro de ±200; si no hay, el más cercano de todos (de relleno incluidos); nunca uno propio | con un solo jugador siempre hay rival |
| Clasificación | 60016 → 60017: mi Elo, mi puesto y mi registro, y los 50 primeros (solo quien ha combatido) | |

## A. Servidor

- [x] Migraciones 15 (`ghost_teams.battles/wins`) y 16 (`ghost_ratings`),
      con sus funciones de repo.
- [x] `game/ghost_ladder.go`: relleno, emparejamiento, Elo (en
      `recordGhostFight`) y 60016/60017.
- [x] Pruebas de unidad: `TestFillerGhosts`, `TestPickGhostFor`,
      `TestGhostElo` y `TestGhostLadder`.
- [x] e2e `TestGhostLadderWithOnePlayer`, el criterio de cierre: un solo
      coach. "Rival automático" le da uno de relleno, combate IA contra IA y
      sale en la clasificación, puesto 1 y fuera de 1000.

## B. Cliente

- [x] Pestaña "Clasificación" y botón "Rival automático" en Retar; los de
      relleno salen como "La arena".

## Criterio de cierre

Con un solo jugador conectado, el modo tiene rivales, ladder y recompensas
coherentes con la decisión tomada.

## Resultado

- **`ghost_smoke.gd` ampliado.** Tras el combate, `test2` vuelve al lobby.
  "Clasificación" le da Elo 984, puesto 1 y 1 combate, y el ghost de `test`
  sube a 1016. "Retar" lista los 12 de relleno y "Rival automático".
  Capturas: `ghost-ladder` y `ghost-fillers` en `~/codigo/capturas/s13/`.
- **Suites:** `go test ./...` en verde; ghost, relleno y migraciones también
  en Postgres 16 y MariaDB 11. `native_panels` 133 PASS;
  `run_tests.sh --headless` 295/295.
