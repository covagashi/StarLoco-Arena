# S42 — Archivo de las arenas: referencias en PNG y JSON, sin el cliente antiguo

**Planificado:** 2026-10-28 · **Abierto:** 2026-10-29 · **Hito:** M7 — Arte propio · **Tamaño:** S · **Estado:** 🟡 esperando al dueño (falta copiar el backup al RAID de la homelab)

## Decisión del dueño (2026-10-28)

> "Ya me he cansado de inventariar. Dejemos estos 12 mapas y de algún modo
> prepara un sprint para que de las 35 arenas los assets se guarden en algún
> sitio, y que en un futuro lo podamos inventariar pero sin usar Java ni
> nada del estilo del cliente antiguo."

- La 1.0 lleva **12 arenas**, de la 1 a la 12 (mundos 5, 10, 12, 15, 21,
  36, 38, 39, 40, 41, 42 y 44). Todas tienen ya los nombres del dueño.
- Las otras **35** (de la 13 a la 47, mundos 45…110) no se modelan ahora.
  Cada una se guarda montada (el mapa entero) y desgranada (sus piezas
  sueltas y dónde va cada una). Se irán añadiendo al juego más adelante,
  por ejemplo en eventos o temporadas, una a una, con su inventario, sus
  assets y su `layout`.
- Hoy montar un mapa necesita lo que se sacó del cliente antiguo. Después
  de S42, el archivo basta.
- La arena 13 (mundo 45, playa) ya tiene hojas y mis suposiciones, pero no
  los nombres del dueño. Se archiva tal cual.

## El problema

Hoy, para inventariar una arena hacen falta tres cosas, y ninguna es nuestra:

- Los sprites retail de cada mapa (`godot/assets/mapgfx/`, 16 MB). Git no
  los sigue y se borran al cerrar M7 (S32, paso 3).
- La forma de la arena, dentro de ficheros `.jar` del cliente
  (`server/data-dist/maps/{fight,tplg,env}/`, 2,7 MB). Solo los lee
  `server/internal/gamedata/fightmaps.go`.
- Las herramientas de `~/codigo/m7-referencias/`, que leen las dos rutas de
  arriba.

Cuando S43 quite el retail del juego, eso desaparece y las 35 arenas ya no
se podrían inventariar.

## Qué se hace

### 1. Un archivo autosuficiente, solo PNG y JSON

Carpeta `~/codigo/archivo-arenas/`, **fuera del repo**. Es arte retail y
no se redistribuye, igual que `m7-referencias`. Se archivan **las 47
arenas**, no solo las 35: mientras se modelan las arenas 8–12, las
comparaciones con el retail también tienen que salir del archivo.

```
archivo-arenas/
  README.md            qué es cada cosa y cómo seguir inventariando
  arenas.json          número de arena → mundo, nombre del bioma, estado
                       (hecha / con nombres / con suposiciones / sin mirar)
  comun/
    names.json         nombres del dueño, suposiciones, same y group
    gfx_rules.json     drop, vfx, replace…
    catalog.json       familias del catálogo
    kits.json          qué gfx cubre ya cada kit nuestro (de los kit.json)
  arena-NN/
    mapa.png           el mapa montado entero, como se ve en el juego
    piezas/<gfx>.png   el mapa desgranado: cada pieza suelta, una vez
    mapa.json          dónde va cada pieza: gfx, posición, tamaño, tinte, celda
    forma.json         casillas, altura, suelo o bloqueo, salidas por equipo,
                       pedestales de coach y casillas especiales
    hojas/             las páginas ya generadas (mapa-arenaNN-*.png)
```

- `mapa.json` es el `godot/assets/mapgfx/<mundo>.json` de hoy, ya
  decodificado.
- `forma.json` se saca **una sola vez** de los `.jar` con un comando Go
  pequeño (`server/cmd/dumparenas`), que reutiliza `gamedata.LoadFightMaps`.
  Ese comando lee del repo, no del cliente. Se borra en S43, cuando el
  servidor lea su propio formato.
- Las hojas de las arenas 1–13 ya existen en `~/codigo/capturas/m7/`: se
  copian. Para las 34 restantes se generan ahora, con mis suposiciones
  vacías ("¿qué es?"), y así el día que se retomen ya están listas.

### 2. Las herramientas leen el archivo

- `map_sheet.py`, `zoom.py`, `crop.py` y `arena_sheet.py` aceptan
  `--archivo ~/codigo/archivo-arenas` y, con eso, no tocan
  `godot/assets/` ni `server/data-dist/`.
- Solo usan Python y Pillow. Nada de Java, `.jar`, `.swf` ni `.anm`.
- Las herramientas viven dentro del archivo (`archivo-arenas/herramientas/`),
  para que se pueda copiar a otra máquina y siga funcionando.

### 3. Dos copias (dueño, 2026-10-28)

- La de trabajo: `~/codigo/archivo-arenas/` en la Ally.
- El backup: en el **RAID de la homelab** (Debian). Va el archivo entero en
  un `.tar.zst` con su `sha256`, y además los originales tal cual: los
  `.jar` de `server/data-dist/maps/` y `godot/assets/mapgfx/`. Así, si algo
  del archivo saliera mal, siempre se puede volver a sacar.
- La Ally no puede entrar por SSH en la homelab (solo al revés). Por eso la
  copia la trae la homelab con `rsync` desde `davian@ally`, o el dueño
  autoriza la clave de la Ally en la homelab.
- No va a `oracle-1` ni a la Samba.

### 4. Prueba de que basta

- Con `godot/assets/mapgfx/` y `server/data-dist/maps/` apartados (se mueven,
  no se borran), `map_sheet.py --archivo` saca las hojas de las arenas 9 y
  14 iguales a las de hoy, comparando píxeles.
- `forma.json` de las 47 arenas coincide con lo que decodifica el servidor:
  mismo número de casillas con suelo y mismas salidas. Lo comprueba una
  prueba Go mientras los `.jar` sigan en el repo.

## Hecho (2026-10-29)

- `~/codigo/archivo-arenas/` con las 47 arenas: `mapa.png`, `mapa.json`
  (cada sprite con su gfx, posición, tamaño, tinte, casilla, capa y orden
  de dibujo), `piezas/`, `forma.json` y `hojas/`. Ocupa unos 260 MB. El
  README explica cada fichero y cómo seguir inventariando.
- `server/cmd/dumparenas` saca `forma.json` de los `.jar` con
  `gamedata.LoadFightMaps`. Salen 47 arenas y no se salta ninguna. Su
  prueba compara cada forma con lo que decodifica el servidor: casillas de
  suelo con su altura, salidas, pedestales y casillas especiales. Con
  `ARCHIVO_ARENAS=~/codigo/archivo-arenas` compara también las copias del
  archivo. Pasa.
- La casilla de cada sprite (sacada de su clave de dibujo) cae en la forma:
  el 89 % de las casillas de suelo tienen su bloque. Las demás quedan
  tapadas por piezas grandes de una casilla vecina, como en el retail.
- Herramientas en `archivo-arenas/herramientas/`: `map_sheet.py`,
  `arena_sheet.py`, `zoom.py`, `crop.py` y `vs.py` aceptan
  `--archivo <dir>`. Solo `fuente.py` sabe de dónde se lee. Llevan la
  Liberation Sans (OFL) dentro, para no depender de la máquina.
  - `estado.py` rellena `arenas.json`: 7 arenas hechas (1–7), 5 con
    nombres (8–12), 1 con suposiciones (13) y 34 sin mirar.
  - `construir.py` rehace el archivo desde el repo mientras exista el
    retail. Se probó a rehacerlo desde cero y sale igual.
    `construir.py --comun` refresca los kits y sus fotos.
- Una sola copia: `~/codigo/m7-referencias/` enlaza a estos scripts y a
  `comun/names.json`, `gfx_rules.json` y `biomes.json`. Los nombres se
  siguen apuntando como siempre, y caen en el archivo.
- Hojas: las de las arenas 2–13 se copiaron tal como las vio el dueño. Las
  de la 1 y de la 14 a la 47 (34 arenas sin mirar, más la 1, que no tenía)
  se sacaron solo desde el archivo. Llevan "¿qué es?" en las piezas nuevas.
- Prueba de que basta: con `godot/assets/mapgfx` y `server/data-dist/maps`
  apartados (movidos y devueltos después), las hojas de las arenas 9 y 14,
  `zoom`, `crop`, `vs` y las fichas de los mundos 40 y 46 salen iguales
  píxel a píxel que desde el repo (22 imágenes).
- Arreglos que salieron por el camino:
  - `map_sheet.py` borraba las páginas con `mapa-arena{N}*.png`, así que al
    sacar la arena 1 se habría llevado las de la 10 a la 19. Ahora borra
    `mapa-arena{N}-*.png`.
  - Las fotos de los kits 6 y 7 estaban solo en `piece-loop/shots` y
    `shots7`, y las hojas no las enseñaban. Se copian a
    `capturas/m7/kit-shots/arena6` y `arena7`.
- Backup preparado en `~/codigo/archivo-arenas-backup/`:
  `archivo-arenas-2026-10-29.tar.zst` (249 MB),
  `originales-2026-10-29.tar.zst` (11 MB, con los `.jar` y `mapgfx`) y
  `SHA256SUMS`. Se descomprimió en otra carpeta, y las hojas de la arena
  20 salieron iguales desde esa copia.
- **Falta:** llevarlo al RAID de la homelab. La Ally no puede entrar por
  SSH en la homelab (`Permission denied (publickey,password)`), así que la
  copia la tiene que traer la homelab. En la homelab:

  ```sh
  rsync -av davian@ally:codigo/archivo-arenas-backup/ <RAID>/pippop/archivo-arenas/
  cd <RAID>/pippop/archivo-arenas && sha256sum -c SHA256SUMS
  ```

## Fuera de alcance

- No se modela nada ni se cambia el juego.
- No se inventarían las 35 arenas. Solo queda todo listo para hacerlo.

## Criterio de cierre

Con el archivo solo, sin `godot/assets/`, sin `server/data-dist/maps/` y sin
nada del cliente antiguo, se puede sacar la hoja de cualquiera de las 47
arenas, poner nombres y saber qué piezas faltan. El backup está en el RAID de la homelab y el README
del archivo explica cómo seguir.
