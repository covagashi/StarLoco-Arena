# S36 — Arenas: todos los assets primero, y un editor para que el dueño monte los mapas

**Planificado:** 2026-10-25 · **Abierto:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (fase B hecha y aprobada el 2026-10-29; fase C, el editor, hecha el 2026-10-29: ahora el dueño monta las arenas; después, fase D)

**Alcance (dueño, 2026-10-28): 12 arenas, de la 1 a la 12** (mundos 5, 10,
12, 15, 21, 36, 38, 39, 40, 41, 42 y 44). El inventario se para aquí: "ya me
he cansado de inventariar". Las otras 35 (de la 13 a la 47; la 13 tiene
hojas y suposiciones, pero no nombres) se guardan en PNG y JSON en el
archivo de [S42](./S42-archivo-de-arenas.md), para retomarlas sin el
cliente antiguo. Lo que queda aquí:
- ~~modelar las arenas 8–12 por grupos~~ hecho (2026-10-29), y las 1–2
  rehechas con las skills;
- ~~el editor (fase C)~~ hecho (2026-10-29): `tools/map_editor/`;
- los `layout` del dueño en el juego (fase D).

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
- La casa: pared con canal de madera (179 baja, 181 alta; el dueño: la
  misma pared en dos alturas) y tejado (178), 2026-10-28. El dueño: "lo
  estás haciendo bien".
  - Pared de una casilla, de revoque, de unos 2,6 m (`wall_low`) y 4,5 m
    (`wall_high`) desde el pie del bloque, como en el retail. Arriba, dos
    maderas en los lados que ve la cámara: en +z una viga sobre dos
    ménsulas, en +x el canal para el agua (un perfil en U, algo más alto) y
    una tabla que remata el resto.
  - Tejado: una tabla inclinada hacia +z con tres hileras de tejas curvas
    al tresbolillo; cada hilera de arriba monta sobre la de abajo.
  - Texturas loom nuevas: `plaster` (manchas suaves de revoque, sin bordes;
    la primera versión parecía enlosado) y `timber` (veta larga, anillos,
    nudos; la primera tenía bandas oscuras cruzadas). Looms de la pared:
    revoque crema, blanco grisáceo (el tinte del mapa), ocre. Del tejado:
    teja verde, teja roja, pizarra.
  - `kit_shots.gd` acepta `--w` para fotos más anchas.
  - Hojas: `arena5-casa-1.png`, `arena5-casa-2.png` y
    `arena5-casa-montada.png` (un tramo montado como en el mapa, con hierba
    y tierra delante; el montaje es de prueba y no se sube).
  - Dueño: "perfecto, lo has pillado bien".
- Ladrillos de decoración (214, 215, 216): se omiten. Dueño (2026-10-28):
  "con la textura que has puesto a la pared, podrías omitir los ladrillos
  de decoración, ya que la textura queda bien". Van en `minor` del
  `kit.json` y anotados en `names.json`.
- Murete de la casa (193 liso, 195 con hiedra, 194 roto con hiedra, 197
  con marca de hierro, 223 el remate en cuña), 2026-10-28.
  - Un murete en ruinas de una casilla de largo, medio metro de grueso y
    unos 1,3 m de alto, con la parte de arriba redondeada (un perfil
    extruido) y hierba al pie. El mismo revoque que la casa.
  - Hiedra, rehecha a petición del dueño ("intenta hacer mejor la
    hiedra"): como la dibuja el retail, un tronco leñoso que sale del suelo,
    grueso al pie, ramificado en ramitas finas; hojas ovaladas con punta,
    grandes abajo y más pequeñas hacia las puntas, separadas de la pared
    cada una con su ángulo, en dos tonos (una hoja oscura bajo otra clara).
    En el roto una rama pasa por encima y deja un ramillete de pie arriba.
    Dueño: "ya me parece perfecto, buen trabajo". Hoja: `arena5-hiedra.png`. La marca de
    hierro va en un panel con borde oscuro (el hueco no se veía).
  - Looms: los del revoque, con la hiedra naranja, roja o verde.
  - Hojas: `arena5-murete-1.png` … `-3.png` y
    `arena5-murete-montado.png` (una fila sobre hierba; el montaje es de
    prueba y no se sube).
- Losas de adoquines blancos (183, 184: la misma losa con dos
  disposiciones), 2026-10-28.
  - En el mapa van encima de bloques, a lo largo del pie de la casa. Son una
    capa (tipo `cap`, como la de hierba): mortero blanco sobre la cara de
    arriba del bloque, con el borde caído por los lados en unas gotas, y
    siete adoquines redondeados encastrados.
  - Textura loom nueva `cobble`: piedra de río gastada, manchas suaves,
    algún poro, motas finas. Looms: mortero blanco con piedra salvia (el
    retail), mortero gris con pizarra azul, mortero arena con piedra parda.
  - Primera versión: adoquines con un escalón y gotas como pinchos; las
    piedras, algo pequeñas para la losa.
  - Hojas: `arena5-losas.png` y `arena5-losas-montadas.png` (una fila sobre
    bloques de tierra junto a la hierba; el montaje es de prueba).
- Valla de madera rota (199: un poste y su travesaño; 200: dos postes y el
  travesaño), 2026-10-28.
  - Postes de tronco cortados en plano, con astillas en el borde de arriba,
    tablillas partidas al pie, musgo en la mitad de abajo con un par de
    regueros, y grietas en la corteza. Travesaño de tronco torcido.
  - La valla corre a lo largo de z. La 199 se encadena: su travesaño llega
    al poste de la 199 de la casilla siguiente (z − 1); el origen de la
    pieza es fijo para que encajen. La última de una fila deja el travesaño
    suelto, como una valla rota.
  - Colores de paleta (la textura de viga tiene la veta horizontal y en un
    poste quedaría atravesada). Looms: madera clara (el retail), gris,
    oscura.
  - Primera versión: postes finos para la escala del juego y musgo
    demasiado chillón.
  - Hojas: `arena5-valla.png` y `arena5-valla-montada.png` (una fila sobre
    hierba; el montaje es de prueba).
- Barril (218) y caja (220), 2026-10-28.
  - Barril grande, casi de una casilla: duelas pintadas y abombadas, dos
    aros de hierro con remaches, aros gruesos de madera clara arriba y al
    pie, y la tapa metida con su agujero. Textura loom nueva `staves`:
    duelas enteras de arriba abajo con juntas oscuras, cada una de su tono,
    y la pintura saltada a manchas. Looms: pintura roja (el retail),
    pintura verde, roble sin pintar.
  - Caja abierta por arriba: marco de vigas en cada arista, paneles de
    tablas verticales metidos, clavos en las esquinas y el fondo a la
    vista. Usa la madera de las vigas de la casa. Looms: madera olivo (el
    retail), gris envejecida, marrón oscura.
  - Primeras versiones: las duelas con juntas cruzadas (parecían un
    entarimado) y la caja alta, con los paneles lisos.
  - Hojas: `arena5-barril-caja.png` y `arena5-barril-caja-montados.png`
    (junto a la pared de la casa; el montaje es de prueba).
- Árboles de hoja verde (2548 recto, 2550 con el tronco en Y, 2556 joven),
  2026-10-28.
  - Tronco claro y esbelto, algo retorcido, con un reguero de corteza
    oscura, el pie ensanchado y una mata de hierba. Copa abierta de hojas
    grandes de arce: núcleos oscuros pequeños con las hojas en abanico
    alrededor, dejando huecos; las claras solo arriba y alguna de otro
    color mezclada.
  - Looms: verde lima (el retail 2556), oliva otoñal (el 2548 del mapa va
    teñido así), verde verano.
  - Primera versión: un 25 % más altos que el retail, la copa una bola
    compacta y muy clara, el tronco grueso y las raíces como pinchos.
    Hojas de 20 puntos para dejarlos entre 4 000 y 7 700 triángulos.
  - Hojas: `arena5-arboles-1.png`, `-2.png` y `arena5-arboles-montados.png` (sobre
    hierba con la valla y una mata; el montaje es de prueba).
  - Dueño: "perfecto, veo que has pillado bien el punto".
- Flores (481 dos, 482 una) y florecitas rosas en el suelo (126),
  2026-10-28.
  - Flor de copa sobre un tallo corto: siete pétalos grandes abiertos, un
    anillo interior más derecho y claro, y el centro naranja. Entre briznas
    de un verde oliva apagado (las del bloque de hierba son lima y aquí
    desentonaban); `blades()` acepta ahora sus colores.
  - Florecitas rosas: cinco pétalos en copa baja con el centro blanco,
    esparcidas por la casilla, de varios tamaños (tipo `flat`).
  - Looms: flores amarillo (el retail), blanco, rojo; florecitas rosa (el
    retail), lila, blanco.
  - Primera versión: cabezas la mitad de grandes y altas, briznas lima
    tapando la flor, y las florecitas planas y pequeñas.
  - Hojas: `arena5-flores-1.png`, `-2.png` y `arena5-flores-montadas.png`
    (sobre hierba junto al árbol joven; el montaje es de prueba).
- Arbotante (225) y buhardilla (226, 227), 2026-10-28.
  - Corrección de un nombre mío: la 226 y la 227 no son la entrada de una
    cripta. En el mapa están encima del tejado: son una buhardilla, una
    ventana de piedra con barrotes, y la 227 es la 226 reflejada. Queda en
    `names.json` como suposición, para que el dueño la confirme.
  - Arbotante: una banda de piedra de sección cuadrada. Una pata recta,
    inclinada 15° hacia la pared que apuntala (−x), y un arco que se dobla
    hasta quedar casi horizontal y acaba en un corte vertical justo en el
    borde −x de la casilla, plano contra la pared de la casilla de al lado.
    Unos cascotes y hierba al pie. El origen es el centro de la casilla en
    el suelo.
  - Dueño: "júntalo con la pared para que puedas ver si la curvatura es la
    correcta". Montado contra la pared y comparado con el retail a la misma
    escala (`arena5-arbotante-vs-retail.png`), salieron tres fallos, que se
    corrigieron uno a uno: subía recto y se doblaba de golpe arriba (en el
    retail se inclina desde abajo y acaba casi horizontal, por eso se ve la
    cara de arriba de su extremo); llegaba casi a las vigas del tejado (en
    el retail se apoya a la altura de la ventana: ahora mide 1,6 m sobre la
    hierba y avanza casi una casilla); y era más delgado.
  - Buhardilla: va sobre el tejado (`on: roof`, y = 0 es la tabla del
    tejado). Dos postes algo inclinados hacia dentro, un dintel grueso,
    ventana oscura con una cruz de barrotes, y una mejilla de piedra que
    baja hasta las tejas.
  - El mismo revoque que la casa. Los nombres de looms se separan: el
    revoque solo (`plaster`) y con hiedra (`plaster_ivy`, los muretes que
    la llevan).
  - Primeras versiones: el arbotante fino como una vara; la buhardilla
    parecía una casita con tejado a dos aguas.
  - Hojas: `arena5-arbotante-buhardilla.png` y
    `arena5-arbotante-buhardilla-montados.png` (contra la pared de la casa;
    el montaje es de prueba).
- Matas de musgo (1682 y 334; 1683 y 1681; 1680) y brotes de hierba (331,
  333, 613), 2026-10-28.
  - Varias son el mismo motivo con otra disposición, así que son cuatro
    modelos. Almohadillas bajas y abultadas de musgo (una mancha aplastada
    con bultos en el borde y la parte de arriba más clara) con puntas de
    briznas diminutas asomando por debajo del borde. Tres almohadillas
    (`moss_pads`), una mancha alargada (`moss_patch`), una con briznas
    altas detrás (`moss_tall`). Brotes: grupitos de briznas anchas y curvas,
    oscuras al pie y claras en la punta, repartidas por la casilla.
  - En el mapa el musgo crece sobre las losas de piedra y en los bordes de
    la hierba; los brotes, sobre la hierba.
  - Colores de paleta en oliva suave. Looms: oliva claro (el retail), verde
    intenso, paja seca.
  - Primeras versiones: los flecos apuntaban hacia arriba como pinchos; con
    la textura de hierba salían oscuras y recargadas; luego, demasiado
    claras y pequeñas; los brotes, escasos y diminutos.
  - Hojas: `arena5-musgo-1.png`, `-2.png` y `arena5-musgo-montado.png`
    (sobre losas de adoquines y hierba; el montaje es de prueba).
- La nube de luz (461) es VFX (dueño, 2026-10-28): va a `gfx_rules.json`
  (`vfx`) y a S37; no se modela.
- Losas grabadas (466 el nudo del centro; 467 y 468 los brazos, la 468 es la
  467 reflejada), 2026-10-28.
  - En el mapa forman una plazuela en cruz de cinco casillas sobre la
    hierba: el nudo en el centro y un brazo a cada lado.
  - Una losa baja de piedra, con mellas en el borde, y la greca en relieve
    encima: espirales cuadradas hechas de bandas claras. El nudo lleva una
    cruz de bandas de borde a borde y una espiral en cada cuadrante
    enganchada a ella (un molinete: la misma espiral girada cuatro veces).
    El brazo lleva una espiral enganchada a una banda que llega al centro
    de su borde −x, tres rayas en una esquina y un botón. Así, girando cada
    brazo hacia el nudo, las bandas continúan de una casilla a otra.
  - El cuerpo baja 12 cm por debajo de la cara para tapar la cúpula del
    bloque de hierba.
  - Looms: piedra crema (el retail), gris, terracota.
  - Primeras versiones: espirales diminutas y apelotonadas (el paso era
    menor que el ancho de la banda); una espiral del nudo sin enganchar;
    motas de hierba atravesando la losa; losa algo gruesa.
  - Hojas: `arena5-losas-grabadas.png` y
    `arena5-losas-grabadas-montadas.png` (la plazuela de cinco casillas
    sobre hierba; el montaje es de prueba).
- Losas rotas (15) y tiras de piedra (16), 2026-10-28.
  - Corrección de un nombre mío: la 16 no son tablones de madera, son tiras
    de piedra del mismo color que las losas rotas. En el mapa las dos van
    juntas, en el borde de la hierba junto al canal.
  - Losas rotas: siete trozos planos de piedra, algo ladeados, cada uno con
    la cara de arriba gastada y más clara; dos tiras finas en el borde del
    fondo (lo que queda del bordillo) y brotes de hierba entre los trozos.
  - Tiras: tres tiras largas de una pieza, algo curvadas en planta, una al
    lado de otra, con una tira fina al fondo y brotes entre ellas.
  - La misma piedra que las losas grabadas (sus looms: piedra crema, gris,
    terracota); los brotes usan el oliva del musgo.
  - Primeras versiones: piedra demasiado clara, tiras hechas de trozos que
    parecían adoquines, y todo algo pequeño para la casilla.
  - Hojas: `arena5-empedrado.png` y `arena5-empedrado-montado.png` (sobre
    hierba y tierra; el montaje es de prueba).
- Chimenea (228), final de puente sobre poste (169) y ventana (210),
  2026-10-28.
  - Corrección de nombres míos, vistos en el mapa: la 228 no es un pilar
    pequeño, es una chimenea sobre el tejado; la 210 no está en el suelo,
    es una ventana en la pared alta (las dos quedan en `names.json` como
    suposiciones). La 169 no es un yunque.
  - Chimenea: fuste de revoque, una banda de madera y un remate cuadrado
    de piedra con el hueco del humo. Va sobre el tejado (`on: roof`). Looms
    del revoque.
  - La 169, dueño (2026-10-28): "no es piedra, es madera con la junta al
    final; creo que ya había otro asset igual". Es la 168, el final de
    puente del kit de nieve, apoyado en un poste. Primero la hice como un
    bloque de piedra oscura nuevo (`canal_block`), que se quita. Ahora es
    `bridge_end_post` en `godot/art/arena1/` (el mismo final de puente con
    un poste cuadrado de madera de 0,6 m que baja al canal, looms de la
    madera), y la arena 5 lo reutiliza.
  - Ventana: marco de tablas, hueco oscuro con una planta dentro. Tipo
    nuevo `wall` en `kit.json`: cuelga de la cara de una pared (z = 0 es la
    cara). Looms de la madera de vigas.
  - Primera versión de la ventana: estrecha, con el hueco asomando por
    encima del marco.
  - Hojas: `arena5-chimenea-ventana.png`, `arena5-puente-poste.png` y
    `arena5-chimenea-bloque-ventana-montados.png` (en la casa; el montaje
    es de prueba).
- Con esto, las 74 piezas de la arena 5 quedan cubiertas: las nuevas en
  `godot/art/arena5/`, las demás reutilizadas de las arenas 1 y 2, los
  ladrillos 214/215/216 omitidos y la nube 461 a VFX.

### Arena 6 (mundo 36, pradera con ruinas y andamios), 2026-10-28

- `mapa-arena6-1.png` … `-8.png`: 54 piezas, 10 ya en el kit (losas de
  adoquines, bloque de hierba, matas de musgo…), 44 nuevas, todas con mi
  suposición marcada con "¿?" en `names.json`.
- Lo que parece haber: bloques y pilares de piedras apiladas con musgo,
  rocas, las rocas del acantilado bajo la isla, losas de arenisca para el
  suelo, andamios y vallas de madera rota, puertas de tablas, plantas y
  helechos, y unos engranajes y tuercas de piedra con una rueda dentada.
- Pendiente del dueño: corregir los nombres antes de modelar.
- Bloques de piedra (1381, 1565, 1650, 1472), 2026-10-28. Kit nuevo en
  `godot/art/arena6/`.
  - Vistos en el mapa: la 1381 son los muros de la ruina, bloques de
    sillares en fila; la 1472 no va en el suelo, va apilada encima de un
    1381 (remate de piedras con musgo y flores blancas, `on: block`); la
    1565 es un montón tan alto como el bloque (no bajo, como supuse); la
    1650 es un pilar de casi dos casillas, algo más ancho que la casilla.
  - Textura loom nueva `stone`: arenisca gastada con manchas, picaduras y
    alguna grieta fina; `stoneMoss`, la misma con musgo que sale de los
    huecos. Looms: arenisca crema (el retail), granito gris, arenisca roja.
  - Cada piedra es un bloque con todas las aristas redondeadas (la unión de
    tres extrusiones redondeadas), para que se lea como piedra gastada.
  - Sillares: tres hiladas, la de en medio de dos piedras largas y las otras
    de 2 × 2, con las juntas fuera del centro. Montón, pilar y remate salen
    de un generador de hiladas irregulares (`rubble`): cada hilada en su
    rejilla, piedras que sobresalen o se meten, algo giradas, piedrecitas
    sueltas arriba. El remate usa la piedra con musgo más verde y lleva
    cuatro florecitas.
  - Musgo: manchas planas de borde rasgado sobre las caras y en las juntas,
    no bolas.
  - Primeras versiones: piedras como losas finas (bisel de dos escalones
    casi invisible), demasiadas juntas, musgo en bolas verdes, el montón y
    el remate bajos, el pilar estrecho y hecho de hiladas finas como
    ladrillos.
  - Hojas: `arena6-piedras-1.png`, `-2.png` y `arena6-piedras-montadas.png`
    (muro de sillares con remates, pilar y montones sobre adoquines y
    hierba; el montaje es de prueba).
  - Dueño: "lo estás haciendo bien".
- Rocas del acantilado (1803, 1802, 1798, 1804, 1799), 2026-10-28.
  - Vistas en el mapa: son la cara de la isla bajo las casillas del borde.
    Cada casilla del borde lleva una columna de roca colgada, del ancho de
    la casilla, que se afila hasta una punta. La 1803 y la 1802 (con bolos
    arriba) son las columnas; la 1798 es la punta de la esquina delantera,
    la más larga (3,3 m). La 1804 y la 1799 no son columnas: son placas de
    roca pegadas a una cara (la 1804 ancha en la cara +x, la 1799 estrecha
    en la +z), para romper una fila de columnas.
  - Tipo nuevo `cliff` en `kit.json`: va bajo una casilla del borde en
    lugar de su bloque. El origen es el centro de la casilla a la altura de
    la parte de arriba del bloque (la losa o la hierba va encima) y la roca
    baja desde ahí. Se ven sus caras +x y +z.
  - Columna: una cabeza del tamaño de la casilla bajo la losa y, debajo,
    lascas gordas de cinco caras que mantienen el ancho hasta la mitad y
    se afilan. La de la esquina es la más larga, así que cada columna acaba
    en una sola punta. Dos placas verticales salen de las caras vistas, con
    el borde de arriba iluminado.
  - Textura loom nueva `cliff`: vetas verticales anchas, juntas oscuras,
    salientes más claros. Looms: arenisca ocre (el retail), pizarra gris,
    roca parda oscura.
  - Primeras versiones: un bloque con carámbanos finos debajo; luego, en
    el montaje, un peine de pinchos (cada columna acababa en cuatro o cinco
    puntas) y las columnas fundidas en una pared; la 1804 y la 1799 hechas
    como columnas y después como tablas planas.
  - Hojas: `arena6-acantilado-1.png` … `-3.png`,
    `arena6-acantilado-montado.png` (una isla de 6 × 6 con columnas en los
    dos bordes vistos, la punta en la esquina, dos placas y una placa
    estrecha) y `arena6-acantilado-vs-retail.png` (el borde del retail al
    lado del montaje; el montaje es de prueba).
- Rocas sueltas (1834, 1835, 1833, 1836), 2026-10-28.
  - En el mapa: trozos claros y angulosos de la misma arenisca, apoyados
    al pie de los muros y pilares, y sueltos sobre la hierba y los
    adoquines.
  - Cada trozo es un bloque de seis caras con el borde de arriba y el pie
    achaflanados y los vértices movidos, así que ninguna cara queda en
    escuadra: tapa plana, canto inclinado iluminado. Uno de cada dos lleva
    la piedra un tono más oscura (`stoneShade`), para que los trozos
    vecinos se separen.
  - Montón (1834): seis trozos revueltos. Dos rocas (1835): un par por un
    lado y una ladeada por el otro, bajas. Roca de lajas (1833): una
    cúpula baja de lajas de canto apoyadas en un núcleo. Dos bloques
    (1836): dos trozos grandes partidos por una grieta y una laja apoyada
    delante.
  - Looms de la piedra: arenisca crema, granito gris, arenisca roja.
  - Primeras versiones: piedras redondeadas como dados; luego icosaedros
    que parecían gemas; la 1833 salió como una campana estrecha y la 1835
    alta y estrecha.
  - Hojas: `arena6-rocas-1.png`, `-2.png` y `arena6-rocas-montadas.png`
    (al pie del muro de sillares y del pilar, en la hierba y junto al
    acantilado; el montaje es de prueba).
- Musgo (1678, 1679) y losas de arenisca (17, 18, 19, 20, 455, 456, 457),
  2026-10-28.
  - Musgo: comparado al lado de las piezas de la arena 5, el 1678 es el
    mismo motivo que el 1680 (`moss_tall`) y el 1679 que el 1682
    (`moss_pads`). No se modelan: van a `shared` en `kit.json`. Hoja
    `arena6-musgo-vs-arena5.png`.
  - Losas: en el mapa no se ven porque quedan bajo los muros; quitando la
    decoración, son la fila del borde del fondo. Siete retail que solo
    cambian el dibujo de las grietas: dos modelos, losa lisa (17, 20,
    456, 457) y losa agrietada (18, 19, 455). Tipo `cap`, como la losa de
    adoquines.
  - Una losa gruesa de arenisca con el canto redondeado sobre un borde
    pálido gastado y la cara algo abombada. Textura loom nueva `flag`:
    enlosado irregular de unas nueve piezas por casilla, cada una de su
    tono, con juntas suaves; `flagCrack` añade grietas largas oscuras.
    Looms: arenisca oliva clara (el retail), gris, arenisca rosa.
  - Primeras versiones: las grietas salían como rayitas cortas y luego
    como manchas gruesas; la losa demasiado clara y amarilla, plana, con
    un escalón duro en el borde, y fina.
  - Hojas: `arena6-losas.png` y `arena6-losas-musgo-montados.png` (la
    fila de losas bajo el muro, el pilar y el montón, musgo en los
    adoquines y la hierba; el montaje es de prueba).
- Andamios y vallas rotas (1863, 1864, 1865, 1875, 1876, 1999, 2000) y
  tablas sueltas (1867, 1871), 2026-10-28.
  - Vistos en el mapa: todos son la misma jaula de tablas clavadas que
    llena una casilla, con distinto número de pisos. Las vallas rotas son
    de un piso, los andamios de tres y los altos de siete. Están contra
    los muros del fondo, entre pilares y bloques de sillares.
  - Dueño (2026-10-28): "la parte de negro es la sombra". La pieza oscura
    del centro de cada sprite no es un poste embreado, como la modelé
    primero: es la sombra dentro de la jaula. Se quitó el poste; la luz ya
    oscurece el interior y las tablas del fondo.
  - Una tabla plana en cada esquina (todas de cara a la cámara) y, en cada
    lado, una tabla ancha por piso, inclinada al revés en cada piso (zigzag
    hacia arriba), con los extremos pasando de las esquinas y un perno de
    hierro en cada uno. La valla baja lleva otra tabla cerca del suelo; la
    rota pierde dos tablas y una cuelga de un perno.
  - Trozo de valla (1867): dos tablas de esquina con dos travesaños.
    Tablas clavadas (1871): tres tablones clavados a la cara de un pilar,
    el del medio atravesado por un tubo de hierro.
  - Textura loom nueva `board`: madera aserrada gastada, vetas a lo largo,
    alguna raja y nudo. Looms: pino miel (el retail, más oliva), gris
    envejecida, nogal oscuro.
  - Primeras versiones: el poste negro del centro; travesaños finos con
    riostras en X (parecía una torre metálica); jaulas de dos y cuatro
    pisos, más bajas que el retail; madera demasiado amarilla.
  - Hojas: `arena6-andamios-1.png` … y `arena6-andamios-montados.png`
    (andamios, vallas y tablas contra el muro del fondo; el montaje es de
    prueba).
- Puertas de tablas (1869, 1870, 1872) y caja de tablas (1263, 1866),
  2026-10-28.
  - Vistas en el mapa: las puertas son hojas sueltas metidas en un hueco
    del muro de sillares, entre bloques, junto a los andamios (la 1870
    queda detrás de la rueda dentada). La 1263 y la 1866 no son una
    esquina: son una caja de tablas que llena la casilla, con una puerta en
    cada cara; la 1263 lleva un montón de piedras encima y la 1866 la
    rueda dentada delante.
  - Puerta: tablas verticales gruesas con los extremos desiguales, un
    travesaño ancho arriba y otro al pie, gruesos y sin pernos, que salen
    por los lados, y un pomo de hierro grande. La 1869 es alta y le falta
    un trozo de la tabla derecha (queda un pico fuera); la 1870, más baja,
    con el pomo arriba y la tabla rota al pie. La 1872 lleva una ventana
    cuadrada con un marco de cuatro tablas gruesas de madera teñida y un
    travesaño que se ve por dentro. Van de cara a +z, centradas en su
    casilla.
  - Caja: cuatro puertas de tres tablas. Las dos que se ven están unidas
    en la esquina delantera por dos bisagras de latón montadas sobre los
    travesaños. En la cara +z los travesaños van arriba y al pie, con una
    tabla corta en medio; en la +x van más abajo, así que asoma la tapa:
    dos tacos gruesos con una raja entre ellos. Los travesaños salen por
    el lado de fuera de cada cara, no por la esquina.
  - Textura loom nueva `boardV`: la misma madera con la veta en vertical
    (la proyección por caras pone la u en horizontal, y las tablas de pie
    salían con la veta atravesada). `boardDark` es la madera teñida del
    marco de la ventana.
  - Primeras versiones: travesaños finos con pernos (parecía una valla) y
    el pomo flotando delante de la puerta; el marco de la ventana marrón
    chocolate; la caja baja y cuadrada como un cajón, con las bisagras
    hacia fuera y luego tapadas por los travesaños, la tapa hundida y las
    tablas de las caras de atrás asomando por los lados.
  - Hojas: `arena6-puertas-1.png`, `-2.png` y
    `arena6-puertas-montadas.png` (muro de sillares sobre losas con las
    tres puertas en sus huecos, la caja con el montón encima, el andamio y
    el pilar; el montaje es de prueba).
  - Dueño (2026-10-28): "todo ok".
- Plantas (259, 260, 1789, 1790), 2026-10-28.
  - Vistas en el mapa: la 259 y la 260 son matas grandes en la hierba
    abierta y al pie de los montones; la 1789 y la 1790, plantitas de hoja
    ancha al pie de las piedras, con tallos secos por el suelo. La 246 de
    la arena 2 (hierba seca de puntas) no sirve: tiene otra forma.
  - Mata de hojas en cinta (259, 260): tres matas, la del medio la más
    alta. Cada hoja es una cinta plegada en V hecha de tramos que se
    curvan hacia fuera solo al final, con la punta redondeada. Lleva tres
    bandas pardas cortas, cada una en una mitad de la hoja. La 260 es más
    grande y algunas de sus hojas son de un verde más fresco.
  - Planta de hoja ancha (1789): dos rosetas de hojas anchas y
    puntiagudas, plegadas, sobre un tallito; cuatro tallos secos salen
    por el suelo hacia +x +z, y hay dos piedrecitas. La 1790 lleva además
    una flor de cinco pétalos mirando a la cámara.
  - Colores de paleta (piezas finas, sin loom). Matas: verde amarillo con
    bandas pardas (el retail), verde oscuro, oliva bronce con bandas óxido.
    Plantas: verde fresco con flor roja (el retail), verde hoja con flor
    violeta, oliva con flor naranja.
  - Primeras versiones: las matas a la mitad de tamaño, bajas y abiertas,
    con las hojas en punta, muy amarillas, las bandas rojizas y la cara
    iluminada del pliegue brillando demasiado; la planta pequeña, de hojas
    estrechas, y la flor diminuta, después girada hacia atrás y luego el
    doble de grande que en el retail.
  - Hojas: `arena6-plantas-1.png`, `-2.png` y `arena6-plantas-montadas.png`
    (matas y plantas en la hierba y al pie del pilar y los montones; el
    montaje es de prueba).
  - Dueño (2026-10-28): "todo ok".
- Engranajes y tuercas de piedra (1994, 2003, 2002, 2053), 2026-10-28.
  - Vistos en el mapa: la 1994 es una rueda dentada grande, de pie en el
    hueco del muro delante de la puerta baja (1870). La 2003 es una
    columna de tres engranajes pequeños colgada de la cara de un andamio,
    junto a la caja de tablas. La 2002 es un engranaje suelto en el suelo
    (en el mapa queda tapado). La 2053 es un montón de tuercas hexagonales
    junto a las rocas.
  - Dientes cuadrados, como los dibuja el retail. Rueda grande: una llanta
    de 32 bloques, 16 dientes, cuatro radios en cruz y un cubo abombado,
    algo echada hacia atrás, de cara a +z (1,7 m con los dientes).
    Engranaje pequeño: un disco de 12 caras con seis dientes y una tuerca
    por cubo. La columna son tres de ellos de cara a +x, engranados (cada
    uno girado medio diente, en zigzag). Tuercas: prismas hexagonales con
    el agujero como un disco oscuro, en cúpula (seis tumbadas, cuatro
    apoyadas encima, dos casi de pie arriba).
  - Piedra: las pequeñas usan la piedra de los sillares (`stone` y
    `stoneShade`); la rueda, `stoneCog`, gris oliva hecha con el granito
    teñido, porque la arenisca crema teñida salía amarilla.
  - Primeras versiones: la rueda un 25 % pequeña, amarilla, con la llanta,
    los dientes y los radios finos; el montón de tuercas pequeño y plano,
    con los agujeros como manchas; el engranaje suelto tumbado del todo y
    la columna con engranajes pequeños.
  - Hojas: `arena6-engranajes-1.png`, `-2.png` y
    `arena6-engranajes-montados.png` (la rueda delante de la puerta baja,
    la columna sobre la caja de tablas junto al andamio, el engranaje y las
    tuercas en los adoquines; el montaje es de prueba).
  - Dueño (2026-10-28): "todo ok". Con esto la arena 6 queda cubierta:
    solo quedan la 1781 (no es un asset) y las nubes 2046-2051 (VFX).

### Arena 7 (mundo 38, cementerio), 2026-10-28

- `mapa-arena7-1.png` … `-12.png`: 88 piezas, 23 ya en los kits, 65
  nuevas, todas con mi suposición marcada con "¿?" en `names.json`.
- `map_sheet.py` ahora también cuenta como cubiertas las piezas que un kit
  toma de otro (`shared` en `kit.json`). Por eso el musgo 1678 y 1679 ya
  sale cubierto (la arena 6 lo comparte de la arena 5).
- Lo que parece haber:
  - Muros del cementerio (1417) coronados por una verja de lanzas de
    hierro (1445, la pieza más usada).
  - Losas de piedra parda partidas para el suelo, ocho dibujos (en el mapa
    van teñidas de oscuro).
  - Lápidas, cruces de piedra, madera y hierro, una capilla pequeña, una
    puerta de cripta y una cripta central de bloques claros.
  - Calaveras, huesos y esqueletos, manchas de sangre, amapolas y una
    planta morada.
- El borde delantero del mapa (1482, 1645 y algunas 1426) está pintado en
  silueta negra: es el marco del primer plano, no otro objeto. La 2038
  parece niebla (VFX).
- Nombres del dueño (2026-10-28), guardados en `names.json`:
  - La 1445 es una reja de metal, como una valla; la 1417, la parte de
    arriba de un muro, rematada en ^.
  - Las ocho losas pardas (263, 266, 267, 268, 1526, 1527, 1532, 1533) son
    la misma: una losa de tierra, como el bloque de hierba pero de tierra.
  - La 1482 y la 1645 son la misma losa de piedra, como la de la casa de la
    arena 5.
  - La 2038 es niebla: va a VFX (`gfx_rules.json`). Hojas grises y polvo
    (2453-2456), lápidas, cruces (gótica de hierro, de piedra, de
    Santiago), una lápida de madera, una casita de piedra, tierra recién
    removida (2497, 2498), partes de muro (2210, 2215, 2222, 2227, 2228,
    2256), un bloque con un agujero (2499), huesos, cráneos, esqueletos y
    sangre.
  - Muchas lápidas y huesos son únicos, pero el dueño me deja agruparlos o
    hacerlos parecidos.
- Muro y reja (1417, 1445), 2026-10-28. Kit nuevo en `godot/art/arena7/`.
  Las piedras usan las texturas loom de la arena 6 (`../arena6/out/`), así
  que el kit de la arena 6 se construye antes.
  - Vistos en el mapa: la 1417 va encima de un bloque, en fila por los dos
    bordes del fondo, y la reja de lanzas va encima de cada remate.
    Además, la reja rodea las tumbas por el patio, teñida de azul.
  - Remate del muro (`wall_top`, `on: block`): dos hiladas de sillares,
    tres por cara, con las juntas cruzadas y una piedra de cada dos un tono
    más oscura, bajo una albardilla gruesa de losa agrietada (la textura
    `flagCrack` de la arena 6), a dos aguas a lo largo de x, en dos losas.
    Looms: arenisca crema (el retail sin teñir), granito gris, arenisca
    roja.
  - Reja (`iron_railing`): tres lanzas de barra cuadrada con la punta
    afilada y el pie abierto, algo torcidas, y un travesaño inclinado que
    sobresale por los lados. Va a lo largo de x, centrada en la casilla.
    Looms: hierro gris (el retail sin teñir; el mapa lo tiñe de azul
    oscuro), hierro oxidado, hierro con verdín.
  - Primeras versiones: el remate bajo y plano, con dos piedras por hilada
    tapadas por el vuelo de la albardilla; la reja de barras finas y en
    negro azulado (ese color es el tinte del mapa).
  - Hojas: `arena7-muro-reja.png` y `arena7-muro-reja-montado.png` (el
    muro con su reja por los dos bordes del fondo sobre bloques de tierra,
    y una tumba rodeada de reja en el patio; el montaje es de prueba).
  - Dueño (2026-10-28): "perfecto, lo has pillado bien".
- Losa de tierra (263, 266, 267, 268, 1526, 1527, 1532, 1533), 2026-10-28.
  - Es el suelo del cementerio (en el mapa va teñida de gris azulado). El
    dueño: "como el bloque de hierba, pero de tierra". Los ocho dibujos
    retail solo cambian las grietas, así que es un solo modelo
    (`dirt_cap`, tipo `cap`), y girándola las grietas no se repiten.
  - Cuatro placas de tierra apelmazada separadas por grietas que
    serpentean (cada borde quebrado por la mitad). Cada placa se abomba en
    cuatro escalones para leerse como un cojín, y una de cada dos va un
    tono más oscura y algo ladeada. Debajo, un reborde ondulado oscuro y
    terrones rotos que cuelgan a ras de los cuatro lados del bloque.
  - Textura loom nueva `dirt` (`arena7/kit.tx.js`): tierra seca pisada,
    manchas anchas, grumos, grano fino, alguna piedrecita y grietas finas,
    polvo claro en los bultos. Looms: tierra parda (el retail), tierra
    gris parda, arcilla roja oscura.
  - Primeras versiones: los terrones como dientes de sierra hacia fuera;
    el color anaranjado; las placas planas como tablones, con grietas
    rectas, y el reborde fino; la textura con piedrecitas como remaches.
  - Hojas: `arena7-losa-tierra.png` y `arena7-losa-tierra-montada.png` (el
    suelo de losas giradas con alguna capa de hierba, y el muro con la reja
    detrás; el montaje es de prueba).
  - Dueño (2026-10-28): "todo ok". Para enseñárselo no hace falta montaje.
- Losa de piedra (1482, 1645), 2026-10-28.
  - El dueño: "como la de la casa de la otra arena". La casa de la arena 5
    es de revoque crema con manchas, como la cara de arriba de la 1482, así
    que la losa usa esa textura (`../arena5/out/plaster`), con sus looms:
    revoque crema, blanco grisáceo, ocre. La 1645 es la misma losa (dueño),
    así que es un solo modelo (`stone_slab`, tipo `cap`).
  - En el mapa va a lo largo de los bordes delanteros (allí pintada en
    silueta negra).
  - Una losa gruesa (0,28 m) de canto redondeado. Los lados son más oscuros
    y algo irregulares, el pie va agrisado por la humedad y la cara de
    arriba se abomba un poco. La textura va tintada a un arena apagado y a
    escala menor, para que las manchas salgan como motas.
  - Primeras versiones: fina y muy clara, con la cara de arriba en
    escalones como una tarta; luego amarilla y con manchas grandes.
  - Hoja: `arena7-losa-piedra.png` (sin montaje, como pidió el dueño).
  - Dueño (2026-10-28): "ok".
- Hojas grises y polvo (2454, 2453, 2456, 2455), 2026-10-28.
  - El dueño: "como las hojas, pero grises". Son copos planos de gris pardo
    por el suelo, y los cuatro dibujos solo cambian cuántos hay. Con la
    libertad que dio el dueño para agrupar, son dos modelos: muchos
    (`dead_leaves`, 2454 y 2453) y pocos (`dead_leaves_few`, 2456 y 2455).
  - Cada copo es un contorno redondeado y desigual, algo doblado por el
    medio; uno de cada tres va más oscuro y otro más claro. Se reparten en
    una rejilla con holgura, así que se esparcen sin amontonarse.
  - Colores de paleta: gris pardo (el retail), gris ceniza, pardo óxido.
  - Primeras versiones: copos la mitad de grandes que en el retail,
    amontonados en grupos y demasiado claros.
  - Hoja: `arena7-hojas-polvo.png`.
  - Dueño (2026-10-28): "ok".
- Lápidas y cruces (2492, 2495, 2496, 2494, 1423, 1426, 1416, 1503, 1464,
  2500, 247, 1419, 2493), 2026-10-28.
  - Cada una es un modelo propio, pero hecho con unas pocas partes comunes:
    - un marco en arco (o cuadrado de esquinas redondas) alrededor de un
      panel hundido;
    - una calavera en relieve (cráneo, mandíbula, cuencas y nariz);
    - matas de hierba al pie y bases escalonadas.
    Todas miran a +z (la cara que el retail dibuja a la izquierda).
  - Lápida en arco con calavera (2492). Cruz gótica de hierro, algo doblada
    (2495), de barras de cuentas con tres bolas en cada brazo. Cruz alta de
    piedra (2496). Cruz de Santiago (2494), con lóbulos redondos en los
    brazos, ladeada. Lápida con tres tablas en el marco (1423). Lápida alta
    en arco con panel rojizo, musgo en la clave y una tablilla de piedra al
    pie (1426). Lápida con una figura en relieve (1416). Nicho con una vela
    encendida sobre dos escalones (1503; la llama brilla). Cruz de rueda
    con calavera y una tablilla de madera colgada (1464). Lápida de madera
    teñida de oliva con calavera y hueso (2500). Bloque grueso con un
    sombrero de piedra y una cruz de anillos de hierro detrás (247). Lápida
    con cuernos, ceja y ojos tallados, con una losa delante (1419). Lápida
    enterrada, de la que solo asoma el casquete (2493).
  - Piedra de la arena 6 (crema, con musgo, y un rojizo para los paneles) y
    su madera. Looms: arenisca crema, granito gris, arenisca roja; el hierro
    y la madera, sus propios looms.
  - Primeras versiones: la lápida del 2492 estrecha y con la calavera
    pequeña; la cruz de hierro fina y lisa; la de Santiago fina; las tablas
    del 1423 ocultas tras el panel; la figura del 1416 sin relieve; el nicho
    del 1503 pequeño y negro; la cabeza de la cruz del 1464 pequeña; la
    lápida de madera fina; el sombrero del 247 plano; la lápida enterrada
    entera (kiln pone la base de cada modelo en y = 0, así que no se
    hundía) y con un montón de tierra que parecía un tronco.
  - Hojas: `arena7-lapidas-1.png` … `-7.png`.
  - Dueño (2026-10-28) sobre la 2493: "simplemente recorta la lápida, que
    se vea solo la punta". Ahora es la lápida en arco de la 2492 cortada
    a ras de suelo (`clipAbove` recorta el contorno), con su marco y el
    panel hundido, casi derecha, y una mata al lado. Hoja:
    `arena7-lapida-enterrada.png`.
  - Dueño (2026-10-28): "el resto está perfecto".
- Plantas (1706, 520, 521, 522), 2026-10-28.
  - Planta muerta (1706): una roseta ancha de hojas largas en punta, gris
    morado. La mayoría tumbadas y las de dentro de pie, cada una doblada
    hacia abajo por la mitad. Looms: gris morado (el retail), pardo seco,
    casi negro.
  - Amapolas (520, 521; casi iguales, así que un modelo): nueve amapolas
    esparcidas a distintas alturas, en tallos finos y algo ladeados. Cada
    una es una copa de cinco pétalos de cuchara (el pétalo de las flores
    de la arena 5) alrededor de un corazón negro, con hojas al pie.
  - Mata de amapolas y margaritas (522): amapolas pequeñas y margaritas
    blancas de corazón amarillo sobre un lecho de hojas oliva.
  - Looms de las flores: rojas (el retail), blancas, naranjas.
  - Primeras versiones: la planta muerta pequeña, lila y de hojas
    estrechas; las amapolas grandes y apiñadas en el centro; la mata del
    522 con pocas hojas.
  - Hojas: `arena7-plantas-1.png`, `-2.png`.
  - Dueño (2026-10-28): "ok".
- Huesos y sangre, 2026-10-28. Con la libertad del dueño para agrupar,
  los 19 dibujos retail quedan en 12 modelos:
  - calaveras sueltas (1451, 2457); montón de calaveras (1476, 1484);
    calaveras en la tierra (1458, 1664); calavera y una mano que sale del
    suelo (1571); huesos sueltos (2265, 2267); huesos con calavera (2264,
    2266, 2268); tres huesos de pie como una valla (2766); esqueleto
    tumbado (2244, 2247); esqueleto atravesado por una estaca (2245);
  - charco de sangre (2447), gotas (1655) y salpicadura (2446), tipo
    `flat`.
  - Partes comunes: la calavera (cráneo, cuencas, nariz, dientes y
    mandíbula, mirando a la cámara y algo hacia arriba), el hueso largo con
    sus nudillos, la vértebra, la pelvis y los terrones de tierra. La
    sangre son manchas de borde irregular, con el centro húmedo más
    claro.
  - Looms: hueso marfil (el retail), gris, amarillento; sangre roja (el
    retail), icor negro, limo verde.
  - Primeras versiones: las calaveras mirando a los lados o al cielo
    (solo se veía la nuca), demasiado blancas y pequeñas; la sangre
    pequeña y demasiado roja.
  - Hojas: `arena7-huesos-sangre-1.png` … `-6.png`.
  - Dueño (2026-10-28): "ok".
- Partes de muro (2210, 2215, 2222, 2227, 2228, 2256), 2026-10-28.
  - Vistas en el mapa: las seis juntas forman el túmulo de piedra que se
    alza en el centro del cementerio. Son bloques de casilla entera con
    la cara de arriba enlosada; las del borde del túmulo tienen un lado
    inclinado.
  - Tres modelos (el editor los gira; la pendiente va en +z):
    - `crypt_block` (2215, 2228): lados de piedras grandes y redondeadas
      en dos hiladas, con las juntas cruzadas, y arriba cuatro losas
      agrietadas;
    - `crypt_block_slope` (2227, 2222, 2256): el lado +z inclinado 30° y
      cubierto de piedras; los demás lados son el núcleo liso, como los
      dibuja el retail, para que se lea el perfil;
    - `crypt_block_smooth` (2210): un solo bloque de losa agrietada con el
      lado inclinado.
  - Piedra y losa agrietada de la arena 6; looms: arenisca crema, granito
    gris, arenisca roja.
  - Primeras versiones: muchas piedras pequeñas (parecían ladrillos), la
    pendiente casi invisible y luego una rampa; en el bloque inclinado,
    las piedras de los lados cortadas a trozos y las de la pendiente
    hundidas en el núcleo.
  - Hojas: `arena7-cripta-1.png`, `-2.png`.
  - Dueño (2026-10-28): "todo ok".
- Casita de piedra (2491), tierra fresca (2497, 2498), bloque con agujero
  (2499), roca de pie (1579) y manchas de musgo (2449), 2026-10-28.
  - Casita: un mausoleo estrecho con la puerta en arco oscura en el
    hastial (+x), un tejado empinado de lajas de piedra en cuatro filas
    que vuela sobre las paredes, y la cumbrera de piedras sueltas.
  - Tierra fresca: un túmulo alargado (a lo largo de x) de tierra recién
    removida, de lados empinados y cima plana, con terrones alrededor. La
    2498 lleva tres florecitas clavadas. Usa la textura `dirt` teñida más
    cálida (`dirtFresh`).
  - Bloque con agujero: un sarcófago sin tapa, de paredes gruesas
    alrededor de un fondo hundido, con una placa en el extremo +x.
  - Roca de pie (1579, el dueño: "roca"): una piedra gris redondeada, de
    pie y algo ladeada, con matas y piedrecitas pardas al pie. Looms:
    granito gris (el retail), gris oscuro, arenisca roja.
  - Musgo (2449): el dueño, al verlo modelado aparte como mancha plana:
    "ya teníamos musgo". Usa las matas de musgo de la arena 5
    (`moss_pads`, en `shared`); el modelo propio se quitó.
  - Primeras versiones: el túmulo plano, pálido y luego rojo oscuro, con
    las flores diminutas; el sarcófago de paredes finas; la roca crema y
    estrecha.
  - Hojas: `arena7-casita-tumbas-1.png` … `-3.png`.
  - Dueño (2026-10-28): "ok".
- Con esto la arena 7 queda cubierta: `mapa-arena7` da 87 piezas, 0
  nuevas (la 2038, niebla, va a VFX).


### Arena 8 (mundo 39, volcán), 2026-10-28

- `mapa-arena8-1.png` … `-6.png`: 37 piezas, 9 ya en los kits, 28 nuevas,
  con mi suposición marcada con "¿?" en `names.json`.
- Lo que parece haber:
  - Suelo de losas de basalto negras con agujeros (2285, 2280: las dos
    piezas más usadas, 217 veces).
  - Casillas y charcos de lava con halo (2270, 2271, 2276–2279) y una
    cascada de lava por el borde (146).
  - Pilares de roca altos alrededor (1764–1766), teñidos de pardo oscuro
    en el mapa, junto al acantilado de la arena 6 (1802–1804, ya hechos).
  - Pinchos y cuernos de roca volcánica con brasas (2290–2297), árboles
    secos (1729–1731), rocas sueltas (1761, 1762, 1767, 1817), una flecha
    (1269) y un esqueleto tumbado más (2246).
- La arena 2 ya tiene `lava_pool`, `bare_tree` y `basalt_rocks`. Lo he
  marcado en las suposiciones por si sirven aquí, para no duplicar.
- La niebla del borde del mapa ya va a VFX.

- Nombres del dueño (2026-10-28), guardados en `names.json`:
  - 2285, losa de roca volcánica; 2280, roca volcánica.
  - 1765 y 1766, columnas de roca. 1764, 1761, 1762, 1767 y 1817, rocas.
  - Lava: 2270, 2271, 2276–2279; la 146 es lava derramándose.
  - Árboles secos: 1729, 1730 y 1731.
  - Pinchos de roca volcánica: 2290–2295 y 2297.
  - La 1269 es igual que la 1270 (`weapons_ground`); la 2246, un
    esqueleto como el 2244 o el 2245.
- Nueva forma de trabajar (dueño, 2026-10-28): primero se inventarían
  todas las arenas, recogiendo y agrupando piezas entre mapas, y después
  se modela por grupos. Así no se repite trabajo. `names.json` tiene dos
  claves nuevas, y `map_sheet.py` muestra las dos:
  - `same`: un gfx que el dueño dice que es igual a otro usa su pieza del
    kit.
  - `group`: el grupo de nombre del dueño. Se modela una familia por
    grupo, y la hoja dice cuántos gfx lleva cada grupo en todas las
    arenas.

### Arena 9 (mundo 40, ruinas con rejas), 2026-10-28

- `mapa-arena9-1.png` … `-6.png`: 40 piezas, 20 ya en los kits (pilares,
  sillares, rocas y musgo de la arena 6; reja, huesos y sangre de la
  arena 7) y 20 nuevas, con mi suposición marcada con "¿?".
- Lo que parece haber:
  - Losas de piedra clara para el suelo (1829, 1839, 1840).
  - Muchas piedrecitas y cascotes sueltos (1413, 1428, 1559, 1637,
    2168–2171, 2174, 2200).
  - Un hueco con escalones (1570), antorchas de pared (1538) y un bloque
    de piedra con tapa (1420).
  - Un escudo redondo (2019), un hacha clavada (2016), una argolla (2020)
    y un poste con sangre (2443).

- Nombres del dueño para la arena 9 (2026-10-28):
  - 1829, 1839 y 1840 son la losa de piedra de la arena 7 (`same` → 1482).
  - 1420 es el remate de muro en ^ de la arena 7 (`same` → 1417).
  - Grupos nuevos: «alcantarilla» (1570: un cuadrado y dos barras de
    metal), «roquitas» (1413, 1428, 1559, 2168, 2169, 2174, 2200),
    «trozo de roca» (1637), «antorcha» (1538: apagada, clavada a la
    roca), «escudo» (2019), «hacha» (2016), «látigo» (2020, recogido),
    «losa rota» (2170, 2171) y «sangre de pared» (2443).
  - Quedan 16 nuevas.

### Arena 10 (mundo 41, cocina del carnicero), 2026-10-28

- `mapa-arena10-1.png` … `-11.png`: 76 piezas, 14 ya en los kits y 62
  nuevas, con mi suposición marcada con "¿?".
- Lo que parece haber:
  - Suelo de baldosas claras (2736, 203 usos).
  - Bloques de piedra parda en el borde (984, 985).
  - Una alfombra roja con bordes, esquinas y un trozo que cuelga por el
    borde del mapa (2458, 2459, 2461, 2465, 2470–2472).
  - Mesas con mantel de cuadros, jaulas de madera, cajas y cestas con
    carne, una tina de sopa y un asador.
  - Mucha comida y utensilios de carnicero, todos de un solo uso.
  - La 2763 parece un personaje pintado (un carnicero sentado). Pregunto
    si se quita.

- Nombres del dueño para la arena 10 (2026-10-28):
  - 2736, losa de ladrillos. 984 y 985 son postes de madera.
  - La 2737 es la mancha de sangre 1655 (`same`); la 1590, la caja 220.
  - La 474 es una cascada, aunque en el mapa sale roja de sangre. La 2459
    es la sangre que va encima de ella.
  - 2461, 2465 y 2470–2472 unen la losa con el río de sangre, en recto o
    en escuadra.
  - Las jaulas (2738, 2739, 2741, 2745, 2751 abierta, 1437 rota) pueden
    ir vacías; dos llevan un pollo.
  - La 2763 es una persona sin cabeza sentada en una silla: se hace.
  - El resto, con sus grupos (embutidos, costillar, herramientas, plato,
    barril, hacha, alcantarilla…), está en `names.json`. Quedan 60 nuevas.

### Arena 11 (mundo 42, selva con plantas carnívoras), 2026-10-28

- `mapa-arena11-1.png` … `-10.png`: 72 piezas, 31 ya en los kits (hierba,
  tierra, musgo, plantas y huesos) y 41 nuevas, con mi suposición
  marcada con "¿?".
- Lo que parece haber:
  - Matas de hierba alta (1751–1753, 2784) y dos bloques de hierba alta
    (516, 580, de la familia del `grass_block`).
  - Helechos oscuros, algunos con plantas carnívoras (2770, 2772–2775).
  - Trepadoras con flores, zarzas con espinas (2599–2605) y lascas de
    tierra seca (2313–2316).
  - Unas pocas ruinas de piedra con musgo (2323, 2324, 2326, 2329).

- Nombres del dueño para la arena 11 (2026-10-28):
  - 1751–1753 y 2784: hierba como la `grass_tuft`, pero de hoja más fina
    y larga (grupo «hierba fina»).
  - Grupos «planta» (11 gfx), «planta mediana» (2145–2147, 2777), «raíz
    con pinchos» (2599, 2601, 2602, 2604, 2605), «hojas secas» (2600,
    2771, 2779), «tótem de roca» (2323, 2326, 2329).
  - 2313–2316 se suman a «losa rota», con las de la arena 9.
  - 2781–2783, "plantita negra, creo que ya la tenemos": les pongo la
    planta muerta 1706 (`same`), a confirmar al modelar.
  - 1601, calavera empalada; 2159, planta seca; 2324, roca con pintura.
  - Quedan 38 nuevas.

### Arena 12 (mundo 44, pantano), 2026-10-28

- `mapa-arena12-1.png` … `-8.png`: 54 piezas, 5 ya en los kits y 49
  nuevas, con mi suposición marcada con "¿?".
- Lo que parece haber:
  - Un bloque de barro amarillo (619, 219 usos) y losas de barro, lisas o
    con hierba oscura (1501, 2654–2657, 2659, 2660, 2692).
  - Tocones con setas planas en el borde (2678–2683).
  - Lenteja de agua (2662–2667), juncos de penacho blanco (2668–2670),
    tallos enroscados del pantano (2618–2625) y cañas rotas (2673–2676).
  - Pasarelas de tablas (1204, 1206, 1296) y postes con cuerda (1207,
    1297).

- Nombres del dueño para la arena 12 (2026-10-28):
  - 619, cuadrado de tierra; 2661, mancha o líquido; 2649, lianas; 790,
    pala.
  - Losas: «losa de tierra» (2654–2656, 2692) y «losa de barro» (1501,
    2657, 2659, 2660).
  - «planta de setas» (los tocones 2678–2682), «plantita» (2683, 2684,
    2686), «líquido verde» (8 gfx: lenteja de agua y zarcillos),
    «tablas» (pasarelas 1204, 1206, 1296 y sus soportes 1207, 1297),
    «enredadera» (2618, 2619, 2621, 2624, 2625), «tronquito» cortado con
    barro y burbujas (2673–2676), «burbuja de barro» (2671, 2672), «flor
    blanca» (2668–2670).

### Modelado de las arenas 8–12 por grupos, 2026-10-29

Kit nuevo `godot/art/arena8/` (volcán), con el mismo formato que los demás.
Se modela un grupo cada vez y se enseña antes de seguir.

- **Suelo del volcán** (grupos «losa volcánica» 2285 y «roca volcánica»
  2280; entre las dos salen 217 veces en el mapa). Hoja:
  `kit-arena8-suelo.png`.
  - Loom `pumice` (`arena8/kit.tx.js`): roca volcánica de piel lisa, con
    abultamientos grandes, surcos finos de la colada en algunas piedras,
    agujeros redondos de tres tamaños y grano fino. Looms: pardo oscuro
    (como lo tiñe el mapa), gris ceniza y escoria roja.
  - `volcanic_slab` (2285): tres piedras redondeadas en fila a lo ancho de
    la casilla, dos largas detrás y una más pequeña y lisa delante.
    `volcanic_rock` (2280): una cúpula, más alta por detrás. Las dos son
    `tile`, y sus normales suaves salen del material `soft*`.
  - Lo que salió mal en la primera versión:
    - Las piedras tenían el eje largo hacia la cámara y se veían escorzadas,
      a la mitad de tamaño. Ahora se colocan en ejes de pantalla (u a lo
      ancho, v hacia la cámara), y la roca mide 1,1 m a lo largo de la
      diagonal, como la retail.
    - La roca era un disco plano: ahora es una cúpula.
    - Los surcos se leían como rayas de cebra en el suelo montado: ahora
      son finos y solo salen en algunas piedras.
    - La textura era clara como hormigón y tenía demasiados poros. Al
      aclararla para que no saliera negra, el suelo parecía de galletas:
      se quedó a medio camino.

- **Lava** (grupo «lava»: 2270, 2271, 2276–2279 y 146). Hojas:
  `kit-arena8-lava-1.png` y `-2.png`. Dueño (2026-10-29): el
  `lava_pool` de la arena 2 (142, 143) "debería ser igual", porque se hizo
  sin las dos skills. Ahora es la misma pieza: la arena 2 ya no tiene modelo
  propio y toma `lava_spots` de este kit (`shared`).
  - Loom `molten` (`arena8/kit.tx.js`): lava lisa y luminosa, distinta de
    la lava con costra de la arena 2. Lleva ondulaciones anchas, manchas
    redondas más frías (alguna con un aro claro) y un brillo fino. Looms:
    amarillo oro (retail), amarilla clara y rojo anaranjado.
  - `lava_cell` (2278): un cojín de lava redondeado que llena la casilla.
    `lava_spots` (2277, 2279, 2270, 2271, 142, 143): el mismo, con unas
    gotas colgando del borde. `lava_sheet` (2276): la lámina plana que
    rellena entre las casillas de lava. `lava_fall` (146): una casilla que
    se derrama por su lado +x en dos chorros separados por una roca oscura;
    caen unos dos metros y se enfrían en cinco bandas hasta casi negro.
  - El halo de luz alrededor de la lava va a S37 (VFX).
  - Lo que salió mal en la primera versión:
    - La emisión quemaba el color y la loom b salía casi blanca. Ahora la
      emisión es más baja y la b, amarilla.
    - Los lados no se oscurecían, porque el tinte no afecta a la emisión de
      la textura. Ahora los lados y las gotas van en un color propio, naranja
      oscuro.
    - Las manchas eran puntitos rojos: ahora son grandes y anaranjadas.
    - El cojín era cuadrado sobre un cuerpo de esquinas redondas, y sus
      picos asomaban.
    - Las gotas salían hacia arriba (un `lathe` se apoya en su base) y
      luego atravesaban el cojín. Ahora acaban dentro del cuerpo.
    - Los chorros eran ladrillos y luego tuberías finas. Ahora son
      cilindros anchos aplastados contra la cara, con un tubo curvo en el
      borde.

- **`lava_rock` de la arena 2 (128), rehecha con las skills** (dueño,
  2026-10-29). Hoja: `kit-arena2-lava-rock.png`.
  - En el mapa es una casilla de suelo (capa 8191): una losa verde al borde
    de un escalón sobre la lava, y no una losa sobre un poste. Pasa a
    `tile` con la forma de la `flagstone`.
  - Lleva una grieta luminosa cerca del borde +x y, por ese lado, dos
    chorros de lava (uno fino y otro ancho) de un metro, con los colores
    de la cascada de la arena 8.
  - La textura de lava con costra de la arena 2 ya no la usaba nadie y se
    quita.
- **Columnas de roca** (grupo «columna de roca»: 1765 y 1766; son el muro
  del fondo de la arena 8 y salen 78 veces). Hojas:
  `kit-arena8-columnas-1.png` y `-2.png`.
  - Reutilizan la textura `cliff` de la arena 6, que es la misma arenisca
    en estratos verticales. Sus looms son ocre, pizarra y pardo oscuro; la
    c es el tono con que el volcán las tiñe.
  - `rock_spire` (1765): unos 5 m. Un núcleo en sombra con lajas verticales
    de alturas distintas alrededor, un trozo roto arriba, un bolo alto al
    pie y musgo en dos repisas.
  - `rock_spire_wide` (1766): tres bloques anchos apilados, de esquinas muy
    redondeadas y abombadas, con cuellos oscuros entre ellos. Lajas en el
    lado +x y una corona inclinada arriba.
  - Lo que salió mal en la primera versión:
    - Las dos eran prismas limpios; ahora tienen silueta irregular y
      huecos en sombra.
    - El musgo eran puntos y luego rayas que parecían palitos; se quedan
      solo las matas en las repisas.
    - En la 1766, los bolos sueltos sobre un poste parecían un muñeco de
      nieve: se volvió a bloques anchos abombados.

- **Rocas sueltas** (grupo «roca»: 1761, 1762, 1764, 1767 y 1817; salen
  en las arenas 8, 18 y 25). Hojas: `kit-arena8-rocas-1.png` … `-3.png`.
  - La misma arenisca que las columnas (`cliff` de la arena 6), en cinco
    formas: `rock_tall` (1764, unos 3,3 m), `rock_leaning` (1762, lajas
    inclinadas hacia atrás), `rock_peak` (1761, un pico de cinco caras),
    `rock_blocky` (1767, bloques con un bolo delante) y `rock_low` (1817,
    un montón bajo de lajas redondeadas).
  - Se construyen con bloques facetados que se estrechan hacia una punta
    roma (`crag`: un lathe de 5 o 6 caras, aplastado e inclinado),
    colocados en ejes de pantalla.
  - Lo que salió mal antes:
    - Con lajas extruidas finas parecían cartones, y medían el 60 % del
      ancho retail (la retail desborda la casilla: 1,3–1,7 m de ancho en
      pantalla).
    - Con bolos (`rock`) parecían patatas.
    - Con prismas chaflanados parecían cajas.
    - La alta se quedaba en 2,5 m.
    - Una mata de musgo quedó escondida detrás, por ponerla en
      coordenadas de mundo.

- **Árboles secos** (grupo «árbol seco»: 1729, 1730 y 1731; son pinos
  muertos). Hojas: `kit-arena8-arboles-1.png` … `-3.png`.
  - No son el `bare_tree` de la arena 2: la 2559 es un árbol oscuro y
    retorcido con hojas.
  - Loom nueva `deadwood` (`arena8/kit.tx.js`): madera sin corteza y
    blanqueada, con fibras verticales, alguna grieta oscura y manchas.
    Looms: blanqueada (retail), gris ceniza y carbonizada (el volcán las
    tiñe casi de negro).
  - `dead_pine_tall` (1731): 9,3 m, muy fino, con dos brazos largos y la
    copa en horquilla. `dead_pine` (1730): 6 m, con una corona de ramas
    peladas, cuatro penachos y musgo al pie. `dead_pine_short` (1729):
    4 m, con la copa rota en tres púas.
  - Tronco en tres tramos encadenados con un poco de giro, raíces abiertas
    al pie, ramas con una horquilla y penachos de agujas secas en abanico.
  - Lo que salió mal en la primera versión:
    - El tronco acababa en punta de aguja.
    - Las raíces eran estrellas larguísimas.
    - El musgo eran rectángulos verdes: ahora son bultitos pegados a la
      madera.
    - Los penachos eran finos y escasos.
    - Quedó un penacho flotando sin su rama.
    - Los brazos del pino alto se salían de la foto: eran más largos que
      los retail.

- **Pinchos volcánicos** (grupo «pincho volcánico»: 2290–2295 y 2297).
  Hojas: `kit-arena8-pinchos-1.png` … `-4.png`.
  - Loom nueva `horn` (`arena8/kit.tx.js`): roca volcánica dura y vítrea,
    con vetas a lo largo y bandas de color suaves. Looms: naranja parda
    (retail), basalto gris y obsidiana roja y negra. Las puntas son más
    oscuras.
  - La ayuda `horn` (tramos de lathe de cinco caras encadenados, que se
    afilan y se doblan) hace las siete piezas: `volcanic_spike` (2291),
    `volcanic_spike_small` (2292, la misma a la mitad),
    `volcanic_spikes_low` (2290), `volcanic_claws` (2293),
    `volcanic_palisade` (2294), `volcanic_horn` (2295) y
    `volcanic_horn_big` (2297, unos 3 m).
  - Al pie llevan brasas encendidas, en grupitos de pepitas. El halo de
    luz va a S37.
  - Lo que salió mal en la primera versión:
    - La loom parecía madera de caramelo: ahora es más oscura y con
      menos veta.
    - Los pinchos inclinados iban demasiado tumbados.
    - Las brasas eran puntitos, y en la loom b salían blancas.
- **Arena 8 completa**: `map_sheet.py 39 8` da 37 piezas y 0 nuevas.
  `arenas.json` del archivo la marca como hecha.

Kit nuevo `godot/art/arena9/` (ruinas con rejas, mundo 40). La piedra usa
la textura `stone` de la arena 6; todavía no tiene `kit.tx.js` propio.

- **Roquitas** (grupo «roquitas»: 1413, 1428, 1559, 2168, 2169, 2174 y
  2200; solo salen en la arena 9). Hojas: `kit-arena9-roquitas-1.png` …
  `-3.png`.
  - Seis modelos con la misma ayuda `pebble`, que coloca cada piedra en ejes
    de pantalla, con su tamaño y su sitio medidos en el sprite retail.
    Hay seis formas: bulto, pico, cuña con arista, lasca plana, losa gastada
    y bloque escuadrado.
  - `pebbles` (1413 y 2174, que son el mismo sprite), `pebbles_spread`
    (1559), `stone_shards` (2168), `stone_flake` (2169, una losa rota con
    otra más fina encima), `pebbles_few` (2200) y `slab_chips` (1428, un
    bloque de piedra rosada con tres roquitas).
  - Lo que salió mal en la primera versión:
    - El `jitter` se aplicaba en metros y deformaba piedras de 10 cm. Ahora
      se aplica a la forma unidad, antes de escalarla.
    - Las piedras quedaban apiñadas en profundidad: convertí la altura del
      sprite a metros con la escala horizontal (61 px/m) en vez de la del
      suelo (30 px/m).
    - Las cuñas de la 2168 eran pirámides, y la losa de la 2169, un
      rectángulo de esquinas vivas.
    - La losa de la 1428 salió primero como un pan y luego naranja. Ahora es
      un bloque con bisel, en el granito de la arena 6 entibiado a rosa.

- **Losas rotas** (grupo «losa rota»: 2170 y 2171 de la arena 9, 2313–2316
  de la arena 11). Hojas: `kit-arena9-losa-rota-1.png` … `-3.png`.
  - Las seis van en el kit de la arena 9, que ahora también cubre la arena
    11 (`arenas: [40, 42]`).
  - Cada trozo es una placa con el contorno medido en el sprite retail
    (ayuda `plate`).
  - Las de arenisca clara, `broken_slab` (2170) y `broken_slab_split`
    (2171), van gastadas: el canto redondeado y la cara de arriba algo
    metida.
  - Las pardas de la arena 11 son `cracked_paving` (2313), `_left` (2314),
    `_bits` (2315) y `_long` (2316). Van de corte vivo, entre grietas
    oscuras del suelo: un agujero con brazos quebrados que se afinan
    (ayuda `crack`).
  - Lo que salió mal en la primera versión:
    - Las grietas eran estrellas pequeñas y negras. Ahora son más grandes,
      con brazos quebrados y menos oscuras.
    - El pardo salía naranja y luego amarillo. Se quedó en un pardo apagado.

- **Alcantarillas** (grupo «alcantarilla»: 1570 de la arena 9 y 2746 de la
  arena 10). Hoja: `kit-arena9-alcantarilla.png`. Las dos son `flat`:
  van tumbadas sobre la cara de arriba de un bloque de suelo, como la
  rejilla de la arena 1.
  - `sewer_grate` (1570): cuatro piedras claras hacen un marco que llena la
    casilla. La boca baja en rampas de musgo hasta el negro, y dos barras
    gruesas de hierro, a lo largo del eje z como en la retail, quedan
    hundidas en el hueco.
  - `blood_drain` (2746): el desagüe redondo donde acaba el río de sangre.
    Tiene un aro de latón, sangre alrededor del agujero que rebosa por
    delante y por detrás, el negro dentro y una barra.
    - Sus looms: latón con sangre roja, gris con icor negro, y cobre con
      limo verde.
    - Las ramitas verdes del sprite no se hacen, y la mancha gris de
      alrededor es sombra pintada.
  - Lo que salió mal en la primera versión:
    - Un `lathe` sin radio 0 cierra igual sus tapas, y tapaba los dos
      agujeros. Ahora el marco son cuatro cajas y el anillo de sangre es un
      polígono abierto por una ranura (ayuda `ring`).
    - El marco salía girado 45° y medía 1,34 m: un `lathe` de cuatro caras
      ya tiene los lados en los ejes.
    - Las barras eran hilos que pasaban por encima del marco.

- **Hachas** (grupo «hacha»: 2016 de la arena 9; 2755 y 2481 de la arena
  10). Hojas: `kit-arena9-hachas-1.png` y `-2.png`.
  - Looms: verdín oliva (retail), acero y hierro oxidado. Son colores de
    paleta, sin textura.
  - `war_axe` (2016): un hacha de guerra de unos 2,4 m, clavada de pie en
    el suelo y algo inclinada a la derecha. Lleva una cabeza maciza con
    martillo, dos remaches y un pincho, una media luna con el filo más
    claro y el mango vendado con dos tiras sueltas.
  - La 2755 y la 2481 son la misma hacha de carnicero en dos posturas.
    Comparten la cabeza (`cleaverHead`) y el mango (`cleaverHaft`); cada
    uno va con su propio ángulo, y una ranura oscura marca el corte.
    - `butcher_axe` (2755): clavada en la mesa, con la hoja inclinada
      hacia atrás y el mango casi horizontal.
    - `butcher_axe_wall` (2481): clavada en una pared, que es el plano
      x = 0 mirando a +x. El filo va vertical y el mango sale hacia abajo.
  - Lo que salió mal en la primera versión:
    - La media luna no tocaba la cabeza.
    - Una segunda lámina del mismo grosor hacía rayas en la hoja: dos caras
      en el mismo plano.
    - Con el mango en el plano de la hoja, la de la mesa parecía un
      recogedor, y el mango subía demasiado.
    - La de la pared se veía de canto. Ahora va girada 30° sobre el filo.

- **Antorcha** (grupo «antorcha»: 1538, apagada; 5 usos en la arena 9).
  Hoja: `kit-arena9-antorcha.png`.
  - `wall_torch`: un brasero de unos 0,95 m que va clavado arriba, en la
    esquina de un pilar. De abajo arriba lleva un bulbo en punta, un vástago
    estrecho, una copa de madera clara ceñida con bandas de hierro oscuro y
    una corona de siete púas doradas, con la ceniza fría dentro.
  - y = 0 es la punta del bulbo. Un soporte de hierro sale de la copa hacia
    atrás (-x -z) hasta la pared.
  - Looms: madera clara con púas doradas (retail), gris con acero, y madera
    rojiza con cobre.
  - Lo que salió mal en la primera versión: las púas eran largas y rectas,
    como una corona de rey. Las de la retail son cortas y abiertas hacia
    fuera.

- **Escudo** (grupo «escudo»: 2019). Hoja: `kit-arena9-escudo.png`.
  - `round_shield`: un escudo redondo y abombado, de unos 0,8 m. Se apoya
    de canto contra un pilar, muy echado hacia atrás (55°), con la cara
    hacia +z.
  - Lleva un aro enrollado, la banda de fuera en cuñas claras y oscuras
    alternas, un aro dentado en relieve y una bolla en el centro.
  - Looms: bronce con verdín (retail), hierro y cobre.
  - Lo que salió mal en la primera versión:
    - Iba casi de pie (22°), y en la retail se ve desde arriba.
    - Los nervios eran rayitas sueltas.
    - La muesca rota del borde no se hace.
  - Dueño (2026-10-29): "haz más cóncavo el escudo".
    - La cúpula pasa de 10 a 22 cm de fondo.
    - Las cuñas de la banda eran cajas planas y asomaban como dientes por
      la silueta. Ahora son láminas cortadas al perfil de la cúpula, que
      siguen la curva.

- **Trozo de roca** (grupo «trozo de roca»: 1637). Hoja:
  `kit-arena9-trozo-de-roca.png`.
  - `rock_chunks`: cuatro cascotes claros de 0,2 a 0,4 m y una miga, medidos
    en el sprite con la ayuda `pebble`. Son más grandes y más blancos que
    las roquitas.
  - Lo que salió mal en la primera versión: con el granito de la arena 6 se
    veían grises. Ninguna loom de piedra es tan clara (el tinte solo
    oscurece), así que van en color de paleta. El primer color era casi
    blanco bajo nuestra luz; se bajó a un crema apagado.

- **Látigo** (grupo «látigo»: 2020). Hoja: `kit-arena9-latigo.png`.
  - `coiled_whip`: un látigo recogido de unos 1,4 m, colgado de una
    clavija en la pared, con la misma convención que el hacha de la 2481:
    la pared es el plano x = 0, mirando a +x, e y = 0 es el suelo.
  - Lleva cuatro vueltas gruesas de cuero, el mango rojo colgando a la
    izquierda y tres colas con nudos de latón que caen casi hasta el suelo.
  - Looms: cuero rojizo (retail), cuero negro y cuerda parda.
  - Lo que salió mal en la primera versión:
    - El rollo era un alambre fino, y en la retail es un manojo grueso.
    - El mango flotaba suelto; ahora cuelga de un tramo de cuero.
    - La clavija era diminuta.
    - El cuero salía anaranjado.

- **Sangre de pared** (grupo «sangre de pared»: 2443). Hoja:
  `kit-arena9-sangre.png`.
  - `wall_blood`: una salpicadura a unos 0,6 m con gotas sueltas, cuatro
    chorretones que bajan por el muro y un charco al pie, que sale un poco
    al suelo.
  - En la retail va debajo del látigo. Usa la misma convención de pared
    (plano x = 0 mirando a +x) y los colores de sangre del desagüe: sangre
    roja, icor negro y limo verde.
  - Lo que salió mal en la primera versión:
    - El charco era rojo vivo; ahora es oscuro y solo el centro brilla un
      poco.
    - Los chorretones parecían postes iguales; ahora tienen anchos y largos
      distintos.
- **Arena 9 completa**: `map_sheet.py 40 9` da 40 piezas y 0 nuevas.
- Dueño (2026-10-29): creía que el látigo (2020) y la sangre de pared
  (2443) se habían pasado a VFX en arenas anteriores. No están en la lista
  `vfx` de `gfx_rules.json` ni en los sprints; la sangre del suelo se
  modeló en la arena 7. Dueño: "si no lo encuentras pues sigue con el
  pipeline normal". Se modelan como los demás grupos.

Kit nuevo `godot/art/arena10/` (cocina del carnicero, mundo 41). Su desagüe
y sus hachas ya están en el kit de la arena 9.

- **Losa de ladrillos** (grupo «losa de ladrillos»: 2736; es el suelo de la
  arena y sale 203 veces). Hoja: `kit-arena10-losa.png`.
  - Loom nueva `paver` (`arena10/kit.tx.js`): barro cocido liso, con nubes
    de tono, roces y desconchones medianos, grano fino y algún poro. Es
    clara, y el modelo la tiñe. Looms: ladrillo crema (retail), pizarra gris
    y terracota.
  - `brick_slab`: una losa fina (`tile`, se pisa a 0,1 m) con tres por tres
    ladrillos cuadrados y acolchados, más oscuros en el borde. Las juntas
    son claras. Una de ellas lleva la línea de rayitas oscuras que pinta la
    retail. Debajo irán los postes de madera (984, 985).
  - Lo que salió mal en la primera versión:
    - Los ladrillos eran tacos de bordes biselados, por ir sin normales
      suaves. Ahora el material es `soft*` y la esquina más redonda.
    - Salía un 20 % más clara y más amarilla que la retail. El amarillo
      venía del tinte y de nuestra luz cálida; ahora el tinte es casi
      neutro.
    - Los ladrillos quedaban pequeños, con juntas anchas, porque el borde
      del cojín se hundía bajo la junta. Ahora llenan la casilla como en la
      retail.
    - El canto de la losa salía blanco; ahora va en sombra.

- **Postes de madera** (grupo «poste de madera»: 984 y 985; 95 usos). Son
  los bloques que sostienen el suelo, y la losa de ladrillos va encima.
  Hoja: `kit-arena10-postes.png`.
  - La `brick_slab` pasa a `cap`: y = 0 es la cara de arriba del poste.
  - Usan las tablas de la arena 6 (`board` y `boardV`), teñidas. La loom a
    sale de la tabla gris templada: pardo gris (retail), gris y rojiza.
  - `wood_post` (984): un bloque de 1,5 m que llena la casilla. Arriba lleva
    una viga grande, con la cara de arriba en dos tablas; abajo, una hilada
    de cuatro tacos. Tiene una grieta en la cara +z.
  - `wood_post_alt` (985): la hilada de abajo más baja, la viga partida en
    la cara +x y tres tablas arriba.
  - Lo que salió mal en la primera versión:
    - Las juntas no se veían: las piezas se tocaban. Ahora hay un hueco
      oscuro entre ellas.
    - Era amarillo miel; la retail es parda gris.
    - Era un 9 % más estrecho que la retail, que llena la casilla de borde a
      borde.

- **Río de sangre** (grupos «alfombra» 2458, «río de sangre» 2461, 2465 y
  2470–2472, y «cascada de sangre» 474 y 2459). Hojas:
  `kit-arena10-sangre-1.png` … `-3.png`.
  - Loom nueva `blood` (`arena10/kit.tx.js`): líquido espeso y brillante,
    con remolinos lentos, ondas y un brillo fino. `bloodFlow` es la misma,
    estirada en chorretones para las caídas. Looms: sangre roja (retail),
    icor negro y limo verde, como el desagüe de la arena 9.
  - `blood_river` (2458): la «alfombra» roja es el río. Es una casilla de
    sangre de borde a borde, así que varias seguidas forman el río.
  - `blood_gutter` (2461, 2472) y `blood_gutter_corner` (2465, 2470,
    2471): en el mapa, las uniones son una canaleta de sangre sobre el suelo
    que acaba vertiendo al río. Van sobre la losa (`flat`): sangre entre dos
    bordillos de la piedra clara de la losa, en recto o en escuadra, y se
    encadenan.
  - `blood_stream` (2459): el chorro fino de unos 1,3 m que cae de la
    canaleta, con su salpicadura y gotas.
  - `blood_fall` (474): una casilla del río que vierte por su lado +x y cae
    unos 5,5 m por el borde de la isla, oscureciéndose en cuatro bandas. La
    retail la pinta verde y el mapa la tiñe de rojo.
  - Lo que salió mal en la primera versión:
    - Salían manchas negras en el río: el relieve se hundía por debajo del
      cuerpo.
    - La canaleta era un hilo; ahora es más ancha y con bordillos más
      altos.
    - El chorro era una tubería oscura y la cascada, tubos de órgano. Ahora
      el chorro es más ancho y claro, y la cascada una lámina con bultos
      suaves.
    - Al escalar un `tube`, kiln escala también sus puntos, y los rollos de
      la cascada se separaban 1,4 m. Ahora se hacen en z = 0 y se mueven
      después.

- **Jaulas** (grupo «jaula»: 2738, 2739, 2741, 2745, 2751 y 1437). Hojas:
  `kit-arena10-jaulas-1.png` y `-2.png`.
  - Tablas de la arena 6 teñidas: madera oliva (retail), gris y oscura.
    Las barras, los clavos, la paja y los pollos van en colores de paleta.
  - `cage` (2738, 2741): una jaula baja, algo más ancha que la casilla.
    Tres tablones gruesos de suelo y tres de tapa, ocho barras redondas y
    oscuras, y dos clavos gordos en cada punta de tablón. La 2741 es la
    misma jaula girada 90°.
  - `cage_chicken` (2739, 2745): la misma, con un pollo redondo dentro
    (amarillo; en las looms b y c, gallina blanca y parda).
  - `cage_open` (2751): una jaula más alta y estrecha. Lleva barras con dos
    travesaños, una banda de tablas arriba con la boca abierta, la tapa
    levantada sobre dos bisagras naranjas, paja y dos pollos.
  - `cage_broken` (1437): el suelo entero, la tapa resbalada y apoyada hacia
    +x, una barra en pie y dos caídas.
  - Lo que salió mal en la primera versión:
    - Faltaban las looms b y c, y la foto falló.
    - Los tablones iban en el otro eje, eran finos y las barras largas.
    - La madera salía mostaza; ahora sale de la tabla gris templada.
    - La tapa de la jaula abierta era enorme; ahora son dos tablas de medio
      metro.

- **Mesa y mantel** (grupos «banco» 1593 y «mantel» 2651). Hoja:
  `kit-arena10-mesa.png`.
  - `low_table` (1593): el «banco» es la mesa baja de las mesas con
    mantel. Lleva un tablero grueso de tres tablas, algo más ancho que la
    casilla, sobre cuatro patas cuadradas hechas de dos tablas cada una.
    Mide 0,5 m. Va en las tablas grises de la arena 6, teñidas: oliva
    (retail), gris y parda.
  - `tablecloth` (2651): un mantel de cuadros sobre el tablero de la mesa
    (y = 0 es el tablero), que cuelga por el lado +x casi hasta el suelo,
    algo abierto y con el bajo deshilachado. Loom nueva `cloth`
    (`kit.tx.js`): algodón de cuadros grandes, con trama fina, arrugas y
    alguna mancha. Looms: cuadros rojos (retail), azules y verdes.
  - Lo que salió mal en la primera versión: las patas eran altas y el
    tablero fino, con la tabla del medio más oscura.
- **Embutidos** (grupo «embutidos»: 2744, 2743 y 2742). Hojas:
  `kit-arena10-embutidos-1.png` y `-2.png`.
  - Loom nueva `pine` (y `pineV`, con la veta vertical): pino dorado y
    brillante para las cajas. Ninguna tabla de las arenas anteriores era
    tan clara, y el tinte solo oscurece. Looms: pino dorado (retail),
    fresno claro y madera teñida oscura.
  - Piezas de carne compartidas, para usarlas también en los platos, la
    pierna y el tocón: jamón (`ham`), ristra de salchichas (`sausages`),
    filete (`steak`) y hueso con nudos (`knuckleBone`). El montón
    (`meatHeap`) junta tres jamones, dos filetes, un hueso y salchichas.
    Looms de la carne: fresca (retail), asada y curada.
  - `meat_crates` (2744): dos cajas doradas apiladas. La de arriba va
    llena de carne y tiene sangre en el frente; una ristra cuelga por el
    lado +x.
  - `meat_crates_spilled` (2743): las mismas, con un jamón caído contra el
    frente, salchichas en el suelo y un charco.
  - `meat_basket` (2742): una cesta de mimbre redonda llena de carne, con
    sangre debajo y una salchicha caída.
  - Lo que salió mal en la primera versión:
    - Las cajas salían oliva con la tabla de la arena 6.
    - Los jamones medían 10 cm y no se veían: el montón eran solo filetes.
- **Costillares** (grupo «costillar»: 2747, 2748 y 234). Hojas:
  `kit-arena10-costillar-1.png` y `-2.png`.
  - Ayuda `rib`: un hueso curvo que se afina, hecho de tramos de lathe
    encadenados, como el cuerno de la arena 8. `spine` es una fila de
    vértebras.
  - `ribcage` (2747): un costillar grande tumbado, de 1,1 m. La columna va
    en el horizontal de la pantalla y siete costillas suben en dos filas y
    se curvan hacia atrás, como lo dibuja la retail. Lleva un trozo de
    cartílago rosa en la cola.
  - `ribcage_small` (2748): uno pequeño y plano, como una espina de pez,
    con un hueso suelto al lado.
  - `ribcage_standing` (234): uno pequeño de pie sobre las puntas de las
    costillas, como una araña.
  - Lo que salió mal en la primera versión:
    - Las costillas eran finas y paralelas, como un peine.
    - Al curvarlas hacia la cámara se tapaban unas a otras. La retail las
      pinta barridas a lo largo de la columna, así que se colocan en ejes
      de pantalla.
    - El de pie tenía las costillas hacia arriba y no tocaba el suelo.

- **Losas manchadas, piernas, cajas, trampa, colmillos, pinchos y
  barriles** (grupos «losa manchada» 1385 y 1466, «pierna» 2758 y 2759,
  «caja rota» 2740, «caja» 1620, «trampa de suelo» 2479, «colmillos»
  2593, «pinchos» 2072 y «barril» 832 y 1855). Hojas:
  `kit-arena10-grasa-piernas-1.png` y `-2.png`, `kit-arena10-cajas.png`,
  `kit-arena10-trampa-colmillos-pinchos-1.png` y `-2.png`, y
  `kit-arena10-barriles.png`.
  - Las piezas pequeñas van en colores de paleta (`MISC`): la loom a es la
    retail; la b, más oscura, y la c, más cálida.
  - `grease_stain` (1385) y `grease_stain_small` (1466): la «losa
    manchada» es grasa amarilla derramada sobre la losa (`flat`). Son
    salpicaduras redondas que se solapan, cada una con un borde oscuro; la
    grande forma un anillo y la pequeña, una mancha.
  - `severed_leg` (2758): una pierna de pie dentro de su bota, de unos
    0,8 m, con la piel pálida, el corte rojo y el hueso fuera.
    `severed_leg_lying` (2759): la misma, caída, con sangre en el corte.
  - `bone_box` (2740) y `tall_box` (1620): cajas de pino claro con un marco
    de vigas, paneles de tablas hundidos y un perno en cada unión (ayuda
    `frameBox`). La rota va abierta, con huesos y carne dentro y sangre por
    la cara +z. La alta mide 1,3 m y tiene la tapa hundida en el marco.
  - `bear_trap` (2479): un cepo abierto, con un aro de acero y dientes,
    las mandíbulas y la placa en medio.
  - `tusks` (2593): cinco colmillos grandes juntos en el suelo, casi de pie
    y algo curvados (ayuda `rib`, en ejes de pantalla).
  - `stakes` (2072): cinco estacas afiladas clavadas en el suelo.
  - `barrel_tap` (832): un barril tumbado sobre dos calzos, con duelas
    naranjas, aros de hierro y un grifo en el extremo +x.
  - `soup_tub` (1855): una tina ancha de madera con sopa verde, un aro de
    hierro, un cucharón dentro y un trapo blanco en el borde -x. Looms de
    la sopa: verde (retail), estofado y caldo rojo.
  - Lo que salió mal en la primera versión:
    - La grasa era amarilla chillona, en gotitas sueltas.
    - El cepo y las estacas eran pequeños.
    - Los colmillos salían tumbados hacia los lados; los de la retail
      suben casi rectos y son gruesos.
    - La caja alta tenía la tapa al ras del marco.

- **Herramientas, platos, ratas y braga** (grupos «herramientas» 1636,
  2102 y 2580; «plato» 2525, 2531 y 2581; «comida» 2363; «rata muerta»
  1634 y 2762; «braga» 1719). Hojas: `kit-arena10-herramientas-1.png` y
  `-2.png`, `kit-arena10-platos-1.png` y `-2.png`, y
  `kit-arena10-ratas-braga-1.png` y `-2.png`.
  - Todo en colores de paleta (`MISC`).
  - `mallet` (1636): una maza grande de madera clara, tumbada.
    `tongs` (2102): tenazas de herrero de pie sobre la boca redonda, con
    los brazos en V, de hierro con verdín y manchas de óxido.
    `hammer_spanner` (2580): un martillo y una llave cruzados en el suelo.
  - `plate_bones` (2525): un plato de barro con salsa, las costillas de un
    asado en arco y un tenedor clavado de pie. `plate_leftovers` (2531):
    un plato de madera con lechuga, puré y zanahoria. `liquor_plate`
    (2581): una botella de licor en forma de calabaza, un vasito y un
    platito. `steak_platter` (2363): un chuletón sobre lechuga, con un
    cuchillo clavado. Usan las piezas de carne compartidas.
  - `rat_skinned` (1634): una rata pequeña despellejada, enroscada, con
    sangre. A mí el sprite me parece un cerebro; lo he hecho como dice el
    dueño, y se cambia si hace falta.
  - `rat_dead` (2762): una rata gorda de lado, con las patas arriba, cruces
    en los ojos y la cola rosa.
  - `knickers` (1719): una braga blanca en el suelo.
  - Lo que salió mal en la primera versión: todo salía a dos tercios del
    tamaño retail. Estas piezas dibujan la comida y las herramientas más
    grandes de lo real, así que se escalaron al sprite.
- Dueño (2026-10-29), mientras hacía estos grupos: "he ido viendo tus
  fotos y todo perfecto".

- **La cocina y las piezas sueltas** (grupos «tocón de carnicero» 2476,
  «parrilla» 2539, «fogón» 2540, «delantales» 2749, «ardilla» 2754, «mano
  de piedra» 2756, «jarrón» 2761, «persona sin cabeza» 2763 y «calavera»
  2764). Hojas: `kit-arena10-cocina-1.png` y `-2.png`, y
  `kit-arena10-sueltas-1.png` … `-3.png`.
  - `butcher_block` (2476): un tocón bajo de madera oscura que llena la
    casilla, de unos 0,55 m, con la cara de arriba forrada de chapa
    manchada. Encima lleva un trozo de carne erizado de huesos, una cuchilla
    de mango rojo y dos ganchos; la sangre baja por la cara +z.
  - `grill` (2539): un marco bajo de tablas claras sobre cuatro patas, con
    brasas dentro (palette `ember`, que brilla), una parrilla de alambre
    encima y el mango redondo de madera hacia +x.
  - `spit_hearth` (2540): un cuenco de ceniza con brasas entre dos huesos
    de pie, y un espetón a lo largo de x con el esqueleto de un animal y
    una manivela en el extremo +x.
  - `aprons` (2749): dos delantales, azul y pardo, colgados de una clavija
    en la pared, con la misma convención de pared que el látigo.
  - `squirrel_rug` (2754): una ardilla aplastada como una alfombra, con la
    cola enroscada y cruces en los ojos.
  - `stone_hand` (2756): un antebrazo y una mano de piedra clara,
    tumbados, con manchas de musgo.
  - `pickle_jar` (2761): un tarro de cristal con trozos claros en conserva
    y la tapa atada con un cordel rojo.
  - `headless_knitter` (2763): una mujer robusta sin cabeza en una
    mecedora. Lleva vestido azul y delantal blanco con un corazón bordado,
    los brazos pálidos en los apoyabrazos y zapatillas rosas, y el ovillo se
    le ha caído al suelo. Mira hacia +x.
  - `skull_blood` (2764): una calavera amarillenta en un charco de sangre.
  - Lo que salió mal en la primera versión:
    - El tocón era alto y de madera clara.
    - Los huesos del fogón eran finos y las costillas apuntaban a un lado.
    - La ardilla, el tarro y la calavera eran pequeños.

- Dueño (2026-10-29): "en headless knitter usa las skills para mejorarlo,
  con skull_blood igual, los aprons también. El resto está ok". Hojas:
  `kit-arena10-mejoras-1.png` y `-2.png`.
  - Tres looms nuevas en `kit.tx.js`, claras para teñirlas: `linen`
    (algodón gastado, con trama fina, arrugas, suciedad en los pliegues y
    alguna mancha desvaída), `knit` (punto, en columnas de lazadas) y
    `boneTex` (hueso viejo, con manchas amarillentas, poros y grietas
    finas).
  - `headless_knitter`: rehecha y girada para mirar a +z, como la dibuja la
    retail.
    - La mecedora tiene balancines curvos, patas torneadas, el respaldo
      alto con pomos, un travesaño curvo y tres tablillas, y brazos que
      acaban en voluta.
    - El cuerpo es un torso de lathe robusto, con el escote pálido y mangas
      abullonadas. Los brazos son grandes y pálidos, sobre los
      apoyabrazos, con los antebrazos hacia el regazo.
    - Lleva la falda en pliegues hasta las rodillas y el delantal blanco
      con el bajo roto. En las manos tiene el punto verde con un corazón
      naranja y dos agujas, y la lana baja hasta el ovillo.
    - Las piernas son gruesas y calza zapatillas de conejo con orejas y
      ojos. Vestido, piel y calavera van en materiales `soft*` (normales
      suaves en el juego).
  - `skull_blood`: un cráneo redondo con arcos de las cejas, cuencas
    hundidas llenas de sangre, la nariz, los pómulos y la fila de dientes
    de arriba, sin mandíbula. Está volcado de lado, con la cara hacia la
    cámara, en un charco de contorno suave con la textura del río.
  - `aprons`: cada delantal cuelga de su gancho de cuerno, con dos tirantes.
    El peto y la falda son una tela con pliegues suaves (ayuda
    `clothPanel`: un `terrain` puesto de pie, con los pliegues más hondos
    hacia el bajo). Llevan cintas sueltas en la cintura, el bajo roto en
    lengüetas y un bolsillo.
  - Lo que salió mal en esta vuelta:
    - Al escalar un `tube`, el travesaño del respaldo se iba volando y los
      brazos de la silla se separaban. Los tubos ya no se escalan.
    - Los pliegues hechos con tiras parecían tablones. Ahora son un
      `terrain` con normales suaves.
    - Las manchas de la `linen` salían como lunares oscuros por todo el
      vestido; ahora son la mitad de fuertes.
    - La calavera era un huevo con una caja por cejas.
- Dueño (2026-10-29): "mejora los brazos de la mujer", "y las
  piernas/falda". Hoja: `kit-arena10-mejoras-1.png`.
  - En la retail, los brazos son enormes y blandos: el de arriba cuelga
    por fuera del apoyabrazos y el antebrazo descansa sobre él.
  - Ayuda nueva `capsule`: una cápsula lisa (lathe con los extremos
    redondos, algo más gruesa en el centro) orientada entre dos puntos, un
    tramo por segmento. Así un brazo o una pantorrilla gordos se leen como
    una sola forma blanda, y solo se marca el pliegue del codo o de la
    rodilla.
  - Los brazos cuelgan gruesos y los antebrazos van por el apoyabrazos.
    Las manos son rechonchas, con tres dedos cortos curvados sobre las
    agujas y el pulgar encima.
  - Las piernas son gruesas y abiertas: el muslo bajo la falda y la
    pantorrilla hasta la zapatilla, que también es más grande. La falda es
    una campana sobre las rodillas con el bajo roto en lengüetas, y el
    delantal blanco cae en pliegues por delante, con el bajo roto.
  - Lo que salió mal antes de quedar así:
    - Con esferas encadenadas, los miembros salían anillados, como un
      muñeco Michelin, y con 52.000 triángulos.
    - Con cilindros y una esfera en cada articulación, las normales suaves
      del juego marcaban bultos de culturista.
    - Ahora son 8.100 triángulos.
- Dueño (2026-10-29): "mejor deja las manos estiradas y mira la ropa de
  los pies". Hoja: `kit-arena10-mejoras-1.png`.
  - Las manos van planas y estiradas: cuatro dedos cortos y rectos que
    siguen la dirección del antebrazo sobre el regazo, y el pulgar abierto
    hacia el centro.
  - Las zapatillas de la retail son de gato, no de conejo. Ahora tienen
    una cabeza redonda en la punta, orejas de gato en punta con el interior
    rosa oscuro, los ojos cerrados en dos rayitas, la nariz y una cola
    fina que se enrosca en el talón.
- Dueño (2026-10-29): "no, lo haces mal", con la foto marcada en el
  regazo, y "el brazo te dije colgando".
  - Fallaban dos cosas:
    - El regazo era un lío: el punto de pie, un delantal pequeño y los
      muslos asomando.
    - Los brazos los había llevado al regazo, y el dueño los pidió
      colgando.
  - Ahora una tela blanca ancha cubre todo el regazo. Es una cúpula
    (lathe) sobre los muslos que cae por todos lados hasta un bajo roto en
    picos irregulares, y bajo ella asoma la falda azul.
  - El punto verde va plano encima, hacia las rodillas, con un corazón
    naranja (dos lóbulos y un cuadrado girado para la punta) y las dos
    agujas.
  - Los brazos cuelgan rectos por fuera de los apoyabrazos, con las manos
    abiertas y los dedos estirados hacia abajo (ayuda `hangingHand`).
  - Lo que salió mal en esta vuelta:
    - El lathe de la tela, con el perfil de dentro hacia fuera, salía del
      revés y se veía como un borde vacío.
    - Los lóbulos del corazón quedaban bajo la barriga, y desde arriba solo
      se veía la punta.
- Dueño (2026-10-29): "la parte blanca forma parte de la bata/pijama,
  así que no la dejes cuadrada, tiene que estar pegada a las piernas", y
  la tela "atrapa la madera del reposabrazos".
  - La cúpula blanca se quita. Ahora la tela del camisón se pega a cada
    muslo (una cápsula algo más ancha que la pierna), cae un poco por
    encima de la rodilla y se hunde entre las dos piernas. Va por debajo
    de los apoyabrazos.
  - En cada rodilla, el bajo roto son picos que se pegan a la pierna (ayuda
    `hemRing`, sobre un arco de la rodilla). La falda azul asoma solo por
    fuera de cada rodilla.
  - El punto con el corazón va plano sobre los muslos.
- Dueño (2026-10-29): "la tela de la rodilla ha quedado muy mal". Hojas:
  `kit-arena10-mejoras-1.png` y, de cerca, `kit-arena10-mujer-cerca.png`.
  - Fallaban tres cosas:
    - El bajo era una corona de triángulos separada de la pierna, como
      banderines.
    - La ayuda `capsule` adelgazaba los tramos más cortos que sus dos
      radios: el redondeo de las puntas ocupaba todo el tramo y la manga de
      la rodilla casi desaparecía. Ahora redondea, como mucho, medio tramo.
    - La parte de arriba de la pantorrilla asomaba por la rodilla.
  - Ahora la tela baja de una pieza: del muslo a una manga recta (lathe)
    que cubre la rodilla y el principio de la espinilla. El bajo roto son
    solapas planas pegadas a la manga y solapadas entre sí (ayuda
    `hemFlaps`). Por fuera de cada rodilla asoman tres solapas azules del
    vestido.
- Dueño (2026-10-29): "usa el color de piel más oscuro para que veas el
  contraste". La piel pasa a crema tostada (retail), rosa tostado y morena
  (`pale` y `softPale`), y la tela blanca del camisón ya se separa de las
  piernas.
- **Arena 10 completa**: `map_sheet.py 41 10` da 76 piezas y 0 nuevas.

Arena 11 (mundo 42, selva), kit nuevo `godot/art/arena11/`, todos los grupos
de una vez (dueño: "hazlo todo de golpe"). Fotos en
`capturas/m7/kit-shots/arena11`. La piedra de las ruinas usa la loom
`stoneMoss` de la arena 6; el resto, colores de paleta en tres looms.

- **Hierba fina** (1751, 1752, 1753, 2784). Hoja:
  `kit-arena11-hierba-fina-1.png` y `-2.png`.
  - Ayuda `fineBlade`: una hoja larga en forma de lanza, doblada por el
    nervio, con una mitad más clara (como la pinta la retail) y el pie más
    oscuro. `fineTuft` las abre en abanico: cuanto más lejos del centro,
    más se inclinan hacia fuera.
  - `grass_fine` (1751), `grass_fine_tall` (1752), `grass_fine_low`
    (1753) y `grass_fine_broad` (2784, de hoja ancha: verdes detrás,
    oliva delante, las del centro más altas). Looms: verde lima (retail),
    verde oscuro y oro de otoño.
  - Lo que salió mal en la primera versión:
    - Las hojas eran finas como cerdas y tenían una banda oscura en el pie.
    - Inclinadas hacia dentro: el giro en z iba al revés. Después se
      tumbaban del todo, porque se sumaban la inclinación y la curva.
- **Enredaderas** (grupo «planta»: 2768, 2769, 1788, 1791). Hojas:
  `kit-arena11-enredaderas-1.png` y `-2.png`.
  - Ayudas `leafAt` (una hoja de corazón, flecha o lanza en la dirección
    de pantalla que se le pida, girada sobre su nervio para mirar a la
    cámara), `sprig` (la hoja en su rabillo), `stem` (un tallo por puntos),
    `tendril` (zarcillo en espiral) y flores blancas de tres pétalos y
    turquesa de cinco.
  - `vine_heart` (2768, 3 m), `flower_vine` (2769, 3,3 m, flores
    turquesa), `vine_tall` (1788, 4,3 m) y `vine_crowns` (1791, dos matas
    de tallos con copa de hojas). Looms: flores blancas y turquesa, rosas y
    violeta, crema y naranja.
  - Lo que salió mal: las hojas se veían de canto, como pinchos. La
    dirección de pantalla estaba girada 90° (la hoja "a la derecha"
    apuntaba a la cámara); ahora cada hoja se orienta con su cara hacia la
    cámara. Además, las hojas eran estrechas y estaban pegadas al tallo.
- **Plantas carnívoras y palmeras oscuras** (grupo «planta»: 2770, 2772,
  2773, 2774, 2775). Hojas: `kit-arena11-carnivoras-1.png` … `-3.png`.
  - En el mapa retail están en el borde, casi negras: es la luz del mapa,
    no el color de la planta.
  - Ayudas `frond` (hoja larga en tramos que se doblan hacia abajo),
    `whorl` (un paraguas de hojas en la punta de un tallo), `pod` (la vaina
    que muerde: un huevo oliva con manchas claras, la boca oscura debajo,
    colmillos de marfil, dos cuernos y un zarcillo) y `litter` (hojas secas
    en el suelo).
  - `snap_plant` (2770), `snap_plant_three` (2772), `snap_plant_low`
    (2773), `dark_palm` (2774, con un paraguas de hojas pálidas) y
    `dark_palm_small` (2775). Looms: hojas pardas con vainas oliva (retail),
    verde selva con vainas rojas y carmesí con vainas violeta.
  - Lo que salió mal: las vainas miraban hacia atrás y eran pequeñas; las
    hojas, finas como estrellas y de un naranja chillón.
- **Calas, helecho y brotes** (2776, 2777, 2145–2148, 2781–2783). Hojas:
  `kit-arena11-calas-helecho-abanico-1.png` y `-2.png`.
  - `calla_pair` (2776) y `calla` (2777): una roseta de hojas pardas
    tumbadas y tallos largos con la espata verde oscura y el espádice azul.
  - `fern_sprig` (2145, 2146, 2147 y 2148, que son la misma planta):
    tallos en zigzag de 1,6 m con tres hojitas en punta en cada codo, sobre
    hierba oliva.
  - `fan_sprouts` (2781–2783): el dueño creía que eran la planta muerta
    1706, pero ampliadas son dos palmitas de abanico sobre un tallo
    rastrero. Las tres retail son la misma pieza en amarillo, verde y
    morado: las looms a, b y c. Se quita el `same` con 1706.
  - Lo que salió mal: la roseta de las calas era un cuenco; los brotes
    medían el doble; las hojitas del helecho eran redondas.
- **Raíces con pinchos** (2599, 2601, 2602, 2604, 2605 y 2600). Hojas:
  `kit-arena11-raices-1.png` y `-2.png`.
  - Ayudas `spline` (curva suave por puntos de pantalla) y `thornRoot`
    (raíz que se afina, con un cuello donde sale del suelo y pinchos crema
    hacia fuera de la curva).
  - `thorn_arches` (2599, 2605), `thorn_row` (2601), `thorn_tangle`
    (2602, 2604) y `thorn_stub` (2600). El dueño puso el 2600 con las
    hojas secas; ampliado es un trozo de raíz con pinchos, roto.
  - Lo que salió mal: las raíces eran finas y los pinchos, enormes; las
    juntas de los tramos se veían como bultos.
- **Piedras de las ruinas** (grupos «tótem de roca» 2323, 2326, 2329 y
  «roca con pintura» 2324). Hojas: `kit-arena11-piedras-1.png` y `-2.png`.
  - `stone_skull` (2326): una roca de ocho caras con la cara +z tallada
    como una calavera (ojos cuadrados con marco claro, cuatro dientes) y un
    arco en la cara +x. `carved_block` (2323): un bloque con una espiral
    grande en la cara +x y dos bloques caídos delante. `carved_block_small`
    (2329): un meandro arriba y dos ranuras. `painted_rock` (2324): una
    roca en forma de huevo con espirales pintadas.
  - Lo que salió mal: el bloque salía en rombo (el lathe de cuatro caras
    ya es un cuadrado sin girarlo), y los paneles tallados flotaban por
    encima porque las cajas se apoyan en su base, no en su centro.
- **Sueltas** (2779, 2771, 1601, 2159). Hoja: `kit-arena11-sueltas-1.png`
  y `-2.png`.
  - `leaf_litter` (2779) y `leaf_litter_small` (2771): hojas secas pardas
    tumbadas (`flat`). `skull_stake` (1601): una calavera en una estaca de
    1,2 m. `dry_stalk` (2159): un tallo seco de 2,3 m que se dobla a la
    izquierda, con hojas verdes redondas al pie.
- **Arena 11 completa**: `map_sheet.py 42 11` da 0 nuevas.
- Dueño (2026-10-29): "todo ok". Arena 11 aprobada.

Arena 12 (mundo 44, pantano), kit nuevo `godot/art/arena12/`, todos los
grupos de una vez, como la 11. Fotos en `capturas/m7/kit-shots/arena12`.
Looms propias en `arena12/kit.tx.js`: `peat`/`peatSide` (cojines de musgo,
y el mismo musgo estirado en vetas para los lados), `mud` (barro con
crestas pálidas que serpentean y surcos mojados) y `duckweed` (frondas
redondas apretadas). Las tablas usan la loom `board` de la arena 6; lo
demás, colores de paleta en tres looms.

- **Suelo** (619, «losa de tierra» 2654–2656, 2692, «losa de barro» 1501,
  2657, 2659, 2660). Hoja: `kit-arena12-suelo-1.png` … `-3.png`.
  - `peat_block` (619, `tile`, 1 m): el bloque de debajo de cada casilla,
    de turba con musgo ocre; arriba, cojines de musgo que se salen un poco
    del borde.
  - Las losas son `cap` sobre él. Ayuda `pillow`: un cuerpo de esquinas
    redondeadas y un campo de alturas inscrito dentro (sus esquinas no
    asoman por los arcos).
  - `earth_slab_grass` (2654 y 2655, que solo mueven las hojas),
    `earth_slab_sparse` (2656) y `earth_slab_half` (2692): un labio alto
    alrededor y hierba de pantano en el hueco. El 1501, que el dueño puso
    en «losa de barro», es el mismo dibujo que el 2692: va en esa pieza.
  - `mud_slab` (2657 y 2660, iguales) y `mud_slab_drip` (2659): una cúpula
    de barro con tres crestas que serpentean; la segunda gotea crema por los
    bordes de delante.
  - Lo que salió mal en la primera versión:
    - El musgo parecía empedrado (juntas negras) y muy amarillo.
    - Las losas eran finas y planas, con el lado de "adoquines".
    - Hacer losa y lados con una sola malla dejaba una placa visible en el
      suelo alrededor; se cambió a `pillow`.
    - Las gotas de 2659 parecían una valla.
- **Líquido verde y charco** (2662–2664, 2666, 2667, 2627, 2630, 2632,
  2661). Hoja: `kit-arena12-liquido-1.png` … `-4.png`.
  - `duckweed_patch` (2666), `duckweed_patch_dense` (2662, 2664),
    `duckweed_ring` (2663, un corro con agua libre en medio) y
    `duckweed_bits` (2667): manchas de contorno blando con frondas sueltas
    alrededor (`flat`).
  - `tendril_s` (2627), `tendril_loop` (2630) y `tendril_curls` (2632):
    zarcillos planos flotando, como cintas aplastadas.
  - `murky_puddle` (2661, «mancha o líquido»): agua turbia con brillos en
    los bordes del fondo.
  - Lo que salió mal: la lenteja parecía ruido de televisión (textura muy
    fina y chillona) y los zarcillos eran hilos; el de 2627 iba de pie.
- **Tocones con setas** (2678–2682). Hoja: `kit-arena12-setas-1.png` y
  `-2.png`.
  - 2681 y 2682 son 2678 y 2679 a la sombra del borde: la luz del mapa, no
    otra planta.
  - `mushroom_stump` (2678, 2681), `mushroom_stump_tall` (2679, 2682) y
    `mushroom_stump_low` (2680): tocón verde con raíces por el suelo y
    sombreros planos apilados.
  - Dueño (2026-10-29): "en mushroom_stump hay partes flotando". Las setas
    de arriba estaban en el aire, encima del corte del tocón. Ayuda `caps`:
    una seta cuya base queda por encima del corte lleva un tallo clavado en
    él, y las de los lados muerden el tronco. Se revisaron en las vistas de
    kiln (frente, lado, arriba) todas las piezas del kit: también flotaban
    dos hojas de las cañas y la enredadera del borde.
- **Plantitas y flor blanca** (2683, 2684, 2686, 2668–2670). Hoja:
  `kit-arena12-plantas-1.png` … `-3.png`.
  - `marsh_clump` (2683), `marsh_fiddle` (2684) y `marsh_paddles` (2686):
    un cojín de musgo oscuro con bolas, palas de pie, pinchos o un brote
    de helecho.
  - `cotton_grass` (2668), `cotton_grass_small` (2669) y
    `cotton_grass_tall` (2670, 2,1 m): tallos finos que se doblan a la
    derecha, con penachos blancos de tiras que el viento echa a un lado.
  - Lo que salió mal: los penachos salían en abanico, como patas de pájaro.
- **Tablas, postes y pala** (1204, 1206, 1296, 1207, 1297, 790). Hoja:
  `kit-arena12-tablas-1.png` … `-3.png`.
  - `plank_raft` (1204), `plank_raft_wide` (1206) y `plank_raft_gap`
    (1296): dos troncos a lo largo de z, tablas cruzadas encima y una o dos
    a lo largo, con musgo.
  - `rope_posts` (1207: un poste inclinado con cuerda abajo y arriba, uno
    corto y una estaca) y `rope_trestle` (1297: dos postes bajo un
    travesaño).
  - `shovel` (790): una pala corta clavada en piedras rojas.
- **Cañas rotas y burbujas** (2673–2676, 2671, 2672). Hoja:
  `kit-arena12-canas-1.png` … `-3.png`.
  - `broken_cane` (2673), `broken_cane_tall` (2675), `broken_cane_short`
    (2674) y `broken_cane_stub` (2676): una caña gruesa partida, hueca y
    con dientes abiertos, limo verde por un lado, bolas de barro y
    burbujas al pie.
  - `mud_bubbles` (2671) y `mud_bubble` (2672): cúpulas grises de barro.
- **Enredaderas y lianas** (2618, 2619, 2621, 2624, 2625, 2649). Hoja:
  `kit-arena12-enredaderas-1.png` … `-3.png`.
  - `vine_tall` (2621, 4,3 m), `vine_loop` (2625), `vine_cut` (2618) y
    `vine_stub` (2624): tallos carnosos oliva con racimos de bayas y una
    cinta fina enroscada que acaba en gancho; los cortados enseñan anillos.
  - `vine_over_edge` (2619): un trozo cortado tumbado en el borde de la
    isla, con hojas colgando por la pared (se gira hacia el vacío).
  - `lianas` (2649): cinco hebras colgando de una pared desde su borde
    (plano x = 0 mirando a +x, como el látigo de la arena 9).
  - Lo que salió mal: las juntas de los tallos hacían bultos (las bolas de
    unión eran más gordas que las caras del tallo); la enredadera alta era
    fina abajo.
- **Arena 12 completa**: `map_sheet.py 44 12` da 54 piezas y 0 nuevas.
  Con ella están modeladas las 12 arenas de la 1.0.

Arenas 1 y 2 rehechas con el método actual (dueño, 2026-10-29: "creo que el
mapa 1, 2 y 3 fueron creados sin el pipeline con las skills"). Primero pidió
solo `rock_low`, `autumn_bush`, `autumn_bush_tall` y `basalt_rocks`;
después, todo lo que marqué como flojo. Hojas: `resumen-arena1-*.png` y
`resumen-arena2-*.png` (retail junto a la loom a; tool
`m7-referencias/kit_resumen.py`) y `revision-arena1-*`, `revision-arena2-*`
(las tres looms a escala de juego). Se revisaron las vistas de kiln de
cada pieza: nada flota.

- **Arena 2**:
  - Arbustos (1028 y familia, 1035/1021) y árbol otoñal (1029): ramilletes
    de hojas ovaladas (`spray`) sobre núcleos oscuros (`foliage`), ramas
    pálidas que asoman con ramilletes en la punta y el hueco oscuro abajo
    donde se ven los tallos. La primera versión eran bolas de hojas; la
    segunda, demasiado chillona y con huecos negros.
  - Árbol sin hojas (2558/2559): tronco pálido con nudos, tocones de ramas,
    copa partida en dos y ramitas torcidas con pocas hojas.
  - Hojas caídas: arce de puntas afiladas a tamaño retail; hierba (246):
    hojas planas anchas con bandas claras.
  - Bloque de roca marrón (1240–1244): placas angulosas en rejilla 3 × 3 en
    cada cara y arriba, el corazón oscuro en las grietas; mide 1 m (`top`
    1,02).
  - Rocas verdes (137): trece columnas hexagonales con tapa clara, alguna
    rota en bisel. Piedras blancas (611, 616): losa tallada con espirales y
    trozos alrededor.
  - Armas al tamaño retail (~1,5 veces el real): maza con púas y flecha,
    alabarda con empuñadura de tela, lanza con dos garfios, hoja de hueso
    dentada con mancha verde.
- **Arena 1 (y 3, 4)**:
  - Bloque de hielo (153): cuerpo abombado y una capa gruesa de nieve con
    bultos que cuelga por el borde. Piedra tallada (77): cubo de aristas muy
    redondeadas y cara de arriba abombada (soft). Roca tosca (104): trozos
    redondeados amontonados.
  - Puente (167) y finales (168, 169): tres tablones gruesos grises con los
    extremos biselados; herrajes claros con pernos negros; poste oscuro.
  - Valla (166, 160): postes gruesos y viga biselada, cuerda atada en tres
    vueltas con flecos; la nevada con montones redondos.
  - Pinchos (157, 159) y cristales (158): esquirlas de hielo blancas con
    caras grises (`shardAt`), más pequeñas al pie, montón de nieve.
  - Escarcha (170, 174): un cordón de nieve con esquirlas en todas
    direcciones; el cordón de hierba (138–141) es la misma forma en verde.
  - Farol (1675): cuatro patas que se juntan hacia una lámpara de piedra a
    2,1 m, dos travesaños y un escudo de tablas con pernos.
  - Montón de nieve (505), runa octogonal de pizarra con el glifo (507–510).
  - Rocas nevadas: alta (2584) de dos lóbulos, baja (2592) en cono con
    gorro de nieve; la 2586 pasa a pieza propia, `rock_small`.
  - Árbol nevado (175): 1,2 veces más grande y con la nieve en bolas.
  - Lo que salió mal: la nieve y las rocas salían 1,4–2 veces grandes; la
    textura de madera hacía rayas en el farol y las vallas (ahora colores
    lisos, como la retail); el puente tenía las tablas cruzadas.
- Dueño (2026-10-29): "ok mejor". Arenas 1 y 2 aprobadas: todos los assets
  de las 12 arenas están hechos.

### Arena 13 (mundo 45, playa), 2026-10-28 — fuera de la 1.0

- El dueño para el inventario en la arena 12. Esta queda en el archivo de
  S42, con mis suposiciones y sin sus nombres.

- `mapa-arena13-1.png` … `-11.png`: 78 piezas, 4 ya cubiertas y 74
  nuevas, con mi suposición marcada con "¿?".
- Lo que parece haber:
  - Casillas de arena que pasan a agua verde (13 gfx, 2388–2399, 2403).
    Parecen solo el color del suelo. Pregunto si son tinte o modelo.
  - Palmeras (2695–2697), corales rojos en charcos (2431, 2442, 2863,
    2864) y plantas tropicales con flores (2345–2347).
  - Vallas de postes y travesaños (2726–2733) y tablas de barco clavadas
    en la arena (2526–2529).
  - Un columpio en cinco piezas (2802–2806), tumbonas, toallas, un baúl,
    cañas de pescar, figuras de arena, conchas, cocos y peces.

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

**Hecho el 2026-10-29, pendiente de que el dueño lo pruebe.** Va en Godot
(la recomendación): los modelos y la luz se ven igual que en el combate.

    godot --path godot tools/map_editor/map_editor.tscn [-- --arena=N]

- [x] Carga la **forma** de cada arena desde la topología de combate del
      servidor (`server/data-dist/maps/`): casillas, alturas, obstáculos,
      salidas de los dos equipos y pedestales. **La forma no se toca.**
  - La rejilla (G) marca cada casilla por su papel: suelo, obstáculo (rojo),
    salida del equipo 1 (azul) y del 2 (naranja), pedestal (oro). Las
    casillas sin suelo salen en gris.
  - Un obstáculo está, en la topología, a la altura del adorno retail que
    tenía encima, así que sus piezas se apoyan en el suelo de la casilla
    vecina más baja (como en `build_map.gd`).
- [x] El dueño **coloca los assets**:
  - paleta con miniaturas: las piezas de los kits de la arena más las que
    toman prestadas (`shared`), o todas; con buscador y grupos (suelos,
    planas, decoración);
  - pincel, seleccionar, borrar y cuentagotas; clic derecho quita la pieza
    de arriba; arrastrando se pintan suelos;
  - loom a/b/c (con sus nombres del kit), girar 90° o 15°, reflejar, escala
    0,5–1,5, tinte (selector o muestras), subir/bajar y desplazar;
  - por casilla, un bloque de suelo (`tile`) y una capa (`cap`); la capa
    queda arriba y el bloque debajo. La decoración se apila en orden, y
    con Mayús+clic va encima de la más alta (el mantel sobre la mesa);
  - las columnas (`col` del kit) se rellenan solas hasta el pie del mapa;
  - "Rellenar casillas vacías" con el suelo del pincel (con giro al azar si
    se quiere), "Vaciar el mapa", deshacer y rehacer (un trazo es un paso).
  - La capa **Retail** (V) pone encima el mapa retail, semitransparente y
    alineado casilla a casilla, como referencia.
- [x] Se guarda un `layout` por arena en `godot/art/layouts/arena-NN.json`
      (Ctrl+S, y también al cambiar de arena o cerrar). Una línea por
      casilla con kit, pieza, loom, giro, reflejo, tinte, escala y
      desplazamiento; lo que va por defecto no se escribe.
- [x] La vista es la del juego: ortográfica 2:1, "Escala de juego" = casillas
      de 86 px, la misma luz que `build_map.gd` y `kit_shots.gd`.
- Código: `src/maps/arena_layout.gd` (datos: arenas, kits, forma, fichero) y
  `src/maps/arena_scene.gd` (de layout a 3D, por casilla). Los dos están en
  `src/` porque la fase D los usará en `fight_view`. `tools/art/dress.gd`
  pasa a `src/maps/kit_dress.gd` por lo mismo.
- Pruebas:
  - `test/unit/arena_layout_test.gd`: las 12 arenas tienen forma, salidas
    y paleta; alturas de bloque, capa y decoración; el fichero se lee y
    escribe sin cambios.
  - `tools/map_editor/editor_shot.gd` maneja el editor sin nadie, bajo
    xvfb: rellena, cambia looms, pone decoración, deshace, guarda fuera del
    repo y hace la captura. Pasado en las 12 arenas, sin modelos que
    falten.
- Incidente: el 2026-10-29 otra sesión de Claude se salió de su carpeta y
  escribió aquí su propio editor (`tools/arena_editor/`, `arena_kits.gd`,
  `arena_shape.gd`) y pisó `arena_layout.gd`. El dueño pidió deshacerlo: se
  quitó todo y se volvió a poner esta versión.
- Hueco de los kits, visto al probar: las arenas 6, 7, 9 y 11 no ofrecían
  bloque de suelo. Revisado contra el mapa retail (2026-10-30), no faltaban
  modelos: sus suelos son piezas de otros kits que su `kit.json` no
  compartía.
  - 6: el bloque de hierba de la 5 (solo compartía la capa).
  - 7: el bloque de tierra de la 5 debajo, y el de hierba encima.
  - 9: el pilar de piedras de la 6 hace de bloque y de muro; las losas son
    la losa de piedra de la 7 (`same`).
  - 11: el bloque de hierba de la 5 y las losas de tierra de la 7.
  - Hecho: los cuatro kits comparten ya todo lo que usa su mapa retail.
  - Dueño: "lo que no puede ser es que el bloque se quede completamente
    vacío". La 6 comparte también el bloque de tierra de la 5, para poner
    bajo los adoquines. La 9 comparte el bloque de piedra tallada de la 1,
    porque su pilar es decoración y no va bajo una losa (decisión mía).
  - La 516 y la 580 de la arena 11 son el bloque de hierba de la 5
    (dueño, 2026-10-30; `same` → 315). No hay que modelarlas.
- 2026-10-30: las arenas 7, 8, 10 y 12 comparten también lo que les
  faltaba (musgo, acantilado de la 6, runas, huesos, caja…). Con esto las
  12 arenas tienen bloque de suelo y todas sus piezas retail en su kit.
  No falta ninguna pieza por crear. Las 11 que se cubren con una pieza
  parecida están en `~/codigo/capturas/m7/piezas-parecidas.png`. Dueño
  (2026-10-30): "lo veo ok".
- Siguiente (dueño, 2026-10-30: "si hay mapas incompletos, no podemos
  seguir con la fase D"): el dueño monta las 12 arenas en
  el editor (aún no hay ningún `layout` guardado). La fase D no empieza
  hasta que las 12 estén montadas.

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

Las 12 arenas tienen un `layout` hecho por el dueño con nuestros assets, el
servidor sortea solo entre ellas y `MapGfx` retail ya no se usa. La forma
propia de las arenas y el borrado del retail van en
[S43](./S43-sin-cliente-antiguo.md).
