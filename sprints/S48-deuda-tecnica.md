# S48 — Deuda técnica

**Planificado:** 2026-11-19 · **Hito:** — · **Tamaño:** M · **Estado:** 🔵 en curso

## Decisión del dueño (2026-11-19)

Tras cerrar S46, entre reabrir S16, la deuda técnica, los retos con el kit
entero o revisar S45, eligió **la deuda técnica del BACKLOG** (§8 y §12).

## Alcance (lo que no necesita al dueño)

1. **Criterios 147 y 222** (§12): logros que no se pueden conseguir.
2. **`totems_smoke` desfasado** (§8): reescribirlo contra Torneos y Social.
3. **B-189: un árbol de la arena tapa al luchador** (§12).
4. **Studio: `GetMapGfx` / `GetMapSprites` / `GetMapRender`** sin consumidor
   (§8): conectarlos o borrarlos.

Fuera (esperan al dueño): la CI con los pushes (ajuste de *Actions* en
GitHub), JS en el portal web, MySQL/Postgres, la ropa de los coach, los
iconos de vetado y las opiniones pendientes de S47.

## 1. Criterios 147 y 222 ✅

147 es el puesto en el ranking 2vs2 y 222 el del ranking de evolución, con
la misma escala que el 35 del 1vs1 (2500 − puesto; metas 1 … 2000). **Nadie
los mantiene, y no por un olvido:** el 2vs2 está oculto desde S20 y no hay
ranking de evolución (la evolución es la Historia, sin escalera; el de los
fantasmas es solo de Élite, S22). Inventar uno sería un modo nuevo.

**Decidido por heurística:** ocultar sus 16 logros ("Cumbre de los Ases"
367–374 y "Metamorfosis final" 375–382, `Hidden` en `achievements.json`; el
cliente ya filtra los ocultos y no los anuncia). Prueba
`TestNoVisibleUnreachableAchievement`: ningún logro visible pide un
criterio que nadie mantiene. Si un día vuelve el 2vs2 o hay un ranking de
Historia, se quita el `Hidden`.
