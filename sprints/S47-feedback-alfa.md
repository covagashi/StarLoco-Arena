# S47 — Feedback de la alfa (dueño, 2026-11-16)

**Planificado:** 2026-11-16 · **Hito:** M7 / M5 · **Tamaño:** L · **Estado:** ⚪ por empezar — solo apuntado, el dueño pidió no arreglar aún (poco % de sesión)

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
