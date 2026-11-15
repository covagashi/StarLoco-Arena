package game

// cardsets.go applies card-SET bonuses ("panoplies", gamedata type 101).
//
// The client's rule, from sj_1's aggregated-bonus builder:
//
//	count the coach's EQUIPPED cards per set id
//	for each effect of each such set: if effect.Threshold <= count, it applies
//	several sources of the same action id are SUMMED
//
// Set effects use the client's AI enum — the coach META layer (XP, wounds,
// morale, fatigue, drops, reputation, resurrection), not in-fight combat stats.
//
// NINE families are wired today, through this one lookup: XP % and flat, morale,
// fatigue, reputation, wound chance, death chance, wound cancellation and
// resurrection — plus the "…for the opponent" variants of six of them, which
// postfight_apply.go sums off the OTHER team (opposingSetBonus). This comment
// used to say resurrection was the only one; that was true when only
// handlers_evolution.go called in.
//
// The DROP family (AI 18–21) was left out of sets on purpose (docs/STATUS.md:
// the retail pool and base rate are not recoverable); since S41 every source
// counts the same way (coachBonusFor), so a set's drop bonus does what the
// client's text for it says.

// AI-enum action ids carried by coach-card and card-set effects. Only the ones we
// act on are named here; the full list is in the client's `AI` enum. The
// post-fight META ids live next to their use in postfight.go.
const (
	aiActionResurrect int32 = 13 // "x% chance to resurrect a fighter that just died"
)

// setBonusFor returns the summed magnitude of every unlocked set effect with the
// given AI action id, across all sets the coach has cards of. Returns 0 when the
// catalogues are absent, so a server without data files behaves as before.
//
// "Unlocked" means the coach has at least the effect's threshold worth of that
// set's cards EQUIPPED (Pos >= 1) — the same set the client counts.
func (s *Session) setBonusFor(action int32) int32 {
	if s == nil || s.Coach == nil || s.deps == nil {
		return 0
	}
	if s.deps.CardSets == nil || s.deps.Cards == nil {
		return 0
	}
	equipped := s.equippedCountsPerSet()
	var total int32
	for setID, count := range equipped {
		set := s.deps.CardSets.Get(setID)
		if set == nil {
			continue
		}
		for _, ef := range set.ActiveEffects(count) {
			if ef.Action == action && len(ef.Params) > 0 {
				total += ef.Params[0]
			}
		}
	}
	return total
}

// coachBonusFor is everything the coach's gear adds to an AI action: the
// unlocked set effects plus the equipped cards' own effects (S41). The card's
// own effects were shown by the retail client (sj_1 sums both into one entry
// per action) but only drops read them here, so a "+4 % XP" cape gave
// nothing unless it completed a set; now the texts the client draws from the
// effects are what the server applies.
func (s *Session) coachBonusFor(action int32) int32 {
	return s.setBonusFor(action) + s.equippedEffectBonus(action)
}

// equippedCountsPerSet counts the coach's equipped cards by their set id. A card
// with no set (CardSet 0) is skipped, and so is one the coach's evolution level
// is too low to benefit from.
//
// SECURITY / FIDELITY: the level filter mirrors the client's own bonus
// aggregator, sj_1.java:346-366, which skips a card entirely when
// `((xj)card.NR()).tr() > aet_0.nJ(standing)` - dropping it from BOTH its own
// bonuses AND its set's threshold count. The i18n string says so plainly:
// "Your evolution level is too low to benefit from this equipment's bonuses."
//
// This one is not purely an attacker's rule. The retail client only WARNS on
// equip (agn_0.java:32-35 shows error.equipment.levelToLow and equips anyway),
// so an honest level-1 player could equip end-game cards and the server counted
// them - unlocking set thresholds that feed resurrection chance, XP, morale,
// fatigue, reputation and wound/death chance, while the client refused to display
// any of it. Server truth and client display disagreed.
func (s *Session) equippedCountsPerSet() map[int32]int {
	out := map[int32]int{}
	level := StandingToLevel(s.Coach.Standing)
	for _, inv := range s.Coach.Inventory {
		if inv.Pos < 1 {
			continue // not equipped
		}
		tmpl := s.deps.Cards.Get(inv.TemplateID)
		if tmpl == nil || tmpl.CardSet == 0 {
			continue
		}
		if tmpl.RequiredLevel > level {
			continue // the coach cannot benefit from it, so it does not count
		}
		out[tmpl.CardSet]++
	}
	return out
}
