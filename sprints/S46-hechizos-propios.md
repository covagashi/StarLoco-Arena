# S46 — Hechizos propios (datos)

**Planificado:** 2026-11-14 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (2026-11-19)

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

## Adelantado la noche del 2026-11-15 (el dueño dormía)

Lo que no necesitaba decisiones de diseño y hacía falta antes de medir
nada (de "Llega de S40"):

- **La IA juega el ataque de su arma.** `aiWeaponOverSpell` lo pone a
  competir con el hechizo con la misma regla que entre hechizos (rematar
  primero, luego daño por PA; en empate, el hechizo); `weaponAI` lo usa el
  luchador sin hechizo de daño (bloqueador, el que se refuerza) antes del
  golpe genérico. La estimación cuenta solo los efectos que ese objetivo
  recibe. Pruebas: `TestAIBlockerUsesItsWeapon`, `TestAIWeaponNeedsRange`,
  `TestAIWeaponVersusSpell`.
- **B-190, un fallo de combate que la IA destapó:** un efecto de un solo
  objetivo no miraba su propia máscara de objetivos. El arma 34 lleva un
  efecto de 8 por cada clase de objetivo y pegaba los catorce (112); los
  hechizos 30 y 443 ponían en el enemigo el extra que es del lanzador.
  Arreglado en `areaFightersFrom` (`server/docs/BUGS.md`).
- **Las armas, medidas por fin** (`S40_SIM=200`, solo las 23 armas, una en
  el Iop contra el espejo desnudo; espejo 0,51):

  | | antes (solo el puñetazo) | IA con armas, sin B-190 | IA con armas, con B-190 |
  |---|---|---|---|
  | arma 34 (valor 100) | 0,49 | **0,92** | 0,53 |
  | el resto (22) | 0,45–0,55 | 0,43–0,55 | 0,46–0,54 |
  | correlación ventaja/valor | r = 0,27 | r = −0,06 | r = −0,04 |

  **Conclusión:** con la IA usándolas, un arma en un luchador apenas mueve
  el resultado (±4 puntos) y su valor no lo predice: los hechizos rinden más
  por PA que el ataque del arma. Es un dato para el rediseño de este sprint
  (¿las armas deberían pesar más, o costar menos?), no algo que cambiar
  sin el dueño.

## Para planificarlo con el dueño (preguntas)

1. **¿Qué se rediseña?** a) solo números (daño, PA, alcance, enfriamiento)
   de los 203 hechizos que hay; b) además algunos hechizos nuevos o
   cambiados por clase; c) desde cero.
2. **¿Entran las clases** (vida, PA, PM, iniciativa de cada luchador)?
3. **Mover segundo da ventaja** (iniciativa alta = 14–25 % de victorias):
   ¿casillas de salida más lejos, o que la iniciativa dé otra cosa?
4. **Armas:** pesan poco frente a los hechizos (arriba). ¿Más daño, menos
   PA, o se quedan como bonus pasivos con un ataque de apoyo?

## Decisiones del dueño (2026-11-19)

1. **Solo números** de los 203 hechizos (daño, PA, alcance, enfriamiento):
   mismos ids, así las recetas de VFX (S37), los sonidos (S39) y las cartas
   `@spell:<id>` siguen valiendo.
2. **Las clases entran** (vida, PA, PM, iniciativa, placaje): salen de
   `breed.go` y del `BREED_STATS` del cliente a `server/content/rules/`.
3. **Iniciativa: el que la gana elige turno** (empezar o ceder). La IA elige
   lo que le conviene.
4. **Armas: 1 PA menos**, mismo daño.

## Plan (2026-11-19)

- **A. Clases a datos.** `server/content/rules/breeds.json`, leído por
  `gamedata`; `exportclient` lo lleva a `godot/assets/content/`, y el
  cliente deja su `BREED_STATS` copiado a mano. Mismos valores: ninguna
  prueba cambia.
- **B. Armas −1 PA**, y se vuelven a medir con `S40_SIM` (la tabla de
  arriba).
- **C. Elegir turno.** Orden de equipo contra equipo; el equipo con más
  iniciativa decide en la colocación si abre o cede (botón; si no decide,
  abre). La IA y los fantasmas deciden solos.
- **D. Clases contra clases.** Simulación nueva (cada clase contra cada
  clase, espejos de equipo), y se tocan números de hechizos y clases hasta
  que ninguna se salga del 40–60 %.

## B. Armas −1 PA (2026-11-19) ✅

Las 23 armas cuestan 1 PA menos (`server/content/cards/fighter.json`; las
de 3 PA a 2, las de 6 a 5). Medidas igual que antes (`S40_SIM=200`, una en
el Iop contra el espejo desnudo; espejo 0,52):

| | 1 PA más (antes) | 1 PA menos |
|---|---|---|
| el arma 34 | 0,53 | 0,52 |
| las 23 | 0,46–0,54 | 0,47–0,57 |
| correlación ventaja/valor | r = −0,04 | r = −0,03 |

**Por qué apenas se mueven:** con el PA de menos, un arma da 3–4 de daño
por PA (6–8 por 2 PA, 10 por 3), lo mismo que los hechizos de daño de las
clases (Iop 3,3; Sacrificado hasta 9 con el 409). La IA ya las elige cuando
rinden más y ahora lo hace más a menudo (el 2 sube a 0,57), pero un arma es
una opción más, no un extra que gane solo. Su valor sigue sin predecir la
ventaja: eso se ajusta en la fase D, con las clases.

Iniciativa, de paso (sin cambiar aún): −30 a los tres 0,72; +30 0,16; +60
0,28; +80 0,27. Mover segundo pesa todavía más que en S40: es la fase C.

## C. Elegir turno (2026-11-19) ✅

**Decisión del dueño, segunda tanda:** con las salidas actuales el que abre
pierde (0,27–0,30 en el espejo: entra primero en alcance), así que con "el
que gana elige" la iniciativa ganaba 7 de cada 10. El dueño: **+PM al que
abre** en su primer turno.

**Reglas nuevas** (`server/internal/game/turn_choice.go`):

- Los turnos **alternan equipo a equipo**, cada equipo en su orden de
  iniciativa (antes, una sola lista por iniciativa: un equipo rápido jugaba
  sus tres seguidos). Si un equipo tiene más luchadores, los que sobran van
  al final.
- **Elige** el equipo con más iniciativa (la suma de sus luchadores;
  empate: el luchador más rápido; luego el lado 0). Por defecto abre.
- El humano elige en la colocación con un botón encima de Listo ("Ceder el
  turno" / "Empezar yo"); la línea de ayuda dice quién elige y quién empieza.
  La IA y los fantasmas eligen al acabar la colocación: abren solo si ya
  llegan a golpear con su paso y su alcance; si no, ceden.
- **El que abre camina +2 PM** en su primer turno (no las invocaciones).
- Opcodes propios: 60050 C2S `[u8 open]`, 60051 S2C `[u8 elige][u8 abre]
  [u8 PM extra][u8 n]{[i64 luchador]}` (tras el 8000, tras cada elección y al
  acabar la colocación; las repeticiones lo graban).

**Medido** (`S46_SIM=600 go test ./internal/game/ -run TestTurnChoiceSim`,
el lado con +30 de iniciativa en los tres elige, contra el espejo desnudo):

| PM extra al que abre | abriendo siempre | eligiendo (IA) |
|---|---|---|
| 0 | 0,26 | 0,74 |
| 1 | 0,39 | 0,62 |
| **2 (elegido)** | **0,45** | **0,54** |
| 3 | 0,49 | 0,47 |
| 4 | 0,50 | 0,53 |

Con +2 la iniciativa vale unos 5 puntos (lo que una buena carta) y abrir ya
no es perder. Con +3 y +4 el ruido tapa la diferencia; +2 cambia menos el
primer turno (5 PM en vez de 3). **Probé que la IA contara los PM extra**
al decidir: abría más y ganaba menos (0,47 contra 0,58 cediendo siempre):
llegar no es ganar el intercambio. Se quedó la regla simple.

**Pruebas:** `turn_choice_test.go` (orden alterno, equipos desiguales,
empate, la elección solo del lado que elige y solo en colocación, PM extra
solo al primer turno del que abre y nunca a una invocación, la IA cede
fuera de alcance y abre en alcance). `fight_smoke` en las dos ramas
(`godot/tools/no_retail_smoke.sh`, y con `SMOKE_ARGS=--challenge=24`): el
rival elige y nos cede (abrimos con 5 PM en la barra); elegimos nosotros,
pulsamos "Ceder" y el orden pasa al rival, que abre con 5 PM.

## D. Clases contra clases — siguiente

Las cartas de iniciativa (88, 89, 162, 164) se miden otra vez en la fase D:
ahora la iniciativa solo decide quién elige, así que +30 y +80 valen lo
mismo; su precio debería ser plano o la iniciativa dar algo más.
