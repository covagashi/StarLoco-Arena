package game

import (
	"log/slog"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// TestBuildFightTeamRefusesIllegalRoster proves the CHOKE POINT applies the rules,
// not just that validateRoster computes them.
//
// My first attempt at this went through e2e matchmaking and passed vacuously: the
// two test coaches never actually paired, so no fight formed either way and a
// mutation removing the whole validation survived. Calling buildFightTeamFor
// directly is deterministic and actually exercises the gate.
func TestBuildFightTeamRefusesIllegalRoster(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/roster.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("rosteracct", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "RosterCoach", 0, 0, 0)

	d := &Deps{Store: st, Log: slog.Default(), World: NewRegistry(50)}
	sess := &Session{Coach: coach, deps: d, log: slog.Default()}

	// 20 owned fighters, all legal individually.
	var ids []int64
	for i := 0; i < 20; i++ {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: uint8(i%12 + 1),
			Name: "F", Budget: 100}
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("seed fighter: %v", err)
		}
		ids = append(ids, int64(f.ID))
	}

	cells := []Pos{{X: 1, Y: 1}, {X: 2, Y: 2}}

	// Oversized roster -> refused.
	if _, err := d.buildFightTeamFor(sess, 0, cells, ids); err == nil {
		t.Error("a 20-fighter roster was accepted; past i=16 the derived WireID " +
			"collides with another fighter's space")
	}

	// A legal subset -> accepted, proving the refusal above is the ROSTER rule and
	// not the fixture failing for some other reason.
	if _, err := d.buildFightTeamFor(sess, 0, cells, ids[:3]); err != nil {
		t.Errorf("a legal 3-fighter roster was refused: %v", err)
	}
}

// TestBuildFightTeamRefusesOverBudget covers the user-facing rule directly: the
// team cost cap the client checks (and, on two paths, only WARNS about while
// still submitting - so even honest clients relied on the server here).
func TestBuildFightTeamRefusesOverBudget(t *testing.T) {
	st, err := storetest.Open(t, t.TempDir()+"/budget.db")
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })

	acc, _ := st.Accounts.CreateAccount("budgetacct", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "BudgetCoach", 0, 0, 0)
	d := &Deps{Store: st, Log: slog.Default(), World: NewRegistry(50)}
	sess := &Session{Coach: coach, deps: d, log: slog.Default()}

	var ids []int64
	for i := 0; i < 3; i++ {
		f := &domain.Fighter{CoachID: coach.ID, BreedID: uint8(i + 1),
			Name: "Rich", Budget: 5000} // 15000 total, cap is 6000
		if err := st.Fighters.Create(f); err != nil {
			t.Fatalf("seed fighter: %v", err)
		}
		ids = append(ids, int64(f.ID))
	}

	cells := []Pos{{X: 1, Y: 1}}
	_, err = d.buildFightTeamFor(sess, 0, cells, ids)
	if err == nil {
		t.Fatal("a 15000-budget team was fielded against a 6000 cap")
	}
	var re rosterError
	if ok := asRosterError(err, &re); !ok || re.Code() != 46 {
		t.Errorf("err = %v; want a rosterError carrying code 46 "+
			"(error.fight.creation.invalidTeamBudget), so the client shows the "+
			"right reason", err)
	}
}

func asRosterError(err error, out *rosterError) bool {
	if re, ok := err.(rosterError); ok {
		*out = re
		return true
	}
	return false
}
