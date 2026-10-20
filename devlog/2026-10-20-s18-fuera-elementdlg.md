# 2026-10-20 — S18: fuera el panel de depuración `ElementDlg` (y `ShopDlg`, `BarterDlg`)

Pedido: "continúa". Con todos sus usos ya nativos, tocaba retirar los
paneles de depuración que S18 dejó "de reserva".

## Hecho (en `main-covaga`)

- `main.tscn`: fuera los 33 nodos de `ElementDlg`, `ShopDlg` y
  `BarterDlg` (152 líneas), sin recursos huérfanos.
- `main.gd`: fuera las 19 funciones que solo los servían (`_element_text`,
  `_on_element_act/_alt`, las ramas de fusión, buzón, intercambio y
  estadísticas de depuración, la tienda y el trueque de reserva, la etiqueta
  del monedero de la tienda), sus conexiones en `_ready` y las constantes
  `ELEM_EXCHANGE` y `ELEM_COACH`. `_open_shop` abre solo el Card Master
  nativo. Un elemento sin pantalla propia ya no abre un panel vacío: queda
  en el log de depuración.
- Smokes: `world_smoke.gd` tiene `_debug_pane_shown()`, que tolera que el
  nodo no exista; `talk`, `fusion`, `mailbox` y `report` la usan.
  `report_smoke.gd` lanza el segundo combate desde la escena principal
  vigente y desengancha la vieja: se acabó el error de dos lobbies a la vez.

## Verificado

Con el servidor local, todo en vivo y bajo xvfb tras el borrado:

| Smoke | Resultado |
|---|---|
| world | 31/31 |
| talk | 8/8 |
| report | 5/5, sin errores de script |
| pvp | completo, TRADE OK, report_rows=1 |
| cardmaster | 5/5 |
| mailbox | 8/8 |
| fusion | 5/5 |
| revive / revive_edge | 6/6 y 4/4, sembrados |
| totems | 10/10, sembrado |
| native_panels | 123 PASS |
| run_tests.sh | headless 158, visual OK |

## Encontrado

- `coachInventoryDialog` ya era nativo (alias a `cardBookDialog` en
  `gui_layer.gd`). `newMailDialog` solo se abre desde botones del buzón XML,
  que ya no se abre.
- Lo que el jugador sigue viendo sin estilo 1 bit: los avisos de
  invitación (desafío, combate encontrado, clan, dúo, intercambio), que son
  `ConfirmationDialog` de Godot. Es lo siguiente.

## Estado del entorno

Las ejecuciones gastan cartas del coach `test` (Card Master, fusión), le
hacen perder combates y mueven cartas con `test2`. Las siembras de revive
y tótems, restauradas.
