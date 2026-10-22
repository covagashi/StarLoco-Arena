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

- [ ] Horario en la consola web: inicio y duración de los periodos de
      búsqueda (y repetición, como el `tournamentAdminCreationDialog` del
      retail: definiciones, 6 franjas, repetir). Con prueba en
      `web/tournaments_test.go`.
- [ ] Estado del torneo (programado → inscripción → en juego → terminado) en
      el modelo y el store, con migración y prueba en los tres dialectos.
- [ ] Un planificador por reloj en el servidor: abre y cierra periodos
      (28630 `open=1/0`, 28644 la cuenta atrás), resuelve los forfeits al
      cerrar (28648) en vez de al pedir la lista, y cierra el torneo cuando hay
      ganador o se acaban los periodos. Reloj inyectable para las pruebas.
- [ ] 28646 "se abre el periodo": decidir con el cliente en la mano si se
      manda (el `zN` no tiene la guarda de duplicados del 28630). Si la alerta
      nativa de Godot (bloque E) deduplica por id, se manda; el retail queda
      fuera de alcance.
- [ ] Al terminar: se retira la alerta, se archivan inscripciones y cuadro, y
      se limpia el gestor en memoria. De paso: borrar un torneo hoy deja sus
      casillas y el gestor (`tournament_repo.go:76`).
- [ ] Aplicar el tipo de equipo y las reglas de la definición al buscar
      rival (28611): clásico con sus presets, evolución (preset 99),
      cementerio, legendario (9999 con el banquillo de leyendas,
      `handlers_evolution.go:114`).
- [ ] Comentarios y docs viejos que aún dicen "no hay capa de partidas":
      `tournaments.go:19`, `tournament_tree.go:99`, `handlers_totems.go:192`,
      `domain/tournament.go:10,146`, `OPCODE-INVENTORY.md:845` ("no schedule
      columns"), el texto de B-100.

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

## Decisiones del dueño

Se trabaja con la opción *por defecto* mientras no diga otra cosa.

| Decisión | Por defecto |
|---|---|
| Regla del arrastre (28617): ¿qué se lleva el coach al siguiente torneo? | la inscripción con preferencia de casilla, nada más |
| Puntos de torneo | ronda alcanzada por torneo terminado, acumulada |
| Torneos de jugador (17010): ¿entran en la 1.0? | sí, sobre una definición clásica base; se cae si el modelo no da |
| ¿Los periodos de torneo son la base de las temporadas (BACKLOG §11)? | no en este sprint; solo se deja apuntado |

## Criterio de cierre

Un torneo programado desde la consola se abre, se juega y se cierra **sin
intervención manual**, con premios, puntos, estadísticas y arrastre, y el
cliente Godot lo muestra entero (alertas, búsqueda en Torneos y Leyendas,
cuadro, detalles). Pruebas: e2e del ciclo completo con reloj falso (programado
→ periodo → partidas → forfeit → terminado → 28618 al siguiente login) en los
tres dialectos, más una partida en vivo con dos clientes Godot. Los 10
diálogos `tournament*`, cubiertos o descartados en la tabla de arriba.
