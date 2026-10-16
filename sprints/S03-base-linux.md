# S03 — Base en Linux headless

**Planificado:** 2026-10-16 · **Hito:** M1 — Jugable de punta a punta · **Tamaño:** S · **Estado:** 🟡 a la espera del dueño — la CI no se dispara (ver el final)

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

- [x] **Godot 4.7.1 para Linux x86_64** en `~/.local/bin/godot` (la misma versión
      que fija la CI). SHA-512 comprobado contra `SHA512-SUMS.txt` de la release.
- [x] **`.gdignore` en las carpetas de assets que se leen en bruto** (`anims/`,
      `gui/`, `mapgfx/`, `fx/`, `sounds/`, `gamedata/`; no en `ui/` ni `i18n/`, que
      sí se importan). Antes, comprobar con grep que nada de esas carpetas pasa por
      `load()`/`preload()`/`ResourceLoader`. Después, borrar los `.import` sobrantes.
- [x] **Import y parse del proyecto** en limpio: `godot --headless --import`.
- [x] **Render sin pantalla:** `xvfb-run` + renderer GL Compatibility sobre
      llvmpipe. Prueba: una escena que guarde un PNG no vacío.
- [x] **`run_tests.sh` portable:** binario por `$GODOT` → `command -v godot` →
      ruta del Mac; `pkill` por un patrón que valga en ambos sistemas; el carril
      visual envuelto en `xvfb-run` cuando no hay `$DISPLAY`.
- [x] Capturas a un directorio temporal portable en vez de `/private/tmp`.
- [x] `./run_tests.sh` completo (headless + visual) en verde aquí.
- [x] `world_smoke.gd`: ni arreglado ni retirado, **movido a S05** (ver Resultado).
- [ ] **CI viva** (necesita al dueño: es configuración de GitHub). Habilitar
      Actions en el fork, hacer un push y confirmar por la API que corrió.
- [x] Docs: el comando para lanzar el cliente en `BACKLOG.md`, la convención de
      limpieza (§7) y las rutas de `godot/DESIGN.md`.

## Fuera de alcance

- Arrancar el cliente **retail** en Linux (faltan `compiled/lib/` y el JRE).
  Se retoma si hace falta validar algo contra el retail.

## Criterio de cierre

- `./run_tests.sh` sale con código 0 en esta máquina, carril visual incluido.
- Una escena del cliente se renderiza a PNG bajo `xvfb-run`, y la captura va en
  el apartado *Resultado*.
- Hay al menos una ejecución de CI disparada por un push, enlazada aquí.

## Resultado (2026-10-16)

Todo hecho salvo la CI, que necesita un push (abajo).

**Godot en Linux.** `godot --version` → `4.7.1.stable.official.a13da4feb`. El
SHA-512 del zip coincide con el de `SHA512-SUMS.txt`.

**`.gdignore`.** Ningún fichero de `src/`, `test/` ni `tools/` carga esas carpetas
con `load()`/`preload()`/`ResourceLoader`: todo pasa por `AssetPaths`, en bruto.
Los seis `.gdignore` **sí van en git**: `.gitignore` pasa de `/dir/` a
`/dir/*` + `!/dir/.gdignore`, porque git no puede re-incluir un fichero dentro
de un directorio excluido. Como `assets/anims/` existe ahora en cualquier
checkout, `run_tests.sh` decide si corre el carril visual mirando
`assets/anims/coach_7000`. Se borraron 319.086 sidecars `.import` sobrantes (se
quedan los 4 de `ui/`). Resultado: `godot --headless --path . --import` tarda
**20 s**, sale con 0 y 0 errores, y `.godot/` ocupa 880 KB.

**`run_tests.sh`.** El binario sale de `$GODOT` → `command -v godot` → la ruta
del Mac. Si no hay `$DISPLAY` (y no es macOS), el carril visual va envuelto en
`xvfb-run -a`. El `pkill` usa `[Gg]odot[^ /]* --path \.`, válido en los dos
sistemas. El array vacío se expande con `${a[@]+...}` porque el bash 3.2 de
macOS lo trata como no definido bajo `set -u`.

**Capturas.** `/private/tmp` → `/tmp` en los cuatro tests y en `DESIGN.md`. En
macOS `/tmp` enlaza a `/private/tmp`, así que allí no cambia nada.

**Evidencia:**

```
$ ./run_tests.sh                     # sin flag: los dos carriles
[unit] suites=5 checks=94 failures=0
--- test/ui_review_preview.tscn @ 1280x720 / 800x600 ---
--- test/fight_ui_preview.tscn @ 1280x720 / 800x600 ---
EXIT=0                               # ~50 s el carril visual, con llvmpipe
```

Las 20 capturas salen en `/tmp/ui-review-*.png` y `/tmp/fight-*.png`. La de
combate (`/tmp/fight-ui.png`, mapa 10 a 800×600) muestra el arte del mapa, el
HUD y las celdas de colocación: render real, no el renderer *dummy*.

**Smoke tests en vivo** contra un servidor local (`127.0.0.1:5555`, cuenta
`test` hecha admin con `seedaccount --admin`, como pide `world_smoke`):

| Test | Resultado |
|---|---|
| `login_smoke` | ✅ tras un arreglo: llamaba a `payload.remaining()`, pero la señal ya entrega un `PackedByteArray` → `payload.size()` |
| `fight_smoke`, `summon_smoke`, `displace_smoke`, `carry_smoke`, `map_smoke` | ✅ exit 0, sin errores de script |
| `native_lobby` (xvfb) | ✅ 26 PASS, 0 FAIL |
| `native_panels` (xvfb) | ✅ exit 0 |
| `world_smoke` | ❌ `Node not found: "World"`: depende del hall deprecado. Se cuelga hasta el timeout. **Pasa a S05**, porque cómo se arregle depende de la decisión de S05 (entradas en el lobby o revivir el hall). |
| `pvp_smoke` | ❌ timeout en el paso del intercambio: la lista de cartas intercambiables del coach `test` sale vacía, así que no pone nada, el bot no ve un 5110 y no da "ready". No se sabe si son los datos locales o una regresión. **Pasa a S08.** |

**Pendiente: CI.** Los workflows están activos (`gh api .../actions/permissions`
→ `enabled: true`), `ci.yml` escucha pushes a `main-covaga` y esa rama recibió
pushes hoy, pero la API sigue mostrando **una sola ejecución**: un
`workflow_dispatch` del 2026-10-13, que falló en `gofmt` (Linux). `gofmt -l`
está limpio ahora. Para cerrar el sprint falta hacer un push y ver si dispara.

**Push hecho (2026-10-16, `3f0fd24c`): la CI sigue sin dispararse.** Para ese
commit GitHub creó suites de otras apps (vercel, claude, cursor…), pero **ninguna
de GitHub Actions**: el evento push ni siquiera llega a Actions. En un fork, lo
típico es que falte el botón *"I understand my workflows, go ahead and enable
them"* de la pestaña Actions, que la API no muestra (`actions/permissions` dice
`enabled: true`). Lo tiene que pulsar el dueño; después, un push cualquiera
cierra el sprint.
