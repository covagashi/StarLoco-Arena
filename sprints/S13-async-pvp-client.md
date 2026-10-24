# S13 — Async PvP, fase 4: el cliente

**Planificado:** 2026-10-16 · **Detallado, abierto y cerrado:** 2026-10-23 · **Hito:** M4 — Async PvP · **Tamaño:** L · **Estado:** 🟢 cerrado (visto bueno del dueño, 2026-10-24)

## Objetivo

La fase 4 de [`godot/ASYNC-PVP.md`](../godot/ASYNC-PVP.md): que un jugador gestione
sus ghosts y combata contra los de otros desde el cliente Godot. No hay nada
empezado en el cliente.

## Decisiones (delegadas: "continúa", 2026-10-23)

| Decisión | Tomada | Por qué |
|---|---|---|
| ¿Quién usa los ghosts? | **todos los coaches** (S12 los dejaba solo a admin) | el criterio pide que lo cree un jugador y lo rete otro; `/AUTOPILOT` sigue siendo de admin |
| Reglas por posición o por luchador | **por id de luchador** en 60010; el servidor las pasa a la posición de su foto y tira las de un luchador que no entre | el cliente no puede saber con certeza a quién elige `titularRoster`; aun así copia su regla (titulares, dos por raza, seis) para enseñar los mismos |
| Dónde se entra | **Menú → Fantasmas**, como Replays; no hay séptimo botón en el lobby | la portada del lobby espera el visto bueno del dueño (S18); un botón ahí cambia su rejilla |
| Pestañas | Retar (los de otros), Mis fantasmas (borrar), Crear (nombre + reglas por titular) | |
| Borrar | opcode nuevo **60015** (solo los propios) | con el tope de tres, sin borrar no se puede guardar otro |
| Editor | una fila por regla: "Si [condición] [valor] → [acción] [hechizo] [objetivo]", ▲▼✕, "+ Regla" (hasta 8 de las 32 del motor) | el vocabulario v1 cerrado cabe en desplegables; el móvil no es objetivo de este cliente |
| "lanzar" sin hechizos | no se ofrece | el servidor rechaza una regla de lanzar sin hechizo |
| Pestaña de ladder de ghosts | **a S14** | el Elo de ghost aún no se mueve (es S14) |

## A. Servidor (sobre S12)

- [x] 60010 con id de luchador; abierto a todos; 60015 borrar.
- [x] Pruebas: `TestGhostDeleteOnlyOwn`; la e2e usa ids de luchador.

## B. Cliente

- [x] `src/ui/gambit_editor.gd`: el editor de una lista de reglas.
- [x] Panel `ghostDialog` en `lobby_panels.gd` y entrada en el Menú.
- [x] `main.gd`: 60010/60012/60014/60015 al servidor, 60013 → modelo
      `ghosts.list`, 60011 → `ghosts.status`.
- [x] Textos es/en/fr.

## Criterio de cierre

Un jugador crea un ghost con reglas desde el cliente, otro lo reta y gana o
pierde. Capturas y prueba del flujo.

## Resultado

- `test/ghost_smoke.gd`, en dos pasadas por el `main.tscn` real:
  - **Como `test`, 5/5.** Menú → Fantasmas → Crear. Las dos reglas se
    construyen con los controles del editor: "si la vida de un rival < 50 % →
    lanzar Presión al rival más débil" y "si siempre → acercarse". El JSON
    sale idéntico al que valida el servidor. Al guardar: "Fantasma guardado"
    y aparece en "Mis fantasmas". En la base, las reglas quedan en el
    luchador con hechizos (índice 0 de la foto).
  - **Como `test2`, 5/5.** Retar lo lista → Combatir → combate. El ghost
    lanza 8 hechizos y gana en 9 rondas; salen la pantalla de resultado y la
    fila en `ghost_fights` con su semilla.
- Capturas en `~/codigo/capturas/s13/`: `ghost-editor`, `ghost-mine`,
  `ghost-challenge`, `ghost-fight` y `ghost-result`.
- `native_panels.gd` (133 PASS, `ghostDialog` incluido), `replay_lobby_smoke`,
  `run_tests.sh --headless` y `go test ./...` en verde.
- **Encontrado:**
  - El editor rehacía sus filas mientras las viejas seguían en el árbol, así
    que Godot renombraba las nuevas. Ahora se sacan del árbol antes.
  - Los titulares de `test` son "Humo" sin hechizos (restos de smokes). El
    smoke siembra en el luchador 2 los hechizos del 1; está en su cabecera.
