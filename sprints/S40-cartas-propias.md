# S40 — Cartas propias (datos)

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** ⚪ esbozo (después del arte, S33–S39)

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

## Propuesta para planificarlo (2026-11-14, a decidir con el dueño)

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
