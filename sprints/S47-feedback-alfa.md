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
