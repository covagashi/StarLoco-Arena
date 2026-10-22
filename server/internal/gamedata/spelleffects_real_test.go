package gamedata

import (
	"os"
	"path/filepath"
	"sort"
	"testing"
)

// TestSpellEffectsReal verifies spell effect decoding against the shipped 2.70
// data: it confirms damage spells resolve to a plausible flat-damage amount via
// Spell.Damage() (the real per-effect magnitude, not the budget Value) and that
// heal spells are detected. Skips without client data.
func TestSpellEffectsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	sp, err := st.LoadSpells()
	if err != nil {
		t.Fatal(err)
	}
	t.Logf("loaded %d spells", sp.Len())

	ids := make([]int32, 0, sp.Len())
	for id := range sp.byID {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })

	damageSpells, healSpells, withEffects := 0, 0, 0
	logged := 0
	for _, id := range ids {
		s := sp.byID[id]
		if len(s.Effects) > 0 {
			withEffects++
		}
		amount, elem, ok := s.Damage()
		if ok {
			damageSpells++
			if amount <= 0 || amount > 500 {
				t.Errorf("spell %d implausible damage %d", id, amount)
			}
			if logged < 15 {
				t.Logf("spell %d breed=%d AP=%d value=%d -> damage=%d elem=%d", id, s.BreedID, s.AP, s.Value, amount, elem)
				logged++
			}
		}
		if s.IsHeal() {
			healSpells++
		}
	}
	t.Logf("%d/%d spells have effects; %d deal flat damage; %d heal", withEffects, sp.Len(), damageSpells, healSpells)
	if withEffects == 0 {
		t.Fatal("no spell effects decoded — header/effect-list offset is wrong")
	}
	if damageSpells == 0 {
		t.Fatal("no damage spells decoded — flat-damage action-id map or params are wrong")
	}
}
