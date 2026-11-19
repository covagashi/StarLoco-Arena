# S49 — Jugar y depurar

**Planificado:** 2026-11-19 · **Hito:** — · **Tamaño:** M · **Estado:** 🔵 en curso

## Decisión del dueño (2026-11-19)

«Ves jugando y depura.» Sin abrir el juego en la pantalla del Ally: todo
bajo xvfb y `unshare -rn` (un qemu ocupa el 5555).

## Cómo se juega

- Los 48 smokes del cliente, uno a uno, cada uno con su servidor y una
  copia de la base sembrada como pide su cabecera
  (`/tmp/claude-1000/play/seeded.sh <smoke> [args]`, fuera del repo).
- 600 combates IA contra IA con tríos al azar de las doce clases, contando
  avisos, errores, pánicos y combates que no acaban.

## Hallazgos

| | qué | tipo |
|---|---|---|
| B-191 | aceptar un combate encontrado lo rechazaba si el coach tenía más de 64 luchadores | servidor |
| B-192 | un luchador de Historia podía quedarse atascado en su tablero de esferas; aro y borde invisibles en el panel blanco | cliente + servidor |
| B-193 | una copa de Evolución sacaba a los de Élite (y "muy barato" se decía "muy caro"; el cliente solo daba un código) | servidor + cliente |
| — | una animación de paso que acaba tras el 8300 leía un luchador ya borrado (`SCRIPT ERROR`) | cliente |
| — | el panel Equipo no cabía en 1280 × 720 (tablas de una fila, todo con scroll) | cliente |
| — | `exists()` contaba como lectura fallida al buscar un dibujo opcional | arnés |

Smokes al día (no eran fallos del juego): textos de S41 (`nilo`), la
resurrección al 25 % de S40 (`revive`), empujones contra un luchador
(`displace`), el VICTORIA/DERROTA que sigue solo desde S21 (`report`), seis
pestañas de ranking desde S47 (`screens`), el bot del torneo en vivo con
el equipo de Historia (`tournament_fight`, desde S29 solo se juegan en vivo
las copas de Evolución).

**Combates IA:** 600, ninguno falla ni deja avisos; un 4 % llega al tope de
40 rondas, casi todos con un Curandero (sus curas a ~2,1× de S46 alargan
los combates: 21,2 rondas de media frente a 16,3 sin él). Es diseño, no un
fallo: anotado para cuando se toque el equilibrio.
