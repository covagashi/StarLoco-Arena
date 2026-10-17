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
| 2026-10-17 | Fondo: la arena 10 en 1 bit, generada en local (git-ignored, es arte retail). Sustituida el mismo día por un fondo propio, ver abajo | agente |
| 2026-10-17 | Título **PIPPOP ARENA** ("PIPPOP" pequeño encima de "ARENA"), en login y lobby | dueño ("sería Pippop arena") |
| 2026-10-17 | El fondo deja de ser la arena retail: **fondo decorativo propio** (`tools/make_onebit_bg.py`, en git). Menú y marcos, aprobados | dueño |
| 2026-10-17 | **El HUD de combate de S17 no se rehace**: acaba de tener el visto bueno. Si gana B, se revisa entonces si hay que acercarlo | agente (el dueño lo dejó a su criterio) |

## Por decidir con el dueño

- **Fondo**: 1 tablero, 2 rayos o 3 cartas
  (`codigo/capturas/s18/fondo-{login,lobby}.png`). El elegido se copia a
  `assets/ui/onebit_bg.png`; mientras tanto sale la viñeta tramada.
  `ARENA_BACKDROP=<nombre>` fuerza uno para comparar.
- La decisión "a confirmar" de arriba (el color en el contenido).

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
| 2026-10-17 | "¿Puedes cambiar el background y poner algo más decorativo por tu parte? El menú y el framing me gusta." | Tres fondos propios en 1 bit (tablero, rayos, cartas), tranquilos en el centro | `tools/make_onebit_bg.py`, `assets/ui/onebit_bg_*.png` |
| 2026-10-17 | "Sería Pippop Arena" | "PIPPOP" encima de "ARENA" | `login_screen.gd`, `lobby_screen.gd` |

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
