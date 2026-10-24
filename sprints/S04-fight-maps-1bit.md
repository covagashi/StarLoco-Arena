# S04 — Mapas de pelea en 1 bit (dithering + capas de luz)

**Planificado:** 2026-10-16 · **Hito:** M2 — Identidad visual · **Estado:** 🟢 terminado (2026-10-24) — falta el visto bueno del dueño: mapas de referencia, color retail · **Depende de:** S03 (render sin pantalla)

## Objetivo

Pintar los mapas de pelea con un estilo **1 bit**: el arte retail convertido a
blanco y negro con dithering Bayer 8×8, y la oscuridad abierta por capas de luz.
La referencia es el reel de *Glagstone* ("a whole island after dark"), cuyas
capas son:

| Capa | Qué es aquí |
|---|---|
| **WORLD** | el mapa de pelea retail tal cual lo pinta hoy `map_gfx.gd` (`assets/mapgfx/`) |
| **DARKNESS** | el patrón Bayer 8×8: umbral por píxel según `(x % 8, y % 8)` |
| **LIGHTS** | máscaras de luz locales (degradado radial alrededor de cada fuente) |
| **BEAM** | máscaras con forma (conos, franjas) para acentos puntuales |

Composición: un píxel muestra el mundo si `luz > umbral_bayer(x, y)`; si no,
sale negro. Todo en un shader del cliente Godot.

**Reparto:** la dirección artística la lleva el dueño del proyecto; el agente
implementa, renderiza capturas y apunta cada toque en el registro de abajo.

## Decisiones ya tomadas (2026-10-16)

- **La fuente sigue siendo el arte retail.** Esto cambia cómo se pinta, no qué
  se pinta: los importadores y `godot/assets/` no se tocan.
- **Se queda Godot.** [ASCILINE](https://github.com/YusufB5/ASCILINE) se miró y
  se descartó: es un motor de *vídeo* a ASCII (Python/FastAPI, núcleo AGPL), sin
  bucle de juego, input ni escena.
- **ASCII/ANSI como estilo principal, descartado** por demasiado de nicho para un
  público que viene por nostalgia del arte original. Queda como idea en
  `BACKLOG.md` §9 (modo opcional y material para redes).
- **La GUI y las ayudas tácticas quedan fuera del filtro**: HUD, números, alcance
  de hechizos, zona de efecto, ruta de movimiento, celda bajo el cursor. En un
  táctico se tienen que leer siempre.

## Alcance

- Solo los **mapas de pelea**: 114 jars en `contents/maps/fight/` (y otros 114
  en `light/`, `tplg/`, `env/`…, uno por mundo).
- El lobby, la GUI y el mundo abierto quedan fuera de este sprint.
- **Abierto (decisión artística):** cómo se tratan los actores (luchadores e
  invocaciones): dentro del filtro, fuera, o con tratamiento propio (más brillo,
  contorno, luz propia).

## Tareas

### 0. Entorno

Lo que necesita este sprint para trabajar en Linux sin pantalla (Godot instalado,
render bajo `xvfb-run`, `run_tests.sh` portable) se hace antes, en
[`S03`](./S03-base-linux.md).

### 1. Bucle de iteración: render de un mapa de pelea a PNG

- [x] `godot/tools/render_fightmap.gd`: carga el mapa de pelea `<id>`, lo pinta
      con `map_gfx.gd`, aplica el filtro y guarda un PNG. Los parámetros del
      shader van por línea de comandos, para iterar sin tocar código.
- [x] Modo lote (2026-10-17): `render_fightmap.gd --batch=DIR [--maps=…]`
      pinta cada mapa en una `fight_view` nueva y escribe `DIR/index.txt`
      (ok / skip / el motivo del fallo: sin arte, sin celdas, texturas que
      faltan, caída al arte retail, fotograma en negro). Ver "Lote" abajo.
- [x] Hoja de contacto (varios mapas o variantes de parámetros en una imagen)
      para comparar de un vistazo.

Es la herramienta de trabajo del sprint: cada toque artístico se valida con una
captura de este script.

### 2. Shader 1 bit

`godot/src/fight/onebit.gdshader`. Parámetros (todos también en la
herramienta): `pixel_size`, `black_point`/`white_point`, `gamma`, `detail` y
`detail_radius` (contraste local), `levels` (posterizado), `edge_strength`/
`edge_threshold` (contornos), `ambient`, `lights[16]`, `light_falloff`, `ink`/
`paper`, y `debug_view` (1 = arte muestreado, 2 = tono antes del dithering).

- [x] Luminancia → umbral Bayer 8×8.
- [x] Parámetros: tamaño de píxel (bajar resolución antes del umbral, porque el
      arte retail en color tiene demasiado detalle para el 1 bit a resolución
      nativa), contraste/gamma, sesgo del umbral, color de tinta y de papel.
- [x] Que el patrón quede fijo a la pantalla o al mundo al mover la cámara:
      **decisión artística**. Fijo a pantalla "hierve" al hacer scroll.

### 3. Capas de luz

- [x] Máscara de luces locales (degradado radial por fuente) compuesta antes del
      umbral.
- [x] **Investigar `contents/maps/light/<id>.jar`**: el cliente retail trae datos
      de luz por mundo (114 jars; entradas `x_y` de 6 bytes, por trozo de mapa),
      sin decodificar todavía. Si es la iluminación del mapa, la capa LIGHTS sale
      de datos reales en vez de colocarse a mano. Si se decodifica, el formato
      se documenta en `client/analysis/`.
- [x] ~~Alternativa si lo anterior no da: luces colocadas por elemento de mapa
      (antorchas, farolas) o a mano por mapa.

### 4. Integración en el combate

- [x] ~~Capa conmutable en `fight_view` (encendido/apagado en caliente), con la GUI
      y las ayudas tácticas por encima del filtro.
- [x] Ajuste en la configuración del cliente: `[arena] art_style` en
      `user://settings.cfg` (`ArtStyle`); se lee al entrar en el combate. Se
      cambia en Opciones → Combate.
- [x] `test/fight_ui_preview.tscn` también con el filtro encendido (ver
      "Estado al pausar").

### 4b. Color de los mapas en el estilo original (de S07, 2026-10-21)

- [x] El retail tiñe cada elemento del mapa (tinte por elemento en `gfx/*.jar`,
      70 % de los elementos de arena) y le suma luz horneada (`light/*.jar`);
      `map_gfx` lo ignora y las arenas salen más planas y claras. Falta
      confirmar la mezcla (¿texel × 2·tinte × luz?) contra una captura del
      retail y exportar el color por sprite. Formato en
      [`client/analysis/MAP-LIGHT.md`](../client/analysis/MAP-LIGHT.md).

### 5. Pasadas artísticas

- [ ] Mapas de referencia elegidos por el dueño del proyecto.
- [x] Registro de toques (abajo), una fila por petición.

## Registro de toques artísticos

Las capturas van al Samba: recurso `codigo` → `capturas/s04/` (en disco,
`/srv/codigo/capturas/s04/`, fuera del repo). Desde esta sesión no se pueden
adjuntar ficheros en la app.

| Fecha | Petición | Cambio (parámetro / código) | Captura |
|---|---|---|---|
| 2026-10-16 | "Primero haz la prueba de un mapa y vemos el arte" | Mapa 10. Cuatro variantes: original; día con celda de 1 px (`--pixel=1 --detail=3`); día con celda de 2 px (`--pixel=2 --detail=3 --black=0.05 --white=0.9`); noche (`--ambient=0.12 --falloff=1.0` + 4 luces) | `prueba1-mapa10.png` |
| 2026-10-16 | "La de Instagram separa los efectos y consigue un resultado más fino; tú no haces el 1 bit por tile, sino por imagen, ¿verdad?" → "hazlo" | **Cambio de enfoque: 1 bit por textura.** `tools/asset-import/onebit.py` convierte cada textura de `mapgfx` (contraste local `--detail=4 --radius=2`, `--white=0.75 --gamma=0.75`, Atkinson, alfa binario) a `assets/mapgfx_1bit/`. `map_gfx.use_onebit()` la carga con filtro nearest y posiciones enteras. El shader (`world_onebit`) ya solo pone la oscuridad: el píxel del mundo sobrevive donde `luz > Bayer`. Render con `--world=1bit --pixel=1`, 5 luces en las losas brillantes y las salidas, `--ambient=0.12 --falloff=1.0` | `prueba2-capas.png` (WORLD / DARKNESS / LIGHTS / FINAL, recorte 1:1), `prueba2-antes-despues.png` |
| 2026-10-16 | "El world de día me parece bien; los otros efectos solo para la animación ambiental; de noche es muy oscuro para una pelea; ¿los muñecos podrían ser 1 bit + color?" → "haz pruebas" | **Decidido:** el WORLD de día es el estilo base de los mapas de pelea; luz y oscuridad, solo para ambiente (efectos puntuales, ambiente suave, eventos), nunca una pelea a oscuras. **Personajes:** `AnmSprite.onebit_style` 1 = cuerpo en 1 bit (Bayer, estable entre frames) + piel/pelo/ojos con su tinte en dos tonos planos + contorno negro; 2 = lo mismo con contorno del color del equipo. El shader deja pasar los píxeles con color. Tres luchadores demo por equipo (`--fighters`) | `prueba3-personajes-zoom.png` (A color / B / B+C, ×3), `prueba3-mapa-equipos.png` (tamaño real) |
| 2026-10-16 | "No me gusta ninguno… ¿qué otra técnica recomiendas?" → "dame pruebas" | Diagnóstico: los sprites retail (~36×87 px, muy pintados) no aguantan trama, y el suelo con puntos por todas partes compite con ellos. Tres cambios: **suelo calmado** (`onebit.py --white=0.55 --gamma=0.5 --detail=3 --radius=2`, casi blanco con las grietas dibujadas); `onebit_style` 3 = **línea + relleno** (líneas donde cambia el color y alrededor de la silueta, relleno blanco, damero/negro solo en lo más oscuro, contorno negro exterior); `onebit_style` 4 = **duotono por equipo** (negro → color del equipo → blanco, sin trama) | `prueba4-personajes-zoom.png` (×3), `prueba4-mapa.png` (tamaño real), `prueba4-suelo.png` (suelo antes/después) |
| 2026-10-16 | "Me gusta el 1, y para distinguir el jugador poner una pequeña aura o lo que sea en el suelo o celda con el color" | **Decidido: personajes en línea + relleno (`onebit_style` 3).** Tres diseños de marca de equipo en `render_fightmap --marks`: `cell` (rombo de la casilla con damero del color y borde sólido), `aura` (halo redondo de puntos Bayer del color que se desvanece), `ring` (elipse gruesa, el anillo actual reforzado). El luchador activo lleva la marca más grande/densa. Se dibujan en el lienzo de `fight_view`, como sus anillos actuales (encima del mapa, debajo de los actores) | `prueba5-marcas-zoom.png` (×3), `prueba5-marcas-mapa.png` (tamaño real) |
| 2026-10-17 | "aura :)" | **Decidido: aura.** `src/fight/team_aura.gd` (tamaño 1,15 casillas; 1,45 la del luchador activo; en la prueba 1,5 se pisaban). **Integrado en el juego**: `src/util/art_style.gd` (`user://settings.cfg` `[arena] art_style = retail\|onebit`, o `ARENA_ART_STYLE`); con `onebit`, `fight_view` carga `mapgfx_1bit` (y cae al arte retail si un mapa no está convertido), pone los actores en línea + relleno, cambia los anillos de equipo por auras (sin aura para los muertos) y el fondo a negro. **Exposición adaptativa** en `onebit.py` (`--auto=0.85 --target=0.72`): el ajuste fijo del mapa 10 quemaba los mapas claros (2, 59). Los 114 mapas convertidos (2.907 texturas, 2 min 46 s). Combate real verificado (`fight_smoke` con `ARENA_ART_STYLE=onebit`, exit 0, sin errores de script) | `prueba6-galeria-mapas.png` (6 mapas), `12-combate-real.png` |
| 2026-10-17 | "¿Por qué se ven los cuadrados verdes?" → la info, en la carta del personaje (Krosmaster): otro sprint | Eran las **barras de vida**: 56×27 px en vez de 56×5, porque `fight_view` fijaba `size` antes de `show_percentage = false`, con la altura mínima del texto aún reservada (medido: 56×27; con el orden cambiado, 56×5). Arreglado en los dos estilos; en 1 bit el fondo es negro y el relleno sigue verde→rojo según la vida. El rediseño del HUD va en [`S17`](./S17-fight-hud.md) | `14-barras-vida-finas.png` |

## Notas de la primera prueba (2026-10-16)

- **El umbral directo no sirve con el arte retail.** Verdes y marrones caen en la
  misma franja de gris medio, y el dithering lo funde en una trama uniforme. Lo
  que lo arregla es el **realce de contraste local** (`detail`): tono = media
  local + (tono − media local) × `detail`, con la media sacada de un mip de la
  pantalla. Con `detail=3` salen las grietas, las losas y los símbolos de las
  casillas especiales.
- **Contornos por color (`edge`)**: oscurecen demasiado, porque el arte tiene
  textura en todas partes. Siguen como parámetro, apagados por defecto.
- **Celda de 1 px** se lee mejor que la de 2 px a 1280×720.
- **Fondo**: el gris por defecto de Godot se convertía en ruido; la herramienta
  pone el fondo en negro. En la integración (tarea 4) hará falta lo mismo.
- **Se comprobó que el shader lee la pantalla bien**: `--debug=1` (el arte tal
  como lo muestrea) frente a la captura sin filtro da una diferencia media de
  2,8/255, sin desplazamiento ni volteo.
- **Prueba 2 — por qué el 1 bit por textura es más fino:** cada tile se
  convierte a su propia rejilla de píxeles, así que el dibujo llega nítido y el
  dithering del shader solo afecta a la luz. Además, la trama viaja con el
  sprite al mover la cámara en vez de "nadar" bajo ella. Atkinson en vez de
  Bayer para el mundo: no repite un patrón, así que no se ven costuras entre
  tiles vecinos. El mapa 10 (57 texturas) se convierte en 2,5 s.
- **Ojo al revisar capturas:** reducir una imagen 1 bit a la mitad borra filas
  enteras de puntos (la oscuridad parece negro puro). `contact_sheet.py --crop`
  recorta a 1:1.
- **Personajes (prueba 3):** la conversión va en `AnmSprite`, al cargar cada
  acción, porque los tintes son por personaje (los colores que elige el
  jugador) y no se pueden hornear offline. Bayer y no Atkinson: la difusión de
  error cambia de frame a frame y la animación parpadearía. El color tramado se
  veía ruidoso; en dos tonos planos, no. El contorno negro se pierde sobre el
  suelo tramado; el de equipo se lee siempre.
- **Para la integración**: hoy las ayudas tácticas (zonas de salida, anillos) se
  dibujan en el mismo canvas que el mapa, así que el filtro se las comería.
  Habrá que moverlas a una capa por encima del filtro.

## Riesgos

- **El arte retail es muy colorido y detallado.** Pasado a 1 bit puede quedar
  ruidoso o plano; por eso el tamaño de píxel y el contraste son parámetros y no
  constantes. No se sabe cómo queda hasta la primera captura.
- **Legibilidad de los luchadores** sobre un suelo con dithering.
- **Rendimiento:** llvmpipe (software) no sirve para medir FPS. La medida de
  rendimiento tiene que hacerse en una máquina con GPU real.

## Criterio de cierre

- Las **47 arenas** se renderizan con el filtro sin errores (el modo lote
  sale con código 0). Eran "114 mapas" al planificar, pero solo 47 de los 114
  `fight/*.jar` traen `.fmd` (en `data-dist` y en el cliente retail); los
  otros 67 son mapas del mundo abierto con el mismo número, y el servidor
  tampoco los carga como arena (`gamedata.LoadFightMaps`).
- El filtro se puede activar y desactivar en el combate, con la GUI y las ayudas
  tácticas legibles.
- `./run_tests.sh --headless` en verde en Linux.
- El dueño del proyecto da el visto bueno al aspecto en los mapas de referencia.

## Estado al pausar (2026-10-17)

**Decidido por el dueño:** el WORLD de día (1 bit por textura, suelo calmado y
exposición adaptativa) es el estilo de los mapas de pelea; los personajes van
en **línea + relleno** (`onebit_style` 3); los equipos se distinguen por un
**aura** de puntos del color del equipo (`team_aura.gd`); la luz y la
oscuridad, solo para ambiente, nunca una pelea a oscuras.

**Ya está en el juego**, detrás de `[arena] art_style = onebit` (o
`ARENA_ART_STYLE=onebit`); por defecto sigue `retail`. Los 114 mapas
convertidos en `godot/assets/mapgfx_1bit/` (generado, fuera de git; se rehace
con `python3 tools/asset-import/onebit.py godot/assets/mapgfx
godot/assets/mapgfx_1bit`, unos 3 min). Verificado con `fight_smoke` en los dos
estilos y con `./run_tests.sh` completo.

**Falta para cerrar:**

- [x] Casilla en el panel de Opciones para cambiar de estilo: sección
      **Combate** (estilo original / 1 bit, y la vida de las cartas de S17),
      2026-10-17. Captura: `ui_review_preview` → `/tmp/ui-review-optionsDialog-end-*.png`.
- [x] Modo lote del render — hecho el 2026-10-17 (ver "Lote" abajo).
- [x] `test/fight_ui_preview.tscn` también con el estilo 1 bit: el carril
      visual de `run_tests.sh` lo pasa en las dos resoluciones si el mapa 10
      está convertido (2026-10-17).
- [x] ~~Luces de ambiente: efectos puntuales (crítico, hechizo), antorchas.~~ (ver 2026-10-24)
- [x] Decodificar `contents/maps/light/<id>.jar` (2026-10-17):
      [`client/analysis/MAP-LIGHT.md`](../client/analysis/MAP-LIGHT.md). No
      son fuentes de luz sino **sombreado horneado por elemento** (clave
      x, y, layer; multiplicador mediano 0,86 en las arenas, 5 % por debajo
      de 0,38). Sirve de máscara de sombra para el ambiente suave; las luces
      tipo antorcha serían el campo dinámico de scripts, sin localizar.
- [x] Repasar los colores de las ayudas tácticas (zonas de colocación,
      alcance, casillas especiales) para que casen con el 1 bit.
- [x] Rendimiento: la conversión de actores a línea es GDScript por píxel al
      cargar cada acción (con caché). Medir en un combate largo; si da tirones,
      pasarla a un shader o a offline (la línea no usa tintes, se podría hornear).
- [ ] Visto bueno final del dueño en sus mapas de referencia.

## Lote (2026-10-17)

```
xvfb-run -a godot --path godot --resolution 1280x720 -s tools/render_fightmap.gd -- \
    --world=1bit --pixel=1 --batch=/tmp/s17/batch
# [render] batch: 114 maps, 67 not arenas, 0 failed   (exit 0, 323 s)
```

- 47 arenas renderizadas, 0 fallos; 67 "skip" (sin `.fmd`). Lo mismo con
  `--world=color` (exit 0, 258 s). Índice y galería
  (reducida, así que la trama no se ve fina) en el Samba:
  `capturas/s04/15-lote-index.txt`, `15-lote-47-arenas-reducido.png`.
- **Cuidado al reutilizar la escena:** la primera versión recargaba la misma
  `fight_view` y, tras el mapa 0 (el mundo grande, 327.000 sprites), todos los
  siguientes salían negros; además la cámara con suavizado aún no había
  llegado al mapa nuevo. Por eso el lote crea una escena por mapa y salta la
  cámara (`reset_smoothing`). El control de "fotograma en negro" (< 2 % de
  píxeles con luz) lo detectó; antes, el índice decía "ok" de mapas negros.
- **Mapas 38 y 42 salían descentrados**: la cámara centraba el rectángulo
  de la topología, que cuenta los trozos vacíos alrededor. Ahora
  `fight_view._load()` encuadra las celdas de suelo (también en el juego);
  lote repetido: 47 arenas, 0 fallos.
- El mapa 2 de la galería de la prueba 6 no es una arena (no tiene `.fmd`):
  vale como prueba de color, no como mapa de referencia.

## Retomado y terminado (2026-10-24)

El dueño: "hay que terminar al 100 % los sprints".

- **Ayudas tácticas en 1 bit.**
  - **Qué fallaba.** El alcance, la zona de efecto, la casilla del puntero,
    los pasos del camino, el coste en PM, las trampas y las casillas
    especiales usaban el translúcido del retail. Sobre la trama blanca se
    quedaba en un pastel casi invisible.
  - **Ahora.** Rellenos de puntos Bayer saturados (`onebit_marks.gd`; la
    densidad marca la fuerza, como en las auras) y un borde negro bajo cada
    línea.
  - **Capturas** en `~/codigo/capturas/s04/`: `ayudas-*`.
  - `fight_ui_preview` gana `FIGHT_UI_TACTICS=spell|move`.
- **Rendimiento.**
  - **Medido.** Cargar una acción en 1 bit tardaba 54 ms de mediana
    (máximo 182) frente a 9 en retail: un tirón cada vez que un luchador
    hacía algo nuevo.
  - **Probado y descartado.** Reescribir la conversión sobre bytes salía
    igual de lento.
  - **Ahora.** Cada fotograma se convierte la primera vez que se dibuja: la
    carga baja a 3,7 ms y cada fotograma, como mucho, a 6,2 ms. La imagen no
    cambia (la diferencia queda dentro del ruido entre pasadas).
- **Luces de ambiente.** Probé un oscurecimiento breve con luz en el impacto
  en críticos y muertes. **El dueño lo vio feo** ("muy oscuro y feo") y **se
  quitó** (revert; está en `361e2198` por si alguna vez se quiere algo mucho
  más suave). **Antorchas: descartadas.** Las luces dinámicas del retail
  solo las crean efectos y scripts Lua (`addGlobalLight`, `addPointLight`),
  y ninguno de los 675 Lua del cliente las usa. Además, en un mundo siempre
  de día no se verían.
- **Capa conmutable en caliente: descartada.** Venía de cuando el 1 bit era
  un filtro de pantalla. Con el 1 bit por textura que eligió el dueño, el
  estilo toca 38 sitios de `fight_view`, además del HUD y los muñecos. Se
  cambia en Opciones → Combate y vale para el combate siguiente.
- **Color retail por elemento (4b).**
  - **La mezcla, confirmada en el código.** `bu_0` deja el combinador de GL
    en `GL_MODULATE` con `GL_RGB_SCALE = 2`. `GeometryMesh.a` multiplica el
    color del vértice por el del material. El vértice es el color de la capa
    (1) × el tinte 0x02 del elemento (limitado a 0..1). El material es el
    registro de `light/*.jar` × el campo dinámico (neutro sin luces). En
    pantalla: **texel × 2·tinte × luz**.
  - **Sin captura del retail.** El cliente solo trae natives de Windows.
  - **Ahora.** `map_gfx.py` exporta `"c"` por sprite (624 181 de 975 501
    sprites en los 114 mapas) y `map_gfx.gd` lo aplica en el estilo retail;
    el 1 bit no lo usa.
  - **Para el dueño.** Algunas arenas cambian mucho: la 10 se vuelve rojiza
    (lava y árboles secos), la 77 oscura, la 52 azul. Tiene pinta de
    ambientes hechos a propósito con los mismos decorados. Capturas
    `color-retail-*` en `~/codigo/capturas/s04/`. **Falta que el dueño
    confirme** que así se veían en el retail. Si no, se quita con una línea
    (`retail_colour`).
- **Siguen siendo del dueño:** los mapas de referencia y el visto bueno final.
