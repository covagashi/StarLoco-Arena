# S44 — Cliente web: la demo se juega en el navegador

**Planificado:** 2026-11-04 · **Hito:** M5 — Release · **Tamaño:** M · **Estado:** 🔵 adelantado el paso 2 (2026-11-14: conexión por WebSocket); el resto, tras S43

## Decisión del dueño (2026-11-04)

> "Al final podríamos hacer el cliente mediante web? Así la gente juega la
> demo y si hay tirón (hay una buena user base) pues ya vamos creando más
> cosas, así quitamos fricción y es lo que veo en los nuevos indie games
> web."

> "Con que funcione con 2 GB de RAM ya es más que suficiente."

> "Que tenga cuenta demo por el momento."

- La demo pública es **web**: un enlace y a jugar, sin instalar nada. Los
  ejecutables de escritorio (S15/S16) pasan a segundo plano y solo se hacen
  si la demo tiene tirón.
- Va **después de S43**: los assets retail no se pueden servir en una web
  pública, así que la demo sale con todo el arte propio de M7.

## Lo que ya hay (2026-11-04)

- Godot 4.7 exporta a web, y el cliente ya usa `gl_compatibility`
  (WebGL2), que es el renderizador que funciona en el navegador.
- El portal web del servidor ya crea las cuentas, y el servidor ya sabe
  crear una cuenta al vuelo en el login (`auto_register`).
- Lo que falta: el cliente se conecta con `StreamPeerTCP`
  (`src/net/arena_client.gd`), y el navegador no puede abrir TCP directo.
  Hoy hay 354 MB de `assets/` retail y 86 MB de arenas (las 6).

## Qué se hace aquí

### 1. Prueba previa (antes de todo lo demás)

- Exportar el cliente actual a web en local, **sin publicarlo** (lleva
  assets retail), y medir: tamaño de la descarga, tiempo de carga, fps de
  un combate en Chrome y Firefox, y memoria de la pestaña.
- Con eso se ajusta el tamaño de este sprint.

### 2. Conexión por WebSocket

- El servidor acepta también WebSocket (`wss://` detrás del proxy con TLS,
  en oracle-2), y por dentro van los mismos mensajes del protocolo. El
  listener TCP sigue para escritorio y para los tests.
- En el cliente cambia solo la capa de red: `arena_client.gd` usa
  `WebSocketPeer` en web y `StreamPeerTCP` en escritorio.
- Las e2e del servidor se repiten por WebSocket.

### 3. Peso y carga

- Primera carga de **30–50 MB** como mucho: el lobby y lo mínimo para
  jugar. Cada arena se descarga cuando toca (por HTTP, con caché del
  navegador), igual que hoy van sueltas en `art/` junto al ejecutable.
- Texturas comprimidas para web; los GLB de las arenas, revisados de peso.

### 4. Memoria: dispositivos de 2 GB de RAM

- Objetivo del dueño: que funcione en un equipo con **2 GB de RAM**.
- En un equipo así, el navegador y el sistema se llevan buena parte. A la
  pestaña le quedan unos **400–600 MB**, y eso incluye la memoria de Godot
  (wasm), las texturas en la GPU y el audio descomprimido. El presupuesto
  del juego es, por tanto, **≤ 500 MB en la pestaña** durante un combate.
- Se mide en la prueba previa y otra vez al final, con el combate más
  pesado (la arena 6) y en un equipo o perfil limitado a 2 GB.
- Si no llega: liberar las arenas que no se juegan, bajar la resolución
  de las texturas en web, y quitar las caras tapadas entre bloques
  vecinos (la arena 6 tiene 1,7 M de triángulos).

### 5. Cuenta demo (dueño, 2026-11-04)

- Por ahora no hay registro: se entra con un botón **"Jugar"** y ya.
- Cada visitante tiene **su propia** cuenta demo, no una compartida: con
  una sola cuenta, dos personas a la vez se pisarían el coach, los
  luchadores y la sesión.
- El servidor crea la cuenta demo al pulsar "Jugar" (nombre generado, sin
  correo ni contraseña) y devuelve un token. El navegador lo guarda, así
  que al volver se sigue con el mismo coach. Si se borra el navegador, la
  cuenta se pierde; es una demo.
- Las cuentas demo no juegan las clasificaciones de temporada ni reciben
  premios que no se puedan perder. Las que lleven 30 días sin entrar se
  borran.
- Límite de cuentas demo nuevas por IP y por hora, para que no se llene la
  base de datos.
- Más adelante, si hay tirón: pasar la cuenta demo a una cuenta normal
  (correo y contraseña) sin perder el progreso. No entra en este sprint.

### 6. Publicación

- Dónde: dominio propio o itch.io. Portales como Poki o CrazyGames piden
  carga corta y jugar sin cuenta; se valora cuando haya demo.
- El juego se llama **Pippop Arena** en la página, nunca StarLoco.

## Criterio de cierre

Desde un enlace, en Chrome y Firefox de escritorio, alguien sin nada
instalado pulsa "Jugar" (cuenta demo, sin registrarse), entra al lobby y juega un combate entero contra
el servidor de producción por `wss://`. La primera carga es ≤ 50 MB y la
pestaña se queda en ≤ 500 MB durante el combate de la arena 6.

## Hecho por adelantado (2026-11-14, el dueño dormía)

### 2. Conexión por WebSocket ✅

No depende de S43 (no publica nada), así que va ya.
- **Servidor:** `internal/wsconn` hace de un WebSocket un `net.Conn` (cada
  mensaje binario lleva un trozo del mismo flujo que el TCP), así que
  `Server.Serve`, el guardián por IP y las sesiones no cambian. Opción
  `ws_addr` en `config.yaml` (y `ARENA_WS_ADDR`), vacía por defecto; en
  producción, detrás del proxy TLS para `wss://`. Se acepta cualquier origen
  (la demo vive en otra página; el protocolo se autentica solo y no viaja
  ninguna cookie). Un cierre sin despedida (1006, una pestaña cerrada) es un
  EOF corriente, como el FIN de TCP.
- **Cliente:** `arena_client.gd` usa `WebSocketPeer` en la compilación web
  (`ws://host:puerto`, o la URL entera si el host ya lo es, para `wss://`) y
  `StreamPeerTCP` en escritorio; `--ws-url=<url>` fuerza WebSocket en
  escritorio para las pruebas.
- **Pruebas:** `internal/wsconn` (el flujo a través de varios mensajes),
  `TestLoginToWorldOverWebSocket` en las e2e (el mismo recorrido que
  `TestLoginToWorld` por TCP), la suite entera del servidor en verde, y
  `cardmaster_smoke` desde el cliente Godot por WebSocket contra el servidor
  local: 6/6 (y apuntado a un puerto vacío no llega al lobby: iba de verdad
  por WebSocket). `run_tests.sh` 1526/0.

Pendiente del paso 2: repetir las demás e2e por WebSocket, y el proxy
`wss://` en oracle-2 (eso, con el dueño: es producción).

### Visto al preparar el paso 1 (2026-11-14)

La prueba previa no se puede hacer tal cual: el cliente lee `assets/` y
`art/` sueltos junto al ejecutable (`AssetPaths`, `ArenaLayout.root()`, y
`export_presets.cfg` los deja fuera del `.pck` a propósito), y en el
navegador no hay disco al lado. Dos maneras, a decidir con el dueño:
meterlo todo en el `.pck` solo para medir (370 MB de `assets/`, con retail,
sin publicar), o empezar por el paso 3: una raíz de assets por HTTP que
descargue a `user://` lo que haga falta (el lobby y lo mínimo en la primera
carga, cada arena al entrar en su combate). Las plantillas web de Godot
4.7.1 ya están instaladas en la Ally.
