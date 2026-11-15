# S46 — Hechizos propios (datos)

**Planificado:** 2026-11-14 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** ⚪ esbozo (tras S40)

## Decisión del dueño (2026-11-14)

"Hacemos un sprint de cartas y otro sprint de hechizos": S40 lleva las
cartas, y este los hechizos.

## Alcance a decidir al planificarlo

- Los hechizos de las 24 clases (`spells` en `data.bdat`), las invocaciones y
  los efectos estáticos, con el mismo camino que S40: el mismo esquema y los
  mismos ids, los datos en `server/content/` (todos los derechos reservados) y
  una prueba de paridad antes de rediseñar nada.
- ¿Entran también las clases (vida, PA, PM de cada luchador)? Van atadas a sus
  hechizos.
- Cada hechizo ya tiene su receta de VFX (S37) y su sonido por forma y
  elemento (S39); el rediseño debe respetarlos o cambiarlos a la vez.

## Llega de S40 (2026-11-15)

- **Mover segundo da ventaja** (`balance_sim_test.go`): quien entra primero
  en el alcance del otro recibe el primer golpe, así que la iniciativa alta
  penaliza (+30: 20–30 % de victorias en espejo). Es de reglas más que de
  cartas: casillas de salida, o que la iniciativa dé otra ventaja.
- **La IA no usa el ataque de las armas** (solo `closeCombatAI`, el golpe
  genérico): hay que enseñárselo y medir entonces las armas con la misma
  simulación.

## Criterio de cierre

El servidor no lee ningún hechizo de `data-dist/`; las partidas siguen
equilibradas (simulaciones IA contra IA, como S29).

## Llega de S41 (2026-11-15)

Los nombres de los hechizos ya son nuestros (`spell.<id>` en
`godot/assets/i18n/content_<lang>.json`) y las clases también (`breed.N`:
Bastión, Domador, Buscaoro, Sombra, Relojero, Tahúr, Curandero, Espadachín,
Arquero, Jardinero, Furia, Panda). Las cartas de regla que prohíben o
encarecen un hechizo apuntan a él (`@spell:<id>`): si el rediseño cambia ids,
hay que actualizar esas referencias.

## Llega de S43 (2026-11-15)

Los hechizos, las invocaciones y los efectos estáticos ya están congelados
en `server/content/rules/` (`spells.json`, `summonings.json`,
`static_effects.json`), con prueba de paridad contra `data.bdat`
(`TestRulesContentParity`): el primer paso de este sprint está hecho. Al
rediseñar, se edita ahí, se quita esa tabla de la paridad y se corre
`go run ./cmd/exportclient` para el cliente.
