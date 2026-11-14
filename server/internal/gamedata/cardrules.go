package gamedata

import "fmt"

// cardrules.go: the S40 rebalance as rules over the card content (the owner's
// answers, 2026-11-14). A rare card is different, not better, so every META
// effect has one cap whatever the card's rank. The caps sit at what a
// middle-rank card gives today, except XP (+10 %) and resurrection (25 %),
// which the owner set.
//
// Only the beneficial direction is capped: a card that hurts its owner (more
// wounds, less XP) keeps its malus. Consumables (HasUsableAction, Historia
// only since S21) keep their potions' magnitudes; the one exception is
// resurrection, which the owner equalised for every card.
//
// ApplyCardRules is idempotent: cmd/cardrules applied it once to the content,
// TestCardContentParity checks content == ApplyCardRules(retail), and
// TestCardContentObeysRules keeps later edits inside the caps.

// metaCap is the largest beneficial magnitude of one META effect. good is the
// sign that helps the card's owner: +1 for "more XP", -1 for "fewer wounds".
type metaCap struct {
	max  int32
	good int32
}

var metaCaps = map[int32]metaCap{
	1:  {10, +1}, // XP %
	2:  {8, +1},  // XP flat
	3:  {8, -1},  // enemy XP %
	4:  {6, -1},  // enemy XP flat
	5:  {5, -1},  // own wound chance
	6:  {5, +1},  // enemy wound chance
	7:  {5, -1},  // own death chance
	8:  {5, +1},  // enemy death chance
	9:  {3, +1},  // morale
	10: {1, -1},  // enemy morale
	11: {6, +1},  // cancel wounds %
	16: {1, -1},  // own fatigue
	17: {1, +1},  // enemy fatigue
	19: {5, +1},  // drop chance
}

const (
	// ResurrectPercentAll is every resurrection card's chance (owner: no card
	// is a sure resurrection).
	ResurrectPercentAll int32 = 25
	// setResurrectBonusCap caps what a set adds on top (middle rank today), so
	// no combination makes a lost fighter a formality.
	setResurrectBonusCap int32 = 10
)

// fighterCardValues are the fighter cards whose budget cost was off for what
// they give (cmd/cardreport, owner-approved): two 5-AP, range 2-5 weapons.
var fighterCardValues = map[int32]int32{
	28: 150, // 10 damage
	34: 100, // 8 damage
}

// capMeta returns v inside the cap of action a (unchanged if a has none).
func capMeta(a, v int32) int32 {
	c, ok := metaCaps[a]
	if !ok || v*c.good <= c.max {
		return v
	}
	return c.max * c.good
}

func capEffects(effs []CardSetEffect) {
	for i := range effs {
		if len(effs[i].Params) > 0 {
			effs[i].Params[0] = capMeta(effs[i].Action, effs[i].Params[0])
		}
	}
}

// ApplyCardRules rewrites c in place to the S40 rules.
func ApplyCardRules(c *CardContent) {
	for _, card := range c.Cards.All() {
		if !card.HasUsableAction {
			capEffects(card.Effects)
		}
		for i := range card.Effects {
			e := &card.Effects[i]
			if e.Action == resurrectAction && len(e.Params) > 0 {
				e.Params[0] = ResurrectPercentAll
			}
		}
		// The decoder takes ResurrectPercent from the first resurrection effect.
		if _, ok := card.EffectParam(resurrectAction); ok {
			card.ResurrectPercent = ResurrectPercentAll
		}
	}
	for _, id := range c.Sets.IDs() {
		set := c.Sets.Get(id)
		capEffects(set.Effects)
		for i := range set.Effects {
			e := &set.Effects[i]
			if e.Action == resurrectAction && len(e.Params) > 0 && e.Params[0] > setResurrectBonusCap {
				e.Params[0] = setResurrectBonusCap
			}
		}
	}
	for id, v := range fighterCardValues {
		if fc := c.Fighters.Get(id); fc != nil {
			fc.Value = v
		}
	}
}

// CardRuleViolations lists what in c breaks the rules (empty = none).
func CardRuleViolations(c *CardContent) []string {
	var out []string
	check := func(where string, effs []CardSetEffect) {
		for _, e := range effs {
			if len(e.Params) > 0 && capMeta(e.Action, e.Params[0]) != e.Params[0] {
				out = append(out, fmt.Sprintf("%s: action %d = %d, over its cap", where, e.Action, e.Params[0]))
			}
		}
	}
	for _, card := range c.Cards.All() {
		if !card.HasUsableAction {
			check(fmt.Sprintf("coach card %d", card.ID), card.Effects)
		}
		for _, e := range card.Effects {
			if e.Action == resurrectAction && len(e.Params) > 0 && e.Params[0] != ResurrectPercentAll {
				out = append(out, fmt.Sprintf("coach card %d: resurrection %d %%, not %d", card.ID, e.Params[0], ResurrectPercentAll))
			}
		}
		if _, ok := card.EffectParam(resurrectAction); ok && card.ResurrectPercent != ResurrectPercentAll {
			out = append(out, fmt.Sprintf("coach card %d: ResurrectPercent %d, not %d", card.ID, card.ResurrectPercent, ResurrectPercentAll))
		}
	}
	for _, id := range c.Sets.IDs() {
		set := c.Sets.Get(id)
		check(fmt.Sprintf("card set %d", id), set.Effects)
		for _, e := range set.Effects {
			if e.Action == resurrectAction && len(e.Params) > 0 && e.Params[0] > setResurrectBonusCap {
				out = append(out, fmt.Sprintf("card set %d: resurrection bonus %d, over %d", id, e.Params[0], setResurrectBonusCap))
			}
		}
	}
	return out
}
