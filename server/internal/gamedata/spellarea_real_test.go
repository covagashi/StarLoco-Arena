package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestSpellAreaSizeReal confirms the effect decoder reads areaSize from the
// correct (5th) post-params array: a non-point AoE shape (circle 2 / cross 3 /
// T 4 / T-inv 9) must now carry a non-empty size. Before the off-by-one fix the
// size read the empty vestigial 4th array and every zone spell collapsed to a
// point. Logs the shape->size distribution for eyeballing. Skips without data.
func TestSpellAreaSizeReal(t *testing.T) {
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

	type stat struct{ total, sized int }
	byShape := map[int32]*stat{}
	sizedNonPoint := 0
	for _, s := range sp.byID {
		for _, ef := range s.Effects {
			st := byShape[ef.AreaShape]
			if st == nil {
				st = &stat{}
				byShape[ef.AreaShape] = st
			}
			st.total++
			if len(ef.AreaSize) > 0 {
				st.sized++
				// A real zone shape (not point 1, not "all" 32767) with a size.
				if ef.AreaShape != 1 && ef.AreaShape != 0 && ef.AreaShape != 32767 {
					sizedNonPoint++
				}
			}
		}
	}
	for shape, st := range byShape {
		t.Logf("areaShape=%d: %d effects, %d with non-empty areaSize", shape, st.total, st.sized)
	}
	if sizedNonPoint == 0 {
		t.Fatal("no non-point AoE effect has a size — areaSize is still read from the wrong array")
	}
	t.Logf("OK: %d non-point AoE effects carry a radius/size", sizedNonPoint)
}
