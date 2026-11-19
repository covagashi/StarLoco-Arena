package game

import "github.com/StarLoco/arena-2.70/internal/gamedata"

// ai_summon.go: the AI calls its creatures (S46, phase D). Until then no AI
// fighter ever cast a summon spell (the attack path only takes spells that
// harm an enemy, the support path only heals), so a summoner class played by
// the AI — every ghost and challenge Osamodas or Jardinero — fought with
// half its kit and the class balance measured the AI instead of the class.

// aiSpellSummons reports whether sp calls a creature (67, 75 or 97).
func aiSpellSummons(sp *gamedata.Spell) bool {
	if sp == nil {
		return false
	}
	for _, ef := range sp.Effects {
		if ef.Kind() == gamedata.KindSummon {
			return true
		}
	}
	return false
}

// aiSummonCast calls ff's dearest castable creature onto the free cell in
// range nearest an enemy, if ff may summon one more, and reports whether it
// cast. Summons never summon.
func (f *Fight) aiSummonCast(ff *FightFighter) bool {
	if ff == nil || ff.isSummon() || f.deps == nil || f.deps.Spells == nil || ff.AP <= 0 {
		return false
	}
	if f.summonCount(ff) >= 1+ff.nbSummons() {
		return false
	}
	var best *gamedata.Spell
	var bestID int32
	for _, id := range f.aiRepertoire(ff) {
		sp := f.deps.Spells.Get(id)
		if !aiSpellSummons(sp) || aiSpellAPCost(sp) > ff.AP {
			continue
		}
		if !ff.CastHistory.canCast(sp.LimitKeyID(), sp.Cooldown, sp.CastMaxPerTurn,
			sp.CastMaxPerTarget, f.tableTurn, 0, false) {
			continue
		}
		// the dearest creature is the strongest one; ties by the lower id
		if best == nil || aiSpellAPCost(sp) > aiSpellAPCost(best) ||
			aiSpellAPCost(sp) == aiSpellAPCost(best) && id < bestID {
			best, bestID = sp, id
		}
	}
	if best == nil {
		return false
	}
	cell, ok := f.aiSummonCell(ff, best)
	if !ok {
		return false
	}
	return f.castSpellByFighter(ff, bestID, cell)
}

// aiSummonCell is the free, castable cell for sp nearest the closest enemy.
func (f *Fight) aiSummonCell(ff *FightFighter, sp *gamedata.Spell) (Pos, bool) {
	r := spellEffectiveMaxRange(ff, sp)
	var best Pos
	bestDist := int32(-1)
	for dx := -r; dx <= r; dx++ {
		for dy := -r; dy <= r; dy++ {
			c := Pos{X: ff.Pos.X + dx, Y: ff.Pos.Y + dy}
			if !f.Arena().walkable(c.X, c.Y) || f.cellDestroyed(c.X, c.Y) {
				continue
			}
			c.Z = f.Arena().altitudeAt(c.X, c.Y)
			if f.cellOccupied(c) || f.aiCellIsSuicideFor(ff, c) ||
				!f.spellTargetValidFrom(ff, ff.Pos, sp, c) {
				continue
			}
			d := f.minEnemyDistance(ff, c)
			if bestDist < 0 || d >= 0 && d < bestDist {
				best, bestDist = c, d
			}
		}
	}
	return best, bestDist >= 0
}
