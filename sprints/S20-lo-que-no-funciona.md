# S20 — Lo que no funciona

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** M · **Estado:** 🟡 siguiente · **Depende de:** —

> El número es el de creación; el orden lo da la tabla de
> [`README.md`](./README.md).

## Origen

El 2026-10-24 el dueño probó el cliente en la Ally y dejó una lista larga
(texto completo en [S21](./S21-game-loop.md#origen)). Su conclusión: "faltan
muchas cosas y creo que está muy sobrecargado (…) esto es algo del 2015 o más
antiguo, hoy en día los game-loop son diferentes (…) no está preparado para los
últimos sprints". De esa lista salen S20–S24, y van **antes** de S15 y S16.

Este sprint recoge lo que el dueño vio **roto**. Los otros cuatro tratan el
diseño. Va primero porque no tiene sentido rediseñar un panel que no guarda.

## Hallazgos (2026-10-24, leyendo el código, sin reproducir todavía)

| # | Lo que dijo el dueño | Lo que hay en el código |
|---|---|---|
| 1 | "le doy a guardar cambios y no hay ninguna seña de nada" (Equipo del luchador) | **Sí guarda**: `lobby_panels.gd:1081` → `_on_eq_save` (`main.gd:3138`) → 6011 → `handlers_fighter.go:241` (`SaveLoadout`) → 6010. La única confirmación es una línea verde en el canal *system* del chat (`main.gd:849-865`). **Bug:** al recibir 6010 solo se actualiza `f.spells`, no las cartas (`main.gd:853-861`); al reabrir el editor salen las cartas viejas y parece que no se guardó |
| 2 | "los botones de mover el pj no funcionan" | No existen botones de mover. Lo más probable son los **« »** del lobby (`lobby_screen.gd:124-132`): solo giran el dibujo, nadie escucha `coach_rotated` y `_local_coach_model()` fija `actorDirection: 3` (`main.gd:4771`), así que cualquier refresco borra el giro. Otros candidatos: ◀ ▶ de "Nuevo luchador" (`lobby_panels.gd:988`, no hacen nada si `actorDescriptorLibrary` está vacío) y "Girar" en combate (`fight_view.gd:2938`, solo en colocación o en tu turno) |
| 3 | "el equipo del coach no funciona" | `coach_equip_panel.gd:57`: al elegir una carta solo se hace `draft["put"] = id`, **sin `schedule_refresh()`**. "Poner" nació desactivado (`:62`) y no se reconstruye, así que no se puede equipar nada. Quitar, Deshacer y "Llevar puesto" funcionan, pero sin confirmación |
| 4 | "el botón de cancelar es muy pequeño y no es visible; los juegos actuales tienen una cuenta atrás" | `lobby_screen.gd:117-123`: botón de 144×38 con fuente de 16, montado sobre la línea del subtítulo. Ni cronómetro ni tiempo estimado |
| 5 | (encontrado al investigar) | **Leyendas no puede llenarse**: "Convertir en leyenda" envía 23000 con el flag 1 (`main.gd:2844`), el servidor lo ignora (`handlers_evolution.go:72`) y `nextFighterState` manda al titular al banquillo (`:108`). Ningún código pone el estado 4 |
| 6 | (encontrado al investigar) | Los combates de **Evolución mueven la fuerza de clasificación** igual que Élite (`handlers_fight_combat.go:857`), y la Ayuda dice lo contrario (`ui_es.json:1109`). Hay que decidir cuál de los dos manda |
| 7 | (encontrado al investigar) | La **clasificación 2v2** (27505) siempre sale vacía (`handlers_ladder.go:212`) |
| 8 | (encontrado al investigar) | En el árbol de Nilo, "Gracias. Quizás vuelva más tarde." lleva al grupo 69, que está en francés. Hay 9 grupos en francés dentro de la tabla española (76, 69, 83, 74, 77–80, 75). Fallo de los datos retail |

## Tareas

- [ ] **1. Guardar con señal.** Al guardar, el panel lo dice ("Guardado" en el
      botón, o un aviso que se va solo) y el botón queda desactivado hasta el
      siguiente cambio. El 6010 actualiza también las cartas en
      `State.roster`. Smoke: guardar, cerrar, reabrir y ver lo guardado.
- [ ] **2. Mover/girar el PJ.** Preguntar al dueño qué botón era. Por
      defecto, arreglar los tres: el giro del lobby persiste (no lo pisa
      `_local_coach_model`), ◀ ▶ funcionan sin `actorDescriptorLibrary`, y
      "Girar" en combate explica cuándo está desactivado.
- [ ] **3. Equipo del coach.** Elegir carta → "Poner" se activa → se equipa.
      Confirmación también en "Llevar puesto". Smoke con la base de pruebas.
- [ ] **4. Buscar rival como hoy.** Mientras busca: un cronómetro grande
      (0:12…), el modo que se busca, y "Cancelar" a tamaño de botón
      principal. Esc también cancela. El diseño fino va en S21.
- [ ] **5. Leyendas.** El 23000 con flag 1 convierte al luchador en
      leyenda (estado 4), con las condiciones del retail (rango). Test Go.
- [ ] **6. Evolución y clasificación.** Decisión (abajo); según cuál, se
      corrige el servidor o la Ayuda.
- [ ] **7. Clasificación 2v2** con datos, o fuera de la interfaz si no tiene
      sentido sin gente.
- [ ] **8. Textos retail en francés** de Nilo: traducidos al español (y al
      inglés si faltan), y el "Gracias" cierra la conversación.

## Decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-24 | S20–S24 van antes de S15 y S16: "no está preparado para los últimos sprints" | dueño |
| — | ¿Evolución cuenta para la clasificación? Por defecto **no** (lo que dice la Ayuda y lo que espera quien llega) | pendiente |
| — | ¿Qué botones eran "mover el pj"? Por defecto, se arreglan los tres candidatos | pendiente |

## Criterio de cierre

Cada fila de la tabla tiene su arreglo con un test (Go o smoke de Godot) o una
decisión escrita, y el dueño prueba 1–4 en la Ally.
