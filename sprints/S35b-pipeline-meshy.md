# S35b — Pipeline Meshy → luchador (una clase por sesión)

**Planificado:** 2026-11-10 · **Hito:** M7 — Arte propio · **Tamaño:** S por figura · **Estado:** 🔵 abierto (piloto Feca f y m aprobado por el dueño, 2026-11-10)

Receta para empezar **limpio**: una sesión por figura (o por clase, f y m),
sin releer S35 entero. Todo lo de aquí se probó en el piloto Feca (S35,
"Piloto Feca f y m"). Dueño, 2026-11-10: "ok todo ok … me gustaría empezar
limpio cada clase y cada asset".

## Entrada

- GLB de Meshy en `~/codigo/capturas/s35/meshy/<carpeta>/<carpeta>.glb`
  (p. ej. `02_osamodas_f/02_osamodas_f.glb`). Pose A, una malla, textura
  2048, sin esqueleto, 0,95 de alto.
- Qué figura es cada clase: `godot/art/characters/meshy_map.json` y la
  tabla de S35 ("Lote 1 de Meshy").
- Solo los GLB de Pippop; los de Ferinia (`_ferinia/`) no se tocan.

## Pasos

Desde `godot/`. `S` = un directorio de trabajo (scratchpad), `C` =
`~/codigo/capturas/s35`, `N` = nombre de salida (`osamodas_f`).

**1. Construir** (limpieza, escala 1,45, 5.000 triángulos, textura 1024,
20 huesos, pesos, 10 animaciones):

```
blender -b -P tools/blender/characters/meshy_fighter.py -- \
    ~/codigo/capturas/s35/meshy/02_osamodas_f/02_osamodas_f.glb art/characters/out/$N.glb --debug=$S
```

Mirar la línea `[meshy] … {json}`: `landmarks` (tobillo, entrepierna,
axila, alto del hombro, hombro, cuello), `tris`, `textures`, `arm_cut`,
`arm_verts` (los dos lados parecidos), `heat_fallbacks`, `glb_kb`.

**2. Revisar los huesos** sobre la radiografía (`$S/$N_bones_front.png` y
`_side.png`) **antes** de mirar animaciones:
- hombro justo bajo lo alto del hombro, no en el bíceps (corrección del
  dueño en el piloto);
- codo en el codo, muñeca en la muñeca, la mano hasta la punta de los dedos;
- cadera en la entrepierna (no en la rodilla si el pantalón se toca);
- rodilla a media pierna, tobillo dentro del zapato, pie hacia delante.

Si algo cae mal: un JSON con las articulaciones a corregir
(`{"upper_arm.L": [x, y, z], …}`, nombres de `bones_from()`) y
`--joints=<json>`; guardarlo junto al GLB de Meshy (`<carpeta>/joints.json`)
y apuntarlo en la tabla de abajo.

**3. Revisar los pesos:** `$S/$N_arm_front.png` / `_back.png` (rojo = brazo
izquierdo, naranja = derecho, azul = candidato rechazado). El brazo entero
pintado hasta los dedos; nada de ropa, capa ni mochila en rojo.

**4. Poses difíciles de cerca** (brazos arriba: llevar, celebrar, lanzar):

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -s tools/art/anim_sheet.gd -- \
    --model=art/characters/out/$N.glb --out=$S/zz --frames=3 --dirs=S,E,N,W --zoom=6 \
    --size=500x600 --focus=0.8 --anims=carry_loop,celebrate,melee
```

Buscar: telas estiradas ("alas") de la mano a la cadera, hilos, esquirlas
bajo el hombro, ropa o mochila que sube con los brazos, brazos que se
cruzan delante del pecho.

**5. Hojas para el dueño** (`$C`):

```
xvfb-run … anim_sheet.gd -- --model=art/characters/out/$N.glb --out=$S/full --frames=6 --dirs=SE,NW --zoom=2 --size=240x280
python3 -I tools/art/anim_sheet.py $S/full $C/s35-$N.png            # → -1.png, -2.png
xvfb-run … anim_sheet.gd -- --model=art/characters/out/$N.glb --out=$S/vid --video --dirs=SE,SW,NE,NW --zoom=2 --size=240x280
python3 -I tools/art/anim_sheet.py $S/vid $C/s35-$N.mp4
tools/art/four_views.sh art/characters/out/$N.glb $C/s35-$N-4vistas.png $N 400
```

**6. En combate:** añadir la clase a `Fighter3D.MODELS`
(`src/anims/fighter3d.gd`, `breed: ["<m>", "<f>"]`; el breed es el número de clase, 2 = Osamodas) y probar sin servidor:
en `test/fight_ui_preview.gd`, `FIGHT_UI_FECA=1` pone breed 1 a Arel (m) y
Brune (f); para otra clase cambiar ese número (o añadir una variable
`FIGHT_UI_BREED`). Luego:

```
FIGHT_UI_FECA=1 FIGHT_UI_FOCUS=1,2 FIGHT_UI_SHOT=$C/s35-$N-combate.png \
    xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --resolution 1280x720 test/fight_ui_preview.tscn
```

(`FIGHT_UI_FOCUS=2,2` para la f.) Un combate real solo si hay una
repetición con esa clase (`tools/reel/make_reel.sh`; listar las clases de
cada `.slr` como en S35) o el servidor local en marcha (`tools/reel/record.gd`).

**7. Cerrar:** `./run_tests.sh` (headless + visual), apuntar la fila en la
tabla de abajo y una línea en S35 si salió algo nuevo; commit y push.

## Fallos conocidos y qué hacer

| Síntoma | Causa | Arreglo |
|---|---|---|
| `can't find arm X apart from the body` | brazos pegados al cuerpo en todo el alto | `--joints` con hombro, codo, muñeca y punta |
| cadera en la rodilla | el pantalón se toca en la rodilla | ya resuelto (hueco más alto); si no, `--joints` |
| la cadera en el bajo de una falda larga | solo bajo la falda hay hueco entre las piernas | `--joints` con `hips`, `spine`, `chest`, `thigh.S` y `shin.S` (Anutrof f) |
| un rizo de pelo junto a la cara tomado por el brazo | una pieza suelta bajo 0,72 del alto | ya resuelto: el brazo es un tramo de 3 cortes o más |
| pulgares flotando junto a la cadera | el pulgar es una pieza aparte, delante de la mano | ya resuelto en `extend_hand` (suma piezas pequeñas pegadas a la mano y da 5 cm de holgura bajo la muñeca); hace falta `--joints` con `hand_tip.S` |
| la mano corta o larga | la mano toca la ropa (se alarga 6,5 % del alto) | `--joints` con `hand.S` y `hand_tip.S` |
| manos sin pintar bajo un brazal fundido al cinturón (`hand_hidden` y la mano por debajo) | el brazo solo se ve suelto por encima; la mano, más estrecha que el brazal, no entra | `--joints` con `hand.S` y `hand_tip.S` más abajo: `extend_hand()` suma las piezas de la mano y, en el tramo fundido, el borde interior más estrecho y el exterior de la pieza fundida (Osamodas m) |
| migas de ropa en las manos | Meshy fundió la ropa con la mano | aceptado a escala de juego; anotarlo |
| agujeritos oscuros en cintura/abrigo | el corte de las uniones fundidas | aceptado; anotarlo |
| algo grande sube con los brazos (capa, alas, mochila) | pesos de brazo por encima del corte | revisar el render de pesos; bajar el 2,2 × radio en `skin()` solo si hace falta |
| figura sin forma humana (alas grandes, cola, criatura) | el ajuste busca dos brazos y dos piernas | parar y preguntar al dueño |

## Fuera de esta receta

- **Invocaciones** (8001–8009): no son humanas; antes hay que decidir el
  rig con el dueño. **8010** es un cristal rígido que modelo yo (S35).
- **Coaches** 7000/7001: humanos, valen con esta receta, pero en combate no
  pasan por `Fighter3D` (son el jugador, no luchadores).
- Viewport compartido para 12 luchadores y la sombra en el suelo: trabajo
  aparte, después de las clases.

## Tabla de figuras

| Carpeta | Salida | Huesos revisados | `--joints` | Hojas | Combate | Notas |
|---|---|---|---|---|---|---|
| 01_feca_f | feca_f | ✅ | — | ✅ | ✅ | piloto |
| 01_feca_m | feca_m | ✅ | — | ✅ | ✅ | piloto; migas de abrigo en las manos |
| 02_osamodas_f | osamodas_f | ✅ | — | ✅ | ✅ | limpio; agujeritos oscuros en la cadera (aceptado) |
| 02_osamodas_m | osamodas_m | ✅ | `hand.L/R` (±0,215, 0,055, 0,625), `hand_tip.L/R` (±0,205, 0,04, 0,52) | ✅ | ✅ | brazales fundidos con las borlas del cinturón: sin `--joints` las manos quedaban fuera del brazo; con ellas, `extend_hand` (abajo) |
| 03_anutrof_f | anutrof_f | ✅ | `hips` 0,52, `spine` 0,624, `chest` 0,75, `thigh.L/R` 0,52, `shin.L/R` 0,30 | ✅ | ✅ | falda larga: la entrepierna sale en el bajo (0,36); las manos agarran las bolsas (fundidas): esquirlas de bolsa al subir los brazos, aceptado a escala de juego |
| 03_anutrof_m | anutrof_m | ✅ | `forearm.L/R` (±0,193, 0,08, 0,85), `hand.L/R` (±0,24, 0,035, 0,64), `hand_tip.L/R` (±0,23, 0,03, 0,55) | ✅ | ✅ | guanteletes anchos: la mano se cortaba en el puño; el pulgar (pieza aparte, delante) se quedaba en la cadera |
| 04_sram_f | sram_f | | | | | |
| 04_sram_m | sram_m | | | | | |
| 05_xelor_f | xelor_f | | | | | |
| 05_xelor_m | xelor_m | | | | | |
| 06_zurcarak_f | zurcarak_f | | | | | |
| 06_zurcarak_m | zurcarak_m | | | | | |
| 07_aniripsa_f | aniripsa_f | | | | | alas |
| 07_aniripsa_m | aniripsa_m | | | | | alas |
| 08_yopuka_f | yopuka_f | | | | | |
| 08_yopuka_m | yopuka_m | | | | | |
| 09_ocra_f | ocra_f | | | | | |
| 09_ocra_m | ocra_m | | | | | |
| 10_sadida_f | sadida_f | | | | | |
| 10_sadida_m | sadida_m | | | | | |
| 11_sacrogrito_f | sacrogrito_f | | | | | hay `_alt` |
| 11_sacrogrito_m | sacrogrito_m | | | | | |
| 12_pandawa_f | pandawa_f | | | | | |
| 12_pandawa_m | pandawa_m | | | | | |
| coach_7000_m | coach_7000 | | | | n/a | |
| coach_7001_f | coach_7001 | | | | n/a | |

## Criterio de cierre

Las 24 filas de clase con huesos revisados, hojas y combate, y los dos
coaches con hojas. Las invocaciones se planifican aparte.
