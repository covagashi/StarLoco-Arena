# 2026-11-11 — S35b-marketing: la tanda 3 (los esqueletos)

Pedido: "continúa con el sprint, creo que te faltaba algo de S35b". Lo que
faltaba era [`S35b-marketing`](../sprints/S35b-marketing.md): los 9 posts
de la tanda 3, sobre cómo se hicieron los esqueletos.

## Hecho

- 9 posts en `~/codigo/marketing/tanda-3/` (30–38: cinco reels, cuatro
  carruseles) con `texto.txt` en inglés y `LEEME.md` con el orden.
- Herramientas para rehacerlos: `tools/blender/characters/promo_bones.py`,
  `promo_slices.py`, `promo_naive.py`, `promo_crystal.py`;
  `tools/promo/fight_promo.gd/.tscn`, `tanda3_render.sh` y `tanda3.py`.
- `crystal_8010.py` solo construye al ejecutarse (se puede importar).

## Decisiones

En el sprint ("Decisiones"): el 32 sin comparar con los pesos de Blender
(salían iguales), el 33 con los 5 bugs que se ven a tamaño móvil, cada
"antes" sacado del script anterior al arreglo; ningún nombre de clase en
imagen ni texto; el 38 es un combate en escena (no hay servidor aquí).

## Probado

- Cada post revisado en hojas a tamaño móvil: legible, nada del retail,
  "Pippop Arena" en cada uno.
- `godot/run_tests.sh`: 552 checks, 0 fallos.

## No verificado

- Ningún post publicado (los sube el dueño).
- El 38 no es un combate real con servidor.
