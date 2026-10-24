# S20 — Lo que no funciona

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** M · **Estado:** 🟡 abierto (2026-10-24) · **Depende de:** —

> El número es el de creación; el orden lo da la tabla de
> [`README.md`](./README.md).

## Origen

El 2026-10-24 el dueño probó el cliente en la Ally y dejó una lista larga
(texto completo en [S21](./S21-game-loop.md#origen)). Su conclusión: "faltan
muchas cosas y creo que está muy sobrecargado (…) esto es algo del 2015 o más
antiguo, hoy en día los game-loop son diferentes (…) no está preparado para los
últimos sprints". De esa lista salen S20–S24, y van **antes** de S15 y S16.

Este sprint recoge lo que el dueño vio **roto**. Los otros cuatro tratan el
diseño. Va primero porque no tiene sentido rediseñar un panel que no guarda.

## Hallazgos (2026-10-24, leyendo el código, sin reproducir todavía)

| # | Lo que dijo el dueño | Lo que hay en el código |
|---|---|---|
| 1 | "le doy a guardar cambios y no hay ninguna seña de nada" (Equipo del luchador) | **Sí guarda**: `lobby_panels.gd:1081` → `_on_eq_save` (`main.gd:3138`) → 6011 → `handlers_fighter.go:241` (`SaveLoadout`) → 6010. La única confirmación es una línea verde en el canal *system* del chat (`main.gd:849-865`). **Bug:** al recibir 6010 solo se actualiza `f.spells`, no las cartas (`main.gd:853-861`); al reabrir el editor salen las cartas viejas y parece que no se guardó |
| 2 | "los botones de mover el pj no funcionan" | No existen botones de mover. Lo más probable son los **« »** del lobby (`lobby_screen.gd:124-132`): solo giran el dibujo, nadie escucha `coach_rotated` y `_local_coach_model()` fija `actorDirection: 3` (`main.gd:4771`), así que cualquier refresco borra el giro. Otros candidatos: ◀ ▶ de "Nuevo luchador" (`lobby_panels.gd:988`, no hacen nada si `actorDescriptorLibrary` está vacío) y "Girar" en combate (`fight_view.gd:2938`, solo en colocación o en tu turno) |
| 3 | "el equipo del coach no funciona" | `coach_equip_panel.gd:57`: al elegir una carta solo se hace `draft["put"] = id`, **sin `schedule_refresh()`**. "Poner" nació desactivado (`:62`) y no se reconstruye, así que no se puede equipar nada. Quitar, Deshacer y "Llevar puesto" funcionan, pero sin confirmación |
| 4 | "el botón de cancelar es muy pequeño y no es visible; los juegos actuales tienen una cuenta atrás" | `lobby_screen.gd:117-123`: botón de 144×38 con fuente de 16, montado sobre la línea del subtítulo. Ni cronómetro ni tiempo estimado |
| 5 | (encontrado al investigar) | **Leyendas no puede llenarse**: "Convertir en leyenda" envía 23000 con el flag 1 (`main.gd:2844`), el servidor lo ignora (`handlers_evolution.go:72`) y `nextFighterState` manda al titular al banquillo (`:108`). Ningún código pone el estado 4 |
| 6 | (encontrado al investigar) | Los combates de **Evolución mueven la fuerza de clasificación** igual que Élite (`handlers_fight_combat.go:857`), y la Ayuda dice lo contrario (`ui_es.json:1109`). Hay que decidir cuál de los dos manda |
| 7 | (encontrado al investigar) | La **clasificación 2v2** (27505) siempre sale vacía (`handlers_ladder.go:212`) |
| 8 | (encontrado al investigar) | En el árbol de Nilo, "Gracias. Quizás vuelva más tarde." lleva al grupo 69, que está en francés. Hay 9 grupos en francés dentro de la tabla española (76, 69, 83, 74, 77–80, 75). Fallo de los datos retail |

## Tareas

- [x] **1. Guardar con señal.** Al guardar, el panel lo dice ("Guardado" en el
      botón, o un aviso que se va solo) y el botón queda desactivado hasta el
      siguiente cambio. El 6010 actualiza también las cartas en
      `State.roster`. Smoke: guardar, cerrar, reabrir y ver lo guardado.
- [x] **2. Mover/girar el PJ.** Preguntar al dueño qué botón era. Por
      defecto, arreglar los tres: el giro del lobby persiste (no lo pisa
      `_local_coach_model`), ◀ ▶ funcionan sin `actorDescriptorLibrary`, y
      "Girar" en combate explica cuándo está desactivado.
- [x] **3. Equipo del coach.** Elegir carta → "Poner" se activa → se equipa.
      Confirmación también en "Llevar puesto". Smoke con la base de pruebas.
- [x] **4. Buscar rival como hoy.** Mientras busca: un cronómetro grande
      (0:12…), el modo que se busca, y "Cancelar" a tamaño de botón
      principal. Esc también cancela. El diseño fino va en S21.
- [x] **5. Leyendas, fuera** (dueño, 2026-10-24). Se quitan de la interfaz
      la pestaña, el botón "Convertir en leyenda" y los torneos de Leyendas.
      El servidor no se toca, porque es retail; solo deja de ofrecerse.
- [x] **6. Evolución no cuenta para la clasificación.** Es el modo historia
      (dueño, 2026-10-24), así que deja de mover la fuerza en
      `handlers_fight_combat.go:857`. Test Go.
- [x] **7. 2vs2, escondido** (dueño, 2026-10-24: "para no tener problemas de
      baja población"). Fuera del lobby y de Equipo (la pestaña, el dúo y su
      clasificación vacía). El código se queda, detrás de un interruptor, por
      si vuelve con más gente.
- [x] **8. Textos retail en francés** de Nilo: traducidos al español (y al
      inglés si faltan), y el "Gracias" cierra la conversación.

## Decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-24 | S20–S24 van antes de S15 y S16: "no está preparado para los últimos sprints" | dueño |
| 2026-10-24 | Los modos se quedan así: **Evolución = modo historia**, **Élite = ranking**, **Torneos** igual; **2vs2 se esconde** (baja población) y **Leyendas se quita** | dueño |
| 2026-10-24 | Evolución, como modo historia, **no cuenta para la clasificación** | se sigue de la anterior |
| — | ¿Qué botones eran "mover el pj"? Por defecto, se arreglan los tres candidatos | pendiente |

## Resultado (en curso)

### Bloque A — 2026-10-24: 1, 2, 3, 4 y 6

| # | Qué se hizo | Evidencia |
|---|---|---|
| 1 | "Guardar cambios" solo se activa si hay cambios, pasa a «Guardando…» y después a «✓ Guardado», y sale un aviso («Cambios de X guardados»). Si falla, un aviso y una línea en rojo. El 6010 actualiza también las cartas en `State.roster`. **De paso:** los avisos (`_toast`) estaban en la capa `$UI` (1), **debajo** de las ventanas (capa 10), así que con una ventana abierta no se veía ninguno. Ahora tienen su propia capa (20) y el estilo de la interfaz (18 px, antes 12) | `test/loadout_smoke.gd`: 6/6 (sin cambios → desactivado; con cambios → activo; «✓ Guardado»; aviso; roster con sus cartas; restaurado). La primera pasada pilló un `get_available_bytes` que no existe en `WireReader` |
| 2 | **Causa:** `_rotate()` llamaba a `_sync()` antes de escribir la dirección, `_sync()` releía la vieja y se volvía a escribir esa. **« » no hacían nada.** Además, `_local_coach_model()` reponía siempre la 3. Ahora se escribe primero y se respeta la del modelo. El "Girar" del combate explica cuándo funciona (el texto anterior enseñaba el opcode) | `test/coach_turn_smoke.gd`: 4/4. Con el código anterior: `» : 3 → 3` (FAIL). Los ◀ ▶ de "Nuevo luchador" ya funcionaban: `2 → 3` |
| 3 | Elegir la carta refresca el panel, así que "Poner" se activa | `screens_smoke.gd` ahora elige la carta en la tabla como un clic (antes escribía el borrador y refrescaba él mismo, por eso pasaba). Con el código anterior: `FAIL put — card 131 not offered`; con el arreglo, 11/11 |
| 4 | Una tarjeta sobre las acciones mientras busca: «Buscando rival…», el modo, un cronómetro de 60 px y "Cancelar" de 280×56 como botón principal. Las acciones se ocultan. **Esc** también cancela si no hay ventanas abiertas | `screens_smoke.gd`: `card with a 280px Cancelar, clock '0:02', actions hidden=true`; `Esc during a search → 2303 → 2306` |
| 6 | Los combates de Evolución guardan las estadísticas pero no mueven la fuerza | `TestEvolutionFightLeavesStrength`. Con el código anterior: `team 0 Strength = 1525, want 1500` |

También: `go vet` y `go test ./...` limpios; `run_tests.sh --headless` 302/0;
`native_panels.gd` 133 PASS.

**Base de pruebas:** cada pasada de `screens_smoke` compra una esfera del
Kanodo al luchador 1. Se deshicieron las tres de hoy (filas 12–14 de
`fighter_spheres`, +37 de XP y cursor de vuelta a (31,1), la casilla de la
esfera 15358) con el servidor parado. A `fight1` se le puso la contraseña
`test123` para probar la creación.

### Bloque B — 2026-10-24: 5, 7 y 8

| # | Qué se hizo | Evidencia |
|---|---|---|
| 5, 7 | `godot/src/features.gd`: dos interruptores, `DUO` y `LEGENDS`, los dos apagados. El código sigue, solo deja de ofrecerse. Con ellos apagados no aparecen: la pestaña 2v2 ni la de Leyendas en Equipo, la acción "2v2 dúo" del lobby, "Convertir en leyenda", y el torneo de Leyendas (definición 24) en el Calendario y en el selector. `tabs()` acepta ahora ids, así que cada pestaña conserva su número de modo del retail (Torneos sigue siendo el 3) | `test/modes_smoke.gd` 5/5 (lobby con 5 acciones sin dúo; pestañas Evolución, Élite, Torneos; Torneos → modo 3; sin "Convertir en leyenda"; 0 torneos de Leyendas en el Calendario, aunque la base de pruebas puede no tener ninguno programado). `native_panels.gd` 133 PASS, ahora comprueba que las escondidas no salen. `pvp_smoke` sigue probando el dúo directamente con `_on_lobby_action("duo")` |
| 8 | `godot/src/gamedata/npc_text_fix.gd`: traducciones de los grupos de Nilo que el retail dejó en francés. En español: 69, 74–80, 83 y respuestas de 8, 17 y 84. En inglés, donde la tabla base trae aún más francés: 8, 66, 69, 74–84. `NpcDialogs.group()` las aplica por idioma. La respuesta 4 del grupo 8 ("Gracias. Quizás vuelva más tarde.") llevaba a la lección de orientación (69), a la que no llegaba ninguna pregunta; ahora es la pregunta «¿Importa hacia dónde mira mi luchador?». Del grupo 80 se quitó a propósito la línea de los "boufteurs" (sobres) que se compraban en la web con ogrinas | `test/unit/npc_text_fix_test.gd` (sin marcas de francés en ninguna corrección; el carril headless pasa a 381 checks). `test/nilo_smoke.gd` 4/4 en vivo: grupo 8 sin francés, la 69 empieza por «Sí:», las preguntas de las cartas en español y la 80 sin ogrinas |

`tournaments_smoke.gd` sin sembrar: pasan sus tres pasos de "Equipo →
Torneos" (la pestaña con el modo 3, buscar y cancelar). Fallan los tres que
necesitan los torneos "Copa Smoke…" sembrados con el SQL de S09, y no son
de este cambio.

**Para S21 (monetización):** el grupo 80 es la prueba del pay-to-win del
original. Decía: «La forma más común [de conseguir cartas] son los
*boufteurs* que puedes conseguir en la web a cambio de unas ogrinas».

**Visto de paso, para S22:** los nombres de los hechizos salen en inglés
("Pressure", "Jump") con la interfaz en español.

## Criterio de cierre

Cada fila de la tabla tiene su arreglo con un test (Go o smoke de Godot) o una
decisión escrita, y el dueño prueba 1–4 en la Ally.
