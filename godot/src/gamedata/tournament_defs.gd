extends RefCounted
## TournamentDefs — the 22 tournament definitions of the 2.70 data (type 1000,
## `aub`), the fields the native panels need (S09).
##
## The 28602 row only carries the definition id; what kind of team it is for,
## what it costs to enter and what it pays are in the client's data, which the
## asset export does not carry. Copied from the server's decoded catalogue
## (server/internal/gamedata/tournaments.go over data-dist/data.bdat): if a
## data update ever changes them, gamedata's tournaments_real_test is the
## place that notices.

const CLASSIC := 1
const EVOLUTION := 2
const GRAVEYARD := 3
const LEGENDARY := 4

## The 28611 pseudo-preset each kind sends (hu_2 / en_2): classic uses the
## picked team preset.
const PRESET_EVOLUTION := 99
const PRESET_GRAVEYARD := 10000
const PRESET_LEGEND := 9999

## def id -> [team kind, entry card, reward card, rule count]
const DEFS := {
	1: [1, 0, 0, 0], 4: [1, 0, 0, 3], 5: [1, 0, 0, 4], 6: [1, 0, 0, 1],
	7: [1, 0, 0, 0], 8: [1, 0, 0, 1], 9: [1, 0, 0, 1], 10: [1, 0, 0, 3],
	11: [1, 0, 26, 0], 12: [2, 0, 0, 0], 13: [1, 16, 0, 0], 14: [1, 0, 0, 2],
	15: [2, 0, 0, 0], 16: [1, 0, 0, 1], 17: [3, 0, 0, 0], 18: [3, 0, 544, 0],
	19: [1, 808, 0, 0], 20: [1, 0, 0, 0], 21: [1, 0, 0, 0], 22: [1, 0, 0, 0],
	23: [1, 0, 0, 0], 24: [4, 0, 0, 0],
}


static func kind(def_id: int) -> int:
	return int(DEFS.get(def_id, [CLASSIC])[0])


static func entry_card(def_id: int) -> int:
	return int(DEFS.get(def_id, [0, 0])[1])


static func reward_card(def_id: int) -> int:
	return int(DEFS.get(def_id, [0, 0, 0])[2])


static func rules(def_id: int) -> int:
	return int(DEFS.get(def_id, [0, 0, 0, 0])[3])


## The preset a 28611 carries for this kind; classic sends the picked one.
static func search_preset(def_id: int, classic_preset: int) -> int:
	match kind(def_id):
		EVOLUTION: return PRESET_EVOLUTION
		GRAVEYARD: return PRESET_GRAVEYARD
		LEGENDARY: return PRESET_LEGEND
	return classic_preset


## The Team panel tab a kind is searched from (S18 order: Evolution, Elite,
## Duo, Tournaments, Legends): evolution and graveyard field the evolution
## team, legendary the legends.
static func team_tab(def_id: int) -> int:
	match kind(def_id):
		EVOLUTION, GRAVEYARD: return 0
		LEGENDARY: return 4
	return 3
