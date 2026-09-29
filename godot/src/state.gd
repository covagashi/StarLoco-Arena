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

## Our coach display name (login name — the server uses it for the coach
## record). Used for local chat echo.
static var my_coach_name := "me"

## Fighter roster from the lobby burst (6006 FighterInformationList):
## [{id, name, breed, sex, type, spells, cards, ...}] — et_2 blobs decoded.
static var roster := []

## Team presets from 6030 TeamPresetList:
## [{id, type, name, game_mode, fighters: [{id, owner}], coaches: [ids]}]
static var presets := []

## Interactive elements spawned in the current world (200/206):
## {instanceId: {x, y, z, dir, flags, desc, kind}} — kind comes from the
## exported env table (gamedata/elements.gd), the wire payload has position.
static var elements := {}

## Coach inventory from 5200 CoachInventoryUpdate: {cardTemplateId: qty}
## (unequipped stacks only — section 3 of the push).
static var inventory := {}

## Wallet from 4001 WalletUpdate / 5403 ShopResult: {currencyType: amount}.
static var wallet := {}

## Social lists — friends: [{name, id, online, notify}], ignored: [names].
static var friends := []
static var ignored := []

## Breed id -> class name (Dofus 1.x order; Iop=8 / Sacrier=11 observed live).
const BREED_NAMES := {1: "Feca", 2: "Osamoda", 3: "Enutrof", 4: "Sram",
	5: "Xelor", 6: "Ecaflip", 7: "Eniripsa", 8: "Iop", 9: "Cra",
	10: "Sadida", 11: "Sacrier", 12: "Pandawa"}

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
			f["team"] = t.id
			fighters[f.id] = f
