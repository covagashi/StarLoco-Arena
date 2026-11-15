# S41 — Textos propios

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ⚪ esbozo (después de S40)

## Decisión del dueño (2026-10-25)

El tercer paso, tras el arte y las cartas: ningún texto del retail.

## Alcance

- Los nombres y descripciones de cartas, hechizos, eventos, logros, retos y
  NPC que hoy salen de las tablas retail (`content.*`, `npcdialogs.json`),
  reescritos en es/en/fr. S23 ya revisó a mano los de los NPC y S26 renombró
  demonios: es la base.
- Ayuda, tutorial e historia del mundo (el Horamundo) con voz propia.
- Quitar `GameText` y los `gui/i18n_*.json` retail.

## Llega de S40 (2026-11-15)

Las descripciones de las cartas en el cliente son textos retail, no salen de
los datos: tras los topes de S40 algunas dicen lo que ya no es ("+50 % XP",
"100 % de resurrección"). Los textos nuevos deben salir de los efectos de
`server/content/` (o escribirse contra ellos).

## Criterio de cierre

Todo texto que ve el jugador sale de los ficheros i18n propios.
