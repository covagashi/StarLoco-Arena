# S17 — HUD de combate estilo Krosmaster

**Planificado:** 2026-10-17 · **Hito:** M2 — Identidad visual · **Tamaño:** M · **Estado:** 🟡 abierto — HUD hecho, a la espera del visto bueno del dueño · **Depende de:** S04

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

- [x] Boceto de composición a 1280×720 y 800×600, en los dos estilos. Se
      hizo directamente con el HUD real sobre `test/fight_ui_preview.tscn`
      (4 contra 4 en el mapa 10, con daño, buffs, una invocación, un muerto y
      un invisible), porque el dueño dormía y el boceto así ya es código.
      Hojas en el Samba (abajo).
- [x] Carta de luchador (`src/fight/fighter_card.gd`): retrato retail
      (`breed*10 + sexo`, o el `look` de la invocación), marco del color del
      equipo, vida (barra o anillo) con el número sobre el retrato, buffs en
      chips hacia el mapa (máx. 3 + "+n"), y los estados: activo (sale 8 px
      hacia el mapa, marco claro y muesca), muerto (gris + "KO"), invisible
      (marco discontinuo, retrato al 40 %). Las invocaciones van un 20 % más
      pequeñas.
- [x] Columnas laterales por equipo en orden de iniciativa (`fight_hud.gd`):
      la nuestra a la izquierda (el espectador ve el equipo 0 a la
      izquierda). Sustituyen a la `Timeline`; clic = centrar la cámara.
      Tamaño de carta adaptativo, el mismo en los dos lados; pasado ~9 una
      columna se parte en dos.
- [x] Medallón del luchador activo (`fight_medallion.gd`) abajo a la
      izquierda: retrato redondo, vida en anillo y tres insignias (PM verde,
      vida roja, PA azul, como Krosmaster), con los valores vivos también en
      turno enemigo. La barra de hechizos va a su lado, ahora con los
      iconos retail (`gui/images/spells/icons/`) y el coste en PA en la
      esquina; el hechizo armado queda pulsado.
- [x] Banner de turno arriba ("TURNO 7" + nombre en el color del equipo; en
      colocación, "COLOCACIÓN") con el reloj en un círculo a su izquierda.
      Botón **PASAR** grande abajo en el centro (a la derecha si los
      hechizos llegarían a él). Girar / Chat / Rendirse / Salir, pequeños
      arriba a la derecha.
- [x] Fuera de encima de las cabezas la barra de vida y la tira de buffs. El
      nombre sale al pasar el ratón por el luchador o por su carta; los
      textos flotantes de daño siguen.
- [x] Funciona con los dos estilos (en 1 bit los controles son tinta y
      papel) y con espectador.
- [x] `test/fight_ui_preview.tscn` actualizado (comprueba que hay una carta
      por luchador y que no flota vida ni buffs); `./run_tests.sh` en verde.
- [ ] Visto bueno del dueño en las dos resoluciones.

## Decisiones tomadas sin el dueño (2026-10-17, revisables)

El dueño pidió seguir sin parar y decidir de forma heurística. Todas son
fáciles de cambiar:

| Pregunta | Se eligió | Por qué | Alternativa lista |
|---|---|---|---|
| ¿Vida como barra o anillo? | ~~barra~~ → **anillo** (el dueño, 2026-10-17); anillo también en el medallión | — | Opciones → Combate → barra; hoja `04` |
| ¿El chat se queda o se pliega? | **se pliega** — confirmado por el dueño | — | hoja `05` |
| ¿2v2 / muchas invocaciones? | cartas adaptativas; 8 por lado en una columna a 800×600 (confirmado por el dueño), con 12 se parte en dos | — | hoja `06` |
| ¿PA/PM en cada carta? | **solo en el medallión** | fuera del turno los PA/PM de los demás son los fijos de la raza: ruido | — |
| ¿Retratos en 1 bit? | **en color** en los dos estilos | S04 dejó la GUI fuera del filtro | — |

## Registro de toques

Capturas en el Samba: recurso `codigo` → `capturas/s17/`.

| Fecha | Petición | Cambio | Captura |
|---|---|---|---|
| 2026-10-17 | "sigue con s17… cualquier duda toma una decisión heurísticamente" | Primera versión completa del HUD (arriba) | `01-antes-despues.png` (combate real), `02-boceto-1280.png`, `03-boceto-800.png`, `04-vida-barra-o-anillo.png`, `05-chat.png`, `06-muchas-cartas.png`, `07-espectador-y-hover.png` |
| 2026-10-17 | "Me parece bien tu diseño; me gusta más el anillo, plegado por defecto, 8 por lado" | Anillo por defecto (`ArtStyle.hud_life()`); el test de reparto cubre barra y anillo | — |
| 2026-10-17 | "Que coincida el área de colocación por tile, hay un offset raro" | **Media casilla de desfase**: el cliente (`aba_2.i/j`) y el arte ponen la celda (x, y) en `((x−y)·43, (x+y)·21,5)`; `fight_view` dibujaba zonas, anillos, auras y luchadores en `x+0,5, y+0,5`, 21,5 px más abajo. Corregido en `_iso`. Los luchadores usan ahora el ancla del `.anm`, como el cliente: `foot_pivot` (fila visible más baja) los subía ~8 px sobre su sombra y hasta 43 px a algunas invocaciones; el desfase anterior lo disimulaba | `10-casillas-alineadas.png` |
| 2026-10-17 | "La imagen de colocación en 1 bit se ve rara; ¿aplicaste los filtros? Dijimos solo en animaciones" | En el juego **no hay filtro de luz/oscuridad** (`onebit.gdshader` solo lo usa la herramienta de render). Lo raro era: el suelo de la arena 48 convertido en un punteado gris uniforme, las zonas como relleno translúcido sobre la trama (puntos teñidos) y el aura sumándose a la zona. Cambiado: zonas como contorno doble del color del equipo (sin relleno) en 1 bit, sin aura durante la colocación, y las zonas de salida solo en la colocación (antes seguían todo el combate). Propuesta C: suelo más claro (`onebit.py --target=0.88 --detail=2.5`), **sin aplicar**, a elegir | `09-colocacion-1bit-ABC.png` |

## Decisiones abiertas (dueño)

- Las de la tabla de arriba, si alguna no convence.
- ¿Se quiere un **medallión a la derecha** para el enemigo (como el segundo
  de Krosmaster), o basta con el de abajo a la izquierda, que sigue el turno?

## Criterio de cierre

Un combate real (`fight_smoke`) muestra toda la información de los
luchadores en sus cartas, nada de vida ni buffs flota sobre el mapa, y el
dueño da el visto bueno en las dos resoluciones.
