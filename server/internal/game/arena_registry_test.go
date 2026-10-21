package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/gamedata"
)

// loadArenaRegistry builds a registry from the real map data on a fresh Deps,
// which also keeps it from leaking into any other test.
func loadArenaRegistry(t *testing.T) *Deps {
	t.Helper()
	// a local data/ copy if there is one, else the committed data-dist
	maps, err := gamedata.LoadFightMaps(filepath.Join("..", "..", "data"))
	if err != nil {
		maps, err = gamedata.LoadFightMaps(filepath.Join("..", "..", "data-dist"))
	}
	if err != nil {
		t.Skipf("map data not available: %v", err)
	}
	d := &Deps{FightMaps: maps}
	d.initArenas()
	return d
}

// arenaIDsOf snapshots the registry's sorted ids.
func arenaIDsOf(d *Deps) []uint16 {
	d.arenas.mu.RLock()
	defer d.arenas.mu.RUnlock()
	return append([]uint16{}, d.arenas.ids...)
}

// TestArenaRegistryLoadsEveryMap: every shipped arena becomes a usable game arena
// with start cells on real floor at the altitude the client expects.
func TestArenaRegistryLoadsEveryMap(t *testing.T) {
	d := loadArenaRegistry(t)
	if n := d.loadedArenaCount(); n != 47 {
		t.Errorf("registry holds %d arenas, want 47", n)
	}
	ids := arenaIDsOf(d)

	for _, id := range ids {
		a := d.arenaByID(id)
		if a == nil {
			t.Fatalf("arena %d missing", id)
		}
		if len(a.team0) == 0 || len(a.team1) == 0 {
			t.Errorf("arena %d has %d/%d start cells", id, len(a.team0), len(a.team1))
		}
		for _, p := range append(append([]Pos{}, a.team0...), a.team1...) {
			if !a.walkable(p.X, p.Y) {
				t.Errorf("arena %d: start cell %v is not walkable", id, p)
			}
			if got := a.altitudeAt(p.X, p.Y); got != p.Z {
				t.Errorf("arena %d: start cell %v altitude %d (client rejects a mismatch)", id, p, got)
			}
		}
		// The camera/collapse centre must be inside the bounding box.
		if a.centerX < a.minX || a.centerX >= a.minX+a.width ||
			a.centerY < a.minY || a.centerY >= a.minY+a.height {
			t.Errorf("arena %d centre (%d,%d) outside bounds", id, a.centerX, a.centerY)
		}
	}
}

// TestArenaGridIsWellFormedForEveryMap: the streamed fight grid must classify each
// cell as floor / scenery / void, and every special cell must sit on real floor.
func TestArenaGridIsWellFormedForEveryMap(t *testing.T) {
	d := loadArenaRegistry(t)
	ids := arenaIDsOf(d)

	for _, id := range ids {
		a := d.arenaByID(id)
		floor := 0
		for y := a.minY; y < a.minY+a.height; y++ {
			for x := a.minX; x < a.minX+a.width; x++ {
				switch a.cellFlag(x, y) {
				case 0xFC00:
					floor++
					if !a.walkable(x, y) {
						t.Fatalf("arena %d (%d,%d): floor flag but not walkable", id, x, y)
					}
				case 0xFFFF:
					if !a.scenery(x, y) || a.walkable(x, y) {
						t.Fatalf("arena %d (%d,%d): obstacle flag but not scenery", id, x, y)
					}
				case 0xFEFF:
					if a.walkable(x, y) {
						t.Fatalf("arena %d (%d,%d): void flag but walkable", id, x, y)
					}
				default:
					t.Fatalf("arena %d (%d,%d): unexpected cell flag", id, x, y)
				}
			}
		}
		if floor == 0 {
			t.Errorf("arena %d has no walkable floor at all", id)
		}
		for _, sc := range a.specials {
			if !a.walkable(sc.Pos.X, sc.Pos.Y) {
				t.Errorf("arena %d: special %v is not on floor", id, sc.Pos)
			}
			if _, _, ok := a.specialAt(sc.Pos.X, sc.Pos.Y); !ok {
				t.Errorf("arena %d: specialAt missed its own special %v", id, sc.Pos)
			}
		}
	}
}

// TestFightsUseTheirOwnArena: a Fight validates against the map it is played on,
// not a package-wide default. Two fights on different arenas must not interfere,
// and sudden death must collapse toward each one's own centre.
func TestFightsUseTheirOwnArena(t *testing.T) {
	d := loadArenaRegistry(t)
	ids := arenaIDsOf(d)
	if len(ids) < 2 {
		t.Skip("need at least two arenas")
	}

	// Pick two arenas with different centres so the difference is observable.
	var a1, a2 *arena
	for _, id := range ids {
		a := d.arenaByID(id)
		if a1 == nil {
			a1 = a
			continue
		}
		if a.centerX != a1.centerX || a.centerY != a1.centerY {
			a2 = a
			break
		}
	}
	if a2 == nil {
		t.Skip("all arenas share a centre")
	}

	mk := func(a *arena) *Fight {
		f := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}, arena: a}
		f.deps = &Deps{Log: testLogger(), Fights: NewFightManager()}
		return f
	}
	f1, f2 := mk(a1), mk(a2)

	if f1.Arena().worldID == f2.Arena().worldID {
		t.Fatal("expected two distinct arenas")
	}
	if got := suddenDeathCentre(f1.Arena()); got.X != a1.centerX || got.Y != a1.centerY {
		t.Errorf("fight 1 collapses toward %v, want its own centre (%d,%d)", got, a1.centerX, a1.centerY)
	}
	if got := suddenDeathCentre(f2.Arena()); got.X != a2.centerX || got.Y != a2.centerY {
		t.Errorf("fight 2 collapses toward %v, want its own centre (%d,%d)", got, a2.centerX, a2.centerY)
	}

	// A fight built WITHOUT an arena still works, on the built-in fallback.
	bare := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}}
	if bare.Arena().worldID != practiceArena.worldID {
		t.Errorf("an arena-less fight fell back to world %d, want %d",
			bare.Arena().worldID, practiceArena.worldID)
	}
}

// TestSuddenDeathWorksOnEveryArena: the collapse must terminate and leave a core on
// every shipped map, not just world 5 — the schedule is derived per arena.
func TestSuddenDeathWorksOnEveryArena(t *testing.T) {
	d := loadArenaRegistry(t)
	ids := arenaIDsOf(d)

	for _, id := range ids {
		a := d.arenaByID(id)
		sched := suddenDeathSchedule(a, mapDestructionNy, mapDestructionNz)
		if len(sched) == 0 {
			t.Errorf("arena %d has an empty collapse schedule", id)
			continue
		}
		for i := 1; i < len(sched); i++ {
			if sched[i] <= sched[i-1] {
				t.Errorf("arena %d: schedule does not advance at step %d", id, i)
				break
			}
		}
		f := &Fight{Teams: [2]*FightTeam{{ID: 0}, {ID: 1}}, arena: a}
		f.deps = &Deps{Log: testLogger(), Fights: NewFightManager()}
		f.tableTurn = suddenDeathTurn
		for i := 0; i < len(sched)+4; i++ {
			f.maybeTriggerSuddenDeath()
			f.tableTurn++
		}
		centre := suddenDeathCentre(a)
		if f.cellDestroyed(centre.X, centre.Y) {
			t.Errorf("arena %d: the centre was destroyed", id)
		}
		if len(f.destroyedCells) == 0 {
			t.Errorf("arena %d: nothing was ever destroyed", id)
		}
	}
}
