# S54 — Figuras ligeras: 3D para jugar, imagen para mirar

**Planificado:** 2026-11-26 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** 🔵 en curso (2026-11-27): pasos 0–3 hechos; el 4a hecho (lobby), la ropa aparcada; el 5 (luchadores) hecho

## Por qué

En S53 (A4) los coaches salieron con «triángulos feos» de cerca. Arreglarlo
costó un día entero: la reducción de Meshy dejaba astillas, el corte del
brazo rasgaba la malla y la textura venía con manchas pintadas. Se arregló
(malla limpia de 40k desde el original de 676k, color rehorneado a 2048²),
pero el coach sigue siendo caro: 2,3–2,4 MB de GLB y unos 21 MB de memoria
de vídeo por coach en la web.

El dueño trae dos opiniones de otro gamedev (2026-11-26):

- «Máximo 5k, y las imperfecciones se tapan con texturas.»
- «Eso y la posición plana de los pies siempre requiere afinarlo. Hazte un
  pipeline integrando y documentando todo, así ahorras tiempo posterior.»

Y propone: **en los menús, imágenes bien definidas en vez del 3D.**

### Lo que hay hoy

| | Hombre (coach_7000) | Mujer (coach_7001) |
|---|---|---|
| Malla | 1 malla, 1 primitiva, 40 000 triángulos | igual |
| Huesos / animaciones | 20 / 14 | 20 / 14 |
| Textura | 2048², JPEG 85 | 2048², JPEG 85 |
| GLB | 2477 KB (tope 2600) | 2381 KB |
| Original de Meshy | 676k triángulos, 39 MB | 676k, 37 MB |
| Prendas | 104 GLB, 11 MB en total (solo se cargan las puestas) | 104 GLB, 11 MB |

El coach sale en 3D en cinco sitios:

| Dónde | Tamaño en pantalla | Qué necesita |
|---|---|---|
| Combate: de pie en su pedestal, junto a la arena (`fight_view._place_actor`) | pequeño, como un luchador | moverse, girar en 8 direcciones, teñido y vestido; sus gestos son la reserva de los luchadores |
| Creación del jefe (`creation_screen.gd`) | grande | teñir piel y pelo al momento, hombre/mujer |
| Lobby (`lobby_screen.gd`) | grande | teñido y vestido, en reposo |
| Equipo del coach (`coach_equip_panel.gd`) | grande | ver cada prenda puesta al probarla |
| Subida de nivel (`level_up_panel.gd`) | mediano | teñido y vestido |

## Decisión propuesta (opinión, para el dueño)

**Dos versiones de cada figura, del mismo original, como en los gacha:**

1. **Para jugar (combate): 3D de 5k triángulos**, como los luchadores. En
   combate una figura mide 100–150 px: ahí 5k sobran, y lo fino lo dan la
   textura y un mapa de normales horneados del original. Lo que la textura
   no tapa es la silueta vista de cerca, y de cerca ya no se vería.
2. **Para mirar (los cuatro menús): imagen renderizada del original de 676k**
   en Blender, con la luz y la tinta del juego, en capas:
   - el cuerpo, con sus **máscaras de piel y pelo** (el menú tiñe como hoy);
   - **cada prenda en su propia capa**, alineada con el cuerpo (el equipo del
     coach la pone y la quita al momento);
   - **solo de frente** (dueño, 2026-11-26);
   - un reposo animado suave (respirar, balanceo), con AniCraft o con el
     mismo truco de los retratos de NPC (`npc_anim.py`).

Por qué renderizado y no ilustrado: dibujar 104 prendas por coach en vex es
mucho trabajo; renderizarlas es automático, y la imagen casa con el 3D del
combate. La ilustración queda para retratos y splash.

## Plan

### Paso 0 — Prueba antes de rehacer nada (S)

Una hoja con la mujer renderizada del original de 676k al lado del 3D
actual, **en la pantalla de creación**, con dos colores de pelo y dos de
piel. El dueño decide si merece la pena. (Quedarse con el 3D de 40k no es
una opción: el 3D va a 5k como mucho, dueño 2026-11-27.)

### Paso 1 — El documento del pipeline de figuras (S)

`docs/pipeline-figuras.md`, un solo sitio con: Meshy → `figures.json` →
`build.py` → `meshy_fighter.py` (reducción limpia con MeshLab, UV,
rehorneado, rig, pesos, `lower_arms`, animaciones) → `coach_masks.py` →
`coach_garment.py` → `check.py`. Qué hace cada paso, qué opciones tiene,
cuánto tarda, cómo se comprueba (`test/coach_sheet.gd`, QA de Blender) y los
fallos típicos que ya conocemos: astillas de la reducción, el brazo rasgado
por el borde del guante, sombras propias en el visor de la figura, manchas
pintadas por Meshy, mechones tomados por piel. Dependencias fuera del repo:
Blender 5.2.3, pymeshlab, `PIPPOP_MESHY` y `PIPPOP_MESHY_HD`.

### Paso 2 — Pies planos (M)

Las suelas a ras del suelo en reposo y en cada animación (hoy se inclina un
pie de la mujer dentro de la bota y el del hombre gira en vez de apoyarse).
Un paso del build: plantar el pie (la rotación del hueso del pie que deja la
suela horizontal cuando toca el suelo) y comprobarlo en una hoja de todas
las animaciones, vistas de lado.

### Paso 3 — El coach de combate a 5k (M)

`figures.json`: `tris=5000` con la reducción limpia, textura a 1024² y un
mapa de normales del original (si el toon lo aprovecha sin escalones; si
no, sin él). Las prendas, reducidas a juego. Hoja a tamaño de combate y de
cerca. `check.py`: el tope del coach vuelve al de los luchadores.

### Paso 4 — Las imágenes de los menús (L)

Un script de Blender en el build (`coach_menu_renders.py`) que saca, del
original, cada ángulo con: color, máscara de piel, máscara de pelo, tinta;
y cada prenda como capa con su propia máscara. Formato ligero para la web
(WebP), con su tope en `check.py`. En Godot, un nodo `CoachPortrait` que
compone las capas, tiñe con las máscaras (el mismo cálculo que
`toon.gdshaderinc`) y anima el reposo. Sustituye al 3D en la creación, el
lobby, el equipo y la subida de nivel.

### Paso 5 — Los luchadores (A5, de S53)

Los 24 luchadores (12 clases × 2) y las invocaciones pasan por la misma
reducción limpia a 5k y el rehorneado, uno por sesión (como S35b), con hoja
antes/después al dueño. Si alguno sale en grande en un menú (Equipo,
reclutar), la misma imagen renderizada.

## Cómo se cierra

- El dueño aprueba la prueba del paso 0 y las hojas de cada paso.
- `docs/pipeline-figuras.md` explica, sin leer código, cómo meter una
  figura nueva de Meshy al juego.
- Ningún pie inclinado ni flotando en ninguna animación (hoja de lado).
- Coach de combate ≤ 5k triángulos; en la web, la primera carga y la
  memoria de vídeo bajan (medidas antes/después).
- Creación, lobby, equipo y nivel con la imagen: teñir y vestir al momento,
  en es/en/fr, a 1280×720 y 1920×1080, sin cortes.
- Unitarias, `coach_look_smoke`, `coach_turn_smoke`, `first_play_smoke` y la
  partida entera de S53 (`first_play_test.mjs`) en el build web.

## Respuestas del dueño (2026-11-26)

1. **Sí al híbrido:** 3D de 5k en combate, imagen renderizada en los menús.
2. **Solo de frente:** un ángulo por figura en los menús (el paso 4 renderiza
   solo el frente; sin girar).
3. **Primero solo la prueba del paso 0, y no ahora:** el sprint espera; al
   retomarlo se hace el paso 0, se enseña y se para hasta su visto bueno.

## Hecho

### Paso 0 — la prueba (2026-11-27)

Hojas en `~/codigo/capturas/s54/` (páginas de pantalla):
`01-creacion-imagen.png` y `02-creacion-3d.png` (la pantalla entera a
1920×1080, la misma mujer con imagen y con 3D), `03-colores-1.png` y
`04-colores-2.png` (piel 1 y 3 × pelo 0 y 3, el 3D y la imagen lado a
lado) y `05-de-cerca.png` (×2: cabeza y torso).

Cómo se hizo, para no repetirlo en el paso 4:

- `tools/blender/characters/coach_hd_pose.py` posa el original de 676k con
  el esqueleto del coach: los mismos pasos que `meshy_fighter.py` (limpieza,
  reducción con MeshLab, articulaciones, pesos) hacen la figura de 40k en la
  pose A, donde aún coincide con el original; sus pesos pasan al original
  (cara más cercana, interpolado), los brazos bajan con ella
  (`lower_arms(..., others=)`, nuevo parámetro; el build no cambia) y el
  clip del menú lo pone en su fotograma 0. La máscara de piel y pelo de
  cada vértice sale de la figura construida y su `_mask.png`, en reposo
  (12 vértices de 363k a más de 1 cm). 30 s.
- `test/coach_hd_trial.gd` abre la pantalla de creación de verdad, para el
  3D de 40k en el mismo fotograma del clip, pone el original en el mismo
  visor (misma cámara, luz y tinta) y saca tres capas: **color sin luz con
  su tinta**, **la luz sola** (figura gris al 50 %: una blanca iluminada
  pasa de 1 y se recorta) y **la máscara**. En 2D el color toma el tinte
  como `toon.gdshaderinc` (con su propia referencia de brillo, el
  percentil 80 bajo cada máscara) y se multiplica por la luz. 3,7 s.
- Tropiezos: en Blender 5 una acción sin su *slot* no posa (la pose se lee
  de las curvas); parchear `bpy.ops.pose.armature_apply` no sirve (cada
  acceso a `bpy.ops.pose` es un objeto nuevo); dividir la capa iluminada
  por la luz falla donde se recorta (pelo blanco), por eso color y luz van
  separados.

Medidas (la mujer, a la escala de hoy en la creación, res 6):

| | 3D de hoy | Imagen |
|---|---|---|
| Descarga | GLB 2381 KB | 3 capas WebP, 59 KB |
| Memoria de vídeo | ~21 MB | ~1,4 MB (recortadas a la figura) |

Lo que se ve: el original trae mechones dibujados y brillos en el pelo, el
ombligo, la clavícula y el borde del cinturón; la cara y el cuerpo, a esta
distancia, casi iguales. Pendiente para el paso 4 si sigue: el reposo
animado (hoy es un fotograma quieto), las prendas como capas, y renderizar
a res 9 (a 1920×1080 la creación muestra la figura a ×1,5 de lo que se
renderiza, igual que el 3D de hoy). Unos puntos blancos en el pelo son los
brillos pintados en la textura del original.

**Corrección del dueño (2026-11-27):** «al final dijimos de dejarlo
máximo 5k». Quedarse con el 3D de 40k no es una opción: el 3D va a 5k
como mucho, y la prueba compara la imagen con un 3D que va a perder
detalle, no con el que se queda. Visto bueno para los pasos 1–5
(«siii», 2026-11-27).

### Paso 1 — el documento (2026-11-27)

[`docs/pipeline-figuras.md`](../docs/pipeline-figuras.md): el esquema de
Meshy al juego, lo que hace falta fuera del repo, la receta de
`figures.json`, cada paso de `meshy_fighter.py` con sus opciones, las
máscaras, las prendas y la imagen de los menús, los presupuestos de
`check.py`, cómo revisar (hojas), los fallos conocidos (con un enlace a la
tabla completa de S35b) y una lista para meter una figura nueva.

## Pregunta del dueño (2026-11-27): «¿y si el coach tiene ropa? ¿mejor quitamos el coach del hub?»

- **La ropa en la imagen:** cada prenda se renderiza puesta sobre el
  original posado, en su propia capa con su máscara; el cuerpo tapa lo
  que queda detrás (una capa solo tiene lo que se ve de esa prenda), y en
  el menú se apilan por ranura (falda, pantalón, botas, torso, marca).
  Las prendas son las caras del propio cuerpo empujadas hacia fuera, así
  que encajan con la imagen sin ajustes. 104 prendas por coach, cada una
  un render de segundos y unos KB.
- **Lo que se pierde en el lobby:** hoy el coach gira con las flechas y
  hace gestos (saludo, pose). Con una imagen de frente, ni gira ni
  gesticula, salvo que se rendericen esos gestos como fotogramas (y cada
  prenda con ellos).
- **Mi opinión:** no quitarlo. El lobby es el único sitio donde el
  jugador ve siempre a su coach vestido, y la ropa es premio: sin el coach
  en el hub, la ropa solo se ve en Equipo del coach. Lo dejaría como
  imagen de frente, quitando las flechas de girar, con el reposo animado
  y los gestos como bocadillo y un saltito. Decide el dueño.

### Referencias del dueño para el hub (2026-11-27)

Tres pantallas de inicio de gacha (`~/codigo/capturas/s54/refs/hub-ref-*.jpg`).
Lo que tienen en común:

- **la figura es la protagonista:** grande, ocupa un tercio de la
  pantalla, a la izquierda o en el centro; los menús alrededor (recursos
  arriba, botones de sistema en una columna a la izquierda, los modos
  grandes a la derecha);
- **de frente y a la altura de los ojos**, no desde arriba como la cámara
  del juego; no gira;
- **quieta o casi:** a lo sumo respira (tipo Live2D);
- dos de las tres **cortan la figura por los muslos o las rodillas**; la
  primera la enseña entera.

Encaja con el plan (imagen de frente, sin flechas de girar). Lo que cambia
el paso 4: la imagen ya no tiene que salir con la cámara del juego, puede
salir de frente y a la altura de los ojos, y si la figura sale más grande
(cortada por los muslos), hay que renderizarla a más resolución.
Preguntas abiertas al dueño: la cámara y el encuadre.

**Respuesta (2026-11-27):** «mejor el 2, cortada por el muslo o
tobillo». Decido yo entre los dos (opinión, no orden): en el **lobby**,
cortada a medio muslo, como la segunda foto, de frente y a la altura de
los ojos; en **Equipo del coach**, entera (ahí se prueban las botas). La
creación, como el lobby. Se revisa con la hoja del paso 4.

### Paso 2 — pies planos (2026-11-27)

- **Causa:** el pie es hijo de la espinilla y solo giraba si el clip lo
  pedía (`foot_<S>`): al inclinarse el cuerpo, abrir una pierna o doblar
  la rodilla, la suela se inclinaba dentro de la bota. El ajuste de suelas
  solo bajaba la figura entera hasta el punto más bajo.
- **Arreglo** (`rig_anims.plant()`): en cada fotograma con los pies en el
  suelo (clave o entre claves), cada pie a menos de 3 cm del suelo vuelve a
  su orientación de reposo, girado solo en vertical hacia donde apunta la
  pierna; `foot_<S>` queda como inclinación sobre esa suela plana (el talón
  al pisar al andar). Después se vuelve a apoyar la figura. El salto
  agachado ya no necesita su `foot=-25` a mano. El GLB no crece (el
  exportador ya muestreaba cada fotograma).
- **Medida** (`tools/blender/characters/feet_check.py`, nuevo): peor
  inclinación de un pie que pisa por clip, y fotogramas flotando. La mujer,
  antes → ahora: menú 14,4° → 0°, reposo 6,4° → 0°, lanzar 23,9° → 0°,
  golpe 30,8° → 0°, tirar 25° → 0,3°, saludo 14,2° → 0°; el hombre flotaba
  1–2 fotogramas en `cast`, `greet`, `shoot` y `throw`, ya no. Las 33
  figuras humanas: todos los clips ≤ 3° salvo `walk` (12° a propósito; en
  algunas clases más, el pie de atrás despegando con el talón, que es el
  paso natural).
- **Hoja:** `~/codigo/capturas/s54/06-pies-mujer.png` (de lado, cámara a
  nivel, el peor fotograma de antes y el mismo ahora, línea de suelo).
- **Comprobado:** `build.py` entero (4 min 58 s, `check.py` 0 fallos),
  `run_tests.sh` (1684 comprobaciones), `coach_look_smoke`,
  `coach_turn_smoke` y `first_play_smoke` con una cuenta nueva (14/14).
- **Queda:** la Sram f flota 2 fotogramas al andar (4–5); las invocaciones
  criatura (pollito 8005, pangolín 8004) usan `creature_anims.py`, sin
  plantar: flotan 1–3 fotogramas y se inclinan 8° al lanzar. Van con el
  paso 5.

### Paso 3 — el coach a 5k, la comparación (2026-11-27)

El dueño: «continua, comparemos los dos». Construidos aparte (la receta de
`figures.json` no cambia todavía): los dos coaches con sus mismas opciones
pero `tris=5000`, `tex=1024`, sin mapa de normales. Máscaras rehechas para
las UV nuevas. Los GLB de 5k, `sheet.py` y `render.sh` en
`~/codigo/capturas/s54/5k/`.

| | 40k (hoy) | 5k |
|---|---|---|
| Triángulos | 40 000 | 4 999 |
| Textura | 2048² | 1024² |
| GLB hombre / mujer | 2477 / 2381 KB | 745 / 725 KB |
| Construir uno | — | 44 s |

Hojas (`~/codigo/capturas/s54/`): `07-coach-5k-combate.png` (los dos a
tamaño de combate, ×1 y ×3), `08`/`10` enteros a tamaño de la creación,
`09`/`11` de cerca (×2,4).

Lo que veo:

- **En combate, casi iguales.** A ×1 no se distinguen; a ×3 el pelo del
  hombre sale algo más liso y en la mujer se pierden unos mechones finos.
- **De cerca se nota:** la mujer pierde las cejas (eran unos téxeles finos
  de la textura de 2048²), el pelo sale con picos más rectos y menos trazos
  dentro, los hombros con alguna arista. El hombre aguanta mejor (sus picos
  ya eran angulosos); una mancha rosada en el pecho de tres cuartos.
  Como en los menús va la imagen del original (paso 4), de cerca ya no se
  verá el 3D.
- **Pesos de la mujer:** 1125 vértices con el respaldo de proximidad (el
  calor de Blender no encontró solución para algún hueso); en las poses de
  reposo no se ve, falta mirarlo en las animaciones difíciles antes de
  adoptarlo.

Lo siguiente, si el dueño da el visto bueno: probar el mapa de normales y
las cejas (más textura en la cara, o 1024² con `--nearest`), la hoja de
animaciones difíciles, y pasarlo a `figures.json` con las prendas
reducidas a juego y el tope de `check.py` de los luchadores.

**Visto bueno del dueño (2026-11-27):** «doy mi ok». Hecho:

- **Las cejas:** no las pierde la textura sino la malla: a 5k el flequillo
  baja hasta el ojo y tapa la frente donde estaban. Nueva opción
  `--head_uv=2` en `meshy_fighter.py` (las piezas de la cabeza con el doble
  de téxeles por lado, mismo peso): los ojos y la boca más nítidos; las
  cejas siguen tapadas. De cerca solo se verá la imagen del paso 4.
- **Mapa de normales: no.** El shader toon no lee ninguno (habría que
  añadirlo con tangentes y otra textura) y en combate, a 100–150 px, no se
  vería; las bandas del toon harían escalones con el relieve fino.
- **Pesos de la mujer:** la hoja de animaciones difíciles
  (`12`/`13-coach-5k-mujer-animaciones-*.png`: golpe, lanzar, tirar,
  cargar, celebrar, saludo, pose, morir; 40k y 5k fila con fila) sale
  igual; los 1125 vértices del respaldo no se notan.
- **Receta** (`figures.json`): los dos coaches `tris=5000`, `tex=1024`,
  `head_uv=2`, sin `jpeg=85` (vuelve al 90 de siempre). `check.py`: el
  coach con el tope de los luchadores (5 000, 1024², 1200 KB).
- **Prendas:** salen del cuerpo, así que bajan solas: 104 por coach,
  11 MB → 5,5 MB por coach; la mayor, 2 490 triángulos (tope 3 500).

| Por coach | 40k | 5k |
|---|---|---|
| GLB hombre / mujer | 2477 / 2381 KB | 826 / 787 KB |
| Prendas (las 104) | ~11 MB | 5,5 / 5,7 MB |
| Textura en vídeo (RGBA con mipmaps, calculado) | ~22 MB | ~5,6 MB |

- **Comprobado:** `build.py` entero (70 s, `check.py` 0 fallos),
  `run_tests.sh` 1684/0, `coach_look_smoke`, `coach_turn_smoke` y
  `first_play_smoke` (14/14). `feet_check.py`: los dos ≤ 3° salvo `walk`
  (el hombre 27,4°, igual que a 40k: el talón al despegar).
- Hojas `07`–`11` rehechas con lo que va al juego.

### Paso 4a — el lobby con la imagen (2026-11-27)

El dueño: «ok, pasa a lo siguiente». Empiezo por el lobby, cortado a medio
muslo, de frente y a la altura de los ojos.

- **Cuánto hay que pintar:** el coach puede ponerse 196 piezas (104 prendas
  que se doblan con el cuerpo y 92 colgadas de un hueso: sombreros, capas,
  hombreras, brazaletes, estandartes, mascotas). Todas van en capas.
- **Posado** (`coach_hd_pose.py`, ya del paso 0): ahora con las mismas
  opciones que la figura de 5k, para que el esqueleto sea el mismo que
  mueve la ropa. La máscara de la mujer tiene 1447 vértices a más de 1 cm
  de la figura de 5k (antes 12, con la de 40k): es el flequillo, que a 5k
  baja más; en la imagen el pelo y la frente salen teñidos bien.
- **Render en capas** (`tools/art/coach_portrait.gd`, nuevo): el cuerpo en
  tres capas (color con tinta, luz, máscara) y cada pieza en la suya.
  Tropiezos:
  - el original asomaba a través de la ropa (es un poco más ancho que la
    figura de 5k, para la que se hicieron las prendas). Encoger el original
    1,5 cm en la máscara no bastó; lo que funciona es usar la figura de 5k
    como lo que tapa: las piezas tapan y quedan tapadas igual que en el
    juego.
  - `Fighter3D` vuelve a girar el modelo a su dirección en cada fotograma:
    las prendas salían giradas respecto al cuerpo. Se fija la dirección de
    frente en la propia figura.
  - el gorro de gelatina salía con la malla dibujada: el temblor abre sus
    caras y deja ver la tinta (en el juego pasa igual, se ve en la hoja de
    antes). En la imagen se renderiza quieto.
- **En el juego** (`src/anims/coach_portrait.gd`, `CoachPortrait`): compone
  las capas, tiñe piel y pelo con la máscara como el shader toon, el brillo
  de los efectos de pelo, apila las piezas por ranura, respira (0,6 % de
  alto cada 3,6 s) y da un saltito donde el 3D saludaba o posaba.
- **Lobby:** la imagen a 560 px por metro (a 1280×720), el corte por
  debajo de la ventana; sin las flechas de girar (decidido con las
  referencias del hub). Fuera `coach_rotated`, `_rotate` y los textos
  `lobby.rotate*`.
- **Build:** `build.py` posa el original y saca las capas tras las prendas
  (2 min 40 s los dos coaches); `check.py` exige la imagen de cada coach
  (4 MB como mucho por encuadre); `pack_arenas.gd` y `pack_web.gd` la
  llevan (en la web, con el arranque: el lobby la dibuja desde la primera
  pantalla).
- **Peso:** 2,1 MB por coach con las 165 piezas que caben en el encuadre
  (las botas quedan bajo el corte); el lobby solo carga las puestas.
- **Pruebas:** `coach_turn_smoke` ya no gira el lobby: comprueba que no
  tiene « » y sigue probando el ▶ de reclutar; `coach_look_smoke` y
  `hub_smoke` comprueban que la imagen lleva las piezas de las cartas
  puestas y el efecto de pelo. Nuevo `test/lobby_coach_sheet.gd`: el lobby
  con el coach, el pelo y las piezas que se le digan, sin servidor.
  Pasan: `run_tests.sh` 1685/0, `check.py`, las 52 smokes
  (`save_account_smoke.sh` con sus fases) y el empaquetado de escritorio
  (`pack_arenas.gd`: 338 capas de imagen).
- **Hojas:** `~/codigo/capturas/s54/14`–`16-lobby-imagen-*.png`, el lobby a
  1920×1080: a la izquierda hoy (el 3D a 5k), a la derecha la imagen; los
  dos coaches sin ropa y con un traje, y la mujer con el pelo de fuego.

Queda para el paso 4: las chispas de los efectos de pelo (hoy solo el
brillo); las prendas vivas en 2D (la gelatina tiembla, el oro brilla, la
llama del estandarte); la creación (cortada como el lobby), Equipo del
coach (entera) y la subida de nivel; y entonces sacar el 3D del coach y
sus prendas del arranque de la web (hoy van las dos cosas).

### Prueba: la ropa como hoy o como objeto propio (2026-11-27)

El dueño, tras ver las hojas del lobby: «es verdad que la ropa se ve mal,
¿podrías hacer la prueba de cómo lo hacemos actualmente y de cómo sería si
la ropa fuera un objeto adicional?».

- **Hoy:** cada prenda son las caras del cuerpo de 5k de su zona,
  empujadas hacia fuera. Copia los bultos del cuerpo (el top del original
  queda marcado debajo de la camiseta), el borde sigue los triángulos (en
  escalera) y sale tan facetada como el cuerpo de 5k.
- **Objeto propio (prueba, sin tocar el build):** la misma zona como punto
  de partida, pero luego tratada como una tela aparte: sus bordes alisados
  a lo largo, la tela entera relajada (olvida los bultos), empujada de
  nuevo fuera del cuerpo donde se mete, subdividida, y las franjas de color
  cortadas al final, rectas. Script en `~/codigo/capturas/s54/ropa/`
  (`garment_object.py`, una copia de `coach_garment.py` con `tailor()`).
  Tres intentos: el primero (relajar solo hacia fuera) salió peor; el
  tercero es el de las hojas.
- **Hojas:** `17-ropa-hoy-vs-objeto-mujer.png`,
  `18-ropa-hoy-vs-objeto-hombre.png` (arriba y pantalón kepika, el traje
  kepika entero, top de gelatina con pantalón jalabol) y
  `19-ropa-de-cerca-mujer.png`.
- **Lo que veo:** mejora el borde de arriba (sin escalera) y las franjas
  salen rectas; quedan sombras de bultos en el pecho, un agujero pequeño, el
  borde del cinturón arrugado, y el pantalón jalabol pierde su forma
  abombada (el relajado se la come). No es una mejora clara: la prenda
  sigue saliendo del cuerpo de Meshy, y por eso hereda sus bultos.
  Triángulos: 4–15k por prenda (hoy 600–1900); para el 3D de combate
  habría que reducirla.

**El dueño (2026-11-27):** «no me convence nada, así que hagamos una cosa:
pasa el coach male sin ropa y pasa a los luchadores, después hablamos de
ropa». Y a la pregunta de qué hacer con la ropa mientras: «por ahora no
tocamos la ropa, solo hagamos el remallado y después yo elijo/depuramos qué
hacer con la ropa». La ropa queda como está; la prueba, sin build.

### Paso 5 — los luchadores con la reducción limpia (2026-11-27)

- **Antes:** el original de Meshy de cada luchador (16–21k triángulos, una
  textura PNG de 2–4 MB) se reducía a 5k con el diezmado de Blender, el que
  deja astillas, y se quedaba con la textura de Meshy reducida.
- **Ahora:** los 24 con la reducción limpia (MeshLab, UV nuevas, color
  rehorneado del original), como el coach: `figures.json`
  `"hd_src": <su src>`, `reduce=clean`, `nearest=1`, `head_uv=2`. El build
  busca el original completo en `PIPPOP_MESHY_HD` y, si no está, en la
  carpeta de Meshy de ese nombre (`build.hd_original()`). Las invocaciones
  siguen como estaban (`meshy_summon.py` no tiene la reducción limpia).
- **Piloto:** Feca f y m (`20`/`21-luchador-feca_*.png`), luego los 24
  (`20`–`43-luchador-*.png`: de cerca y a tamaño de combate, hoy y nuevo).
  Revisados uno a uno: ninguno sale peor; se van las motas y rayas oscuras
  del diezmado (el agujero negro en el pelo de la Aniripsa f, las manchas
  en las piernas de varios, los trazos rotos de tinta en el pelo).
- **Medidas:** 5000 triángulos cada uno; los 24 GLB, 19 → 17 MB.
  Brazos parecidos a los dos lados salvo la Yopuka f (142/340), que ya
  estaba así (el arma en una mano); la Anutrof f usa el respaldo de pesos
  en 439 vértices, como antes (462).
- **Pies:** todos ≤ 3° salvo `walk` y dos golpes a 15,5°: la Sacrogrito f
  (ya estaba) y el Yopuka m (nuevo): el talón de atrás que se levanta en la
  estocada, se ve natural (hoja de lado mirada).
- **El dueño:** «osamodas_m mira la barbilla, feca_m los dedos y
  anutrof_f las manos». Los tres ya venían del original de Meshy:
  - Osamodas m: una aleta fina colgando de la barbilla. Nueva opción
    `--drop` (caras con una esquina dentro de una caja, en la figura
    limpia), con su caja en `figures.json`: 14 caras, la barbilla limpia.
  - Feca m y Anutrof f: en el original la mano descansa sobre la falda o
    las bolsas, y Meshy fundió los dedos con ellas; en el juego asoman
    puntas de tela. Probé tres arreglos (menos margen en la mano, mezclar
    los pesos alrededor, `claim_arm_verts` para que la mano se lleve lo que
    toca: el último funciona, la mano sujeta la falda o las bolsas). El
    dueño: «ignora el mensaje anterior … intenta arreglar esa cuña del
    osa». Y después: «sí, el arreglo lo has hecho bien, lo único que mis
    mensajes no llegaron a tiempo … es mejor hacerlo bien». Se quedan los
    dos: `--drop` en Osamodas m y `--claim_hands=1` en Feca m y Anutrof f
    (los otros dos intentos no cambiaban nada y no se quedan).
- **Comprobado:** `build.py` entero (887 s, `check.py` 0 fallos), los pies
  de los tres, `run_tests.sh` 1685/0, `fight_smoke`, `summon_smoke`,
  `coach_look_smoke`, `hub_smoke`, `first_play_smoke` (14/14).

### Prueba: la ropa pintada sobre la piel, como en WoW (2026-11-27)

El dueño, de otro gamedev: «WoW, por ejemplo, combina geosets y saca
resultados aceptables. Textura + geoset … con texturas se refiere a poner
la ropa encima de la malla. Haz una prueba rápida con la coach mujer y con
un set».

- **Cómo lo hace WoW:** la mayor parte de la ropa no es geometría: se pinta
  en la textura del cuerpo por zonas (brazos, torso, piernas, manos, pies),
  así que la ropa ajustada nunca la atraviesa; los **geosets** son trozos de
  malla del cuerpo que se encienden o apagan según lo que lleve (mangas,
  perneras, botas, falda); cascos, hombreras y armas van colgados de un
  hueso.
- **La prueba** (sin build, scripts en `~/codigo/capturas/s54/ropa/`): el
  traje kepika (torso y pantalón) sobre la coach mujer, en la imagen del
  lobby. `cloth_pose.py` (una copia de `coach_hd_pose.py`): en la pose de
  reposo, desde cada vértice del original sale un rayo a lo largo de su
  normal; donde da con la tela de la prenda (los materiales `cloth_*`, no
  sus cuernos), el vértice toma su color (80 299 de 363 656 vértices, 1 s).
  `coach_portrait_paint.gd`: el color del cuerpo lleva esa tela, la máscara
  no la tiñe, y de la prenda solo quedan como pieza sus cuernos.
  Tropiezos: los 363k rayos desde Python tardaban más de 30 min leyendo la
  normal vértice a vértice (con `foreach_get`, 1 s); el exportador sacaba
  el color de la máscara (hay que marcar la tela como color de render); y
  el color salía oscuro (hay que pasarlo a sRGB en el shader).
- **Hoja:** `~/codigo/capturas/s54/44-ropa-pintada-kepika.png` (hoy y
  pintada; arriba y pantalón solos, y el traje entero).
- **Lo que veo:** la ropa pintada sigue el cuerpo del original exactamente
  (sin huecos, sin bultos que atraviesen, el cinturón y el top del original
  se marcan debajo como tela ajustada) y se parece al resto de la figura.
  Lo que falla en la prueba: los bordes de las franjas salen borrosos y
  deshilachados (el color va por vértice y copia el borde de la prenda de
  5k), y se pierden los parches. Se arreglaría pintando con la receta de la
  prenda (franjas por altura, parches por ángulo) en vez de copiar la malla
  de 5k, y horneándolo en una textura (bordes nítidos). Para el combate
  sería lo mismo: una textura de ropa sobre la del cuerpo de 5k. Lo
  abultado (falda, pantalón abombado, botas, cuernos) seguiría siendo
  geometría: los geosets.

### Prueba: WoW + geoset con el traje kepika (2026-11-27)

El dueño: «¿y has usado geoset?» (no: solo la textura) y «haz la prueba de
estilo WoW + geoset … con la ropa kepika».

- **Textura:** la parte de arriba pintada sobre la piel, como en la prueba
  anterior, sin los vértices del brazo (su rayo daba con el costado del
  top y lo manchaba).
- **Geoset:** el pantalón y las botas. En el posado, cada cara del
  original que queda bajo la prenda (un rayo a lo largo de su normal da con
  ella a menos de 12 cm) se borra: 123 647 caras bajo el pantalón y 71 452
  bajo las botas; en su lugar va la malla de la prenda, la tela subdividida
  una vez (los cuernos sin subdividir: si no, se vuelven gotas). Lo que
  tapa a la prenda en la imagen es el original sin piernas (las manos
  siguen delante).
- **Hojas:** `45-ropa-wow-geoset-entera.png` (entera: hoy y WoW + geoset,
  solo arriba, pantalón y botas, y con el traje entero) y
  `46-ropa-wow-geoset-lobby.png` (a medio muslo). Scripts en
  `~/codigo/capturas/s54/ropa/` (`cloth_pose_geo.py`,
  `coach_portrait_geo.gd`, `subdiv.py`).
- **Lo que veo:** el pantalón y las botas como geoset salen redondos, sin
  facetas ni piel que asome, y con sus cuernos; la parte de arriba pintada
  sigue el cuerpo. Quedan: el borde del top del original asoma por encima
  de la parte de arriba (su dobladillo queda más bajo), unas marcas
  oscuras en lo alto de los brazos, y las franjas del pantalón algo
  onduladas por la subdivisión.

### Prueba: la ropa con la skill blender-clothing (2026-11-27)

El dueño, tras la prueba WoW + geoset: «mmmm se ve fatal. Busca y usa
blender-clothing». Y: «prueba también este:
skillsdirectory.com/skills/arjun988-cloth-sim».

- **blender-clothing** (`garment.py`): la prenda ajustada se hace del
  cuerpo (extraer la zona, soltarla del cuerpo, darle grosor), con los
  pesos del cuerpo copiados y la piel que tapa oculta. La usé sobre el
  original de 676k, no sobre la figura de 5k: la zona de cada prenda es lo
  que tapa la prenda de hoy (un rayo por vértice), 6 mm de holgura; el
  color de cada cara, el de la tela de hoy más cercana. Scripts en
  `~/codigo/capturas/s54/ropa/` (`hd_clothes.py`, `coach_portrait_hdc.gd`).
- Tropiezos: los grupos de la prueba (la zona y la piel oculta) se
  copiaban como pesos y quitaban sitio a los huesos (el dueño: «¿y por qué
  no ajustas los pesos en vez de quitarlos?»: se quitan solo esos grupos,
  los de los huesos se quedan y se normalizan); seguían saliendo pinchos de
  cientos de metros: el grosor (`Solidify` con `use_even_offset`) explota
  en las caras diminutas del original, así que la prueba va sin grosor; y
  las manos, junto al pantalón, quedaban dentro de él.
- **Hoja:** `47-ropa-blender-clothing.png`.
- **Lo que veo:** la prenda sigue la forma del cuerpo del original (más
  fina que la de hoy, sin facetas ni piel que asome); los bordes de color
  siguen borrosos (copiados de la prenda de 5k) y queda una rendija clara
  en la cadera.
- **arjun988-cloth-sim:** una guía (sin scripts) para simular tela en
  Blender: pines, colisión, asentado y horneado a shape keys. Sirve para
  lo suelto (faldas, capas, estandartes), no para la ropa ajustada:
  pendiente de probar con una falda o una capa.

## Respuestas del dueño (2026-11-27, tras el recuento)

- **El hub:** «dejamos el hub 2D en los muslos»: la imagen, como el
  lobby de hoy; la creación igual; Equipo del coach entera.
- **Los efectos** (chispas del pelo, prendas vivas en 2D): «los
  arreglaremos en el futuro. Todo debería ser arreglado»: no cierran S54,
  pero quedan anotados, no olvidados.
- **La ropa:** pasa a [S55](./S55-afinar-piezas.md), prenda a prenda.

Queda en S54: la creación, Equipo del coach y la subida de nivel con la
imagen; el 3D del coach fuera del arranque de la web y las medidas
antes/después; las invocaciones con la reducción limpia; los pies que
quedan (Sram f, invocaciones criatura); la partida entera de S53 en web.
