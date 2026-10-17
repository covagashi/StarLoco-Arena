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
| 2026-10-17 | En 1 bit, la interfaz es blanco y negro y el **contenido** conserva su color: el azul del equipo propio, las muestras de pelo y piel, el muñeco y el arte de las cartas. Es la regla de los combates en 1 bit. **Corregida abajo para el arte de las cartas** | agente |
| 2026-10-17 | Fondo: la arena 10 en 1 bit, generada en local (git-ignored, es arte retail). Sustituida el mismo día por un fondo propio, ver abajo | agente |
| 2026-10-17 | Título **PIPPOP ARENA** ("PIPPOP" pequeño encima de "ARENA"), en login y lobby | dueño ("sería Pippop arena") |
| 2026-10-17 | Fondo elegido: **rayos** (sol de semitono), en `assets/ui/onebit_bg.png` | dueño ("el de rayos me parece bien") |
| 2026-10-17 | El fondo deja de ser la arena retail: **fondo decorativo propio** (`tools/make_onebit_bg.py`, en git). Menú y marcos, aprobados | dueño |
| 2026-10-17 | Card Master nativo: **"Comprar" solo cuando la carta tiene precio**. La mayoría de sets del retail son solo trueque (precio 0), y entonces el trueque pasa a ser la acción principal. El trueque va en la misma ventana: tus cartas a la izquierda, la carta que quieres y lo ofrecido a la derecha | agente |
| 2026-10-17 | **Arte de las cartas en trama 1 bit** (opción B), también los iconos de fichas: "el b". El azul del equipo y las muestras de pelo y piel siguen en color, porque significan algo | dueño |
| 2026-10-17 | **El muñeco del coach y del luchador, en 1 bit**: "por mi pásalo a 1b". Dibujo a línea, el estilo de los luchadores en el combate 1 bit (`AnmSprite` estilo 3), en creación, lobby y nuevo luchador. Probé la trama de las cartas: el muñeco quedaba fantasmal y el pelo oscuro se perdía en el negro | dueño (el estilo, el agente) |
| 2026-10-17 | **Card Master nativo aprobado**: "sí, me parece perfecto" | dueño |
| 2026-10-17 | **El HUD de combate de S17 no se rehace**: acaba de tener el visto bueno. Si gana B, se revisa entonces si hay que acercarlo | agente (el dueño lo dejó a su criterio) |

## Por decidir con el dueño

- Con el muñeco en línea, el color de pelo y piel que eliges en la creación
  ya no se ve en el muñeco (solo en las muestras). Hoja:
  `codigo/capturas/s18/muneco-1bit.png`.

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

## Tanda 2: el Card Master (2026-10-17)

`src/ui/card_master_panel.gd` sustituye al `cardMasterDialog` XML (mismo
nombre de diálogo, así que la auditoría sigue valiendo). Rejilla del set con
su arte, detalle con precio en fichas (icono de `gui/images/tokens`), lo que
ya tienes, y el trueque en la misma ventana con la barra de lo ofrecido. El
modelo `cardMasterTrade` gana campos nativos (`catalog`, `offer`, `staged`,
`wallet`, `status`); el cable sigue en `main.gd` (5450 compra, 5400 trueque).
El resultado (5403) sale en el panel, no solo en el chat.

Encontrado: `shop.done`, `shop.tokens` y `shop.refused` no existían en
ninguna tabla de i18n; el chat mostraba las claves. Cada clic reconstruía la
rejilla y la devolvía arriba: ahora conserva el desplazamiento y el foco
(la prueba falla sin el arreglo: 151 → 0).

Verificado: `test/cardmaster_smoke.gd` en vivo (abre el panel nativo,
elige, ofrece, intercambia: 5403 OK y la carta en el inventario), 6/6;
`world_smoke` 57/57; `native_panels` 123 y `native_lobby` 28 PASS;
`./run_tests.sh` exit 0, mirado también a 800×600. Sin probar en vivo: la
compra con fichas (5450), porque el coach `test` no tiene ninguna carta con
precio a su alcance en los Card Masters; está en la vista previa y en el
smoke, que la hace si la encuentra.

## Registro de toques artísticos

| Fecha | Nota del dueño | Cambio | Fichero |
|---|---|---|---|
| 2026-10-17 | "¿Puedes cambiar el background y poner algo más decorativo por tu parte? El menú y el framing me gusta." | Tres fondos propios en 1 bit (tablero, rayos, cartas), tranquilos en el centro | `tools/make_onebit_bg.py`, `assets/ui/onebit_bg_*.png` |
| 2026-10-17 | "Sería Pippop Arena" | "PIPPOP" encima de "ARENA" | `login_screen.gd`, `lobby_screen.gd` |
| 2026-10-17 | Arte de las cartas: "el b" (hoja `opciones-arte-cartas.png`) | Trama por defecto; `ARENA_CARD_ART=color` para comparar | `src/ui/onebit.gd` |
| 2026-10-17 | Muñeco: "por mi pásalo a 1b" | Línea 1 bit; estilo por sprite (`AnmSprite.style`), `ARENA_DOLL_STYLE` para comparar | `onebit.gd`, `anm_sprite.gd`, creación, lobby, paneles |

## Siguiente paso (para la próxima sesión)

Card Master hecho y aprobado, con el arte en trama. Sigue la tanda 2 con el **buzón**
(`mailboxDialog`), después el altar de fusión, el cementerio, las
conversaciones (`ElementDlg`) y los tótems, con el mismo patrón: un panel
sobre `lobby_panel.gd`, registrado en `_gui.native_factories` con el nombre
del diálogo retail, y eventos `native*` hacia los handlers de `main.gd`.
`ShopDlg` y `BarterDlg` de `main.tscn` quedan de reserva y se retiran con
los demás paneles de depuración.

Pendiente del dueño: el visto bueno del muñeco en línea (`muneco-1bit.png`).

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
      nativos (lista de S05). Card Master hecho (2026-10-17); faltan buzón,
      altar, fuegos artificiales, cementerio, retos, demonios, tótems.
- [ ] Retirar de `main.tscn` los paneles de depuración que queden sin uso.
- [ ] `godot/PRODUCT.md` y `DESIGN.md` al día (hoy dicen que el dueño fija el
      estilo de login y creación, y eso ya no vale).

## Criterio de cierre

Ninguna pantalla fuera del combate usa un diálogo retail XML ni el panel de
depuración, y todas tienen el visto bueno del dueño en hoja.
