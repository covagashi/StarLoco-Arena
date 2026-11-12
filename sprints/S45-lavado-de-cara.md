# S45 — Lavado de cara de la interfaz

**Planificado:** 2026-11-12 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (fase 1 hecha, 2026-11-12)

## Por qué

Dueño, 2026-11-12: "la interfaz actual es muy tosca, quería hacerle un lavado
de cara". La de hoy (`ui_style.gd`, piedra oliva y oro desde 2026-10-24) pone
marcos dentro de marcos, texto pequeño y todo con el mismo peso.

## La dirección (maqueta)

Maqueta: https://claude.ai/artifact/22QtzoocwYafanHDKGBpcX (seis pantallas a
1280×720 con arte real del juego: inicio de sesión, crea tu coach, lobby,
equipo del coach, combate, sistema visual).

- Primera versión: el dueño la vio "muy ai slop, menos el gui del combate. Hay
  que dar sensación de juego, no una web", con trece referencias de juegos.
  La maqueta de la v16b (servidor Demonis) era solo un ejemplo de lo fresco,
  "no lo quiero clavado".
- Segunda versión: "ahora mejor, habría que mejorar un poquito las cosas pero
  mejor".

Lo que queda decidido:
- El arte manda: el coach y los luchadores en grande, la arena 3D de fondo.
- Material de juego: borde de tinta de 3 px y sombra dura (no difusa), títulos
  en Lilita One con contorno, Nunito en negrita para leer, cintas con muesca,
  papel con pespunte para formularios y fichas, medallones redondos, engarces en
  rombo, botones en relieve con labio y la acción principal inclinada.
- Menús como losetas ilustradas cortadas en diagonal (Historia, Ranking,
  Torneos), no tarjetas de texto.
- Monedas en cápsulas con "+"; riel de medallones con nombre a la izquierda.
- Combate: el HUD de la maqueta (línea de turnos en círculos con anillo azul o
  rojo arriba, "¡Te toca!", retrato con la vida en anillo y medallas de PA/PM,
  barra de hechizos flotante con su coste, ficha al pasar el ratón, "Pasar
  turno" grande).
- Colores: noche `#12152A`, pop `#FF6B3D` solo para la acción, sol `#FFC247`
  para premios, azul aliado, rojo rival, verde aceptar; tinta `#0B0D1C`.

## Fases

Cada fase se enseña al dueño (capturas en `~/codigo/capturas/s45/`) antes de
la siguiente.

0. **Ajustes de la maqueta.** Lo que el dueño quiera "mejorar un poquito",
   sobre la propia maqueta, antes de tocar el cliente.
1. **Base.** Fuentes Lilita One y Nunito (OFL) en `godot/assets/ui/fonts/`,
   con su licencia y en `CREDITS.md`. `ui_style.gd` v2: paleta, contorno de los
   títulos con el outline de la fuente, y las piezas (botón en relieve, cinta,
   papel, medallón, rombo, cápsula) como texturas 9-slice de un generador
   propio (`tools/make_ui_kit.py`, como los fondos de hoy), sin imágenes a mano.
   Los 21 archivos que usan `UiStyle` toman el estilo nuevo sin tocarlos uno a uno
   donde se pueda.
2. **Pantallas completas.** Inicio de sesión, crea tu coach y lobby como en la
   maqueta; las ilustraciones de las losetas salen de renders del juego
   (`anim_sheet.gd`, arenas), no dibujadas.
3. **Paneles.** La base de los paneles (`lobby_panel.gd`) pasa a hoja de papel
   con cinta; equipo del coach como pantalla de héroe; después los demás
   paneles (inventario, equipo, ranking, kanodo, torneos, correo…), por tandas.
4. **Combate.** El HUD de la maqueta en `fight_hud.gd` y `fight_view.gd`.
5. **Cierre.** Smokes con capturas de cada pantalla, `run_tests.sh` (también el
   carril de 800×600) y el peso para la demo web (S44: ≤ 50 MB de primera
   carga, móviles de 2 GB).

## Progreso

### Fase 0 — a la espera del dueño

Lo que quiera "mejorar un poquito" de la maqueta no está dicho todavía. Por
heurística (sprints autónomos) no bloquea la fase 1: la base (fuentes, paleta,
piezas) no depende de esos retoques, y lo que el dueño pida se aplica encima.

### Fase 1 — base (2026-11-12) ✅

- Fuentes: `godot/assets/ui/fonts/LilitaOne-Regular.ttf` y
  `Nunito-Variable.ttf` (OFL 1.1, de github.com/google/fonts, con sus
  `OFL-*.txt`), en `godot/art/CREDITS.md`; `tools/art/check.py` también exige
  el crédito de las fuentes de `assets/ui/fonts/`. De paso salen dos fuentes
  retail de las pantallas (TAHOMA y COPRGTB quedan solo como reserva si no
  están las nuestras, y en el combate hasta la fase 4).
- `tools/make_ui_kit.py` dibuja las piezas en `godot/assets/ui/kit/` (27 PNG,
  ~60 KB): botón en relieve con labio en pop, azul noche, verde y sol (normal,
  encima, pulsado, apagado), la acción principal inclinada, campo hundido,
  ventana, ficha, papel con pespunte y rayado, cinta, medallón y cápsula; y el
  fondo noche `assets/ui/ui_bg.png` (sustituye la piedra).
- `ui_style.gd` v2: paleta de la maqueta con los nombres de siempre (INK sigue
  siendo el texto, PAPER el relleno…), así que los 21 ficheros que usan
  `UiStyle` cambian sin tocarlos. Nuevo: `kit()`, `button_box()`, `field()`,
  `paper()` y `title()` (Lilita con contorno y sombra dura). Botones y
  desplegables en Lilita con contorno; el texto, Nunito 800; las etiquetas,
  Nunito 900 espaciada. Sin el kit, cajas planas en la misma paleta.
- Títulos de login, creación y de cada panel con `UiStyle.title()`.

**Decisión (heurística):** en esta fase las ventanas son de noche azul con
texto crema, no de papel. Pasar los paneles a papel obliga a cambiar el color
del texto de cada uno (crema → tinta), y eso va por tandas en la fase 3; hacerlo
aquí de golpe dejaría texto ilegible en los paneles que no se revisen.

Evidencia: `run_tests.sh --headless` → `suites=22 checks=1463 failures=0`;
`ui_review_preview` a 1280×720 sin fallos, 17 capturas antes/después en
`~/codigo/capturas/s45/antes/` y `~/codigo/capturas/s45/fase1/`.

### Corrección del dueño (2026-11-12)

Al ver la fase 1: "no se parece nada al artefacto". Tenía razón: la fase 1
solo cambió colores y piezas sobre la composición vieja (cajas centradas),
y lo que define la maqueta es la composición: el arte en grande, la arena de
fondo, el papel inclinado con su cinta. **Regla desde aquí: cada pantalla se
compara lado a lado con la maqueta renderizada** (la maqueta se renderiza en
local con el chromium headless de Playwright a partir de los `.dc.html`) y no
se enseña hasta que se parece.

### Fase 2 — pantallas completas

- **Inicio de sesión ✅ (a revisar por el dueño).** Como la maqueta: la arena
  en 3D de fondo con su viñeta y el brillo cálido, el coach y dos luchadores en
  grande, PIPPOP en cinta y ARENA en sol con destellos, el medallón del idioma
  arriba a la derecha (abre los tres idiomas) y a la derecha la hoja de papel
  inclinada 1,5° con el borde perforado, la cinta "¡A LA ARENA!", los campos
  de papel, el servidor como chip verde y CONECTAR. Las imágenes son renders de
  nuestro juego (`godot/art/ui/renders/`, sacados para la maqueta) que
  `tools/make_ui_scene.py` pasa a `assets/ui/scene/` con la sombra horneada.
  Captura lado a lado: `~/codigo/capturas/s45/fase2/login-maqueta-vs-juego.png`.
  Fuera de momento: "Recordar la cuenta", "Crear una cuenta" y "¿Olvidaste la
  contraseña?" (el cliente no los tiene; serían funciones nuevas) y el
  "Demo · v0.37".
- **Crea tu coach ✅.** Escenario con foco, cabecera (medallón atrás + tira
  pop; conecta por fin la señal `closed`, que nada emitía), tres rombos de
  sección (cuerpo, pelo, piel), el coach 3D en grande sobre pedestal con los
  chevrones que lo giran, el nombre escrito sobre la cinta, la hoja de papel
  con cinta azul y gemas de color (o sexo), "Al azar" y "¡CREAR!".
- **Lobby ✅.** Arena de fondo y el coach grande; arriba a la izquierda nivel
  y nombre en cinta; arriba al centro la temporada (60031); arriba a la
  derecha fichas y pesetas (la cartera, que ahora llega al modelo como
  `wallet`) y Estadísticas, Social y Ayuda como medallones; a la izquierda el
  riel de medallones de los seis paneles; a la derecha las losetas
  ilustradas cortadas en diagonal (la loseta entera es su botón, con la acción
  real en la píldora; el equipo de Ranking como chip desplegable;
  Entrenamiento, Contra un fantasma y Ver torneos en su loseta; lo que gana y
  su aviso, en el tooltip) y "¡A LUCHAR!" (Ranking directo). La búsqueda es
  una hoja de papel con el reloj, Cancelar y la oferta de fantasma. Chat
  abajo a la izquierda.
  Decisiones: sin "+" en las monedas (no hay tienda todavía: S30) ni correo
  en la barra (sigue en Servicios), para no dejar botones muertos.

### Fase 3 — paneles ✅ (a revisar)

- La base de todos los paneles (`lobby_panel.gd`) es la hoja de papel con
  la cinta del título, "?" y cerrar como medallones en la esquina y el pie
  en papel más oscuro; tema `UiStyle.paper_theme()` (texto tinta, campos y
  tablas de papel, botones azules en relieve). Los colores puestos a mano en
  los paneles pasan a su versión sobre papel (`BROWN`, `ACCENT_INK`); las
  cartas siguen azules sobre el papel, como en la maqueta.
- **Equipo del coach** es pantalla de héroe (`hero_panel.gd`): el coach en
  pedestal con lo que lleva el borrador puesto, los 12 huecos como rombos con
  su carta, la hoja con las cartas del hueco, "Deshacer" y "LLEVAR PUESTO".
  Sin las pestañas Sets/Aspecto de la maqueta (no existen).

### Fase 4 — combate ✅ (a revisar)

- `fight_hud.gd`: el orden de turno arriba en una píldora (el que juega
  primero y más grande, su reloj en insignia y un aro que se agota; los demás
  con el aro de su equipo, que es su vida; KO en gris), "¡Te toca!" en pop o
  de quién es el turno en azul, y la ficha crema al pasar el ratón. Azul
  siempre somos nosotros, rojo el rival. Se van las columnas laterales.
- `fight_medallion.gd`: retrato grande con la vida en aro, PA y PM en
  medallones, nombre, vida y hasta tres efectos.
- `fight_view.gd`: "Pasar turno" en píldora pop con su tecla, la barra de
  hechizos en una píldora oscura con el coste en insignia azul, el menú en
  botones redondos con icono. A 800×600 la barra sube una fila.
  El tema del combate ya no sale de los paneles (ahora de papel).

### Giro de estilo (dueño, 2026-11-12)

Tras la fase 4 y el acabado de pergamino: "usaría un poco más el estilo glass
o el estilo japonés… lo que tú estás haciendo es más estilo
cartoon-supercell", y "meter el mismo mapa de fondo para todo" no. Hoja de dos
opciones del lobby (`~/codigo/capturas/s45/estilos/`): A glass, B japonés.
**Elegida la B** (placas oscuras cortadas en diagonal con línea blanca,
títulos en cursiva condensada con etiquetas pequeñas, menú como lista, acento
coral), **con fondos propios por pantalla, sin reciclar arenas**. El dueño
ofrece referencias de Pinterest para los fondos. Herramientas en la mesa:
vex y AniCraft (editor de animación vectorial con CLI y MCP).

## Fuera
### Giro de estilo (dueño, 2026-11-12)

Tras la fase 4 y el acabado de pergamino: "usaría un poco más el estilo glass
o el estilo japonés… lo que tú estás haciendo es más estilo
cartoon-supercell", y "meter el mismo mapa de fondo para todo" no. Hoja de dos
opciones del lobby (`~/codigo/capturas/s45/estilos/`): A glass, B japonés.
**Elegida la B** (placas oscuras cortadas en diagonal con línea blanca,
títulos en cursiva condensada con etiquetas pequeñas, menú como lista, acento
coral), **con fondos propios por pantalla, sin reciclar arenas**. El dueño
ofrece referencias de Pinterest para los fondos. Herramientas en la mesa:
vex y AniCraft (editor de animación vectorial con CLI y MCP).

## Fuera

- Las ilustraciones de las cartas y los iconos de hechizos: S38, ya con este
  estilo (los de la maqueta son provisionales).
- La tienda (S30): aquí solo las cápsulas de monedas con su "+".

## Criterio de cierre

Ninguna pantalla ni panel usa ya el estilo de piedra y oro; el dueño ha visto
las capturas de todas y las da por buenas.
