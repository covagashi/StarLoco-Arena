# S07 — Lo que el retail tenía y aquí falta

**Planificado:** 2026-10-16 · **Detallado:** 2026-10-21 · **Hito:** M2 — Identidad visual · **Tamaño:** M · **Estado:** 🟢 cerrado el 2026-10-21

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
- [x] **Ficha del luchador**: clic en una carta de la línea de tiempo →
      raza y bando, vida / PA / PM como están, estados, cartas y hechizos
      (`fight/fighter_info_panel.gd`). No es modal: sin sombra, el mapa sigue
      respondiendo y se pone junto a la columna de la carta pulsada. Otra
      carta la cambia, la misma la cierra, y se cierra si el luchador muere,
      como en el retail. Prueba: `fight_smoke` (abre, cambia, cierra).
- [x] **Cartas de evento**: la descripción al pasar el ratón. El retail usa
      `content.27` (efectos y duración) donde existe, 15 de 51, y genera el
      resto desde los efectos del evento (`tO.getDescription` → `asf_0`);
      aquí, para esos, el texto de ambiente de la carta (`content.9`).
      `npc_dialogs.py` exporta las dos tablas en los tres idiomas. Prueba:
      `fight_smoke` (la carta 14 lleva su texto).
- [x] **"Esperando a los rivales…"** tras pulsar Listo en la colocación, en el
      botón y en la línea de fase. Prueba: `fight_smoke`.
- [x] **Pantalla versus** al empezar el combate (fase de presentación,
      `fight/versus_panel.gd`): cada jefe con sus luchadores, "¡A luchar!" y
      una cuenta atrás. El retail espera al botón o a los 20 s del servidor;
      aquí el botón o 4 s, y antes se mandaba el 8011 al instante. Prueba:
      `fight_smoke` (sale con los dos bandos y da paso sola a la colocación).
- [x] ~~**Colores desbloqueados**: las cartas tipo 29 como colores extra al
      crear luchador.~~ El dueño (2026-10-21): "lo ideal sería no tener los
      colores"; los equipos se distinguen por su aro. Fuera el selector de
      piel, pelo y ojos: los luchadores nuevos se crean con el índice 255,
      que la paleta deja sin teñir (como `tn_0.hT` → `null` en el retail), y
      salen con los colores de su raza. Los ya creados conservan el suyo. Las
      23 cartas de color quedan en el backlog como posible premio de
      temporada. Pruebas: `test/unit/palettes_test.gd` y
      `test/colours_smoke.gd` (el servidor guarda y devuelve 255/255/255).
- [x] **Nombres en el idioma de la interfaz**: hechizos y cartas (las Zaap
      incluidas) se buscan en las tablas del retail por idioma
      (`gamedata/game_text.gd`: `content.3` y `content.23` de
      `assets/gui/i18n_<lang>.json`), con el inglés de respaldo. Las razas
      pasan a `breed.1`–`breed.12` en los tres idiomas (había una lista en
      español fija en los paneles y otra en inglés en `State`). Los NPC ya
      venían traducidos; los demonios del panel Ciudad salen ahora como en el
      resto ("Demonio XVI"). Prueba: `test/unit/game_text_test.gd` y la ficha
      de `fight_smoke` ("Castigo, Demencia…"). Quedan en otro idioma los nombres
      que manda el servidor (el jefe IA "Démon de la 58ème minute").
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

## Resultado (2026-10-21)

Cumplido. Cada diálogo del triaje está cubierto o descartado por escrito, y
cada tarea tiene su prueba:

- `./run_tests.sh --headless`: 9 suites, 236 checks, 0 fallos (nuevas
  `coach_level_test.gd` y `game_text_test.gd`). La lane visual, sin avisos
  de anchors (antes 54).
- Batería completa en vivo bajo xvfb, cada smoke sembrado sobre una copia
  fresca de la base: `fight` (versus, "Esperando a los rivales…", carta de
  evento con su texto, ficha del luchador), `report` 7/7 (subida de nivel y
  su contrario), `audio` 7/7, `world` 31/31, `talk` 8/8, `pvp`, `ask` 8/8,
  `ask2` 5/5, `screens` 9/9, `mailbox` 8/8, `cardmaster` 5/5, `fusion` 5/5,
  `revive` 6/6, `revive_edge` 4/4, `totems` 10/10, `native_panels`,
  `native_lobby`, `login_smoke`, las dos lanes y `go test ./...`.
- Capturas en `~/codigo/capturas/s07/`: `subida-nivel.png`, `versus.png`,
  `ficha-luchador.png`.

Encontrado por el camino y fuera del alcance:

- `pvp_smoke` nunca pulsaba Listo en la colocación: su vista de combate no
  recibe el 8020 (el arnés deja dos lobbies vivos) y la colocación acaba por
  tiempo. No cambia el resultado del smoke; la prueba de "Esperando…" va en
  `fight_smoke`.
- Dos `ERROR: Lambda capture … was freed` en `report_smoke`, iguales en
  `HEAD`: vienen del arnés, que libera un lobby a mano.
- Lo que manda el servidor en un solo idioma (el jefe IA "Démon de la 58ème
  minute", luchadores IA llamados como su raza en inglés/francés).
- El retail genera la descripción de 36 cartas de evento desde sus efectos
  (`asf_0`); aquí, de momento, su texto de ambiente.
