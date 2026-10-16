# S08 — Deuda de servidor

**Planificado:** 2026-10-16 · **Hito:** M3 — Paridad de contenido · **Tamaño:** L (probablemente se parta en dos) · **Estado:** ⚪ esbozo

## Objetivo

Que el servidor no tenga huecos *conocidos*: bugs abiertos cerrados, datos
retail leídos y documentación que no se contradiga.

## Bugs y comportamientos abiertos

- [ ] **Enraizado:** el servidor no deja moverse a un luchador enraizado, pero
      en 2.70 parece que solo bloquea empujar/atraer. Comprobarlo contra el
      cliente descompilado (`BUGS.md`; `handlers_fight_combat.go`).
- [ ] Los iconos de buff no se restauran al reconectar a mitad de combate.
- [ ] B-151: falta el e2e de la compra (5450) de una carta sin precio.
- [ ] B-074: panel de fin de combate con el equipo perdedor vivo, sin verificar
      visualmente.
- [ ] Casillas especiales: confirmar en vivo que una se dispara.
- [ ] B-111: de dónde salen los rosters de 10 objetos.
- [ ] Nombres con acentos: el cliente retail los estropea; las cadenas de
      gamedata se leen como UTF-8 y no como cp1252.

## Datos retail sin leer (`DATA-COVERAGE.md`)

- [ ] Tipo 210 (trampas): política de re-disparo, máscaras y temporizador; los
      disparadores 10002/10003/10006/10008 (la plantilla 1016 nunca se dispara).
- [ ] Tipo 400: logro enlazado, recompensa y tope de XP.
- [ ] Estadísticas: hay 98 contadores referenciados y el servidor mueve "un
      puñado".
- [ ] Bits de máscara de objetivo 55 y 58–61; código 66.

## Opcodes pequeños pendientes

4800 RunScript, 8250 (penalización por duración del turno), 4106
(recolocación en lote), 2307/2309 (variante con apuesta) y apuestas sobre la
victoria, 3212 (sin llamada). El faucet diario de fichas. Los sub-blobs de
estadísticas de evolución y puntos de torneo en 2052/4096.

## Documentación que se contradice

- [ ] Recuentos de opcodes distintos en `COVERAGE.md`, `OPCODE-INVENTORY.md` y
      `STATUS.md` (y 28612/28614: "sin implementar" en uno, "emitido" en otro).
- [ ] Entradas viejas en `BUGS.md` (la capa meta y las heridas, crit/fumble base).
- [ ] "Known gaps" de `OPCODE-INVENTORY.md`: el 2v2 y el 4521 ya están hechos.
- [ ] X-vs-X (ítem 33): `STATUS.md` lo da como pendiente y el ROADMAP retirado
      como cerrado. Lo decide el dueño; por defecto, cerrado.

## Pruebas y bases de datos

- [ ] El arnés e2e pasa gamedata `nil`: la capa de datos no tiene e2e.
- [ ] e2e de ida y vuelta para 6006/6030.
- [ ] Postgres (el de producción) en los tests del store, no solo SQLite.
- [ ] Decisión del dueño: ¿seguir con MySQL? No hay constancia de que se haya
      corrido nunca.

## Criterio de cierre

Cada punto de arriba arreglado con prueba, o descartado por escrito, y un solo
recuento de opcodes que coincida en las tres docs.
