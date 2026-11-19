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

### Corrección de C (fase D, 2026-11-19): +4 PM, no +2

Los +2 PM "funcionaban" por un fallo: con 5 PM el primer turno,
`classifyAI` hacía del que abría un luchador "de huida" (umbral 4 PM), que
invocaba o pegaba y **se alejaba**. Arreglado (mira sus PM de base), y
medido otra vez (`S46_SIM=600`):

| PM extra | abriendo siempre | eligiendo (IA) |
|---|---|---|
| 0 | 0,27 | 0,75 |
| 1 | 0,24–0,30 | 0,73 |
| 2 | 0,23–0,27 | 0,74 |
| 3 | 0,23–0,27 | 0,74 |
| **4** | **0,57** | **0,51–0,56** |

Con +1..+3 el que abre sigue entrando en alcance sin llegar a golpear; con
+4 llega y pega primero. **Ahora +4**, y la IA cuenta esos PM al decidir:
abre casi siempre (ceder siempre da 0,43). La iniciativa vale unos 5 puntos.

## D. Clases contra clases (2026-11-19, en curso)

**Decisiones del dueño:** mandan **duelos y tríos**, las dos medias en
40–60 %; el Curandero sube con **curas más fuertes**; palancas: daño y
curas, PA/alcance/enfriamiento, vida de las clases, invocaciones.

**Simulación** (`S46_BREEDS=100 go test ./internal/game/ -run TestBreedSim`):
duelos (uno contra uno, las 66 parejas) y tríos (la clase + Iop + Arquero
contra el mismo par con la otra clase). Cada clase con su invocación más
cara, su primera cura y sus hechizos de daño, seis como mucho.
`S46_ONLY=4` mide solo las parejas de una clase; `S46_DROP=69` quita un
hechizo del kit.

**Dos arreglos de IA antes de medir nada** (lo que medía era la IA, no la
clase):

1. **La IA no invocaba nunca** (`ai_summon.go`): invoca su criatura más
   cara en la casilla libre más cercana al enemigo antes de atacar. Domador
   en tríos 0,17 → 0,58.
2. **La IA pegaba a la invocación más cercana**: el Arquero se pasaba doce
   turnos con el doble de 40 PV de la Sombra. Ahora prefiere un luchador de
   verdad (salvo para rematar) y camina hacia el luchador más cercano.

**Primera foto (sin tocar datos), media de duelos / tríos:**

| clase | duelos | tríos |
|---|---|---|
| Sombra (Sram) | 0,78 | 0,82 |
| Arquero (Crâ) | 0,65 | 0,64 |
| Domador (Osamodas) | 0,59 | 0,49 |
| Buscaoro (Enutrof) | 0,58 | 0,49 |
| Relojero (Xélor) | 0,57 | 0,59 |
| Furia (Sacrieur) | 0,55 | 0,48 |
| Bastión (Féca) | 0,53 | 0,61 |
| Espadachín (Iop) | 0,52 | 0,40 |
| Curandero (Eniripsa) | 0,43 | 0,08 |
| Panda (Pandawa) | 0,28 | 0,55 |
| Jardinero (Sadida) | 0,26 | 0,31 |
| Tahúr (Ecaflip) | 0,26 | 0,53 |

**El ajustador** (`TestBreedTune`, `S46_TUNE_WRITE=1` escribe los datos
medidos; con multiplicadores 1 los ficheros salen idénticos): un
multiplicador por clase de daño (curas en el Curandero, vida de las
criaturas en el Jardinero), redondeado como se guarda.

- **Con una palanca** hacia la media de las dos medidas se estanca en
  0,20–0,28 de la peor clase: la Sombra con el daño a ×0,5 (el tope) sigue
  en 0,66; el Jardinero con las muñecas a ×2,5 de vida sigue en 0,31; y
  varias clases tienen el duelo y el trío muy separados (Tahúr 0,22/0,51,
  Curandero con curas ×2,2: 0,63/0,34).
- **Con dos palancas** (daño y vida, por la matriz medida: el daño mueve el
  duelo el doble que el trío, la vida los dos igual) llega a extremos (Panda
  daño ×2,5 y vida ×0,6; Curandero curas ×0,4 y vida ×1,8). Lo paré: no es
  un diseño, es el ajuste persiguiendo el ruido.

**Conclusión:** con los números de daño solo se acerca la media; lo que
separa a las de los extremos es su mecánica: el doble de la Sombra (40 PV,
6 PA, sin plantilla: un segundo luchador), las muñecas del Jardinero (10–12
PV, quitan 1 PA), las curas frente al daño en un trío. Preguntas al dueño
antes de seguir. Los datos del juego **no han cambiado** en esta fase.

### Segunda tanda del dueño y el ajuste (2026-11-19)

**Decisiones:** el doble de la Sombra, **más flojo**; las muñecas del
Jardinero, **más fuertes**; **tríos estrictos 40–60, duelos 35–65**, solo
números.

**Cambios de mecánica (a mano):**

- **Doble sombra** (69) llama a una criatura propia, la 56 (15 PV, 6 PA,
  3 PM, placaje 20; antes, sin plantilla, 40 PV por defecto). Nombre
  `summon.56` en los tres idiomas.
- **Muñeca loca** (plantilla 4) 12 → 25 PV y su hechizo (107) quita 2 PA en
  vez de 1; **Muñeca mártir** (8) 10 → 20 PV.
- **Manecilla ardiente** (43, Relojero) alcance 2–6 → 2–5: el Relojero vive
  de ella y su daño salta de 0,38 a 0,65 en tríos entre 4 y 5 puntos; el
  alcance deja el punto medio (0,57).

**Otro fallo de IA, el que más pesaba:** el arreglo de `classifyAI` (ver
"Corrección de C"): con los PM extra del primer turno, todo el que abría
huía. Solo con eso el Curandero pasó de 0,08 a 0,37 en tríos.

**El ajuste** (`TestBreedTune`, `S46_TUNE_TRIO=1`: el trío a 0,5 y el
duelo solo si sale de 35–65; una palanca por clase, guardando la mejor
ronda porque el terreno va a saltos: un punto de daño cambia de cuántos
golpes cae alguien). Diez rondas con pasos largos y ocho de afinado desde
la mejor; luego el Jardinero y el Relojero a mano. Multiplicadores
finales, sobre los números originales (redondeados como se guardan):

| clase | palanca | × |
|---|---|---|
| Bastión (Féca) | daño | 0,67 |
| Domador (Osamodas) | daño | 1,38 |
| Buscaoro (Enutrof) | daño | 0,99 |
| Sombra (Sram) | daño | 0,59 |
| Relojero (Xélor) | daño | 0,77 (+ Manecilla 2–5) |
| Tahúr (Ecaflip) | daño | 1,09 |
| Curandero (Eniripsa) | curas | 1,78 |
| Espadachín (Iop) | daño | 0,77 |
| Arquero (Crâ) | daño | 0,75 |
| Jardinero (Sadida) | daño ×1,45, criaturas vida ×2 (sobre lo de arriba) |
| Furia (Sacrieur) | daño | 0,87 |
| Panda (Pandawa) | daño | 0,87 |

Cambian 44 hechizos y 4 criaturas (`spells.json`, `summonings.json`); la
vida de las clases no se tocó.

**Comprobado aparte** (`S46_BREEDS=200 go test ./internal/game/ -run
TestBreedSim`, semillas nuevas, sobre los datos guardados):

| clase | duelos antes → ahora | tríos antes → ahora |
|---|---|---|
| Bastión | 0,53 → 0,31 | 0,61 → 0,56 |
| Domador | 0,59 → 0,51 | 0,49 → 0,46 |
| Buscaoro | 0,58 → 0,70 | 0,49 → 0,47 |
| Sombra | 0,78 → 0,77 | 0,82 → 0,45 |
| Relojero | 0,57 → 0,22 | 0,59 → 0,58 |
| Tahúr | 0,26 → 0,39 | 0,53 → 0,42 |
| Curandero | 0,43 → 0,65 | 0,08 → 0,49 |
| Espadachín | 0,52 → 0,38 | 0,40 → 0,59 |
| Arquero | 0,65 → 0,51 | 0,64 → 0,48 |
| Jardinero | 0,26 → 0,68 | 0,31 → 0,42 |
| Furia | 0,55 → 0,60 | 0,48 → 0,53 |
| Panda | 0,28 → 0,28 | 0,55 → 0,54 |

("antes" es la primera foto, con las dos primeras correcciones de IA pero
aún con el fallo de huida.)

**Tríos: las 12 entre 0,42 y 0,59. ✅** **Duelos: 7 fuera de 35–65**
(Sombra 0,77, Buscaoro 0,70, Jardinero 0,68, Curandero 0,65 al borde;
Bastión 0,31, Panda 0,28, Relojero 0,22). Con una palanca por clase el
trío manda; separar el duelo del trío pide mecánica (lo que una clase hace
sola frente a lo que hace con dos compañeros), o la vida y el daño en
sentidos contrarios, que llevaba a extremos. **Pregunta al dueño.**

Pendiente de la fase C: las cartas de iniciativa (88, 89, 162, 164) ahora
solo deciden quién elige, así que +30 y +80 valen lo mismo; su precio
debería ser plano o la iniciativa dar algo más.
