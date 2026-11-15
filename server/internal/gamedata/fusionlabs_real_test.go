package gamedata

import (
	"sort"
	"testing"
)

// TestLoadFusionLabsReal pins the type-1100 decode. The record is only 12 bytes,
// so a field-order slip would still "decode" and just produce nonsense — the
// assertions below are about plausibility, not just parsing.
func TestLoadFusionLabsReal(t *testing.T) {
	st, err := openContent(t)
	if err != nil {
		t.Fatal(err)
	}
	labs, err := st.LoadFusionLabs()
	if err != nil {
		t.Fatal(err)
	}
	if labs.Len() == 0 {
		t.Fatal("no fusion labs decoded")
	}

	ids := make([]int64, 0, labs.Len())
	for id := range labs.All() {
		ids = append(ids, id)
	}
	sort.Slice(ids, func(i, j int) bool { return ids[i] < ids[j] })
	for _, id := range ids {
		l := labs.Get(id)
		t.Logf("lab %d: power=%d quality=%d slots=%d (stored %d)",
			l.ID, l.Power, l.Quality, l.Slots-1, l.Slots)
		// The client renders `azi() - 1` as the slot count, so the stored value
		// must be at least 1 or the panel would show a negative number of slots.
		if l.Slots < 1 {
			t.Errorf("lab %d: stored slot count %d < 1, so the client would render %d slots",
				l.ID, l.Slots, int(l.Slots)-1)
		}
		if l.Power < 0 {
			t.Errorf("lab %d: negative power %d", l.ID, l.Power)
		}
	}

	// Default() must be deterministic and the lowest id.
	if d := labs.Default(); d == nil || d.ID != ids[0] {
		t.Errorf("Default() = %v, want the lowest id %d", d, ids[0])
	}
}
