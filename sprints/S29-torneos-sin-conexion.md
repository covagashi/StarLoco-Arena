# S29 — Torneos sin conexión

**Planificado, abierto y cerrado:** 2026-10-25 · **Hito:** M6 — Un juego de hoy · **Tamaño:** L · **Estado:** 🟢 cerrado

## Objetivo

La propuesta de S26, aprobada por el dueño ("1 ok"): un torneo no necesita
que sus jugadores estén conectados. Cada uno entrega un equipo con sus
reglas, como un fantasma; a la hora del torneo el servidor juega todo el
cuadro IA contra IA, y cada combate se puede ver después como replay.

## Decisiones (delegadas: "hazlo", 2026-10-25)

| Decisión | Tomada | Por qué |
|---|---|---|
| Qué torneos | los **clásicos** (equipo de Élite: 18 de las 22 definiciones, entre ellas las dos que el servidor ofrece por defecto). Los de **Historia y Cementerio siguen en vivo** | estos usan los luchadores de Historia, que se cansan, se hieren y mueren; jugarlos sin el jugador decidiría eso por él |
| Con qué equipo | el **último fantasma** que guardó el jugador, en el momento del sorteo | ya es "un equipo con sus reglas" (S13), está congelado y no toca a los luchadores reales; sin migración ni pantalla nueva. Para cambiar de equipo basta con guardar otro fantasma |
| Inscripción | en un torneo clásico se pide tener un fantasma: si no, 28608 con el **código 3**, y el cliente dice "crea uno en Ranking → Contra un fantasma" | mejor avisar al inscribirse que perder sin combatir |
| Cuándo | al **cerrarse la inscripción** (inicio del primer periodo), todo el cuadro de una vez, ronda a ronda | no hay que esperar a nadie; un torneo de 16 se juega en milisegundos |
| Sin fantasma al llegar el sorteo (borrado) | pierde **sin combate**; si ninguno de los dos tiene, pasa el primero del cruce | el cuadro siempre termina |
| Combate que no acaba | a las **40 rondas** gana el lado con más porcentaje de vida | la muerte súbita (ronda 15) no obliga a matar |
| Cómo se juega | **en síncrono**, en la goroutine del programador, sin actor ni relojes y sin registrarse en el `FightManager`, como lo hace `determinism_test.go`. Los dos lados son coaches sintéticos (`ghostCoachID`, `offlineCoachID`) | ningún coach real queda "dentro" de un combate (todos los manejadores buscan el combate por coach), y nada de estadísticas, premios ni guardados corre sobre ids sintéticos: `checkFightEnd` ve `f.offline` y solo anota al ganador |
| Grabación | un espectador falso (una `Session` sin socket) recibe lo mismo que un espectador real, con reloj virtual (350 ms por frame y 2,5 s de entrada), y se guarda en el formato de replay del cliente (SLRP, gzip) en la tabla `tournament_matches` (migración 18) | la replay la reproduce el `ReplayPlayer` de S11 sin cambios, y no depende de que la IA o el balance cambien después |
| Descarga | 60032/60033 (lista) y 60034/60035 (la grabación en trozos de 60 KB: un frame admite como máximo 64 KB). Las grabaciones son **públicas**, como el cuadro | |
| Interruptor | `world.offline_tournaments` en la configuración, **activado por defecto**; el servidor se lo dice al cliente en el 60001 | un operador puede volver a los torneos en vivo; las pruebas antiguas del modo en vivo siguen valiendo |

## Hecho

- **Servidor:** `game/tournament_offline.go` (el ejecutor síncrono, el
  grabador, el recorrido del cuadro y los opcodes), `PendingFixtures` en el
  gestor de torneos, `f.offline` en `checkFightEnd`, el atajo en
  `tickTournament` (sin periodos de búsqueda en un torneo sin conexión),
  `GhostRepo.LatestByCoach` y `tournament_matches` con sus funciones de
  repo. El premio sale como siempre: `awardTournamentPrize` (fichas de S26
  más la carta, si la hay) y `finishTournament`.
- **Cliente:** el calendario dice "Se juega solo…" y ya no muestra el
  botón de buscar; "Combates" lista lo jugado y "Ver" descarga la
  grabación, la guarda en `user://replays` (así también sale en Replays) y
  la abre en el visor de combates.

## Evidencia

- `TestOfflineTournamentPlaysTheWholeBracket`: cuatro coaches con fantasma;
  antes del sorteo no se juega nada; un tick juega los 3 combates en
  **7 ms**, cada grabación va de 8000 a 8300, el torneo se cierra con su
  ganador (que cobra 500 fichas) y ningún coach se queda en un combate; un
  segundo tick no cambia nada.
- `TestOfflineFixtureWithoutAGhostIsAWalkover`,
  `TestOfflineRegistrationNeedsAGhost` (28608 código 3, sin inscribir).
- `go test ./...` en verde en SQLite; store y game, también en **PostgreSQL
  16 y MariaDB 11** (podman). Las pruebas del modo en vivo siguen pasando
  (con el interruptor apagado, que es su valor en `Deps`).
- **En vivo** (`tourn_offline_smoke` 12/12): se siembra en la base de pruebas
  un torneo clásico ("Copa sin conexión", sorteo a 100 s) con `test2`
  inscrito y su fantasma. `test` se inscribe desde el cliente (aceptado),
  el código 3 se lee bien, y en el sorteo el servidor juega el cruce. Log:
  "offline fixture played … winner=2 loser=1 recorded=true", "credited
  tokens coach=2 why=tournament win tokens=500", "tournament finished
  winner=2". "Combates" lista "test2 venció a test · 11 rondas"; "Ver" abre
  el visor, la grabación se guarda en Replays, llega al resultado a ×4 y
  vuelve al lobby. 0 errores en el log del servidor.
- `run_tests.sh --headless` 429/0; `native_panels` 138 PASS.

## Pendiente

- Elegir el fantasma con el que se juega cada torneo (hoy, el último
  guardado).
- Un aviso al entrar si se jugó un torneo tuyo mientras estabas fuera (hoy
  se ve en el calendario).
