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
- [ ] `pvp_smoke` se para en el intercambio (S03): el coach `test` no tiene cartas
      intercambiables en la lista del cliente, aunque tiene 13 en `coach_cards`.
      ¿Datos locales o regresión?
- [ ] Nombres con acentos: el cliente retail los estropea; las cadenas de
      gamedata se leen como UTF-8 y no como cp1252.
- [ ] **Catálogos de Card Master de 845 cartas** (visto en S05): los
      catálogos 17, 19, 21 y 24 (Totem Arena 101, mundo 80) no son un set
      conocido y `cardMasterStock` cae a "todas las cartas con precio". Son de
      modo 1 ("démone II"): averiguar qué vendían en el retail. En el cliente
      Godot ese catálogo cuesta ~15 s la primera vez (845 ilustraciones).

- [ ] 509 (crear clan) no exige la carta 214 "Pacte", que en el retail es lo
      que abre la creación (visto en S05).

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
- [ ] `OPCODE-INVENTORY.md`: 4523 no es un comando de consola, es
      `Context.skipTutorial()` del escenario 1; 22093 no es "cross-game", es
      usar una carta de título (tipo 28). Visto en S05 leyendo el cliente.
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
- [ ] `godot/test/displace_smoke.gd` se cuelga (timeout a 250 s) también en
      `0a99cc6f`: el intercambio (hechizo 135) depende de la geometría del mapa
      que toque y a veces nunca encuentra aliado. Visto en S17 (2026-10-17).
- [ ] Los smokes que se cortan dejan luchadores `zz*` en la cuenta `test`; a
      100 el servidor rechaza crear (código 20, "pool full"). Limpiarlos al
      empezar, no solo al terminar.

## Criterio de cierre

Cada punto de arriba arreglado con prueba, o descartado por escrito, y un solo
recuento de opcodes que coincida en las tres docs.
