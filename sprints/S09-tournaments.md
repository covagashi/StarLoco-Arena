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

- [x] **28618 / 28617, arrastre** (2026-10-22, `tournament_carry.go`). Al
      terminar sin ganador una edición que se repite, los inscritos que seguían
      en liza (su cruce sin decidir) quedan marcados `Unfinished`. Tras el
      siguiente 28602 se les pregunta **una vez** (un "no" no manda nada, así
      que volver a preguntar sería insistir). **Trampa encontrada en el
      cliente:** `ajp_0` busca el id del 28618 en el registro del 28602 y, si
      no está, no enseña nada; una edición terminada ya no se lista, así que el
      28618 lleva el id de la **siguiente** edición (mismo nombre). El "sí"
      (28617) solo vale para quien recibió la pregunta y mientras la siguiente
      edición admite inscripciones; inscribe al coach con prioridad de
      casilla: los arrastrados se siembran primero, así que nunca se quedan
      fuera del cuadro de 16. Como el 28617 no tiene respuesta, se reenvía el
      28602 para que la fila salga inscrita.
- [x] **Puntos de torneo** (2026-10-22, `tournament_results.go`): por edición,
      1 por participar y 3, 6 o 10 según los cruces ganados; el ganador, 20.
      Los pases sin rival no cuentan: quien gana un torneo vacío por estar solo
      se lleva 1 punto, no 20. La escala sale de los logros: el de más puntos
      pide 20 000 y el de más victorias 1 000, o sea 20 por victoria. El total
      es la estadística 183 y va en el 2052 (`aez_0.anV`, antes 0 fijo).
- [x] **Clasificación Tournoi (27507)** con datos: puntos de las ediciones
      terminadas en el mes, trimestre y año elegidos (0-based, como el
      cliente; año 0 = ahora, que es lo que manda Godot al abrir), con el
      puesto propio. **Encontrado:** las tres listas del cliente retail son de
      10 filas, sin comprobar índices, y el primer entero de cada ventana es
      hasta dónde limpia la lista, no el total; ahora va el tamaño de página
      (10). El ranking 1v1 (27501) manda hasta 20 filas a una lista de 10,
      así que en el retail con más de 10 clasificados fallaría: apuntado en el
      BACKLOG (§1), sin tocar, porque Godot no tiene el problema.
- [x] **Estadísticas** 183 (puntos), 187 y 190 (torneos ganados, solo con un
      cruce ganado de verdad), 188 (duelos ganados, solo jugados, no por
      incomparecencia), 189 (inscripciones, una por torneo). Las rachas: un
      cruce de torneo cuenta ya para la racha de su modo (1v1, o evolución),
      porque es clasificatorio y mueve la fuerza 1v1.
- [x] **Los 25 logros** (182–206): todos son umbrales sobre 183, 187, 188 y
      189 (5 a 1 000; 5 a 20 000 los de puntos), así que ya se pueden
      conseguir. Probado de punta a punta el 182: cinco inscripciones por el
      4607 real y llega el 22000.
- [ ] Inscripción visible al entrar (BACKLOG §1): el 28602 ya lleva el estado
      por coach; falta que Godot lo use (bloque E).

Pruebas (2026-10-22): `go test ./internal/game -run 'TournamentPoints|Finished|ByeWinner|PlayedFixture|RegistrationCounts|CarryOver|TournamentLadder|TournamentAchievements'`
y `./internal/handshake -run TournamentPoints`. Suite completa verde en
SQLite; en Postgres 16 y MariaDB 11, los tests de torneos (`internal/game`,
el filtro de arriba más los del bloque A) y de `internal/store`. La suite
completa en esos dos dialectos se pasó por tiempo (10 min) porque la máquina
estaba saturada por otros procesos (carga media 72–150, 1,2 GB libres; hasta
`web`, que el bloque B no toca, se pasó), así que se repitió solo lo afectado.
Migración 11.

## C. Servidor: torneos de jugador (17010, cartas 807 y 808)

- [x] **17010** (2026-10-22, `tournament_player.go`). **Corrección de lo que
      se daba por sabido:** el inventario decía que un torneo de jugador "no
      tiene definición tipo 1000"; leyendo `aFu.encode` y `aob_2`, el mensaje
      **sí la lleva** (`selectedTournamentDefinition`, 1 por defecto), así que
      no hay hueco de modelo: es una edición más, con `CreatorCoachID`.
      Formato entero en `OPCODE-INVENTORY.md`. Se toman la definición, el
      nombre, la descripción y los periodos de juego (hasta 4) como periodos
      de búsqueda. Cuesta una 807; se refusa una definición con premio o con
      entrada (sería un grifo de cartas entre amigos), un inicio pasado o a
      más de un año, periodos solapados o de menos de un minuto o más de 24 h.
      Sin repetición. Las reglas personalizadas del diálogo **no se aplican**
      (tampoco las de las definiciones; queda dicho en el log). Un torneo de
      jugador **no da puntos ni cuenta como oficial** (187), sí como torneo
      ganado (190), para que no sirva para inflar la clasificación.
- [x] **Código 66** `badCoachCardQuantity`: 25000 con 66 si se manda el 17010
      sin la 807 (el cliente ya lo comprueba antes, así que uno honrado no lo
      ve). Primero se crea la fila y luego se cobra la carta: si falla el
      cobro se borra, y un rechazo nunca cuesta la carta.
- [x] **Carta 808 "Ticket MasterCoach"**: es la carta de entrada de la
      definición 19 (y la 16 de la 13). El cliente ya preguntaba "¿gastar
      una?" y mandaba su id en el 4607 (a veces negado); el servidor ahora la
      cobra al inscribirse, una sola vez. La consola ofrece ya esas dos
      definiciones, con la carta en la etiqueta.
- [x] **Nadie da esas cartas** (encontrado): 16, 807 y 808 no tienen precio
      ni salen como premio de desafío o de torneo en los datos 2.70; en el
      retail se repartían por eventos. Nuevo comando de GM
      `/GIVECARD <coach> <carta> [cantidad]` (solo admin), que también sirve
      para los premios de temporada que el dueño tiene en mente (BACKLOG §11).

Pruebas (2026-10-22): `go test ./internal/game -run 'PlayerTournament|EntryCard|GMGiveCard'`
(el 17010 construido byte a byte como `aFu.encode`, sin carta → código 66,
siete rechazos que no cuestan la carta, sin puntos ni 187, la 808 cobrada una
vez con el id negado, `/GIVECARD`) y `./internal/web -run Tournament`.
Suite completa verde en SQLite. En Postgres pasaron store, web y e2e; `game`
se pasó de tiempo (25 min) con la máquina sin memoria (250 MB libres, carga
83, por otros procesos), y MariaDB no llegó a correr. **Pendiente**: repetir
`internal/game` en Postgres y todo en MariaDB cuando la máquina esté libre.

## D. 2411, récord de ladder por preset

- [x] **Sale del sprint** (decidido el 2026-10-22, al llegar): necesita un
      modelo de estadísticas por preset (fuerza, victorias, derrotas y racha
      de cada preset, apuntadas al acabar cada combate con el preset usado)
      que hoy no existe, y no tiene que ver con los torneos. Pasa al BACKLOG
      §1 con el formato ya descifrado; no bloquea el cierre de S09.

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
| Regla del arrastre (28617): ¿qué se lleva el coach al siguiente torneo? | la inscripción en la siguiente edición, sembrado antes que los nuevos (nunca se queda fuera del cuadro de 16), nada más |
| Puntos de torneo | por edición: 1 / 3 / 6 / 10 según cruces ganados, 20 el ganador (sin contar pases); acumulados |
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
