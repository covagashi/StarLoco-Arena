# S32 — Fuera la extracción del retail

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ⚪ esbozo (el primero de M7)

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
- ¿Se borra `client/` (retail compilado y decompilado) del disco y del repo?

## Criterio de cierre

Ningún script del repo lee el cliente retail; el juego arranca y juega con
los assets que hay; los docs no mandan a nadie a extraer nada.
