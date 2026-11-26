# S54 — Figuras ligeras: 3D para jugar, imagen para mirar

**Planificado:** 2026-11-26 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** 📝 redactado (2026-11-26), a la espera del dueño

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
   - 2–4 ángulos (frente, tres cuartos; perfil y espalda si el menú los usa);
   - un reposo animado suave (respirar, balanceo), con AniCraft o con el
     mismo truco de los retratos de NPC (`npc_anim.py`).

Por qué renderizado y no ilustrado: dibujar 104 prendas por coach en vex es
mucho trabajo; renderizarlas es automático, y la imagen casa con el 3D del
combate. La ilustración queda para retratos y splash.

## Plan

### Paso 0 — Prueba antes de rehacer nada (S)

Una hoja con la mujer renderizada del original de 676k al lado del 3D
actual, **en la pantalla de creación**, con dos colores de pelo y dos de
piel. El dueño decide si merece la pena. Si no, se cierra aquí y se queda
el 3D de 40k.

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

## Preguntas al dueño

1. ¿Te convence el híbrido (3D de 5k en combate, imagen en los menús), o
   prefieres ilustración dibujada para los menús aunque cueste más?
2. ¿Qué ángulos quieres ver del coach en los menús: solo de frente, o que
   se pueda girar (frente, tres cuartos, perfil, espalda)?
3. ¿Hago primero la prueba del paso 0 y esperamos, o sigo seguido?
