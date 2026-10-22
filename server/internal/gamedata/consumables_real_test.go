package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestConsumableCardsReal pins the shipped consumable population. The card
// decoder used to keep only the resurrection percentage out of the effect array
// and throw the rest away, which silently made every other usable card inert —
// this is the canary against that regression returning.
func TestConsumableCardsReal(t *testing.T) {
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

	var usable, withEffects int
	byAction := map[int32]int{}
	for _, c := range cards.All() {
		if c.HasUsableAction {
			usable++
		}
		if len(c.Effects) > 0 {
			withEffects++
		}
		seen := map[int32]bool{}
		for _, ef := range c.Effects {
			if c.HasUsableAction && !seen[ef.Action] {
				byAction[ef.Action]++
				seen[ef.Action] = true
			}
		}
	}
	if cards.Len() != 907 {
		t.Errorf("decoded %d cards, want 907", cards.Len())
	}
	if usable != 325 {
		t.Errorf("%d usable cards, want 325", usable)
	}
	if withEffects == 0 {
		t.Fatal("no card carries an effect array — the akw_0 decode is broken")
	}

	// The consumable actions the server implements, with their shipped counts.
	// If one of these drops to 0 the corresponding feature has gone dark.
	want := map[int32]struct {
		n    int
		what string
	}{
		2:  {4, "grant XP"},
		5:  {30, "heal serious wounds"},
		9:  {8, "change morale"},
		11: {30, "heal light wounds"},
		13: {4, "resurrect"},
		15: {165, "apply a condition"},
		16: {8, "change fatigue"},
	}
	for action, w := range want {
		if byAction[action] != w.n {
			t.Errorf("AI %d (%s): %d usable cards, want %d", action, w.what, byAction[action], w.n)
		}
	}

	// Resurrection percentages must still be derived from the effect array after
	// the refactor that started keeping the whole list.
	for id, pct := range map[int32]int32{305: 100, 316: 100, 51: 12, 53: 10, 35: 5, 137: 1} {
		c := cards.Get(id)
		if c == nil {
			t.Errorf("card %d missing", id)
			continue
		}
		if c.ResurrectPercent != pct {
			t.Errorf("card %d resurrect = %d%%, want %d%%", id, c.ResurrectPercent, pct)
		}
	}

	// Every AI-15 card must carry BOTH params (conditionId, duration) — the
	// server reads params[1] directly, so a one-param row would apply a
	// zero-duration condition.
	var bad int
	for _, c := range cards.All() {
		if !c.HasUsableAction {
			continue
		}
		for _, ef := range c.Effects {
			if ef.Action == 15 && len(ef.Params) < 2 {
				bad++
			}
		}
	}
	if bad != 0 {
		t.Errorf("%d usable AI-15 effects carry fewer than 2 params", bad)
	}
}
