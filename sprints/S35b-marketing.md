# S35b-marketing — Tanda 3: cómo se le pone esqueleto a una figura

**Planificado:** 2026-11-10 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🔵 abierto (empieza en la próxima sesión)

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
