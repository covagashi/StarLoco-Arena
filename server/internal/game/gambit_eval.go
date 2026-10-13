package game

import (
	"fmt"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// gambit_eval.go EVALUATES the rulesets gambit.go defines, on an AI-driven
// fighter's turn, inside runAITurn.
//
// The shape is the design's, in one sentence: rules first, archetype second.
// gambitTurn walks the fighter's list top-down; the first rule whose condition
// holds AND whose action can actually be taken right now wins; it acts, the
// list is walked again from the top, and the turn ends when nothing applies.
// If NOTHING applied on the first pass, gambitTurn reports that it did not
// play, and runAITurn hands the whole turn to the archetype AI (ai.go) exactly
// as it did before gambits existed.
//
// Three properties this file is built around:
//
//  1. A rule that CANNOT act is not a rule that fired. "Cast spell 148 at the
//     weakest enemy" with 148 on cooldown, out of range, unaffordable or aimed
//     through a wall does not consume the turn and does not stop the list — the
//     walk continues to the next rule, and if no rule can act the archetype
//     plays. That is the "falls back to the existing archetype AI" clause of
//     the design, and it is why the readiness check uses the REAL validators
//     (aiSpellCastableFrom, the same predicate the AI's own positioning and
//     casting agree on) rather than a cheaper approximation that could disagree
//     with the cast handler and freeze the fighter.
//
//  2. Nothing here bypasses a rule the fight enforces. Every action routes
//     through the same call a human coach's packet would reach
//     (castSpellByFighter, closeCombat, the AI's own MP-limited, hazard-aware
//     movement), so a ruleset cannot ask for a cast the handlers would refuse,
//     cannot see an invisible enemy, and cannot nuke its own team: the
//     friendly-fire and support gates from ai.go/ai_support.go apply to a
//     rule-driven cast as much as to an archetype one.
//
//  3. Determinism survives (phase 1). Evaluation reads fight state, walks
//     SLICES only (never a map), and consumes no RNG of its own: the only dice
//     a gambit turn rolls are the ones its casts and attacks were always going
//     to roll. Ties are broken by rule order, and rule order alone.

// maxGambitStepsPerTurn is the hard ceiling on actions one gambit turn may
// take, whatever the rules say.
//
// Nearly every action spends AP or MP, so the AP+MP budget below is the real
// bound; this one exists because a cast can GIVE AP back (an action-13 self
// buff with no cooldown is a legal ruleset away from a turn that funds itself).
// A fight must not be able to spin on a crafted rule list, and a turn capped at
// 64 actions is far past anything a real strategy needs.
const maxGambitStepsPerTurn = 64

// gambitStepBudget is how many actions this fighter's gambit turn may take: its
// AP plus its MP plus two (one for a pass, one for slack), capped. Every
// performed action spends AP or MP or stops the turn, so the budget is reached
// only by a ruleset doing something pathological.
func gambitStepBudget(ff *FightFighter) int {
	if ff == nil {
		return 0
	}
	ap, mp := ff.AP, ff.MP
	if ff.MaxAP > ap {
		ap = ff.MaxAP
	}
	if ff.MaxMP > mp {
		mp = ff.MaxMP
	}
	budget := int(ap) + int(mp) + 2
	if budget < 2 {
		budget = 2 // a fighter with no resources may still pass
	}
	if budget > maxGambitStepsPerTurn {
		budget = maxGambitStepsPerTurn
	}
	return budget
}

// gambitTurn plays `ff`'s turn from its gambit rules and reports whether the
// rules played it at all. false means "no rule applied": the caller must fall
// back to the archetype AI, which is the design's documented behaviour for
// anything the rules cannot express.
//
// Runs on the fight actor goroutine, like every other turn-progression call —
// no new goroutine, no locking, same as the AI it sits on top of.
func (f *Fight) gambitTurn(ff *FightFighter) bool {
	if f == nil || ff == nil || ff.Gambits == nil || len(ff.Gambits.Rules) == 0 {
		return false
	}
	fired := false
	budget := gambitStepBudget(ff)
	for step := 0; step < budget; step++ {
		if ff.HP <= 0 || f.Phase() != PhaseAction || !f.isCurrentTurn(ff.WireID) {
			break // died mid-turn, or a cast ended the fight
		}
		idx := f.gambitStep(ff)
		if idx < 0 {
			break // nothing in the list can act on the state we are now in
		}
		fired = true
		if ff.Gambits.Rules[idx].Do.Kind == gambitPass {
			break // a pass is a deliberate end of turn, not a step toward one
		}
	}
	return fired
}

// gambitStep walks the rule list once from the top and takes the FIRST rule
// that holds, is ready, and whose action actually changes something. It returns
// that rule's index, or -1 when the whole list did nothing.
//
// The walk continues past a rule whose action turns out to be a no-op (the
// clearest case: "move toward the enemy" from a fighter already standing next
// to it, where readiness cannot know the move search will find no better cell).
// That is the same principle as a rule that is not ready at all — a rule that
// did not act is not a rule that fired — and it is forward-only, so it cannot
// loop: either some rule acts, or the step reports -1 and the archetype AI gets
// the turn.
//
// Each chosen rule is written to the fight decision log in the decisionBehavior
// slot — the one runAITurn fills with the archetype name — so a replay reads
// "which plan drove this turn" the same way whether a rule or an archetype
// drove it (see fightlog.go). It is logged BEFORE the action, so the cast/move
// rows that follow sit under the rule that ordered them, and a logged rule with
// no row under it is visibly a rule that achieved nothing.
func (f *Fight) gambitStep(ff *FightFighter) int {
	for i := range ff.Gambits.Rules {
		r := ff.Gambits.Rules[i]
		if !f.gambitConditionHolds(ff, r.If) {
			continue
		}
		if !f.gambitActionReady(ff, r.Do) {
			continue // cannot act on this one right now: try the next rule
		}
		f.logDecision(ff, decisionBehavior, fmt.Sprintf("gambit rule=%d %s", i+1, r))
		if f.gambitPerform(ff, r.Do) {
			return i
		}
		// Chosen but it changed nothing: keep walking rather than burn the turn.
		// Every action that DOES change something spends AP or MP, which is what
		// bounds the step budget above.
	}
	return -1
}

// gambitConditionHolds evaluates one condition against the current fight state.
//
// Every opponent-facing condition skips INVISIBLE enemies, the same way the
// AI's targeting does (ai_knowledge.go): a ghost that reacts to an enemy it
// cannot see is the most visible way for a server-driven fighter to look like
// it is cheating, and it would be one missing check away.
func (f *Fight) gambitConditionHolds(ff *FightFighter, c gambitCondition) bool {
	if ff == nil {
		return false
	}
	switch c.Kind {
	case gambitAlways:
		return true
	case gambitSelfHPBelow:
		return gambitHPBelowPct(ff, c.Value)
	case gambitEnemyHPBelow:
		for _, fr := range f.allFighters() {
			if f.gambitSeesEnemy(ff, fr) && gambitHPBelowPct(fr, c.Value) {
				return true
			}
		}
		return false
	case gambitAllyHPBelow:
		for _, fr := range f.allFighters() {
			if gambitIsAlly(ff, fr) && gambitHPBelowPct(fr, c.Value) {
				return true
			}
		}
		return false
	case gambitNearestEnemyDistLE:
		d := f.minEnemyDistance(ff, ff.Pos)
		return d >= 0 && d <= c.Value
	case gambitTurnGE:
		return f.tableTurn >= c.Value
	case gambitAllyCountLE:
		n := int32(0)
		for _, fr := range f.allFighters() {
			if gambitIsAlly(ff, fr) {
				n++
			}
		}
		return n <= c.Value
	default:
		// Unreachable through parseGambitRules, which rejects unknown kinds. A
		// ruleset built in code that skipped validation reads as "does not hold",
		// so an unknown condition can never fire — it falls back, it does not
		// guess.
		return false
	}
}

// gambitHPBelowPct reports whether a fighter's HP is strictly below `pct`
// percent of its maximum. Compared by multiplication rather than dividing into
// a percentage, so a threshold is not silently shifted by integer truncation.
func gambitHPBelowPct(ff *FightFighter, pct int32) bool {
	if ff == nil || ff.HP <= 0 || ff.MaxHP <= 0 {
		return false
	}
	return ff.HP*100 < pct*ff.MaxHP
}

// gambitSeesEnemy reports whether `fr` is an opponent of `ff` that `ff` is
// allowed to react to: living, on the other side, and not invisible.
func (f *Fight) gambitSeesEnemy(ff, fr *FightFighter) bool {
	return fr != nil && fr.HP > 0 && f.areOpponents(ff, fr) && !fr.hasState(stateInvisible)
}

// gambitIsAlly reports whether `fr` is a living teammate of `ff` OTHER than
// `ff` itself — the meaning both ally conditions and the weakest_ally target
// share, so "ally" never quietly includes the fighter asking.
func gambitIsAlly(ff, fr *FightFighter) bool {
	return fr != nil && fr != ff && fr.HP > 0 && fr.TeamID == ff.TeamID
}

// gambitResolveTarget resolves a cast target spec to a fighter, or nil when
// there is nobody to aim at (which makes the rule inapplicable rather than an
// error).
//
// Both "weakest" walks take the lowest HP on a single pass over the fighter
// slices, improving only on a STRICT decrease, so equal-HP candidates are
// settled by the fight's own fighter order and never by map iteration.
func (f *Fight) gambitResolveTarget(ff *FightFighter, t gambitTarget) *FightFighter {
	switch t {
	case gambitTargetSelf:
		if ff == nil || ff.HP <= 0 {
			return nil
		}
		return ff
	case gambitTargetNearestEnemy:
		return f.nearestOpponent(ff)
	case gambitTargetWeakestEnemy:
		var best *FightFighter
		for _, fr := range f.allFighters() {
			if !f.gambitSeesEnemy(ff, fr) {
				continue
			}
			if best == nil || fr.HP < best.HP {
				best = fr
			}
		}
		return best
	case gambitTargetWeakestAlly:
		var best *FightFighter
		for _, fr := range f.allFighters() {
			if !gambitIsAlly(ff, fr) {
				continue
			}
			if best == nil || fr.HP < best.HP {
				best = fr
			}
		}
		return best
	default:
		return nil
	}
}

// gambitActionReady reports whether the action could be taken right now. It is
// the gate that decides whether a rule FIRES at all, so it must agree with what
// the action's own call will do — anything it waves through that the handler
// then refuses ends the turn with nothing done.
func (f *Fight) gambitActionReady(ff *FightFighter, a gambitAction) bool {
	switch a.Kind {
	case gambitCast:
		_, _, ok := f.gambitCastReady(ff, a)
		return ok
	case gambitMoveToward, gambitMoveAway:
		// Both movement actions need legs and something to move relative to.
		return ff.MP > 0 && !ff.hasState(stateRooted) && f.nearestOpponent(ff) != nil
	case gambitCloseCombat:
		return ff.effectiveAP() >= closeCombatAP && f.adjacentOpponent(ff) != nil
	case gambitPass:
		return true
	default:
		return false
	}
}

// gambitCastReady resolves a cast rule and validates it through the SAME
// predicates the AI uses for its own casts, returning the spell and target when
// the cast is legal from where the fighter stands this instant.
//
// Pure: it changes nothing, so the readiness check and the action can both call
// it and cannot disagree.
//
// An enemy-aimed cast goes through aiSpellCastableFrom, which is the one
// predicate in this package that answers "could this fighter legally and
// sensibly cast this at that right now" — harmful effect, affordable, off
// cooldown, within its frequency limits, the real range/line-of-sight/target
// validator from the caster's cell, and no friendly splash. An ally- or
// self-aimed cast gets the mirror of it (ai_support.go's gate): the spell must
// NOT be harmful, and must be affordable, available and legally targetable. So
// a ruleset can no more drop a bomb on its own healer than the archetype AI
// can, and no more aim a heal at an enemy.
func (f *Fight) gambitCastReady(ff *FightFighter, a gambitAction) (*gamedata.Spell, *FightFighter, bool) {
	if ff == nil || f.deps == nil || f.deps.Spells == nil {
		return nil, nil, false
	}
	// A rule may only name a spell the fighter actually knows. castSpellByFighter
	// enforces this too (a forged cast must not reach the spell table), but
	// checking here means a stale ruleset — a spell the roster no longer carries —
	// falls through to the next rule instead of being chosen and then refused.
	if !fighterKnowsSpell(ff, a.Spell) {
		return nil, nil, false
	}
	sp := f.deps.Spells.Get(a.Spell)
	if sp == nil {
		return nil, nil, false // not in this server's spell data
	}
	target := f.gambitResolveTarget(ff, a.Target)
	if target == nil {
		return nil, nil, false
	}
	if f.areOpponents(ff, target) {
		if !f.aiSpellCastableFrom(ff, ff.Pos, sp, target) {
			return nil, nil, false
		}
		return sp, target, true
	}
	if !f.gambitSupportCastable(ff, sp, target) {
		return nil, nil, false
	}
	return sp, target, true
}

// gambitSupportCastable is the ally/self half of gambitCastReady: the same
// checks aiSupportCast applies, minus the "is this heal worth an action"
// judgement — a rule IS the judgement, so the engine does not second-guess it.
func (f *Fight) gambitSupportCastable(ff *FightFighter, sp *gamedata.Spell, target *FightFighter) bool {
	if aiSpellHarmsEnemy(sp) {
		return false // never aim a harmful spell at your own side
	}
	if aiSpellAPCost(sp) > ff.AP {
		return false
	}
	if !ff.CastHistory.canCast(sp.LimitKeyID(), sp.Cooldown, sp.CastMaxPerTurn,
		sp.CastMaxPerTarget, f.tableTurn, target.WireID, true) {
		return false
	}
	return f.spellTargetValidFrom(ff, ff.Pos, sp, target.Pos)
}

// gambitPerform takes the action and reports whether it changed anything.
//
// "Changed anything" is measured from observable state (position, AP, the
// cast's own return) rather than assumed from the call succeeding, because an
// action that silently no-ops is exactly the case the caller must notice: it
// stops the turn instead of re-choosing the same rule forever.
func (f *Fight) gambitPerform(ff *FightFighter, a gambitAction) bool {
	switch a.Kind {
	case gambitCast:
		_, target, ok := f.gambitCastReady(ff, a)
		if !ok {
			return false
		}
		return f.castSpellByFighter(ff, a.Spell, target.Pos)
	case gambitMoveToward:
		before := ff.Pos
		f.moveTowardNearestOpponent(ff)
		return ff.Pos != before
	case gambitMoveAway:
		before := ff.Pos
		f.retreatFromOpponents(ff)
		return ff.Pos != before
	case gambitCloseCombat:
		target := f.adjacentOpponent(ff)
		if target == nil {
			return false
		}
		before := ff.AP
		f.closeCombat(ff, target.Pos)
		return ff.AP < before
	case gambitPass:
		// Nothing to do, and deliberately nothing logged: the turn ends having
		// taken no action, which endTurn already records as a pass (fightlog.go).
		return true
	default:
		return false
	}
}
