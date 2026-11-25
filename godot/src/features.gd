extends RefCounted
## Features the owner switched off without deleting them (S20, 2026-10-24).
## The code behind each stays; flip a switch to bring the feature back.

## 2vs2: hidden "para no tener problemas de baja población". Hides the Team
## panel's 2vs2 tab and the lobby's dúo action.
const DUO := false

## Leyendas: removed. Hides the Team panel's Leyendas tab, "Convertir en
## leyenda" and the Legends tournaments (definition 24) in the Calendar and
## the tournament picker.
const LEGENDS := false

## The Evolution PvP queue (23003): off since Historia is the campaign of PvE
## challenges (S21). Hides "Buscar combate" on the Team panel's Historia tab;
## the hub's Historia card opens the campaign. Tournaments of the evolution
## kind still field the same team.
const EVO_PVP := false


## «Guardar mi progreso» (S51): turning the guest account into one with an
## email and password, «Ya tengo cuenta» and the reset code. Off for the
## alpha (owner, 2026-11-25: "al ser una alfa, déjalo como guest"): everyone
## plays as a guest of this browser. The server keeps the opcodes; the S51
## smokes switch it on with `-- --save-account`.
const SAVE_ACCOUNT := false


static func save_account() -> bool:
	return SAVE_ACCOUNT or OS.get_cmdline_user_args().has("--save-account")


## The Team panel tabs that show, by retail game-mode id (0 evolution,
## 1 elite, 2 2v2, 3 tournaments, 4 legends). S47 (owner): no Tournaments
## tab — tournaments live in their own screen (Torneos) and a classic one
## fields the Élite team.
static func team_modes() -> Array:
	var modes := [0, 1]
	if DUO:
		modes.append(2)
	if LEGENDS:
		modes.append(4)
	return modes
