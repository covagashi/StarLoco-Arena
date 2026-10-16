# S04 — Mapas de pelea en 1 bit (dithering + capas de luz)

**Planificado:** 2026-10-16 · **Hito:** M2 — Identidad visual · **Estado:** 🟡 abierto (2026-10-16) · **Depende de:** S03 (render sin pantalla)

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
- [ ] Parámetros: tamaño de píxel (bajar resolución antes del umbral, porque el
      arte retail en color tiene demasiado detalle para el 1 bit a resolución
      nativa), contraste/gamma, sesgo del umbral, color de tinta y de papel.
- [ ] Que el patrón quede fijo a la pantalla o al mundo al mover la cámara:
      **decisión artística**. Fijo a pantalla "hierve" al hacer scroll.

### 3. Capas de luz

- [ ] Máscara de luces locales (degradado radial por fuente) compuesta antes del
      umbral.
- [ ] **Investigar `contents/maps/light/<id>.jar`**: el cliente retail trae datos
      de luz por mundo (114 jars; entradas `x_y` de 6 bytes, por trozo de mapa),
      sin decodificar todavía. Si es la iluminación del mapa, la capa LIGHTS sale
      de datos reales en vez de colocarse a mano. Si se decodifica, el formato
      se documenta en `client/analysis/`.
- [ ] Alternativa si lo anterior no da: luces colocadas por elemento de mapa
      (antorchas, farolas) o a mano por mapa.

### 4. Integración en el combate

- [ ] Capa conmutable en `fight_view` (encendido/apagado en caliente), con la GUI
      y las ayudas tácticas por encima del filtro.
- [ ] Ajuste en la configuración del cliente.
- [ ] `test/fight_ui_preview.tscn` también con el filtro encendido.

### 5. Pasadas artísticas

- [ ] Mapas de referencia elegidos por el dueño del proyecto.
- [ ] Registro de toques (abajo), una fila por petición.

## Registro de toques artísticos

Las capturas van al Samba: recurso `codigo` → `capturas/s04/` (en disco,
`/srv/codigo/capturas/s04/`, fuera del repo). Desde esta sesión no se pueden
adjuntar ficheros en la app.

| Fecha | Petición | Cambio (parámetro / código) | Captura |
|---|---|---|---|
| 2026-10-16 | "Primero haz la prueba de un mapa y vemos el arte" | Mapa 10. Cuatro variantes: original; día con celda de 1 px (`--pixel=1 --detail=3`); día con celda de 2 px (`--pixel=2 --detail=3 --black=0.05 --white=0.9`); noche (`--ambient=0.12 --falloff=1.0` + 4 luces) | `prueba1-mapa10.png` |

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
