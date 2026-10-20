# 2026-10-20 — S18: tótems al Calendario y al Clan, fuegos en el lobby

Pedido: el dueño aceptó las tres propuestas ("1.- ok 2.- ok 3.- si crees
que está bien hazlo en el lobby pero si es difícil quítalo"). Se pudo
hacer en el lobby.

## Hecho (en `main-covaga`)

- **Tótem de torneos → Calendario.** En el detalle del día, cada torneo
  dice si estás inscrito, si las inscripciones están abiertas o si buscas
  rival, y ofrece Inscribirme, Ver cuadro (28649 → 28650, en una tabla) y
  Buscar rival / Cancelar búsqueda (28611 / 28609) cuando la ventana de
  búsqueda está abierta. Los resultados salen bajo el torneo. Al abrir el
  Calendario se pide también la lista (28601), que trae el estado de las
  inscripciones y los avisos de búsqueda (28630).
- **Tótem de demonios → Social → Clan.** Una sección "Demonio del clan":
  a cuál sirve y, para el líder, "Ofrecer cartas al demonio", que abre
  `src/ui/demon_panel.gd` (sustituye al XML `demonAffiliationDialog`):
  elegir demonio si el clan no tiene, tus cartas, la ofrenda con la
  reputación que vale, la clasificación de clanes de ese demonio (27510 →
  27511) y Ofrecer con confirmación (las cartas se pierden).
- Los demonios se llaman por número romano, como el retail (`afg_1.kn`):
  "Demonio XVI". También en la pestaña Demonios de Clasificación, que decía
  "Demon 16".
- **Fuegos artificiales en el lobby.** `src/ui/firework_fx.gd`: cohete,
  estallido o fuente según la carta, con píxeles en el color de la carta,
  sobre el fondo y detrás de las ventanas. `lobby_screen.firework()` lo
  lanza al llegar un 22094, también los que lanzan otros. Lanzador nativo
  `src/ui/firework_panel.gd` (sustituye al XML `fireworkDialog`): hasta 8,
  cada uno con su espera.
- `cmd/dumpcards` exporta `fwType` y `fwColour`; `cards.json` regenerado
  (el resto de campos, idéntico: comparado).
- "Servicios" ya no lista los tótems. Fuera `_open_demon_totem`,
  `_open_tournament_totem`, `_on_tournament_sel`, `_open_firework_debug` y
  sus ramas de `ElementDlg`.
- Claves `tourn.*` que el código usaba y no estaban en ninguna tabla:
  añadidas en es/en/fr.

## Encontrado

- Tras una ofrenda aceptada **el servidor gasta las cartas pero no manda
  inventario** (el retail ya las quitaba de su vista al enviar). El cliente
  ahora las descuenta al recibir el 5403 de éxito.
- La clasificación de un demonio **solo lista clanes activos** (5+
  miembros, `GuildActiveMinMembers`). El clan del test tiene uno: el panel
  lo explica en vez de enseñar una tabla vacía sin más.
- El cuadro de un torneo con un solo inscrito enseña la misma persona en
  cinco plazas: es su plaza y su avance por un cuadro sin rivales. La
  inscripción está guardada una sola vez.
- Al BACKLOG: nombres de cartas solo en inglés, la tabla de miembros del
  clan vacía, y que el cliente no sabe al entrar en qué torneos estás.

## Verificado

Contra el servidor local, sembrando con el servidor parado y restaurando
después (cabecera del smoke):

- `test/totems_smoke.gd` 10/10 sin ventana y bajo xvfb. La base de datos,
  antes de restaurar: la carta ofrecida desaparece, el clan sirve al
  demonio IV con 51 de reputación; log del servidor `demon affiliation …
  gave=51`.
- `world_smoke.gd` 31/31 (antes 56: ya no recorre los 24 tótems de demonio
  ni el de torneos), `talk_smoke.gd` 8/8, `native_panels.gd` 123 PASS,
  `run_tests.sh` headless (158) y visual.
- Capturas miradas: `cal-bracket.png`, `clan-demon.png`, `demon-offer.png`,
  `fw-sky.png` (primera versión de los fuegos demasiado tenue: se hicieron
  más grandes y aditivos y se repitió).

## Sin verificar

- Que otro coach conectado vea tus fuegos: el servidor los manda a los
  coaches cercanos por posición, y con un solo cliente no lo he probado.
- Los fuegos no se gastan al lanzarlos (el servidor no los consume); no he
  comprobado qué hacía el retail.

## Para empezar mañana

Los servicios de S18 están hechos. Quedan en `ElementDlg` el intercambio
entre jugadores, las estadísticas de otro coach y el resultado de combate,
y los puntos de este devlog que están en el BACKLOG.
