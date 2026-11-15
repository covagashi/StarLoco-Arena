# Deployment

Docker images + compose stacks for the DofusArena 2.70 server. The server is a
pure-Go static binary (CGO disabled), so images are tiny (~20 MB on alpine).

## Game data

The game data is the game's own and is embedded in the server binary
(`server/content`), so there is nothing to mount for it.

## Stacks

### SQLite (simplest — one container)
```bash
docker compose -f deploy/docker-compose.sqlite.yml up --build
```
Embedded DB file persisted in the `arena-state` volume. Fine for dev / small
scale.

### PostgreSQL (production)
```bash
docker compose -f deploy/docker-compose.postgres.yml up --build
```
Server + Postgres 16; the server waits for a healthy DB, then auto-migrates.

### MySQL / MariaDB (production)
```bash
docker compose -f deploy/docker-compose.mysql.yml up --build
```

## Seeding an admin account

Run the bundled seed tool inside the running server container:

```bash
docker compose -f deploy/docker-compose.postgres.yml exec arena \
  /app/seedaccount --config /app/configs/config.postgres.yaml \
  --login admin --password secret --admin
```

## Configuration

Everything is set via `ARENA_*` env vars (see the compose files) or a mounted
YAML config (`configs/config.*.yaml`). Env vars override the file.

| Var | Meaning |
|---|---|
| `ARENA_ADDR` | game listen address (e.g. `0.0.0.0:5555`) |
| `ARENA_LOG_LEVEL` | debug / info / warn / error |
| `ARENA_WEB_ENABLED` | serve the account-registration portal (`true`/`false`) |
| `ARENA_WEB_ADDR` | portal listen address (image default `0.0.0.0:8080`) |
| `ARENA_WEB_REGISTRATION_ENABLED` | allow visitors to sign themselves up |
| `ARENA_WEB_PUBLIC_HOST` | hostname shown to players as the game address |
| `ARENA_WEB_CLIENT_DOWNLOAD_URL` | link to the game client shown on the portal (blank by default, and blank hides it — see `DISCLAIMER.md` before setting it) |
| `ARENA_WEB_CONTACT_EMAIL` | address published on `/legal` and `/privacy` for takedown and GDPR requests — **set this on a public server** |
| `ARENA_WEB_HOSTING_PROVIDER` | your host's legal entity + address, required in the legal notice |
| `ARENA_WEB_SERVER_NAME` | site branding (defaults to the neutral "Arena Server") |
| `ARENA_WEB_BRAND_DIR` | folder of logo/favicon/artwork overriding the built-in assets |

### Branding

The portal ships **white-label**: no logo, no favicon, no game artwork, and the
server name rendered as text. That is deliberate — the published project must
not carry any one operator's identity, nor artwork it has no rights to.

Point `brand_dir` at a folder and any file in it replaces the built-in asset of
the same name (`logo.png`, `favicon.ico`, `arena-bg.jpg`, `fighter-1.webp`,
even `app.css`). Contents are hashed into the asset version, so a replaced logo
busts browser caches by itself. Mount it read-only:

```yaml
volumes:
  - ./branding:/app/branding:ro
environment:
  ARENA_WEB_BRAND_DIR: "/app/branding"
```
| `ARENA_UPDATE_CHECK_ENABLED` | startup "newer release available" notice |
| `ARENA_DB_DRIVER` | sqlite / postgres / mysql |
| `ARENA_DB_DSN` | connection string / file path |
| `ARENA_DB_MAX_OPEN_CONNS` | pool size (server DBs) |
| `ARENA_DB_MAX_IDLE_CONNS` | idle pool size |

## Accounts

Players register themselves on the web portal (port `8080` above). **The first
account created becomes the administrator**, so open it and register before
exposing the server to anyone else.

The `seedaccount` tool below remains available for scripted setup.

## Notes on scaling

This is a **single stateful instance** (coaches on one process interact
directly). It handles thousands of concurrent connections on modest hardware.
The DB is the first thing to scale — switch to Postgres/MySQL and tune the pool.
True horizontal auto-scaling (multiple game instances behind a gateway + shared
bus) is a separate, larger effort; the store abstraction + config keep that door
open.
