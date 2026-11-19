# S48 — Deuda técnica

**Planificado:** 2026-11-19 · **Hito:** — · **Tamaño:** M · **Estado:** ✅ cerrado (2026-11-19)

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

## 2. `totems_smoke` ✅

Antes, 3 de 7 (Servicios, búsqueda, Social y fuegos fallaban; S47 lo vio
4/4 en sus partes). Ahora **7 de 7**
(`SMOKES=totems_smoke godot/tools/no_retail_smoke.sh <copia sembrada>`,
bajo `unshare -rn`):

- **Fuera** Servicios sin tótems y los fuegos artificiales: el lanzador
  solo se abre ya desde un elemento del mundo, y el juego no tiene mundos.
- Los botones del lobby se buscan por su `tooltip_text` (son iconos desde
  S45), no por su texto: Social abre otra vez.
- Inscribirse y buscar rival, en torneos distintos: la inscripción se
  cierra en cuanto se abre la ventana de búsqueda, así que el smoke se
  inscribe en el primer torneo del calendario abierto para él (no sin
  conexión, sin carta de entrada que falte) y busca rival desde **Mis
  torneos**. Si el calendario no tiene ninguno, el fallo lista los que hay.

## 3. B-189: el árbol tapa al luchador ✅

El ocultador de la arena borraba cada píxel de algo en 2D que la arena
tuviera delante. Ahora un luchador (y su sombra) **no se borra**: donde la
arena lo tapa se dibuja su silueta translúcida en azul claro (frío, para que
se lea en las arenas cálidas; probé antes un crema y se perdía en el
follaje). Las marcas del suelo siguen ocultándose. Vista previa de B-189
antes y después: de Arel solo se veían los pies; ahora se ven su silueta y
la cabeza de otra luchadora a través de las hojas, y el brazo de un panda
a través de una caja. Detalle en `server/docs/BUGS.md` (B-189).

## 4. Funciones del studio sin uso ✅ (obsoleto)

Ya no existen: S43 (`72fb6d0d`) las borró al quitar los lectores del
cliente antiguo. Solo quedaba la línea del BACKLOG.

## Cierre (2026-11-19)

Los cuatro puntos cerrados. Pruebas: `go test ./...`,
`godot/run_tests.sh --headless` (24 suites, 1544), `fight_smoke` y
`totems_smoke` (7/7) bajo `unshare -rn`.

Siguen en el BACKLOG, esperando al dueño: la CI con los pushes (habilitar
*Actions* en el fork), JS en el portal web, MySQL/Postgres o solo SQLite,
la ropa de los coach, los iconos de vetado y las opiniones pendientes de S47.
