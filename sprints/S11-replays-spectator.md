# S11 — Replays y espectador

**Planificado:** 2026-10-16 · **Detallado y abierto:** 2026-10-23 · **Hito:** M3 — Paridad de contenido · **Tamaño:** M · **Estado:** 🟢 cerrado (2026-10-24)

## Objetivo

El retail guarda replays (`replayDialog`, `replayIdentificationCertificate`, la
opción "guardar replay") y tiene un modo observador (`fightObservation`). En el
cliente Godot, `setSaveReplay` no hace nada; el espectador en vivo funciona
(`/watch`), aunque es de solo lectura.

## Decisión previa (dueño)

¿Replays completos como el retail (grabar y reproducir), o basta con el
espectador en vivo? Por defecto: grabar y reproducir los combates propios. Para
el marketing de S04 (clips de combates en 1 bit) los replays son muy útiles:
permiten volver a renderizar un combate con otro estilo.

## Punto de partida (auditoría del 2026-10-23)

**El retail grababa en local, en el cliente.** `tu_1` (el lector) y el
`replayDialog` trabajan sobre `game/replays/*.rda`, un fichero de texto con
una línea por suceso: `código|tiempo|campos…`. Los códigos (0 cabecera,
100 el combate en bytes, 200 la cámara, 300 colocación, 400–418 acciones,
500 fin, -1 el certificado `replayIdentificationCertificate`) **no son
opcodes**: son las clases de acción internas del cliente (`vu_0`, `act`,
`mv_0`…), metidas en su línea de tiempo `RO.aer()`.

- Hay **51 `.rda` reales** en `client/compiled/game/replays/`: los grabó el
  cliente retail contra este servidor Go (18–20 de julio, "Loov VS
  Sparring"). Solo 13 llegan al 500; los otros 38 se cortan antes.
- Leerlos exigiría reimplementar esas clases internas una a una. El cliente
  Godot no tiene esa línea de tiempo: dibuja a partir de los mensajes del
  servidor.
- **El cliente Godot no graba nada.** `gamePreferences.saveReplays` existe en
  el modelo (`gui_layer.gd`) pero nadie lo lee ni lo enseña.
- **El espectador en vivo funciona** (`/watch`, 2260 → 26331, y la final
  de un torneo). El servidor le manda un resync neutro (`sendFightResync`
  con `spectator`) y luego todos los `broadcast`. Solo se entra por chat o
  desde el aviso de la final.
- **`fight_view` se puede alimentar sin socket.** Solo usa
  `State.net.message_received`, `drain()`, `scene_active` y
  `send_message()`. Basta un nodo con esa misma forma.

## Decisiones (delegadas: "toma usando heurística"; el dueño pidió además reels de combates, 2026-10-23)

| Decisión | Tomada | Por qué |
|---|---|---|
| Replays completos o solo espectador | **completos**: grabar y reproducir | el dueño quiere reels de combates, y un replay se puede volver a renderizar con otro estilo |
| Formato | **propio**: los frames S2C tal como llegan (opcode + payload) con su tiempo, en gzip; **no** el `.rda` | el `.rda` guarda clases internas del cliente retail; el flujo de mensajes es lo que `fight_view` ya sabe pintar, y se mantiene válido mientras el protocolo no cambie (no cambia) |
| ¿Dónde se graba? | **en el cliente**, como el retail (`user://replays/`) | sin opcode ni tabla nueva; se graba también lo que se ve como espectador |
| Los `.rda` del retail | no se leen; se documenta el formato | 38 de 51 están cortados, y leerlos es reimplementar la línea de tiempo retail |
| Perspectiva al reproducir | modo solo lectura (como espectador), con el título del resultado según el que grabó | `fight_view` ya sabe ser espectador |
| Tiempos muertos | al reproducir, ninguna espera entre mensajes pasa de 1,5 s; velocidad ×1/×2/×4 y pausa | un combate real tiene turnos de hasta 30 s pensando |
| Cuántos se guardan | los 30 últimos; el resto se borra solo | un combate pesa pocos KB, pero sin límite crece para siempre |
| Nombre del fichero | `AAMMDDhhmm_A_VS_B.slr`, como el retail | se ve igual que su carpeta |
| Espectador desde la UI | un botón "Ver combate" en los amigos conectados que están luchando | el chat (`/watch`) no se descubre |
| Reels | un modo de captura: reproduce un replay a 9:16 con `--write-movie` y lo pasa a mp4 con ffmpeg | reutiliza el replay; sin música (la del retail no es nuestra) |

## A. Grabar y reproducir (cliente)

- [x] `replay_file.gd`: escribir y leer el formato (cabecera JSON + frames).
- [x] `replay_recorder.gd`: graba desde el 8000 hasta el 8300 si
      `saveReplays` está activo; guarda el combate cortado si se cae la
      conexión.
- [x] `replay_client.gd`: un `State.net` falso que emite los frames a su
      tiempo, con pausa y velocidad; el 26321 de cierre recibe un 4600
      sintético.
- [x] Barra de reproducción en `fight_view` (pausa, ×1/×2/×4, salir).
- [x] Vuelta al lobby tras el replay sin esperar al servidor.

## B. Panel de replays

- [x] "Replays" en el menú: lista (fecha, rivales, resultado, duración),
      ver y borrar.
- [x] "Guardar replays" en Opciones → Combate.

## C. Espectador desde la UI

- [x] "Ver combate" en Social para los amigos conectados.

**Pruebas (A–C):**

- `test/unit/replay_test.gd`, 33 comprobaciones: el formato ida y vuelta, la
  cola cortada, el grabador (empieza en 8000, quita los susurros, para en
  8300 o al caerse, respeta `saveReplays`), el reloj comprimido, la pausa,
  la velocidad y el 26321 → 4600.
- `test/replay_smoke.gd`: un combate real contra el demonio del minuto 58
  (desafío 34), rendición en el turno 7. Lo graba (≈190 frames) y lo
  reproduce a ×4 en un `fight_view` nuevo. Casillas, daño (74), muertes,
  turno de mesa (8) y ganadores salen **iguales**, y se emiten todos los
  frames.
- `test/replay_lobby_smoke.gd`, 29 comprobaciones por el `main.tscn` real:
  Menú → Replays → Ver → barra (×4) → "Continuar" → el lobby vuelve con
  la sesión viva; Borrar pide confirmación y borra; Opciones apaga y
  enciende el grabador; Social tiene "Ver combate".
- `native_panels.gd` (xvfb): 128 PASS, `replayDialog` incluido.
- Con la salida del replay salió un aviso viejo de `xps_fx.gd`: dos lambdas
  guardaban la partícula, y Godot avisa si se libera antes de su
  temporizador. Ahora van con `weakref`.

## D. Reels

- [x] `/AUTOPILOT [on|off]` (GM, admin): la IA del servidor juega los
      luchadores del coach que lo pide; su sesión sigue enganchada y recibe
      todos los frames. Así un cliente graba un combate IA contra IA.
- [x] La IA de un luchador de jugador **lanza sus hechizos**. `classifyAI`
      solo leía `SummonSpellID`, que un luchador de jugador no tiene, así que
      quedaba como "bloqueador" y solo pegaba cuerpo a cuerpo (el propio
      comentario lo daba por sabido). Ahora la firma es el primer hechizo
      ofensivo de su equipo. También juegan mejor los coaches que se caen a
      mitad de combate.
      Medido (desafío 34, arena 36, IA contra IA): antes, 0 hechizos en
      18 rondas; ahora, 12 hechizos, 4 golpes y 2 muertes en 6 rondas.
- [x] `tools/reel/record.gd`: login, `/ARENA`, desafío, colocación,
      `/AUTOPILOT on`; graba en `--out`.
- [x] `tools/reel/render.gd` + `make_reel.sh`: replay → mp4 vertical
      (540×960 → 1080×1920 sin suavizado, 30 fps): portada, cámara sobre el
      que actúa, cámara lenta en cada muerte, cartel del ganador. Sin
      botones ni chat.
- [ ] Una primera tanda de clips para que el dueño elija: **hecha, falta
      que elija.** `~/codigo/capturas/s11/reel-retail.mp4` y
      `reel-1bit.mp4`: el mismo combate (desafío 34, arena 36, IA contra IA),
      22 s, 1080×1920.

**Notas del bloque D:**

- El movie maker de Godot graba al tamaño de ventana del proyecto leído al
  arrancar. Ni `--resolution` ni un cambio de tamaño desde el script lo
  mueven (salía a 1280×720 estirado), así que `make_reel.sh` pone el
  tamaño vertical con un `override.cfg` temporal y lo borra al salir.
- `_initialize` de un `-s` corre antes de que `root` procese los `_ready`
  (`fight_view` aún sin HUD). El renderizador arranca diferido.
- Los luchadores salen como siluetas oscuras **también en vivo**
  (`fight_smoke`): así pinta hoy el cliente sus sprites. No es cosa del
  replay.
- Los reels llevan el arte del retail (Ankama). Publicarlos es decisión del
  dueño.
- Con xvfb y llvmpipe, un reel de 22 s tarda alrededor de 1 min.

## Criterio de cierre

Un combate grabado se reproduce entero en el cliente y coincide con lo que pasó.

Y un reel sale de un replay con un solo comando.

## Cierre (2026-10-24)

El dueño: "me gustó el primer reel, pero recuerda que es Pippop Arena, no
StarLoco".

- **El reel:** sale `~/codigo/capturas/s11/reel-pippop.mp4` (arena 36, en
  retail). La portada y el cartel final dicen **PIPPOP ARENA**
  (`render.gd`, `BRAND`); la variante 1 bit y el segundo reel se borraron.
- **El título de la ventana del cliente:** también es "Pippop Arena"
  (`main.gd`, `WINDOW_TITLE`). En `project.godot` el nombre se queda en
  "StarLoco Arena", porque también da nombre a la carpeta de datos
  (preferencias, replays): cambiarlo, aun con `custom_user_dir`, la movía
  de sitio.
