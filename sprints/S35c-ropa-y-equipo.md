# S35c — Ropa y equipo sobre la figura

**Planificado:** 2026-11-11 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🟡 abierto 2026-11-11: pasos 1–3 hechos (piezas rígidas, arma, el luchador vestido en el lobby y en combate); paso 4 (sombreros) aprobado; pasos 5–8 hechos (las 167 piezas rígidas; todas aprobadas); paso 9a (piloto de las prendas que se deforman) aprobado; paso 9b (los 19 pantalones) esperando al dueño

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

## Paso 8b: los 31 sombreros del coach (2026-11-11)

Dueño: "continúa".

| Cambio | Fichero |
|---|---|
| Los 31 en kiln, diseño propio (la ilustración retail de `ropa-coach/11-cascos` solo como idea): Hornudo, Jalatranki, cascabeles, pasamontañas rojo, puntiagudo (con aureola), Chaferombi, Champi, Sgrim (bombín), Kepika (púas), gelatina, Sedforme (guante sobre una diadema), Rompedor (aviador), orejas de wabbit, escudero, Campeón, Campierrele, Grilembore (birrete), L.Men'Tal (cazador), Dragón Blanco, Alu-Card, Gosbaster, de guerra, Kamas (moneda), Stasis, pío rojo, Superjefe, Lolomg, wonejo, Sámara, leñoso, Nuboso. 80–720 triángulos | `art/equipment/coach_hats.kx.js` |
| Las 31 cartas (tipo 11) → su sombrero; el coach los lleva por el hueco 0 (paso 8a), con el mismo ajuste a la cabeza que el luchador | `pieces.json` (`coach`) |
| Prueba: cada carta de la tabla del coach es de sombrero, bastón, capa o mascota, su pieza está modelada y es de su tipo; `coach_pieces` con hombreras aún no pinta nada | `test/unit/fighter3d_test.gd` |

Corregido al revisar las piezas: las motas del Champi quedaban dentro del
sombrero; las púas del Kepika apuntaban hacia dentro (signo de la rotación
al revés); las puntadas del aviador y los arañazos del escudero flotaban; la
barra del escudero y los colmillos del Campeón sobresalían del borde. La
aureola del puntiagudo flota a propósito.

Hojas: `~/codigo/capturas/s35c/s35c-coach-sombreros-31-1.png`, `-2.png` y
`-3.png` (cada sombrero en coach_7000 o coach_7001, de frente y de perfil) y
las piezas solas en `s35c-coach-sombreros-31-piezas-1.png` … `-6.png`.
`run_tests.sh`: 976 checks, 0 fallos; `build.py equipment` y `check.py`: 0
fallos.

Para el dueño: la gelatina y el pasamontañas tapan la cabeza entera, como en
la ilustración; la moneda del Kamas es enorme a propósito. ¿Valen así?

Dueño: "no te preocupes de si se ve la cara o no, es un juego isométrico".
**Los 31 aprobados tal cual.** De la prueba con otro modelo: "pone más
detalles pero no es ningún wow, así que nos quedamos igual" (seguimos con
este pipeline).

Aparte (dueño): prueba de otro modelo con un solo sombrero, el Dragón Blanco
(213), con el mismo pipeline; recorte de la ilustración en
`~/codigo/capturas/s35c/prueba-fable/`. Fuera del juego. Borrada después,
con sus capturas (dueño: "puedes eliminar esa prueba").

## Paso 8c: las 15 capas del coach (2026-11-11)

Dueño, sobre los sombreros: aprobados; seguimos.

| Cambio | Fichero |
|---|---|
| Las 15 en kiln, diseño propio: Arlan Txin (lavanda con borde dorado), La Jalosa (columna de lana roja, amarilla y verde, a juego con el gorro Jalatranki), Profión (blanca con cuello de pelo y puntas rojas), Ciguador (larga, ocre con borde verde y escudo), Kepika (púas), Krono (gris verdoso con flecha), Sedforme (flecos), Rompedora (costuras y remiendo), Campeón y Campierrele (melena de hojas y borlas), Alu-Card (negra en picos), Gosbaster (mechones cian), pío rojo (plumas), Cobija Nubosa (nube), Zar (ancha, a rayas, broche de estrella). 150–640 triángulos | `art/equipment/coach_capes.kx.js` |
| La carta 18 deja de usar la capa del luchador (`cape_jalosa`, un vellón): la del coach es otra cosa en la ilustración | `pieces.json` (`coach`) |
| La forma común de las capas sale a un fichero propio que el kit incluye una vez; las 15 del luchador salen idénticas (mismos triángulos) | `art/equipment/cape_kit.kx.js`, `capes.kx.js`, `kit.kx.js` |
| Las hojas de revisión pasan a ser una herramienta del repo (antes eran scripts sueltos): `equip_sheet.py figures <ranura> …` y `pieces …`, por páginas | `tools/art/equip_sheet.py` |

Corregido al revisar: las franjas laterales de la Arlan Txin y la Ciguador
subían por encima del cuello; las borlas del Campeón y el Campierrele no
seguían el bajo en zigzag y algunas quedaban sueltas debajo.

Hojas: `~/codigo/capturas/s35c/s35c-coach-capas-15-1.png` y `-2.png` (de
espaldas, de perfil y de frente) y `s35c-coach-capas-15-piezas-1.png` …
`-3.png` (vistas de kiln: se ve la cara de dentro). `run_tests.sh`: 1018
checks, 0 fallos; `build.py equipment`: 0 fallos (121 piezas, 2,4 MB).

Siguiente: los 13 bastones y las 5 mascotas del coach.

Dueño: "doy mi ok a las capas". **Las 15 aprobadas.**

## Paso 8d: los 13 bastones y las 5 mascotas del coach (2026-11-11)

| Cambio | Fichero |
|---|---|
| Los 13 "bastones" (tipo 12) son estandartes en la ilustración, salvo el Bastón Rompedor (un asta con punta dentada). En kiln, diseño propio: Laúd (lira dorada), Maza claveteada (bola con pinchos y calavera), Cetro de cascabeles (banderín de bufón), Deshueso (hueso), Mh'Asalto (verde azulado con ganchos), Cetro roído (bordes mordidos y engranaje), Aurea flamma (llama), Rompedor, Campeón y Campierrele (oscuros con franjas), Alu-Card (morado con calavera y colas), jálabol (cara de oveja), Lolomg (manchas rojas). 84–400 triángulos. Todos `staff_`: en la mano derecha y en vertical, como los bastones del luchador | `art/equipment/coach_staffs.kx.js` |
| Las 5 mascotas sin gemela de luchador (no hay ilustración: diseño desde el nombre): Zanahowia pataleante (zanahoria con patas), Demonita, Diablotín, Reloj (reloj de bolsillo con patas), Sacrificada (muñeca de trapo con venda). Miaumiau y Wauwau siguen con las del luchador | `art/equipment/coach_pets.kx.js` |
| Las 18 cartas → su pieza; la tabla del coach tiene ya 66 cartas (todas las rígidas menos hombreras y brazaletes) | `pieces.json` (`coach`) |

Corregido al revisar: el hueso del Deshueso tenía los nudillos sueltos (la
caja apoya en su base: el grupo gira ahora en el centro del hueso); la venda
de la Sacrificada flotaba sobre la cabeza (ahora la rodea). Probé a colgar la
tela de los estandartes al otro lado del asta: tapaba la cara y el cuerpo, así
que se queda por fuera, donde pisa un poco el brazo.

Hojas: `s35c-coach-mascotas-7.png` (las 7, por los dos lados); las de los
bastones se rehicieron después (abajo). `run_tests.sh`: 1072
checks, 0 fallos; `build.py equipment`: 0 fallos.

Siguiente: las 13 hombreras y los 13 brazaletes (necesitan su colocación nueva,
en el hombro y el antebrazo); después las 91 prendas que se deforman y las 13
marcas.

Dueño: "los estandartes están bien, pero pasa lo mismo que con el arco: la
tela va hacia el cuerpo, no hacia fuera". Visto en vistas rectas: de frente
la tela salía hacia fuera, pero la cámara isométrica mira en diagonal y la
proyectaba sobre el cuerpo. **Arreglado:** los estandartes son ahora
`banner_` (el Rompedor sigue `staff_`), una familia nueva de
`Fighter3D.WEAPON_STYLES` que los lleva en vertical y los gira 55° sobre el
asta (`_grip` acepta un giro), así que la tela cae hacia fuera y hacia atrás:
en una diagonal se ve de lado, en la otra de canto junto al asta, de perfil
queda detrás. El primer giro (-55°) la ponía delante de la cara; es +55°.
Hojas rehechas: `s35c-coach-estandartes-12.png`,
`s35c-coach-baston-rompedor.png` y
`s35c-coach-estandartes-mascotas-piezas-1.png` … `-3.png` (dos diagonales y
perfil). `run_tests.sh`: 1072 checks, 0 fallos.

## Paso 8e: las 13 hombreras y los 13 brazaletes del coach (2026-11-11)

Dueño: "continúa con las hombreras y brazalete".

| Cambio | Fichero |
|---|---|
| Huecos 3 (hombreras) y 4 (brazaletes) del coach → `shoulders` y `bracelets`. Van por pares, uno en cada brazo: la hombrera en `upper_arm`, el brazalete a 0,6 del `forearm` (siguen al brazo cuando se levanta). La pieza se modela para el brazo izquierdo con su cara de fuera hacia +X; el derecho la lleva en espejo, o `<pieza>_r` si el par es distinto (Jalatranki: amarilla y roja; La Moralizadora: ala y garra). Quitarla quita las dos, como las dagas | `src/anims/fighter3d.gd` (`COACH_SLOT`, `_on_arm`) |
| Las dos escalan al grosor del brazo medido en la figura: mediana de la distancia al eje del hueso de sus vértices (`_limb_radius`; 0,75–1,4). La caja de huesos y esta medida comparten `_owned_verts` | `fighter3d.gd` (`PAD_*`, `CUFF_*`, `ARM_*`) |
| Las 13 hombreras en kiln, diseño propio: Yoghi (cabeza de bicho con melena), Jalatranki (lana), La Moralizadora (ala / garra roja), Kepika (cuerno), Krono (engranaje), Sedforme (mano roja), Rompedoras (cuero con parche y costuras), Alu-Card (calavera, aro y colmillos), de guerra (cuerno y borde de acero), Stasis (placas de piedra), Superjefe (casco dorado con flecos naranjas), Sámara (semilla alada), Nubosas (nube). 78–560 triángulos | `art/equipment/coach_shoulders.kx.js` |
| Los 13 brazaletes: de fuerza (cuero con tachón), Jalatranki (rollos de lana amarillos / rojos), Alambrada espinosa (tablillas y alambre de espino), Kepika (cuerno), Krono (cresta dorada), Sedforme (placa y correas, aleta verde), Rompedores (bajo dentado y pinchos), escudero (tela con banda y flecos), Campeón y Campierrele (franjas), Alu-Card (pincho), Superjefe (brazal largo), Lolomg (anillos de piedra). 104–338 triángulos | `art/equipment/coach_bracelets.kx.js` |
| Las 26 cartas → su pieza; la tabla del coach tiene ya todas las rígidas (92) | `pieces.json` (`coach`) |
| Prueba: cartas de hombreras y brazaletes, de su tipo; los huecos 3 y 4 pintan su pieza, el 5 (prenda) aún nada | `test/unit/fighter3d_test.gd` |

Corregido al revisar las piezas: las plumas del ala de La Moralizadora
flotaban sobre la cúpula; el parche de la Rompedora y las placas del
Superjefe quedaban dentro (el punto sobre la cúpula no seguía su
inclinación); los flecos del escudero colgaban sueltos.

Probado:
- `run_tests.sh`: 1150 checks, 0 fallos. `build.py equipment` y `check.py`:
  0 fallos (165 GLB, 3,3 MB).
- Combate real (`fight_smoke`, servidor local): al coach `test` le puse las
  hombreras de guerra (506) y los brazaletes de Krono (121) en `coach_cards`
  (2 filas, borradas después); `COACH EQUIP OK test cards=[55, 506, 121] …
  worn=[bracelets, hat, shoulders]`.

Hojas: `~/codigo/capturas/s35c/s35c-coach-shoulders-13-1.png` y `-2.png`,
`s35c-coach-bracelets-13-1.png` y `-2.png` (de cerca, en coach_7000 y
coach_7001: de frente y en las dos diagonales), y las piezas solas en
`s35c-coach-{shoulders,bracelets}-13-piezas-1.png` … `-3.png`.

Para el dueño: a escala de juego las hombreras se ven como manchas de color
en el hombro y los brazaletes como un anillo; ¿más grandes, o valen así?

Dueño: "ajusta mejor las hombreras". Medido en las figuras: flotaban unos
4 cm por encima de la piel (coach_7000: articulación a 1,021 m, piel del
hombro a 1,045 m, cúpula hasta 1,086 m) y su centro, sobre la articulación,
las metía hacia el cuello; en la coach_7001 llegaban a la barbilla.
**Arreglado:** el origen de la hombrera es ahora la piel de arriba del
hombro (el vértice más alto del hombro y del brazo justo encima de la
articulación, medido por figura: `_shoulder_top`), 0,3 radios del brazo
hacia fuera; cada pieza baja lo que sube su interior (`pad(nombre, hundido,
…)`) y la cúpula se inclina 38° hacia fuera (antes 28°), sobre el
deltoides. El engranaje del Krono se inclina como las demás. Con los brazos
arriba (`celebrate`, `cast`) la hombrera sigue al brazo sin tocar la cabeza.
Hojas rehechas: `s35c-coach-shoulders-13-1.png`, `-2.png` y
`s35c-coach-shoulders-13-piezas-1.png` … `-3.png`. `run_tests.sh`: 1150
checks, 0 fallos; `check.py`: 0 fallos.

Dueño: "ok mejor"; con las hojas: "si, todo ok". **Las 13 hombreras y los
13 brazaletes aprobados.**

Siguiente: las 91 prendas que se deforman (Meshy → pesos del cuerpo) y las
13 marcas.

## Paso 9a: las prendas que se deforman, piloto (2026-11-12)

Dueño: "continúa con el sprint". Antes de las 91 prendas, una de cada tipo
en los dos coaches, como el sombrero y el dofus del paso 1.

Decisión (sin preguntar, el dueño ya dijo en el paso 1 "Meshy es
demasiado"): las prendas no son GLB de Meshy, salen **del propio coach**.
Los coaches base van en ropa interior, así que una prenda es la piel de su
zona copiada con sus pesos, separada y con grosor; se dobla igual que la
piel de debajo y no la deja asomar. Diseño propio, la ilustración retail
solo como idea, como las piezas rígidas.

| Cambio | Fichero |
|---|---|
| Generador nuevo en Blender: torso / pantalón / botas = las caras de la figura en la zona (cortadas limpias en el bajo con planos), empujadas `ease` hacia fuera y con grosor (`thick`); la falda es un tubo desde la cintura, ancho de cadera y con vuelo, con pesos de la cadera arriba a la mitad del muslo abajo. Color plano por franjas a lo largo de la prenda (`bands`), un material por color como las piezas de kiln. Se exporta con el rig del coach, sin animaciones | `tools/blender/characters/coach_garment.py` |
| Recetas de las prendas (una entrada por prenda: `kind`, colores, corte) | `art/equipment/garments.json` |
| Piloto, diseño propio: torso del escudero (176, marrón con cuello y bajo dorados, manga corta), pantalón de Grilembore (197, azul con cinturilla clara), falda Gobkool (22, verde con cinturón marrón), botas del escudero (178, cuero con vuelta) | `garments.json`, `pieces.json` (`coach`) |
| Huecos del coach 5 falda, 6 pantalón, 10 botas, 11 torso. La prenda es por figura (`out/garments/<coach>/<prenda>.glb`); su malla va al esqueleto de la figura, junto al cuerpo; quitarla quita un nodo. Las medidas de la figura (`_owned_verts`) solo cuentan el cuerpo | `src/anims/fighter3d.gd` (`GARMENTS`, `_dress_garment`) |
| Pipeline: `build.py equipment` (o el build entero) construye las prendas después de las figuras; `check.py` mira que cada prenda esté construida en los dos coaches, al día y en presupuesto (3500 triángulos, 192 KB); `pack_arenas.gd` las copia junto a la release | `tools/art/build.py`, `check.py`, `pack_arenas.gd` |
| Prueba: cartas de prenda → receta de su tipo; los huecos 11, 6, 5 y 10 pintan su prenda; un coach construido lleva el pantalón en su esqueleto, con pesos, y se lo quita | `test/unit/fighter3d_test.gd` |

Corregido al revisar: la primera tanda salía con agujeros en zigzag (muslos
de atrás, vientre). El GLB parte la piel en cada costura de UV (425 islas)
y el paso que borra migajas se comía trozos de tela; ahora se sueldan las
costuras antes. De paso, la dirección del empuje se orienta lejos del
hueso (Meshy trae alguna normal hacia dentro).

Probado:
- `run_tests.sh`: 1163 checks, 0 fallos. `build.py equipment` y `check.py`:
  0 fallos (8 prendas, 0,8 MB). `pack_arenas.gd` a una carpeta: con
  `equipment/out/garments/` de los dos coaches.
- Combate real (`fight_smoke`, servidor local): al coach `test` le puse
  torso 176, pantalón 197 y botas 178 en `coach_cards` (3 filas, borradas
  después); `COACH EQUIP OK test cards=[55, 176, 197, 178] … worn=[boots,
  hat, pants, torso]`.
- Lobby en vivo (`hub_smoke`): `coach dressed` OK, el coach sale con
  bombín, torso, pantalón y botas.

Hojas: `~/codigo/capturas/s35c/s35c-prendas-piloto-1.png` (torso, pantalón
y botas; coach_7000 y coach_7001, de espaldas y en las dos diagonales,
quieto y andando), `s35c-prendas-piloto-2.png` (torso, falda y botas,
andando y celebrando) y `s35c-prendas-lobby.png`.

Para el dueño:
1. ¿Vale este camino (la prenda sale del cuerpo, color plano por franjas)
   para las 91? Es rápido y nunca deja asomar la piel; lo que no hace es
   volumen propio (volantes, hombreras de la chaqueta, pinchos): eso iría
   como pieza rígida encima, como las hombreras.
2. Peso: torso + pantalón + botas suman unos 7500 triángulos sobre los 5000
   del coach (el grosor duplica la tela). Para la demo web se pueden
   aligerar después.

Dueño (2026-11-12): las capas, mascotas y dofus del luchador ya los había
aprobado; sobre las prendas: "sobre las piernas y el resto también, buena
técnica". **Piloto aprobado; el camino vale para las 91.**

Siguiente: las 91 prendas por tipo (19 faldas,
19 pantalones, 27 botas, 26 torsos), una hoja por tipo; luego las 13
marcas.

## Paso 9b: los 19 pantalones del coach (2026-11-12)

| Cambio | Fichero |
|---|---|
| Patrones nuevos además de las franjas (`paint()`): rayas repetidas (`stripes`), franja por fuera de cada pierna (`side`) o por delante (`front`), rombos de arlequín (`diamonds`), parches redondos (`patches`), una pierna de otro color (`leg`); y `puff` (abulta la tela entre dos alturas: bombachos, pelo en el bajo, bultos de gelatina). `start` hace que la prenda empiece más abajo (las espinilleras) | `tools/blender/characters/coach_garment.py` |
| Torso, pantalón y botas pasan a **una sola capa** (sin grosor): dentro de una manga o una pernera está el cuerpo, así que el grosor solo duplicaba los triángulos. Cada cara mira hacia fuera de su hueso. La falda conserva el grosor (por debajo se ve su interior). Los pantalones quedan en 430–2130 triángulos (antes hasta 4600 con rayas) | `coach_garment.py` |
| Los 18 que faltaban, diseño propio (la ilustración solo como idea): Bombachos (rojos, cortos y abombados), Jalatranki (rojo con franja y bajo amarillo de lana), Gregüescos (abombados naranja hasta medio muslo, medias a rayas azul marino), Salteadorillo (verde azulado acampanado con franja clara), Ladilla (rosa pálido con pelo blanco en rodilla y tobillo), Tribuno (gris verdoso estrecho), Kepika (cuero con anillos de hueso), gelatina (tres bultos rosas, cinturilla verde de hojas), Sedforme (amarillo pálido con parches verdes), calzas Rezina (rombos naranja y gris), Rompedor (mostaza con parches), escudero (verde lima con parches), tubo de wabbit (negro con franja blanca abajo), L.Men'Tal (tostado ancho por la rodilla), Alu-Card (negro con franja morada y hebilla), jálabol (corto rojo con cinturilla blanca), espinilleras del Superjefe (oro, de la rodilla abajo, borde naranja), Lolomg (verde azulado oscuro con paneles) | `art/equipment/garments.json`, `pieces.json` (`coach`) |

Corregido al revisar: los rombos del Rezina, pequeños, salían como manchas
(la cara de la figura es grande para un dibujo fino): ahora son grandes;
los parches eran demasiado pequeños para verse a escala de juego (×1,7).

Probado: `run_tests.sh`: 1199 checks, 0 fallos. `build.py equipment` y
`check.py`: 0 fallos (44 prendas, 3,5 MB). Las prendas del piloto, en una
capa, rehechas y vistas andando (`walk_loop`): sin agujeros.

Hojas: `~/codigo/capturas/s35c/s35c-coach-pantalones-19-1.png` y `-2.png`
(cada pantalón en un coach, de frente y en las dos diagonales).

Para el dueño: no llevan volumen propio (los cuernos del Kepika, las
burbujas de verdad de la gelatina): ¿así, o esas piezas sueltas encima como
las hombreras?

Dueño: "¿crees que haciendo vfx quedaría mejor que poniendo partes
sueltas?". Mi respuesta: según la parte. Lo sólido, como pieza rígida
encima (con partículas un cuerno se lee como un hechizo, no como ropa, y se
calcula en cada fotograma); los VFX solo para lo que tiene que moverse o
brillar, y en S37. Dueño: "ok hazlo como tú dices". **Decidido:**
- Las prendas siguen como están; lo que necesita volumen propio se apunta
  aquí y se hace en una tanda al final (paso 9f), como piezas rígidas en
  el hueso de su sitio.
- Los candidatos a VFX van a [`S37-vfx.md`](./S37-vfx.md) (gelatina que
  tiembla, brillo del oro del Superjefe, llama de la Aurea flamma).

Partes sueltas apuntadas (paso 9f):
- Pantalón Kepika (119): cuernos de hueso en los muslos.
- Pantalón Ladilla (54) y Jalatranki (24): un anillo de pelo o lana en el
  bajo (el abultado de ahora, más esponjoso).
- Pantalón de gelatina (126): dos o tres burbujas grandes.

Siguiente: las 19 faldas.

## Para retomar (2026-11-11)

Dueño: "sigue el orden de los sprints". Orden que queda:
1. ~~Capas, mascotas y dofus~~: hecho (paso 6), aprobado.
2. ~~Paso 7: la animación `shoot` del arco~~: hecho.
3. El equipo del coach: la fontanería y `art/equipment` en `build.py`,
   hechos (paso 8a); las 92 piezas rígidas, hechas (pasos 8b–8e); faltan
   las 91 prendas que se deforman (piloto aprobado, paso 9a) y las 13
   marcas.

Herramientas: `anim_sheet.gd --pieces=<slot>:<pieza>` o `--cards=`,
`test/fighter_equip_preview.tscn`, `fight_smoke` (`EQUIP OK`). Construir:
`cd godot/art/equipment && node ~/.claude/skills/kiln/bin/kiln.js build kit.kx.js`.
