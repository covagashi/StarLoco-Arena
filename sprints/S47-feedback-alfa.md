# S47 — Feedback de la alfa (dueño, 2026-11-16)

**Planificado:** 2026-11-16 · **Hito:** M7 / M5 · **Tamaño:** L · **Estado:** 🟡 en curso — tanda 1 de arreglos hecha (2026-11-17, abajo); queda la reorganización de pantallas, las mallas, el tutorial y el inventario

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
