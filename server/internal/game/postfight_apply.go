package game

// postfight_apply.go — runs the post-fight META pass at the end of a fight:
// build each fighter's report (postfight.go), let the coach's card-set bonuses
// modify it, bank the results onto the persistent fighters, and award the coach
// its reputation.
//
// Scope: XP, morale, fatigue and reputation, PLUS the wound and death rolls
// (applyWoundAndDeathRolls, B-066) and condition ageing. This note used to say
// the rolls were not run; they are.

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"math/rand"
	"time"
)

// AI-enum action ids that this META pass consumes. The full list lives in the
// client's `AI` enum, which still carries its original French descriptions.
const (
	aiXPPercent      int32 = 1  // "Bonus ou malus d'XP en %"
	aiXPFlat         int32 = 2  // "Bonus ou malus d'XP"
	aiXPPercentEnemy int32 = 3  // "... en % pour l'adversaire"
	aiXPFlatEnemy    int32 = 4  // "... pour l'adversaire"
	aiWound          int32 = 5  // "Modification des blessures de ses combattants"
	aiWoundEnemy     int32 = 6  // "... des blessures des combattants adverses"
	aiDeath          int32 = 7  // "Modification des chances de mort de ses combattants"
	aiDeathEnemy     int32 = 8  // "... des chances de mort des adversaires"
	aiMorale         int32 = 9  // "Modification du moral de ses combattants"
	aiMoraleEnemy    int32 = 10 // "... des combattants adverses"
	aiCancelWound    int32 = 11 // "Donne x% de chance d'annuler les blessures en fin de combat"
	aiReputation     int32 = 14 // "Modifie le gain de réputation"
	aiTiredness      int32 = 16 // "Modification de fatigue de ses combattants"
	aiTirednessEnemy int32 = 17 // "... des combattants adverses"
)

// baseXPPerFight is the XP a fight is worth before any modifier.
//
// HONEST LIMIT: this number is NOT recoverable from the client. `adl_0` receives
// `baseXp` already computed (the client only ever *reads* `cnr`), so the real
// server's formula for it is not in `core.jar`. Everything the value then flows
// through IS client-exact; only this seed is ours. It is deliberately a single
// named constant so it can be replaced the moment evidence turns up, rather than
// being smeared through the code.
//
// Chosen so that a fighter at neutral morale needs a plausible number of fights
// to clear level 1 (860 XP → ~9 fights) rather than to feel tuned.
// baseXPPerFight moved to Rules.BaseXPPerFight (configurable). The constant is\n// gone deliberately: leaving it would let a call site silently bypass config.

// timeChallengeXPPerTurn mirrors the one XP rule the client DOES compute itself
// (WE.java, time challenges): turns/2 rounded両 ways, times the challenge's own
// multiplier. Not used yet — recorded here so the next person does not re-derive
// it. See docs/DATA-COVERAGE.md.

// deathIsRolledNotDealt records WHY being downed does not kill a fighter, since
// the opposite is the intuitive guess and was what this server did until B-097.
//
// Permanent death in evolution mode is a per-fighter PROBABILITY, computed from
// that fighter's own lifetime XP (`adl_0.atd()`: death% = (totalXp/1000)²/100)
// and spent at the end of the fight. It has no HP input anywhere. Four
// independent pieces of the client say a KO is not a death:
//
//   - `fightEndAchievementDeathDescriptionFailed` — "vous n'avez pas occasionné
//     de MORT DÉFINITIVE chez les combattants adverses". You down the enemy team
//     to win, so if downing killed, this string could never be shown after a win.
//     The client also distinguishes the two words: `fight.die` ("[#1] est mort")
//     is the in-fight KO, "mort définitive" is the permanent one.
//   - `content.29.301` — "et un grand nombre de BLESSURES peut provoquer la
//     mort". Death is the terminal stage of an injury/fatigue chain, reached
//     over many fights, not the consequence of one knockdown.
//   - `bf_1.b` (the wound roller) kills only on an upgrade roll landing while the
//     fighter ALREADY holds 3 serious wounds — again cumulative, never HP-driven.
//   - Opcode 4520 `FighterDiesMessage` (`cd_2`) carries a bare fighter id and no
//     permanence flag, and NO client code links HP==0 to `isDead()`/state 2.
//
// So the two real death paths — the quadratic XP roll and the 3-serious-wounds
// escalation — are both already implemented (B-066), and the HP<=0 override we
// used to run on top of them was invented, not derived. It fired for exactly the
// fighters most likely to be affected and hid the modelled mechanic completely.
//
// HONEST LIMIT: `adl_0.atd()` and `bf_1.b` have no callers in the client (they
// are server logic shipped inside core.jar), so we cannot prove from the client
// whether retail ran the roll for every fielded fighter or gated it on some
// participation test. We roll for every fielded fighter. What the evidence does
// settle is that a KO does not REPLACE the roll with certain death.
const deathIsRolledNotDealt = true

// runPostFightMeta produces the per-fighter debrief reports for a finished fight
// and applies their results. Returns the reports (wire-ready), the reputation
// each coach won, the killed/injured tallies for the achievement counters, and
// the fighters this fight actually KILLED, per coach — the caller uses that last
// one to refresh the affected rosters.
//
// Practice and challenge fights are excluded: they must not feed progression (the
// client says as much for time challenges — "tu n'auras pas de fatigue ni de
// blessure ou de mort dans un défi du temps").
func (d *Deps) runPostFightMeta(f *Fight, winnerTeam uint8) (
	reports []endFightReport, standingByCoach map[uint]int32, killed, injured uint8,
	diedByCoach map[uint][]string) {

	standingByCoach = map[uint]int32{}
	diedByCoach = map[uint][]string{}
	if f == nil || !fightFeedsProgression(f) {
		return nil, standingByCoach, 0, 0, diedByCoach
	}
	now := time.Now().Unix()
	rng := f.rngSource()
	if rng == nil {
		rng = rand.New(rand.NewSource(now))
	}

	for _, t := range f.Teams {
		won := t.ID == winnerTeam
		// Per MEMBER, not per side. Set bonuses come from a coach's OWN equipped
		// cards, so in a 2v2 each coach's bonuses must reach only the fighters it
		// owns - otherwise an ally's gear would silently buff fighters belonging
		// to someone else. `ownFighters` below is what enforces that.
		for _, mem := range t.Members {
			if mem.Coach == nil || isSyntheticCoach(mem.Coach.ID) {
				continue
			}
			sess := mem.Session

			// Set bonuses are per-COACH, so resolve them once per team rather than
			// per fighter.
			xpPct := sessionSetBonus(sess, aiXPPercent)
			xpFlat := sessionSetBonus(sess, aiXPFlat)
			moraleMod := sessionSetBonus(sess, aiMorale)
			tirednessMod := sessionSetBonus(sess, aiTiredness)
			repMod := sessionSetBonus(sess, aiReputation)
			woundMod := sessionSetBonus(sess, aiWound)
			deathMod := sessionSetBonus(sess, aiDeath)
			cancelWound := sessionSetBonus(sess, aiCancelWound)
			// The opponent-facing variants are applied to the OTHER side.
			xpPct += opposingSetBonus(f, t.ID, aiXPPercentEnemy)
			xpFlat += opposingSetBonus(f, t.ID, aiXPFlatEnemy)
			moraleMod += opposingSetBonus(f, t.ID, aiMoraleEnemy)
			tirednessMod += opposingSetBonus(f, t.ID, aiTirednessEnemy)
			woundMod += opposingSetBonus(f, t.ID, aiWoundEnemy)
			deathMod += opposingSetBonus(f, t.ID, aiDeathEnemy)

			var teamStanding int32
			for _, ff := range ownFighters(t, mem) {
				if ff == nil || ff.Fighter == nil || ff.Fighter.ID == 0 {
					continue // summons and synthetic fighters have no persistent row
				}
				fr := ff.Fighter
				rep := &postFightReport{won: won}
				hours := hoursSince(fr.LastFightAt, now)

				// 1. XP: base, scaled by morale, then the rest bonus.
				rep.applyXP(f.deps.rules().BaseXPPerFight, hours, int8(clampInt32(int32(fr.Morale), 0, maxMorale)))
				// 2. Gear/set XP modifiers stack onto the final figure only. A HEAD
				//    WOUND lives here too: it is a meta effect (AI 1, -10%/-20% XP),
				//    which is why the fighter's own conditions are summed in.
				xpPctTotal := xpPct + conditionMetaBonus(d.Conditions, fr, aiXPPercent)
				if xpPctTotal != 0 {
					rep.addXP(rep.xpBeforeGear * xpPctTotal / 100)
				}
				if xpFlat != 0 {
					rep.addXP(xpFlat)
				}
				// 3. Reputation set bonus is converted into XP at the client's rate
				//    (ga_0: cnv += x * nr_0.Po) AND earns the coach standing.
				if repMod != 0 {
					rep.addXP(repMod * standingXPScale)
					teamStanding += repMod
				}
				// 4. Morale drifts with the result, then set bonuses and the
				//    fighter's own conditions shift it (a serious "other" wound is
				//    AI 9, -1 morale).
				rep.applyMoraleDrift(int8(clampInt32(int32(fr.Morale), 0, maxMorale)), won, rng)
				moraleTotal := moraleMod + conditionMetaBonus(d.Conditions, fr, aiMorale)
				if moraleTotal != 0 {
					rep.addMorale(int8(moraleTotal))
				}
				// 5. Fatigue: recover elapsed time, add this fight's cost, then
				//    apply set bonuses (usually negative — rest gear).
				rep.applyTiredness(fr.Tiredness, hours, true, rng)
				if tirednessMod != 0 {
					rep.addTiredness(int8(tirednessMod))
					rep.finaliseTiredness()
				}
				// 6. Wounds and death. Every fielded fighter takes the SAME roll,
				//    whether it finished the fight standing or at 0 HP: falling in
				//    the fight is a KO, not a death. See the block comment above
				//    `deathIsRolledNotDealt` for why.
				if d.Conditions != nil {
					rep.rollInjuryChances(fr.TotalXP, rng)
					// Card/set modifiers shift the chances, guarded exactly as the
					// client guards them: `jT` only applies once the roll happened,
					// and `jU` refuses to raise the death chance of a fighter whose
					// lifetime XP is still under a tenth of the scale — i.e. rookies
					// are protected from death-chance stacking.
					if woundMod != 0 && rep.injuryRolled {
						rep.injuryChance += woundMod
					}
					if deathMod != 0 && rep.injuryRolled && fr.TotalXP*10 < deathXPScale {
						rep.deathChance += deathMod
					}
					if cancelWound > 0 && int32(rng.Intn(100)) < cancelWound {
						rep.injuryCancel = true
					}
					d.applyWoundAndDeathRolls(rep, fr, rng)
				}
				if rep.dead {
					killed++
					diedByCoach[mem.Coach.ID] = append(diedByCoach[mem.Coach.ID], fr.Name)
				}
				if rep.woundID != 0 {
					injured++
					if f.woundsByCoach == nil {
						f.woundsByCoach = map[uint]int32{}
					}
					f.woundsByCoach[mem.Coach.ID]++
					if d.Conditions.Get(int16(rep.woundID)).IsSeriousWound() {
						if f.seriousByCoach == nil {
							f.seriousByCoach = map[uint]int32{}
						}
						f.seriousByCoach[mem.Coach.ID]++
					}
				}

				// 7. Age the fighter's timed conditions by one fight. Done LAST so a
				//    wound taken this fight is not immediately aged.
				expireConditions(fr)

				// SECURITY: re-read the ACCUMULATING fields before banking.
				//
				// fr is the fighter SNAPSHOT taken when the fight was built, and
				// SaveProgress writes absolute values - so anything that changed the
				// stored row while the fight ran was silently reverted at fight end.
				// That was the free talent tree: BuySphere debits XP in the database,
				// the fight ended, and the pre-purchase XP was written back while the
				// fighter_spheres rows (a different table) survived. Mid-fight
				// consumable use was reverted the same way.
				//
				// XP and TotalXP are the only fields bank() ACCUMULATES onto, so they
				// are the only ones a concurrent writer and this write-back can both
				// own. Everything else bank touches (morale, tiredness, last-fight,
				// state) is derived from the fight itself and should overwrite.
				//
				// The roster lock on 23009/5201 is the primary control; this is the
				// root-cause backstop, so a future handler that mutates a fighter
				// without a lock cannot resurrect the exploit. A read-then-write
				// window remains in theory - it is bounded by the locks above, and
				// closing it properly needs SQL deltas whose clamp is dialect-specific
				// (MIN vs LEAST), which is not worth the portability risk here.
				d.refreshAccumulatingFields(fr)

				rep.bank(fr, now)
				if d.Store != nil {
					_ = d.Store.Fighters.SaveProgress(fr)
					_ = d.Store.Fighters.SaveConditions(fr.ID, fr.Conditions)
				}
				// Keyed by the ROSTER id, and tagged with its owner: the client looks
				// each one up in its own fighter list, so a wire id - or another
				// coach's fighter - resolves to nothing and takes the result dialog
				// down with it (B-096).
				reports = append(reports, endFightReport{
					FighterID: int64(fr.ID),
					CoachID:   mem.Coach.ID,
					Blob:      rep.encode(),
				})
			}

			// Coach reputation for the fight itself, plus any set bonus.
			standing := f.deps.standingForResult(won) + teamStanding
			if standing < 0 {
				standing = 0
			}
			standingByCoach[mem.Coach.ID] = standing
			if standing > 0 {
				mem.Coach.Mu.Lock()
				before := StandingToLevel(mem.Coach.Standing)
				mem.Coach.Standing += standing
				after := StandingToLevel(mem.Coach.Standing)
				mem.Coach.Mu.Unlock()
				if d.Store != nil {
					_ = d.Store.Coaches.Save(mem.Coach)
				}
				if after > before {
					d.Log.Info("coach evolution level up", "coach", mem.Coach.Name,
						"level", after, "standing", mem.Coach.Standing)
				}
			}
		}
	}
	if len(reports) > 0 {
		d.Log.Info("post-fight meta", "fight", f.ID, "reports", len(reports),
			"killed", killed, "injured", injured, "standing", standingByCoach)
	}
	return reports, standingByCoach, killed, injured, diedByCoach
}

// fightFeedsProgression decides whether a finished fight runs the META pass.
//
//   - An EVOLUTION fight always does. It IS the progression mode — the client
//     ships a whole dialog for its debrief (`fightResultEvolutionDialog`) — and
//     it is flagged practice as well when started solo against the sparring
//     dummy, so testing `Practice` alone would wrongly skip exactly the mode that
//     needs this most.
//   - A plain PRACTICE ("Tester") fight never does: no ladder, no progression.
//   - A CHALLENGE (PvE) never does either. The client is explicit for the time
//     challenges — "tu n'auras pas de fatigue ni de blessure ou de mort dans un
//     défi du temps" — and challenge rewards are cards, granted elsewhere.
func fightFeedsProgression(f *Fight) bool {
	if f.Evolution {
		return true
	}
	return !f.Practice && f.ChallengeID == 0
}

// standingForResult is the reputation a fight itself is worth.
//
// HONEST LIMIT: like baseXPPerFight, the real value arrives pre-computed on the
// wire (`YP.cbG`) and is not derivable from the client. A win being worth more
// than a loss — and a loss still being worth something — is the shape every
// Ankama progression uses, but the magnitudes here are ours.
func (d *Deps) standingForResult(won bool) int32 {
	if won {
		return d.rules().StandingWin
	}
	return d.rules().StandingLoss
}

// sessionSetBonus is setBonusFor guarded for an absent session (a coach can
// finish a fight disconnected, and the synthetic sides have no session at all).
func sessionSetBonus(s *Session, action int32) int32 {
	if s == nil {
		return 0
	}
	return s.setBonusFor(action)
}

// opposingSetBonus sums an "…pour l'adversaire" bonus owned by the OTHER team and
// therefore applied to this one.
func opposingSetBonus(f *Fight, myTeam uint8, action int32) int32 {
	var total int32
	for _, t := range f.Teams {
		if t.ID == myTeam {
			continue
		}
		// Every member of the opposing side contributes: in a 2v2 both enemy
		// coaches' "pour l'adversaire" bonuses land on us, which is what makes
		// them worth equipping.
		for _, mem := range t.Members {
			total += sessionSetBonus(mem.Session, action)
		}
	}
	return total
}

// ownFighters returns the fighters on side t that belong to member mem.
//
// In a 1v1 that is every fighter on the side, so behaviour is unchanged. In a
// 2v2 it is the split that keeps one coach's set bonuses, wound rolls and XP
// from being applied to its ally's fighters - they are different people with
// different gear, and the post-fight maths is per-coach.
//
// Fighters carry their owner's id from the moment the team is built, so this is
// a filter rather than a guess. A fighter whose CoachID matches no member (a
// summon, or a server-driven fighter) belongs to the side's representative, so
// it is still processed exactly once.
func ownFighters(t *FightTeam, mem *FightMember) []*FightFighter {
	if t == nil || mem == nil || mem.Coach == nil {
		return nil
	}
	out := make([]*FightFighter, 0, len(t.Fighters))
	for _, ff := range t.Fighters {
		if ff == nil {
			continue
		}
		if ff.CoachID == mem.Coach.ID {
			out = append(out, ff)
			continue
		}
		// Unowned: fold it into the representative so it is neither dropped nor
		// counted twice.
		if t.MemberFor(ff.CoachID) == nil && len(t.Members) > 0 && t.Members[0] == mem {
			out = append(out, ff)
		}
	}
	return out
}

// refreshAccumulatingFields re-reads the fighter fields that postFightReport.bank
// ACCUMULATES onto, so a change made while the fight ran is not clobbered.
//
// SECURITY: see the call site in runPostFightMeta. fr is the snapshot taken when
// the fight was built and SaveProgress writes absolute values, so without this a
// mid-fight XP spend was silently refunded at fight end - the root cause of the
// free-talent-tree exploit.
//
// XP and TotalXP only: everything else bank touches (morale, tiredness,
// last-fight, state) is derived from the fight itself and SHOULD overwrite
// whatever is stored.
func (d *Deps) refreshAccumulatingFields(fr *domain.Fighter) {
	if d.Store == nil || d.Store.Fighters == nil || fr == nil {
		return
	}
	fresh, err := d.Store.Fighters.Get(fr.ID)
	if err != nil || fresh == nil {
		return
	}
	fr.XP, fr.TotalXP = fresh.XP, fresh.TotalXP
}
