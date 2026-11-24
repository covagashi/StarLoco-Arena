# 2026-11-24 — S51: «Guardar mi progreso»

El coordinador pidió implementar la sección «Guardar mi progreso» de
`sprints/S51-itchio.md` (la especificación). Detalle y cifras en el sprint.

## Qué se hizo

- **Servidor:** migración 24 (`account_keys`, `password_resets`),
  `AccountRepo.ClaimDemo` / llaves / códigos, opcodes 60070–60077
  (`game/account_save.go`), login con correo (en minúsculas, nunca se
  auto-registra) y con llave, paquete `internal/mail` (SMTP 465; sin host,
  el código va al log), sección `mail:` y `ARENA_MAIL_*`, `/privacy` 1.1.
- **Cliente:** `save_account_panel.gd` (aviso tras ganar, formulario,
  hecho), «Guardar mi progreso» en Opciones, «Ya tengo cuenta» y la
  recuperación en la pantalla de login, `demo_account.cfg` con
  `claimed`, textos en es/en/fr.
- **Pruebas:** Go (store, mail, game, e2e), unitarias de Godot,
  `save_account_smoke.gd` + `tools/save_account_smoke.sh` (7 fases),
  `tools/web/save_account_test.mjs` (Chromium, build web).

## Encontrado por el camino

- `go vet ./...` fallaba ya antes (copylocks en `store/seasons.go`):
  arreglado.
- En la web, cerrar una ventana y abrir otra en el mismo fotograma pierde
  una entrada del historial; dos seguidas (Menú → Opciones → otra) mandaban
  la página atrás, fuera del juego. Esquivado aquí (el formulario se abre
  encima de Opciones); el fallo de `GuiLayer.close`+`open` sigue ahí.

## Sin verificar

- El envío real por SMTP (no hay cuenta de correo configurada): probado
  el mensaje y el modo sin host; nada desplegado en oracle-2.
