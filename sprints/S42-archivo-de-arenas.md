# S42 — Archivo de las arenas: referencias en PNG y JSON, sin el cliente antiguo

**Planificado:** 2026-10-28 · **Hito:** M7 — Arte propio · **Tamaño:** S · **Estado:** ⚪ planificado (antes de seguir modelando S36)

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

### 3. Dos copias

- La de trabajo: `~/codigo/archivo-arenas/` en la Ally.
- Una copia en `oracle-1`, la máquina de pruebas, nunca en `oracle-2`
  (producción). Va en un `.tar.zst` con su `sha256`.
- Por decidir (dueño): ¿también en la Samba? *Por defecto, no.*

### 4. Prueba de que basta

- Con `godot/assets/mapgfx/` y `server/data-dist/maps/` apartados (se mueven,
  no se borran), `map_sheet.py --archivo` saca las hojas de las arenas 9 y
  14 iguales a las de hoy, comparando píxeles.
- `forma.json` de las 47 arenas coincide con lo que decodifica el servidor:
  mismo número de casillas con suelo y mismas salidas. Lo comprueba una
  prueba Go mientras los `.jar` sigan en el repo.

## Fuera de alcance

- No se modela nada ni se cambia el juego.
- No se inventarían las 35 arenas. Solo queda todo listo para hacerlo.

## Criterio de cierre

Con el archivo solo, sin `godot/assets/`, sin `server/data-dist/maps/` y sin
nada del cliente antiguo, se puede sacar la hoja de cualquiera de las 47
arenas, poner nombres y saber qué piezas faltan. Hay dos copias y el README
del archivo explica cómo seguir.
