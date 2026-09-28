extends RefCounted

## Tiny cross-scene state holder (static vars — no autoload needed).

## World id of the last EnterInstance (4600). For fight instances this is the
## arena's own id: arena.worldID == fight-map id == maps/fight/<id>.fmd.
static var current_world := -1

## Set when FightCreation (8000) arrives — fight_view reads it on open.
static var fight_world := -1

## Decoded 8000 FightCreation (see codec_overrides._fight_creation):
## {teams: [{id, name, fighters: [{id, breed, sex, name, coach, ...}]}],
##  coaches: [...], timeline: [fighterId], ...}
static var fight_data := {}

## id -> {name, breed, sex, team, coach} for every fighter in the fight.
static var fighters := {}

## Coach ids present in the fight (real coach ids, e.g. 1, 0x80000001).
static var coach_ids := {}

## Our own coach id (from 2052 CoachInfo at login). Fighters with
## fighter.coach == my_coach_id are ours — fight_view ends their turns.
static var my_coach_id := -1

## Live ArenaClient — set by the Session autoload (app) or the test harness.
## Scenes read `net.message_received` and `net.drain()`.
static var net: Node = null

## Populate the fighter index from a decoded fight_creation dict.
static func index_fighters(d: Dictionary) -> void:
	fighters = {}
	coach_ids = {}
	for c in d.get("coaches", []):
		coach_ids[c.id] = c
	for t in d.get("teams", []):
		for f in t.get("fighters", []):
			fighters[f.id] = f
