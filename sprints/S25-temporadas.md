# S25 — Temporadas

**Planificado:** 2026-10-25 · **Hito:** M6 — Un juego de hoy · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

Dar un ciclo al ladder: temporadas con principio y fin, un premio para el top y
un reinicio suave al empezar la siguiente. Cierra las dos decisiones que S14
dejó abiertas (dueño, 2026-10-25).

## Decisiones del dueño

- Al cerrar una temporada, el top gana **pesetas**. Son una moneda solo para
  comprar **cosméticos**, nada que dé ventaja (la regla de S21).
- El Elo no decae con el tiempo: hay un **reinicio suave** al empezar cada
  temporada.

## Por decidir (dueño)

- ¿Duración de la temporada? (por defecto: un mes)
- ¿Qué ladders cuentan: el de ghosts, el 1 contra 1 (Strength) o los dos?
- ¿Cuántos puestos cobran y cuánto? (por defecto: una escala por tramos,
  1.º / 2.º–3.º / 4.º–10.º / 11.º–50.º)
- ¿Las pesetas se ganan solo con la temporada, o también con algo diario?
- ¿Pesetas y tokens del Card Master son monedas distintas? (por defecto: sí;
  los tokens compran cartas y las pesetas, solo cosméticos)

## Tareas candidatas

- Servidor: tabla de temporadas (id, inicio, fin), cierre automático,
  foto del top al cerrar, pago en pesetas y reinicio suave
  (`elo = media + (elo − media) × f`, por defecto con media 1000 y f = 0,5).
- Monedero de pesetas aparte del de tokens.
- Tienda de cosméticos con pesetas (el catálogo de S21: auras, anillos,
  cartas de color como premio de temporada).
- Cliente: temporada y días restantes en Ranking, el historial de
  temporadas y un aviso del premio al entrar.

## Criterio de cierre

Una temporada forzada a terminar paga al top, aplica el reinicio y abre la
siguiente; un jugador gasta las pesetas en un cosmético. Probado con
datos sembrados.
