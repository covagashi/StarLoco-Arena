# S33 — Plan de arte: estilo, técnica y prototipo vertical

**Planificado:** 2026-10-25 · **Abierto:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🟡 esperando al dueño (elegir técnica)

## Objetivo

Decidir **cómo** se hace el arte nuevo antes de hacerlo, y probarlo con una
porción mínima del juego: **un luchador, una arena, un hechizo** jugando un
combate real.

## Por qué no copiar el retail (dueño: "tantas animaciones me parecen demasiado")

El retail son sprites pintados fotograma a fotograma: 6.977 animaciones
(acción × dirección), de las que hoy se usan 1.567 (S31). En 2026 no hace
falta así:

| Técnica | Qué ahorra | Coste |
|---|---|---|
| **Personajes 3D low-poly con un rig común**, dibujados por Godot en la vista isométrica (o pre-renderizados a sprites) | las 8 direcciones salen gratis (es girar el modelo); una animación vale para las 12 clases si comparten esqueleto; la ropa y el equipo se cambian sin redibujar | modelado y rig; el estilo no es "pixel" |
| **2D por piezas (cutout) con `Skeleton2D` + IK** | 2–3 direcciones con espejo en vez de 8; una animación por esqueleto para todas las clases | dibujar cada pieza por clase y dirección |
| **VFX en tiempo real** (`GPUParticles2D/3D`, shaders, trails) en vez de animaciones por hechizo | **un solo gesto de lanzar** (o 3: corto, a distancia, potente) + un efecto por **elemento** (fuego, agua, tierra, aire, neutro) con variantes por color/escala | escribir los shaders y una librería de efectos |
| **Animación procedural** (squash & stretch, retroceso al golpe, rebote al morir, temblor de cámara) | sustituye golpe, muerte, KO y retroceso hechos a mano | ajuste fino |
| **Herramientas de IA** (conceptos, variaciones de color, texturas, ayuda en el retopo y en la captura de movimiento desde vídeo) | velocidad en conceptos y variantes | licencias y coherencia: el arte final, revisado a mano |

**Lista mínima de animaciones por personaje (propuesta):** reposo, andar,
golpe recibido, morir, lanzar (1–3 variantes), ataque cuerpo a cuerpo,
salto/teletransporte, celebrar, y llevar/lanzar solo para la clase que lo
usa. Unas **10 por esqueleto**, no por clase ni por dirección: frente a las
~1.500 de hoy.

## Tareas

- [x] Hoja de estilo (art bible), borrador abajo; paleta en
      `godot/proto/s33/palette.gd`.
- [ ] Elegir técnica de personajes: 3D en Godot / 3D a sprites / cutout 2D.
      **Probadas las tres con el mismo luchador** (abajo); falta que el dueño
      elija.
- [ ] Prototipo vertical: 1 luchador (rig + 10 animaciones), 1 arena, 1
      hechizo con VFX por elemento, en un combate real contra la IA.
- [x] Medir: peso en disco y coste por fotograma (abajo). El rendimiento con
      la GPU de la Ally queda para el prototipo vertical, con la técnica
      elegida (sin abrir ventanas en la pantalla del dueño).
- [ ] Escribir el pipeline elegido (S34).

## Criterio de cierre

El dueño elige técnica y estilo sobre el prototipo jugando; queda escrito el
número de animaciones por personaje y la lista de VFX base.

## Hoja de estilo (borrador, 2026-10-25)

- **Proporciones:** cabezón (cabeza + sombrero ≈ 45 % de la altura), cuerpo
  corto y miembros gruesos; ~70 px de alto a tamaño de juego sobre celdas de
  86×43, como hoy.
- **Contorno** marrón oscuro (`#2a1d14`), nunca negro; **dos tonos** por
  material (luz desde arriba a la izquierda) y un brillo de borde fino.
- **Paleta:** cuerpos cálidos y poco saturados con un acento fuerte por
  personaje (sombrero rojizo del prototipo); el dorado de la UI (`#e2bd6e`)
  se repite en bufanda y remates; las arenas en la piedra de UiStyle con
  musgo y grietas.
- **Equipo por anillo:** azul/rojo bajo los pies; la ropa no lleva el color
  del equipo (dueño: sin colores de luchador).
- **Lectura de la espalda:** cada clase lleva un detalle trasero (aquí, la
  cola de la bufanda) para distinguir NE/NW de SE/SW de un vistazo.
- **Elementos:** un par de colores por elemento (núcleo y borde), compartido
  por VFX, gema del arma y la interfaz: fuego naranja, agua azul, tierra
  ocre/verde (trozos, sin brillo aditivo), aire blanco/turquesa en remolino,
  neutro violeta en anillo.

## Prototipo (2026-10-25)

`godot/proto/s33/`: el mismo luchador con las tres técnicas sobre una arena
de piedra propia, con **una sola pose procedural** (`pose.gd`: reposo,
andar, lanzar, golpe, morir) que leen el rig 3D y el recorte 2D por igual:
la apuesta de "una animación por esqueleto, no por clase ni dirección". El
golpe es procedural (retroceso, aplastado, destello blanco); la muerte
también. Los hechizos son VFX en tiempo real por elemento (`vfx.gd`):
proyectil con estela, estallido y anillo en el suelo.

Todo es arte de prueba hecho con primitivas (no hay Blender ni Krita en la
Ally): sirve para elegir técnica, no es el aspecto final.

```
xvfb-run -a -s "-screen 0 1280x720x24" godot --path godot --fixed-fps 30 \
    -s proto/s33/capture.gd -- --out=<dir> --video --measure
python3 -I godot/proto/s33/make_sheet.py <dir> ~/codigo/capturas/s33/s33-tecnicas.png
```

**Para el dueño:** `~/codigo/capturas/s33/s33-tecnicas.png` (hoja: tres
columnas, siete estados, VFX y números) y `s33-tecnicas.mp4` (10 s, las
tres a la vez: reposo, andar, cinco hechizos uno por elemento, muerte).

| Medida | A — 3D en vivo | B — 3D → sprites | C — Recorte 2D |
|---|---|---|---|
| Peso por clase | glTF, est. 0,1–0,3 MB | **medido:** 415 KB con 5 anims × 5 dir. (295 PNG) → ~0,8 MB con 10; 12 clases ≈ 10 MB | ~15 piezas × 2 vistas, est. 0,2–0,5 MB |
| Coste, 12 luchadores (llvmpipe, solo relativo) | 52 ms/frame (un viewport por luchador; uno compartido y la GPU lo bajan mucho) | prototipo en vivo 19 ms; el real reproduce PNG: como C o menos | 10 ms/frame |
| Direcciones | 8 gratis (girar el modelo) | 5 horneadas + 3 espejo, gratis al hornear | 2 dibujadas + espejo |
| Zoom / cámara | nítido a cualquier escala | pixelado (se ve en los 3x) | nítido |
| Equipo y ropa | se cambia sin redibujar | rehornear | piezas nuevas por vista |

Hoy, las animaciones retail ocupan 239 MB en 4.245 PNG.

**Recomendación (opinión, decide el dueño): A.** Es la que mejor encaja
con lo que pidió: pocas animaciones compartidas, ocho direcciones y equipo
sin redibujar, VFX en tiempo real y una cámara que puede acercarse (reels,
remates). El coste por luchador se resuelve con un único viewport 3D para
todos los actores. B es la alternativa si quiere aspecto pixel y el
mínimo coste en la Ally; C, si prefiere un estilo de papel recortado y
dibujar a mano.

**Siguiente, cuando elija:** el prototipo vertical (un combate real contra
la IA con esa técnica dentro de `fight_view`) y escribir el pipeline (S34).

## Después del prototipo: arena 5 (2026-10-25)

Registro de toques artísticos (dueño → cambio → fichero):

| Dueño | Cambio | Fichero |
|---|---|---|
| "usa estas skills (loom, pxl, kiln, reel)… el tipo ankalike ya me gusta… mapa 1… primero tiles, mapas, muñecos, animaciones/efectos y por último la iluminación" | skills instaladas; el mapa 1 no es arena, se elige la 5 (Entrenamiento); acabado pintado suave | `godot/art/arena5/` |
| "la forma de la nieve es muy sólida… pasan el corte" | tiles loom + kiln aprobados | `tiles.tx.js`, `tiles.kx.js` |
| decoración low-poly: "suspendido", "AI slop" | se descarta; se prueba un bloque solo | — |
| "quiero pintado" | bloque vectorial SVG | `paint/ice_block.mjs` |
| "demasiado rígido… ¿qué dice vex?" | vex instalada; bloque, pincho y árbol en vex | `vex/arena5.vx.js` |
| "pilla el asset real… pásalo por la skill" | trazado vex del pincho y el árbol retail, solo como referencia, fuera del repo | `~/codigo/m7-referencias/` |
| "hazlo con kiln… solo el árbol y el bloque" | árbol kiln (tocón facetado, corteza loom, gorros de nieve) | `tree.kx.js`, `block.kx.js` |
| "me quedo con kiln… en el mapa hay demasiada iluminación" | **decidido: kiln para tiles y decoración**; la luz se corrige en el paso de iluminación | `tools/art/patch.gd` |

**Decisión de técnica (dueño, 2026-10-25): kiln (3D real con texturas loom).**
Queda por decidir si en el juego va en 3D vivo o horneado a 2D.


## Correcciones del dueño a las fichas de piezas (2026-10-25)

Notas sobre `~/codigo/capturas/m7/arenas/arena-NNN.png`: qué es cada pieza
en realidad, qué se descarta y qué la sustituye. Sirven de referencia para
elegir las piezas de cada arena en la sesión limpia.

| Arena | Pieza | Nota del dueño | Acción |
|---|---|---|---|
| 005 | #3 (gfx 167) | no es una losa oscura: es un **puente de madera** | renombrar |
| 005 | #6 (gfx 176) | no son cristales azules: son **hojas con nieve encima** | renombrar |
| 005 | #14 (gfx 156) | hielo con bola de nieve | **descartar**; en su sitio va #2 (bloque de hielo transparente, gfx 154) |
| 005 | #20 (gfx 123) | bloque negro: solo está para dar efecto (sombra) | **quitar**, no es un asset |
| 010 | #13 (gfx 1665) | rayo de luz desde el cielo | **VFX**, no es pieza de mapa |
| 010 | #22 (gfx 1342) | efecto de luz, como #13 | **VFX** |
| 010 | #35 (gfx 1253) | efecto | **VFX** |
| 010 | #6 (gfx 123) | el mismo bloque negro de la 005 #20; se parece al efecto VFX | **no se usa** |
| 010 | #26, #27 (gfx 202, 203) | hojas de árbol tipo arce (Canadá) | renombrar |
| 010 | #32 (gfx 1016) | arbusto | renombrar |
| 010 | #33 (gfx 1029) | árbol | renombrar |
| 010 | #38 (gfx 2559) | árbol sin hojas | renombrar |
| 010 | #39 (gfx 128) | roca con lava | renombrar |
| 010 | #44 (gfx 246) | hierba (grass) | renombrar |
| 010 | #36, #37 (gfx 1675, 1676) | el mismo asset que la 005 #18, #19 (postes farol) | uno solo para las dos arenas |
| 010 | #23 (gfx 140) | la misma forma que la 005 #4 (gfx 170), pero gris verdoso en vez de blanco | variante de color, pendiente de decidir cómo |

Reglas que salen de esto:
- gfx 123 (bloque negro) no es un asset en ninguna arena.
- Los rayos de luz van a VFX, no a la decoración.
- Hay muchas piezas que repiten forma con otro color; el dueño pregunta si
  basta con una y cambiar el color (ver la respuesta en la conversación del
  2026-10-25).
- Orden acordado: primero el dueño repasa todas las fichas y dice qué no se
  usa; después se hace el catálogo de familias (mismo gfx / misma forma con
  otro color) y el dueño lo confirma.

### Lista por gfx (dueño, 2026-10-25)

Los gfx son únicos, así que la referencia es el gfx y no el número de la
ficha. Copia legible por máquina en `~/codigo/m7-referencias/gfx_rules.json`,
que es lo que usará el catálogo.

| Regla | gfx |
|---|---|
| fuera, no es un asset | 123 (bloque negro de sombra), 1781 (vacía) |
| fuera, es VFX | 74, 75, 76, 462, 463, 907, 908, 1253, 1342, 1583, 1587, 1646, 1665, 2037, 2043, 2044, 2045, 2046, 2047, 2048, 2049, 2050, 2051, 2385, 2450, 2451, 2489, 2964, 3487 |
| se sustituye por 154 | 155, 156 |
| se queda por ahora | la sangre de la arena 041 |

Pendiente para cada mapa: las piezas de "textura" o adorno menor (piedrecitas,
hojitas, nieve suelta) se deciden mapa a mapa.
