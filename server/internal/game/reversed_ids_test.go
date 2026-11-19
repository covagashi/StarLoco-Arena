package game

import (
	"testing"

	"github.com/StarLoco/arena-2.70/internal/protocol"
)

// TestReversedIDsReadsAWholeRoster (S48): a 23114 from a coach with 70
// fighters (a roster holds up to 100) must leave the reader on the accept
// byte; it used to stop at 64 ids without reading them, so the accept read
// as a decline.
func TestReversedIDsReadsAWholeRoster(t *testing.T) {
	w := protocol.NewWriter()
	w.I32(70)
	for i := int64(70); i >= 1; i-- {
		w.I64(i)
	}
	w.U8(1)
	r := protocol.NewReader(w.Bytes())
	ids, err := readReversedIDs(r)
	if err != nil || len(ids) != 70 {
		t.Fatalf("ids = %d, err %v; want 70", len(ids), err)
	}
	if b, err := r.U8(); err != nil || b != 1 {
		t.Errorf("byte after the roster = %d (%v), want the accept 1", b, err)
	}
	w = protocol.NewWriter()
	w.I32(maxFightersPerCoach + 1)
	if _, err := readReversedIDs(protocol.NewReader(w.Bytes())); err == nil {
		t.Error("a roster bigger than any coach can own was accepted")
	}
}
