# 2026-10-20 — S18: los casos de "Caídos" que quedaron sin probar

Pedido: el dueño preguntó por qué no probé lo que la entrada anterior
([`2026-10-20-s18-caidos.md`](./2026-10-20-s18-caidos.md)) dejaba "sin
verificar". Tenía razón: las tres cosas se podían probar. Esta entrada lo
corrige.

## Hecho

- **El mensaje de resultado va en el pie del panel** (donde pone
  "Cambios de equipo sincronizados"), no en la columna del detalle. Así el
  detalle no crece y no hay scroll.
- `test/revive_smoke.gd` comprueba ahora que el cuerpo del panel no hace
  scroll a 1280×720 en el detalle del muerto, del retirado y después de
  resucitarlos.
- `test/revive_edge_smoke.gd` nuevo, con su siembra en la cabecera:
  - **Tirada fallida**: todas las cartas de resurrección son del 100 %, pero
    el servidor acepta en 22099 cualquier carta con efecto de resurrección y
    la gasta. La chaqueta Weerdtrot (137) da un 1 %. El smoke la manda por
    la función de resucitar del cliente, porque el panel no la ofrece, y
    también comprueba que no la ofrece.
  - **Banquillo lleno** (7): el botón del retirado sale desactivado con el
    motivo. Si se fuerza igualmente, el servidor rechaza y la carta no se
    gasta.

## Verificado

Contra un servidor local nuevo en cada escenario, sembrando con el servidor
parado:

- `revive_smoke.gd` 6/6, con las tres comprobaciones de que no hay scroll.
- `revive_edge_smoke.gd` 4/4: el panel ofrece solo "Resurrection"; la
  tirada falla (log del servidor: `resurrection failed … card=137 pct=1`),
  el luchador sigue muerto, la carta pasa de 3 a 2, no llega 6006, y el pie
  dice "La tirada falló: Weerdtrot Jacket se ha gastado y Humo sigue
  muerto."; con 7 en el banquillo, botón desactivado con el motivo y, forzado,
  la carta sigue en 1 y "El servidor no aceptó la resurrección de Humo."
- `native_panels.gd` 123 PASS, 0 FAIL; `run_tests.sh --headless` 158 checks.
- Capturas miradas: `revive-failed.png`, `revive-bench-full.png`,
  `revive-done-2.png`.

## Sin verificar

- La tirada falla 99 veces de cada 100: si alguna vez sale el 1 %, el smoke
  lo dice y hay que volver a sembrar.

## Estado del entorno

`server/arena.db` restaurado: luchador 1 en el banquillo, 2–15 titulares,
sin cartas 137 ni 305 (como estaba). Servidor parado.
