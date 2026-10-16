# 2026-10-16 — Permisos del checkout + S02

## Qué se pidió

Arreglar el usuario del checkout (la copia desde el Mac lo dejó de solo lectura)
y hacer un sprint rápido con lo barato del stack: pnpm + oxlint + oxfmt + knip
en el studio y HTMX en el panel de bug reports.

## Qué se hizo

- **Permisos**: `sudo chown -R claudio:claudio /srv/codigo/StarLoco-Arena`, igual
  que el resto de `/srv/codigo`. Tarda mucho (árbol grande con `client/compiled`
  y `godot/assets`). El trabajo siguió en el clon del scratchpad mientras tanto.
- **S02** cerrado: ver [`sprints/S02-studio-tooling.md`](../sprints/S02-studio-tooling.md).
  Dos commits de código (tooling + knip, y la pasada de oxfmt aparte) y uno de docs.
- **S01** cerrado del todo: su lane Godot ya había salido verde en un runner real.

## Encontrado por el camino

- **HTMX descartado** antes de tocarlo: el portal tiene una CSP sin `script-src`
  fijada por un test, como defensa contra XSS almacenado. Decisión del dueño;
  queda en `BACKLOG.md` §8.
- **La CI no se dispara con los pushes**: una sola ejecución en todo el repo, y
  fue manual. Es lo más urgente del backlog: sin esto, la lane nueva de S02 y
  las de S01 no vigilan nada.
- Corrige la entrada anterior ([`2026-10-16-docs-reorg.md`](./2026-10-16-docs-reorg.md)):
  ahí decía que `go build`/`go test` no se pudieron correr. Ahora sí corrieron
  (Go 1.26.9 en `~/.local/share/go`): build, vet, gofmt y los tests de
  `internal/game` e `internal/web`, todo OK.

## Sin verificar

- La lane `studio-frontend` en GitHub (por lo de la CI) y el studio bajo `wails dev`.
- La suite completa de Go (`go test ./...`, incluido `test/e2e`). Solo corrieron
  los dos paquetes tocados de forma indirecta.
