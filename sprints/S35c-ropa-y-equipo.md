# S35c — Ropa y equipo sobre la figura

**Planificado:** 2026-11-11 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🟡 abierto 2026-11-11: pasos 1–3 hechos (piezas rígidas, arma, el luchador vestido en el lobby y en combate); paso 4 (sombreros) aprobado; paso 5 (las 23 armas) esperando al dueño

## Por qué

Dueño, 2026-11-11: "nos faltaría la ropa y todo eso". S35 dejó los 24
luchadores, las 9 invocaciones y los 2 coaches en 3D, con piel y pelo del
coach teñibles. Lo que lleva puesto cada uno (el equipo del coach, los 5
huecos de equipo del luchador, los cosméticos de S30) todavía no se ve sobre
la figura. Tampoco se veía antes: ninguna pantalla lo dibujaba.

## Alcance

- **Piezas rígidas** colgadas de un hueso del rig común (`BoneAttachment3D`):
  sombrero y casco → `head`; arma → `hand.R`; capa, hombreras y mascota de
  espalda → `chest`; dofus → flotando junto a la figura. Las ilustraciones ya
  están (S35: `accesorios/`, 75 piezas de luchador; `ropa-coach/`).
- **Prendas que se deforman** (torso, pantalón, falda, botas): GLB de Meshy por
  prenda, con los pesos transferidos del cuerpo en Blender al mismo rig de 20
  huesos (`meshy_fighter.py` como base) y la piel de debajo oculta.
- ~~**Peinados del coach**~~: fuera (dueño, 2026-11-11: solo color, que ya
  se cambia con la máscara de S35).
- El servidor ya sabe qué lleva cada uno (5200 del coach, `Objects` del
  luchador): el cliente lo pinta al recibirlo, en combate y en los menús.

## Decisiones del dueño (2026-11-11)

- **Qué se ve en la 1.0: todo el equipo** ("en la 1.0 todo"): los huecos de
  equipo del coach y del luchador y los cosméticos de S30.
- **Peinados del coach: no, solo color** ("los peinados no... solo color"):
  el pelo de Meshy se queda fundido en la malla y se tiñe con la máscara de
  S35. Sale del alcance el coach base calvo con el pelo como pieza aparte.

## Criterio de cierre

Un coach y un luchador con su equipo puesto, en combate y en el lobby, con
las piezas que el dueño elija; al cambiar de equipo cambia la figura sin
reconstruirla.

## Inventario (2026-11-11)

Contado en `assets/gamedata/fightercards.json` y `cards.json`:

| Quién | Ranura | Cartas | Cómo |
|---|---|---|---|
| luchador | arma (tipo 1) | 23 | rígida, `hand.R` |
| luchador | mascota (2) | 15 | rígida, `chest` |
| luchador | capa (3) | 15 | rígida, `chest` |
| luchador | sombrero (4) | 16 | rígida, `head` |
| luchador | dofus (5) | 6 | flotando, sin hueso |
| coach | sombrero/casco (11) | 31 | rígida |
| coach | hombreras (7), brazaletes (5) | 13 + 13 | rígidas |
| coach | capa (8), bastón (12), mascota (13) | 15 + 13 + 7 | rígidas |
| coach | falda (2), pantalón (9), torso (10), botas (6) | 19 + 19 + 26 + 27 | se deforman |
| coach | marcas (4) | 13 | textura sobre la piel |
| coach | peinado (3) | 19 | fuera (solo color) |

Unas 167 piezas rígidas, 91 prendas y 13 marcas.

## Paso 1: piezas rígidas, piloto (2026-11-11)

| Cambio | Fichero |
|---|---|
| `Fighter3D.equip(slot, pieza)` / `hang()`: la pieza (GLB) va en un `BoneAttachment3D` del hueso de su ranura; quitarla o cambiarla toca un nodo, no la figura | `src/anims/fighter3d.gd` |
| El sombrero se ajusta a la cabeza de cada figura: caja de los vértices que mueve sobre todo el hueso `head` (cabeza y pelo), ancho × 0,85, hundido 0,45 del alto | `fighter3d.gd` (`_head_box`, `HAT_SINK`) |
| El dofus flota junto al pecho, sube, baja y gira | `fighter3d.gd` (`DOFUS_AT`) |
| Carta → pieza: `pieces.json` (`fighter` y `coach`); `wear_fighter_cards()` viste al luchador con sus cartas (`cards` del ET2) en combate | `art/equipment/pieces.json`, `src/fight/fight_view.gd` |
| Dos piezas piloto mías en kiln (diseño propio): sombrero de paja (carta 108) y dofus verde (118) | `art/equipment/kit.kx.js` |
| `anim_sheet.gd --cards=108,118` (o `--pieces=hat:hat_straw`) y `FIGHT_UI_CARDS=108,118` en la vista del combate | `tools/art/anim_sheet.gd`, `test/fight_ui_preview.gd` |
| Prueba: carta → ranura → pieza | `test/unit/fighter3d_test.gd` |

Construir las piezas: `cd godot/art/equipment && node ~/.claude/skills/kiln/bin/kiln.js build kit.kx.js`
(`out/` git-ignorado; falta meterlo en `tools/art/build.py`).

Hoja: `~/codigo/capturas/s35c/s35c-piloto-sombrero-dofus.png` (Feca m y f,
Sram m, Pandawa f, Xelor m, Sadida f; arriba en reposo, abajo celebrando: el
sombrero sigue a la cabeza con los brazos arriba). `run_tests.sh`: 672
checks, 0 fallos.

Visto en la hoja:
- El sombrero encaja en las seis cabezas sin tocar nada por figura.
- El pelo de punta del Sram m atraviesa la copa: el pelo está fundido en la
  malla de Meshy.
- En combate (arena 10) Arel queda detrás del árbol; la toma de cerca es la
  de `anim_sheet`. Dueño: "el árbol no debería tapar al muñeco": deuda
  técnica, **B-189** en [`BACKLOG.md`](./BACKLOG.md) §12 (no es de este sprint).

### Preguntas para el dueño (antes de hacer las 270 piezas)

1. **Quién hace las piezas.** a) Flow → Meshy, como las figuras (mismo
   acabado con textura; ~167 rígidas, mucho trabajo tuyo); b) yo en kiln
   (low-poly de color plano, como el piloto: rápido, pero no casa del todo
   con las figuras de Meshy); c) mezcla: Meshy para lo que se ve grande
   (sombreros, capas, armas, mascotas), kiln para lo pequeño (dofus,
   brazaletes, hombreras). **Mi propuesta: c.**
2. **El pelo que atraviesa el sombrero.** a) Aplastar el pelo bajo el
   sombrero (el shader encoge los vértices de la cabeza por encima del ala);
   b) sombreros más grandes que tapen el pelo. **Propuesta: a.**
3. **Armas.** Varias figuras de Meshy ya llevan su arma fundida en la mano
   (Yopuka f, la espada). ¿El arma equipada sustituye a la de la clase (hay
   que separarla de la malla) o se lleva en la otra mano / a la espalda?

### Respuestas del dueño (2026-11-11)

1. **Las piezas las hago yo en kiln** ("tú las puedes hacer… hacerlo con
   Meshy es demasiado"). El sombrero piloto vale; ajustar un poco la altura.
   El brazo que atraviesa el sombrero al celebrar: arreglarlo **o dejarlo**,
   "al fin y al cabo es un lowpoly".
2. **Pelo que atraviesa la copa:** subir el sombrero un poco ("se podría
   subir el sombrero un poco hacia arriba"), no aplastar el pelo.
3. **El arma equipada sustituye a la de la clase**: el arma fundida en la
   malla de Meshy se oculta cuando el luchador lleva un arma.

Siguiente (antes de las respuestas): el lobby (la figura de la gestión de
equipo con su equipo) y la primera tanda de piezas.

## Paso 2: altura del sombrero y arma que sustituye (2026-11-11)

| Cambio | Fichero |
|---|---|
| Sombrero más alto (respuesta 2): hundido 0,36 del alto de la cabeza (antes 0,45) | `fighter3d.gd` (`HAT_SINK`) |
| Inventario de armas fundidas en las 24 figuras (frente y perfil): **solo la Yopuka f** (la espada). Las bolsas de la Anutrof f no son arma | — |
| `meshy_fighter.py --weapon=1`: la pieza suelta de más de 25 cm que va entera con un brazo sale como malla propia `class_weapon`, con los mismos pesos (Yopuka f: 226 vértices) | `tools/blender/characters/meshy_fighter.py`, `art/characters/figures.json` |
| Arma equipada en `hand.R`, a 6 cm de la muñeca, la hoja hacia delante y un poco abajo; mientras se lleva, `class_weapon` se oculta y vuelve al quitarla (respuesta 3; luego sustituido: abajo) | `fighter3d.gd` (`WEAPON_*`, `show_class_weapon`) |
| Espada corta piloto en kiln (carta 1) | `art/equipment/kit.kx.js`, `pieces.json` |

Hojas: `~/codigo/capturas/s35c/s35c-sombrero-altura.png` (las seis
figuras, frente y perfil) y `s35c-arma-sustituye.png` (Yopuka f sin carta
con su espada, Yopuka f con la espada corta, Feca m con espada y sombrero,
Sadida m; arriba en reposo, abajo golpeando). `run_tests.sh`: 674 checks,
0 fallos.

Visto: en la Yopuka f la espada de la clase desaparece entera y la nueva va en
la misma mano. El pelo de punta del Sram m apenas asoma por la copa. El brazo
que atraviesa el ala al celebrar se queda así (respuesta 1).

Dueño, después: "¿podrías quitarle la espada a la Yopuka f?". **Hecho:** la
figura ya no lleva arma propia; `--weapon=1` pasa a `--drop_weapon=1`, que
borra la pieza (226 vértices) en vez de separarla, y sobra el ocultar
`class_weapon` del juego. Ninguna figura lleva arma: el arma es solo la de la
carta. Hoja: `~/codigo/capturas/s35c/s35c-yopuka-f-sin-espada.png` (sin
carta, en reposo y golpeando; con la espada corta, igual).

Siguiente: el lobby (la figura de la gestión de equipo con su equipo) y las
75 piezas de luchador en kiln, por ranura: primero los 16 sombreros, en una
hoja para el dueño.

## Paso 3: el luchador vestido en el lobby y en combate (2026-11-11)

Dueño: "continúa con tu trabajo".

| Cambio | Fichero |
|---|---|
| "Equipo del luchador" lleva a la derecha la figura 3D con sus cinco cartas puestas. La figura se guarda entre los redibujados del panel: al poner o quitar una carta cambia esa pieza, no la figura (criterio de cierre) | `src/ui/lobby_panels.gd` (`_equip_figure`) |
| Vista sin servidor del panel: sombrero y dofus, luego espada y sin sombrero; falla si la figura se reconstruye | `test/fighter_equip_preview.tscn` |
| `fight_smoke` comprueba que cada figura 3D lleva las piezas de las cartas del 8000 (los luchadores de los dos equipos traen sus cartas) | `test/fight_smoke.gd` (`_check_equipment`) |

Probado:
- `run_tests.sh`: 674 checks, 0 fallos.
- `fighter_equip_preview`: ok (misma figura tras el cambio; `worn` = dofus y
  espada). Capturas `~/codigo/capturas/s35c/s35c-lobby-equipo-1.png` y `-2.png`.
- Servidor local: `loadout_smoke` 7 OK, 0 errores de script (un hueco vacío
  llega como `null`, no `{}`: arreglado); captura
  `s35c-lobby-equipo-servidor.png` (Humo, Yopuka m, con Raciela → espada corta).
- Combate real (`fight_smoke`, reto 34): con la base local los Humo del
  combate no tenían cartas; les puse 1, 108 y 118 en `fighter_objects` (183
  filas), y los dos Humo salieron con espada, sombrero y dofus
  (`EQUIP OK`); filas borradas después. Captura `s35c-combate-real.png`
  (los dos sombreros abajo a la izquierda, junto al HUD).

Pendiente de este sprint:
- Las 75 piezas de luchador en kiln (por ranura, una hoja por ranura).
- El coach: sus cartas solo llegan para uno mismo (5200); en combate, el
  8000 trae de cada coach piel, pelo y sexo, sin equipo: hace falta un campo
  nuevo en el servidor para ver el equipo de los demás coaches.
- Las prendas que se deforman (91) y las marcas (13).
- Meter `art/equipment` en `tools/art/build.py`.

## Paso 4: los 16 sombreros de luchador (2026-11-11)

| Cambio | Fichero |
|---|---|
| Los 15 que faltaban, en kiln, diseño propio (la ilustración retail solo como idea): Kritter (calavera con cuernos), Dora (gorro con borde de hojas), Dantgul (gorro naranja cosido), Dragosombrero (cáscara de huevo), Champo (seta plana), Clint (vaquero), Caparasombrero (caparazón), Cuerbosombrero (yelmo con pico), Melenuda (cabeza de pájaro con melena), Jalató (lana y cuernos), Champisombrero (seta roja con cuernos), Moskitogarruleto (capucha con gafas), Prespic (capucha de púas), El Cascruj (piedras), Corona de Sidán (aro con pinchos). 100–700 triángulos cada uno | `art/equipment/hats.kx.js` |
| Convención: `pivot: "origin"`, `y = 0` es donde apoya en la cabeza; un casco o máscara baja por debajo de 0 | `hats.kx.js` (cabecera) |
| Las 16 cartas (108–133, 157) → su sombrero | `art/equipment/pieces.json` |
| La caja de la cabeza cuenta pelo, cuernos y orejas: con la cabeza ancha de la Osamodas f el sombrero salía al 160 %. Escala limitada a 0,8–1,15 | `fighter3d.gd` (`HAT_MIN`, `HAT_MAX`) |

Corregido al revisar las piezas: el ala del Clint flotaba suelta a los lados
(ahora un ala entera doblada hacia arriba), los dientes del borde del
Dragosombrero parecían patas (más cortos y más), los ojos del Kritter
abultaban (aplastados).

Hojas: `~/codigo/capturas/s35c/s35c-sombreros-16.png` (cada sombrero en una
figura distinta, de frente y de perfil, con el nombre de la figura debajo) y
`s35c-sombreros-16-piezas.png` (las piezas solas). `run_tests.sh`: 674
checks, 0 fallos.

Para el dueño: Jalató y Prespic tapan media cara en las cabezas pequeñas
(Sacrogrito m, Osamodas m) y el Dragosombrero cubre el casco del Xelor m;
¿subirlos o se quedan como máscaras?

Dueño: "si tapan la cara no pasa nada… todo ok". **Los 16 sombreros
aprobados tal cual**, máscaras incluidas.

## Paso 5: las 23 armas de luchador (2026-11-11)

| Cambio | Fichero |
|---|---|
| Las 23 en kiln, diseño propio, por familia: 4 espadas (Raciela, Kwakhoja, Llyoda Da, Jaley), 4 pares de dagas (Bashers, Taimadagas, Ajadoras, Olynaa), 4 arcos (La Cuerda, Arco Desade, Cotazo, Arco Ángel), 3 bastones (Celestina, Varita de Líder, Pataflón), 4 martillos (Cerbero, Falistos, Parteghuls, Xelorillo), 4 hachas y palas (Pala Enredaderada, Enterradora Infiel, Luna Roja, Solitaria). 58–376 triángulos | `art/equipment/weapons.kx.js` |
| Convención nueva: el origen es el centro de la empuñadura (antes la base); la espada piloto pasa a ser la Raciela | `weapons.kx.js` (cabecera) |
| La familia sale del nombre: `bow_` en la mano izquierda y vertical, `staff_` hacia arriba, `dagger_` a pares (una por mano; quitarla quita las dos), el resto hacia delante y un poco abajo | `fighter3d.gd` (`WEAPON_STYLES`, `_grip`) |
| Las 23 cartas → su arma; la prueba comprueba que cada carta del `pieces.json` es real y su pieza está modelada | `pieces.json`, `test/unit/fighter3d_test.gd` |

Corregido al revisar: los mangos de martillos y hachas empezaban en la
mano (la bola del Xelorillo flotaba debajo); ahora bajan 20 cm.

Hojas: `~/codigo/capturas/s35c/s35c-armas-23-1.png` y `-2.png` (cada arma en
una figura, en reposo y golpeando), `s35c-armas-familias.png` (de cerca:
dagas, dos arcos, dos bastones, martillo) y `s35c-armas-23-piezas.png`.
`run_tests.sh`: 751 checks, 0 fallos.

Dueño, al ver las armas: "creo que necesitarías una animación para el
arco… ¿no crees?". De acuerdo: hoy el golpe de arma con arco es `melee`, un
tajo. **Pendiente (paso 7):** una animación `shoot` en `rig_anims.py`
(tensar con la izquierda, la cuerda hasta la cara con la derecha, soltar),
la misma para las 24 figuras (reconstruirlas); `Fighter3D.take` pone
`shoot` en lugar de `melee` cuando el arma puesta es `bow_`. Bastones:
`cast` ya vale. Va antes que las capas, mascotas y dofus solo si el dueño
lo pide; si no, después.

## Paso 6: capas, mascotas y dofus de luchador (2026-11-11)

Dueño: "sigue con S35c".

| Cambio | Fichero |
|---|---|
| Las 15 capas en kiln, diseño propio: N'terarroza (harapo oliva), Gallo Umbo (azul con greca), Taz (rayas en punta), Tofu Loco (flecos de plumas), Dofustadora (blanca con borde naranja), Wey Wabbit (naranja con piel), La Harapa (capucha y remiendos), Abracapa (escamas de corteza), Jalosa (vellón con lazo y pezuñas), Vegacapa (una hoja), Champ Champ (baba que gotea), Mochila del Pequeño Moskito (mochila con casco y gafas), Crujicapa (piedra agrietada), Prespic (piel con púas y zarpas), Plumobardes (plumas en punta). 130–710 triángulos | `art/equipment/capes.kx.js` |
| Una capa son tiras planas alrededor de un cilindro (abraza la espalda), el bajo con forma propia, inclinada 4–8° hacia atrás para que las piernas no la atraviesen | `capes.kx.js` (`cape`, `on`) |
| Las 15 mascotas: Wauwau, Miaumiau, Wabbit, los cuatro Bwak, Moon, Buhordilla, Rayalkulo, Fotasma, Kwoko, Cuerbako, Tortuga, Abra. 170–570 triángulos | `art/equipment/pets.kx.js` |
| Los 6 dofus: Esmeralda (espiral), Turquesa (casquete helado), Púrpura (brasa con llamas), Zanahowia (anillo), Vulbis (corona de hojas oscuras), de los Hielos (cristales). 80–450 triángulos. El dofus piloto pasa a ser el Esmeralda | `art/equipment/dofus.kx.js`, `kit.kx.js` |
| Las 36 cartas → su pieza | `pieces.json` |
| La capa va en la espalda a la altura de los hombros, escalada al ancho del torso (0,85–1,2); la mascota sobre el hombro izquierdo, 10 cm por fuera de la articulación del brazo, a 1,4× (a escala de juego, al lado de la cabeza, se perdía). La caja medida de la cabeza pasa a ser por huesos (`_bones_box`) y sirve también para el torso y el hombro | `fighter3d.gd` (`CAPE_*`, `PET_*`) |
| Cada `.kx.js` nuevo va en un bloque `{ }` para que sus ayudas no choquen con las de los otros includes | `capes/pets/dofus.kx.js` |

Corregido al revisar: la mascota salía dentro del cuello y el pelo (la caja del
torso es estrecha y alta); el hocico del Wauwau era una caja suelta (ahora
redondo); la cola del Fotasma parecía un hueso (ahora un cono); el huevo de
los dofus era casi una bola (más alto, 0,19 m); el casquete del Turquesa
parecía una seta (más pequeño).

Hojas: `~/codigo/capturas/s35c/s35c-capas-15-1.png` y `-2.png` (cada capa en
una figura: de espaldas, de perfil y de frente), `s35c-mascotas-15-1.png` y
`-2.png` (de frente por los dos lados y de espaldas), `s35c-dofus-6.png`, y
las piezas solas en `s35c-{capas-15,mascotas-15,dofus-6}-piezas*.png` (las
capas se ven por dentro: la cara de fuera está en la hoja con figura).
`run_tests.sh`: 821 checks, 0 fallos.

Para el dueño: la capa es rígida (cuelga del pecho, no ondea); la Mochila
Moskito es una mochila, no una capa. ¿Valen así?

Dueño: "estaría bien que ondeen, pero si es complejo, déjalo rígido"; la
Mochila Moskito vale. **Hecho, barato:** la capa sigue rígida pero cuelga de
una bisagra en el cuello (`Fighter3D._swing`): quieta se mece ±2°; al andar
se levanta 12° hacia atrás y aletea ±4°, con suavizado al empezar y parar. Una
tela que se doble de verdad (varios huesos o simulación) queda fuera.
`fighter_equip_preview` pone capa y mascota, hace andar al luchador y falla si
la capa no se mueve (15,3° al andar); captura `s35c-capa-ondea.png`. También
pedido: apuntar en S16 la limpieza de los contenedores viejos del VPS (hecho).

## Paso 7: el arco dispara (2026-11-11)

Dueño: "continúa con el paso 7".

| Cambio | Fichero |
|---|---|
| Animación `shoot`, la misma para las 24 figuras: el brazo izquierdo sube al frente con el arco, la mano derecha tensa la cuerda hasta la cara, aguanta, suelta y vuelve (36 fotogramas). El arco va en la mano a lo largo del brazo, así que la muñeca izquierda se dobla 85° para que siga vertical con el brazo levantado | `tools/blender/characters/rig_anims.py` |
| Las 35 figuras reconstruidas (`build.py`: `rig_anims.py` cambiado); las de luchador traen 11 animaciones. Invocaciones y coaches no la usan | `art/characters/out/` (fuera de git) |
| Un golpe de arma (`AnimStatique03-<fam>`) con un `bow_` puesto hace `shoot` en lugar de `melee`; los puños (`-219`) siguen con `melee`. `equip()` apunta la pieza de cada hueco | `fighter3d.gd` (`_shoots`, `take`) |
| `art/equipment/` en `art/CREDITS.md`: `build.py` fallaba en la comprobación de créditos desde que existe la carpeta | `art/CREDITS.md` |

Probado:
- `run_tests.sh`: 873 checks, 0 fallos (nuevo: cada carta de sombrero, capa,
  mascota o dofus enseña una pieza de su tipo).
- `fighter_equip_preview`: sin arco, `melee`; con la carta 28 (La Cuerda),
  `shoot`; con arco y puños, `melee`.
- Combate real (`fight_smoke`, reto 34, servidor local): a los Humo les puse
  arco 28, mascota 92 y capa 97 en `fighter_objects` (185 filas, borradas
  después); `EQUIP OK` y `SHOOT OK … plays shoot` en los dos.
- `build.py` completo en verde (0 fallos).

Hoja: `~/codigo/capturas/s35c/s35c-arco-dispara.png` (Ocra m y Sadida f con el
Arco Ángel y la capa Plumobardes; cada fila, siete momentos del disparo, de
frente y de perfil). En las figuras de brazos cortos la mano llega a la
altura del pecho, no de la mejilla. No hay flecha: la cuerda no se mueve con
la mano (el arco es una pieza rígida).

Dueño: "el arco está girado". Cierto: la panza miraba al arquero y la cuerda
al blanco (la muñeca se doblaba hacia abajo y el arco, simétrico, quedaba
boca abajo). **Arreglado:** la muñeca se dobla hacia arriba (`hand_L=-85`);
ahora la panza va hacia delante y la cuerda hacia la cara, y el arco sigue
vertical al bajar el brazo. Figuras reconstruidas (`build.py` en verde),
`fighter_equip_preview` ok, hoja `s35c-arco-dispara.png` rehecha.

## Paso 8a: el coach lleva su equipo, en el lobby y en combate (2026-11-11)

Dueño: "continúa". El paso 8 es grande (unas 92 piezas rígidas del coach, 91
prendas, 13 marcas y el campo nuevo del servidor); va por tandas. Esta es la
fontanería: que lo que lleva cada coach llegue y se pinte.

| Cambio | Fichero |
|---|---|
| Mensaje nuevo **60040** (solo Godot): justo después del 8000, cada coach del combate con sus cartas puestas (hueco de 5201, carta). El bloque del coach del 8000 retail no tiene sitio y el cliente retail aún existe (S43 sin cerrar), así que va aparte y solo a la sesión que mandó el 60000 (el cliente Godot); también al reconectar | `server/internal/game/fight_packets.go` (`buildFightCoachLooks`), `handlers_fight.go`, `handlers_reconnect.go`, `session.go` (`godot`), `handlers_clientconfig.go`, `protocol/opcodes.go`, `docs/OPCODE-INVENTORY.md` |
| El combate guarda el 60040 en el coach (`State.coach_ids[id].cards`) y viste su figura al colocarlo (4102) | `src/fight/fight_view.gd` (`_coach_looks`, `_dress_coach`) |
| `Fighter3D.wear_coach_cards()` / `coach_pieces()`: hueco del coach → pieza (0 sombrero, 7 bastón en la mano como un arma, 8 capa, 9 mascota). Un hueco sin hueso (hombreras, brazaletes, todavía) no pinta nada; antes habría flotado como un dofus | `src/anims/fighter3d.gd` (`COACH_SLOT`) |
| El coach del lobby lleva lo que dice el 5200 (`localCoach.worn`) | `src/main.gd` (`_push_coach_worn`), `src/ui/lobby_screen.gd` |
| Piloto con las tres cartas de coach que ya tienen pieza aprobada: capa La Jalosa (18) → `cape_jalosa`, Miaumiau (75) → `pet_miaumiau`, Wauwau (80) → `pet_wauwau` | `art/equipment/pieces.json` (`coach`) |
| `art/equipment` entra en el pipeline: `build.py equipment` (o el build entero) lo construye con kiln; `check.py` comprueba que cada pieza de `pieces.json` está construida, dentro de presupuesto (1500 triángulos, 256 KB) y al día; `pack_arenas.gd` copia `pieces.json` y sus piezas junto a la release (sin esto un juego exportado no llevaba el equipo) | `tools/art/build.py`, `check.py`, `pack_arenas.gd` |

Probado:
- Go: `go test ./...` en verde; nuevas `TestFightCoachLooksListsWornCards`
  (cartas puestas sí, la bolsa no; el lado sintético sin nada) y
  `TestFightCoachLooksOnlyToGodot` (una sesión retail no recibe el 60040).
- `run_tests.sh`: 873 checks, 0 fallos. `build.py` y `check.py`: 0 fallos
  (equipo: 75 GLB, 1,6 MB). `pack_arenas.gd` a una carpeta: 276 ficheros,
  con `equipment/pieces.json` y las 75 piezas.
- Combate real (`fight_smoke`, ahora manda el 60000 como el juego): al coach
  `test` le puse la capa 18 y la mascota 75 en `coach_cards` (2 filas,
  borradas después); `COACH EQUIP OK test cards=[55, 18, 75] … worn=[cape,
  pet]` (el sombrero 55 aún no tiene pieza).
- Lobby en vivo (`hub_smoke`, paso 7 nuevo): `coach dressed` OK; captura
  `~/codigo/capturas/s35c/s35c-coach-lobby.png` (el coach con la Miaumiau al
  hombro; la capa queda detrás).

Visto de paso, no es de este sprint: `go vet` avisa en `store/seasons.go`
(54 y 102: el `range` copia un `domain.Coach`, que lleva un `sync.Mutex`); ya
estaba antes de este cambio.

Siguiente (paso 8b): las piezas rígidas del coach en kiln, por tipo y con una
hoja cada uno como las del luchador: 31 sombreros, 14 capas (sin La Jalosa),
13 bastones, 5 mascotas (sin Miaumiau ni Wauwau), y luego 13 hombreras y 13
brazaletes, que necesitan su colocación nueva (hombro y antebrazo). Después
las 91 prendas que se deforman y las 13 marcas.

## Para retomar (2026-11-11)

Dueño: "sigue el orden de los sprints". Orden que queda:
1. ~~Capas, mascotas y dofus~~: hecho (paso 6), a falta de que el dueño
   revise las hojas.
2. ~~Paso 7: la animación `shoot` del arco~~: hecho.
3. El equipo del coach: la fontanería y `art/equipment` en `build.py`,
   hechos (paso 8a); faltan sus piezas (paso 8b), las 91 prendas que se
   deforman y las 13 marcas.

Herramientas: `anim_sheet.gd --pieces=<slot>:<pieza>` o `--cards=`,
`test/fighter_equip_preview.tscn`, `fight_smoke` (`EQUIP OK`). Construir:
`cd godot/art/equipment && node ~/.claude/skills/kiln/bin/kiln.js build kit.kx.js`.
