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
