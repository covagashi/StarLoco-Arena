# S54 — Figuras ligeras: 3D para jugar, imagen para mirar

**Planificado:** 2026-11-26 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** 🔵 en curso (2026-11-27): pasos 0–2 hechos; el 3, probado aparte (40k contra 5k), a la espera de que el dueño compare las hojas

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
