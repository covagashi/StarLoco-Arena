# 2026-10-20 — B-177: el servidor ya no gasta equipo como resurrección

Pedido: el dueño no sabía si el retail dejaba usar equipo para resucitar.
Lo comprobé en el cliente descompilado ("comprueba eso del cliente") y,
visto el resultado, "confío en ti, haz los cambios".

## Lo que hace el retail

- El cementerio solo lista las cartas de los sets "evolutionSets": sets cuya
  primera carta es de tipo 24, "Evolution" (`aij_0`, `aMK.dYy`).
- Al soltar una carta sobre un muerto exige el efecto de resurrección
  (`aks_2` evento 23056 → `xj.DF()` → `nz_1.aaF()`; si no,
  "noConsumableEffectOnDeadFighter"), y avisa si el banquillo está lleno.

El servidor solo tenía el segundo filtro, así que un cliente modificado podía
gastar una chaqueta Weerdtrot (valor 57, 1 %) en vez de una Resurrection
(33 200, 100 %).

## Hecho

- `handleFighterUseItemOn` exige también tipo 24
  (`gamedata.CardTypeEvolution`). Lo demás se rechaza sin gastarse.
- Tests: `TestResurrectEquipmentCardRefused` (falla sin el arreglo: se
  gastaban las cinco) y `TestResurrectionConsumablesAreEvolutionTypeShipped`
  sobre `data-dist`, que corre también en CI.
- `godot/test/revive_edge_smoke.gd`: el primer caso pasa de "tirada fallida"
  a "equipo rechazado".
- BUGS.md B-177, fila en DATA-COVERAGE, BACKLOG cerrado.

## Verificado

- `go vet ./...`, `go test ./...` (11 paquetes OK), `go test -race` de los
  tests de resurrección y consumibles.
- En vivo, con el servidor recompilado: `revive_smoke.gd` 6/6 y
  `revive_edge_smoke.gd` 4/4 (la chaqueta se queda en el inventario, 3 → 3,
  el luchador sigue muerto y el pie dice que el servidor la rechazó).
  El log del servidor no registra ninguna "resurrection failed".

## Consecuencia

Con los datos actuales, **una tirada fallida ya no puede pasar**: las cuatro
cartas de resurrección son del 100 % y los bonus de set solo suman. La rama
del panel para "la tirada falló" se queda, por si un día hay cartas con menos
probabilidad; el lado del servidor lo fija
`TestResurrectFailedRollConsumesButKeepsDead`.

## Estado del entorno

`server/arena.db` restaurado (luchador 1 en el banquillo, 2–15 titulares,
sin cartas 137 ni 305). Servidor parado.
