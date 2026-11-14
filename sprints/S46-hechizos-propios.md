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

## Criterio de cierre

El servidor no lee ningún hechizo de `data-dist/`; las partidas siguen
equilibradas (simulaciones IA contra IA, como S29).
