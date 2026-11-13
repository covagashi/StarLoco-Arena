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

### Iconos del equipo del coach (2026-11-13, hoja al dueño)

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
`PX` para el coach. Paro aquí hasta que el dueño vea la hoja (regla del arte).

## Mini sprint para seguir (S38b, escrito al parar el 2026-11-13)

El dueño pidió parar por contexto. Lo que queda, en orden, cada paso
cerrable solo:

1. ✅ (salvo el visto bueno de la hoja, arriba) **Iconos de las cartas del coach (196).** Herramientas hechas:
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
2. **Iconos de logros y de fichas/pesetas.** Logros: `lobby_panels.gd`
   `_ach_icon` y `achievementDialog` (S22); fichas: `card_panel.gd`
   `_token()` (tipo 1) y pesetas (tipo 10, hoy texto). Estilo B como los
   hechizos (`spell_icons.py`: pictograma blanco sobre color); hoja antes.
3. **Retratos de NPC** (Nilo, Aldebrán, Demonio I, Señores del Tiempo) para
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
