package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLoadSpellsReal(t *testing.T) {
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
	if sp.Len() == 0 {
		t.Fatal("no spells loaded")
	}
	n := 0
	for _, s := range sp.byID {
		if n < 6 {
			t.Logf("spell %d breed=%d value=%d AP=%d range=%d-%d",
				s.ID, s.BreedID, s.Value, s.AP, s.RangeMin, s.RangeMax)
		}
		n++
		if s.AP < 0 || s.AP > 12 {
			t.Errorf("spell %d implausible AP=%d", s.ID, s.AP)
		}
	}
}

// TestSpellCastLimitsReal pins the four cast-limit fields to the real data. They
// are easy to confuse and were: the COOLDOWN is field 10, not field 8.
//
// Each maps to a different bucket of the client's cast-history tracker `sH`:
// field 7 -> per-target cap, field 8 -> max live instances, field 9 -> per-turn
// cap, field 10 -> cooldown in table turns (63 = once per fight).
func TestSpellCastLimitsReal(t *testing.T) {
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

	var withCooldown, oncePerFight, withMaxActive int
	for _, s := range sp.All() {
		if s.Cooldown != 0 {
			withCooldown++
		}
		if s.Cooldown == 63 {
			oncePerFight++
		}
		if s.MaxActive != 0 {
			withMaxActive++
		}
	}
	// The canary: cooldowns are COMMON (about half the spell book) while the
	// max-active cap is rare. Reading the cooldown off field 8 inverted this and
	// left 97 spells — 28 of them once-per-fight — with no limit at all.
	if withCooldown < 50 {
		t.Errorf("only %d spells have a cooldown; the cooldown is field 10 (es/iV), "+
			"not field 8 — check the field order", withCooldown)
	}
	if oncePerFight == 0 {
		t.Error("no spell is once-per-fight (cooldown 63); field 10 is likely misread")
	}
	if withMaxActive > withCooldown {
		t.Errorf("maxActive (%d) should be far rarer than cooldown (%d); fields 8 and 10 look swapped",
			withMaxActive, withCooldown)
	}
	t.Logf("%d spells: %d with a cooldown (%d once-per-fight), %d with a max-active cap",
		sp.Len(), withCooldown, oncePerFight, withMaxActive)
}
