# S10 — Tutorial y onboarding

**Planificado:** 2026-10-16 · **Detallado y abierto:** 2026-10-22 · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** 🟢 cerrado (2026-10-22)

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

- [x] **Criterios 198/199/200** al ganar el 29/30/31 (y 226 al ganar el 46),
      en el mismo mapa que los demonios de los minutos
      (`challengeCriterion`).
- [x] **XP de los desafíos** con `QC` (29, 30, 31, 45): por cada luchador del
      coach en el combate, sin pasar de `QD` de XP total (1/1, 2/10, 3/15,
      5/300), así que repetirlos no sirve para subir. Es su única XP: los
      desafíos no pasan por el META de fin de combate. **Decisión**: se lee
      `QD` como tope de XP total del luchador; en el retail no está claro si
      era eso o un tope por desafío, y con esta lectura no se puede abusar.
- [x] **Orden**: el 30 se rechaza sin el logro 280 y el 31 sin el 281 (26310,
      "no se pudo crear el combate"), evaluando la definición del logro con
      los criterios del coach.
- [x] **Estadística 211**: +1 por luchador creado.
- [x] **Docs**: 27551 era "saltarse el tutorial" (no un ack de
      notificaciones); 4523 es "intro terminada" y 4800 el lanzador de
      escenarios; los tres, descartados por escrito (sin isla). La cobertura
      de estadísticas sube a 89 de 98.

Pruebas (2026-10-22): `go test ./internal/game -run 'DemonIII|ChallengeXP|BaanTutorial'`
(criterios, XP con su tope, el orden 29 → 30 → 31 por el 26330 real, el 226)
y `./test/e2e -run Recruits` (tres luchadores por el 6001 real → 211 = 3).

## B. Cliente Godot

- [x] **Ayuda**: títulos arreglados (h0–h3 sobre b0–b3; fuera las claves viejas
      `h4`, `p1`–`p4`). Dos secciones nuevas:
      - **"Primeros pasos"**: los seis logros del tutorial en el orden del
        retail (275, 276, 284, 278, 277, 279). Los hechos llevan ✓ y el
        siguiente ▶, cada uno con cómo hacerlo aquí.
      - **"Reglas básicas"**: cinco reglas propias (es/en/fr).
- [x] **Intro de Adamai** la primera vez que se entra al lobby (escenarios 0 y
      1, 12 páginas). "Cerrar" la salta.
- [x] **Servicios → "Aprendizaje"**, el primer grupo: Baan, los 12 maestros de
      clase y el Demonio III, sacados de los mundos 85 y 35 sin viajar.
      - El maestro ofrece "Reclutar un guerrero", que abre la creación con su
        clase ya elegida.
      - El Demonio III solo ofrece el 30 tras el logro 280 y el 31 tras el 281.
- [x] **Monólogos** de los escenarios que abren los logros (280 → 105,
      281 → 106, 284 → 107, 278 → 115, 279 → 116, 454 → 118, 455 → 119). La
      lección de Baan (200 + 201, 10 páginas) sale antes de su combate.
      **Decisión:** en el retail los dos salían dentro del combate, con sus
      pasos (mover, lanzar Presión). Aquí son una lección previa: el cliente
      de combate no tiene enganches para guiar paso a paso, y el contenido es
      el mismo.
- [x] **"Entrenamiento" sin luchadores**: no lanza nada y dice dónde
      reclutar.
- [x] **Encontrado y arreglado:** el cliente no veía los contadores que solo
      mueve el servidor (211, 198–200) hasta el siguiente 2052, así que el
      Demonio III seguía sin ofrecer nada tras reclutar. Ahora, al llegar un
      22000, el cliente sube a su umbral los criterios de ese logro: es cierto
      por construcción, porque el servidor solo lo anuncia cuando se cumplen.

## Criterio de cierre

Una cuenta nueva recorre el tutorial de principio a fin (intro, reclutar tres,
la cadena del Demonio III con sus monólogos y su XP, Baan) en un smoke contra
un servidor real, con capturas.

## Resultado

Cerrado el 2026-10-22. Las decisiones están arriba; todas delegadas.

**El tutorial de una cuenta nueva, probado en dos mitades:**

- **Interfaz** (`godot -s test/tutorial_smoke.gd -- --as=<login nuevo>`,
  servidor real; la cuenta la crea el propio inicio de sesión): **10/10**.
  Cubre:
  - la intro de Adamai (8 + 4 páginas);
  - "Entrenamiento" sin luchadores, que no lanza nada;
  - "Primeros pasos" con el 275 como siguiente;
  - "Aprendizaje" con sus 14 personajes;
  - "Reclutar" de un maestro, que abre la creación con su clase;
  - el "Soy nuevo" de Baan, que marca el 219;
  - el Demonio III, tras los tres reclutas, ofreciendo solo el 29;
  - el monólogo del logro 280 (escenario 105);
  - la lección de Baan antes de su combate, que empieza (8000).

  Capturas revisadas: la intro, la Ayuda y Servicios.
- **Los combates** (`go test ./test/e2e -run TutorialChain`, por socket con
  los datos reales). Una cuenta nueva:
  - recluta tres (logro 276);
  - ve rechazado el 30;
  - gana el 29, el 30 y el 31 (logros 280, 281 y 284, 6 de XP);
  - gana el 46 de Baan (logro 446).

  Los combates se ganan con `/ENDFIGHT`, porque jugarlos desde el smoke de
  Godot recarga la escena principal y deja al smoke sin su instancia.

**Lo que no se hizo, y por qué:**

- **La XP de los desafíos no sale en la pantalla de resultado.** Se paga, pero
  los desafíos no tienen informe de combate por luchador (no pasan por el
  META); se ve en la ficha del luchador. El diálogo propio del retail
  (`fightResultEvolutionTuto/ChallengeDialog`) no se ha hecho.
- **La guía paso a paso dentro del combate de Baan** (escenarios 200/201 con
  sus disparadores): se cuenta antes del combate.
- **Las barras de menú y el equipo "tutorial"** que bloqueaban la interfaz:
  descartados (ver "Decisiones").
- **Escenarios sin disparador ni sitio en el lobby:** el 100 (mapa), el 102 y
  103 (presentaciones de la isla), el 104 (maestros) y el 108 y 109 (Zaap y
  mundo 37). Su contenido lo cubren "Primeros pasos" y los propios diálogos
  de los personajes.
- `docs/wiki/` no se usa (es de la 2.04).

**Revisión de los esbozos de detrás:** S11 (replays y espectador) pasa a
siguiente. Su decisión pendiente ("¿grabar como el retail o solo
espectador?") se toma al abrirlo, con la opción por defecto si no hay
motivo para otra.
