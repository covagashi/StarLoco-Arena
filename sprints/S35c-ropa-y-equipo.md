# S35c — Ropa y equipo sobre la figura

**Planificado:** 2026-11-11 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🟡 abierto 2026-11-11: pasos 1–2 (piezas rígidas, piloto; arma que sustituye a la de la clase) hechos; esperando al dueño

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
