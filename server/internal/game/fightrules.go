package game

// fightrules.go — the per-fight RULESET.
//
// A challenge (and, once decoded, a tournament) can customise the match through
// its `np_1` parameter list: turn duration, when sudden death starts, the budget,
// roster limits, the arena, bonus-cell strength (see docs/DATA-COVERAGE.md §5b
// for the full type table).
//
// Two of those were package-level constants in this server until now, which was
// wrong twice over: the values were invented rather than read from the data, AND
// being package-level meant a rule set by one fight would leak into every other
// fight in the process. Rules are per-Fight here for that reason.

import (
	"time"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// fightRules is the resolved ruleset for one fight.
type fightRules struct {
	// TurnClock is how long a human fighter's turn lasts (np_1 type 10).
	TurnClock time.Duration
	// SuddenDeathTurn is the table turn on which the arena starts to shrink
	// (np_1 type 11).
	SuddenDeathTurn int32
	// BonusCellMultiplier scales bonus-cell effects (np_1 type 13). 1 = normal.
	BonusCellMultiplier int32
	// StartEffects are applied to every fighter once, when the fight starts
	// (np_1 type 12). Challenges 29/30/31 each carry one.
	StartEffects []gamedata.Effect
	// Victory are the alternative win conditions (np_1 type 14). Nine shipped
	// challenges carry one; see victory.go for which subtypes are evaluated.
	Victory []gamedata.VictoryCondition
}

// defaultFightRules is the ruleset a fight gets with no parameters of its own.
// It reads the package defaults, so the existing test hooks (SetTurnClockForTest,
// and the sudden-death default) keep working unchanged.
func defaultFightRules() fightRules {
	return fightRules{
		TurnClock:           turnClock,
		SuddenDeathTurn:     suddenDeathTurn,
		BonusCellMultiplier: 1,
	}
}

// rulesFromParameters overlays an `np_1` list onto the defaults. Unknown or
// absent types simply leave the default in place — the client does the same
// (`np_1.co` falls back to a generic holder rather than failing), so a rule this
// server does not implement is inert rather than fatal.
//
// THE TIMING RULES ARE DELTAS, NOT ABSOLUTES. The client's own label table says
// so unambiguously:
//
//	content.54.10 = "[£1] secondes en {[+1]?plus:moins} pour jouer chaque combattant"
//	content.54.11 = "La mort subite a lieu [£1] tours plus {[+1]?tard:tôt}"
//
// i.e. "N seconds MORE/LESS per fighter" and "sudden death happens N turns
// LATER/EARLIER". The `{[+1]?…:…}` construct picks the wording from the sign,
// which only makes sense for a signed offset — and the sudden-death comment in
// suddendeath.go had already recorded that tournament cards "shift it by ±5/±10
// turns". Reading either as an absolute value silently produces a completely
// different fight.
func rulesFromParameters(ps []gamedata.Parameter) fightRules {
	r := defaultFightRules()
	if deltaMS, ok := gamedata.FirstParam(ps, gamedata.ParamTypeTurnDurationMS); ok && deltaMS != 0 {
		next := r.TurnClock + time.Duration(deltaMS)*time.Millisecond
		if next > 0 { // a negative delta must never zero the clock
			r.TurnClock = next
		}
	}
	if deltaTurns, ok := gamedata.FirstParam(ps, gamedata.ParamTypeSuddenDeathTurn); ok && deltaTurns != 0 {
		if next := r.SuddenDeathTurn + deltaTurns; next > 0 {
			r.SuddenDeathTurn = next
		}
	}
	// The multiplier IS absolute — "Effets des cases bonus multipliés par [#1]".
	if m, ok := gamedata.FirstParam(ps, gamedata.ParamTypeBonusCellMult); ok && m > 0 {
		r.BonusCellMultiplier = m
	}
	r.StartEffects = gamedata.FightStartEffects(ps)
	r.Victory = gamedata.VictoryConditions(ps)
	return r
}

// noClockTurn is the turn clock from which a fight counts as having none: a
// rule that adds an hour or more (Nilo's practice, challenge 46: +3 600 000
// ms) means "take your time", not a longer turn.
const noClockTurn = 10 * time.Minute

// placementClockFor is the placement window: the usual placementClock, or —
// in a fight with no turn clock — as long as a turn (S52). The guided practice
// talks the player through placing; a 30-second window placed them while they
// read, and npc.283 promises that practice has no clock.
func (f *Fight) placementClockFor() time.Duration {
	if f != nil && f.Rules.TurnClock >= noClockTurn {
		return f.Rules.TurnClock
	}
	return placementClock
}

// rulesForChallenge resolves the ruleset a challenge fight runs under.
func (d *Deps) rulesForChallenge(challengeID int32) fightRules {
	if challengeID == 0 || d.ChallengeDefs == nil {
		return defaultFightRules()
	}
	ch := d.ChallengeDefs.Get(challengeID)
	if ch == nil {
		return defaultFightRules()
	}
	return rulesFromParameters(ch.Bonuses)
}

// wireKind is the fight kind the client reads back as aKl() from CREATE_FIGHT's
// first i32. Everything the client decides about the shape of a fight — which
// result dialog to open, whether to read a coach's evolution level instead of
// its strength, whether to look up challenge metadata — hangs off this one
// value, so it is derived in exactly one place.
//
// Evolution wins over challenge when a fight is somehow both: the lethal
// debrief is the more important of the two panels, and the challenge id is
// suppressed alongside it so the client cannot open both.
func (f *Fight) wireKind() int32 {
	switch {
	case f == nil:
		return fightKindNormal
	case f.Evolution:
		return fightKindEvolution
	case f.ChallengeID != 0:
		return fightKindChallenge
	default:
		return fightKindNormal
	}
}

// turnClockFor returns the clock to arm for a fighter's turn.
func (f *Fight) turnClockFor() time.Duration {
	if f == nil || f.Rules.TurnClock <= 0 {
		return turnClock
	}
	return f.Rules.TurnClock
}

// suddenDeathTurnFor returns the table turn this fight starts shrinking on.
func (f *Fight) suddenDeathTurnFor() int32 {
	if f == nil || f.Rules.SuddenDeathTurn <= 0 {
		return suddenDeathTurn
	}
	return f.Rules.SuddenDeathTurn
}
