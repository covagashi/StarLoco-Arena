package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

func rosterOf(specs ...[3]int) []*domain.Fighter {
	out := make([]*domain.Fighter, 0, len(specs))
	for i, sp := range specs {
		out = append(out, &domain.Fighter{
			ID:      uint(i + 1),
			BreedID: uint8(sp[0]),
			Budget:  int16(sp[1]),
			State:   uint8(sp[2]),
		})
	}
	return out
}

// TestRosterRulesAreEnforcedServerSide covers the rules the RETAIL SERVER
// enforced and this server did not.
//
// These are not "client-side validation we would diverge from by enforcing" -
// which is what this project previously concluded about the team budget. zN.java
// handles opcode 25000, a server->client error frame, and maps codes 45/46/63 to
// these very messages in the SAME switch as 34/38/39/40, which this server
// already sends. Retail validated all of it.
func TestRosterRulesAreEnforcedServerSide(t *testing.T) {
	cases := []struct {
		name    string
		roster  []*domain.Fighter
		evo     bool
		want    rosterViolation
		wantErr uint8
	}{
		{"legal 3-fighter team", rosterOf([3]int{1, 500, 0}, [3]int{2, 500, 0}, [3]int{3, 500, 0}), false, rosterOK, 0},
		{"empty", nil, false, rosterEmpty, protocol.FightErrInvalidFightersCount},
		{"seven fighters", rosterOf(
			[3]int{1, 10, 0}, [3]int{2, 10, 0}, [3]int{3, 10, 0}, [3]int{4, 10, 0},
			[3]int{5, 10, 0}, [3]int{6, 10, 0}, [3]int{7, 10, 0}), false,
			rosterTooManyFighters, protocol.FightErrInvalidFightersCount},
		{"three of one breed", rosterOf([3]int{1, 10, 0}, [3]int{1, 10, 0}, [3]int{1, 10, 0}), false,
			rosterTooManySameBreed, protocol.FightErrTooManySameBreed},
		{"over budget", rosterOf([3]int{1, 5000, 0}, [3]int{2, 5000, 0}), false,
			rosterOverBudget, protocol.FightErrInvalidTeamBudget},
		{"exactly at budget is allowed", rosterOf([3]int{1, 3000, 0}, [3]int{2, 3000, 0}), false, rosterOK, 0},
		{"dead fighter fielded", rosterOf([3]int{1, 10, int(domain.FighterStateDead)}), false, rosterDeadFighter, 0},
		{"graveyard fighter fielded", rosterOf([3]int{1, 10, int(domain.FighterStateGraveyard)}), false, rosterDeadFighter, 0},
		{"evolution below the minimum budget", rosterOf([3]int{1, 100, 0}), true,
			rosterOverBudget, protocol.FightErrInvalidTeamBudget},
		{"evolution at the minimum budget", rosterOf([3]int{1, 5000, 0}), true, rosterOK, 0},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got := validateRoster(tc.roster, tc.evo, maxTeamBudget)
			if got != tc.want {
				t.Fatalf("validateRoster = %v, want %v", got, tc.want)
			}
			if tc.wantErr != 0 && got.code() != tc.wantErr {
				t.Errorf("error code = %d, want %d (the client renders this string)",
					got.code(), tc.wantErr)
			}
		})
	}
}

// TestRosterRejectsDuplicateFighters covers the duplication vector at the fight
// choke point. 6021 was fixed for this in B-148, but opcode 2301 hands a raw id
// list straight to buildFightTeamFor, so the same corruption was still reachable:
// past i=16 the derived WireID (base + fighterID*16 + side*8 + i) collides with
// another fighter's space.
func TestRosterRejectsDuplicateFighters(t *testing.T) {
	same := &domain.Fighter{ID: 7, BreedID: 1, Budget: 10}
	if got := validateRoster([]*domain.Fighter{same, same}, false, maxTeamBudget); got == rosterOK {
		t.Error("the same fighter twice was accepted into a fight roster")
	}
}

// TestBudgetCeilingMatchesTheClient pins the two thresholds against the client's
// own literals, so a change here has to be deliberate.
func TestBudgetCeilingMatchesTheClient(t *testing.T) {
	if maxTeamBudget != 6000 {
		t.Errorf("maxTeamBudget = %d, but the client checks `n4 > 6000` (hu_2.java:456)", maxTeamBudget)
	}
	if minEvolutionTeamBudget != 5000 {
		t.Errorf("minEvolutionTeamBudget = %d, but the client formats its message "+
			"with 5000 (hu_2.java:1073, zN.java:314)", minEvolutionTeamBudget)
	}
}
