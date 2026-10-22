# S10 — Tutorial y onboarding

**Planificado:** 2026-10-16 · **Detallado y abierto:** 2026-10-22 · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** 🟡 abierto (2026-10-22)

## Objetivo

Que un jugador que nunca ha jugado a Dofus Arena entienda qué hacer en sus
primeros diez minutos. El retail tenía un tutorial (la isla del mundo 35, el
Demonio III, los maestros de clase, Baan); aquí no hay mundo (S05: lobby), así
que el tutorial se trae al lobby.

## Punto de partida (auditoría del 2026-10-22)

**Hoy una cuenta nueva no tiene tutorial.**

- Entra al lobby sin luchadores. "Entrenamiento" lanza el demonio del minuto
  58 (desafío 34) con un "Champion" Feca que el servidor se inventa
  (`handlers_fight.go:203`).
- **La Ayuda está mal:** los títulos van desfasados uno respecto a su texto
  (solo `help.h0` es de la tanda nueva; `h1`–`h3` son de una vieja numerada
  desde 1). Además es ayuda de interfaz, sin reglas del juego.
- **Lo del tutorial está fuera de alcance:**
  - Los maestros de clase, el Demonio III (mundo 35) y Baan (mundo 85) no
    salen en Servicios.
  - Los disparadores de zona solo existen en el mundo 35 y nunca saltan.
  - `scenarios.gd` porta 12 de los 50 escenarios Lua, y su campo `zaap` no lo
    lee nadie.
- **El servidor:**
  - No marca los criterios 198–200 (los desafíos 29/30/31 del Demonio III),
    así que los logros 280, 281 y 284 son imposibles.
  - Los desafíos no dan XP (`fightFeedsProgression`), aunque 29/30/31/45 la
    traen en sus datos (1/1, 2/10, 3/15, 5/300).
  - No hay orden: el 30 y el 31 se pueden jugar sin el logro que los abre.
  - Nadie mueve las estadísticas 211 ni 226.
- **"taskId" no era un campo de escenario.** En el retail es el valor de
  `invoke`/`setInterval` (`aq_1`, `ajk_2`, `eh_1`). La tarea del esbozo no
  tenía objeto.
- **27551 está mal descrito** en `OPCODE-INVENTORY.md` ("notification pref
  ack"): es el "saltarse el tutorial" de las barras de menú tutorial
  (`avv_0.skipTutorial` → `and_2`).

**Cómo funcionaba el retail** (los Lua están en
`client/compiled/game/contents/data.jar`, `scripts/scenario/*.lua`):

- **Arranque.** Escenario 0, la cinemática de Adamai ("te ha capturado un
  demonio de las horas…", textos 90–97). El 4517 cambiaba al mundo 35 y el
  escenario 1 (98, 147–149) cerraba la intro con el 4523.
- **La isla.**
  - Las zonas lanzaban 100 (chat, equipo, mapa, "visita a los maestros de
    clases"), 102/103 (los demonios de las horas, el Demonio III) y 104 (los
    maestros); el 108 era el Zaap.
  - Reclutar tres guerreros (211 ≥ 3, logro 276).
  - La cadena del Demonio III: los desafíos 29 → 30 → 31, criterios 198/199/200,
    logros 280/281/284, escenarios 105/106/107; el 106 enseña el Kanodo.
- **Lo demás.**
  - Los demonios de los minutos (logro 278 → escenario 115) y la clasificación
    (279 → 116).
  - Herido o muerto (454/455 → 118/119).
  - Baan: el desafío 46 "Tutorial de Baan", con los escenarios 200/201
    (colocación y observación) y la estadística 226.
- **La ayuda (`tooltipTutoDialog`).** Enseñaba el siguiente paso pendiente,
  en este orden de logros: 275, 276, 284, 278, 277, 279.

## Decisiones (delegadas: "toma usando heurística", 2026-10-22)

| Decisión | Tomada | Por qué |
|---|---|---|
| ¿Revivir la isla (mundo 35)? | **no**: sus personajes vienen al lobby, en Servicios, en un grupo "Aprendizaje" (los 12 maestros de clase, el Demonio III y Baan) | S05 quitó los mundos a propósito |
| La intro de Adamai (escenarios 0 y 1) | un monólogo nativo la primera vez que se entra al lobby, que se puede saltar | es lo único que cuenta la historia; sin isla no hay 4517/4523 |
| La ayuda del retail (`tooltipTutoDialog`) | una sección "Primeros pasos" arriba de la Ayuda: el siguiente logro del tutorial con sus criterios marcados, calculado en el cliente | el cliente ya tiene logros y criterios; no hace falta el 22002 |
| Escenarios lanzados por logros (105–107, 115, 116, 118, 119) | el monólogo sale tras el aviso del logro | el retail lo hacía así (`zN` 22000 → `scriptID`) |
| Barras de menú tutorial y equipo tutorial (`menuBarTuto*`, `evolutionTeamManagementTuto*`) | **descartadas**: el lobby lo enseña todo desde el principio y los "Primeros pasos" guían | bloquear la interfaz sin isla solo estorba |
| `cardBookTutorial*`, `emissaryTutoDialog` | descartados: el primero no lo abre nadie; el segundo es el retrato de los monólogos, que ya hace el panel de diálogo | |
| 211 ("reclutar tres guerreros con los maestros") | +1 por cada luchador creado | el servidor no puede saber desde qué pantalla se creó, y el logro 276 pide 3 |
| 226 ("pedir a Baan las bases") | al ganar el desafío 46 | es el combate que enseña las bases |
| Orden de la cadena del Demonio III | el servidor rechaza el 30 sin el logro 280 y el 31 sin el 281; el cliente no los enseña | como el retail (`achievementLinkedCompleted`) |
| XP de los desafíos 29/30/31/45 | la de sus datos (`QC` por combate, `QD` de tope por luchador) | era la recompensa del tutorial |
| Reglas del juego | un texto corto propio en la Ayuda (es/en/fr); **no** se importa `docs/wiki/` | la wiki es de la 2.04, en inglés, y contradice la 2.70 |
| "Entrenamiento" sin luchadores | el cliente avisa de reclutar primero en vez de dejar luchar con un luchador inventado | el "Champion" es una comodidad de desarrollo |

## A. Servidor

- [ ] Criterios 198/199/200 al ganar el 29/30/31.
- [ ] XP de los desafíos con `QC` (29, 30, 31, 45): por luchador, con tope `QD`.
- [ ] Orden: 30 exige el logro 280; 31 el 281 (rechazo como desafío desconocido).
- [ ] Estadística 211 al crear luchador; 226 al ganar el 46.
- [ ] Docs: 27551 bien descrito; 4517/4523/4800 descartados por escrito (sin isla).

## B. Cliente Godot

- [ ] Ayuda: arreglar los títulos; "Primeros pasos" (siguiente logro del
      tutorial con sus criterios) y "Reglas básicas".
- [ ] Intro de Adamai la primera vez (escenarios 0/1), con "Saltar".
- [ ] Servicios → "Aprendizaje": maestros de clase (reclutar con la clase
      fijada, como `fighterCreationTutorialDialog`), Demonio III (29/30/31 en
      orden), Baan (desafío 46).
- [ ] Monólogos de los escenarios que lanzan los logros (105–107, 115, 116,
      118, 119) y los del 46 (200/201) al empezar ese combate.
- [ ] "Entrenamiento" sin luchadores: aviso para reclutar.

## Criterio de cierre

Una cuenta nueva recorre el tutorial de principio a fin (intro, reclutar tres,
la cadena del Demonio III con sus monólogos y su XP, Baan) en un smoke contra
un servidor real, con capturas.
