# Client testing — notes

> **Historical (2026-10-25).** The retail client, `client/arena-mcp/` and
> `client/control-agent/` were removed in sprint S32 (git history only).
> Live testing is now the Godot client's smoke scripts — see
> [`godot/README.md`](../../godot/README.md).

## Validating in-fight frames without a rendering client

**This document previously said in-fight frames could not be live-validated.
That was wrong**, and the mistake is worth understanding because it cost this
project real coverage.

The reasoning was: animations fail to load in this environment
(`AnimCommunes.anm` FileNotFoundException), so no sprites render, so the combat
UI never attaches, so every in-fight frame reports
`[DEFAUT DE CONCEPTION] Message (X) non traité, de type N` — therefore nothing
can be checked.

The flaw is the last step. **Decoding happens before, and independently of, any
UI consuming the result.** `non traité` means the frame was parsed into its
message class (the log even names the class) and then found no open screen. A
frame the client cannot parse produces something else entirely.

### The oracle

| Log line | Meaning |
|---|---|
| `Message (aAt) non traité, de type 8000` | **Decoded correctly.** No UI consumer — expected here. |
| `ERROR [ConnectionHandler-N] Exception` + `java.nio.BufferUnderflowException` | **Decode FAILED.** The frame does not match the client's parser. |

Verified by controlled experiment, not assumed:

- A correctly-formed 4601 (`[u16 nSit][i64×n][u16 nStand][i64×n]`) → `non traité`
  only, **no exception**.
- The same opcode truncated (`nSit=1` with no body) → `BufferUnderflowException`.

The first attempt at that experiment used a *wrong* layout for the "good" frame
and both threw — which is itself the point: the oracle detected a bad frame that
had been believed good.

### What this makes verifiable

Running one practice fight to completion (`/c2s?opcode=26330&hex=0000000C0000`)
and grepping the log for `BufferUnderflow` live-validates every frame the fight
emits. A full AI fight produced **19 distinct in-fight opcodes, all decoding
cleanly**:

```
8000 8010 8018 8020 8028 8030 8038 8040 8100 8104
8106 8112 8120 8200 4902 4524 4102 6006 6030
```

That includes 8020/8018/8028/8030 and 4902 — the exact frames previously recorded
as unverifiable.

### What it still does NOT prove

Only that the client can **parse** the frame. It says nothing about whether the
result looks right on screen, whether an animation plays, or whether the UI does
the correct thing with it. For a project whose core constraint is byte-exact wire
compatibility with a client that cannot be changed, parseability is nonetheless
the property that matters most — and it was being left unmeasured.

### Recipe

```powershell
# 1. arena_up + arena_login
# 2. start a practice fight through the dev endpoint
Invoke-WebRequest "http://127.0.0.1:5599/c2s?opcode=26330&hex=0000000C0000&arch=2&coach=1"
# 3. let it play out, then read the oracle
#    arena_client_log filter: "BufferUnderflow|Unable to unserialize|Exception"
#    Any hit that is not one of your own deliberate malformed injections is a
#    real wire bug.
```

## The client's own log is the fastest oracle

`arena_client_log` tails `client/compiled/game/output.log`. That file is only
useful because the MCP now spawns the client with its stdout and stderr
redirected into it (`server.mjs`, `stdio: ["ignore", cliFd, cliFd]`). It used to
spawn with `stdio: "ignore"`, and since the client's log4j has no file appender
configured, **everything it said was discarded** — the log was permanently empty,
and a client-side exception was indistinguishable from the server sending
nothing at all.

Read it first, because the client reports far more than it shows on screen:

- `Unable to unserialize AbstractCoachCard : referenceCard not found : N` — a
  card id the client's data does not contain, usually a wrong id space.
- `[DEFAUT DE CONCEPTION] Message (X) non traité, de type N` — **the message
  decoded, but no handler consumed it.** Easy to misread as a server bug: most
  of the client's handlers are installed by a UI state, so this usually means
  the client was not in the state that listens for that opcode.

### An injected message is not the same as one the client asked for

Most notably, the 8300 end-of-fight handler (`WE`) is registered in exactly one
place — inside the fight object the client builds *when it processes 8000*.
Injecting a fight into a client that never asked for one therefore yields
"non traité" for **both** 8000 and 8300, no fight UI at all (just the arena
scenery from ENTER_INSTANCE), and no result dialog — none of which indicates
anything wrong with the server.

So for anything gated behind a UI state — fights, exchanges, the end-of-fight
dialog — drive the client's own flow, or bring in a second real participant (see
the synthetic trade partner built on `internal/testclient` for B-093).

---

# E2E fight-test flakiness — diagnosis and current state

The three full-fight e2e tests (`TestCombatSpellDamage`, `TestFighterMoveInFight`,
`TestPlacementMove`) used to fail *rotating* — a different one each run — on a busy
machine. Two real causes were found and fixed; a residual remains.

**Cause 1 — the turn clock was 5× the test's patience.** Production `turnClock` is 30s
while the tests wait 15s for a turn, so a missed window was a GUARANTEED timeout rather
than a slow pass: the next `FIGHTER_TURN_BEGIN` cannot arrive until the current fighter's
clock expires. `game.SetTurnClockForTest` now lets the e2e harness shrink it to 6s.

**Cause 2 — the collect loop swallowed the next turn.** `TestCombatSpellDamage`'s frame
collector documented itself as running "until the flush barrier **or the next turn
begins**", but its switch had no case for `FIGHTER_TURN_BEGIN` — so under load it consumed
that frame and the following `WaitForTurn` blocked for an entire extra turn. It now keeps
the frame (`pendingTurn`) for the next attempt.

**Result:** 3-of-3 runs failing → 1-of-4, on the same loaded machine (~53% background CPU
from unrelated apps).

**Cause 3 — the real one: the tests assumed "client A == side 0" (B-064).** Causes 1 and 2
were genuine improvements that did not touch the actual bug, which is why the failure kept
returning. Side 0 is whoever reaches the **matchmaker queue first** (`Matchmaker.Search`
pairs the arriving searcher with the one already queued; `buildFightTeam(pm.a, 0)`), and
`startFightForCombat` fires both searches with no happens-before — so under load B can win
and A becomes side 1. The tests then acted with the *opponent's* fighter, which the server
drops silently (`caster.CoachID != cid`), and skipped their own.

The tests are now **side-agnostic**: they act on every turn offered using that fighter's own
side-appropriate cells, prove ownership by the echo where one exists, and assert relative to
the caster's side (`fighterSide`). `isTeamAFighter` is gone.

**Two lessons worth keeping:**
1. *Make the flake deterministic before theorising.* Pinning 23 of 24 cores with busy loops
   turned "~1 in 4" into "4 in 4", which made the whole investigation cheap. Any timing bug
   in this suite should start here.
2. *Instrument the refusal, don't infer it.* Every guard in the cast path returns silently.
   One temporary `Log.Error` on each branch named the cause on the first run
   (`coachMismatch=true`, `notCurrentTurn=false`) and killed the timing hypothesis outright.

**Turn clock.** Now **12s** (was 6s). It must be long enough to act inside your own turn on
a loaded machine — the server silently refuses actions from a fighter whose turn expired —
and short enough that waiting through a turn nobody ends still fits a `WaitForTurn` budget.
A test needing fast rotation should end its *other* client's turns explicitly (as
`TestCombatSpellDamage` does) rather than shrink the clock.

**Rule of thumb when this suite goes red:** check whether the failing test's `Deps` field
is even wired before blaming a gameplay change. `testServerWithDeps` builds `game.Deps`
with **nil** `Cards`, `Spells`, `FighterCards`, `Summonings`, `CardSets`, `Events` and
`FightMaps`, so most data-layer work is provably inert in e2e. A *varying* failing test is
load; a *consistent* one is a regression.

---

# Autonomous live-client testing loop

How the server is validated against the **real retail 2.70 client** with no human
in the loop. This closes the gap that byte-audits and scripted wire tests can't:
*does the change actually work in the client the player runs?*

> **Button coordinates & UI flows:** see [`CLIENT-UI-MAP.md`](./CLIENT-UI-MAP.md)
> — verified canvas click targets so you don't re-find them by screenshot.

## The three oracles

A server change is validated against three independent signals, cheapest first:

1. **Go tests** (`go test ./...`, `go test -race ./...`) — unit + scripted-wire
   e2e. Fast, deterministic, catch regressions. Always run these first.
2. **Client error log** — the retail client writes `output.log` (log4j). It
   reports decode failures (`Erreur à la désérialisation`), UI crashes
   (`IndexOutOfBoundsException`), and protocol desyncs (the ping keepalive
   `reply number is low`). Truncate it, run the scenario, grep for `ERROR` /
   `Exception` / `Erreur`. Found B-014, would have flagged B-013's crash path.
3. **Screenshots + client model state** — the control agent (see
   `client/control-agent/README.md`) drives the client and returns PNGs +
   reflection reads of client-side models. This is how we confirm a panel
   actually renders what we sent (B-012, B-013).

## The loop — via the `arena` MCP tools (preferred)

The `arena-mcp` server (`client/arena-mcp/`, registered in
`opencode.json`) exposes the whole loop as tool calls. It runs the client
**off-screen** with **synthetic input** — it never touches the physical
mouse/keyboard or the visible desktop — and keeps the server+client alive across
calls.

```
arena_up { rebuild: true }     # rebuild server + start server/client, wait until interactive, go off-screen
arena_login {}                 # -> "entered world coach=Loov"
arena_click { x, y }           # navigate (canvas coords; GLCanvas is 1016x741)
arena_doubleclick { x, y }     # ACTIVATE list items / cards / elements (see below)
# agent-only HTTP routes (curl/Invoke-WebRequest on 127.0.0.1:8099):
#   /elements               dump every spawned interactive element's USABILITY state
#   /selftest-doubleclick   prove the double-click is a real AWT double-click
arena_screenshot {}            # returns a PNG inline — SEE the panel
arena_roster {}                # ASSERT client model: adY.atu() size
arena_server_log { filter }    # what the server saw
arena_client_log { filter: "ERROR|Exception|Erreur" }   # did the client break?
arena_down {}                  # teardown + free port 5555
```

Rebuild the agent (`control-agent/`) after changing it; the MCP server picks up
the new jar on the next `arena_up`.

### Single vs double click — they are not interchangeable

A lot of the UI *activates* on double-click and only *highlights* on single click:
every `onItemDoubleClick` / `onDoubleClick` in the layouts — inventory cards
(`equip`), Zaap cards (`changeInstance` → sends 4512), friends
(`privateMessage`), team presets (`loadTeam`), fighter spells/equipment
(`addSpell`/`removeEquipment`), card-master and exchange baskets (`removeCard`).

**Two `arena_click` calls do NOT make a double-click.** The client tests
`MouseEvent.getClickCount() == 2` (decompiled `sj_2`, and `lt_0` which copies the
count into the GUI framework's own event), so two events carrying count 1 are just
two single clicks. `arena_doubleclick` emits the real AWT sequence — PRESS/RELEASE/
CLICK with count 1, then again with count 2.

To confirm the harness end (no game content required):

```powershell
Invoke-WebRequest "http://127.0.0.1:8099/selftest-doubleclick" -UseBasicParsing |
  Select-Object -Expand Content
# PASS single=[P1 R1 C1] want=[P1 R1 C1] double=[P1 R1 C1 P2 R2 C2] want=[P1 R1 C1 P2 R2 C2]
```

It installs a probe listener on the real GLCanvas, fires a single click and a
double-click at it, and reports both sequences — so it also proves the two differ,
which a test of the double-click alone would not.

### Diagnosing interactive elements

`/elements` reports what decides whether an element can be USED, not what is drawn:

```
id  x   y    z  mask   inert  approach  parts  hittable  viewClassChain
37  40  -20  8  65279  false  7         1      1         hh<tp<aiu<GQ<aHh
```

- `inert` - bit 256 of the mask; when true `do_1.a(coach)` fails wherever you stand.
- `approach` - cells the element can be used from. **0 means permanently unusable.**
- `hittable` - views registered with the hit-test/script registry. 0 means the mouse
  cannot reach it.

Beware the decompiler's renames when reading this code: the runtime classes are
`tp`, `do`, `in`, ... and the sources call them `tp_1`, `do_1`, `in_1` because CFR
renames anything colliding with a Java keyword. Comparing a runtime class name
against the decompiled one reports every element as unhittable - that mistake cost
real time here.

### Interactive world elements need a RIGHT-click (button 3)

Using a Zaap, graveyard, mailbox, card master or NPC is **button 3**, not button 1.
`wp_2` picks the button by option — `if (clW) { move=1; action=3 } else { move=3;
action=1 }` — and in this client's state **left-click is MOVE**, so left-clicking an
element just walks the coach to it and looks like "nothing happened". The game's own
help text spells it out: *"Après avoir fait un clic droit sur un zaap, double clic
sur la kard représentant ta destination !"*.

`arena_click` sends button 1, so for an element action use the agent route directly:

```powershell
Invoke-WebRequest "http://127.0.0.1:8099/click?x=472&y=262&button=3" -UseBasicParsing
```

Confirm server-side — the flow is `201 element action`, and for a Zaap destination
card (double-click, button 1) `4512 zaap teleport`:

```
element action  element=37 kind=zaap action=0 coach=Chrono
zaap teleport   coach=Chrono card=202 world=23 zaap=35 alt=2
```

The `Animation <dir>_AnimStatique_<n> not found` errors are cosmetic: the assets are
present, the client just always appends a state suffix the `.anm` files do not
carry. Elements render, highlight and activate regardless.

## Fallback — the PowerShell driver

If the MCP tools aren't available (e.g. before an opencode restart), the same
capabilities are in `client/control-agent/drive.ps1`:

```powershell
. .\drive.ps1
Build-Server; Start-Arena
Ctl '/offscreen?on=1'; Ctl '/login?user=locos975&pass=azerty'
Shot 'panel.png'; Ctl '/roster'
Stop-Arena
```

### Fallback that works from an agent shell — `control-agent/arena.ps1`

`drive.ps1` starts the server/client as **children of the calling shell**. An agent
tool-shell kills its whole process tree when a command returns, so both die instantly
(the symptom is a `ChildProcess.kill` error and nothing listening on 5555).

`arena.ps1` solves this by launching through **WMI**, which reparents the new process
away from the caller so it survives:

```powershell
([WMICLASS]"\\.\root\cimv2:Win32_Process").Create($cmdline, $workingDir)
```

```powershell
$a = "E:\Projets\DofusArena2-06\client\control-agent\arena.ps1"
& $a up -Rebuild          # server + client, agent on :8099, window off-screen
& $a login                # locos975 / azerty
& $a shot C:\tmp\s.jpg 1016 85
& $a c2s 3151 3 012A0C2F53...   # inject a C2S frame (GM chat, etc.)
& $a srvlog 30 "sudden|fight"
& $a down
```

Screenshots are written to a file, which the Read tool renders directly — so an agent
can *see* the game without any MCP layer.

### The agent's `/type` mangles non-ASCII — don't test encodings with it

`/type?text=…` URL-decodes with the JVM's platform charset, so `%C3%A9` arrives as
`Ã©` rather than `é`: the text lands **already mangled in the client's input field**,
before any protocol code runs. Chasing that as a server bug wastes a cycle.

To exercise accented text, inject the exact bytes a real client would send instead:

```powershell
$cp  = [System.Text.Encoding]::GetEncoding(1252)
$b   = $cp.GetBytes("Café")           # 43 61 66 E9 — what the client puts on the wire
$hex = "012A" + ("{0:X2}" -f $b.Length) + (($b | %{ "{0:X2}" -f $_ }) -join "")
& $arena c2s 3151 3 $hex
```

Reading the server log back has the same trap in reverse: it is UTF-8, so read it with
an explicit UTF-8 `StreamReader` — a bare `Get-Content` renders `é` as `Ã©` and looks
like a bug that isn't there.

### Proving "is it us or the client?" for a rendering bug

The pattern that settled the accented-name question, reusable for any "the client shows
the wrong thing" report:

1. **Dump the bytes we actually send** from a unit test on the builder
   (`writeFightCoachBlock`, `buildVicinityMessage`, …). If they are right, stop blaming
   the encoder.
2. **Change the input in the DB, not the code** — renaming a coach needs no rebuild and
   isolates one field.
3. **Feed it a pre-mangled value.** If the render gets *worse* rather than better, the
   client is applying its own transform and there is no server-side workaround. If it
   gets better, you have found a compensation (and a nasty decision to make).
4. Compare against a field that works — an accented chat *body* renders correctly,
   which is what proved the problem is specific to the name path.

### Two things this document used to claim that are FALSE

1. **"Clicks only reach AWT/Swing dialogs, not the GLCanvas."** Wrong. `ControlAgent`
   explicitly targets the GLCanvas (*"Input must target the GLCanvas, not the Frame"*)
   and invokes its registered listeners on the EDT. The full in-game UI is clickable;
   the team panel, the **Tester** button and the **Prêt** button were all driven this way.
2. **"Injected fights build no client-side match object, so in-fight visuals can't be
   self-verified."** Half-wrong, and the *reason* matters. Injecting `26330` through
   `/c2s` does produce a correct fight — the client loads the arena and logs **no**
   errors — but the client never arms its fight HUD, because that is local UI state
   entered when *the client itself* initiates. Drive the real UI instead and everything
   renders:

   > team emblem (490,652) → **TESTER** (608,344) → **PRÊT** (247,462)

   That is a solo practice fight against the Sparring dummy: **one account, no second
   player, full HUD.** For a fast end state use the GM commands (`/SUDDENDEATH`,
   `/ENDFIGHT`) rather than playing 15 rounds.

## Test account / fixtures

- Account **`locos975`** / password **`azerty`** (seed with
  `go run ./cmd/seedaccount --config configs/config.sqlite.yaml --login locos975 --password azerty`).
- Coach **`Loov`** (created interactively once; persists in `arena.dev.db`).
- Login field click target in the 1024×768 window: **`x=512 y=380`** (account),
  TAB to password.

## What each signal is good for

| Signal | Catches | Blind to |
|---|---|---|
| Go unit/e2e | wire layout, server logic, races | client-side rendering / state |
| `output.log` | decode fails, UI crashes, protocol desync | silent "wrong but valid" state |
| Screenshot | what the player actually sees | exact internal counts |
| `/eval` model read | client-side model counts/flags | pixels |

Use them together: `output.log` says "did anything break", the screenshot says
"does it look right", and `/eval` says "does the client's model match ours".

## Known-benign log noise (ignore these)

- `Probl?me lors de SoundManager.initialize` / `Erreur durant l'initialisation
  du soundManager` — audio device not available in the test env.
- `Impossible de retrouver la valeur sélectionnée dans la liste ... Minuit` —
  the server-select dropdown populating on the login screen.
- `game data not loaded ... indexes.bdat` (server side) — the harness runs
  without the client `bdata`; real-data-dependent features are exercised via the
  gamedata unit tests instead.

Only **new** ERROR lines (not on this list) indicate a real problem.

## Live session, 2026-08-11 — driving a fight from a cold database

Recorded because two steps here cost real time and are not obvious from the code.

**A 6006 roster push only lands while the team panel is the ACTIVE frame.** A
fighter created while the world was in front (here, by injecting `6001` through
`/c2s`) is persisted correctly and the server re-pushes the roster, but the
client drops it: `adY.atu()` stayed empty and the team grid stayed empty across
a full relog. Creating the fighter with the panel already open populated both
immediately. If the roster looks empty after a create, that is why.

**The client refuses to start a fight with an empty team, before any packet is
sent** — *"Il faut au moins un combattant dans ton équipe pour lancer le
combat !"*. So a fighter must be in a TEAM SLOT, not merely in the roster.
The reliable route is entirely in the GUI: team emblem → **Recruter** on a slot →
the *Nouveau combattant* dialog (name field, camp, one of the 14 class icons) →
**Valider**. That places the fighter in the slot and the budget counter moves
(600/6000 for a bare Iop).

Full working sequence from a database with no coach at all:

1. `arena_up`, `arena_login` → the coach-creation screen; click the name field,
   type, **Valider** (all canvas clicks — they work; see the retraction above).
2. Team emblem **(490, 652)**.
3. **Recruter** on the first slot **(141, 293)** → fill the dialog → **Valider**
   **(625, 660)**.
4. **TESTER (608, 344)** → the fight starts (it launches challenge 12, not a
   sparring dummy).
5. **PRÊT (483, 735)** → placement ends and the action phase begins.
6. End it fast with GM chat rather than playing it out — opcode `3151`, arch 3,
   payload `012A` + `[u8 len]` + the command:
   `curl "http://127.0.0.1:5599/c2s?opcode=3151&arch=3&hex=012A092F454E444649474854"`
   (that hex is `/ENDFIGHT`).

**What this run confirmed:** fighters render in the placement phase (which is the
real test of any change to the CREATE_FIGHT fighter blob — a wrong byte makes
`gn_0.b` underflow and the fighter silently disappears), round 1 draws event card
14, the end-of-fight panel renders with its won-cards row, and the client log
stays completely error-free.

**It also reproduced the known accent bug**: the opponent name rendered as
`DÃƒÂ¢fi` for *Défi*. That is the client-side mangling documented above — the
server's encoding is correct and must not be "fixed" to chase it.

## Live session, 2026-08-11 (second) — verifying the AI spell repertoire

Ran challenge 12 in the retail client to validate the AI repertoire change
end-to-end. The `/fight` dev dump (`http://127.0.0.1:5599/fight`) is the fastest
way to see what the AI is actually holding — it prints each fighter's spell list:

```
side=1 name="Iop"  breed=8 spells=5[165 5 4 166 9]
side=1 name="Cra"  breed=9 spells=6[18 16 3 168 17 170]
side=1 name="Feca" breed=1 spells=2[31 137]
```

Those counts (5 / 6 / 2) match the per-breed damaging-spell counts measured from
the shipped table exactly, and demons previously carried **one** spell each.

Over four rounds: both the Cra and the Feca ended every turn at `ap=0/6` —
spending their full AP casting — and the player fighter went from 75 to 19 HP.
The round-4 event card applied its -15 % fire modifier to all six fighters
(`stats[fDmg0/-15%]`), and the client log stayed error-free throughout.

**Note for future AI testing:** spell casts are NOT logged server-side, so the
server log will look idle even while the AI is fighting. Read `/fight` for AP/HP
deltas instead, or watch the damage numbers in a screenshot.

**Gotcha when testing player-side casting:** the fighters in this run showed
`spells=0[]` and so could not cast at all. That is NOT a bug — fighter creation
does not grant spells; they arrive later through the loadout message
(`decodeLoadoutSpells`, the `Oi`/`en_1` blob of `[i16 slot][i32 spellId]`). A
fighter recruited straight from the *Nouveau combattant* dialog and thrown into a
fight is simply unarmed. Assign a loadout first if the test needs the player side
to cast.

## Driving a whole fight fast with /script

The 30 s player turn clock makes a full fight impractical to watch through the
GUI: five fighters is ~150 s per round. `/script` removes that entirely — it
posts each step to the fight actor and waits, so rounds take milliseconds and the
client still receives every real broadcast.

The useful idiom is `goto <wire> ai`, which advances turns until that fighter is
current, force-ending the player turns it passes and letting session-less
fighters actually PLAY their AI turn. Cycling it over the AI team runs the fight:

```powershell
$demons = @(1099511640072,1099511640073,1099511640074,1099511640075)
$cmds = @(); foreach ($d in $demons) { $cmds += "goto $d ai" }
$q = [System.Uri]::EscapeDataString(($cmds -join ";"))
Invoke-WebRequest "http://127.0.0.1:5599/script?cmds=$q" -UseBasicParsing
```

Poll `/fight` between batches and stop on `active fights: 0`. Watch for
`cap reached; target never became current` — that means the target died or the
timeline changed, which is itself information.

**A full 5v4 run, 2026-08-11.** By round 7 the AI team had killed two of the
player's fighters and taken **zero** damage: all four demons still at full HP
after seven rounds of four clustered casters using area spells. That is the
end-to-end evidence for the friendly-fire gate (B-085) and the Killer-tile filter
— in the run BEFORE those landed, a Xelor killed itself on a Killer tile. The
fight then ended naturally (`fight ended winnerTeam=1`) with an error-free client
log.

**Reading AI health from `/fight`:** `mp=3/3` and `ap=6/6` on a fighter whose turn
has passed means it did NOTHING, which is how the B-086 freeze was spotted. A
working AI shows spent MP while closing and spent AP once in range.

## Running a SECOND client (two-player tests)

The MCP `arena_up` tool drives one client on agent port **8099**. A second is spawned by hand,
outside the Bash process tree so it survives the shell, with its own agent port:

```powershell
$java    = "<repo>\client\compiled\jre\bin\java.exe"
$agent   = "<repo>\client\control-agent\control-agent.jar"
$natives = "<repo>\client\compiled\natives\win32\x86"
$game    = "<repo>\client\compiled\game"
$main    = "com.ankamagames.dofusarena.client.DofusArenaClient"
$cmd = "`"$java`" `"-javaagent:$agent=port=8100`" -Xmx768m `"-Djava.library.path=$natives`" -cp core.jar $main"
Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{
  CommandLine = $cmd; CurrentDirectory = $game
}
```

Then drive it over plain HTTP on 8100: `/health`, `/offscreen?on=1`,
`/login?user=&pass=`, `/click?x=&y=`, `/doubleclick`, `/type`, `/key?name=ENTER`,
`/screenshot`. Wait for `/health` to report `ready=true` before logging in - the agent answers
long before the UI attaches its input handler.

Two things that cost time when they are not written down:

- **`-Djava.library.path` must point at `client\compiled\natives\win32\x86`**, NOT at
  anything under `game\`. A wrong path leaves the agent reachable and `canvas=false` forever,
  which looks like a hang rather than a misconfiguration.
- **Redirect stdout** if you want the second client's log. `Win32_Process Create` discards it,
  so the second client is silent - only the first client's `output.log` exists. Any assertion
  about what the SECOND client received has to come from a screenshot or the server log.

### What two clients cannot tell you here

Player sprites do not render in this environment at all: `animations.jar` fails to load
(`AnimCommunes.anm` FileNotFoundException), so neither coach appears, on either client.
Verified with two clients logged in simultaneously as Chrono and ExBot - the world draws, the
players do not.

So anything whose evidence is "does the other player SEE it" (sitting, emotes, walk
animations) cannot be settled here. Use the server log and the client's own message-handling
warnings instead: a frame the client could not route logs
`[DEFAUT DE CONCEPTION] Message (X) non traite, de type N`, and its ABSENCE is meaningful -
that is how 4601 was confirmed handled and 6029 confirmed unhandled outside the team panel.

### In-fight frames cannot be validated in this environment

Established by driving a real evolution fight (`/EVOFIGHT`) and injecting 4902:

```
WARN [DEFAUT DE CONCEPTION] Message (aIZ) non traite, de type 4902
WARN [DEFAUT DE CONCEPTION] Message (ut)  non traite, de type 8020   <- StartPlacement
WARN [DEFAUT DE CONCEPTION] Message (aKl) non traite, de type 8018
WARN [DEFAUT DE CONCEPTION] Message (aAw) non traite, de type 8028
WARN [DEFAUT DE CONCEPTION] Message (aGP) non traite, de type 8030
```

8020 StartPlacement demonstrably works in real play, so "unhandled" here is not a verdict on
the server. The arena map renders (placement cells and all), but no fighter sprites appear -
`animations.jar` cannot load - and the combat UI layer never attaches, so nothing consumes
fight frames.

**Consequence:** no in-fight opcode can be live-validated here. Wire correctness still can be
(a malformed frame fails to DECODE, which logs a different error entirely, and an unknown
actor id in 4902 produced no NullPointerException - that handler null-checks, unlike 4700's).

**And a correction to the heuristic recorded above.** The ABSENCE of `non traite` is
meaningful - something consumed the frame. Its PRESENCE is not, on its own: it can equally
mean the relevant UI is not open, which is exactly the case for every fight frame here and was
also the case for 6029 outside the team panel. Read it as "no active screen wanted this",
not as "the server sent something wrong".

### Targeting ONE client: `?coach=<id>`

`/c2s` and `/s2c` accept an optional `coach=<id>`. Without it they hit every connected client,
which cannot express anything involving two players - "A invites B" is not a frame both of them
send. With it:

```
curl "http://127.0.0.1:5599/c2s?opcode=6024&hex=<...>&arch=2&coach=1"   # as Chrono
curl "http://127.0.0.1:5599/c2s?opcode=6026&hex=<...>&arch=2&coach=2"   # as ExBot
```

That is what made the 2v2 disconnect test (B-132) possible without driving the invite UI.

Spawn the second client with the java PID directly (`Win32_Process Create` on java.exe, not on
a `cmd.exe` wrapper) - then `taskkill /PID <pid> /F` severs the socket, which is what the
disconnect path needs to see.