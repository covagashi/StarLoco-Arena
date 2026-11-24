# S51 — Pippop Arena en itch.io

**Planificado:** 2026-11-24 · **Hito:** M5 — Release · **Tamaño:** S · **Estado:** 🟡 en curso (el código está listo; falta la página de itch.io, del dueño)

## Decisión del dueño (2026-11-24)

«¿Cómo haría para que el juego se pueda poner en itch.io?» Visto que otro
juego de Godot (The Alchemist) se juega en itch.io en el navegador:

- **Solo el cliente web**, nada duplicado: «no quiero tener dist y web a la
  vez… solo añadimos web». Sin descargas de Windows, Linux ni macOS.
- itch.io es **el único sitio donde se juega**: `alfa-pippop.covaga.dev`
  redirige a la página de itch y queda solo para la conexión del juego
  (`/ws`).
- Se quitan los presets de escritorio de `export_presets.cfg`.

## Hecho

- **Cliente:** `WebAssets.server_url()` ya no busca el servidor en la página
  (en itch.io la página está en `*.itch.zone`, que no tiene servidor): usa
  `WebAssets.SERVER` = `wss://alfa-pippop.covaga.dev/ws`, salvo que la página
  lleve `?server=` (las pruebas de `tools/web/`).
- **`export_presets.cfg`:** solo el preset `Web` (sin hilos desde S44, así
  que itch.io no necesita SharedArrayBuffer ni COOP/COEP).
- **`build.py --pack`** quitado: copiaba el arte junto a un ejecutable de
  escritorio. `pack_arenas.gd` se queda, porque `pack_web.gd` lo usa.
- **Worker** (`server/deploy/cloudflare/alfa-pippop.worker.js`): con
  `ITCH` relleno, todo lo que no sea `/ws` redirige a la página de itch;
  vacío, sigue pasando la página como hasta ahora. **Sin desplegar** hasta
  que exista la página.
- AGENTS.md: el único build es el web.

**Verificado:** `run_tests.sh --headless` (24 suites, 1544). Export web
nuevo servido sin COOP/COEP dentro de un iframe de otro origen, como itch.io,
sin `?server=`: abre `wss://alfa-pippop.covaga.dev/ws`, JUGAR crea la cuenta
demo y llega a «Crea tu jefe» (la cuenta demo de la prueba caduca sola a los
30 días).

## Guardar mi progreso (dueño, 2026-11-24)

Respuestas del dueño: correo y contraseña (para recuperarla); el aviso sale
**tras el primer combate ganado** («¿Guardas tu progreso?», Ahora / Más
tarde); se vuelve a entrar con **«Ya tengo cuenta»** junto a JUGAR, con
«¿Olvidaste la contraseña?». Correos por Cloudflare (el dueño paga Workers).

Decidido con criterio (el porqué):

- **Todo dentro del juego**, por el socket, sin abrir el portal web: en
  itch.io el juego vive en un iframe y salir de él a otra web despista.
  Recuperar la contraseña: el servidor manda **un código de 6 cifras** por
  correo y se escribe en el juego con la contraseña nueva.
- **El login pasa a ser el correo** (en minúsculas): el `Name` de la cuenta
  ya es único, así que no hace falta otra columna; un login con «@» nunca
  puede ser uno de demo.
- **El navegador no guarda la contraseña.** En itch.io todos los juegos
  HTML5 comparten el mismo origen (`html-classic.itch.zone`), así que lo que
  guarda uno lo puede leer otro. Al guardar, la clave aleatoria de la demo
  pasa a ser una **llave de este navegador** (tabla `account_keys`, con
  hash) y el navegador sigue entrando con correo + llave; al entrar con
  «Ya tengo cuenta» el servidor da una llave nueva. La contraseña solo viaja
  al escribirla.
- **Producción, con `auto_register: false`** al desplegar: hoy oracle-2 lo
  tiene encendido y un correo mal escrito en «Ya tengo cuenta» crearía una
  cuenta vacía. Las de demo siguen por `demo_accounts`.
- Las cuentas guardadas dejan de ser demo: entran en la temporada y no se
  borran a los 30 días.
- La privacidad (`/privacy`) dice que se guarda el correo y para qué.

### Hecho

- **Servidor:** migración 24: `account_keys` (llaves de navegador con
  SHA-256; la de la demo guardada conserva su bcrypt) y `password_resets`
  (6 cifras, 15 min, 5 intentos, uno por cuenta: pedir otro lo reemplaza).
  `AccountRepo.ClaimDemo` en una transacción (solo demo, correo libre: el
  `Name` pasa a ser el correo y la clave de la demo, una llave);
  `AddKey`/`VerifyKey` (como mucho 20 por cuenta), `CreateResetCode`,
  `VerifyResetCode`, `ResetPassword` (borra todas las llaves). Borrar una
  cuenta borra sus llaves y su código.
- **Login (1025):** un login con «@» se pasa a minúsculas y **nunca** se
  auto-registra, aunque `auto_register` esté encendido; entra la contraseña
  o una llave.
- **Opcodes Godot** (`game/account_save.go`, `OPCODE-INVENTORY.md`):
  60070 → 60071 guardar (códigos 0 ok, 1 no es demo, 2 correo, 3 contraseña
  <8, 4 correo cogido, 5 demasiados intentos, 8 error); 60072 → 60073 llave
  (32 hex, «» si no); 60074 → 60075 pedir código y 60076 → 60077 cambiar
  (6 código mal, 7 caducado o gastado), los dos **antes de entrar**.
  Pedir código responde «enviado» también a correos que no existen; tope
  por dirección (`limits.password_resets_per_ip_hour`, 5) y uno por minuto
  y cuenta. Guardar y cambiar gastan del cupo de logins (bcrypt). El 60001
  lleva `account_demo`.
- **Correo:** `internal/mail`, SMTP con TLS directo (465) por `net/smtp`;
  sección `mail:` (`host`, `port`, `username`, `password`, `from`,
  `from_name`) y `ARENA_MAIL_*`. Sin host no envía: escribe el código en el
  log («dev mode»). Asunto «Pippop Arena — tu código», cuerpo en español e
  inglés.
- **Privacidad:** `/privacy` 1.1 (2026-11-24): el correo de una cuenta
  guardada, solo para entrar y recuperar la contraseña (es/en/fr/de).
- **Cliente:** `demo_account.cfg` = {login, password (la llave), claimed}.
  Tras **la primera victoria** (el informe, y la subida de nivel si la hay,
  se cierran antes), `save_account_panel.gd`: «¿Guardas tu progreso?» con el
  jefe al lado, Más tarde / Ahora; luego correo, contraseña ×2, Guardar;
  luego «¡Progreso guardado!». Como mucho una vez por sesión hasta guardar.
  **Opciones → Cuenta** tiene «Guardar mi progreso» mientras es demo. En el
  login, **«Ya tengo cuenta»** bajo JUGAR (correo, contraseña, Entrar,
  «¿Olvidaste la contraseña?» → correo → código + contraseña ×2 → entra).
  Tras entrar con contraseña se pide una llave (60072) y solo se guarda
  esa. Si la llave guardada ya no vale (tras un cambio de contraseña),
  JUGAR dice que se entre con «Ya tengo cuenta». Textos en es/en/fr.
- **Pruebas:** Go: `TestClaimDemo`, `TestClaimDemoRefusals`,
  `TestAccountKeys`, `TestResetCodes`, `TestDeleteAccountRemovesKeys`,
  `TestResetMessage`, `TestSendResetCode`, `TestValidEmail`,
  `TestResetPerIPHour`, e2e `TestSaveDemoAccount`. Godot:
  `test/unit/demo_account_test.gd`; `test/save_account_smoke.gd` con
  `godot/tools/save_account_smoke.sh` (servidor propio con
  `demo_accounts` y sin `auto_register`, un `user://` por «navegador», 7
  fases; capturas en `~/codigo/capturas/s51/`);
  `godot/tools/web/save_account_test.mjs` (Chromium, la build web).

Desvíos y decisiones:

- La llave de la demo guardada se queda con su hash bcrypt (no se conoce la
  clave en claro); `VerifyKey` acepta los dos.
- Contraseñas: 8 a 72 bytes (el límite de bcrypt), y solo caracteres que
  viajan en cp1252: el login (1025) los manda así, y una contraseña con
  emoji no entraría nunca.
- «Ahora» no cuenta como guardado: si se cierra el formulario, el aviso
  puede volver tras otra victoria en otra sesión.
- Encontrado: en la web, cerrar una ventana y abrir otra en el mismo
  fotograma desajusta el historial del navegador; dos seguidas (Menú →
  Opciones → Guardar) sacaban la página del juego. El formulario se abre
  encima de Opciones; el fallo de `GuiLayer` sigue para otros saltos.
- Arreglado de paso: `go vet ./...` (copylocks en `store/seasons.go`).

**Verificado:** `go test ./...` (1451 tests y subtests en verde, 8 saltados,
0 fallos), `go vet ./...` limpio; `run_tests.sh --headless` (25 suites, 1601
comprobaciones, 0 fallos); `save_account_smoke.sh` 46/46 en 7 fases (es, y
fr/en para las capturas); `login_smoke` y `slots_smoke` siguen en verde; la
build web (`--export-release Web` + `pack_web.gd`) en Chromium contra un
servidor local: guardar desde Opciones, volver con JUGAR tras recargar y
«Ya tengo cuenta» en otro navegador, 4/4. Sin probar: el envío SMTP real
(no hay cuenta de correo); nada desplegado.

### Práctica guiada (dueño, 2026-11-24) → sprint propio después de esto

«¿No hay pelea de práctica con el típico parpadeo indicando la acción y un
bocadillo de texto?» Hoy los 10 consejos de Nilo salen todos antes del
combate (hasta «¡Genial, le has dado!» antes de dar). El dueño: **paso a
paso**, Nilo en un bocadillo en cada momento (colocar, Listo, moverse,
atacar, terminar turno), parpadea lo que hay que tocar, y solo avanza cuando
lo haces. Va después de «Guardar mi progreso».

## Falta

- [ ] **Dueño:** crear la cuenta y la página de itch.io (nombre Pippop
      Arena; gratis; tipo HTML5, «This file will be played in the browser»;
      viewport 1280×720; botón de pantalla completa; **sin** «Mobile
      friendly»; SharedArrayBuffer **sin** marcar; declarar el uso de IA).
      Pasar una clave de API de butler (va a `~/.secrets`).
- [ ] Subir: `--export-release Web`, `pack_web.gd`, y `butler push
      dist/web <usuario>/pippop-arena:web` (un solo canal).
- [x] **Antes de publicar** (dueño, 2026-11-24): «Guardar mi progreso» pasa
      la cuenta demo a una cuenta con correo y contraseña, sin perder nada,
      y se puede recuperar la contraseña por correo. Correo por Cloudflare
      (el dueño paga Workers), como el SMTP de pasaexam. Hecho (arriba);
      falta al desplegar: `auto_register: false` y la cuenta SMTP en
      `ARENA_MAIL_*` de oracle-2.
- [ ] Probar un combate entero desde la página en borrador (Chrome y
      Firefox), luego hacerla pública.
- [ ] Poner la URL en `ITCH` del Worker y desplegarlo; en oracle-2, que
      Caddy redirija también la IP directa (`https://140.238.172.196/`)
      salvo `/ws`.
- Nota: dentro del iframe de itch.io el navegador guarda los datos del juego
  aparte, así que la cuenta demo puede perderse con más facilidad
  (BACKLOG §13: pasar la cuenta demo a correo y contraseña).
