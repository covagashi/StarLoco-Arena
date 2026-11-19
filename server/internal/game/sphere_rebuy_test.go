package game

import (
	"log/slog"
	"path/filepath"
	"testing"

	"github.com/StarLoco/arena-2.70/internal/domain"
	"github.com/StarLoco/arena-2.70/internal/gamedata"
	"github.com/StarLoco/arena-2.70/internal/protocol"
	"github.com/StarLoco/arena-2.70/internal/store/storetest"
)

// S48 (play and debug): a fighter walks back through a sphere it owns for a
// tenth of its cost — the only way out of a dead branch — and an owned
// barrier asks for no card again. Board: root (1,1) item · (2,1) empty ·
// (3,1) barrier asking card 500.
func TestSphereRebuyWalksBackThroughAnOwnedBarrier(t *testing.T) {
	st, err := storetest.Open(t, filepath.Join(t.TempDir(), "rebuy.db"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = st.Close() })
	acc, _ := st.Accounts.CreateAccount("rebuy", "pw", false)
	coach, _ := st.Coaches.Create(acc.ID, "Rebuy", 0, 0, 0)
	f := &domain.Fighter{CoachID: coach.ID, BreedID: 3, Name: "F", XP: 1000, Evolution: true,
		SphereX: 1, SphereY: 1}
	if err := st.DB().Create(f).Error; err != nil {
		t.Fatal(err)
	}
	boards := gamedata.NewSphereBoards(
		[]*gamedata.SphereBoard{{ID: 9, Breed: 3, RootX: 1, RootY: 1}},
		[]*gamedata.Sphere{
			{ID: 1, BoardID: 9, X: 1, Y: 1, XPCost: 50, EquipmentPoolID: 1},
			{ID: 2, BoardID: 9, X: 2, Y: 1},
			{ID: 3, BoardID: 9, X: 3, Y: 1, XPCost: 200, BarrierCards: []int32{500}},
		})
	s := &Session{Coach: coach, log: slog.Default(),
		deps: &Deps{Store: st, SphereBoards: boards, Log: slog.Default(), World: NewRegistry(50)}}
	buy := func(sphere, card int32) {
		w := protocol.NewWriter()
		w.I64(int64(f.ID))
		w.I32(sphere)
		w.I32(card)
		if err := handleSphereBuy(s, &protocol.C2SFrame{Payload: w.Bytes()}); err != nil {
			t.Fatal(err)
		}
	}
	xp := func() int32 { g, _ := st.Fighters.Get(f.ID); return g.XP }

	buy(3, 0) // a barrier not yet opened, no card: refused
	if xp() != 1000 {
		t.Fatalf("an unopened barrier with no card was bought (xp %d)", xp())
	}
	if err := st.DB().Create(&domain.FighterSphere{FighterID: f.ID, SphereID: 3}).Error; err != nil {
		t.Fatal(err)
	}
	buy(3, 0) // owned: walked back through for a tenth, no card
	g, _ := st.Fighters.Get(f.ID)
	if g.XP != 980 || g.SphereX != 3 || g.SphereY != 1 {
		t.Errorf("owned barrier re-buy: xp %d cursor (%d,%d), want 980 and (3,1)", g.XP, g.SphereX, g.SphereY)
	}
	owned, _ := st.Fighters.SpheresOf(f.ID)
	if len(owned) != 1 {
		t.Errorf("owned = %v, want the barrier once", owned)
	}
}
