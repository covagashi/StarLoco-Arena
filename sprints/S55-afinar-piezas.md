# S55 — Afinar la ropa y las piezas, una a una

**Planificado:** 2026-11-27 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** 🟡 en curso (2026-11-27)

## Por qué

En S54 las figuras bajaron a 5k y el coach del lobby pasó a imagen, pero la
ropa del coach se ve mal: el dueño, al ver las hojas del lobby, «es verdad
que la ropa se ve mal». Probé cuatro maneras (S54, hojas 17–19 y 44–47):
la de hoy (las caras del cuerpo de 5k empujadas hacia fuera), la prenda
como tela propia, pintada sobre la piel como en WoW, WoW + geoset, y la
skill `blender-clothing` sobre el original de 676k. Con la última, el
dueño: «pinta bien y mejor, pero tenemos que afinar mejor cada pieza».

## El recuento (2026-11-27)

Todas las figuras: 5 000 triángulos como mucho (confirmado; `check.py`).

| | Cuántas | Hoy |
|---|---|---|
| **Coach: prendas que se doblan** (`garments.json`) | 104 por coach (208 GLB) | caras del cuerpo de 5k empujadas; máx. 2 490 triángulos |
| · torso | 26 | |
| · botas | 27 | |
| · pantalones | 19 | |
| · faldas | 19 | |
| · marcas (tatuajes) | 13 | |
| **Coach: piezas rígidas** (kiln, en un hueso) | 92 | |
| · sombreros | 31 | |
| · capas | 15 | |
| · hombreras | 13 | |
| · brazaletes | 13 | |
| · estandartes y báculo | 13 | |
| · mascotas | 7 | |
| **Luchadores: piezas rígidas** (kiln, en un hueso) | 75 | |
| · armas | 23 | 4 espadas, 4 dagas, 4 arcos, 3 bastones, 4 martillos, 4 hachas |
| · sombreros | 16 | |
| · capas | 15 | |
| · mascotas | 15 | |
| · dofus | 6 | |

Cada carta tiene su pieza (196 del coach, 75 de los luchadores). Lo que se
ve mal son las 104 prendas del coach; las 167 rígidas están por revisar.

## Plan (borrador, a cerrar con el dueño)

1. **Receta por prenda** con `blender-clothing` sobre el original de 676k
   (S54, `hd_clothes.py`): la zona de cada prenda, su holgura y su grosor
   (sin que explote: limpiar antes las caras diminutas del original), los
   pesos de los huesos.
2. **Color bien pintado:** con la receta de cada prenda (franjas por altura,
   parches por ángulo, dibujos) horneado en una textura, no copiado de la
   prenda de 5k: bordes nítidos.
3. **Lo suelto** (faldas, capas, estandartes) con simulación de tela (la
   skill `arjun988-cloth-sim`: pines, colisión, asentado, horneado).
4. **Una a una:** cada prenda con su hoja (de frente, a medio muslo y
   entera, con las dos coaches), el dueño la aprueba o la corrige.
5. **La misma prenda para el combate:** reducida a juego con el cuerpo de
   5k (o pintada en su textura).
6. **Las piezas rígidas:** una hoja de las 167 para que el dueño diga cuáles
   se rehacen.

## Respuestas del dueño (2026-11-27)

- «Pues sí, dejamos el hub 2D en los muslos»: la imagen de S54; y luego
  «mejor completo en el hub»: entera, como en los cuatro menús.
- «Sobre las prendas, lo hacemos 1 por 1»: cada prenda con su hoja y su
  visto bueno antes de la siguiente.

## Para retomar (2026-11-27, el dueño hace /clear)

El dueño: «todo ok, ahora hago clear y hacemos los ítems 1 a 1 usando el
geoset + malla … usando la skill». **El método:** cada prenda con la skill
`blender-clothing` (`~/.claude/skills/blender-clothing/scripts/garment.py`)
como geoset + malla: la malla de la prenda hecha del cuerpo con la skill, y
la parte del cuerpo que tapa, fuera (su `--hide-body`). Prenda a prenda,
con su hoja y el visto bueno del dueño antes de la siguiente.

Lo que ya hay de las pruebas de S54 (todo en `~/codigo/capturas/s54/ropa/`,
nada en el build):

- `hd_clothes.py`: la prenda hecha del original de 676k con `garment.py`
  (la zona = lo que tapa la prenda de hoy, holgura 6 mm, pesos de los
  huesos, la piel tapada oculta); sin grosor (`THICK=0`: el `Solidify`
  explota en las caras diminutas del original; limpiarlas antes).
- `cloth_pose_geo.py`: posa el original y le quita las caras bajo una
  prenda (`GEOSET=<prenda.glb>,…`).
- `subdiv.py`: la tela de una prenda subdividida, los cuernos sin tocar.
- `coach_portrait_hdc.gd` / `coach_portrait_geo.gd`: el renderizador de la
  imagen con esas prendas (`--static=`, `--geoset=`, `--paint=`).
- Hojas: `44`–`47`. Lo que quedó mal: bordes de color borrosos (copiados
  de la prenda de 5k: pintar con la receta de `garments.json`), una
  rendija en la cadera, el borde del top del original asomando.

S54 sigue abierto por lo que no es ropa: el 3D del coach fuera del
arranque de la web y las medidas, las invocaciones con la reducción limpia,
los pies que quedan y la partida entera en web.

## Prenda 1 — arriba kepika (`torso_kepika`) (2026-11-27)

Script: `~/codigo/capturas/s55/ropa/hd_garment.py` (de `hd_clothes.py`;
`run.sh <coach> <prenda>` lo pasa y pinta la imagen de hoy y la nueva,
`sheet.py` hace las hojas). Nada en el build todavía: entra cuando el
método quede aprobado.

**El método** (geoset + malla, con `garment.py` de `blender-clothing`):

- **La zona, por la receta** (`garments.json`), no por la prenda de 5k: el
  mismo corte que `coach_garment.py` (cuello, cintura, la sisa como plano
  en el brazo), cada vértice del original por el hueso que más lo lleva.
- **La malla:** las caras del original en la zona (1 cm de más), soldadas
  (Meshy parte la piel en cada costura UV: sin soldar, quitar migajas
  dejaba agujeros), reducidas a 8 000 caras y relajadas 60 pasadas, a 6 mm
  de la piel como mínimo, con un muelle a su sitio fuerte junto al borde
  (el borde libre se hundía en la barriga) y flojo dentro. Así la tela pasa
  por encima de los músculos y de los pliegues del top del original, no
  los calca (con el original entero y 676k caras, ni 3 000 pasadas
  bastaban: el hombre parecía pintado).
- **Cortes limpios:** los dobladillos y los bordes de cada franja con
  planos, las caras fuera de la receta fuera, y lo que queda dentado
  (los bordes entre huesos) relajado a lo largo de sí mismo.
- **Color, de la receta, antes de mover nada:** `paint()` de
  `coach_garment.py` en el centro de cada cara: bordes nítidos.
- **Cuernos:** `add_extras()` de `coach_garment.py`, como en la de 5k.
- **Pesos:** los del original (`garment.py`); un trozo de cintura que el
  original pesaba al brazo colgado (en la pose del menú salía un pincho
  hacia la mano) toma los del tronco más cercano.
- **El geoset:** se oculta la piel que la prenda tapa de verdad (un rayo
  por vértice) y a 1,5 cm o más de su borde (pegado al borde, con la
  holgura, se veía el hueco por debajo); en la pose del menú, también la
  piel que asoma por fuera de la tela. Las caras quedan del lado de fuera
  de su hueso (el top del original va encima de la piel: al juntarse,
  algunas caras salían del revés).
- 7 400–7 600 triángulos (solo para la imagen del menú).

**Hojas:** `~/codigo/capturas/s55/01-torso_kepika-mujer.png` y
`01-torso_kepika-hombre.png` (hoy, nueva entera, y las dos de cerca).

**Lo que veo:** sin facetas ni dientes, franjas rectas, sin rendija en la
cadera, los cuernos en su sitio; la tela más ceñida que la de hoy. Quedan
el dobladillo de la mujer un poco ondulado por delante (la barriga), una
muesca de hombro en la sisa del hombre (es la sisa: sin mangas se ve el
hombro) y la franja oscura del cuello (la receta: 0–0,07).

Pendiente del dueño: visto bueno o correcciones de la prenda 1 antes de la
2.

**El cuello** (el dueño: «mejora el cuello, se ve raro»): la receta sube
el top hasta el cuello (`top: 0`), y con la sisa cortada al hombro queda
una tira estrecha hasta la garganta con la franja oscura encima (en el
hombre, un collar oscuro). Probé el escote recto más abajo
(`OVERRIDE='{"top": …}'` en `hd_garment.py`, la receta sin tocar):
hoja `~/codigo/capturas/s55/02-cuello-opciones.png` — A como estaba, B a
5 cm bajo el cuello, C a 9 cm. B queda limpio en los dos, con la franja
oscura como ribete del escote; C deja asomar en la mujer el borde del top
del original. Propuesta: B (`"top": 0.05` en `torso_kepika`, que también
cambiará la prenda de 5k cuando se reconstruya).

**El dueño eligió B** («el B pero arregla el top del hombre»): `"top": 0.05`
en `torso_kepika` (`garments.json`; la de 5k cambiará con él cuando se
reconstruya). El top del hombre tenía un mordisco en la sisa derecha: el
original pesa al brazo la piel de su pecho bajo las hombreras, y el plano
de la sisa a lo largo del brazo se la comía. Para un top sin manga
(`sleeve` ≤ 0), en `hd_garment.py`:

- la piel que el brazo lleva se queda si cae dentro del alcance del tronco
  a esa altura y en esa dirección (`trunk_reach`: lo más lejos que llega la
  piel del tronco, por centímetro y por 22,5°) y dentro de un corte
  vertical junto al hombro, o si la deja el plano de antes; las dos reglas
  solas fallaban en uno de los dos (un peto plano en el hombre, alas
  colgando a los costados de la mujer, que lleva el brazo pegado);
- esa piel del pecho toma solo los pesos del tronco y el hombro (con los
  del brazo, la tela se estiraba en láminas hasta el codo);
- la piel del propio brazo no se oculta (su cara interior mira a la tela y
  el rayo la encontraba: agujeros en el brazo).

Hoja: `~/codigo/capturas/s55/03-torso_kepika-{mujer,hombre}.png`. Queda en el
hombre una marca fina en el borde interior de los brazos (el canto de la
tela asomando junto al brazo) y en la mujer el dobladillo algo ondulado.

**Prenda 1 aprobada** (el dueño: «doy, ok, siguiente pieza»).

## Prenda 2 — pantalón kepika (`pants_kepika`) (2026-11-28)

Hecho junto con el arriba aprobado (`run.sh <coach> torso_kepika,pants_kepika`:
varias prendas en una pasada). Dos arreglos en `hd_garment.py`:

- **Las manos:** en reposo descansan contra los muslos, y los pesos por la
  cara más cercana daban a las caderas algo del brazo: en la pose del menú
  salían dos solapas hasta las manos. Pantalón, falda y botas no llevan
  nunca pesos del brazo (se quitan; si no queda ninguno, los del vértice
  de pierna más cercano).
- **Una prenda tras otra:** los grupos de la primera (zona, piel oculta)
  quedaban en el original y mandaban sobre sus huesos: los cuernos de la
  segunda caían en otro sitio (en el hombre, a los tobillos). Ahora la
  zona va en memoria y las máscaras se ponen al final; el hueso que manda
  en una cara no cuenta los grupos propios.

Hoja: `~/codigo/capturas/s55/04-pants_kepika-{mujer,hombre}.png`. 8 300–8 600
triángulos. Queda un poco de barriga entre el top y el pantalón en la mujer
(el top es corto; hoy se solapan).
