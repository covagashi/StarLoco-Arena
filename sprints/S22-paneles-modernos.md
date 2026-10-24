# S22 — Los paneles, con un toque moderno

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** L · **Estado:** ⚪ esbozo · **Depende de:** S20, S21 (qué paneles sobreviven)

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

## Criterio de cierre

Cada panel que sobrevive a S21 tiene su versión nueva aprobada por el dueño y
su smoke en `godot/test/`.
