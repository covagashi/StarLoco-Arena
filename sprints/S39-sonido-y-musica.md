# S39 — Sonido y música

**Planificado:** 2026-10-25 · **Hito:** M7 — Arte propio · **Tamaño:** M · **Estado:** 🔵 en curso (2026-11-14: sonidos de interfaz hechos)

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

### Siguiente

Combate: hechizos por elemento y forma (como S37), golpes, muerte, pasos;
hoy `spell_sfx.json` manda sonidos retail. Después la música (lobby y
combate) y quitar `sounds/` y `musics/` retail.
