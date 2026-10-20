# 2026-10-20 — S18: avisos de invitación nativos

Pedido: "continúa". Tras retirar `ElementDlg`, lo que el jugador seguía
viendo sin estilo 1 bit eran los avisos de invitación: seis
`ConfirmationDialog` de Godot.

## Hecho (en `main-covaga`)

- **`src/ui/ask_panel.gd`** (`askDialog`): título (qué es), una línea (quién
  y qué), Rechazar y Aceptar (primario). Cerrar o Esc rechaza.
- `main.gd`: `_ask(tipo, título, texto, respuesta)` con **cola**: si llegan
  dos invitaciones a la vez, sale la primera y la siguiente al contestar.
  `_ask_withdraw` quita una que el otro retiró (26304) sin contestarla.
  Pasan por ahí: desafío (26300), combate encontrado (23110), clan (502),
  dúo (6025) e intercambio (5102).
- `main.tscn`: fuera `ChallengeDlg`, `ChallengeAskDlg` (nunca se abría),
  `MatchAskDlg`, `GuildAskDlg`, `DuoAskDlg` y `ExchangeAskDlg`.
- Borrar el coach pedía confirmación dos veces (el panel de Opciones y un
  diálogo de Godot): queda solo la de Opciones.
- Textos `duo.invite_ask`, `challenge.ask` y `guild.invite_ask` que no
  estaban en ninguna tabla (habrían salido como claves): añadidos en
  es/en/fr.
- `test/ask_smoke.gd` nuevo, con un segundo cliente (`test2`).

## Encontrado

Un `var x := a and b` sin tipo rompió el parseo de `main.gd`. La lane
headless de `run_tests.sh` no compila `main.gd` (solo los smokes y
`native_panels` lo hacen), así que solo un smoke lo detectó. Por eso los
smokes van siempre antes de subir.

## Verificado

Contra el servidor local, `ask_smoke.gd` 6/6: el bot propone intercambio y
desafía a la vez → dos avisos en cola, sale "Propuesta de intercambio";
Aceptar abre la ventana de intercambio (5104) y deja ver "Te desafían";
Rechazar manda 26307 y el bot recibe 26304; un tercer aviso cerrado con
Cerrar rechaza; una invitación a dúo "Pareja" rechazada llega al bot como
6027. Captura mirada: `ask-trade.png`. También `world` 31/31, `talk` 8/8,
`report` 5/5, `pvp` completo, `native_panels` 123 PASS, las dos lanes.

## Sin verificar, y por qué

- El aviso de **clan**: `test` ya es líder de un clan y el servidor rechaza
  invitarlo antes de que llegue el aviso; probarlo exige sacarlo de su clan.
- El de **combate encontrado**: hace falta que dos coaches busquen partida a
  la vez con equipos válidos.
Los dos usan la misma cola que los cuatro probados; solo cambia el texto y
la función que responde, que no se ha tocado.
