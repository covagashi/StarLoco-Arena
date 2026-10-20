# 2026-10-20 — S18: intercambio entre jugadores nativo, PvP probado de punta a punta

Pedido: "continúa". Para probar el informe de combate con informe de
luchadores hacía falta un PvP real, y `pvp_smoke.gd` ya no llegaba: se
atascaba en el intercambio previo. Era la última pantalla legacy que el
jugador ve.

## Por qué estaba roto `pvp_smoke.gd`

Al aceptarse un intercambio se abría el diálogo XML retail
`exchangeDialog`, pero el smoke esperaba el panel de depuración: nunca
ponía cartas ni confirmaba, y el combate no empezaba (timeout a los 60 s).

## Hecho (en `main-covaga`)

- **`src/ui/exchange_panel.gd`** (`exchangeDialog`): tus cartas
  intercambiables a la izquierda; "Tú ofreces" y "{otro} ofrece" con su
  valor y "Listo" / "Aún no"; Ofrecer (de una en una: el 5105 lleva la
  cantidad TOTAL, el servidor reemplaza), Quitar, Cancelar y Listo. Cerrar
  la ventana cancela el intercambio (5111).
- El cliente anula el "Listo" de los dos al cambiar cualquier oferta, como
  ya hacía el servidor (`exchange.go stageCard`); antes seguía enseñando
  "listo" a quien ya no lo estaba.
- Límite de 5 cartas distintas por lado (el del servidor y el retail),
  avisado en el panel; los rechazos (5113: carta única o ligada) salen en
  el panel.
- El chat decía "Tú está listo": ahora "Estás listo".
- `pvp_smoke.gd`: la fase de intercambio usa el panel nativo, el bot
  ofrece la carta 1 (la 7 se le acabó tras varias ejecuciones), comprueba
  las dos ofertas, comprueba el informe nativo tras el PvP y admite
  `--shot-dir`.

## Verificado

Contra el servidor local, `pvp_smoke.gd` completo bajo xvfb (dos sockets
más un espectador): dúo, clan, intercambio (`TRADE OK`: mi oferta y la del
bot en sus tablas, 5114 SWAP COMMITTED), desafío PvP, combate, rendición, y
el informe nativo del lobby con **una fila de luchador real**
("Humo +100 xp, Bien") — lo que la entrada anterior dejaba sin verificar.
Capturas miradas: `exchange.png`, `fight-report-pvp.png`.
`world_smoke` 31/31, `report_smoke` 5/5, `native_panels` 123 PASS, las dos
lanes de `run_tests.sh`.

## Estado del entorno

Cada `pvp_smoke.gd` mueve una carta entre `test` y `test2` (los dos
ofrecen la primera que tienen) y les hace pelear una vez.

## Para empezar mañana

Retirar de `main.tscn` los paneles de depuración que ya no usa nadie
(`ElementDlg` con sus ramas de fusión, buzón e intercambio, `ShopDlg`,
`BarterDlg`, la fila de botones de depuración) y quitarlos de los smokes que
aún los miran.
