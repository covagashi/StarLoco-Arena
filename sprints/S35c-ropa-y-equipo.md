# S35c — Ropa y equipo sobre la figura

**Planificado:** 2026-11-11 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🟡 abierto 2026-11-11: paso 1 (piezas rígidas, piloto) hecho; esperando al dueño

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

Siguiente, cuando el dueño responda: el lobby (la figura de la gestión de
equipo con su equipo) y la primera tanda de piezas.
