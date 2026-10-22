package game

// fight_statistics.go collects, during a fight, the statistics the client's
// shared combat code wrote into each member's container (gn_0.LQ(): cl_1.l
// adds, cl_1.m keeps the best). The calls are still in the client's effect
// classes, against stub containers; their real bodies were the server's:
//
//	ig_1 (damage)     caster += 60 and the per-turn 1000, only against the
//	                  other side; a kill adds 1 to the per-turn 999, not for
//	                  a summon's kill
//	sq_2 (MP use)     mover += 156 and the per-turn 1001, not for a summon
//	df_2 (AP loss)    caster keeps the best 69: the target's max AP minus its AP
//	va_1 (area death) the area's owner += 57; with no owner (a killer cell)
//	                  the victim += 56
//	NC/ah/… (res)     the fighter keeps the best 58: element + general res
//
// The per-turn temporaries (999 kills, 1000 damage, 1001 MP) end up as the
// best-of-a-turn statistics 61, 59 and 62. recordFightStatistics banks it all
// at the end, 57 / 59 / 60 in the variant of the coach's level.

// Client or_0 ids the in-fight collector feeds.
const (
	statDeathCellDeaths int16 = 56  // "Nombre de combattants morts sur une case mort"
	statTrapKills       int16 = 57  // "Nombre d'adversaires tués avec un piège mortel"
	statBestArmour      int16 = 58  // "Plus gros bonus d'armure atteint"
	statTurnDamage      int16 = 59  // "Dégâts maximum faits en un tour"
	statFightDamage     int16 = 60  // "Dégâts maximum faits en un combat"
	statTurnKills       int16 = 61  // "Nombre maximum de combattants tués en un tour"
	statTurnMP          int16 = 62  // "Nombre maximum de PMs utilisés en un tour"
	statAPRemoved       int16 = 69  // "Nombre maximum de PAs retirés à un combattant en un tour"
	statBonusCells      int16 = 70  // "Nombre maximum de cases bonus dont on a profité au cours d'un combat"
	statMPUsed          int16 = 156 // "Nombre total de PMs utilisés en combat"
	statEniripsaPunches int16 = 161 // "Nombre d'adversaires finis à coup de poing par un Eniripsa"

	breedEniripsa uint8 = 7
)

// memberStats is one coach's tally for the fight in progress.
type memberStats struct {
	damage, trapKills, deathCells, mpUsed, bonusCells int32
	eniripsaPunches                                   int32
	castSpell                                         bool // any spell this fight (84: "sans sort")
	bestArmour, bestAPRemoved                         int32
	// this turn, and the best turn so far
	turnDamage, turnKills, turnMP             int32
	bestTurnDamage, bestTurnKills, bestTurnMP int32
}

// stat returns coachID's tally, creating it; nil for no coach.
func (f *Fight) stat(coachID uint) *memberStats {
	if coachID == 0 || isSyntheticCoach(coachID) {
		return nil
	}
	if f.memberStats == nil {
		f.memberStats = map[uint]*memberStats{}
	}
	s := f.memberStats[coachID]
	if s == nil {
		s = &memberStats{}
		f.memberStats[coachID] = s
	}
	return s
}

// noteHPLoss is ig_1's half: damage to the other side, and the kill.
func (f *Fight) noteHPLoss(caster, victim *FightFighter, amount int32) {
	if caster == nil || victim == nil || amount <= 0 || caster.TeamID == victim.TeamID {
		return
	}
	if s := f.stat(caster.CoachID); s != nil {
		s.damage += amount
		s.turnDamage += amount
		if victim.HP <= 0 && !caster.isSummon() {
			s.turnKills++
			if f.punching && breedOf(caster) == breedEniripsa {
				s.eniripsaPunches++
			}
		}
	}
	if victim.HP <= 0 && f.firingArea != nil && !f.firingArea.isAura() && f.firingArea.caster != nil &&
		f.firingArea.caster.TeamID != victim.TeamID {
		if s := f.stat(f.firingArea.caster.CoachID); s != nil {
			s.trapKills++ // va_1: the area's owner
		}
	}
}

// noteMPUsed is sq_2's half.
func (f *Fight) noteMPUsed(mover *FightFighter, mp int32) {
	if mover == nil || mover.isSummon() || mp <= 0 {
		return
	}
	if s := f.stat(mover.CoachID); s != nil {
		s.mpUsed += mp
		s.turnMP += mp
	}
}

// noteAPRemoved is df_2's half: how far below its max AP the target now is.
func (f *Fight) noteAPRemoved(caster, victim *FightFighter) {
	if caster == nil || victim == nil || victim.isSummon() {
		return
	}
	if s := f.stat(caster.CoachID); s != nil {
		s.bestAPRemoved = max(s.bestAPRemoved, victim.MaxAP-victim.AP)
	}
}

// noteDeathCell is va_1 with no area owner: the victim's coach.
func (f *Fight) noteDeathCell(victim *FightFighter) {
	if victim == nil || victim.isSummon() {
		return
	}
	if s := f.stat(victim.CoachID); s != nil {
		s.deathCells++
	}
}

// noteBonusCell counts a special cell that helped one of the coach's fighters.
func (f *Fight) noteBonusCell(ff *FightFighter) {
	if ff == nil {
		return
	}
	if s := f.stat(ff.CoachID); s != nil {
		s.bonusCells++
	}
}

// bestResistance is the client's armour figure (NC and its siblings): an
// element's resistance plus the general one, for the best element.
func (s *combatStats) bestResistance() int32 {
	best := s.resPct[0]
	for _, r := range s.resPct[1:] {
		best = max(best, r)
	}
	return best + s.resPctAll
}

// noteArmour keeps the best element + general resistance a fighter reached.
func (f *Fight) noteArmour(ff *FightFighter, res int32) {
	if ff == nil {
		return
	}
	if s := f.stat(ff.CoachID); s != nil {
		s.bestArmour = max(s.bestArmour, res)
	}
}

// closeStatTurn folds every coach's per-turn temporaries into its best turn
// and clears them. Called when a fighter's turn ends, and once more at the
// end of the fight for the turn that ended it.
func (f *Fight) closeStatTurn() {
	for _, s := range f.memberStats {
		s.bestTurnDamage = max(s.bestTurnDamage, s.turnDamage)
		s.bestTurnKills = max(s.bestTurnKills, s.turnKills)
		s.bestTurnMP = max(s.bestTurnMP, s.turnMP)
		s.turnDamage, s.turnKills, s.turnMP = 0, 0, 0
	}
}

// bank writes the fight's tally for one coach, the level variants picked by
// the force it brought to the fight.
func (s *memberStats) bank(b *statBatch, force int32) {
	b.add(tieredStat(statTrapKills, force), s.trapKills)
	b.max(tieredStat(statTurnDamage, force), s.bestTurnDamage)
	b.max(tieredStat(statFightDamage, force), s.damage)
	b.add(statDeathCellDeaths, s.deathCells)
	b.max(statBestArmour, s.bestArmour)
	b.max(statTurnKills, s.bestTurnKills)
	b.max(statTurnMP, s.bestTurnMP)
	b.max(statAPRemoved, s.bestAPRemoved)
	b.max(statBonusCells, s.bonusCells)
	b.add(statMPUsed, s.mpUsed)
	b.add(statEniripsaPunches, s.eniripsaPunches)
}
