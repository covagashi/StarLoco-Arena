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
4. **Identidad visual propia.** Pantallas nativas propias en piedra y oro, y
   combates con el arte retail (el 1 bit se abandonó el 2026-10-24).
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
| **M2 — Identidad visual** | HUD propio y pantallas propias (el 1 bit, abandonado) | S04, S17, S18, S07 |
| **M3 — Paridad de contenido** | servidor sin deuda conocida, torneos completos, tutorial, replays | S08, S19, S09, S10, S11 |
| **M4 — Async PvP** | ghosts: crear, combatir y ladder | S12, S13, S14 |
| **M6 — Un juego de hoy** | un game-loop actual: lo roto arreglado, una puerta por modo, paneles con respuesta, NPCs con cara y un combate que se explica. Va **antes** de M5 (dueño, 2026-10-24: "no está preparado para los últimos sprints") | S20, S20B, S21, S22, S23, S24, S26, S28, S25, S29, S27 |
| **M7 — Arte propio** | nada del retail: arte, efectos y sonido propios con un pipeline nuevo y muchas menos animaciones (dueño, 2026-10-25). Va antes de S16, que esperaba justo a cambiar los assets | S32–S41 (arte, luego cartas, luego textos) |
| **M5 — Release 1.0** | cliente empaquetado para 3 plataformas e instancia pública | S15, S16, S30 |


Si se quiere gente probando antes de la 1.0, el sitio natural para una **beta
cerrada** es tras M1 + M2, adelantando la parte mínima de S15 (un export para
Linux y Windows).

## Índice

| Sprint | Hito | Tamaño | Estado | Tema |
|---|---|---|---|---|
| [S01](./S01-client-test-net.md) | — | — | 🟢 cerrado | Red de pruebas del cliente + raíz de assets (B-173, B-174, B-175) |
| [S02](./S02-studio-tooling.md) | — | — | 🟢 cerrado | Tooling del stack en el studio: pnpm, oxlint, oxfmt, knip, lane de CI |
| [S03](./S03-base-linux.md) | M1 | S | 🟡 a la espera del dueño (CI) | Base en Linux headless: Godot, render con xvfb, tests portables, CI viva |
| [S04](./S04-fight-maps-1bit.md) | M2 | M | ⛔ abandonado (dueño, 2026-10-24) | Mapas de pelea en 1 bit: quitado; se queda el color retail por elemento |
| [S17](./S17-fight-hud.md) | M2 | M | 🟢 cerrado | HUD de combate estilo Krosmaster: la info del luchador en su carta, no sobre el mapa |
| [S05](./S05-lobby-services.md) | M1 | M | 🟢 cerrado | Lo que se perdió con el hall: Card Master, Zaap, correo, cementerio, fusión, NPCs |
| [S18](./S18-screens-redesign.md) | M2 | L | 🟢 cerrado | Todas las pantallas nuevas: login, creación, lobby, paneles y servicios (fuera de los diálogos retail) |
| [S06](./S06-options-audio.md) | M1 | S | 🟢 cerrado | Opciones que no hacen nada, música y volúmenes |
| [S07](./S07-gui-fidelity.md) | M2 | M | 🟢 cerrado | Lo que el retail tenía y aquí falta: nivel del coach, ficha del luchador, versus, colores |
| [S08](./S08-server-debt.md) | M3 | L | 🟢 cerrado | Deuda de servidor: bugs abiertos, docs que se contradicen, pruebas en los tres dialectos |
| [S19](./S19-retail-data.md) | M3 | M | 🟢 cerrado | Datos retail sin leer, texto de las cartas de evento y opcodes pequeños (la otra mitad de S08) |
| [S09](./S09-tournaments.md) | M3 | L | 🟢 cerrado | Torneos completos: arrastre, periodos, torneos de jugador, Leyendas |
| [S10](./S10-tutorial-onboarding.md) | M3 | M | 🟢 cerrado | Tutorial Kanojedo y onboarding del jugador nuevo |
| [S11](./S11-replays-spectator.md) | M3 | M | 🟢 cerrado | Replays (grabar y reproducir), espectador desde la UI, reels |
| [S12](./S12-async-pvp-server.md) | M4 | M | 🟢 cerrado | Async PvP fase 3: `ghost_teams` y opcodes |
| [S13](./S13-async-pvp-client.md) | M4 | L | 🟢 cerrado | Async PvP fase 4: panel de ghosts y editor de reglas |
| [S14](./S14-async-pvp-ladder.md) | M4 | M | 🟢 cerrado (recompensas y decaimiento, a decidir) | Async PvP fase 5: ghosts de relleno, ladder, recompensas, determinismo |
| [S20](./S20-lo-que-no-funciona.md) | M6 | M | 🟢 cerrado | Lo que no funciona: guardar sin señal, girar el PJ, equipo del coach, cancelar búsqueda; fuera Leyendas y 2vs2 |
| [S20B](./S20B-hub.md) | M6 | L | 🟢 cerrado | Modernizar el hub: el wireframe del lobby de 2026-10-05 (Devin), rehecho alrededor de Historia, Ranking (con fantasmas) y Torneos |
| [S21](./S21-game-loop.md) | M6 | L | 🟢 cerrado | Un game-loop de hoy: qué es cada modo, buscar rival con cronómetro, un solo fin de combate, ayuda útil y **monetización solo cosmética, sin p2w** |
| [S22](./S22-paneles-modernos.md) | M6 | L | 🟢 cerrado | Los paneles originales con un toque moderno: equipo del luchador, inventario, logros con iconos, servicios |
| [S23](./S23-npcs-con-cara.md) | M6 | M | 🟢 cerrado | Los NPC con retrato, Aldebrán presentado y los textos revisados (anexo con todos) |
| [S24](./S24-combate-legible.md) | M6 | S | 🟢 cerrado | Un combate que se entiende: el letrero de la carta de evento dice qué hace |
| [S15](./S15-client-packaging.md) | M5 | L | 🟢 cerrado | Empaquetado del cliente: 3 plataformas, generador de assets, peso |
| [S26](./S26-retos-demonios-fichas.md) | M6 | M | 🟢 cerrado (torneos sin conexión y economía de cartas, aprobados → por planificar) | Fichas en torneos y retos, todos los retos en Historia, los Señores del Tiempo (nombres mayas), Demonio I narrador |
| [S28](./S28-economia-cartas.md) | M6 | S | 🟢 cerrado | Economía de cartas: los sets de Card Master cuestan fichas (valor/100, mínimo 10); las pesetas, solo cosméticos |
| [S25](./S25-temporadas.md) | M6 | M | 🟢 cerrado | Temporadas: reinicio suave del Elo y pesetas para el top, para comprar cosméticos |
| [S29](./S29-torneos-sin-conexion.md) | M6 | L | 🟢 cerrado | Torneos sin conexión: el servidor juega el cuadro IA contra IA con el último fantasma de cada uno y graba cada combate |
| [S27](./S27-supermensajes.md) | M6 | M | ⛔ descartado (dueño, 2026-10-25) | Supermensajes, como en Mobile Legends, en lugar de los fuegos artificiales |
| [S32](./S32-fuera-el-retail.md) | M7 | M | 🟢 cerrado | Fuera la extracción del retail: `tools/` borrado, docs reescritos; los `dump*` se quedan hasta S40 (leen `data-dist`) |
| [S33](./S33-plan-de-arte.md) | M7 | M | 🟡 esperando al dueño | Plan de arte: estilo, técnica (3D/cutout, VFX en tiempo real, animación procedural) y prototipo vertical |
| [S34](./S34-pipeline-de-assets.md) | M7 | M | ⚪ esbozo | Pipeline nuevo: de la fuente al juego en un comando, licencias, comprobaciones |
| [S35](./S35-personajes.md) | M7 | L | ⚪ esbozo | Personajes: 24 luchadores, 9 invocaciones, 2 coaches; ~10 animaciones por esqueleto |
| [S36](./S36-arenas.md) | M7 | L | ⚪ esbozo | Arenas con un kit modular por bioma sobre la topología de combate |
| [S37](./S37-vfx.md) | M7 | M | ⚪ esbozo | Librería de VFX por elemento y forma; cada hechizo, por datos |
| [S38](./S38-cartas-e-iconos.md) | M7 | L | ⚪ esbozo | Cartas (plantilla + ilustración por familia), iconos, retratos, fuentes |
| [S39](./S39-sonido-y-musica.md) | M7 | M | ⚪ esbozo | Sonido y música propios |
| [S40](./S40-cartas-propias.md) | M7 | L | ⚪ esbozo (tras el arte) | Cartas propias: diseño y datos fuera del retail |
| [S41](./S41-textos-propios.md) | M7 | M | ⚪ esbozo (tras las cartas) | Textos propios en es/en/fr |
| [S16](./S16-release-1.0.md) | M5 | M | ⏸ en pausa (dueño, 2026-10-25: hasta cambiar los assets) | Release pública 1.0: pipeline, instancia segura, docs, legal |
| [S31](./S31-assets-sin-usar.md) | M5 | M | 🟢 cerrado | Fuera los assets sin usar: 435 de 823 MB; quedan 47 mapas, 38 muñecos y 2.395 animaciones; etapa `prune` en el generador |
| [S30](./S30-tienda.md) | M5 | L | ⚪ esbozo (después de S16) | Tienda: cosméticos con pesetas y compras con dinero real, sin pagar para ganar |

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
| ¿El 1 bit es el estilo **por defecto** o un modo opcional? | S04, S07 | **ninguno: abandonado** (dueño, 2026-10-24); combates en retail, pantallas en piedra y oro |
| Servicios del hall (Card Master, Zaap…): ¿entradas en el lobby o revivir el hall caminable? | S05 | entradas en el lobby |
| Replays: ¿grabar/reproducir como el retail, o solo espectador en vivo? | S11 | grabar y reproducir (tomada en S11 por heurística, 2026-10-23: el dueño pidió reels) |
| X-vs-X (ítem 33 heredado): ¿cerrarlo como muerto en esta build? | S08 | cerrarlo (aplicado en S08; se reabre si el dueño dice) |
| Async PvP: recompensa por ganar a un ghost, decaimiento del Elo | S14 | sin recompensa en cartas, sin decaimiento (aplicado en S14) |
| Modos: Evolución = historia, Élite = ranking, Torneos igual; 2vs2 escondido, Leyendas fuera | S20, S20B, S21 | **tomada** (dueño, 2026-10-24) |
| ¿Fantasmas dentro del Ranking (relleno cuando no hay rival) o con entrada propia? | S20B | **tomada**: dentro del Ranking, dos escaleras (dueño, 2026-10-24); hecho en S20B |
| ¿Historia = campaña PvE de desafíos y demonios (y se esconde la cola PvP de Evolución)? | S21 | **tomada**: sí (dueño, 2026-10-24); hecho en S21 |
| Ranking: ¿Elo (ganar a uno más fuerte vale más) en vez de ±25 fijo? | S21/S22 | ±25 hasta que el dueño diga (cambia la escala de la clasificación) |
| Monetización: solo cosméticos; ¿qué se hace con lo que hoy da ventaja? | S21 | **hecho el mapa** (S21 bloque D): Élite ya no toca a los luchadores, consumibles solo en Historia, sin drops en práctica; tienda futura solo con cosméticos (tipos 1, 25, 28 y arte propio) |
| ¿Qué botones eran "mover el pj"? | S20 | se arreglan los tres candidatos |
| ¿Qué añade el game-loop moderno que el retail no tiene (misiones diarias, primera victoria, temporadas)? | S21 | se apunta; sprint aparte si el dueño lo quiere |
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
