# S35b-marketing — Tanda 3: cómo se le pone esqueleto a una figura

**Planificado:** 2026-11-10 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ✅ cerrado 2026-11-11: los 9 posts en `tanda-3/`

Dueño, 2026-11-10: "crear la 3ª tanda de posts para el marketing, sobre
todo sobre cómo has hecho los esqueletos, que se vean las capturas o cosas
simuladas, que llamen la atención". Sale de S35/S35b: 24 luchadores, 2
coaches y 9 invocaciones de Meshy convertidos en piezas de juego con
huesos, pesos y 10 animaciones.

## Reglas que ya estaban

- Solo **Instagram + TikTok**; reel 9:16 (`.mp4`, sin música: el sonido
  se pone en la app) y carrusel 4:5 (`.png`). Textos y hashtags en
  **inglés**, en `texto.txt` por post (como la tanda 2).
- El juego es **Pippop Arena**; nunca "StarLoco" ni el retail en imagen,
  texto, nombre de archivo ni metadatos.
- Nada del cliente retail en pantalla: ni sprites antiguos, ni la hoja
  de referencia de 8010, ni el combate con luchadores 2D al lado. Los
  fondos de combate solo de las arenas aprobadas para marketing (1–6).
- Decido yo el orden, los textos y el montaje (dueño, 2026-11-05); entrego
  posts terminados. Hojas a tamaño de pantalla, nunca tiras largas.

## Salida

`~/codigo/marketing/tanda-3/`, una carpeta por post numerada desde el 30
(la tanda 2 acaba en el 28), con su `LEEME.md` igual que la tanda 2. El
código que genera las imágenes va en `godot/tools/promo/` (y Blender en
`godot/tools/blender/characters/`), para poder rehacerlas.

## Posts (propuesta)

| # | Tipo | Título | Qué se ve |
|---|---|---|---|
| 30 | reel | From statue to fighter | Figura de Meshy en pose A, gris → aparecen los huesos uno a uno (radiografía) → se pinta la piel → empieza a andar. 10–12 s |
| 31 | carrusel | How the bones find themselves | 1: la figura cortada en lonchas horizontales (render de cortes, colores por pieza). 2: las lonchas marcan tobillo, entrepierna, axila, cuello. 3: el esqueleto de 20 huesos encima. 4: la misma regla en tres figuras distintas |
| 32 | reel | Weight painting, explained in 8 seconds | Mapa de pesos animado: rojo/naranja = brazos; el brazo sube y lo pintado sube con él; mismo plano sin el corte → la manga "ala" que se estira (antes / después) |
| 33 | carrusel | Bugs we hit (and fixed) | Antes/después a pares: pulgar flotando junto a la cadera, bufanda tomada por brazo, alas tomadas por brazos, hombro en la decoración del bíceps (Pandawa), volantes que se quedaban en el pecho. Rótulo corto en cada par |
| 34 | reel | 24 fighters, one skeleton | Rejilla de los 24 luchadores haciendo la misma animación a la vez (celebrate, luego melee), cámara que se acerca |
| 35 | carrusel | Not everything has two arms | Pollito, oveja y pangolín: su esqueleto corto en radiografía + un fotograma de su andar; gólem con cada piedra rígida |
| 36 | reel | The crystal | 8010 de cero en Blender: óvalo, marco, rayos, el giro; acaba flotando en una arena |
| 37 | carrusel | Under the hood | Números: 5.000 triángulos, 20 huesos, 10 animaciones, 1024 px, ~800 KB por luchador; la línea `[meshy] {…}` del log como imagen "de terminal" |
| 38 | reel | In the arena | Plano de combate en una arena 1–6 con solo figuras 3D: un luchador lanza, la invocación aparece, golpe, celebración |

Si alguno no llama la atención al verlo montado, se cambia o se quita y
se apunta aquí por qué.

## Cómo (para la sesión)

1. **Renders nuevos** (todo con lo que ya hay, sin tocar los GLB del
   juego):
   - radiografía animada: `meshy_fighter.py --debug` ya pinta huesos y
     pesos; hace falta una versión por fotogramas (huesos apareciendo) en
     Blender headless;
   - lonchas: un render de los cortes de `Slicer` como discos de colores
     sobre la malla;
   - antes/después: rehacer las figuras con las opciones quitadas
     (sin `--sleeve`, sin `hand_tip`, script anterior a cada arreglo:
     `git show <commit>:…meshy_fighter.py`) en una carpeta temporal y
     sacar el mismo fotograma de `anim_sheet.gd`;
   - rejilla de 24: `anim_sheet.gd` por figura y montaje con PIL/ffmpeg.
2. **Combate solo 3D**: `fight_ui_preview` con las 7 fichas en clases 3D
   (ampliar `FIGHT_UI_BREED` a una lista por fid) y arena 1–6; sin UI
   retail a la vista.
3. **Montaje** en `godot/tools/promo/` (reutilizar `reels.py` /
   `*_cards.py` de `_fuentes/`): tipografía y colores de la tanda 2,
   logo de Pippop Arena, rótulos en inglés.
4. **Revisión** de cada post a tamaño móvil antes de darlo por bueno
   (legible, nada retail, nombre correcto) y `LEEME.md` con el orden.

## Criterio de cierre

Los 9 posts (o los que queden tras la revisión) en `tanda-3/` con su
`texto.txt`, `LEEME.md` con el orden y el ritmo, y las herramientas
nuevas en el repo.

## Hecho (2026-11-11)

Los 9 posts en `~/codigo/marketing/tanda-3/` con `texto.txt` y `LEEME.md`.
Herramientas nuevas (todas leen los GLB del juego, ninguna los toca):

- `godot/tools/blender/characters/promo_bones.py`: capas por fotograma
  (arcilla, radiografía, textura, mapa de pesos) y las articulaciones en
  pantalla (`joints.json`); los huesos se dibujan luego en PIL, así el
  estilo cambia sin volver a renderizar.
- `promo_slices.py`: las lonchas de `Slicer` como anillos de colores por
  número de piezas, con las alturas de tobillo/cadera/axila/cuello.
- `promo_naive.py`: la figura con solo los pesos automáticos de Blender
  (para comparar; ver abajo por qué no se usó).
- `promo_crystal.py`: el 8010 pieza a pieza con las funciones de
  `crystal_8010.py` (que ahora solo construye con `__main__`).
- `godot/tools/promo/fight_promo.gd/.tscn`: combate en escena, 6
  luchadores 3D y una oveja invocada, HUD oculto, para el movie maker.
- `godot/tools/promo/tanda3_render.sh` (renders a
  `~/codigo/marketing/_fuentes/raw3/`) y `tanda3.py` (montaje, mismo tipo
  y colores que la tanda 2).

## Decisiones (sin dueño, por heurística)

- **32 no compara con los pesos de Blender a pelo**: probados en 5
  figuras (`promo_naive.py`), salen casi iguales que los míos a tamaño
  móvil; los fallos de verdad vinieron de dónde caían los huesos. El
  antes/después del 32 es la bufanda (script anterior a `0d5f2420`), con
  el mapa de pesos al lado.
- **33 con 5 bugs, no 7**: cada "antes" es real: `meshy_fighter.py` del
  commit anterior al arreglo (`git archive`) o la opción quitada
  (sin `hand_tip` en la Sram f). Fuera las aletas del Xelor m (sin
  `--arm_slack`), las mangas de la Pandawa f (sin `--sleeve`) y las tiras
  del coach 7001 (sin `--cut`): a tamaño móvil no se ven. (Con solo los
  pesos de Blender la Pandawa f sale sin esqueleto: el cálculo falla.) Los hombros de la Aniripsa f van en
  radiografía (con textura no se nota).
- **Ningún nombre de clase en imagen ni texto** (son del retail): la
  línea del log del 37 dice `fighter_01`; los rótulos del 38 dicen "a
  summon", "a strike"…
- **38 es un combate en escena, no uno real**: no hay servidor en esta
  máquina y las repeticiones guardadas son de antes de las arenas 1–6.
  Arena 5, HUD oculto (la arena 3D es un CanvasLayer de capa -1: solo se
  ocultan las capas ≥ 0).
- El 34 acerca la rejilla 2,2× y pasa a un primer plano renderizado
  grande: con zoom de imagen se pixelaba.
