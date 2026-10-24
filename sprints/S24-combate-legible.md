# S24 — Un combate que se entiende

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** S · **Estado:** 🟢 cerrado (2026-10-24) · **Depende de:** —

## Origen

El dueño, 2026-10-24 (texto completo en [S21](./S21-game-loop.md#origen)):
"¿por qué en la parte de arriba en el combate dice 'es la hora de la acción',
'dios sram', 'ira guerrera', 'diosa sacrogrito'?"

## Qué es ese letrero

Son las **cartas de evento**: una por ronda, y dura esa ronda. El servidor
(`server/internal/game/events.go`) saca una de la baraja 1..27 (la ronda 1
siempre es la 14) y aplica su efecto a todos los luchadores del combate. El
cliente recibe el id en 8100 y enseña **solo el nombre** arriba
(`fight_view.gd:663-669`, nombre de `content.8`). Lo que hace solo se ve
pasando el ratón por la tira de cartas (`fight_view.gd:1539`). Ejemplos:

| Carta | Efecto (1 turno) |
|---|---|
| 12 · Es la hora de la acción | +1 PA |
| 19 · Ira guerrera | +15 % de daño |
| 2 · Dios Sram | solo Srams: +10 % de daño elemental y +60 % de esquiva |
| 3 · Diosa Sacrógrito | solo Sacrógritos: +10 % de daño y +2 PM |

Las 12 cartas de dioses solo afectan a su clase. Un jugador que no lo sabe ve
el nombre de un dios y nada más.

## Tareas

- [x] **El letrero dice qué cambia y a quién.** Al salir la carta, un
      anuncio grande en el centro durante 2 s: el nombre y, debajo, el
      efecto (`NpcDialogs.event_effect`). Ejemplos:
  - «IRA GUERRERA / +15% de daño»;
  - «DIOS SRAM / +10% de daño de cualquier elemento, +60% de esquiva
    (Srams)…».

  Las cartas de dios (1–11, 27) añaden «nadie en este combate es Sram»
  cuando ninguno de los luchadores es de esa clase (`GOD_BREED`).
  ~~Brillo sobre los luchadores afectados~~: fuera, porque el texto ya dice
  la clase.
- [x] **La tira, legible sin ratón:** la carta de esta ronda lleva «nombre
      · efecto» bajo el turno; las anteriores, solo el nombre. La
      descripción entera sigue en el tooltip.
- [ ] Repasar el resto del HUD de S17 con el mismo criterio → pasa a S22
      (paneles y HUD).

## Resultado

| Qué | Evidencia |
|---|---|
| El efecto en una línea: sin "Efecto(s):", sin la línea "Duración" (ni la errata "Duación" de los datos) y sin "(1 turno)" | `test/unit/event_effect_test.gd` (+15% de daño, +1 PA, Dios Sram conserva "(Srams)") |
| Anuncio central y carta de la ronda con su efecto, en un combate real (desafío 14, ya ganado: práctica) | `test/event_smoke.gd`: "Bajón · Estabiliza al objetivo (será imposible empujarlo o atraerlo), está enraizado, vuelve enraizado" (536 px) y el anuncio. Capturas en `~/codigo/capturas/s24/` |
| La línea de pista de arriba sigue siendo contextual ("Haz clic en una celda…"); el efecto vive en la tira | captura `event-strip.png` |

Regresión: headless (17 suites) y `run_tests.sh --visual` en verde.

## Criterio de cierre

El dueño juega un combate en la Ally y entiende cada letrero sin preguntar.
