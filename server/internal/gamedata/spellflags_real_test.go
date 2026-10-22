package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestDumpSpellFlagsReal verifies the targeting-flag LABELS (fields 14/15/16 =
// TestLoS/OnlyLine/NeedFreeCell) against the shipped 2.70 data by correlating
// them with damage spells. The decisive invariant: a DAMAGE spell targets an
// enemy fighter, so its cell is occupied — it must NOT have NeedFreeCell set. If
// the field labeled NeedFreeCell were actually (say) TestLoS, most damage spells
// would light it up, exposing the mislabel. Skips without client data.
func TestDumpSpellFlagsReal(t *testing.T) {
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

	var total, los, line, free int
	var dmgTotal, dmgLoS, dmgLine, dmgFree int
	logged := 0
	for _, s := range sp.byID {
		total++
		if s.TestLoS {
			los++
		}
		if s.OnlyLine {
			line++
		}
		if s.NeedFreeCell {
			free++
		}
		_, _, isDmg := s.Damage()
		if isDmg {
			dmgTotal++
			if s.TestLoS {
				dmgLoS++
			}
			if s.OnlyLine {
				dmgLine++
			}
			if s.NeedFreeCell {
				dmgFree++
			}
			if logged < 12 {
				t.Logf("dmg spell %d breed=%d rng=%d-%d LoS=%v line=%v free=%v",
					s.ID, s.BreedID, s.RangeMin, s.RangeMax, s.TestLoS, s.OnlyLine, s.NeedFreeCell)
				logged++
			}
		}
	}
	t.Logf("all %d spells: TestLoS=%d OnlyLine=%d NeedFreeCell=%d", total, los, line, free)
	t.Logf("%d damage spells: TestLoS=%d OnlyLine=%d NeedFreeCell=%d", dmgTotal, dmgLoS, dmgLine, dmgFree)

	// Invariant: a damage spell targets a fighter (occupied cell) -> NeedFreeCell
	// must be false. Allow a tiny slack for odd data, but a large count means the
	// field is mislabeled.
	if dmgTotal > 0 && dmgFree*2 > dmgTotal {
		t.Errorf("NeedFreeCell set on %d/%d damage spells — field 16 looks MISLABELED", dmgFree, dmgTotal)
	}
	// Sanity: flags must not be all-true or all-false (that'd mean we read a fixed
	// byte, i.e. a wrong offset).
	if los == 0 || los == total {
		t.Errorf("TestLoS is uniform (%d/%d) — likely wrong offset", los, total)
	}
}
