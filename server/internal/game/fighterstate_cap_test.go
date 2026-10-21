package game

import (
	"log/slog"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestFighterStateToggleRespectsCapacity drives handleFighterSetState's guard,
// not just the constants.
//
// Only the graveyard cap was enforced. The TITULAR one matters most:
// titularRoster feeds evolution and PvE challenge fights, and its 6-limit came
// only from a `max` argument one caller passed - nothing stopped the stored
// line-up itself from growing.
func TestFighterStateToggleRespectsCapacity(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/states.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("statecap", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "StateCap", 0, 0, 0)
	s := &Session{
		Coach: coach,
		deps:  &Deps{Store: st, Log: slog.Default(), World: NewRegistry(50)},
		log:   slog.Default(),
	}

	// Fill the bench to its capacity of 7.
	for i := 0; i < domain.BenchCapacity; i++ {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "B",
			State: domain.FighterStateBench}
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("seed bench %d: %v", i, err)
		}
	}
	full, err := s.stateIsFull(domain.FighterStateBench)
	if err != nil {
		t.Fatalf("stateIsFull: %v", err)
	}
	if !full {
		t.Fatalf("fixture broken: %d benched fighters should fill a %d-slot bench",
			domain.BenchCapacity, domain.BenchCapacity)
	}

	// One more titular fighter tries to move to the full bench.
	extra := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "Extra",
		State: domain.FighterStateTitular}
	if err := st.Fighters.Create(extra); err != nil {
		t.Fatalf("seed extra: %v", err)
	}
	next, ok := nextFighterState(extra.State)
	if !ok || next != domain.FighterStateBench {
		t.Fatalf("fixture broken: titular should toggle to bench, got %d ok=%v", next, ok)
	}
	if full, _ := s.stateIsFull(next); !full {
		t.Error("the bench is full but stateIsFull says otherwise, so the handler " +
			"guard can never fire")
	}

	// And a state with room must NOT be reported full, or the guard blocks
	// legitimate moves.
	if full, _ := s.stateIsFull(domain.FighterStateGraveyard); full {
		t.Error("an empty graveyard was reported full")
	}

	// THE TITULAR CAP specifically. This is the one that mattered: titularRoster
	// feeds evolution and PvE challenge fights, and its 6-limit came only from a
	// caller's `max` argument - the stored line-up itself was unbounded. A
	// mutation removing this cap survived until the test filled titular directly
	// rather than only the bench.
	if full, _ := s.stateIsFull(domain.FighterStateTitular); full {
		t.Fatal("fixture broken: only one titular fighter exists, cannot be full")
	}
	for i := 0; i < maxTeamMembers; i++ {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: 1, Name: "T",
			State: domain.FighterStateTitular}
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("seed titular %d: %v", i, err)
		}
	}
	full, err = s.stateIsFull(domain.FighterStateTitular)
	if err != nil {
		t.Fatalf("stateIsFull(titular): %v", err)
	}
	if !full {
		t.Errorf("more than %d titular fighters are not reported as full - the "+
			"starting line-up is unbounded", maxTeamMembers)
	}
}

// TestStateIsFullCoversEveryCappedState guards against a destination silently
// having no capacity concept - which is exactly how the bench, titular and
// legendary caps went missing while the graveyard was enforced.
func TestStateIsFullCoversEveryCappedState(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/states2.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("statecap2", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "StateCap2", 0, 0, 0)
	s := &Session{Coach: coach, deps: &Deps{Store: st, Log: slog.Default()}, log: slog.Default()}

	// Every state reachable from nextFighterState must have a capacity.
	for _, from := range []uint8{
		domain.FighterStateTitular, domain.FighterStateBench,
		domain.FighterStateDead, domain.FighterStateLegendary,
		domain.FighterStateLegBench,
	} {
		next, ok := nextFighterState(from)
		if !ok {
			continue
		}
		var capped bool
		switch next {
		case domain.FighterStateTitular, domain.FighterStateBench,
			domain.FighterStateGraveyard, domain.FighterStateLegendary,
			domain.FighterStateLegBench:
			capped = true
		}
		if !capped {
			t.Errorf("state %d (reached from %d) has no capacity rule", next, from)
		}
		if _, err := s.stateIsFull(next); err != nil {
			t.Errorf("stateIsFull(%d): %v", next, err)
		}
	}
}
