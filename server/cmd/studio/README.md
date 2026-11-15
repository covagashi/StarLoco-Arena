# Studio (`server/cmd/studio`)

A desktop content browser and card editor for the game's own data in
`server/content` (since S40/S43 nothing comes from the old client). It is the
owner's balance tool.

- **Tables** — spells, summonings and static effects (`server/content/rules`,
  decoded by `gamedata.LoadRulesContent`) and the coach and fighter cards
  (`server/content/cards`, `gamedata.LoadCardContent`): sortable, faceted,
  CSV export, detail drawer.
- **Card editor** — a card's drawer edits its balance fields (value, rank,
  price, level, booster weight, bound / undestructible; a fighter card's AP cost
  and range) and saves with `gamedata.WriteCardContent`, one card per line, so a
  save diffs as that card alone. Bad edits are rejected and change nothing.

Run from a checkout, it reads (and the editor writes) `server/content`, so it
shows exactly what the server loads. Anywhere else it shows the copy embedded in
the binary (package `content`), read-only.

## Build / run

A [Wails v2](https://wails.io) app: Go backend in this directory, TypeScript +
Vite frontend in `frontend/` (pnpm). It needs CGO and the OS webview
(WebKitGTK on Linux, WebView2 on Windows, WKWebView on macOS).

```sh
go install github.com/wailsapp/wails/v2/cmd/wails@latest
wails dev        # hot reload
wails build      # build/bin/

go test ./cmd/studio                    # from server/
cd frontend && pnpm install --frozen-lockfile && pnpm check && pnpm build
```

`frontend/dist` holds only a `.gitkeep` in git; the Go `//go:embed` needs it to
exist, and `wails build` fills it.
