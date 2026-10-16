# S03 — Base en Linux headless

**Planificado:** 2026-10-16 · **Hito:** M1 — Jugable de punta a punta · **Tamaño:** S · **Estado:** 🟡 siguiente

## Objetivo

El desarrollo pasó de un Mac a una máquina Linux x86_64 **sin pantalla**. Este
sprint deja todo lo que daba por hecho el Mac funcionando aquí, para que los
sprints siguientes (empezando por S04, que necesita capturas) puedan trabajar y
verificar.

## Punto de partida (2026-10-16)

- No hay ningún binario de Godot instalado. Sí hay `xvfb-run` y Mesa 22.3
  (llvmpipe, render por software).
- `godot/run_tests.sh`: el binario por defecto es
  `/Applications/Godot.app/Contents/MacOS/Godot`, y el `pkill` de limpieza busca
  `Contents/MacOS/Godot`.
- `test/native_lobby.gd` y `test/native_panels.gd` escriben capturas en
  `/private/tmp/…`, una ruta que solo existe en macOS (`godot/DESIGN.md`).
- `godot/assets/` lleva **319.090 sidecars `.import`**, aunque esos assets se leen
  en bruto (`asset_paths.gd`). Aquí todavía no existe `.godot/`: al abrir el
  proyecto, Godot intentaría importar 312k PNG.
- `test/world_smoke.gd` usa `_main.world`, que ya no existe desde que se deprecó
  el hall: probablemente roto (sin correr).
- CI: `ci.yml` se dispara con los pushes a `main-covaga` según el fichero, pero
  en todo el repo solo hay **una** ejecución y fue manual (`BACKLOG.md` §8).

## Tareas

- [ ] **Godot 4.7.1 para Linux x86_64** en `~/.local` (la misma versión que fija
      la CI). Comprobar el hash de la descarga.
- [ ] **`.gdignore` en las carpetas de assets que se leen en bruto** (`anims/`,
      `gui/`, `mapgfx/`, `fx/`, `sounds/`, `gamedata/`; no en `ui/` ni `i18n/`, que
      sí se importan). Antes, comprobar con grep que nada de esas carpetas pasa por
      `load()`/`preload()`/`ResourceLoader`. Después, borrar los `.import` sobrantes.
- [ ] **Import y parse del proyecto** en limpio: `godot --headless --import`.
- [ ] **Render sin pantalla:** `xvfb-run` + renderer GL Compatibility sobre
      llvmpipe. Prueba: una escena que guarde un PNG no vacío.
- [ ] **`run_tests.sh` portable:** binario por `$GODOT` → `command -v godot` →
      ruta del Mac; `pkill` por un patrón que valga en ambos sistemas; el carril
      visual envuelto en `xvfb-run` cuando no hay `$DISPLAY`.
- [ ] Capturas a un directorio temporal portable en vez de `/private/tmp`.
- [ ] `./run_tests.sh` completo (headless + visual) en verde aquí.
- [ ] `world_smoke.gd`: arreglarlo o retirarlo, sabiendo qué cubría.
- [ ] **CI viva** (necesita al dueño: es configuración de GitHub). Habilitar
      Actions en el fork, hacer un push y confirmar por la API que corrió.
- [ ] Docs: el comando para lanzar el cliente en `BACKLOG.md`, la convención de
      limpieza (§7) y las rutas de `godot/DESIGN.md`.

## Fuera de alcance

- Arrancar el cliente **retail** en Linux (faltan `compiled/lib/` y el JRE).
  Se retoma si hace falta validar algo contra el retail.

## Criterio de cierre

- `./run_tests.sh` sale con código 0 en esta máquina, carril visual incluido.
- Una escena del cliente se renderiza a PNG bajo `xvfb-run`, y la captura va en
  el apartado *Resultado*.
- Hay al menos una ejecución de CI disparada por un push, enlazada aquí.
