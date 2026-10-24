# S24 — Un combate que se entiende

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** S · **Estado:** ⚪ esbozo · **Depende de:** —

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

## Tareas candidatas

- [ ] El letrero dice **qué cambia y a quién**: «Ira guerrera — +15 % de daño
      para todos, esta ronda». Las de dios marcan con un brillo a los
      luchadores afectados, o avisan si no afectan a nadie del combate.
- [ ] La tira de las próximas cartas, legible sin pasar el ratón (también con
      mando).
- [ ] Repasar el resto del HUD de S17 con el mismo criterio: todo lo que sale
      en pantalla dice qué significa.

## Criterio de cierre

El dueño juega un combate en la Ally y entiende cada letrero sin preguntar.
