# S04 — Mapas de pelea en 1 bit (dithering + capas de luz)

**Planificado:** 2026-10-16 · **Hito:** M2 — Identidad visual · **Estado:** ⏸ en pausa (2026-10-17) — se pasa a S17; lo que falta, al final · **Depende de:** S03 (render sin pantalla)

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
- [ ] Modo lote: los 114 mapas, con un índice de los que fallan y por qué.
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
- [ ] **Investigar `contents/maps/light/<id>.jar`**: el cliente retail trae datos
      de luz por mundo (114 jars; entradas `x_y` de 6 bytes, por trozo de mapa),
      sin decodificar todavía. Si es la iluminación del mapa, la capa LIGHTS sale
      de datos reales en vez de colocarse a mano. Si se decodifica, el formato
      se documenta en `client/analysis/`.
- [ ] Alternativa si lo anterior no da: luces colocadas por elemento de mapa
      (antorchas, farolas) o a mano por mapa.

### 4. Integración en el combate

- [~] Capa conmutable en `fight_view` (encendido/apagado en caliente), con la GUI
      y las ayudas tácticas por encima del filtro.
- [x] Ajuste en la configuración del cliente: `[arena] art_style` en
      `user://settings.cfg` (`ArtStyle`); se lee al entrar en el combate. Falta
      la casilla en el panel de opciones.
- [ ] `test/fight_ui_preview.tscn` también con el filtro encendido.

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

- Los 114 mapas de pelea se renderizan con el filtro sin errores (el modo lote
  sale con código 0).
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

- [ ] Casilla en el panel de Opciones para cambiar de estilo (hoy solo el
      fichero de ajustes o la variable de entorno).
- [ ] Modo lote del render (los 114 mapas con índice de fallos) — el
      criterio de cierre lo pide.
- [ ] `test/fight_ui_preview.tscn` también con el estilo 1 bit.
- [ ] Luces de ambiente: efectos puntuales (crítico, hechizo), antorchas;
      y decodificar `contents/maps/light/<id>.jar`.
- [ ] Repasar los colores de las ayudas tácticas (zonas de colocación,
      alcance, casillas especiales) para que casen con el 1 bit.
- [ ] Rendimiento: la conversión de actores a línea es GDScript por píxel al
      cargar cada acción (con caché). Medir en un combate largo; si da tirones,
      pasarla a un shader o a offline (la línea no usa tintes, se podría hornear).
- [ ] Visto bueno final del dueño en sus mapas de referencia.
