# S04 — Mapas de pelea en 1 bit (dithering + capas de luz)

**Planificado:** 2026-10-16 · **Hito:** M2 — Identidad visual · **Estado:** ⚪ detallado (se abre al cerrar S03) · **Depende de:** S03 (render sin pantalla)

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

- [ ] `godot/tools/render_fightmap.gd`: carga el mapa de pelea `<id>`, lo pinta
      con `map_gfx.gd`, aplica el filtro y guarda un PNG. Los parámetros del
      shader van por línea de comandos, para iterar sin tocar código.
- [ ] Modo lote: los 114 mapas, con un índice de los que fallan y por qué.
- [ ] Hoja de contacto (varios mapas o variantes de parámetros en una imagen)
      para comparar de un vistazo.

Es la herramienta de trabajo del sprint: cada toque artístico se valida con una
captura de este script.

### 2. Shader 1 bit

- [ ] Luminancia → umbral Bayer 8×8.
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

| Fecha | Petición | Cambio (parámetro / código) | Captura |
|---|---|---|---|
| | | | |

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
