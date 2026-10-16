# 2026-10-16 — Reorganización de docs

## Qué se pidió

Saber el estado del proyecto y si había roadmap o sprints. Después: quitar el
roadmap heredado de la base del fork para no confundirlo con el propio, fundir
`pendiente/` en `sprints/` y abrir este devlog.

## Qué se hizo

- **`ROADMAP.md` retirado**, junto con `server/internal/game/roadmap_status_test.go`,
  que solo validaba los marcadores de ese fichero (y se saltaba solo si faltaba,
  así que habría quedado como test muerto). Ningún otro test usaba sus helpers.
  Sigue legible con `git show v2.70:ROADMAP.md`.
- **`pendiente/README.md` → `sprints/BACKLOG.md`** (con `git mv`, el historial se
  conserva). Mantiene la numeración de secciones, así que las referencias `§5`,
  `§6`, `§7` de `godot/run_tests.sh` y `godot/tools/export_islands.gd` siguen
  valiendo; solo cambió la ruta.
- **§4 del backlog corregida**: decía "async PvP sin implementar", pero las fases
  1 (`5bd7427a`) y 2 (`8220cac4`) ya estaban hechas según `godot/ASYNC-PVP.md` y
  los commits. La cabecera también apuntaba al FX como §5 cuando es §6.
- Las dos referencias de docs a `ROADMAP.md` (`server/docs/STATUS.md`,
  `server/COVERAGE.md`) ahora apuntan a `git show v2.70:ROADMAP.md`.
- `sprints/README.md` reescrito como punto de entrada del roadmap;
  `AGENTS.md` lista ahora `godot/`, `sprints/` y `devlog/`, que no salían en el mapa.

## Encontrado por el camino

- **El fork no ha borrado ni un fichero** respecto a `v2.70`
  (`git diff --diff-filter=D origin/v2.70...main-covaga` vacío, y ningún commit
  del fork borra nada). El único recorte visible es el hall caminable, que se
  movió a `godot/deprecated_hall/` en vez de borrarse. Si hubo más recortes, no
  están en `origin`.
- **El checkout de `/srv/codigo/StarLoco-Arena` es de solo lectura para el
  usuario `claudio`**: dueño uid 501 (el Mac), máscara ACL `r-x`. Este trabajo se
  hizo en un clon aparte y se empujó a `origin/main-covaga`; ese checkout hay
  que actualizarlo con `git pull` desde una cuenta con permiso.
- Quedan **comentarios de código** que citan "ROADMAP item N" (siete, en
  `server/internal/game` y `gamedata`). No se tocaron: son referencias
  históricas y `sprints/README.md` dice dónde resolverlas.

## Sin verificar

- **`go build ./...` / `go test ./...` no se corrieron**: no hay toolchain de Go en
  esta máquina. El riesgo es bajo (solo se borró un `_test.go` autocontenido y
  se tocaron comentarios de shell/GDScript), pero lo confirma la CI del push.
