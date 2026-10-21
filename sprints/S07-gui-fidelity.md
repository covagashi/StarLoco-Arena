# S07 — Lo que el retail tenía y aquí falta

**Planificado:** 2026-10-16 · **Detallado:** 2026-10-21 · **Hito:** M2 — Identidad visual · **Tamaño:** M · **Estado:** 🟡 abierto

## Objetivo

Cubrir con paneles nativos lo que el retail enseñaba y el cliente Godot no, y
cerrar los restos sueltos de interfaz. Ya no es "fidelidad GUI": S18 sustituyó
todos los diálogos XML del retail por paneles propios (el dueño los considera
legado), así que lo que queda es lo que falta, no cómo se ve.

## Triaje de los diálogos retail sin referencia (2026-10-21)

Leído en el XML del retail, en el cliente descompilado (quién lo abre) y en el
cliente Godot (si ya hay equivalente con otro nombre).

| Diálogo retail | Cuándo lo abre el retail | En Godot | Decisión |
|---|---|---|---|
| `fightPresentation` | 8010 (`do_2`): ventana "versus" con los dos bandos, rango, rachas y cuenta atrás | se manda 8011 al instante, solo una etiqueta de fase | **tarea**: pantalla versus breve |
| `fightPlacement` | 8020 | fase de colocación completa, Listo → 8023 | cubierto |
| `fightEventCards` | al salir de la observación | tira `$UI/EventCards`, solo nombres | **tarea**: la descripción al pasar el ratón |
| `fightObservation` | 8030 | se salta a propósito (8031 al instante) | cubierto |
| `fighterInformations` | clic en un luchador de la línea de tiempo (18012) | el clic solo centra la cámara | **tarea**: ficha nativa del luchador |
| `coachLevelUp` | 8300, si la reputación ganada cruza un nivel (`WE`) | nivel del coach fijo a 0 | **tarea**: nivel real y aviso de subida |
| `unlockedColors` | "+" junto a un color al crear luchador (20130): cartas tipo 29 "Couleur" | solo los colores naturales | **tarea** (baja prioridad) |
| `chatFilter` | clic derecho en una pestaña del chat | pestañas de un solo canal | cubierto (simplificado) |
| `teamLoad` | cargar equipos guardados en ficheros `.atd` locales | los presets del servidor sí funcionan | descartado: importar ficheros locales no aporta |
| `teamList` | nunca (XML muerto) | panel de Equipo | no aplica |
| `progressDialog` | carga, login, reconexión, "esperando a los rivales" | nada tras pulsar Listo | **tarea**: "Esperando a los rivales…" |
| `splitCardMasterTrade` | arrastrar un montón al Card Master | cada clic añade una copia | cubierto |
| `splitDemonAffiliationTrade` | ídem en la ofrenda al demonio | ídem | no aplica (no hay arrastre) |
| `demonIIDialog` | 5401 con modo 1 | el modo se lee y se ignora | no aplica: el servidor siempre manda modo 0 |

## Tareas

- [x] Los avisos de anchors: no eran 4 sino 4 + 50 (`login_screen`,
      `creation_screen` y la sombra de cada panel nativo, `lobby_panel`).
- [x] **Nivel del coach**: la reputación de cada 8300 se suma a
      `State.coach_standing` (el absoluto solo llega con el 2052 del login), el
      nivel sale de la fórmula del retail (`aet_0.nJ`, la misma que
      `StandingToLevel` del servidor) y, al cerrar el informe de un combate que
      cruza un nivel, sale el aviso nativo (`level_up_panel.gd`). El retail
      enseña al jefe bailando; los sets del jefe no traen emotes, así que salta.
      Pruebas: `test/unit/coach_level_test.gd` (bordes de nivel) y dos pasos
      nuevos en `report_smoke` (cruza un nivel → aviso con el 4 y el lobby en
      "Nivel 4"; +1 dentro del nivel → sin aviso).
- [ ] **Ficha del luchador**: clic en la línea de tiempo → estadísticas,
      equipo y hechizos del luchador.
- [x] **Cartas de evento**: la descripción al pasar el ratón. El retail usa
      `content.27` (efectos y duración) donde existe, 15 de 51, y genera el
      resto desde los efectos del evento (`tO.getDescription` → `asf_0`);
      aquí, para esos, el texto de ambiente de la carta (`content.9`).
      `npc_dialogs.py` exporta las dos tablas en los tres idiomas. Prueba:
      `fight_smoke` (la carta 14 lleva su texto).
- [x] **"Esperando a los rivales…"** tras pulsar Listo en la colocación, en el
      botón y en la línea de fase. Prueba: `fight_smoke`.
- [ ] **Pantalla versus** al empezar el combate (fase de presentación).
- [ ] **Colores desbloqueados**: las cartas tipo 29 como colores extra al
      crear luchador.
- [ ] Nombres de gamedata en inglés con la UI en español (NPCs, cartas Zaap,
      demonios): exportar los nombres en los tres idiomas.
- [x] `fight_view.gd`: fuera `_mount_fight_hud` y con él todo el HUD XML del
      retail que colgaba de él (`_gui` nunca se asignaba): `_hud_push`,
      `_on_gui_event`, los `_position_*`, `_timeline_items`… 208 líneas.
- [x] **El chat ya no vuelca datos**: cada push del roster escribía la lista
      entera de luchadores ("Humo (Iop), Humo (Iop)…"), y también salían el
      número de equipos guardados, de cartas distintas, de torneos y de cartas
      del buzón. Queda solo "Aún no tienes luchadores".

## Descartado o resuelto por el camino

- Las letras en español horneadas en el arte: S18 dejó de dibujar ese arte
  (`DESIGN.md`); ya no aplica.
- El Card Master beige: el panel es nativo desde S18.
- Card Masters de modo 1 (`demonIIDialog`): el servidor siempre manda modo 0.
- `useSpecialCard` de tipo 28 (22093) y 30 (22097): son transferencias de
  cartas a otro juego de Ankama, descartadas ya en
  `server/docs/OPCODE-INVENTORY.md`.
- Las tareas de fidelidad de los diálogos XML (theme, estados del atlas,
  `teamManagementDialog`, fuentes DDS): sin objeto tras S18.
- **Color de los mapas** (tinte por elemento y luz horneada): es arte de
  mapa y necesita comparar con capturas del retail y el ojo del dueño; pasa a
  S04, que ya trata los mapas de combate. Formato en
  [`client/analysis/MAP-LIGHT.md`](../client/analysis/MAP-LIGHT.md).

## Criterio de cierre

Cada diálogo del triaje cubierto o descartado por escrito, cada tarea hecha
con su prueba, y capturas de lo nuevo en el *Resultado*.
