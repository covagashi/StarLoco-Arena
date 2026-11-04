package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// Coach pedestals, against the real shipped .fmd files.
//
// The .fmd ALWAYS stores six pedestal slots, whether or not the map uses them,
// and an unused slot decodes to the unpacked-zero sentinel (-2047, -2047, -127).
// Fifteen of the forty-seven shipped arenas populate none of the six. Keeping the
// sentinels and handing them out as cells put a coach 2047 tiles off the map.
//
// Reading the data also answered the question that prompted this: a 2v2 does NOT
// need a different kind of map. Twenty-eight arenas populate all six slots and
// twenty-four of those split them exactly 3/3, so the shipped arenas were always
// built for up to THREE coaches a side.

func loadRealFightMaps(t *testing.T) *gamedata.FightMaps {
	t.Helper()
	m, err := gamedata.LoadFightMaps()
	if err != nil {
		t.Fatal(err)
	}
	return m
}

func TestArenaDropsEmptyPedestalSlots(t *testing.T) {
	maps := loadRealFightMaps(t)
	checked := 0
	for _, id := range maps.IDs() {
		a := newArenaFromMap(maps.Get(id))
		for _, p := range a.coachCells {
			if p.X == emptyPedestalXY && p.Y == emptyPedestalXY {
				t.Fatalf("arena %d kept an empty pedestal slot %v - a coach would be "+
					"placed 2047 tiles off the map", id, p)
			}
		}
		if len(a.coachCells) > 6 {
			t.Errorf("arena %d has %d pedestals, the .fmd only stores 6", id, len(a.coachCells))
		}
		checked++
	}
	if checked == 0 {
		t.Fatal("no arenas checked")
	}
}

// TestPedestalsAreOnTheirOwnSide: a pedestal handed to a side must sit nearer
// that side's start cells than the enemy's, or a coach would stand behind the
// team it is fighting.
func TestPedestalsAreOnTheirOwnSide(t *testing.T) {
	maps := loadRealFightMaps(t)
	for _, id := range maps.IDs() {
		a := newArenaFromMap(maps.Get(id))
		if len(a.startCells(0)) == 0 || len(a.startCells(1)) == 0 {
			continue // a one-sided map cannot express "own side"
		}
		for _, side := range []uint8{0, 1} {
			for _, p := range a.pedestalsFor(side) {
				mine, theirs := a.nearestStart(p, side), a.nearestStart(p, 1-side)
				if mine > theirs {
					t.Errorf("arena %d: pedestal %v given to side %d is closer to side %d",
						id, p, side, 1-side)
				}
			}
		}
	}
}

// TestSomeArenasSeatTwoCoachesPerSide is the one that makes 2v2 possible at all.
// If it ever fails, either the sentinel filter or the side split has broken, and
// a 2v2 has nowhere to seat its second coach.
func TestSomeArenasSeatTwoCoachesPerSide(t *testing.T) {
	maps := loadRealFightMaps(t)
	capable, total := 0, 0
	for _, id := range maps.IDs() {
		a := newArenaFromMap(maps.Get(id))
		total++
		if a.coachCapacity() >= 2 {
			capable++
		}
	}
	if capable == 0 {
		t.Fatalf("no arena of %d can seat 2 coaches a side - 2v2 is unhostable", total)
	}
	// Of the prototype's six, arenas 3, 4 and 5 (worlds 12, 15, 21) seat two
	// a side. 2vs2 is hidden (S20), so this only guards against a collapse
	// (e.g. the sentinel filter eating real cells).
	if capable < 3 {
		t.Errorf("only %d/%d arenas can seat 2 coaches a side, expected 3", capable, total)
	}
	t.Logf("%d/%d arenas can host a 2v2", capable, total)
}
