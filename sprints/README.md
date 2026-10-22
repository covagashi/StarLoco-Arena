# Sprints

El roadmap del proyecto: adónde vamos, en qué orden, qué queda por hacer y qué
se hizo en cada tanda.

| Documento | Responde |
|---|---|
| este fichero | **la visión**: qué es "el juego al 100%", los hitos y el orden de los sprints |
| [`BACKLOG.md`](./BACKLOG.md) | la cola de trabajo viva, sin plazos — lo que queda por coger |
| `SNN-slug.md` (índice abajo) | **qué se hace en cada tanda y con qué evidencia** |
| [`server/docs/BUGS.md`](../server/docs/BUGS.md) | el log de bugs `B-NNN`, con causa raíz y verificación |
| [`devlog/`](../devlog/README.md) | el diario del agente: qué hizo en cada sesión y qué encontró |

Los comentarios de código que citan "ROADMAP item N" o "ROADMAP §N" apuntan al
`ROADMAP.md` heredado de la base del fork, retirado el 2026-10-16 para no
confundirlo con este directorio. Sigue legible: `git show v2.70:ROADMAP.md`.

## Visión: qué es "el juego al 100%" (la 1.0)

Fijada el 2026-10-16. La 1.0 está hecha cuando se cumplen las cinco:

1. **Paridad con el retail.** Todo lo que se puede hacer en el cliente Java 2.70
   se puede hacer desde el cliente Godot, o está descartado **por escrito** en
   un sprint (con el porqué).
2. **Servidor sin huecos conocidos.** Los opcodes sin implementar son solo los
   descartados a propósito, y no queda ningún bug abierto que rompa una partida.
3. **Lo propio, terminado.** Async PvP con sus cinco fases.
4. **Identidad visual propia.** El estilo 1 bit decidido y aplicado donde el
   dueño del proyecto diga.
5. **Un jugador nuevo puede jugar.** Instala el cliente en Linux, Windows o
   macOS siguiendo una guía, genera sus assets desde su propio cliente retail y
   se conecta a una instancia pública configurada de forma segura.

## Cómo se planifica

Por sprints, como hasta ahora, con dos añadidos:

- **Hitos.** Los sprints se agrupan en cinco hitos (M1–M5). Un hito es un punto
  en el que el juego está mejor *de forma visible*, aunque no se siga.
- **Planificación por oleadas.** Solo el sprint en curso y el siguiente están
  detallados. Los demás son esbozos: objetivo, alcance y tareas candidatas.
  **Al cerrar cada sprint se revisan los esbozos**: se reordenan, se parten, se
  fusionan o se meten sprints intermedios. Es normal que S08 acabe siendo dos
  sprints, o que algo salga de la 1.0.

Un sprint aquí no es una duración fija (el trabajo va por sesiones, no por
semanas): es **un tema con criterio de cierre**. El tamaño (S/M/L) es orientativo.

## Hitos

| Hito | Qué se nota al llegar | Sprints |
|---|---|---|
| **M1 — Jugable de punta a punta** | desde el cliente Godot se llega a todo lo que el retail ofrece fuera del combate, con sonido y opciones | S03, S05, S06 |
| **M2 — Identidad visual** | combates en 1 bit, HUD propio y pantallas propias | S04, S17, S18, S07 |
| **M3 — Paridad de contenido** | servidor sin deuda conocida, torneos completos, tutorial, replays | S08, S19, S09, S10, S11 |
| **M4 — Async PvP** | ghosts: crear, combatir y ladder | S12, S13, S14 |
| **M5 — Release 1.0** | cliente empaquetado para 3 plataformas e instancia pública | S15, S16 |

S04 (1 bit) va pronto aunque sea de M2: es lo que el dueño quiere trabajar ya,
y su dependencia real es solo S03.

Si se quiere gente probando antes de la 1.0, el sitio natural para una **beta
cerrada** es tras M1 + M2, adelantando la parte mínima de S15 (un export para
Linux y Windows).

## Índice

| Sprint | Hito | Tamaño | Estado | Tema |
|---|---|---|---|---|
| [S01](./S01-client-test-net.md) | — | — | 🟢 cerrado | Red de pruebas del cliente + raíz de assets (B-173, B-174, B-175) |
| [S02](./S02-studio-tooling.md) | — | — | 🟢 cerrado | Tooling del stack en el studio: pnpm, oxlint, oxfmt, knip, lane de CI |
| [S03](./S03-base-linux.md) | M1 | S | 🟡 a la espera del dueño (CI) | Base en Linux headless: Godot, render con xvfb, tests portables, CI viva |
| [S04](./S04-fight-maps-1bit.md) | M2 | M | ⏸ en pausa | Mapas de pelea en 1 bit: dithering Bayer + capas de luz |
| [S17](./S17-fight-hud.md) | M2 | M | 🟢 cerrado | HUD de combate estilo Krosmaster: la info del luchador en su carta, no sobre el mapa |
| [S05](./S05-lobby-services.md) | M1 | M | 🟡 a la espera del dueño (cierre) | Lo que se perdió con el hall: Card Master, Zaap, correo, cementerio, fusión, NPCs |
| [S18](./S18-screens-redesign.md) | M2 | L | 🟢 terminado (falta el visto bueno de las pantallas nuevas) | Todas las pantallas nuevas: login, creación, lobby, paneles y servicios (fuera de los diálogos retail) |
| [S06](./S06-options-audio.md) | M1 | S | 🟢 cerrado | Opciones que no hacen nada, música y volúmenes |
| [S07](./S07-gui-fidelity.md) | M2 | M | 🟢 cerrado | Lo que el retail tenía y aquí falta: nivel del coach, ficha del luchador, versus, colores |
| [S08](./S08-server-debt.md) | M3 | L | 🟢 cerrado | Deuda de servidor: bugs abiertos, docs que se contradicen, pruebas en los tres dialectos |
| [S19](./S19-retail-data.md) | M3 | M | 🟢 cerrado | Datos retail sin leer, texto de las cartas de evento y opcodes pequeños (la otra mitad de S08) |
| [S09](./S09-tournaments.md) | M3 | L | 🟡 abierto | Torneos completos: arrastre, periodos, torneos de jugador, Leyendas |
| [S10](./S10-tutorial-onboarding.md) | M3 | M | ⚪ esbozo | Tutorial Kanojedo y onboarding del jugador nuevo |
| [S11](./S11-replays-spectator.md) | M3 | M | ⚪ esbozo | Replays y modo espectador (alcance por decidir) |
| [S12](./S12-async-pvp-server.md) | M4 | M | ⚪ esbozo | Async PvP fase 3: `ghost_teams` y opcodes |
| [S13](./S13-async-pvp-client.md) | M4 | L | ⚪ esbozo | Async PvP fase 4: panel de ghosts y editor de reglas |
| [S14](./S14-async-pvp-ladder.md) | M4 | M | ⚪ esbozo | Async PvP fase 5: ghosts de relleno, ladder, recompensas, determinismo |
| [S15](./S15-client-packaging.md) | M5 | L | ⚪ esbozo | Empaquetado del cliente: 3 plataformas, generador de assets, peso |
| [S16](./S16-release-1.0.md) | M5 | M | ⚪ esbozo | Release pública 1.0: pipeline, instancia segura, docs, legal |

Estados: ⚪ esbozo / ⚪ detallado (planificado) · 🟡 siguiente o abierto · ⏸ en pausa · 🟢 cerrado.
La tabla va en **orden de ejecución**; el número de un sprint es el de su
creación, así que un sprint insertado más tarde (S17) puede ir antes que otros.
Solo puede haber **un sprint abierto** a la vez; uno que solo espera una acción
del dueño no cuenta (lo marca "a la espera del dueño").

## Decisiones pendientes del dueño

Las que cambian el alcance de algún sprint. Mientras no se tomen, el sprint
afectado trabaja con la opción marcada como *por defecto*.

| Decisión | Afecta a | Por defecto |
|---|---|---|
| ¿El 1 bit es el estilo **por defecto** o un modo opcional? | S04, S07 | opcional, conmutable |
| Servicios del hall (Card Master, Zaap…): ¿entradas en el lobby o revivir el hall caminable? | S05 | entradas en el lobby |
| Replays: ¿grabar/reproducir como el retail, o solo espectador en vivo? | S11 | solo lo que ya hay + guardar replays |
| X-vs-X (ítem 33 heredado): ¿cerrarlo como muerto en esta build? | S08 | cerrarlo (aplicado en S08; se reabre si el dueño dice) |
| Async PvP: recompensa por ganar a un ghost, decaimiento del Elo | S14 | sin recompensa en cartas |
| ¿Cómo consigue el jugador los assets? (generador incluido en la release) | S15 | generador incluido |
| ¿JS en el portal web? | S16 | sin JS |
| ¿Seguir publicando `data-dist/` y `client/decompiled/`? | S16 | sin cambios |

## Convención

- Un fichero por sprint: `SNN-slug.md`, con hito, objetivo, alcance, tareas y
  **criterio de cierre**.
- Los esbozos se detallan cuando su sprint pasa a ser el siguiente.
- Al abrir un sprint, se enlazan los ítems de `BACKLOG.md` que coge; al cerrarlo,
  se marcan allí como hechos con el enlace al sprint.
- Al cerrar, el mismo fichero se completa con la sección *Resultado* — qué se
  hizo, qué no, y los comandos que lo demuestran — y se revisan los esbozos que
  vienen detrás. No se abre un fichero de informe aparte.
- Nada se marca `[x]` sin evidencia reproducible: código de salida de una
  prueba, salida de comando, o entrada `B-NNN` en el log de bugs.

Esa última regla existe por una razón concreta: buena parte del trabajo del
cliente la generó un agente, y los mensajes de commit afirmaban verificaciones
que nadie había vuelto a correr. Resultaron ciertas, pero se comprobaron **a
posteriori**. El criterio ahora es que la evidencia vaya en el sprint.
