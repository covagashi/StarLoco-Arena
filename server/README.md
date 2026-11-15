# DofusArena 2.70 server

A from-scratch Go server wire-compatible with the retail **DofusArena 2.70**
client (build 2.70, rev 72909). Built from the protocol/data specs in
[`../client/analysis/`](../client/analysis).

Separate Go module (`github.com/StarLoco/arena-2.70`) parallel to the existing
the 2006 server (`server/` on this repo's **`v2.04`** branch), which stays intact as a reference.

## Status

Full pre-fight + fight pipeline implemented end-to-end: login → coach → world
(with dynamic area-of-interest) → chat/whisper → friends/ignore → inventory/equip
→ **card trading** → fighters → teams → matchmaking → a complete fight to victory.

Scaling-hardened: actor-model fights (race-clean), async backpressured writes,
AoI-scoped broadcasts, multi-DB via config, Docker per DB. Load-tested at ~2000
concurrent coaches on one instance (~170 MB).

**Coverage & audit status:** see [`COVERAGE.md`](./COVERAGE.md) — a per-opcode
matrix of what's implemented, wire-audited against the real client (both
directions), and unit/E2E-tested. Every opcode in the login→world→fight path has
been byte-audited against the decompiled client.

Protocol/data references live in
[`../client/analysis/`](../client/analysis) (PROTOCOL.md,
PROTOCOL-messages.md, PROTOCOL-parttable.md, DATA-FORMAT.md).

Not a substitute for a **live retail-client GUI run**, which remains the final
validation step.

## Run

```powershell
go build ./...
go test ./...
go run ./cmd/server                              # listens on 0.0.0.0:5555
go run ./cmd/server --config configs/config.sqlite.yaml
```

The listen address is a config key (`addr`), not a flag — the first run writes a
fully commented `config.yaml` next to the binary. The two flags are `--config` and
`--version`. The game data is embedded (`server/content`, S43).

The retail client already ships pointed at `127.0.0.1:5555`
(`client config.properties → proxyAddresses_1`), so it connects with no change;
the server binds `0.0.0.0` by default so other machines can reach it too.

## Layout

```
cmd/server              entrypoint (config, data discovery, wiring)
cmd/studio              Wails desktop data browser (Windows; excluded from releases)
internal/protocol       frame codec, opcodes, big-endian read/write buffer
internal/handshake      version + auth message decode/encode
internal/game           the game server: sessions, world, fights, economy
internal/gamedata       .bdat / maps decoders
internal/store          persistence (SQLite / PostgreSQL / MySQL)
internal/config         self-writing YAML config
internal/web            browser sign-up portal
```
