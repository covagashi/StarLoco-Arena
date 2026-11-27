# Pipeline de figuras: de Meshy al juego

Un solo sitio para meter una figura nueva (un luchador, un coach, una
invocación) sin leer código. Recoge lo que estaba repartido entre las
cabeceras de los scripts y los sprints S35, S35b, S35c, S47, S53 y S54.

```
Flow → Meshy (dueño)        GLB en pose A, 1 malla, 1 textura
   │
   ▼
figures.json                 la receta de cada figura (qué original, qué opciones)
   │
   ▼
build.py figuras             Blender: meshy_fighter.py / meshy_summon.py
   │                         (limpiar, reducir, UV y color, huesos, pesos,
   │                          brazos abajo, animaciones) → out/<nombre>.glb
   ├── coaches: coach_masks.py      máscara de piel y pelo → <nombre>_mask.png/.json
   ├── coaches: coach_garment.py    las prendas que se doblan → equipment/out/garments/
   ├── coaches: coach_hd_pose.py    el original posado en la pose del menú → out/hd/ (no se publica)
   ├── coaches: coach_portrait.gd   la imagen de los menús en capas → out/portraits/ (S54)
   ▼
check.py                     presupuestos, nombres, alturas, animaciones, máscaras
   │
   ▼
revisión con hojas           coach_sheet.gd, anim_sheet.gd/.py, four_views.sh, QA de Blender
   │
   ▼
Fighter3D (fighter3d.gd)     el juego la carga, la viste con toon.gd y la anima
```

Todo se lanza desde `godot/`.

## Lo que hace falta fuera del repo

| Qué | Dónde | Para qué |
|---|---|---|
| Blender 5.2.3 | `~/.local/opt/blender-5.2.3-linux-x64`, en el PATH como `blender` (o `BLENDER=`) | todos los pasos de Blender |
| pymeshlab | en el Python de Blender: `<blender>/5.2/python/bin/python3.* -m pip install --no-deps --target ~/.config/blender/5.2/scripts/addons/modules pymeshlab` | `--reduce=clean` (la reducción limpia) |
| Originales de Meshy | `PIPPOP_MESHY` (por defecto `~/codigo/capturas/s35/meshy/<carpeta>/<carpeta>.glb`) | el `src` de cada figura |
| Originales completos | `PIPPOP_MESHY_HD` (por defecto `~/codigo/capturas/s47/meshy-hd/<nombre>.glb`, unos 676k triángulos) | el `hd_src` (coaches) |
| Godot 4.7.1 y `xvfb-run` | `~/.local/bin/godot` | hojas y pruebas (renderizan) |
| numpy, Pillow | Python del sistema | `coach_masks.py`, las hojas |

Los originales no van a git (sin LFS): viven en `~/codigo/capturas` y en
el RAID del homelab. **No se borran nunca.**

## 1. La receta: `art/characters/figures.json`

Una entrada por figura, con el nombre de salida como clave:

```json
"coach_7001": {
  "script": "meshy_fighter.py",
  "src": "coach_7001_f_hd",
  "hd_src": "coach_7001_f_hd",
  "opts": {"tris": "5000", "reduce": "clean", "tex": "1024", "head_uv": "2", "lower_arms": "10", "menu": "1", …},
  "joints": true
}
```

- `script`: `meshy_fighter.py` (humanoides), `meshy_summon.py`
  (invocaciones: también criaturas) o un script que modela la figura él
  mismo (`crystal_8010.py`, sin `src`).
- `src`: la carpeta del original en `PIPPOP_MESHY`.
- `hd_src`: el original completo en `PIPPOP_MESHY_HD`; con
  `reduce=clean` la malla y el color salen de él.
- `joints: true`: hay correcciones de huesos en `art/characters/joints/<src>.json`.
- `opts`: las opciones de abajo, como texto.

Para que el juego la dibuje, la figura tiene que estar además en la tabla
de `src/anims/fighter3d.gd` (`MODELS` para luchadores por clase y sexo,
`COACHES`, `SUMMONS`).

## 2. Construir: `tools/art/build.py`

```
python3 tools/art/build.py feca_f          # solo esa figura (y luego check.py)
python3 tools/art/build.py --force coach_7001
python3 tools/art/build.py --dry-run       # qué está desfasado
```

Cada paso guarda un sello con el hash de lo que leyó (`out/.build.json`):
solo se reconstruye lo que cambió. Tras las figuras van las máscaras de
los coaches y sus prendas, y al final `check.py`; si un check falla, el
build falla.

### Lo que hace `meshy_fighter.py`, en orden

| Paso | Qué hace | Opciones |
|---|---|---|
| Limpiar | une las mallas, suelda las costuras que deja Meshy, quita migas, escala a **1,45** de alto, pies en z=0 y centrados, mirando a −Y | — |
| Reducir | `--reduce=clean`: la malla sale del original completo, soldada y reducida con MeshLab (sin astillas), con **UV nuevas** y el color del original **rehorneado**; sin él, el decimado de Blender y la textura de Meshy reducida | `--tris` (5000), `--tex` (1024), `--jpeg` (90), `--nearest=1` (cada téxel toma el color del punto más cercano que mira igual), `--head_uv=2` (las piezas de la cabeza con el doble de téxeles por lado: los ojos a 1024²), `--charts`, `--unwrap`, `--bake_margin`, `--bake_extrusion` |
| Articulaciones | busca piernas, entrepierna, brazos, axila, cuello en cortes horizontales; un JSON de `joints/` corrige las que caen mal | `--joints`, `--debug=<dir>` (cortes y radiografía de huesos) |
| Huesos | los 20 huesos comunes (`fighter1.BONES`) | — |
| Pesos | pesos de calor de Blender; cada vértice se queda solo con los huesos cercanos (máx. 4); por encima del cuello, con la cabeza; el brazo se corta del cuerpo en la axila | `--arm_slack` (0,03; 0,06 con armadura en el brazo), `--arm_flap` (una pieza fina pegada fuera del brazo es brazo: el borde de un guante), `--sleeve` (2,2), `--thumb`, `--cut=<z>` |
| Brazos abajo | originales en pose A: los brazos bajan a `deg` grados de la vertical y esa pose pasa a ser el reposo | `--lower_arms=10` |
| Animaciones | las 10 de `rig_anims.py` (`idle_loop`, `walk_loop`, `cast`, `melee`, `hit`, `die`, `jump`, `celebrate`, `carry_loop`, `throw`); con `--menu=1` también `menu`, `greet` y `pose` (los coaches) | `--menu`, `--overhead_out` (40) |
| Exportar | un GLB con malla, esqueleto y una pista por animación; `--weld_normals=1` da una normal y unos pesos por posición (las costuras no se abren y la tinta no hace pinchos) | `--weld_normals`, `--drop_weapon=1` (quita el arma fundida en la mano: el arma es la carta) |

Mirar siempre la línea `[meshy] … {json}` que imprime: `landmarks`,
`tris`, `arm_cut`, `arm_verts` (los dos lados parecidos),
`heat_fallbacks`, `arms_lowered_from`, `glb_kb`.

Tiempos en el Ally: el `build.py` entero, 5 min 32 s (S53); el posado
del original de un coach (`coach_hd_pose.py`, que hace la reducción y los
pesos), 30 s.

### Solo los coaches

- **Máscara de piel y pelo** (`tools/art/coach_masks.py coach_7000 coach_7001`):
  el coach trae una sola textura, así que piel y pelo son una máscara
  (`<nombre>_mask.png`: R piel, G pelo) y un brillo de referencia por canal
  (`_mask.json`, percentil 80 en luz lineal). `toon.gdshaderinc` tiñe esos
  téxeles al color elegido conservando el sombreado. `--sheet=out.png`
  saca una hoja de la máscara.
- **Prendas** (`tools/blender/characters/coach_garment.py`, recetas en
  `art/equipment/garments.json`): torso, pantalón, botas y falda hechos con
  las propias caras del cuerpo empujadas hacia fuera (`ease`), con los
  pesos de la piel de debajo, así que se doblan igual y no dejan pasar la
  piel; marcas (tatuajes) con su emblema. Una prenda por GLB en
  `art/equipment/out/garments/<coach>/`.
- **Imagen de los menús** (S54): en los menús el coach no es el 3D sino
  una imagen del original completo, de frente y a la altura de los ojos.
  1. `coach_hd_pose.py` pone el original (676k) en el fotograma 0 del clip
     del menú con el esqueleto de la figura construida (los mismos pasos y
     opciones que ella, así que las articulaciones coinciden y la ropa
     encaja) y le pasa la máscara de piel y pelo por cercanía.
     `out/hd/<coach>.glb`, unos 40 MB: solo para el build, nunca se publica.
     30 s.
  2. `tools/art/coach_portrait.gd` (Godot, bajo xvfb) lo renderiza con la
     luz y la tinta del juego (el sol girado con la cámara, como la
     dirección de frente) en capas: `body_lit` (color sin luz, con su
     tinta), `body_light` (la luz sola, una figura gris al 50 %),
     `body_mask` (R piel, G pelo, sin pérdida), y **cada pieza** que el
     coach puede ponerse, encendida, en su propia capa: se renderiza sola y
     luego con la figura construida en negro delante, y solo queda lo que la
     figura no tapa (con la figura construida y no con el original: las
     piezas se hicieron para ella, y la piel del original asomaría). Las
     prendas con vida (gelatina) se renderizan quietas. WebP, recortadas,
     con `index.json` (lienzo, rectángulos, suelo, brillo de referencia de
     la máscara). Encuadres (`FRAMES`): `thigh`, desde medio muslo (lobby y
     creación); `whole`, entera (Equipo del coach). Unos 50 s y 2,1 MB por
     coach y encuadre, las 165 piezas que caben.
  3. En el juego, `src/anims/coach_portrait.gd` (`CoachPortrait`) las
     compone: tiñe el cuerpo con la máscara como `toon.gdshaderinc`
     (también el brillo de los efectos de pelo), apila las piezas por
     ranura, respira y da un saltito donde el 3D saludaba.
  `build.py` hace los dos pasos tras las prendas (`--frame` en
  `PORTRAIT_FRAMES`). Para ver un coach en el lobby sin servidor:
  `xvfb-run -a godot --path . --resolution 1920x1080 -s test/lobby_coach_sheet.gd -- --out=<png> --sex=1 --hair=3 --pieces=hat_kepika,torso_kepika`.

## 3. Comprobar: `tools/art/check.py`

```
python3 -I tools/art/check.py
```

| Figura | Triángulos | Huesos | Textura | GLB |
|---|---|---|---|---|
| luchador / invocación | 5 000 | 20 | 1024² | 1200 KB |
| coach | 5 000 | 20 | 1024² | 1200 KB |
| prenda de coach | 3 500 | — | — | 256 KB |
| pieza de equipo | 1 500 | — | — | 256 KB |

Desde S54 el coach tiene el presupuesto de los luchadores (antes 40 000, 2048² y 2600 KB): en los menús va la imagen del original.
Además: 1,45 de alto con los pies en el suelo y centrados, las 10
animaciones, que cada figura que dibuja `Fighter3D` tenga receta y que los
coaches tengan máscara y su imagen de los menús en cada encuadre (todas
sus capas, como mucho 4 MB por encuadre).

## 4. Revisar

Siempre antes de enseñar nada (y la QA de Blender, skill
`blender-asset-qa`, para mallas tocadas a mano).

| Qué mirar | Herramienta |
|---|---|
| Huesos y pesos | `--debug=<dir>`: `<n>_bones_front/side.png` (hombro bajo lo alto del hombro, codo, muñeca, la mano hasta la punta, cadera en la entrepierna) y `<n>_arm_front/back.png` (rojo brazo izquierdo, naranja derecho: el brazo pintado entero, nada de ropa) |
| Poses difíciles de cerca | `xvfb-run -a godot --path . -s tools/art/anim_sheet.gd -- --model=art/characters/out/<n>.glb --out=<dir> --frames=3 --dirs=S,E,N,W --zoom=6 --size=500x600 --focus=0.8 --anims=carry_loop,celebrate,melee` |
| Hojas para el dueño | `anim_sheet.gd` + `python3 -I tools/art/anim_sheet.py <dir> <out.png>` (páginas del tamaño de la pantalla, nunca una tira larga; también `.mp4`) |
| Cuatro vistas | `tools/art/four_views.sh art/characters/out/<n>.glb <out.png> <n> 400` |
| Un coach de cerca | `xvfb-run -a godot --path . --resolution 1600x720 -s test/coach_sheet.gd -- <out.png> [--male] [--hair=r,g,b] [--skin=N] [--k=5] [--y=…] [--dirs=2,1,0,6]`; la máscara sola: `python3 tools/art/coach_masks.py --sheet=<out.png> <coach>` |
| Pies planos | `blender -b -P tools/blender/characters/feet_check.py -- art/characters/out/<n>.glb [--json=…]`: por clip, la inclinación de los pies que pisan y los fotogramas en que flota; ≤ 3° salvo `walk` (el talón al pisar y la punta al despegar) |
| En combate | `test/fight_ui_preview.tscn` con `FIGHT_UI_FECA` / `FIGHT_UI_FOCUS` / `FIGHT_UI_SHOT` (ver S35b, paso 6) |

## 5. Fallos que ya conocemos

| Síntoma | Causa | Arreglo |
|---|---|---|
| astillas y pliegues en el sombreado toon (cintura, muslos, sobre los guantes) | el decimado de Blender deja 1 triángulo de cada 7 en astilla | `--reduce=clean` con `hd_src` (MeshLab): 0,5 % de astillas |
| trazos en el codo, el brazo se rasga al doblarlo | el corte del brazo se llevaba el borde del guante | `--arm_flap=0.03` |
| esquirlas naranjas en las costillas | sombras propias en el visor de la figura (está sola, la sombra solo caía sobre ella) | ya resuelto: las figuras no proyectan sombra (S53) |
| una franja o mancha que no es del modelo | Meshy la pintó en la textura | pintarla fuera antes del rehorneado (S53, el muslo de la mujer) |
| piel teñida entre los mechones, o pelo teñido como piel | la máscara toma por piel la piel rodeada de pelo en las puntas | ya resuelto en `coach_masks.py` (S53); revisar con `coach_masks.py --sheet=` |
| la costura del brazo se abre en pinchos oscuros | una normal y unos pesos por lado de la costura | `--weld_normals=1` |
| el coach anda con los brazos abiertos | original en pose A | `--lower_arms=10` |
| un pie se inclina dentro de la bota o gira en vez de apoyarse | el pie seguía a la espinilla; el ajuste de suelas solo bajaba la figura entera | ya resuelto: `rig_anims.plant()` planta cada pie que pisa en cada fotograma (S54); medirlo con `feet_check.py` |
| `can't find arm X apart from the body`, cadera en la rodilla, hombro en el bíceps, pulgares flotando, cola entre las piernas… | el ajuste de articulaciones con formas raras | la tabla completa, con el arreglo de cada clase, en [S35b](../sprints/S35b-pipeline-meshy.md#fallos-conocidos-y-qué-hacer) |
| figura sin forma humana (alas grandes, criatura) | el ajuste busca dos brazos y dos piernas | invocaciones: `meshy_summon.py --shape=creature`; luchadores: parar y preguntar al dueño |

Y en Blender 5, al automatizar: una acción asignada sin su *slot* no posa
nada (leer las curvas o asignar `action_slot`), y parchear
`bpy.ops.pose.<op>` no sirve (cada acceso a `bpy.ops.pose` es un objeto
nuevo): mejor un parámetro en la función (S54).

## 6. Meter una figura nueva, paso a paso

1. El dueño deja el GLB de Meshy en `PIPPOP_MESHY/<carpeta>/` (y el
   completo en `PIPPOP_MESHY_HD` si lo hay).
2. Una entrada en `figures.json` copiando la de una figura parecida;
   `tris=5000`, `tex=1024` para un luchador.
3. `python3 tools/art/build.py <nombre>` con `--debug` en las opciones la
   primera vez, y mirar huesos y pesos.
4. Si algo cae mal: `joints/<src>.json` o la opción de la tabla de fallos;
   repetir.
5. Las poses difíciles de cerca, las cuatro vistas y las hojas para el
   dueño.
6. Añadirla a `fighter3d.gd` (`MODELS` / `COACHES` / `SUMMONS`) y verla
   en combate.
7. `check.py` limpio, unitarias y smokes, la fila en la tabla de S35b y
   una nota en el sprint; commit y push.
