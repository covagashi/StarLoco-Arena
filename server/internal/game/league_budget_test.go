package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
)

// S40: the team budget follows the coach's league on the two ladders.

func TestValidateRosterLeagueCap(t *testing.T) {
	team := rosterOf([3]int{1, 2200, 0}, [3]int{2, 2200, 0}) // 4400
	if v := validateRoster(team, false, domain.RankedLeague(1000).Budget); v != rosterOverBudget {
		t.Fatalf("4400 in bronze (4000): %v, want over budget", v)
	}
	if v := validateRoster(team, false, domain.RankedLeague(1200).Budget); v != rosterOK {
		t.Fatalf("4400 in silver (4500): %v", v)
	}
}

// leagueFixture: the ghost fixture's coach with two fighters worth 2200 each.
func leagueFixture(t *testing.T) (*Deps, *domain.Coach) {
	t.Helper()
	d, st, coach := ghostFixture(t)
	live, _ := st.Fighters.ListByCoach(coach.ID)
	for _, fr := range live {
		if err := st.Fighters.SaveLoadout(fr.ID, coach.ID, fr.Objects, fr.Spells, 2200); err != nil {
			t.Fatal(err)
		}
	}
	return d, coach
}

func TestGhostSnapshotHeldToItsLeague(t *testing.T) {
	d, coach := leagueFixture(t)
	if _, code := d.saveGhost(coach.ID, "bronce", nil); code == ghostOK {
		t.Fatal("a 4400 ghost saved at a bronze rating (4000)")
	}
	if err := d.Store.Ghosts.SaveRating(domain.GhostRating{CoachID: coach.ID, Elo: 1150}); err != nil {
		t.Fatal(err)
	}
	if _, code := d.saveGhost(coach.ID, "plata", nil); code != ghostOK {
		t.Fatalf("a 4400 ghost at silver (4500): code %d", code)
	}
}

func TestRankedTeamHeldToItsLeague(t *testing.T) {
	d, coach := leagueFixture(t)
	live, _ := d.Store.Fighters.ListByCoach(coach.ID)
	ids := []int64{int64(live[0].ID), int64(live[1].ID)}
	sess := &Session{Coach: coach, deps: d, log: d.Log}
	a := &arena{}
	if _, err := d.buildFightTeam(a, &searcher{session: sess, teamIDs: ids, strength: 1100}, 0); err == nil {
		t.Fatal("a 4400 team was fielded in bronze")
	}
	if _, err := d.buildFightTeam(a, &searcher{session: sess, teamIDs: ids, strength: 1250}, 0); err != nil {
		t.Fatalf("a 4400 team in silver: %v", err)
	}
	// Outside the ladders the retail cap stands.
	if _, err := d.buildFightTeamFor(sess, 0, nil, ids); err != nil {
		t.Fatalf("a 4400 team in a mode without a league: %v", err)
	}
}
