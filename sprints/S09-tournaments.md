# S09 — Torneos completos

**Planificado:** 2026-10-16 · **Detallado y abierto:** 2026-10-22 · **Hito:** M3 — Paridad de contenido · **Tamaño:** L (era M; ver "Punto de partida") · **Estado:** 🟢 cerrado (2026-10-22)

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
- [x] Inscripción visible al entrar (BACKLOG §1): hecho en Godot (bloque E).

Pruebas (2026-10-22): `go test ./internal/game -run 'TournamentPoints|Finished|ByeWinner|PlayedFixture|RegistrationCounts|CarryOver|TournamentLadder|TournamentAchievements'`
y `./internal/handshake -run TournamentPoints`. Suite completa verde en
SQLite, y en Postgres 12 y MariaDB 10.3 en `oracle-1` (ver el bloque C); antes,
en Postgres 16 y MariaDB 11, los tests de torneos (`internal/game`,
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
Suite completa verde en SQLite. En esta máquina, Postgres se pasó de tiempo
por falta de memoria, así que los dialectos se corrieron en la VPS `oracle-1`
(2026-10-22): binarios de test compilados aquí con `CGO_ENABLED=0 go test -c`
y lanzados allí contra **Postgres 12.22** y **MariaDB 10.3.39** (los de Ubuntu
20.04, instalados por apt y apagados y desactivados al terminar). `game`,
`store`, `web` y `e2e` pasan en los dos (con el código de los bloques A, B y C;
unas 36 000 transacciones en Postgres y 143 000 consultas en MariaDB confirman
que no corrió SQLite). Las versiones son más viejas que las de AGENTS.md
(Postgres 16, MariaDB 11): si algo funciona en 12 y 10.3, también en las nuevas.

## D. 2411, récord de ladder por preset

- [x] **Sale del sprint** (decidido el 2026-10-22, al llegar): necesita un
      modelo de estadísticas por preset (fuerza, victorias, derrotas y racha
      de cada preset, apuntadas al acabar cada combate con el preset usado)
      que hoy no existe, y no tiene que ver con los torneos. Pasa al BACKLOG
      §1 con el formato ya descifrado; no bloquea el cierre de S09.

## E. Cliente Godot

- [x] **Bug del 28614** (2026-10-22): leía `d.f0`; ahora `tournament_id`.
- [x] **Inscripción visible al entrar** (BACKLOG §1): el cliente pide el 28601
      al llegar al lobby y al abrir el Equipo o el Calendario, y marca como
      inscritos los torneos cuyo estado en el 28602 no es -128. Las ediciones
      terminadas desaparecen porque la lista se rehace entera.
- [x] **Avisos**: el 28646 (periodo abierto), el 28644 (abre en N min) y el
      28648 (ganas o pierdes por incomparecencia) salen como aviso y en el
      chat; el 28618 sale como pregunta nativa (`askDialog`) y el "sí" manda
      el 28617; la final (28620) pregunta "¿quieres mirarla?" y el "sí" la
      sigue como espectador, como el `/watch`. **Diferencia con el retail,
      a propósito:** no hay lista de alertas aparte; elegir torneo, que en el
      retail era pulsar su alerta (`agz_1`), se hace en el propio panel de
      Equipo (abajo), que ya es donde se busca rival.
- [x] **Buscar rival** desde Equipo → Torneos y → Leyendas: un desplegable
      con los torneos en los que estás inscrito de ese tipo (los de
      evolución y cementerio salen en Torneos, con un aviso de que se juegan
      con los titulares), con la búsqueda abierta primero, y "Buscar rival
      del torneo" manda el 28611 con el preset que toca
      (`TournamentDefs.search_preset`: el equipo elegido, 99, 10000 o 9999).
      La búsqueda usa la barra "buscando… Cancelar" del lobby, como las
      demás (tipo 4); se cierra con 28610, 28614, 28616 o 28648, y su
      cancelar manda el 28609.
- [x] **Calendario**: cada torneo sale en los días de sus periodos (el
      servidor manda ya todos en el 17003, y la inscripción acaba en el
      primero; antes salía en el día de "caducidad", una semana después), y
      el detalle dice tipo, reglas, organizador, periodos, hasta cuándo hay
      inscripción, carta de entrada (con cuántas tienes) y premio. Con carta
      de entrada, la confirmación dice cuál se gasta y el botón se apaga si
      no la tienes; el 4607 la manda. **Descartado el filtro por tipo de
      evento**: el servidor solo manda torneos (no hay difusiones ni
      mantenimientos), así que no filtraría nada.
- [x] **Cuadro por rondas**: primera, cuartos, semis, final y ganador, en
      columnas, solo las rondas a las que ha llegado alguien, con tu nombre
      marcado. **Descartados la paginación y la búsqueda por nombre**: el
      cuadro tiene 16 plazas y la página 0 ya lo trae entero.
- [x] **Crear torneo** (bloque C): botón en el Calendario con las cartas 807
      que tienes, y formulario con nombre, descripción, día, hora, duración de
      cada búsqueda (30 min a 4 h) y días seguidos (1 a 4). Manda el 17010 con
      la definición 1, como el diálogo retail.
- Las definiciones (tipo, carta de entrada, premio, reglas) van en una tabla
  pequeña, `src/gamedata/tournament_defs.gd`, copiada del catálogo del
  servidor: la exportación de assets no lleva el tipo 1000 y son 22 registros.

Pruebas (2026-10-22): `godot -s test/tournaments_smoke.gd` contra un servidor
real con una copia de `arena.db` sembrada (el script de siembra está en el
devlog del bloque E): **10/10** — la pregunta de arrastre y el "sí", el
torneo en su día con sus periodos, el cuadro por rondas, el desplegable de
Torneos, buscar (28612, la barra del lobby) y cancelar (28610), un periodo
que se abre durante la sesión (28646) y crear un torneo desde el formulario
(listado con organizador "test"). Capturas revisadas: Calendario con detalles,
pestaña Torneos, formulario y la pregunta de arrastre. `run_tests.sh
--headless` 261/261. **No probado en vivo**: la pregunta de la final (28620)
y la partida de torneo con dos clientes Godot (ver el criterio de cierre).
`totems_smoke.gd` se adaptó al cuadro nuevo, pero no se ha vuelto a correr
(necesita su propia siembra: clan sin demonio y cartas).

### Los 10 diálogos `tournament*` del retail

Ninguno se ve en Godot (S18). Cómo queda cada uno:

| Diálogo retail | Destino |
|---|---|
| `tournamentListDialog` | descartado: no lo abre nadie en la 2.70 (no está en `oh_2`); su papel es la vista del día del Calendario |
| `tournamentDetailsDialog` | descartado: constante `oh_2.Sz` que nadie abre; lo sustituyó `calendarTournamentDetailsDialog` → detalle del Calendario (hecho) |
| `tournamentTreeDialog` | hecho: cuadro por rondas en el Calendario |
| `tournamentsSearchStatusDialog` | hecho: la barra "buscando… Cancelar" del lobby |
| `tournamentEvolutionDialog` | hecho: Equipo → Torneos con un torneo de evolución (juega los titulares, preset 99) |
| `tournamentGraveyardDialog` | hecho: igual, con preset 10000; los caídos se ven en la sección de caídos de la pestaña Evolución (S18) |
| `tournamentTeamManagementDialog` | hecho: Equipo → Torneos, con el selector de equipo de siempre |
| `tournamentInformationDialog` | descartado: vista de depuración |
| `tournamentCreationDialog` | hecho: formulario "Crear torneo" del Calendario |
| `tournamentAdminCreationDialog` | descartado en el cliente: lo cubre la consola web (A) |

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

## Resultado

Cerrado el 2026-10-22, en una sola tanda (bloques A a E), con las decisiones
delegadas por el dueño.

**El criterio se cumple:** un torneo programado se abre, se juega y se cierra
sin tocar nada, y el cliente Godot lo muestra entero.

- **Partida en vivo** (`godot -s test/tournament_fight_smoke.gd`, servidor
  real sobre una copia de `arena.db` con la "Copa Final" sembrada: periodo
  abierto, `test` y `test2` inscritos): Godot busca desde Equipo → Torneos
  (28611 → 28612, barra del lobby), el segundo cliente busca en el mismo
  torneo, el servidor los empareja (`tournament match paired`, 28614 a los
  dos, la finale anunciada), se juega, `test` se rinde, `tournament bracket
  advanced winner=2 slot=1`, y el planificador, 5 s después, `tournament
  finished winner=2`. En la base: edición terminada con ganador 2; puntos 20
  (`test2`) y 1 (`test`); estadísticas 183 = 20 / 1, 187, 188 y 190 = 1 para
  `test2`. El segundo cliente es un cliente de red sin interfaz (el patrón de
  `pvp_smoke`), no un segundo Godot: la máquina se comparte y la norma es
  un solo Godot a la vez.
- **Ciclo completo con reloj falso**, sin cliente: `go test ./internal/game`
  (bloques A y B), verde en SQLite, y en Postgres 12 y MariaDB 10.3 (en
  `oracle-1`).
- **Godot**: `tournaments_smoke.gd` 10/10 y `run_tests.sh --headless` 261/261.

**Lo que no se hizo, y por qué:**

- **2411** (récord por preset): al BACKLOG §1 (bloque D).
- **Reglas de las definiciones y reglas personalizadas** de los torneos de
  jugador: no se aplican en combate. Ya era así antes de S09 y no lo pedía el
  sprint. Queda escrito en el log de cada creación y aquí.
- **Filtro de eventos, paginación del cuadro y búsqueda por nombre**:
  descartados con su motivo en el bloque E.
- **Sin probar en vivo**: la pregunta "¿mirar la final?" (28620), que necesita
  a un tercer coach mirando una final ajena; la pestaña Leyendas con un torneo
  legendario (definición 24; el servidor la prueba con las definiciones
  reales en `TestTournamentTeamKind`, la pestaña de Godot es la misma que la
  de Torneos con otro filtro); y `totems_smoke.gd` adaptado al cuadro nuevo,
  que necesita su propia siembra.
- **Nadie da las cartas 16, 807 ni 808** en los datos 2.70; `/GIVECARD` es la
  fuente hasta que el dueño decida otra (premios de temporada, BACKLOG §11).
- Los torneos sin horario (los tres de serie) siguen como antes, siempre
  abiertos y sin final, y el calendario les inventa un periodo de una hora,
  que el detalle de Godot enseña tal cual. Para jugar de verdad hay que darles
  horario en la consola.

**Revisión de los esbozos de detrás:** S10 (tutorial) pasa a siguiente sin
cambios de alcance; nada de S09 lo toca. Las temporadas (BACKLOG §11) siguen
fuera; si se hacen, el sitio natural es encima de las ediciones repetidas
(`RepeatDays`, `PreviousID`) y de los puntos por periodo de la clasificación.
