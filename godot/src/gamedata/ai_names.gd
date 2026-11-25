extends RefCounted
## AiNames — the server's AI opponents in the UI language (S08).
##
## The server names its own coaches and fighters in French, as the retail did:
## the demon bosses ("Démon de la 58ème minute"), the breed master, and each AI
## fighter after its breed ("Iop", "Crâ"). The wire carries plain strings, so
## the translation happens here, once, when the 8000 is indexed: the demons
## by their npc.<id> name (ours since S41, NpcDialogs), the rest by our own
## i18n keys. Only these two coach
## ids are touched, and a fighter only when its name is exactly its breed's
## French name, so nothing a player typed is ever rewritten.
##
## Keep in step with server/internal/game/challenge_fights.go
## (demonChallengeName, challengeOpponentName, breedName) and
## handlers_fightcreation.go (the "Sparring" opponent).

const NpcDialogs := preload("res://src/gamedata/npcdialogs.gd")

const SPARRING_COACH := 2147483648      # 1 << 31, sparringCoachID
const CHALLENGE_COACH := 2147483649     # 1 << 31 + 1, challengeCoachID

## demonChallengeName -> its npc.<id> name (NpcDialogs, ours since S41)
const DEMONS := {
	"Démon de la 58ème minute": 262, "Démon de la 52ème minute": 263,
	"Démon de la 46ème minute": 264, "Démon de la 25ème minute": 265,
	"Démon de la 12ème minute": 266, "Démon de la 37ème seconde": 281,
}
## the other server-made coach and fighter names -> ui i18n keys
const OTHERS := {
	"Maître d'élevage": "ai.breed_master", "Démon": "ai.demon",
	"Défi": "ai.challenge", "Sparring": "ai.sparring",
}
## breedName in challenge_fights.go, by breed id
const BREEDS_FR := {
	1: "Féca", 2: "Osamodas", 3: "Enutrof", 4: "Sram", 5: "Xélor",
	6: "Ecaflip", 7: "Eniripsa", 8: "Iop", 9: "Crâ", 10: "Sadida",
	11: "Sacrieur", 12: "Pandawa",
}


static func is_ai_coach(id: int) -> bool:
	return id == SPARRING_COACH or id == CHALLENGE_COACH


## A server-made coach name in the UI language; anything else unchanged.
static func coach_name(id: int, name: String) -> String:
	if not is_ai_coach(id):
		return name
	if DEMONS.has(name):
		var n := NpcDialogs.npc_name(DEMONS[name])
		return n if n != "" else name
	if OTHERS.has(name):
		var t := I18n.t(OTHERS[name])
		return name if t == OTHERS[name] else t
	return name


## A server-made fighter name in the UI language; anything else unchanged.
static func fighter_name(coach_id: int, breed: int, name: String) -> String:
	if not is_ai_coach(coach_id):
		return name
	if BREEDS_FR.get(breed, "") == name:
		var t := I18n.t("breed.%d" % breed)
		return name if t == "breed.%d" % breed else t
	if OTHERS.has(name):
		var t2 := I18n.t(OTHERS[name])
		return name if t2 == OTHERS[name] else t2
	return name


## Nilo's training dummy (S52, server practice_dummy.go dummyName): its
## name is npc.316 and it wears the stuffed sack (summon look 8003, the
## Bloqueadora's figure and portrait — no art of its own).
const DUMMY := "Mannequin"
const DUMMY_NAME := 316
const DUMMY_LOOK := 8003


## Rewrites the coach and fighter names of a decoded 8000 in place.
static func localize(fight: Dictionary) -> void:
	for c in fight.get("coaches", []):
		c["name"] = coach_name(int(c.get("id", 0)), str(c.get("name", "")))
	for t in fight.get("teams", []):
		for f in t.get("fighters", []):
			if is_ai_coach(int(f.get("coach", 0))) and str(f.get("name", "")) == DUMMY:
				var n := NpcDialogs.npc_name(DUMMY_NAME)
				f["name"] = n if n != "" else DUMMY
				f["look"] = DUMMY_LOOK
				f["dummy"] = true
				# its life is its own, not its breed's: the server counts its
				# hpLost from the breed's (fight_packets.go), so that gives it
				var base := int(load("res://src/gamedata/breeds.gd").stats(
					int(f.get("breed", 1)), [0, 0, 0])[0])
				f["hp"] = maxi(base - int(f.get("hp_lost", 0)), 1)
				f["hp_lost"] = 0
				continue
			f["name"] = fighter_name(int(f.get("coach", 0)), int(f.get("breed", 0)),
				str(f.get("name", "")))
