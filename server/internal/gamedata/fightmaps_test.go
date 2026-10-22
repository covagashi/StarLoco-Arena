package gamedata

import "testing"

func loadMaps(t *testing.T) *FightMaps {
	t.Helper()
	m, err := LoadFightMaps(clientBdataDir)
	if err != nil {
		t.Skipf("map data not available: %v", err)
	}
	return m
}

// TestFightMapsLoad checks the whole set decodes and that every arena is coherent:
// a bounding box, at least one start cell per side, and every start cell standing on
// real ground at the altitude the .fmd recorded (the client rejects a fighter whose
// z disagrees with the topology).
func TestFightMapsLoad(t *testing.T) {
	maps := loadMaps(t)
	// 47 worlds ship fight start points and all 47 decode once every per-cell tile
	// kind is handled (types 2, 3 and 5). Two special cells (map 42) sit on cells
	// the topology gives no floor and are dropped as unreachable.
	if maps.Len() != 47 {
		t.Errorf("loaded %d arenas, want 47", maps.Len())
	}
	if got := maps.Skipped(); len(got) != 0 {
		t.Errorf("skipped = %v, want none", got)
	}
	if n := maps.UnreachableSpecials(); n != 2 {
		t.Errorf("unreachable specials = %d, want 2 (map 42's content quirk)", n)
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

// TestFightMap5MatchesHandDecode is the regression that matters: world 5 was decoded
// BY HAND into the server months ago (start cells, coach pedestals, the 22 scenery
// obstacles, the 9 special cells and a 151/22/151 floor/obstacle/void split). The
// loader must reproduce it exactly, or every other map it produces is suspect too.
func TestFightMap5MatchesHandDecode(t *testing.T) {
	m := loadMaps(t).Get(5)
	if m == nil {
		t.Fatal("world 5 missing")
	}
	if m.MinX != 0 || m.MinY != 0 || m.Width != 18 || m.Height != 18 {
		t.Fatalf("bounds = (%d,%d) %dx%d, want (0,0) 18x18", m.MinX, m.MinY, m.Width, m.Height)
	}

	wantTeam0 := []MapPos{
		{7, 15, 0}, {9, 15, 0}, {12, 15, 0}, {13, 15, 0},
		{6, 16, 0}, {8, 16, 0}, {12, 16, 0}, {13, 16, 0},
	}
	wantTeam1 := []MapPos{
		{6, 2, 3}, {9, 2, 3}, {10, 2, 3}, {13, 2, 0},
		{6, 3, 3}, {9, 3, 3}, {10, 3, 3}, {13, 3, 0},
	}
	assertCells(t, "team0", m.Team0, wantTeam0)
	assertCells(t, "team1", m.Team1, wantTeam1)

	// The 22 scenery obstacles: no ground, but a real altitude.
	wantObstacles := map[[2]int32]bool{
		{9, 1}: true, {10, 1}: true, {11, 1}: true, {13, 1}: true,
		{14, 2}: true, {4, 4}: true, {14, 5}: true, {2, 6}: true,
		{2, 7}: true, {9, 7}: true, {5, 8}: true, {5, 9}: true,
		{5, 10}: true, {11, 10}: true, {4, 11}: true, {4, 13}: true,
		{6, 13}: true, {7, 13}: true, {14, 13}: true, {16, 13}: true,
		{5, 15}: true, {12, 17}: true,
	}
	floor, obstacle, void := 0, 0, 0
	got := map[[2]int32]bool{}
	for y := int32(0); y < 18; y++ {
		for x := int32(0); x < 18; x++ {
			c := m.At(x, y)
			switch {
			case c.Ground:
				floor++
			case c.Void:
				void++
			default:
				obstacle++
				got[[2]int32{x, y}] = true
			}
		}
	}
	if floor != 151 || obstacle != 22 || void != 151 {
		t.Errorf("split = %d floor / %d obstacle / %d void, want 151/22/151", floor, obstacle, void)
	}
	for k := range wantObstacles {
		if !got[k] {
			t.Errorf("obstacle (%d,%d) missing from the decode", k[0], k[1])
		}
	}
	for k := range got {
		if !wantObstacles[k] {
			t.Errorf("unexpected obstacle at (%d,%d)", k[0], k[1])
		}
	}

	// The 9 special cells, with their template ids.
	wantSpecials := map[[2]int32]int32{
		{5, 6}: 1004, {15, 7}: 1004, {13, 9}: 1005, {12, 9}: 1008,
		{15, 11}: 1004, {8, 9}: 1008, {6, 11}: 1004, {7, 9}: 1005, {6, 9}: 1006,
	}
	if len(m.Specials) != len(wantSpecials) {
		t.Fatalf("specials = %d, want %d", len(m.Specials), len(wantSpecials))
	}
	for _, s := range m.Specials {
		want, ok := wantSpecials[[2]int32{s.X, s.Y}]
		if !ok {
			t.Errorf("unexpected special at (%d,%d)", s.X, s.Y)
			continue
		}
		if s.Template != want {
			t.Errorf("special (%d,%d) template = %d, want %d", s.X, s.Y, s.Template, want)
		}
	}

	// Coach pedestals sit ON scenery (no ground), which independently confirms the
	// ground-palette decode.
	for _, p := range m.CoachCells {
		if c := m.At(p.X, p.Y); c.Ground {
			t.Errorf("coach pedestal (%d,%d) should stand on scenery, not floor", p.X, p.Y)
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
