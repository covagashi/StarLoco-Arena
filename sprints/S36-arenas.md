# S36 — Arenas: todos los assets primero, y un editor para que el dueño monte los mapas

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** ⚪ planificado (se empieza en la próxima sesión)

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
