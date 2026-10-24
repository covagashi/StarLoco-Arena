# S22 — Los paneles, con un toque moderno

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** L · **Estado:** 🟡 abierto (2026-10-24) · **Depende de:** S20, S21 (qué paneles sobreviven)

## Origen

El dueño, 2026-10-24 (texto completo en [S21](./S21-game-loop.md#origen)):
"la ventana de equipo del luchador hazlo más ameno y accesible", "haz mejor la
parte de logros, estoy seguro de que ya existían iconos", "la parte de
servicios es demasiado condensada", "el inventario está bien pero es denso,
ahora que no hacemos el 1 bit, creo que podríamos hacer más", y como regla
general: **"mejor los paneles originales pero darle un toque moderno, sin
redundancias"**.

## Qué significa "los originales con un toque moderno"

La base es lo que el panel del retail enseñaba y en qué orden (S07 ya lo
recuperó). Encima: el estilo piedra y oro de S18, más aire, jerarquía clara
(una acción principal por panel), respuesta visible a cada acción y nada
repetido en dos sitios. Con el 1 bit fuera, el arte retail (cartas,
retratos, iconos) puede ir **a color y grande**.

## Panel a panel (estado 2026-10-24)

| Panel | Hoy | Propuesta |
|---|---|---|
| **Equipo del luchador** (`lobby_panels.gd:~1000-1081`) | hechizos y cartas en listas; guardar sin señal (S20 #1) | el luchador grande a la izquierda; los huecos de equipo como casillas con la carta dentro; los hechizos con su icono; cambios marcados y "Guardar" solo activo con cambios |
| **Inventario** (`lobby_panels.gd:312-363`, `card_panel.gd`) | 4 pestañas, buscador, rejilla de 4 columnas con fichas de 150×180 y detalle de 300 px: caben unas 8 cartas, sin orden ni filtros | rejilla más rica (arte de la carta a color, rareza por el marco), ordenar y filtrar por tipo y rareza, detalle al pasar el ratón en vez de una columna fija |
| **Logros** (`lobby_panels.gd:581-593`) | una tabla de texto; el modelo pone `iconUrl: ""` (`main.gd:4146`) | **los iconos existen**: `godot/assets/gui/images/achievement/icons/` (10 png: 1..5 completado y -1..-5 apagado) y `.../achievement/key/` (5 png), convertidos del retail (`gui.jar → gui/achievement/`). La regla del retail (`aea_1.java:92-118`): icono = `min(puntos/5, 5)`, en negativo si no está hecho. **Ojo:** con menos de 5 puntos da 0 y no hay `0.png`. Propuesta: tarjetas con icono, progreso y recompensa, agrupadas por categoría |
| **Servicios** (`lobby_panels.gd:836`, cuadrícula de 3 columnas) | todo en una cuadrícula: 14 Card Master, 6 altares de fusión, buzón, fuegos, aprendizaje (14 NPCs), retos, demonios | agrupar por lo que hace (Tienda, Fusión, Correo, Aprender, Retos) con una tarjeta por grupo y su retrato (S23); dentro, la lista. Los 14 Card Master como **una** tienda con filtro por set |
| **Equipo del coach** (`coach_equip_panel.gd`) | no deja equipar (S20 #3) | el muñeco del coach con sus casillas, como el del luchador |
| **Resto** (menú, estadísticas, clasificación, calendario, social, clan, opciones…) | S18 los pasó a piedra y oro | repaso por redundancias con S21: lo que se elimina, se elimina antes de rediseñarlo |

## Heredado de S20–S24 (2026-10-24)

- **Fantasmas desde el equipo de Élite** (S21, p2w): hoy el fantasma se
  congela de `titularRoster`, que mete titulares de Historia con sus
  esferas. Toca el editor de S13.
- **Ranking solo con luchadores de Élite** (S21): el panel ya lo hace,
  pero el servidor no rechaza un luchador de Historia en un equipo de
  Élite.
- **Los nombres de los hechizos salen en inglés** con la interfaz en
  español ("Pressure", "Jump"; S20).
- El panel Equipo se titula "Equipo y arena". Basta con "Equipo".
- Repasar el HUD de combate de S17 con el criterio de S24: todo lo que
  sale en pantalla dice qué significa.

## Tareas candidatas

- [ ] Hoja de opciones por panel (como en S18):
      el dueño elige en la Ally.
- [ ] Logros con iconos (incluido el caso de 0 puntos).
- [ ] Inventario y Equipo del luchador con el arte a color.
- [ ] Servicios agrupados.
- [ ] Cada acción con respuesta visible: aviso que se va solo, estado del
      botón o animación. Nunca solo una línea en el chat.
- [ ] Accesibilidad: tamaño mínimo de texto y de botones, contraste, todo
      alcanzable con teclado y mando (la Ally es un mando).

## Resultado (en curso)

### Bloque A — 2026-10-24

| Qué | Evidencia |
|---|---|
| **Hechizos en el idioma de la interfaz.** El panel del luchador y la barra del combate usaban el nombre inglés de la exportación; ahora usan `Spells.name_of` ("Presión", "Espada del Destino") | lectura de `gui/i18n_es.json` (`content.3.4` = Presión); `native_panels` 138 PASS |
| **Logros con sus iconos.** Tiles con el icono del retail: el grado sale de los puntos, `min(puntos/5, 5)`, mínimo 1 porque no hay `0.png`, y el icono va apagado (candado del color del grado) hasta conseguirlo. Cada tile lleva barra de progreso y puntos. Filtro Pendientes / Hechos / Todos. Al elegir uno, el detalle con el icono grande, **qué pide** (antes la descripción solo existía una vez conseguido; si los datos no traen texto, se arma con sus condiciones) y el progreso | `test/achievements_smoke.gd` 3/3: 103 pendientes, todos con icono; 6 hechos; detalle "Tener la carta Hombreras Jalatranki". Capturas en `~/codigo/capturas/s22/` |

### Bloque B — Equipo del luchador (2026-10-24)

- **Más ameno y accesible**, como pidió el dueño:
  - Hechizos: tiles con su icono, nombre y PA. Arriba los equipados (n/6),
    abajo los disponibles; un clic equipa o quita.
  - Equipamiento: las cinco casillas con el arte de la carta y, debajo,
    las cartas de la casilla elegida como tiles; un clic la pone.
  - "Guardar" va fijo en el pie de la ventana, con la señal de S20.
  - El valor del luchador sale arriba (de 6000).
- **Fallo encontrado (venía de antes): el editor usaba la tabla equivocada.**
  - El equipo de luchador (tipo 250, 75 cartas) comparte id con las cartas
    del coach, pero es otro objeto. La carta 1 es la espada «Raciela»
    (`content.1`) y la carta del coach 1 es la capa «Capa Arlan Txin»
    (`content.23`).
  - El cliente decidía la casilla, el nombre y el arte con la tabla del
    coach. Así ofrecía emotes y equipo del coach como equipo de luchador,
    en casillas equivocadas, con otro nombre y otro dibujo.
  - El servidor no se dejaba engañar: descarta lo que no es carta de
    luchador.
  - Arreglo: `dumpfightercards` exporta la casilla (`type`) y el valor.
    `FighterCards.slot_type`, `label` (`content.1`) y `value_of`, y
    `UiStyle.fighter_card_art` (`equipments/fighters/icons`). Los nombres
    del arma en el combate también cambian.
  - **Hay que regenerar `fightercards.json`**: `go run ./cmd/dumpfightercards
    data-dist ../godot/assets/gamedata/fightercards.json`.
- **p2w en el propio panel:** a un luchador de Élite se le ofrecían solo las
  cartas que el coach tenía. El retail (`aca_0`) y el servidor
  (`entitledEquip`) le permiten todas las del tipo; solo limita el
  presupuesto. Ahora se le ofrecen todas, de menor a mayor valor. Los de
  Historia siguen con las suyas.
- **Evidencia:**
  - `loadout_smoke` 7/7: quitar y poner un hechizo por su tile, guardar,
    la pestaña de equipamiento con 5 casillas y 12 cartas.
  - `test/unit/fighter_cards_test.gd`: la 1 es un arma, «Raciela», no el
    nombre del coach.
  - Captura `loadout-equipment.png`: Arma = Raciela, con su arte.
- **Lo que ofrece a cada luchador, del servidor.** A uno de Historia el
  retail le ofrece las cartas que desbloquean sus esferas compradas
  (`sphereEquipmentPools`), no las del inventario. El cliente ofrecía las
  del inventario. Nuevo par Godot-only 60022 → 60023 (`wearableCards`):
  todas para Élite y las desbloqueadas para Historia, la misma regla que
  aplica `entitledEquip` al guardar. Lo que lleva puesto se enseña aunque
  no esté en el inventario.
  - Evidencia: `TestWearableCards`; `loadout_smoke` 7/7 con el 60023
    recibido en vivo; `OPCODE-INVENTORY.md` al día.

## Criterio de cierre

Cada panel que sobrevive a S21 tiene su versión nueva aprobada por el dueño y
su smoke en `godot/test/`.
