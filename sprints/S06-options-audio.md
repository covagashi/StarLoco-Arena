# S06 — Opciones, música y volúmenes

**Planificado:** 2026-10-16 · **Detallado y hecho:** 2026-10-21 · **Hito:** M1 — Jugable de punta a punta · **Tamaño:** S · **Estado:** 🟢 cerrado

## Objetivo

Que cada opción del panel haga lo que dice, y que el juego suene: hasta ahora
solo había efectos de combate.

## Punto de partida (2026-10-21, ya leído)

El esbozo de 2026-10-16 era de antes de S18. Al abrir el sprint:

- El panel de Opciones ya es el nativo de S18 (`lobby_panels._options`):
  idioma, pantalla completa, vsync, resolución, silenciar música, volumen de
  música, estilo de combate, vida en las cartas y eliminar jefe. Los ajustes
  sin efecto del `optionsDialog` retail (ratón invertido, rejilla,
  partículas…) ya no se ven; solo quedaban sus handlers vacíos en `main.gd`.
- **No había música** y **no había buses**: el volumen de música caía en el
  bus 0 (Master), así que movía el volumen de todo.
- No había volumen de efectos.
- Las preferencias se guardaban (`user://gui_settings.cfg [prefs]`), pero
  **nada las aplicaba al arrancar**: volumen, pantalla completa, vsync y
  resolución volvían a los valores por defecto en cada sesión.

## Lo que hace el retail (cliente descompilado)

- Música: `musics.jar` trae `loading`, `island` y `fight` (`sk_2`, ids 0–2).
  `nk_0.ce(1)` al entrar en el mundo (`aog_1`) y al acabar un combate (`RO`),
  `nk_0.ce(2)` al empezar uno (`aog_1`, `tu_1`). `loading` nunca se pide. El
  gestor (`aae_0`) funde una pista con la otra.
- El volumen de "sonidos" (`nk_0.ai`) mueve efectos **y** ambientes; en el
  `optionsDialog` sus claves son `ambianceSoundsMute`/`ambianceSoundsVolume`.
- `playBark` (`OL`) y `playGroundSound` (`agt_1`) consultan dos tablas que
  en el 2.70 son stubs que devuelven `null` (`aGI`, `rj`): **en el retail
  tampoco suenan**.

## Tareas

- [x] Buses Master ← Music y Master ← SFX, y los dos volúmenes con su
      silencio. Autoload `Audio` (`godot/src/audio/audio.gd`); los efectos de
      combate (el pool de `AnmSprite`) van al bus SFX.
- [x] Música: importador `tools/asset-import/musics.py` (→ `assets/musics/`,
      ignorado por git como el resto del arte retail) y reproducción como el
      retail: `island` en el lobby, `fight` en combate, fundido de 1,5 s. El
      login queda en silencio (el retail empieza al entrar en el mundo). Sin
      música importada, silencio sin errores.
- [x] Preferencias aplicadas al arrancar: volúmenes, vsync, pantalla completa
      o, si no, la resolución elegida. Una vez por ejecución (`main.tscn` se
      recarga tras cada combate).
- [x] Panel de Opciones: Música y Efectos, cada uno con volumen y "Silenciar".
- [x] Cada opción: implementada o descartada por escrito (abajo). Fuera los
      handlers vacíos de `main.gd`.
- [x] `playBark` / `playGroundSound`: descartados, son mudos también en el
      retail.

## Opciones del retail que no están en el panel

| Opción retail | Decisión | Por qué |
|---|---|---|
| Ratón invertido | descartada | en el retail cambia qué botón mueve y cuál actúa (`xu_2`, `wp_2`, `S`: derecho por defecto); nuestro combate lo hace todo con el izquierdo, así que no hay nada que invertir |
| Ocultar el mundo (`alphaMask`) | descartada | era para el mundo caminable |
| Mostrar rango de movimiento | descartada | la vista de combate siempre enseña el camino y su coste |
| Guardar replays | a S11 | depende de la decisión de replays |
| Rejilla | al backlog (S04/S07) | encaja con el filtro 1 bit, que está en pausa |
| Partículas | al backlog | útil para equipos lentos; hoy no hace falta |
| Shaders | descartada | no hay nada que apagar fuera del estilo, que ya tiene su opción |
| Sonidos de ambiente por mapa (`nk_0.aL`) | al backlog | sin leer los datos de ambiente del mapa |

## Criterio de cierre

Ninguna opción visible es un no-op. Música y efectos tienen volumen propio y se
guardan entre sesiones.

## Resultado (2026-10-21)

Cumplido. Todas las opciones del panel hacen algo; música y efectos tienen
volumen y silencio propios, se guardan en `gui_settings.cfg` y se aplican al
arrancar.

Evidencia:

- `./run_tests.sh --headless`: 173 checks, 0 fallos. La suite nueva
  `test/unit/audio_test.gd` comprueba los buses, que los volúmenes llegan a
  ellos (silencio y deslizador a 0 callan), los valores por defecto, que sin
  música importada no hay stream y que el pool de efectos usa el bus SFX.
- `test/audio_smoke.gd` contra el servidor local, bajo xvfb, 7/7: volúmenes
  guardados aplicados al arrancar; `island` en el lobby; el deslizador de
  efectos y el silencio de música llegan al bus y se guardan en
  `gui_settings.cfg` (y se restauran); `fight` en combate con un solo
  reproductor sonando tras el fundido; `island` otra vez al volver.
- Caso límite a mano: con `musicVolume=0.3` y `ambianceSoundsMute=true` en
  el fichero, el arranque deja Music en 0,30 y SFX en 0 (fichero del dueño
  restaurado después).
- Batería completa de smokes tras el cambio (toca `main.gd`), todos en
  verde: `world` 31/31, `talk` 8/8, `report` 5/5, `pvp`, `ask` 8/8, `ask2`
  5/5, `screens` 9/9, `mailbox` 8/8, `cardmaster` 5/5, `fusion` 5/5,
  `revive` 6/6, `revive_edge` 4/4, `totems` 10/10, `native_panels`,
  `native_lobby`, `login_smoke`, las dos lanes y `go test ./...`. Detalle
  y los dos tropiezos de siembra en `devlog/2026-10-21-s06-audio.md`.
