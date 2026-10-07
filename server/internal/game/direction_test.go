package game

import (
	"encoding/binary"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// TestFighterDirectionChangeWire locks the 4522 layout the client's u_0 decoder
// reads: the 8-byte ue_0 action header [i32 uid][i32 -1] then [i64 fighterId]
// [u8 direction] — 17 bytes exactly.
func TestFighterDirectionChangeWire(t *testing.T) {
	const wireID int64 = 0x0102030405060708
	frame, err := buildFighterDirectionChange(7, wireID, 6)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	if op := binary.BigEndian.Uint16(frame[2:4]); op != protocol.OpFighterChangeDir {
		t.Fatalf("opcode = %d, want %d", op, protocol.OpFighterChangeDir)
	}
	p := frame[4:]
	if len(p) != 4+4+8+1 {
		t.Fatalf("payload = %d bytes, want 17", len(p))
	}
	if uid := binary.BigEndian.Uint32(p[0:4]); uid != 7 {
		t.Errorf("uid = %d, want 7", uid)
	}
	if trig := int32(binary.BigEndian.Uint32(p[4:8])); trig != -1 {
		t.Errorf("triggeringId = %d, want -1", trig)
	}
	if got := int64(binary.BigEndian.Uint64(p[8:16])); got != wireID {
		t.Errorf("fighterId = %d, want %d", got, wireID)
	}
	if p[16] != 6 {
		t.Errorf("direction = %d, want 6", p[16])
	}
}

// TestFighterDirectionChangeValidation exercises applyDirectionChange: a coach may
// turn only its OWN, LIVING fighter, and only on that fighter's turn.
func TestFighterDirectionChangeValidation(t *testing.T) {
	f := buildTestFight() // coach 1 (team 0) vs coach 2 (team 1), one fighter each
	f.setPhase(PhaseAction)

	var mine, theirs *FightFighter
	for i, ff := range f.Timeline {
		switch ff.CoachID {
		case 1:
			f.turnIndex = i // make coach 1's fighter the current turn
			mine = ff
		case 2:
			theirs = ff
		}
	}
	if mine == nil || theirs == nil {
		t.Fatal("expected one fighter per coach in the test fight")
	}

	// Happy path: the owner turns their fighter on its turn.
	if got := f.applyDirectionChange(1, mine.WireID, 6); got != mine {
		t.Fatalf("owner change returned %v, want the fighter", got)
	}
	if mine.Orientation != 6 {
		t.Errorf("orientation = %d, want 6", mine.Orientation)
	}
	// A second change updates the facing.
	if f.applyDirectionChange(1, mine.WireID, 2) != mine || mine.Orientation != 2 {
		t.Errorf("orientation = %d, want 2 after re-facing", mine.Orientation)
	}

	// Spoof: another coach cannot turn a fighter that isn't theirs.
	if f.applyDirectionChange(2, mine.WireID, 4) != nil {
		t.Error("a non-owner coach was allowed to change another fighter's facing")
	}
	if mine.Orientation != 2 {
		t.Errorf("orientation = %d, want 2 (unchanged by spoof)", mine.Orientation)
	}

	// Out of turn: coach 2's fighter is not the current turn.
	if f.applyDirectionChange(2, theirs.WireID, 3) != nil {
		t.Error("a fighter was allowed to change facing out of turn")
	}

	// Unknown fighter id.
	if f.applyDirectionChange(1, 0xDEADBEEF, 1) != nil {
		t.Error("an unknown fighter id was accepted")
	}

	// Dead fighter cannot turn.
	mine.HP = 0
	if f.applyDirectionChange(1, mine.WireID, 1) != nil {
		t.Error("a dead fighter was allowed to change facing")
	}
}

// TestFighterDirectionChangePlacement: during PhasePlacement there is no turn
// yet, so a coach may face its own fighter freely — but still nobody else's.
func TestFighterDirectionChangePlacement(t *testing.T) {
	f := buildTestFight()
	f.setPhase(PhasePlacement)
	f.turnIndex = -1 // no current turn in placement

	var mine, theirs *FightFighter
	for _, ff := range f.Timeline {
		switch ff.CoachID {
		case 1:
			mine = ff
		case 2:
			theirs = ff
		}
	}
	if mine == nil || theirs == nil {
		t.Fatal("expected one fighter per coach in the test fight")
	}

	// Owner turns its fighter during placement — no turn check applies.
	if got := f.applyDirectionChange(1, mine.WireID, 7); got != mine {
		t.Fatalf("placement facing returned %v, want the fighter", got)
	}
	if mine.Orientation != 7 {
		t.Errorf("orientation = %d, want 7", mine.Orientation)
	}

	// Still not the other coach's fighter.
	if f.applyDirectionChange(1, theirs.WireID, 2) != nil {
		t.Error("a coach turned another coach's fighter during placement")
	}
	if f.applyDirectionChange(2, mine.WireID, 2) != nil {
		t.Error("a non-owner turned a fighter during placement")
	}
}
