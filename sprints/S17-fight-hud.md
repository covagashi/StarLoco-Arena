# S17 — HUD de combate estilo Krosmaster

**Planificado:** 2026-10-17 · **Hito:** M2 — Identidad visual · **Tamaño:** M · **Estado:** 🟡 siguiente (S04 queda en pausa) · **Depende de:** S04

> El número es el de creación; el orden lo da la tabla de
> [`README.md`](./README.md), donde va detrás de S04.

## Objetivo

Sacar la información de los luchadores de encima del mapa y llevarla a sus
**"cartas"**: retratos en los laterales, uno por luchador, como en *Krosmaster
Arena*. El mapa queda limpio, que es justo lo que pide el estilo 1 bit de S04,
y la información se lee en un sitio fijo en vez de buscarla sobre cabezas
apiñadas.

Se aparta del retail a propósito, como el 1 bit; por eso no va en S07, que es
fidelidad con el retail.

**Referencia:** dos capturas de Krosmaster Arena en el Samba,
`codigo/capturas/s17/ref-krosmaster-{1,2}.jpg` (fuera del repo).

## Origen

Al revisar el combate real de S04 (2026-10-17), las barras de vida encima de
las cabezas se veían como bloques verdes. Eran 56×27 px en vez de 56×5 por un
bug de orden (`show_percentage` después de `size`), arreglado en S04. El
dueño propuso que esa información esté en la carta del personaje.

## Lo que se coge de Krosmaster

- **Columnas de retratos a los lados**, una por equipo, con el marco del color
  del equipo y la vida en el propio retrato (barra o anillo).
- **Medallón grande del luchador activo** abajo a la izquierda: PA, PM y vida
  bien visibles, con sus hechizos al lado.
- **Banner de turno arriba** ("TURNO 7 · nombre").
- **Botón PASAR grande** abajo, en el centro.
- **Sobre el mapa, lo mínimo**: casillas de movimiento y alcance, el aura del
  equipo (S04) y el nombre al pasar el ratón.

## Lo que ya hay (2026-10-17)

- `fight_view.tscn`: `TopBar` (botones, `Timeline` con un chip por luchador,
  `TurnTimer`), `SpellScroll/SpellBar` (hechizos + "AP n MP n"), `EventCards`,
  `Info`, `Chat`, panel de resultado.
- Encima de cada luchador: placa con nombre, barra de vida, tira de buffs y
  textos flotantes de daño/estado.
- **Arte retail para las cartas**: 102 retratos de raza de 100×100 en
  `assets/gui/images/theme/images/breeds/` y 36 iconos en
  `assets/gui/images/breeds/fightTimeline/` (ya los usa `widget.gd`).

## Tareas

- [ ] Boceto de composición a 1280×720 y 800×600 (render con la herramienta de
      S04 + HUD) para validar con el dueño **antes** de programar todo.
- [ ] Carta de luchador: retrato, marco del color del equipo, vida, PA/PM,
      estado (activo / muerto / invisible), buffs en iconos pequeños.
- [ ] Columnas laterales por equipo, ordenadas por iniciativa (sustituyen a
      la `Timeline` de arriba); clic en una carta = centrar la cámara (lo que
      hoy hace el chip).
- [ ] Medallón del luchador activo + barra de hechizos.
- [ ] Banner de turno y botón PASAR (hoy "Fin de turno" en la `TopBar`).
- [ ] Quitar de encima de las cabezas la barra de vida y la tira de buffs;
      dejar nombre al pasar el ratón y los textos flotantes de daño.
- [ ] Que funcione con los dos estilos (retail y 1 bit) y con espectador.
- [ ] `test/fight_ui_preview.tscn` actualizado; carril visual en verde.

## Decisiones abiertas (dueño)

- ¿Vida como barra o como anillo alrededor del retrato?
- ¿El chat se queda en combate o se pliega?
- ¿Qué pasa con 2v2 o con muchas invocaciones? Las columnas tienen que
  aguantar 8 o más cartas por lado.

## Criterio de cierre

Un combate real (`fight_smoke`) muestra toda la información de los
luchadores en sus cartas, nada de vida ni buffs flota sobre el mapa, y el
dueño da el visto bueno en las dos resoluciones.
