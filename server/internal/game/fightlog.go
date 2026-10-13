package game

import "fmt"

// fightlog.go records WHAT each fighter did on its turn.
//
// A seeded fight (fightseed.go) is reproducible, but reproducing it tells you
// nothing about WHY it went the way it did: the dice are only half the story,
// the other half is the decision each fighter made with them. The decision log
// is that half — one row per action, carrying the round, whose turn it was, the
// fighter, and the action taken.
//
// It is deliberately server-internal and deliberately cheap: an append onto a
// capped slice plus the Debug line the fight already emits through
// f.logfDebug, so it costs nothing a fight was not already paying and adds no
// logging dependency. Nothing about it reaches the wire.
//
// The hook sits at the ACTION choke points (cast, move, close combat, card
// use, pass), not inside the AI, so it records a human coach's turn exactly as
// it records a server-driven one — which is the point for moderation: an
// unattended fight and a played one leave the same shape of trail.

// fightDecisionKind names what a fighter did.
type fightDecisionKind string

const (
	// decisionBehavior is WHICH PLAN the fighter is playing: the gambit rule that
	// fired (gambit_eval.go) when it has an authored rule list, otherwise the
	// AI's archetype choice. One slot for both, so the action rows below are
	// unchanged either way and a replay reads a rule-driven turn exactly like an
	// archetype-driven one.
	decisionBehavior    fightDecisionKind = "behavior"
	decisionCast        fightDecisionKind = "cast"
	decisionMove        fightDecisionKind = "move"
	decisionCloseCombat fightDecisionKind = "closecombat"
	decisionCard        fightDecisionKind = "card"
	// decisionPass is recorded when a turn ends having taken no action at all —
	// a human who passed, a petrified fighter, a disconnected coach's auto-pass.
	decisionPass fightDecisionKind = "pass"
)

// fightDecision is one row of the log: (round, turn, fighter, action).
type fightDecision struct {
	// Round is the table turn (1-indexed), Turn the timeline index whose turn it
	// was. Together they identify the turn unambiguously across a whole fight.
	Round int32
	Turn  int
	// WireID identifies the acting fighter; Name is its display name when it has
	// one (a summon has none) and AI records whether a client was driving it.
	WireID int64
	Name   string
	AI     bool
	Kind   fightDecisionKind
	// Detail is the action's parameters, pre-rendered (spell id, destination,
	// crit/fumble). A string keeps the row flat for a log line and a future
	// replay dump without a kind-tagged union per action.
	Detail string
}

// String renders one row for a log line / replay dump.
func (d fightDecision) String() string {
	return fmt.Sprintf("r%d t%d wire=%d %s %s", d.Round, d.Turn, d.WireID, d.Kind, d.Detail)
}

// maxFightDecisions caps the log. A fight is bounded by sudden death, so this is
// generous rather than load-bearing; it exists so a pathological fight (or a
// loop a future change introduces) cannot grow the slice without limit. Once
// full the log stops growing: the EARLY turns are the ones worth keeping, since
// a fight replays forwards from its seed.
const maxFightDecisions = 4096

// logDecision appends one (round, turn, fighter, action) row and mirrors it to
// the fight's Debug log. Called from inside the fight actor, like every other
// turn-progression path, so it needs no locking.
func (f *Fight) logDecision(ff *FightFighter, kind fightDecisionKind, detail string) {
	if f == nil || ff == nil {
		return
	}
	d := fightDecision{
		Round:  f.tableTurn,
		Turn:   f.turnIndex,
		WireID: ff.WireID,
		AI:     f.isAIControlled(ff),
		Kind:   kind,
		Detail: detail,
	}
	if ff.Fighter != nil {
		d.Name = ff.Fighter.Name
	}
	if len(f.decisions) < maxFightDecisions {
		f.decisions = append(f.decisions, d)
	}
	f.logfDebug("fight decision", "fight", f.ID, "round", d.Round, "turn", d.Turn,
		"wire", d.WireID, "name", d.Name, "ai", d.AI, "action", string(kind), "detail", detail)
}

// logAction records an action row and counts it against the current turn, so a
// turn that ends having recorded none is logged as a pass (see endTurn).
func (f *Fight) logAction(ff *FightFighter, kind fightDecisionKind, detail string) {
	if f == nil {
		return
	}
	f.turnActions++
	f.logDecision(ff, kind, detail)
}

// decisionLog returns a copy of the fight's decision log. Read it from the
// fight actor (or after the fight has stopped) like any other actor-owned state.
func (f *Fight) decisionLog() []fightDecision {
	if f == nil || len(f.decisions) == 0 {
		return nil
	}
	out := make([]fightDecision, len(f.decisions))
	copy(out, f.decisions)
	return out
}
