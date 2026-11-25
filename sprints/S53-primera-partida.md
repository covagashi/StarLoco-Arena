# S53 — La primera partida, de verdad

**Planificado:** 2026-11-25 · **Hito:** M5 — Release · **Tamaño:** L · **Estado:** 📝 redactado, a la espera del dueño

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

## Preguntas para el dueño

1. **Arena 2:** ¿la que ves corrupta es la del grid verde con vallas de
   madera (la captura), o la de otra partida? ¿Cuál es tu fichero bueno?
2. **Tutorial:** ¿te vale el orden *jefe → reclutar → combate contra el
   muñeco → fin*, o quieres el combate antes de reclutar (con un luchador
   prestado)?
3. **Dispositivo del error de conexión:** ¿iPhone, iPad o Mac con Safari?
