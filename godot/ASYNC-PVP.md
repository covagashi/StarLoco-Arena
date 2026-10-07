# Async PvP — ghost teams & gambits

Design for the PvP-first game StarLoco Arena should become, validated against
the code that exists today. Nothing here is implemented yet; this is the plan
to review before building.

## Problem

The game is full-PvP with a tiny population. Synchronous matchmaking means
queues that never pop, which reads as a dead game. The fix used by Super Auto
Pets / Backpack Battles: you fight a **saved snapshot of another player's
team** — a ghost — driven by rules its owner configured. No opponent online,
no queue, still real PvP.

## Pillars

- **Ghosts, not bots that pretend.** The opponent is explicitly a recording:
  the saved roster plus its owner's priority rules.
- **Gambits are the strategy.** FFXII's gambit system: an ordered list of
  `IF condition THEN action` rules per fighter, evaluated top-down each turn.
  Building a good ruleset is the skill, not piloting in real time.
- **Deterministic combat.** Same roster + same rules + same seed = same
  fight, always. Enables server verification (anti-cheat), replays, and
  balance debugging.
- **Equal budget, cosmetic-only.** Every team is built under the same fighter
  budget (the server already enforces this at fight launch). No purchasable
  power.
- **Separate ladders.** Ghost-fight ladder and live-fight ladder never mix.
  Filler ghosts (server-generated) feed an offline/PvE progression, not the
  global ranking.

## What already exists to build on

- `internal/game/ai.go` — a real AI: archetype classification
  (`behaviorBlocker/SelfBuff/Kite/Aggressive` from the spell repertoire),
  target selection, BFS/flood positioning, friendly-fire and suicide-cell
  guards, close-combat fallback. Gambits sit **on top** of this, not instead
  of it: rules first, archetype as fallback when no rule fires.
- `runAITurn` already drives any session-less fighter — the exact same hook a
  ghost needs (it is also what takes over when a coach disconnects).
- `f.rng` (`*rand.Rand` per fight) is the single dice source — but it is
  lazily seeded from `time.Now()` (`spell_effects.go:37`). Determinism =
  seeding it from a stored fight seed instead. That is the one structural
  change determinism requires.
- Placement facing (4521, B-170) means ghost rosters can store per-fighter
  cells + directions verbatim.

## Data model

`ghost_teams` table (new schema migration):

- `coach_id`, `name`, `created_at`
- `roster` — serialized fighter snapshot (ids, breed, level, spells, cards,
  placement cells, facing)
- `rules` — JSON: per fighter, an ordered gambit list
- `elo_ghost` — ghost-ladder rating
- `battles`, `wins`

Gambit rule (versioned JSON, edited client-side):

```
{ "if": {"kind": "enemy_hp_pct_below", "value": 40},
  "do": {"kind": "cast", "spell": 51, "target": "weakest_enemy"} }
```

Condition kinds v1: `always`, `self_hp_pct_below`, `enemy_hp_pct_below`,
`ally_hp_pct_below`, `nearest_enemy_distance_le`, `turn_ge`, `ally_count_le`.
Action kinds v1: `cast` (+ target spec), `move_toward`, `move_away`,
`close_combat`, `pass`. Anything the client can't express falls back to the
existing archetype AI.

## Fight flow

1. Challenger picks "Fight a ghost" → server picks an opponent ghost
   (Elo-band match on `elo_ghost`, else a filler ghost).
2. Fight launches through the normal pipeline — the ghost's fighters are
   session-less, so `runAITurn` drives them. Challenger plays normally.
3. On a ghost fighter's turn: evaluate its rule list top-down; first firing
   rule wins; none → `classifyAI` archetype. All of it runs on the fight
   actor goroutine, same as today.
4. `f.rng` is seeded `hash(fight_seed)` where `fight_seed` is stored on the
   fight record at creation → replays and re-verification are bitwise
   reproducible.
5. Result updates the ghost ladder only. Rewards from ghost wins are reduced
   or cosmetic to keep the live ladder meaningful.

## New protocol (Godot-only, retail unaffected)

Same pattern as the 60000/60001 client-config pair — the retail client never
sends these, so it never sees the replies:

- `60010` C2S GhostListReq → `60011` S2C ghost-ladder/opponent list
- `60012` C2S GhostSaveReq (roster + rules JSON) → `60013` ack/err
- `60014` C2S GhostFightReq (ghost id or "matchmake") → existing fight-start
  frames

Filler ghosts ship in `data-dist/` as authored JSON (a few dozen hand-made or
budget-random rosters with simple rules — no ML, no generation at runtime).

## Anti-abuse / honesty notes

- Ghost snapshots are taken at save time — leveling your real team does not
  retro-buff your ghost; re-saving is the update path.
- Reported identity fields on fights vs ghosts are still untrusted client
  claims; the server re-derives the roster from the stored snapshot, never
  from the wire.
- Determinism helps verification but is NOT replay-proof on its own: keep the
  seed server-side, log rule decisions per turn in `DebugLog`-style fight
  logs for moderation.

## Phasing

1. **Determinism**: seed `f.rng` from a stored fight seed; add a fight-log
   hook recording (turn, fighter, rule fired / action taken).
2. **Gambit engine**: rule eval on top of `runAITurn`, archetype fallback,
   JSON schema + unit tests over real spell data.
3. **Ghost storage + opcodes** above, admin-visible at first.
4. **Client**: ghost management panel (rules editor UI is the hard UX part —
   ordered rule list with condition/action pickers), "Fight a ghost" entry,
   ghost-ladder tab.
5. **Filler ghosts + offline ladder**, rewards policy.

Open questions for the maintainer: reward policy for ghost wins; whether
ghost Elo should decay; mobile UI constraints for the rules editor.
