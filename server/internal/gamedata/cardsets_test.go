package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestLoadCardSetsReal locks the type-101 decode and the threshold model. The
// engine rule is the PER-EFFECT threshold (client sj_1: apply when
// threshold <= equipped count of that set); fe_1's half/full split is only UI.
func TestLoadCardSetsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	sets, err := st.LoadCardSets()
	if err != nil {
		t.Fatal(err)
	}
	if sets.Len() == 0 {
		t.Fatal("no card sets decoded")
	}

	// Every set the cards point at must exist, and vice versa: membership runs
	// from the coach card's CardSet field, so a mismatch means one of the two
	// records is misdecoded.
	cards, err := st.LoadCards()
	if err != nil {
		t.Fatal(err)
	}
	members := map[int32]int{}
	for _, c := range cards.All() {
		if c.CardSet != 0 {
			members[c.CardSet]++
		}
	}
	for setID := range members {
		if sets.Get(setID) == nil {
			t.Errorf("cards reference set %d but no such set record exists", setID)
		}
	}

	nEffects, resurrect := 0, 0
	for _, id := range sets.IDs() {
		cs := sets.Get(id)
		for _, ef := range cs.Effects {
			nEffects++
			if ef.Action == 13 {
				resurrect++
			}
			// Canaries: a field-order slip in akw_0 blows these ranges out.
			if ef.Threshold == 0 || ef.Threshold > 20 {
				t.Errorf("set %d: implausible threshold %d", id, ef.Threshold)
			}
			if ef.Action <= 0 || ef.Action > 30 {
				t.Errorf("set %d: action %d is outside the AI enum (1..21)", id, ef.Action)
			}
			if len(ef.Params) == 0 {
				t.Errorf("set %d action %d: no params", id, ef.Action)
			}
		}
	}
	if nEffects == 0 {
		t.Fatal("no set effects decoded")
	}
	if resurrect == 0 {
		t.Error("no set grants resurrection (AI 13); that is the one bonus the server consumes")
	}
	t.Logf("%d sets, %d effects (%d grant resurrection), %d sets referenced by cards",
		sets.Len(), nEffects, resurrect, len(members))
}

// TestCardSetActiveEffects pins the threshold rule itself.
func TestCardSetActiveEffects(t *testing.T) {
	cs := &CardSet{ID: 1, Effects: []CardSetEffect{
		{Action: 13, Params: []int32{5}, Threshold: 2},
		{Action: 13, Params: []int32{20}, Threshold: 5},
		{Action: 1, Params: []int32{10}, Threshold: 3},
	}}
	if got := len(cs.ActiveEffects(0)); got != 0 {
		t.Errorf("no cards equipped unlocked %d effects, want 0", got)
	}
	if got := len(cs.ActiveEffects(1)); got != 0 {
		t.Errorf("1 card unlocked %d effects, want 0 (lowest threshold is 2)", got)
	}
	if got := len(cs.ActiveEffects(2)); got != 1 {
		t.Errorf("2 cards unlocked %d effects, want 1", got)
	}
	if got := len(cs.ActiveEffects(4)); got != 2 {
		t.Errorf("4 cards unlocked %d effects, want 2", got)
	}
	if got := len(cs.ActiveEffects(5)); got != 3 {
		t.Errorf("5 cards unlocked %d effects, want all 3", got)
	}
	var nilSet *CardSet
	if got := nilSet.ActiveEffects(10); got != nil {
		t.Error("a nil set should unlock nothing")
	}
}
