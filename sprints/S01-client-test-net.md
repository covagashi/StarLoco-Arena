# S01 — Red de pruebas del cliente + raíz de assets

**Abierto:** 2026-10-13 · **Rama:** `main-covaga` · **Estado:** 🟢 cerrado salvo la primera corrida real de CI

## Objetivo

Dejar el cliente Godot con pruebas que *alguien más que el autor* pueda correr,
y cerrar de paso la clase de bug que impide exportar un build.

## Punto de partida (auditado el 2026-10-13, no asumido)

Lo que **sí** funciona, reproducido con el motor en la mano (Godot 4.7.1):

| Prueba | 1280×720 | 800×600 |
|---|---|---|
| `test/ui_review_preview.tscn` | `EXIT=0`, 0 fallos | `EXIT=0`, 0 fallos |
| `test/fight_ui_preview.tscn` | `EXIT=0` | `EXIT=0` |

Parse headless del proyecto limpio, cero `ERROR` de script. Las afirmaciones
son reales (foco inicial, orden de tabulación, `FOCUS_NONE`, y el `frame` de las
veinte rutas de panel dentro del viewport) y salen con `quit(1)` al fallar.
El i18n tiene **718 claves exactas en es/en/fr**, cero faltantes ni sobrantes.

Lo que **no** existe:

1. **`godot/` no entra en CI.** `grep -i godot .github/workflows/` → sin
   resultados; `ci.yml` solo cubre `server/`.
2. **CI no corre en esta rama.** `on: push: branches: [v2.70]` — llevamos 130
   commits en `main-covaga` sin pasar por CI ni una vez.
3. **Las pruebas no corren sin ventana.** En `--headless` el proceso se cuelga
   (hay que matarlo, exit 144). Causa exacta: `_shot()` hace
   `await RenderingServer.frame_post_draw`, que sin renderer no dispara nunca.
   Las *afirmaciones* sí son headless-compatibles — pasa las dos de login antes
   de colgarse.
4. **Ningún runner.** 25 ficheros en `test/` (4.771 líneas) sin forma unificada
   de lanzarlos.

## La restricción que condiciona el diseño

`godot/assets/` está **gitignored a propósito** (restricción legal de
`AGENTS.md`); solo `assets/ui` y `assets/i18n` están versionados. Por tanto
`ui_review_preview` y `fight_ui_preview` **nunca podrán correr en CI**:
necesitan `coach_7000/` y los atlases de `appSkin`.

Las pruebas se parten en dos carriles, y conviene nombrarlo ahora en vez de
descubrirlo a medio camino:

- **Carril CI (sin assets)** — lógica pura: resolución de rutas, paridad de
  i18n, `direction8`, codec del protocolo con fixtures inline. Esto es lo que
  merece el nombre de *pruebas unitarias*.
- **Carril local (con assets)** — los previews visuales. Punto de entrada único
  y ritual documentado de "antes de push", porque automatizarlos es imposible.

## El bug: clase entera, no un descuido

`Image.load_from_file()` y `FileAccess` sobre rutas `res://` **no funcionan en un
build exportado** — los ficheros crudos no están dentro del `.pck`. El barrido
encontró que no es un caso aislado:

- **6** cargas de imagen (`load_from_file`) y **~35** accesos `FileAccess`
- **~50** rutas `res://assets/...` hardcodeadas en **20** ficheros
- **dos idiomas inconsistentes**: unos sitios usan `ProjectSettings.globalize_path()`
  (que también falla al exportar), otros la ruta `res://` cruda
- **`export_presets.cfg` no existe** — el proyecto nunca se ha exportado, así
  que el bug está **latente**: saltaría el día que se intente distribuir

Es consecuencia de una decisión correcta: los assets son artefactos generados
por `tools/asset-import`, no recursos importados por Godot (no hay `.import`).
El modelo bueno es el que ya usa el servidor con `data-dist/`: una carpeta junto
al ejecutable. Lo que falta es un **resolutor único** por el que pasen todas las
llamadas.

## Barrido de clases hermanas (2026-10-13)

Buscando el mismo patrón de "suposiciones sobre el entorno de ficheros":

**Limpio** — ninguna ruta POSIX absoluta hardcodeada en `src/` (`/tmp`, `/Users`,
`/Applications`: cero resultados), y los ajustes usan `user://` correctamente
(`gui_settings.cfg`, `settings.cfg`). Esa clase no existe aquí.

**B-174 — resultado de `JSON.parse_string` sin comprobar en 3 de 16 sitios.**
13 puntos de llamada se protegen (`if data == null` o `is Dictionary`); tres
asignan directamente a una variable **tipada**:

- `src/maps/map_gfx.gd:55` — `var meta: Dictionary = JSON.parse_string(...)`
- `src/anims/anm_sprite.gd:91` — ídem, el `meta.json` de cada acción
- `src/gamedata/kanodo.gd:27` — `spheres.json`

Semántica verificada empíricamente en un proyecto desechable con Godot 4.7.1,
no de memoria:

```
SCRIPT ERROR: Trying to assign value of type 'Nil' to a variable of type 'Dictionary'.
```

y **la función aborta en esa línea** (el `print` siguiente no se ejecuta). La
forma protegida degrada limpiamente.

Importa porque esos tres ficheros los **genera** `tools/asset-import`: una
corrida interrumpida deja un JSON truncado y entonces `load_action` aborta a
medias — sin frames, sin poblar la caché — y el síntoma es "las animaciones no
salen" con una sola línea en el log. Es el modo de fallo más caro de
diagnosticar meses después.

## Tareas

- [x] `src/util/asset_paths.gd` — resolutor de raíz de assets, con sondeo de
      raíces en orden y compatibilidad con las rutas `res://assets/...` actuales
      (migración mecánica y reversible).
- [x] Arnés de aserciones headless + `test/unit/` sin dependencia de assets.
- [x] Unitarias: `asset_paths` (sobre directorios temporales), paridad de las
      718 claves i18n, `direction8`.
- [x] `_shot()` no-op bajo el servidor de display headless → las afirmaciones
      de los previews corren sin ventana.
- [x] Migrar los ~50 puntos de llamada al resolutor.
- [x] `run_tests.sh` — punto de entrada único (carril headless + carril ventana).
- [x] `ci.yml`: añadir `main-covaga` a los triggers y una lane Godot que corra
      **solo** el carril sin assets.
- [x] Registrar la clase de bug en `BUGS.md` como `B-173`.
- [x] Lint anti-regresión de B-173 dentro de `run_tests.sh` (grep, sin Godot).
- [x] `B-174`: proteger los 3 `JSON.parse_string` tipados + unitaria que cubra
      la forma degradada (fixture de JSON truncado, sin assets).

## Criterio de cierre

1. `./run_tests.sh --headless` verde en una máquina **sin** `godot/assets/`.
2. Los cuatro previews siguen en `EXIT=0` tras la migración — misma tabla que
   arriba, reproducida al final del sprint. Es la prueba de no-regresión.
3. CI corre en `main-covaga` y falla si el carril headless falla.
4. `B-173` en `BUGS.md` con causa raíz y método de verificación.

## Resultado

### Evidencia

Todo medido por mí tras el trabajo de los agentes, no copiado de sus informes.

| Comprobación | Resultado |
|---|---|
| `run_tests.sh --headless` (carril CI) | `[unit] suites=4 checks=84 failures=0`, exit 0 |
| Los cuatro previews con ventana | exit 0, 0 aserciones fallidas, 0 script errors |
| Parse headless del proyecto | exit 0, 0 errores |
| Warnings `will not work on export` | 7 → **0** y 57 → **0** |
| Ensayo de CI en árbol sin assets | `--import` exit 0 → carril 84/0, exit 0 |
| El carril falla de verdad cuando debe | suite rota → `failures=1`, **exit 1** |
| La unitaria de B-174 caza el bug | fix revertido → `failures=2`; restaurado → 0 |
| El lint de B-173 caza una reintroducción | literal plantado → `exit 1` con fichero y línea |

El árbol del ensayo se construyó con `git ls-files -c -o --exclude-standard`,
así que `assets/` solo contenía `i18n` y `ui` — exactamente lo que ve un runner.

### Lo que salió del trabajo y no estaba previsto

- **B-175**, encontrado *por* el ensayo de CI y antes de que el workflow
  corriera nunca: `--quit` no escribe
  `.godot/global_script_class_cache.cfg`, así que en un checkout fresco ningún
  `class_name` resuelve; y el runner **se colgaba** en vez de reportarlo,
  porque llamaba a `.new()` sobre un script que no compiló y el abort ocurría
  antes del `quit()`. En un runner eso es un timeout de job, no una cruz roja.
- **El warning de export estaba mal interpretado por mí.** Salta por rutas
  `res://` que tienen `.import` hermano, y Godot auto-importa todo PNG bajo
  `res://`. Verificado en proyecto desechable: `res://`+`.import` → salta;
  misma ruta globalizada → no; `res://` sin `.import` → no. Es un marcador del
  síntoma, no el bug. `AssetPaths.load_image` lleva un desvío **con guarda de
  editor** por higiene del log.
- **El conteo exacto de claves i18n se relajó a suelo de cordura.** La paridad
  entre locales es invariante; el total absoluto no. Un test que falla con
  trabajo legítimo y cuyo arreglo es "edita el número" enseña a editar números
  sin leerlos.

### `*.uid` y `*.import`: resuelto por precedente

No hacía falta decidir nada nuevo. El repo ya versiona **60 ficheros `.uid`**, y
de los 5 `.import` sin seguimiento todos pertenecen a PNG versionados — con uno
de ellos (`assets/ui/login_bg.png.import`) ya commiteado. Así que entran todos:
es lo que el repo ya hacía, y además arregla esa inconsistencia. `.gitignore`
no se toca (`/godot/.godot/` ya cubre la caché de importación).

### Lo único sin verificar

La lane de CI no ha corrido en un runner real todavía. Los comandos están
probados en árbol sin assets y el YAML parsea, y el tag y el nombre del binario
se comprobaron contra la API de GitHub (`Godot_v4.7.1-stable_linux.x86_64.zip`),
pero el primer push es lo que lo confirma.
