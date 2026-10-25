# S36 — Arenas: todos los assets primero, y un editor para que el dueño monte los mapas

**Planificado:** 2026-10-25 · **Abierto:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (fase B: bioma nieve aprobado)

## Por qué cambia el plan (dueño, 2026-10-25)

> "Ni siquiera arena-plan-1 está actualizado. Creo que será mejor si primero
> pasas todo y creas los assets y creas las texturas, y luego haces algo para
> que yo pueda hacer los mapas. Dejas el 'shape' del mapa, pero luego yo
> posiciono los assets."

Ese día se intentó montar la arena 1 entera de forma automática, colocando
nuestros modelos en las coordenadas de los sprites retail
(`tools/art/build_arena.gd`). Salió mal:

- Los bloques quedaban unos 70 px más altos que los retail.
- Las columnas apiladas repetían la franja oscura de la base.
- Faltaban los tintes por celda.
- La hoja `arena1-plan.png` no reflejaba lo hecho.

**Conclusión: la máquina no coloca. Se hacen todos los assets, y el dueño
coloca en un editor.**

## Lo que ya hay (de S33)

- Criba del dueño por gfx en `~/codigo/m7-referencias/gfx_rules.json`:
  - `drop`: lo que no es un asset.
  - `vfx`: va a S37, no a la decoración.
  - `replace`: 155 y 156 → 154.
  - `family_merge` / `family_split`: correcciones a las familias.
- Catálogo de familias en `~/codigo/capturas/m7/catalogo/` (`catalog.py`):
  64 familias, 177 gfx en familias, 964 piezas sueltas y 49 comunes
  (salen en 8 arenas o más).
- Técnica decidida: **kiln** (3D) con texturas **loom**.
  - Aprobados: `ice_block` y `tree` (`godot/art/arena1/`).
  - A revisar: `ice_clear` (bloque transparente).
- Las variantes de color van como **un modelo y un tinte**. El retail ya lo
  hace así: cada sprite lleva un `c` multiplicador, y la nieve lila es el
  bloque blanco teñido.
- La arena 1 es el mundo retail 5. El arte vive en `godot/art/arena1/`.

## Tres looms por pieza (dueño, 2026-10-25)

> "Pasa los assets a kiln, y en la herramienta que tú hagas yo podré poner 3
> diferentes tipos de loom."

- Cada pieza se exporta en tres looms: `<nombre>` (a), `<nombre>_b` y
  `<nombre>_c`.
  - Es el mismo modelo kiln con todos los materiales de textura cambiados
    (`base` + `swap`).
  - Las texturas de cada loom son loom.
- En el editor (fase C), al colocar una pieza se elige a, b o c.
- Las variantes de color del retail (las familias del catálogo y el tinte
  lila) pasan a ser looms.

## Mapa por mapa (dueño, 2026-10-25)

> "Vamos mapa por mapa rellenando los assets; recuerda reutilizar lo que ya
> tenemos."

Se descarta hacer los seis biomas de golpe con agentes: modelaban a partir
de lo que creían que era cada dibujo retail y se equivocaban (la 160 era la
puerta 166 con nieve, no unas setas). Sus carpetas (`godot/art/{lava,
pradera,ruinas,playa,fortaleza,cueva}/`) quedan sin subir y sin revisar.

Proceso, por arena:
1. `map_sheet.py <mundo> <arena>` (fuera del repo) genera
   `~/codigo/capturas/m7/mapa-arenaN.png`. Lleva las piezas retail del mapa
   ya cribadas, numeradas por uso, cada una con lo que es:
   - el nombre que dio el dueño, o mi suposición marcada con "¿?";
   - si ya la tenemos (por gfx, o por familia: misma forma con otro loom),
     junto a nuestra pieza; si no, NUEVO.
2. El dueño corrige qué es cada pieza. Sus nombres se guardan en
   `names.json` y mandan sobre los míos.
3. Se modelan solo las piezas nuevas, siguiendo las skills kiln y loom, y
   se enseñan.

Numeración: arena N es el N-ésimo mundo por id (arena 1 = mundo 5, arena 2
= mundo 10, arena 3 = mundo 12…).

### Arena 2 (mundo 10, otoño y lava), 2026-10-25

El dueño confirmó todas las suposiciones de `mapa-arena2.png`; la 138 y la
141 son la escarcha (la misma forma en verde).

- Kit `godot/art/arena2/` con 19 piezas en tres looms:
  - suelo: bloque de roca marrón (+ columna), losa verde, charco de lava;
  - plantas: arbusto otoñal, arbusto alto, árbol otoñal, árbol sin hojas,
    hojas caídas, hierba;
  - piedra: columna de roca, rocas verdes, roca con lava, tótem, tótem alto,
    piedras blancas;
  - armas: armas en el suelo, espada, lanza y hoja clavadas.
- Loom en las superficies grandes (roca, losa, lava, tótem), hechas con las
  reglas de la skill; colores de paleta con 2–3 tonos en plantas y armas.
- El follaje son hojas de arce de cinco lóbulos sobre un núcleo oscuro. La
  primera versión eran bolas lisas, y la segunda parecía de estrellas.
- Se reutiliza del kit de la arena 1: piedra tallada, piedrecitas, losa con
  glifo, runa y farol. Además, el cordón de la escarcha en verde
  (`grass_drift`, tres looms verdes).
- `mapa-arena2.png`: las 52 piezas del mapa cubiertas (0 nuevas). Hoja del
  kit: `kit-arena2.png`.

## Fases

### A. Inventario completo (antes de modelar nada)

- [ ] Una hoja de plan por arena, como `arena1-plan.png` pero bien hecha y
      regenerada de verdad cada vez:
  - aplica `gfx_rules.json` y las familias;
  - cada pieza lleva su estado (hecho / a revisar / por hacer / menor) y la
    vista de nuestro modelo;
  - empezar por arreglar la de la arena 1.
- [ ] Lista maestra de assets sin duplicados: una entrada por familia o por
      pieza suelta, con las arenas que la usan.
  - Es lo que hay que fabricar.
  - Se agrupa por bioma (nieve, otoño/lava, hierba…).
- [ ] El dueño marca lo que no se usa y los adornos menores que se quedan
      (decisión por mapa, pero las 49 comunes se deciden una vez).

### B. Fabricar los assets y las texturas

**Bioma nieve (arena 1): aprobado por el dueño el 2026-10-25 ("perfecto, ya se ve todo bien").**
Hoja: `~/codigo/capturas/m7/arena1-kit.png`. Retail a la izquierda y las
tres looms a escala de juego a la derecha. Plan actualizado en
`~/codigo/capturas/m7/arena1-plan.png`.

- `godot/art/arena1/kit.json`: el manifiesto del kit, que leerá el editor.
  Lleva 15 piezas con su tipo (`tile` / `deco` / `flat`), la altura donde se
  pisa, la columna que va debajo, los gfx retail que sustituye y el nombre
  de cada loom.
- `kit.kx.js`: incluye `tree.kx.js` y `block.kx.js`. Son 17 modelos, cada
  uno en tres looms:
  - bloques (con nieve, transparente) y sus dos columnas;
  - árbol, puente, escarcha y escarcha pequeña, hojas con nieve;
  - pincho y pincho doble, farol, montón de nieve, nieve suelta,
    piedrecitas;
  - losa con glifo y runa de suelo.
- Las texturas: `block.tx.js` y `kit.tx.js`.
  - Los bloques se pasaron a funciones con tres looms (nieve, lila y
    escarcha). La `a` es idéntica a la aprobada; se comprobó píxel a píxel.
  - Las columnas llevan una textura sin franjas, para que se apilen.
- Glifos baybayin: `glyphs.py` los dibuja con Noto Sans Tagalog
  (`godot/art/fonts/`, OFL).
  - Losas: ha, ba, ka (oro viejo, azul, rojo).
  - Runas: la, ta, sa (ámbar, azul, rojo, con brillo).
- `tools/art/kit_shots.gd` fotografía cada pieza y cada loom a escala de
  juego.
  - Cada pieza sale sola. El dueño (2026-10-25): "no entiendo por qué el
    puente o la escarcha necesitan un bloque". El bloque de debajo solo
    confundía, y el puente ya no lleva columna en `kit.json`.
  - `kit_sheet.py` (fuera del repo) compone la hoja.
- No hay pack único: kiln no resuelve en un pack los materiales cambiados
  entre ficheros incluidos. El editor cargará `out/models/<nombre>.glb`.
- Escarcha (170 y 174), corrección del dueño: "es una línea de nieve
  acumulada". Se rehízo como un cordón de nieve a lo largo de un eje de la
  casilla, con crestas afiladas por el viento.
- Pincho de hielo (157), dueño: "hazlo más grueso". La base pasa de 0,17 a
  0,29 m de radio, con 6 caras; los dos trozos laterales y la nieve del
  pie también crecen.
- Siguiente: los demás biomas, que se sacan de la lista maestra (fase A).

- [ ] Por bioma: primero las texturas loom del bioma y después los modelos
      kiln (bloques, losas, columnas, decoración).
  - Cada familia, un solo modelo con los colores como tinte.
  - Las columnas usan una textura sin franjas, para que se puedan apilar.
- [ ] Cada asset se revisa en una hoja a escala de juego (`build_tile.gd` y
      `patch.gd`), y el dueño da el ok pieza a pieza.
  - Una pieza cada vez: enseñarla y esperar el ok (`slow-down-art`).
- [ ] Losas doradas y runas de suelo: glifos **baybayin** con una
      tipografía, "a modo de trampa" (idea del dueño).
- [ ] Lo que la criba marcó como VFX se apunta para S37, no se modela aquí.

### C. Editor de mapas para el dueño

- [ ] Herramienta que carga la **forma** de cada arena: casillas, alturas,
      obstáculos y celdas de salida, sacadas de la topología de combate que
      el servidor ya usa. **La forma no se toca.**
- [ ] El dueño **coloca los assets**:
  - una paleta con la lista maestra, filtrada por bioma;
  - clic en una casilla para poner o quitar;
  - girar, reflejar, tintar (selector de color o los tintes del bioma) y
    escalar un poco;
  - el bloque de suelo por casilla y la decoración encima;
  - las columnas se rellenan solas hasta el pie del mapa.
- [ ] Se guarda un `layout` por arena dentro del repo (JSON legible: casilla,
      modelo, giro, tinte).
- [ ] La vista es la del juego: ortográfica 2:1, casillas de 86 px y la
      misma luz.
- [ ] Por decidir con el dueño: el editor va dentro de Godot (vista real 3D)
      o en el studio (Go/Wails). **Recomendación: Godot**, porque los
      modelos y la luz se ven igual que en el combate.

### D. Del editor al juego

- [ ] `fight_view` dibuja el `layout` de la arena con nuestros modelos en vez
      de `MapGfx` retail.
- [ ] El dueño monta las arenas que quiera para la 1.0. Antes se habló de
      12–20.

## Lo que queda a medias de la sesión del 2026-10-25 (sin commit)

- `godot/tools/art/dress.gd`: el vestido de los GLB (normales suaves en la
  nieve, borde de luz en el hielo) sacado de `build_tile.gd` para
  compartirlo. Se puede quedar.
- `godot/tools/art/build_arena.gd` y `godot/art/arena1/layout.json`:
  colocación automática desde los sprites retail. **Descartada** como forma
  de montar mapas, aunque decodificar la casilla de cada sprite (clave `z`)
  puede servir para mostrar el retail como referencia en el editor.
- `godot/art/arena1/block.kx.js`: columnas `ice_col` / `ice_clear_col`.
  Hay que rehacer su textura sin franjas (fase B).

## Criterio de cierre

Todas las arenas que el servidor sienta tienen un `layout` hecho por el
dueño con nuestros assets, y `MapGfx` retail ya no se usa.
