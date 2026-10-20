# 2026-10-20 — Puesta a punto del entorno en la ROG Ally

Pedido: "estás en un nuevo dispositivo, en una ROG Ally: revisa tu centro de
trabajo e instala lo que necesites". Esta entrada deja escrito qué había, qué
se instaló y qué cambia respecto al homelab, para que la siguiente sesión no
lo redescubra. No toca código.

## La máquina

Bazzite 44 (Fedora Silverblue, inmutable), Ryzen Z1 Extreme, 16 núcleos,
11 GB de RAM + 5,7 GB de swap, ~417 GB libres en `/var/home`. GPU AMD con
Mesa 26 (radeonsi) y sesión GNOME/Wayland viva en `DISPLAY=:0`. Repos en
`~/codigo` (`/home` → `/var/home`). `godot/assets` (2,1 GB) y
`client/compiled` están; `server/data` no (solo `data-dist`, que basta).

## Instalado (todo en espacio de usuario, sin `rpm-ostree`)

- **Go 1.26.10** en `~/.local/share/go` (tarball oficial, sha256 comprobado
  contra `go.dev/dl`). `go.mod` pide 1.26.6. PATH, `GOROOT` y `GOPATH` en
  `~/.bashrc.d/starloco-dev.sh`; en shells no-login hay que exportar
  `~/.local/share/go/bin` a mano.
- **Godot 4.7.1** en `~/.local/bin/godot` (zip oficial, sha512 comprobado
  contra `SHA512-SUMS.txt` de la release).
- Ya estaba: `xvfb-run`, Mesa (llvmpipe incluido), gcc/make, Java 21,
  node 24 y pnpm (árbol Homebrew ajeno; su `brew` no arranca), unzip, jq,
  python3 con módulo `sqlite3`. No hay CLI `sqlite3`: para tocar `arena.db`
  usar `python3 -c "import sqlite3"`.

## Verificado

- `server/`: `go build ./...`, `go vet ./...` y `go test ./...` → 11 paquetes
  OK, 0 fallos (~17 s). `go test -race ./internal/config/` también pasa (hay
  C toolchain).
- `godot/run_tests.sh --headless` → `suites=6 checks=158 failures=0`.
- `env -u DISPLAY -u WAYLAND_DISPLAY ./run_tests.sh --visual` → las cuatro
  previsualizaciones bajo xvfb/llvmpipe en ~32 s; `/tmp/fight-ui-onebit.png`
  es un HUD 1 bit real (mirado).
- `ssh -T git@github.com` autentica como `covagashi`; el push va por SSH.

## Cambios respecto al homelab

- Aquí hay pantalla: la lane visual sin `env -u DISPLAY` abriría ventanas
  sobre el escritorio del dueño. Por defecto, forzar xvfb.
- No hay Samba ni `/srv/codigo`. `SendUserFile` sigue fallando ("not on a
  project thread"). Las capturas van a `~/codigo/capturas/<sprint>/` (creado
  hoy, vacío) y el dueño las abre en la propia Ally.
- Menos RAM (11 GB; un `java` de ~1,8 GB y Steam residentes). Un Godot a la
  vez y `free -h` antes de lo pesado.
- Identidad git del repo fijada a la de los commits anteriores (`Daviaan`),
  solo en este checkout.

## Sin verificar

- La batería en vivo contra el servidor local (smokes de `godot/test/`): no
  se levantó servidor en esta sesión.
- `goreleaser` no está instalado; las releases son cosa de CI, no se necesita
  aquí de momento.

## Para empezar mañana

Lo mismo que dejó [`2026-10-18-s18-altar.md`](./2026-10-18-s18-altar.md):
visto bueno del buzón y el altar (las hojas hay que regenerarlas aquí, en
`~/codigo/capturas/s18/`, porque no se copiaron del homelab), y seguir la
tanda 2 de S18 con el cementerio.
