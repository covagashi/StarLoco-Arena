package game

import (
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

func TestSphereCostGivesTheTenthDiscountOnAnOwnedNode(t *testing.T) {
	s := &gamedata.Sphere{ID: 7, XPCost: 218}

	if got := sphereCost(s, nil); got != 218 {
		t.Errorf("new node cost = %d, want 218", got)
	}
	// The client charges aus()/10 for a node already owned, which a portal makes
	// reachable again. Integer division, like the client's.
	if got := sphereCost(s, []int32{7}); got != 21 {
		t.Errorf("owned node cost = %d, want 21 (218/10 truncated)", got)
	}
	if got := sphereCost(s, []int32{1, 2, 3}); got != 218 {
		t.Errorf("cost = %d, want full price when the node is not owned", got)
	}
}

func TestSphereAcceptsCardOnlyForItsOwnBarrierCards(t *testing.T) {
	s := &gamedata.Sphere{ID: 1, BarrierCards: []int32{100, 200}}

	if !sphereAcceptsCard(s, 200) {
		t.Error("a listed card is refused")
	}
	if sphereAcceptsCard(s, 300) {
		t.Error("an unlisted card opens the barrier")
	}
	// 0 is what the client sends for a NON-barrier purchase; it must never be
	// mistaken for a valid sacrifice.
	if sphereAcceptsCard(s, 0) {
		t.Error("card 0 opens the barrier")
	}
	if sphereAcceptsCard(&gamedata.Sphere{ID: 2}, 0) {
		t.Error("a node with no barrier cards accepts card 0")
	}
}

// TestBuySphereChargesAndMovesTheCursor drives the repository, which is where the
// purchase becomes durable. The xp guard lives in the UPDATE's WHERE clause, so a
// fighter that cannot afford the node must come back unchanged rather than
// half-charged.
func TestBuySphereChargesAndMovesTheCursor(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "spherebuy.db"))
	if err != nil {
		t.Fatalf("open store: %v", err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("sphbuy", "secret", false)
	coach, _ := st.Coaches.Create(acc.ID, "Chef", 1, 2, 0)
	f := &domain.Fighter{CoachID: coach.ID, BreedID: 3, Name: "F", XP: 250, Evolution: true}
	if err := st.DB().Create(f).Error; err != nil {
		t.Fatalf("create fighter: %v", err)
	}

	if err := st.Fighters.BuySphere(f.ID, 42, 218, 5, 7); err != nil {
		t.Fatalf("buy: %v", err)
	}
	got, _ := st.Fighters.Get(f.ID)
	if got.XP != 32 {
		t.Errorf("xp = %d, want 32 (250 - 218)", got.XP)
	}
	if got.SphereX != 5 || got.SphereY != 7 {
		t.Errorf("cursor = (%d,%d), want (5,7) - the cursor walks onto the node bought",
			got.SphereX, got.SphereY)
	}
	owned, _ := st.Fighters.SpheresOf(f.ID)
	if len(owned) != 1 || owned[0] != 42 {
		t.Errorf("owned = %v, want [42]", owned)
	}

	// Cannot afford the next one: nothing moves.
	if err := st.Fighters.BuySphere(f.ID, 43, 1000, 9, 9); err == nil {
		t.Fatal("an unaffordable purchase succeeded")
	}
	got, _ = st.Fighters.Get(f.ID)
	if got.XP != 32 || got.SphereX != 5 || got.SphereY != 7 {
		t.Errorf("a refused purchase still moved the fighter: xp=%d cursor=(%d,%d)",
			got.XP, got.SphereX, got.SphereY)
	}
	owned, _ = st.Fighters.SpheresOf(f.ID)
	if len(owned) != 1 {
		t.Errorf("a refused purchase credited a node: %v", owned)
	}

	// Re-buying an owned node is legal and must not duplicate the row.
	if err := st.Fighters.BuySphere(f.ID, 42, 21, 5, 7); err != nil {
		t.Fatalf("rebuy: %v", err)
	}
	owned, _ = st.Fighters.SpheresOf(f.ID)
	if len(owned) != 1 {
		t.Errorf("re-buying duplicated the node: %v", owned)
	}
}
