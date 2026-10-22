package gamedata

import (
	"os"
	"path/filepath"
	"reflect"
	"testing"
)

// TestLoadElementViewsReal locks the type-360 decode against the shipped data —
// and, more usefully, PINS THE EVIDENCE that this table is not the interactive
// element table.
//
// Roadmap item 24 used to read "decode type 360 + maps/env/*.jar and retire the
// hand-transcribed table", which implied 360 held element placements. It does not:
// it is a sprite descriptor keyed by view id. The assertions below are what make
// that checkable rather than a matter of trust, so the next person does not spend
// a session chasing it.
func TestLoadElementViewsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	views, err := st.LoadElementViews()
	if err != nil {
		t.Fatal(err)
	}

	// Population canary: retail ships 42 records, ids 1..42.
	if n := views.Len(); n != 42 {
		t.Fatalf("loaded %d element views, want 42", n)
	}
	for id := int32(1); id <= 42; id++ {
		if views.Get(id) == nil {
			t.Errorf("view id %d missing", id)
		}
	}

	// The shape that proves it is only art: of the five live fields, only GFX
	// varies. If a future data set breaks any of these, this table is richer than
	// we think and item 24's reasoning deserves a re-read.
	var gfxSeen = map[int32]bool{}
	for id, v := range views.All() {
		if v.Type != 0 {
			t.Errorf("view %d: Type = %d, want 0 (constant across retail data)", id, v.Type)
		}
		if v.Colour != -1 {
			t.Errorf("view %d: Colour = %d, want -1 (none)", id, v.Colour)
		}
		if v.Height != 0 {
			t.Errorf("view %d: Height = %d, want 0", id, v.Height)
		}
		if v.Unused != 0 {
			t.Errorf("view %d: trailing i32 = %d, want 0 (it has no reader in the client)",
				id, v.Unused)
		}
		if v.GFX == 0 {
			t.Errorf("view %d: GFX = 0, expected a real sprite id", id)
		}
		gfxSeen[v.GFX] = true
	}

	// GFX is the one field carrying information, so it must actually vary —
	// otherwise the decode is reading a constant and the offsets are wrong.
	if len(gfxSeen) < 30 {
		t.Errorf("only %d distinct GFX values across 42 views; the decode is "+
			"probably misaligned", len(gfxSeen))
	}

	// Nothing in the record identifies a PLACEMENT, and the 19-byte layout leaves
	// no room for one. Checked against the struct itself so that adding a field
	// (an instanceId, a world, a cell) fails here and forces whoever does it to
	// find where the value actually came from — because type 360 cannot supply it.
	if got := reflect.TypeOf(ElementView{}).NumField(); got != 6 {
		t.Errorf("ElementView has %d fields, want 6: type 360 is 19 bytes of "+
			"{id,type,gfx,colour,height,unused} and carries no placement data. "+
			"See ROADMAP item 24 — placements come from maps/env/*.jar.", got)
	}
}
