# S53 — La primera partida, de verdad

**Planificado:** 2026-11-25 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** 🔵 en curso (2026-11-25)

## Por qué

El dueño jugó la alfa en itch.io como un jugador nuevo y encontró una lista
larga de fallos que yo no vi. Cerré S47–S52 con smokes, unitarias y capturas
sueltas, pero **nunca jugué la partida entera como alguien que llega por
primera vez**, en el navegador y a un tamaño de ventana normal. Así se
escaparon cosas que se ven en el primer minuto. Este sprint arregla la
lista y añade esa prueba como condición de cierre.

## Lo que vio el dueño (2026-11-25)

### A. Fallos que se ven

| # | Fallo | Qué creo que es |
|---|---|---|
| A1 | Una línea horizontal corta el retrato de Aldebrán en su diálogo | la regla de la cabecera del lobby se dibuja por encima de la capa del diálogo |
| A2 | «Página 1 de 8» en los diálogos | sobra: fuera |
| A3 | Las respuestas de Nilo salen fuera del cuadro de texto, flotando sobre el lobby | deben ir dentro del bocadillo, debajo de su frase |
| A4 | Triángulos feos en los coaches: mujer en codo, muslo y pelo junto a la oreja; hombre en las costillas | la máscara piel/pelo (`coach_masks.py`) clasifica mal algunos triángulos, y las bandas del toon siguen la malla en escalones (normales sin suavizar) |
| A5 | La malla de los luchadores es muy mala | revisar los 12 (Meshy → `meshy_fighter.py`): mismas dos causas, más la reducción a 5k triángulos |
| A6 | En combate todos los muñecos son iguales, blancos y translúcidos; no sé cuál soy | los luchadores se ven como «fantasmas»: el paquete `figures` aún no estaba bajado al empezar el combate, o un material de sustitución; hay que esperar a que esté y no enseñar nunca el sustituto |
| A7 | No se ve de quién es el turno ni cuál es el mío | anillo bajo mis luchadores (color de mi equipo), un aro y una flecha encima del que tiene el turno, su retrato en la barra |
| A8 | El zoom no tiene límite, ni hacia dentro ni hacia fuera | límites al zoom de la cámara de combate (y al del lobby si lo hay) |
| A9 | Al cambiar el tamaño de la ventana el combate se ve todo diminuto | el escalado de la interfaz y de la cámara al tamaño de la ventana: la arena debe llenar el espacio y el HUD crecer con ella |
| A10 | El mapa de la arena 2 está corrupto, o no es el que hizo el dueño | comparar el `layout` de la 2 del paquete web con el del editor del dueño; si el paquete es viejo o el borrador de `draft_from_retail.gd` pisó el suyo, rehacerlo desde su fichero |
| A11 | Las animaciones de Historia, Ranking y Torneos solo se mueven al pasar el ratón | moverse siempre en reposo (suave), y más al pasar el ratón |
| A12 | Al crear un luchador vuelve a la pantalla principal | quedarse en Equipo, con el luchador nuevo seleccionado |
| A13 | Al crear el luchador no se explica qué son las pesetas | una línea en el reclutamiento: qué cuesta, cuántas tienes, cómo se ganan |
| A14 | Pantalla gris tras «¡Crear!»: `WebSocket … The network connection was lost` | el cliente no dice nada si se cae la conexión fuera del lobby (ver abajo) |

**A14, conexión.** En el log de oracle-2 la sesión del dueño (19:01) llega
a la creación del jefe y la conexión se cierra a los 2 min, sin que llegue el
«¡Crear!». En Chromium no se reproduce (150 s quieto en esa pantalla y luego
crear: va bien), y el texto del error es el de Safari: el navegador corta el
socket al cambiar de app, bloquear la pantalla o suspender la página.
Arreglo: un aviso «Se perdió la conexión» con «Reconectar» en cualquier
pantalla, que vuelve a entrar con la misma cuenta de invitado; y si se cayó
mientras la página estaba en segundo plano, reconectar solo al volver.

### B. El tutorial está mal planteado

Lo que dice el dueño, en corto: **en un tutorial hay que obligar al jugador
a hacer lo que toca, apagar todo lo demás y enseñar explícitamente dónde
está cada cosa; y la guía solo debe enseñar a pelear: con un primer
combate basta.**

Fallos concretos de la guía actual (S47):

- Resalta adónde ir **y además** tiene un botón gigante «IR» y una «X».
  Sobran los dos.
- El resto de la interfaz sigue activo y pulsable mientras se resalta algo.
- El paso 1 manda a hablar con Nilo, pero en la pantalla de NPC no se
  resalta Nilo y se puede hablar con cualquiera.
- Nilo tiene muchísimas opciones de conversación: un jugador nuevo se
  pierde.
- Empezar por Nilo y luego por el Demonio III no tiene sentido.
- Al reclutar no se dice si el luchador es para Historia o para Élite y
  torneos.

## Plan

### B1. Un tutorial nuevo, corto y guiado a la fuerza

1. **Crear el jefe** (como hoy).
2. **Reclutar el primer luchador.** Foco en Equipo → «Reclutar»; el resto
   apagado y sin clics. Dos líneas antes de elegir: *este luchador es para
   Historia (crece combate a combate); Élite y torneos se juegan con otro
   equipo, más adelante*; y qué son las pesetas y cuántas te quedan. Al
   reclutar, te quedas en Equipo con él seleccionado (A12).
3. **Primer combate guiado**: la práctica de Nilo contra el muñeco (S52),
   lanzada directamente desde el tutorial, sin pasar por la pantalla de
   NPC ni por sus menús de conversación.
4. **Fin**: «Ya sabes pelear» y el lobby normal. Nada de Demonio III ni de
   más pasos: el resto se descubre jugando.

Cómo se ve cada paso:

- **Foco de verdad:** todo oscurecido salvo el control del paso, con un
  agujero recortado a su alrededor; los clics fuera del agujero no hacen
  nada. Un bocadillo junto al agujero dice qué hacer.
- **Sin «IR» y sin «X».** En su lugar, un enlace pequeño «Saltar tutorial»
  en una esquina, que pregunta una vez antes de saltar.
- **Respuestas dentro del cuadro** (A3) y **sin «Página n de m»** (A2) en
  todos los diálogos.
- Los NPC (Nilo, Demonio III, Aldebrán…) siguen en Servicios para quien
  quiera hablar con ellos, pero el tutorial no pasa por ellos.

### B2. El combate se entiende

- A6, A7: cada luchador con su figura real (nunca el sustituto), el mío con
  un anillo de mi color, el del turno con aro, flecha y su retrato
  destacado en la barra de turnos.
- A8, A9: zoom con límites; la arena y el HUD escalan con la ventana.

### B3. Arte

- A4: rehacer la máscara de los dos coaches (render con y sin pelo/piel,
  diferencia, y revisar los triángulos sueltos) y suavizar sus normales;
  hoja antes/después al dueño.
- A5: los 12 luchadores, el mismo repaso, uno por sesión (como S35b).
- A10: la arena 2, desde el fichero del dueño.
- A11: animación en reposo de las tarjetas del lobby.

### B4. Conexión (A14)

Aviso y reconexión en cualquier pantalla; prueba en Chromium cortando el
socket a mano en la creación, el lobby y un combate; y en Safari si el dueño
puede (no tengo Safari aquí).

## Orden

1. A14 (conexión): hoy deja la partida bloqueada.
2. B1 + A1–A3, A12, A13 (tutorial y diálogos).
3. B2 (combate legible: A6–A9).
4. A10, A11.
5. A4, A5 (arte), con hojas al dueño.

## Cómo se cierra (nuevo)

Además de unitarias y smokes, **una partida entera como jugador nuevo**:

- en el build web, en Chromium, con una cuenta de invitado recién creada;
- a 1280×720 y a 1920×1080, y cambiando el tamaño de la ventana a mitad;
- desde «Jugar como invitado» hasta terminar el primer combate;
- grabada en capturas paso a paso, que miro una a una con esta lista:
  ¿se sabe qué hacer sin leer nada fuera del foco?, ¿se puede pulsar algo
  que no toca?, ¿hay algo cortado, encima de otra cosa o diminuto?, ¿se
  sabe cuál es mi luchador y de quién es el turno?

Además de esa partida, paso las listas de las skills de diseño de juego
(`gamedev:game-ui-ux`, onboarding y escalado) antes de dar nada por
terminado.

## Respuestas del dueño (2026-11-25)

1. **Arena 2:** el fichero bueno es el del editor; «la hierba no está tan
   alta». Lo busco yo junto al editor (S36 fase C) y comparo con lo que
   sirve el paquete web.
2. **Tutorial:** sí a *jefe → reclutar → combate contra el muñeco → fin*.
3. **Conexión:** Safari; con F5 volvió todo. A14 baja de prioridad, pero
   el aviso con «Reconectar» se hace igual (nadie sabe que hay que pulsar F5).

Orden nuevo: B1 + diálogos → B2 → A10/A11 → A14 → arte.

## Hecho

### Diálogos (A1–A3) — 2026-11-25

- **A1 no era una línea del lobby:** el retrato de Aldebrán venía cortado
  por arriba (los palos del sombrero se salían del lienzo de vex y la tinta
  quedaba plana). Lo mismo con las alas del Demonio I, el cuerno del
  Demonio III y las orejas de Nilo (a los lados). Palos más cortos, los dos
  demonios dibujados 16 unidades más abajo, y `npc_anim.py` encaja cada
  figura con sus capas (parpadeo, brillo, chispa) para dejar 12 px libres
  arriba y a los lados, también con la respiración.
- **A2:** sin «Página n de m». **A3:** las respuestas van dentro del cuadro,
  bajo la frase (antes flotaban a la derecha, sobre el lobby).

### Tutorial nuevo (B1, A12, A13) — 2026-11-25

- **Fuera la guía de S47** (tarjeta con «IR» y la cruz, y sus seis pasos de
  logros). Los logros siguen; Ayuda ofrece «Repetir el tutorial».
- **`src/ui/spotlight.gd`:** oscurece toda la ventana menos un agujero
  alrededor del control del paso; un clic fuera no hace nada, dentro llega
  al control. Bocadillo al lado del agujero (o centrado sin agujero, con su
  botón) y «Saltar tutorial» arriba a la derecha, que pregunta antes.
- **Pasos** (`main._tutorial_step`): sin luchadores → el agujero en la
  tarjeta de Historia, que abre Reclutar; con luchador → la misma tarjeta
  lanza directamente la práctica de Nilo (reto 46); al volver → «¡Ya sabes
  pelear!» centrado y fin. Hecho o saltado se guarda en `gamePreferences`;
  un coach que ya ha peleado no lo ve (salvo si pide repetirlo).
- **Reclutar en el tutorial (A13):** una nota dice que es para Historia, que
  Élite y Torneos se reclutan aparte, que reclutar es gratis y qué son las
  fichas y las pesetas; Élite queda cerrado.
- **A12:** fuera del tutorial, al reclutar se abre Equipo en la pestaña del
  luchador nuevo (antes volvía al lobby).
- Textos `tutorial.*` en es/en/fr.

Verificado: `run_tests.sh --headless` 26 suites, 1681 comprobaciones, 0
fallos. `first_play_smoke` (nuevo; sustituye a `guide_smoke`) **14/0** en
es, en y fr: el agujero rodea la tarjeta, fuera no pasa el clic, Reclutar en
modo tutorial, de vuelta al lobby, la práctica empieza desde la tarjeta, al
volver «¡Ya sabes pelear!», su botón lo termina, «Repetir» lo trae y
«Saltar» lo cierra, y fuera del tutorial reclutar lleva a Equipo.
`tutorial_smoke` 10/0, `s47_smoke` 22/0, `practice_smoke` 22/0,
`talk_smoke` 7/0, `slots_smoke` 4/0. Capturas miradas: oscuro entero salvo
la tarjeta, bocadillo legible a su lado.

Pendiente de B1: dentro del combate la guía de Nilo parpadea lo que toca,
pero el resto de la interfaz sigue pulsable; va con B2.

### Combate legible (A7–A9) — 2026-11-25

- **A7:** los anillos dicen *míos / suyos* (azul / rojo), no equipo 0 / 1:
  si eras el equipo 1 tus luchadores salían en rojo. Disco de color bajo los
  pies y aro más grueso; el que tiene el turno, disco más lleno, aro
  brillante y un segundo aro, y una flecha de su color que bota sobre su
  cabeza (`TurnMark`, encima de todas las figuras).
- **A9:** durante el combate la ventana escala su contenido desde
  1280×720 (`canvas_items`, aspecto `expand`): el HUD y el tablero crecen
  con la ventana; al salir vuelve como estaba (el lobby tiene su escalado).
  La cámara encaja el suelo en lo que deja el HUD al entrar y en cada cambio
  de tamaño.
- **A8:** la rueda queda entre 0,75× y 3× de ese encaje, y el arrastre no
  saca el suelo de la pantalla.
- Comprobado con capturas a 1280×720, 1920×1080, 1024×640 y 1600×720 (las
  dos primeras, idénticas en proporción) y de cerca: flecha azul sobre Humo,
  aro azul bajo él y rojo bajo el muñeco.

**A6 (figuras blancas y translúcidas):** no se reproduce en Chromium (las
figuras salen con su color, captura de un combate real contra oracle-2).
Es de Safari: las figuras se pintan en un SubViewport con fondo
transparente y Safari mezcla ese alfa de otra manera. El WebKit de
Playwright no arranca en Bazzite (le faltan bibliotecas de Ubuntu). Queda
abierto: probar en un contenedor con WebKit o con el Safari del dueño.

### Lobby vivo (A11) y conexión perdida (A14) — 2026-11-25

- **A11:** las figuras de las tarjetas se balancean 3° (antes 1,4°) y
  respiran con un bote de 4 px en reposo, y el fondo de puntos va al doble
  (8; 16 con el puntero encima). El puntero solo lo aviva.
- **A14:** `src/ui/lost_connection.gd`: si el socket cae con sesión
  iniciada (no al cerrar sesión), en cualquier pantalla sale «Se perdió la
  conexión» con «Reconectar»: en la web recarga la página (el navegador
  guarda la llave del invitado y entra solo); fuera, vuelve al login. Si la
  página estaba en segundo plano (cuando Safari corta), reconecta sola al
  volver al frente. `lost_connection_smoke` **4/0** (cae → aviso; cerrar
  sesión → nada; Reconectar → login).

### A6 y A10 son de Safari

En Chromium (web, contra oracle-2) la arena 36 sale como en el editor
(hierba a ras del pavimento blanco, captura `fight-1-later.png` de
`fight_load_test`), y los luchadores con su color. En el Safari del dueño
la hierba sale levantada, con los lados de tierra a la vista, y las
figuras blancas y translúcidas: es cómo Safari pinta (profundidad y alfa
del 3D), no el mapa (los `layout` siguen como los dejó el dueño el
2026-11-03). Para probarlo: el MacBook responde por SSH y tiene
`safaridriver`, pero Safari pide «Permitir la automatización remota»
(Ajustes → Avanzado → funciones de desarrollador; menú Desarrollador), que
solo puede activar el dueño.

### Cierre: la partida entera como jugador nuevo, en el build web — 2026-11-25

`godot/tools/web/first_play_test.mjs` (nuevo) en Chromium sobre el build
web, contra un servidor local (oracle-2 limita las cuentas demo por
dirección y hora, y hoy ya había hecho muchas), a **1280×720** y a
**1920×1080**, y cambiando a 1920×1080 y vuelta en mitad del combate.
Recorrido: Jugar como invitado → jefe → intro de Aldebrán → foco en
Historia (un clic fuera no abre nada) → Reclutar en modo tutorial → lobby →
la práctica de Nilo → salir → resultado → «¡Ya sabes pelear!». Capturas
miradas una a una. Lo que encontró y se arregló:

- **El historial echaba del juego.** Cada «Siguiente» de la intro cierra y
  vuelve a abrir el diálogo; el `history.back()` (asíncrono) del cierre se
  cruzaba con el `pushState` de la apertura y, al pasar de la intro 0 a la
  1, el historial retrocedía hasta `about:blank` (en el marco de itch,
  página vacía). Ahora `gui_layer.gd` iguala las entradas a las ventanas
  abiertas una vez por fotograma y nunca con un `go()` a medio llegar
  (`gui_history_test`: el caso de cerrar y abrir en fotogramas distintos).
- **Salir de la práctica con ⇥** no cerraba el tutorial (la escena cambia
  antes del 8300): ahora sí.
- **«Fichas 0» al volver de un combate** (el lobby nuevo no tenía la
  cartera hasta que el servidor la reenviaba): se la pasa el de antes.
- **Los bocadillos del tutorial no crecían con la ventana** (a 1920×1080
  quedaban pequeños) y el botón «¡A jugar!» salía cortado.

Verificado: `run_tests.sh --headless` 26 suites, **1685** comprobaciones, 0
fallos; `first_play_smoke` 14/0; `first_play_test.mjs` a las dos
resoluciones sin salir del juego, con las capturas de cada paso.

### Limpieza antes de seguir — 2026-11-26

- **Fuera (en git queda el historial):** `src/util/le_reader.gd` (lector de
  los formatos retail, sin uso), `proto/s33/` (prototipo de arte de S33),
  `tools/map_editor/draft_from_retail.gd` (necesitaba el archivo retail de
  S42; las arenas ya son finales), `tools/make_creation_bg.py` (sin uso),
  `art/biomes.json` (biomas de S36 que no lee nadie), el `.uid` huérfano de
  `guide_smoke`; en Go, `teamUps.cancelPending` y el helper de test
  `assertCells`, que nadie llamaba.
- **Fuera del disco (no estaban en git):** los kits de biomas del 25 de
  octubre (`art/{cueva,fortaleza,lava,playa,pradera,ruinas}`, 453 MB, casi
  todo `out/`; las fuentes van en `~/.local/share/limpieza-s53/`), los
  builds de escritorio de `dist/` (macOS 3,4 GB anterior a S43 con arte
  retail, Linux, Windows: solo hay web, S51), ficheros `._*` de macOS,
  `__pycache__`.
- **Se queda, a propósito:** el 2vs2 (dormido tras `Features.DUO`, no
  muerto) y `zaap.go` en el servidor; las herramientas y smokes viejos que
  aún funcionan (`tools/portraits`, `promo`, `reel`…).
- Unitarias **1684** (una menos: `scripts_compile_test` ya no compila
  `le_reader.gd`), 0 fallos; `go vet` y `go test ./...` limpios.

### La práctica, cerrada como el lobby (B1) — 2026-11-26

- Mientras Nilo habla, un clic izquierdo o derecho solo llega a lo que
  parpadea (el rombo de la casilla, el botón, la barra de turnos, el globo
  de PA) y a su bocadillo; lo demás no hace nada. La rueda, el arrastre con
  el botón central y el paso del ratón siguen llegando al combate.
- El resto se oscurece al 45 % (el lobby, al 72 %): el tablero se sigue
  leyendo; el hueco de una casilla es su rombo, no la caja con la figura.
  Sin nada que señalar (turno del muñeco) no se oscurece, pero tampoco se
  puede pulsar nada.
- `fight_view._try_move` toma la casilla de la posición del clic, no del
  puntero (lo mismo con un toque o con un clic de prueba).
- `practice_smoke` hace clics reales: coloca pulsando la casilla, pulsa
  «Listo», y un clic en «Pasar turno» mientras parpadea una casilla no hace
  nada. **20/0** (y `--healed` 22/0, `--skip-at=4` 11/0, `--lang=fr` 20/0);
  `first_play_smoke` 14/0; unitarias 1684/0. Capturas miradas: colocación,
  Listo, el hechizo, el globo de PA.

## Pendiente

- **A6 / A10 en Safari** (figuras blancas, hierba levantada): falta un
  Safari que se pueda controlar; el dueño puede activar «Permitir la
  automatización remota» en el MacBook.
- **A4 / A5:** las mallas de los coaches y los luchadores (arte, con hojas
  antes/después al dueño).
