# S39 — Sonido y música

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🟢 hecho a falta del dueño (2026-11-14: interfaz, hechizos, combate y música propios; falta que lo oiga)

## Alcance

- Música: lobby y combate (hoy 2 pistas retail), y quizá una por bioma.
- Efectos de sonido por **elemento y forma** de efecto (como S37), golpes,
  pasos, interfaz (hoy no hay sonidos de interfaz).
- Librerías con licencia libre o encargo; lista de procedencias.

## Criterio de cierre

Ningún sonido retail; `sounds/` y `musics/` retail se pueden borrar.

## Decisiones (2026-11-14, el dueño dormía: "elige heurísticamente")

- **Procedencia:** paquetes CC0 de Kenney (kenney.nl: *Interface Sounds*,
  *Impact Sounds*, *RPG Audio*), que no piden crédito (aun así van en
  `godot/art/CREDITS.md`). La descarga directa da "forbidden"; con la cookie de
  la propia página, sí. Para la música, CC0 de OpenGameArt, en un paso aparte.
- **No puedo escuchar audio**: elijo por el nombre y el tipo de cada sonido.
  Todo lo elegido queda a la espera de que el dueño lo oiga; cambiar uno es
  copiar otro fichero encima.

## Hecho

### Sonidos de interfaz (2026-11-14)

No había ninguno. `godot/assets/audio/ui/` (124 KB): `click` (click_003),
`tab` (switch_002), `open` (maximize_006), `close` (minimize_006), `toast`
(pluck_002), `confirm` (confirmation_002), `error` (error_004), `coins`
(handleCoins, RPG Audio), `card` (bookFlip2, RPG Audio), `back` (back_002).
`Audio.ui(kind)` los toca en el bus SFX (el deslizador de efectos ya
existente), **uno por fotograma, el más importante** (clic < pestaña <
carta/abrir/cerrar < aviso < monedas/confirmar < error), para que un clic
que abre un panel suene una vez ("feedback on every action, no duplicates").
Cada botón que entra en el árbol suena al pulsarlo (`node_added`; un nodo se
calla con el meta `silent`), los desplegables y las pestañas al cambiar; los
paneles al abrirse y al irse; los avisos (`_toast`); y los resultados que
`main.gd` ya guarda: compra o trueque del Card Master (monedas o error),
fusión, envío y recogida del correo, torneos (inscripción, búsqueda, crear),
afiliación al demonio. `Audio.ui_played` guarda los últimos para las pruebas.
Evidencia: una prueba de un solo uso contra el servidor local — abrir el
inventario suena "open" (una vez, no clic + abrir), una loseta "click", un
aviso "toast", cerrar "close": 4/4; `run_tests.sh` 1526/0.

### Hechizos por forma y elemento (2026-11-14)

Ninguna librería CC0 a mano trae magia por elementos, así que son nuestros:
`tools/audio/spell_sfx.py` los sintetiza (numpy y ffmpeg, con semilla): el
elemento da la textura (fuego: ruido en banda resonante con chispas; agua:
chirridos senoidales ascendentes sobre un chapoteo; aire: ruido por una
banda resonante que barre; tierra: un golpe grave que cae y un retumbo;
neutro: parciales brillantes con vibrato) y la forma su envolvente, duración
y movimiento (el rayo vuela y llega con un golpe, el área retumba, la
maldición cae, la cura sube con campanillas, la invocación acaba en un
"pop", el teletransporte zumba, la trampa chasquea). 45 sonidos, 368 KB, en
`godot/assets/audio/spells/<forma>_<elemento>.ogg`. `fight_view._cast_sfx`
toca el de la receta S37 del hechizo (`Audio.sfx()`, varios a la vez en el
bus SFX); sin receta (el arma) suena "golpe neutro". Los eventos retail de
`spell_sfx.json` ya no se tocan. **A la espera de que el dueño los oiga**
(no puedo escucharlos; los revisé con espectrogramas: el aire barre, la
tierra se queda en los graves). Evidencia: `fight_smoke` de un combate
entero — 16 de 16 sonidos de hechizo, nuestros (teletransporte y rayo de
aire, golpe de tierra). En esa pasada `fight_smoke` dio "Ready did not say
it waits for the opponents" y un "previously freed" en el Versus: también
sin los cambios de sonido (comprobado) y `fight_view.gd` no cambió hoy;
parece de tiempos (la IA confirma antes del vistazo de 0,6 s). Apuntado.

### Golpes, caídas, pasos (2026-11-14)

Con las figuras 3D el combate estaba mudo fuera de los hechizos:
`AnmSprite.play_once` toma el camino 3D antes de leer los sonidos de los
fotogramas retail. `Audio.fight(kind)` toca una variación al azar de
`godot/assets/audio/fight/` (Kenney CC0, 268 KB): `step` (footstep_grass,
5, un paso por casilla y por debajo de lo demás, −8 dB), `hurt`
(impactPunch_medium, 5, cada pérdida de vida), `death` (impactSoft_heavy, 5),
`tackle` (impactGeneric_light, 5), `swing` (knifeSlice ×2 y drawKnife, el
golpe de arma) y `jump` (cloth ×2, los saltos y los intercambios).
Evidencia: los últimos 16 sonidos de un `fight_smoke` entero, todos nuestros
(pasos, golpes, un salto, la muerte, rayos y teletransportes de aire).

### Música (2026-11-14)

Elegida a ciegas por la descripción de su autor (no puedo escucharla), y con
preferencia por CC0; CC-BY vale (el cliente es propietario, pero el crédito
basta), CC-BY-SA y GPL no.
- **Lobby: "Enchanted Festival"**, Matthew Pablo, **CC-BY 3.0**: festiva y
  juguetona ("para pueblos, menús, tutoriales"), trae versión en bucle.
  **Pide crédito:** está en `CREDITS.md`, y el juego publicado tendrá que
  mostrarlo (una pantalla de créditos antes de la demo pública, S44).
- **Combate: "Battle Theme A"**, cynicmusic, CC0: cuerdas y metales épicos
  para combates de RPG.
`godot/assets/audio/music/` (2,9 MB, Ogg Vorbis). `Audio` las lee ahí (la
pista de fuera del combate sigue llamándose "island") y ya no lee la música
retail. `audio_smoke` 7/7 (contaba todos los reproductores de `Audio`
sonando, y desde S39 también están los de efectos: ahora solo los del bus
de música).

### Siguiente

Que el dueño lo oiga todo (interfaz, hechizos, golpes, las dos músicas) y
cambie lo que no le guste. Quitar `sounds/` y `musics/` retail cuando nada
los lea (`anm_sprite._play_sfx` aún toca los sonidos de los sets 2D que
queden; eso cae con S43).

### Créditos en el juego (2026-11-14)

Ayuda tiene una quinta pestaña, **Créditos** (es/en/fr): la música con su
autor y licencia (Matthew Pablo, CC-BY 3.0, como pide su licencia; la de
combate, CC0), los sonidos de Kenney (CC0) y que los de los hechizos son del
propio juego, las fuentes (Saira Condensed, Lilita One y Nunito, OFL 1.1) y
Godot (MIT, con su aviso). `help_smoke` 6/6 con la pestaña nueva; captura
`~/codigo/capturas/s39/creditos.png`.
