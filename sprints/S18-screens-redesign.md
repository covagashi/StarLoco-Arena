# S18 — Todas las pantallas, nuevas

**Planificado:** 2026-10-17 · **Hito:** M2 — Identidad visual · **Tamaño:** L · **Estado:** 🟡 abierto · **Depende de:** S05 (servicios accesibles)

> El número es el de creación; el orden lo da la tabla de
> [`README.md`](./README.md).

## Origen

En S05 (2026-10-17) el dueño, al ver las pantallas de los servicios: "esas
pantallas son legacy, hay que mejorarlas todas". Y después: "hay que cambiar
todo, incluyendo las primeras pantallas". No es fidelidad con el retail (S07):
es un diseño propio para todo lo que el jugador ve fuera del combate.

## Inventario (2026-10-17)

Hojas en el Samba, `codigo/capturas/s05/inventario/`:

1. **`1-entrada.png`**: login, creación de coach, lobby, informe de bug.
2. **`2-paneles.png`**: los 21 paneles nativos del lobby (menú, equipo,
   evolución, estadísticas, inventario, clasificación, calendario, logros,
   social, clan ×4, ayuda, opciones, nuevo luchador, equipo del luchador,
   nombres de equipo ×3, ciudad).
3. **`3-servicios.png`**: lo que abren los servicios de "Ciudad". Diálogos
   retail XML: Card Master, buzón, altar de fusión, fuegos artificiales.
   Panel de depuración `ElementDlg`: cementerio, retos, demonios, tótems.
   Sin captura todavía: escribir carta, ofrenda al demonio, intercambio y
   resultado de combate.

Se rehacen con `UI_REVIEW_ALL=1` en `test/ui_review_preview.tscn` (paneles)
y `test/world_smoke.gd -- --shot-dir=D --shot-all` (servicios), ambos bajo
`xvfb-run`.

## Decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-17 | Tres direcciones a comparar: A, la familia del HUD de combate de S17; B, el 1 bit de S04; C, una propia ("mesa de cartas": tapete verde y paneles de papel) | dueño ("sí, me parece bien") |
| 2026-10-17 | **Dirección B (1 bit)**: "la b me gusta mucho" | dueño |
| 2026-10-17 | En 1 bit, la interfaz es blanco y negro y el **contenido** conserva su color: el azul del equipo propio, las muestras de pelo y piel, el muñeco y el arte de las cartas. Es la regla de los combates en 1 bit | agente, a confirmar |
| 2026-10-17 | Fondo: la arena 10 en 1 bit, generada en local (`assets/mapgfx_1bit/backdrop.png`, git-ignored: es arte retail), con trama encima; sin ella, una viñeta tramada por shader | agente |
| 2026-10-17 | Fuera del login el título es "ARENA" a secas: el "PIPPOP" del arte horneado no se ha mantenido | agente, a confirmar |
| 2026-10-17 | **El HUD de combate de S17 no se rehace**: acaba de tener el visto bueno. Si gana B, se revisa entonces si hay que acercarlo | agente (el dueño lo dejó a su criterio) |

## Por decidir con el dueño

- Visto bueno de la tanda 1 (`codigo/capturas/s18/tanda1-*.png`).
- Las dos decisiones "a confirmar" de arriba.

## Hojas de opciones

Bocetos con Pillow, no la implementación: `godot/tools/mock_screens.py OUT`
(desde `godot/`; usa las capturas de combate que deja `./run_tests.sh` en
`/tmp`). Las mismas tres pantallas en las tres direcciones, con arte real
(ilustraciones del set Jalatranki) y datos de ejemplo en la clasificación.

## Tanda 1 (2026-10-17)

Hojas: `codigo/capturas/s18/tanda1-entrada.png` (login, creación, lobby) y
`tanda1-paneles.png` (equipo, opciones, ciudad). Verificado:
`./run_tests.sh` exit 0, `native_lobby` 28 PASS, `native_panels` 123 PASS y
`world_smoke` 57/57 con el lobby nuevo.

## Registro de toques artísticos

| Fecha | Nota del dueño | Cambio | Fichero |
|---|---|---|---|

## Tareas candidatas

- [x] Hoja de 3 direcciones sobre las mismas tres pantallas (2026-10-17).
- [x] **Sistema 1 bit** `src/ui/onebit.gd`: tema (botones, campos, tablas,
      menús, barras, interruptores, deslizador), ventana con sombra dura,
      trama para sombrear, fondo, botón principal. Tanda 1, 2026-10-17.
- [x] Los 21 paneles del lobby, por la base común (`lobby_panel.gd`).
- [x] Login y creación de coach, sin arte horneado; los textos de la
      creación pasan a i18n (estaban en español dentro de la imagen).
- [x] Lobby: ventanas nativas, Combate como acción principal, iconos en
      blanco, chat compacto.
- [ ] Informe de bug (`bug_report.gd`, una `Window` con su propio tema).
- [ ] Contenido de los paneles: hoy son tablas genéricas. Rehacerlos uno a
      uno (inventario con cartas, clasificación como el boceto…).
- [ ] Servicios: sustituir los diálogos XML y `ElementDlg` por paneles
      nativos (lista de S05).
- [ ] Retirar de `main.tscn` los paneles de depuración que queden sin uso.
- [ ] `godot/PRODUCT.md` y `DESIGN.md` al día (hoy dicen que el dueño fija el
      estilo de login y creación, y eso ya no vale).

## Criterio de cierre

Ninguna pantalla fuera del combate usa un diálogo retail XML ni el panel de
depuración, y todas tienen el visto bueno del dueño en hoja.
