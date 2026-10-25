# S32 — Fuera la extracción del retail

**Planificado, abierto y cerrado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🟢 cerrado (paso 1 y docs; los pasos 2 y 3 viajan con S34–S39)

## Decisión del dueño (2026-10-25)

"A partir de ahora ya no miraremos nada del retail o del cliente oficial y
vamos a crear un nuevo pipeline para crear assets. Todo el código que usamos
para extraer se puede quitar." Los 435 MB sin usar ya están borrados (S31; la
copia aparte también, el mismo día).

## Qué se quita

- `tools/make_assets.sh` y `tools/asset-import/` entero (anm_*, gui_extract,
  map_gfx, xps_dump, musics, sounds, portraits.sh, card_names, spell_names,
  npc_dialogs, prune_unused y sus tests).
- Los `server/cmd/dump*` que solo sirven para exportar JSON al cliente
  (dumpcards, dumpeffects, dumpelements, dumpfightercards, dumpnpcdialogs,
  dumpspells, dumpspheres): revisar antes si algún test o el studio los usa.
- Lo que en el cliente solo existe para leer formatos retail cuando el arte
  nuevo lo sustituya: el motor XML (`src/gui/`), `xps_fx.gd`, los lectores
  `.anm`, `deprecated_hall/`, y las pruebas `gui_*`/`evo_smoke` de pantallas
  legacy.
- Documentación que explique la extracción (S15, README, AGENTS.md,
  QUICKSTART), y la parte de "genera tus assets desde tu cliente" del
  criterio 5 de la 1.0.

## Orden (para no dejar el juego sin arranque)

Los assets de hoy siguen en disco (git los ignora) y el juego los usa hasta
que llegue el arte nuevo. Por eso:
1. Ya: borrar las herramientas de extracción y los dump; el cliente sigue con
   el `godot/assets/` que hay.
2. Cada sprint de arte (S34–S39) retira el lector retail de lo que
   sustituye.
3. Al terminar M7, borrar `godot/assets/` retail entero.

## Por decidir (dueño)

- ~~¿Los datos del juego también se rehacen?~~ **Decidido (dueño,
  2026-10-25): primero el arte (M7), después las cartas (S40) y después los
  textos (S41).** Hasta entonces `server/data-dist/` (cartas, hechizos,
  efectos, topología de arenas) se queda como está, y los textos retail
  siguen saliendo de sus tablas.
- ~~¿Se borra `client/`?~~ **Hecho (dueño: "sí", 2026-10-25):** borrado del
  disco y del repo (5.101 ficheros con seguimiento y los 265 MB del retail
  compilado). Nada del código dependía de él para compilar ni para las
  pruebas; solo comentarios. Dejan de funcionar el visor de arte del studio
  (abría los `.jar` del retail) y `tools/proto-gen` (los opcodes que generó
  ya están en el repo). Sigue en el historial de git: reescribirlo es otra
  decisión. **Pendiente en este sprint:** reescribir README, AGENTS.md,
  CONTRIBUTING.md y DISCLAIMER.md, que lo describen (AGENTS.md lleva ya un
  aviso arriba).

## Criterio de cierre

Ningún script del repo lee el cliente retail; el juego arranca y juega con
los assets que hay; los docs no mandan a nadie a extraer nada.

## Hecho (2026-10-25)

- **Borrado `tools/` entero** salvo su README: `make_assets.sh`,
  `asset-import/` (21 scripts y sus tests), `cfr.jar` (el decompilador),
  `i18n-re/`, `sba-re/`, `zorder-re/` (fragmentos de ingeniería inversa) y
  `proto-gen/` (leía `client/`, ya borrado). Todos leían el cliente retail o
  sus formatos. El README de `tools/` era el documento de diseño del studio:
  pasa a `server/cmd/studio/README.md` con un aviso de qué parte murió.
- **Comentarios del código** que mandaban a `tools/asset-import` ahora dicen
  "el importador antiguo"; las cabeceras de `godot/src/net/generated/` dicen
  que se editan a mano; el aviso de `run_tests.sh` ya no manda a regenerar.
- **Docs reescritos:** README (qué es ahora, sin `client/`, cómo jugar con el
  cliente Godot, aviso de que un clon nuevo no trae arte hasta M7),
  AGENTS.md (mapa, restricciones 4 y 6, pruebas en vivo con los smoke de
  Godot), CONTRIBUTING.md, DISCLAIMER.md y NOTICE (lo que se quitó sigue en
  el historial de git y lo dicen; fuera la JRE de Oracle y CFR, que ya no
  están), `docs/QUICKSTART.md` (paso 4 con el cliente Godot),
  `godot/README.md` (sección Assets nueva). Avisos de "histórico" arriba de
  `server/docs/STATUS.md` y `CLIENT-TESTING.md`. BACKLOG: tres puntos
  obsoletos cerrados y el bloque "Regenerar assets" sustituido.
- **De paso:** dos líneas en blanco de más que `gofmt` marcaba en
  `internal/game` (el paso de formato del CI fallaba por ellas), en un
  commit aparte.

## Decisiones (heurística, dueño ausente)

- **Los `server/cmd/dump*` se quedan.** El esbozo los ponía en la lista de
  quitar "revisando antes"; revisados: no leen el cliente retail, solo
  `server/data-dist/`, que el dueño mantiene hasta S40. Son la única forma de
  regenerar `godot/assets/gamedata/` si cambia un dato del servidor antes de
  S40. Ojo: los nombres de `spells.json`, `cards.json` y `npcdialogs.json` los
  ponía el importador desde los textos retail; un dump nuevo de esos tres sale
  sin nombres, así que se conservan los ficheros actuales hasta S40/S41
  (escrito en `godot/README.md`). Se borran en S40/S41 si el formato nuevo no
  los necesita.
- **La restricción 6 de AGENTS.md** ("el protocolo es sagrado porque el
  cliente retail no se puede cambiar") pierde su motivo: el único cliente es
  el de Godot. Queda como "contrato": un mensaje solo cambia a la vez en
  servidor y cliente, con sus pruebas, en el mismo commit. No abre la puerta
  a cambiar el protocolo; solo deja de citar un cliente que no existe.
- ~~El cliente Godot como MIT~~ **Decidido (dueño, 2026-10-25): "el cliente
  mío sí que sea copyright".** `godot/LICENSE` nuevo: © 2026 Daviaan, todos
  los derechos reservados; el MIT de la raíz cubre solo el servidor y los
  docs. README, DISCLAIMER, NOTICE, CONTRIBUTING y AGENTS lo dicen. Los
  commits anteriores en el fork público no llevaban esta aclaración.
- **Mapas (dueño, 2026-10-25):** "si hace falta algo del cliente para ver los
  mapas, lo mantenemos hasta que tengamos todo nuestro". Comprobado: el juego
  dibuja los mapas con `godot/assets/mapgfx/` (en disco) y `map_gfx.gd`, y
  el studio lee las topologías de `server/data-dist/maps/tplg`; nada de eso
  se ha tocado. Se queda hasta que S36 (arenas) lo sustituya. Lo único que
  ya no va es el arte de mapa del studio, que leía los `.jar` de
  `client/compiled/` (borrado antes de S32).
- `.gitignore` conserva las entradas de `godot/assets/*` y del antiguo
  `.make_assets/`: los equipos que aún tienen la exportación no deben
  subirla por error.

## Queda fuera (otros sprints)

- Los lectores retail del cliente (`src/gui/`, `xps_fx.gd`, `.anm`,
  `deprecated_hall/`, pruebas `gui_*`/`evo_smoke`): paso 2, cada sprint de
  arte S34–S39 quita el suyo.
- `godot/tools/make_login_bg.py` usa las fuentes retail exportadas
  (`assets/gui/fonts/`): sale con las fuentes propias (S34).
- El visor de arte del studio (`server/cmd/studio/assets.go`, `app.go`)
  sigue con código que abría los `.jar` de `client/compiled/`; sin cliente no
  hace nada. Reescribirlo o borrarlo es decisión aparte (el dueño, arriba).
- S16 (en pausa) aún cita `make_assets.sh` en lo heredado de S15; no se toca
  hasta que el dueño la reabra.

## Pruebas

```
cd server && go build ./... && go test ./...      # todo ok
gofmt -l ./cmd ./internal ./test                  # vacío
godot/run_tests.sh --headless                     # rc=0: lint ok, 19 suites, 429 checks, 0 fallos
```

