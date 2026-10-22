package gamedata

import (
	"os"
	"path/filepath"
	"testing"
)

// TestLoadEquipmentPoolsReal locks the type-251 decode against the shipped data,
// and cross-checks it against the Sphere Board: an Item node names a pool, so
// every pool a node points at must exist and every pool must be pointed at.
func TestLoadEquipmentPoolsReal(t *testing.T) {
	if _, err := os.Stat(filepath.Join(clientBdataDir, "data.bdat")); err != nil {
		t.Skip("no client data")
	}
	st, err := Open(clientBdataDir)
	if err != nil {
		t.Fatal(err)
	}
	pools, err := st.LoadEquipmentPools()
	if err != nil {
		t.Fatalf("load: %v", err)
	}
	if got, want := pools.Len(), 11; got != want {
		t.Errorf("decoded %d pools, want %d", got, want)
	}
	for _, id := range pools.IDs() {
		p := pools.Get(id)
		if lo := p.Leftover(); lo != 0 {
			t.Errorf("pool %d: %d bytes unconsumed - the layout is wrong", id, lo)
		}
		if len(p.CardIDs) == 0 {
			t.Errorf("pool %d unlocks nothing", id)
		}
		for _, c := range p.CardIDs {
			if c <= 0 {
				t.Errorf("pool %d names card id %d", id, c)
			}
		}
	}

	// The Sphere Board is the independent oracle: pools exist to be unlocked.
	sb, err := st.LoadSphereBoards()
	if err != nil {
		t.Fatalf("spheres: %v", err)
	}
	referenced := map[int32]bool{}
	for _, bid := range sb.BoardIDs() {
		for _, s := range sb.SpheresOf(bid) {
			if s.EquipmentPoolID == 0 {
				continue
			}
			referenced[s.EquipmentPoolID] = true
			if pools.Get(s.EquipmentPoolID) == nil {
				t.Errorf("sphere %d unlocks pool %d, which does not exist",
					s.ID, s.EquipmentPoolID)
			}
		}
	}
	if len(referenced) == 0 {
		t.Fatal("no sphere references a pool; this proves nothing")
	}
	// Every pool but one is unlocked by around 14 nodes. Pool 5 is unlocked by
	// none and holds a single card, where the others hold 4 to 10: unfinished
	// content, like the three breed-127 boards. Asserted as EXACTLY one so the
	// cross-check stays sharp - if a real pool ever fell out of the board's reach,
	// the count would move.
	var orphans []int32
	for _, id := range pools.IDs() {
		if !referenced[id] {
			orphans = append(orphans, id)
		}
	}
	if len(orphans) != 1 || orphans[0] != 5 {
		t.Errorf("pools no sphere unlocks = %v, want exactly [5]", orphans)
	}
	if n := len(pools.Get(5).CardIDs); n != 1 {
		t.Errorf("pool 5 holds %d cards, want the 1 that marks it as a stub", n)
	}
}

func TestEquipmentPoolGrants(t *testing.T) {
	pools := NewEquipmentPools(
		&EquipmentPool{ID: 1, CardIDs: []int32{10, 11}},
		&EquipmentPool{ID: 2, CardIDs: []int32{11, 12}},
	)
	if !pools.Grants([]int32{1}, 10) {
		t.Error("a card in an unlocked pool is refused")
	}
	if pools.Grants([]int32{1}, 12) {
		t.Error("a card from a pool the fighter has NOT unlocked is granted")
	}
	if pools.Grants(nil, 10) {
		t.Error("a fighter with no pools is granted a card")
	}
	// An unknown pool id must be ignored, not panic or grant everything.
	if pools.Grants([]int32{99}, 10) {
		t.Error("an unknown pool granted a card")
	}
	// A card in two pools is still granted once, and the union is deduplicated.
	if got := pools.CardsOf([]int32{1, 2}); len(got) != 3 ||
		got[0] != 10 || got[1] != 11 || got[2] != 12 {
		t.Errorf("CardsOf = %v, want [10 11 12]", got)
	}
}
