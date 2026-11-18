# S47 — Feedback de la alfa (dueño, 2026-11-16)

**Planificado:** 2026-11-16 · **Hito:** M7 / M5 · **Tamaño:** L · **Estado:** 🟡 en curso — tanda 1, mapa de pantallas y reorganización 1 (reclutar, torneos, iconos) hechos (2026-11-17, abajo); puntos 4, 16 y 12 (con su pasada de diseño) hechos; quedan los iconos (11) y la coach mujer a 40k (1) — ver «Dónde retomar»

Dictado del dueño tras probar la demo. Referencias en [`ref/S47/`](./ref/S47/):
`crear-personaje-ref-1.webp` y `crear-personaje-ref-2.webp` (pantalla de
creación de personaje de referencia: lista de clases a la izquierda, figura
grande al centro, descripción + dificultad + roles + preview en peana +
colores a la derecha) y `equipo-actual.png` (nuestro modal de Equipo hoy).

## Puntos

1. **Mallas de los coach.** Triángulos mal puestos y partes del pelo que no
   se pintan bien; al cambiar el color del pelo cambia el de los ojos
   (slots de material/zonas mezclados). Se bajaron demasiado: rehacer con
   **~40 000 triángulos** y revisar la asignación de materiales por zona.
2. **Modales demasiado pequeños en pantalla completa.** Deben escalar con la
   resolución.
3. **Sin onboarding claro.** Nada indica que hay que crear un equipo; al pulsar
   Equipo te lleva a Historia/Élite/Torneos y "Crear luchador" queda en segundo
   plano. Antes de tocar nada: **hacer un mapa visual de las pantallas
   actuales** (captura de cada una + flujo) para tener el recorrido delante.
4. **Tutorial.** Tiene que haber algún tipo de tutorial guiado.
5. **Crear luchador → pantalla propia, no modal.** La pestaña
   Evolución/Clásico apenas se nota qué cambia. No se ven ni los ataques ni la
   descripción de la clase. Hacerlo como en las referencias: pantalla nativa
   con figura grande, descripción, dificultad, roles y ataques.
6. **El luchador creado no sale en Historia, solo en Torneo.** Muy confuso.
7. **"Luchadores · 0" pero deja activar** (seguramente existe pero solo se
   lista en Torneos). Unificar la lista o explicar por modo.
8. **Separar Historia y Ranking** en modales distintos. Y **Torneos** no tiene
   sentido si solo es un calendario cuando en otro modal también hay Torneos.
9. **Quitar "Esc vuelve · Enter confirma el campo activo"** de todas partes.
10. **Añadir amigo:** el mensaje de resultado sale en el chat, debe salir en el
    propio modal.
11. **Iconos del inventario del coach repetidos** (ya avisado antes, sigue).
12. **Rework grande de Inventario / Colecciones.**
13. **Calendario es redundante con Torneos** (ver 8).
14. **Revisar las descripciones de los logros** (que digan lo que de verdad
    piden).
15. **Iconos de la barra:** el Buzón debería ir en el icono del chat, y lo que
    hoy abre el chat pasar a ser un icono de "Amigos".
16. **"Equipo" del luchador no se entiende:** ¿el valor de qué es? Explicar o
    rediseñar (qué mide, para qué sirve).

## Orden propuesto (por decidir con el dueño)

3 (mapa de pantallas) primero, porque 5–8, 13 y 15 son reorganización de
pantallas y salen de ese mapa. Luego 1 (mallas), 2, 9, 10, 11, 14 (arreglos
rápidos), y por último 4 (tutorial) y 12 (inventario) sobre el flujo nuevo.

## Requisito del dueño (2026-11-16)

> "añade que sea mínimo 4 GB"

- **El mínimo pasa a ser un dispositivo con 4 GB de RAM** (antes, S44:
  2 GB). Las pruebas de rendimiento y memoria de la demo web se hacen contra
  4 GB.

## Auditoría de interfaz web (skill game-ui-ux, 2026-11-16)

El juego es **solo web**: lo que importa es la ventana del navegador, el
móvil y el táctil (mando y zona segura pasan a segundo plano). Solo
apuntado, nada arreglado.

**Graves**

- W1. **La UI no escala con la ventana.** `export_presets.cfg` tiene
  `html/canvas_resize_policy=2` (el canvas llena la ventana) pero
  `project.godot` no define stretch: 1 px de canvas = 1 px de UI, y el modal
  de 1120×620 (`lobby_panel.gd:12`) se ve diminuto maximizado o en pantalla
  completa (punto 2). Fijar `canvas_items` + `expand` con una referencia.
- W2. **En móvil no cabe:** un móvil vertical (~390×844) desborda el modal de
  1120 px. Choca con el requisito de dispositivos de 4 GB (móviles).
- W3. **No se puede escribir en móvil:**
  `html/experimental_virtual_keyboard=false` (nombre del luchador, chat,
  añadir amigo).
- W4. **128 posiciones/tamaños fijos en píxeles** en `src/ui` (≈10 archivos);
  la ventana del navegador cambia de tamaño en cualquier momento.

**Medios**

- W5. **Texto pequeño:** 19 tamaños < 14 px; la pista del pie a 12 px.
- W6. **Nada táctil:** ningún código de toques, todo depende de que el
  navegador emule el clic; botones de 40×40 (`lobby_panel.gd:157`) justos
  para el dedo (44–48 px tras escalar); revisar todo lo que dependa de
  pasar el ratón por encima.
- W7. **Sin pila de pantallas:** cada panel se abre y cierra por su cuenta
  (parte del lío de los puntos 3, 6–8) y el botón "atrás" del navegador no
  tiene dónde engancharse.
- W8. **"Esc vuelve · Enter confirma" en todos los modales**
  (`lobby_panel.gd:124`, clave `panel.hint`): en móvil no hay Esc ni Enter
  (punto 9).

**Menores**

- W9. **Animación del lobby en cada fotograma** (`lobby_screen.gd:1001`):
  procesador y batería en móviles modestos; bajar la frecuencia o parar con
  la pestaña oculta.
- W10. **Foco inicial:** 17 de 29 scripts de UI no ponen el cursor en el
  campo de texto al abrirse; en el ordenador hay que hacer clic antes de
  escribir.

## Tanda 1 — los arreglos rápidos (2026-11-17)

El dueño: "sigue con los bug fixes". Hecho lo que era arreglo y no rediseño
(puntos 2, 6–7 en parte, 9, 10, 14 y W1, W3, W8, W10); lo que es
reorganización de pantallas (3, 5, 8, 13, 15, 16), arte (1, 11) o un sprint
propio (4, 12) sigue como está, abajo el porqué.

| Punto | Qué se hizo | Dónde |
|---|---|---|
| 2 / W1 | Los modales **escalan con la ventana** como el lobby (ambos contra 1280×720); antes `lobby_panel.gd` no pasaba de 1:1 y el modal quedaba diminuto en pantalla completa. Sigue encogiendo en ventanas pequeñas. No hace falta un `stretch` global: login, creación, lobby y pantallas de héroe ya escalaban solas; el combate mide su HUD contra la ventana | `lobby_panel.gd` `_layout` |
| 9 / W8 | **Fuera "Esc vuelve · Enter confirma el campo activo"** de todos los modales y el "· Esc" del tooltip de cerrar. El pie del modal solo aparece cuando un panel fija acciones en él | `lobby_panel.gd`, `ui_*.json` (`panel.hint` y `panel.footer_hint` borradas) |
| 10 | **Añadir amigo responde en el propio modal**: "X añadido a amigos", "No hay ningún jefe que se llame X", "la lista está llena…" (también quitar, ignorar y dejar de ignorar). El chat sigue recibiendo la línea. El servidor contesta 3204 (nombre desconocido, `[u8 len]name`) y 3216 (lista llena): el cliente no los leía | `main.gd` (`_social_status`, `OP_USER_NOT_FOUND`, `OP_OPERATION_NOT_PERMITTED`), `lobby_panels.gd` `_social` |
| 14 | **Los logros dicen lo que piden**: el texto del criterio con su meta en el `[#1]` ("Hilar 5 triunfos seguidos."), bajo la descripción cuando la hay. Antes, con descripción, solo salía esta: "Gana partidas seguidas." para los ocho Marcha. Tres criterios no tenían nombre y salían como `#147`, `#167`, `#222`: 167 es la fuerza máxima de equipo en 1vs1 (`coach_statistics.go`), 147 el puesto del ranking 2vs2 y 222 el del ranking de evolución (por su posición entre los criterios y la categoría de sus logros). **Ojo:** el servidor no mantiene 147 ni 222, así que "Cumbre de los Ases" y "Metamorfosis final" no se pueden conseguir hoy; apuntado en el BACKLOG §12 | `main.gd` `_achievement_asks`, `content_*.json` |
| 6–7 | Las pestañas de Equipo **dicen de quién son los luchadores que listan**: los de Historia (evolución, crecen) y los de Élite/Torneos (clásicos, nivel fijo con cartas) son luchadores distintos en el servidor, y "Crear luchador" crea el del modo de la pestaña. "Buscar combate" y "Buscar torneo" quedan **apagados sin luchadores**. Unificar la lista es parte del rediseño (punto 5) | `lobby_panels.gd` `_team` |
| W3 | **Teclado en pantalla en el móvil**: `html/experimental_virtual_keyboard=true` | `export_presets.cfg` |
| W10 | **El cursor entra en el primer campo** al abrir un modal con campos (Social, Inventario, correo…), salvo en pantallas táctiles (levantaría el teclado antes de leer nada). Como el campo se traga el primer Esc, el modal lo captura él mismo y cierra | `lobby_panel.gd` `focus_first_field`, `_input` |

### Por qué lo demás no entra en esta tanda

- **11, iconos repetidos del inventario.** No es un fallo del código: los
  iconos propios (`assets/ui/cards/coach/`, 392) solo cubren el equipo del
  coach (tipos 2, 4–13). Las demás cartas llevan el pictograma de su
  familia, de ahí la repetición: tipo 26 (282 cartas), 24 (190), 30 (99),
  25 (30), 29 (23), 3 (8), 1 (10)… Es el pendiente "Cartas sin ilustración
  propia" del BACKLOG §13: hacen falta ilustraciones (S40/S38), no un
  arreglo.
- **1, mallas de los coach.** Arte (pipeline Meshy, `S35b`), sesión propia.
- **3, 5, 8, 13, 15, 16.** Reorganización de pantallas: primero el mapa de
  pantallas (3), luego decidir con el dueño (modo Q&A).
- **4, 12.** Tutorial e inventario: sprints propios sobre el flujo nuevo.
- **W2, W4–W7, W9.** Móvil vertical, posiciones fijas, texto pequeño,
  táctil, pila de pantallas, animación del lobby: caen con la
  reorganización, no antes.

### Verificado

- `godot/run_tests.sh --headless`: 20 suites, 1491 comprobaciones, 0
  fallos (`own_text`: 102 criterios con nombre, antes 99).
- `godot/run_tests.sh --visual` (xvfb, 1280×720 y 800×600): sin fallos; los
  modales siguen dentro de la ventana.
- `test/ui_review_preview.tscn` a **1920×1080** bajo xvfb: Social y Equipo
  a 1,5× (el modal llena la pantalla como el lobby), el cursor en "Nombre
  del jefe", el pie sin la pista. La primera pasada sacó Equipo fuera de la
  ventana: la nota por modo era una línea sin ajuste; arreglado con
  autowrap.
- No probado en vivo: la respuesta 3204/3216 en el modal Social contra un
  servidor (la ruta es la misma que la de la línea del chat, que sí llegaba)
  y el teclado en pantalla en un móvil real.

## Punto 3 — el mapa de pantallas (2026-11-17)

El dueño: "empieza". Primero del orden propuesto.

- **Dónde:** `~/codigo/capturas/s47/mapa/index.html` (abrir en el
  navegador de la Ally). Arriba el recorrido como árbol (qué abre qué, en
  amarillo lo que se abre desde varios sitios), luego lo que enseña el mapa
  y la galería: 51 pantallas, cada una con todas las formas de llegar.
- **Cómo se hizo:** `godot/test/screen_map.gd` juega el cliente contra un
  servidor local como un jugador (login → crear jefe → intro → cada botón
  del lobby y cada pestaña → cada loseta → «Crear luchador» por pestaña →
  cada grupo de Servicios y lo que abren → combate de entrenamiento), con
  una cuenta nueva y con `test`. `godot/tools/screen_map.sh OUT` lo repite
  entero en una red aislada y `tools/screen_map_page.py` monta la página;
  las notas (árbol y hallazgos) van a mano en `OUT/notas.html`. Sirve para
  comparar después de reorganizar.

### Lo que enseña

| Hallazgo | Puntos |
|---|---|
| **Opciones, Replays, Reportar bug, Desconectar y Salir no tenían entrada** desde el 7-oct: el lobby perdió el botón de Menú. **Arreglado** (B-191): icono de tres rayas arriba a la derecha, el que el atlas tenía sin usar. Dónde vive al final, con la reorganización | nuevo |
| Reclutar no tiene camino directo: «Reclutar» (Historia), «Crear equipo» (Ranking) y «¡A luchar!» sin equipo abren Equipo, donde «Crear luchador» es un botón pequeño; el otro camino es Servicios → Aprendizaje → un maestro | 3, 5 |
| Equipo se abre desde cinco sitios y su pie repite las losetas (Entrenamiento, Historia, Buscar combate) | 7, 8 |
| Los torneos están en cuatro sitios: loseta, Calendario (lista y loseta), pestaña de Equipo y pestaña de Clasificación | 8, 13 |
| Dos clasificaciones: Clasificación y la pestaña de Fantasmas | 8 |
| La campaña no tiene entrada propia: sin luchadores la loseta lleva a Equipo | 6, 8 |
| La intro son 12 páginas seguidas; el resto del tutorial es la lista «Primeros pasos» de Ayuda | 4 |
| El bocadillo abre Social; el chat no tiene icono; el Buzón está en Servicios | 15 |
| Nuevo luchador: modal con nombre, tres desplegables y una figura; sin descripción, dificultad ni ataques | 5 |
| Estadísticas del jefe: icono suelto con ocho cifras | — |

Sin capturar (piden un estado concreto): equipar hechizos, esferas, el
informe del combate, subir de nivel, elegir carta, intercambio, crear
equipo o clan, paneles de demonio.

### Verificado

- Las dos pasadas del mapa terminan sin errores de script (54 capturas la
  cuenta nueva, 47 la de datos, combate incluido), antes y después de
  devolver el Menú; tras el arreglo llegan a Opciones y Replays desde el
  icono.
- `run_tests.sh --headless`: 1491/0.

### Siguiente

Con el mapa delante, decidir con el dueño la reorganización (puntos 5–8,
13, 15, 16), en preguntas cortas (modo Q&A).

## Reorganización 1 (2026-11-17)

Tres preguntas al dueño con el mapa delante; "sí a las tres, hazlo".

### 1. Reclutar, pantalla propia (puntos 3, 5 y 7)

- `src/ui/recruit_screen.gd`, como las referencias: las 12 clases con su
  retrato a la izquierda, sexo y modo encima (Historia / Élite y Torneos,
  con una línea que dice qué significa cada uno), el luchador grande en el
  centro con las flechas para girarlo, y en la hoja de la derecha la
  dificultad (estrellas), los roles, una descripción propia de la clase y
  sus 10 ataques (icono, PA, alcance, elemento). Nombre y «¡RECLUTAR!»
  abajo. Sustituye al modal: todas las entradas llegan aquí.
- **Entradas directas:** «Reclutar» de Historia, «Crear equipo» de Ranking,
  «¡A luchar!» y «Entrenamiento» sin luchadores de ese modo abren
  Reclutar en su modo. Con luchadores pero sin equipo, Equipo como antes.
- La pantalla espera la respuesta del servidor: un nombre rechazado se
  queda con el motivo; si sale bien se cierra y avisa "X se une a tu
  equipo (modo)".
- Las descripciones, dificultad y roles son míos (los datos no traían);
  el diseño visual lo pulió un agente Fable (regla del dueño).

### 2. Torneos en un solo sitio (puntos 8 y 13)

- El Calendario pasa a ser **Torneos**, con tres pestañas: **Mis torneos**
  (en los que estás, qué equipo juega, buscar rival y ver cuadro),
  **Calendario** (el de antes, para apuntarse) y **Clasificación** (la de
  torneos, que estaba en Clasificación).
- **Equipo pierde la pestaña Torneos**: un torneo clásico juega con el
  equipo de Élite elegido (el servidor acepta cualquier equipo clásico,
  `TestTournamentTeamKind`), que se elige en Torneos o en la loseta de
  Ranking. **Clasificación pierde la de torneos.**
- La loseta Torneos y la lista de la izquierda abren esta pantalla.

### 3. Iconos de arriba (puntos 15 y Estadísticas)

- **Estadísticas del jefe es una pestaña de Logros.**
- El icono de barras desaparece; en su sitio, **Amigos** (dos personas,
  nuevo en el atlas: `tools/make_lobby_bg.py --icons`, hueco 10) que abre
  Social. El **bocadillo abre el Buzón**, que sale de Servicios. Orden:
  Amigos, Buzón, Ayuda, Menú.

### Verificado

- `test/s47_smoke.gd` contra un servidor local en red aislada: **19/19**.
  Reclutar como Historia y como Élite (nombre vacío: aviso sin enviar;
  "1234": el servidor lo rechaza y la pantalla lo dice; nombre bueno: se
  cierra y el luchador está en el plantel con su tipo y clase), las tres
  pestañas de Torneos (la clasificación pide su tabla al servidor), Equipo
  solo con Historia y Élite, Clasificación sin torneos, Logros con
  Estadísticas (8 filas), Amigos → Social, Buzón → buzón con su lista,
  Menú → menú, sin icono de barras y sin Buzón en Servicios.
- `run_tests.sh --headless` 1492/0, `--visual` sin fallos (la escena de
  revisión incluye Reclutar: 12 clases, 10 ataques, botón dentro).
- Smokes en vivo pasados a los sitios nuevos y en verde: `modes_smoke`
  (Equipo: Historia y Élite), `colours_smoke` y `coach_turn_smoke` (la
  pantalla de reclutar crea y gira), `mailbox_smoke` (desde el icono),
  `story_smoke`, `tournaments_smoke` sembrado (10/10: buscar rival desde
  Mis torneos).
- `totems_smoke` falla 4/4, **igual en el commit anterior** (comprobado en
  una copia limpia): busca tótems y fuegos en Servicios, que se quitaron en
  S18/S26, y el icono Social por su texto. Smoke viejo, apuntado en BACKLOG
  §8.

### El mapa, después

`~/codigo/capturas/s47/mapa-despues/index.html` (49 pantallas, el de
antes sigue en `mapa/`), rehecho con `godot/tools/screen_map.sh`: las dos
pasadas sin errores de script.

## Punto 16 — el «Equipo» del luchador (2026-11-17)

El dueño: "sigue". Qué confundía, mirado en el código y en el servidor:

- **"Equipo" es a la vez *team* y *equipamiento*.** La pantalla de
  hechizos y cartas de un luchador se llamaba "Equipo del luchador" y su
  botón "Equipamiento y hechizos", al lado del panel Equipo (el plantel).
  Ahora se llama **Hechizos y cartas** (título, botón y pestaña "Cartas").
- **"Valor 1240 / 6000" no decía de qué.** El valor es lo que el servidor
  llama presupuesto: **600 de la clase + el valor de cada carta que lleva**
  (`computeFighterBudget`). El 6000 no es un tope por luchador sino del
  **equipo entero** (`maxTeamBudget`), y en Ranking el tope es el de la
  liga (Bronce 4000 … Diamante 6000). La pantalla dice ahora "Valor 800"
  y debajo "Valor = 600 de su clase + 200 de sus cartas = 800: cuanto más
  alto, más fuerte va. Tu equipo de Élite suma el valor de sus luchadores
  y no puede pasar del presupuesto de tu liga (Bronce: 4000)" (Historia:
  "no pueden pasar de 6000").
- **El valor se mueve al probar una carta** (antes era el guardado); se
  calcula igual que el servidor.
- **La tabla de Equipo tiene la columna Valor**, que es lo que suma la
  línea "presupuesto del equipo" de Élite.
- De paso: una línea con ajuste que se activaba después de entrar en el
  panel lo ensanchaba a 1807 px (se salía de la ventana); se crea ya
  ajustada. Pasaba también con la nota por modo de Equipo.

**Verificado:** `s47_smoke` 22/22 en vivo (el valor mostrado = el del
servidor, se mueve al probar una carta 800 → 700, el panel cabe en la
ventana), `loadout_smoke` 7/7, `native_panels` sin fallos,
`run_tests.sh --headless` 1492/0.

## Punto 1, primera parte — los ojos con el color del pelo (2026-11-17)

**Causa:** los coach de Meshy llevan una sola textura y el tinte de pelo va
por una máscara pintada por color (`tools/art/coach_masks.py`): todo
triángulo claro por encima del cuello empezaba "pelo". El blanco de los
ojos es claro y está por encima del cuello, así que la coach mujer teñía
los ojos con el pelo (y el hombre tenía manchas junto a un ojo).

**Arreglo:** un triángulo de la franja de la cara con iris (color saturado
que no es piel: el ámbar y el azul) es ojo; ni él ni sus vecinos muy
blancos (el blanco del ojo) pueden ser pelo. El resto igual: el hombre
queda con 839 triángulos de pelo (840 antes), la mujer con 707 (720: los
13 de los ojos). `build.py` rehace las máscaras al cambiar el script.

**Verificado:** `test/coach_face_preview.gd` (nuevo: las dos caras de cerca
con pelo verde y rojo), antes y después en
`~/codigo/capturas/s47/coach/ojos-antes.png` y `ojos-despues.png`;
`run_tests.sh --headless` 1492/0.

**Lo que queda del punto 1:** rehacer las mallas a ~40 000 triángulos
(hoy 5 000 por el pipeline de S35b) y los triángulos y mechones mal
pintados. Es arte: un paso, enseñarlo y esperar al dueño. Ojo con la demo
web (≤ 50 MB de primera carga, equipos de 4 GB): 8× triángulos en los dos
coach hay que medirlo.

## Punto 1, segunda parte — coach hombre a 40 000 triángulos (2026-11-18)

Dueño: "haz el coach hombre a 40k y enséñamelo", y "hagamos la prueba,
ya que tiene web, podemos hacer test de velocidad de carga".

- **El original de siempre tiene 20 861 triángulos** (un export "lowpoly"
  de Meshy), así que de él no salen 40k. El dueño generó uno nuevo:
  `~/codigo/capturas/s47/meshy-hd/coach_7000_m_hd.glb`, **610 242
  triángulos**, en pose en A y con tres texturas (color, normales,
  metal-rugosidad). También el de la mujer (676 936), sin tocar aún.
- **Cómo se construyó** (sin cambiar todavía `figures.json`):
  1. Reducción previa en Blender a 80 000 (el script en Python era
     inviable con 610k: 20 min sin acabar la limpieza; el modificador lo
     hace en 6 min): `meshy-hd/coach_7000_m_80k.glb`.
  2. `meshy_fighter.py --tris=40000 --menu=1 --weld_normals=1
     --lower_arms=10` sin `--joints` (las articulaciones guardadas son de
     brazos bajados; las detectadas encajan en la pose en A).
- **Cambios en el pipeline** (opcionales, las figuras de 5k no cambian):
  - `--lower_arms`: pesa en pose en A (los brazos quedan separados del
    cuerpo) y después baja los brazos a 10° de la vertical y fija esa
    postura como reposo; antes asigna al brazo los vértices que el pesado
    había dado al cuerpo (puntas de dedos, codos), que se quedaban flotando.
  - `--weld_normals`: una normal y unos pesos por posición, para que el
    contorno de tinta no se abra en picos en las costuras (con 21k se veían
    en el corte del brazo).
  - Las pasadas de suavizado de pesos crecen con la densidad (4 a 5k).
  - Solo se guarda la textura de color (el shader no lee las otras), y
    `coach_masks.py` lee la textura del color base, no la primera imagen.
- **Resultado:** 39 999 triángulos, 2,3 MB (antes 880 KB). Pelo mucho más
  definido, cara más fina, ojos limpios. Hoja:
  `~/codigo/capturas/s47/coach/coach-hombre-40k.png`.

### Prueba de carga web (Chromium, Playwright, GPU AMD)

`godot/tools/web/load_test.mjs`: sirve la exportación con gzip, red
limitada por perfil, mide hasta el login (marca nueva del juego en web:
`window.__pippop`), pulsa JUGAR y mide "Crea tu jefe" (memoria PSS del
navegador y fotogramas).

| | 5k (hoy) | 40k (nuevo) |
|---|---|---|
| Paquete `boot` | 25,04 MB | 25,90 MB |
| Primera carga por la red | 36,6 MB | 37,5 MB |
| Hasta el login, 4G | 366 s | 396 s |
| Hasta el login, fibra | 299 s | 350 s |
| De JUGAR a "Crea tu jefe" | 29 s | 34 s |
| Memoria en "Crea tu jefe" | 715 MB | 709 MB |
| Fotogramas en "Crea tu jefe" | 3,8 | 4,0 |

**Los tiempos absolutos no valen:** la Ally estaba cargada por otros
procesos (un servidor Java en contenedor y una compilación Gradle, carga
media 26 con 16 núcleos), y la descarga y la descompresión del wasm van por
CPU. La comparación sí: misma máquina y mismo momento. El coach nuevo suma
**0,9 MB** a la primera carga, la memoria no cambia y los tiempos crecen
entre un 8 y un 17 %. Pendiente: repetir con la máquina libre o en
oracle-2 para tener tiempos reales.

**Pendiente del dueño:** adoptarlo (receta nueva en `figures.json` y subir
el tope de `check.py`, hoy 5 000) y hacer la mujer igual.

## Punto 4 — el tutorial guiado (2026-11-18)

Dueño: "sigue con los otros puntos" (las preguntas de diseño quedaron sin
responder; decidido con criterio, aquí el porqué).

- **La guía es la cadena de "Primeros pasos" que ya existía** (los seis
  logros del tutorial, `Scenarios.TUTORIAL_STEPS`), así que el servidor ya
  sabe en qué paso va cada jefe y no hay estado nuevo que guardar.
- **Una tarjeta en el lobby**, bajo la lista de la izquierda: "GUÍA · PASO
  N DE 6", qué hacer en una línea y **IR**, que lleva a la pantalla
  (Servicios → Aprendizaje; Reclutar en modo Historia; Historia). Un **aro
  coral late** alrededor del botón real que usa ese paso. Con la cruz se
  oculta (se guarda en las preferencias) y **Ayuda → Empezar** la vuelve a
  mostrar. Al terminar los seis pasos desaparece.
- La intro de 12 páginas sigue igual: ya se puede cerrar con "Cerrar", y
  acortarla es contenido del dueño (BACKLOG §13).

**Verificado:** `test/guide_smoke.gd` en vivo, 6/6 con un jefe nuevo (paso
1, aro en Servicios, IR abre Servicios, ocultar/mostrar) y 6/6 con `test`
(paso 3, aro en la loseta Historia, IR abre Historia). Capturas en
`~/codigo/capturas/s47/guia/`. `run_tests.sh --headless` 1492/0.

## Punto 12 — el inventario, primera pasada (2026-11-18)

- `src/ui/inventory_screen.gd`: pantalla propia en lugar del modal.
  **Cartas:** a la izquierda para qué sirven (con cuántas tienes de cada
  tipo), la búsqueda, el orden y "Equipo del coach"; en el centro las
  cartas; a la derecha la elegida en grande, qué hace, para qué sirve, su
  colección ("tienes 3 de 8"), copias y valor, y "Ponérsela al jefe" si es
  equipo del coach. **Colecciones:** un álbum: cada colección con su
  barra y sus cartas en pequeño (las que faltan, apagadas), las más cerca
  de completarse primero; Empezadas / Completas / Todas; la elegida dice
  sus bonus y qué falta.
- **Verificado:** `inventory_smoke` 6/6 en vivo (todas, equipo del coach,
  para qué sirve, por valor, álbum, elegir colección);
  `run_tests.sh --headless` 1493/0.

## Punto 12 — pasada de diseño del inventario (2026-11-18)

Dueño: "usa opus 5.5 en esfuerzo alto, creo que fable sería demasiado";
la pasada la empezó un agente Fable y la terminó y verificó uno de Opus.

- **Orden:** tres botones inclinados (Nombre / Valor / Cantidad), como los
  de sexo y modo de Reclutar, en lugar del desplegable antiguo.
- **La ficha de la derecha se desplaza**, con un degradado y un chevrón
  coral al pie mientras queda texto debajo; el título encoge (30 → 20) en
  vez de cortarse. "Ponérsela al jefe" queda fijo abajo a la derecha.
- Filtros sobre una losa con cinta coral y cuentas en oro, búsqueda
  enmarcada, tipo de carta como medallón con rombos de rareza; en el álbum
  cada colección es una losa con su barra, en oro y con destello si está
  completa.
- `style_b.gd` recoge `ribbon()`, `choice()` y `draw_slab()` (salen de
  `recruit_screen.gd`); `hero_panel.gd` gana `harden_sheet()` y el aviso de
  "hay más abajo", que también usa el Equipo del coach.
- Arreglado: la pista sin carta elegida era una línea sin ajuste que
  empujaba la ficha fuera de la pantalla.

**Verificado:** `inventory_smoke` 12/12 a 1280×720 y 12/12 a 1920×1080
(escala ×1,5), `s47_smoke` (Reclutar) 22/22 e idéntico píxel a píxel a la
base fuera de la figura, `run_tests.sh --headless` 1493/0. El smoke usa una
copia de la base con las cartas 409, 137 y 316 sembradas. Capturas en
`~/codigo/capturas/s47/inventario/`.

## Dónde retomar (contexto nuevo)

1. ~~Inventario, pasada de diseño~~ hecha (arriba); falta la opinión del
   dueño.
2. **Iconos repetidos (11):** ilustraciones propias por familia (Fable +
   vex o kiln), BACKLOG §13.
3. **Coach mujer a 40k** (al final, dueño): el original está en
   `~/codigo/capturas/s47/meshy-hd/coach_7001_f_hd.glb` (676 936 tris);
   mismo método que el hombre: reducción previa a 80k con
   `predecimate`, luego `meshy_fighter.py --tris=40000 --menu=1
   --weld_normals=1 --lower_arms=10 --arm_slack=0.06` (sus opciones de
   `figures.json`; `--cut` probablemente sobra en pose en A).
4. **Adoptar los coach de 40k** cuando el dueño diga: receta en
   `figures.json` (src nuevo, opciones), `check.py` FIG_TRIS para los
   coach, y medir el panel Equipo del coach con GPU.
5. **Repetir la prueba de carga web** con la Ally libre
   (`tools/web/load_test.mjs`; la marca `window.__pippop` ya está).
6. Lo que queda de la auditoría web: W2 (móvil vertical), W4–W7, W9.
