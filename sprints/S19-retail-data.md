# S19 — Datos retail sin leer y opcodes pequeños

**Planificado:** 2026-10-21 (al cerrar S08, que se partió en dos) · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** 🟡 siguiente (esbozo; se detalla al abrirlo)

## Objetivo

La otra mitad de la deuda de servidor: lo que el cliente trae en sus datos y
el servidor todavía no lee, y los opcodes pequeños que faltan. A diferencia de
S08 (bugs, docs y pruebas), aquí casi todo es leer el cliente descompilado
antes de escribir código.

## Heredado de S08

- [ ] **Texto de 36 cartas de evento**: el retail lo genera a partir de los
      efectos de cada evento (`tO.getDescription` → `asf_0`); hoy enseñan su
      texto de ambiente (`content.9`). Generar la línea de efectos con los
      datos del evento.

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
