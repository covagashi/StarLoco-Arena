# S55 — Afinar la ropa y las piezas, una a una

**Planificado:** 2026-11-27 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** ⚪ planificado (2026-11-27)

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
geoset + malla». **El método:** cada prenda como geoset (la parte del
cuerpo que tapa, fuera) más su propia malla, prenda a prenda, con su hoja y
el visto bueno del dueño antes de la siguiente.

Lo que ya hay de las pruebas de S54 (todo en `~/codigo/capturas/s54/ropa/`,
nada en el build):

- `cloth_pose_geo.py`: posa el original de 676k y le quita las caras bajo
  una prenda (`GEOSET=<prenda.glb>,…`: un rayo por vértice a lo largo de su
  normal, 12 cm); también pinta tela sobre la piel (los argumentos tras la
  máscara).
- `hd_clothes.py`: la prenda hecha del original con `garment.py` de la
  skill `blender-clothing` (zona, holgura 6 mm, pesos de los huesos, piel
  tapada oculta); sin grosor (`THICK=0`: el `Solidify` explota en las caras
  diminutas del original).
- `subdiv.py`: la tela de una prenda subdividida una vez, los cuernos sin
  tocar.
- `coach_portrait_geo.gd` / `coach_portrait_hdc.gd`: el renderizador de la
  imagen con esas prendas (`--geoset=`, `--static=`, `--paint=`).
- Hojas: `44`–`47` (pintada, WoW + geoset, blender-clothing).
- Lo que quedó mal en ellas: bordes de color borrosos (copiados de la
  prenda de 5k: pintar con la receta), una rendija en la cadera, el borde
  del top del original asomando por encima de la parte de arriba.

S54 sigue abierto por lo que no es ropa: el 3D del coach fuera del
arranque de la web y las medidas, las invocaciones con la reducción limpia,
los pies que quedan y la partida entera en web.
