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
- [ ] **El mundo 35 es la isla del tutorial** (S05, 2026-10-17). Se llegaba
      desde la cinemática (`scenario/0.lua` → `tutorialChangeInstance()` →
      4517) y se salía por Zaap con la carta 254. El servidor no implementa
      4800 (RunScript), 4523 (`skipTutorial`, escenario 1) ni el relevo del
      4517. Hoy el 35 solo se alcanza con `/world`. Detalle en S05, "Mundos
      sin Zaap".
- [ ] Ayuda in-game con las reglas (hay material en `docs/wiki/`).
- [ ] **La cadena del Demonio III** (de S19, 2026-10-22): los desafíos 29, 30
      y 31 son "en modo evolución" (criterios 198–200 de `or_0`) y llevan XP
      (`GE.QC`/`QD`: 1/1, 2/10, 3/15). Falta: que el servidor marque 198–200
      al ganarlos; que la lista solo enseñe el 30 tras el logro 280 y el 31
      tras el 281 (`afz_0.achievementLinkedCompleted`); la XP de esos
      combates (hoy un desafío no da progresión: `fightFeedsProgression`); y
      el resultado propio que abre el retail (`fightResultEvolutionTutoDialog`
      hasta el logro 284, `fightResultEvolutionChallengeDialog` después). El
      45 (Bernabé, 5/300) usa el mismo resultado.

## Criterio de cierre

Una cuenta nueva recorre el tutorial completo de principio a fin, con capturas.
