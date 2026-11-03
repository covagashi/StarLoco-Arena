# S43 — Sin el cliente antiguo

**Planificado:** 2026-10-28 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** ⚪ esbozo (cierra M7; tras las 6 arenas del prototipo y S35, S37–S41)

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
> (paso 2). Falta: que el servidor arranque sin los `.jar` (hoy los sigue
> leyendo para las otras 41 arenas) y que el cliente no lea
> `Topology`/`FightMap` para nada.

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

## Criterio de cierre

Desde un checkout limpio, sin `godot/assets/` retail ni
`server/data-dist/`, el servidor arranca y el cliente juega un combate en
cualquiera de las 6 arenas del prototipo, con nuestros modelos, efectos, sonidos, cartas
y textos. Ningún fichero del repo lee formatos del cliente antiguo.
