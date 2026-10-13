package game

import (
	"sort"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// ai.go drives the built-in AI that plays the turn of any fighter no client
// controls: a summoned creature (has a Father) and the sparring opponent (its
// team has no session). Without it such a fighter would just idle until its turn
// clock force-ended. The behaviour is a port of the v2.04b server's summon AI
// (internal/combat/summon_ai.go), adapted to the 2.70 fight model: a summon's
// archetype is DERIVED from its single spell + stats (there is no behaviour data
// in the game files), so it stays correct as the underlying spell data changes.
//
//   - Blocker    (no spell): walk adjacent to the nearest enemy and hit it.
//   - Aggressive (spell damages enemies): close into range and cast until dry.
//   - Kite       (debuff spell, or lots of MP): cast from range, then retreat.
//   - Self-buff  (self-targeted buff): cast on self, then block the nearest enemy.
//
// The archetype is still chosen from the fighter's DEFINING spell
// (SummonSpellID), but casting is no longer limited to it: a fighter plays from
// a repertoire (aiRepertoire) and re-picks the best castable spell before every
// cast. A summoned creature carries exactly one spell, so it is unaffected.
//
// Every archetype except Kite then spends LEFTOVER AP on close combat. Kite is
// excluded on purpose: its plan is to break contact, and trading blows would
// undo the retreat it just made.

type aiBehavior int

const (
	behaviorBlocker    aiBehavior = iota // no spell: close in and body-block
	behaviorSelfBuff                     // buffs self: cast on self, then block
	behaviorKite                         // debuffs enemies / high MP: cast then retreat
	behaviorAggressive                   // damages enemies: close in and cast
)

// String names the archetype for the fight decision log (fightlog.go).
func (b aiBehavior) String() string {
	switch b {
	case behaviorSelfBuff:
		return "selfbuff"
	case behaviorKite:
		return "kite"
	case behaviorAggressive:
		return "aggressive"
	default:
		return "blocker"
	}
}

// kiteMPThreshold: a damage summon with at least this much MP hits and runs
// instead of standing and trading (e.g. a nimble Tofu).
const kiteMPThreshold int32 = 4

// runAITurn plays a full AI turn for `ff` and then ends its turn. Armed from
// beginTurn (on the short aiTurnClock) so the client renders the turn-begin
// first. Runs on the fight actor goroutine like every other turn-progression
// call, so ending the turn at the end is safe.
func (f *Fight) runAITurn(ff *FightFighter) {
	if f.Phase() != PhaseAction || !f.isCurrentTurn(ff.WireID) {
		return
	}
	behavior := f.classifyAI(ff)
	// Record WHICH plan this fighter is playing before it plays it. Today that is
	// the archetype; it is the slot a gambit engine's "rule fired" row occupies,
	// so the action rows that follow need no change when rules arrive.
	f.logDecision(ff, decisionBehavior, behavior.String())
	switch behavior {
	case behaviorSelfBuff:
		f.playSelfBuffAI(ff)
		f.closeCombatAI(ff)
	case behaviorAggressive:
		f.playAggressiveAI(ff)
		f.closeCombatAI(ff)
	case behaviorKite:
		// No weapon attack: this archetype's plan is to break contact, and
		// standing to trade blows would undo the retreat it just made.
		f.playKiteAI(ff)
	default: // behaviorBlocker
		f.moveTowardNearestOpponent(ff)
		f.closeCombatAI(ff)
	}

	// If the fighter died mid-turn (kamikaze cast / lethal cell) or its cast
	// ended the fight, the turn already advanced centrally — don't end it again.
	if ff.HP <= 0 || f.Phase() != PhaseAction || !f.isCurrentTurn(ff.WireID) {
		return
	}
	f.endTurn(ff.WireID)
}

// classifyAI derives the fighter's behaviour archetype from its spell. No spell
// (or no gamedata) -> blocker. Otherwise inspect the spell's effect kinds: any
// damage -> aggressive (or kite if very mobile); a debuff -> kite; a self-only
// buff -> self-buff.
func (f *Fight) classifyAI(ff *FightFighter) aiBehavior {
	// No signature spell => blocker: walk in and use close combat. Note this is
	// reached by any AI fighter whose SummonSpellID is 0, INCLUDING one that has a
	// full Fighter.Spells loadout - the repertoire is never consulted from the
	// blocker branch. Challenge demons therefore have a breed spell assigned for
	// exactly this reason (challenge_fights.go pickBreedSpell).
	if ff.SummonSpellID == 0 || f.deps == nil || f.deps.Spells == nil {
		return behaviorBlocker
	}
	sp := f.deps.Spells.Get(ff.SummonSpellID)
	if sp == nil {
		return behaviorBlocker
	}
	var damages, debuffs, buffsSelf bool
	for _, ef := range sp.Effects {
		switch ef.Kind() {
		case gamedata.KindDamage, gamedata.KindLeech, gamedata.KindPercentHP,
			gamedata.KindPoison, gamedata.KindScaledAP, gamedata.KindScaledMP,
			gamedata.KindInstantDeath:
			damages = true
		case gamedata.KindAPLoss, gamedata.KindMPLoss, gamedata.KindAPSteal, gamedata.KindMPSteal:
			debuffs = true
		case gamedata.KindBuff:
			if sp.RangeMax == 0 { // a range-0 spell only targets its own cell
				buffsSelf = true
			}
		}
	}
	switch {
	case damages:
		if ff.MP >= kiteMPThreshold {
			return behaviorKite
		}
		return behaviorAggressive
	case debuffs:
		return behaviorKite
	case buffsSelf:
		return behaviorSelfBuff
	default:
		return behaviorBlocker
	}
}

// playAggressiveAI closes into spell range of the nearest enemy and casts until
// out of AP or range.
func (f *Fight) playAggressiveAI(ff *FightFighter) {
	target := f.nearestOpponent(ff)
	if target == nil {
		return
	}
	f.moveIntoSpellRange(ff, target)
	f.castAISpellRepeatedly(ff)
}

// playKiteAI casts at the nearest enemy from range, then retreats with leftover
// MP (hit-and-run).
func (f *Fight) playKiteAI(ff *FightFighter) {
	target := f.nearestOpponent(ff)
	if target == nil {
		return
	}
	f.moveIntoSpellRange(ff, target)
	f.castAISpellRepeatedly(ff)
	if ff.HP > 0 && f.isCurrentTurn(ff.WireID) {
		f.retreatFromOpponents(ff)
	}
}

// playSelfBuffAI casts the self-buff on its own cell, then blocks the nearest
// enemy.
func (f *Fight) playSelfBuffAI(ff *FightFighter) {
	if ff.SummonSpellID != 0 {
		f.castSpellByFighter(ff, ff.SummonSpellID, ff.Pos)
	}
	if ff.HP > 0 && f.isCurrentTurn(ff.WireID) {
		f.moveTowardNearestOpponent(ff)
	}
}

// adjacentOpponent returns the living enemy on an orthogonally adjacent cell
// that this fighter should hit, using the same preference as target selection
// (higher initiative, then a real fighter over a summon) so it stays
// deterministic.
func (f *Fight) adjacentOpponent(self *FightFighter) *FightFighter {
	var best *FightFighter
	for _, fr := range f.allFighters() {
		if fr.HP <= 0 || !f.areOpponents(self, fr) || fr.hasState(stateInvisible) {
			continue
		}
		if manhattanDist(self.Pos, fr.Pos) != 1 {
			continue
		}
		if best == nil || aiTargetPreferred(fr, best) {
			best = fr
		}
	}
	return best
}

// closeCombatAI spends LEFTOVER AP on weapon attacks against an adjacent enemy.
//
// It runs after the archetype has cast, because a spell is almost always the
// better use of AP — close combat is a flat 5 AP for a flat 5 base damage, while
// chooseAISpell already picked the hardest-hitting affordable spell. Without
// this a fighter with no castable spell did NOTHING all fight: the blocker
// archetype walked adjacent and then just stood there, which is also what
// happens to any fighter whose loadout is empty.
func (f *Fight) closeCombatAI(ff *FightFighter) {
	for ff.HP > 0 && f.isCurrentTurn(ff.WireID) && ff.AP >= closeCombatAP {
		target := f.adjacentOpponent(ff)
		if target == nil {
			return
		}
		before := ff.AP
		f.closeCombat(ff, target.Pos)
		if ff.AP >= before {
			return // refused for a reason we did not model: stop rather than spin
		}
	}
}

// aiRepertoire returns every spell the AI fighter may cast, in a deterministic
// order. SummonSpellID comes first — it is the fighter's defining spell, and for
// a summoned creature it is the ONLY one — followed by any spells its
// domain.Fighter carries. Both sources are exactly what fighterKnowsSpell
// accepts, so the AI can never pick something the cast handler will refuse as
// unowned.
//
// A summon (empty Fighter.Spells) therefore still yields a single-spell list and
// behaves exactly as before.
func (f *Fight) aiRepertoire(ff *FightFighter) []int32 {
	if ff == nil {
		return nil
	}
	out := make([]int32, 0, 1+maxFighterSpells)
	seen := make(map[int32]bool, 1+maxFighterSpells)
	add := func(id int32) {
		if id == 0 || seen[id] {
			return
		}
		seen[id] = true
		out = append(out, id)
	}
	add(ff.SummonSpellID)
	if ff.Fighter != nil {
		for _, sp := range ff.Fighter.Spells {
			add(sp.SpellID)
		}
	}
	return out
}

// aiSpellAPCost mirrors castSpellByFighter's cost rule so the AI budgets its AP
// with the same number the handler will actually charge.
func aiSpellAPCost(sp *gamedata.Spell) int32 {
	if sp == nil {
		return defaultSpellAPCost
	}
	if sp.AP > 0 {
		return int32(sp.AP)
	}
	return defaultSpellAPCost
}

// aiSpellHarmsEnemy reports whether a spell is something the AI should aim AT AN
// OPPONENT — it takes HP, drains a resource, inflicts a state, or shoves the
// target around.
//
// This gate is not optional. The AI aims at the nearest opponent, and a
// fighter's loadout is arbitrary: a real coach's team becomes AI-driven the
// moment that coach drops mid-fight (coachLeftFightOnActor nils the session),
// and those fighters carry whatever spells the player equipped. Without this,
// the AI would happily cast a HEAL on the enemy it is trying to kill — only 3
// shipped spells carry an enforced ally-only target mask, so the targeting
// validator does not catch it.
//
// Deliberately a whitelist: an effect kind we do not model reads as "not known
// to harm", so a new or unsupported effect is never fired at an enemy on a
// guess.
func aiSpellHarmsEnemy(sp *gamedata.Spell) bool {
	if sp == nil {
		return false
	}
	for _, ef := range sp.Effects {
		if aiEffectHarms(ef) {
			return true
		}
	}
	return false
}

// aiEffectHarms is the per-effect half of aiSpellHarmsEnemy, so the friendly-fire
// check can ask the same question of ONE effect: it is the harmful effects whose
// area must not catch an ally, while a buff or heal riding along in the same
// spell is fine.
func aiEffectHarms(ef gamedata.Effect) bool {
	switch ef.Kind() {
	case gamedata.KindDamage, gamedata.KindLeech, gamedata.KindPercentHP,
		gamedata.KindPoison, gamedata.KindScaledAP, gamedata.KindScaledMP,
		gamedata.KindInstantDeath, gamedata.KindZoneDamage, gamedata.KindLineDamage,
		gamedata.KindAPLoss, gamedata.KindMPLoss, gamedata.KindAPSteal,
		gamedata.KindMPSteal, gamedata.KindZoneAPLoss, gamedata.KindZoneMPLoss,
		gamedata.KindState, gamedata.KindPush, gamedata.KindPull:
		return true
	}
	return false
}

// aiWouldHitOwnTeam reports whether casting sp at `center` would land a HARMFUL
// effect on one of the caster's own team, or on the caster itself.
//
// Friendly fire is real and authentic here — areaFighters applies an area effect
// to allies, enemies and the caster alike, and you are meant to position to spare
// your team. The AI had no idea: it now picks the HARDEST-HITTING affordable
// spell, and 15 of the damaging breed spells carry an area shape, several of them
// the strongest their breed has (the Cra's best is a size-3 T, and one Iop spell
// is shape 32767 = every living fighter). So without this the AI would routinely
// nuke its own team, and with a 32767 spell, itself.
//
// The policy is deliberately strict: any friendly splash disqualifies the spell,
// rather than trying to weigh ally damage against enemy damage. That is
// predictable and cheap to reason about; the cost is that the AI declines a cast
// that a human might judge worth it. Uses the caster's CURRENT position, which is
// where chooseAISpell is called from, so the directional shapes resolve exactly.
func (f *Fight) aiWouldHitOwnTeam(caster *FightFighter, from Pos, sp *gamedata.Spell, center Pos) bool {
	if caster == nil || sp == nil {
		return false
	}
	for _, ef := range sp.Effects {
		if !aiEffectHarms(ef) {
			continue
		}
		for _, v := range f.areaFightersFrom(caster, from, ef, center) {
			if v != nil && v.HP > 0 && v.TeamID == caster.TeamID {
				return true
			}
		}
	}
	return false
}

// aiSpellCastableFrom is THE predicate: could ff, standing at `from`, legally and
// sensibly cast sp at target right now?
//
// There must be exactly one of these. Positioning and casting used to ask
// different questions — moveIntoSpellRange only checked range/validity while
// chooseAISpell also checked cooldown, frequency and friendly fire — and a spell
// that passed the first but failed the second FROZE the fighter: it would not
// move, believing it could fire, and then would not cast. That is not
// hypothetical, it stalled a live 5v4 for eight rounds. The Cra's spell 3 reaches
// 5-8 cells, so at distance 8 it "could fire"; its best spell (18) was on its
// 1-turn cooldown, and nothing else was in range, so the fighter stood still with
// full AP and MP.
func (f *Fight) aiSpellCastableFrom(ff *FightFighter, from Pos, sp *gamedata.Spell, target *FightFighter) bool {
	if ff == nil || sp == nil || target == nil {
		return false
	}
	if !aiSpellHarmsEnemy(sp) {
		return false
	}
	if aiSpellAPCost(sp) > ff.AP {
		return false
	}
	if !ff.CastHistory.canCast(sp.LimitKeyID(), sp.Cooldown, sp.CastMaxPerTurn,
		sp.CastMaxPerTarget, f.tableTurn, target.WireID, true) {
		return false
	}
	if !f.spellTargetValidFrom(ff, from, sp, target.Pos) {
		return false
	}
	return !f.aiWouldHitOwnTeam(ff, from, sp, target.Pos)
}

// chooseAISpell picks the best spell to cast at `target` from where the fighter
// is standing right now, or 0 if nothing is castable. A candidate must harm an
// enemy, be affordable, be off cooldown, be within its frequency limits and pass
// the REAL targeting validator from the caster's cell — so a choice is never
// made that the cast handler would then reject, and never one that would help
// the target.
//
// Ranking is deliberately simple and deterministic: highest raw damage first,
// then cheaper, then lowest id. Damage is the spell record's own figure, not a
// simulation — the AI is meant to be competent, not optimal.
// chooseAITarget picks WHO to attack, the way a player would: finish something
// if you can, otherwise press the one closest to dying, otherwise hit whatever is
// nearest.
//
// Deliberately shallow. One pass over the living, visible opponents, and for each
// the best spell already-castable from where the fighter stands - no lookahead, no
// movement search, no simulating the enemy's turn. That keeps it O(enemies x
// spells) on sets that are both tiny, and it is also the depth a human actually
// plays at: nobody at the keyboard solves the turn optimally, they take the kill
// in front of them.
//
// Invisible enemies are already excluded upstream (nearestOpponent), and nothing
// here consults enemy traps or any other hidden state - see ai_knowledge.go.
func (f *Fight) chooseAITarget(ff *FightFighter) *FightFighter {
	nearest := f.nearestOpponent(ff)
	if ff == nil || nearest == nil || f.deps == nil || f.deps.Spells == nil {
		return nearest
	}

	var (
		bestKill   *FightFighter // reachable AND finishable this cast
		bestKillHP int32
		bestHurt   *FightFighter // reachable, lowest HP
		bestHurtHP int32
	)
	for _, fr := range f.allFighters() {
		if fr.HP <= 0 || !f.areOpponents(ff, fr) || fr.hasState(stateInvisible) {
			continue
		}
		_, dmg := f.bestSpellAgainst(ff, fr)
		if dmg <= 0 {
			continue // cannot actually hit it from here
		}
		if dmg >= fr.HP && (bestKill == nil || fr.HP < bestKillHP) {
			bestKill, bestKillHP = fr, fr.HP
		}
		if bestHurt == nil || fr.HP < bestHurtHP {
			bestHurt, bestHurtHP = fr, fr.HP
		}
	}
	switch {
	case bestKill != nil:
		return bestKill
	case bestHurt != nil:
		return bestHurt
	default:
		// Nothing is castable from here; fall back to nearest so the movement
		// logic still has something to walk towards.
		return nearest
	}
}

// bestSpellAgainst returns the highest-damage spell `ff` can cast at `target`
// from where it stands, and that damage. (0, 0) when nothing is castable.
func (f *Fight) bestSpellAgainst(ff, target *FightFighter) (int32, int32) {
	if ff == nil || target == nil || f.deps == nil || f.deps.Spells == nil {
		return 0, 0
	}
	var bestID, bestDmg, bestCost int32
	for _, id := range f.aiRepertoire(ff) {
		sp := f.deps.Spells.Get(id)
		if sp == nil || !f.aiSpellCastableFrom(ff, ff.Pos, sp, target) {
			continue
		}
		cost := aiSpellAPCost(sp)
		dmg := f.aiEstimatedDamage(ff, target, sp)
		if better := f.aiSpellBetter(target, dmg, cost, id, bestDmg, bestCost, bestID); better {
			bestID, bestDmg, bestCost = id, dmg, cost
		}
	}
	return bestID, bestDmg
}

// aiSpellBetter ranks two candidate casts against the same target.
//
// Two rules, in order, both of them how a person actually decides:
//
//  1. If a spell FINISHES the target, take it. A kill removes an attacker from
//     the fight; nothing measured in raw damage competes with that, and spending
//     leftover AP on a corpse is the classic bot mistake.
//  2. Otherwise prefer damage per AP, not raw damage. With 6 AP, a 2-AP spell
//     for 30 beats a 4-AP spell for 40: three casts is 90, and greedy-by-damage
//     scores 70. Raw damage only wins ties.
//
// Deterministic throughout - equal on every measure falls back to the lower id -
// so a fight replays identically.
func (f *Fight) aiSpellBetter(target *FightFighter, dmg, cost, id, bestDmg, bestCost, bestID int32) bool {
	if bestID == 0 {
		return true
	}
	kills := target != nil && dmg >= target.HP
	bestKills := target != nil && bestDmg >= target.HP
	if kills != bestKills {
		return kills // a finisher beats anything that is not one
	}
	if kills && bestKills {
		// Both finish it: take the cheaper, so the leftover AP buys something else.
		if cost != bestCost {
			return cost < bestCost
		}
		return id < bestID
	}
	// Neither finishes it: efficiency decides. Compared as a cross-product to
	// stay in integers (dmg/cost > bestDmg/bestCost).
	if cost > 0 && bestCost > 0 {
		l, r := dmg*bestCost, bestDmg*cost
		if l != r {
			return l > r
		}
	}
	if dmg != bestDmg {
		return dmg > bestDmg
	}
	if cost != bestCost {
		return cost < bestCost
	}
	return id < bestID
}

// aiEstimatedDamage is what the AI expects `sp` to take off `target`, through the
// SAME elemental damage/resistance maths the real cast uses.
//
// Using the resolved figure rather than the spell's printed base is what makes
// "can I finish this one" mean anything: against different resistances the same
// spell lands for different amounts, and a player reading the enemy's stats
// (which the client displays) accounts for that. It also stops the AI throwing a
// fire spell into fire resistance when a weaker earth one would do more.
//
// This is an ESTIMATE: it deliberately ignores crits, shields applied mid-turn
// and rebound, because a human cannot predict those either.
func (f *Fight) aiEstimatedDamage(ff, target *FightFighter, sp *gamedata.Spell) int32 {
	base, _, ok := sp.Damage()
	if !ok || base <= 0 {
		return 0
	}
	_, actionID, _, hasPrimary := sp.PrimaryDamage()
	if !hasPrimary {
		return base
	}
	return f.computeElementalDamage(ff, target, base, damageElement(actionID))
}

func (f *Fight) chooseAISpell(ff *FightFighter, target *FightFighter) int32 {
	if ff == nil || target == nil || f.deps == nil || f.deps.Spells == nil {
		return 0
	}
	// Delegates to bestSpellAgainst so there is exactly ONE ranking. There used to
	// be two copies of it here, and the moment they disagreed the AI chose by one
	// rule and valued the target by the other - the AP-efficiency work landed in
	// the copy that picks TARGETS while the copy that picks the CAST kept spending
	// greedily. A test measuring damage-per-turn caught it; reading the code did
	// not, twice.
	id, _ := f.bestSpellAgainst(ff, target)
	return id
}

// castAISpellRepeatedly spends the fighter's AP on the best spell available each
// time, re-picking both the target and the spell after every cast so it reacts
// to a kill, a move or a spell going on cooldown mid-turn.
func (f *Fight) castAISpellRepeatedly(ff *FightFighter) {
	if f.deps == nil || f.deps.Spells == nil {
		return
	}
	// Support first: a teammate about to die is worth more than another hit.
	// Bounded by AP like everything else, and it only fires when an ally is
	// genuinely hurt (see aiHealThresholdPct), so a healthy team costs nothing.
	for ff.AP > 0 && f.isCurrentTurn(ff.WireID) && ff.HP > 0 {
		if !f.aiSupportCast(ff) {
			break
		}
	}
	maxCasts := int(ff.MaxAP) + 1 // hard safety cap; every cast must spend AP
	for i := 0; i < maxCasts; i++ {
		if ff.HP <= 0 || !f.isCurrentTurn(ff.WireID) || ff.AP <= 0 {
			return
		}
		target := f.chooseAITarget(ff)
		if target == nil {
			return
		}
		spellID := f.chooseAISpell(ff, target)
		if spellID == 0 {
			return // nothing castable from here
		}
		if !f.castSpellByFighter(ff, spellID, target.Pos) {
			return // refused for a reason we did not model: stop rather than spin
		}
	}
}

// aiCanFireFrom reports whether ff, standing at `from`, could cast ANY affordable
// spell in its repertoire at `target`. Uses the real validator, so it accounts
// for the Range-stat extension, only-line, free-cell, line-of-sight and target
// masks rather than a bare distance window.
func (f *Fight) aiCanFireFrom(ff *FightFighter, from Pos, target *FightFighter) bool {
	if f.deps == nil || f.deps.Spells == nil {
		return false
	}
	for _, id := range f.aiRepertoire(ff) {
		sp := f.deps.Spells.Get(id)
		if sp != nil && f.aiSpellCastableFrom(ff, from, sp, target) {
			return true
		}
	}
	return false
}

// aiFiringGap is how far `from` is outside the range window of the repertoire
// spell it comes CLOSEST to being able to fire — a "how much closer do I need to
// get" proxy used to pick a direction when nothing is castable yet.
func (f *Fight) aiFiringGap(ff *FightFighter, from Pos, target *FightFighter) int32 {
	best := int32(-1)
	if f.deps == nil || f.deps.Spells == nil {
		return best
	}
	for _, id := range f.aiRepertoire(ff) {
		sp := f.deps.Spells.Get(id)
		if sp == nil || !aiSpellHarmsEnemy(sp) || aiSpellAPCost(sp) > ff.AP {
			continue
		}
		// Skip one it could not cast even standing in the perfect spot, so it does
		// not walk toward a spell that is on cooldown or out of casts.
		if !ff.CastHistory.canCast(sp.LimitKeyID(), sp.Cooldown, sp.CastMaxPerTurn,
			sp.CastMaxPerTarget, f.tableTurn, target.WireID, true) {
			continue
		}
		g := firingGap(from, target.Pos, int32(sp.RangeMin), spellEffectiveMaxRange(ff, sp))
		if best < 0 || g < best {
			best = g
		}
	}
	return best
}

// moveIntoSpellRange walks the fighter (MP-limited) to the nearest reachable cell
// from which it can hit `target` with SOMETHING in its repertoire. No-op if it
// can already fire or cannot improve.
func (f *Fight) moveIntoSpellRange(ff, target *FightFighter) {
	if f.deps == nil || f.deps.Spells == nil {
		f.moveTowardNearestOpponent(ff)
		return
	}
	if len(f.aiRepertoire(ff)) == 0 {
		f.moveTowardNearestOpponent(ff)
		return
	}
	if f.aiCanFireFrom(ff, ff.Pos, target) {
		return // already able to fire
	}
	if ff.MP <= 0 || ff.hasState(stateRooted) {
		return
	}
	var bestPath []Pos
	bestCanFire := false
	bestScore := f.aiFiringGap(ff, ff.Pos, target)
	bestLen := 0
	bestRisk := f.aiCellRisk(ff, ff.Pos)
	for _, path := range f.orderedReachablePaths(ff, ff.MP) {
		cell := path[len(path)-1]
		canFire := f.aiCanFireFrom(ff, cell, target)
		score := f.aiFiringGap(ff, cell, target)
		risk := f.aiCellRisk(ff, cell)
		better := (canFire && !bestCanFire) ||
			(canFire == bestCanFire && score >= 0 && (bestScore < 0 || score < bestScore)) ||
			// Same firing quality: take the SAFER cell. A player who can shoot from
			// two places picks the one that is not surrounded, and this is where
			// a known friendly trap costs the cell without ever blocking a move.
			(canFire == bestCanFire && score == bestScore && risk < bestRisk) ||
			(canFire == bestCanFire && score == bestScore && risk == bestRisk &&
				bestPath != nil && len(path) < bestLen)
		if better {
			bestPath, bestCanFire, bestScore, bestLen, bestRisk = path, canFire, score, len(path), risk
		}
	}
	if len(bestPath) > 0 {
		f.applyFighterMove(ff, bestPath)
	}
}

// moveTowardNearestOpponent walks the fighter toward the cell nearest the closest
// living opponent (blocker / self-buff behaviour). No-op if already adjacent, out
// of MP, or unable to improve.
func (f *Fight) moveTowardNearestOpponent(ff *FightFighter) {
	if ff.MP <= 0 || ff.hasState(stateRooted) {
		return
	}
	target := f.nearestOpponent(ff)
	if target == nil || manhattanDist(ff.Pos, target.Pos) <= 1 {
		return
	}
	bestDist := manhattanDist(ff.Pos, target.Pos)
	var bestPath []Pos
	bestLen := 0
	for _, path := range f.orderedReachablePaths(ff, ff.MP) {
		cell := path[len(path)-1]
		d := manhattanDist(cell, target.Pos)
		if d < bestDist || (d == bestDist && bestPath != nil && len(path) < bestLen) {
			bestPath, bestDist, bestLen = path, d, len(path)
		}
	}
	if len(bestPath) > 0 {
		f.applyFighterMove(ff, bestPath)
	}
}

// retreatFromOpponents walks the fighter to the reachable cell that maximises its
// minimum distance to any living enemy (used after a kite cast). Only moves if it
// strictly improves safety.
func (f *Fight) retreatFromOpponents(ff *FightFighter) {
	if ff.MP <= 0 || ff.hasState(stateRooted) {
		return
	}
	currentSafety := f.minEnemyDistance(ff, ff.Pos)
	if currentSafety < 0 {
		return // no enemies
	}
	bestSafety := currentSafety
	var bestPath []Pos
	bestLen := 0
	for _, path := range f.orderedReachablePaths(ff, ff.MP) {
		cell := path[len(path)-1]
		safety := f.minEnemyDistance(ff, cell)
		if safety > bestSafety || (safety == bestSafety && bestPath != nil && len(path) < bestLen) {
			bestPath, bestSafety, bestLen = path, safety, len(path)
		}
	}
	if len(bestPath) > 0 {
		f.applyFighterMove(ff, bestPath)
	}
}

// aiCellIsSuicide reports whether ENDING a move on this cell would kill the
// fighter outright. Today that is the Killer tile (template 1002): whoever starts
// its turn there dies with no save and no resistance
// (applyTurnStartSpecialCell).
//
// Watched live: a Xelor walked onto one mid-approach and was dead at the start of
// its next turn. Nothing in the movement scoring knew the cell existed — it only
// measured distance — so the AI would keep doing it.
//
// Only the DESTINATION matters: a Killer tile fires at turn start, so passing
// over one is harmless. The Trap tile (1003) is deliberately not included: it
// costs 10 HP, which is a cost to weigh rather than a certain death, and refusing
// to path near it would distort movement far more than the damage is worth.
func (f *Fight) aiCellIsSuicide(p Pos) bool {
	return f.aiCellIsSuicideFor(nil, p)
}

// aiCellIsSuicideFor is the knowledge-aware form: `ff` may only take account of
// hazards it is ALLOWED to see (see ai_knowledge.go). Passing a nil fighter means
// "map features only", which is what the old signature did.
//
// Enemy traps deliberately do not count. An AI that steps around a trap nobody
// told it about is the most visible way for a bot to look like it is cheating,
// and it is a one-line mistake to make.
func (f *Fight) aiCellIsSuicideFor(ff *FightFighter, p Pos) bool {
	if ff == nil {
		sc, _, ok := f.Arena().specialAt(p.X, p.Y)
		if !ok {
			return false
		}
		return specialCellByTemplate[sc.Template] == specialCellKiller
	}
	lethal, _ := f.aiKnownHazardAt(ff, p)
	return lethal
}

// orderedReachablePaths returns every reachable-cell path (from reachableCells)
// in a deterministic order (shorter routes first, then by destination coords),
// so the AI's "first strictly-better wins" tie-breaks are stable across the map's
// random Go iteration order.
func (f *Fight) orderedReachablePaths(ff *FightFighter, mp int32) [][]Pos {
	reachable := f.reachableCells(ff, ff.Pos, mp)
	paths := make([][]Pos, 0, len(reachable))
	for _, p := range reachable {
		// Knowledge-aware: f may only avoid hazards it is allowed to see, so
		// this filters arena killer tiles for everyone and the fighter's OWN
		// team's lethal areas for it alone. Enemy traps are invisible here by
		// design (ai_knowledge.go).
		if len(p) > 0 && !f.aiCellIsSuicideFor(ff, p[len(p)-1]) {
			paths = append(paths, p)
		}
	}
	sort.Slice(paths, func(i, j int) bool {
		a, b := paths[i], paths[j]
		if len(a) != len(b) {
			return len(a) < len(b)
		}
		la, lb := a[len(a)-1], b[len(b)-1]
		if la.X != lb.X {
			return la.X < lb.X
		}
		return la.Y < lb.Y
	})
	return paths
}

// firingGap is how many cells `from` is outside the spell's [rMin,rMax] range
// window to `to` (0 if in range) — a proxy for "how much closer to get".
func firingGap(from, to Pos, rMin, rMax int32) int32 {
	d := manhattanDist(from, to)
	switch {
	case d > rMax:
		return d - rMax
	case d < rMin:
		return rMin - d
	default:
		return 0
	}
}

// nearestOpponent returns the living opponent the fighter should engage: smallest
// Manhattan distance, tie-broken by highest initiative, then a real fighter over
// an enemy summon (the wiki's "Summon Intelligence" rules).
func (f *Fight) nearestOpponent(self *FightFighter) *FightFighter {
	var best *FightFighter
	var bestDist int32
	for _, fr := range f.allFighters() {
		if fr.HP <= 0 || !f.areOpponents(self, fr) || fr.hasState(stateInvisible) {
			continue // an invisible enemy is unseen by the AI
		}
		d := manhattanDist(self.Pos, fr.Pos)
		if best == nil || d < bestDist || (d == bestDist && aiTargetPreferred(fr, best)) {
			best, bestDist = fr, d
		}
	}
	return best
}

// aiTargetPreferred reports whether cand is a better target than best at equal
// distance: higher initiative first, then a non-summon over a summon.
func aiTargetPreferred(cand, best *FightFighter) bool {
	if cand.Init != best.Init {
		return cand.Init > best.Init
	}
	return !cand.isSummon() && best.isSummon()
}

// minEnemyDistance returns the Manhattan distance from `at` to the nearest living
// enemy of `self`, or -1 if there are none.
func (f *Fight) minEnemyDistance(self *FightFighter, at Pos) int32 {
	best := int32(-1)
	for _, fr := range f.allFighters() {
		if fr.HP <= 0 || !f.areOpponents(self, fr) || fr.hasState(stateInvisible) {
			continue
		}
		d := manhattanDist(at, fr.Pos)
		if best < 0 || d < best {
			best = d
		}
	}
	return best
}

// areOpponents reports whether a and b are on opposing teams.
func (f *Fight) areOpponents(a, b *FightFighter) bool {
	return a != nil && b != nil && a.TeamID != b.TeamID
}
