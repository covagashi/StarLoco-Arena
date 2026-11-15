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

## Publicada en oracle-2

El dueño aclaró que oracle-2 es el servidor de pruebas (1–2 personas): la
demo está en **https://140.238.172.196/** (servidor nuevo con WebSocket,
Caddy con certificado de IP, la imagen y la base de antes guardadas para
volver atrás). Recorrido real JUGAR → lobby desde aquí. `wsconn` toma la
IP del jugador de `X-Forwarded-For` cuando viene del proxy local.

## No verificado / pendiente

- Firefox, y combates con más luchadores: ver el sprint.
- Un combate entero contra oracle-2; dominio propio o itch.io: con el dueño.
- El tutorial de entrada son ~22 páginas antes de la primera pelea; en una
  demo pesa. Apuntado para el dueño, sin tocar.

## Más tarde, misma sesión (el dueño, luego dormido)

- "Sí, hazlo" a los cuatro pendientes: Firefox medido (funciona entero,
  gasta más que Chromium; el dueño lo da por bueno), combate entero contra
  oracle-2 en Firefox por internet, primera carga 34,5 MB (luchadores en
  segundo plano), cartas del inventario decodificadas poco a poco.
- Informe del hermano desde un móvil: manchas en la piel del jefe (máscara
  de `coach_masks.py`, pasaba en todas partes con piel oscura), no veía
  hombre/mujer (la pantalla abría en PELO, y MUJER era una mancha), acciones
  de las losetas tapadas, chat ilegible sobre blanco, música al abrir y
  cerrar el inventario. Arreglado y subido.
- **S44 cerrado.** Lo que espera al dueño, en `sprints/BACKLOG.md` §13.
- Pedido a un agente Fable: propuesta de bienvenida (3 páginas) y un
  luchador en vex, en `~/codigo/capturas/s44/arte/`, sin tocar el juego.

## Noche (el dueño dormía), S46 adelantado

- La IA juega el ataque de su arma (S46, de lo que dejó S40). Al medirlo
  salió **B-190**: un efecto de un solo objetivo no miraba su propia
  máscara; el arma 34 pegaba 112 en vez de 8 y los hechizos 30 y 443 daban
  al enemigo el extra del lanzador. Arreglado, probado y subido a oracle-2.
- Con eso, las 23 armas quedan al 46–54 % contra el espejo: pesan poco
  frente a los hechizos. Preguntas de diseño para el dueño, en S46.
- La propuesta del agente Fable (bienvenida en 3 páginas y un luchador en
  vex) está en `~/codigo/capturas/s44/arte/`, sin tocar el juego. Sus tres
  preguntas, en el resumen al dueño.

Verificado: `go test ./...` en verde (una e2e de fantasma superó su plazo
con la máquina cargada; sola, y el paquete entero después, pasan);
`run_tests.sh` 1491/0; smokes `hub`, `talk`, `inventory`, `fight` OK.
