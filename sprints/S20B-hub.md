# S20B — Modernizar el hub (el lobby)

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** L · **Estado:** ⚪ esbozo · **Depende de:** S20 · **Lo usa:** S21 (qué va en cada puerta), S22 (paneles)

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

## Tareas candidatas

- [ ] Inventario del hub actual: cada elemento, qué hace y cuántas veces se
      usa en una partida tipo.
- [ ] Dos o tres wireframes nuevos (bloques grises, sin arte), en una hoja
      para el dueño. Referencias: hubs de juegos de cartas y autobattlers
      actuales.
- [ ] El elegido, en piedra y oro, sustituyendo `lobby_screen.gd`. Los
      nueve menús se reparten: lo diario a la vista y el resto en un menú.
- [ ] Navegación con mando y teclado en todo el hub.
- [ ] Smoke `native_lobby.gd` actualizado al nuevo diseño.

## Decisiones pendientes del dueño

| Decisión | Por defecto |
|---|---|
| ¿Los fantasmas van dentro del Ranking (como relleno cuando no hay rival) o con su propia entrada? | **dentro del Ranking** (dueño, 2026-10-24: "de acuerdo") |
| ¿Una escalera o dos (Élite y fantasmas)? | **dos, como hoy, hasta tener datos** (dueño, 2026-10-24) |

## Criterio de cierre

El dueño elige un wireframe; el hub nuevo está en el cliente con su smoke, y
el dueño lo aprueba en la Ally.
