# S44 — Cliente web: la demo se juega en el navegador

**Planificado:** 2026-11-04 · **Hito:** M5 — Release · **Tamaño:** M · **Estado:** ⚪ esbozo (tras S43)

## Decisión del dueño (2026-11-04)

> "Al final podríamos hacer el cliente mediante web? Así la gente juega la
> demo y si hay tirón (hay una buena user base) pues ya vamos creando más
> cosas, así quitamos fricción y es lo que veo en los nuevos indie games
> web."

> "Con que funcione con 2 GB de RAM ya es más que suficiente."

- La demo pública es **web**: un enlace y a jugar, sin instalar nada. Los
  ejecutables de escritorio (S15/S16) pasan a segundo plano y solo se hacen
  si la demo tiene tirón.
- Va **después de S43**: los assets retail no se pueden servir en una web
  pública, así que la demo sale con todo el arte propio de M7.

## Lo que ya hay (2026-11-04)

- Godot 4.7 exporta a web, y el cliente ya usa `gl_compatibility`
  (WebGL2), que es el renderizador que funciona en el navegador.
- El portal web del servidor ya crea las cuentas.
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

### 5. Publicación

- Dónde: dominio propio o itch.io. Portales como Poki o CrazyGames piden
  carga corta y jugar sin cuenta; se valora cuando haya demo.
- El juego se llama **Pippop Arena** en la página, nunca StarLoco.

## Criterio de cierre

Desde un enlace, en Chrome y Firefox de escritorio, alguien sin nada
instalado crea su cuenta, entra al lobby y juega un combate entero contra
el servidor de producción por `wss://`. La primera carga es ≤ 50 MB y la
pestaña se queda en ≤ 500 MB durante el combate de la arena 6.
