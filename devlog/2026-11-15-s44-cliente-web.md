# 2026-11-15 — S44: la demo arranca en el navegador

El dueño: "continúa". S43 estaba cerrado, así que tocaba S44 (cliente web).
Detalle, cifras y decisiones en `sprints/S44-cliente-web.md`.

## Qué se hizo

- **Export web** (`export_presets.cfg`, preset `Web`, sin hilos) y
  **paquetes** (`godot/tools/web/pack_web.gd`): `assets/` y el arte que el
  juego lee en crudo, en zips de ~4 MB con hash en el nombre; `boot` antes
  de la primera pantalla y uno por arena al entrar en su combate.
- **Cliente**: `src/util/web_assets.gd` (descarga y descomprime en el
  sistema de ficheros en memoria del navegador), `src/web/web_boot.tscn`
  (escena inicial en web), la arena se baja en `fight_view` y sus modelos
  se borran al montarla.
- **Cuenta demo**: el login web es un botón JUGAR; el navegador guarda un
  login `demo-…` y su clave. El servidor (`limits.demo_accounts`, apagado
  por defecto) crea la cuenta con `is_demo`, con tope por IP y hora, fuera
  de las clasificaciones de temporada, y la borra a los 30 días sin entrar.
- **Memoria**: el audio, en modo stream (en web Godot decodificaba la
  música entera a PCM en JavaScript); los paquetes, en trozos (el wasm no
  devuelve memoria).
- **Fuente de símbolos** de respaldo (recorte de Noto, OFL): flechas,
  triángulos, ✓, ✕… salían como cuadros en web.

## Verificado

- `go test ./...` en verde (e2e incluidas: `TestDemoAccounts`,
  `TestDemoAccountsOffByDefault`; unidad: demo login, tope, purga, fuera
  de la temporada).
- `run_tests.sh --headless`: 1491/0. `fight_smoke` de escritorio (sin
  retail, en red aislada): OK.
- En Chromium (Playwright con la GPU de la Ally, sin ventana, servidor
  local por WebSocket): carga → JUGAR → cuenta demo → crea tu jefe → lobby
  → tutorial → luchador → combate de entrenamiento con su arena 3D bajada
  al entrar. El tope de cuentas demo por IP saltó de verdad.
- Memoria de la pestaña con PSS + swap: lobby ~430 MB, combates de las
  arenas de los mundos 10 y 38 ~480–520 MB, **arena 6 452–472 MB** (bajo
  el presupuesto de 500).

## No verificado / pendiente

- Firefox, y combates con más luchadores: ver el sprint.
- `wss://` en producción (oracle-2) y la publicación: con el dueño.
- El tutorial de entrada son ~22 páginas antes de la primera pelea; en una
  demo pesa. Apuntado para el dueño, sin tocar.
