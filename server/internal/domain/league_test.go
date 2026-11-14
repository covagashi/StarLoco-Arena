package domain

import "testing"

func TestRankedLeague(t *testing.T) {
	for _, tc := range []struct {
		strength int32
		name     string
		budget   int32
	}{
		{0, "bronze", 4000}, {1000, "bronze", 4000}, {1199, "bronze", 4000},
		{1200, "silver", 4500}, {1400, "gold", 5000}, {1600, "platinum", 5500},
		{1799, "platinum", 5500}, {1800, "diamond", 6000}, {3000, "diamond", 6000},
	} {
		if l := RankedLeague(tc.strength); l.Name != tc.name || l.Budget != tc.budget {
			t.Errorf("RankedLeague(%d) = %+v, want %s %d", tc.strength, l, tc.name, tc.budget)
		}
	}
}

func TestGhostLeague(t *testing.T) {
	for _, tc := range []struct {
		elo    int32
		name   string
		budget int32
	}{
		{100, "bronze", 4000}, {1000, "bronze", 4000}, {1099, "bronze", 4000},
		{1100, "silver", 4500}, {1250, "gold", 5000}, {1300, "platinum", 5500},
		{1400, "diamond", 6000}, {2500, "diamond", 6000},
	} {
		if l := GhostLeague(tc.elo); l.Name != tc.name || l.Budget != tc.budget {
			t.Errorf("GhostLeague(%d) = %+v, want %s %d", tc.elo, l, tc.name, tc.budget)
		}
	}
}
