# S20B — Modernizar el hub (el lobby)

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** L · **Estado:** 🟢 cerrado (2026-10-24) · **Depende de:** S20 · **Lo usa:** S21 (qué va en cada puerta), S22 (paneles)

> "S20B" porque va justo detrás de S20 y antes de S21; el dueño lo pidió con
> ese nombre.

## Origen

El dueño, 2026-10-24: "hay que hacer un sprint, el S20B, que sea el de
modernizar el hub, ya que si no recuerdo mal el wireframe lo hizo Devin".

## De dónde viene el lobby de hoy

- El 2026-10-05 se dejó el hall caminable por un flujo de lobby. Esos commits
  van co-firmados por Devin: `1280ada2` ("deprecate the walkable overworld
  hall (lobby-first flow)") y `ae138619` ("strip hall hooks from live code").
- El mismo día, `4a837ac5` creó `godot/src/ui/lobby_screen.gd`. Su cabecera
  es un brief de diseño ("THESIS… STORY: inspect your coach, prepare a team,
  then choose a fight mode. FIRST VIEWPORT: coach left; six actions center;
  chat and retail menus below"). Ese es el wireframe que sigue vigente.
- S18 cambió el **estilo** (1 bit y, después, piedra y oro), no la
  **estructura**. La disposición sigue siendo la de entonces, fijada en
  1280×720:
  - el coach a la izquierda (`COACH_RECT`, con los « » de girar);
  - **seis acciones** en el centro (entrenamiento, combate, aleatorio,
    evolución, dúo, equipo), cuatro de ellas duplicadas (ver S21);
  - el chat abajo a la izquierda (`CHAT_RECT`);
  - **nueve menús** abajo a la derecha (`MENU_RECT`: equipo, estadísticas,
    inventario, clasificación, calendario, logros, social, ayuda, servicios).

## Objetivo

Un hub como el de un juego actual: **un botón Jugar** que domina la pantalla,
los modos que quedan (Historia, Ranking, Torneos) como tarjetas, tu equipo a
la vista, y lo demás recogido donde no estorbe. Pensado para 16:9 y para la
Ally (mando, pantalla de 7").

## Modos que el hub tiene que enseñar (decisión del dueño, 2026-10-24)

| Modo | Qué es | Hoy |
|---|---|---|
| **Historia** | Evolución: tus luchadores crecen, se hieren y mueren | 23003 |
| **Ranking** | Élite: todos al mismo nivel, sube o baja tu fuerza. Los **fantasmas** (async PvP, S12–S14) van aquí; ver abajo | 23103 + 60010… |
| **Torneos** | Calendario, inscripción y periodos | 28611 |
| ~~2vs2~~ | escondido por baja población | — |
| ~~Leyendas~~ | quitado | — |

**Fantasmas en el Ranking** (opinión del agente, a confirmar): con poca gente,
el ranking en vivo deja colas vacías. Propuesta: una sola puerta "Ranking".
Busca rival en vivo durante unos segundos, con cronómetro, y si no hay nadie
ofrece pelear contra un fantasma de un rival de tu nivel. También se puede
elegir el fantasma directamente. Hoy son dos escaleras separadas (la fuerza
de Élite y `ghost_ratings`, por decisión de S14); unirlas o no se decide aquí.

## Tareas

- [x] Inventario del hub actual: arriba, en "De dónde viene el lobby de hoy",
      y la tabla de redundancias de S21.
- [x] ~~Dos o tres wireframes para el dueño~~ → **un diseño, decidido por
      heurística** (Decisiones). El dueño: "simplemente sigue con los
      sprints".
- [x] El hub nuevo en piedra y oro, sustituyendo `lobby_screen.gd`.
- [x] Navegación con mando y teclado.
- [x] Smokes al día: `hub_smoke.gd` nuevo; `native_lobby`, `modes_smoke` y
      `screens_smoke` adaptados.

## Decisiones pendientes del dueño

| Decisión | Por defecto |
|---|---|
| ¿Los fantasmas van dentro del Ranking (como relleno cuando no hay rival) o con su propia entrada? | **dentro del Ranking** (dueño, 2026-10-24: "de acuerdo") |
| ¿Una escalera o dos (Élite y fantasmas)? | **dos, como hoy, hasta tener datos** (dueño, 2026-10-24) |

## Decisiones

| Fecha | Decisión | Quién |
|---|---|---|
| 2026-10-24 | **Un diseño, sin hoja de opciones.** El dueño no quiere que se le pare a elegir. Se toma el patrón de los hubs actuales de juegos de cartas y autobattlers: una tarjeta por modo con su "Jugar", el personaje a un lado y los paneles diarios como tiles | delegada |
| 2026-10-24 | **Fuera del hub:** "Aleatorio" (2301, la búsqueda rápida con el preset elegido; repetía Ranking), "Equipo" como acción (sigue como tile) y el título "Elige tu próximo combate". El código de la búsqueda rápida se queda | delegada |
| 2026-10-24 | Barra superior para lo ocasional (Estadísticas, Social, Ayuda); abajo, seis tiles con el icono sobre el texto | delegada |
| 2026-10-24 | **Ranking dice con qué equipo juega** (selector con los equipos de Élite). Antes, el "Combate" del lobby mandaba el último elegido en el panel Equipo sin decirlo. Sin equipos, "Jugar" pasa a "Crear equipo" y abre Equipo en Élite | delegada |
| 2026-10-24 | **Fantasmas en el Ranking**, de dos formas: "Contra un fantasma" siempre a mano, y la tarjeta de búsqueda lo ofrece a los 20 s de un Ranking sin rival (cancela la búsqueda y abre el panel). Hasta ahora los fantasmas solo se alcanzaban desde el menú Esc | delegada (el dueño aceptó "dentro del Ranking") |
| 2026-10-24 | "Jugar" en Historia sigue lanzando la cola de Evolución (23003) hasta que S21 haga la campaña PvE | delegada |
| 2026-10-24 | Frase del Ranking: «Combates en igualdad: tu fuerza sube al ganar y baja al perder.», no «gana el mejor jefe, no la mejor colección», que no será verdad hasta que S21 resuelva el p2w | delegada |
| 2026-10-24 | Los avisos (`_toast`) pasan **arriba, en el centro**: abajo tapaban el texto de las ventanas (se vio en la Ayuda) | delegada |

## Resultado

Capturas en `~/codigo/capturas/s20b/` (`hub.png`, `hub-searching.png`).

| Qué | Evidencia |
|---|---|
| Hub nuevo (`src/ui/lobby_screen.gd`), con el modelo `hub` que empuja `main._push_hub_model()` (titulares, equipos de Élite y el que juega, torneo inscrito con búsqueda abierta) | `test/hub_smoke.gd` 7/7: las tres tarjetas con sus líneas (`1 titulares · 1 en el banquillo`, `Élite de prueba`, `Tournoi 1v1 Classique · búsqueda abierta`); elegir equipo en el Ranking cambia el preset que se envía (119); Jugar → búsqueda con «Ranking» y oferta de fantasma a los 20 s; Cancelar devuelve las tarjetas; "Contra un fantasma" abre el panel; los 9 menús abren su panel; mando: derecha → Torneos, abajo → los tiles |
| **B-187**, encontrado al capturar: Aldebrán salía en cada entrada. El cliente leía los criterios del 2052 al revés (`d[a()] = b()` evalúa primero la derecha en GDScript) | `test/criteria_smoke.gd`; `tutorial_smoke` 10/10 con una cuenta nueva; la misma cuenta, al volver a entrar, ya no ve la intro |
| Regresión | `run_tests.sh --headless` 381/0; `native_panels` 133 PASS; `native_lobby` 28 PASS (el entrenamiento, ahora botón de la tarjeta Historia, entra al combate y vuelve); `modes_smoke` 5/5; `screens_smoke` 11/11; `coach_turn` 4/4; `loadout` 6/6 |

**Base de pruebas:**

- Fuera los 25 equipos "zz…" que dejaban los smokes antiguos: llenaban el
  selector del Ranking. Copia previa en `/tmp/claude-1000/arena.db.bak-s20b`.
- `test` tiene ahora un equipo **"Élite de prueba"** (id 119, luchadores 2–4)
  para el Ranking.
- Se deshizo la esfera que compró `screens_smoke`.
- Se descartan del selector los presets con id 0 (el pseudo-preset del
  roster).

**Para S21:** la Ayuda sigue diciendo que el 2v2 y Élite son
clasificatorios, que las cartas de evento duran "unos turnos" y que
Evolución no cuenta (ahora es verdad). Hay que reescribirla con los tres
modos.

## Criterio de cierre

El dueño elige un wireframe; el hub nuevo está en el cliente con su smoke, y
el dueño lo aprueba en la Ally.

**Cerrado sin elección ni prueba del dueño**, por su indicación del
2026-10-24 ("sigue con los sprints y no abras el juego"): un diseño por
heurística, smokes y capturas de xvfb.
