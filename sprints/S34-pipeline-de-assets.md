# S34 — Pipeline de assets nuevo

**Planificado:** 2026-10-25 · **Abierto y cerrado:** 2026-11-11 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🟢 cerrado

## Objetivo

Del archivo fuente al juego en un comando, con el arte propio **dentro del
repo o en un repo de arte**, no generado desde nada ajeno.

## Punto de partida (2026-11-11)

S35 y S36 se hicieron antes que este sprint, así que el pipeline ya existía
a trozos: loom, kiln, `build_models.py`, `bake_kits.py`, `meshy_fighter.py`,
`coach_masks.py` y `pack_arenas.gd`, cada uno con su comando escrito en
su sprint. Faltaba lo que pedía S34: un solo comando, comprobaciones,
procedencias y que un juego exportado lea el arte nuevo.

Lo que salió al reconstruir todo desde un checkout limpio (worktree en el
scratchpad, sin ninguna salida):
- **Las 10 arenas se reconstruyen byte a byte** (loom → kiln → Blender → AO),
  salvo lo de abajo. Solo faltaba un paso no escrito: `arena1/glyphs.py`
  antes de su loom.
- **Salidas obsoletas en el árbol de trabajo:** los looms b y c de
  `duckweed`, `mud`, `peat` y `peatSide` (arena 12) venían de un
  `kit.tx.js` anterior al guardado (14:32 frente a 14:42 del 29-10): en el
  árbol salían como celdas de voronoi, la fuente dice lenteja de agua y
  barro. 18 piezas de la arena 5 difieren en 4 bytes (kiln más viejo). La
  arena 12 no sale en el prototipo; la fuente manda. Es justo el caso que
  el comando único evita: cada paso se sella por **contenido**.
- **Un juego exportado no llevaba las figuras 3D:** `Fighter3D` las leía de
  `res://art/…`, que tiene `.gdignore` (no entra en el `.pck`), y
  `pack_arenas.gd` solo copiaba arenas. Exportado, todo volvía al retail.
- Las recetas de las 35 figuras solo estaban en la tabla de S35b, y los
  `joints.json` (correcciones de huesos revisadas) fuera del repo.

## Hecho

- **`godot/tools/art/build.py`**: un comando para todo (pasos, sellos y
  opciones en su cabecera y en AGENTS.md). `--dry-run`, `--force`, filtros
  por kit o figura, `--pack <dist>` y `--show ARENA[:CLASE]` (un combate
  real, `test/fight_ui_preview.tscn` bajo xvfb, a PNG).
- **`godot/art/characters/figures.json`**: la receta de cada figura
  (script, carpeta Meshy, opciones de la tabla de S35b) y
  **`characters/joints/`** con los 30 `joints.json`, ya versionados.
- **`godot/tools/art/check.py`** (+ `glb.py`, lector GLB sin dependencias):
  nombres, piezas en sus tres looms, bloque con su superficie dentro del
  modelo y centrado, presupuestos (pieza ≤ 25.000 triángulos, textura ≤
  1024, ≤ 4 MB; figura ≤ 5.000 triángulos, ≤ 20 huesos, ≤ 1024, ≤ 1,2 MB,
  1,45 de alto, pies en el suelo, las 10 animaciones), piezas de los
  layouts en su kit, receta para cada figura que dibuja `Fighter3D`,
  máscaras de los coaches, peso por arena del prototipo y créditos.
  `test_check.py` las prueba con GLB inventados (10 pruebas, en el carril
  `--headless` de `run_tests.sh`, o sea en CI); encontraron un fallo de
  borde en el lector JPEG.
- **`godot/art/CREDITS.md`**: procedencia de cada carpeta y fuente.
- **Cliente:** `Fighter3D` lee las figuras de `ArenaLayout.root()` (el
  `art/` junto al ejecutable en un juego exportado) y `pack_arenas.gd`
  copia también las 35 figuras y las máscaras (pack: 200 ficheros,
  111,8 MB). `--old-art` / `PIPPOP_OLD_ART=1` juega con los sprites retail
  mientras convivan (las arenas ya no tienen versión retail desde S43).
- AGENTS.md: sección "Art: from source to game".
- Elegir un kit arrastra los kits que leen sus texturas (la 7 lee las de
  la 5 y la 6), también en `--dry-run`. Blender corre con
  `--python-exit-code 1`: sin eso, un script que falla devuelve 0.

## Decisiones (sin el dueño, por heurística)

| Pregunta | Decisión | Por qué |
|---|---|---|
| ¿Git LFS o repo aparte? | Ninguno para lo que se construye: las salidas no se versionan, se regeneran. Los originales de Meshy (5–30 MB cada uno) se quedan en el repo de arte del homelab (`pippop-arena-assets`) con `PIPPOP_MESHY` | AGENTS.md prohíbe LFS; todo lo demás son fuentes de texto pequeñas que ya están en git |
| ¿Sello por fecha o por contenido? | Contenido (hash de la fuente, sus `include()`, las texturas loom que usa y los scripts de Blender) | Las fechas no sobreviven a un checkout, y el caso de la arena 12 fue justo un sello por fecha que mintió |
| Presupuestos | Los de lo ya aprobado, con margen: el máximo actual de pieza es 21.948 triángulos (árbol de otoño) y 3,6 MB | Que fallen las desviaciones, no lo aprobado |
| ¿`fighter1` (el piloto de S35)? | Fuera de `figures.json`: no sale en el juego | Construir solo lo que el juego usa |
| Carpetas de biomas sin revisar (`art/{lava,pradera,…}`) | Fuera del build (solo `arena<N>/` con `kit.json`) y sin tocar | S36 las dejó "sin subir y sin revisar" |

## Pendiente del dueño

- Confirmar que el plan de Meshy permite el uso comercial de las figuras
  (anotado en `CREDITS.md`; necesario antes de S16).

## Criterio de cierre

Un asset de prueba sale de su fuente, pasa las comprobaciones y se ve en el
juego con un solo comando; documentado en AGENTS.md.

**Cumplido (2026-11-11):** en un clon limpio, el césped de la arena 5
cambiado de tono (+120°, solo para la prueba, no se guardó):

```
python3 tools/art/build.py arena5 --show 5:1
```

reconstruyó la textura, la arena 5 y la 7 (lee sus texturas), pasó las
comprobaciones (0 fallos) y sacó un combate real con el césped azul y los
Feca en 3D. 37 s.

## Probado

- Construcción completa desde nada (clon limpio, sin ninguna salida):
  **337 s**, 0 fallos. Frente al árbol de trabajo: las 10 arenas iguales
  byte a byte salvo las obsoletas de arriba; de las 35 figuras, 33 iguales
  y las 2 máscaras. `yopuka_m` difiere en 8 valores de malla: se construyó
  el 10-11 a las 16:32, antes de un arreglo posterior de
  `meshy_fighter.py`. `summon_8010` sale distinto en cada ejecución del
  propio Blender (ruido del exportador, no hay azar en el script).
- El árbol de trabajo, reconstruido entero con el comando (288 s): ya
  coincide con sus fuentes; `--dry-run` no encuentra nada pendiente.
- `run_tests.sh --headless`: 10 pruebas del pipeline + 667 checks, 0
  fallos. Smokes `fight`, `summon`, `coach_turn` y `carry` contra el
  servidor local: los cuatro pasan.
- `pack_arenas.gd`: 200 ficheros, 111,8 MB, con las 35 figuras.
- Peso que lleva cada arena del prototipo: de 12,9 MB (4) a 31,3 MB (6);
  figuras, 26 MB en total.

## No verificado

- Un juego exportado de verdad leyendo las figuras del `art/` junto al
  ejecutable: probado con la prueba unitaria (`set_root`), no con una
  exportación.
- Que un original de Meshy cambiado se detecte: el sello usa su tamaño
  (los originales no se editan; leer 30 MB por figura en cada build no
  compensa).
