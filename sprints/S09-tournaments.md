# S09 — Torneos completos

**Planificado:** 2026-10-16 · **Detallado y abierto:** 2026-10-22 · **Hito:** M3 — Paridad de contenido · **Tamaño:** L (era M; ver "Punto de partida") · **Estado:** 🟡 abierto (2026-10-22)

## Objetivo

El ítem 32 (la capa de partidas del torneo: cuadros, emparejamientos, premios)
está hecho y verificado en vivo. Falta lo de alrededor para que un torneo viva
solo de principio a fin, y que el cliente Godot lo muestre.

## Punto de partida (auditoría del 2026-10-22)

Lo que el esbozo daba por hecho y no lo está:

- **Ningún torneo tiene horario.** `domain.Tournament` tiene
  `SearchPeriodStart`/`SearchPeriodMinutes`, pero la consola web
  (`readTournamentForm`, `handlers_tournaments.go:107`) y
  `TournamentRepo.Update` (`tournament_repo.go:61`) no los leen ni escriben.
  Solo los pone un test o un `UPDATE` a mano, así que en la práctica la
  búsqueda está **siempre abierta** (`handlers_totems.go:482`).
- **Nada corre por reloj.** No hay ticker: los forfeits
  (`settleTournamentPeriod`, `tournament_finale.go:117`) se resuelven de forma
  perezosa cuando alguien pide la lista (28601).
- **Un torneo no termina nunca.** No hay estado: tras pagar el premio
  (`awardTournamentPrize`, `handlers_fight_combat.go:1076`) quedan las
  inscripciones, las casillas del cuadro y la alerta 28630, y nada lo recicla.
  Sin final no hay arrastre (28618/28617) ni "inscrito sin terminar".
- **El tipo de equipo del torneo no se aplica.** La definición trae clásico /
  evolución / cementerio / legendario (`gamedata/tournaments.go`) y sus reglas
  de combate; solo se enseñan en la consola.
- **Leyendas es un tipo de torneo**, no una clasificación: la pestaña manda el
  mismo 28611 con el preset 9999 (`hu_2.java:848`) para el torneo elegido en
  la alerta. Hoy el 9999 cae al equipo titular sin más (`handlers_totems.go:326`).
- **Godot** no tiene lista de alertas (en el retail es la única forma de elegir
  torneo: `agz_1` → `vk_1.ad(tid)`), ni vista de cuadro (es una tabla plana,
  siempre la página 0), ni detalles ni filtro en el calendario
  (`main.gd:496-498`, no-ops). Las pestañas Torneos y Leyendas dicen "not
  available yet" (`lobby_panels.gd:179`).

Por eso pasa de M a L. El orden de abajo es el de ejecución: cada bloque
depende del anterior.

## A. Servidor: un torneo con horario que empieza y termina

- [x] **Horario en la consola web** (2026-10-22): inicio del primer periodo,
      duración, número de periodos (1–6, las franjas del
      `tournamentAdminCreationDialog`), minutos entre inicios y repetir cada N
      días. Validado: periodos que se solapan, más de 6, duración 0, repetir
      sin inicio, ediciones que se pisan, fecha ilegible → 400. La lista
      enseña la fase de cada edición ("Registration until…", "Search period
      2 of 4 open", "Finished, won by X"). Sin inicio, el torneo sigue como
      antes: siempre abierto y sin final.
- [x] **Ediciones** (2026-10-22): `domain.Tournament` es una edición, con
      `SearchPeriods`, `PeriodIntervalMinutes`, `RepeatDays`, `FinishedAt`,
      `WinnerCoachID` y `PreviousID`; migración 10. La inscripción se cierra
      sola al empezar el primer periodo (`RegistrationOpenAt`). Una edición
      terminada sale de la lista de jugadores; si repite, el planificador crea
      la siguiente como fila nueva (wire id nuevo, cuadro vacío) y la vieja se
      queda como historial, que es lo que necesita el arrastre (B).
- [x] **Planificador por reloj** (`tournament_schedule.go`, cada 5 s, reloj
      inyectable con `Deps.TournamentClock`): al abrir un periodo manda 28646
      a los inscritos conectados; al cerrarlo resuelve los forfeits (28648),
      suelta a quien seguía esperando (28610) y retira la alerta (28630
      `open=0`); termina la edición cuando el cuadro tiene ganador o se cierra
      el último periodo (sin ganador si nadie jugó; si la final aún se está
      jugando, espera a que acabe). La resolución perezosa al
      pedir la lista (28601) se ha quitado. Tras un reinicio, los periodos ya
      cerrados no se re-resuelven con los que buscan en el periodo actual.
- [x] **28646 sí se manda** (2026-10-22). Leído el `zN`: el 28630 `open=0` y el
      28648 quitan la fila de la alerta, y el 28646 la añade sin guarda y quita
      la cuenta atrás del 28644. Como cada periodo se cierra con 28630 `open=0`
      antes de que el siguiente mande su 28646, no se duplica nunca, tampoco
      en el retail. El 28630 `open=1` queda para quien abre la lista con un
      periodo ya abierto (el `zN` lo deduplica). Además: el 28644 se apilaba
      (una fila por cada vez que se abría el calendario); ahora va una vez por
      periodo y sesión.
- [x] **Al terminar** se retiran la alerta y la finale, las inscripciones y el
      cuadro se quedan en la base como historial y el gestor en memoria olvida
      la edición (también al arrancar, para las ya terminadas). Borrar un
      torneo borra ahora también sus casillas, que si no las heredaba la fila
      que reutilizase el id.
- [x] **Tipo de equipo** (2026-10-22, `tournament_teams.go`): el 28611 solo se
      acepta con el preset que manda la pestaña de ese tipo (`agz_1`, `hu_2`,
      `en_2`): clásico un preset real, evolución 99, cementerio 10000,
      legendario 9999. Cada tipo juega su alineación: el preset (clásico), los
      titulares (evolución y cementerio, con las reglas de evolución) o los
      legendarios. **Bug encontrado de paso:** el preset del segundo en
      buscar se aplicaba a los dos lados, así que el primero jugaba con un
      solo luchador y el segundo siempre con sus titulares. Ahora cada uno
      juega el preset con el que buscó.
- [x] Comentarios y docs viejos: `tournaments.go`, `tournament_tree.go`,
      `handlers_totems.go`, `domain/tournament.go`, `OPCODE-INVENTORY.md`
      (28646 pasa a E, 155 emitidos), `STATUS.md` y una nota en B-100.

Pruebas (2026-10-22):

- `go test ./internal/game -run 'Scheduled|Undecided|LoneEntrant|RestartMid|RegistrationCloses|TeamKind|EachSidesOwnPreset|LastPeriodWaits'`:
  el ciclo entero con reloj falso (inscripción → periodo 1 → forfeits → periodo 2
  → ganador → terminado → siguiente edición una semana después), la edición
  que termina sin ganador, el inscrito único que gana al cerrarse el cuadro,
  el reinicio a mitad de periodo, la inscripción cerrada por el 4607 real, los
  cuatro tipos de equipo con las definiciones reales, cada lado con su
  preset (falla con el código anterior) y la final en juego al cerrarse el
  último periodo.
- `go test ./internal/store -run Edition` y `./internal/web -run Schedule`.
- Suite completa (`go test ./internal/... ./test/...`) verde en **SQLite,
  Postgres 16 y MariaDB 11**.
- **En vivo** con el binario real sobre una copia de `arena.db` (migración 10
  aplicada sin tocar nada): un torneo de 2 periodos de 1 minuto, repetición
  diaria, dos inscritos que no juegan. Log: `search period opened` 15:24:24 →
  `closed` 15:25:24 → `opened` → `closed` 15:26:24 → `tournament finished
  winner=0` → `next edition opened from=2600004 to=2600005
  start=2026-10-23T13:24:24Z`. Sin cliente conectado: lo que ve el jugador
  (alertas, búsqueda) es el bloque E, y la partida en vivo con dos clientes
  va en el cierre del sprint.

## B. Servidor: arrastre, puntos y estadísticas

- [ ] **28618 / 28617, arrastre entre torneos.** El retail solo dice la
      pregunta ("¿llevar mi posición al siguiente torneo del mismo tipo?"); la
      regla no está en el cliente. Por defecto (ver "Decisiones"): el coach
      que estaba inscrito en un torneo terminado sin jugar todas sus rondas
      recibe el 28618 al entrar; si dice que sí (28617), queda inscrito en el
      siguiente torneo de la misma definición con preferencia de casilla.
- [ ] **Puntos de torneo del coach** en el 2052 (blob 0x100, `aez_0.anV`;
      hoy 0 fijo en `handshake/coach.go:263`) y la clasificación Tournoi
      (27507, hoy vacía, `handlers_ladder.go:437`). Necesita un modelo de
      puntos: por defecto, ronda alcanzada en cada torneo terminado.
- [ ] **Estadísticas 183, 187, 188, 189** (puntos máximos en torneo, torneos
      oficiales ganados, duelos ganados en torneo, inscripciones): apuntarlas
      en `coach_statistics.go` (`statBatch`) como las demás. Las rachas en
      combates de torneo (hoy fuera, `coach_statistics.go:76`).
- [ ] Comprobar uno a uno los 25 logros que dependían de torneos
      (`v2.70:ROADMAP.md:1651`) y dejar escrito cuáles ya se consiguen.
- [ ] Inscripción visible al entrar (BACKLOG §1, "Inscripción a torneos"): el
      28602 ya lleva el estado por coach; que Godot lo use (bloque E).

## C. Servidor: torneos de jugador (17010, cartas 807 y 808)

- [ ] **17010**: el cliente lo manda con la carta 807 "Création de Tournoi"
      (`oz_1` 20072: nombre, descripción, mes y hora) y no espera respuesta.
      El hueco del modelo: un torneo de jugador no tiene definición tipo 1000
      y el cliente la lee sin guarda al inscribirse. Por defecto: se crea
      sobre una definición base (clásica, sin carta de entrada ni premio), se
      gasta la 807 y entra en el calendario de todos.
- [ ] Código de error 66 `badCoachCardQuantity` (el único que no está en
      `je_2`): su disparador plausible es este.
- [ ] Carta 808 "Ticket MasterCoach" (viene de S05): leer qué la mira en el
      flujo de torneos y hacerla o descartarla por escrito.

Si al leerlo el modelo cuesta más que lo que da, este bloque se descarta por
escrito o sale a su propio sprint; no bloquea el cierre de A, B, D y E.

## D. 2411, récord de ladder por preset

- [ ] Necesita estadísticas por preset, que hoy no existen (todo es por
      coach). No es de torneos: **se decide al llegar** si se hace aquí o sale
      a S14 (recompensas) o al BACKLOG.

## E. Cliente Godot

- [ ] **Bug**: el 28614 lee `d.f0`, pero el campo decodificado es
      `tournament_id` (`main.gd:1176`, `message_defs.gd:332`).
- [ ] **Lista de alertas nativa** (el `zN`/`iz_1` del retail): 28620 (con
      "¿mirar?"), 28630, 28644, 28646, 28648; deduplica por id de torneo, y
      al pulsarla elige el torneo y abre el equipo en la pestaña que toca
      (evolución, Torneos con solo los presets permitidos, Leyendas), como
      `agz_1.java:44-72`.
- [ ] **Buscar rival** desde las pestañas Torneos (28611 con el preset) y
      Leyendas (9999), con un aviso nativo de "buscando… Cancelar" que se
      cierra con 28610/28614/28648 (el `tournamentsSearchStatusDialog`).
- [ ] **Calendario**: detalles del torneo (ilustración, horario, nivel,
      reglas, premios, carta de entrada) y el filtro por tipo de evento
      (difusión / torneo / mantenimiento), los dos solo de cliente como en el
      retail (`aug.java:106-148`). La inscripción pide la carta de entrada
      cuando la definición la exige (hoy manda preset -1 y no mira nada).
- [ ] **Cuadro** con rondas (primera, cuartos, semis, final, ganador),
      paginado y búsqueda por nombre (28649 página + nombre), marcando al
      coach propio. Hoy es una tabla plana.
- [ ] Inscripción visible al entrar, desde el 28602 (ver B).
- [ ] Si se hace C: formulario nativo de torneo de jugador.

### Los 10 diálogos `tournament*` del retail

El esbozo decía 8; son 10. Ninguno se ve en Godot (S18). Cada uno se cubre con
un panel nativo o se descarta aquí:

| Diálogo retail | Destino |
|---|---|
| `tournamentListDialog` | descartar: no lo abre nadie en la 2.70 (no está en `oh_2`); su papel es la vista del día del calendario |
| `tournamentDetailsDialog` | descartar: constante `oh_2.Sz` que nadie abre; lo sustituyó `calendarTournamentDetailsDialog` → detalles del calendario |
| `tournamentTreeDialog` | cuadro nativo (E) |
| `tournamentsSearchStatusDialog` | aviso "buscando… Cancelar" (E) |
| `tournamentEvolutionDialog` | panel de equipo en modo torneo, pestaña Evolución (E) |
| `tournamentGraveyardDialog` | sección de caídos del panel de equipo en modo torneo (E) |
| `tournamentTeamManagementDialog` | pestaña Torneos del panel de equipo (E) |
| `tournamentInformationDialog` | descartar: vista de depuración |
| `tournamentCreationDialog` | formulario de torneo de jugador, solo si se hace C |
| `tournamentAdminCreationDialog` | descartar en el cliente: lo cubre la consola web (A) |

## Decisiones

El dueño las delegó el 2026-10-22 ("elige tú, lo que sea más conveniente");
se quedan las que estaban por defecto:

| Decisión | Tomada |
|---|---|
| Regla del arrastre (28617): ¿qué se lleva el coach al siguiente torneo? | la inscripción en la siguiente edición, con preferencia de casilla, nada más |
| Puntos de torneo | ronda alcanzada por torneo terminado, acumulada |
| Torneos de jugador (17010): ¿entran en la 1.0? | sí, sobre una definición clásica base; se cae si el modelo no da |
| ¿Los periodos de torneo son la base de las temporadas (BACKLOG §11)? | no en este sprint; solo se deja apuntado |
| 28646 (decidida en A) | se manda, ordenado tras el 28630 `open=0` |
| Tipo cementerio: ¿con qué equipo se juega? (decidida en A) | los titulares con reglas de evolución, como el 99; el diálogo del cementerio solo lista los caídos de ese equipo |

## Criterio de cierre

Un torneo programado desde la consola se abre, se juega y se cierra **sin
intervención manual**, con premios, puntos, estadísticas y arrastre, y el
cliente Godot lo muestra entero (alertas, búsqueda en Torneos y Leyendas,
cuadro, detalles). Pruebas: e2e del ciclo completo con reloj falso (programado
→ periodo → partidas → forfeit → terminado → 28618 al siguiente login) en los
tres dialectos, más una partida en vivo con dos clientes Godot. Los 10
diálogos `tournament*`, cubiertos o descartados en la tabla de arriba.
