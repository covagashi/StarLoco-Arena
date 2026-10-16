# S10 — Tutorial y onboarding

**Planificado:** 2026-10-16 · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

Que un jugador que nunca ha jugado a Dofus Arena entienda qué hacer en sus
primeros diez minutos. El retail tiene el tutorial Kanojedo y varios diálogos de
tutorial; el cliente Godot tiene una versión reducida.

## Punto de partida

- `scenarios.gd` reduce los escenarios Lua del retail a páginas de monólogo.
- Los disparadores de zona solo saltan cuando aparece un elemento, porque ya no
  se camina (depende de lo que decida S05).
- Los escenarios del cliente con `taskId` no se ejecutan (`main.gd`).
- Ningún código usa los diálogos de tutorial del retail: `cardBookTutorial*`,
  `menuBarTuto*`, `evolutionTeamManagementTuto*`,
  `fighterCreationTutorialDialog`, `emissaryTutoDialog`.

## Tareas candidatas

- [ ] Inventario del tutorial retail: qué escenarios hay y en qué orden.
- [ ] Los diálogos de tutorial, nativos.
- [ ] Escenarios con `taskId`.
- [ ] Primer combate guiado.
- [ ] Ayuda in-game con las reglas (hay material en `docs/wiki/`).

## Criterio de cierre

Una cuenta nueva recorre el tutorial completo de principio a fin, con capturas.
