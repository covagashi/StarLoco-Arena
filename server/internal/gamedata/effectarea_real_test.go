package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestLoadStaticEffectsReal decodes every trap/glyph template (type 210) from
// the real 2.70 data and validates the parser against the known shipped records:
// the two canonical TRAP templates (id=1 point single-shape, id=2 circle radius
// 2) and the SPECIAL map tiles. A wrong layout would mis-decode the type string,
// area shape or the inner-effect list. Skips without client data.
func TestLoadStaticEffectsReal(t *testing.T) {
	if _, err := os.Stat(clientBdataDir + `\data.bdat`); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	se, err := st.LoadStaticEffects()
	if err != nil {
		t.Fatal(err)
	}
	if se.Len() == 0 {
		t.Fatal("no static-effect templates decoded — type-210 layout is wrong")
	}

	traps, specials := 0, 0
	for _, s := range se.byID {
		switch s.Type {
		case "TRAP":
			traps++
		case "SPECIAL":
			specials++
		default:
			t.Errorf("template %d has unexpected type %q (string field misaligned)", s.ID, s.Type)
		}
		if s.AreaShape <= 0 {
			t.Errorf("template %d has non-positive areaShape %d", s.ID, s.AreaShape)
		}
	}
	t.Logf("decoded %d static-effect templates (%d TRAP, %d SPECIAL)", se.Len(), traps, specials)
	if traps == 0 {
		t.Error("no TRAP templates decoded")
	}
	if specials == 0 {
		t.Error("no SPECIAL templates decoded")
	}

	// id=1: the canonical single-shape neutral trap (walk-on trigger 10001, two
	// inner HP-loss effects action id 1).
	t1 := se.Get(1)
	if t1 == nil {
		t.Fatal("template 1 (trap) missing")
	}
	if t1.Type != "TRAP" || t1.AreaShape != 1 {
		t.Errorf("template 1: type=%q shape=%d, want TRAP/1", t1.Type, t1.AreaShape)
	}
	if !containsI32Test(t1.AppTriggers, 10001) {
		t.Errorf("template 1 appTriggers=%v, want to contain 10001 (walk-on)", t1.AppTriggers)
	}
	if len(t1.Effects) != 2 || t1.Effects[0].ActionID != 1 {
		t.Errorf("template 1 inner effects = %d (first action %d), want 2 × action 1",
			len(t1.Effects), firstActionID(t1.Effects))
	}

	// id=2: circle radius 2 (areaSize [2]).
	if t2 := se.Get(2); t2 == nil {
		t.Error("template 2 (circle trap) missing")
	} else if t2.AreaShape != 2 || len(t2.AreaSize) == 0 || t2.AreaSize[0] != 2 {
		t.Errorf("template 2: shape=%d size=%v, want shape 2 size [2]", t2.AreaShape, t2.AreaSize)
	}
}

func containsI32Test(s []int32, v int32) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}

func firstActionID(e []Effect) int32 {
	if len(e) == 0 {
		return -1
	}
	return e[0].ActionID
}

// TestStaticEffectsUnusedFieldsReal pins why the server applies neither the
// application condition (yl_1.d), ack_1.ahJ nor the re-trigger delay
// (yl_1.FH): every shipped template leaves them at zero / empty (S19). It
// also pins the trigger ids to the six the client knows (he_1.a, B-076). Runs
// on the committed data-dist.
func TestStaticEffectsUnusedFieldsReal(t *testing.T) {
	st, err := Open(filepath.Join("..", "..", "data-dist"))
	if err != nil {
		t.Skip("no data-dist; skipping")
	}
	se, err := st.LoadStaticEffects()
	if err != nil {
		t.Fatal(err)
	}
	if se.Len() != 16 {
		t.Errorf("templates = %d, want 16", se.Len())
	}
	known := map[int32]bool{10000: true, 10001: true, 10002: true, 10003: true, 10006: true, 10008: true}
	for id, s := range se.All() {
		if s.AppCondition != 0 || s.Field6 != 0 || len(s.RetriggerDelay) != 0 {
			t.Errorf("template %d: appCondition=%d field6=%d delay=%v, want 0/0/[] (the server ignores them)",
				id, s.AppCondition, s.Field6, s.RetriggerDelay)
		}
		for _, tr := range append(append([]int32{}, s.AppTriggers...), s.UnappTriggers...) {
			if !known[tr] {
				t.Errorf("template %d: unknown trigger %d", id, tr)
			}
		}
	}
	if a := se.Get(1).Animation; a != 109 {
		t.Errorf("template 1 animation = %d, want 109", a)
	}
}
