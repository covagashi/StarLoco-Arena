# S45 — Lavado de cara de la interfaz

**Planificado:** 2026-11-12 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🟡 siguiente

## Por qué

Dueño, 2026-11-12: "la interfaz actual es muy tosca, quería hacerle un lavado
de cara". La de hoy (`ui_style.gd`, piedra oliva y oro desde 2026-10-24) pone
marcos dentro de marcos, texto pequeño y todo con el mismo peso.

## La dirección (maqueta)

Maqueta: https://claude.ai/artifact/22QtzoocwYafanHDKGBpcX (seis pantallas a
1280×720 con arte real del juego: inicio de sesión, crea tu coach, lobby,
equipo del coach, combate, sistema visual).

- Primera versión: el dueño la vio "muy ai slop, menos el gui del combate. Hay
  que dar sensación de juego, no una web", con trece referencias de juegos.
  La maqueta de la v16b (servidor Demonis) era solo un ejemplo de lo fresco,
  "no lo quiero clavado".
- Segunda versión: "ahora mejor, habría que mejorar un poquito las cosas pero
  mejor".

Lo que queda decidido:
- El arte manda: el coach y los luchadores en grande, la arena 3D de fondo.
- Material de juego: borde de tinta de 3 px y sombra dura (no difusa), títulos
  en Lilita One con contorno, Nunito en negrita para leer, cintas con muesca,
  papel con pespunte para formularios y fichas, medallones redondos, engarces en
  rombo, botones en relieve con labio y la acción principal inclinada.
- Menús como losetas ilustradas cortadas en diagonal (Historia, Ranking,
  Torneos), no tarjetas de texto.
- Monedas en cápsulas con "+"; riel de medallones con nombre a la izquierda.
- Combate: el HUD de la maqueta (línea de turnos en círculos con anillo azul o
  rojo arriba, "¡Te toca!", retrato con la vida en anillo y medallas de PA/PM,
  barra de hechizos flotante con su coste, ficha al pasar el ratón, "Pasar
  turno" grande).
- Colores: noche `#12152A`, pop `#FF6B3D` solo para la acción, sol `#FFC247`
  para premios, azul aliado, rojo rival, verde aceptar; tinta `#0B0D1C`.

## Fases

Cada fase se enseña al dueño (capturas en `~/codigo/capturas/s45/`) antes de
la siguiente.

0. **Ajustes de la maqueta.** Lo que el dueño quiera "mejorar un poquito",
   sobre la propia maqueta, antes de tocar el cliente.
1. **Base.** Fuentes Lilita One y Nunito (OFL) en `godot/assets/ui/fonts/`,
   con su licencia y en `CREDITS.md`. `ui_style.gd` v2: paleta, contorno de los
   títulos con el outline de la fuente, y las piezas (botón en relieve, cinta,
   papel, medallón, rombo, cápsula) como texturas 9-slice de un generador
   propio (`tools/make_ui_kit.py`, como los fondos de hoy), sin imágenes a mano.
   Los 21 archivos que usan `UiStyle` toman el estilo nuevo sin tocarlos uno a uno
   donde se pueda.
2. **Pantallas completas.** Inicio de sesión, crea tu coach y lobby como en la
   maqueta; las ilustraciones de las losetas salen de renders del juego
   (`anim_sheet.gd`, arenas), no dibujadas.
3. **Paneles.** La base de los paneles (`lobby_panel.gd`) pasa a hoja de papel
   con cinta; equipo del coach como pantalla de héroe; después los demás
   paneles (inventario, equipo, ranking, kanodo, torneos, correo…), por tandas.
4. **Combate.** El HUD de la maqueta en `fight_hud.gd` y `fight_view.gd`.
5. **Cierre.** Smokes con capturas de cada pantalla, `run_tests.sh` (también el
   carril de 800×600) y el peso para la demo web (S44: ≤ 50 MB de primera
   carga, móviles de 2 GB).

## Fuera

- Las ilustraciones de las cartas y los iconos de hechizos: S38, ya con este
  estilo (los de la maqueta son provisionales).
- La tienda (S30): aquí solo las cápsulas de monedas con su "+".

## Criterio de cierre

Ninguna pantalla ni panel usa ya el estilo de piedra y oro; el dueño ha visto
las capturas de todas y las da por buenas.
