# S21 — Un game-loop de hoy: lobby, modos y fin de combate

**Planificado:** 2026-10-24 · **Hito:** M6 — Un juego de hoy · **Tamaño:** L · **Estado:** 🟢 cerrado (2026-10-24) · **Depende de:** S20

## Origen

El dueño, 2026-10-24, tras probar el cliente en la Ally (texto literal, es
el origen de S20–S24):

> la ventana de "equipo del luchador" hazlo mas ameno y accesible, le doy a
> guardar cambios y no hay ninguna seña de nada. que diferencia hay entre
> evolucion, elite, 2vs2, torneos y leyendas? haz mejor la parte de logros,
> estoy seguro de que ya existia iconos. por que hay la redundancia de "elige
> tu proximo combate" con la parte de "equipo"? la parte de ayuda es muy vaga.
> los botones de mover el pj no funciona. el boton de cancelar es muy
> "pequeño" y no es visible, los juegos actuales hay como una cuenta atras.
> que es eso de evolucion? la parte de "servicios" es demasiado condensaado y
> cuando está hablando Nilo o cualquier npc no sale la cara ni nada de eso.
> por que en la parte de arriba en el combate dice "es la hora de la accion",
> "dios sram", "ira guerrera", diosa sacrogrito"? cuando uno gana el combate,
> sale vistoria y continuar y en el lobby sale otro panel/modal, con la misma
> informacion, se podrian combinar para no duplicar. el equipo del coach no
> funciona, y la parte del inventario está bien pero es denso, ahora que no
> hacemos el 1bit, creo que podriamos hacer mas. y mejor los paneles
> originales pero darle un toque moderno, sin redundancias, tambien dime o
> ponme los textos de cada npc que hay en servicio y cuando abrí el juego me
> abló un tal aldebaran, no estoy seguro si eso es un servicio o parte de
> tutorial. faltan muchaas cosas y creo que está muy sobre cargado, ya sé que
> esto es lo que tiene el servidor original, pero esto es algo del 2015 o mas
> antiguo, hoy en dia los game-loop son diferentes, así que ahora, en mi
> opinion, no está preparado para los los ultimos sprints

Reparto: lo roto → [S20](./S20-lo-que-no-funciona.md); lobby, modos, fin de
combate y ayuda → este; paneles → [S22](./S22-paneles-modernos.md); NPCs →
[S23](./S23-npcs-con-cara.md); el letrero del combate →
[S24](./S24-combate-legible.md).

## Objetivo

Que quien entra sepa en diez segundos **qué puede jugar, con qué equipo y qué
gana**, sin cinco caminos al mismo sitio. El servidor sigue siendo el del
retail; lo que cambia es cómo se presenta.

## Los modos: lo que decidió el dueño (2026-10-24)

"Evolución: este es el modo historia. Élite: ranking. 2vs2: lo quitamos
(escondemos) para no tener problemas de baja población. Torneos: ok, lo
mantenemos. Leyendas: lo quitamos."

Quedan tres: **Historia** (Evolución), **Ranking** (Élite, y los fantasmas,
ver [S20B](./S20B-hub.md)) y **Torneos**. Lo de quitar y esconder lo hace S20
(#5–7), el hub lo diseña S20B y este sprint define qué es cada uno para el
jugador.

**Historia, hoy, no es historia** (nota del agente): Evolución es una cola
**PvP** contra otros jugadores de Evolución (23003). Un modo historia
normalmente se juega contra la IA. El servidor ya tiene la pieza: los
desafíos y los demonios (Demonio III, los demonios de los minutos, Demonio
I) son combates PvE con texto y recompensas. Propuesta: Historia = la
cadena de desafíos y demonios como campaña, con las reglas de Evolución (XP,
heridas, muerte), y la cola PvP de Evolución escondida como el 2vs2. A
confirmar.

## Borrador de las fichas de modo (para que el dueño las corrija)

El dueño, 2026-10-24: "pásame la parte de las fichas y yo cambio los textos
o te digo qué cambiar". El mismo día aceptó las opciones por defecto
("de acuerdo, me parece bien"): los fantasmas van dentro del Ranking, y
Historia es la campaña PvE de desafíos y demonios.

| | Historia | Ranking | Torneos |
|---|---|---|---|
| **Frase** | Recluta luchadores y hazlos crecer combate a combate contra los demonios del Horamundo. | Todos empiezan igual: gana el mejor jefe, no la mejor colección. | Inscríbete, combate en tu horario y sube en el cuadro. |
| **Qué ganas** | Experiencia, cartas y esferas para el Kanodo | Puntos de ranking y tu puesto en la clasificación | Fichas de torneo y puntos |
| **Con qué equipo** | Tus titulares de Historia (hasta 6) | Un equipo de Élite (6000 puntos, como mucho 2 de la misma clase) | El que pida el torneo |
| **Aviso** | Tus luchadores se cansan, se hieren y pueden morir. | Si no hay rival en vivo, peleas contra el fantasma de un jugador de tu nivel. | Próximo torneo: {fecha} · Inscrito / Sin inscribir |
| **Botón** | Jugar | Jugar | Ver torneos |

Al buscar: «Buscando rival… 0:12» y «Cancelar».

## Los cinco modos del retail (2026-10-24, leyendo el código)

| Modo | Qué es para el jugador | Equipo | Qué se juega | Servidor |
|---|---|---|---|---|
| **Evolución** | El modo para empezar y el de progresión: tus luchadores ganan XP y desbloquean hechizos y equipo con el Kanodo (esferas que se compran con XP). Se cansan, se hieren y **pueden morir**; las cartas de resurrección los traen de vuelta. Es donde más cartas se ganan | un equipo: hasta 6 titulares y 7 en el banquillo | XP, cartas, heridas y muertes (y hoy también fuerza de clasificación, ver S20 #6) | 23003 con el pseudo-equipo 99 (`handlers_evolution_search.go:44`) |
| **Élite** | El competitivo: todos parten del mismo nivel, con todos los hechizos y equipo. 6000 puntos para armar el equipo, como mucho 2 de la misma clase. Sin XP ni muertes | equipos guardados de luchadores clásicos | la fuerza: ±25 entre 1000 y 3000 (`domain/ladder.go:20`) | 23103 con el id del equipo |
| **2vs2** | Élite con un amigo de tu lista: un equipo compartido | un dúo (6024–6028) | lo mismo que Élite; los dos pulsan Combatir | 23103 |
| **Torneos** | Te inscribes en el Calendario (a veces pagando una carta), hay periodos de búsqueda con horario y se ganan puntos y fichas de torneo | según el torneo: Élite, titulares de Evolución, cementerio o Leyendas | puntos y fichas | 28611 |
| **Leyendas** | Los luchadores de Evolución de mayor rango se vuelven inmortales y solo combaten en torneos de Leyendas. **No es una cola**, es un tipo de torneo. Hoy está roto (S20 #5) | luchadores en estado 4 | torneos de Leyendas | — |

## La redundancia "Elige tu próximo combate" ↔ "Equipo"

Seis botones en el lobby (`lobby_screen.gd:29-36`), y cuatro son atajos a algo
que ya está en el panel Equipo:

| Botón del lobby | Igual que |
|---|---|
| Entrenamiento | "Entrenamiento" al pie de Equipo |
| Combate (clasificado) | "Buscar combate" en Élite/2v2; desde el lobby no se ve **con qué equipo** |
| Evolución | "Buscar combate" en Evolución |
| 2v2 dúo | "Nuevo equipo" en la pestaña 2v2 |
| Equipo | también en el menú inferior y en Esc (tres accesos) |
| Aleatorio | — (el único propio) |

Además, las pestañas Élite y 2v2 muestran la misma lista mezclada de equipos
(`lobby_panels.gd:116`).

## Tareas candidatas

- [ ] **Una sola puerta por modo.** La disposición la decide S20B; aquí,
      el contenido de cada tarjeta: nombre, una frase de qué es, qué ganas y
      con qué equipo juegas. El panel Equipo queda para **preparar** el
      equipo, no para lanzar combates. Fuera los duplicados.
- [ ] **Decir qué es cada modo** donde se elige, con las frases de la tabla
      de arriba, no escondido en la Ayuda.
- [ ] **Buscar rival:** cronómetro, modo, equipo y cancelar grande (lo mínimo
      va en S20 #4; aquí, el diseño).
- [ ] **Un solo fin de combate.** Hoy hay dos: el modal "Victoria/Derrota" de
      `fight_view.gd:2983` (solo cartas ganadas y perdidas) y
      `report_panel.gd` en el lobby (resultado, posición ±, muertos y
      heridos, coaches, XP/moral/cansancio por luchador, cartas, y después la
      subida de nivel). Se unen en una pantalla que sale al acabar: resultado
      grande, lo que ganaste y después el detalle, y "Continuar" lleva al
      lobby sin otro modal.
- [ ] **Ayuda útil.** Hoy (`lobby_panels.gd:855-881`): primeros pasos,
      reglas en 5 líneas y 4 bloques genéricos; dice que las cartas de evento
      duran "unos turnos" y duran 1. Propuesta: menos texto general y más
      ayuda **en el sitio**: un "?" en cada panel que explica ese panel, y
      una página por modo.
- [ ] **Menos carga.** Revisar el lobby entero con el dueño: qué se ve de
      entrada y qué va dentro. Hoy hay ~21 paneles. La referencia son los
      juegos de cartas y autobattlers actuales (un botón Jugar, misiones
      diarias, pase de temporada…). Lo que el servidor no tiene se apunta,
      no se inventa en este sprint.

## Monetización: solo cosméticos, sin pay-to-win

El dueño, 2026-10-24: "en el S21 tienes que añadir la parte de monetización.
Por lo que he leído, el Dofus Arena era muy pay-to-win, y aquí sería solo
cosméticos, y mejorar y determinar la parte de p2w y ver cómo solucionarlo".

**Regla:** nada que cambie un combate se compra con dinero. Con dinero solo
se compra lo que se ve.

**Punto de partida, en el servidor de hoy** (sin dinero real; no hay ogrinas
ni pagos):

- **De dónde salen las cartas:**
  - drops al acabar el combate, de la tabla de sorteo de las cartas
    `ObtainableInDraw` (`gamedata/carddraw.go`, `game/drops.go:55`);
  - recompensas de desafío (`challenge_fights.go:343`);
  - el Card Master: compra con fichas del monedero `coach_currencies`
    (`handlers_shop.go`), o trueque de cartas por cartas;
  - el altar de fusión.
- **Lo que da poder:**
  - las cartas de equipo, que dan estadísticas;
  - los hechizos y el equipo que desbloquea el Kanodo con XP;
  - las cartas de resurrección;
  - las cartas de fuerza de la fusión;
  - en Historia, el tamaño del banquillo.

**Tareas:**

- **Prueba en los datos** (S20, 2026-10-24): el grupo 80 de Nilo, en
  francés en el retail: «La plus courante, est grâce aux boufteurs que tu
  peux récupérer sur le site en échange de quelques ogrines». Los sobres de
  cartas se compraban con dinero real.
- [ ] **Mapa del p2w:** cada fuente de poder, cómo se consigue y qué pasaría
      si se vendiera. Además, contrastar con lo que se sabe del Dofus Arena
      original (qué vendía Ankama por ogrinas: sobres de cartas, cuentas
      abonadas…). Lo que se encuentre se cita, no se supone.
- [ ] **Arreglar lo que ya es p2w sin dinero:** lo que hoy decide un combate
      por haber jugado más horas o por suerte en el sorteo. En Ranking, que
      la ventaja de colección no decida. Opciones: equipo normalizado en
      Élite, límite de valor por equipo (ya existe el de 6000) o todas las
      cartas de equipo disponibles en Ranking.
- [ ] **Catálogo de cosméticos:**
  - aspecto del coach;
  - dorsos y marcos de carta;
  - fuegos artificiales (ya existen: 22094);
  - emotes;
  - títulos;
  - fondos del lobby;
  - auras y anillos de equipo (las cartas de color **solo como recompensa
    de temporada**, regla del dueño de 2026-10-21).
- [ ] **Cómo se ganan sin pagar:** pase de temporada con una vía gratuita,
      logros y torneos. Lo de pago, solo cosmético.
- [ ] **Lo legal y los pagos** (proveedor, impuestos, menores, y que el arte
      es retail): se apunta para S16; aquí solo el diseño.

## Decisiones pendientes del dueño

| Decisión | Por defecto |
|---|---|
| ¿Historia es la campaña PvE de desafíos y demonios, y se esconde la cola PvP de Evolución? | **sí** (dueño, 2026-10-24) |
| ¿Qué entra en el game-loop moderno que el retail no tiene (misiones diarias, recompensa por primera victoria, temporadas)? | se apunta en el BACKLOG; un sprint aparte si el dueño lo quiere |

## Resultado

### Bloque A — un solo fin de combate (2026-10-24)

- **En el combate:** el modal de "Victoria" (que solo listaba cartas) pasa a
  ser una palabra grande, VICTORIA o DERROTA, que entra con una animación
  corta. "Continuar" o 2,5 s de tiempo real, que no se acelera en las
  repeticiones a ×4, y vuelta al lobby.
- **En el lobby:** el informe es el único sitio donde se cuenta el resultado.
  El resultado en grande, lo que ganaste como tiles con el arte de la carta,
  al lado tus luchadores (XP, moral, cansancio, estado), y la fuerza de cada
  coach en una línea si hubo rival. Cabe en 720p sin scroll.
- **Evidencia:** `report_smoke` 8/8; `run_tests.sh --visual` (captura
  `/tmp/fight-result-ui.png`); `replay_lobby_smoke` (Continuar en una
  repetición a ×4 vuelve al lobby). Capturas en `~/codigo/capturas/s21/`.

### Bloque B — Historia, la campaña (2026-10-24)

| Qué | Evidencia |
|---|---|
| **Servidor** (`server/internal/game/story.go`): tres capítulos, `{46, 29, 30, 31}`, `{34, 35, 36, 32, 33}` y `{45, 3, 13, 16, 14}`. La primera victoria de cada desafío lleva `Fight.Story`, que hace pasar el combate por la progresión de Evolución (XP, cansancio, moral, heridas, muerte) sin dejar de ser un desafío en el cable (su nombre, sus cartas). Repetir uno ganado es entrenamiento. Nuevo par Godot-only 60020 → 60021: los desafíos de la campaña ganados (el blob de criterios no lleva esa contabilidad a propósito) | `story_test.go`: primera vez Story y repetición práctica; una victoria Story suma XP; 60021 lista los ganados; la lista del cliente y la del servidor coinciden (`TestStoryChallengesMatchClient` lee `story.gd`). `OPCODE-INVENTORY.md` al día |
| **Fallo encontrado:** los desafíos los peleaba cualquier titular, también los luchadores clásicos de Élite (estado 0 es el de todos). Con Story habrían ganado XP y cansancio que Élite no tiene. `storyRoster` usa solo titulares de Historia (o los titulares si aún no hay ninguno); `titularRoster` no cambia, porque fantasmas y torneos lo usan | `TestStoryRosterFieldsHistoriaStarters`; en vivo, el log del servidor (`story=true`, 1 informe) y solo la titular 15 sumó XP |
| **Fallo encontrado:** "Reclutar un guerrero" de los maestros de clase creaba un luchador clásico de Élite. Ahora crea uno de Historia | `tutorial_smoke` 10/10 con una cuenta nueva |
| **Cliente:** panel Historia (`storyDialog`). Capítulos con su progreso, cada desafío como ✓ ganado, ▶ siguiente o bloqueado ("gana antes el anterior"), qué está en juego ("Primera vez: tus titulares ganan experiencia… y pueden morir" / "Ya lo ganaste: repetirlo es entrenamiento"), y Jugar o Repetir. La intro del demonio la primera vez (36 → 113, 45 → 117) y las lecciones de Nilo antes del 46. La tarjeta Historia del hub y el pie de la pestaña Historia de Equipo lo abren | `story_smoke` 4/4: 14 filas (12 bloqueadas), siguiente "Tutorial de Nilo", un ganado dice Repetir, Jugar → lecciones → 26330 → 8000, Equipo sin "Buscar combate" |
| **La cola PvP de Evolución, escondida** (`Features.EVO_PVP = false`). La pestaña "Evolución" de Equipo pasa a llamarse **Historia** | `native_panels` 138 PASS (el pie de Historia cabe), `modes_smoke`, `hub_smoke` |
| Regresión | `go test ./...` y e2e en verde. `TestTutorialChainOverTheWire` esperaba solo la XP de los desafíos (6); ahora cada primera victoria suma la de Evolución (≥ 306, en vivo 393). `run_tests.sh --headless` 381/0 |

**Base de pruebas:** la luchadora 5 de `test` pasa a Historia (segunda
titular, como la 15). `report_smoke` pelea el desafío 14 ("aguanta 20
rondas") con el equipo de Historia, y con una sola titular de nivel 0
perdía. Se restauraron la XP de la 15 y la de la 2 y la 3, que había
cobrado la primera pasada antes del arreglo.

**Decisiones (delegadas):**

- **Solo la primera victoria cuenta.** Así no se puede granjear XP con los
  capítulos fáciles, porque los rivales de los desafíos tienen stats
  planas.
- **La campaña va en orden.** Dentro de un capítulo se juega en orden, y un
  capítulo se abre al acabar el anterior.
- **Ningún desafío de clase en la campaña.** Los 17–28 de los maestros
  quedan como pruebas sueltas en Servicios.
- Los desafíos que existen en los datos pero ningún sitio ofrece (6, 11,
  12, 15 y los contrarreloj 37–44) quedan para un capítulo futuro.
- **El abandono no tira muerte:** sigue siendo un combate de práctica en
  ese aspecto.

### Bloque C — la Ayuda (2026-10-24)

- La Ayuda pasa de una página vaga a **cuatro pestañas**:
  - Empezar: los primeros pasos, ya apuntando a los capítulos de Historia,
    y los controles de ratón, teclado y mando.
  - Modos: Historia, Ranking con fantasmas, y Torneos.
  - Combate: colocación, PA/PM, espalda/lado, placaje, cartas de evento
    (una ronda) y condición de victoria.
  - Paneles: para qué sirve cada tile.
- **Cada ventana se explica con su "?"** (`lobby_panel.gd`). Si existe
  `help.panel.<ventana>` en los textos, aparece el botón, que muestra dos
  líneas en dorado bajo el título. Lo tienen 15 ventanas.
- Corregido lo que la Ayuda decía mal: las cartas de evento duran una
  ronda, no "unos turnos"; el 2v2 ya no existe; Evolución no cuenta para el
  ranking.
- **Evidencia:** `test/help_smoke.gd` 5/5; `tutorial_smoke` 10/10 (Primeros
  pasos); `native_panels` 138 PASS; headless 381/0.

### Bloque D — el mapa del pay-to-win y lo que se arregló (2026-10-24)

**Lo que vendía el retail por dinero** (los textos del propio juego):

- `content.59.80`: «La plus courante, est grâce aux boufteurs que tu peux
  récupérer sur le site en échange de quelques ogrines».
- `content.59.11`: «des boufteurs (que tu achètes grâce aux ogrines sur le
  site web du jeu)».
- `content.59.54`: para curar una herida «il n'existe qu'une solution :
  Utiliser une kard de soin … dans les boufteurs que tu peux acheter contre
  quelques ogrines».
- `content.29.306`: en los sobres hay pociones de resurrección.
- `content.42.19`: el Ticket MasterCoach, «uniquement dans les boufteurs
  MasterCoach».
- El cliente enlazaba a `dofus-arena.com/<lang>/kards-boufteurs`.

Es decir, **se vendían curas, resurrecciones y tickets**: justo lo que decide
los combates de Evolución. Y por un fallo (abajo), también los de Élite.

**De dónde sale el poder hoy, y si pesa en Ranking:**

| Fuente | En combate | En Ranking |
|---|---|---|
| Equipo de luchador (tipo 250, 75 cartas) | PV, PA, PM, alcance, pasivas | **No es p2w**: Élite ofrece todas las cartas del tipo sin mirar la colección (`spheres.go:166`); solo limita el presupuesto de 6000 (600 por raza + valor del equipo; los hechizos no cuentan) |
| Esferas del Kanodo (XP) | efectos y hechizos extra | Solo Historia… salvo que un luchador de Historia entre en un equipo de Élite o en un fantasma (abajo) |
| Condiciones / bendiciones (consumibles AI 15) | efectos todo el combate | **Era p2w**: se podían aplicar a luchadores de Élite. **Arreglado** |
| Heridas y muerte, curas y resurrecciones (tipo 24) | stats perdidas, luchador fuera | **Era p2w**: los combates de Ranking pasaban por la progresión de Evolución (B-188). **Arreglado** |
| Bonus de set del equipo del coach (XP, moral, heridas y muerte propias **y del rival**) | meta | **Era p2w** por la misma vía. **Arreglado** (ya no hay progresión de luchadores en Ranking) |
| Drops tras ganar | cartas | Se podían **granjear** contra el muñeco de entrenamiento, los fantasmas y los desafíos repetidos. **Arreglado** |
| Fuerza ±25 fija por combate | clasificación | Premia el volumen de partidas, no el nivel del rival. **Pendiente** (abajo) |
| Cartas "Combat" (tipo 26), fusión | — | sin efecto en combate |

**Arreglado en este bloque** (decisiones delegadas: aplican la regla del
dueño, "nada que cambie un combate se gana con dinero ni con horas"):

| Arreglo | Evidencia |
|---|---|
| **B-188: Élite deja de tocar a los luchadores.** Solo los combates de Evolución y de Historia pasan por XP, cansancio, moral, heridas y muerte (`postfight_apply.go`). La reputación del coach sigue en todos los modos. Es lo que decía el retail de Élite: «todos parten del mismo nivel… sin XP ni muertes» | `TestRankedFightLeavesFighters`; sin el arreglo: `TotalXP 0 → 150 after a ranked win`. El e2e de B-096 pasa a emparejar por Evolución para seguir teniendo informes |
| **Consumibles solo en luchadores de Historia** (`consumables.go`) | `TestConsumableRefusedOnEliteFighter` (la poción no cura y no se gasta) |
| **Sin drops en práctica**: muñeco, fantasmas y desafíos repetidos. La primera victoria de Historia sí roba (`fightPaysDrops`) | `TestFightPaysDrops` |

**Pendiente, con propuesta:**

- **Fantasmas con luchadores de Historia.** El fantasma se congela de
  `titularRoster`, que mezcla titulares de Élite y de Historia (con sus
  esferas). Propuesta: que el fantasma salga del **equipo de Élite**
  elegido. Toca el editor de S13, así que va en S22 con los paneles.
- **Equipos de Élite con luchadores de Historia.** El panel no lo deja
  (solo lista clásicos), pero el servidor no lo rechaza. Propuesta:
  rechazarlo en `validateRoster` para los combates de Ranking.
- **Fuerza ±25 fija.** Propuesta: Elo (como ya usan los fantasmas, K = 32),
  para que ganar a alguien más fuerte valga más. Cambia la escala de la
  clasificación. **Decide el dueño.**

**Catálogo de cosméticos** (lo que puede venderse o darse como recompensa
porque no toca el combate):

| Qué | Hoy | Falta para venderlo |
|---|---|---|
| Fuegos artificiales (tipo 25, 30 cartas) | se lanzan en el cielo del lobby | el servidor **no comprueba que tengas la carta ni la gasta** |
| Emotes (tipo 1, 10 cartas) | tabla fija | comprobar propiedad |
| Títulos (tipo 28, 12 cartas) | sin implementar (3212) | implementarlos |
| Colores (tipo 29, 23 cartas) | quitados en S07 | solo como recompensa de temporada (dueño, 2026-10-21) |
| Iconos y fondos de equipo | existen en el preset | arte propio |
| Aspecto del coach (sombrero, tatuaje, peinado…) | **no es puro**: lleva bonus de set | separar aspecto y bonus |
| Dorsos y marcos de carta | no existen | arte |

**Regla para una tienda futura:** solo tipos 1, 25, 28 y las cosas de arte
propio. Nunca tipo 24 (curas, resurrecciones, runas, pociones de XP), equipo
ni tickets. Pagos, proveedor y legal, en S16.

## Criterio de cierre

**Cerrado el 2026-10-24** sin la aprobación en la Ally ("sigue con los
sprints y no abras el juego"). Lo que queda: el fantasma desde el equipo de
Élite y rechazar luchadores de Historia en Ranking van a S22; Elo frente a
±25 espera al dueño (README).

Desde el lobby, cada modo tiene una sola entrada y dice qué es; el mapa del
p2w está escrito y decidido, con el catálogo de cosméticos; buscar rival
tiene cronómetro y cancelar visible; al acabar un combate sale una sola
pantalla de resultado; la Ayuda explica cada panel. El dueño lo aprueba en la
Ally.
