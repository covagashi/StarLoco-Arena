package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestCardResurrectPercentReal pins the resurrection-effect decode against the
// real card table. The percentages are read from each card's effect array
// (action 13, param[0]); getting the aPp field layout wrong (e.g. the i32
// floatParams count) would misalign the array and yield garbage, so this asserts
// the exact known values and that NO other card is mistaken for a resurrection
// card.
func TestCardResurrectPercentReal(t *testing.T) {
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Skipf("game data not available: %v", err)
	}
	cards, err := st.LoadCards()
	if err != nil {
		t.Fatalf("LoadCards: %v", err)
	}

	want := map[int32]int32{
		35: 5, 51: 12, 53: 10, 137: 1,
		305: 100, 316: 100, 317: 100, 318: 100,
	}
	for id, pct := range want {
		c := cards.Get(id)
		if c == nil {
			t.Errorf("card %d missing", id)
			continue
		}
		if c.ResurrectPercent != pct {
			t.Errorf("card %d ResurrectPercent = %d, want %d", id, c.ResurrectPercent, pct)
		}
	}

	// Exactly the eight known cards carry a resurrection effect, and every percent
	// is in range â€” a misaligned decode would flag extra cards or wild values.
	got := 0
	for _, c := range cards.All() {
		if c.ResurrectPercent == 0 {
			continue
		}
		got++
		if _, ok := want[c.ID]; !ok {
			t.Errorf("unexpected resurrection card %d (%d%%)", c.ID, c.ResurrectPercent)
		}
		if c.ResurrectPercent < 1 || c.ResurrectPercent > 100 {
			t.Errorf("card %d ResurrectPercent = %d out of 1..100 (decode misaligned?)",
				c.ID, c.ResurrectPercent)
		}
	}
	if got != len(want) {
		t.Errorf("resurrection card count = %d, want %d", got, len(want))
	}
}

// TestCoachCardFullDecodeReal pins the fields beyond the header that used to be
// skipped. The two tradability flags are the ones that matter: the server, not the
// client, has to police what may be staked in an exchange.
func TestCoachCardFullDecodeReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	cards, err := st.LoadCards()
	if err != nil {
		t.Fatal(err)
	}

	var bound, undestructible, withLevel, obtainable, ranked, usable int
	for id, c := range cards.All() {
		if c.Bound {
			bound++
		}
		if c.Undestructible {
			undestructible++
		}
		if c.RequiredLevel > 0 {
			withLevel++
		}
		if c.ObtainableInDraw {
			obtainable++
		}
		if c.Rank > 0 {
			ranked++
		}
		if c.HasUsableAction {
			usable++
		}
		// Canaries against a field-order slip: these are all small bounded values.
		if c.RequiredLevel < 0 || c.RequiredLevel > 200 {
			t.Errorf("card %d: implausible requiredLevel %d", id, c.RequiredLevel)
		}
		if c.Rank < 0 || c.Rank > 100 {
			t.Errorf("card %d: implausible rank %d", id, c.Rank)
		}
		if c.DropPercent < 0 || c.DropPercent > 100 {
			t.Errorf("card %d: implausible dropPercent %d", id, c.DropPercent)
		}
	}
	if ranked == 0 {
		t.Error("no card has a rank; field 18 is misaligned")
	}
	if bound == 0 && undestructible == 0 {
		t.Error("no card is bound or undestructible; fields 12/13 look misaligned")
	}
	t.Logf("%d cards: bound=%d undestructible=%d requiredLevel>0=%d obtainable=%d ranked=%d usable=%d",
		cards.Len(), bound, undestructible, withLevel, obtainable, ranked, usable)
}

// TestResurrectionConsumablesAreEvolutionTypeShipped pins, on the shipped
// data-dist, the split the graveyard handler relies on: the four resurrection
// cards are Evolution consumables (type 24, the only type the retail graveyard
// offers), while the four equipment cards that also carry the effect (their
// chance to come back during a fight) are not. If a data update ever moved one
// across, the handler's CardTypeEvolution gate would silently change meaning.
func TestResurrectionConsumablesAreEvolutionTypeShipped(t *testing.T) {
	root := filepath.Join("..", "..", "data-dist")
	if _, err := os.Stat(filepath.Join(root, "data.bdat")); err != nil {
		t.Skipf("shipped data unavailable: %v", err)
	}
	st, err := Open(root)
	if err != nil {
		t.Fatalf("open: %v", err)
	}
	cards, err := st.LoadCards()
	if err != nil {
		t.Fatalf("LoadCards: %v", err)
	}
	for id, evolution := range map[int32]bool{
		305: true, 316: true, 317: true, 318: true, // Resurrection ×4
		35: false, 51: false, 53: false, 137: false, // apron, helmet, banner, Weerdtrot Jacket
	} {
		c := cards.Get(id)
		if c == nil {
			t.Errorf("card %d missing", id)
			continue
		}
		if c.ResurrectPercent <= 0 {
			t.Errorf("card %d has no resurrection effect", id)
		}
		if got := c.Type == CardTypeEvolution; got != evolution {
			t.Errorf("card %d type = %d, Evolution(24) = %v, want %v", id, c.Type, got, evolution)
		}
	}
}
