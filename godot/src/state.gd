extends RefCounted

## Tiny cross-scene state holder (static vars — no autoload needed).

## World id of the last EnterInstance (4600). For fight instances this is the
## arena's own id: arena.worldID == fight-map id == maps/fight/<id>.fmd.
static var current_world := -1

## Set when FightCreation (8000) arrives — fight_view reads it on open.
static var fight_world := -1
