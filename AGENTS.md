# AGENTS.md — working in this repository

Guidance for AI agents (and humans) contributing to the **DofusArena 2.70**
line. Read this before making changes. For the human-facing overview see
[`README.md`](./README.md).

## What this project is

A preservation + reverse-engineering project for **DofusArena 2.70** (the
Feb-2012 retail build, rev 72909): a decompiled client used as the protocol
reference, plus a **from-scratch Go server** that is wire-compatible with it.

The client is fixed and cannot be changed, so the server must match it
byte-for-byte. The decompiled client under `client/` is the source of truth for
every opcode, field order and data layout.

> The 2006-era **2.04b** line (a separate client + Go server) lives on the
> **`v2.04`** branch of this repository. Comments in this codebase that say
> "ported from the v2.04b reference" refer to that branch — it is a useful
> *unobfuscated* cross-check, but 2.70 re-tuned most numbers, so client data
> always wins over anything inherited from 2.04b.

## Repository map

| Path | What it is | Do you edit it? |
|---|---|---|
| `server/` | **The Go 1.26 server — the primary active project.** Module `github.com/StarLoco/arena-2.70` | Yes — primary work happens here |
| `server/docs/` | **Start at `STATUS.md`** (current state, open items, invariants), then `DATA-COVERAGE.md` / `BUGS.md` | Yes, keep in sync with code |
| `godot/` | The Godot 4 client (login → coach creation → native lobby → native combat). `godot/assets/` is git-ignored on purpose; tests via `godot/run_tests.sh` | Yes — active work |
| `sprints/` | **The roadmap**: `BACKLOG.md` (live work queue) + one `SNN-*.md` per sprint with its evidence | Yes, keep in sync with the work |
| `devlog/` | The agent's per-session log — what was asked, done, found, and left unverified | Yes — add an entry per session |
| `server/COVERAGE.md` | Per-opcode implemented / wire-audited / tested matrix | Yes, keep current |
| `server/data-dist/` | The redistributable server-data subset (`data.bdat` + `indexes.bdat`, maps) — ships in git and in releases | Occasionally, deliberately (see constraint 4) |
| `server/data/` | Local scratch copy for pointing a dev build at your own client instead | No — **git-ignored**, local input only |
| `client/decompiled/` | Decompiled (obfuscated) 2.70 client source — the protocol reference | No — read for provenance |
| `client/analysis/` | Protocol + data-format write-ups (`PROTOCOL*.md`, `DATA-FORMAT.md`, `opcode_map.csv`) | Yes, when you learn something new |
| `client/compiled/` | The runnable retail client (launcher, `core.jar`, assets, bundled JRE) | No — **git-ignored**, ~436 MB, local only. Never committed here, but linked from the release notes/README/web portal to a maintainer-hosted mirror (see constraint 5) |
| `client/arena-mcp/`, `client/control-agent/` | RE tooling: an MCP server + a Java agent that drive the live client for testing | Occasionally |
| `client/deobf-lab/` | Deobfuscation pipeline (mappings + scripts); its `build/` and `decompiled/` outputs are ignored | Occasionally |
| `tools/` | RE reference snippets + `cfr.jar` (Java decompiler) | Occasionally |
| `docs/` | Game wiki (rules, breeds, spells, mechanics), console commands, `QUICKSTART.md` (ships inside releases) | Occasionally |
| `.github/workflows/` | `ci.yml` (build/test on Linux+Windows), `release.yml` (release-please → GoReleaser) | Occasionally |
| `.goreleaser.yaml` | How the downloadable binaries are cross-compiled and packaged | Occasionally |

## Critical constraints — do not break these

1. **Do not move `server/data/`.** The server resolves it from
   `server/configs/*.yaml` (`data_dir: "data"`, relative to the `server/`
   working directory). It is **git-ignored** — a local scratch copy for
   pointing a dev build at your own client. Tests that need it must **skip**,
   not fail, when it is absent.
2. **The Go module path is `github.com/StarLoco/arena-2.70`** (in
   `server/go.mod`) even though the folder is just `server/`. This is
   intentional — do **not** rewrite imports to match the folder name.
3. **`server/cmd/studio` embeds `frontend/dist` via `//go:embed`.** A committed
   placeholder `server/cmd/studio/frontend/dist/.gitkeep` keeps the directory
   present so `go build ./...` works without first building the frontend. Do not
   delete it.
4. **This branch does not use Git LFS.** Everything committed is source, docs or
   small tooling assets. The heavy, copyrighted material (`client/compiled/`,
   `server/data/`) is excluded by `.gitignore` and must stay that way — never
   `git add -f` it.
   **`server/data-dist/` is the one deliberate exception**: a small (~2.5 MB)
   maintainer-curated subset of card/spell/arena *records* (no art, audio, or
   executable code), committed on purpose so the server and its releases work
   without every operator sourcing a client first. It is edited only via an
   explicit maintainer decision (StarLoco), not by force-adding whatever
   happens to be in a local `server/data/`. Keep `DISCLAIMER.md` and `NOTICE`
   in sync with whatever it contains.
5. **Nothing in this project links to a copy of the retail client, and
   `web.client_download_url` defaults to empty.** This replaces an earlier
   decision (the default used to be a maintainer-hosted Mega mirror, also
   printed in the release notes and the README). It was reversed deliberately
   in the compliance pass, for a reason worth keeping: because it was the
   *default*, every operator who unzipped a release and ran it republished
   that link from their own public portal without ever choosing to — spreading
   the one genuinely unambiguous legal exposure in the project onto strangers
   who could not weigh it.

   So: **do not re-add the URL** to `config.go`, `config.template.yaml`,
   `.goreleaser.yaml`'s `release.footer`, `README.md`, or the portal
   templates, and do not "restore" it thinking it was lost. The config field
   still exists, so an operator with a lawful copy can opt in under their own
   name — that is the only path this project supports.
   `TestNoClientDownloadLinkByDefault` pins the default.
6. **The wire protocol is sacred.** The retail client cannot be changed, so
   server output must match the decompiled reference in `client/decompiled/` and
   the specs in `client/analysis/`. Never "improve" the wire format.

## Build / test / run (from `server/`)

```powershell
go mod tidy
go build ./...                                   # must pass; studio needs frontend/dist/.gitkeep
go vet ./...
go test ./...                                    # full suite, no CGO
go test -race ./...                              # needs a C toolchain
go run ./cmd/server                              # listens on 0.0.0.0:5555
go run ./cmd/server --config configs/config.sqlite.yaml
go run ./cmd/seedaccount --login test --password test123
```

- First run creates `config.yaml` (from the embedded, fully commented
  `internal/config/config.template.yaml`) and `arena.db` (SQLite, WAL) in
  `server/` — both git-ignored. It also finds the committed
  `server/data-dist/` automatically, so fights work with no further setup.
- The retail client already ships pointed at `127.0.0.1:5555`
  (`client/compiled/game/config.properties` → `proxyAddresses_1`), so it
  connects with no change.
- End-to-end tests live in `server/test/e2e/` and drive a real server over a
  real socket.

## Releases

Fully automated; **do not tag by hand**. Conventional-Commit messages on `v2.70`
drive `release-please`, which maintains a release PR; merging it tags, creates
the GitHub release, and triggers GoReleaser to attach the binaries. See
["How a release happens"](./CONTRIBUTING.md#how-a-release-happens).

```powershell
goreleaser check                              # validate .goreleaser.yaml
goreleaser release --snapshot --clean         # build all targets locally, publish nothing
```

Two constraints worth knowing before editing the workflows:

1. **GoReleaser must stay in the same workflow run as release-please.** Tags
   pushed with the built-in `GITHUB_TOKEN` do not trigger new workflow runs, so
   a separate `on: push: tags` build would never fire and releases would ship
   with no binaries.
2. **`cmd/studio` is excluded from Linux CI and from releases.** It is a Wails
   desktop app needing CGO + GTK/WebKit headers; the shipped server is built
   with `CGO_ENABLED=0` so one Linux runner cross-compiles every target.
   Windows CI still builds and tests it.

## Testing against the live client

`client/arena-mcp/` exposes an MCP server that boots the retail client with
`client/control-agent/control-agent.jar` injected as a `-javaagent`, then drives
it with synthetic input and returns screenshots + logs. See
[`server/docs/CLIENT-TESTING.md`](./server/docs/CLIENT-TESTING.md).

This requires the git-ignored `client/compiled/` tree to be present locally.
A live GUI run remains the final validation step — unit and E2E tests are not a
substitute for it.

## Conventions

- **Go**: standard `gofmt`; keep the byte-exact wire protocol.
- **Tests**: prefer table/real-data tests; real-data tests **skip** (not fail)
  when `server/data` is absent. Keep that behavior.
- **Docs**: keep [`server/docs/STATUS.md`](./server/docs/STATUS.md) current — it
  is the cold-start entry point (what is done, in flight, open, and the
  invariants). Add a `server/docs/BUGS.md` entry and a
  `server/docs/DATA-COVERAGE.md` change-log row for each fix, and update
  `server/COVERAGE.md` when opcode coverage changes.
- **Line endings / encoding**: this repo does not force text normalization
  (`.gitattributes` only marks binaries). Preserve existing line endings; avoid
  whole-file reformatting that creates CRLF churn.
