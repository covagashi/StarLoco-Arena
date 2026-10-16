# S09 — Torneos completos

**Planificado:** 2026-10-16 · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** ⚪ esbozo

## Objetivo

El ítem 32 (la capa de partidas del torneo: cuadros, emparejamientos, premios)
está hecho y verificado en vivo. Falta lo de alrededor para que un torneo viva
solo de principio a fin, y que el cliente Godot lo muestre.

## Servidor

- [ ] 28617/28618: arrastre entre torneos. Bloqueado hasta que los torneos
      terminen de verdad.
- [ ] 28646 "se abre el periodo de búsqueda": necesita planificación por reloj, y
      antes resolver el riesgo de alertas duplicadas del 28630.
- [ ] 17010: torneos creados por jugadores (hoy no existe en el modelo).
- [ ] 2411: récord de ladder por preset (necesita estadísticas por preset).
- [ ] Comprobar si los 25 logros que dependían de torneos ya se pueden conseguir.

## Cliente Godot

- [ ] Búsqueda de Torneos y Leyendas: hoy "not available yet"
      (`lobby_panels.gd`).
- [ ] Calendario: los detalles del torneo y el filtro por evento no hacen nada.
- [ ] Los 8 diálogos `tournament*` del retail: cubrirlos o descartarlos.

## Criterio de cierre

Un torneo programado se abre, se juega y se cierra sin intervención manual, con
premios y arrastre, y el cliente Godot lo muestra entero. Prueba e2e más una
partida en vivo con dos clientes.
