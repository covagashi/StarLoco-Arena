package game

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
)

// gambit.go is the VOCABULARY and the SCHEMA of the gambit rule engine: the
// closed list of conditions and actions a ruleset may contain, and the parser
// that refuses anything else. Evaluation lives in gambit_eval.go.
//
// A gambit is one ordered list of `IF condition THEN action` rules belonging to
// a fighter, evaluated top-down on its turn: the first rule that both holds and
// can act wins (FFXII's system, and the design in godot/ASYNC-PVP.md). It is
// what makes an async ghost fight real PvP rather than a bot match — the
// opponent's owner authored the list, so the strategy is theirs.
//
// Rules sit ON TOP of the archetype AI in ai.go, never instead of it. A fighter
// with no ruleset, or whose every rule declines this turn, plays exactly the
// archetype turn it played before this file existed. That is the whole reason
// the vocabulary can afford to be small.
//
// The vocabulary is CLOSED and VERSIONED on purpose. Two earlier bounded
// evaluators in this repo (the .xps FX subset, the spell criterion
// mini-evaluator) stayed bounded and were the better for it; a general
// expression language here would mean a server that must evaluate whatever a
// client sends, forever, with no way to say no. Instead: these seven
// conditions, these five actions, a version field — and anything outside them
// is rejected at parse time and falls back to the archetype AI, which is a
// competent player in its own right.
//
// Nothing here touches the wire. Phase 3 owns the opcodes that carry a ruleset
// and the storage that keeps one; this file only says what a valid ruleset is.

// gambitSchemaVersion is the version of the rule vocabulary this server speaks.
//
// It is MANDATORY in the JSON and must match exactly: a ruleset authored
// against a newer vocabulary is rejected whole rather than half-understood,
// because a rule list silently missing its first (highest-priority) rule plays
// a strategy its author never wrote. Bump it only when the vocabulary changes,
// and keep the old number working or refusing — never reinterpret it.
const gambitSchemaVersion = 1

// maxGambitRules bounds one fighter's rule list. The authoring UI is an ordered
// list a human maintains, so a few dozen is already past usable; the bound
// exists so the eventual 60012 frame cannot hand the engine a list it walks
// every turn of every fight.
const maxGambitRules = 32

// Condition kinds — the complete v1 set from the design doc. Every one is a
// single comparison against fight state that the client can also compute, which
// is what keeps the authoring UI honest about what a rule will do.
type gambitConditionKind string

const (
	// gambitAlways is the unconditional rule, used as the last line of a list
	// ("...otherwise just attack"). It takes no value.
	gambitAlways gambitConditionKind = "always"
	// gambitSelfHPBelow fires when the fighter's own HP is strictly below `value`
	// percent of its maximum.
	gambitSelfHPBelow gambitConditionKind = "self_hp_pct_below"
	// gambitEnemyHPBelow fires when ANY living, visible opponent is below `value`
	// percent ("someone is finishable").
	gambitEnemyHPBelow gambitConditionKind = "enemy_hp_pct_below"
	// gambitAllyHPBelow fires when any living teammate OTHER than the fighter
	// itself is below `value` percent (self has its own condition).
	gambitAllyHPBelow gambitConditionKind = "ally_hp_pct_below"
	// gambitNearestEnemyDistLE fires when the closest living, visible opponent is
	// within `value` cells (Manhattan, the distance the whole fight model uses).
	gambitNearestEnemyDistLE gambitConditionKind = "nearest_enemy_distance_le"
	// gambitTurnGE fires from round `value` onward (the 1-indexed table turn), for
	// opening/late-game plans.
	gambitTurnGE gambitConditionKind = "turn_ge"
	// gambitAllyCountLE fires when at most `value` living teammates remain beside
	// the fighter itself — 0 meaning "I am the last one standing".
	gambitAllyCountLE gambitConditionKind = "ally_count_le"
)

// Action kinds — the complete v1 set. Each maps onto something the fight model
// already does for a human coach, so a rule can never ask for a move the
// handlers would not allow.
type gambitActionKind string

const (
	// gambitCast casts `spell` at `target`. The only action carrying parameters.
	gambitCast gambitActionKind = "cast"
	// gambitMoveToward walks toward the nearest opponent (the blocker archetype's
	// approach, MP-limited, hazard-aware).
	gambitMoveToward gambitActionKind = "move_toward"
	// gambitMoveAway retreats to the reachable cell furthest from every opponent
	// (the kite archetype's disengage).
	gambitMoveAway gambitActionKind = "move_away"
	// gambitCloseCombat makes one weapon attack on an adjacent opponent.
	gambitCloseCombat gambitActionKind = "close_combat"
	// gambitPass deliberately ends the turn, doing nothing further. It is the one
	// action that stops evaluation outright.
	gambitPass gambitActionKind = "pass"
)

// Target specs for a `cast` action — the closed v1 set.
//
// The doc fixes the condition and action vocabularies and leaves `cast (+ a
// target spec)` to be pinned down here. These four are the targets the
// CONDITIONS already talk about (self, enemies, allies) and nothing more: the
// point of a closed target list is that the server never has to resolve a
// targeting expression it has not seen before.
type gambitTarget string

const (
	// gambitTargetSelf aims at the fighter's own cell (self-buffs, self-heals).
	gambitTargetSelf gambitTarget = "self"
	// gambitTargetNearestEnemy aims at the closest living, visible opponent, with
	// the same tie-break the AI's own target selection uses.
	gambitTargetNearestEnemy gambitTarget = "nearest_enemy"
	// gambitTargetWeakestEnemy aims at the living, visible opponent with the
	// lowest HP (the finisher).
	gambitTargetWeakestEnemy gambitTarget = "weakest_enemy"
	// gambitTargetWeakestAlly aims at the most hurt living teammate other than
	// the fighter itself (the heal). Self is deliberately excluded — that is what
	// gambitTargetSelf is for — so a solo fighter's "heal the weakest ally" rule
	// simply never fires instead of quietly meaning something else.
	gambitTargetWeakestAlly gambitTarget = "weakest_ally"
)

// gambitRuleSet is one fighter's ordered rule list plus the schema version it
// was authored against.
type gambitRuleSet struct {
	Version int          `json:"version"`
	Rules   []gambitRule `json:"rules"`
}

// gambitRule is one `IF condition THEN action` line. The JSON field names are
// the design doc's verbatim:
//
//	{ "if": {"kind": "enemy_hp_pct_below", "value": 40},
//	  "do": {"kind": "cast", "spell": 51, "target": "weakest_enemy"} }
type gambitRule struct {
	If gambitCondition `json:"if"`
	Do gambitAction    `json:"do"`
}

// gambitCondition is a kind plus its single integer operand (a percentage, a
// distance, a round number or a count, depending on the kind).
type gambitCondition struct {
	Kind  gambitConditionKind `json:"kind"`
	Value int32               `json:"value,omitempty"`
}

// gambitAction is a kind plus the parameters only `cast` carries.
type gambitAction struct {
	Kind   gambitActionKind `json:"kind"`
	Spell  int32            `json:"spell,omitempty"`
	Target gambitTarget     `json:"target,omitempty"`
}

// String renders a condition for the fight decision log (fightlog.go).
func (c gambitCondition) String() string {
	if c.Kind == gambitAlways {
		return string(c.Kind)
	}
	return fmt.Sprintf("%s:%d", c.Kind, c.Value)
}

// String renders an action for the fight decision log.
func (a gambitAction) String() string {
	if a.Kind == gambitCast {
		return fmt.Sprintf("%s:%d@%s", a.Kind, a.Spell, a.Target)
	}
	return string(a.Kind)
}

// String renders a whole rule for the fight decision log, so a replay can read
// which rule drove a turn without holding the ruleset beside it.
func (r gambitRule) String() string {
	return fmt.Sprintf("if=%s do=%s", r.If, r.Do)
}

// errGambitNoRules is returned for a ruleset with nothing in it. An empty list
// is not an error state at runtime (a fighter without rules plays the
// archetype), but it IS a malformed document: whoever sent it meant to send
// rules.
var errGambitNoRules = errors.New("gambit ruleset: no rules")

// parseGambitRules decodes and validates a gambit ruleset, returning an error
// rather than a partially-understood list.
//
// It is strict in three ways that each close a way for a ruleset to mean
// something other than what it says:
//
//   - unknown JSON fields are REJECTED, so a misspelled key ("spel": 51) fails
//     loudly instead of decoding as a cast of spell 0;
//   - trailing content after the document is rejected, so a truncated or
//     concatenated payload is not half-read;
//   - the schema version must match exactly (see gambitSchemaVersion).
//
// A rejected ruleset is simply never attached to a fighter, which leaves the
// archetype AI in charge — the documented fallback for anything the vocabulary
// cannot express.
func parseGambitRules(data []byte) (*gambitRuleSet, error) {
	dec := json.NewDecoder(bytes.NewReader(data))
	dec.DisallowUnknownFields()
	var rs gambitRuleSet
	if err := dec.Decode(&rs); err != nil {
		return nil, fmt.Errorf("gambit ruleset: %w", err)
	}
	if dec.More() {
		return nil, errors.New("gambit ruleset: trailing content after the rule list")
	}
	if err := rs.validate(); err != nil {
		return nil, err
	}
	return &rs, nil
}

// validate checks a ruleset against the closed vocabulary. Every rule must be
// understood for the set to be accepted: see gambitSchemaVersion for why a
// partially-understood list is worse than no list.
func (rs *gambitRuleSet) validate() error {
	if rs == nil {
		return errGambitNoRules
	}
	if rs.Version != gambitSchemaVersion {
		return fmt.Errorf("gambit ruleset: schema version %d not understood (this server speaks v%d)",
			rs.Version, gambitSchemaVersion)
	}
	if len(rs.Rules) == 0 {
		return errGambitNoRules
	}
	if len(rs.Rules) > maxGambitRules {
		return fmt.Errorf("gambit ruleset: %d rules, at most %d allowed", len(rs.Rules), maxGambitRules)
	}
	for i := range rs.Rules {
		if err := rs.Rules[i].validate(); err != nil {
			// 1-indexed: the authoring UI numbers the list the way a person reads it.
			return fmt.Errorf("gambit rule %d: %w", i+1, err)
		}
	}
	return nil
}

// validate checks one rule's condition and action.
func (r gambitRule) validate() error {
	if err := r.If.validate(); err != nil {
		return err
	}
	return r.Do.validate()
}

// validate checks a condition's kind and the range of its operand.
//
// The bounds are per-kind and deliberately reject values that could never be
// true (an HP percentage of 0) or that are nonsense for the quantity (a round
// number of -1). A rule that can never fire is an authoring mistake, and the
// author is better served by an error than by a line of their strategy quietly
// doing nothing for the rest of the season.
func (c gambitCondition) validate() error {
	switch c.Kind {
	case gambitAlways:
		if c.Value != 0 {
			return fmt.Errorf("condition %q takes no value, got %d", c.Kind, c.Value)
		}
		return nil
	case gambitSelfHPBelow, gambitEnemyHPBelow, gambitAllyHPBelow:
		return gambitValueInRange(c, 1, 100)
	case gambitNearestEnemyDistLE:
		return gambitValueInRange(c, 0, maxGambitDistance)
	case gambitTurnGE:
		return gambitValueInRange(c, 1, maxGambitTurn)
	case gambitAllyCountLE:
		return gambitValueInRange(c, 0, maxGambitAllyCount)
	case "":
		return errors.New("condition has no kind")
	default:
		return fmt.Errorf("unknown condition kind %q", c.Kind)
	}
}

// Operand ceilings. Each is comfortably past anything the fight model can
// produce (the largest arena is well inside 64 cells across, sudden death ends
// a fight long before round 1000, and a side holds a handful of fighters), so
// they bound a hostile payload without constraining a real strategy.
const (
	maxGambitDistance  = 64
	maxGambitTurn      = 1000
	maxGambitAllyCount = 16
)

// gambitValueInRange is the shared operand bounds check.
func gambitValueInRange(c gambitCondition, lo, hi int32) error {
	if c.Value < lo || c.Value > hi {
		return fmt.Errorf("condition %q value %d out of range [%d,%d]", c.Kind, c.Value, lo, hi)
	}
	return nil
}

// validate checks an action's kind and its parameters.
//
// Only `cast` carries parameters, and it requires both of them. The other four
// must carry NEITHER: a "move_toward" with a spell id attached means its author
// believed something about the vocabulary that is not true, and accepting it
// silently would hide that.
func (a gambitAction) validate() error {
	switch a.Kind {
	case gambitCast:
		if a.Spell <= 0 {
			return fmt.Errorf("action %q needs a spell id, got %d", a.Kind, a.Spell)
		}
		switch a.Target {
		case gambitTargetSelf, gambitTargetNearestEnemy,
			gambitTargetWeakestEnemy, gambitTargetWeakestAlly:
			return nil
		case "":
			return fmt.Errorf("action %q needs a target", a.Kind)
		default:
			return fmt.Errorf("unknown cast target %q", a.Target)
		}
	case gambitMoveToward, gambitMoveAway, gambitCloseCombat, gambitPass:
		if a.Spell != 0 {
			return fmt.Errorf("action %q takes no spell, got %d", a.Kind, a.Spell)
		}
		if a.Target != "" {
			return fmt.Errorf("action %q takes no target, got %q", a.Kind, a.Target)
		}
		return nil
	case "":
		return errors.New("action has no kind")
	default:
		return fmt.Errorf("unknown action kind %q", a.Kind)
	}
}

// setGambitRulesJSON parses a ruleset and attaches it to the fighter, or leaves
// the fighter untouched and returns why it would not.
//
// This is the one intended entry point for giving a fighter rules: the phase-3
// ghost-storage path hands it the stored JSON verbatim, so a stored ruleset is
// validated against the vocabulary at load time rather than discovered to be
// broken mid-fight. A fighter whose rules were refused keeps nil Gambits and
// plays the archetype AI.
func (ff *FightFighter) setGambitRulesJSON(data []byte) error {
	if ff == nil {
		return errors.New("gambit ruleset: no fighter")
	}
	rs, err := parseGambitRules(data)
	if err != nil {
		return err
	}
	ff.Gambits = rs
	return nil
}
