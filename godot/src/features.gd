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


## The Team panel tabs that show, by retail game-mode id (0 evolution,
## 1 elite, 2 2v2, 3 tournaments, 4 legends).
static func team_modes() -> Array:
	var modes := [0, 1]
	if DUO:
		modes.append(2)
	modes.append(3)
	if LEGENDS:
		modes.append(4)
	return modes
