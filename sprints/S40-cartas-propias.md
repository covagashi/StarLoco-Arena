# S40 — Cartas propias (datos)

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🟡 abierto (2026-11-14)

## Decisión del dueño (2026-10-25)

"Solo arte y después cartas, y después texto." Este sprint es el segundo
paso: las cartas dejan de ser las del retail.

## Alcance a decidir al planificarlo

- Diseño propio de las cartas de equipo (coach y luchador), las de evento y
  las especiales: qué hacen, sus valores, sets y rarezas, sin pagar para
  ganar (S28).
- ¿Hechizos y clases también, o solo las cartas? ¿Y la topología de las
  arenas?
- Dónde viven los datos nuevos: fuera de `data.bdat` (formato propio,
  editable en el studio), y cómo se migran los inventarios de los jugadores.
- El arte de carta de S38 ya pensado para esta lista nueva.

## Criterio de cierre

El servidor no lee ninguna carta de `data-dist/`; las partidas siguen
equilibradas (simulaciones IA contra IA, como S29).

## Decisiones del dueño (2026-11-14)

| Pregunta | Respuesta |
|---|---|
| Camino | **A**: el mismo esquema, datos nuestros, los mismos ids |
| Alcance | **Solo cartas.** Los hechizos van en su propio sprint ([S46](./S46-hechizos-propios.md)) |
| Cuántas cartas | **No se recorta**: entran las 907 |
| Economía | **Sí se toca**: "Dofus Arena murió por mucho pay to win, así que necesitamos balancear o replantear" |
| Licencia de los datos | **Todos los derechos reservados**, junto al servidor: `server/content/` con su propio `LICENSE`, como `godot/`. El código del servidor sigue siendo MIT |

Las rarezas de S38b (negra, cobre, plata y oro por `Card.Rank`) se quedan
como punto de partida (heurística: los marcos ya las usan); el paso 2 decide
qué significan.

### Qué quiere decir "balancear o replantear"

S28 ya quitó el pago con dinero real: las cartas solo se ganan jugando y las
pesetas solo compran cosméticos. Lo que mató a Dofus Arena va más allá del
dinero: las cartas raras eran **más fuertes**, así que quien tenía más (por
pagar o por llevar más tiempo) ganaba antes de empezar. El paso 2 lo ataca
por tres lados, y cada uno se prueba con simulaciones IA contra IA:
- **Potencia por coste, no por rareza.** Cada carta con un presupuesto de
  potencia; una carta rara es distinta (otra forma de jugar), no mejor.
- **Un tope por equipo.** Que el equipo tenga un coste máximo por liga, para
  que un coach nuevo con cartas comunes pueda plantar cara.
- **El ritmo de conseguirlas.** Cuántas victorias cuesta cada carta (fichas,
  trueque, sobres), medido con los datos de S28.

## Propuesta para planificarlo (2026-11-14, aprobada: camino A)

Escrita de noche con el dueño dormido; **no se ha empezado nada**: son
decisiones suyas.

**Qué hay hoy.** `gamedata.Bundle` (server/internal/gamedata/bundle.go) lee
de `data-dist/data.bdat` 17 tablas retail: cartas (907 plantillas en 138
sets; 735 intercambiables, 143 con precio), hechizos, cartas de luchador
(75), invocaciones, efectos estáticos, desafíos, eventos, sets, logros,
condiciones, altares de fusión, bonos de mapa, la tabla de sobres, torneos,
tableros de esferas y repartos de equipo. El cliente lee lo mismo ya
exportado (`assets/gamedata/*.json`, local, fuera de git). El studio
(`server/cmd/studio`) ya sabe abrir y editar esas tablas.

**Dos caminos.**
- **A. El mismo esquema, datos nuestros (recomendado).** Paso 1: un formato
  propio (JSON o TOML versionado en el repo, p. ej.
  `server/content/cards/*.json`), un cargador que lo lee en lugar del
  `.bdat`, y una prueba de paridad (los datos exportados hoy dan el mismo
  juego). Los ids no cambian, así que los inventarios no se migran. Paso 2:
  rediseñar set a set (nombres, valores, efectos, rarezas) con simulaciones
  IA contra IA (S29) para que el combate siga equilibrado, y sin pagar para
  ganar (S28). Paso 3: los textos (S41) sobre los mismos ids.
- **B. Catálogo nuevo desde cero.** Ids nuevos, menos cartas y más claras,
  y una tabla de conversión para los inventarios existentes. Más limpio,
  pero rompe todo a la vez (tienda, sobres, logros que piden cartas,
  torneos que piden una carta de entrada) y cuesta mucho más probarlo.

**Lo que el dueño tiene que decidir:**
1. Camino A o B.
2. Alcance: ¿solo cartas (coach, luchador, evento, especiales) o también
   hechizos y clases? Mi recomendación: solo cartas en S40; hechizos y
   clases, en otro sprint, porque están atados a las 12 clases 3D y a los
   VFX de S37.
3. Cuántas cartas quiere en la 1.0 (hoy 907; muchas son variantes de un
   mismo set) y si las rarezas de S38b (negra, cobre, plata y oro por el
   rango retail) se quedan como regla de diseño.
4. ¿Se puede tocar la economía (precios en fichas, valores de trueque) o
   solo el contenido?

## Hecho

### Paso 1: las cartas son datos nuestros (2026-11-14)

- `server/content/` (todos los derechos reservados, su `LICENSE`; el `.go`
  que los embebe es MIT): `cards/coach/set_<id>.json` (las 907 cartas de
  coach, un fichero por set), `sets.json` (138 sets), `fighter.json` (75
  cartas de luchador) y `events.json` (51 eventos). Una carta por línea, para
  que el rediseño se vea carta a carta en el diff. 788 KB.
- `gamedata.LoadCardContent` los lee (un campo mal escrito o una carta en dos
  sets es un error); `LoadBundle` toma de ahí las cuatro tablas, el precio en
  fichas de S28 y la tabla de sobres, **sin `data.bdat`**.
- `cmd/exportcards` hizo la conversión (de un solo uso; se va con
  `data-dist` en S43). Los `dump*` que generan el JSON del cliente leen las
  cartas de `content`: su salida es **idéntica byte a byte** a la de antes
  (cards, fusionlabs, fightercards, effects, npcdialogs).
- Pruebas: `TestCardContentParity` (cada registro igual al retail, hasta que
  el rediseño cambie cartas a propósito: entonces se retira set a set),
  `TestCardContentRoundTrip`, `TestBundleCardsWithoutRetailData` (el
  servidor sin ningún `.bdat` tiene las 907 cartas, precios y sobres).
  `go test ./...` en verde (el e2e arranca con `LoadBundle`, así que ya juega
  con estas cartas).

### Pendiente del paso 1

- ~~El studio~~ **hecho (2026-11-14):** lee las cartas de
  `server/content/cards` (las busca desde el checkout, sin necesitar el
  `.bdat`; fuera de un checkout enseña las embebidas, solo lectura) y el panel
  lateral de cada carta trae un formulario para editarla. Coach: valor, rango
  (0–10), precio, nivel requerido, sobres y peso de tirada, ligada,
  indestructible. Luchador: valor, PA y alcance del arma. Los efectos no se
  tocan aquí (eso es el rediseño del paso 2). Se valida en Go, y una edición
  mala no cambia nada; al guardar solo cambia el fichero del set de esa carta
  (reescribir el contenido sin cambios da los mismos bytes). Pruebas en
  `cmd/studio/cardedit_test.go`; la interfaz, en Chromium con un backend
  simulado: guarda, enseña el error y edita un luchador, sin errores de
  página. Wails no está instalado en la Ally, así que la ventana de escritorio
  no se ha abierto.
- El **cliente** lee el JSON derivado (`assets/gamedata/cards.json`, local);
  puede leer `server/content/` directamente, como ya hace con las arenas.

### Paso 2: decisiones del dueño (2026-11-14, por preguntas)

| Pregunta | Respuesta |
|---|---|
| Qué es una carta rara | **Distinta, no mejor**: otra forma de jugar con la misma potencia que una común de su coste |
| Tope por equipo | **Sí, por liga**: presupuesto pequeño en las ligas bajas, que crece al subir |
| Novatos frente a veteranos | **Desbloquear cartas jugando combates**; lo desbloqueado da variedad, no potencia |
| Sobres | **Se quedan, con garantía**: las repetidas se convierten en fichas y cada cierto número de sobres sale una rara seguro |
| Ligas del presupuesto | **Tramos de Elo** (bronce, plata, oro, platino, diamante); el presupuesto sube con la liga y se reinicia en parte con la temporada (S25) |
| Presupuesto de la liga más baja | **4.000**, unos +500 por liga hasta el 6.000 de hoy (`maxTeamBudget`, el tope del cliente retail) |
| Desbloqueo jugando | **Cada X victorias eliges 1 carta entre 3**, sin repetidas; rápido al principio, más lento después |
| Garantía de los sobres | **Una rara cada 10 sobres** |
| Inventarios existentes | **Se quedan**: las cartas cambian de valores para todos a la vez (mismos ids, sin migrar) |
| Ritmo del desbloqueo | **Cada 3 victorias** las 10 primeras elecciones, **luego cada 5** |
| Equipo inicial | **Lo justo**: luchadores sin equipo, todo se gana jugando (el dueño descartó mi propuesta de un equipo básico) |
| Repetidas de sobre | **Fichas según su rareza** (p. ej. común 5, rara 50) |

**Orden de trabajo (heurística):** 1) medir: potencia de cada carta frente a
su rango, precio y valor, y cuánto cuesta hoy en victorias; 2) presupuesto por
liga de Elo (4.000 en bronce, +500 por liga) en `roster_rules.go`;
3) desbloqueo de 1 entre 3 cada 3/5 victorias; 4) garantía de rara cada 10
sobres y repetidas a fichas; 5) igualar la potencia por coste set a set
(raras distintas, no mejores), con simulaciones IA contra IA.

### Paso 2: rebalanceo contra el pay to win

Visto al hacer el paso 1: el retail ya tiene un **presupuesto de equipo**
(`ParamTypeBudget`, "Modifie le budget", en `parameters.go`), que es el tope
por equipo de arriba. Antes de rediseñar, medir: potencia de cada carta frente
a su rareza y su precio, y cuántas victorias cuesta cada una.

### Paso 2.1: la medición (2026-11-14)

`go run ./cmd/cardreport` (en `server/`) mide las cartas de `content`. Lo que
dice, con lo que hace hoy el servidor (leído en el código):

- **Solo las 75 cartas de luchador actúan en combate.** Su `Value` es lo que
  cuestan en el presupuesto (600 de base por luchador, 6 luchadores como mucho,
  6.000 por equipo). **Ya están bien pagadas:** el valor sigue a lo que dan con
  R² = 0,87 (precio implícito: 1 PA ≈ 194, 1 PM ≈ 238, 1 de alcance ≈ 191,
  1 PV ≈ 8, 1 % de daño ≈ 3,5, 1 de daño por PA del arma ≈ 74). Hay unas pocas
  desviadas en ±50–100 (armas de 100 que valen ~150; cartas de solo iniciativa
  que cuestan 50 y no dan casi nada).
- **Las 907 cartas de coach no actúan en combate**: XP, heridas, muerte,
  moral, fatiga, botín y resurrección, todo después del combate. Solo las de
  "aplicar condición" (acción 15, consumibles de Historia) llegan al combate
  por sus condiciones. **Aquí sí manda la rareza:** XP % 2–5 en rangos 0–4
  y 40–50 en rangos 7–10; resurrección del 100 % desde el rango 6; menos
  heridas y muerte al subir de rango. Es el patrón "rara = mejor" que hay que
  quitar, y es progresión (quien tiene raras sube a sus luchadores más rápido).
- **No hay sobres.** Las cartas al azar salen del botín después de cada
  combate (`rollFightDrops`, por `ObtainableInDraw`/`DropPercent`) o se
  compran una a una. Una victoria de Ranking da 50 fichas; las raras (rango
  9–10) cuestan una mediana de 20–30 victorias.
- **Choques con lo decidido:** un equipo completo sin equipo ya cuesta 3.600,
  así que con 4.000 en bronce quedan 400 para equipo; y Evolución exige un
  mínimo de 5.000 (`minEvolutionTeamBudget`), por encima del tope de bronce.
- De paso: el comentario de `computeFighterBudget` dice base 400 y el código
  usa 600.
