package domain

// Leagues (S40, owner 2026-11-14): the team budget grows with the coach's
// rating, so a new coach with few cards meets teams on the same budget. Five
// tiers per ladder — bronze to diamond — 4000 to 6000 in steps of 500; 6000 is
// the retail client's own cap (game.maxTeamBudget), kept for every mode
// without a ladder (practice, PvE challenges, Evolution).

// League is a rating tier and the team budget it allows.
type League struct {
	Tier   uint8  // 0 bronze .. 4 diamond
	Name   string // "bronze", "silver", "gold", "platinum", "diamond"
	Budget int32
}

var leagueNames = [...]string{"bronze", "silver", "gold", "platinum", "diamond"}

const (
	// LeagueBronzeBudget is the lowest tier's team budget; each tier adds
	// LeagueBudgetStep, so diamond is 6000.
	LeagueBronzeBudget int32 = 4000
	LeagueBudgetStep   int32 = 500
)

func leagueAt(tier int32) League {
	tier = max(0, min(tier, int32(len(leagueNames)-1)))
	return League{Tier: uint8(tier), Name: leagueNames[tier], Budget: LeagueBronzeBudget + tier*LeagueBudgetStep}
}

// RankedLeague is the 1v1 Ranking tier of a Strength (1000-3000, ±25 a fight):
// 200 points a tier, eight net wins, from 1000; unranked (0) is bronze.
func RankedLeague(strength int32) League {
	return leagueAt((strength - StrengthMin) / 200)
}

// GhostLeague is the ghost-ladder tier of an Elo (start 1000, K 32): below
// 1100 is bronze, then 100 points a tier, about six wins at even odds.
func GhostLeague(elo int32) League {
	if elo < GhostEloStart+100 {
		return leagueAt(0)
	}
	return leagueAt((elo - GhostEloStart) / 100)
}
