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

## Falta

- [ ] **Dueño:** crear la cuenta y la página de itch.io (nombre Pippop
      Arena; gratis; tipo HTML5, «This file will be played in the browser»;
      viewport 1280×720; botón de pantalla completa; **sin** «Mobile
      friendly»; SharedArrayBuffer **sin** marcar; declarar el uso de IA).
      Pasar una clave de API de butler (va a `~/.secrets`).
- [ ] Subir: `--export-release Web`, `pack_web.gd`, y `butler push
      dist/web <usuario>/pippop-arena:web` (un solo canal).
- [ ] **Antes de publicar** (dueño, 2026-11-24): «Guardar mi progreso» pasa
      la cuenta demo a una cuenta con correo y contraseña, sin perder nada,
      y se puede recuperar la contraseña por correo. Correo por Cloudflare
      (el dueño paga Workers), como el SMTP de pasaexam.
- [ ] Probar un combate entero desde la página en borrador (Chrome y
      Firefox), luego hacerla pública.
- [ ] Poner la URL en `ITCH` del Worker y desplegarlo; en oracle-2, que
      Caddy redirija también la IP directa (`https://140.238.172.196/`)
      salvo `/ws`.
- Nota: dentro del iframe de itch.io el navegador guarda los datos del juego
  aparte, así que la cuenta demo puede perderse con más facilidad
  (BACKLOG §13: pasar la cuenta demo a correo y contraseña).
