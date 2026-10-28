# S36 — Arenas: todos los assets primero, y un editor para que el dueño monte los mapas

**Planificado:** 2026-10-25 · **Abierto:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (fase B: bioma nieve aprobado)

## Por qué cambia el plan (dueño, 2026-10-25)

> "Ni siquiera arena-plan-1 está actualizado. Creo que será mejor si primero
> pasas todo y creas los assets y creas las texturas, y luego haces algo para
> que yo pueda hacer los mapas. Dejas el 'shape' del mapa, pero luego yo
> posiciono los assets."

Ese día se intentó montar la arena 1 entera de forma automática, colocando
nuestros modelos en las coordenadas de los sprites retail
(`tools/art/build_arena.gd`). Salió mal:

- Los bloques quedaban unos 70 px más altos que los retail.
- Las columnas apiladas repetían la franja oscura de la base.
- Faltaban los tintes por celda.
- La hoja `arena1-plan.png` no reflejaba lo hecho.

**Conclusión: la máquina no coloca. Se hacen todos los assets, y el dueño
coloca en un editor.**

## Lo que ya hay (de S33)

- Criba del dueño por gfx en `~/codigo/m7-referencias/gfx_rules.json`:
  - `drop`: lo que no es un asset.
  - `vfx`: va a S37, no a la decoración.
  - `replace`: 155 y 156 → 154.
  - `family_merge` / `family_split`: correcciones a las familias.
- Catálogo de familias en `~/codigo/capturas/m7/catalogo/` (`catalog.py`):
  64 familias, 177 gfx en familias, 964 piezas sueltas y 49 comunes
  (salen en 8 arenas o más).
- Técnica decidida: **kiln** (3D) con texturas **loom**.
  - Aprobados: `ice_block` y `tree` (`godot/art/arena1/`).
  - A revisar: `ice_clear` (bloque transparente).
- Las variantes de color van como **un modelo y un tinte**. El retail ya lo
  hace así: cada sprite lleva un `c` multiplicador, y la nieve lila es el
  bloque blanco teñido.
- La arena 1 es el mundo retail 5. El arte vive en `godot/art/arena1/`.

## Tres looms por pieza (dueño, 2026-10-25)

> "Pasa los assets a kiln, y en la herramienta que tú hagas yo podré poner 3
> diferentes tipos de loom."

- Cada pieza se exporta en tres looms: `<nombre>` (a), `<nombre>_b` y
  `<nombre>_c`.
  - Es el mismo modelo kiln con todos los materiales de textura cambiados
    (`base` + `swap`).
  - Las texturas de cada loom son loom.
- En el editor (fase C), al colocar una pieza se elige a, b o c.
- Las variantes de color del retail (las familias del catálogo y el tinte
  lila) pasan a ser looms.

## Mapa por mapa (dueño, 2026-10-25)

> "Vamos mapa por mapa rellenando los assets; recuerda reutilizar lo que ya
> tenemos."

Se descarta hacer los seis biomas de golpe con agentes: modelaban a partir
de lo que creían que era cada dibujo retail y se equivocaban (la 160 era la
puerta 166 con nieve, no unas setas). Sus carpetas (`godot/art/{lava,
pradera,ruinas,playa,fortaleza,cueva}/`) quedan sin subir y sin revisar.

Proceso, por arena:
1. `map_sheet.py <mundo> <arena>` (fuera del repo) genera
   `~/codigo/capturas/m7/mapa-arenaN.png`. Lleva las piezas retail del mapa
   ya cribadas, numeradas por uso, cada una con lo que es:
   - el nombre que dio el dueño, o mi suposición marcada con "¿?";
   - si ya la tenemos (por gfx, o por familia: misma forma con otro loom),
     junto a nuestra pieza; si no, NUEVO.
2. El dueño corrige qué es cada pieza. Sus nombres se guardan en
   `names.json` y mandan sobre los míos.
3. Se modelan solo las piezas nuevas, siguiendo las skills kiln y loom, y
   se enseñan.

Numeración: arena N es el N-ésimo mundo por id (arena 1 = mundo 5, arena 2
= mundo 10, arena 3 = mundo 12…).

### Arena 2 (mundo 10, otoño y lava), 2026-10-25

El dueño confirmó todas las suposiciones de `mapa-arena2.png`; la 138 y la
141 son la escarcha (la misma forma en verde).

- Kit `godot/art/arena2/` con 19 piezas en tres looms:
  - suelo: bloque de roca marrón (+ columna), losa verde, charco de lava;
  - plantas: arbusto otoñal, arbusto alto, árbol otoñal, árbol sin hojas,
    hojas caídas, hierba;
  - piedra: columna de roca, rocas verdes, roca con lava, tótem, tótem alto,
    piedras blancas;
  - armas: armas en el suelo, espada, lanza y hoja clavadas.
- Loom en las superficies grandes (roca, losa, lava, tótem), hechas con las
  reglas de la skill; colores de paleta con 2–3 tonos en plantas y armas.
- El follaje son hojas de arce de cinco lóbulos sobre un núcleo oscuro. La
  primera versión eran bolas lisas, y la segunda parecía de estrellas.
- Se reutiliza del kit de la arena 1: piedra tallada, piedrecitas, losa con
  glifo, runa y farol. Además, el cordón de la escarcha en verde
  (`grass_drift`, tres looms verdes).
- `mapa-arena2.png`: las 52 piezas del mapa cubiertas (0 nuevas). Hoja del
  kit: `kit-arena2.png`.
- Tótems rehechos (dueño, 2026-10-27: "cambia solo los tótems"). Eran
  cajitas de medio metro con cuatro marcas; ahora son cabezas redondeadas de
  casi una casilla, apiladas sobre cuellos oscuros, con las espirales en
  relieve claro en las dos caras que ve la cámara, ojos oscuros bajo una
  ceja clara, mandíbula saliente en el corto, cuernos de carnero en el alto
  y hierba en cada junta. Las cabezas son cinco prismas apilados con las
  tapas metidas (`pillow`), que a escala de juego leen como redondeadas.
  Hoja: `totems-arena2.png`. Dueño (2026-10-27): "ya quedan mejor".
- Las hojas ya no son una tira larga (dueño, 2026-10-27: "no hagas una
  imagen infinita, pierde demasiada calidad"). `kit_sheet.py` saca páginas
  que caben en la pantalla de la Ally (`kit-arena2-1.png` … `-10.png`), y
  `kit_shots.gd` no aleja la cámara en las piezas altas: la foto crece.

### Arenas 3, 4 y 5, 2026-10-27

- Las hojas de mapa ya no son tiras largas. `map_sheet.py` saca páginas que
  caben en la pantalla de la Ally: la primera es el mapa recortado a su
  bloque principal, y las siguientes llevan las piezas en dos columnas, con
  el sprite retail y nuestra foto casi a tamaño real.
- Arena 3 (mundo 12, nieve): 32 piezas, todas cubiertas por el kit de la
  arena 1. No hay nada que modelar. Hoja: `mapa-arena3-1.png` … `-5.png`.
- Arena 4 (mundo 15, nieve): 29 piezas, 1 nueva, la 150 (mi suposición:
  tronco seco nevado). Hoja: `mapa-arena4-1.png` … `-5.png`.
- Arena 5 (mundo 21, pradera): 74 piezas, 51 nuevas. Todas llevan mi
  suposición con "¿?" en `names.json` para que el dueño las corrija. Hoja:
  `mapa-arena5-1.png` … `-11.png`.
  - La 461 (nube de luz) parece VFX: si el dueño lo confirma, va a
    `gfx_rules.json` y a S37.
- Siguiente: el dueño corrige los nombres de la 150 y de la arena 5; luego
  se modelan, una pieza cada vez.

### Correcciones del dueño a las arenas 3–5, 2026-10-27

- Nombres guardados en `names.json` (mandan sobre los míos). El resto de
  suposiciones de la arena 5 las dio por buenas.
- Kit de nieve (`godot/art/arena1/`), rehecho o nuevo:
  - Nieve suelta (504): bolas pequeñas y bien separadas por la casilla.
  - Piedrecitas (163): ocho piedras planas repartidas, cada una con su
    gorro de nieve, más grandes que antes.
  - La 166 no es una puerta de piedra: "dos palos de madera con uno arriba,
    como si fuera el trozo de una valla". `stone_gate` pasa a
    `fence_piece` (dos postes cuadrados, travesaño y cuerda en las juntas),
    con los looms de madera; la 160 es la misma con nieve
    (`fence_piece_snow`).
  - La 513 no es una runa: es una rejilla metálica, la trampa típica. Pieza
    nueva `grate` (placa con 3×3 agujeros y marco), looms acero/óxido/bronce.
  - La 150 es un árbol seco sin hojas: pieza nueva `dead_tree` (tronco
    pálido abierto, ramas retorcidas), looms de corteza pálida/gris/oscura.
- Con eso la arena 4 queda cubierta del todo.
- Arena 5, nombres del dueño: 315, 316 y 317 son el mismo bloque de hierba;
  1199 y 1355, hierba de esquina; 1754 hierba mediana y 1755 más pequeña;
  179 y 181, la pared del edificio con canal de madera para el agua (dos
  alturas), que va con el tejado 178; 193, 194, 195, 197 y 223, paredes de
  la casa; 214, 215 y 216, ladrillos sueltos de decoración.
- Hoja de los cambios: `cambios-nieve-1.png` … `-3.png`.

### Arena 5 (mundo 21, pradera), 2026-10-27

Kit nuevo en `godot/art/arena5/` (texturas `kit.tx.js`, modelos `kit.kx.js`,
manifiesto `kit.json` con lo que reutiliza de las arenas 1 y 2). Una pieza
cada vez, empezando por la más usada.

- Bloque de hierba (315, 316, 317; el dueño: "es el mismo bloque").
  - Cuerpo de tierra con estratos ondulados (textura loom `soil`: arena
    ocre, tierra oscura, arcilla roja), un borde ondulado de tierra oscura
    bajo la hierba, un cojín de hierba encima (textura loom `grass`: manto
    denso de briznas, sin tierra a la vista) y, en cada lado, bultos de
    hierba que asoman por el borde con briznas colgando.
  - Looms: verde fresco (el retail), verde prado, seco dorado.
  - Columna `soil_col` de 1 m para apilar debajo; los estratos siguen de una
    a otra.
  - Hojas: `arena5-hierba.png` (la pieza) y `arena5-hierba-prado.png`
    (6×6 a escala real del juego).
  - Dueño (2026-10-27): la cuadrícula se tiene que ver, cada casilla como
    el bloque suelto y no como un prado continuo. La hierba sube en cúpula
    desde un borde bajo, con hierba más oscura al pie (`grassRim`) y los
    bultos del borde en un verde medio (`grassMid`). Se probó un borde ancho
    (tablero de cojines, demasiado) y sin borde (prado, se pierde); queda una
    línea fina, como en el retail. Hoja: `arena5-hierba-prado.png`.
  - Dueño: sí a la hierba sobre otros bloques. Pieza nueva `grass_cap`
    (tipo `cap` en `kit.json`: va encima del bloque de otra pieza, y = 0 es
    su cara de arriba, el borde de tierra cuelga por sus lados). El bloque y
    la capa comparten la misma parte de arriba (`grassTop`). Hoja:
    `arena5-hierba-sobre-piedra.png` (con un bloque gris de prueba, no se
    sube).
- Bloque de tierra (233), 2026-10-28.
  - Cuerpo con la misma textura de estratos que el bloque de hierba, y una
    franja de tierra apelmazada oscura arriba, con la cara de arriba de
    bordes gastados. La primera versión usaba la textura de estratos también
    arriba (parecía madera) y la franja sobresalía como una tapa.
  - Textura loom nueva `earth`: tierra pisada sin estratos, piedrecitas
    clavadas, grietas finas y polvo en lo alto. Looms: arena ocre, tierra
    oscura, arcilla roja (los de `soil`).
  - En el mapa retail el 233 va casi siempre teñido de azul, y por eso se
    ve gris bajo la hierba: ese gris es el tinte del editor, no un loom.
  - Hojas: `arena5-tierra.png` y `arena5-tierra-prado.png` (mezclado con
    hierba, a escala real).
- Hierba de esquina (1199, 1355), 2026-10-28.
  - En el mapa retail es la hierba que cuelga por el lado de un bloque
    donde el mapa acaba o baja: la 1199 por la cara izquierda y la 1355 por
    la derecha, la misma pieza girada. Sale 65 veces, siempre en bordes.
  - `grass_edge`: una cortina sobre un lado de la casilla, en tres capas de
    briznas recortadas (las largas oscuras detrás, las cortas claras
    delante), un rollo de hierba en el borde y el pie algo abierto.
  - Tipo nuevo `side` en `kit.json`: cuelga del borde de un bloque (y = 0
    es el borde, el lado +z; el editor la gira). Cada bloque lleva `rim`,
    la altura de ese borde (hierba 0,76, tierra 0,85).
  - Hojas: `arena5-esquina.png` y `arena5-esquina-prado.png` (colgando por
    los dos lados de un trozo de 6×6, a escala real).
- Hierba mediana (1754) y pequeña (1755), 2026-10-28.
  - Matas de briznas cortas, anchas y curvadas, repartidas por la casilla
    en tres grupos. Cada brizna tiene la base oscura y la punta clara que se
    dobla, en dos piezas; las de delante, más claras. La pequeña es más baja
    y rala, con algunas briznas tumbadas.
  - Primera versión: briznas rectas como palitos, y la mitad de grandes que
    en el retail.
  - El bloque de hierba pasa a `top` 0,93 (la cúpula llega a 0,94; a 0,86
    la decoración quedaba enterrada). `patch.gd` acepta `--top` para poner
    la decoración a la altura de cada bloque.
  - Hojas: `arena5-hierbas.png`, `arena5-grass_tuft-prado.png` y
    `arena5-grass_tuft_small-prado.png` (sobre hierba, a escala real).

## Fases

### A. Inventario completo (antes de modelar nada)

- [ ] Una hoja de plan por arena, como `arena1-plan.png` pero bien hecha y
      regenerada de verdad cada vez:
  - aplica `gfx_rules.json` y las familias;
  - cada pieza lleva su estado (hecho / a revisar / por hacer / menor) y la
    vista de nuestro modelo;
  - empezar por arreglar la de la arena 1.
- [ ] Lista maestra de assets sin duplicados: una entrada por familia o por
      pieza suelta, con las arenas que la usan.
  - Es lo que hay que fabricar.
  - Se agrupa por bioma (nieve, otoño/lava, hierba…).
- [ ] El dueño marca lo que no se usa y los adornos menores que se quedan
      (decisión por mapa, pero las 49 comunes se deciden una vez).

### B. Fabricar los assets y las texturas

**Bioma nieve (arena 1): aprobado por el dueño el 2026-10-25 ("perfecto, ya se ve todo bien").**
Hoja: `~/codigo/capturas/m7/arena1-kit.png`. Retail a la izquierda y las
tres looms a escala de juego a la derecha. Plan actualizado en
`~/codigo/capturas/m7/arena1-plan.png`.

- `godot/art/arena1/kit.json`: el manifiesto del kit, que leerá el editor.
  Lleva 15 piezas con su tipo (`tile` / `deco` / `flat`), la altura donde se
  pisa, la columna que va debajo, los gfx retail que sustituye y el nombre
  de cada loom.
- `kit.kx.js`: incluye `tree.kx.js` y `block.kx.js`. Son 17 modelos, cada
  uno en tres looms:
  - bloques (con nieve, transparente) y sus dos columnas;
  - árbol, puente, escarcha y escarcha pequeña, hojas con nieve;
  - pincho y pincho doble, farol, montón de nieve, nieve suelta,
    piedrecitas;
  - losa con glifo y runa de suelo.
- Las texturas: `block.tx.js` y `kit.tx.js`.
  - Los bloques se pasaron a funciones con tres looms (nieve, lila y
    escarcha). La `a` es idéntica a la aprobada; se comprobó píxel a píxel.
  - Las columnas llevan una textura sin franjas, para que se apilen.
- Glifos baybayin: `glyphs.py` los dibuja con Noto Sans Tagalog
  (`godot/art/fonts/`, OFL).
  - Losas: ha, ba, ka (oro viejo, azul, rojo).
  - Runas: la, ta, sa (ámbar, azul, rojo, con brillo).
- `tools/art/kit_shots.gd` fotografía cada pieza y cada loom a escala de
  juego.
  - Cada pieza sale sola. El dueño (2026-10-25): "no entiendo por qué el
    puente o la escarcha necesitan un bloque". El bloque de debajo solo
    confundía, y el puente ya no lleva columna en `kit.json`.
  - `kit_sheet.py` (fuera del repo) compone la hoja.
- No hay pack único: kiln no resuelve en un pack los materiales cambiados
  entre ficheros incluidos. El editor cargará `out/models/<nombre>.glb`.
- Escarcha (170 y 174), corrección del dueño: "es una línea de nieve
  acumulada". Se rehízo como un cordón de nieve a lo largo de un eje de la
  casilla, con crestas afiladas por el viento.
- Pincho de hielo (157), dueño: "hazlo más grueso". La base pasa de 0,17 a
  0,29 m de radio, con 6 caras; los dos trozos laterales y la nieve del
  pie también crecen.
- Siguiente: los demás biomas, que se sacan de la lista maestra (fase A).

- [ ] Por bioma: primero las texturas loom del bioma y después los modelos
      kiln (bloques, losas, columnas, decoración).
  - Cada familia, un solo modelo con los colores como tinte.
  - Las columnas usan una textura sin franjas, para que se puedan apilar.
- [ ] Cada asset se revisa en una hoja a escala de juego (`build_tile.gd` y
      `patch.gd`), y el dueño da el ok pieza a pieza.
  - Una pieza cada vez: enseñarla y esperar el ok (`slow-down-art`).
- [ ] Losas doradas y runas de suelo: glifos **baybayin** con una
      tipografía, "a modo de trampa" (idea del dueño).
- [ ] Lo que la criba marcó como VFX se apunta para S37, no se modela aquí.

### C. Editor de mapas para el dueño

- [ ] Herramienta que carga la **forma** de cada arena: casillas, alturas,
      obstáculos y celdas de salida, sacadas de la topología de combate que
      el servidor ya usa. **La forma no se toca.**
- [ ] El dueño **coloca los assets**:
  - una paleta con la lista maestra, filtrada por bioma;
  - clic en una casilla para poner o quitar;
  - girar, reflejar, tintar (selector de color o los tintes del bioma) y
    escalar un poco;
  - el bloque de suelo por casilla y la decoración encima;
  - las columnas se rellenan solas hasta el pie del mapa.
- [ ] Se guarda un `layout` por arena dentro del repo (JSON legible: casilla,
      modelo, giro, tinte).
- [ ] La vista es la del juego: ortográfica 2:1, casillas de 86 px y la
      misma luz.
- [ ] Por decidir con el dueño: el editor va dentro de Godot (vista real 3D)
      o en el studio (Go/Wails). **Recomendación: Godot**, porque los
      modelos y la luz se ven igual que en el combate.

### D. Del editor al juego

- [ ] `fight_view` dibuja el `layout` de la arena con nuestros modelos en vez
      de `MapGfx` retail.
- [ ] El dueño monta las arenas que quiera para la 1.0. Antes se habló de
      12–20.

## Lo que queda a medias de la sesión del 2026-10-25 (sin commit)

- `godot/tools/art/dress.gd`: el vestido de los GLB (normales suaves en la
  nieve, borde de luz en el hielo) sacado de `build_tile.gd` para
  compartirlo. Se puede quedar.
- `godot/tools/art/build_arena.gd` y `godot/art/arena1/layout.json`:
  colocación automática desde los sprites retail. **Descartada** como forma
  de montar mapas, aunque decodificar la casilla de cada sprite (clave `z`)
  puede servir para mostrar el retail como referencia en el editor.
- `godot/art/arena1/block.kx.js`: columnas `ice_col` / `ice_clear_col`.
  Hay que rehacer su textura sin franjas (fase B).

## Criterio de cierre

Todas las arenas que el servidor sienta tienen un `layout` hecho por el
dueño con nuestros assets, y `MapGfx` retail ya no se usa.
