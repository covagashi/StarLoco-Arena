package gamedata

import "testing"

func loadMaps(t *testing.T) *FightMaps {
	t.Helper()
	m, err := LoadFightMaps()
	if err != nil {
		t.Fatal(err)
	}
	return m
}

// TestFightMapsLoad checks every arena is coherent: a bounding box, at least one
// start cell per side, and every start cell and special cell standing on real
// ground at the altitude it records (the client rejects a fighter whose z
// disagrees with the cell's).
func TestFightMapsLoad(t *testing.T) {
	maps := loadMaps(t)
	if maps.Len() != 6 {
		t.Errorf("loaded %d arenas, want the prototype's 6", maps.Len())
	}
	for _, id := range maps.IDs() {
		m := maps.Get(id)
		if m.Width <= 0 || m.Height <= 0 {
			t.Errorf("map %d has empty bounds %dx%d", id, m.Width, m.Height)
			continue
		}
		if len(m.Team0) == 0 || len(m.Team1) == 0 {
			t.Errorf("map %d has %d/%d start cells", id, len(m.Team0), len(m.Team1))
		}
		for _, p := range append(append([]MapPos{}, m.Team0...), m.Team1...) {
			c := m.At(p.X, p.Y)
			if !c.Ground {
				t.Errorf("map %d: start cell (%d,%d) has no ground", id, p.X, p.Y)
			}
			if c.Alt != p.Z {
				t.Errorf("map %d: start cell (%d,%d) z=%d but topology altitude=%d",
					id, p.X, p.Y, p.Z, c.Alt)
			}
		}
		for _, s := range m.Specials {
			c := m.At(s.X, s.Y)
			if !c.Ground {
				t.Errorf("map %d: special cell (%d,%d) has no ground", id, s.X, s.Y)
			}
			if c.Alt != s.Z {
				t.Errorf("map %d: special (%d,%d) z=%d but altitude=%d", id, s.X, s.Y, s.Z, c.Alt)
			}
		}
	}
}

func assertCells(t *testing.T, what string, got, want []MapPos) {
	t.Helper()
	if len(got) != len(want) {
		t.Errorf("%s: %d cells, want %d", what, len(got), len(want))
		return
	}
	set := map[MapPos]bool{}
	for _, p := range got {
		set[p] = true
	}
	for _, p := range want {
		if !set[p] {
			t.Errorf("%s: missing start cell %+v (got %+v)", what, p, got)
		}
	}
}
