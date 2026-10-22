package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestLoadSummoningsReal decodes every summon template (type 300) from the real
// 2.70 data and sanity-checks the stat sheet the server mirrors: plausible
// HP/AP/MP, and that both spell-casting creatures and spell-less blockers exist
// (the two ends of the summon-AI behaviour range). Skips without client data.
func TestLoadSummoningsReal(t *testing.T) {
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
	if sm.Len() == 0 {
		t.Fatal("no summon templates decoded — type-300 layout is wrong")
	}
	withSpell, blockers := 0, 0
	for _, s := range sm.byID {
		if s.HP <= 0 || s.HP > 20000 || s.AP < 0 || s.AP > 20 || s.MP < 0 || s.MP > 20 {
			t.Errorf("summon %d implausible stats hp=%d ap=%d mp=%d", s.ID, s.HP, s.AP, s.MP)
		}
		if s.PrimarySpellID() != 0 {
			withSpell++
		} else {
			blockers++
		}
	}
	t.Logf("decoded %d summon templates (%d cast a spell, %d spell-less blockers)", sm.Len(), withSpell, blockers)
	if withSpell == 0 {
		t.Error("no spell-casting summons decoded — spell-id list offset is wrong")
	}
	if blockers == 0 {
		t.Error("no spell-less blocker summons decoded — spell-count byte is wrong")
	}
}
