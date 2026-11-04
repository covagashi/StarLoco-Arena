# S35 — Personajes

**Planificado:** 2026-10-25 · **Abierto:** 2026-11-04 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (paso 1 a revisar por el dueño)

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
