package game

import (
	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// Roster rules, enforced server-side at the single point every fight path funnels
// through (buildFightTeamFor).
//
// THE POINT OF THIS FILE: these are rules the retail SERVER enforced. They are
// visible in the client only as messages, and it is tempting to read them as
// "client-side validation we would diverge from by enforcing" - which is exactly
// what this project previously concluded about the team budget. That was wrong.
// zN.java:214-322 handles opcode 25000, a server->client error frame, and it maps
// codes 45/46/63/69/78 to these very strings, in the SAME switch as 34/38/39/40
// which this server already sends. Retail validated all of it.
//
// Client-side checks are advisory by definition: a modified client omits them.
// Worse, on two paths (24000/24001, hu_2.java:456-459) the RETAIL client only
// WARNS about the budget and submits anyway - so even honest clients were relying
// on the server here.
const (
	// maxTeamBudget is the client's own cap (hu_2.java:456: `n4 > 6000`), the
	// budget of every mode without a league; the Ranking and the ghost ladder
	// cap a team by the coach's league instead (domain.League, S40).
	maxTeamBudget int32 = 6000
	// minEvolutionTeamBudget mirrors hu_2.java:1073 and the client's rendering of
	// code 78, which formats the message with the literal 5000.
	minEvolutionTeamBudget int32 = 5000
)

// rosterViolation names which rule a roster broke, so the caller can answer with
// the matching retail error code instead of a generic failure.
type rosterViolation uint8

const (
	rosterOK rosterViolation = iota
	rosterEmpty
	rosterTooManyFighters
	rosterTooManySameBreed
	rosterOverBudget
	rosterDeadFighter
)

// code maps a violation to the client error code that renders the right message.
func (v rosterViolation) code() uint8 {
	switch v {
	case rosterTooManyFighters, rosterEmpty:
		return protocol.FightErrInvalidFightersCount
	case rosterTooManySameBreed:
		return protocol.FightErrTooManySameBreed
	case rosterOverBudget:
		return protocol.FightErrInvalidTeamBudget
	default:
		return protocol.FightErrUnableToCreate
	}
}

func (v rosterViolation) String() string {
	switch v {
	case rosterOK:
		return "ok"
	case rosterEmpty:
		return "empty roster"
	case rosterTooManyFighters:
		return "too many fighters"
	case rosterTooManySameBreed:
		return "too many of one breed"
	case rosterOverBudget:
		return "over budget"
	case rosterDeadFighter:
		return "dead fighter fielded"
	default:
		return "unknown"
	}
}

// validateRoster checks a resolved roster against the retail rules.
//
// It takes already-resolved fighters (ownership having been established by the
// caller) so that it is a pure function of the roster and therefore trivially
// testable.
func validateRoster(chosen []*domain.Fighter, evolution bool, budgetCap int32) rosterViolation {
	if len(chosen) == 0 {
		return rosterEmpty
	}
	if len(chosen) > maxTeamMembers {
		return rosterTooManyFighters
	}

	seen := map[uint]bool{}
	perBreed := map[uint8]int{}
	var budget int32
	for _, fr := range chosen {
		if fr == nil {
			return rosterEmpty
		}
		// A duplicate id is the roster-duplication vector; it also collides the
		// derived WireID (base + fighterID*16 + side*8 + i) once i passes 16.
		if seen[fr.ID] {
			return rosterTooManyFighters
		}
		seen[fr.ID] = true

		perBreed[fr.BreedID]++
		if perBreed[fr.BreedID] > maxSameBreedPerTeam {
			return rosterTooManySameBreed
		}
		// A dead (or graveyarded) evolution fighter may not be fielded. The client
		// refuses the match outright rather than quietly dropping the fighter
		// (hu_2.java:1016-1037), so the server refuses too.
		if fr.State == domain.FighterStateDead || fr.State == domain.FighterStateGraveyard {
			return rosterDeadFighter
		}
		budget += int32(fr.Budget)
	}

	if budget > budgetCap {
		return rosterOverBudget
	}
	if evolution && budget < minEvolutionTeamBudget {
		// Sandbagging guard: evolution feeds progression (XP, morale, fatigue,
		// wounds, permanent death), so a near-zero-cost roster farms rated matches
		// against opponents who spent the full budget, with nothing at risk.
		return rosterOverBudget
	}
	return rosterOK
}
