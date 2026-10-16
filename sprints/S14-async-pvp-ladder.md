# S14 — Async PvP, fase 5: relleno, ladder y recompensas

**Planificado:** 2026-10-16 · **Hito:** M4 — Async PvP · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

La fase 5 de [`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md): que el modo funcione
aunque haya pocos jugadores conectados, que es justo el caso de un revival.

## Decisiones previas (dueño)

- ¿Qué se gana al vencer a un ghost? Por defecto, nada en cartas: solo ladder.
- ¿El Elo de un ghost decae con el tiempo?

## Tareas candidatas

- [ ] Ghosts de relleno en `data-dist/`.
- [ ] Ladder offline.
- [ ] Política de recompensas, según la decisión de arriba.

## Criterio de cierre

Con un solo jugador conectado, el modo tiene rivales, ladder y recompensas
coherentes con la decisión tomada.
