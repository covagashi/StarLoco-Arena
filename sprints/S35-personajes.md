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
- **Proporción:** 1,30 celdas sin sombrero (~70 px a zoom 1), cabeza ~37 %;
  el sombrero de cada clase la lleva al 45 % de la hoja de estilo.

## Paso 1: rig y animaciones base (2026-11-04)

Un muñeco neutro (túnica, cinturón, botas, ojos) para ver el esqueleto y
las animaciones; no es ninguna clase.

```
blender -b -P godot/tools/blender/characters/mannequin.py      # → art/characters/out/mannequin.glb
xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot -s tools/art/anim_sheet.gd -- \
    --out=<dir> --frames=6 --dirs=SE,NW --zoom=2 --size=240x280      # o --video
python3 -I godot/tools/art/anim_sheet.py <dir> <hoja.png | video.mp4>
```

- `mannequin.py`: cuerpo de esferas fundidas (remesh por vóxel, suavizado,
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
- Bajar a ≤4.000 triángulos por luchador (12 en pantalla, demo web en
  móviles de 2 GB, S44); la cabeza aún muestra facetas del decimado.
- Meter el actor 3D en `fight_view`: la arena se pinta **una vez** en un
  SubViewport y los actores son sprites 2D encima con un oclusor de
  profundidad (`arena_view.gd`); el luchador 3D necesita un viewport
  compartido que respete esa profundidad (el coste medido en S33 era por
  viewport y luchador).
- El dueño revisa el esqueleto y las animaciones antes de empezar las
  clases (paso 2).
