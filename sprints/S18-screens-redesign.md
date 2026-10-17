# S18 — Todas las pantallas, nuevas

**Planificado:** 2026-10-17 · **Hito:** M2 — Identidad visual · **Tamaño:** L · **Estado:** ⚪ esbozo · **Depende de:** S05 (servicios accesibles)

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

## Por decidir con el dueño

- **Dirección visual.** Opciones a enseñar en hoja: la familia del HUD de
  combate de S17 (el último estilo aprobado), el 1 bit de S04, u otra con
  referencias del dueño.
- ¿Entra el HUD de combate (S17, cerrado con su visto bueno)?
- Orden. Propuesta: primero el sistema (marco, botones, listas, tipografía)
  sobre una pantalla de cada tipo (login, un panel con tabla, un servicio),
  y luego el resto en tandas.

## Tareas candidatas

- [ ] Hoja de 2–3 direcciones sobre las mismas tres pantallas.
- [ ] Componentes comunes en `lobby_panel.gd` según la dirección elegida.
- [ ] Login y creación de coach.
- [ ] Lobby y sus 21 paneles.
- [ ] Servicios: sustituir los diálogos XML y `ElementDlg` por paneles
      nativos (lista de S05).
- [ ] Retirar de `main.tscn` los paneles de depuración que queden sin uso.
- [ ] `godot/PRODUCT.md` y `DESIGN.md` al día (hoy dicen que el dueño fija el
      estilo de login y creación, y eso ya no vale).

## Criterio de cierre

Ninguna pantalla fuera del combate usa un diálogo retail XML ni el panel de
depuración, y todas tienen el visto bueno del dueño en hoja.
