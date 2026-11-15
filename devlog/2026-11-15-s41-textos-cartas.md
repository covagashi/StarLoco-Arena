# 2026-11-15 — S41 paso 1: lo que hace cada carta

El dueño pidió seguir con S41 a partir de la nota de S40 ("las cartas aún
dicen +50 % XP"). Detalle y decisiones en `sprints/S41-textos-propios.md`.

## Qué se encontró

- La nota de S40 era una sospecha: el cliente nativo **no enseñaba ningún
  efecto** de las cartas de coach (descripción vacía en el inventario).
- El servidor **no aplicaba los efectos propios de las cartas puestas**,
  solo los de sus sets. Arreglado (`coachBonusFor`): ahora cuentan, también
  en el botín; la resurrección que suma el equipo, como mucho +25.
- Las pociones de Historia con dos condiciones solo aplicaban la primera.
  Arreglado.

## Qué se hizo

- `cmd/dumpcards` exporta los efectos de cartas (`fx`) y sets
  (`cardsetfx.json`).
- `godot/src/gamedata/card_text.gd` + claves `cardfx.*` en es/en/fr: el
  detalle del Inventario dice qué hace la carta, cuándo cuenta y qué nivel
  pide; la pestaña Colecciones, los bonus del set por número de cartas.

## Verificado

- `go test ./...` en verde (en `server/`); las cuatro pruebas nuevas fallan
  sin el cambio (comprobado quitando los efectos propios de `coachBonusFor`).
- `godot/run_tests.sh --headless`: 1614/0.
- `test/inventory_smoke.gd` bajo xvfb contra un servidor local (copia de
  `arena.db` en el scratchpad, cartas 409, 137, 305, 123 y del set 1
  sembradas): 7/7. Capturas en `~/codigo/capturas/s41/`.

## No verificado / pendiente

- `go vet ./...` avisa en `internal/store/seasons.go` (copia de un mutex en
  un `range`); ya estaba antes de esta sesión, no se ha tocado.
- `cards.json` y `cardsetfx.json` del cliente son locales (fuera de git):
  otra máquina tiene que volver a correr `go run ./cmd/dumpcards data-dist
  ../godot/assets/gamedata/cards.json` desde `server/`.
- Los nombres (cartas, colecciones, condiciones) siguen siendo retail: lo
  siguiente de S41.
