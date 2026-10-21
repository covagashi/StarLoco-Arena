package game

import (
	"encoding/binary"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// decodeAttachBuff reads 8121 the way rq_2.a does:
// [i32 actionId][i16 blobLen][blob][i64 fighterId][i16 expiry][i8 flag].
func decodeAttachBuff(t *testing.T, frame []byte) (actionID int32, fighterID int64, expiry int16) {
	t.Helper()
	if op := binary.BigEndian.Uint16(frame[2:4]); op != protocol.OpRunScriptedEffect {
		t.Fatalf("opcode = %d, want %d", op, protocol.OpRunScriptedEffect)
	}
	r := protocol.NewReader(frame[4:])
	v, err := r.I32()
	if err != nil {
		t.Fatalf("actionId: %v", err)
	}
	actionID = v
	blobLen, err := r.U16()
	if err != nil {
		t.Fatalf("blobLen: %v", err)
	}
	if _, err := r.Bytes(int(blobLen)); err != nil {
		t.Fatalf("blob: %v", err)
	}
	fighterID, err = r.I64()
	if err != nil {
		t.Fatalf("fighterId: %v", err)
	}
	e, err := r.U16()
	if err != nil {
		t.Fatalf("expiry: %v", err)
	}
	expiry = int16(e)
	if _, err := r.U8(); err != nil {
		t.Fatalf("flag: %v", err)
	}
	return actionID, fighterID, expiry
}

// TestBuffExpiryIsAbsoluteNotRemaining is the trap this whole feature turns on.
//
// The client stores a buff's duration as an ABSOLUTE mark against that fighter's
// own turn counter (`aGT` builds it as `alh_1.aAy() + duration`) and reads what
// is left back as `expiry - aAy()`. Sending the REMAINING count instead - the
// obvious thing, and what the server actually stores - would make every restored
// buff look already expired on a fighter that has taken any turns.
func TestBuffExpiryIsAbsoluteNotRemaining(t *testing.T) {
	ff := &FightFighter{WireID: 77, turnsTaken: 5}
	b := &activeBuff{turnsLeft: 3}

	if got := buffExpiryMark(ff, b); got != 8 {
		t.Errorf("expiry = %d, want 8 (turnsTaken 5 + turnsLeft 3); the client "+
			"reads remaining as expiry-aAy(), so a raw remaining count of 3 would "+
			"read as -2 turns left", got)
	}
}

// TestInfiniteBuffIsNegative: akv_0.isInfinite() is `NC < 0`, which is how a
// permanent buff (a mask's malus, for instance) must be expressed.
func TestInfiniteBuffIsNegative(t *testing.T) {
	ff := &FightFighter{WireID: 77, turnsTaken: 5}
	b := &activeBuff{turnsLeft: 0, infinite: true}

	if got := buffExpiryMark(ff, b); got >= 0 {
		t.Errorf("infinite buff expiry = %d, want negative - the client tests "+
			"NC < 0 for infinite, so a 0 here expires it immediately", got)
	}
}

// TestAttachBuffWireShape pins the frame against rq_2's own reader.
func TestAttachBuffWireShape(t *testing.T) {
	blob := buildEffectBlob(42, 11, 22, Pos{X: 1, Y: 2, Z: 0}, 7)
	frame, err := buildAttachBuff(9, blob, 22, 8)
	if err != nil {
		t.Fatalf("build: %v", err)
	}
	actionID, fighterID, expiry := decodeAttachBuff(t, frame)
	if actionID != 9 {
		t.Errorf("actionId = %d, want 9", actionID)
	}
	if fighterID != 22 {
		t.Errorf("fighterId = %d, want 22 (the buff's owner)", fighterID)
	}
	if expiry != 8 {
		t.Errorf("expiry = %d, want 8", expiry)
	}
}

// TestTurnCounterMirrorsTheClient: the expiry is only meaningful if our counter
// advances exactly when the client's does - once per turn that fighter takes.
func TestTurnCounterMirrorsTheClient(t *testing.T) {
	f, a, _ := aiMeleeFight(t)
	before := a.turnsTaken
	f.beginTurn(a)
	if a.turnsTaken != before+1 {
		t.Fatalf("turnsTaken %d -> %d, want +1 per turn begun",
			before, a.turnsTaken)
	}
	f.beginTurn(a)
	if a.turnsTaken != before+2 {
		t.Errorf("turnsTaken = %d after two turns, want %d",
			a.turnsTaken, before+2)
	}
}

// TestResyncReattachesLiveBuffs drives the real resync path (resume and
// spectate share it): a living fighter's buff comes back as one 8121 with its
// absolute expiry, and a dead fighter's buff is not sent at all.
func TestResyncReattachesLiveBuffs(t *testing.T) {
	f, a, b := aiMeleeFight(t)
	a.turnsTaken = 2
	a.Buffs = append(a.Buffs, &activeBuff{actionID: 9, effectID: 77, turnsLeft: 3})
	b.Buffs = append(b.Buffs, &activeBuff{actionID: 9, effectID: 78, turnsLeft: 3})
	b.HP = 0

	d := &Deps{Log: testLogger()}
	s := &Session{log: testLogger(), deps: d, out: make(chan []byte, writeQueueSize),
		quit: make(chan struct{}), Coach: &domain.Coach{ID: 999, Name: "viewer"}}
	d.sendFightResync(s, f, true)
	close(s.out)

	var got []int64
	for frame := range s.out {
		if binary.BigEndian.Uint16(frame[2:4]) != protocol.OpRunScriptedEffect {
			continue
		}
		_, fid, expiry := decodeAttachBuff(t, frame)
		if fid == a.WireID && expiry != 5 {
			t.Errorf("expiry = %d, want 5 (turnsTaken 2 + 3 left)", expiry)
		}
		got = append(got, fid)
	}
	if len(got) != 1 || got[0] != a.WireID {
		t.Fatalf("8121 fighters = %v, want only the living one (%d)", got, a.WireID)
	}
}
