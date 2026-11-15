package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// TestResetPositionMovesCoachToAZaap: /resetPosition (4514) is the player's own
// unstick. It must land the coach somewhere it can actually walk out of - a
// Zaap cell - and on the world it is CURRENTLY on, not the start world, or the
// unstick silently becomes an eviction.
func TestResetPositionMovesCoachToAZaap(t *testing.T) {
	d, st := fightCreationDeps(t)
	_ = st
	d.Log = testLogger()
	s := tmSession(d, 1, "Stuck")
	d.World.Add(&Online{Coach: s.Coach, Session: s})
	s.currentWorld = startWorldID

	z, ok := primaryZaap(startWorldID)
	if !ok {
		t.Fatal("no zaap for the start world in elements_data.go")
	}
	// Wedge the coach somewhere it certainly is not supposed to be.
	s.Coach.PosX, s.Coach.PosY, s.Coach.PosZ = -9999, -9999, 0
	d.World.UpdatePosition(s.Coach.ID, -9999, -9999, 0)

	if err := handleResetPosition(s, &protocol.C2SFrame{Opcode: protocol.OpResetPosition}); err != nil {
		t.Fatalf("handleResetPosition: %v", err)
	}
	if s.Coach.PosX != z.cellX || s.Coach.PosY != z.cellY || s.Coach.PosZ != z.alt {
		t.Errorf("coach at (%d,%d,%d), want the world's zaap (%d,%d,%d)",
			s.Coach.PosX, s.Coach.PosY, s.Coach.PosZ, z.cellX, z.cellY, z.alt)
	}
}

// TestResetPositionRefusedInFight: it must not double as an escape hatch out of
// a fight.
func TestResetPositionRefusedInFight(t *testing.T) {
	d, _ := fightCreationDeps(t)
	d.Log = testLogger()
	s := tmSession(d, 1, "Fighter")
	d.World.Add(&Online{Coach: s.Coach, Session: s})
	s.currentWorld = startWorldID
	if _, ok := primaryZaap(startWorldID); !ok {
		t.Skip("no zaap data for the start world")
	}
	s.Coach.PosX, s.Coach.PosY = -1234, -1234

	f := buildTestFight()
	f.Teams[0].Coach().ID = s.Coach.ID
	f.setPhase(PhaseAction)
	d.Fights.Create(f)

	// Fixture check: without a fight actually registered for this coach the
	// guard below is never reached and the test would pass vacuously.
	if d.Fights.ByCoach(s.Coach.ID) == nil {
		t.Fatal("fixture: no fight registered for the coach")
	}
	if err := handleResetPosition(s, &protocol.C2SFrame{Opcode: protocol.OpResetPosition}); err != nil {
		t.Fatalf("handleResetPosition: %v", err)
	}
	if s.Coach.PosX != -1234 {
		t.Errorf("coach moved to x=%d during a fight; /resetPosition must not be "+
			"an escape hatch", s.Coach.PosX)
	}
}

// TestResetPositionStaysOnCurrentWorld: the unstick must land the player on the
// island it is ON, not the start island. A start-world fallback here would look
// like a working unstick in every test that happens to sit on world 25, while
// silently evicting everyone else - so this case uses a DIFFERENT world on
// purpose.
func TestResetPositionStaysOnCurrentWorld(t *testing.T) {
	const otherWorld int16 = 26
	if otherWorld == startWorldID {
		t.Fatal("fixture: otherWorld must differ from startWorldID or this test is vacuous")
	}
	other, ok := primaryZaap(otherWorld)
	if !ok {
		t.Skip("no zaap data for world 26")
	}
	start, ok := primaryZaap(startWorldID)
	if !ok {
		t.Skip("no zaap data for the start world")
	}
	if other.cellX == start.cellX && other.cellY == start.cellY {
		t.Fatal("fixture: the two worlds' zaaps coincide, so this test could not " +
			"tell a correct destination from a start-world fallback")
	}

	d, _ := fightCreationDeps(t)
	d.Log = testLogger()
	s := tmSession(d, 1, "Traveller")
	d.World.Add(&Online{Coach: s.Coach, Session: s})
	s.currentWorld = otherWorld
	s.Coach.PosX, s.Coach.PosY, s.Coach.PosZ = -9999, -9999, 0

	if err := handleResetPosition(s, &protocol.C2SFrame{Opcode: protocol.OpResetPosition}); err != nil {
		t.Fatalf("handleResetPosition: %v", err)
	}
	if s.Coach.PosX != other.cellX || s.Coach.PosY != other.cellY {
		t.Errorf("coach at (%d,%d), want world %d's zaap (%d,%d); landing on the "+
			"start world's (%d,%d) would mean the unstick evicted the player",
			s.Coach.PosX, s.Coach.PosY, otherWorld, other.cellX, other.cellY,
			start.cellX, start.cellY)
	}
}
