package game

import "github.com/StarLoco/arena-2.70/internal/domain"

// statistics.go keeps the coach statistics only the server can see.
//
// The achievements (type 800) are thresholds on the client's statistic enum
// (or_0). The client moves a few of those itself through 22003 — the Rayban
// tip, talking to Demon III / Demon I / a breed master, creating a coach, a
// dialog reply or a script that names one. Everything about fights, the ladder
// and evolution it never sends, because only the server knows it; until S19
// the server kept none of them, so ~85 counters sat at 0 and their
// achievements could never unlock.
//
// Two kinds of value, as the enum descriptions say: a running total ("Nombre
// de …", AddStat) and a best ever ("… maximum", "Plus gros …", MaxStat). The
// per-level variants ("(2572 >= force > 1756)", "(force > 2572)") sit at +300
// and +600 of the base id and are picked by the coach's 1v1 force, which is
// what the achievements call levels 1-20, 20-40 and over 40.

// Client or_0 ids the server maintains.
const (
	statBiggestFeca      int16 = 42  // + breed - 1: "Plus gros <breed> utilisé pour un combat gagné"
	statLevelGap1v1      int16 = 131 // "Différence de niveau positive maximale … en 1VS1"
	statWinStreak2v2     int16 = 146 // "Nombre de victoires consécutives maximum en 2VS2"
	statLevelGap2v2      int16 = 148
	statWinStreak1v1     int16 = 165
	statForce1v1         int16 = 167 // "Force maximale atteinte en 1VS1"
	statLostByGiveUp     int16 = 170 // "Nombre de combat perdus par abandon"
	statGaveUpFirst2v2   int16 = 171 // "Nombre d'abandons avant son coéquipier en 2VS2"
	statWonSolo          int16 = 63  // "Nombre de combats gagnés avec un seul personnage"
	statMostXPSpent      int16 = 201 // "Le plus d'Xp utilisés par un fighter"
	statEvoDeathsTaken   int16 = 202 // "Morts eus en mode évolution"
	statEvoWoundsTaken   int16 = 203
	statEvoDeathsDealt   int16 = 204 // "Morts infligés en mode évolution"
	statEvoWoundsDealt   int16 = 205
	statReputation       int16 = 207 // "Réputation atteinte"
	statWinStreakEvo     int16 = 209 // "Nombre de victoires consécutives en mode évolution"
	statLadderGap1v1     int16 = 35  // "Haber alcanzado el puesto: 2.500 - [#1]" (content.48.35)
	statHellsTofus       int16 = 40  // wins against challenge 3, "Hell's tofus of the death!"
	statLimeroByPunches  int16 = 84  // challenge 12 (Limero) won without casting a spell
	statEvoSerious       int16 = 206 // "Haber tenido [#1] heridas graves en modo evolución"
	ladderGapBase        int32 = 2500
	challengeHellsTofus  int32 = 3
	challengeLimero      int32 = 12
	statTierStep         int16 = 300 // a per-level variant is base + 300 / + 600
	tierForceLow         int32 = 1756
	tierForceHigh        int32 = 2572
	statServerStreakBase int16 = 3000 // server-only current streaks, above the client enum
)

// Server-only bookkeeping: the CURRENT win streak per mode, which the "maximum"
// criteria above are the best of. Above handshake.MaxCriterionID, so never sent.
const (
	streakMode1v1 int16 = iota + 1
	streakMode2v2
	streakModeEvolution
)

// tieredStat picks a per-level variant of base by the coach's 1v1 force.
func tieredStat(base int16, force int32) int16 {
	switch {
	case force > tierForceHigh:
		return base + 2*statTierStep
	case force > tierForceLow:
		return base + statTierStep
	}
	return base
}

// fightStatMode is the ladder a finished fight counts for, or 0 for none:
// practice and challenges keep no streaks. A tournament fixture counts for its
// mode (1v1, or evolution for evolution-type tournaments): it is ranked and
// moves the 1v1 force like any Combattre pairing (S09).
func fightStatMode(f *Fight) int16 {
	switch {
	case f.Evolution:
		return streakModeEvolution
	case f.Practice || f.ChallengeID != 0:
		return 0
	}
	for _, t := range f.Teams {
		if len(t.Members) > 1 {
			return streakMode2v2
		}
	}
	return streakMode1v1
}

// fightOutcome is what checkFightEnd hands the statistics pass: who gave up,
// and the evolution deaths and wounds the post-fight roll dealt per coach.
type fightOutcome struct {
	winnerTeam uint8
	preForce   map[uint]int32 // 1v1 force before this fight moved it
	gaveUp     map[uint]bool
	deaths     map[uint]int32
	wounds     map[uint]int32
	serious    map[uint]int32 // the serious ones among wounds
}

// recordFightStatistics banks the end-of-fight statistics for every real
// coach, then lets each one's achievements re-evaluate. Runs on the fight
// actor after the post-fight META pass; errors are logged, never propagated.
func (d *Deps) recordFightStatistics(f *Fight, out fightOutcome) {
	if d.Store == nil || f == nil {
		return
	}
	mode := fightStatMode(f)
	f.closeStatTurn() // the turn that ended the fight
	for _, t := range f.Teams {
		won := t.ID == out.winnerTeam
		for _, mem := range t.Members {
			c := mem.Coach
			if c == nil || isSyntheticCoach(c.ID) {
				continue
			}
			b := statBatch{d: d, coach: c.ID}
			c.Mu.Lock()
			after, standing := c.Strength, c.Standing
			c.Mu.Unlock()
			force := out.preForce[c.ID]

			b.max(statReputation, standing)
			if out.gaveUp[c.ID] {
				b.add(statLostByGiveUp, 1)
				if mode == streakMode2v2 && !out.gaveUp[allyOf(t, c.ID)] {
					b.add(statGaveUpFirst2v2, 1)
				}
			}
			if mode != 0 {
				b.streak(mode, won)
			}
			if mode == streakMode1v1 {
				b.max(statForce1v1, after)
				if rank, err := d.Store.Coaches.LadderRank(c.ID); err == nil && rank > 0 {
					b.max(statLadderGap1v1, ladderGapBase-int32(rank))
				}
			}
			if won && f.ChallengeID == challengeHellsTofus {
				b.add(statHellsTofus, 1)
			}
			if won && f.ChallengeID == challengeLimero {
				if s := f.memberStats[c.ID]; s == nil || !s.castSpell {
					b.add(statLimeroByPunches, 1)
				}
			}
			if won && (mode == streakMode1v1 || mode == streakMode2v2) {
				gap := sideLevel(f, out.preForce, t.ID, false) - sideLevel(f, out.preForce, t.ID, true)
				if mode == streakMode1v1 {
					b.max(statLevelGap1v1, gap)
				} else {
					b.max(statLevelGap2v2, gap)
				}
			}
			if f.Evolution {
				b.add(statEvoDeathsTaken, out.deaths[c.ID])
				b.add(statEvoWoundsTaken, out.wounds[c.ID])
				b.add(statEvoSerious, out.serious[c.ID])
				for _, om := range opponentsOf(f, t.ID) {
					b.add(statEvoDeathsDealt, out.deaths[om])
					b.add(statEvoWoundsDealt, out.wounds[om])
				}
			}

			own := ownFighters(t, mem)
			fielded := 0
			for _, ff := range own {
				if ff == nil || ff.Fighter == nil || ff.Fighter.ID == 0 {
					continue // summons
				}
				fielded++
				fr := ff.Fighter
				b.max(statMostXPSpent, fr.TotalXP-fr.XP)
				if won && mode != 0 && fr.BreedID >= 1 && fr.BreedID <= 12 {
					b.max(tieredStat(statBiggestFeca+int16(fr.BreedID)-1, force), int32(fr.Budget))
				}
			}
			if won && mode != 0 && fielded == 1 {
				b.add(statWonSolo, 1)
			}
			if s := f.memberStats[c.ID]; s != nil && !f.Practice {
				s.bank(&b, force) // a sparring bout is a sandbox, not a record
			}
			if b.moved && mem.Session != nil {
				mem.Session.evaluateAchievements()
			}
		}
	}
}

// statBatch writes one coach's statistics and remembers whether any moved.
type statBatch struct {
	d     *Deps
	coach uint
	moved bool
}

func (b *statBatch) max(id int16, v int32) {
	if v <= 0 {
		return
	}
	moved, err := b.d.Store.Coaches.MaxStat(b.coach, id, v)
	b.note(id, moved, err)
}

func (b *statBatch) add(id int16, delta int32) {
	if delta == 0 {
		return
	}
	moved, err := b.d.Store.Coaches.AddStat(b.coach, id, delta)
	b.note(id, moved, err)
}

// streak advances (or resets) the current win streak of one mode and folds
// it into that mode's best.
func (b *statBatch) streak(mode int16, won bool) {
	cur := statServerStreakBase + mode
	if !won {
		_ = b.d.Store.Coaches.UpsertStat(b.coach, cur, 0)
		return
	}
	if _, err := b.d.Store.Coaches.AddStat(b.coach, cur, 1); err != nil {
		b.note(cur, false, err)
		return
	}
	n := b.d.Store.Coaches.StatValue(b.coach, cur)
	switch mode {
	case streakMode1v1:
		b.max(statWinStreak1v1, n)
	case streakMode2v2:
		b.max(statWinStreak2v2, n)
	case streakModeEvolution:
		b.max(statWinStreakEvo, n)
	}
}

func (b *statBatch) note(id int16, moved bool, err error) {
	if err != nil {
		b.d.Log.Warn("record statistic", "coach", b.coach, "stat", id, "err", err)
		return
	}
	b.moved = b.moved || moved
}

// allyOf is the other coach on a 2v2 side (0 when there is none).
func allyOf(t *FightTeam, coachID uint) uint {
	for _, m := range t.Members {
		if m.Coach != nil && m.Coach.ID != coachID {
			return m.Coach.ID
		}
	}
	return 0
}

// opponentsOf lists the real coaches facing team.
func opponentsOf(f *Fight, team uint8) []uint {
	var out []uint
	for _, t := range f.Teams {
		if t.ID == team {
			continue
		}
		for _, m := range t.Members {
			if m.Coach != nil && !isSyntheticCoach(m.Coach.ID) {
				out = append(out, m.Coach.ID)
			}
		}
	}
	return out
}

// sideLevel is the mean coach level (from the pre-fight force) of team, or of
// the side facing it when own is false.
func sideLevel(f *Fight, force map[uint]int32, team uint8, own bool) int32 {
	var sum, n int32
	for _, t := range f.Teams {
		if (t.ID == team) != own {
			continue
		}
		for _, m := range t.Members {
			if m.Coach != nil {
				s := force[m.Coach.ID]
				if s == 0 {
					s = domain.StrengthUnranked // an unranked coach plays at level 1
				}
				sum += int32(domain.StrengthToLevel(s))
				n++
			}
		}
	}
	if n == 0 {
		return 0
	}
	return sum / n
}

// Statistics moved outside a fight, by the coach's own session.
const (
	statWornItems       int16 = 34  // "Equipar a tu jefe con [#1] objetos" (content.48.34)
	statEvoConsumables  int16 = 208 // "Haber utilizado [#1] pócimas y objetos consumibles en modo evolución"
	statEvoLivingDelete int16 = 220 // "Nombre de combattants évolution non morts supprimés"
	coachSlotPet        int16 = 9   // the Familier slot: a pet, not something worn
)

// noteStat applies one statistic for the session's coach (best when best is
// set, else a running total) and re-evaluates its achievements if it moved.
func (s *Session) noteStat(id int16, v int32, best bool) {
	if s.Coach == nil || s.deps.Store == nil {
		return
	}
	b := statBatch{d: s.deps, coach: s.Coach.ID}
	if best {
		b.max(id, v)
	} else {
		b.add(id, v)
	}
	if b.moved {
		s.evaluateAchievements()
	}
}

// wornItems counts the coach cards worn in the clothing slots (aMK: 0-11, the
// pet's slot left out).
func wornItems(inv []domain.CoachCard) int32 {
	var n int32
	for _, c := range inv {
		if slot := c.Pos - 1; c.Pos > 0 && slot <= 11 && slot != coachSlotPet {
			n++
		}
	}
	return n
}
