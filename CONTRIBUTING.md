# Contributing

Thanks for your interest in this project. This guide covers how to work in the
repository. For the deeper agent/contributor reference (repo map, critical
constraints), read [`AGENTS.md`](./AGENTS.md).

## Scope of contributions

This branch (`v2.70`) started as a rewrite of **DofusArena 2.70** (the Feb-2012
retail build, rev 72909). The actively developed components are the **Go
server** in [`server/`](./server) and the **Godot client** in
[`godot/`](./godot). The Godot client is **proprietary (all rights reserved,
see [`godot/LICENSE`](./godot/LICENSE))**: contributions to it are accepted
only by arrangement with its copyright holder.

> The 2006-era **2.04b** line lives on the **`v2.04`** branch. Contributions for
> that line belong there, not here.

The retail client, its decompiled sources, the reverse-engineering tooling
and the asset-extraction scripts were removed on 2026-10-25 (sprint S32); they
are in git history only. The project is moving to its own art, cards and texts
(milestone M7, [`sprints/`](./sprints)).

- `server/data/` — a git-ignored scratch copy of game data, for local
  development.
- `server/data-dist/` — the small, deliberately-curated data subset that *is*
  committed and ships in releases (see `AGENTS.md` constraint 4). Changes to it
  are a maintainer decision, not a routine contribution.

Please **do not** add decompiled third-party code, retail files or scripts
that extract from the retail client, and do not commit copyrighted assets.
`server/data-dist/` is the one deliberate exception, covered by
`DISCLAIMER.md`, until the project's own cards replace it (S40).

## Getting set up

Prerequisites and full instructions are in [`README.md`](./README.md). In short,
from `server/`:

```powershell
go mod tidy
go build ./...
go vet ./...
go test ./...        # full suite, no CGO required
go test -race ./...  # requires a C toolchain
```

No Git LFS is needed — a plain `git clone` gets everything that is tracked.

## Coding conventions

- **Go:** standard `gofmt`; keep changes focused and idiomatic.
- **The wire protocol is a contract** between the server and the Godot
  client: change a message only in both at once, in the same commit, with the
  protocol tests updated.
- **Do not move `server/data/`** — `server/configs/*.yaml` resolves it as
  `data_dir: "data"`, relative to the `server/` working directory.
  See [`AGENTS.md`](./AGENTS.md) for the exact constraints.
- **Module path** stays `github.com/StarLoco/arena-2.70` even though the folder
  is just `server/`. Don't rewrite imports to match the folder.
- **Tests:** prefer table-driven and real-data tests; real-data tests must
  **skip** (not fail) when `server/data` is absent.
- **Docs:** keep `server/docs/STATUS.md` current, add a `server/docs/BUGS.md`
  entry and a `server/docs/DATA-COVERAGE.md` row for each fix, and update
  `server/COVERAGE.md` when opcode coverage changes.
- **Line endings:** this repo does not force normalization; preserve existing
  line endings and avoid whole-file reformatting that creates CRLF churn.

## Commit messages

Releases are automated, and the version number and changelog are derived from
commit messages, so this project uses
[Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <description>
```

| Type | Use it for | Effect on the next release |
|---|---|---|
| `feat` | a new capability | bumps the **minor** version, listed under *Features* |
| `fix` | a bug fix | bumps the **patch** version, listed under *Bug fixes* |
| `perf` | a performance improvement | patch bump |
| `docs` | documentation only | no version bump |
| `refactor`, `test`, `build`, `ci`, `chore` | internal work | no version bump, hidden from the changelog |

Examples:

```
feat(web): let players register their own accounts
fix(fight): stop the turn clock leaking after a forfeit
docs: explain the update check in the quick start
```

A breaking change adds a `!` after the type (`feat!: ...`) or a
`BREAKING CHANGE:` footer. While the project is pre-1.0 that bumps the minor
version, not the major one.

If a commit doesn't follow this format nothing breaks — it simply won't appear
in the changelog.

## Pull requests

1. Keep PRs small and single-purpose.
2. Ensure `go build ./...`, `go vet ./...`, and `go test ./...` pass from
   `server/`. CI runs these on Linux and Windows for every PR.
3. Run `gofmt -w` on files you touched (CI enforces it).
4. Describe what changed and why; reference any opcode/design doc you touched.
5. By contributing, you agree that your contributions are your own original work
   and are licensed under the project's [MIT License](./LICENSE).

## How a release happens

Nobody tags by hand:

1. Commits land on `v2.70`.
2. **release-please** keeps a *"chore: release x.y.z"* pull request open,
   containing the version bump and the generated `CHANGELOG.md`.
3. Merging that PR creates the git tag and the GitHub release.
4. **GoReleaser** then builds Windows/Linux/macOS binaries and attaches them,
   with a `checksums.txt`.

To cut a release, merge the release PR. To hold one back, leave it open.

## Reporting bugs & security issues

Use GitHub issues for ordinary bugs. For anything security-sensitive, follow
[`SECURITY.md`](./SECURITY.md) instead of opening a public issue.
