package gamedata

import (
	"path/filepath"
	"testing"
)

// TestMapBonusesReal pins the type-1600 decode against the real record set:
// 29 maps, two action families — arenas 86-109 carry AI19 drop chance 1-25%
// and maps 24-28 carry AI1 XP% 5-25 — plus the eliteDropBonus byte (1-3).
// The values below were dumped straight from the shipped data.
func TestMapBonusesReal(t *testing.T) {
	st, err := Open(filepath.Join("..", "..", "data"))
	if err != nil {
		st, err = Open(filepath.Join("..", "..", "data-dist"))
		if err != nil {
			t.Skipf("game data not available: %v", err)
		}
	}
	mb, err := st.LoadMapBonuses()
	if err != nil {
		t.Fatalf("LoadMapBonuses: %v", err)
	}
	if mb.Len() != 29 {
		t.Fatalf("Len = %d, want 29", mb.Len())
	}

	// Drop arenas: each carries exactly one AI19 action.
	dropWant := map[int16]int32{
		86: 15, 87: 16, 88: 12, 89: 17, 90: 9, 91: 14, 92: 3, 93: 6,
		94: 2, 95: 4, 96: 7, 97: 23, 98: 18, 99: 21, 100: 1, 101: 10,
		102: 11, 103: 13, 104: 19, 105: 5, 106: 20, 107: 8, 108: 22, 109: 25,
	}
	for m, want := range dropWant {
		if got := mb.DropChanceBonus(m); got != want {
			t.Errorf("DropChanceBonus(map %d) = %d, want %d", m, got, want)
		}
	}
	// XP maps: one AI1 each, 5/10/15/20/25 by id order 24..28.
	xpWant := map[int16]int32{24: 5, 25: 20, 26: 10, 27: 15, 28: 25}
	for m, want := range xpWant {
		if got := mb.XPBonusPercent(m); got != want {
			t.Errorf("XPBonusPercent(map %d) = %d, want %d", m, got, want)
		}
	}
	// Elite bonus sits in 1..3 everywhere it exists; a plain map reports none.
	for _, e := range st.EntriesOf(TypeMapBonus) {
		rec, _ := st.ReadRecord(e.Position)
		if m := decodeMapBonus(rec.Data); m != nil {
			if m.EliteDropBonus < 1 || m.EliteDropBonus > 3 {
				t.Errorf("map %d eliteDropBonus = %d, want 1..3", m.MapID, m.EliteDropBonus)
			}
		}
	}
	if mb.Get(5) != nil || mb.DropChanceBonus(5) != 0 || mb.XPBonusPercent(5) != 0 {
		t.Error("map 5 should have no bonus record")
	}
}
