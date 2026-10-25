# StarLoco Arena 2.70 — Go server + Godot client

A tactical card-arena game you can run on your own computer: a **from-scratch
Go server** and a **from-scratch Godot 4 client** (players see the game as
**Pippop Arena**). It started as a rewrite of **DofusArena 2.70** — the
February 2012 retail build (rev 72909) of Ankama's card arena game — and is
moving to its own art, cards and texts.

> 🎨 **No retail client any more (2026-10-25).** The decompiled retail client,
> the reverse-engineering tooling and the scripts that converted retail art
> were removed from this branch; they are in git history only. The Godot
> client is getting its own art (milestone M7, see [`sprints/`](./sprints)).
> Until that lands, a fresh clone has **no game art**: the server runs and
> its tests pass, the client's headless tests pass, but there is nothing
> playable to download yet.

> 🌿 **Branches.** This is the **`v2.70`** branch. The 2006-era **2.04b** line
> (a different client and a different Go server) lives on the **`v2.04`** branch.

> 💬 **Stuck or have a question? [Join us on Discord](https://discord.com/invite/k3Yk9DuhgY)** — see [Community & Support](#-community--support).

---

## 🎮 Just want to play? Download the server

You don't need Go, Git, or a build step. Grab a ready-to-run server:

### **[⬇ Download the latest release](https://github.com/StarLoco/StarLoco-Arena/releases/latest)**

Available for **Windows**, **Linux** and **macOS** (Intel & Apple Silicon).

1. Unzip it and run **`arena-server`**.
2. It writes its own `config.yaml`, creates its database, and prints a **web
   portal** address.
3. Open that address in a browser and **register an account** — the first
   account created becomes the server administrator.
4. Point the Godot client at the server and log in (see the callout above:
   there is no playable client download until the new art lands).

Full walkthrough: [`docs/QUICKSTART.md`](./docs/QUICKSTART.md) (it is also
included inside every download).

> The download already includes the small set of card/spell/arena data the
> *server* needs to run fights.

The server tells you at startup when a newer version is available. That check is
a single anonymous request to GitHub's public releases page — nothing about your
server or your players is sent, and nothing is installed automatically. Turn it
off with `update_check: enabled: false` in `config.yaml`.

---

## What's in this branch

| Piece | What it is | Included here? |
|---|---|---|
| 🖥️ **Server** | The Go program the game client connects to. Accounts, chat, matchmaking, teams, full fights. | ✅ Yes — `server/` |
| 🗃️ **Server game data** | `data.bdat` / `indexes.bdat` + maps: the card/spell/arena records the *server's own logic* needs to run a fight. | ✅ Yes — `server/data-dist/` (~2.5 MB) |
| 🕹️ **Godot client** | The game client players use (login, lobby, fights). Proprietary, all rights reserved. | ✅ Yes — `godot/` (code; its art is being redone, see above) |

> ⚖️ **Server game data.** `server/data-dist/` is a small,
> deliberately curated subset of records — no art, audio, or executable code —
> needed for the server's own fight logic, and StarLoco (the maintainer) has
> chosen to include it so the server runs with zero setup. It stays until the
> project's own cards replace it (sprint S40). Nothing in this project links
> to a copy of the retail client. See [`DISCLAIMER.md`](./DISCLAIMER.md) for
> the exact split and [`SECURITY.md`](./SECURITY.md) for takedown requests.
>
> Everything else committed here is source, documentation and small tooling
> assets, so a plain `git clone` stays fast and **no Git LFS is required**.

The **server** and the **Godot client** are the actively developed parts.

---

## 🚀 Getting started (building from source)

> Only needed if you want to modify the server or run unreleased code. To just
> play, [download a release](#-just-want-to-play-download-the-server) instead.

### Step 0 — Install Go

| Tool | Why | Get it |
|---|---|---|
| **Go** 1.26.4+ | Builds and runs the server | <https://go.dev/dl/> — Windows: the `.msi`; macOS: the `.pkg` (or `brew install go`) |
| **Git** | Downloads the code | <https://git-scm.com/downloads> (or [GitHub Desktop](https://desktop.github.com/)) |
| **Node.js** (LTS) — *optional* | Only for the Studio editor | <https://nodejs.org/> |
| **Godot** 4.7 — *optional* | Runs the client in `godot/` | <https://godotengine.org/download> |

Check Go works — open a terminal and run:

```
go version
```

You should see something like `go version go1.26.4 …`. If you get "command not
found", close and reopen the terminal.

<details>
<summary><b>How to open a terminal</b></summary>

- **Windows:** Press `Win`, type **PowerShell**, press Enter. To open it *inside a
  folder*, open that folder in File Explorer, click the address bar, type
  `powershell`, and press Enter.
- **macOS:** Press `Cmd + Space`, type **Terminal**, press Enter. To move into a
  folder, type `cd ` (with a space) and then drag the folder onto the Terminal
  window and press Enter.
</details>

### Step 1 — Get the code

```
git clone --branch v2.70 https://github.com/StarLoco/StarLoco-Arena.git
```

No `git lfs` step is needed on this branch. Everything below is run from inside
the **`server`** folder of the clone.

### Step 2 — Game data

The repo already includes the data the *server* needs
(`server/data-dist/`), so fights work out of the box — `go run ./cmd/server`
finds it automatically and nothing is required here.

To use another copy of that data instead, point the server at a folder holding
`data.bdat`, `indexes.bdat` **and** `maps/`:

```
go run ./cmd/server --data /path/to/data
```

the `ARENA_DATA_DIR` environment variable, or `data_dir` in `config.yaml`.
The dev-only `server/data/` (a scratch spot for such a copy) is git-ignored —
unlike `server/data-dist/`, which is tracked deliberately (see the callout
above).

### Step 3 — Start the server

Open a terminal **in the `server` folder** and run:

```
go run ./cmd/server
```

The first time, Go downloads dependencies and this may take a minute. When it's
ready the program **keeps running** — that's normal — and prints:

```
  DofusArena 2.70 server dev

  Game server   0.0.0.0:5555
  Web portal    http://localhost:8080

  Settings written to config.yaml - edit it and restart to change anything.
  Press Ctrl+C to stop.
```

On that first run it creates, in the `server` folder:

- **`config.yaml`** — every setting, documented inline. Edit and restart.
- **`arena.db`** — the SQLite database (accounts, coaches, teams).

> **Leave this terminal window open** the whole time you want to play. To stop
> the server later, click the window and press `Ctrl + C`.

The bundled `configs/config.*.yaml` files remain as examples for PostgreSQL and
MySQL; pass one with `--config configs/config.postgres.yaml`.

### Step 4 — Create an account

Open the **web portal** address the server printed and fill in the form. The
**first account created becomes the administrator**.

That portal is also where you run the server from day to day. Signed in, every
player sees everything stored about them — coach, ladder record, fighters,
teams, cards, friends. As the administrator you additionally get a console:
search every account (by account *or* coach name), open a deep view of any of
them, create accounts, grant or revoke admin, delete an account and all its
data, view the site as any player to reproduce a bug they are reporting, and a
monitoring page with live runtime stats and Go's profiler. There is also a
public `/status` page and a public `/ladder`, both safe to share.

Full details: [`server/docs/WEB-PORTAL.md`](./server/docs/WEB-PORTAL.md).

> Two settings matter once the server is public: set **`web.session_secret`** to
> a long random string (otherwise everyone is signed out whenever you restart),
> and only turn on **`web.secure_cookies`** if you actually serve the site over
> `https://` — on plain HTTP it makes signing in silently impossible.

Prefer the command line, or scripting a lot of accounts? The seed tool still
works — open a **second** terminal in the `server` folder:

```
go run ./cmd/seedaccount --login test --password test123 --admin
```

### Step 5 — Play

From the repository root, with [Godot 4.7](https://godotengine.org/download):

```
godot --path godot
```

The login screen offers `127.0.0.1:5555`; log in with the account from Step 4.
The client needs art under `godot/assets/` that a fresh clone does not have
until the new art lands (see the callout at the top); the client's own docs
are in [`godot/README.md`](./godot/README.md).

---

## 🩹 Troubleshooting

| Problem | Fix |
|---|---|
| `go` / `git` **is not recognized** (Windows) or **command not found** (macOS) | The tool isn't installed or isn't on your `PATH`. Reopen the terminal after installing. |
| Server says **"No game data ... fights are unavailable"** | Shouldn't happen — data ships bundled. If `data/` got separated from `arena-server`, or `--data`/`data_dir` points somewhere empty, put it back next to the binary or drop the override. |
| **"another program is already using that port"** | Another copy of the server is still running. Close the other terminal (`Ctrl + C`), or change `addr` in `config.yaml`. |
| The **web portal** doesn't open | Read the address the server printed — port 80 usually needs admin rights, so it falls back to another port automatically. Set `web.addr` in `config.yaml` to pin one, or `web.enabled: false` to turn it off. |
| The client **can't connect** | Make sure the Step 3 terminal is still running. On first launch your firewall may ask for permission — **allow** it. |
| `go test -race` **fails to build** | The race detector needs a C compiler. It's optional — plain `go test ./...` works without one. |
| Something else | Ask on **[Discord](https://discord.com/invite/k3Yk9DuhgY)** — we're happy to help. |

---

## Repository layout

```
StarLoco-Arena/  (branch v2.70)
├── .github/workflows/      CI (build/test) and Release (release-please + GoReleaser)
├── .goreleaser.yaml        How the downloadable binaries are built and packaged
├── server/                 The Go 1.26 server — the primary active project
│   │                       (module github.com/StarLoco/arena-2.70)
│   ├── cmd/                Entry points: server, seedaccount, studio (editor), loadtest, dump*
│   ├── internal/           Implementation (protocol, gamedata, web portal, game, store…)
│   ├── configs/            Example YAML configs (sqlite / postgres / mysql)
│   ├── deploy/             Docker Compose files, one per database
│   ├── test/e2e/           End-to-end tests driving a real server over a real socket
│   ├── docs/               STATUS.md (start here), BUGS.md, DATA-COVERAGE.md, …
│   ├── COVERAGE.md         Per-opcode implemented / wire-audited / tested matrix
│   ├── data-dist/          Server game data (~2.5 MB) — COMMITTED, ships in releases
│   └── data/               Local scratch copy of game data — NOT committed
├── godot/                  The Godot 4 client (Pippop Arena); assets/ is NOT committed
├── sprints/                The roadmap: BACKLOG.md + one file per sprint
├── devlog/                 Per-session work log
└── docs/                   Game wiki (rules, breeds, spells, mechanics) + console commands
```

> **Why `data*/` lives inside `server/`:** it is the server's runtime input.
> `server/configs/*.yaml` resolves it as `data_dir: "data"`, relative to the
> `server/` working directory (falling back to the committed `data-dist/` — see
> [`internal/gamedata/locate.go`](./server/internal/gamedata/locate.go)). Do
> **not** move either — see [`AGENTS.md`](./AGENTS.md).

For full server details and the design docs, see
[`server/README.md`](./server/README.md), [`server/docs/`](./server/docs) and
[`server/COVERAGE.md`](./server/COVERAGE.md).

---

## Testing

From the `server` folder:

```
go vet ./...
go build ./...
go test ./...            # full suite, no C toolchain required
go test -race ./...      # requires a C toolchain (optional)
```

Tests that need the real game data **skip** (they don't fail) when `server/data`
is absent, so the suite is green on a fresh clone.

The Godot client has its own suite (`godot/run_tests.sh`) and live smoke
scripts that drive a real server — see [`godot/README.md`](./godot/README.md).

---

## Git

This branch does **not** use Git LFS — a plain `git clone` gets everything,
including the small (~2.5 MB) `server/data-dist/` the server needs to run
fights. Copyrighted material (the converted art under `godot/assets/`) and
regenerable outputs (build artifacts, `node_modules/`, dev databases, logs) are
excluded via [`.gitignore`](./.gitignore) — see [`DISCLAIMER.md`](./DISCLAIMER.md)
for exactly what is and isn't redistributed here.

---

## 💬 Community & Support

Questions, ideas, or just want to hang out? Join the community on Discord:

[![Join our Discord](https://discordapp.com/api/guilds/856945561421086730/widget.png?style=banner2)](https://discord.com/invite/k3Yk9DuhgY)

### Support the project by buying us a coffee

If this project is useful to you, a coffee is hugely appreciated and helps keep
the work going. ☕

[![Buy Me A Coffee](https://cdn.buymeacoffee.com/buttons/default-orange.png)](https://www.buymeacoffee.com/starloco)

---

## License & legal

- The **Go server** under `server/` and this project's docs are released under
  the [MIT License](./LICENSE).
- The **Godot client** under `godot/` is **proprietary — © 2026 Daviaan, all
  rights reserved** (see [`godot/LICENSE`](./godot/LICENSE)). It is not
  MIT-licensed; you may not copy, modify or distribute it without permission.
- This repository is an **independent, non-commercial** preservation and
  interoperability project and is **not affiliated with Ankama**.
  **DofusArena**, **Dofus**, and all related assets are the property of
  **Ankama**. The MIT license does **not** cover that third-party material.
- The decompiled client sources that used to live under `client/decompiled/`
  were removed from the tree on 2026-10-25; they remain in git history.
- See [`DISCLAIMER.md`](./DISCLAIMER.md) for the full non-affiliation and
  copyright notice, [`NOTICE`](./NOTICE) for third-party attributions, and
  [`SECURITY.md`](./SECURITY.md) for takedown/vulnerability reporting.

## Contributing

See [`CONTRIBUTING.md`](./CONTRIBUTING.md) and [`AGENTS.md`](./AGENTS.md). By
participating you agree to the [Code of Conduct](./CODE_OF_CONDUCT.md).
