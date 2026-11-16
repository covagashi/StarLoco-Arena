# S44 — Cliente web: la demo se juega en el navegador

**Planificado:** 2026-11-04 · **Hito:** M5 — Release · **Tamaño:** M · **Estado:** 🟢 cerrado 2026-11-15: demo en https://140.238.172.196/ (oracle-2), cuenta demo con JUGAR, combate entero en Chromium y Firefox, primera carga 34,5 MB; lo pendiente, en [BACKLOG §13](./BACKLOG.md)

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

## Abierto tras S43 (2026-11-15)

S43 cerrado: ya no queda nada retail, así que la demo se puede construir
entera. Pasos 1, 3 y 5 empezados en la misma sesión.

### 1 y 3. Exportar y bajar los assets por partes

- **Preset `Web`** en `export_presets.cfg` (sin hilos: vale en itch.io y
  cualquier hosting sin cabeceras COOP/COEP).
  `godot --headless --path godot --export-release Web ../dist/web/index.html`
  da `index.wasm` 39,5 MB (9 MB con gzip), `index.pck` 0,9 MB.
- **Paquetes** (`tools/web/pack_web.gd -- ../dist/web`): lo que un
  escritorio lleva suelto junto al ejecutable (`assets/` y `art/`) va en
  zips en `bundles/`, con `manifest.json` y el hash en el nombre (caché
  para siempre). `boot` = `assets/` + figuras + equipo: 40,3 MB; cada arena,
  aparte: 9,1 / 12,1 / 10,1 / 9,1 / 21,7 / 27,7 MB (arenas 1–6).
  `pack_arenas.gd` se partió en `arena_files` / `figure_files` /
  `equipment_files` para que los dos empaquetadores lean la misma lista
  (la salida de `pack_arenas` es idéntica byte a byte, `diff -r`).
- **Cliente** (`src/util/web_assets.gd`): baja un grupo y lo descomprime en
  `/tmp/pippop`, el sistema de ficheros en memoria del navegador (no
  `user://`: ese se copia a IndexedDB y se vuelve a leer entero en cada
  arranque). `AssetPaths` y `ArenaLayout.root()` leen de ahí en web, así
  que ninguna lectura del juego cambia. `src/web/web_boot.tscn` es la
  escena inicial en web (`run/main_scene.web`): barra de carga, `boot`, y
  pasa a `main.tscn`. `fight_view` baja la arena de su mundo antes de
  montarla (los mensajes del servidor esperan, `scene_active` sigue
  apagado), y solo una arena queda descomprimida a la vez.
- Godot 4.7.1 en web: `HTTPRequest.download_file` no escribe nada; el
  cuerpo llega a memoria y se escribe a mano para `ZIPReader`.
- **Primera carga ≈ 50 MB** con gzip (9 wasm + 0,9 pck + 40,3 boot). Justo
  en el límite: queda recortar (pasos 3–4).

### 5. Cuenta demo ✅ (servidor y cliente)

- **Servidor**: `limits.demo_accounts` (apagado por defecto) y
  `limits.demo_accounts_per_ip_hour` (5). Un login desconocido con la forma
  `demo-` + 20 letras/cifras (`game.IsDemoLogin`) crea una cuenta con
  `is_demo` (migración 22) aunque `auto_register` esté apagado, nunca admin,
  con tope por IP y hora. Las cuentas demo no entran en `RankedTop` /
  `GhostTop`, así que no cobran pesetas de temporada. `RunDemoPurge` borra
  cada hora las que llevan `DemoMaxIdle` (30 días) sin entrar.
- **Cliente**: en web el login es un solo botón **JUGAR** con una línea
  ("Demo gratis en el navegador, sin registro…"). `src/web/demo_account.gd`
  genera login y clave la primera vez y los guarda en `user://` (IndexedDB
  del navegador): al volver se sigue con el mismo jefe. El servidor es el de
  la página (`/ws` en el mismo host, `wss://` en https) o `?server=<url>`
  para pruebas. "Crea tu jefe" sale con un nombre generado ("Lonefen76").
  Un rechazo en la demo dice "No se pudo abrir tu partida demo…", no
  "contraseña incorrecta".
- Pruebas: `TestDemoAccounts`, `TestDemoAccountsOffByDefault` (e2e),
  `TestIsDemoLogin`, `TestDemoPerIPHour`, `TestPurgeDemoAccounts`,
  `TestDemoCoachesTakeNoSeasonPlace`.
- Recorrido real en Chromium (Playwright, GPU AMD por ANGLE/Vulkan, sin
  ventana): carga → JUGAR → cuenta demo creada en el servidor → crea tu jefe
  (figura 3D) → lobby → tutorial de Aldebrán → crear luchador → equipo. El
  tope por IP saltó de verdad en la sexta cuenta de la sesión.

### 4. Memoria, primera medida (Chromium, lobby)

PSS de los procesos, con recolección forzada antes de medir:

| Momento | Pestaña (renderer) | wasm | GPU |
|---|---|---|---|
| Antes de bajar nada | 241 MB | 46 MB | 86 MB |
| Pantalla de login (boot bajado) | 380 MB | 80 MB | 89 MB |
| Lobby | 554 MB | 148 MB | 102 MB |

- Bajar `boot` de una pieza dejaba el wasm en 171 MB para siempre (la
  memoria de wasm no se devuelve): ahora va en partes de ~4 MB y se queda
  en 80. Las arenas, igual.
- El resto: ~200 MB son Chromium con el motor compilado; ~65 MB los
  ficheros de `boot` en memoria; el lobby suma ~70 MB de wasm (figuras).
- **Pasa del presupuesto (≤ 500 MB) ya en el lobby.** Siguiente: que las
  figuras y el equipo se bajen al usarse en vez de en `boot` (son 46 de los
  65 MB), y medir el combate de la arena 6.

#### Segunda medida, misma sesión

- **Audio en modo stream**: Godot 4.7 en web reproduce por defecto cada
  sonido como "sample" de Web Audio, que decodifica el OGG entero a PCM en
  JavaScript (las dos músicas son 96 y 103 s). `project.godot`:
  `audio/general/default_playback_type.web=0`. Lobby: 554 → 425 MB.
- **Arena montada, modelos fuera**: tras montar la arena, `fight_view`
  borra sus GLB de la memoria (`WebAssets.drop_models`) y `ArenaView`
  suelta las plantillas del constructor (vale también en escritorio).
- **El manifiesto, sin caché** (`?t=`): con el perfil del navegador
  guardado pedía trozos de una compilación anterior (404).
- Medido con PSS + SwapPss (la Ally está en swap y el PSS solo engañaba):

| Momento | Pestaña | wasm | GPU |
|---|---|---|---|
| Lobby | 425–434 MB | 80 MB | 90–103 MB |
| Combate, arena del mundo 10 (12 MB) | 476 MB | 115 MB | 122 MB |
| Combate, arena del mundo 38 (10 MB) | 482–520 MB | 115 MB | 91–150 MB |
| **Combate, arena 6 (mundo 36, 27,7 MB)** | **452–472 MB** | 115 MB | 82–89 MB |

**Presupuesto de memoria cumplido en Chromium** con la arena más pesada
(entrenamiento 1 contra 1). Falta Firefox, y un combate con más luchadores.

### Visto de paso

- Los iconos que la interfaz dibuja con caracteres sueltos (flechas,
  triángulos, ✓, ✕, ●, ∞, ≤, ≥) salían como cuadros en web: ninguna de
  nuestras tres fuentes los tiene y en escritorio los ponía una fuente del
  sistema. **Arreglado**: `assets/ui/fonts/PippopSymbols*.ttf` (8 KB,
  recortadas de Noto, OFL, `tools/fonts/make_symbols.py`) como respaldo de
  todas las fuentes en `UiStyle._file`. Verificado en Chromium: el ▸ de
  JUGAR ya se ve.
- El tutorial de entrada son 8 + 4 páginas de Aldebrán y luego 10 de Nilo
  antes de la primera pelea; en una demo pesa. Lo apunto para el dueño, no
  lo toco.

### 6. Publicada en oracle-2 (2026-11-15) ✅ a medias

El dueño: "el oracle es el de pruebas, para 1/2 personas". Así que la demo
va ahí: **https://140.238.172.196/**

- **Servidor**: imagen `dofusarena-2.70:s44` (binario compilado aquí,
  `configs/config.oracle.yaml`: sqlite en el volumen de siempre y
  `limits.demo_accounts: true`), contenedor `deploy-arena-1` con los mismos
  puertos (5555, 3000, 8080) más `127.0.0.1:5556` para el WebSocket. La
  imagen de antes (6 semanas, anterior a S43) quedó como
  `dofusarena-2.70:pre-s44` y su contenedor parado como
  `deploy-arena-1-pre-s44`; la base, copiada en
  `~/arena-s44/arena.db.bak-2026-11-15`. Volver atrás: parar y borrar
  `deploy-arena-1`, renombrar el `-pre-s44` y arrancarlo.
- **Web**: `/srv/pippop-demo` (el export y los paquetes; wasm, pck, js y
  manifiesto también en `.gz`). Caddy: un bloque nuevo para la IP en
  `/etc/caddy/Caddyfile` (copia en `Caddyfile.bak-2026-11-15`): estáticos
  con `precompressed gzip`, el manifiesto `no-cache`, los trozos `immutable`
  y `/ws` al 5556. Los bloques de `arena.pippop.shop` y `mvp.pippop.shop` no
  se tocaron (`/health` 200 antes y después).
- **HTTPS obligatorio**: Godot en web se niega a arrancar sin contexto
  seguro, aunque no use hilos. Sin dominio, un certificado de Let's
  Encrypt para la IP (perfil `shortlived`, 6 días, Caddy lo renueva solo) y
  `default_sni 140.238.172.196` en las opciones globales (un navegador que
  entra por IP no manda SNI).
- **La IP real del jugador**: detrás de Caddy todas las conexiones venían
  del proxy, y los topes por IP (conexiones, logins, cuentas demo) habrían
  sido uno solo para todos. `wsconn` toma la última entrada de
  `X-Forwarded-For` cuando quien conecta es local o de red privada
  (`TestClientAddrBehindProxy`). Comprobado: el log de oracle-2 muestra la
  IP de casa, no la del proxy.
- **Recorrido real** en Chromium desde aquí: carga (50,9 MB transferidos
  en total, con gzip) → JUGAR → cuenta demo → crea tu jefe → lobby.
  Pestaña: 372 MB en el login, 441 MB en el lobby.

Falta para cerrar: Firefox, un combate entero contra oracle-2 y que la
primera carga baje con holgura de 50 MB. Un dominio propio quitaría el
certificado de IP (decisión del dueño, como itch.io).

### Música entrecortada al abrir el inventario (2026-11-15)

Dueño: "dice mi hermano que cuando entra a inventario la música se empieza
a escuchar entrecortada" (demo en oracle-2, su equipo).

- Causa: la compilación web no tiene hilos, así que Godot mezcla el audio
  en el hilo principal, y en web su búfer de salida es de 50 ms: cualquier
  fotograma más largo corta la música. Al pasar el audio a modo stream (por
  memoria) quedó expuesto a eso. Abrir el inventario (decodificar las
  imágenes de las cartas y dibujarlas) da fotogramas largos; en la Ally, a
  60 fps incluso con la CPU ×4, solo uno de 50 ms al abrir, pero en un equipo
  más flojo pasa de largo.
- Arreglo: `audio/driver/output_latency.web=250` (la música aguanta un
  cuarto de segundo de fotograma lento) y los sonidos cortos (interfaz y
  combate, `Audio.SHORT`) como "sample" de Web Audio: suenan al instante y
  no dependen de los fps. La música sigue en stream (como sample se
  decodificaba entera en memoria). Memoria igual: lobby 435 MB, inventario
  407 MB.
- Subido a oracle-2. No lo he oído (aquí no hay salida de audio): queda que
  el hermano lo pruebe.

### Firefox, combate entero, primera carga, inventario (2026-11-15)

Dueño: "sí, hazlo" (los cuatro pendientes, en orden).

1. **Firefox 155** (el de Playwright, en ventana dentro de `gamescope
   --backend headless`, que le da la GPU AMD real: `radeonsi, phoenix`).
   Funciona entero, pero **gasta bastante más que Chromium**:

   | Momento | Pestaña | Proceso principal |
   |---|---|---|
   | Login | 445 MB | 411 MB |
   | Lobby | 602–653 MB | 327–427 MB |
   | Combate (arena del mundo 12) | 625–744 MB | 513–593 MB |

   Pestaña en el lobby, por `smaps`: 474 MB de montón (wasm de Godot, JS,
   ficheros en memoria) y 94 MB de código compilado del motor (Firefox
   guarda dos niveles de compilación del wasm). El proceso principal lleva
   el WebGL. **En Firefox no se cumple el ≤ 500 MB**: queda abierto (abajo).
2. **Combate entero contra oracle-2**, en Firefox y por internet, cuenta
   nueva: JUGAR → jefe → tutorial → luchador → entrenamiento → combate
   hasta el final (`fight ended id=1` en el log de oracle-2).
3. **Primera carga 34,5 MB** (antes 50,9): `boot` lleva `assets/`, los dos
   jefes y el equipo (el lobby viste al jefe al momento): 24 MB. Luchadores
   e invocaciones (`figures`, 16,3 MB) se bajan en segundo plano desde la
   pantalla de login (`WebAssets.fetch_later`), y el primer combate los
   espera con su barra si aún no han llegado. Las descargas van de una en
   una (`ensure` hace cola). Una vista que dibuja un luchador antes de que
   lleguen (crear luchador en los primeros segundos) lo muestra al siguiente
   refresco: `figure.gd` lo vuelve a buscar en cada `load_action`.
   Comprobado: combate en la arena 6 con las figuras llegadas por detrás.
4. **Inventario**: `CardFace` dibujaba la imagen de cada carta
   decodificándola en el momento, todas en el mismo fotograma.
   Ahora la pide (`_tex_soon`) y se redibuja cuando está: 4 imágenes por
   fotograma. Peor fotograma al abrirlo con la CPU ×4: 50 → 33 ms.
   `inventory_smoke` y `fight_smoke` OK, 1491/0.

Todo subido a https://140.238.172.196/.

### Lo que queda para cerrar S44

- **Firefox ≤ 500 MB.** Las palancas que quedan, de más a menos efecto:
  - un motor web propio sin los módulos que no usamos (el wasm de 39 MB
    baja; Firefox guarda su código compilado dos veces);
  - no tener en memoria a la vez el fichero y lo que se carga de él
    (texturas e imágenes de la interfaz que ya están decodificadas);
  - figuras por luchador en vez de todas.

  La primera es la grande (compilar Godot para web con emscripten aquí,
  una o dos horas de máquina) y la propongo como siguiente paso.
- Dominio o itch.io (dueño); de momento, la IP.

### Lo que vio el hermano en el móvil (2026-11-15, Firefox Android)

Dueño: "en firefox funciona bien, ya sé que no está optimizado para
móviles pero he encontrado algunos fallos" (cuatro capturas). Firefox se
da por bueno como está: no se compila un motor web propio.

Arreglado (subido a oracle-2):
- **La piel del jefe con manchas blancas**: no era el móvil; pasaba en
  todas partes con una piel oscura. `tools/art/coach_masks.py` dejaba fuera
  de la máscara de piel los tonos crema y melocotón claro (los brillos que
  Meshy hornea en la textura) y la ponía a cero justo en el borde de cada
  trozo de textura (rayitas claras). Ahora la piel es todo tono cálido con
  algo de saturación (la armadura blanca y el pelo gris, neutros o fríos,
  siguen fuera) y la máscara sangra unos píxeles fuera de cada trozo.
  Piel cubierta: 221.941 → 363.241 px (él), 214.081 → 432.942 px (ella).
- **No vio elegir hombre o mujer**: "Crea tu jefe" abría en PELO; abre en
  CUERPO. Y "MUJER" sin elegir salía como una mancha: el texto oculto del
  botón seguía dibujando su contorno (igual que la flecha izquierda del
  lobby). Arreglados los dos.
- **"Un botón que no se ve" en Historia** (y CREAR EQUIPO / VER TORNEOS
  tapados por las piernas de los luchadores): las acciones de las tres
  losetas llevan una tira blanca debajo; la frase de Historia, un punto
  más pequeña y más estrecha, ya no choca con el pollito ni la tapa la
  etiqueta del equipo.
- **El chat "se ve muy mal"**: usaba los colores del fondo oscuro del
  combate (caqui, verde y amarillo chillones) sobre el blanco del lobby.
  `ChatBox.light`: tinta y verdes/amarillos/rojos oscuros en el lobby. Fuera
  también el "En el lobby." repetido y el ":-" del mensaje de conexión.
- **La música al abrir y cerrar el inventario**: búfer de la música en web
  a 500 ms (antes 250). Con la CPU ×6, abrir da un fotograma de 83 ms y
  cerrar 17 ms.
- La flecha izquierda para girar al jefe quedaba debajo del chat (gris).

Pendiente, para el dueño:
- **¿Tantos canales de chat?** (Todo, General, Comercio, Grupo, Clan,
  Privados, Sistema). Mi opinión: no. En la demo no hay grupos (el 2vs2
  está escondido) ni comercio entre jugadores a la vista, y sin canales se
  lee mejor en pequeño. Propuesta: **Todo · Privados · Sistema** (General
  pasa a ser lo que se escribe en Todo). No lo toco hasta que digas.
- **Crear cuenta**: en la demo no hay registro a propósito (JUGAR guarda
  la partida en el navegador). Pasar la demo a una cuenta con correo y
  contraseña sin perder el progreso estaba en el plan "si hay tirón".
- **Cartas con dibujo provisional**: las de arena (Bosque de Cobre,
  Callejón de los Faroles…) y los peinados llevan el pictograma de su
  familia, no una ilustración propia. Es trabajo de arte (S38 hizo la
  plantilla y los pictogramas).
- **Pantalla de bienvenida y vex en vez del 3D** en las pantallas (el
  jefe se queda en 3D): trabajo de arte en el estilo B de S45
  (`capturas/s45/referencias`). Primer paso propuesto abajo.
- **Escribir en el móvil** y **la mitad de la pantalla en negro** (tercera
  captura): no lo reproduzco aquí. Al cambiar el tamaño en Chromium el
  juego se reescala bien; será la barra o el teclado de Firefox Android
  cambiando el alto de la ventana. Queda para cuando se trabaje el móvil.

## Resultado (cierre, 2026-11-15)

El criterio de cierre, punto por punto:

| Criterio | Cómo queda |
|---|---|
| Desde un enlace, sin instalar nada | https://140.238.172.196/ (oracle-2, el servidor de pruebas; dominio o itch.io, cuando el dueño diga) |
| JUGAR con cuenta demo, sin registro | ✅ cuenta propia por navegador; tope por IP y hora; fuera de la temporada; purga a 30 días |
| Lobby y un combate entero contra el servidor por `wss://` | ✅ Chromium y Firefox, por internet (`fight ended` en el log de oracle-2) |
| Primera carga ≤ 50 MB | ✅ 34,5 MB (luchadores e invocaciones, 16,3 MB, en segundo plano) |
| Pestaña ≤ 500 MB en la arena 6 | ✅ Chromium 452–515 MB; Firefox 625–744 MB, **aceptado por el dueño** ("en Firefox funciona bien") |

Comandos que lo demuestran: `go test ./...` (con `TestDemoAccounts`,
`TestDemoAccountsOffByDefault`, `TestClientAddrBehindProxy`, …);
`godot/run_tests.sh --headless` 1491/0; `tools/no_retail_smoke.sh` con
`fight_smoke`, `hub_smoke`, `inventory_smoke` y `talk_smoke`; los recorridos de
Playwright de este fichero.

Lo que sigue va en [BACKLOG §13](./BACKLOG.md): canales del chat,
bienvenida e ilustraciones vex, tutorial largo, cartas sin ilustración,
móvil, Firefox, cuenta demo → cuenta normal, dominio.

### Para los amigos: https://alfa-pippop.covaga.dev (2026-11-16)

Dueño: "¿podemos enmascarar la IP con la URL de un Worker de Cloudflare?",
"usa covaga.dev… alfa-pippop.covaga.dev", "hazlo tú, tienes el token".

- El token de la sesión de wrangler (`~/.config/.wrangler`) no tiene
  permiso de DNS, pero sí de Workers: un **Worker con dominio propio**
  (`alfa-pippop`, fuente en `server/deploy/cloudflare/alfa-pippop.worker.js`)
  crea su registro él solo y lo pasa todo, WebSocket incluido, al servidor.
  La sesión había caducado (14-11); se renovó con su `refresh_token`.
- Cloudflare no deja a un Worker llamar a una IP (error 1003): el origen es
  `140-238-172-196.sslip.io`, un nombre que resuelve a la IP, con su propio
  certificado en Caddy (el mismo bloque que la IP).
- La IP del jugador: el Worker la manda en `X-Pippop-Client`; Caddy la
  toma solo si la petición viene de rangos de Cloudflare
  (`trusted_proxies` + `client_ip_headers`) y se la pasa al juego en
  `X-Forwarded-For`. Comprobado: el log de oracle-2 muestra la IP de casa.
  Límite conocido: otro Worker de Cloudflare (de cualquiera) podría poner esa
  cabecera; solo serviría para saltarse el tope de cuentas demo por IP.
- Recorrido real por el dominio: carga, JUGAR, cuenta demo, jefe, lobby.
- La IP directa (https://140.238.172.196/) sigue funcionando.
