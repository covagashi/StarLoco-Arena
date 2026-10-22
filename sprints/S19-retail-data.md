# S19 — Datos retail sin leer y opcodes pequeños

**Planificado:** 2026-10-21 (al cerrar S08, que se partió en dos) · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** 🟡 abierto (2026-10-22)

## Objetivo

La otra mitad de la deuda de servidor: lo que el cliente trae en sus datos y
el servidor todavía no lee, y los opcodes pequeños que faltan. A diferencia de
S08 (bugs, docs y pruebas), aquí casi todo es leer el cliente descompilado
antes de escribir código.

## Heredado de S08

- [x] **Texto de 36 cartas de evento** (2026-10-22). El retail
      (`tO.getDescription` → `asf_0.a(id, flag, efectos, null, 27)`), para los
      eventos con el byte de descripción (`ama_1.iG`, 36 de 51), escribe cada
      efecto con `content.22.<acción>` y sus parámetros, le pega la duración
      (`cast.durationDescription`, ≥ 63 → `cast.infiniteDuration`), separa los
      críticos y lo envuelve en `cast.effectDescription`; luego añade
      `content.27` (vacío en esos 36, a mano en los otros 15). Como todo es
      estático, lo hace el exportador: `dumpnpcdialogs` saca los efectos de
      cada evento y `npc_dialogs.py` porta `are_0.format` (los bloques
      `{[cond]?sí:no}`, `[#n]`, `[£n]`) y `asf_0.a`. Los iconos en línea
      (elemento, turno) pasan a palabra en cada idioma, porque el tooltip es
      texto plano. De paso: el `\n` de `content.27` llegaba crudo al tooltip
      de los 15 escritos a mano; ahora se resuelven los escapes de
      `.properties`. Pruebas: `tools/asset-import/test_npc_dialogs.py` 16/16
      (con los casos que el propio `are_0.main()` trae); `fight_smoke` en
      vivo: la carta 14 dice "Efecto: Estabiliza al objetivo (…) (1 turno),
      está enraizado (1 turno), vuelve enraizado (1 turno)". Esas dos últimas
      son las traducciones del retail para los efectos 127/128 (en inglés
      "Impossible to carry / to transpose"); se dejan como vienen.

## Datos retail sin leer (`server/docs/DATA-COVERAGE.md`)

- [ ] Tipo 210 (trampas): política de re-disparo, máscaras y temporizador; los
      disparadores 10002/10003/10006/10008 (la plantilla 1016 nunca se dispara).
- [ ] Tipo 400: logro enlazado, recompensa y tope de XP.
- [ ] Estadísticas: hay 98 contadores referenciados y el servidor mueve "un
      puñado".
- [ ] Bits de máscara de objetivo 55 y 58–61; código 66.

## Opcodes pequeños

4800 RunScript, 8250 (penalización por duración del turno), 4106
(recolocación en lote), 2307/2309 (variante con apuesta) y apuestas sobre la
victoria, 3212 (sin llamada). El faucet diario de fichas. Los sub-blobs de
estadísticas de evolución y puntos de torneo en 2052/4096.

## Criterio de cierre

Cada punto leído en el cliente y hecho con prueba, o descartado por escrito
con la clase que lo demuestra; el resumen de `OPCODE-INVENTORY.md` (que un test
recuenta) baja en lo que se haga.
