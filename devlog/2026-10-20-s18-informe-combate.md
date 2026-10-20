# 2026-10-20 — S18: informe de combate nativo y la vuelta del combate (B-178)

Pedido: "continúa". Tras los servicios, lo siguiente que usaba el panel de
depuración `ElementDlg` y que el jugador ve era el informe al terminar un
combate.

## Hecho (en `main-covaga`)

- **`src/ui/report_panel.gd`** (`fightReportDialog`): Victoria / Derrota /
  Combate abandonado en el título; clasificación y bajas en una línea; los
  coaches con su fuerza nueva; una fila por luchador (XP, moral y cansancio
  con su cambio, estado Bien / Herido / Muerto); las cartas ganadas en una
  línea; "Continuar". `main.gd` `_show_fight_result` ahora rellena el
  modelo `fightReport` (sigue aplicando el informe al roster) y fuera
  `_style_fight_debrief`.
- **B-178**: al volver de un combate normal, `main.gd` reproducía los
  mensajes pendientes antes de crear su interfaz; la entrada al lobby
  fallaba y el informe no salía nunca. El drenado va ahora al final de
  `_ready`.
- `cards.gd` lee el idioma de `State.locale` en vez del autoload `I18n`:
  en los smokes `-s` el autoload no compila y `fight_smoke.gd` daba
  "Nonexistent function 'name_of'" en la barra de hechizos (ya pasaba antes
  de hoy; comprobado con los cambios guardados aparte).
- `test/report_smoke.gd` nuevo.

## Verificado

Contra el servidor local, `report_smoke.gd` 5/5 bajo xvfb:

- Desafío (26330 → 8000), rendición a los 5 s (8151) y el lobby recibe el
  8300: informe nativo "Derrota" con los dos coaches; Continuar lo cierra.
- Las filas de luchador y las cartas: los combates de desafío no traen
  informe de luchadores, así que el smoke le pasa a `_show_fight_result` la
  forma decodificada de uno de evolución (dos luchadores, uno muerto, dos
  cartas): "Victoria", 2 filas, el segundo "Muerto", la moral del roster
  pasa a 55, y todo cabe sin scroll a 1280×720.
- El camino normal: con el lobby viejo desenganchado, la vista de combate
  confirma, el servidor reingresa al coach y una escena principal nueva
  enseña el lobby y el informe (antes: tres errores de script y nada).
- `world_smoke` 31/31, `native_panels` 123 PASS, `fight_smoke` sin errores
  de script, `totems_smoke` 10/10 sembrado, las dos lanes de
  `run_tests.sh`.

## Sin verificar, y por qué

- Un 8300 real de evolución con informe de luchadores: hace falta un
  combate de evolución entre dos coaches. Lo probado es el pintado con la
  forma que da el decodificador, no el decodificador con datos de ese
  combate.

## Estado del entorno

Cada ejecución de `report_smoke.gd` pierde dos combates con el coach
`test`: sus luchadores acumulan cansancio y moral como en cualquier
derrota. `server/arena.db` sin más cambios (lo de tótems, restaurado).
