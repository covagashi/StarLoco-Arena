extends RefCounted
## Historia (S21, owner 2026-10-24: "evolución: este es el modo historia").
## The campaign: the PvE challenges the lobby already had, in their story
## order, as three chapters. Within a chapter each challenge opens when the
## one before it is won; a chapter opens when the one before it is done.
##
## The server keeps the same list (server/internal/game/story.go): the FIRST
## win of each challenge counts like an evolution fight — XP, fatigue,
## morale, wounds and death for your Historia starters — and a won challenge
## can be replayed as practice. TestStoryChallengesMatchClient checks the two
## lists are equal, so edit both.

const CHAPTERS := [
	{"key": "story.ch1", "challenges": [46, 29, 30, 31]},
	{"key": "story.ch2", "challenges": [34, 35, 36, 32, 33]},
	{"key": "story.ch3", "challenges": [45, 3, 13, 16, 14]},
]

## A challenge's demon intro (scenarios.gd) the first time it is launched
## from Historia, as its NPC plays it in the lobby (S18).
const INTROS := {36: 113, 45: 117}


## "won" / "next" / "locked" for challenge `id`, given the ids won.
static func status(id: int, won: Array) -> String:
	if won.has(id):
		return "won"
	var prev_done := true
	for ch in CHAPTERS:
		for c in ch.challenges:
			if int(c) == id:
				return "next" if prev_done else "locked"
			prev_done = won.has(int(c))
	return "locked"


## The first challenge not yet won whose predecessors are (-1 = all won).
static func next_challenge(won: Array) -> int:
	for ch in CHAPTERS:
		for c in ch.challenges:
			if not won.has(int(c)):
				return int(c)
	return -1


static func chapter_done(i: int, won: Array) -> int:
	var n := 0
	for c in CHAPTERS[i].challenges:
		if won.has(int(c)):
			n += 1
	return n
