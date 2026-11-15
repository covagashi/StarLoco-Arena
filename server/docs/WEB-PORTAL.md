# Web portal

The browser site bundled with the server: where players register, see everything
the server stores about them, and where operators run the game from.

It lives in **`internal/web`** and is **Go stdlib + `html/template` only** — no
Node toolchain, no build step, no framework, no CDN. Templates, the stylesheet,
two webfonts and the favicon are `//go:embed`-ed, so the whole site ships inside
the binary and works on a machine with no internet access.

## 1. Running it

The portal runs **inside `cmd/server`**, sharing its process and its `*store.Store`.
That is deliberate rather than incidental:

- the live tiles (players online, active fights) read the real registries;
- the monitoring page profiles *this* runtime, so there is no second,
  unauthenticated debug port to leave open.

It is on by default and needs no configuration. `web.enabled: false` turns it
off; accounts are then created with `go run ./cmd/seedaccount`.

## 2. Configuration (`web:` block)

```yaml
web:
  enabled: true
  addr: "0.0.0.0:0"          # 0 = pick a port: 80, 8080, 8090, 3000, 5000, any
  registration_enabled: true
  server_name: "My Arena"    # branding; empty = "DofusArena"
  public_host: ""            # address shown to players; empty = the host they used
  client_download_url: "..." # empty hides the download link
  min_login_length: 3
  min_password_length: 6
  session_secret: ""         # empty = random per start (everyone signed out on restart)
  secure_cookies: false      # true ONLY behind https
```

Two of these bite if you get them wrong:

- **`session_secret`** is a credential. Empty is fine for a home server, it just
  means a restart signs everyone out. Set it (or `ARENA_WEB_SESSION_SECRET`) in
  production; anyone who learns it can forge a login for any account.
- **`secure_cookies: true` on a plain-HTTP server makes signing in silently
  impossible** — the browser accepts the cookie and then refuses to send it
  back, so every login looks like it "did nothing". It stays off by default.

## 3. Pages

Public — no account needed:

| Route | What it is |
|---|---|
| `GET /` | Landing page. Redirects a signed-in visitor to `/account`. |
| `GET /status` | Is the server up, is anyone playing. **Aggregate counts only** — no player or account names — because anyone on the internet can read it. |
| `GET /ladder` | The public 1v1 leaderboard, paginated. Shows what the in-game ladder already shows every player. |
| `GET\|POST /login`, `GET\|POST /register`, `POST /logout` | |
| `GET /health` | `ok`, for uptime checks. |

Signed in, any account:

| Route | What it is |
|---|---|
| `GET /account` | Everything stored about you: coach, ladder record, wallet, fighters (with spell/item/wound counts), teams, equipped cards, bag, friends, ignored, mail count, statistics. |
| `GET\|POST /account/password` | Change password. Requires the current one. |

Admin only — gated on the **real** signed-in account being `is_admin`:

| Route | What it is |
|---|---|
| `GET /admin` | Tiles (accounts, players online, active fights, uptime) + newest accounts. |
| `GET /admin/accounts` | Searchable, paginated. Search matches the **account or the coach name**, since most players only know each other by the latter. |
| `GET\|POST /admin/accounts/new` | Create an account, optionally as an admin. |
| `GET /admin/accounts/{id}` | The same deep view the player sees, plus moderation. |
| `POST /admin/accounts/{id}/delete` | Deletes the account and everything under it. Refused while connected. |
| `POST /admin/accounts/{id}/toggle-admin` | Grant/revoke admin. |
| `POST /admin/accounts/{id}/impersonate` | Start viewing the site as that player. |
| `GET /admin/tournaments` | The standing tournaments players see. Create, edit, reorder, hide or delete. |
| `GET\|POST /admin/tournaments/new` | |
| `GET\|POST /admin/tournaments/{id}` | Edit. |
| `POST /admin/tournaments/{id}/delete` `.../toggle` | Delete, or hide without losing the setup. |
| `GET /admin/monitoring` | Runtime stats + the profiler. |
| `GET /admin/monitoring/pprof/{profile}` | One profile, served from this process. |
| `POST /impersonate/stop` | Not admin-gated: whoever is impersonating must always be able to get back to themselves. |

The account view is **one template** (`_partials.html` → `account_data`) shared by
the player's page and the admin's, so the two cannot drift apart: an admin sees
exactly what the player sees, plus the controls.

## 4. Security model

**Sessions** (`session.go`) are HMAC-SHA256 **signed, not encrypted** — the
payload is `accountID.impersonatedID.issuedUnix`, which holds nothing secret, so
integrity is the only property needed. Crucially the cookie is never used as a
cache: every request re-loads the account from the database, so a deleted or
demoted user is handled on their next click rather than at their next login.
7-day TTL, `HttpOnly`, `SameSite=Lax`.

### Tournament editing is the one dangerous form

Everywhere else in this console a careless save annoys somebody. Here it can
take every connected client down, so the rules are enforced rather than
documented.

A tournament row carries a **client definition id** — a `data.bdat` type-1000
`aub` record. The retail client ships 22 of them (ids 1 and 4–24) and
dereferences the id **unguarded**: `LS.Yf().gG(defId)` returns null for anything
else and the list/detail/register code walks straight into it. On top of that, a
definition whose inscription card is non-zero makes the client demand an entry
ticket this server never grants, so registration can never complete.

Both rules are checked against the decoded catalogue in `validateTournament`,
and the form only ever offers definitions that satisfy them — the picker shows
20 of the 22, labelled with the team type the client will read (`1 — classic
1v1`, `17 — graveyard`). With no game data loaded (a broken build) the catalogue is
empty and the id is taken on trust, because refusing to let an operator edit
tournaments at all would be worse.

Name and short label are capped at 127 bytes. That is the wire, not taste: both
are length-prefixed with a **signed** byte, so 128 presents as a negative length
and the client's decoder throws.

**CSRF** (`csrf.go`) is a signed per-account double-submit token: an HMAC over
the account id plus a day bucket, embedded in every state-changing form and
re-derived on POST. Keyed with the same secret as sessions, so it cannot be
minted; bound to the account id, so it cannot be replayed across users. The
previous day's bucket is also accepted, so a form left open over midnight still
submits. GET never mutates, so only POSTs verify.

**Impersonation** keeps *both* identities in the session. `requireAdmin` only
ever looks at the **real** one, so viewing-as grants a view and never a
privilege, and the impersonated session is **read-only** — an admin cannot
change the password of somebody they are impersonating. A banner with a
one-click way out is shown on every page.

**Self-harm guards.** An admin cannot delete or demote the account they are
signed in as: on a one-admin server that would lock the console for good.
Deleting a *connected* account is refused too, because the game server is
holding that coach in memory and would keep saving it back.

**Rate limits.** Sign-up and sign-in have separate allowances (10/hour and
20/15min per address) because the right number differs by an order of magnitude:
ten new accounts an hour from one address is suspicious, ten mistyped passwords
in an evening is not. Proxy headers are ignored — they are attacker-controlled
unless a known proxy rewrites them, and trusting them would defeat the limit.

**CSP** is `default-src 'none'` with **no `script-src` at all**. The site has no
JavaScript, so this is a real mitigation rather than a formality: a stored-XSS
bug in something like a coach name could not execute.

> **`is_admin` is only a boundary as of B-090.** The game server used to promote
> every account that logged in. Databases created before that fix may contain
> accounts that still carry the flag:
> `SELECT id, name, is_admin FROM accounts WHERE is_admin = 1;`

## 5. Monitoring and pprof

Served **in-process** rather than reverse-proxied to a separate listener (which
is what the v2.04 portal did, because it could run as its own process). Only six
named profiles are reachable — `goroutine`, `heap`, `allocs`, `threadcreate`,
`block`, `mutex`. Requests never fall through to `net/http/pprof`'s own mux, so
there is no path to `cmdline` (which leaks the command line) or to the CPU
profile's `seconds` parameter, which would let a caller hold a request open for
as long as they liked.

## 6. Theme

A dark, warm-black ground (`#0a0806`) with a single amber accent (`#fa9e19`),
following the visual language of the modern Dofus Arena fan sites. The
distinctive parts:

- **borders are never grey** — always the accent at 15% opacity;
- **depth comes from a faint amber grid texture and large blurred colour blobs**,
  not from grey drop shadows;
- every section is announced by an **eyebrow**: a short amber rule followed by
  small uppercase letter-spaced accent text;
- hover is a 2–4px lift plus an amber glow.

**Fonts** are Sora (headings) and Outfit (body), bundled as **variable** woff2 in
the latin subset — 57 KB for both, one file per family covering every weight the
site uses. They are self-hosted rather than fetched from a CDN so the portal
works offline and the CSP can keep `font-src 'self'`. Both are SIL Open Font
License; see `internal/web/static/fonts/LICENSE.md`.

Everything respects `prefers-reduced-motion`.

## 7. Tests

- `web_test.go` — public pages render, the status page leaks no names, the
  fonts are actually embedded and are valid woff2, registration/validation/
  duplicate/closed-registration, both rate limiters, cross-origin rejection,
  the listener ladder, clean shutdown, and a guard that every template parses.
- `session_test.go` — codec round-trip, tampering, foreign-key and expiry
  rejection, ephemeral-key behaviour, CSRF per-account and day-bucket rules.
- `portal_test.go` — drives the site over a real socket with a cookie jar:
  login/logout, the account page with and without a coach, password change
  (including the CSRF requirement), admin gating for anonymous and ordinary
  players, console rendering, search, pprof, create/delete/grant, the self-harm
  guards, the connected-account refusal, impersonation both ways, and a session
  whose account was deleted.

Four security properties are **mutation-checked** — dropping the `IsAdmin`
check, gating on the effective instead of the real account, making `verifyCSRF`
always return true, and allowing the password change while impersonating each
fail a specific named test.
