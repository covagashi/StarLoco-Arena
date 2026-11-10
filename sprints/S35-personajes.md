# S35 — Personajes

**Planificado:** 2026-10-25 · **Abierto:** 2026-11-04 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (piloto Feca f y m hecho, a la espera del dueño)

## Alcance (lo que hoy se usa, S31)

- 12 clases × 2 sexos (24 luchadores), con un rig común.
- 9 invocaciones.
- 2 coaches (la figura del jugador).
- Las ~10 animaciones por esqueleto que fije S33 (no 8 direcciones a mano).
- Cambios de aspecto por equipo y por cosmético (S30): piezas o materiales
  intercambiables, no un dibujo por combinación.

## Orden

1. Rig y animaciones base (valen para todas las clases).
2. Las 12 clases, una por una, con su silueta propia.
3. Invocaciones.
4. Coaches y piezas de aspecto.

## Criterio de cierre

Un combate de cada clase con arte nuevo; el lector `.anm` retail ya no se
usa para luchadores.

## Decisiones al abrir (2026-11-04, delegadas; el dueño puede cambiarlas)

- **3D en vivo (técnica A de S33), no horneado a sprites.** Las arenas ya
  son 3D (`arena_scene.gd`) y se dibujan con la cámara ortográfica del
  juego; un luchador 3D con la misma luz y la misma cámara encaja sin
  costuras, gira a las 8 direcciones gratis y cambia de equipo sin
  rehornear.
- **Blender (bpy), no kiln.** Regla del dueño (2026-11-03): lo orgánico va a
  Blender, y kiln solo anima piezas rígidas; un cuerpo con piel deformable
  necesita un esqueleto con pesos.
- **Un esqueleto para todos** (luchadores, invocaciones con forma humana,
  coaches): 20 huesos — `root`, `hips`, `spine`, `chest`, `neck`, `head` y,
  por lado, `shoulder`, `upper_arm`, `forearm`, `hand`, `thigh`, `shin`,
  `foot`. El arma y el sombrero se cuelgan de `hand.R` / `head` en Godot
  (`BoneAttachment3D`), sin huesos extra.
- **10 animaciones** (la lista de S33): `idle_loop`, `walk_loop` (en el
  sitio; el juego desliza el actor), `cast`, `melee`, `hit`, `die`, `jump`
  (también teletransporte), `celebrate`, `carry_loop`, `throw`. El golpe
  blanco, el temblor y el número los pone el juego, no la animación.
- **Proporción:** la del retail (ver abajo, corrección del dueño): 1,45
  celdas con el pelo (~78 px a zoom 1), cabeza y pelo un tercio de la
  altura, cuerpo largo y delgado.

## Paso 1: rig y animaciones base (2026-11-04)

Un muñeco neutro (túnica, cinturón, botas, ojos) para ver el esqueleto y
las animaciones; no es ninguna clase.

```
blender -b -P godot/tools/blender/characters/fighter1.py       # → art/characters/out/fighter1.glb
xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot -s tools/art/anim_sheet.gd -- \
    --out=<dir> --frames=6 --dirs=SE,NW --zoom=2 --size=240x280      # o --video
python3 -I godot/tools/art/anim_sheet.py <dir> <hoja.png | video.mp4>
```

- `fighter1.py` (antes `mannequin.py`): cuerpo de esferas fundidas (remesh por vóxel, suavizado,
  decimado), cabeza aparte y rígida en `head`, pesos automáticos de Blender
  en el cuerpo. Las poses se escriben en términos del cuerpo
  (`lean`, `arm_R=(adelante, afuera)`, `knee_L`…), no en ejes de hueso.
  Cada fotograma con los pies en el suelo se corrige solo: `sole()` mide la
  bota más baja y baja o sube el `root` para que pise el suelo (sin eso, el
  reposo y el llevar hundían los pies 2–6 cm).
- `anim_sheet.gd`: carga el GLB como el juego (GLTFDocument, `kit_dress`),
  con la luz y la cámara de `arena_scene.gd`, sobre una celda de piedra.
- Medido: 20 huesos, 10 animaciones, 10.180 triángulos, GLB de 484 KB.

**Para el dueño:** `~/codigo/capturas/s35/s35-rig.mp4` (las 10 animaciones
en 4 direcciones), `s35-rig-1.png` / `s35-rig-2.png` (6 fotogramas por
animación, SE y NW) y `s35-muneco-4vistas.png`.

Lo que la primera versión hizo mal, ya corregido:
- La muerte caía de cara (signo del giro del `root`).
- Con los brazos "por encima de la cabeza" (llevar, celebrar, lanzar) las
  manos quedaban **dentro** de la cabeza: los brazos de un cabezón no
  llegan más arriba. Ahora abren en V; el que se lleva va sentado sobre la
  cabeza.
- Bordes de material dentados (caras enteras del remesh): ahora se corta la
  malla en cada altura de cambio (bisect) antes de pintar.
- La hoja usaba la luz de `promo.gd`, más fuerte que la del juego, y lo
  lavaba todo; ahora usa `ArenaScene.add_lights`.

Pendiente:
- Bajar triángulos por luchador (ver "Más acabado": hoy 21.963) (12 en pantalla, demo web en
  móviles de 2 GB, S44); la cabeza aún muestra facetas del decimado.
- Meter el actor 3D en `fight_view`: la arena se pinta **una vez** en un
  SubViewport y los actores son sprites 2D encima con un oclusor de
  profundidad (`arena_view.gd`); el luchador 3D necesita un viewport
  compartido que respete esa profundidad (el coste medido en S33 era por
  viewport y luchador).
- El dueño revisa el esqueleto y las animaciones antes de empezar las
  clases (paso 2).

### Corrección del dueño: el luchador 1, sobre el retail (2026-11-04)

| Dueño | Cambio | Fichero |
|---|---|---|
| "no me gustan los diseños, toma como referencia 1 del retail" | fuera el muñeco cabezón; el luchador 1 se rehace sobre la clase 1 retail (`fighter_-110`), solo como referencia de forma, con colores propios | `fighter1.py` |

Referencia (fuera del repo): `~/codigo/m7-referencias/s35/retail-110.png`
(×4: reposo de frente y de espaldas, andar en 4 direcciones, golpe,
muerte, hechizo, placaje). Medido en el sprite: 78 px de alto, el cuello a
un 31 % desde arriba, hombros de 11 px.

Lo que cambia respecto al muñeco:
- Cuerpo largo y estrecho (hombros a ±0,10), brazos largos hasta medio
  muslo, piernas separadas; cabeza pequeña dentro de una **nube de
  pinchos** (34 pinchos hacia fuera en todas direcciones, también bajando
  por los lados), escalada ×1,15 para que cabeza y pelo sean un tercio.
- Ropa: chaleco gris con mangas blancas, cuello dorado anudado, cinturón,
  **faldones** delante y detrás hasta medio muslo (dos paneles curvos, no
  una falda, para que las piernas no la atraviesen al andar), **bombacho**
  ancho recogido en el tobillo con tiras naranjas, botas.
- Los brazos con los brazos de llevar/celebrar/lanzar vuelven arriba: con
  brazos largos ya pasan la cabeza.

Fallos de la primera versión, corregidos:
- Puntas de pelo más finas que el vóxel: salían trocitos flotando.
  Ahora las puntas tienen grosor mínimo y `drop_crumbs()` borra islas
  sueltas.
- Brazos fundidos con el bombacho (cuelgan pegados): al moverse el
  pantalón se estiraba hacia la mano. Cada brazo es ahora su propia malla,
  con pesos solo de su cadena (pecho, hombro, brazo, antebrazo, mano).
- Aun así los pesos automáticos daban la cara exterior del muslo a los
  huesos del brazo (una "aleta" verde en los gestos vistos de espaldas): el
  cuerpo ya no lleva pesos de brazo.
- Faldones de cartón (una caja fina): ahora dos pieles curvas de 1,6 cm.

Medido: 20 huesos, 10 animaciones, 9.626 triángulos.

**Para el dueño** (`~/codigo/capturas/s35/`): `s35-luchador1-vs-retail.png`
(el retail ×4 a la izquierda, el nuestro a la misma escala),
`s35-luchador1.mp4` (las 10 animaciones en 4 direcciones),
`s35-luchador1-1.png` / `-2.png` y `s35-luchador1-4vistas.png`.

### Más acabado (dueño, 2026-11-04: "quiero más acabado")

| Dueño | Cambio | Fichero |
|---|---|---|
| "¿has usado blender para el muñeco?" → "quiero más acabado" | geometría de detalle y texturas loom | `fighter1.py`, `art/characters/fighter1.tx.js` |

- **Texturas loom** (`loom build godot/art/characters/fighter1.tx.js`
  antes de Blender): lana del chaleco, algodón del bombacho, lino de las
  mangas, cuero de botas y cinturón, pelo, piel y oro. Albedos en gris
  claro que `fighter1.py` multiplica por el color de cada material (como
  kiln), así una clase o un cosmético recolorea los mismos mapas. UV por
  proyección de caja en reposo, cada material a su tamaño de tesela.
- **Cara**: blanco del ojo, iris, pupila y brillo, cejas en arco y una
  boca torcida.
- **Manos** con palma, cuatro dedos algo doblados y pulgar (malla aparte,
  vóxel fino, rígida en `hand`); la manga acaba en un puño ancho abierto.
- **Pelo** en mechones: cada pincho es un mechón principal y dos finos,
  algo curvados, con la punta afilada.
- **Bombacho** con pliegues en la malla (`wrinkle()`): anillos fruncidos
  sobre el tobillo, pliegues junto a la rodilla.
- **Pies**: tres tiras naranjas sobre el puño del pantalón (en `shin`) y
  suela oscura (en `foot`). **Hebilla** dorada y **ribete** dorado en los
  faldones. La parte alta de la manga lleva el color del chaleco: tapa el
  hombro.

Lo que la primera pasada hizo mal, corregido sobre primeros planos
(`--zoom=12 --focus=…`, nuevo en `anim_sheet.gd`):
- Texturas demasiado finas y contrastadas: a escala de juego el chaleco
  parecía cota de malla y el tejido de las mangas, escamas. Ahora lana y
  lino casi lisos, teselas de 0,3–0,55 m.
- Pliegues pintados en la textura del bombacho: proyectados sobre la
  pierna redonda salían como llamas. Los pliegues van solo en la malla.
- Pelo rayado en horizontal (textura de hebras proyectada en caja): ahora
  manchas suaves sin dirección.
- Dedos como collares de cuentas (esferas sueltas): ahora fundidos.
- Suelas que sobresalían como esquís; picos del pantalón bajo las tiras;
  manchas blancas de manga en los hombros.

Medido: 21.963 triángulos, GLB de 3,2 MB (siete texturas 512²). **El
presupuesto ya no es ≤4.000**: con este acabado, el objetivo realista es
~10.000 por luchador y texturas compartidas entre clases; queda para
cuando el dueño apruebe el aspecto.

**Para el dueño** (`~/codigo/capturas/s35/`): `s35-luchador1-detalle.png`
(primeros planos: cara, manos, pies), `s35-luchador1-vs-retail.png`,
`s35-luchador1-4vistas.png`, `s35-luchador1.mp4` y las hojas
`s35-luchador1-1/2.png`.

### Por partes (dueño, 2026-11-04)

| Dueño | Cambio | Fichero |
|---|---|---|
| "está saliendo muy mal, ¿qué te parece si dibujas el cuerpo por partes y luego lo unes?" → "modelar en Blender solo la cabeza, después torso, una pierna (espejo) y una mano; luego con loom la ropa" | se deja el cuerpo de esferas fundidas (`fighter1.py`, aspecto de plastilina); cada parte se modela aparte y se enseña sola | `tools/blender/characters/parts/` |

Orden: cabeza → torso → pierna (con espejo) → mano (con espejo) → unir
y vestir (la forma de la ropa es una capa modelada; loom pone tela, cuero
y pelo). Cada parte espera el visto bueno del dueño.

**Parte 1, cabeza** (`parts/head.py` → `art/characters/out/parts/head.glb`):
- Cráneo con jaula de pocos polígonos (esfera 16×12 deformada: cráneo
  ancho, cara plana, mejillas, mandíbula que se estrecha a una barbilla
  en punta, nariz) y subdivisión 2; orejas aparte.
- Ojos puestos sobre la cara con rayos (blanco, iris, pupila, brillo),
  línea del párpado, cejas y boca como trazos con grosor.
- Pelo: casquete sobre el cráneo y 23 mechones anchos y planos (curvas
  bezier con perfil de lente, afiladas en la punta) en estrella hacia
  todos lados, más un flequillo de 4 mechones sobre la frente.
- 15.560 triángulos (se bajarán al unir).
- Corregido antes de enseñar: mechones como agujas (eran 30 finos → 23
  anchos), franja clara en las puntas que hacía bandas (fuera), cara y
  ojos demasiado grandes frente al pelo (el retail apenas enseña la cara),
  huecos del casquete junto a la oreja.

`anim_sheet.gd` acepta ahora una parte sin animaciones (la saca como
`rest`).

**Para el dueño:** `~/codigo/capturas/s35/s35-pieza-cabeza-vs-retail.png`
(retail ×4 y la cabeza en 6 direcciones a la misma escala) y
`s35-pieza-cabeza-4vistas.png`.

**Cabeza, segunda vuelta (2026-11-04):**

| Dueño | Cambio | Fichero |
|---|---|---|
| "busca por internet alguna skill… está muy mal dibujado" → "1" | instaladas las 28 skills de EL4CTEO/blender-skills (MIT, v1.2.0; código revisado: sin red, sin borrados) en `~/.claude/skills` | — |
| "está fatal. ¿por qué haces la cara en forma de V?" | error mío: barbilla en punta de anime que el retail no tiene; ahora cara redonda y llena, mandíbula corta, barbilla suave | `parts/head.py` |

- Aspecto **dibujado** (skill `blender-stylized-npr`): `src/anims/toon.gd`
  pone a cada material del luchador `toon.gdshader` (dos tonos, sombra
  fría, sombras proyectadas con corte duro) y un pase de **contorno**
  marrón oscuro (`toon_outline.gdshader`, casco invertido medido en
  píxeles de pantalla: igual de fino a zoom 1 que de cerca). Los rasgos de
  la cara llevan los dos tonos pero no contorno.
- Normales de la cara copiadas de un elipsoide (Data Transfer): sombra
  limpia, sin manchas en nariz y mejillas.
- Fallos encontrados: el pelo salía negro (normales de los mechones hacia
  dentro, el contorno los tapaba): ahora se recalculan; el contorno no se
  veía (el renderizador de compatibilidad no da el tamaño del píxel en el
  shader): lo pasa `toon.gd` desde la cámara (`set_pixel`).
- Pendiente de decidir: las arenas siguen en su luz PBR; luchadores en
  dibujo y arenas pintadas pueden convivir, pero hay que verlo junto.

**Para el dueño:** `s35-pieza-cabeza-cerca.png` (de cerca, 4 lados) y
`s35-pieza-cabeza-vs-retail.png` (a escala de juego junto al retail).

**Cuerpo entero por partes (dueño, 2026-11-04: "haz el cuerpo entero y
enséñame solo 1 vista; a partir de allí te digo si se anima o no"):**
`parts/body.py` → `art/characters/out/parts/body.glb`, sin rig todavía.
- Torso: un loft de 9 anillos de las caderas al cuello, con un anillo en
  cada borde de prenda (pantalón, cinturón, chaleco, piel): los colores
  acaban en una línea limpia. Subdivisión 2.
- Una pierna en loft (bombacho ancho en rodilla y pantorrilla, fruncido
  en el tobillo) con espejo; bota de caja redondeada con puntera, suela y
  tres tiras (toros) con espejo.
- Un brazo en loft (manga blanca, puño abierto, el hombro bajo el
  chaleco) con espejo; una mano de dibujo (palma ancha, cuatro dedos
  gordos en puño suelto, pulgar) con espejo.
- Cuello dorado (toro) con nudo, cinturón con hebilla, faldones delante
  y detrás con ribete dorado; la cabeza de `head.py` a ×1,08.
- Fallos antes de enseñar: el nudo del cuello flotaba lejos (giraba sobre
  el origen), cuello demasiado largo, manos como garritas (ahora de
  dibujo, grandes), agujeros oscuros en las puntas de los dedos (tubos sin
  tapa).
- 38.788 triángulos, 1,38 de alto: la subdivisión se baja al rigar.

**Para el dueño:** `~/codigo/capturas/s35/s35-cuerpo-entero.png` (una
vista, cámara del juego).

### Sobre el boceto del dueño (2026-11-04)

| Dueño | Cambio | Fichero |
|---|---|---|
| "está fatal, ¿cuál ha sido la pipeline?" | explicado: todo inventado con números, sin diseño de partida | — |
| "envíame donde se ve el muñeco en varias direcciones… DEL RETAIL" | hoja del retail clase 1 en 8 direcciones (×6, fondo liso) | `capturas/s35/retail-clase1-direcciones.png` |
| boceto de Flow (frente, ¾, perfil, espalda) "¿esto te va bien?" | sí; guardado como plano | `m7-referencias/s35/boceto-clase1-flow.jpg` |
| "el color de piel debería cambiarse como el pelo… elige los mejores colores" | piel y pelo son canales de tinte (`skin*`, `hair*`); por defecto piel `e8bd96`, pelo `e3cf86` | `src/anims/toon.gd`, `parts/body.py` |

- **Medido, no inventado:** siluetas de frente, perfil y espalda del
  boceto (fondo rellenado desde los bordes; 415 px = 1,45 m), leídas por
  altura: ancho y fondo del torso, piernas y brazos, nube del pelo. Los
  lofts de `body.py` salen de esa tabla.
- Lo que toma del boceto: chaleco oscuro sin mangas con cuello alto,
  hombreras, panel gris con remate blanco ondulado y emblema dorado
  (también en la espalda); fajín blanco; faldones laterales con bajo
  curvo y ribete dorado, abiertos delante y detrás; brazos desnudos con
  brazalete dorado y vendas blancas del codo a la mano; bombacho turquesa
  bajo la rodilla con puño blanco; espinillas y pies descalzos en
  sandalias con tiras doradas; orejas de elfo; ojos con el párpado medio
  caído; pelo en nube de pinchos hacia fuera.
- `front_decal()`: el panel, el remate y el emblema son un contorno
  rellenado y proyectado sobre el pecho (sin escalones de píxel).
- `anim_sheet.gd --skin= --hair=` prueba los tintes.
- 58.544 triángulos (el pelo y la subdivisión): se bajan al rigar.

**Para el dueño:** `s35-luchador1-vs-boceto.png` (el 3D en cuatro vistas
sobre el boceto), `s35-luchador1-juego.png` (cámara del juego) y
`s35-luchador1-tintes.png` (tres combinaciones de piel y pelo).

### Cambio de flujo: Google Flow → Meshy (dueño, 2026-11-04)

| Dueño | Cambio | Fichero |
|---|---|---|
| "se te queda muy grande… pagaré 1 mes de Meshy" → "con google flow he hecho la pose A o T de varios ángulos, y luego pasarlo por meshy" → "sí, genérame eso" | los muñecos ya no se modelan a mano en bpy: el dueño los redibuja en Flow (pose A, varias vistas) desde el retail y los pasa por Meshy; yo preparo las referencias y luego limpio, reduzco, rigo a los 20 huesos y pruebo en combate | `godot/tools/art/flow_refs.py` |

```
python3 -I godot/tools/art/flow_refs.py ~/codigo/capturas/s35/flow
```

Paquete de referencia (retail, **solo forma**; las zonas grises son las que
el retail tiñe, no colores que copiar): una hoja del tamaño de la pantalla
por figura, en reposo y en todas las direcciones que tiene el retail.
- `clase-01…12-m.png` / `-f.png`: los 24 luchadores, hombre y mujer por
  separado, 5 vistas (frente, 3/4 frente, perfil, 3/4 espalda, espalda; las
  otras 3 del retail son espejos).
- `coach-7000.png`, `coach-7001.png`: los 2 coaches, 5 vistas.
- `invocacion-NNNN.png`: las 9 invocaciones, 4 vistas en diagonal (no
  tienen más).

Corrección del dueño: "con la forma retail es suficiente y si separas la
mujer y el hombre, mejor": fuera las vistas sueltas, los accesorios, la ropa
del coach y las posturas con arma (161 hojas → 35); el rig se hace luego
sobre la malla de Meshy.

Después (dueño: "los accesorios y la ropa dámelo"), como ideas aparte, 15
ilustraciones por hoja:
- `accesorios/`: los 75 equipos de luchador por ranura (23 armas, 15
  mascotas, 15 capas, 16 sombreros, 6 dofus).
- `ropa-coach/`: la ropa del coach por ranura (faldas, peinados, marcas,
  brazaletes, botas, hombreras, capas, pantalones, torsos, cascos, armas).

Para entregar por muñeco: GLB de alta de Meshy y, si se puede, uno reducido
(~5k triángulos), más las imágenes de Flow, en
`~/codigo/capturas/s35/meshy/<clase>_<m|f>/`. Presupuesto en juego: 3–6k
triángulos y textura de 1024 (o 512) por luchador (demo web, S44).
Antes de las 24, un piloto: la clase 1 en los dos sexos de punta a punta.

### Lote 1 de Meshy: inventario y correspondencia (2026-11-09)

| Dueño | Cambio | Fichero |
|---|---|---|
| "ya tengo los assets… están en la homelab" | bajados los 56 GLB de `//debian/codigo/pippop-arena-assets` a `~/codigo/capturas/s35/meshy/_homelab/` (272 MB, fuera del repo); inventario y hojas de revisión; propuesta de qué figura es cada clase | `godot/art/characters/meshy_map.json` |

Medido (Blender 5.2 headless, `inventario.json` junto a los GLB):
- 53 figuras de Meshy: una malla, un material, una textura 2048², 12–21k
  triángulos, **sin esqueleto**, pose A, todas normalizadas a 0,95 m de
  alto (hay que escalarlas a 1,45 celdas al meterlas en el juego).
- El mecha chibi viene dos veces: `Chibi_Mecha_Remeshed` (10k) y la misma
  malla con rig de Mixamo (50 huesos, `Alert`/`Running`/`Walking`, texturas
  4096², 33 MB). El rig de Mixamo no nos sirve tal cual (el juego usa los
  20 huesos y las 10 animaciones de S33); vale como prueba de que la
  malla se deforma bien.
- `fox_warrior` viene en dos versiones (15k "game asset" masculino y 20k
  "lowpoly" femenino): son los dos sexos de Zurcarák, no un duplicado.

**Hojas para el dueño:** `~/codigo/capturas/s35/s35-meshy-lote1-{1,2,3}.png`
(frente, luz neutra, número y triángulos bajo cada figura).

Propuesta de correspondencia (número de la hoja), comparada con las
hojas retail del paquete de Flow; **el dueño confirma o corrige**:

| Clase | f | m |
|---|---|---|
| 1 Feca | 29 falda turquesa | 33 pelo de punta, pantalón teal |
| 2 Osamodas | 30 cuernos y pelaje | 06 cuernos y pelaje |
| 3 Anutrof | 31 lazos naranja, botas rojas | 07 chaleco marrón, pantalón ocre |
| 4 Sram | 03 traje blanco con huesos | 53 calavera |
| 5 Xelor | 08 mecha azul | 01 mecha chibi (00 es el mismo con Mixamo; confirmado por el dueño) |
| 6 Zurcarák | 28 orejas, naranja | 55 orejas, naranja |
| 7 Aniripsa | 11 hada con alas | 34 abrigo marrón con alas |
| 8 Yopuka | 32 cinta roja | 25 verde y rojo, pelo de punta (el 47 era de Ferinia) |
| 9 Ocra | 13 armadura marrón y amarilla | 24 coleta, botas lima |
| 10 Sadida | 05 flor en el pelo | 04 rastas |
| 11 Sacrógrito | 12 moño, falda roja (26 es casi igual) | 14 bufanda roja, vendas |
| 12 Pandawa | 48 | 09 |
| Coach 7000 / 7001 | 15 (bikini verde) | 27 (calzón verde) |

Invocaciones: 8001 → 49 muñeco vudú · 8002 → 02 muñeco con venda ·
8003 → 10 saco · 8004 → 23 pangolín · 8005 → 43 tofu · 8006 → 41 oveja · 8007 → 54 gólem · 8009 → 42 árbol ·
**8010 es un cristal, un espejo** (dueño, 2026-11-09): no viene de
Meshy, lo modelo yo como pieza rígida (sin rig; el brillo y el giro los
pone el juego).

**Solo los de Pippop** (dueño, 2026-11-09: "se me ha colado… has pillado
los glb de ferinia… ignora los de ferinia"). En la carpeta de la homelab
hay 20 GLB de Ferinia. Se distinguen por el nombre: los de Ferinia van en
mayúsculas con `_LowPoly` (`Bear_Warrior_LowPoly`), los de Pippop en
minúsculas (`_lowpoly`, `game_asset`, `20k_mesh`). Apartados en
`~/codigo/capturas/s35/meshy/_ferinia/`. Quedan 35 figuras de Pippop:
las 34 de la tabla más una segunda versión de Sacrógrito f (26).

**Hojas con la propuesta** (`~/codigo/capturas/s35/`):
`s35-meshy-pippop-clases.png` (arriba mujer, abajo hombre) y
`s35-meshy-pippop-invocaciones.png` (invocaciones y coaches).

**Copiados para trabajar (2026-11-09):** cada GLB de Pippop en su carpeta,
`~/codigo/capturas/s35/meshy/<carpeta>/<carpeta>.glb` (36 ficheros, p. ej. `01_feca_f/01_feca_f.glb`):
`01_feca_f` … `12_pandawa_m`, `coach_7000_m`, `coach_7001_f`,
`invocacion_8001` … `invocacion_8009`, más `05_xelor_m_mixamo` (el
mismo Xelor con rig de Mixamo, solo para comparar) y
`11_sacrogrito_f_alt`. Los originales siguen en `_homelab/` con
`inventario.json`. Los de Ferinia no se usan ni se tocan.

Decisiones abiertas:
- 8005 y 8006: el dueño escribió "8005 = 02, 8006 = 10", pero 02 y 10
  tienen la forma de 8002 y 8003 en la hoja retail; se queda 8005 → 43
  y 8006 → 41 hasta que lo confirme.
- Rig: lo hago yo en Blender con los 20 huesos y las 10 animaciones
  (recomendado al dueño: el rig de Meshy/Mixamo no tiene nuestras
  animaciones ni sirve para criaturas). El Xelor con Mixamo sirve de
  comparación en el piloto.

**Piloto Feca f y m** (`01_feca_f`, `01_feca_m`), de punta a punta (plan del 2026-11-09, hecho el 2026-11-10, abajo):
1. Limpiar en Blender: escala a 1,45 celdas, pies en el suelo, origen,
   orientación al frente del juego, revisión con `blender-asset-qa`.
2. Reducir a 3–6k triángulos y la textura de 2048 a 1024.
3. Rig a los 20 huesos (pesos automáticos, retoque) y las 10 animaciones
   de `fighter1.py`.
4. Hoja con `anim_sheet.gd` a escala de juego, junto al Xelor de Mixamo.
5. Un combate con el Feca nuevo.

Después: el cristal de 8010 (pieza rígida, la modelo yo) y el resto de
clases en lote.

### Piloto Feca f y m (2026-11-10)

| Dueño | Cambio | Fichero |
|---|---|---|
| "continúa con: mañana empiezo el piloto con los dos Feca" | de un GLB de Meshy a un luchador del juego en un solo paso de Blender, y el luchador 3D dentro del combate | `tools/blender/characters/meshy_fighter.py`, `rig_anims.py`, `src/anims/fighter3d.gd` |
| "revisa bien dónde has puesto los hombros, lo has puesto a la altura de los bíceps/tríceps" | tenía razón: el hombro iba 3,5 cm sobre la axila, y con los brazos pegados al cuerpo eso es el bíceps. Ahora sale de la silueta: el alto del hombro es el último corte, subiendo, que aún es claramente más ancho que el cuello, y la articulación va un radio de brazo por debajo (f 0,919 → 0,981; m 0,855 → 0,960) | `meshy_fighter.py` |

```
blender -b -P tools/blender/characters/meshy_fighter.py -- \
    ~/codigo/capturas/s35/meshy/01_feca_m/01_feca_m.glb art/characters/out/feca_m.glb [--debug=<dir>]
```

Pasos, todos en `meshy_fighter.py`:
1. **Limpieza y escala:** junta las mallas, une los vértices duplicados de
   las costuras de Meshy (de ~8.000 aristas abiertas a 130–226), escala a
   1,45 de alto, pies en z=0 y centrados, mirando a -Y (el frente del
   juego; el de Meshy ya lo es).
2. **Reducción:** 20.900 → 5.000 triángulos (colapso) y la textura de 2048
   a 1024, en JPEG dentro del GLB: ~790 KB por luchador.
3. **Rig:** los 20 huesos de `fighter1.py` puestos sobre la malla a partir
   de cortes horizontales reales (triángulos cortados por el plano y unidos
   en lazos): pies, tobillo, entrepierna (el hueco más alto entre las
   piernas: el bombacho del m se toca en la rodilla), brazos (las piezas de
   fuera en cada corte), mano (si el brazo acaba tocando el cuerpo, una
   mano más: 6,5 % del alto, como `fighter1`), cuello (el corte más
   estrecho) y hombro (arriba). Un JSON `--joints` corrige cualquier
   articulación a mano; `--debug` saca los cortes y una radiografía de los
   huesos.
4. **Pesos:** los automáticos de Blender y luego tres reglas, porque Meshy
   funde lo que se toca: (a) por debajo de la axila un vértice es de brazo
   solo si está en la pieza del brazo de su corte, cerca de sus huesos y
   unido por la malla al núcleo del brazo; (b) la malla se **corta** entre
   las caras de brazo y las del cuerpo (codo pegado a la cintura de la f,
   mano pegada al abrigo del m), por aristas y por esquinas; (c) por encima
   del corte, huesos del brazo solo a menos de dos radios del brazo (la
   mochila del m subía con las manos). Luego un suavizado de pesos (4
   pasadas) y la cabeza rígida.
5. **Animaciones:** las 10 de `fighter1.py`, que ahora viven en
   `rig_anims.py` (`fighter1.py` sale igual byte a byte). Los brazos cortos
   bajo una cabeza grande no pasan por encima de ella: al subir más de 100°
   se abren en V (`--overhead_out=40`; `fighter1` usa 0).

Medido (los dos): 20 huesos, 10 animaciones, 4.999–5.000 triángulos,
textura 1024², GLB de 772–775 KB.

Lo que salió mal antes de enseñarlo, corregido:
- Cortes por vértices después de reducir: con 2.500 vértices no salían ni
  brazos ni piernas. Ahora corta triángulos y antes de reducir.
- Caderas a la altura de la rodilla en el m (el bombacho se toca ahí).
- Las puntas del abrigo del m pasaban por manos.
- Brazos levantados que se cruzaban delante del pecho (la V giraba al
  revés con el brazo hacia arriba).
- "Alas": telas estiradas de la mano a la cadera (caras fundidas, la cara
  interior de la manga que quedaba en el cuerpo, triángulos largos del
  reducido que cruzaban el corte). Quedan unos agujeritos oscuros donde
  estaba la unión, visibles solo de cerca.

Pendiente:
- Unas migas del abrigo siguen pegadas a las manos del m (estaban fundidas
  con la mano en la malla de Meshy).
- Los GLB del juego (`art/characters/out/`) no van al repo, como los kits:
  se rehacen con el comando de arriba desde `~/codigo/capturas/s35/meshy/`.

**En combate** (`src/anims/fighter3d.gd`, técnica A de S33): cada luchador
3D tiene su viewport pequeño y transparente con la luz de la arena y la
cámara del juego, a 2× y mostrado como sprite con el origen en los pies.
Cuelga del `AnmSprite` (`model3d`), así `fight_view` lo sigue colocando,
ordenando, ocultando tras la arena, con nombre y texto flotante como
antes; las acciones retail (`1_AnimMarche02`, `AnimSort-…`, `AnimHit`,
`AnimKO-…`, `Anim0xPorte`) se traducen a las 10 animaciones y la dirección a
un giro (deshace el espejo de 3/4/7). Solo los luchadores con modelo
(`Fighter3D.MODELS`: Feca) cambian; el resto sigue en sprite retail.
- Prueba sin servidor: `FIGHT_UI_FECA=1 FIGHT_UI_FOCUS=1,2
  test/fight_ui_preview.tscn` (Arel y Brune pasan a Feca m y f; arena 2).
- Combate real: la repetición grabada `2610251213_test_VS_test2.slr`
  (11 turnos, un Féca m contra dos Humo) con `tools/reel/make_reel.sh`: anda,
  lanza, recibe y muere de espaldas sin errores. Es el mundo 65, un mapa
  antiguo pintado (no hay repetición con Feca en las arenas nuevas ni con
  Feca f).
- De paso: el texto flotante salía en espejo sobre un luchador mirando a
  3/4/7 (no era del 3D, pasaba ya); ahora se desespeja como el nombre.
- Tests de Godot: 20 suites, 552 comprobaciones, 0 fallos, y los dos
  previews visuales.
- Pendiente: un viewport compartido para doce luchadores (hoy uno por
  luchador, ~4 ms cada uno según S33) y la sombra en el suelo.

**Para el dueño** (`~/codigo/capturas/s35/`):
`s35-feca-piloto-escala.png` (los dos Feca y el Xelor de Mixamo, ×1 y ×2,
SE y NW), `s35-feca-f-1/2.png` y `s35-feca-m-1/2.png` (las 10 animaciones,
6 fotogramas, SE y NW), `s35-feca-f.mp4` / `s35-feca-m.mp4` (las 10 en 4
direcciones), `s35-feca-f/m-4vistas.png`, `s35-feca-m-combate-arena2.png` /
`s35-feca-f-combate-arena2.png` (en la arena 2) y `s35-feca-combate.mp4`
(el combate real).

**2026-11-10 — Osamodas f y m (S35b).** La f sale sin tocar nada. El m
lleva brazales fundidos con las borlas del cinturón (z 0,62–0,78): las
manos quedaban fuera del brazo y, al subirlo, el pelo del brazal se
quedaba flotando en la cadera. Nuevo `extend_hand()` en `meshy_fighter.py`,
solo cuando `--joints` mueve `hand_tip.S` (los Feca no cambian: sin
`--joints`). Relajar el ancho mínimo de la mano en general se probó y
rompía el brazo derecho del Feca m (cogía el bajo del abrigo hasta 0,41).
`FIGHT_UI_BREED=<n>` en la vista previa de combate.

**2026-11-10 — Anutrof f y m (S35b).** La f lleva falda larga y unas
bolsas que agarra con las manos. Con la falda, la entrepierna salía en el
bajo, así que la cadera va por `--joints`. Los rizos del pelo se tomaban
por el brazo, y ahora el brazo es un tramo de 3 cortes o más. Las bolsas
están fundidas con la mano y dejan esquirlas al subir los brazos;
aceptado a escala de juego. El m lleva guanteletes: la mano se corta en
el puño y el pulgar es una pieza aparte. `extend_hand` ahora suma esas
piezas pequeñas y da más holgura bajo la muñeca. El Osamodas m se
reconstruyó con esto y sigue limpio; los Feca no cambian (sin `--joints`).

**2026-11-10 — Sram f y m (S35b).** Huesos y pesos bien a la primera;
solo el pulgar, una pieza aparte en el corte, se quedaba junto al muslo
al subir los brazos. Con `hand_tip` en `--joints` (su propio valor) lo
recoge `extend_hand`. Repasados los Feca con la misma mirada: la f deja
dos puntitos junto a la falda con los brazos arriba; pequeño, el piloto
está aprobado, no se toca salvo que el dueño lo pida.

**2026-11-10 — Xelor f y m (S35b).** Los dos mecha llegan como una malla
soldada (`islands: 1`). Las aletas del brazal del m y las coderas de la
f sobresalen del brazo más que la holgura del script y se quedaban con el
cuerpo, estiradas en "alas". Nueva opción `--arm_slack` (0,03 por
defecto, 0,06 en los dos Xelor). La f además tiene las manos fundidas con
la cadera y el m el pulgar suelto: `--joints` con la mano. El m conserva
el mapa de metal de Meshy (segunda textura); en Godot el dorado brilla
bien, solo `four_views.sh` (Blender sin entorno) lo enseña oscuro.

