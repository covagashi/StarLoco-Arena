package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestSummonInnateFlagsReal pins the type-300 tail that used to be skipped. The
// six flags decide whether a creature can be shoved, swapped, carried or walk at
// all — a wall summon that can be pushed is a wrong-looking fight.
func TestSummonInnateFlagsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	sm, err := st.LoadSummonings()
	if err != nil {
		t.Fatal(err)
	}

	var rooted, carried, stab, intr, withBlock, withDodge int
	for id, s := range sm.All() {
		if s.Rooted {
			rooted++
			// Every shipped rooted creature also ships MP 0; if that ever stops
			// being true the rooted flag becomes the only thing pinning it down.
			if s.MP != 0 {
				t.Logf("note: rooted summon %d has MP %d — the flag is now load-bearing", id, s.MP)
			}
		}
		if s.CannotBeCarried {
			carried++
		}
		if s.Stabilised {
			stab++
		}
		if s.Intransposable {
			intr++
		}
		if s.Block != 0 {
			withBlock++
		}
		if s.Dodge != 0 {
			withDodge++
		}
		if s.Dodge < -1000 || s.Dodge > 1000 || s.Block < -1000 || s.Block > 1000 {
			t.Errorf("summon %d: implausible block/dodge %d/%d — the tail is misaligned",
				id, s.Block, s.Dodge)
		}
	}
	// Canaries: these are large, stable populations. A field-order slip would
	// collapse them to zero.
	if rooted < 10 || carried < 10 || stab < 10 || intr < 5 {
		t.Errorf("innate flags look misdecoded: rooted=%d cannotBeCarried=%d stabilised=%d intransposable=%d",
			rooted, carried, stab, intr)
	}
	if withDodge < 20 {
		t.Errorf("only %d summons have a dodge %%; the tail is probably misaligned", withDodge)
	}
	t.Logf("%d summons: rooted=%d cannotBeCarried=%d stabilised=%d intransposable=%d block!=0=%d dodge!=0=%d",
		sm.Len(), rooted, carried, stab, intr, withBlock, withDodge)
}
