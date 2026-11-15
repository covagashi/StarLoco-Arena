package gamedata

import "testing"

// TestLoadEventsReal decodes the shipped per-round event cards (type 230) and
// asserts the shape the round-card mechanic depends on. Skips when the client
// data directory is absent.
func TestLoadEventsReal(t *testing.T) {
	s, err := openContent(t)
	if err != nil {
		t.Skip(err)
	}
	events, err := s.LoadEvents()
	if err != nil {
		t.Fatalf("LoadEvents: %v", err)
	}
	if events.Len() == 0 {
		t.Fatal("no event cards decoded")
	}

	// Every record's inner id must equal the id we keyed it by: a mis-aligned
	// header (the i16 + flag byte before the effect list) would desync the whole
	// effect list, so this is the decoder's canary.
	for _, id := range events.IDs() {
		if ev := events.Get(id); ev == nil || ev.ID != id {
			t.Fatalf("event %d: decoded id mismatch (%v)", id, ev)
		}
	}

	// The base deck the round mechanic draws from — ids 1..27, exactly what the
	// 2006 client's events.dat shipped — must all be present.
	for id := int32(1); id <= roundDeckMaxIDForTest; id++ {
		if events.Get(id) == nil {
			t.Errorf("base deck card %d missing", id)
		}
	}

	// Every drawable card carries effects, and each names an action.
	//
	// Area shape is deliberately NOT asserted to be 32767 ("all"): most cards use
	// it, but event 7 ("Déesse Cra") ships areaShape=1 (point). A round card has
	// no aimed cell, so the server never resolves an event through cell-area
	// expansion — it applies each effect directly, once per living fighter,
	// filtered by the effect's target conditions (game/events.go). This assertion
	// records that the shape field is inconsistent in the shipped data and must
	// not be relied on.
	pointShaped := 0
	for id := int32(1); id <= roundDeckMaxIDForTest; id++ {
		ev := events.Get(id)
		if ev == nil {
			continue
		}
		if len(ev.Effects) == 0 {
			t.Errorf("event %d has no effects", id)
		}
		for i, ef := range ev.Effects {
			if ef.ActionID == 0 {
				t.Errorf("event %d effect %d: no actionId", id, i)
			}
			if ef.AreaShape != 32767 {
				pointShaped++
			}
		}
	}
	if pointShaped != 2 {
		t.Errorf("non-'all' event effects = %d, want 2 (both on event 7); "+
			"if this changed, re-check that events bypass area resolution", pointShaped)
	}

	// The opening-round card: "Cloué au lit" = stabilised + anchored +
	// intransposable, one table turn. If this ever changes, the forced
	// first-round draw in game/events.go must be revisited.
	ev := events.Get(14)
	if ev == nil {
		t.Fatal("event 14 (the opening-round card) missing")
	}
	want := map[int32]bool{94: false, 127: false, 128: false}
	if len(ev.Effects) != 3 {
		t.Errorf("event 14 has %d effects, want 3", len(ev.Effects))
	}
	for _, ef := range ev.Effects {
		if _, ok := want[ef.ActionID]; !ok {
			t.Errorf("event 14 carries unexpected action %d", ef.ActionID)
			continue
		}
		want[ef.ActionID] = true
		if len(ef.Duration) < 1 || ef.Duration[0] != 1 {
			t.Errorf("event 14 action %d: duration %v, want one table turn", ef.ActionID, ef.Duration)
		}
	}
	for action, seen := range want {
		if !seen {
			t.Errorf("event 14 is missing action %d", action)
		}
	}

	// A breed-god card restricts itself with the effect's own breed target
	// condition rather than any per-card field: "Dieu Iop" (1) carries the Iop
	// breed bit (1<<(8-1) << 16), so only Iops are buffed.
	iop := events.Get(1)
	if iop == nil || len(iop.Effects) == 0 {
		t.Fatal("event 1 (Dieu Iop) missing")
	}
	const iopBreedBit int64 = 1 << (8 - 1) << 16
	found := false
	for _, ef := range iop.Effects {
		for _, cond := range ef.Targets {
			if cond == iopBreedBit {
				found = true
			}
		}
	}
	if !found {
		t.Errorf("event 1 carries no Iop breed condition; targets=%v", iop.Effects[0].Targets)
	}
}

// roundDeckMaxIDForTest mirrors game.roundEventDeckMaxID (the packages cannot
// import each other).
const roundDeckMaxIDForTest int32 = 27
