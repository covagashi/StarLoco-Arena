# S02 — Tooling del stack en el studio (sprint rápido)

**Abierto y cerrado:** 2026-10-16 · **Rama:** `main-covaga` · **Estado:** 🟢 cerrado

## Objetivo

Aplicar al frontend del studio (`server/cmd/studio/frontend`, TS estricto + Vite,
~3.200 líneas de TS) las herramientas del stack que encajan sin reescribir nada:
**pnpm** (el backend es Go, así que pnpm y no Bun), **oxlint**, **oxfmt** y
**knip**, con una lane de CI que lo vigile.

Propuesto también: **HTMX en el panel de bug reports** del portal web. Lo
descarté antes de tocarlo (ver abajo).

## Tareas

- [x] npm → pnpm: fuera `package-lock.json`, dentro `pnpm-lock.yaml` y
      `packageManager: pnpm@12.14.0`; `wails.json` usa pnpm en install/build/dev.
- [x] `pnpm-workspace.yaml` con `allowBuilds: { esbuild: true }` — pnpm bloquea
      los scripts de build por defecto y esbuild es el único que lo necesita.
- [x] Scripts: `typecheck` (`tsc --noEmit`; `vite build` nunca comprobaba
      tipos), `lint`, `fmt`, `fmt:check`, `knip`, y `check`, que corre los cuatro.
- [x] oxfmt con `printWidth: 120`: es el estilo que ya tenía el código. Con 100
      cambiaban 283/169 líneas y con 120, 169/188. La pasada de formato va en un
      commit aparte.
- [x] Arreglar lo que encontró knip (abajo).
- [x] Lane `studio-frontend` en `ci.yml` (Linux: la parte TS no necesita CGO
      ni Wails): `pnpm install --frozen-lockfile`, `pnpm check`, `pnpm build`.
- [ ] ~~HTMX en el panel de bug reports~~ — descartado, ver abajo.

## Lo que encontró knip

Siete exports que nadie importaba. Les quité el `export`, y `tsc` con
`noUnusedLocals` confirmó que los siete estaban muertos del todo. Los borré:

| Símbolo | Fichero | Nota |
|---|---|---|
| `connected` | `backend.ts` | |
| `getMapGfx`, `getMapSprites`, `getMapRender` | `backend.ts` | Envoltorios de bindings Go que el frontend nunca llama. Los métodos Go (`maps.go`, `maprender.go`) se quedan: siguen tipados en `AppBindings` y tienen tests Go. Ver backlog. |
| `uiLang` | `i18n.ts` | |
| `fmtList` | `table.ts` | |
| `focusMap` | `maps.ts` | Era el único que escribía `pendingMapId`, un deep-link "set by main.ts crosslink" que `main.ts` nunca tuvo. También se borró la rama que lo leía. |

Los 5 tipos que knip marcó (`MapCell`, `MapGfx`…) siguen en uso dentro de
`backend.ts`; solo perdieron el `export`.

## Por qué no HTMX en el portal

El portal web **no lleva JavaScript a propósito**. Su CSP es
`default-src 'none'` sin `script-src` (`internal/web/web.go`), y hay un test que
lo fija, `security_headers_test.go`: falla si la CSP empieza a permitir scripts,
*"default-src 'none' is what makes stored XSS unexploitable"*. Los bug reports
son justo texto escrito por jugadores que se pinta en el panel de admin. Meter
HTMX obliga a abrir `script-src 'self'` y a quitar esa garantía.

`html/template` ya escapa la salida, así que abrirlo no es un agujero inmediato.
Pero quita la segunda línea de defensa en la página que más contenido ajeno
pinta. Es una decisión del dueño del repo, no un ajuste de tooling, así que va
al backlog como pregunta.

## Resultado

### Evidencia

| Comprobación | Resultado |
|---|---|
| `tsc --noEmit` sobre el código original | exit 0 (ya estaba limpio) |
| `oxlint` sobre el código original | exit 0, 0 avisos |
| `knip` sobre el código original | 7 exports + 5 tipos sin usar → arreglados → exit 0 |
| `pnpm check` final (typecheck + lint + fmt:check + knip) | exit 0 |
| `pnpm build` final | ✓ built, `dist/.gitkeep` restaurado (Vite lo borra con `emptyOutDir`) |
| `go build` / `go vet` (todo menos `cmd/studio`, como en CI) | OK |
| `gofmt -l ./cmd ./internal ./test` | vacío |
| `go test ./internal/game/ ./internal/web/` | `ok` los dos (279 s y 233 s) — incluye la retirada de `roadmap_status_test.go` del commit anterior |

Go 1.26.9 instalado en `~/.local/share/go` del servidor para poder verificar esto;
antes no había toolchain.

### Encontrado por el camino

- **La CI no se dispara con los pushes.** En todo el repo hay una sola
  ejecución: [run 38454218639](https://github.com/covagashi/StarLoco-Arena/actions/runs/38454218639),
  `workflow_dispatch` sobre `f56c0ae5`. Ningún push posterior, incluidos los de
  hoy, ha lanzado nada, aunque `ci.yml` tiene `on: push: branches: [v2.70, main-covaga]`.
  El repo es un fork de GitHub, y en los forks las Actions vienen desactivadas
  para los pushes hasta que se habilitan en la pestaña *Actions*. No lo puedo
  comprobar sin acceso a los ajustes del repo. **Hasta que esto se arregle, la
  lane nueva no protege nada.**
- Esa misma ejecución confirma lo último que S01 tenía sin verificar: el carril
  Godot salió verde en un runner real.

### Sin verificar

- La lane `studio-frontend` no ha corrido en GitHub (por lo de arriba). Los
  mismos comandos pasan en local con Node 26.8.1. La lane usa Node 24.
- El studio no se ha arrancado con `wails dev` (no hay Wails ni GTK/WebKit en
  esta máquina). El cambio en `wails.json` es solo el gestor de paquetes. El
  código borrado no tenía llamadas, según `tsc`.
