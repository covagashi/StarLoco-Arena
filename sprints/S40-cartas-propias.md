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

- El **studio** aún edita las cartas en el `.bdat`; tiene que editar
  `server/content/`.
- El **cliente** lee el JSON derivado (`assets/gamedata/cards.json`, local);
  puede leer `server/content/` directamente, como ya hace con las arenas.

### Paso 2 (siguiente): rebalanceo contra el pay to win

Visto al hacer el paso 1: el retail ya tiene un **presupuesto de equipo**
(`ParamTypeBudget`, "Modifie le budget", en `parameters.go`), que es el tope
por equipo de arriba. Antes de rediseñar, medir: potencia de cada carta frente
a su rareza y su precio, y cuántas victorias cuesta cada una.
