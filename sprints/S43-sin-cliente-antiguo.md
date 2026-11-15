# S43 — Sin el cliente antiguo

**Planificado:** 2026-10-28 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🔵 en curso (pasos 1 y 2 hechos el 2026-11-04, paso 3 el 2026-11-15; el 4, borrar, espera el ok del dueño)

## Decisión del dueño (2026-10-28)

> "Ya después de terminar los 12 mapas, estaría bien dejar de depender
> totalmente del cliente antiguo."

S32 quitó las herramientas de extracción. Pero el juego sigue **leyendo** lo
que se extrajo del retail. Este sprint corta lo último y comprueba que no
queda nada: el juego arranca y se juega desde un checkout limpio, con solo
nuestros assets y nuestros datos.

## Lo que aún viene del cliente antiguo (2026-10-28)

| Qué | Dónde | Tamaño | Lo sustituye |
|---|---|---|---|
| Decoración de las arenas | `godot/assets/mapgfx/`, `src/maps/map_gfx.gd` | 16 MB | S36, fase D: `fight_view` dibuja los `layout` del dueño |
| Forma de las arenas | `server/data-dist/maps/{fight,tplg,env}/*.jar`, `gamedata/fightmaps.go` | 2,7 MB | **este sprint**, paso 1 |
| Luchadores, invocaciones, coaches | `godot/assets/anims/`, `src/anims/anm_sprite.gd` | 239 MB | S35 |
| Efectos de hechizo | `godot/assets/fx/`, `src/anims/xps_fx.gd` | 3,7 MB | S37 |
| Interfaz retail | `godot/assets/gui/`, el motor XML de `src/gui/` | 83 MB | S38 y los paneles nativos |
| Sonido y música | `godot/assets/{sounds,musics}/` | 9,5 MB | S39 |
| Cartas, hechizos, efectos, elementos | `server/data-dist/{data,indexes}.bdat`, `godot/assets/gamedata/` | 3,2 MB | S40 |
| Textos (nombres, diálogos de NPC) | las mismas tablas | — | S41 |

Hay que revisar `godot/assets/i18n/` (las cadenas de la interfaz) y
`godot/assets/ui/` (dos fondos): seguramente son nuestros, pero viven junto
al retail.

## Qué se hace aquí

### 1. Formato propio para la forma de las arenas

> **Hecho en parte en S36 (2026-11-03):** las 6 arenas del prototipo ya
> tienen su JSON (`server/internal/gamedata/arenas/<mundo>.json`, sacado
> del `layout`, embebido en el servidor) y la rotación es solo de esas 6
> (paso 2).
>
> **Hecho (2026-11-04):**
> - Servidor: `gamedata.LoadFightMaps()` ya no recibe carpeta ni lee
>   `.jar`. Las arenas son las 6 embebidas y nada más; el servidor arranca
>   con "6 arenas". Fuera el decodificador `.fmd`/topología de las arenas y
>   `cmd/dumparenas` (su trabajo, el archivo de S42, ya está hecho). Un id
>   de arena desconocido (el de un fantasma viejo) juega en la arena 1.
>   El lector de topología sigue solo para el `/TP` de GM, que es del mundo
>   abierto, no de las arenas.
> - Cliente: la forma base de las 12 arenas (las casillas y alturas
>   retail y las salidas del `.fmd`) se congeló una vez en
>   `godot/art/shapes/arena-NN.json`, con el mismo formato que la forma de
>   combate. `arena_layout.gd` `shape()` y `fight_shape()` la leen de ahí;
>   `fight_view` lee solo la forma de combate propia. `pack_arenas.gd`
>   también copia `shapes/`.
> - Comprobado: `shape()` da lo mismo que antes en las 12 arenas (huella
>   md5 de cada una, antes y después), y al volver a exportar las formas de
>   combate no cambia ningún archivo. Go: gamedata, game y e2e pasan.
>   Godot: 552 comprobaciones. `fight_smoke` contra el servidor juega un
>   combate entero en la arena 2 (rc 0), y la captura de la arena 5 sale
>   con 8 contra 8 y 6 pedestales.
> - De paso: `unit_runner.gd` da fallo si una suite no hace ninguna
>   comprobación. Un error de script en `fight_view.gd` había dejado
>   `direction8` en 0 comprobaciones sin ponerse en rojo.
> - `fight_smoke` con una base de datos vacía no puede crear el coach (el
>   mensaje de crear coach cambió y el smoke no). Se probó con una copia de
>   la base local. Pendiente de arreglar en el smoke.
> - Aún leen `.jar`: el minimapa del mundo abierto (`main.gd`),
>   `deprecated_hall/`, `tools/export_islands.gd`, `tools/art/build_map.gd`,
>   `test/map_smoke.gd`, el `/TP` de GM y `envmaps.go` (elementos del
>   mundo). Es todo del mundo abierto o herramientas viejas, y se borra en
>   el paso 4.

- Un JSON legible por arena, con seguimiento en git, por ejemplo
  `server/arenas/<id>.json`. No va en `server/data/`, que es la copia local
  ignorada (AGENTS.md). Lleva casillas con altura y suelo, salidas por
  equipo, pedestales y casillas especiales. Es el mismo contenido que el
  `forma.json` de S42.
- Solo las **6 arenas** del prototipo (1–6; dueño, 2026-11-03). Las 7–12
  se convierten cuando el dueño las monte. **La forma no se toca** (S36): se
  convierte, no se rediseña.
- El servidor carga ese JSON. El lector de `.jar` (`fightmaps.go`, la parte
  de `archive/zip`) y `server/cmd/dumparenas` se borran.
- Las pruebas del servidor y las e2e pasan con el formato nuevo. Una prueba
  compara, por última vez, la forma JSON con la de los `.jar` antes de
  borrarlos.

### 2. La rotación, solo con las 6

- ~~`arena_registry.go` sortea entre las 6 arenas del prototipo~~ hecho
  en S36 (2026-11-03).
- ~~Pedestales por lado para el 2v2~~: no aplica, el 2vs2 está escondido
  desde S20 (dueño). Si vuelve, solo la 3, la 4 y la 5 sientan dos por lado.
- Las 7–12 entran cuando tengan `layout`. Las otras 35 siguen en el archivo de S42, listas para añadirlas una a una
  cuando tengan arte y `layout`.

### 3. Una prueba "sin retail"

- Un smoke test arranca servidor y cliente (Godot headless, bajo xvfb) con
  `godot/assets/{anims,mapgfx,fx,gui,sounds,musics,gamedata}/` y
  `server/data-dist/` apartados, y juega un combate entero.
- Una comprobación en CI falla si el código vuelve a nombrar `.jar`,
  `.anm`, `.xps`, `mapgfx` o `data-dist`.

> **Hecho (2026-11-15):**
>
> **Lo que se vio al apartarlo todo.** El servidor arrancaba con 0 hechizos
> (el aviso de seguridad) y rechazaba el combate: hechizos, invocaciones,
> efectos estáticos, retos, logros, condiciones, laboratorios de fusión,
> bonus de mapa, torneos, tableros de esferas, lotes de equipo y diálogos
> de NPC aún salían de `data.bdat`. El cliente se quedaba sin sus tablas
> (`assets/gamedata/*.json`, generadas por los `dump*` desde `data.bdat`) y
> pedía la fuente retail `gui/fonts/COPRGTB.TTF`.
>
> - **Servidor:** las 12 tablas, congeladas en `server/content/rules/`
>   (3,4 MB, un registro por línea) por `cmd/exportrules`, como S40 hizo con
>   las cartas: mismos structs, mismos ids. `LoadBundle` ya no abre
>   `data.bdat`; el aviso de arranque ya no manda al operador a buscar el
>   cliente. Una prueba de paridad compara cada tabla con `data.bdat`
>   registro a registro (mientras `data-dist` exista). De paso:
>   `boardByBreed` se llenaba en orden de mapa (no determinista); ahora va
>   por id.
> - **Cliente:** `server/internal/clientdata` + `cmd/exportclient` escriben
>   los JSON del cliente desde `server/content` en `godot/assets/content/`
>   (con seguimiento: `godot/` es propietario, como `server/content/`).
>   `TestClientDataUpToDate` falla si `server/content` cambia y no se vuelve
>   a exportar. Salen idénticos a los de antes, salvo los textos retail que
>   S41 ya no leía (nombres de hechizos, etiquetas de diálogo). Fuera los seis
>   `dump*` y `spell_sfx.json` (nadie lo usaba). El anuncio de evento y el
>   título de fin de combate usan nuestra fuente de títulos.
> - **La prueba:** `godot/tools/no_retail_smoke.sh` aparta las carpetas
>   retail y `data-dist`, compila el servidor, juega `fight_smoke` (o los
>   que diga `SMOKES=`) con `ARENA_ASSET_TRACE=1` y lo devuelve todo al
>   acabar. Falla si el combate no termina, si el servidor no carga
>   hechizos o si el cliente pide **cualquier** fichero que no está
>   (`AssetPaths.resolve` lo avisa con el rastreo; `read_json` callaba).
> - **La guarda de CI:** `run_tests.sh` (`run_retail_guard`, carril
>   `--headless`) compara los ficheros que nombran `.jar`/`.anm`/`.xps`/
>   `mapgfx`/`data-dist` con `godot/tools/retail_refs.txt` (81 hoy). Un
>   fichero nuevo falla; uno que deja de nombrarlos tiene que salir de la
>   lista, así que solo encoge. El paso 4 la deja vacía y la guarda pasa a
>   ser "ninguno".
>
> **Los menús, también sin retail.** Con `SMOKES=` se pasaron el lobby, el
> inventario y las pantallas. El lobby creaba la capa XML retail al
> arrancar y esta cargaba `gui/xml/theme/default.xml` y los bordes
> `gui/misc/appSkin/` aunque todos los paneles que abre son nativos: ahora
> `GuiLib` crea el tema y el cargador XML solo al abrir el primer diálogo
> XML. `gamedata/elements.json` (los elementos del lobby: Baan, el Card
> Master…) no sale de ninguna tabla de reglas; se congeló tal cual en
> `assets/content/elements.json`, como su gemelo del servidor
> (`internal/game/elements_data.go`).
>
> **Queda para el paso 4** (la lista exacta: `godot/tools/retail_refs.txt`):
> - Cliente: `map_gfx.gd`, `jar.gd`, `topology.gd`, `fightmap.gd`, la ruta
>   retail de `anm_sprite.gd` (y `anm_scripts.json`), el motor XML de
>   `src/gui/` con los diálogos que aún no tienen panel nativo (S38),
>   `test/map_smoke.gd`, `topology_bounds_test.gd`, `tools/export_islands.gd`,
>   `tools/art/build_arena.gd`, la casilla "retail" del editor de mapas.
> - Servidor: `cmd/studio` (visor de datos retail), `cmd/dumpelements`,
>   `cmd/genelements`, `envmaps.go`/`worldtopo.go`/`elementviews.go` (mundo
>   abierto, el `/TP` de GM), `exportcards` y `exportrules`.
> - **Las pruebas Go que leen `data-dist`** (`*_real_test.go`,
>   `realdata_test.go`, las e2e `realdata`/`challenge_fight`/
>   `victory_condition`, `balance_sim_test.go`…): sin `data-dist` se saltan
>   en silencio. Antes de borrarlo hay que pasarlas a `server/content`, o se
>   pierde esa cobertura sin que nada se ponga en rojo.
>
> **Decisión (sin el dueño, heurística de sprints autónomos):** los hechizos
> se congelaron aquí aunque S46 los iba a mover. S43 no se puede cerrar sin
> ellos y el camino es el mismo que pedía S46 ("mismo esquema, mismos ids,
> prueba de paridad antes de rediseñar"); S46 empieza ya desde
> `server/content/rules/spells.json`.

### 4. Borrar

Esto se hace cuando el paso 3 pasa y el dueño da el ok:

- Las carpetas retail de `godot/assets/` y sus líneas de `.gitignore`.
- Los lectores: `map_gfx.gd`, `anm_sprite.gd`, `xps_fx.gd`, el motor XML de
  `src/gui/` y los `server/cmd/dump*` que queden.
- `server/data-dist/`. Se acaba la excepción de redistribución.
- Los docs: AGENTS.md (la excepción de `data-dist`), README, DISCLAIMER y
  QUICKSTART dejan de hablar del cliente antiguo.

## Orden

- Los pasos 1 y 2 pueden empezar cuando las 6 arenas del prototipo tengan `layout`
  (S36, fase D), sin esperar al resto de M7.
- Los pasos 3 y 4 necesitan que S35 y S37–S41 hayan sustituido su parte.
- "Dejar de depender totalmente" llega con el paso 4.

## Llega de S40 (2026-11-15)

Las cartas ya son de `server/content/`; el cliente aún lee el JSON que
generan los `dump*` (`assets/gamedata/cards.json`, `fightercards.json`).
Al quitar `data-dist`, el cliente tiene que leer `server/content/`
directamente, como ya hace con las arenas.

## Criterio de cierre

Desde un checkout limpio, sin `godot/assets/` retail ni
`server/data-dist/`, el servidor arranca y el cliente juega un combate en
cualquiera de las 6 arenas del prototipo, con nuestros modelos, efectos, sonidos, cartas
y textos. Ningún fichero del repo lee formatos del cliente antiguo.

## Llega de S41 (2026-11-15)

El cliente ya no lee ninguna tabla de texto retail (`GameText` borrado, la
capa XML no carga `gui/i18n_*.json`, `NpcDialogs` solo toma la estructura de
`npcdialogs.json`). Al borrar `godot/assets/` retail: `gui/i18n_*.json` y
`gamedata/cardsets.json` ya no hacen falta, y `dumpnpcdialogs` puede dejar de
exportar textos.
