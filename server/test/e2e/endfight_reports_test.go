package e2e

import (
	"testing"
	"time"

	"github.com/StarLoco/arena-2.70/internal/game"
	"github.com/StarLoco/arena-2.70/internal/store"
	"github.com/StarLoco/arena-2.70/internal/testclient"
)

// assertEndFightReportsAreRosterIDs decodes the per-fighter report block out of
// a real END_FIGHT (8300) payload and checks every id against the recipient's
// roster.
//
// This exists because the same mistake can be made in two independent places —
// the id the report is built with, and which coach's reports end up in which
// frame — and neither is visible from a unit test of the packet builder. Both
// produce the same symptom: the client cannot resolve the id in its own roster,
// `adY.atu().dz(id).a(...)` throws, and no result dialog opens at all.
func assertEndFightReportsAreRosterIDs(t *testing.T, st *store.Store, payload []byte, coachID int64) {
	t.Helper()

	r := testclient.NewR(payload)
	r.I32() // action uid
	r.I32() // action header, second word
	r.U8()  // flee flag

	// Two [i32 n]{[i64][i32]} strength maps.
	for i := 0; i < 2; i++ {
		n := r.I32()
		for j := int32(0); j < n; j++ {
			r.I64()
			r.I32()
		}
	}
	// Two [u8 n]{[i64][i16][i16 len][bytes]} result lists.
	for i := 0; i < 2; i++ {
		n := r.U8()
		for j := uint8(0); j < n; j++ {
			r.I64()
			r.U16()
			r.RawN(int(r.U16()))
		}
	}
	// Two card blobs, each [u16 len][bytes].
	for i := 0; i < 2; i++ {
		r.RawN(int(r.U16()))
	}

	// The report block itself.
	n := r.U8()
	if n == 0 {
		t.Fatal("END_FIGHT carried no per-fighter reports; this check needs at least one")
	}

	// Everything the recipient could legitimately be sent.
	roster := map[int64]bool{}
	fighters, err := st.Fighters.ListByCoach(uint(coachID))
	if err != nil {
		t.Fatalf("list roster: %v", err)
	}
	for _, f := range fighters {
		roster[int64(f.ID)] = true
	}

	for i := uint8(0); i < n; i++ {
		id := r.I64()
		r.RawN(int(r.U16()))

		if id >= game.FighterWireIDBase {
			t.Errorf("report %d is keyed by %d, which is a fight WIRE id; the client "+
				"looks reports up in its roster and throws on a miss, so the result "+
				"dialog never opens", i, id)
			continue
		}
		if !roster[id] {
			t.Errorf("report %d is for fighter %d, which is not in coach %d's roster "+
				"(%v); the client cannot resolve another coach's fighter either",
				i, id, coachID, roster)
		}
	}
}

// TestEndFightReportsResolveInTheRecipientsRoster is the end-to-end guard for
// B-096. It needs a fight that actually produces debriefs, which means real
// roster fighters (progression skips placeholder fighters with id 0) and an
// EVOLUTION fight between two coaches: since S21 only Evolution and Historia
// fights bank per-fighter reports (a ranked Elite fight leaves its fighters
// as they were), so this pairs two coaches through the evolution search.
func TestEndFightReportsResolveInTheRecipientsRoster(t *testing.T) {
	t.Parallel()
	if raceEnabled {
		t.Skip("timing-sensitive full-fight E2E; flaky under -race's slowdown")
	}
	st, addr := testServerWithStore(t)

	a, aID := dialLogin(t, addr, "c1", "Combatant1")
	reachWorld(t, a)
	b, bID := dialLogin(t, addr, "c2", "Combatant2")
	reachWorld(t, b)
	giveTitulars(t, st.Fighters, aID, "Debrief A")
	giveTitulars(t, st.Fighters, bID, "Debrief B")
	a.DrainReceived(150 * time.Millisecond)
	b.DrainReceived(150 * time.Millisecond)
	_ = a.Send(2, opEvoSearchRequest, evoSearchPayload(aID))
	if _, _, err := a.WaitFor(opEvoSearchResult, testclient.DefaultTimeout); err != nil {
		t.Fatalf("A: no 23004: %v", err)
	}
	_ = b.Send(2, opEvoSearchRequest, evoSearchPayload(bID))
	for _, c := range []*testclient.Client{a, b} {
		if _, _, err := c.WaitFor(testclient.OpCreateFight, testclient.DefaultTimeout); err != nil {
			t.Fatalf("no CREATE_FIGHT from the evolution pairing: %v", err)
		}
	}
	a.DrainReceived(150 * time.Millisecond)
	b.DrainReceived(150 * time.Millisecond)
	readyGate(a, b, testclient.OpReadyForPlacement)
	readyGate(a, b, testclient.OpReadyForObservation)
	_ = a.Send(3, testclient.OpReadyForAction, nil)
	_ = b.Send(3, testclient.OpReadyForAction, nil)
	a.DrainReceived(200 * time.Millisecond)
	b.DrainReceived(200 * time.Millisecond)

	// A gives up, so B wins and both receive END_FIGHT.
	_ = a.Send(3, testclient.OpGiveUp, nil)

	winner, err := st.Coaches.GetByName("Combatant2")
	if err != nil {
		t.Fatalf("get winner: %v", err)
	}
	end, _, err := b.WaitFor(testclient.OpEndFight, testclient.DefaultTimeout)
	if err != nil {
		t.Fatalf("winner got no END_FIGHT: %v", err)
	}
	assertEndFightReportsAreRosterIDs(t, st, end.Payload, int64(winner.ID))

	// The loser's frame has to be right too — and it is the one that would
	// carry the winner's fighters if the reports were not scoped per coach.
	loser, err := st.Coaches.GetByName("Combatant1")
	if err != nil {
		t.Fatalf("get loser: %v", err)
	}
	if endA, _, err := a.WaitFor(testclient.OpEndFight, testclient.DefaultTimeout); err == nil {
		assertEndFightReportsAreRosterIDs(t, st, endA.Payload, int64(loser.ID))
	}
}
