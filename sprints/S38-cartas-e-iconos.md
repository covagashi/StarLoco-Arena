# S38 — Cartas, iconos e interfaz

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** L · **Estado:** 🔵 en curso (retratos hechos, 2026-11-13)

## Alcance

- Ilustraciones de carta: hoy ~960 (equipo del coach y del luchador). No se
  pueden dibujar una a una: plantilla de carta (marco por tipo y rareza) +
  ilustración por **familia** o por set, iconos por slot, y solo arte propio
  para las especiales.
- Iconos de hechizo (167), de equipo de luchador (151), de logros, de fichas
  y pesetas, de clases (timeline y retratos).
- **Retratos del combate desde la figura 3D** (dueño, 2026-11-11: "en el
  círculo del pj actual aún sale el retail, y en las cartitas de los turnos
  también"): el medallón del luchador activo y las cartas de la línea de
  turnos, renderizados del modelo 3D de cada clase/sexo e invocación (cabeza
  y hombros, con la luz del juego), no los PNG retail
  (`gui/images/...`).
- Retratos de NPC (Nilo, Aldebrán, Demonio I) y de los Señores del Tiempo.
- Fuentes propias o libres (hoy Copperplate y Tahoma retail).
- Lo que queda de imágenes retail en los paneles nativos.

## Criterio de cierre

Ningún panel muestra una imagen retail; `gui/` retail se puede borrar.

## Desde S45 (2026-11-12)

Las fuentes y el material de la interfaz van en S45 (Lilita One + Nunito,
tinta, cintas, papel). Aquí, las cartas y los iconos se dibujan ya con ese
estilo: borde de tinta y sombra dura.

## Progreso

### Retratos del combate ✅ (2026-11-13)

`tools/portraits/portraits.tscn` renderiza cada figura 3D (24 luchadores, los
2 coaches y las 9 invocaciones) sobre fondo transparente, busca su contorno
y corta un cuadrado: cabeza y hombros en los humanoides, el cuerpo entero en
las invocaciones. Salen 35 PNG de 160 px (1,1 MB) en
`godot/assets/ui/portraits/`, con su fila en `art/CREDITS.md`.
`FighterCard.portrait_for()` los lee antes que el arte retail, así que el
medallón del luchador activo y la línea de turnos ya no enseñan el retail
(lo que pidió el dueño el 2026-11-11). Un coach en combate (raza 7000/7001)
también tiene el suyo.
Evidencia: `fight_ui_preview` a 1280×720 con los retratos nuevos;
`run_tests.sh --headless` 1525/0; `tools/art/check.py` 0 fallos.

### Iconos de hechizo: hoja de opciones (2026-11-13, a la espera del dueño)

Piloto con los 10 hechizos del Yopuka, un dibujo propio por hechizo (no por
forma de efecto: con forma + elemento saldrían 35 auras neutras iguales) y
tres maneras de ponerlo en el estilo B: A trazo de tinta sobre el pálido del
elemento, B blanco sobre el color del elemento, C tinta sobre blanco con una
banda del elemento; abajo, B en la barra del combate a su tamaño. Hecha con
`godot/tools/icons/spell_icon_options.py` (dibujo a código, sin imágenes a
mano). Por la regla del arte (una cosa, enseñarla, esperar) no sigo con las
otras 11 clases hasta que el dueño elija.

### Iconos de hechizo ✅ (2026-11-13, dueño: "b")

`tools/icons/spell_icons.py` dibuja los 120 hechizos de los datos de hoy y la
casilla del arma: un pictograma propio por hechizo (escudo con rayo, reloj,
dado, trébol, flecha con diana…) en blanco sobre el color de su elemento,
cortado en diagonal, con la regla de tinta arriba. 840 KB en
`godot/assets/ui/spells/`, con su fila en `art/CREDITS.md`. La barra del
combate y la ficha de hechizos de los paneles los leen antes que el retail;
la casilla del hechizo ya solo los enmarca. Hoja de los 120 para el dueño: "me parecen bien" (2026-11-13).
Evidencia: `fight_ui_preview` con la barra nueva, `run_tests.sh --headless`
1525/0, `tools/art/check.py` 0 fallos.

### Iconos de equipo del luchador ✅ (2026-11-13)

Los 75 equipos de luchador de los datos (no 151: es lo que hay en
`fightercards.json`) salen de nuestras piezas 3D (S35c): `tools/icons/
equip_icons.tscn` renderiza cada pieza en un estudio (tres cuartos, el
sombreado toon con el contorno medido a esa cámara, fondo transparente) a
`art/ui/out/equip/` (construido, fuera de git), y `tools/icons/
equip_icons.py` la pone en la placa B con el tinte pálido de su hueco (arma,
mascota, capa, sombrero, dofus); las armas largas, en diagonal. 664 KB en
`godot/assets/ui/equip/`. `UiStyle.fighter_card_art()` y la barra del
combate (cartas activas) los leen antes que el retail. Hoja para el dueño.

### Iconos del equipo del coach ✅ (2026-11-13, dueño: "sí, me gusta la estética")

Las 196 cartas del coach ya tienen icono propio en
`godot/assets/ui/equip_coach/` (2,2 MB), y `UiStyle.card_art()` los lee antes
que las ilustraciones retail (inventario, Equipo del coach, correo). Las 92
piezas sueltas salen como las del luchador. Las 104 prendas:
`tools/icons/garment_icons.tscn` congela la pose del coach, lo renderiza
desnudo una vez (`_bare.png`) y luego con cada prenda sola, a cuadro entero,
sin que la prenda proyecte sombra (su sombra sobre la piel cambiaba la banda
del toon y contaba como prenda); `equip_icons.py --coach` se queda con la
diferencia como contorno de la prenda, corta a su cuadrado y deja el cuerpo
alrededor en gris pálido (sin la sombra del suelo). Las 13 marcas eran unos
pocos píxeles, muchas en la espalda o en la cara de dentro del brazo: su icono
es el emblema (`tools/art/mark_emblems.py`) sobre un parche de piel. Figura
subida 40 px para que las botas no se corten en el borde del cuadro.
Regenerar: `equip_icons.tscn -- --coach`, `garment_icons.tscn`,
`equip_icons.py --coach`.
Evidencia: `run_tests.sh --headless` 1525/0, `tools/art/check.py` 0 fallos,
`screens_smoke` contra el servidor local: equipo del coach 5/5 (puesto al
entrar, inventario, panel, cambio de sombrero, devolverlo); los 2 fallos del
Kanodo son del estado de la cuenta `test` (ninguna esfera a su alcance), no
de esto. Hoja y capturas en `~/codigo/capturas/s38/`: `equipo-coach.png`,
`equipo-coach-panel.png`, `equipo-coach-inventario.png`. Nota: la vista
grande del inventario estira el icono de 96 px a ~270; si se ve blando, subir
`PX` para el coach. Hoja vista y aprobada por el dueño el mismo día.

### Logros, fichas y pesetas: hoja de opciones (2026-11-13; dueño: B para los dos)

`godot/tools/icons/badge_icon_options.py` (dibujado en código). Logros: un
pictograma por categoría de los datos (`cat` de npcdialogs.json: 1 combate
—pilares de clase y rachas—, 3 torneos, 5 hazañas, 6 colección, 8 progreso),
el grado de hoy (puntos / 5, de 1 a 5) como metal (bronce, plata, oro, rubí,
cristal, en lugar del oliva/cobre/plata/oro/cristal del retail) y un candado
mientras está pendiente, como el retail. Tres maneras: A la placa inclinada
de los hechizos en el metal del grado, B medallón (borde de metal, centro del
color de la categoría), C escarapela (disco de metal, cintas de la
categoría); a la derecha, cada una en la fila de la lista a su tamaño (52 px).
Fichas (tipo 1, 845 cartas) y los tipos 2, 3 y 5 (pocas cartas) con una
estrella, y pesetas (tipo 10, hoy solo texto) con la P cruzada, en tres
monedas: A ficha plana con muescas, B moneda de tres cuartos, C ficha
hexagonal; debajo, junto a una cantidad, al tamaño de las cartas y la barra
de arriba. Hoja: `~/codigo/capturas/s38/logros-fichas-opciones.png`. Por la
regla del arte no sigo hasta que el dueño elija.

### Logros, fichas y pesetas ✅ (2026-11-13, opción B)

El dueño eligió B para los dos ("en 2026 se lleva más el estilo B").
`tools/icons/badge_icons.py` hace 26 medallones en `godot/assets/ui/
achievements/` (`<cat>_<grado>.png` de las 5 categorías y `pending.png`, el
candado gris; 320 KB) y 5 monedas en `godot/assets/ui/tokens/` (40 KB). Las
monedas llevan la cara más ancha y el canto más fino que en la hoja, para
que la marca se lea a 26–28 px; la peseta es una P con una raya corta en el
palo (la raya entera la hacía parecer un martillo a ese tamaño).
Conectado: `main.gd` da a cada logro su medallón (o el candado si falta);
`UiStyle.token_icon()` (nuevo, lo usan las cartas, el Card Master, el correo
y la fusión) lee la moneda nuestra antes que la retail, así que las pesetas
ya tienen icono en lugar de texto; la barra de arriba del lobby enseña la
moneda junto a fichas y pesetas.
Arreglos de paso: (1) el nombre de los logros no se veía en las fichas
oscuras de la lista (tinta sobre azul noche): ahora crema, y tinta solo en
la elegida; (2) la temporada centrada chocaba con las fichas al ganar ancho
la moneda: ahora se aparta a la izquierda si centrada tocaría las monedas,
y la entrada animada de la barra solo mueve en vertical (movía también en
horizontal, a la posición vieja, y deshacía el apartado).
Evidencia: `run_tests.sh --headless` 1525/0, `tools/art/check.py` 0 fallos,
contra el servidor local `achievements_smoke` 3/3 y `cardmaster_smoke` 6/6
(compra y trueque de verdad en la cuenta `test`). Capturas en
`~/codigo/capturas/s38/`: `b-lobby.png`, `b-achievements.png`,
`b-achievements-detail.png`, `b-cm-catalogue.png`.

### Retratos de NPC: primera prueba con Nilo (2026-11-13, a la espera del dueño)

Ningún NPC del diálogo (Nilo, Aldebrán, Demonio I, Demonio III) tiene figura
3D, y el dueño no tiene crédito en Meshy: "hazlo con vex". Nilo primero
(regla del arte: uno, enseñarlo, esperar), en
`godot/tools/portraits/npc_portraits.vx.js`: dibujo nuestro sobre la forma
del retrato retail (cuernos de carnero con triángulos de oro, dos rizos
pálidos en la coronilla, gafas moradas, cejas blancas en sierra, bigote
largo, orejas en punta, bastón con piedra naranja), estilo B: contorno de
tinta, tinta fina entre piezas, dos tonos por material, luz arriba a la
izquierda; 170 × 200 unidades, el `FACE_SIZE` de `talk_panel.gd`. Hoja:
`~/codigo/capturas/s38/npc-nilo.png` (retail, el nuestro grande y a su tamaño
en la ventana). Aún sin conectar: si gusta, salen los otros tres igual,
`--scales 2` a `assets/ui/portraits/npc/` y los `FACE_*` de `main.gd` pasan a
`{"image": …}`.
Segunda propuesta (el dueño pidió un agente Fable con vex): `godot/tools/
portraits/nilo_fable.vx.js`, con más acabado (sombra con luz de borde,
párpados a media asta y media sonrisa, una ceja alzada, barba, aro de oro,
copa de garras en el bastón, el puño en la cadera). Hoja para elegir:
`~/codigo/capturas/s38/npc-nilo-comparar.png` (retail, el mío, el de Fable,
grandes y a su tamaño).
Dueño: "fable" (2026-11-13). Nilo conectado: `assets/ui/portraits/npc/
nilo.png` (la exportación ×2, 340 × 400) y `FACE_NILO` pasa a
`{"image": …}`; el marco de la cara en `talk_panel.gd` es ahora una placa
clara con borde de tinta (sobre el azul noche el contorno de tinta del
retrato desaparecía). `nilo_smoke` pide ya una imagen y no la animación
retail: 5/5 contra el servidor local. Mi versión
(`npc_portraits.vx.js`) borrada. Aldebrán, Demonio I y Demonio III: tres
agentes Fable en paralelo con `nilo_fable.vx.js` de guía de estilo; el
Demonio III no tiene arte retail (el juego enseñaba la ilustración de un
desafío, una oveja), así que se diseña como hermano del Demonio I, con su
"III". Captura: `~/codigo/capturas/s38/b-nilo-dialogo.png`.
Los tres hechos (`aldebran_fable.vx.js`, `demon1_fable.vx.js`,
`demon3_fable.vx.js`, mismos ayudantes y lienzo que Nilo). Aldebrán: el
gran sombrero greñudo con ramas, cara de pelo blanco, ojos con brillo de
estrella, bolsa naranja y un amuleto de estrella. Demonio I: los dos cuernos
altos de pluma, calavera con llamas cian, ojos rosa encendidos, sonrisa de
colmillos, la "I". Demonio III (diseño nuevo, misma especie que el I): verde
azulado, tres penachos por el "III", un reloj de arena en la coronilla, cejas
severas y media sonrisa con un colmillo, manos juntas sobre la niebla. Hoja
de los cuatro: `~/codigo/capturas/s38/npc-los-cuatro.png`.

### Retratos de NPC ✅ (2026-11-13, dueño: "ok hazlo")

Los cuatro en `godot/assets/ui/portraits/npc/` (exportación ×2, 340 × 400) y
`FACE_ALDEBRAN`, `FACE_DEMON1`, `FACE_DEMON3` pasan a `{"image": …}`: la
ventana de diálogo ya no enseña las animaciones retail ni la oveja del
desafío. Evidencia contra el servidor local: `talk_smoke` 7/7 (Demonio III
en la oferta del desafío), `nilo_smoke` 5/5, `narrator_smoke` 5/5 (ahora
con captura del Demonio I), Aldebrán forzado con el escenario 0 (su
presentación del tutorial, ya leída en la cuenta `test`): cara = la
imagen. `tutorial_smoke` 6/10, los mismos 4 fallos sin este cambio
(comprobado con `git stash`): son del estado de la cuenta `test` (la
presentación ya leída, luchadores ya reclutados, primeros pasos hechos).
`run_tests.sh --headless` 1525/0. Capturas en `~/codigo/capturas/s38/`:
`b-nilo-dialogo.png`, `b-aldebran-dialogo.png`, `b-demonio1-dialogo.png`,
`b-demonio3-dialogo.png`. Si algún día se animan: con AniCraft (dueño), aún
sin instalar.
De paso, las fichas de Servicios → Aprendizaje: Nilo tiene ya su cara, los
maestros de clase el retrato nuestro de su clase (`ui/portraits/<clase×10>`,
antes `fightTimeline` retail) y el Demonio III el suyo (antes la oveja).
`tutorial_smoke` "learning" OK; captura `b-aprendizaje.png`.

### La ventana de diálogo, rehecha (2026-11-13)

Dueño: "el diálogo me parece un poco raro, ¿toda la pantalla blanca para ese
poco texto? mira las imágenes de referencia" (las de S45: personajes grandes
que llevan la pantalla, placas pequeñas al lado). `talk_panel.gd` ya no usa
la hoja de los demás paneles: el lobby se ve detrás bajo un velo claro, quien
habla está de pie y grande a la izquierda hasta el borde de abajo (un retrato
cuadrado, como el de un maestro de clase, va en un medallón), lo que dice
va en una placa abajo que crece con el texto hasta 330 de alto (medido con la
fuente: en la reconstrucción la etiqueta aún no tiene ancho), su nombre en
una cinta de tinta con raya coral y quién es al lado, las respuestas en una
columna a la derecha sobre la placa (placas blancas inclinadas, coral con el
foco) y Siguiente / Aceptar / Cerrar en la esquina. Sin cara, la placa ocupa
el ancho. Entrada: el personaje entra desde la izquierda y la placa sube.
El maestro de clase usa ya nuestro retrato de su clase. Evidencia:
`nilo_smoke` 5/5, `talk_smoke` 7/7, `narrator_smoke` 5/5, Aldebrán forzado
1/1, `tutorial_smoke` con sus 4 fallos de la cuenta `test` de siempre (una
pasada dio un quinto, el combate de la lección de Baan al cerrarse, con
errores de `vfx.gd`: no es de aquí), `run_tests.sh` 1525/0. Capturas:
`~/codigo/capturas/s38/dialogo-*.png`.

### Nilo animado con AniCraft (2026-11-13, hoja al dueño)

Dueño: "pues instala anicraft", "anima ahora". AniCraft 0.2.1 instalado en
`~/.local/opt` (tarball de Linux con su suma comprobada; `anicraft` y
`anicraft-cli` en `~/.local/bin`) y registrado como MCP de este proyecto
(sus herramientas salen al reiniciar la sesión). Ciclo de reposo de Nilo, 48
fotogramas a 24 fps (2 s): `godot/tools/portraits/nilo_anim.vx.js` dibuja
las capas de encima (párpados cerrados, el brillo de la piedra recortado a
la piedra, un destello) y `nilo_anim.py` monta la línea de tiempo en
AniCraft por `anicraft-cli serve`: respiración (se estira 1,2 % desde los
pies, tweens clásicos con easing), la piedra que se enciende y se apaga, un
parpadeo en los fotogramas 31–34 y el destello que gira y se desvanece. Se
importan los PNG ×2, no el SVG: el importador de SVG lo parte en 136 capas y
se salta 14 recortes anidados. Un halo suave sobre la figura oscurecía la
tinta y la madera de alrededor (mezcla sin premultiplicar), así que el
brillo va recortado a la piedra. Salidas: `.anicraft`, GIF, hoja de sprites
(2720 × 2400, transparente, 6,6 MB) y secuencia PNG. GIF y fotogramas en
`~/codigo/capturas/s38/anim/`. Aún no está en el juego: la hoja pesa
demasiado para la demo web (4 NPC ≈ 26 MB); a decidir con el dueño.

## Mini sprint para seguir (S38b, escrito al parar el 2026-11-13)

El dueño pidió parar por contexto. Lo que queda, en orden, cada paso
cerrable solo:

1. ✅ **Iconos de las cartas del coach (196).** Herramientas hechas:
   `equip_icons.tscn -- --coach` renderiza las 92 piezas sueltas (sombreros,
   capas, estandartes, hombreras, brazaletes, mascotas, bastón) y
   `tools/icons/garment_icons.tscn` las 104 prendas puestas en el coach
   (torso, pantalón, falda, botas, marcas), cortadas por la franja del cuerpo
   que cubren; `equip_icons.py --coach` hace las placas en
   `assets/ui/equip_coach/` (borrado al parar: se regenera con los tres
   comandos). **Falta:** (a) el corte de las prendas aún enseña el cuerpo
   entero de ancho: cortar también en horizontal al ancho de la prenda (su
   contorno: render con y sin la prenda y quedarse con la diferencia), (b)
   las marcas (13) casi no se ven sobre la piel: acercar el corte a la
   marca o pintarla sobre un torso neutro, (c) conectar: `UiStyle.card_art()`
   lee `ui/equip_coach/<id>.png` antes que las ilustraciones retail, y (d)
   hoja al dueño.
2. ✅ **Iconos de logros y de fichas/pesetas.** Logros: `lobby_panels.gd`
   `_ach_icon` y `achievementDialog` (S22); fichas: `card_panel.gd`
   `_token()` (tipo 1) y pesetas (tipo 10, hoy texto). Estilo B como los
   hechizos (`spell_icons.py`: pictograma blanco sobre color); hoja antes.
3. ✅ **Retratos de NPC** (Nilo, Aldebrán, Demonio I, Señores del Tiempo) para
   `talk_panel.gd`: con `tools/portraits` si tienen figura 3D; si no,
   pedir al dueño.
4. **Plantilla de carta por familia** (marco por tipo y rareza + la pieza 3D
   o el pictograma), para el Card Master y el inventario.
5. **Cierre de S38:** ningún panel con imagen retail (`grep gui/images` en
   `src/`), `run_tests.sh`, smokes de inventario, cardmaster, mailbox y
   fusión contra el servidor (uno a uno), capturas.

Pendientes de S45 que no son de aquí: los tres fallos de
`tournaments_smoke` (día del calendario, pregunta del arrastre 28618,
periodo que se abre), que leen datos del servidor., y después los de equipo
del luchador, logros y fichas; luego la plantilla de carta por familia.
